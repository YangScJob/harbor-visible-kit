import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_server.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeHarborApiService extends HarborApiService {
  HarborConnection? configuredConnection;
  bool disconnected = false;
  bool rejectAuthentication = false;
  int authenticateCalls = 0;

  @override
  void configure(HarborConnection connection) {
    configuredConnection = connection;
    disconnected = false;
  }

  @override
  Future<String> ping() async => 'fake-version';

  @override
  Future<String> authenticate() async {
    authenticateCalls += 1;
    if (rejectAuthentication) {
      throw Exception('认证失败，请检查用户名和密码');
    }
    return configuredConnection?.username ?? 'admin';
  }

  @override
  void disconnect() {
    disconnected = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  HarborConnection connection({
    String host = 'legacy.harbor.example.test',
    int port = 9089,
    String username = 'admin',
    String password = 'secret',
  }) {
    return HarborConnection(
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }

  group('ConnectionStore', () {
    test(
      'migrates legacy single connection into server and username lists',
      () async {
        final legacy = connection();
        SharedPreferences.setMockInitialValues({
          'harbor_connection': jsonEncode({
            'host': legacy.host,
            'port': legacy.port,
            'username': legacy.username,
            'password': legacy.password,
          }),
        });

        final api = FakeHarborApiService();
        final store = ConnectionStore(api);
        await store.loadSaved();

        expect(store.servers, hasLength(1));
        expect(store.servers.single.id, 'legacy.harbor.example.test:9089');
        expect(store.usernames, ['admin']);
        expect(store.selectedServerId, 'legacy.harbor.example.test:9089');
        expect(store.selectedUsername, 'admin');
        expect(store.rememberPassword, isTrue);
        expect(store.connection.password, 'secret');
        expect(api.configuredConnection?.id, legacy.id);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('harbor_servers'), hasLength(1));
        expect(prefs.getStringList('harbor_usernames'), ['admin']);
        expect(prefs.getString('harbor_connection'), isNull);
      },
    );

    test('saves server and username without remembering password', () async {
      final store = ConnectionStore(FakeHarborApiService());
      final conn = connection(password: 'session-password');

      await store.updateConnection(conn, rememberPassword: false);

      expect(store.servers, hasLength(1));
      expect(store.usernames, ['admin']);
      expect(store.selectedServerId, 'legacy.harbor.example.test:9089');
      expect(store.connection.password, 'session-password');
      expect(store.rememberPassword, isFalse);

      final reloaded = ConnectionStore(FakeHarborApiService());
      await reloaded.loadSaved();
      expect(reloaded.connection.password, isEmpty);
    });

    test(
      'remembers password when enabled and restores it by server username',
      () async {
        final store = ConnectionStore(FakeHarborApiService());
        final conn = connection(username: 'release', password: 'remember-me');

        await store.updateConnection(conn, rememberPassword: true);

        final reloaded = ConnectionStore(FakeHarborApiService());
        await reloaded.loadSaved();

        expect(reloaded.rememberPassword, isTrue);
        expect(reloaded.selectedUsername, 'release');
        expect(reloaded.connection.password, 'remember-me');
      },
    );

    test('auto connect requires credential authentication', () async {
      final store = ConnectionStore(FakeHarborApiService());
      await store.updateConnection(
        connection(password: 'wrong-password'),
        rememberPassword: true,
      );

      final api = FakeHarborApiService()..rejectAuthentication = true;
      final reloaded = ConnectionStore(api);
      await reloaded.loadSaved();
      await Future<void>.delayed(Duration.zero);

      expect(api.authenticateCalls, 1);
      expect(api.disconnected, isTrue);
      expect(reloaded.isConnected, isFalse);
    });

    test('dedupes saved usernames and updates selected username', () async {
      final store = ConnectionStore(FakeHarborApiService());

      await store.updateConnection(connection(username: 'admin'));
      await store.updateConnection(connection(username: 'operator'));
      await store.updateConnection(connection(username: 'admin'));

      expect(store.usernames, ['admin', 'operator']);
      expect(store.selectedUsername, 'admin');
    });

    test(
      'selects server and username and clears stale connected status',
      () async {
        final api = FakeHarborApiService();
        final store = ConnectionStore(api);
        final first = HarborServer(host: 'harbor-a.example.test', port: 8085);
        final second = HarborServer(host: 'harbor-b.example.test', port: 9089);

        await store.saveServer(first);
        await store.updateConnection(
          connection(host: second.host, port: second.port, username: 'release'),
          rememberPassword: true,
        );
        store.setConnected('v2.0');

        await store.selectServer(first.id);
        expect(store.connection.registry, first.registry);
        expect(store.isConnected, isFalse);
        expect(api.disconnected, isTrue);

        await store.selectUsername('release');
        expect(store.selectedUsername, 'release');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('harbor_selected_server_id'), first.id);
        expect(prefs.getString('harbor_selected_username'), 'release');
      },
    );

    test(
      'deletes selected server and clears saved passwords for that server',
      () async {
        final store = ConnectionStore(FakeHarborApiService());
        final first = connection(
          host: 'harbor-a.example.test',
          password: 'first-password',
        );
        final second = connection(
          host: 'harbor-b.example.test',
          password: 'second-password',
        );

        await store.updateConnection(first, rememberPassword: true);
        await store.updateConnection(second, rememberPassword: true);

        await store.deleteServer(second.registry);
        expect(store.servers, hasLength(1));
        expect(store.connection.registry, first.registry);
        expect(store.selectedServerId, first.registry);

        await store.deleteServer(first.registry);
        expect(store.servers, isEmpty);
        expect(store.selectedServerId, isNull);
        expect(store.connection.host, isEmpty);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('harbor_servers'), isEmpty);
        expect(prefs.getString('harbor_selected_server_id'), isNull);
        expect(prefs.getString('harbor_saved_passwords'), '{}');
      },
    );
  });
}

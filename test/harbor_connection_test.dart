import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_server.dart';

void main() {
  group('HarborConnection', () {
    test('builds stable id and display label from connection fields', () {
      const conn = HarborConnection(
        host: 'Harbor.Local',
        port: 8085,
        username: 'admin',
        password: 'secret',
      );

      expect(conn.id, 'harbor.local:8085|admin');
      expect(conn.displayLabel, 'Harbor.Local:8085 / admin');
      expect(conn.toJson()['id'], 'harbor.local:8085|admin');
    });

    test('reads legacy json without id and parses string port', () {
      final conn = HarborConnection.fromJson({
        'host': 'legacy.harbor.example.test',
        'port': '9089',
        'username': 'admin',
        'password': 'secret',
      });

      expect(conn.port, 9089);
      expect(conn.id, 'legacy.harbor.example.test:9089|admin');
      expect(conn.displayLabel, 'legacy.harbor.example.test:9089 / admin');
    });
  });

  group('HarborServer', () {
    test('builds stable id and display label from host and port', () {
      const server = HarborServer(host: 'Harbor.Local', port: 8085);

      expect(server.id, 'harbor.local:8085');
      expect(server.displayLabel, 'Harbor.Local:8085');
      expect(server.toJson()['id'], 'harbor.local:8085');
    });

    test('reads json with string port', () {
      final server = HarborServer.fromJson({
        'host': 'legacy.harbor.example.test',
        'port': '9089',
      });

      expect(server.port, 9089);
      expect(server.id, 'legacy.harbor.example.test:9089');
    });
  });
}

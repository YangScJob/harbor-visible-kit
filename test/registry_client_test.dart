import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/data/harbor/registry_client.dart';

void main() {
  group('RegistryClient', () {
    test('parses bearer auth challenge', () {
      final params = RegistryClient.parseAuthChallenge(
        'Bearer realm="http://harbor.local/service/token",'
        'service="harbor-registry",scope="repository:example/app:pull,push"',
      );

      expect(params['realm'], 'http://harbor.local/service/token');
      expect(params['service'], 'harbor-registry');
      expect(params['scope'], 'repository:example/app:pull,push');
    });

    test('calculates sha256 digest with registry prefix', () {
      final digest = RegistryClient.digestForBytes(utf8.encode('artifact'));

      expect(
        digest,
        'sha256:c7c5c1d70c5dec4416ab6158afd0b223ef40c29b1dc1f97ed9428b94d4cadb1c',
      );
    });
  });
}

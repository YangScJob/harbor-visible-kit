import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';
import 'package:harbor_visible_kit/domain/push/harbor_push_config.dart';

void main() {
  group('HarborPushConfig', () {
    test(
      'loads legacy json with default artifact type and empty customer code',
      () {
        final config = HarborPushConfig.fromJson({
          'id': 'legacy',
          'name': '旧模板',
          'project': 'release',
          'artifact': 'example-service-artifacts',
          'tag': '3.4.0',
        });

        expect(config.artifactType, PushArtifactType.jar);
        expect(config.customerCode, isEmpty);
        expect(config.project, 'release');
        expect(config.artifact, 'example-service-artifacts');
      },
    );

    test('persists artifact type and tag suffix', () {
      const config = HarborPushConfig(
        id: 'apk',
        name: '移动端补丁',
        project: 'release',
        artifact: '',
        tag: '3.4.0.1',
        artifactType: PushArtifactType.apk,
        customerCode: 'customer-a',
      );

      final json = config.toJson();
      expect(json['artifactType'], 'apk');
      expect(json['customerCode'], 'customer-a');

      final restored = HarborPushConfig.fromJson(json);
      expect(restored.artifactType, PushArtifactType.apk);
      expect(restored.customerCode, 'customer-a');
    });

    test(
      'maps legacy internal artifact type names to generic open-source types',
      () {
        expect(
          HarborPushConfig.fromJson({
            'artifactType': 'damengImage',
          }).artifactType,
          PushArtifactType.image,
        );
        expect(
          HarborPushConfig.fromJson({
            'artifactType': 'androidAppA',
          }).artifactType,
          PushArtifactType.apk,
        );
        expect(
          HarborPushConfig.fromJson({
            'artifactType': 'androidAppB',
          }).artifactType,
          PushArtifactType.apk,
        );
      },
    );
  });
}

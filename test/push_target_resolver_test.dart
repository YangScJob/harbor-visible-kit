import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_target_resolver.dart';

void main() {
  const resolver = PushTargetResolver();
  const registry = 'harbor.example.test:8080';
  const project = 'release';

  PushSourceFile file(String name, {String? path}) {
    return PushSourceFile(path: path ?? '/tmp/$name', name: name);
  }

  group('PushTargetResolver', () {
    test('resolves jar repository and appends tag suffix before jar suffix', () {
      final target = resolver.resolve(
        file: file('example-service.jar'),
        artifactType: PushArtifactType.jar,
        registry: registry,
        project: project,
        batchVersion: '3.4.0.1',
        customerCode: 'customer-a',
      );

      expect(target.isValid, isTrue);
      expect(target.repository, 'example-service-artifacts');
      expect(target.version, '3.4.0.1');
      expect(target.tag, '3.4.0.1-customer-a-jar');
      expect(
        target.imageTag,
        'harbor.example.test:8080/release/example-service-artifacts:3.4.0.1-customer-a-jar',
      );
    });

    test('resolves image service when file version matches batch version', () {
      final target = resolver.resolve(
        file: file('example-api-docker-image-3.4.0.tar.gz'),
        artifactType: PushArtifactType.image,
        registry: registry,
        project: project,
        batchVersion: '3.4.0',
      );

      expect(target.isValid, isTrue);
      expect(target.repository, 'example-api');
      expect(target.version, '3.4.0');
      expect(target.tag, '3.4.0');
    });

    test(
      'rejects image archive when file version differs from batch version',
      () {
        final target = resolver.resolve(
          file: file('example-api-docker-image-3.4.0.tar.gz'),
          artifactType: PushArtifactType.image,
          registry: registry,
          project: project,
          batchVersion: '3.5.0',
        );

        expect(target.isValid, isFalse);
        expect(target.version, '3.4.0');
        expect(target.tag, '3.4.0');
        expect(target.imageTag, isNull);
        expect(target.errors.join(), contains('文件版本 3.4.0 与当前版本标签 3.5.0 不一致'));
      },
    );

    test('uses parsed image repository without product-specific suffixes', () {
      final target = resolver.resolve(
        file: file('example-db-docker-image-3.4.0.1.tar.gz'),
        artifactType: PushArtifactType.image,
        registry: registry,
        project: project,
        batchVersion: '3.4.0.1',
      );

      expect(target.isValid, isTrue);
      expect(target.repository, 'example-db');
      expect(target.tag, '3.4.0.1');
    });

    test('uses manual repository override for unrecognized archives', () {
      final target = resolver.resolve(
        file: file('custom-hotfix.tar.gz'),
        artifactType: PushArtifactType.image,
        registry: registry,
        project: project,
        batchVersion: '3.4.0.1',
        repositoryOverride: 'custom-service',
      );

      expect(target.isValid, isTrue);
      expect(target.requiresRepositoryOverride, isTrue);
      expect(target.repository, 'custom-service');
      expect(target.tag, '3.4.0.1');
    });

    test('resolves web package to fixed web repository and manual tag', () {
      final target = resolver.resolve(
        file: file('dist.zip'),
        artifactType: PushArtifactType.web,
        registry: registry,
        project: project,
        batchVersion: '3.4.0.1',
        repositoryOverride: 'portal',
      );

      expect(target.isValid, isTrue);
      expect(target.requiresRepositoryOverride, isFalse);
      expect(target.repository, 'web');
      expect(target.version, '3.4.0.1');
      expect(target.tag, '3.4.0.1');
      expect(target.imageTag, 'harbor.example.test:8080/release/web:3.4.0.1');
    });

    test('rejects web package files that are not dist zip', () {
      final target = resolver.resolve(
        file: file('portal.zip'),
        artifactType: PushArtifactType.web,
        registry: registry,
        project: project,
        batchVersion: '3.4.0.1',
        repositoryOverride: 'portal',
      );

      expect(target.isValid, isFalse);
      expect(target.errors.join(), contains('dist.zip'));
    });

    test('resolves generic APK repository and build tag from filename', () {
      final target = resolver.resolve(
        file: file('mobile-client V3.4.1 build98.apk'),
        artifactType: PushArtifactType.apk,
        registry: registry,
        project: project,
        batchVersion: '3.4.1',
      );

      expect(target.isValid, isTrue);
      expect(target.requiresRepositoryOverride, isFalse);
      expect(target.repository, 'mobile-client');
      expect(target.version, '3.4.1-98');
      expect(target.tag, '3.4.1-98');
      expect(
        target.imageTag,
        'harbor.example.test:8080/release/mobile-client:3.4.1-98',
      );
    });

    test('resolves generic APK with optional space before build code', () {
      final target = resolver.resolve(
        file: file('mobile-client V3.4.1 build 187.apk'),
        artifactType: PushArtifactType.apk,
        registry: registry,
        project: project,
        batchVersion: 'V3.4.1',
      );

      expect(target.isValid, isTrue);
      expect(target.repository, 'mobile-client');
      expect(target.version, '3.4.1-187');
      expect(target.tag, '3.4.1-187');
      expect(
        target.imageTag,
        'harbor.example.test:8080/release/mobile-client:3.4.1-187',
      );
    });

    test(
      'resolves APK repository from plain file name when pattern is absent',
      () {
        final target = resolver.resolve(
          file: file('mobile-client.apk'),
          artifactType: PushArtifactType.apk,
          registry: registry,
          project: project,
          batchVersion: '3.4.1',
        );

        expect(target.isValid, isTrue);
        expect(target.repository, 'mobile-client');
        expect(target.version, '3.4.1');
        expect(target.tag, '3.4.1');
      },
    );

    test('allows manual repository override for APK files', () {
      final target = resolver.resolve(
        file: file('debug-build.apk'),
        artifactType: PushArtifactType.apk,
        registry: registry,
        project: project,
        batchVersion: '3.4.1',
        repositoryOverride: 'mobile-client',
      );

      expect(target.isValid, isTrue);
      expect(target.repository, 'mobile-client');
      expect(target.tag, '3.4.1');
    });

    test('rejects apk when filename version differs from batch version', () {
      final target = resolver.resolve(
        file: file('mobile-client V3.4.1 build98.apk'),
        artifactType: PushArtifactType.apk,
        registry: registry,
        project: project,
        batchVersion: '3.4.2',
      );

      expect(target.isValid, isFalse);
      expect(
        target.errors.join(),
        contains('APK 文件版本 3.4.1 与当前版本标签 3.4.2 不一致'),
      );
    });

    test('rejects mixed artifact types', () {
      final jarBatchTarget = resolver.resolve(
        file: file('example-api-docker-image-3.4.0.tar.gz'),
        artifactType: PushArtifactType.jar,
        registry: registry,
        project: project,
        batchVersion: '3.4.0',
      );
      final imageBatchTarget = resolver.resolve(
        file: file('example-service.jar'),
        artifactType: PushArtifactType.image,
        registry: registry,
        project: project,
        batchVersion: '3.4.0',
      );
      final apkBatchTarget = resolver.resolve(
        file: file('example-service.jar'),
        artifactType: PushArtifactType.apk,
        registry: registry,
        project: project,
        batchVersion: '3.4.0',
      );

      expect(jarBatchTarget.isValid, isFalse);
      expect(jarBatchTarget.errors.join(), contains('只能选择 .jar'));
      expect(imageBatchTarget.isValid, isFalse);
      expect(imageBatchTarget.errors.join(), contains('.tar.gz'));
      expect(apkBatchTarget.isValid, isFalse);
      expect(apkBatchTarget.errors.join(), contains('.apk'));
    });

    test('rejects non-ascii tag suffix', () {
      final target = resolver.resolve(
        file: file('example-service.jar'),
        artifactType: PushArtifactType.jar,
        registry: registry,
        project: project,
        batchVersion: '3.4.0',
        customerCode: '中文',
      );

      expect(target.isValid, isFalse);
      expect(target.errors.join(), contains('ASCII'));
    });
  });
}

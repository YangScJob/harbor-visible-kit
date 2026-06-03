import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_kind_classifier.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';

void main() {
  group('ArtifactKindClassifier', () {
    test('classifies repository names by generic artifact type', () {
      expect(
        ArtifactKindClassifier.isRepositoryNameInArtifactType(
          'release/example-service-artifacts',
          PushArtifactType.jar,
        ),
        isTrue,
      );
      expect(
        ArtifactKindClassifier.isRepositoryNameInArtifactType(
          'release/web',
          PushArtifactType.web,
        ),
        isTrue,
      );
      expect(
        ArtifactKindClassifier.isRepositoryNameInArtifactType(
          'release/mobile-client-apk',
          PushArtifactType.apk,
        ),
        isTrue,
      );
      expect(
        ArtifactKindClassifier.isRepositoryNameInArtifactType(
          'release/example-service',
          PushArtifactType.image,
        ),
        isTrue,
      );
    });

    test('keeps typed repositories out of generic image type', () {
      for (final repository in [
        'release/example-service-artifacts',
        'release/web',
        'release/mobile-client-apk',
        'release/mobile-client-android',
      ]) {
        expect(
          ArtifactKindClassifier.isRepositoryNameInArtifactType(
            repository,
            PushArtifactType.image,
          ),
          isFalse,
          reason: repository,
        );
      }
    });

    test('returns user-facing labels for repository kinds', () {
      expect(
        ArtifactKindClassifier.kindLabelForRepositoryName(
          'release/example-service-artifacts',
        ),
        'JAR',
      );
      expect(
        ArtifactKindClassifier.kindLabelForRepositoryName('release/web'),
        'Web',
      );
      expect(
        ArtifactKindClassifier.kindLabelForRepositoryName(
          'release/mobile-client-apk',
        ),
        'Android APK',
      );
      expect(
        ArtifactKindClassifier.kindLabelForRepositoryName(
          'release/example-service',
        ),
        '镜像',
      );
    });
  });
}

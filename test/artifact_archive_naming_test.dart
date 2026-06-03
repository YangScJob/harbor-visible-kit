import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_archive_naming.dart';

void main() {
  group('ArtifactArchiveNaming', () {
    test('builds docker image archive name with tar gz extension', () {
      final fileName = ArtifactArchiveNaming.dockerImageArchiveFileName(
        repositoryName: 'shardingsphere-center',
        tag: '3.4.0',
      );

      expect(fileName, 'shardingsphere-center-docker-image-3.4.0.tar.gz');
    });

    test('does not duplicate docker image marker', () {
      final fileName = ArtifactArchiveNaming.dockerImageArchiveFileName(
        repositoryName: 'shardingsphere-center-docker-image',
        tag: '3.4.0',
      );

      expect(fileName, 'shardingsphere-center-docker-image-3.4.0.tar.gz');
    });

    test('sanitizes repository segment and tag for local path use', () {
      final fileName = ArtifactArchiveNaming.dockerImageArchiveFileName(
        repositoryName: 'release/shardingsphere:center',
        tag: '3.4.0/hotfix',
      );

      expect(
        fileName,
        'shardingsphere_center-docker-image-3.4.0_hotfix.tar.gz',
      );
    });
  });
}

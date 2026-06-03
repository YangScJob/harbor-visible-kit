import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';

class ArtifactKindClassifier {
  const ArtifactKindClassifier._();

  static String repositoryBaseName(String repositoryName) {
    return repositoryName.split('/').last.toLowerCase();
  }

  static bool isJarRepositoryName(String repositoryName) {
    return repositoryBaseName(repositoryName).endsWith('-artifacts');
  }

  static bool isWebRepositoryName(String repositoryName) {
    return repositoryBaseName(repositoryName) == 'web';
  }

  static bool isApkRepositoryName(String repositoryName) {
    final repoName = repositoryBaseName(repositoryName);
    return repoName == 'apk' ||
        repoName == 'android' ||
        repoName.endsWith('-apk') ||
        repoName.endsWith('-android');
  }

  static bool isRepositoryNameInArtifactType(
    String repositoryName,
    PushArtifactType type,
  ) {
    final isJar = isJarRepositoryName(repositoryName);
    final isWeb = isWebRepositoryName(repositoryName);
    final isApk = isApkRepositoryName(repositoryName);

    return switch (type) {
      PushArtifactType.jar => isJar,
      PushArtifactType.image => !isJar && !isWeb && !isApk,
      PushArtifactType.web => isWeb,
      PushArtifactType.apk => isApk,
    };
  }

  static bool isApkArtifactType(PushArtifactType artifactType) {
    return artifactType == PushArtifactType.apk;
  }

  static String kindLabelForRepositoryName(String repositoryName) {
    if (isJarRepositoryName(repositoryName)) return 'JAR';
    if (isWebRepositoryName(repositoryName)) return 'Web';
    if (isApkRepositoryName(repositoryName)) return 'Android APK';
    return '镜像';
  }
}

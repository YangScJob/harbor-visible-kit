class ArtifactArchiveNaming {
  static const dockerImageMarker = '-docker-image';

  const ArtifactArchiveNaming._();

  static String dockerImageArchiveFileName({
    required String repositoryName,
    required String tag,
    bool compressed = true,
  }) {
    final repoSegment = repositoryName.split('/').last;
    final sanitizedRepo = sanitizePathSegment(repoSegment);
    final baseName = sanitizedRepo.endsWith(dockerImageMarker)
        ? sanitizedRepo
        : '$sanitizedRepo$dockerImageMarker';
    final extension = compressed ? '.tar.gz' : '.tar';

    return '$baseName-${sanitizePathSegment(tag)}$extension';
  }

  static String sanitizePathSegment(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}

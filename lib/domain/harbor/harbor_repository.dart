/// Harbor repository model.
class HarborRepository {
  final int id;
  final String name;
  final int artifactCount;
  final String creationTime;
  final String updateTime;

  const HarborRepository({
    required this.id,
    required this.name,
    required this.artifactCount,
    required this.creationTime,
    required this.updateTime,
  });

  /// Short name without the project prefix.
  String get shortName {
    final parts = name.split('/');
    return parts.length > 1 ? parts.sublist(1).join('/') : name;
  }

  factory HarborRepository.fromJson(Map<String, dynamic> json) {
    return HarborRepository(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      artifactCount: json['artifact_count'] as int? ?? 0,
      creationTime: json['creation_time'] as String? ?? '',
      updateTime: json['update_time'] as String? ?? '',
    );
  }
}

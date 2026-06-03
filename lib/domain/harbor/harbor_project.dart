/// Harbor project model.
class HarborProject {
  final int projectId;
  final String name;
  final int repoCount;
  final String creationTime;

  const HarborProject({
    required this.projectId,
    required this.name,
    required this.repoCount,
    required this.creationTime,
  });

  factory HarborProject.fromJson(Map<String, dynamic> json) {
    return HarborProject(
      projectId: json['project_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      repoCount: json['repo_count'] as int? ?? 0,
      creationTime: json['creation_time'] as String? ?? '',
    );
  }
}

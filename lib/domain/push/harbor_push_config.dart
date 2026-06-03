import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';

/// Push configuration model.
class HarborPushConfig {
  final String id;
  final String name;
  final String project;
  final String artifact;
  final String tag;
  final PushArtifactType artifactType;
  final String customerCode;

  const HarborPushConfig({
    required this.id,
    required this.name,
    required this.project,
    required this.artifact,
    required this.tag,
    this.artifactType = PushArtifactType.jar,
    this.customerCode = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'project': project,
    'artifact': artifact,
    'tag': tag,
    'artifactType': artifactType.name,
    'customerCode': customerCode,
  };

  factory HarborPushConfig.fromJson(Map<String, dynamic> json) {
    return HarborPushConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      project: json['project'] as String? ?? '',
      artifact: json['artifact'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      artifactType: PushArtifactType.fromName(json['artifactType'] as String?),
      customerCode: json['customerCode'] as String? ?? '',
    );
  }

  factory HarborPushConfig.empty() => const HarborPushConfig(
    id: '',
    name: '',
    project: '',
    artifact: '',
    tag: '',
  );

  HarborPushConfig copyWith({
    String? id,
    String? name,
    String? project,
    String? artifact,
    String? tag,
    PushArtifactType? artifactType,
    String? customerCode,
  }) {
    return HarborPushConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      project: project ?? this.project,
      artifact: artifact ?? this.artifact,
      tag: tag ?? this.tag,
      artifactType: artifactType ?? this.artifactType,
      customerCode: customerCode ?? this.customerCode,
    );
  }
}

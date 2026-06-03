/// Harbor artifact and tag model.
class HarborArtifact {
  final String digest;
  final List<String> tags;
  final int size;
  final String pushTime;
  final String mediaType;

  const HarborArtifact({
    required this.digest,
    required this.tags,
    required this.size,
    required this.pushTime,
    required this.mediaType,
  });

  /// Primary tag name, usually the first tag.
  String get primaryTag =>
      tags.isNotEmpty ? tags.first : digest.substring(0, 12);

  /// Human-readable file size.
  String get readableSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  factory HarborArtifact.fromJson(Map<String, dynamic> json) {
    final tagList = <String>[];
    if (json['tags'] != null) {
      for (final tag in json['tags'] as List) {
        if (tag is Map<String, dynamic> && tag['name'] != null) {
          tagList.add(tag['name'] as String);
        }
      }
    }
    return HarborArtifact(
      digest: json['digest'] as String? ?? '',
      tags: tagList,
      size: json['size'] as int? ?? 0,
      pushTime: json['push_time'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? '',
    );
  }
}

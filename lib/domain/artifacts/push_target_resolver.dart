import 'package:harbor_visible_kit/domain/artifacts/artifact_kind_classifier.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';

class PushSourceFile {
  final String path;
  final String name;

  const PushSourceFile({required this.path, required this.name});

  bool get isJar => name.toLowerCase().endsWith('.jar');

  bool get isWebPackage => name.toLowerCase() == 'dist.zip';

  bool get isApk => name.toLowerCase().endsWith('.apk');

  bool get isArchive {
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('.tar.gz') ||
        lowerName.endsWith('.tgz') ||
        lowerName.endsWith('.tar');
  }

  String get jarBaseName => name.substring(0, name.length - '.jar'.length);

  String get apkBaseName => name.substring(0, name.length - '.apk'.length);
}

class PushTargetResolution {
  final PushSourceFile file;
  final PushArtifactType artifactType;
  final String? repository;
  final String? version;
  final String? tag;
  final String? imageTag;
  final bool requiresRepositoryOverride;
  final List<String> errors;

  const PushTargetResolution({
    required this.file,
    required this.artifactType,
    required this.repository,
    required this.version,
    required this.tag,
    required this.imageTag,
    required this.requiresRepositoryOverride,
    required this.errors,
  });

  bool get isValid => errors.isEmpty && imageTag != null;
}

class PushTargetResolver {
  static final RegExp _customerCodePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_.-]*$',
  );
  static final RegExp _dockerTagPattern = RegExp(
    r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$',
  );
  static final RegExp _apkNamePattern = RegExp(
    r'^(.*?)\s+V([0-9]+(?:\.[0-9]+)*)\s+build\s*([0-9]+)\.apk$',
    caseSensitive: false,
  );

  const PushTargetResolver();

  PushTargetResolution resolve({
    required PushSourceFile file,
    required PushArtifactType artifactType,
    required String registry,
    required String project,
    required String batchVersion,
    String customerCode = '',
    String repositoryOverride = '',
  }) {
    final errors = <String>[];
    final trimmedRegistry = registry.trim();
    final trimmedProject = project.trim();
    final trimmedVersion = batchVersion.trim();
    final trimmedCustomerCode = customerCode.trim();
    final normalizedOverride = normalizeRepository(repositoryOverride);

    if (trimmedRegistry.isEmpty) {
      errors.add('请先连接 Harbor');
    }
    if (trimmedProject.isEmpty) {
      errors.add('请选择项目空间');
    }
    if (!_isAllowedForType(file, artifactType)) {
      errors.add(_typeMismatchMessage(artifactType));
    }
    if (trimmedVersion.isEmpty) {
      errors.add('请填写版本标签');
    }
    if (trimmedCustomerCode.isNotEmpty &&
        !isValidCustomerCode(trimmedCustomerCode)) {
      errors.add('标签后缀仅支持 ASCII 字母、数字、下划线、中划线和点号');
    }

    String? repository;
    String version;
    var requiresRepositoryOverride = false;

    if (artifactType == PushArtifactType.jar) {
      if (file.isJar) {
        repository = normalizeRepository('${file.jarBaseName}-artifacts');
      }
      version = trimmedVersion;
    } else if (artifactType == PushArtifactType.web) {
      version = trimmedVersion;
      repository = 'web';
    } else if (ArtifactKindClassifier.isApkArtifactType(artifactType)) {
      final apkParts = parseApkName(file.name);
      if (normalizedOverride.isNotEmpty) {
        repository = normalizedOverride;
      } else if (apkParts != null) {
        repository = normalizeRepository(apkParts.appName);
      } else if (file.isApk) {
        repository = normalizeRepository(file.apkBaseName);
      }

      if (apkParts == null) {
        version = trimmedVersion;
      } else {
        final normalizedBatchVersion = _normalizeVersionName(trimmedVersion);
        if (normalizedBatchVersion.isNotEmpty &&
            apkParts.versionName != normalizedBatchVersion) {
          errors.add(
            'APK 文件版本 ${apkParts.versionName} 与当前版本标签 $trimmedVersion 不一致，请选择正确包或修改版本标签',
          );
        }
        version = '${apkParts.versionName}-${apkParts.versionCode}';
      }
    } else {
      final archiveParts = parseArchiveName(file.name);
      requiresRepositoryOverride = archiveParts == null;
      repository = archiveParts?.service;
      version = archiveParts?.version ?? trimmedVersion;
      if (archiveParts != null &&
          trimmedVersion.isNotEmpty &&
          archiveParts.version != trimmedVersion) {
        errors.add(
          '文件版本 ${archiveParts.version} 与当前版本标签 $trimmedVersion 不一致，请选择正确包或修改版本标签',
        );
      }

      if (normalizedOverride.isNotEmpty) {
        repository = normalizedOverride;
      } else if (repository != null) {
        repository = normalizeRepository(repository);
      }
    }

    if (repository == null || repository.isEmpty) {
      errors.add('无法从文件名识别仓库名，请手动填写仓库名');
    }
    if (version.trim().isEmpty) {
      errors.add('无法推导版本标签');
    }

    final resolvedTag = _buildTag(
      artifactType: artifactType,
      version: version,
      customerCode: trimmedCustomerCode,
    );
    if (resolvedTag.isNotEmpty && !_dockerTagPattern.hasMatch(resolvedTag)) {
      errors.add('最终标签包含 Docker 不支持的字符');
    }

    final imageTag = errors.isEmpty
        ? '$trimmedRegistry/$trimmedProject/$repository:$resolvedTag'
        : null;

    return PushTargetResolution(
      file: file,
      artifactType: artifactType,
      repository: repository,
      version: version,
      tag: resolvedTag.isEmpty ? null : resolvedTag,
      imageTag: imageTag,
      requiresRepositoryOverride: requiresRepositoryOverride,
      errors: errors,
    );
  }

  bool isValidCustomerCode(String customerCode) {
    final trimmed = customerCode.trim();
    return trimmed.isEmpty || _customerCodePattern.hasMatch(trimmed);
  }

  ArchiveNameParts? parseArchiveName(String fileName) {
    final stem = stripArchiveExtension(fileName);
    const marker = '-docker-image-';
    final markerIndex = stem.indexOf(marker);
    if (markerIndex <= 0) return null;

    final service = normalizeRepository(stem.substring(0, markerIndex));
    final version = stem.substring(markerIndex + marker.length).trim();
    if (service.isEmpty || version.isEmpty) return null;
    return ArchiveNameParts(service: service, version: version);
  }

  ApkNameParts? parseApkName(String fileName) {
    final match = _apkNamePattern.firstMatch(fileName.trim());
    if (match == null) return null;
    final appName = normalizeRepository(match.group(1)!);
    if (appName.isEmpty) return null;
    return ApkNameParts(
      appName: appName,
      versionName: match.group(2)!,
      versionCode: match.group(3)!,
    );
  }

  String stripArchiveExtension(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.tar.gz')) {
      return fileName.substring(0, fileName.length - '.tar.gz'.length);
    }
    if (lowerName.endsWith('.tgz')) {
      return fileName.substring(0, fileName.length - '.tgz'.length);
    }
    if (lowerName.endsWith('.tar')) {
      return fileName.substring(0, fileName.length - '.tar'.length);
    }
    return fileName;
  }

  String normalizeRepository(String repository) {
    return repository
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._/-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'(^[-./]+|[-./]+$)'), '');
  }

  bool _isAllowedForType(PushSourceFile file, PushArtifactType artifactType) {
    return switch (artifactType) {
      PushArtifactType.jar => file.isJar,
      PushArtifactType.image => file.isArchive,
      PushArtifactType.web => file.isWebPackage,
      PushArtifactType.apk => file.isApk,
    };
  }

  String _typeMismatchMessage(PushArtifactType artifactType) {
    return switch (artifactType) {
      PushArtifactType.jar => 'JAR 服务包批次只能选择 .jar 文件',
      PushArtifactType.image => 'Docker 镜像包批次只能选择 .tar.gz/.tgz/.tar 文件',
      PushArtifactType.web => 'Web 前端包批次只能选择 dist.zip 文件',
      PushArtifactType.apk => 'Android APK 批次只能选择 .apk 文件',
    };
  }

  String _normalizeVersionName(String version) {
    return version.trim().replaceFirst(RegExp(r'^[Vv]'), '');
  }

  String _buildTag({
    required PushArtifactType artifactType,
    required String version,
    required String customerCode,
  }) {
    final versionPart = version.trim();
    if (versionPart.isEmpty) return '';

    final customerPart = customerCode.trim();
    final taggedVersion = customerPart.isEmpty
        ? versionPart
        : '$versionPart-$customerPart';
    if (artifactType == PushArtifactType.jar) {
      return taggedVersion.endsWith('-jar')
          ? taggedVersion
          : '$taggedVersion-jar';
    }
    return taggedVersion;
  }
}

class ArchiveNameParts {
  final String service;
  final String version;

  const ArchiveNameParts({required this.service, required this.version});
}

class ApkNameParts {
  final String appName;
  final String versionName;
  final String versionCode;

  const ApkNameParts({
    required this.appName,
    required this.versionName,
    required this.versionCode,
  });
}

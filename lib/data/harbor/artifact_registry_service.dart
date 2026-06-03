import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_archive_naming.dart';
import 'package:harbor_visible_kit/data/artifacts/file_artifact_packager.dart';
import 'package:harbor_visible_kit/data/artifacts/image_archive_planner.dart';
import 'package:harbor_visible_kit/data/harbor/registry_client.dart';
import 'package:harbor_visible_kit/data/artifacts/tar_archive_utils.dart';

class ArtifactRegistryService {
  static const _dockerConfigMediaType =
      'application/vnd.docker.container.image.v1+json';
  static const _dockerLayerGzipMediaType =
      'application/vnd.docker.image.rootfs.diff.tar.gzip';
  static const _ociImageIndexMediaType =
      'application/vnd.oci.image.index.v1+json';
  static const _dockerManifestListMediaType =
      'application/vnd.docker.distribution.manifest.list.v2+json';
  static const _artifactFileNameLabel = 'harbor-visible-kit.artifact.file-name';

  final HarborConnection connection;
  late final RegistryClient _client;

  ArtifactRegistryService(this.connection) {
    _client = RegistryClient(connection);
  }

  Future<void> pushJar({
    required String project,
    required String repository,
    required String tag,
    required String jarPath,
    void Function(String line)? onOutput,
  }) async {
    await _pushFileArtifact(
      project: project,
      repository: repository,
      tag: tag,
      sourcePath: jarPath,
      containerDirectory: 'app',
      artifactLabel: 'JAR 制品',
      tempPrefix: 'harbor-visible-kit-push-jar-',
      onOutput: onOutput,
    );
  }

  Future<void> pushWebPackage({
    required String project,
    required String repository,
    required String tag,
    required String packagePath,
    void Function(String line)? onOutput,
  }) async {
    final packageName = File(packagePath).uri.pathSegments.last.toLowerCase();
    if (packageName != 'dist.zip') {
      throw Exception('Web 前端包文件必须命名为 dist.zip');
    }
    await _pushFileArtifact(
      project: project,
      repository: repository,
      tag: tag,
      sourcePath: packagePath,
      containerDirectory: 'web',
      artifactLabel: 'Web 前端包',
      tempPrefix: 'harbor-visible-kit-push-web-',
      onOutput: onOutput,
    );
  }

  Future<void> pushApkPackage({
    required String project,
    required String repository,
    required String tag,
    required String apkPath,
    required String artifactLabel,
    void Function(String line)? onOutput,
  }) async {
    final packageName = File(apkPath).uri.pathSegments.last.toLowerCase();
    if (!packageName.endsWith('.apk')) {
      throw Exception('$artifactLabel 文件必须是 .apk 安装包');
    }
    await _pushFileArtifact(
      project: project,
      repository: repository,
      tag: tag,
      sourcePath: apkPath,
      containerFileName: 'package.apk',
      containerDirectory: 'apk',
      artifactLabel: artifactLabel,
      tempPrefix: 'harbor-visible-kit-push-apk-',
      metadataFileName: File(apkPath).uri.pathSegments.last,
      onOutput: onOutput,
    );
  }

  Future<void> _pushFileArtifact({
    required String project,
    required String repository,
    required String tag,
    required String sourcePath,
    String? containerFileName,
    required String containerDirectory,
    required String artifactLabel,
    required String tempPrefix,
    String? metadataFileName,
    void Function(String line)? onOutput,
  }) async {
    final sourceFile = File(sourcePath);
    final sourceFileName = sourceFile.uri.pathSegments.last;
    final fileName = containerFileName ?? sourceFileName;
    final containerPath = '/$containerDirectory/$fileName';
    final fullRepository = _client.repositoryPath(project, repository);

    onOutput?.call('正在构造 $artifactLabel 镜像: $repository:$tag');
    final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
    try {
      final preparedLayer = await Isolate.run(
        () => FileArtifactPackager.prepareLayerFile(
          sourcePath: sourcePath,
          fileName: fileName,
          containerDirectory: containerDirectory,
          tempDirPath: tempDir.path,
        ),
      );
      final layerFile = File(preparedLayer['path'] as String);
      final layerDigest = preparedLayer['digest'] as String;
      final diffId = preparedLayer['diffId'] as String;
      final layerSize = preparedLayer['size'] as int;

      final now = DateTime.now().toUtc().toIso8601String();
      final configBytes = _jsonBytes({
        'created': now,
        'architecture': 'amd64',
        'os': 'linux',
        'config': {
          'Cmd': [containerPath],
          if (metadataFileName != null)
            'Labels': {_artifactFileNameLabel: metadataFileName},
        },
        'rootfs': {
          'type': 'layers',
          'diff_ids': [diffId],
        },
        'history': [
          {
            'created': now,
            'created_by': 'harbor-visible-kit import $sourceFileName',
          },
        ],
      });
      final configDigest = RegistryClient.digestForBytes(configBytes);

      await _client.uploadBlob(
        repository: fullRepository,
        bytes: configBytes,
        digest: configDigest,
        onOutput: onOutput,
      );
      await _client.uploadBlobFromFile(
        repository: fullRepository,
        file: layerFile,
        digest: layerDigest,
        onOutput: onOutput,
      );

      final manifestBytes = _jsonBytes({
        'schemaVersion': 2,
        'mediaType': RegistryClient.dockerManifestV2,
        'config': {
          'mediaType': _dockerConfigMediaType,
          'size': configBytes.length,
          'digest': configDigest,
        },
        'layers': [
          {
            'mediaType': _dockerLayerGzipMediaType,
            'size': layerSize,
            'digest': layerDigest,
          },
        ],
      });
      await _client.putManifest(
        repository: fullRepository,
        reference: tag,
        bytes: manifestBytes,
        mediaType: RegistryClient.dockerManifestV2,
      );
      onOutput?.call('$artifactLabel 上传完成: $fullRepository:$tag');
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> pushImageArchive({
    required String project,
    required String repository,
    required String tag,
    required String archivePath,
    void Function(String line)? onOutput,
  }) async {
    final fullRepository = _client.repositoryPath(project, repository);
    final tempDir = await Directory.systemTemp.createTemp(
      'harbor-visible-kit-push-image-',
    );
    try {
      onOutput?.call('正在解析镜像包...');
      final plan = await Isolate.run(
        () => ImageArchivePlanner.prepareUploadPlan(
          archivePath: archivePath,
          tempDirPath: tempDir.path,
        ),
      );
      final type = plan['type'] as String;
      if (type == 'oci') {
        final blobs = (plan['blobs'] as List).cast<Map<String, Object?>>();
        for (var i = 0; i < blobs.length; i++) {
          final blob = blobs[i];
          final digest = blob['digest'] as String;
          onOutput?.call('正在上传 OCI blob ${i + 1}/${blobs.length}: $digest');
          await _client.uploadBlobFromFile(
            repository: fullRepository,
            file: File(blob['path'] as String),
            digest: digest,
            onOutput: onOutput,
          );
        }
        await _client.putManifest(
          repository: fullRepository,
          reference: tag,
          bytes: await File(plan['manifestPath'] as String).readAsBytes(),
          mediaType: plan['manifestMediaType'] as String,
        );
        onOutput?.call('OCI 镜像包上传完成: $fullRepository:$tag');
        return;
      }

      final configPath = plan['configPath'] as String;
      final configDigest = plan['configDigest'] as String;
      final configSize = plan['configSize'] as int;
      onOutput?.call('正在上传镜像 config');
      await _client.uploadBlobFromFile(
        repository: fullRepository,
        file: File(configPath),
        digest: configDigest,
        onOutput: onOutput,
      );

      final layerDescriptors = <Map<String, dynamic>>[];
      final layers = (plan['layers'] as List).cast<Map<String, Object?>>();
      for (var i = 0; i < layers.length; i++) {
        final layer = layers[i];
        final digest = layer['digest'] as String;
        onOutput?.call('正在上传 layer ${i + 1}/${layers.length}');
        await _client.uploadBlobFromFile(
          repository: fullRepository,
          file: File(layer['path'] as String),
          digest: digest,
          onOutput: onOutput,
        );
        layerDescriptors.add({
          'mediaType': _dockerLayerGzipMediaType,
          'size': layer['size'] as int,
          'digest': digest,
        });
      }

      final manifestBytes = _jsonBytes({
        'schemaVersion': 2,
        'mediaType': RegistryClient.dockerManifestV2,
        'config': {
          'mediaType': _dockerConfigMediaType,
          'size': configSize,
          'digest': configDigest,
        },
        'layers': layerDescriptors,
      });
      await _client.putManifest(
        repository: fullRepository,
        reference: tag,
        bytes: manifestBytes,
        mediaType: RegistryClient.dockerManifestV2,
      );
      onOutput?.call('镜像包上传完成: $fullRepository:$tag');
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> extractJar({
    required String project,
    required String repository,
    required String tag,
    required String jarFileName,
    required String outputPath,
    void Function(String line)? onOutput,
  }) async {
    await _extractFileArtifact(
      project: project,
      repository: repository,
      tag: tag,
      fileName: jarFileName,
      containerDirectory: 'app',
      artifactLabel: 'JAR 制品',
      tempPrefix: 'harbor-visible-kit-jar-',
      outputPath: outputPath,
      onOutput: onOutput,
    );
  }

  Future<void> extractWebPackage({
    required String project,
    required String repository,
    required String tag,
    required String outputPath,
    void Function(String line)? onOutput,
  }) async {
    await _extractFileArtifact(
      project: project,
      repository: repository,
      tag: tag,
      fileName: 'dist.zip',
      containerDirectory: 'web',
      artifactLabel: 'Web 前端包',
      tempPrefix: 'harbor-visible-kit-web-',
      outputPath: outputPath,
      onOutput: onOutput,
    );
  }

  Future<String> extractApkPackage({
    required String project,
    required String repository,
    required String tag,
    required String outputDirectory,
    required String artifactLabel,
    String? fallbackFileName,
    void Function(String line)? onOutput,
  }) async {
    return _extractFirstFileArtifact(
      project: project,
      repository: repository,
      tag: tag,
      containerDirectory: 'apk',
      extension: 'apk',
      artifactLabel: artifactLabel,
      tempPrefix: 'harbor-visible-kit-apk-',
      outputDirectory: outputDirectory,
      fallbackFileName: fallbackFileName,
      onOutput: onOutput,
    );
  }

  Future<void> _extractFileArtifact({
    required String project,
    required String repository,
    required String tag,
    required String fileName,
    required String containerDirectory,
    required String artifactLabel,
    required String tempPrefix,
    required String outputPath,
    void Function(String line)? onOutput,
  }) async {
    final fullRepository = _client.repositoryPath(project, repository);
    onOutput?.call('正在下载 $artifactLabel 镜像清单: $fullRepository:$tag');
    final manifest = await _singleManifest(fullRepository, tag);
    final layers = (manifest.json['layers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final expectedPath = '$containerDirectory/$fileName';

    final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
    try {
      for (var i = 0; i < layers.length; i++) {
        final layer = layers[i];
        final digest = layer['digest'] as String?;
        if (digest == null) continue;
        onOutput?.call('正在下载 layer ${i + 1}/${layers.length}: $digest');
        final layerPath = '${tempDir.path}${Platform.pathSeparator}layer-$i';
        await _client.downloadBlobToFile(
          repository: fullRepository,
          digest: digest,
          outputPath: layerPath,
        );
        final extracted = await Isolate.run(
          () => TarArchiveUtils.extractFileFromLayerFile(
            layerPath: layerPath,
            mediaType: layer['mediaType'] as String?,
            expectedPath: expectedPath,
            artifactLabel: artifactLabel,
            outputPath: outputPath,
          ),
        );
        if (!extracted) continue;
        onOutput?.call('$artifactLabel 已保存到: $outputPath');
        return;
      }
    } finally {
      await tempDir.delete(recursive: true);
    }

    throw Exception('镜像中未找到 $expectedPath');
  }

  Future<String> _extractFirstFileArtifact({
    required String project,
    required String repository,
    required String tag,
    required String containerDirectory,
    required String extension,
    required String artifactLabel,
    required String tempPrefix,
    required String outputDirectory,
    required String? fallbackFileName,
    void Function(String line)? onOutput,
  }) async {
    final fullRepository = _client.repositoryPath(project, repository);
    onOutput?.call('正在下载 $artifactLabel 镜像清单: $fullRepository:$tag');
    final manifest = await _singleManifest(fullRepository, tag);
    final layers = (manifest.json['layers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final outputFileName =
        await _artifactFileNameFromConfig(
          manifest: manifest,
          repository: fullRepository,
        ) ??
        TarArchiveUtils.safeArchiveOutputFileName(fallbackFileName);

    final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
    try {
      for (var i = 0; i < layers.length; i++) {
        final layer = layers[i];
        final digest = layer['digest'] as String?;
        if (digest == null) continue;
        onOutput?.call('正在下载 layer ${i + 1}/${layers.length}: $digest');
        final layerPath = '${tempDir.path}${Platform.pathSeparator}layer-$i';
        await _client.downloadBlobToFile(
          repository: fullRepository,
          digest: digest,
          outputPath: layerPath,
        );
        final outputPath = await Isolate.run(
          () => TarArchiveUtils.extractFirstFileFromLayerFile(
            layerPath: layerPath,
            mediaType: layer['mediaType'] as String?,
            containerDirectory: containerDirectory,
            extension: extension,
            artifactLabel: artifactLabel,
            outputDirectory: outputDirectory,
            outputFileName: outputFileName,
          ),
        );
        if (outputPath == null) continue;
        onOutput?.call('$artifactLabel 已保存到: $outputPath');
        return outputPath;
      }
    } finally {
      await tempDir.delete(recursive: true);
    }

    throw Exception('镜像中未找到 $containerDirectory/ 下的 .$extension 文件');
  }

  Future<void> exportImageArchive({
    required String project,
    required String repository,
    required String tag,
    required String outputPath,
    void Function(String line)? onOutput,
  }) async {
    final fullRepository = _client.repositoryPath(project, repository);
    onOutput?.call('正在下载镜像清单: $fullRepository:$tag');
    final manifest = await _singleManifest(fullRepository, tag);
    final manifestJson = manifest.json;
    final config = manifestJson['config'] as Map<String, dynamic>?;
    if (config == null || config['digest'] is! String) {
      throw Exception('镜像清单缺少 config 描述');
    }

    final configDigest = config['digest'] as String;
    final configBlob = await _client.getBlob(
      repository: fullRepository,
      digest: configDigest,
    );
    final tempDir = await Directory.systemTemp.createTemp(
      'harbor-visible-kit-image-',
    );
    final layerInputs = <Map<String, Object?>>[];
    final layers = (manifestJson['layers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    try {
      for (var i = 0; i < layers.length; i++) {
        final layer = layers[i];
        final digest = layer['digest'] as String?;
        if (digest == null) {
          throw Exception('镜像清单中存在缺少 digest 的 layer');
        }
        onOutput?.call('正在下载 layer ${i + 1}/${layers.length}: $digest');
        final layerPath = '${tempDir.path}${Platform.pathSeparator}layer-$i';
        await _client.downloadBlobToFile(
          repository: fullRepository,
          digest: digest,
          outputPath: layerPath,
        );
        layerInputs.add({
          'digest': digest,
          'mediaType': layer['mediaType'] as String?,
          'path': layerPath,
        });
      }

      onOutput?.call('正在生成本地镜像归档...');
      await Isolate.run(
        () => TarArchiveUtils.writeDockerSaveArchiveFile(
          configDigest: configDigest,
          configBytes: configBlob.bytes,
          repositoryTag: '$fullRepository:$tag',
          layers: layerInputs,
          outputPath: outputPath,
        ),
      );
      onOutput?.call('镜像归档已保存到: $outputPath');
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  String dockerImageArchiveFileName({
    required String repositoryName,
    required String tag,
  }) {
    return ArtifactArchiveNaming.dockerImageArchiveFileName(
      repositoryName: repositoryName,
      tag: tag,
    );
  }

  Future<RegistryManifest> _singleManifest(
    String repository,
    String tag,
  ) async {
    final manifest = await _client.getManifest(
      repository: repository,
      reference: tag,
    );
    final mediaType =
        manifest.json['mediaType'] as String? ?? manifest.mediaType;
    if (mediaType != _ociImageIndexMediaType &&
        mediaType != _dockerManifestListMediaType) {
      return manifest;
    }

    final manifests = (manifest.json['manifests'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final selected = _selectOciManifest(manifests);
    final digest = selected['digest'] as String?;
    if (digest == null) {
      throw Exception('多架构镜像清单缺少 digest');
    }
    return _client.getManifest(repository: repository, reference: digest);
  }

  Map<String, dynamic> _selectOciManifest(
    List<Map<String, dynamic>> manifests,
  ) {
    if (manifests.isEmpty) {
      throw Exception('多架构镜像清单为空');
    }
    return manifests.firstWhere((manifest) {
      final platform = manifest['platform'] as Map<String, dynamic>?;
      return platform?['os'] == 'linux' && platform?['architecture'] == 'amd64';
    }, orElse: () => manifests.first);
  }

  Uint8List _jsonBytes(Object value) {
    return Uint8List.fromList(utf8.encode(jsonEncode(value)));
  }

  Future<String?> _artifactFileNameFromConfig({
    required RegistryManifest manifest,
    required String repository,
  }) async {
    final config = manifest.json['config'] as Map<String, dynamic>?;
    final digest = config?['digest'] as String?;
    if (digest == null) return null;

    final blob = await _client.getBlob(repository: repository, digest: digest);
    final configJson =
        jsonDecode(utf8.decode(blob.bytes)) as Map<String, dynamic>;
    final configData = configJson['config'] as Map<String, dynamic>?;
    final labels = configData?['Labels'] as Map<String, dynamic>?;
    final fileName = labels?[_artifactFileNameLabel] as String?;
    if (fileName == null || fileName.trim().isEmpty) return null;
    return TarArchiveUtils.safeArchiveOutputFileName(fileName);
  }
}

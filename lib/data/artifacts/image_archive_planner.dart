import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:harbor_visible_kit/data/harbor/registry_client.dart';
import 'package:harbor_visible_kit/data/artifacts/tar_archive_utils.dart';

class ImageArchivePlanner {
  const ImageArchivePlanner._();

  static Future<Map<String, Object?>> prepareUploadPlan({
    required String archivePath,
    required String tempDirPath,
  }) async {
    final archiveBytes = await _readMaybeGzipArchiveFile(archivePath);
    final archive = TarArchiveUtils.readTarArchiveBytes(archiveBytes);
    if (TarArchiveUtils.findArchiveFileByName(archive, 'oci-layout') != null) {
      return _prepareOciUploadPlan(archive, tempDirPath);
    }
    return _prepareDockerSaveUploadPlan(archive, tempDirPath);
  }

  static Future<Map<String, Object?>> _prepareDockerSaveUploadPlan(
    Archive archive,
    String tempDirPath,
  ) async {
    final manifestEntry = TarArchiveUtils.findArchiveFileByName(
      archive,
      'manifest.json',
    );
    if (manifestEntry == null) {
      throw Exception('不是有效的 Docker save 包: 缺少 manifest.json');
    }
    final manifestList =
        jsonDecode(utf8.decode(manifestEntry.readBytes()!)) as List;
    if (manifestList.isEmpty) {
      throw Exception('Docker save 包 manifest.json 为空');
    }
    final source = manifestList.first as Map<String, dynamic>;
    final configPath = source['Config'] as String?;
    if (configPath == null) {
      throw Exception('Docker save 包缺少 Config');
    }
    final configEntry = TarArchiveUtils.findArchiveFileByName(
      archive,
      configPath,
    );
    if (configEntry == null) {
      throw Exception('Docker save 包缺少 config 文件: $configPath');
    }
    final configFile = File('$tempDirPath${Platform.pathSeparator}config.json');
    configFile.writeAsBytesSync(configEntry.readBytes()!);

    final layers = (source['Layers'] as List? ?? []).cast<String>();
    if (layers.isEmpty) {
      throw Exception('Docker save 包缺少 layer');
    }
    final layerPlans = <Map<String, Object?>>[];
    for (var i = 0; i < layers.length; i++) {
      final layerPath = layers[i];
      final layerEntry = TarArchiveUtils.findArchiveFileByName(
        archive,
        layerPath,
      );
      if (layerEntry == null) {
        throw Exception('Docker save 包缺少 layer: $layerPath');
      }
      final rawFile = File('$tempDirPath${Platform.pathSeparator}layer-$i.tar');
      rawFile.writeAsBytesSync(layerEntry.readBytes()!);
      final compressedFile = File(
        '$tempDirPath${Platform.pathSeparator}layer-$i.tar.gz',
      );
      await rawFile
          .openRead()
          .transform(GZipCodec(level: 1).encoder)
          .pipe(compressedFile.openWrite());
      layerPlans.add({
        'path': compressedFile.path,
        'digest': await RegistryClient.digestForFile(compressedFile),
        'size': await compressedFile.length(),
      });
    }

    return {
      'type': 'docker',
      'configPath': configFile.path,
      'configDigest': await RegistryClient.digestForFile(configFile),
      'configSize': await configFile.length(),
      'layers': layerPlans,
    };
  }

  static Future<Map<String, Object?>> _prepareOciUploadPlan(
    Archive archive,
    String tempDirPath,
  ) async {
    final indexEntry = TarArchiveUtils.findArchiveFileByName(
      archive,
      'index.json',
    );
    if (indexEntry == null) {
      throw Exception('不是有效的 OCI archive: 缺少 index.json');
    }
    final indexJson =
        jsonDecode(utf8.decode(indexEntry.readBytes()!))
            as Map<String, dynamic>;
    final manifests = (indexJson['manifests'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (manifests.isEmpty) {
      throw Exception('OCI archive 缺少 manifest 描述');
    }
    final selected = _selectManifestDescriptor(manifests);
    final manifestDigest = selected['digest'] as String?;
    if (manifestDigest == null) {
      throw Exception('OCI archive manifest 缺少 digest');
    }
    final manifestEntry = _blobByDigestValue(archive, manifestDigest);
    if (manifestEntry == null) {
      throw Exception('OCI archive 缺少 manifest blob: $manifestDigest');
    }
    final manifestFile = File(
      '$tempDirPath${Platform.pathSeparator}manifest.json',
    );
    manifestFile.writeAsBytesSync(manifestEntry.readBytes()!);
    final manifestJson =
        jsonDecode(utf8.decode(manifestFile.readAsBytesSync()))
            as Map<String, dynamic>;
    final descriptors = <Map<String, dynamic>>[
      if (manifestJson['config'] is Map<String, dynamic>)
        manifestJson['config'] as Map<String, dynamic>,
      ...(manifestJson['layers'] as List? ?? []).cast<Map<String, dynamic>>(),
    ];

    final blobs = <Map<String, Object?>>[];
    for (var i = 0; i < descriptors.length; i++) {
      final descriptor = descriptors[i];
      final digest = descriptor['digest'] as String?;
      if (digest == null) {
        throw Exception('OCI archive 描述中存在缺少 digest 的 blob');
      }
      final blob = _blobByDigestValue(archive, digest);
      if (blob == null) {
        throw Exception('OCI archive 缺少 blob: $digest');
      }
      final blobFile = File('$tempDirPath${Platform.pathSeparator}oci-blob-$i');
      blobFile.writeAsBytesSync(blob.readBytes()!);
      blobs.add({'path': blobFile.path, 'digest': digest});
    }

    return {
      'type': 'oci',
      'manifestPath': manifestFile.path,
      'manifestMediaType':
          manifestJson['mediaType'] as String? ??
          selected['mediaType'] as String? ??
          RegistryClient.ociManifestV1,
      'blobs': blobs,
    };
  }

  static Future<Uint8List> _readMaybeGzipArchiveFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final lower = path.toLowerCase();
    if (lower.endsWith('.gz') || lower.endsWith('.tgz')) {
      return GZipDecoder().decodeBytes(bytes);
    }
    return bytes;
  }

  static Map<String, dynamic> _selectManifestDescriptor(
    List<Map<String, dynamic>> manifests,
  ) {
    return manifests.firstWhere((manifest) {
      final platform = manifest['platform'] as Map<String, dynamic>?;
      return platform?['os'] == 'linux' && platform?['architecture'] == 'amd64';
    }, orElse: () => manifests.first);
  }

  static ArchiveFile? _blobByDigestValue(Archive archive, String digest) {
    final hex = TarArchiveUtils.hexDigestValue(digest);
    return TarArchiveUtils.findArchiveFileByName(archive, 'blobs/sha256/$hex');
  }
}

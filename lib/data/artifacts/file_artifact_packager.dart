import 'dart:io';
import 'dart:typed_data';

import 'package:harbor_visible_kit/data/harbor/registry_client.dart';
import 'package:harbor_visible_kit/data/artifacts/tar_archive_utils.dart';

class FileArtifactPackager {
  const FileArtifactPackager._();

  static Future<Map<String, Object>> prepareLayerFile({
    required String sourcePath,
    required String fileName,
    required String containerDirectory,
    required String tempDirPath,
  }) async {
    final rootfsTarFile = File(
      '$tempDirPath${Platform.pathSeparator}rootfs.tar',
    );
    final layerFile = File('$tempDirPath${Platform.pathSeparator}layer.tar.gz');
    final sourceFile = File(sourcePath);
    final sourceSize = await sourceFile.length();
    final normalizedDirectory = TarArchiveUtils.normalizeArchivePathValue(
      containerDirectory,
    ).replaceAll(RegExp(r'/+$'), '');

    final sink = rootfsTarFile.openWrite();
    try {
      sink.add(
        TarArchiveUtils.buildTarHeader(
          '$normalizedDirectory/',
          size: 0,
          typeFlag: 0x35,
        ),
      );
      sink.add(
        TarArchiveUtils.buildTarHeader(
          '$normalizedDirectory/$fileName',
          size: sourceSize,
          typeFlag: 0x30,
        ),
      );
      await for (final chunk in sourceFile.openRead()) {
        sink.add(chunk);
      }
      TarArchiveUtils.writeTarPadding(sink, sourceSize);
      sink.add(Uint8List(1024));
    } finally {
      await sink.close();
    }

    await rootfsTarFile
        .openRead()
        .transform(GZipCodec(level: 1).encoder)
        .pipe(layerFile.openWrite());

    return {
      'path': layerFile.path,
      'digest': await RegistryClient.digestForFile(layerFile),
      'diffId': await RegistryClient.digestForFile(rootfsTarFile),
      'size': await layerFile.length(),
    };
  }
}

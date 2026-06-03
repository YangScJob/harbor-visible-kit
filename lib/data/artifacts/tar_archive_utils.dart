import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class TarArchiveUtils {
  const TarArchiveUtils._();

  static bool extractFileFromLayerFile({
    required String layerPath,
    required String? mediaType,
    required String expectedPath,
    required String artifactLabel,
    required String outputPath,
  }) {
    final layerBytes = File(layerPath).readAsBytesSync();
    final tarBytes = maybeGunzipBytes(layerBytes, mediaType);
    final tar = readTarArchiveBytes(tarBytes);
    final jarEntry = findArchiveFileByName(tar, expectedPath);
    if (jarEntry == null) return false;
    final bytes = jarEntry.readBytes();
    if (bytes == null) {
      throw Exception('$artifactLabel 文件内容为空: $expectedPath');
    }
    File(outputPath).writeAsBytesSync(bytes);
    return true;
  }

  static String? extractFirstFileFromLayerFile({
    required String layerPath,
    required String? mediaType,
    required String containerDirectory,
    required String extension,
    required String artifactLabel,
    required String outputDirectory,
    required String? outputFileName,
  }) {
    final layerBytes = File(layerPath).readAsBytesSync();
    final tarBytes = maybeGunzipBytes(layerBytes, mediaType);
    final tar = readTarArchiveBytes(tarBytes);
    final normalizedDirectory = normalizeArchivePathValue(
      containerDirectory,
    ).replaceAll(RegExp(r'/+$'), '');
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');

    for (final entry in tar.files) {
      final normalizedName = normalizeArchivePathValue(entry.name);
      final lowerName = normalizedName.toLowerCase();
      if (!normalizedName.startsWith('$normalizedDirectory/')) continue;
      if (!lowerName.endsWith('.$normalizedExtension')) continue;
      final bytes = entry.readBytes();
      if (bytes == null) {
        throw Exception('$artifactLabel 文件内容为空: $normalizedName');
      }
      final fileName = outputFileName ?? normalizedName.split('/').last;
      final outputPath = [
        outputDirectory,
        fileName,
      ].where((part) => part.isNotEmpty).join(Platform.pathSeparator);
      final outputFile = File(outputPath);
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsBytesSync(bytes);
      return outputPath;
    }

    return null;
  }

  static Future<void> writeDockerSaveArchiveFile({
    required String configDigest,
    required Uint8List configBytes,
    required String repositoryTag,
    required List<Map<String, Object?>> layers,
    required String outputPath,
  }) async {
    final configFileName = '${hexDigestValue(configDigest)}.json';
    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    final layerEntries = <String>[];

    final fileSink = outputFile.openWrite();
    final gzipSink = GZipCodec(
      level: 1,
    ).encoder.startChunkedConversion(fileSink);
    try {
      writeTarBytesEntry(gzipSink, configFileName, configBytes);

      for (final layer in layers) {
        final digest = layer['digest'] as String;
        final layerDir = hexDigestValue(digest);
        final layerPath = '$layerDir/layer.tar';
        layerEntries.add(layerPath);

        writeTarDirectoryEntry(gzipSink, '$layerDir/');
        final layerTarFile = await materializeLayerTar(layer);
        await writeTarFileEntry(gzipSink, layerPath, layerTarFile);
      }

      writeTarBytesEntry(
        gzipSink,
        'manifest.json',
        utf8.encode(
          jsonEncode([
            {
              'Config': configFileName,
              'RepoTags': [repositoryTag],
              'Layers': layerEntries,
            },
          ]),
        ),
      );

      final repositoryParts = repositoryTag.split(':');
      final tag = repositoryParts.length > 1
          ? repositoryParts.removeLast()
          : '';
      final repository = repositoryParts.join(':');
      writeTarBytesEntry(
        gzipSink,
        'repositories',
        utf8.encode(
          jsonEncode({
            repository: {tag: layerEntries.isEmpty ? '' : layerEntries.last},
          }),
        ),
      );

      gzipSink.add(Uint8List(1024));
    } finally {
      gzipSink.close();
    }
    await fileSink.done;
  }

  static Future<File> materializeLayerTar(Map<String, Object?> layer) async {
    final mediaType = layer['mediaType'] as String?;
    final path = layer['path'] as String;
    final type = mediaType ?? '';
    if (type.contains('zstd')) {
      throw Exception('暂不支持 zstd 压缩 layer');
    }

    final sourceFile = File(path);
    final isGzip =
        type.contains('+gzip') ||
        type.endsWith('.gzip') ||
        fileLooksGzip(sourceFile);
    if (!isGzip) return sourceFile;

    final decodedFile = File('$path.decoded.tar');
    await sourceFile
        .openRead()
        .transform(gzip.decoder)
        .pipe(decodedFile.openWrite());
    return decodedFile;
  }

  static Future<void> writeTarFileEntry(
    Sink<List<int>> sink,
    String name,
    File file,
  ) async {
    final size = await file.length();
    sink.add(buildTarHeader(name, size: size, typeFlag: 0x30));
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    writeTarPadding(sink, size);
  }

  static void writeTarBytesEntry(
    Sink<List<int>> sink,
    String name,
    List<int> bytes,
  ) {
    sink.add(buildTarHeader(name, size: bytes.length, typeFlag: 0x30));
    sink.add(bytes);
    writeTarPadding(sink, bytes.length);
  }

  static void writeTarDirectoryEntry(Sink<List<int>> sink, String name) {
    sink.add(buildTarHeader(name, size: 0, typeFlag: 0x35));
  }

  static Uint8List buildTarHeader(
    String name, {
    required int size,
    required int typeFlag,
  }) {
    final header = Uint8List(512);
    _writeTarString(header, 0, 100, name);
    _writeTarOctal(header, 100, 8, typeFlag == 0x35 ? 0x1ed : 0x1a4);
    _writeTarOctal(header, 108, 8, 0);
    _writeTarOctal(header, 116, 8, 0);
    _writeTarOctal(header, 124, 12, size);
    _writeTarOctal(
      header,
      136,
      12,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    for (var i = 148; i < 156; i++) {
      header[i] = 0x20;
    }
    header[156] = typeFlag;
    _writeTarString(header, 257, 6, 'ustar');
    _writeTarString(header, 263, 2, '00');

    var checksum = 0;
    for (final byte in header) {
      checksum += byte;
    }
    final checksumText = checksum.toRadixString(8).padLeft(6, '0');
    _writeTarString(header, 148, 6, checksumText);
    header[154] = 0;
    header[155] = 0x20;
    return header;
  }

  static void writeTarPadding(Sink<List<int>> sink, int size) {
    final remainder = size % 512;
    if (remainder != 0) {
      sink.add(Uint8List(512 - remainder));
    }
  }

  static bool fileLooksGzip(File file) {
    final raf = file.openSync();
    try {
      if (raf.lengthSync() < 2) return false;
      final bytes = raf.readSync(2);
      return bytes[0] == 0x1f && bytes[1] == 0x8b;
    } finally {
      raf.closeSync();
    }
  }

  static Archive readTarArchiveBytes(List<int> bytes) {
    try {
      return TarDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('读取 tar 归档失败: $e');
    }
  }

  static ArchiveFile? findArchiveFileByName(Archive archive, String name) {
    final normalized = normalizeArchivePathValue(name);
    for (final file in archive.files) {
      if (normalizeArchivePathValue(file.name) == normalized) return file;
    }
    return null;
  }

  static Uint8List maybeGunzipBytes(Uint8List bytes, String? mediaType) {
    final type = mediaType ?? '';
    if (type.contains('+gzip') ||
        type.endsWith('.gzip') ||
        _looksGzipBytes(bytes)) {
      return GZipDecoder().decodeBytes(bytes);
    }
    if (type.contains('zstd')) {
      throw Exception('暂不支持 zstd 压缩 layer');
    }
    return bytes;
  }

  static String normalizeArchivePathValue(String path) {
    return path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  }

  static String? safeArchiveOutputFileName(String? fileName) {
    if (fileName == null) return null;
    final normalized = normalizeArchivePathValue(fileName);
    final leafName = normalized.split('/').last.trim();
    if (leafName.isEmpty) return null;
    return leafName;
  }

  static String hexDigestValue(String digest) {
    return digest.contains(':') ? digest.split(':').last : digest;
  }

  static bool _looksGzipBytes(Uint8List bytes) {
    return bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  }

  static void _writeTarString(
    Uint8List buffer,
    int offset,
    int length,
    String value,
  ) {
    final bytes = ascii.encode(value);
    final count = bytes.length > length ? length : bytes.length;
    buffer.setRange(offset, offset + count, bytes);
  }

  static void _writeTarOctal(
    Uint8List buffer,
    int offset,
    int length,
    int value,
  ) {
    final text = value.toRadixString(8).padLeft(length - 1, '0');
    _writeTarString(buffer, offset, length - 1, text);
    buffer[offset + length - 1] = 0;
  }
}

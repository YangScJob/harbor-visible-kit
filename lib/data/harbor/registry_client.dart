import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';

class RegistryBlob {
  final Uint8List bytes;
  final String mediaType;

  const RegistryBlob({required this.bytes, required this.mediaType});
}

class RegistryManifest {
  final Uint8List bytes;
  final Map<String, dynamic> json;
  final String mediaType;

  const RegistryManifest({
    required this.bytes,
    required this.json,
    required this.mediaType,
  });
}

class RegistryClient {
  static const dockerManifestV2 =
      'application/vnd.docker.distribution.manifest.v2+json';
  static const ociManifestV1 = 'application/vnd.oci.image.manifest.v1+json';

  final HarborConnection connection;
  late final Dio _dio;
  late final Uri _baseUri;

  RegistryClient(this.connection) {
    _baseUri = Uri.parse(connection.baseUrl);
    _dio = Dio(
      BaseOptions(
        baseUrl: connection.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 10),
        validateStatus: (_) => true,
      ),
    );
  }

  String repositoryPath(String project, String repository) {
    return '$project/$repository';
  }

  Future<RegistryManifest> getManifest({
    required String repository,
    required String reference,
    String actions = 'pull',
  }) async {
    final response = await _request(
      'GET',
      '/v2/${_encodeRepository(repository)}/manifests/${Uri.encodeComponent(reference)}',
      repository: repository,
      actions: actions,
      headers: {
        'Accept': [
          dockerManifestV2,
          ociManifestV1,
          'application/vnd.docker.distribution.manifest.list.v2+json',
          'application/vnd.oci.image.index.v1+json',
        ].join(', '),
      },
      responseType: ResponseType.bytes,
    );
    _ensureSuccess(response, '获取镜像清单失败');
    final bytes = Uint8List.fromList(List<int>.from(response.data as List));
    final mediaType =
        response.headers.value('content-type')?.split(';').first.trim() ??
        dockerManifestV2;
    return RegistryManifest(
      bytes: bytes,
      json: jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      mediaType: mediaType,
    );
  }

  Future<RegistryBlob> getBlob({
    required String repository,
    required String digest,
  }) async {
    final response = await _request(
      'GET',
      '/v2/${_encodeRepository(repository)}/blobs/$digest',
      repository: repository,
      actions: 'pull',
      responseType: ResponseType.bytes,
    );
    _ensureSuccess(response, '下载镜像数据失败');
    return RegistryBlob(
      bytes: Uint8List.fromList(List<int>.from(response.data as List)),
      mediaType: response.headers.value('content-type') ?? '',
    );
  }

  Future<void> downloadBlobToFile({
    required String repository,
    required String digest,
    required String outputPath,
    void Function(int received)? onProgress,
  }) async {
    final response = await _request(
      'GET',
      '/v2/${_encodeRepository(repository)}/blobs/$digest',
      repository: repository,
      actions: 'pull',
      responseType: ResponseType.stream,
    );
    _ensureSuccess(response, '下载镜像数据失败');
    final body = response.data as ResponseBody;
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in body.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received);
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> uploadBlob({
    required String repository,
    required Uint8List bytes,
    required String digest,
    void Function(String line)? onOutput,
  }) async {
    final start = await _request(
      'POST',
      '/v2/${_encodeRepository(repository)}/blobs/uploads/',
      repository: repository,
      actions: 'pull,push',
    );
    _ensureSuccess(start, '创建上传会话失败', accepted: {202});
    final location = start.headers.value('location');
    if (location == null || location.isEmpty) {
      throw Exception('创建上传会话失败: Harbor 未返回 Location');
    }

    final uploadUri = _resolveLocation(location);
    final separator = uploadUri.hasQuery ? '&' : '?';
    final completeUrl = '$uploadUri${separator}digest=$digest';
    final result = await _requestAbsolute(
      'PUT',
      completeUrl,
      repository: repository,
      actions: 'pull,push',
      data: bytes,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    _ensureSuccess(result, '上传镜像数据失败', accepted: {201, 202});
    onOutput?.call('已上传 blob $digest (${bytes.length} bytes)');
  }

  Future<void> uploadBlobFromFile({
    required String repository,
    required File file,
    required String digest,
    void Function(String line)? onOutput,
  }) async {
    final start = await _request(
      'POST',
      '/v2/${_encodeRepository(repository)}/blobs/uploads/',
      repository: repository,
      actions: 'pull,push',
    );
    _ensureSuccess(start, '创建上传会话失败', accepted: {202});
    final location = start.headers.value('location');
    if (location == null || location.isEmpty) {
      throw Exception('创建上传会话失败: Harbor 未返回 Location');
    }

    final uploadUri = _resolveLocation(location);
    final separator = uploadUri.hasQuery ? '&' : '?';
    final completeUrl = '$uploadUri${separator}digest=$digest';
    final length = await file.length();

    Future<Response<dynamic>> send(String authHeader) {
      return _dio.requestUri<dynamic>(
        Uri.parse(completeUrl),
        data: file.openRead(),
        options: Options(
          method: 'PUT',
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/octet-stream',
            'Content-Length': length,
          },
        ),
      );
    }

    var result = await send(_basicAuthHeader());
    if (result.statusCode == 401) {
      final token = await _tokenFromChallenge(
        result.headers.value('www-authenticate'),
        repository: repository,
        actions: 'pull,push',
      );
      if (token != null) {
        result = await send('Bearer $token');
      }
    }

    _ensureSuccess(result, '上传镜像数据失败', accepted: {201, 202});
    onOutput?.call('已上传 blob $digest ($length bytes)');
  }

  Future<void> putManifest({
    required String repository,
    required String reference,
    required Uint8List bytes,
    required String mediaType,
  }) async {
    final response = await _request(
      'PUT',
      '/v2/${_encodeRepository(repository)}/manifests/${Uri.encodeComponent(reference)}',
      repository: repository,
      actions: 'pull,push',
      data: bytes,
      headers: {'Content-Type': mediaType},
    );
    _ensureSuccess(response, '上传镜像清单失败', accepted: {200, 201, 202});
  }

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    required String repository,
    required String actions,
    Object? data,
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) {
    final uri = _baseUri.resolve(path).toString();
    return _requestAbsolute(
      method,
      uri,
      repository: repository,
      actions: actions,
      data: data,
      headers: headers,
      responseType: responseType,
    );
  }

  Future<Response<dynamic>> _requestAbsolute(
    String method,
    String url, {
    required String repository,
    required String actions,
    Object? data,
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    final mergedHeaders = <String, dynamic>{
      ...?headers,
      'Authorization': _basicAuthHeader(),
    };
    var response = await _dio.requestUri<dynamic>(
      Uri.parse(url),
      data: data,
      options: Options(
        method: method,
        headers: mergedHeaders,
        responseType: responseType,
      ),
    );
    if (response.statusCode != 401) return response;

    final challenge = response.headers.value('www-authenticate');
    final token = await _tokenFromChallenge(
      challenge,
      repository: repository,
      actions: actions,
    );
    if (token == null) return response;

    response = await _dio.requestUri<dynamic>(
      Uri.parse(url),
      data: data,
      options: Options(
        method: method,
        headers: {...?headers, 'Authorization': 'Bearer $token'},
        responseType: responseType,
      ),
    );
    return response;
  }

  Future<String?> _tokenFromChallenge(
    String? header, {
    required String repository,
    required String actions,
  }) async {
    if (header == null || !header.toLowerCase().startsWith('bearer ')) {
      return null;
    }
    final params = parseAuthChallenge(header);
    final realm = params['realm'];
    if (realm == null || realm.isEmpty) return null;
    final tokenUri = Uri.parse(realm).replace(
      queryParameters: {
        if (params['service'] != null) 'service': params['service']!,
        'scope': 'repository:$repository:$actions',
      },
    );
    final response = await _dio.getUri<dynamic>(
      tokenUri,
      options: Options(headers: {'Authorization': _basicAuthHeader()}),
    );
    _ensureSuccess(response, '获取 Registry 访问令牌失败');
    final data = response.data as Map<String, dynamic>;
    return data['token'] as String? ?? data['access_token'] as String?;
  }

  static Map<String, String> parseAuthChallenge(String header) {
    final value = header.replaceFirst(RegExp(r'^\s*Bearer\s+'), '');
    final result = <String, String>{};
    final pattern = RegExp(r'(\w+)="([^"]*)"|(\w+)=([^,]+)');
    for (final match in pattern.allMatches(value)) {
      final key = match.group(1) ?? match.group(3);
      final val = match.group(2) ?? match.group(4);
      if (key != null && val != null) {
        result[key] = val.trim();
      }
    }
    return result;
  }

  static String digestForBytes(List<int> bytes) {
    return 'sha256:${sha256.convert(bytes)}';
  }

  static Future<String> digestForFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return 'sha256:$digest';
  }

  String _basicAuthHeader() {
    final raw = '${connection.username}:${connection.password}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  String _encodeRepository(String repository) {
    return repository.split('/').map(Uri.encodeComponent).join('/');
  }

  Uri _resolveLocation(String location) {
    final uri = Uri.parse(location);
    if (uri.hasScheme) return uri;
    return _baseUri.resolve(location);
  }

  void _ensureSuccess(
    Response<dynamic> response,
    String message, {
    Set<int> accepted = const {200},
  }) {
    final status = response.statusCode ?? -1;
    if (accepted.contains(status)) return;
    final detail = response.data is List<int>
        ? utf8.decode(
            List<int>.from(response.data as List),
            allowMalformed: true,
          )
        : response.data?.toString();
    throw Exception(
      '$message: HTTP $status${detail == null ? '' : ' $detail'}',
    );
  }
}

import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_project.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_repository.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_artifact.dart';

/// Harbor v2.0 REST API wrapper service.
class HarborApiService {
  Dio? _dio;
  HarborConnection? _connection;

  /// Whether a valid connection has been configured.
  bool get isConfigured => _connection != null && _connection!.isValid;

  /// Initializes the Dio instance with the connection configuration.
  void configure(HarborConnection connection) {
    _connection = connection;
    _dio = Dio(
      BaseOptions(
        baseUrl: '${connection.baseUrl}/api/v2.0',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${connection.username}:${connection.password}'))}',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Disconnects and clears the current client.
  void disconnect() {
    _dio?.close();
    _dio = null;
    _connection = null;
  }

  /// Verifies Harbor connectivity.
  ///
  /// Calls the /systeminfo endpoint and returns the Harbor version on success.
  Future<String> ping() async {
    _ensureConfigured();
    try {
      final response = await _dio!.get('/systeminfo');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['harbor_version'] as String? ?? 'connected';
      }
      throw Exception('Unexpected status: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('连接超时，请检查 IP 和端口是否正确');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('认证失败，请检查用户名和密码');
      }
      throw Exception('连接失败: ${e.message}');
    }
  }

  /// Validates the current username and password.
  ///
  /// /systeminfo only proves that Harbor is reachable.
  /// /users/current requires Basic Auth; 401 and 403 are treated as auth failures.
  Future<String> authenticate() async {
    _ensureConfigured();
    try {
      final response = await _dio!.get('/users/current');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['username'] as String? ?? _connection!.username;
      }
      throw Exception('Unexpected status: ${response.statusCode}');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw Exception('认证失败，请检查用户名和密码');
      }
      throw Exception('认证失败: ${e.message}');
    }
  }

  /// Lists all Harbor projects.
  Future<List<HarborProject>> listProjects() async {
    _ensureConfigured();
    try {
      final response = await _dio!.get(
        '/projects',
        queryParameters: {'page_size': 100},
      );
      final list = response.data as List;
      return list
          .map((e) => HarborProject.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('获取项目列表失败: ${e.message}');
    }
  }

  /// Creates a Harbor project.
  Future<void> createProject(String projectName, {bool isPublic = true}) async {
    _ensureConfigured();
    try {
      await _dio!.post(
        '/projects',
        data: {
          'project_name': projectName,
          'metadata': {'public': isPublic.toString()},
        },
      );
    } on DioException catch (e) {
      final detail = e.response?.data?['errors']?[0]?['message'] ?? e.message;
      throw Exception('创建项目空间失败: $detail');
    }
  }

  /// Lists repositories in a Harbor project.
  Future<List<HarborRepository>> listRepositories(String projectName) async {
    _ensureConfigured();
    try {
      final response = await _dio!.get(
        '/projects/$projectName/repositories',
        queryParameters: {'page_size': 100},
      );
      final list = response.data as List;
      return list
          .map((e) => HarborRepository.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('获取仓库列表失败: ${e.message}');
    }
  }

  /// Lists artifacts and tags in a repository.
  Future<List<HarborArtifact>> listArtifacts(
    String projectName,
    String repositoryName,
  ) async {
    _ensureConfigured();
    try {
      // Repository names may contain '/', so they must be URL encoded.
      final encodedRepo = Uri.encodeComponent(repositoryName);
      final response = await _dio!.get(
        '/projects/$projectName/repositories/$encodedRepo/artifacts',
        queryParameters: {'page_size': 100, 'with_tag': true},
      );
      final list = response.data as List;
      return list
          .map((e) => HarborArtifact.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('获取制品列表失败: ${e.message}');
    }
  }

  /// Aggregates existing artifact tags for push-page version suggestions.
  Future<List<String>> listTagsForProject(
    String projectName, {
    Iterable<String> repositoryNames = const [],
  }) async {
    _ensureConfigured();

    final normalizedRepositories = repositoryNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    final repositories = normalizedRepositories.isNotEmpty
        ? normalizedRepositories
        : (await listRepositories(
            projectName,
          )).map((repository) => repository.shortName).toList();

    final tagPushTimes = <String, String>{};
    for (final repositoryName in repositories) {
      try {
        final encodedRepo = Uri.encodeComponent(repositoryName);
        final response = await _dio!.get(
          '/projects/$projectName/repositories/$encodedRepo/artifacts',
          queryParameters: {'page_size': 100, 'with_tag': true},
        );
        final list = response.data as List;
        final artifacts = list
            .map((e) => HarborArtifact.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final artifact in artifacts) {
          for (final tag in artifact.tags) {
            final trimmedTag = tag.trim();
            if (trimmedTag.isEmpty) continue;
            final currentPushTime = tagPushTimes[trimmedTag];
            if (currentPushTime == null ||
                artifact.pushTime.compareTo(currentPushTime) > 0) {
              tagPushTimes[trimmedTag] = artifact.pushTime;
            }
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) continue;
        throw Exception('获取版本标签失败: ${e.message}');
      }
    }

    return tagPushTimes.keys.toList()..sort((a, b) {
      final timeCompare = (tagPushTimes[b] ?? '').compareTo(
        tagPushTimes[a] ?? '',
      );
      if (timeCompare != 0) return timeCompare;
      return b.compareTo(a);
    });
  }

  void _ensureConfigured() {
    if (_dio == null || _connection == null) {
      throw Exception('Harbor API 未配置，请先设置连接信息');
    }
  }
}

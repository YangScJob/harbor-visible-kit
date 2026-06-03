import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_server.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';

/// Persistent connection storage and global connection state.
///
/// Stores servers, usernames, and optional passwords with shared_preferences.
/// Also broadcasts connection state changes to the UI as a ChangeNotifier.
class ConnectionStore extends ChangeNotifier {
  static const _keyLegacyConfig = 'harbor_connection';
  static const _keyLegacyConnections = 'harbor_connections';
  static const _keyLegacySelectedId = 'harbor_connection_selected_id';

  static const _keyServers = 'harbor_servers';
  static const _keySelectedServerId = 'harbor_selected_server_id';
  static const _keyUsernames = 'harbor_usernames';
  static const _keySelectedUsername = 'harbor_selected_username';
  static const _keyRememberPassword = 'harbor_remember_password';
  static const _keySavedPasswords = 'harbor_saved_passwords';

  final HarborApiService _apiService;

  ConnectionStore(this._apiService);

  List<HarborServer> _servers = [];
  List<String> _usernames = [];
  Map<String, String> _savedPasswords = {};
  String? _selectedServerId;
  String _selectedUsername = 'admin';
  bool _rememberPassword = false;
  HarborConnection _connection = HarborConnection.empty();
  bool _isConnected = false;
  String _harborVersion = '';

  List<HarborServer> get servers => List.unmodifiable(_servers);
  List<String> get usernames => List.unmodifiable(_usernames);
  String? get selectedServerId => _selectedServerId;
  String get selectedUsername => _selectedUsername;
  bool get rememberPassword => _rememberPassword;

  // Compatibility with the previous multi-connection API.
  List<HarborConnection> get connections => _servers
      .map(
        (server) => HarborConnection(
          host: server.host,
          port: server.port,
          username: _selectedUsername,
          password: _passwordFor(server, _selectedUsername),
        ),
      )
      .toList(growable: false);
  String? get selectedId => _selectedServerId;

  HarborConnection get connection => _connection;
  bool get isConnected => _isConnected;
  String get harborVersion => _harborVersion;

  /// Loads saved connection settings from local storage.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRememberSetting = prefs.containsKey(_keyRememberPassword);

    _selectedServerId = null;
    _servers = _loadServers(prefs);
    _usernames = _loadUsernames(prefs);
    _savedPasswords = _loadSavedPasswords(prefs);
    _rememberPassword = prefs.getBool(_keyRememberPassword) ?? false;

    final legacyConnections = _loadLegacyConnections(prefs);
    if (_servers.isEmpty && legacyConnections.isNotEmpty) {
      _migrateLegacyConnections(
        legacyConnections,
        prefs.getString(_keyLegacySelectedId),
      );
      await _saveToPrefs(prefs);
      await prefs.remove(_keyLegacyConnections);
      await prefs.remove(_keyLegacySelectedId);
    }

    if (_servers.isEmpty) {
      final migrated = _loadLegacyConnection(prefs);
      if (migrated != null) {
        _migrateLegacyConnections([migrated], migrated.id);
        await _saveToPrefs(prefs);
        await prefs.remove(_keyLegacyConfig);
      }
    }

    if (!hasRememberSetting && _savedPasswords.isNotEmpty) {
      _rememberPassword = true;
      await prefs.setBool(_keyRememberPassword, true);
    }

    _selectedServerId ??= prefs.getString(_keySelectedServerId);
    if (_selectedServerId == null ||
        !_servers.any((server) => server.id == _selectedServerId)) {
      _selectedServerId = _servers.isEmpty ? null : _servers.first.id;
    }

    final savedUsername = prefs.getString(_keySelectedUsername);
    if (savedUsername != null && savedUsername.trim().isNotEmpty) {
      _selectedUsername = savedUsername.trim();
    } else if (_usernames.isNotEmpty) {
      _selectedUsername = _usernames.first;
    }

    _connection = _connectionForCurrentSelection();
    notifyListeners();

    // Initialize the API client and try to connect asynchronously.
    if (_connection.isValid) {
      _apiService.configure(_connection);
      _autoConnect();
    }
  }

  List<HarborServer> _loadServers(SharedPreferences prefs) {
    final jsonList = prefs.getStringList(_keyServers);
    if (jsonList == null || jsonList.isEmpty) return [];

    try {
      return _dedupeServers(
        jsonList
            .map((item) {
              final map = jsonDecode(item) as Map<String, dynamic>;
              return HarborServer.fromJson(map);
            })
            .where((server) => server.isValid)
            .toList(),
      );
    } catch (_) {
      return [];
    }
  }

  List<String> _loadUsernames(SharedPreferences prefs) {
    final values = prefs.getStringList(_keyUsernames) ?? [];
    return _dedupeUsernames(values);
  }

  Map<String, String> _loadSavedPasswords(SharedPreferences prefs) {
    final json = prefs.getString(_keySavedPasswords);
    if (json == null || json.isEmpty) return {};

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value as String? ?? ''));
    } catch (_) {
      return {};
    }
  }

  List<HarborConnection> _loadLegacyConnections(SharedPreferences prefs) {
    final jsonList = prefs.getStringList(_keyLegacyConnections);
    if (jsonList == null || jsonList.isEmpty) return [];

    try {
      return jsonList
          .map((item) {
            final map = jsonDecode(item) as Map<String, dynamic>;
            return HarborConnection.fromJson(map);
          })
          .where((conn) => conn.host.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  HarborConnection? _loadLegacyConnection(SharedPreferences prefs) {
    final json = prefs.getString(_keyLegacyConfig);
    if (json == null) return null;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final conn = HarborConnection.fromJson(map);
      return conn.host.isEmpty ? null : conn;
    } catch (_) {
      return null;
    }
  }

  void _migrateLegacyConnections(
    List<HarborConnection> legacyConnections,
    String? legacySelectedId,
  ) {
    for (final conn in legacyConnections) {
      _upsertServer(HarborServer.fromConnection(conn));
      _upsertUsername(conn.username);
      if (conn.password.isNotEmpty) {
        _savedPasswords[conn.id] = conn.password;
      }
    }

    final selected = legacyConnections.firstWhere(
      (conn) => conn.id == legacySelectedId,
      orElse: () => legacyConnections.first,
    );
    _selectedServerId = HarborServer.fromConnection(selected).id;
    _selectedUsername = selected.username;
  }

  HarborConnection _connectionForCurrentSelection() {
    final server = _selectedServer();
    if (server == null) {
      return HarborConnection.empty().copyWith(username: _selectedUsername);
    }

    return HarborConnection(
      host: server.host,
      port: server.port,
      username: _selectedUsername,
      password: _passwordFor(server, _selectedUsername),
    );
  }

  HarborServer? _selectedServer() {
    if (_selectedServerId == null) return null;
    final index = _servers.indexWhere(
      (server) => server.id == _selectedServerId,
    );
    return index == -1 ? null : _servers[index];
  }

  String _passwordFor(HarborServer server, String username) {
    if (!_rememberPassword) return '';
    final id = HarborConnection.buildId(
      host: server.host,
      port: server.port,
      username: username,
    );
    return _savedPasswords[id] ?? '';
  }

  /// Tests the connection asynchronously and restores connection state.
  Future<void> _autoConnect() async {
    try {
      final version = await _apiService.ping();
      await _apiService.authenticate();
      setConnected(version);
    } catch (_) {
      _apiService.disconnect();
      setDisconnected();
    }
  }

  /// Saves or updates the server, username, and optional password.
  Future<void> updateConnection(
    HarborConnection conn, {
    bool? rememberPassword,
  }) async {
    _upsertServer(HarborServer.fromConnection(conn));
    _upsertUsername(conn.username);

    _selectedServerId = HarborServer.fromConnection(conn).id;
    _selectedUsername = conn.username.trim().isEmpty
        ? 'admin'
        : conn.username.trim();
    if (rememberPassword != null) {
      _rememberPassword = rememberPassword;
    }

    if (_rememberPassword && conn.password.isNotEmpty) {
      _savedPasswords[conn.id] = conn.password;
    } else if (!_rememberPassword) {
      _savedPasswords.remove(conn.id);
    }

    _connection = conn;
    _markDisconnected();

    final prefs = await SharedPreferences.getInstance();
    await _saveToPrefs(prefs);
    notifyListeners();
  }

  /// Saves or selects a server address.
  Future<void> saveServer(HarborServer server) async {
    if (!server.isValid) return;

    _upsertServer(server);
    _selectedServerId = server.id;
    _connection = _connectionForCurrentSelection();
    _apiService.disconnect();
    _markDisconnected();

    final prefs = await SharedPreferences.getInstance();
    await _saveToPrefs(prefs);
    notifyListeners();
  }

  /// Selects a saved server address.
  Future<void> selectServer(String id) async {
    if (!_servers.any((server) => server.id == id)) return;

    _selectedServerId = id;
    _connection = _connectionForCurrentSelection();
    _apiService.disconnect();
    _markDisconnected();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedServerId, id);
    notifyListeners();
  }

  /// Clears the current server selection without deleting saved addresses.
  Future<void> clearSelectedServer() async {
    _selectedServerId = null;
    _connection = _connectionForCurrentSelection();
    _apiService.disconnect();
    _markDisconnected();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySelectedServerId);
    notifyListeners();
  }

  /// Deletes a saved server address.
  Future<void> deleteServer(String id) async {
    final index = _servers.indexWhere((server) => server.id == id);
    if (index == -1) return;

    final deletingSelected = _selectedServerId == id;
    _servers.removeAt(index);
    _savedPasswords.removeWhere((key, _) => key.startsWith('$id|'));
    if (deletingSelected) {
      _selectedServerId = _servers.isEmpty ? null : _servers.first.id;
      _connection = _connectionForCurrentSelection();
      _apiService.disconnect();
      _markDisconnected();
    }

    final prefs = await SharedPreferences.getInstance();
    await _saveToPrefs(prefs);
    notifyListeners();
  }

  /// Selects a saved username.
  Future<void> selectUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    _selectedUsername = trimmed;
    _connection = _connectionForCurrentSelection();
    _apiService.disconnect();
    _markDisconnected();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedUsername, trimmed);
    notifyListeners();
  }

  // Compatibility with the previous multi-connection API.
  Future<void> selectConnection(String id) => selectServer(id);
  Future<void> deleteConnection(String id) => deleteServer(id);

  void _upsertServer(HarborServer server) {
    final index = _servers.indexWhere((item) => item.id == server.id);
    if (index == -1) {
      _servers.add(server);
    } else {
      _servers[index] = server;
    }
  }

  void _upsertUsername(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;
    _usernames = _dedupeUsernames([trimmed, ..._usernames]);
  }

  List<HarborServer> _dedupeServers(List<HarborServer> servers) {
    final seen = <String>{};
    return [
      for (final server in servers)
        if (seen.add(server.id)) server,
    ];
  }

  List<String> _dedupeUsernames(List<String> usernames) {
    final seen = <String>{};
    return [
      for (final username in usernames.map((value) => value.trim()))
        if (username.isNotEmpty && seen.add(username)) username,
    ];
  }

  Future<void> _saveToPrefs(SharedPreferences prefs) async {
    final serverJson = _servers
        .map((server) => jsonEncode(server.toJson()))
        .toList();
    await prefs.setStringList(_keyServers, serverJson);
    await prefs.setStringList(_keyUsernames, _usernames);
    await prefs.setString(_keySavedPasswords, jsonEncode(_savedPasswords));
    await prefs.setBool(_keyRememberPassword, _rememberPassword);
    await prefs.setString(_keySelectedUsername, _selectedUsername);

    if (_selectedServerId == null) {
      await prefs.remove(_keySelectedServerId);
    } else {
      await prefs.setString(_keySelectedServerId, _selectedServerId!);
    }
  }

  /// Marks the store as connected.
  void setConnected(String version) {
    _isConnected = true;
    _harborVersion = version;
    notifyListeners();
  }

  /// Marks the store as disconnected.
  void setDisconnected() {
    _markDisconnected();
    notifyListeners();
  }

  void _markDisconnected() {
    _isConnected = false;
    _harborVersion = '';
  }
}

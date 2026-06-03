import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:harbor_visible_kit/domain/push/harbor_push_config.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';

/// Persistent storage and state management for push templates.
class PushConfigStore extends ChangeNotifier {
  static const _keyConfigs = 'harbor_push_configs';
  static const _keySelectedId = 'harbor_push_selected_id';

  List<HarborPushConfig> _configs = [];
  String? _selectedId;

  List<HarborPushConfig> get configs => _configs;
  String? get selectedId => _selectedId;

  HarborPushConfig get selectedConfig {
    if (_selectedId == null || _configs.isEmpty) {
      return const HarborPushConfig(
        id: 'default',
        name: '默认配置',
        project: '',
        artifact: '',
        tag: '',
      );
    }
    return _configs.firstWhere(
      (c) => c.id == _selectedId,
      orElse: () => _configs.first,
    );
  }

  /// Loads saved configurations from local storage.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyConfigs);

    if (jsonList != null && jsonList.isNotEmpty) {
      try {
        _configs = jsonList.map((item) {
          final map = jsonDecode(item) as Map<String, dynamic>;
          return HarborPushConfig.fromJson(map);
        }).toList();
      } catch (_) {
        _configs = [];
      }
    }

    // Initialize the default configuration.
    if (_configs.isEmpty) {
      _configs = [
        const HarborPushConfig(
          id: 'default',
          name: '默认配置',
          project: '',
          artifact: '',
          tag: '',
        ),
      ];
    }

    _selectedId = prefs.getString(_keySelectedId);
    if (_selectedId == null || !_configs.any((c) => c.id == _selectedId)) {
      _selectedId = _configs.first.id;
    }

    notifyListeners();
  }

  /// Adds and selects a new configuration.
  Future<void> addConfig({
    required String name,
    required String project,
    required String artifact,
    required String tag,
    PushArtifactType artifactType = PushArtifactType.jar,
    String customerCode = '',
  }) async {
    final newConfig = HarborPushConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      project: project,
      artifact: artifact,
      tag: tag,
      artifactType: artifactType,
      customerCode: customerCode,
    );
    _configs.add(newConfig);
    _selectedId = newConfig.id;
    await _saveToPrefs();
    notifyListeners();
  }

  /// Updates an existing configuration.
  Future<void> updateConfig(
    String id, {
    required String project,
    required String artifact,
    required String tag,
    PushArtifactType artifactType = PushArtifactType.jar,
    String customerCode = '',
  }) async {
    final index = _configs.indexWhere((c) => c.id == id);
    if (index != -1) {
      _configs[index] = _configs[index].copyWith(
        project: project,
        artifact: artifact,
        tag: tag,
        artifactType: artifactType,
        customerCode: customerCode,
      );
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Deletes a configuration.
  Future<void> deleteConfig(String id) async {
    // Keep at least one configuration; the only configuration cannot be deleted.
    if (_configs.length <= 1) return;

    final index = _configs.indexWhere((c) => c.id == id);
    if (index != -1) {
      _configs.removeAt(index);
      if (_selectedId == id) {
        _selectedId = _configs.first.id;
      }
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Selects a saved configuration.
  Future<void> selectConfig(String id) async {
    if (_configs.any((c) => c.id == id)) {
      _selectedId = id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedId, id);
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _configs.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_keyConfigs, jsonList);
    if (_selectedId != null) {
      await prefs.setString(_keySelectedId, _selectedId!);
    }
  }
}

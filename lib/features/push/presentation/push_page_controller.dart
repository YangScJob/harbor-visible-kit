part of 'push_page.dart';

class _PushPageController extends ChangeNotifier {
  final _projectController = TextEditingController();
  final _tagController = TextEditingController();
  final _customerCodeController = TextEditingController();

  final _targetResolver = const PushTargetResolver();
  final List<LogEntry> _logs = [];

  final List<_SelectedArtifactFile> _selectedFiles = [];
  final Map<String, TextEditingController> _repositoryControllers = {};
  PushArtifactType _selectedArtifactType = PushArtifactType.jar;
  bool _isPushing = false;
  String? _lastSelectedId;

  List<HarborProject> _projects = [];
  bool _isLoadingProjects = false;
  List<String> _rawTagSuggestions = [];
  List<String> _tagSuggestions = [];
  bool _isLoadingTagSuggestions = false;
  bool _tagSuggestionLoadScheduled = false;
  int _tagSuggestionRequestId = 0;
  String _lastProjectText = '';
  String _lastCustomerCodeText = '';
  ConnectionStore? _connectionStore;
  BuildContext? _context;

  _PushPageController() {
    _projectController.addListener(_onFieldChanged);
    _tagController.addListener(_onFieldChanged);
    _customerCodeController.addListener(_onFieldChanged);
  }

  AppStrings get _strings {
    final context = _context;
    return context == null ? AppStrings.fallback : context.l10n;
  }

  void start(BuildContext context) {
    _context = context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        _loadProjects(context);
      }
    });
  }

  void bindConnectionStore(BuildContext context, ConnectionStore newStore) {
    _context = context;
    if (_connectionStore == newStore) return;
    _connectionStore?.removeListener(_onConnectionChanged);
    _connectionStore = newStore;
    _connectionStore?.addListener(_onConnectionChanged);
  }

  void syncSelectedConfig(String? selectedId, HarborPushConfig config) {
    if (_lastSelectedId == selectedId) return;
    _lastSelectedId = selectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _projectController.text = config.project;
      _tagController.text = config.tag;
      _customerCodeController.text = config.customerCode;
      _selectedArtifactType = config.artifactType;
      _selectedFiles.clear();
      _disposeRepositoryControllers();
      notifyListeners();
    });
  }

  void _addLog(String message, {LogLevel level = LogLevel.info}) {
    _logs.add(LogEntry(message: message, level: level));
    notifyListeners();
  }

  void _clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<List<HarborProject>?> _loadProjects(
    BuildContext context, {
    bool manual = false,
    bool logSuccess = true,
  }) async {
    final store = context.read<ConnectionStore>();
    final strings = context.l10n;
    if (!store.isConnected) {
      if (manual) {
        _addLog(
          strings.pick(
            '请先连接 Harbor 后再刷新项目空间',
            'Connect to Harbor before refreshing project namespaces',
          ),
          level: LogLevel.warning,
        );
      }
      return null;
    }

    _isLoadingProjects = true;
    notifyListeners();
    try {
      final api = context.read<HarborApiService>();
      final projects = await api.listProjects();
      if (!context.mounted) return projects;

      String? removedProject;
      _projects = projects;
      final currentText = _projectController.text.trim();
      if (currentText.isNotEmpty &&
          !projects.any((p) => p.name == currentText)) {
        removedProject = currentText;
        _projectController.clear();
      }
      if (projects.length == 1 && _projectController.text.trim().isEmpty) {
        _projectController.text = projects.single.name;
        _projectController.selection = TextSelection.collapsed(
          offset: projects.single.name.length,
        );
      }
      notifyListeners();
      if (removedProject != null) {
        _addLog(
          strings.pick(
            '项目空间 "$removedProject" 已不在 Harbor 当前列表中，已清空当前选择',
            'Project namespace "$removedProject" is no longer in Harbor. Current selection was cleared',
          ),
          level: LogLevel.warning,
        );
      }
      if (logSuccess) {
        _addLog(
          manual
              ? strings.pick(
                  '已刷新 ${projects.length} 个项目空间',
                  'Refreshed ${projects.length} project ${strings.plural(projects.length, 'namespace', 'namespaces')}',
                )
              : strings.pick(
                  '已加载 ${projects.length} 个项目空间',
                  'Loaded ${projects.length} project ${strings.plural(projects.length, 'namespace', 'namespaces')}',
                ),
          level: LogLevel.success,
        );
      }
      return projects;
    } catch (e) {
      _addLog(
        strings.pick('加载项目列表失败: $e', 'Failed to load project list: $e'),
        level: LogLevel.error,
      );
      return null;
    } finally {
      if (context.mounted) {
        _isLoadingProjects = false;
        notifyListeners();
      }
    }
  }

  void _resetTagSuggestions() {
    _tagSuggestionRequestId++;
    _rawTagSuggestions = [];
    _tagSuggestions = [];
    _isLoadingTagSuggestions = false;
  }

  void _scheduleTagSuggestionLoad() {
    if (_tagSuggestionLoadScheduled) return;
    _tagSuggestionLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tagSuggestionLoadScheduled = false;
      final context = _context;
      if (context != null && context.mounted) {
        _loadTagSuggestions(context);
      }
    });
  }

  List<String> _normalizeTagSuggestions(Iterable<String> tags) {
    final customerCode = _customerCodeController.text.trim();
    final seen = <String>{};
    final values = <String>[];

    for (final tag in tags) {
      var value = tag.trim();
      if (value.isEmpty) continue;

      if (_selectedArtifactType == PushArtifactType.jar &&
          value.endsWith('-jar')) {
        value = value.substring(0, value.length - '-jar'.length);
      } else if (_selectedArtifactType != PushArtifactType.jar &&
          value.endsWith('-jar')) {
        continue;
      }
      if (customerCode.isNotEmpty && value.endsWith('-$customerCode')) {
        value = value.substring(0, value.length - customerCode.length - 1);
      }
      if (value.isNotEmpty && seen.add(value)) {
        values.add(value);
      }
    }

    return values.take(60).toList();
  }

  List<String> _targetRepositoriesForTagSuggestions(ConnectionStore store) {
    final project = _projectController.text.trim();
    if (!store.isConnected || project.isEmpty || _selectedFiles.isEmpty) {
      return const [];
    }

    final repositories = <String>{};
    final fallbackVersion = _tagController.text.trim().isEmpty
        ? 'latest'
        : _tagController.text.trim();
    for (final file in _selectedFiles) {
      final target = _targetResolver.resolve(
        file: file.toSourceFile(),
        artifactType: _selectedArtifactType,
        registry: store.connection.registry,
        project: project,
        batchVersion: fallbackVersion,
        customerCode: _customerCodeController.text,
        repositoryOverride: _repositoryOverrideFor(file),
      );
      final repository = target.repository?.trim();
      if (repository != null && repository.isNotEmpty) {
        repositories.add(repository);
      }
    }

    return repositories.toList()..sort();
  }

  Future<void> _loadTagSuggestions(
    BuildContext context, {
    bool manual = false,
  }) async {
    final store = context.read<ConnectionStore>();
    final strings = context.l10n;
    final project = _projectController.text.trim();
    if (!store.isConnected || project.isEmpty) {
      if (manual) {
        _addLog(
          strings.pick(
            '请先连接 Harbor 并选择项目空间',
            'Connect to Harbor and choose a project namespace first',
          ),
          level: LogLevel.warning,
        );
      }
      return;
    }

    final requestId = ++_tagSuggestionRequestId;
    final repositories = _targetRepositoriesForTagSuggestions(store);
    _isLoadingTagSuggestions = true;
    notifyListeners();

    try {
      final api = context.read<HarborApiService>();
      final rawTags = await api.listTagsForProject(
        project,
        repositoryNames: repositories,
      );
      if (!context.mounted || requestId != _tagSuggestionRequestId) return;

      final tags = _normalizeTagSuggestions(rawTags);
      _rawTagSuggestions = rawTags;
      _tagSuggestions = tags;
      notifyListeners();

      if (manual) {
        _addLog(
          tags.isEmpty
              ? strings.pick(
                  'Harbor 中暂未发现可复用版本标签',
                  'No reusable version tags were found in Harbor',
                )
              : strings.pick(
                  '已刷新 ${tags.length} 个版本标签候选',
                  'Refreshed ${tags.length} version tag ${strings.plural(tags.length, 'candidate', 'candidates')}',
                ),
          level: tags.isEmpty ? LogLevel.info : LogLevel.success,
        );
      }
    } catch (e) {
      if (!context.mounted || requestId != _tagSuggestionRequestId) return;
      if (manual) {
        _addLog(
          strings.pick('刷新版本标签失败: $e', 'Failed to refresh version tags: $e'),
          level: LogLevel.error,
        );
      }
    } finally {
      if (context.mounted && requestId == _tagSuggestionRequestId) {
        _isLoadingTagSuggestions = false;
        notifyListeners();
      }
    }
  }

  void _onConnectionChanged() {
    final context = _context;
    if (context == null || !context.mounted) return;
    if (_connectionStore?.isConnected == true &&
        _projects.isEmpty &&
        !_isLoadingProjects) {
      _loadProjects(context);
      if (_projectController.text.trim().isNotEmpty) {
        _loadTagSuggestions(context);
      }
    } else if (_connectionStore?.isConnected == false) {
      _projects = [];
      _resetTagSuggestions();
      notifyListeners();
    }
  }

  void _setArtifactType(PushArtifactType type) {
    if (_selectedArtifactType == type) return;
    _selectedArtifactType = type;
    _selectedFiles.clear();
    _disposeRepositoryControllers();
    _resetTagSuggestions();
    notifyListeners();
    _scheduleTagSuggestionLoad();
    _addLog(
      _strings.pick(
        '已切换制品类型: ${_strings.artifactLabel(type)}',
        'Switched artifact type: ${_strings.artifactLabel(type)}',
      ),
    );
  }

  void _onFilesSelected(List<String> paths) {
    final selectedFiles = <_SelectedArtifactFile>[];
    final seenPaths = <String>{};
    for (final path in paths) {
      if (!seenPaths.add(path)) continue;
      final file = File(path);
      if (!file.existsSync()) {
        _addLog(
          _strings.pick(
            '文件不存在，已跳过: $path',
            'File does not exist and was skipped: $path',
          ),
          level: LogLevel.warning,
        );
        continue;
      }
      final size = file.lengthSync();
      selectedFiles.add(
        _SelectedArtifactFile(
          path: path,
          name: file.uri.pathSegments.last,
          sizeBytes: size,
          sizeLabel: _formatSize(size),
        ),
      );
    }

    if (selectedFiles.isEmpty) return;

    _selectedFiles
      ..clear()
      ..addAll(selectedFiles);
    _syncRepositoryControllers(selectedFiles);
    _resetTagSuggestions();
    notifyListeners();
    _scheduleTagSuggestionLoad();

    final totalSize = selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.sizeBytes,
    );
    _addLog(
      _strings.pick(
        '已选择 ${selectedFiles.length} 个文件，总计 ${_formatSize(totalSize)}',
        'Selected ${selectedFiles.length} ${_strings.plural(selectedFiles.length, 'file', 'files')}, total ${_formatSize(totalSize)}',
      ),
      level: LogLevel.success,
    );
    for (final file in selectedFiles) {
      _addLog(' - ${file.name} (${file.sizeLabel})');
    }
  }

  void _syncRepositoryControllers(List<_SelectedArtifactFile> files) {
    final currentPaths = files.map((file) => file.path).toSet();
    final removedPaths = _repositoryControllers.keys
        .where((path) => !currentPaths.contains(path))
        .toList();
    for (final path in removedPaths) {
      _repositoryControllers.remove(path)?.dispose();
    }

    for (final file in files) {
      _repositoryControllers.putIfAbsent(file.path, () {
        final controller = TextEditingController();
        controller.addListener(_onRepositoryOverrideChanged);
        return controller;
      });
    }
  }

  void _disposeRepositoryControllers() {
    for (final controller in _repositoryControllers.values) {
      controller.removeListener(_onRepositoryOverrideChanged);
      controller.dispose();
    }
    _repositoryControllers.clear();
  }

  void _onRepositoryOverrideChanged() {
    notifyListeners();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _artifactIcon(PushArtifactType type) {
    switch (type) {
      case PushArtifactType.jar:
        return Icons.description_rounded;
      case PushArtifactType.web:
        return Icons.web_asset_rounded;
      case PushArtifactType.apk:
        return Icons.android_rounded;
      case PushArtifactType.image:
        return Icons.inventory_2_rounded;
    }
  }

  String? get _selectedFileSummary {
    if (_selectedFiles.isEmpty) return null;
    final totalSize = _selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.sizeBytes,
    );
    return _strings.pick(
      '${_strings.artifactShortLabel(_selectedArtifactType)} ${_selectedFiles.length} 个 / ${_formatSize(totalSize)}',
      '${_strings.artifactShortLabel(_selectedArtifactType)} ${_selectedFiles.length} ${_strings.plural(_selectedFiles.length, 'file', 'files')} / ${_formatSize(totalSize)}',
    );
  }

  String? get _customerCodeError {
    final customerCode = _customerCodeController.text.trim();
    if (_targetResolver.isValidCustomerCode(customerCode)) return null;
    return _strings.pick(
      '标签后缀仅支持 ASCII 字母、数字、下划线、中划线和点号',
      'Tag suffix only supports ASCII letters, numbers, underscores, hyphens, and dots',
    );
  }

  String _repositoryOverrideFor(_SelectedArtifactFile file) {
    return _repositoryControllers[file.path]?.text ?? '';
  }

  List<PushTargetResolution> _buildPreviewTargets({
    required String registry,
    required String project,
  }) {
    return _selectedFiles.map((file) {
      return _targetResolver.resolve(
        file: file.toSourceFile(),
        artifactType: _selectedArtifactType,
        registry: registry,
        project: project,
        batchVersion: _tagController.text,
        customerCode: _customerCodeController.text,
        repositoryOverride: _repositoryOverrideFor(file),
      );
    }).toList();
  }

  bool _hasInvalidPreviewTargets({
    required String registry,
    required String project,
  }) {
    final targets = _buildPreviewTargets(registry: registry, project: project);
    return targets.any((target) => !target.isValid);
  }

  String? _pushDisabledReason(ConnectionStore store) {
    final strings = _strings;
    if (_isPushing) {
      return strings.pick(
        '正在推送，完成后可再次操作',
        'Push is in progress. Try again after it finishes',
      );
    }
    if (!store.isConnected) {
      return strings.pick(
        '请先在「连接配置」页面连接 Harbor',
        'Connect to Harbor on the Connection page first',
      );
    }
    if (_projectController.text.trim().isEmpty) {
      return strings.pick('请选择项目空间', 'Choose a project namespace');
    }
    if (_tagController.text.trim().isEmpty) {
      return strings.pick('请填写版本标签', 'Enter a version tag');
    }
    final customerCodeError = _customerCodeError;
    if (customerCodeError != null) return customerCodeError;
    if (_selectedFiles.isEmpty) {
      return strings.pick('请先选择制品文件', 'Choose artifact files first');
    }
    if (_hasInvalidPreviewTargets(
      registry: store.connection.registry,
      project: _projectController.text.trim(),
    )) {
      return strings.pick(
        '请先修正目标预览中的待处理项',
        'Fix pending items in the target preview first',
      );
    }
    return null;
  }

  List<String> _previewIssues(List<PushTargetResolution> targets) {
    return targets
        .where((target) => !target.isValid)
        .map((target) {
          final errors = target.errors
              .map(_strings.targetError)
              .join(_strings.pick('；', '; '));
          return '${target.file.name}: $errors';
        })
        .toList(growable: false);
  }

  int _pushWorkflowStep(ConnectionStore store) {
    if (!store.isConnected) return 0;
    if (_projectController.text.trim().isEmpty ||
        _tagController.text.trim().isEmpty ||
        _customerCodeError != null) {
      return 1;
    }
    if (_selectedFiles.isEmpty) return 2;
    if (_hasInvalidPreviewTargets(
      registry: store.connection.registry,
      project: _projectController.text.trim(),
    )) {
      return 3;
    }
    return 4;
  }

  Future<void> _pushToHarbor(BuildContext context) async {
    final strings = context.l10n;
    if (_selectedFiles.isEmpty) {
      final message = strings.pick('请先选择制品文件', 'Choose artifact files first');
      _addLog(message, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: message,
      );
      return;
    }

    final store = context.read<ConnectionStore>();
    if (!store.isConnected) {
      final logMessage = strings.pick(
        '请先在「连接配置」页面连接 Harbor',
        'Connect to Harbor on the Connection page first',
      );
      _addLog(logMessage, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: strings.pick('请先连接 Harbor', 'Connect to Harbor first'),
      );
      return;
    }

    final registry = store.connection.registry;
    final project = _projectController.text.trim();
    final tag = _tagController.text.trim();
    final customerCodeError = _customerCodeError;

    if (project.isEmpty || tag.isEmpty) {
      final message = strings.pick(
        '请填写项目空间和版本标签',
        'Enter a project namespace and version tag',
      );
      _addLog(message, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: message,
      );
      return;
    }
    if (customerCodeError != null) {
      _addLog(customerCodeError, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: customerCodeError,
      );
      return;
    }

    final latestProjects = await _loadProjects(context, logSuccess: false);
    if (!context.mounted) return;
    if (latestProjects == null) {
      _addLog(
        strings.pick(
          '无法刷新 Harbor 项目空间，已停止推送',
          'Could not refresh Harbor project namespaces. Push stopped',
        ),
        level: LogLevel.warning,
      );
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: strings.pick(
          '无法刷新 Harbor 项目空间',
          'Could not refresh Harbor project namespaces',
        ),
      );
      return;
    }
    if (!latestProjects.any((p) => p.name == project)) {
      _addLog(
        strings.pick(
          '项目空间 "$project" 已不存在，请刷新后重新选择',
          'Project namespace "$project" no longer exists. Refresh and choose again',
        ),
        level: LogLevel.warning,
      );
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: strings.pick(
          '项目空间 "$project" 已不存在',
          'Project namespace "$project" no longer exists',
        ),
      );
      return;
    }

    final targets = _buildPreviewTargets(registry: registry, project: project);
    PushTargetResolution? invalidTarget;
    for (final target in targets) {
      if (!target.isValid) {
        invalidTarget = target;
        break;
      }
    }
    if (invalidTarget != null) {
      final errors = invalidTarget.errors
          .map(strings.targetError)
          .join(strings.pick('；', '; '));
      _addLog(
        strings.pick(
          '请先修正 ${invalidTarget.file.name}: $errors',
          'Fix ${invalidTarget.file.name}: $errors',
        ),
        level: LogLevel.warning,
      );
      AppNotice.warning(
        context,
        title: strings.pick('无法推送', 'Cannot push'),
        message: '${invalidTarget.file.name}: $errors',
      );
      return;
    }

    _isPushing = true;
    notifyListeners();

    try {
      _addLog(
        strings.pick(
          '开始批量推送 ${targets.length} 个文件',
          'Starting batch push for ${targets.length} ${strings.plural(targets.length, 'file', 'files')}',
        ),
      );
      for (var i = 0; i < targets.length; i++) {
        final target = targets[i];
        _addLog(
          strings.pick(
            '文件 ${i + 1}/${targets.length}: ${target.file.name}',
            'File ${i + 1}/${targets.length}: ${target.file.name}',
          ),
        );
        _addLog(
          strings.pick(
            '目标制品: ${target.imageTag}',
            'Target artifact: ${target.imageTag}',
          ),
        );
        final success = await _pushSingleTarget(context, target);
        if (!success) {
          _addLog(
            strings.pick('批量推送已停止', 'Batch push stopped'),
            level: LogLevel.error,
          );
          if (context.mounted) {
            AppNotice.error(
              context,
              title: strings.pick('推送失败', 'Push failed'),
              message: strings.pick(
                '${target.file.name} 处理失败，批量推送已停止',
                '${target.file.name} failed. Batch push stopped',
              ),
            );
          }
          return;
        }
      }

      _addLog(
        strings.pick(
          '批量推送完成，共 ${targets.length} 个文件',
          'Batch push completed, ${targets.length} ${strings.plural(targets.length, 'file', 'files')}',
        ),
        level: LogLevel.success,
      );
      if (context.mounted) {
        AppNotice.success(
          context,
          title: strings.pick('推送成功', 'Push successful'),
          message: strings.pick(
            '已推送 ${targets.length} 个制品到 $project',
            'Pushed ${targets.length} ${strings.plural(targets.length, 'artifact', 'artifacts')} to $project',
          ),
        );
      }
    } catch (e) {
      _addLog(
        strings.pick('操作异常: $e', 'Operation error: $e'),
        level: LogLevel.error,
      );
      if (context.mounted) {
        AppNotice.error(
          context,
          title: strings.pick('推送失败', 'Push failed'),
          message: strings.errorMessage(e),
        );
      }
    } finally {
      _isPushing = false;
      notifyListeners();
    }
  }

  Future<bool> _pushSingleTarget(
    BuildContext context,
    PushTargetResolution target,
  ) async {
    final strings = context.l10n;
    final file = target.file;
    final store = context.read<ConnectionStore>();
    final service = ArtifactRegistryService(store.connection);

    try {
      if (target.artifactType == PushArtifactType.jar) {
        _addLog(
          strings.pick(
            '正在封装并上传 JAR 制品 (${target.imageTag})...',
            'Packaging and uploading JAR artifact (${target.imageTag})...',
          ),
        );
        await service.pushJar(
          project: _projectController.text.trim(),
          repository: target.repository!,
          tag: target.tag!,
          jarPath: file.path,
          onOutput: (line) => _addLog(strings.runtimeMessage(line)),
        );
      } else if (target.artifactType == PushArtifactType.web) {
        _addLog(
          strings.pick(
            '正在封装并上传 Web 前端包 (${target.imageTag})...',
            'Packaging and uploading Web frontend package (${target.imageTag})...',
          ),
        );
        await service.pushWebPackage(
          project: _projectController.text.trim(),
          repository: target.repository!,
          tag: target.tag!,
          packagePath: file.path,
          onOutput: (line) => _addLog(strings.runtimeMessage(line)),
        );
      } else if (ArtifactKindClassifier.isApkArtifactType(
        target.artifactType,
      )) {
        final artifactLabel = strings.artifactLabel(target.artifactType);
        _addLog(
          strings.pick(
            '正在封装并上传 $artifactLabel (${target.imageTag})...',
            'Packaging and uploading $artifactLabel (${target.imageTag})...',
          ),
        );
        await service.pushApkPackage(
          project: _projectController.text.trim(),
          repository: target.repository!,
          tag: target.tag!,
          apkPath: file.path,
          artifactLabel: target.artifactType.label,
          onOutput: (line) => _addLog(strings.runtimeMessage(line)),
        );
      } else {
        _addLog(
          strings.pick(
            '正在解析并上传镜像包 (${file.name})...',
            'Parsing and uploading image archive (${file.name})...',
          ),
        );
        await service.pushImageArchive(
          project: _projectController.text.trim(),
          repository: target.repository!,
          tag: target.tag!,
          archivePath: file.path,
          onOutput: (line) => _addLog(strings.runtimeMessage(line)),
        );
      }
    } catch (e) {
      _addLog(
        strings.pick(
          '制品上传失败: ${strings.errorMessage(e)}',
          'Artifact upload failed: ${strings.errorMessage(e)}',
        ),
        level: LogLevel.error,
      );
      return false;
    }
    _addLog(
      strings.pick(
        '制品上传成功: ${target.imageTag}',
        'Artifact uploaded: ${target.imageTag}',
      ),
      level: LogLevel.success,
    );
    return true;
  }

  HarborProject? _selectedProjectValue() {
    final currentText = _projectController.text.trim();
    if (currentText.isEmpty) return null;
    for (final project in _projects) {
      if (project.name == currentText) return project;
    }
    return null;
  }

  void _onFieldChanged() {
    final projectText = _projectController.text.trim();
    final customerCodeText = _customerCodeController.text.trim();
    final projectChanged = projectText != _lastProjectText;
    final customerCodeChanged = customerCodeText != _lastCustomerCodeText;

    _lastProjectText = projectText;
    _lastCustomerCodeText = customerCodeText;

    if (projectChanged) {
      _resetTagSuggestions();
    } else if (customerCodeChanged && _rawTagSuggestions.isNotEmpty) {
      _tagSuggestions = _normalizeTagSuggestions(_rawTagSuggestions);
    }
    notifyListeners();

    if (projectChanged &&
        projectText.isNotEmpty &&
        _connectionStore?.isConnected == true) {
      _scheduleTagSuggestionLoad();
    }
  }

  @override
  void dispose() {
    _connectionStore?.removeListener(_onConnectionChanged);
    _projectController.removeListener(_onFieldChanged);
    _tagController.removeListener(_onFieldChanged);
    _customerCodeController.removeListener(_onFieldChanged);
    _disposeRepositoryControllers();
    _projectController.dispose();
    _tagController.dispose();
    _customerCodeController.dispose();
    super.dispose();
  }
}

class _SelectedArtifactFile {
  final String path;
  final String name;
  final int sizeBytes;
  final String sizeLabel;

  const _SelectedArtifactFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.sizeLabel,
  });

  PushSourceFile toSourceFile() => PushSourceFile(path: path, name: name);
}

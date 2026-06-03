part of 'pull_page.dart';

class _PullPageController extends ChangeNotifier {
  final List<LogEntry> _logs = [];

  List<HarborProject> _projects = [];
  List<HarborRepository> _repositories = [];
  List<HarborArtifact> _artifacts = [];
  List<String> _versionTags = [];
  final List<HarborArtifact> _selectedArtifacts = [];
  final List<_DownloadItem> _downloadItems = [];

  HarborProject? _selectedProject;
  PushArtifactType? _selectedArtifactType;
  HarborRepository? _selectedRepo;
  String? _selectedVersionTag;

  String _savePath = PlatformUtils.downloadsPath;
  bool _isLoading = false;
  bool _isLoadingVersions = false;
  bool _isExtracting = false;
  int _versionRequestId = 0;
  ConnectionStore? _connectionStore;
  BuildContext? _context;

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

    _isLoading = true;
    notifyListeners();
    try {
      final api = context.read<HarborApiService>();
      final projects = await api.listProjects();
      if (!context.mounted) return projects;
      _projects = projects;
      _repositories = [];
      _artifacts = [];
      _versionTags = [];
      _selectedArtifacts.clear();
      _selectedProject = null;
      _selectedArtifactType = null;
      _selectedRepo = null;
      _selectedVersionTag = null;
      notifyListeners();
      if (projects.length == 1) {
        await _loadRepositories(context, projects.single);
        if (!context.mounted) return projects;
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
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadRepositories(
    BuildContext context,
    HarborProject project,
  ) async {
    _selectedProject = project;
    _selectedArtifactType = null;
    _selectedRepo = null;
    _selectedVersionTag = null;
    _selectedArtifacts.clear();
    _repositories = [];
    _artifacts = [];
    _versionTags = [];
    _versionRequestId++;
    _isLoading = true;
    notifyListeners();

    try {
      final api = context.read<HarborApiService>();
      final repos = await api.listRepositories(project.name);
      if (!context.mounted) return;
      _repositories = repos;
      notifyListeners();
      _addLog(
        context.l10n.pick(
          '项目 [${project.name}] 下有 ${repos.length} 个仓库',
          'Project [${project.name}] has ${repos.length} ${context.l10n.plural(repos.length, 'repository', 'repositories')}',
        ),
      );
    } catch (e) {
      _addLog(
        context.l10n.pick('加载仓库列表失败: $e', 'Failed to load repository list: $e'),
        level: LogLevel.error,
      );
    } finally {
      if (context.mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadArtifacts(
    BuildContext context,
    HarborRepository repo,
  ) async {
    _selectedRepo = repo;
    _selectedArtifacts.clear();
    _artifacts = [];
    _versionTags = [];
    _selectedVersionTag = null;
    _versionRequestId++;
    _isLoading = true;
    notifyListeners();

    try {
      final api = context.read<HarborApiService>();
      final artifacts = await api.listArtifacts(
        _selectedProject!.name,
        repo.shortName,
      );
      if (!context.mounted) return;
      _artifacts = artifacts;
      _versionTags = _tagsFromArtifacts(artifacts);
      notifyListeners();
      _addLog(
        context.l10n.pick(
          '仓库 [${repo.shortName}] 下有 ${artifacts.length} 个制品',
          'Repository [${repo.shortName}] has ${artifacts.length} ${context.l10n.plural(artifacts.length, 'artifact', 'artifacts')}',
        ),
      );
    } catch (e) {
      _addLog(
        context.l10n.pick('加载制品列表失败: $e', 'Failed to load artifact list: $e'),
        level: LogLevel.error,
      );
    } finally {
      if (context.mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _pickSavePath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: _strings.pick('选择保存目录', 'Choose save directory'),
      initialDirectory: _savePath,
    );
    if (result != null) {
      _savePath = result;
      notifyListeners();
    }
  }

  void _onConnectionChanged() {
    final store = _connectionStore;
    if (store == null) return;

    if (store.isConnected && _projects.isEmpty && !_isLoading) {
      final context = _context;
      if (context != null && context.mounted) {
        _loadProjects(context);
      }
    } else if (!store.isConnected) {
      _projects = [];
      _repositories = [];
      _artifacts = [];
      _versionTags = [];
      _selectedArtifacts.clear();
      _downloadItems.clear();
      _selectedProject = null;
      _selectedArtifactType = null;
      _selectedRepo = null;
      _selectedVersionTag = null;
      _versionRequestId++;
      notifyListeners();
    }
  }

  String get _downloadQueueSummary {
    final strings = _strings;
    if (_downloadItems.isEmpty) {
      return strings.pick('下载清单为空', 'Download queue is empty');
    }
    final jarCount = _downloadItems.where((item) => item.isJar).length;
    final webCount = _downloadItems.where((item) => item.isWeb).length;
    final apkCount = _downloadItems.where((item) => item.isApkApp).length;
    final imageCount = _downloadItems.length - jarCount - webCount - apkCount;
    final parts = <String>[];
    if (jarCount > 0) parts.add('JAR $jarCount');
    if (webCount > 0) parts.add('Web $webCount');
    if (apkCount > 0) parts.add('APK $apkCount');
    if (imageCount > 0) {
      parts.add(strings.pick('镜像 $imageCount', 'Image $imageCount'));
    }
    return strings.pick(
      '已加入 ${_downloadItems.length} 项（${parts.join(' / ')}）',
      'Added ${_downloadItems.length} ${strings.plural(_downloadItems.length, 'item', 'items')} (${parts.join(' / ')})',
    );
  }

  List<HarborRepository> get _filteredRepositories {
    final type = _selectedArtifactType;
    if (type == null) return const [];
    return _repositories
        .where((repo) => _isRepositoryInArtifactType(repo, type))
        .toList();
  }

  List<String> _tagsFromArtifacts(List<HarborArtifact> artifacts) {
    final tags = <String>{};
    for (final artifact in artifacts) {
      for (final tag in artifact.tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) tags.add(trimmed);
      }
    }
    return tags.toList()..sort((a, b) => b.compareTo(a));
  }

  HarborArtifact? _artifactForTag(List<HarborArtifact> artifacts, String tag) {
    for (final artifact in artifacts) {
      if (artifact.tags.contains(tag) || artifact.primaryTag == tag) {
        return artifact;
      }
    }
    return null;
  }

  void _selectVersionTag(String tag) {
    if (_isExtracting) return;
    final artifact = _selectedRepo == null
        ? null
        : _artifactForTag(_artifacts, tag);
    _selectedVersionTag = tag;
    _selectedArtifacts
      ..clear()
      ..addAll(artifact == null ? const [] : [artifact]);
    notifyListeners();
  }

  Future<void> _loadVersionsForArtifactType(
    BuildContext context,
    PushArtifactType type,
  ) async {
    final project = _selectedProject;
    if (project == null) return;

    final requestId = ++_versionRequestId;
    final repositories = _repositories
        .where((repo) => _isRepositoryInArtifactType(repo, type))
        .toList();
    if (repositories.isEmpty) {
      _versionTags = [];
      _isLoadingVersions = false;
      notifyListeners();
      return;
    }

    _isLoadingVersions = true;
    notifyListeners();
    try {
      final api = context.read<HarborApiService>();
      final tags = await api.listTagsForProject(
        project.name,
        repositoryNames: repositories.map((repo) => repo.shortName),
      );
      if (!context.mounted || requestId != _versionRequestId) return;
      _versionTags = tags;
      notifyListeners();
    } catch (e) {
      if (!context.mounted || requestId != _versionRequestId) return;
      _addLog(
        context.l10n.pick(
          '刷新版本候选失败: $e',
          'Failed to refresh version candidates: $e',
        ),
        level: LogLevel.error,
      );
      _versionTags = [];
      notifyListeners();
    } finally {
      if (context.mounted && requestId == _versionRequestId) {
        _isLoadingVersions = false;
        notifyListeners();
      }
    }
  }

  void _selectArtifactType(BuildContext context, PushArtifactType type) {
    if (_isExtracting) return;
    _selectedArtifactType = type;
    _selectedRepo = null;
    _selectedVersionTag = null;
    _artifacts = [];
    _versionTags = [];
    _selectedArtifacts.clear();
    _versionRequestId++;
    notifyListeners();
    _loadVersionsForArtifactType(context, type);
  }

  Future<void> _addSelectedArtifactsToQueue(BuildContext context) async {
    final strings = context.l10n;
    final project = _selectedProject;
    final repo = _selectedRepo;
    final type = _selectedArtifactType;
    final tag = _selectedVersionTag;
    if (project == null || type == null || tag == null || tag.isEmpty) {
      final message = strings.pick(
        '请先选择项目空间、制品类型和版本',
        'Choose a project namespace, artifact type, and version first',
      );
      _addLog(message, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('无法加入清单', 'Cannot add to queue'),
        message: message,
      );
      return;
    }

    final items = <_DownloadItem>[];
    if (repo != null) {
      final artifact = _artifactForTag(_artifacts, tag);
      if (artifact != null) {
        items.add(
          _DownloadItem(
            project: project,
            repo: repo,
            artifact: artifact,
            tag: tag,
          ),
        );
      }
    } else {
      _isLoading = true;
      notifyListeners();
      try {
        final api = context.read<HarborApiService>();
        for (final candidateRepo in _filteredRepositories) {
          final artifacts = await api.listArtifacts(
            project.name,
            candidateRepo.shortName,
          );
          final artifact = _artifactForTag(artifacts, tag);
          if (artifact == null) continue;
          items.add(
            _DownloadItem(
              project: project,
              repo: candidateRepo,
              artifact: artifact,
              tag: tag,
            ),
          );
        }
      } catch (e) {
        _addLog(
          strings.pick(
            '按版本匹配组件失败: $e',
            'Failed to match components by version: $e',
          ),
          level: LogLevel.error,
        );
        if (context.mounted) {
          AppNotice.error(
            context,
            title: strings.pick('加入失败', 'Add failed'),
            message: strings.errorMessage(e),
          );
        }
        return;
      } finally {
        if (context.mounted) {
          _isLoading = false;
          notifyListeners();
        }
      }
    }

    if (!context.mounted) return;
    if (items.isEmpty) {
      final message = strings.pick(
        '没有组件包含版本 $tag',
        'No components contain version $tag',
      );
      _addLog(message, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('未加入新条目', 'No new items added'),
        message: message,
      );
      return;
    }

    var addedCount = 0;
    for (final item in items) {
      if (_downloadItems.any((queued) => queued.key == item.key)) continue;
      _downloadItems.add(item);
      addedCount++;
    }
    notifyListeners();

    if (!context.mounted) return;
    if (addedCount == 0) {
      final message = strings.pick(
        '所选版本已在下载清单中',
        'The selected version is already in the download queue',
      );
      _addLog(message, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('未加入新条目', 'No new items added'),
        message: message,
      );
      return;
    }

    _addLog(
      strings.pick(
        '已加入 $addedCount 项到下载清单',
        'Added $addedCount ${strings.plural(addedCount, 'item', 'items')} to the download queue',
      ),
      level: LogLevel.success,
    );
  }

  void _removeDownloadItem(_DownloadItem item) {
    if (_isExtracting) return;
    _downloadItems.removeWhere((queued) => queued.key == item.key);
    notifyListeners();
  }

  void _clearDownloadQueue() {
    if (_isExtracting || _downloadItems.isEmpty) return;
    _downloadItems.clear();
    notifyListeners();
  }

  String? _addToQueueDisabledReason() {
    final strings = _strings;
    if (_isExtracting) {
      return strings.pick(
        '正在下载，暂不能调整清单',
        'Download is in progress. The queue cannot be adjusted now',
      );
    }
    if (_isLoading || _isLoadingVersions) {
      return strings.pick('正在加载候选数据', 'Loading candidate data');
    }
    if (_selectedProject == null) {
      return strings.pick('请先选择项目空间', 'Choose a project namespace first');
    }
    if (_selectedArtifactType == null) {
      return strings.pick('请先选择制品类型', 'Choose an artifact type first');
    }
    if (_selectedVersionTag == null) {
      return strings.pick('请先选择版本', 'Choose a version first');
    }
    return null;
  }

  String? _downloadDisabledReason(ConnectionStore store) {
    final strings = _strings;
    if (_isExtracting) {
      return strings.pick(
        '正在下载，完成后可再次操作',
        'Download is in progress. Try again after it finishes',
      );
    }
    if (!store.isConnected) {
      return strings.pick('请先连接 Harbor', 'Connect to Harbor first');
    }
    if (_downloadItems.isEmpty) {
      return strings.pick(
        '请先将组件版本加入下载清单',
        'Add component versions to the download queue first',
      );
    }
    if (_savePath.trim().isEmpty) {
      return strings.pick('请选择下载位置', 'Choose a download location');
    }
    return null;
  }

  int _pullWorkflowStep(ConnectionStore store) {
    if (!store.isConnected) return 0;
    if (_selectedProject == null ||
        _selectedArtifactType == null ||
        _selectedVersionTag == null) {
      return 1;
    }
    if (_downloadItems.isEmpty) return 2;
    return 3;
  }

  String _outputFileNameFor(_DownloadItem item) {
    if (item.isJar) return _artifactFileName(item.repo);
    if (item.isWeb) return 'dist.zip';
    if (item.isApkApp) return _apkFileNameFor(item);
    return ArtifactArchiveNaming.dockerImageArchiveFileName(
      repositoryName: item.repo.shortName,
      tag: item.tag,
    );
  }

  String _localDestinationFor(_DownloadItem item) {
    return _joinLocalPath([_savePath, _outputFileNameFor(item)]);
  }

  String _apkFileNameFor(_DownloadItem item) {
    final appName = item.repo.shortName.split('/').last;
    final tagParts = item.tag.split('-');
    if (tagParts.length >= 2 && RegExp(r'^\d+$').hasMatch(tagParts[1])) {
      final versionName = tagParts.first.replaceFirst(RegExp(r'^[Vv]'), '');
      return '$appName V$versionName build${tagParts[1]}.apk';
    }
    return '$appName ${item.tag}.apk';
  }

  String _imageTagFor({
    required String registry,
    required HarborProject project,
    required HarborRepository repo,
    required String tag,
  }) {
    return '$registry/${project.name}/${repo.shortName}:$tag';
  }

  bool _isRepositoryInArtifactType(
    HarborRepository repo,
    PushArtifactType type,
  ) {
    return ArtifactKindClassifier.isRepositoryNameInArtifactType(
      repo.shortName,
      type,
    );
  }

  String _artifactFileName(HarborRepository repo) {
    final repoName = repo.shortName.split('/').last;
    const suffix = '-artifacts';
    if (!repoName.endsWith(suffix)) return repoName;
    return '${repoName.substring(0, repoName.length - suffix.length)}.jar';
  }

  String _joinLocalPath(List<String> parts) {
    return parts.where((part) => part.isNotEmpty).join(Platform.pathSeparator);
  }

  String _outputDirectoryFor(String saveBasePath) {
    return saveBasePath;
  }

  Future<String?> _downloadJarItem({
    required ArtifactRegistryService service,
    required String registry,
    required String saveBasePath,
    required _DownloadItem item,
  }) async {
    final imageTag = _imageTagFor(
      registry: registry,
      project: item.project,
      repo: item.repo,
      tag: item.tag,
    );
    final fileName = _artifactFileName(item.repo);
    final targetDir = _outputDirectoryFor(saveBasePath);
    await Directory(targetDir).create(recursive: true);
    final localDest = _joinLocalPath([targetDir, fileName]);

    _addLog(
      _strings.pick(
        '正在下载并提取 JAR 制品: $imageTag',
        'Downloading and extracting JAR artifact: $imageTag',
      ),
    );
    try {
      await service.extractJar(
        project: item.project.name,
        repository: item.repo.shortName,
        tag: item.tag,
        jarFileName: fileName,
        outputPath: localDest,
        onOutput: (line) => _addLog(_strings.runtimeMessage(line)),
      );
    } catch (e) {
      _addLog(
        _strings.pick(
          'JAR 制品提取失败: ${_strings.errorMessage(e)}',
          'JAR artifact extraction failed: ${_strings.errorMessage(e)}',
        ),
        level: LogLevel.error,
      );
      return null;
    }

    _addLog(
      _strings.pick('文件已成功提取到: $localDest', 'File extracted to: $localDest'),
      level: LogLevel.success,
    );
    return localDest;
  }

  Future<String?> _downloadWebItem({
    required ArtifactRegistryService service,
    required String registry,
    required String saveBasePath,
    required _DownloadItem item,
  }) async {
    final imageTag = _imageTagFor(
      registry: registry,
      project: item.project,
      repo: item.repo,
      tag: item.tag,
    );
    final targetDir = _outputDirectoryFor(saveBasePath);
    await Directory(targetDir).create(recursive: true);

    final localDest = _joinLocalPath([targetDir, 'dist.zip']);

    _addLog(
      _strings.pick(
        '正在下载并提取 Web 前端包: $imageTag',
        'Downloading and extracting Web frontend package: $imageTag',
      ),
    );
    try {
      await service.extractWebPackage(
        project: item.project.name,
        repository: item.repo.shortName,
        tag: item.tag,
        outputPath: localDest,
        onOutput: (line) => _addLog(_strings.runtimeMessage(line)),
      );
    } catch (e) {
      _addLog(
        _strings.pick(
          'Web 前端包提取失败: ${_strings.errorMessage(e)}',
          'Web frontend package extraction failed: ${_strings.errorMessage(e)}',
        ),
        level: LogLevel.error,
      );
      return null;
    }

    _addLog(
      _strings.pick(
        'Web 前端包已成功提取到: $localDest',
        'Web frontend package extracted to: $localDest',
      ),
      level: LogLevel.success,
    );
    return localDest;
  }

  Future<String?> _downloadApkItem({
    required ArtifactRegistryService service,
    required String registry,
    required String saveBasePath,
    required _DownloadItem item,
  }) async {
    final imageTag = _imageTagFor(
      registry: registry,
      project: item.project,
      repo: item.repo,
      tag: item.tag,
    );
    final targetDir = _outputDirectoryFor(saveBasePath);
    await Directory(targetDir).create(recursive: true);

    final kindLabel = _strings.kindLabelForRepositoryName(item.repo.shortName);
    _addLog(
      _strings.pick(
        '正在下载并提取 $kindLabel: $imageTag',
        'Downloading and extracting $kindLabel: $imageTag',
      ),
    );
    try {
      final localDest = await service.extractApkPackage(
        project: item.project.name,
        repository: item.repo.shortName,
        tag: item.tag,
        outputDirectory: targetDir,
        artifactLabel: item.kindLabel,
        fallbackFileName: _apkFileNameFor(item),
        onOutput: (line) => _addLog(_strings.runtimeMessage(line)),
      );
      _addLog(
        _strings.pick(
          '$kindLabel 已成功提取到: $localDest',
          '$kindLabel extracted to: $localDest',
        ),
        level: LogLevel.success,
      );
      return localDest;
    } catch (e) {
      _addLog(
        _strings.pick(
          '$kindLabel 提取失败: ${_strings.errorMessage(e)}',
          '$kindLabel extraction failed: ${_strings.errorMessage(e)}',
        ),
        level: LogLevel.error,
      );
      return null;
    }
  }

  Future<String?> _downloadImageItem({
    required ArtifactRegistryService service,
    required String registry,
    required String saveBasePath,
    required _DownloadItem item,
  }) async {
    final imageTag = _imageTagFor(
      registry: registry,
      project: item.project,
      repo: item.repo,
      tag: item.tag,
    );
    final targetDir = _outputDirectoryFor(saveBasePath);
    await Directory(targetDir).create(recursive: true);

    final fileName = ArtifactArchiveNaming.dockerImageArchiveFileName(
      repositoryName: item.repo.shortName,
      tag: item.tag,
    );
    final localDest = _joinLocalPath([targetDir, fileName]);

    _addLog(
      _strings.pick(
        '正在下载并导出镜像归档: $imageTag',
        'Downloading and exporting image archive: $imageTag',
      ),
    );
    try {
      await service.exportImageArchive(
        project: item.project.name,
        repository: item.repo.shortName,
        tag: item.tag,
        outputPath: localDest,
        onOutput: (line) => _addLog(_strings.runtimeMessage(line)),
      );
    } catch (e) {
      _addLog(
        _strings.pick(
          '镜像归档导出失败: ${_strings.errorMessage(e)}',
          'Image archive export failed: ${_strings.errorMessage(e)}',
        ),
        level: LogLevel.error,
      );
      return null;
    }

    _addLog(
      _strings.pick('镜像已成功导出到: $localDest', 'Image exported to: $localDest'),
      level: LogLevel.success,
    );
    return localDest;
  }

  Future<void> _downloadQueuedArtifacts(BuildContext context) async {
    final strings = context.l10n;
    if (_downloadItems.isEmpty) {
      final message = strings.pick(
        '请先将组件版本加入下载清单',
        'Add component versions to the download queue first',
      );
      _addLog(message, level: LogLevel.warning);
      AppNotice.warning(
        context,
        title: strings.pick('无法下载', 'Cannot download'),
        message: message,
      );
      return;
    }

    final store = context.read<ConnectionStore>();
    if (!store.isConnected) {
      _addLog(
        strings.pick(
          '请先在「连接配置」页面连接 Harbor',
          'Connect to Harbor on the Connection page first',
        ),
        level: LogLevel.warning,
      );
      AppNotice.warning(
        context,
        title: strings.pick('无法下载', 'Cannot download'),
        message: strings.pick('请先连接 Harbor', 'Connect to Harbor first'),
      );
      return;
    }

    final registry = store.connection.registry;
    final service = ArtifactRegistryService(store.connection);
    final items = List<_DownloadItem>.from(_downloadItems);
    final saveBasePath = _savePath;

    _isExtracting = true;
    notifyListeners();

    try {
      _addLog(
        strings.pick(
          '开始批量下载 ${items.length} 个制品',
          'Starting batch download for ${items.length} ${strings.plural(items.length, 'artifact', 'artifacts')}',
        ),
      );
      final savedPaths = <String>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final kindLabel = strings.kindLabelForRepositoryName(
          item.repo.shortName,
        );
        _addLog(
          strings.pick(
            '制品 ${i + 1}/${items.length}: ${item.repo.shortName}:${item.tag} ($kindLabel)',
            'Artifact ${i + 1}/${items.length}: ${item.repo.shortName}:${item.tag} ($kindLabel)',
          ),
        );
        if (!context.mounted) return;
        final savedPath = item.isJar
            ? await _downloadJarItem(
                service: service,
                registry: registry,
                saveBasePath: saveBasePath,
                item: item,
              )
            : item.isWeb
            ? await _downloadWebItem(
                service: service,
                registry: registry,
                saveBasePath: saveBasePath,
                item: item,
              )
            : item.isApkApp
            ? await _downloadApkItem(
                service: service,
                registry: registry,
                saveBasePath: saveBasePath,
                item: item,
              )
            : await _downloadImageItem(
                service: service,
                registry: registry,
                saveBasePath: saveBasePath,
                item: item,
              );
        if (savedPath == null) {
          _addLog(
            strings.pick('批量下载已停止', 'Batch download stopped'),
            level: LogLevel.error,
          );
          if (context.mounted) {
            AppNotice.error(
              context,
              title: strings.pick('下载失败', 'Download failed'),
              message: strings.pick(
                '${item.repo.shortName}:${item.tag} 处理失败，批量下载已停止',
                '${item.repo.shortName}:${item.tag} failed. Batch download stopped',
              ),
            );
          }
          return;
        }
        savedPaths.add(savedPath);
      }

      _addLog(
        strings.pick(
          '批量下载完成，共 ${savedPaths.length} 个制品',
          'Batch download completed, ${savedPaths.length} ${strings.plural(savedPaths.length, 'artifact', 'artifacts')}',
        ),
        level: LogLevel.success,
      );
      if (context.mounted) {
        AppNotice.success(
          context,
          title: strings.pick('下载成功', 'Download successful'),
          message: savedPaths.length == 1
              ? strings.pick(
                  '文件已保存到 ${savedPaths.first}',
                  'File saved to ${savedPaths.first}',
                )
              : strings.pick(
                  '已下载 ${savedPaths.length} 个制品到 $saveBasePath',
                  'Downloaded ${savedPaths.length} ${strings.plural(savedPaths.length, 'artifact', 'artifacts')} to $saveBasePath',
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
          title: strings.pick('下载失败', 'Download failed'),
          message: strings.errorMessage(e),
        );
      }
    } finally {
      if (context.mounted) {
        _isExtracting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _connectionStore?.removeListener(_onConnectionChanged);
    super.dispose();
  }
}

class _DownloadItem {
  final HarborProject project;
  final HarborRepository repo;
  final HarborArtifact artifact;
  final String tag;

  const _DownloadItem({
    required this.project,
    required this.repo,
    required this.artifact,
    required this.tag,
  });

  String get key => '${project.name}|${repo.shortName}|${artifact.digest}|$tag';

  bool get isJar => ArtifactKindClassifier.isJarRepositoryName(repo.shortName);

  bool get isWeb => ArtifactKindClassifier.isWebRepositoryName(repo.shortName);

  bool get isApkApp =>
      ArtifactKindClassifier.isApkRepositoryName(repo.shortName);

  String get kindLabel =>
      ArtifactKindClassifier.kindLabelForRepositoryName(repo.shortName);
}

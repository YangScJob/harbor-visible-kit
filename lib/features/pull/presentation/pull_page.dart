import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_project.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_repository.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_artifact.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_archive_naming.dart';
import 'package:harbor_visible_kit/data/harbor/artifact_registry_service.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_kind_classifier.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';
import 'package:harbor_visible_kit/core/utils/platform_utils.dart';
import 'package:harbor_visible_kit/core/widgets/app_select.dart';
import 'package:harbor_visible_kit/core/widgets/app_notice.dart';
import 'package:harbor_visible_kit/core/widgets/action_reason_banner.dart';
import 'package:harbor_visible_kit/core/widgets/connection_status_badge.dart';
import 'package:harbor_visible_kit/core/widgets/labeled_field.dart';
import 'package:harbor_visible_kit/core/widgets/log_console.dart';
import 'package:harbor_visible_kit/core/widgets/progress_overlay.dart';
import 'package:harbor_visible_kit/core/widgets/section_title.dart';
import 'package:harbor_visible_kit/core/widgets/workflow_steps.dart';

part 'pull_page_controller.dart';
part 'pull_page_sections.dart';

/// Artifact pull and export page.
class PullPage extends StatefulWidget {
  const PullPage({super.key});

  @override
  State<PullPage> createState() => _PullPageState();
}

class _PullPageState extends State<PullPage> {
  late final _controller = _PullPageController();

  List<LogEntry> get _logs => _controller._logs;
  List<HarborProject> get _projects => _controller._projects;
  List<String> get _versionTags => _controller._versionTags;
  List<_DownloadItem> get _downloadItems => _controller._downloadItems;
  HarborProject? get _selectedProject => _controller._selectedProject;
  PushArtifactType? get _selectedArtifactType =>
      _controller._selectedArtifactType;
  HarborRepository? get _selectedRepo => _controller._selectedRepo;
  String? get _selectedVersionTag => _controller._selectedVersionTag;
  String get _savePath => _controller._savePath;
  bool get _isLoading => _controller._isLoading;
  bool get _isLoadingVersions => _controller._isLoadingVersions;
  bool get _isExtracting => _controller._isExtracting;
  String get _downloadQueueSummary => _controller._downloadQueueSummary;
  List<HarborRepository> get _filteredRepositories =>
      _controller._filteredRepositories;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _controller.start(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.bindConnectionStore(
      context,
      Provider.of<ConnectionStore>(context),
    );
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<List<HarborProject>?> _loadProjects({
    bool manual = false,
    bool logSuccess = true,
  }) {
    return _controller._loadProjects(
      context,
      manual: manual,
      logSuccess: logSuccess,
    );
  }

  Future<void> _loadRepositories(HarborProject project) {
    return _controller._loadRepositories(context, project);
  }

  Future<void> _loadArtifacts(HarborRepository repo) {
    return _controller._loadArtifacts(context, repo);
  }

  Future<void> _pickSavePath() {
    return _controller._pickSavePath();
  }

  void _selectVersionTag(String tag) {
    _controller._selectVersionTag(tag);
  }

  void _selectArtifactType(PushArtifactType type) {
    _controller._selectArtifactType(context, type);
  }

  Future<void> _addSelectedArtifactsToQueue() {
    return _controller._addSelectedArtifactsToQueue(context);
  }

  void _removeDownloadItem(_DownloadItem item) {
    _controller._removeDownloadItem(item);
  }

  void _clearDownloadQueue() {
    _controller._clearDownloadQueue();
  }

  String? _addToQueueDisabledReason() {
    return _controller._addToQueueDisabledReason();
  }

  String? _downloadDisabledReason(ConnectionStore store) {
    return _controller._downloadDisabledReason(store);
  }

  int _pullWorkflowStep(ConnectionStore store) {
    return _controller._pullWorkflowStep(store);
  }

  String _localDestinationFor(_DownloadItem item) {
    return _controller._localDestinationFor(item);
  }

  Future<void> _downloadQueuedArtifacts() {
    return _controller._downloadQueuedArtifacts(context);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConnectionStore>();
    final strings = context.l10n;

    return ProgressOverlay(
      visible: _isExtracting,
      message: strings.pick(
        '正在下载，日志持续更新',
        'Downloading. Logs continue to update',
      ),
      blocking: false,
      alignment: Alignment.topRight,
      child: LayoutBuilder(
        builder: (context, pageConstraints) {
          final pagePadding = pageConstraints.maxWidth < 860 ? 20.0 : 32.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(pagePadding),
            child: Builder(
              builder: (context) {
                final b = Theme.of(context).brightness;
                final addReason = _addToQueueDisabledReason();
                final downloadReason = _downloadDisabledReason(store);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header.
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download_rounded,
                          color: AppTheme.prim(b),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.pick('下行提取', 'Pull artifacts'),
                          style: TextStyle(
                            color: AppTheme.textP(b),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConnectionStatusBadge(isConnected: store.isConnected),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: store.isConnected && !_isLoading
                              ? () => _loadProjects(manual: true)
                              : null,
                          icon: _isLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.upl(b),
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(strings.pick('刷新列表', 'Refresh list')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.pick(
                        '浏览 Harbor 项目、仓库与版本，将多个组件的 JAR、Web、APP 或镜像加入清单后批量下载',
                        'Browse Harbor projects, repositories, and versions, add JAR, Web, APP, or image artifacts to the queue, then download them in batch',
                      ),
                      style: TextStyle(color: AppTheme.textM(b), fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    _buildPullWorkflow(store, b),
                    const SizedBox(height: 24),

                    if (!store.isConnected) ...[
                      _buildNotConnectedHint(b),
                    ] else ...[
                      // Selector card.
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: AppTheme.cardDeco(b),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(
                              icon: Icons.search_rounded,
                              title: strings.pick('仓库浏览', 'Repository browser'),
                              brightness: b,
                            ),
                            const SizedBox(height: 20),

                            Wrap(
                              spacing: 16,
                              runSpacing: 14,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: LabeledField(
                                    label: strings.pick(
                                      '项目空间',
                                      'Project namespace',
                                    ),
                                    brightness: b,
                                    child: _buildDropdown<HarborProject>(
                                      items: _projects,
                                      value: _selectedProject,
                                      hint: strings.pick(
                                        '选择项目空间',
                                        'Choose project namespace',
                                      ),
                                      itemLabel: (p) => strings.pick(
                                        '${p.name}  (${p.repoCount} 个仓库)',
                                        '${p.name}  (${p.repoCount} ${strings.plural(p.repoCount, 'repository', 'repositories')})',
                                      ),
                                      onChanged: (p) {
                                        if (p != null) _loadRepositories(p);
                                      },
                                      brightness: b,
                                      leadingIcon: Icons.folder_rounded,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: LabeledField(
                                    label: strings.pick(
                                      '制品类型',
                                      'Artifact type',
                                    ),
                                    brightness: b,
                                    child: _buildDropdown<PushArtifactType>(
                                      items: _selectedProject == null
                                          ? const []
                                          : PushArtifactType.values,
                                      value: _selectedArtifactType,
                                      hint: strings.pick(
                                        '选择制品类型',
                                        'Choose artifact type',
                                      ),
                                      itemLabel: strings.artifactLabel,
                                      onChanged: (type) {
                                        if (type == null || _isExtracting) {
                                          return;
                                        }
                                        _selectArtifactType(type);
                                      },
                                      brightness: b,
                                      leadingIcon: Icons.category_rounded,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 300,
                                  child: LabeledField(
                                    label: strings.pick(
                                      '组件名称',
                                      'Component name',
                                    ),
                                    brightness: b,
                                    child: _buildDropdown<HarborRepository>(
                                      items: _isExtracting
                                          ? const []
                                          : _filteredRepositories,
                                      value: _selectedRepo,
                                      hint: _selectedArtifactType == null
                                          ? strings.pick(
                                              '先选择制品类型',
                                              'Choose artifact type first',
                                            )
                                          : strings.pick(
                                              '选择组件',
                                              'Choose component',
                                            ),
                                      itemLabel: (r) =>
                                          '${r.shortName}  (${r.artifactCount})',
                                      onChanged: (r) {
                                        if (r != null) _loadArtifacts(r);
                                      },
                                      brightness: b,
                                      leadingIcon: Icons.inventory_2_rounded,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 240,
                                  child: LabeledField(
                                    label: strings.pick('版本选择', 'Version'),
                                    brightness: b,
                                    child: _buildSelectedArtifactSummary(b),
                                  ),
                                ),
                                SizedBox(
                                  height: 48,
                                  child: Tooltip(
                                    message:
                                        addReason ??
                                        strings.pick(
                                          '加入下载清单',
                                          'Add to download queue',
                                        ),
                                    child: OutlinedButton.icon(
                                      onPressed: addReason == null
                                          ? _addSelectedArtifactsToQueue
                                          : null,
                                      icon: const Icon(
                                        Icons.playlist_add_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        strings.pick('加入下载清单', 'Add to queue'),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (addReason != null) ...[
                              const SizedBox(height: 12),
                              _buildActionReason(addReason, b),
                            ],

                            if (_isLoading)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: LinearProgressIndicator(
                                  backgroundColor: AppTheme.div(b),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.upl(b),
                                  ),
                                  minHeight: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDownloadQueue(b),
                      const SizedBox(height: 20),

                      // Save path and extraction action.
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: AppTheme.cardDeco(b),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(
                              icon: Icons.save_alt_rounded,
                              title: strings.pick('下载位置', 'Download location'),
                              brightness: b,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bg(b),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.surfBorder(b),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.folder_open_rounded,
                                          size: 16,
                                          color: AppTheme.textM(b),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _savePath,
                                            style: TextStyle(
                                              color: AppTheme.textS(b),
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _isExtracting
                                      ? null
                                      : _pickSavePath,
                                  icon: const Icon(
                                    Icons.folder_outlined,
                                    size: 16,
                                  ),
                                  label: Text(strings.select),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (downloadReason != null) ...[
                              _buildActionReason(downloadReason, b),
                              const SizedBox(height: 10),
                            ],
                            Tooltip(
                              message:
                                  downloadReason ??
                                  strings.pick(
                                    '批量下载到本地',
                                    'Download batch locally',
                                  ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: downloadReason == null
                                      ? _downloadQueuedArtifacts
                                      : null,
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    strings.pick(
                                      '批量下载到本地',
                                      'Download batch locally',
                                    ),
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Logs.
                      LogConsole(
                        logs: _logs,
                        title: strings.pick('下载日志', 'Download logs'),
                        onClear: _controller._clearLogs,
                        maxHeight: 280,
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

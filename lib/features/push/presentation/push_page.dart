import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/app/state/push_config_store.dart';
import 'package:harbor_visible_kit/domain/push/harbor_push_config.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_project.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_artifact_type.dart';
import 'package:harbor_visible_kit/data/harbor/artifact_registry_service.dart';
import 'package:harbor_visible_kit/domain/artifacts/artifact_kind_classifier.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';
import 'package:harbor_visible_kit/domain/artifacts/push_target_resolver.dart';
import 'package:harbor_visible_kit/core/widgets/app_select.dart';
import 'package:harbor_visible_kit/core/widgets/app_notice.dart';
import 'package:harbor_visible_kit/core/widgets/action_reason_banner.dart';
import 'package:harbor_visible_kit/core/widgets/connection_status_badge.dart';
import 'package:harbor_visible_kit/core/widgets/drop_zone.dart';
import 'package:harbor_visible_kit/core/widgets/labeled_field.dart';
import 'package:harbor_visible_kit/core/widgets/log_console.dart';
import 'package:harbor_visible_kit/core/widgets/progress_overlay.dart';
import 'package:harbor_visible_kit/core/widgets/section_title.dart';
import 'package:harbor_visible_kit/core/widgets/workflow_steps.dart';

part 'push_page_controller.dart';
part 'push_page_sections.dart';

/// Artifact push page.
class PushPage extends StatefulWidget {
  const PushPage({super.key});

  @override
  State<PushPage> createState() => _PushPageState();
}

class _PushPageState extends State<PushPage> {
  late final _controller = _PushPageController();

  TextEditingController get _projectController =>
      _controller._projectController;
  TextEditingController get _tagController => _controller._tagController;
  TextEditingController get _customerCodeController =>
      _controller._customerCodeController;
  List<LogEntry> get _logs => _controller._logs;
  List<_SelectedArtifactFile> get _selectedFiles => _controller._selectedFiles;
  Map<String, TextEditingController> get _repositoryControllers =>
      _controller._repositoryControllers;
  PushArtifactType get _selectedArtifactType =>
      _controller._selectedArtifactType;
  List<HarborProject> get _projects => _controller._projects;
  bool get _isLoadingProjects => _controller._isLoadingProjects;
  List<String> get _tagSuggestions => _controller._tagSuggestions;
  bool get _isLoadingTagSuggestions => _controller._isLoadingTagSuggestions;
  bool get _isPushing => _controller._isPushing;
  String? get _selectedFileSummary => _controller._selectedFileSummary;
  String? get _customerCodeError => _controller._customerCodeError;

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

  Future<void> _loadTagSuggestions({bool manual = false}) {
    return _controller._loadTagSuggestions(context, manual: manual);
  }

  void _setArtifactType(PushArtifactType type) {
    _controller._setArtifactType(type);
  }

  void _onFilesSelected(List<String> paths) {
    _controller._onFilesSelected(paths);
  }

  IconData _artifactIcon(PushArtifactType type) {
    return _controller._artifactIcon(type);
  }

  void _addLog(String message, {LogLevel level = LogLevel.info}) {
    _controller._addLog(message, level: level);
  }

  List<PushTargetResolution> _buildPreviewTargets({
    required String registry,
    required String project,
  }) {
    return _controller._buildPreviewTargets(
      registry: registry,
      project: project,
    );
  }

  String? _pushDisabledReason(ConnectionStore store) {
    return _controller._pushDisabledReason(store);
  }

  List<String> _previewIssues(List<PushTargetResolution> targets) {
    return _controller._previewIssues(targets);
  }

  int _pushWorkflowStep(ConnectionStore store) {
    return _controller._pushWorkflowStep(store);
  }

  Future<void> _pushToHarbor() {
    return _controller._pushToHarbor(context);
  }

  HarborProject? _selectedProjectValue() {
    return _controller._selectedProjectValue();
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
    final configStore = context.watch<PushConfigStore>();
    final strings = context.l10n;

    _controller.syncSelectedConfig(
      configStore.selectedId,
      configStore.selectedConfig,
    );

    return ProgressOverlay(
      visible: _isPushing,
      message: strings.pick('正在推送，日志持续更新', 'Pushing. Logs continue to update'),
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
                final disabledReason = _pushDisabledReason(store);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header.
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          color: AppTheme.upl(b),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          strings.pick('上行推送', 'Push artifacts'),
                          style: TextStyle(
                            color: AppTheme.textP(b),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConnectionStatusBadge(isConnected: store.isConnected),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.pick(
                        '批量封装 JAR、Web、APP 或导入镜像归档，并按制品命名规则上行到 Harbor',
                        'Package JAR, Web, APP, or image archives in batches and push them to Harbor using artifact naming rules',
                      ),
                      style: TextStyle(color: AppTheme.textM(b), fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    _buildPushWorkflow(store, b),
                    const SizedBox(height: 24),

                    _buildBatchConfig(store, b),
                    const SizedBox(height: 20),
                    _buildFilePickerSection(b),
                    const SizedBox(height: 20),
                    _buildTargetPreviewPanel(
                      registry: store.connection.registry,
                      brightness: b,
                    ),
                    const SizedBox(height: 16),
                    if (disabledReason != null) ...[
                      _buildActionReason(disabledReason, b),
                      const SizedBox(height: 10),
                    ],
                    Tooltip(
                      message:
                          disabledReason ??
                          strings.pick('开始批量上行推送', 'Start batch push'),
                      child: SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: disabledReason == null
                              ? _pushToHarbor
                              : null,
                          icon: const Icon(
                            Icons.cloud_upload_rounded,
                            size: 20,
                          ),
                          label: Text(
                            strings.pick('批量上行推送', 'Batch push'),
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Logs.
                    LogConsole(
                      logs: _logs,
                      title: strings.pick('推送日志', 'Push logs'),
                      onClear: _controller._clearLogs,
                      maxHeight: 300,
                    ),
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

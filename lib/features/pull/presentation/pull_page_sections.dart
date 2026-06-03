part of 'pull_page.dart';

extension _PullPageSections on _PullPageState {
  Widget _buildPullWorkflow(ConnectionStore store, Brightness b) {
    final strings = context.l10n;
    final currentStep = _pullWorkflowStep(store);
    final steps = [
      WorkflowStepData(
        icon: Icons.link_rounded,
        title: strings.pick('连接', 'Connection'),
        subtitle: store.isConnected
            ? store.connection.registry
            : strings.disconnected,
      ),
      WorkflowStepData(
        icon: Icons.search_rounded,
        title: strings.pick('浏览', 'Browse'),
        subtitle: _selectedVersionTag ?? strings.pick('选择版本', 'Choose version'),
      ),
      WorkflowStepData(
        icon: Icons.playlist_add_check_rounded,
        title: strings.pick('清单', 'Queue'),
        subtitle: _downloadItems.isEmpty
            ? strings.pick('等待加入', 'Waiting to add')
            : strings.pick(
                '${_downloadItems.length} 项',
                '${_downloadItems.length} ${strings.plural(_downloadItems.length, 'item', 'items')}',
              ),
      ),
      WorkflowStepData(
        icon: Icons.download_rounded,
        title: strings.pick('下载', 'Download'),
        subtitle: _savePath,
      ),
    ];

    return WorkflowSteps(currentStep: currentStep, steps: steps, brightness: b);
  }

  Widget _buildActionReason(String reason, Brightness b) {
    return ActionReasonBanner(reason: reason, brightness: b);
  }

  Widget _buildNotConnectedHint(Brightness b) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: AppTheme.cardDeco(b),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.link_off_rounded, size: 48, color: AppTheme.textM(b)),
            const SizedBox(height: 16),
            Text(
              strings.pick(
                '请先在「连接配置」页面连接 Harbor',
                'Connect to Harbor on the Connection page first',
              ),
              style: TextStyle(color: AppTheme.textS(b), fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              strings.pick(
                '连接成功后即可浏览和下载制品',
                'After connecting, you can browse and download artifacts',
              ),
              style: TextStyle(color: AppTheme.textM(b), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedArtifactSummary(Brightness b) {
    final strings = context.l10n;
    final hint = _selectedArtifactType == null
        ? strings.pick('先选择制品类型', 'Choose artifact type first')
        : (_isLoadingVersions || (_isLoading && _selectedRepo != null)
              ? strings.pick('正在加载版本列表...', 'Loading version list...')
              : strings.pick('选择版本', 'Choose version'));

    return AppSelect<String>(
      items: _isExtracting || _isLoadingVersions ? const [] : _versionTags,
      value: _selectedVersionTag,
      hint: hint,
      itemLabel: (tag) => tag,
      onChanged: (tag) {
        if (tag == null) return;
        _selectVersionTag(tag);
      },
      leadingIcon: Icons.checklist_rounded,
      itemIcon: Icons.label_rounded,
      brightness: b,
      tooltip: _selectedArtifactType == null
          ? strings.pick('请先选择制品类型', 'Choose artifact type first')
          : strings.pick('选择版本', 'Choose version'),
    );
  }

  Widget _buildDownloadQueue(Brightness b) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDeco(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SectionTitle(
                icon: Icons.playlist_add_check_rounded,
                title: strings.pick('下载清单', 'Download queue'),
                brightness: b,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _downloadQueueSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textM(b), fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: _downloadItems.isEmpty || _isExtracting
                    ? null
                    : _clearDownloadQueue,
                icon: const Icon(Icons.delete_sweep_rounded, size: 17),
                label: Text(strings.clear),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_downloadItems.isEmpty)
            Text(
              strings.pick(
                '从上方选择项目、组件和版本后加入清单；可跨多个组件混合加入 JAR、Web、APP 与镜像。',
                'Choose a project, component, and version above, then add them to the queue. You can mix JAR, Web, APP, and image artifacts across components.',
              ),
              style: TextStyle(color: AppTheme.textM(b), fontSize: 13),
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.bg(b).withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.surfBorder(b)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < _downloadItems.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: AppTheme.div(b)),
                        _buildDownloadItemRow(_downloadItems[i], b),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadItemRow(_DownloadItem item, Brightness b) {
    final strings = context.l10n;
    final icon = item.isJar
        ? Icons.description_rounded
        : item.isWeb
        ? Icons.web_asset_rounded
        : item.isApkApp
        ? Icons.android_rounded
        : Icons.inventory_2_rounded;
    final color = item.isJar
        ? AppTheme.upl(b)
        : item.isWeb
        ? AppTheme.suc(b)
        : item.isApkApp
        ? AppTheme.suc(b)
        : AppTheme.prim(b);
    final destination = _localDestinationFor(item);
    final kindLabel = strings.kindLabelForRepositoryName(item.repo.shortName);

    return Semantics(
      container: true,
      label: strings.pick(
        '$kindLabel ${item.project.name}/${item.repo.shortName}:${item.tag}，保存到 $destination',
        '$kindLabel ${item.project.name}/${item.repo.shortName}:${item.tag}, save to $destination',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            _KindPill(
              label: kindLabel,
              color: color,
              background: color.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.project.name}/${item.repo.shortName}:${item.tag}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textP(b),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.artifact.pushTime.isEmpty
                        ? item.artifact.digest
                        : item.artifact.pushTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textM(b), fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Tooltip(
                    message: destination,
                    child: Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.textM(b), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              item.artifact.readableSize,
              style: TextStyle(color: AppTheme.textS(b), fontSize: 12.5),
            ),
            IconButton(
              onPressed: _isExtracting ? null : () => _removeDownloadItem(item),
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: strings.pick('移出下载清单', 'Remove from download queue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required List<T> items,
    required T? value,
    required String hint,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    Brightness? brightness,
    IconData? leadingIcon,
  }) {
    final b = brightness ?? Theme.of(context).brightness;
    return AppSelect<T>(
      items: items,
      value: value,
      hint: hint,
      itemLabel: itemLabel,
      onChanged: onChanged,
      leadingIcon: leadingIcon,
      brightness: b,
    );
  }
}

class _KindPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _KindPill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

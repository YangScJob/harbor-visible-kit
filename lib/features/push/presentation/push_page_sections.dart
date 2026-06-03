part of 'push_page.dart';

extension _PushPageSections on _PushPageState {
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

  void _showCreateProjectDialog(BuildContext context) {
    final strings = context.l10n;
    final nameController = TextEditingController();
    bool isPublic = true;
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final b = Theme.of(dialogContext).brightness;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surf(b),
              title: Text(
                strings.pick('新建项目空间', 'Create project namespace'),
                style: TextStyle(color: AppTheme.textP(b)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: AppTheme.textP(b)),
                    decoration: InputDecoration(
                      labelText: strings.pick('项目名称', 'Project name'),
                      hintText: strings.pick(
                        '仅限小写字母、数字、下划线、中划线',
                        'Lowercase letters, numbers, underscores, and hyphens only',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        strings.pick('访问级别: ', 'Access level: '),
                        style: TextStyle(
                          color: AppTheme.textS(b),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(strings.pick('公开', 'Public')),
                        selected: isPublic,
                        showCheckmark: false,
                        onSelected: (val) =>
                            setDialogState(() => isPublic = val),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(strings.pick('私有', 'Private')),
                        selected: !isPublic,
                        showCheckmark: false,
                        onSelected: (val) =>
                            setDialogState(() => isPublic = !val),
                      ),
                    ],
                  ),
                  if (isCreating) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(strings.cancel),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = nameController.text.trim().toLowerCase();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.pick(
                                    '项目名称不能为空',
                                    'Project name cannot be empty',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          // Validate the project name format.
                          if (!RegExp(
                                r'^[a-z0-9]+[a-z0-9_.-]*[a-z0-9]$',
                              ).hasMatch(name) &&
                              name.length > 1) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.pick(
                                    '项目名称格式不正确(以小写字母/数字开头结尾，支持_.-)',
                                    'Project name format is invalid. Start and end with a lowercase letter or number; supports _.-',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isCreating = true);
                          try {
                            final api = dialogContext.read<HarborApiService>();
                            await api.createProject(name, isPublic: isPublic);

                            _addLog(
                              strings.pick(
                                '成功新建项目空间 "$name"',
                                'Created project namespace "$name"',
                              ),
                              level: LogLevel.success,
                            );

                            // Reload the project list.
                            await _loadProjects();

                            // Select the newly created project.
                            _projectController.text = name;

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.pick(
                                      '已新建并选中项目空间 "$name"',
                                      'Created and selected project namespace "$name"',
                                    ),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() => isCreating = false);
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    strings.pick(
                                      '创建失败: $e',
                                      'Create failed: $e',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: Text(strings.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaveAsDialog(BuildContext context) {
    final strings = context.l10n;
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final b = Theme.of(context).brightness;
        return AlertDialog(
          backgroundColor: AppTheme.surf(b),
          title: Text(
            strings.pick('另存为新配置模板', 'Save as new config template'),
            style: TextStyle(color: AppTheme.textP(b)),
          ),
          content: TextField(
            controller: nameController,
            style: TextStyle(color: AppTheme.textP(b)),
            decoration: InputDecoration(
              labelText: strings.pick('模板名称', 'Template name'),
              hintText: strings.pick('请输入模板名称', 'Enter template name'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final store = context.read<PushConfigStore>();
                  store.addConfig(
                    name: name,
                    project: _projectController.text.trim(),
                    artifact: '',
                    tag: _tagController.text.trim(),
                    artifactType: _selectedArtifactType,
                    customerCode: _customerCodeController.text.trim(),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.pick('已保存模板 "$name"', 'Saved template "$name"'),
                      ),
                    ),
                  );
                }
              },
              child: Text(strings.confirm),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTemplateSelector(BuildContext context) {
    final store = context.watch<PushConfigStore>();
    final strings = context.l10n;
    final configs = store.configs;
    final selectedId = store.selectedId;
    final b = Theme.of(context).brightness;
    final selectedConfig =
        selectedId == null || !configs.any((config) => config.id == selectedId)
        ? null
        : configs.firstWhere((config) => config.id == selectedId);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.pick('模板: ', 'Template: '),
          style: TextStyle(color: AppTheme.textS(b), fontSize: 13),
        ),
        const SizedBox(width: 6),
        AppSelect<HarborPushConfig>(
          width: 170,
          menuWidth: 190,
          compact: true,
          items: configs,
          value: selectedConfig,
          hint: strings.pick('选择模板', 'Choose template'),
          itemLabel: (config) => strings.templateName(config.name),
          leadingIcon: Icons.settings_rounded,
          brightness: b,
          tooltip: strings.pick('选择模板', 'Choose template'),
          onChanged: (config) {
            if (config != null) {
              store.selectConfig(config.id);
            }
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.save_as_rounded, size: 18, color: AppTheme.prim(b)),
          tooltip: strings.pick('另存为新模板', 'Save as new template'),
          onPressed: () => _showSaveAsDialog(context),
          splashRadius: 20,
        ),
        IconButton(
          icon: Icon(Icons.save_rounded, size: 18, color: AppTheme.suc(b)),
          tooltip: strings.pick('更新当前模板', 'Update current template'),
          onPressed: selectedId != null
              ? () {
                  store.updateConfig(
                    selectedId,
                    project: _projectController.text.trim(),
                    artifact: '',
                    tag: _tagController.text.trim(),
                    artifactType: _selectedArtifactType,
                    customerCode: _customerCodeController.text.trim(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.pick('已成功保存至当前模板', 'Saved to current template'),
                      ),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              : null,
          splashRadius: 20,
        ),
        IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: configs.length > 1 ? AppTheme.err(b) : AppTheme.textM(b),
          ),
          tooltip: strings.pick('删除当前模板', 'Delete current template'),
          onPressed: configs.length > 1 && selectedId != null
              ? () {
                  store.deleteConfig(selectedId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.pick('模板已删除', 'Template deleted')),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              : null,
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildArtifactTypeField(Brightness b) {
    final strings = context.l10n;
    return LabeledField(
      label: strings.pick('制品类型', 'Artifact type'),
      brightness: b,
      child: _buildDropdown<PushArtifactType>(
        items: PushArtifactType.values,
        value: _selectedArtifactType,
        hint: strings.pick('选择制品类型', 'Choose artifact type'),
        itemLabel: strings.artifactLabel,
        onChanged: (type) {
          if (type != null) _setArtifactType(type);
        },
        brightness: b,
        leadingIcon: Icons.category_rounded,
      ),
    );
  }

  Widget _buildProjectField(ConnectionStore store, Brightness b) {
    final strings = context.l10n;
    return LabeledField(
      label: strings.pick('项目空间', 'Project namespace'),
      brightness: b,
      child: Builder(
        builder: (context) {
          if (store.isConnected) {
            return Row(
              children: [
                Expanded(
                  child: _buildDropdown<HarborProject>(
                    items: _projects,
                    value: _selectedProjectValue(),
                    hint: _isLoadingProjects
                        ? strings.pick('正在加载项目列表...', 'Loading project list...')
                        : strings.pick(
                            '选择产品级项目空间，例如 release',
                            'Choose a product-level project namespace, such as release',
                          ),
                    itemLabel: (p) => strings.pick(
                      '${p.name}  (${p.repoCount} 个仓库)',
                      '${p.name}  (${p.repoCount} ${strings.plural(p.repoCount, 'repository', 'repositories')})',
                    ),
                    onChanged: (p) {
                      if (p != null) {
                        _projectController.text = p.name;
                      }
                    },
                    brightness: b,
                    leadingIcon: Icons.folder_rounded,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: _isLoadingProjects
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.upl(b),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  tooltip: strings.pick('刷新项目空间', 'Refresh project namespaces'),
                  onPressed: _isLoadingProjects
                      ? null
                      : () => _loadProjects(manual: true),
                  splashRadius: 20,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: strings.pick('新建项目空间', 'Create project namespace'),
                  onPressed: () => _showCreateProjectDialog(context),
                  splashRadius: 20,
                ),
              ],
            );
          }
          return _buildDropdown<HarborProject>(
            items: const [],
            value: null,
            hint: strings.pick(
              '连接后选择项目空间',
              'Choose a project namespace after connecting',
            ),
            itemLabel: (p) => p.name,
            onChanged: (_) {},
            brightness: b,
            leadingIcon: Icons.folder_rounded,
          );
        },
      ),
    );
  }

  Widget _buildVersionTagField(ConnectionStore store, Brightness b) {
    final strings = context.l10n;
    return LabeledField(
      label: strings.pick('版本标签', 'Version tag'),
      brightness: b,
      child: TextField(
        controller: _tagController,
        decoration: InputDecoration(
          hintText: _isLoadingTagSuggestions
              ? strings.pick('正在加载已有版本...', 'Loading existing versions...')
              : strings.pick(
                  '例如 3.4.0 或 3.4.0.1',
                  'For example, 3.4.0 or 3.4.0.1',
                ),
          prefixIcon: const Icon(Icons.label_rounded, size: 18),
          suffixIcon: _buildVersionTagActions(store, b),
        ),
      ),
    );
  }

  Widget _buildCustomerCodeField(Brightness b) {
    final strings = context.l10n;
    return LabeledField(
      label: strings.pick('标签后缀(可选)', 'Tag suffix (optional)'),
      brightness: b,
      child: TextField(
        controller: _customerCodeController,
        decoration: InputDecoration(
          hintText: strings.pick(
            '例如 customer-a、hotfix-1',
            'For example, customer-a or hotfix-1',
          ),
          errorText: _customerCodeError,
          prefixIcon: const Icon(Icons.badge_rounded, size: 18),
        ),
      ),
    );
  }

  Widget _buildVersionTagActions(ConnectionStore store, Brightness b) {
    final strings = context.l10n;
    final canRefresh =
        store.isConnected &&
        _projectController.text.trim().isNotEmpty &&
        !_isLoadingTagSuggestions;
    final canSelect = _tagSuggestions.isNotEmpty && !_isLoadingTagSuggestions;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingTagSuggestions) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.upl(b),
            ),
          ),
          const SizedBox(width: 4),
        ],
        PopupMenuButton<String>(
          tooltip: strings.pick('选择已有版本标签', 'Choose an existing version tag'),
          enabled: canSelect,
          color: AppTheme.surf(b),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: BorderSide(color: AppTheme.div(b)),
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: canSelect ? AppTheme.textS(b) : AppTheme.textM(b),
          ),
          onSelected: (tag) {
            _tagController.text = tag;
            _tagController.selection = TextSelection.collapsed(
              offset: tag.length,
            );
          },
          itemBuilder: (context) {
            return _tagSuggestions.map((tag) {
              final selected = tag == _tagController.text.trim();
              return PopupMenuItem<String>(
                value: tag,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primDim(b) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_outline_rounded,
                        size: 16,
                        color: selected ? AppTheme.prim(b) : AppTheme.textM(b),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.prim(b)
                                : AppTheme.textP(b),
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: selected ? AppTheme.prim(b) : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
        ),
        IconButton(
          tooltip: strings.pick('刷新版本标签', 'Refresh version tags'),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          onPressed: canRefresh
              ? () => _loadTagSuggestions(manual: true)
              : null,
        ),
      ],
    );
  }

  Widget _buildPushWorkflow(ConnectionStore store, Brightness b) {
    final strings = context.l10n;
    final currentStep = _pushWorkflowStep(store);
    final steps = [
      WorkflowStepData(
        icon: Icons.link_rounded,
        title: strings.pick('连接', 'Connection'),
        subtitle: store.isConnected
            ? store.connection.registry
            : strings.disconnected,
      ),
      WorkflowStepData(
        icon: Icons.tune_rounded,
        title: strings.pick('批次', 'Batch'),
        subtitle: _projectController.text.trim().isEmpty
            ? strings.pick('选择项目空间', 'Choose project namespace')
            : _projectController.text.trim(),
      ),
      WorkflowStepData(
        icon: Icons.file_present_rounded,
        title: strings.pick('文件', 'Files'),
        subtitle: _selectedFiles.isEmpty
            ? strings.pick('等待选择', 'Waiting for selection')
            : strings.pick(
                '${_selectedFiles.length} 个文件',
                '${_selectedFiles.length} ${strings.plural(_selectedFiles.length, 'file', 'files')}',
              ),
      ),
      WorkflowStepData(
        icon: Icons.fact_check_rounded,
        title: strings.pick('预览', 'Preview'),
        subtitle: currentStep >= 4
            ? strings.pick('目标已确认', 'Targets confirmed')
            : strings.pick('校验目标', 'Validate targets'),
      ),
    ];

    return WorkflowSteps(currentStep: currentStep, steps: steps, brightness: b);
  }

  Widget _buildActionReason(String reason, Brightness b) {
    return ActionReasonBanner(reason: reason, brightness: b);
  }

  Widget _buildBatchFieldGrid(ConnectionStore store, Brightness b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final firstRow = [
          _buildArtifactTypeField(b),
          _buildProjectField(store, b),
        ];
        final secondRow = [
          _buildVersionTagField(store, b),
          _buildCustomerCodeField(b),
        ];

        if (narrow) {
          return Column(
            children: [
              for (final field in [...firstRow, ...secondRow]) ...[
                field,
                if (field != secondRow.last) const SizedBox(height: 16),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < firstRow.length; i++) ...[
                  Expanded(child: firstRow[i]),
                  if (i != firstRow.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < secondRow.length; i++) ...[
                  Expanded(child: secondRow[i]),
                  if (i != secondRow.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBatchConfig(ConnectionStore store, Brightness b) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDeco(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionTitle(
                icon: Icons.tune_rounded,
                title: strings.pick('发版批次', 'Release batch'),
                brightness: b,
              ),
              _buildTemplateSelector(context),
            ],
          ),
          const SizedBox(height: 16),
          _buildBatchFieldGrid(store, b),
          const SizedBox(height: 12),
          Text(
            strings.pick(
              '项目空间按产品级使用；标签后缀只写入最终标签，不自动拆分项目空间。',
              'Use project namespaces at product level. The tag suffix is only appended to the final tag and does not split project namespaces automatically.',
            ),
            style: TextStyle(color: AppTheme.textM(b), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerSection(Brightness b) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDeco(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.file_present_rounded,
            title: strings.pick('选择制品文件', 'Choose artifact files'),
            brightness: b,
          ),
          const SizedBox(height: 8),
          Text(
            strings.pick(
              '当前批次: ${strings.artifactLabel(_selectedArtifactType)}，${strings.acceptedFileDescription(_selectedArtifactType)}',
              'Current batch: ${strings.artifactLabel(_selectedArtifactType)}, ${strings.acceptedFileDescription(_selectedArtifactType)}',
            ),
            style: TextStyle(color: AppTheme.textM(b), fontSize: 12),
          ),
          const SizedBox(height: 16),
          DropZone(
            onFilesSelected: _onFilesSelected,
            allowedExtensions: _selectedArtifactType.allowedExtensions,
            selectedFileNames: _selectedFiles.map((file) => file.name).toList(),
            selectedFileSummary: _selectedFileSummary,
            emptyTitle: strings.pick(
              '拖拽${strings.artifactShortLabel(_selectedArtifactType)}文件至此',
              'Drag ${strings.artifactShortLabel(_selectedArtifactType)} files here',
            ),
            emptySubtitle: strings.acceptedFileDescription(
              _selectedArtifactType,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetPreviewPanel({
    required String registry,
    required Brightness brightness,
  }) {
    final b = brightness;
    final strings = context.l10n;
    final project = _projectController.text.trim();
    final targets = _buildPreviewTargets(registry: registry, project: project);
    final invalidCount = targets.where((target) => !target.isValid).length;
    final issues = _previewIssues(targets);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDeco(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SectionTitle(
                icon: Icons.fact_check_rounded,
                title: strings.pick('目标预览', 'Target preview'),
                brightness: b,
              ),
              const Spacer(),
              if (_selectedFiles.isNotEmpty)
                _StatusPill(
                  label: invalidCount == 0
                      ? strings.pick('全部通过', 'All passed')
                      : strings.pick(
                          '$invalidCount 项待处理',
                          '$invalidCount pending ${strings.plural(invalidCount, 'item', 'items')}',
                        ),
                  color: invalidCount == 0 ? AppTheme.suc(b) : AppTheme.err(b),
                  background: invalidCount == 0
                      ? AppTheme.sucDim(b)
                      : AppTheme.errDim(b),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (issues.isNotEmpty) ...[
            _buildPreviewIssueSummary(issues, b),
            const SizedBox(height: 14),
          ],
          if (_selectedFiles.isEmpty)
            Text(
              strings.pick(
                '先完成批次设置并选择文件后，这里会逐项显示仓库名、版本、最终标签和 Harbor 地址。',
                'After completing batch settings and choosing files, this area shows each repository name, version, final tag, and Harbor address.',
              ),
              style: TextStyle(color: AppTheme.textM(b), fontSize: 13),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 920) {
                  return _buildPreviewCards(targets, b);
                }
                return _buildPreviewTable(targets, b, constraints.maxWidth);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewIssueSummary(List<String> issues, Brightness b) {
    final strings = context.l10n;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errDim(b).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.err(b).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.err(b),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.pick(
                    '需要处理 ${issues.length} 项',
                    '${issues.length} ${strings.plural(issues.length, 'item', 'items')} need attention',
                  ),
                  style: TextStyle(
                    color: AppTheme.err(b),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final issue in issues.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  issue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textS(b),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            if (issues.length > 3)
              Text(
                strings.pick(
                  '还有 ${issues.length - 3} 项，请在下方预览中逐项修正。',
                  '${issues.length - 3} more ${strings.plural(issues.length - 3, 'item', 'items')}. Fix them one by one in the preview below.',
                ),
                style: TextStyle(color: AppTheme.textM(b), fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTable(
    List<PushTargetResolution> targets,
    Brightness b,
    double maxWidth,
  ) {
    final tableWidth = maxWidth < 1040 ? 1040.0 : maxWidth;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: tableWidth),
        child: Column(
          children: [
            _buildPreviewHeader(b),
            const SizedBox(height: 6),
            ...targets.map((target) => _buildPreviewRow(target, b)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCards(List<PushTargetResolution> targets, Brightness b) {
    return Column(
      children: [
        for (final target in targets) ...[
          _buildPreviewCard(target, b),
          if (target != targets.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildPreviewCard(PushTargetResolution target, Brightness b) {
    final strings = context.l10n;
    final isValid = target.isValid;
    final repositoryController = _repositoryControllers[target.file.path];
    final statusText = isValid
        ? strings.pick('通过', 'Passed')
        : target.errors.map(strings.targetError).join(strings.pick('；', '; '));

    return Semantics(
      container: true,
      label: strings.pick(
        '${target.file.name}，${isValid ? '目标校验通过' : statusText}',
        '${target.file.name}, ${isValid ? 'target validation passed' : statusText}',
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isValid
              ? AppTheme.bg(b).withValues(alpha: 0.55)
              : AppTheme.errDim(b).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isValid
                ? AppTheme.surfBorder(b)
                : AppTheme.err(b).withValues(alpha: 0.34),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _artifactIcon(target.artifactType),
                  color: isValid ? AppTheme.upl(b) : AppTheme.err(b),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    target.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textP(b),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(
                  label: isValid
                      ? strings.pick('通过', 'Passed')
                      : strings.pick('待处理', 'Pending'),
                  color: isValid ? AppTheme.suc(b) : AppTheme.err(b),
                  background: isValid ? AppTheme.sucDim(b) : AppTheme.errDim(b),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (target.requiresRepositoryOverride) ...[
              TextField(
                controller: repositoryController,
                style: TextStyle(color: AppTheme.textP(b), fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: strings.pick('仓库名', 'Repository name'),
                  hintText: strings.pick('填写仓库名', 'Enter repository name'),
                  prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildPreviewMeta(
                  strings.pick('类型', 'Type'),
                  strings.artifactShortLabel(target.artifactType),
                  b,
                ),
                _buildPreviewMeta(
                  strings.pick('仓库', 'Repository'),
                  target.repository ?? '-',
                  b,
                ),
                _buildPreviewMeta(
                  strings.pick('版本', 'Version'),
                  target.version ?? '-',
                  b,
                ),
                _buildPreviewMeta('Tag', target.tag ?? '-', b),
              ],
            ),
            const SizedBox(height: 10),
            _buildPreviewMeta(
              strings.pick('Harbor 地址', 'Harbor address'),
              target.imageTag ?? '-',
              b,
            ),
            if (!isValid) ...[
              const SizedBox(height: 10),
              Text(
                statusText,
                style: TextStyle(
                  color: AppTheme.err(b),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMeta(String label, String value, Brightness b) {
    return Tooltip(
      message: value,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: AppTheme.textM(b),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: AppTheme.textS(b),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewHeader(Brightness b) {
    final strings = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bg(b),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.surfBorder(b)),
      ),
      child: Row(
        children: [
          _PreviewCell(
            strings.pick('文件名', 'File name'),
            width: 210,
            brightness: b,
            isHeader: true,
          ),
          _PreviewCell(
            strings.pick('类型', 'Type'),
            width: 86,
            brightness: b,
            isHeader: true,
          ),
          _PreviewCell(
            strings.pick('仓库名', 'Repository'),
            width: 170,
            brightness: b,
            isHeader: true,
          ),
          _PreviewCell(
            strings.pick('版本', 'Version'),
            width: 104,
            brightness: b,
            isHeader: true,
          ),
          _PreviewCell(
            strings.pick('最终 Tag', 'Final Tag'),
            width: 152,
            brightness: b,
            isHeader: true,
          ),
          _PreviewCell(
            strings.pick('Harbor 地址', 'Harbor address'),
            width: 270,
            brightness: b,
            isHeader: true,
          ),
          _PreviewCell(
            strings.pick('状态', 'Status'),
            width: 150,
            brightness: b,
            isHeader: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(PushTargetResolution target, Brightness b) {
    final strings = context.l10n;
    final isValid = target.isValid;
    final repositoryController = _repositoryControllers[target.file.path];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isValid
            ? AppTheme.bg(b).withValues(alpha: 0.55)
            : AppTheme.errDim(b).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isValid
              ? AppTheme.surfBorder(b)
              : AppTheme.err(b).withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        children: [
          _PreviewCell(target.file.name, width: 210, brightness: b),
          _PreviewCell(
            strings.artifactShortLabel(target.artifactType),
            width: 86,
            brightness: b,
          ),
          SizedBox(
            width: 170,
            child: target.requiresRepositoryOverride
                ? TextField(
                    controller: repositoryController,
                    style: TextStyle(color: AppTheme.textP(b), fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: strings.pick('填写仓库名', 'Enter repository name'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                    ),
                  )
                : _PreviewText(target.repository ?? '-', brightness: b),
          ),
          _PreviewCell(target.version ?? '-', width: 104, brightness: b),
          _PreviewCell(target.tag ?? '-', width: 152, brightness: b),
          _PreviewCell(target.imageTag ?? '-', width: 270, brightness: b),
          _PreviewCell(
            isValid
                ? strings.pick('通过', 'Passed')
                : target.errors
                      .map(strings.targetError)
                      .join(strings.pick('；', '; ')),
            width: 150,
            brightness: b,
            color: isValid ? AppTheme.suc(b) : AppTheme.err(b),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  final String text;
  final double width;
  final Brightness brightness;
  final bool isHeader;
  final Color? color;
  final int maxLines;

  const _PreviewCell(
    this.text, {
    required this.width,
    required this.brightness,
    this.isHeader = false,
    this.color,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _PreviewText(
        text,
        brightness: brightness,
        isHeader: isHeader,
        color: color,
        maxLines: maxLines,
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  final String text;
  final Brightness brightness;
  final bool isHeader;
  final Color? color;
  final int maxLines;

  const _PreviewText(
    this.text, {
    required this.brightness,
    this.isHeader = false,
    this.color,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:
              color ??
              (isHeader
                  ? AppTheme.textS(brightness)
                  : AppTheme.textP(brightness)),
          fontSize: isHeader ? 12 : 12.5,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

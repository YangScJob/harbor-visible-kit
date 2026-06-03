import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';

/// File drop zone component.
///
/// Supports drag-and-drop plus click selection for allowed extensions.
class DropZone extends StatefulWidget {
  final ValueChanged<List<String>> onFilesSelected;
  final List<String> allowedExtensions;
  final List<String> selectedFileNames;
  final String? selectedFileSummary;
  final String emptyTitle;
  final String emptySubtitle;

  const DropZone({
    super.key,
    required this.onFilesSelected,
    this.allowedExtensions = const ['jar', 'tar.gz', 'tar', 'tgz'],
    this.selectedFileNames = const [],
    this.selectedFileSummary,
    this.emptyTitle = '拖拽 JAR 或 TAR.GZ 文件至此',
    this.emptySubtitle = '或 点击多选文件',
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  bool _isFocused = false;
  bool _isHovered = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _pickerExtensions,
      allowMultiple: true,
    );
    if (result != null) {
      final paths = result.files
          .map((file) => file.path)
          .whereType<String>()
          .toList();
      _selectFiles(paths);
    }
  }

  List<String> get _pickerExtensions {
    final extensions = <String>{};
    for (final ext in widget.allowedExtensions) {
      final normalized = _normalizeExtension(ext);
      extensions.add(normalized);

      final dotIndex = normalized.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < normalized.length - 1) {
        extensions.add(normalized.substring(dotIndex + 1));
      }
    }
    return extensions.toList();
  }

  String _normalizeExtension(String ext) {
    return ext.startsWith('.')
        ? ext.substring(1).toLowerCase()
        : ext.toLowerCase();
  }

  bool _isAllowedPath(String path) {
    final lowerPath = path.toLowerCase();
    return widget.allowedExtensions.any((ext) {
      return lowerPath.endsWith('.${_normalizeExtension(ext)}');
    });
  }

  void _selectFiles(List<String> paths) {
    if (paths.isEmpty) return;

    final allowedPaths = <String>[];
    final rejectedNames = <String>[];
    for (final path in paths) {
      if (_isAllowedPath(path)) {
        allowedPaths.add(path);
      } else {
        rejectedNames.add(path.split('/').last);
      }
    }

    if (allowedPaths.isNotEmpty) {
      widget.onFilesSelected(allowedPaths);
    }

    if (rejectedNames.isNotEmpty) {
      final strings = context.l10n;
      final rejectedText = rejectedNames.take(3).join('、');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.pick(
              '已跳过 $rejectedText，仅支持 ${widget.allowedExtensions.join("/")} 格式的文件',
              'Skipped $rejectedText. Only ${widget.allowedExtensions.join("/")} files are supported',
            ),
          ),
          backgroundColor: AppTheme.err(Theme.of(context).brightness),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.selectedFileNames.isNotEmpty;
    final brightness = Theme.of(context).brightness;
    final strings = context.l10n;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final highlighted = _isDragging || _isFocused || _isHovered;
    final semanticsLabel = hasFile
        ? strings.pick(
            '${widget.selectedFileNames.length} 个文件已选择，点击重新选择',
            '${widget.selectedFileNames.length} ${strings.plural(widget.selectedFileNames.length, 'file', 'files')} selected. Click to choose again',
          )
        : '${widget.emptyTitle}，${widget.emptySubtitle}';

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _pickFile();
              return null;
            },
          ),
        },
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _isFocused = value),
          onShowHoverHighlight: (value) => setState(() => _isHovered = value),
          child: Semantics(
            button: true,
            label: semanticsLabel,
            hint: strings.pick(
              '按 Enter 或 Space 选择文件，也可以拖拽文件到此区域',
              'Press Enter or Space to choose files, or drag files into this area',
            ),
            child: DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (detail) {
                setState(() => _isDragging = false);
                if (detail.files.isNotEmpty) {
                  final paths = detail.files.map((file) => file.path).toList();
                  _selectFiles(paths);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickFile,
                child: AnimatedContainer(
                  duration: AppTheme.animNormal,
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? AppTheme.uplDim(brightness).withValues(alpha: 0.68)
                        : hasFile
                        ? AppTheme.sucDim(brightness).withValues(alpha: 0.38)
                        : highlighted
                        ? AppTheme.surfL(brightness).withValues(alpha: 0.52)
                        : AppTheme.bg(brightness),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: _isDragging || _isFocused
                          ? AppTheme.upl(brightness)
                          : hasFile
                          ? AppTheme.suc(brightness).withValues(alpha: 0.34)
                          : highlighted
                          ? AppTheme.upl(brightness).withValues(alpha: 0.36)
                          : AppTheme.surfBorder(brightness),
                      width: _isDragging || _isFocused ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasFile) ...[
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.suc(brightness),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.pick(
                            '${widget.selectedFileNames.length} 个文件已选择',
                            '${widget.selectedFileNames.length} ${strings.plural(widget.selectedFileNames.length, 'file', 'files')} selected',
                          ),
                          style: TextStyle(
                            color: AppTheme.textP(brightness),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.selectedFileNames.take(4).map((name) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.description_rounded,
                                  color: AppTheme.textM(brightness),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.textS(brightness),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (widget.selectedFileNames.length > 4)
                          Text(
                            strings.pick(
                              '还有 ${widget.selectedFileNames.length - 4} 个文件...',
                              '${widget.selectedFileNames.length - 4} more ${strings.plural(widget.selectedFileNames.length - 4, 'file', 'files')}...',
                            ),
                            style: TextStyle(
                              color: AppTheme.textM(brightness),
                              fontSize: 12,
                            ),
                          ),
                        if (widget.selectedFileSummary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.selectedFileSummary!,
                            style: TextStyle(
                              color: AppTheme.textM(brightness),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          strings.pick('点击重新选择', 'Click to choose again'),
                          style: TextStyle(
                            color: AppTheme.upl(brightness),
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, _) {
                            final opacity = disableAnimations
                                ? 0.72
                                : _pulseAnimation.value;
                            return Icon(
                              _isDragging
                                  ? Icons.file_download_rounded
                                  : Icons.cloud_upload_outlined,
                              color: _isDragging
                                  ? AppTheme.upl(brightness)
                                  : AppTheme.textM(
                                      brightness,
                                    ).withValues(alpha: opacity),
                              size: 48,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDragging
                              ? strings.pick('松手即可添加文件', 'Release to add files')
                              : widget.emptyTitle,
                          style: TextStyle(
                            color: _isDragging
                                ? AppTheme.upl(brightness)
                                : AppTheme.textS(brightness),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.emptySubtitle,
                          style: TextStyle(
                            color: AppTheme.textM(brightness),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

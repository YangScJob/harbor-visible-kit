import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';

/// Log entry level.
enum LogLevel { info, success, warning, error }

/// Single log entry.
class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime time;

  LogEntry({required this.message, this.level = LogLevel.info, DateTime? time})
    : time = time ?? DateTime.now();

  String get timeStr {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color levelColor(Brightness b) {
    switch (level) {
      case LogLevel.info:
        return AppTheme.textS(b);
      case LogLevel.success:
        return AppTheme.suc(b);
      case LogLevel.warning:
        return AppTheme.warn(b);
      case LogLevel.error:
        return AppTheme.err(b);
    }
  }

  /// Kept for backward compat (always dark)
  Color get color => levelColor(Brightness.dark);

  String get prefix {
    switch (level) {
      case LogLevel.info:
        return '▸';
      case LogLevel.success:
        return '✓';
      case LogLevel.warning:
        return '⚠';
      case LogLevel.error:
        return '✗';
    }
  }
}

/// Real-time log console component.
class LogConsole extends StatefulWidget {
  final List<LogEntry> logs;
  final String? title;
  final VoidCallback? onClear;
  final double? maxHeight;

  const LogConsole({
    super.key,
    required this.logs,
    this.title,
    this.onClear,
    this.maxHeight,
  });

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel? _levelFilter;
  late int _lastLogCount;

  List<LogEntry> get _visibleLogs {
    final filter = _levelFilter;
    if (filter == null) return widget.logs;
    return widget.logs.where((log) => log.level == filter).toList();
  }

  String get _filterLabel {
    final filter = _levelFilter;
    final strings = context.l10n;
    if (filter == null) return strings.pick('全部', 'All');
    return filter.localizedLabel(strings);
  }

  @override
  void initState() {
    super.initState();
    _lastLogCount = widget.logs.length;
    if (widget.logs.isNotEmpty) {
      _scrollToBottom();
    }
  }

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasNewLogs = widget.logs.length > _lastLogCount;
    _lastLogCount = widget.logs.length;
    if (_autoScroll && hasNewLogs) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppTheme.animFast,
        curve: Curves.easeOut,
      );
    });
  }

  void _copyAll() {
    final strings = context.l10n;
    final text = _visibleLogs
        .map((e) => '[${e.timeStr}] ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    final brightness = Theme.of(context).brightness;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.pick('日志已复制到剪贴板', 'Logs copied to clipboard')),
        backgroundColor: AppTheme.surfL(brightness),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }

  TextSpan _buildLogSpan(Brightness brightness, List<LogEntry> logs) {
    const baseStyle = TextStyle(fontSize: 12, height: 1.6);
    final children = <InlineSpan>[];

    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final logColor = log.levelColor(brightness);
      children.addAll([
        TextSpan(
          text: '${log.timeStr} ',
          style: TextStyle(color: AppTheme.textM(brightness)),
        ),
        TextSpan(
          text: '${log.prefix} ',
          style: TextStyle(color: logColor),
        ),
        TextSpan(
          text: log.message,
          style: TextStyle(color: logColor),
        ),
      ]);
      if (i != logs.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(style: baseStyle, children: children);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = context.l10n;
    final consoleBg = AppTheme.terminalBg(brightness);
    final visibleLogs = _visibleLogs;

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight ?? 250),
      decoration: BoxDecoration(
        color: consoleBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.surfBorder(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surf(brightness).withValues(alpha: 0.55),
              border: Border(
                bottom: BorderSide(color: AppTheme.surfBorder(brightness)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 14,
                  color: AppTheme.upl(brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title ?? strings.pick('操作日志', 'Operation log'),
                  style: TextStyle(
                    color: AppTheme.textS(brightness),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.logs.isNotEmpty) ...[
                  _buildFilterMenu(brightness),
                  const SizedBox(width: 6),
                  _buildToolButton(
                    _autoScroll
                        ? Icons.vertical_align_bottom_rounded
                        : Icons.vertical_align_center_rounded,
                    _autoScroll
                        ? strings.pick('自动滚动已开启', 'Auto-scroll enabled')
                        : strings.pick('自动滚动已关闭', 'Auto-scroll disabled'),
                    () => setState(() {
                      _autoScroll = !_autoScroll;
                      if (_autoScroll) _scrollToBottom();
                    }),
                    brightness,
                    active: _autoScroll,
                  ),
                  const SizedBox(width: 4),
                  _buildToolButton(
                    Icons.copy_rounded,
                    strings.pick('复制全部', 'Copy all'),
                    _copyAll,
                    brightness,
                  ),
                  const SizedBox(width: 4),
                  if (widget.onClear != null)
                    _buildToolButton(
                      Icons.delete_outline_rounded,
                      strings.clear,
                      widget.onClear!,
                      brightness,
                    ),
                ],
              ],
            ),
          ),

          // Log content.
          Flexible(
            child: widget.logs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        strings.pick('等待操作...', 'Waiting for action...'),
                        style: TextStyle(
                          color: AppTheme.textM(brightness),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : visibleLogs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        strings.pick('当前筛选下暂无日志', 'No logs for this filter'),
                        style: TextStyle(
                          color: AppTheme.textM(brightness),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: 1,
                    itemBuilder: (context, index) {
                      return SelectionArea(
                        child: SelectableText.rich(
                          _buildLogSpan(brightness, visibleLogs),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    Brightness brightness, {
    bool active = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 15,
        color: active ? AppTheme.upl(brightness) : AppTheme.textS(brightness),
      ),
    );
  }

  Widget _buildFilterMenu(Brightness brightness) {
    final strings = context.l10n;
    return PopupMenuButton<LogLevel?>(
      tooltip: strings.pick('筛选日志级别', 'Filter log level'),
      onSelected: (level) => setState(() => _levelFilter = level),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<LogLevel?>>[
          _buildFilterMenuItem(
            null,
            strings.pick('全部日志', 'All logs'),
            brightness,
          ),
          const PopupMenuDivider(height: 4),
          for (final level in LogLevel.values)
            _buildFilterMenuItem(
              level,
              level.localizedLabel(strings),
              brightness,
            ),
        ];
        return items;
      },
      child: Semantics(
        button: true,
        label: strings.pick(
          '筛选日志级别，当前 $_filterLabel',
          'Filter log level, current $_filterLabel',
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surf(brightness),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.surfBorder(brightness)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 15,
                color: _levelFilter == null
                    ? AppTheme.textS(brightness)
                    : AppTheme.upl(brightness),
              ),
              const SizedBox(width: 5),
              Text(
                _filterLabel,
                style: TextStyle(
                  color: AppTheme.textS(brightness),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<LogLevel?> _buildFilterMenuItem(
    LogLevel? value,
    String label,
    Brightness brightness,
  ) {
    final selected = _levelFilter == value;
    final color = value?.colorFor(brightness) ?? AppTheme.textS(brightness);
    return PopupMenuItem<LogLevel?>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: selected
                ? AppTheme.upl(brightness)
                : AppTheme.textM(brightness),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

extension on LogLevel {
  Color colorFor(Brightness b) {
    switch (this) {
      case LogLevel.info:
        return AppTheme.textS(b);
      case LogLevel.success:
        return AppTheme.suc(b);
      case LogLevel.warning:
        return AppTheme.warn(b);
      case LogLevel.error:
        return AppTheme.err(b);
    }
  }

  String localizedLabel(AppStrings strings) {
    switch (this) {
      case LogLevel.info:
        return strings.pick('信息', 'Info');
      case LogLevel.success:
        return strings.pick('成功', 'Success');
      case LogLevel.warning:
        return strings.pick('警告', 'Warning');
      case LogLevel.error:
        return strings.pick('错误', 'Error');
    }
  }
}

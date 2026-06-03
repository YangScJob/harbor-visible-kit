import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';

enum AppNoticeType { success, error, warning, info }

class AppNotice {
  AppNotice._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void success(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(context, type: AppNoticeType.success, title: title, message: message);
  }

  static void error(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(context, type: AppNoticeType.error, title: title, message: message);
  }

  static void warning(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    show(context, type: AppNoticeType.warning, title: title, message: message);
  }

  static void show(
    BuildContext context, {
    required AppNoticeType type,
    required String title,
    String? message,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final b = Theme.of(context).brightness;
    final style = _AppNoticeStyle.resolve(type, b);
    final duration = type == AppNoticeType.error
        ? const Duration(seconds: 6)
        : const Duration(seconds: 4);

    _hide();
    _entry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        final horizontalInset = media.size.width >= 720 ? 24.0 : 16.0;
        final noticeWidth = media.size.width >= 720
            ? 520.0
            : media.size.width - horizontalInset * 2;

        return Positioned(
          top: media.padding.top + 16,
          right: horizontalInset,
          width: noticeWidth,
          child: _AppNoticeCard(
            title: title,
            message: message,
            brightness: b,
            style: style,
            onClose: _hide,
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, _hide);
  }

  static String messageFrom(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  static void _hide() {
    _timer?.cancel();
    _timer = null;
    if (_entry?.mounted ?? false) {
      _entry?.remove();
    }
    _entry = null;
  }
}

class _AppNoticeCard extends StatefulWidget {
  final String title;
  final String? message;
  final Brightness brightness;
  final _AppNoticeStyle style;
  final VoidCallback onClose;

  const _AppNoticeCard({
    required this.title,
    required this.message,
    required this.brightness,
    required this.style,
    required this.onClose,
  });

  @override
  State<_AppNoticeCard> createState() => _AppNoticeCardState();
}

class _AppNoticeCardState extends State<_AppNoticeCard> {
  bool _expanded = false;

  String get _message => widget.message?.trim() ?? '';
  bool get _hasMessage => _message.isNotEmpty;
  bool get _canExpand => _message.length > 72 || _message.contains('\n');

  void _copyMessage() {
    final strings = context.l10n;
    final text = _hasMessage ? '${widget.title}\n$_message' : widget.title;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(strings.pick('通知详情已复制', 'Notification details copied')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfL(widget.brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brightness;
    final strings = context.l10n;

    return Focus(
      autofocus: true,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                widget.onClose();
                return null;
              },
            ),
          },
          child: Semantics(
            container: true,
            liveRegion: true,
            label: _hasMessage ? '${widget.title}。$_message' : widget.title,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surf(b),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: widget.style.color.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.style.background,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: widget.style.color.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Icon(
                          widget.style.icon,
                          color: widget.style.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: AppTheme.textP(b),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_hasMessage) ...[
                              const SizedBox(height: 4),
                              Text(
                                _message,
                                maxLines: _expanded ? 8 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textS(b),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (_canExpand) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _expanded = !_expanded),
                                icon: Icon(
                                  _expanded
                                      ? Icons.unfold_less_rounded
                                      : Icons.unfold_more_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  _expanded
                                      ? strings.pick('收起详情', 'Collapse details')
                                      : strings.pick('展开详情', 'Expand details'),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_hasMessage)
                        IconButton(
                          tooltip: strings.pick(
                            '复制通知详情',
                            'Copy notification details',
                          ),
                          icon: Icon(
                            Icons.copy_rounded,
                            color: AppTheme.textM(b),
                            size: 17,
                          ),
                          onPressed: _copyMessage,
                        ),
                      IconButton(
                        tooltip: strings.pick('关闭通知', 'Close notification'),
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppTheme.textM(b),
                          size: 18,
                        ),
                        onPressed: widget.onClose,
                      ),
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

class _AppNoticeStyle {
  final IconData icon;
  final Color color;
  final Color background;

  const _AppNoticeStyle({
    required this.icon,
    required this.color,
    required this.background,
  });

  static _AppNoticeStyle resolve(AppNoticeType type, Brightness brightness) {
    switch (type) {
      case AppNoticeType.success:
        return _AppNoticeStyle(
          icon: Icons.check_circle_rounded,
          color: AppTheme.suc(brightness),
          background: AppTheme.sucDim(brightness),
        );
      case AppNoticeType.error:
        return _AppNoticeStyle(
          icon: Icons.error_rounded,
          color: AppTheme.err(brightness),
          background: AppTheme.errDim(brightness),
        );
      case AppNoticeType.warning:
        return _AppNoticeStyle(
          icon: Icons.warning_rounded,
          color: AppTheme.warn(brightness),
          background: AppTheme.warnDim(brightness),
        );
      case AppNoticeType.info:
        return _AppNoticeStyle(
          icon: Icons.info_rounded,
          color: AppTheme.upl(brightness),
          background: AppTheme.uplDim(brightness),
        );
    }
  }
}

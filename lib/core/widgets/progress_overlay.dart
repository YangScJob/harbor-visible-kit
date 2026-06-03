import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';

/// Global loading progress overlay.
class ProgressOverlay extends StatelessWidget {
  final bool visible;
  final String? message;
  final Widget child;
  final bool blocking;
  final Alignment alignment;

  const ProgressOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message,
    this.blocking = true,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = context.l10n;
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: AppTheme.animNormal,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: message ?? strings.processing,
                child: blocking
                    ? ModalBarrier(
                        color: AppTheme.bg(brightness).withValues(alpha: 0.7),
                        dismissible: false,
                      )
                    : IgnorePointer(
                        child: Align(
                          alignment: alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: _ProgressCard(
                              message: message,
                              brightness: brightness,
                              compact: true,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        if (visible && blocking)
          Center(
            child: Semantics(
              liveRegion: true,
              label: message ?? strings.processing,
              child: _ProgressCard(message: message, brightness: brightness),
            ),
          ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String? message;
  final Brightness brightness;
  final bool compact;

  const _ProgressCard({
    required this.message,
    required this.brightness,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorSize = compact ? 22.0 : 36.0;
    final textStyle = TextStyle(
      color: AppTheme.textS(brightness),
      fontSize: compact ? 12.5 : 14,
      fontWeight: compact ? FontWeight.w600 : FontWeight.w400,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 30,
        vertical: compact ? 10 : 22,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surf(brightness),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfBorder(brightness)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: indicatorSize,
                  height: indicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.upl(brightness),
                    ),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(width: 10),
                  Text(message!, style: textStyle),
                ],
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: indicatorSize,
                  height: indicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.upl(brightness),
                    ),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(message!, style: textStyle, textAlign: TextAlign.center),
                ],
              ],
            ),
    );
  }
}

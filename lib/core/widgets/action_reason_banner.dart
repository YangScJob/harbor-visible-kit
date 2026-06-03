import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/theme/app_theme.dart';

class ActionReasonBanner extends StatelessWidget {
  final String reason;
  final Brightness? brightness;

  const ActionReasonBanner({super.key, required this.reason, this.brightness});

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.warnDim(b).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.warn(b).withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.warn(b), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: AppTheme.textS(b),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

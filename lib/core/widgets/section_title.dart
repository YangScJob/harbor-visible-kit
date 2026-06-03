import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Brightness? brightness;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return Row(
      children: [
        Icon(icon, color: AppTheme.prim(b), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textP(b),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

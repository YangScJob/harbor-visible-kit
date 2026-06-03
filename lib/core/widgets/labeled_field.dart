import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/theme/app_theme.dart';

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final Brightness? brightness;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textS(b),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

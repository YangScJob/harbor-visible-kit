import 'package:flutter/material.dart';

class AppIconMark extends StatelessWidget {
  const AppIconMark({super.key, this.size = 36});

  static const assetPath = 'assets/app_icon/harbor_visible_kit_icon_1024.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image(
        image: const ExactAssetImage(assetPath),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.anchor_rounded,
            size: size,
            color: Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}

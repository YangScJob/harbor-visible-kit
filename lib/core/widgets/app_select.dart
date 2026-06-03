import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.items,
    required this.value,
    required this.hint,
    required this.itemLabel,
    required this.onChanged,
    this.leadingIcon,
    this.itemIcon,
    this.brightness,
    this.width,
    this.menuWidth,
    this.compact = false,
    this.tooltip,
  });

  final List<T> items;
  final T? value;
  final String hint;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final IconData? leadingIcon;
  final IconData? itemIcon;
  final Brightness? brightness;
  final double? width;
  final double? menuWidth;
  final bool compact;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    final strings = context.l10n;
    final selectedLabel = value == null ? hint : itemLabel(value as T);
    final enabled = items.isNotEmpty;
    final height = compact ? 32.0 : 48.0;
    final horizontalPadding = compact ? 10.0 : 14.0;
    final fontSize = compact ? 13.0 : 13.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final resolvedWidth = width ?? boundedWidth;
        final resolvedMenuWidth = menuWidth ?? resolvedWidth ?? 180.0;

        return PopupMenuButton<T>(
          enabled: enabled,
          tooltip: '',
          padding: EdgeInsets.zero,
          color: AppTheme.surf(b),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          constraints: BoxConstraints(
            minWidth: resolvedMenuWidth,
            maxWidth: resolvedMenuWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: BorderSide(color: AppTheme.surfBorder(b)),
          ),
          onSelected: onChanged,
          itemBuilder: (context) {
            return items.map((item) {
              final selected = item == value;
              return PopupMenuItem<T>(
                value: item,
                height: compact ? 38 : 44,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: _AppSelectMenuItem<T>(
                  selected: selected,
                  label: itemLabel(item),
                  icon: itemIcon ?? leadingIcon,
                  brightness: b,
                  compact: compact,
                ),
              );
            }).toList();
          },
          child: Semantics(
            button: true,
            enabled: enabled,
            label: selectedLabel,
            hint: enabled
                ? (tooltip ?? strings.expandSelect)
                : strings.noOptions,
            child: SizedBox(
              width: resolvedWidth,
              height: height,
              child: _AppSelectButton(
                label: selectedLabel,
                hasValue: value != null,
                enabled: enabled,
                leadingIcon: leadingIcon,
                brightness: b,
                horizontalPadding: horizontalPadding,
                fontSize: fontSize,
                compact: compact,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppSelectButton extends StatelessWidget {
  const _AppSelectButton({
    required this.label,
    required this.hasValue,
    required this.enabled,
    required this.leadingIcon,
    required this.brightness,
    required this.horizontalPadding,
    required this.fontSize,
    required this.compact,
  });

  final String label;
  final bool hasValue;
  final bool enabled;
  final IconData? leadingIcon;
  final Brightness brightness;
  final double horizontalPadding;
  final double fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = brightness;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.surf(b) : AppTheme.bg(b),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: hasValue
              ? AppTheme.surfBorder(b)
              : AppTheme.div(b).withValues(alpha: 0.85),
        ),
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: compact ? 16 : 18,
              color: hasValue ? AppTheme.prim(b) : AppTheme.textM(b),
            ),
            SizedBox(width: compact ? 8 : 12),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasValue ? AppTheme.textP(b) : AppTheme.textM(b),
                fontSize: fontSize,
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 12),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: compact ? 18 : 20,
            color: enabled ? AppTheme.textS(b) : AppTheme.textM(b),
          ),
        ],
      ),
    );
  }
}

class _AppSelectMenuItem<T> extends StatelessWidget {
  const _AppSelectMenuItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.brightness,
    required this.compact,
  });

  final bool selected;
  final String label;
  final IconData? icon;
  final Brightness brightness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = brightness;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primDim(b) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: selected
              ? AppTheme.prim(b).withValues(alpha: 0.22)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 16 : 17,
              color: selected ? AppTheme.upl(b) : AppTheme.textM(b),
            ),
            SizedBox(width: compact ? 8 : 10),
          ],
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppTheme.textP(b) : AppTheme.textP(b),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Icon(
            Icons.check_rounded,
            size: compact ? 16 : 17,
            color: selected ? AppTheme.upl(b) : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

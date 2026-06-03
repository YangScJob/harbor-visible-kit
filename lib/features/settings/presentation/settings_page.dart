import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/state/locale_store.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';
import 'package:harbor_visible_kit/app/state/theme_store.dart';
import 'package:harbor_visible_kit/core/widgets/app_icon_mark.dart';

/// Settings page.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final themeStore = context.watch<ThemeStore>();
    final localeStore = context.watch<LocaleStore>();
    final strings = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_rounded,
                color: AppTheme.prim(brightness),
                size: 26,
              ),
              const SizedBox(width: 12),
              Text(
                strings.settingsTitle,
                style: TextStyle(
                  color: AppTheme.textP(brightness),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.settingsDescription,
            style: TextStyle(color: AppTheme.textM(brightness), fontSize: 14),
          ),
          const SizedBox(height: 28),
          _buildCard(
            brightness: brightness,
            title: strings.appearance,
            icon: Icons.palette_rounded,
            headerTrailing: _buildThemeSelector(
              context,
              brightness,
              themeStore,
            ),
          ),
          const SizedBox(height: 20),
          _buildCard(
            brightness: brightness,
            title: strings.language,
            icon: Icons.translate_rounded,
            headerTrailing: _buildLanguageSelector(
              context,
              brightness,
              localeStore,
            ),
          ),
          const SizedBox(height: 20),
          _buildCard(
            brightness: brightness,
            title: strings.about,
            icon: Icons.info_outline_rounded,
            child: _buildAboutCard(context, brightness),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Brightness brightness,
    required String title,
    required IconData icon,
    Widget? child,
    Widget? headerTrailing,
  }) {
    return AnimatedContainer(
      duration: AppTheme.themeTransition,
      curve: AppTheme.themeCurve,
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.cardDeco(brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.prim(brightness), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textP(brightness),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (headerTrailing != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: headerTrailing,
                  ),
                ),
              ],
            ],
          ),
          if (child != null) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    Brightness brightness,
    ThemeStore store,
  ) {
    return AnimatedContainer(
      duration: AppTheme.themeTransition,
      curve: AppTheme.themeCurve,
      constraints: const BoxConstraints(maxWidth: 390),
      decoration: BoxDecoration(
        color: AppTheme.bg(brightness),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfBorder(brightness)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < AppThemeMode.values.length; i++) ...[
            Expanded(
              child: _buildThemeOption(
                context,
                brightness,
                store,
                AppThemeMode.values[i],
                isFirst: i == 0,
                isLast: i == AppThemeMode.values.length - 1,
              ),
            ),
            if (i != AppThemeMode.values.length - 1)
              AnimatedContainer(
                duration: AppTheme.themeTransition,
                curve: AppTheme.themeCurve,
                width: 1,
                height: 48,
                color: AppTheme.div(brightness),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    Brightness brightness,
    ThemeStore store,
    AppThemeMode mode, {
    required bool isFirst,
    required bool isLast,
  }) {
    final strings = context.l10n;
    final selected = store.mode == mode;
    final icon = switch (mode) {
      AppThemeMode.system => Icons.brightness_auto_rounded,
      AppThemeMode.light => Icons.light_mode_rounded,
      AppThemeMode.dark => Icons.dark_mode_rounded,
    };
    final borderRadius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(AppTheme.radiusMd) : Radius.zero,
      right: isLast ? const Radius.circular(AppTheme.radiusMd) : Radius.zero,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => store.setMode(mode),
        child: AnimatedContainer(
          duration: AppTheme.themeTransition,
          curve: AppTheme.themeCurve,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primDim(brightness).withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppTheme.themeTransition,
                curve: AppTheme.themeCurve,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.uplDim(brightness)
                      : AppTheme.div(brightness).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? AppTheme.upl(brightness)
                      : AppTheme.textS(brightness),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strings.themeModeLabel(mode),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: AppTheme.textP(brightness),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    Brightness brightness,
    LocaleStore store,
  ) {
    return AnimatedContainer(
      duration: AppTheme.themeTransition,
      curve: AppTheme.themeCurve,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: AppTheme.bg(brightness),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfBorder(brightness)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < AppLanguage.values.length; i++) ...[
            Expanded(
              child: _buildLanguageOption(
                context,
                brightness,
                store,
                AppLanguage.values[i],
                isFirst: i == 0,
                isLast: i == AppLanguage.values.length - 1,
              ),
            ),
            if (i != AppLanguage.values.length - 1)
              AnimatedContainer(
                duration: AppTheme.themeTransition,
                curve: AppTheme.themeCurve,
                width: 1,
                height: 48,
                color: AppTheme.div(brightness),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    Brightness brightness,
    LocaleStore store,
    AppLanguage language, {
    required bool isFirst,
    required bool isLast,
  }) {
    final strings = context.l10n;
    final selected = store.language == language;
    final borderRadius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(AppTheme.radiusMd) : Radius.zero,
      right: isLast ? const Radius.circular(AppTheme.radiusMd) : Radius.zero,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => store.setLanguage(language),
        child: AnimatedContainer(
          duration: AppTheme.themeTransition,
          curve: AppTheme.themeCurve,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primDim(brightness).withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: borderRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppTheme.themeTransition,
                curve: AppTheme.themeCurve,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.uplDim(brightness)
                      : AppTheme.div(brightness).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: selected
                      ? AppTheme.upl(brightness)
                      : AppTheme.textS(brightness),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  strings.languageLabel(language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textP(brightness),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, Brightness brightness) {
    final strings = context.l10n;
    return Row(
      children: [
        const AppIconMark(size: 36),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Harbor Visible Kit',
              style: TextStyle(
                color: AppTheme.textP(brightness),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              strings.versionInfo,
              style: TextStyle(color: AppTheme.textM(brightness), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

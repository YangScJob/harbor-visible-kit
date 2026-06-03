import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/core/widgets/app_icon_mark.dart';

/// Left sidebar navigation.
class SidebarNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const SidebarNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConnectionStore>();
    final brightness = Theme.of(context).brightness;
    final strings = context.l10n;
    final items = [
      _NavItem(icon: Icons.link_rounded, label: strings.navConnection),
      _NavItem(icon: Icons.cloud_upload_rounded, label: strings.navPush),
      _NavItem(icon: Icons.cloud_download_rounded, label: strings.navPull),
      _NavItem(icon: Icons.settings_rounded, label: strings.navSettings),
    ];

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _NavStepIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _NavStepIntent(-1),
        SingleActivator(LogicalKeyboardKey.home): _NavBoundaryIntent(false),
        SingleActivator(LogicalKeyboardKey.end): _NavBoundaryIntent(true),
      },
      child: Actions(
        actions: {
          _NavStepIntent: CallbackAction<_NavStepIntent>(
            onInvoke: (intent) {
              final next = (selectedIndex + intent.delta).clamp(
                0,
                items.length - 1,
              );
              onItemSelected(next);
              return null;
            },
          ),
          _NavBoundaryIntent: CallbackAction<_NavBoundaryIntent>(
            onInvoke: (intent) {
              onItemSelected(intent.last ? items.length - 1 : 0);
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: AnimatedContainer(
            duration: AppTheme.themeTransition,
            curve: AppTheme.themeCurve,
            width: AppTheme.sidebarWidth,
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? AppTheme.background
                  : AppTheme.surf(brightness),
              border: Border(
                right: BorderSide(color: AppTheme.surfBorder(brightness)),
              ),
            ),
            child: Column(
              children: [
                // Logo area.
                const SizedBox(height: 22),
                _buildLogo(brightness, strings),
                const SizedBox(height: 22),

                // Navigation items.
                ...List.generate(items.length, (i) {
                  return _buildNavItem(
                    i,
                    items[i],
                    selected: i == selectedIndex,
                    brightness: brightness,
                    strings: strings,
                  );
                }),

                const Spacer(),

                // Footer connection status.
                _buildConnectionStatus(store, brightness, strings),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Brightness brightness, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const AppIconMark(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harbor Visible Kit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textP(brightness),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.appSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textM(brightness),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    _NavItem item, {
    required bool selected,
    required Brightness brightness,
    required AppStrings strings,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        hint: strings.pressEnterToOpen,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            focusColor: AppTheme.uplDim(brightness).withValues(alpha: 0.52),
            hoverColor: AppTheme.surfL(brightness).withValues(alpha: 0.56),
            onTap: () => onItemSelected(index),
            child: AnimatedContainer(
              duration: AppTheme.themeTransition,
              curve: AppTheme.themeCurve,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primDim(brightness).withValues(alpha: 0.76)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: selected
                      ? AppTheme.upl(brightness).withValues(alpha: 0.32)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AppTheme.themeTransition,
                    curve: AppTheme.themeCurve,
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.upl(brightness)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    item.icon,
                    size: 20,
                    color: selected
                        ? AppTheme.upl(brightness)
                        : AppTheme.textM(brightness),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.textP(brightness)
                          : AppTheme.textS(brightness),
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(
    ConnectionStore store,
    Brightness brightness,
    AppStrings strings,
  ) {
    final connected = store.isConnected;
    return Semantics(
      container: true,
      liveRegion: true,
      label: connected
          ? strings.harborConnected(store.connection.registry)
          : strings.harborDisconnected,
      child: AnimatedContainer(
        duration: AppTheme.themeTransition,
        curve: AppTheme.themeCurve,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: connected
              ? AppTheme.sucDim(brightness).withValues(alpha: 0.62)
              : AppTheme.surf(brightness),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: connected
                ? AppTheme.suc(brightness).withValues(alpha: 0.28)
                : AppTheme.surfBorder(brightness),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected
                    ? AppTheme.suc(brightness)
                    : AppTheme.textM(brightness),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? strings.connected : strings.disconnected,
                    style: TextStyle(
                      color: connected
                          ? AppTheme.suc(brightness)
                          : AppTheme.textM(brightness),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (connected && store.connection.host.isNotEmpty)
                    Text(
                      store.connection.registry,
                      style: TextStyle(
                        color: AppTheme.textM(brightness),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavStepIntent extends Intent {
  final int delta;

  const _NavStepIntent(this.delta);
}

class _NavBoundaryIntent extends Intent {
  final bool last;

  const _NavBoundaryIntent(this.last);
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

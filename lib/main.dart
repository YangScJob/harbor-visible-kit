import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';
import 'package:harbor_visible_kit/features/connection/presentation/connection_page.dart';
import 'package:harbor_visible_kit/features/push/presentation/push_page.dart';
import 'package:harbor_visible_kit/features/pull/presentation/pull_page.dart';
import 'package:harbor_visible_kit/features/settings/presentation/settings_page.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/app/state/locale_store.dart';
import 'package:harbor_visible_kit/app/state/push_config_store.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';
import 'package:harbor_visible_kit/app/state/theme_store.dart';
import 'package:harbor_visible_kit/app/shell/sidebar_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the desktop window manager.
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1160, 760),
    minimumSize: Size(960, 640),
    center: true,
    backgroundColor: AppTheme.background,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Harbor Visible Kit',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const HarborVisibleKitApp());
}

class HarborVisibleKitApp extends StatelessWidget {
  const HarborVisibleKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => HarborApiService()),
        ChangeNotifierProvider(
          create: (context) =>
              ConnectionStore(context.read<HarborApiService>())..loadSaved(),
        ),
        ChangeNotifierProvider(create: (_) => PushConfigStore()..loadSaved()),
        ChangeNotifierProvider(create: (_) => ThemeStore()),
        ChangeNotifierProvider(create: (_) => LocaleStore()),
      ],
      child: Consumer2<ThemeStore, LocaleStore>(
        builder: (context, themeStore, localeStore, _) {
          return MaterialApp(
            title: 'Harbor Visible Kit',
            debugShowCheckedModeBanner: false,
            locale: localeStore.locale,
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeStore.themeMode,
            themeAnimationDuration: AppTheme.themeTransition,
            themeAnimationCurve: AppTheme.themeCurve,
            home: const MainShell(),
          );
        },
      ),
    );
  }
}

/// Main shell with a custom title bar, sidebar, and content area.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;

  static const _pages = <Widget>[
    ConnectionPage(),
    PushPage(),
    PullPage(),
    SettingsPage(),
  ];

  static const double _captionButtonWidth = 46;

  bool get _usesCustomCaptionButtons => Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    if (!mounted || _isMaximized == isMaximized) return;
    setState(() => _isMaximized = isMaximized);
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowRestore() {
    _syncWindowState();
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncWindowState();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: AppTheme.themeTransition,
        curve: AppTheme.themeCurve,
        color: AppTheme.bg(brightness),
        child: Column(
          children: [
            // Custom draggable title bar.
            _buildTitleBar(context),

            // Main content area.
            Expanded(
              child: Row(
                children: [
                  SidebarNav(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (i) => setState(() => _selectedIndex = i),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final strings = context.l10n;
    return AnimatedContainer(
      duration: AppTheme.themeTransition,
      curve: AppTheme.themeCurve,
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.surf(brightness),
        border: Border(
          bottom: BorderSide(color: AppTheme.surfBorder(brightness)),
        ),
      ),
      child: Stack(
        children: [
          DragToMoveArea(
            child: Center(
              child: Text(
                'Harbor Visible Kit',
                style: TextStyle(
                  color: AppTheme.textM(brightness),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_usesCustomCaptionButtons)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _captionButtonWidth * 3,
                height: double.infinity,
                child: Row(
                  children: [
                    Tooltip(
                      message: strings.pick('最小化', 'Minimize'),
                      child: SizedBox(
                        width: _captionButtonWidth,
                        height: double.infinity,
                        child: WindowCaptionButton.minimize(
                          brightness: brightness,
                          onPressed: () => windowManager.minimize(),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: _isMaximized
                          ? strings.pick('还原', 'Restore')
                          : strings.pick('最大化', 'Maximize'),
                      child: SizedBox(
                        width: _captionButtonWidth,
                        height: double.infinity,
                        child: _isMaximized
                            ? WindowCaptionButton.unmaximize(
                                brightness: brightness,
                                onPressed: () => windowManager.unmaximize(),
                              )
                            : WindowCaptionButton.maximize(
                                brightness: brightness,
                                onPressed: _toggleMaximize,
                              ),
                      ),
                    ),
                    Tooltip(
                      message: strings.pick('关闭', 'Close'),
                      child: SizedBox(
                        width: _captionButtonWidth,
                        height: double.infinity,
                        child: WindowCaptionButton.close(
                          brightness: brightness,
                          onPressed: () => windowManager.close(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

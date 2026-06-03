import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:harbor_visible_kit/features/pull/presentation/pull_page.dart';
import 'package:harbor_visible_kit/features/push/presentation/push_page.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';
import 'package:harbor_visible_kit/app/state/push_config_store.dart';
import 'package:harbor_visible_kit/app/shell/sidebar_nav.dart';

void main() {
  Widget appWithStores(Widget child) {
    final api = HarborApiService();
    return MultiProvider(
      providers: [
        Provider<HarborApiService>.value(value: api),
        ChangeNotifierProvider<ConnectionStore>(
          create: (_) => ConnectionStore(api),
        ),
        ChangeNotifierProvider<PushConfigStore>(
          create: (_) => PushConfigStore(),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('push page explains disabled primary action when disconnected', (
    tester,
  ) async {
    await tester.pumpWidget(appWithStores(const PushPage()));
    await tester.pump();

    expect(find.text('请先在「连接配置」页面连接 Harbor'), findsOneWidget);
    expect(find.text('批量上行推送'), findsOneWidget);
  });

  testWidgets('pull page shows not connected guidance', (tester) async {
    await tester.pumpWidget(appWithStores(const PullPage()));
    await tester.pump();

    expect(find.text('请先在「连接配置」页面连接 Harbor'), findsOneWidget);
    expect(find.text('连接成功后即可浏览和下载制品'), findsOneWidget);
  });

  testWidgets('sidebar supports keyboard navigation', (tester) async {
    final api = HarborApiService();
    var selectedIndex = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>(
        create: (_) => ConnectionStore(api),
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return SidebarNav(
                selectedIndex: selectedIndex,
                onItemSelected: (index) =>
                    setState(() => selectedIndex = index),
              );
            },
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(selectedIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(selectedIndex, 3);
  });
}

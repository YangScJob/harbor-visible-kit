import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/core/widgets/app_notice.dart';

void main() {
  Future<void> pumpNoticeTestApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AppNotice.success(
                  context,
                  title: '推送成功',
                  message: '已推送 3 个制品',
                ),
                child: const Text('show'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('shows top-right notice content without shadow', (tester) async {
    await pumpNoticeTestApp(tester);
    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.text('推送成功'), findsOneWidget);
    expect(find.text('已推送 3 个制品'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final closeTopRight = tester.getTopRight(find.byIcon(Icons.close_rounded));
    expect(closeTopRight.dx, greaterThan(740));
    expect(closeTopRight.dy, lessThan(70));

    final card = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('推送成功'), matching: find.byType(DecoratedBox))
          .last,
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNull);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
  });

  testWidgets('can close notice manually', (tester) async {
    await pumpNoticeTestApp(tester);
    await tester.tap(find.text('show'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(find.text('推送成功'), findsNothing);
  });

  testWidgets('notice dismisses automatically', (tester) async {
    await pumpNoticeTestApp(tester);
    await tester.tap(find.text('show'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.text('推送成功'), findsNothing);
  });

  testWidgets('can expand and copy long notice details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AppNotice.error(
                  context,
                  title: '推送失败',
                  message: '第一行错误详情\n第二行错误详情\n第三行错误详情\n第四行错误详情',
                ),
                child: const Text('show error'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('show error'));
    await tester.pump();

    expect(find.text('展开详情'), findsOneWidget);
    expect(find.byTooltip('复制通知详情'), findsOneWidget);

    await tester.tap(find.text('展开详情'));
    await tester.pump();
    expect(find.text('收起详情'), findsOneWidget);

    await tester.tap(find.byTooltip('复制通知详情'));
    await tester.pump();
    expect(find.text('通知详情已复制'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
  });
}

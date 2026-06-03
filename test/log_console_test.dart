import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/core/widgets/log_console.dart';

void main() {
  ScrollPosition consoleScrollablePosition(WidgetTester tester) {
    final scrollable = find.descendant(
      of: find.byType(LogConsole),
      matching: find.byType(Scrollable),
    );
    final positions = tester
        .stateList<ScrollableState>(scrollable)
        .map((state) => state.position)
        .where((position) => position.maxScrollExtent > 0)
        .toList();
    expect(positions, hasLength(1));
    return positions.single;
  }

  testWidgets('renders selectable logs and auto-scroll toggle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogConsole(
            logs: [
              LogEntry(message: '开始推送'),
              LogEntry(message: '推送成功', level: LogLevel.success),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byIcon(Icons.vertical_align_bottom_rounded), findsOneWidget);
    expect(find.byTooltip('筛选日志级别'), findsOneWidget);
    expect(find.byTooltip('复制全部'), findsOneWidget);
  });

  testWidgets('filters logs by level', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogConsole(
            logs: [
              LogEntry(message: '普通信息'),
              LogEntry(message: '失败详情', level: LogLevel.error),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('筛选日志级别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('错误').last);
    await tester.pumpAndSettle();

    final richText = tester.widget<SelectableText>(find.byType(SelectableText));
    final plainText = richText.textSpan!.toPlainText();
    expect(plainText, contains('失败详情'));
    expect(plainText, isNot(contains('普通信息')));
  });

  testWidgets('auto-scrolls when parent mutates the same log list', (
    tester,
  ) async {
    final logs = <LogEntry>[LogEntry(message: '开始推送')];
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return LogConsole(logs: logs, maxHeight: 120);
            },
          ),
        ),
      ),
    );

    setHostState(() {
      logs.addAll(
        List.generate(
          80,
          (index) => LogEntry(message: '日志行 $index: docker push output'),
        ),
      );
    });

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final position = consoleScrollablePosition(tester);
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
  });
}

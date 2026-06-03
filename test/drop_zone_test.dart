import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_visible_kit/core/widgets/drop_zone.dart';

void main() {
  testWidgets('shows dynamic accepted file prompt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropZone(
            onFilesSelected: (_) {},
            allowedExtensions: const ['jar'],
            emptyTitle: '拖拽JAR文件至此',
            emptySubtitle: '仅支持 .jar',
          ),
        ),
      ),
    );

    expect(find.text('拖拽JAR文件至此'), findsOneWidget);
    expect(find.text('仅支持 .jar'), findsOneWidget);
  });

  testWidgets('exposes file picker semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropZone(
            onFilesSelected: (_) {},
            allowedExtensions: const ['jar'],
            emptyTitle: '拖拽JAR文件至此',
            emptySubtitle: '仅支持 .jar',
          ),
        ),
      ),
    );

    final semanticNode = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == '拖拽JAR文件至此，仅支持 .jar' &&
          widget.properties.button == true,
    );
    expect(semanticNode, findsOneWidget);
  });
}

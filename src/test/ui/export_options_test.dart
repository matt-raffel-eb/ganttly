import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/ui/file_actions.dart';

void main() {
  Future<double?> choose(WidgetTester tester, {required double screen, String? pick, bool cancel = false}) async {
    double? result = -1;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await askExportZoom(context, screen),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    if (pick != null) await tester.tap(find.textContaining(pick));
    await tester.pump();
    await tester.tap(find.text(cancel ? 'Cancel' : 'Export…'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the export uses the standard 100% zoom unless "As on screen" is chosen', (tester) async {
    expect(await choose(tester, screen: 44), 22, reason: 'standard by default, not the 200% on screen');
  });

  testWidgets('"As on screen" exports at the current zoom, and the option shows it', (tester) async {
    expect(await choose(tester, screen: 44, pick: 'As on screen (200%)'), 44);
  });

  testWidgets('Cancel exports nothing', (tester) async {
    expect(await choose(tester, screen: 44, cancel: true), isNull);
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/main.dart';
import 'package:ganttly/state/project_controller.dart';
import 'package:ganttly/ui/gantt/gantt_painter.dart';
import 'package:ganttly/ui/gantt/png_export.dart';
import 'package:ganttly/ui/task_grid.dart';

import '../sample.dart';

void main() {
  Future<ProjectController> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProjectController(sampleFromFile());
    await tester.pumpWidget(GanttlyApp(controller: c));
    return c;
  }

  testWidgets('shows the project, its rows, the chart and the deadline status', (tester) async {
    await pumpApp(tester);
    expect(find.text('Website relaunch'), findsOneWidget);
    expect(find.text('CMS integration'), findsOneWidget);
    expect(find.textContaining('late by 1 working day'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GanttBodyPainter), findsOneWidget);
  });

  testWidgets('editing a duration in the grid moves the plan and the deadline status', (tester) async {
    final c = await pumpApp(tester);
    final row = c.project.tasks.indexWhere((t) => t.name == 'Fix issues');
    final days = find.descendant(of: find.byType(TaskGridRow).at(row), matching: find.byType(TextField)).at(1);
    await tester.enterText(days, '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.project.tasks[row].durationDays, 1);
    expect(find.textContaining('late by'), findsNothing);
    expect(find.textContaining('on track'), findsOneWidget);
  });

  testWidgets('the chart scrolls sideways: the wheel over the date header, and a scrollbar always shown', (tester) async {
    await pumpApp(tester);
    final horizontal = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right && w.controller != null);
    ScrollPosition pos() => tester.state<ScrollableState>(horizontal.last).position;
    await tester.pumpAndSettle();
    expect(pos().maxScrollExtent, greaterThan(0), reason: 'the chart is wider than the window');
    final header = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GanttHeaderPainter);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(header)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pump();
    expect(pos().pixels, 120);
    final bars = find.byWidgetPredicate((w) => w is Scrollbar && w.thumbVisibility == true);
    expect(bars, findsNWidgets(2), reason: 'vertical and horizontal scrollbars stay visible');
  });

  testWidgets('zoom: the buttons change and show the zoom; Fit makes the whole plan fit', (tester) async {
    await pumpApp(tester);
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fit_screen_outlined));
    await tester.pumpAndSettle();
    final horizontal = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right && w.controller != null);
    expect(tester.state<ScrollableState>(horizontal.last).position.maxScrollExtent, lessThan(1));
    await tester.tap(find.textContaining('%'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('the date parser reads the formats the Start column accepts', (tester) async {
    final near = DateTime.utc(2026, 11, 2);
    expect(parseDay('11/16', near: near), DateTime.utc(2026, 11, 16));
    expect(parseDay('Mon 1/4', near: near), DateTime.utc(2027, 1, 4));
    expect(parseDay('2026-12-01', near: near), DateTime.utc(2026, 12, 1));
    expect(parseDay('2/30', near: near), isNull);
  });

  testWidgets('PNG export produces a PNG of the whole chart', (tester) async {
    final layout = GanttLayout(ProjectController(sampleFromFile()).schedule, today: DateTime.utc(2026, 10, 29));
    final bytes = await tester.runAsync(() => ganttPng(layout, pixelRatio: 1));
    expect(bytes!.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(bytes.length, greaterThan(10000));
  });
}

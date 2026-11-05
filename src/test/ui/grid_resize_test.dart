import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/io/app_settings.dart';
import 'package:ganttly/main.dart';
import 'package:ganttly/state/project_controller.dart';
import 'package:ganttly/ui/task_grid.dart';

import '../sample.dart';

void main() {
  late Directory tmp;
  late AppSettings settings;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ganttly_grid_');
    settings = AppSettings(Directory('${tmp.path}/settings'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GanttlyApp(controller: ProjectController(sampleFromFile()), settings: settings));
  }

  double columnWidth(WidgetTester tester, GridColumn c) => tester.getSize(find.byKey(ValueKey('header-${c.name}'))).width;

  /// Where the chart starts: the right edge of the divider.
  double chartLeft(WidgetTester tester) => tester.getTopRight(find.byKey(const ValueKey('grid-divider'))).dx;

  Future<void> drag(WidgetTester tester, Finder f, double dx) async {
    await tester.drag(f, Offset(dx, 0), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  }

  Future<void> doubleClick(WidgetTester tester, Finder f) async {
    await tester.tap(f, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(f, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  }

  ScrollPosition gridHScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find.descendant(of: find.byKey(const ValueKey('grid-hscroll')), matching: find.byType(Scrollable)).first)
      .position;

  testWidgets('dragging a column edge resizes it and moves the chart; double-click resets it', (tester) async {
    await pumpApp(tester);
    final left = chartLeft(tester);
    await drag(tester, find.byKey(const ValueKey('resize-name')), 50);
    expect(columnWidth(tester, GridColumn.name), 350);
    expect(chartLeft(tester), left + 50);
    expect(settings.gridColumns, containsPair('name', 350));

    // Anywhere on the title, not only the edge.
    await doubleClick(tester, find.text('Task'));
    expect(columnWidth(tester, GridColumn.name), 300);
    expect(chartLeft(tester), left);
    expect(settings.gridColumns, containsPair('name', 300));
  });

  testWidgets('columns keep a minimum width, the chart keeps 200 px, and # is fixed', (tester) async {
    await pumpApp(tester);
    await drag(tester, find.byKey(const ValueKey('resize-days')), -100);
    expect(columnWidth(tester, GridColumn.days), 40);

    await drag(tester, find.byKey(const ValueKey('resize-name')), 2000);
    expect(chartLeft(tester), 1600 - 200);

    expect(find.byKey(const ValueKey('resize-id')), findsNothing);
  });

  testWidgets('the divider narrows the grid, which then scrolls sideways; double-click fits the columns', (tester) async {
    await pumpApp(tester);
    final full = chartLeft(tester);
    await drag(tester, find.byKey(const ValueKey('grid-divider')), -300);
    expect(chartLeft(tester), full - 300);
    expect(gridHScroll(tester).maxScrollExtent, 300);
    expect(settings.gridWidth, isNotNull);

    // The grid never gets wider than its columns.
    await drag(tester, find.byKey(const ValueKey('grid-divider')), 900);
    expect(chartLeft(tester), full);
    expect(settings.gridWidth, isNull, reason: 'back to following the columns');

    await drag(tester, find.byKey(const ValueKey('grid-divider')), -300);
    await doubleClick(tester, find.byKey(const ValueKey('grid-divider')));
    expect(chartLeft(tester), full);
    expect(gridHScroll(tester).maxScrollExtent, 0);
  });

  testWidgets('when the window gets narrower the chart keeps 200 px and the grid scrolls', (tester) async {
    await pumpApp(tester);
    await drag(tester, find.byKey(const ValueKey('resize-name')), 600);
    tester.view.physicalSize = const Size(1500, 1000);
    await tester.pumpAndSettle();
    expect(chartLeft(tester), 1500 - 200);
    expect(gridHScroll(tester).maxScrollExtent, 1310 - (1500 - 200 - 5));
  });

  testWidgets('saved widths come back on the next start', (tester) async {
    settings.rememberGrid(columns: {'name': 420, 'links': 90}, width: 500);
    await pumpApp(tester);
    expect(columnWidth(tester, GridColumn.name), 420);
    expect(columnWidth(tester, GridColumn.links), 90);
    expect(columnWidth(tester, GridColumn.start), 100);
    expect(tester.getSize(find.byKey(const ValueKey('grid-hscroll'))).width, 500);
  });

  test('saved widths that make no sense take the defaults', () {
    final cols = GridColumns.fromJson({'name': 'wide', 'days': -5, 'start': 10, 'id': 99});
    expect(cols[GridColumn.name], 300);
    expect(cols[GridColumn.days], 60);
    expect(cols[GridColumn.start], 70, reason: 'raised to its minimum');
    expect(cols[GridColumn.id], 40, reason: '# is not resizable');
    expect(GridColumns.fromJson('junk')[GridColumn.name], 300);
  });

  test('saving the grid keeps the last project', () {
    settings.rememberProject('/plans/a.ganttly');
    settings.rememberGrid(columns: GridColumns.defaults.toJson());
    expect(settings.lastProjectPath, '/plans/a.ganttly');
    expect(settings.gridWidth, isNull);
  });
}

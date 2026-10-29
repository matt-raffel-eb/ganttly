import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/project_controller.dart';
import 'file_actions.dart';
import 'gantt/gantt_painter.dart';
import 'project_settings_dialog.dart';
import 'task_grid.dart';

/// The main window: toolbar, project summary, task grid and Gantt chart.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final ProjectController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _gridScroll = ScrollController();
  final _chartScroll = ScrollController();
  final _chartHScroll = ScrollController();
  final _headerHScroll = ScrollController();
  bool _syncing = false;

  /// Zoom: pixels per day. 100% is [_defaultDayWidth].
  static const double _defaultDayWidth = 22, _minDayWidth = 4, _maxDayWidth = 64;
  double _dayWidth = _defaultDayWidth;

  ProjectController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    // The grid and the chart scroll up and down together.
    void sync(ScrollController from, ScrollController to) {
      from.addListener(() {
        if (_syncing || !to.hasClients) return;
        _syncing = true;
        to.jumpTo(from.offset.clamp(0, to.position.maxScrollExtent));
        _syncing = false;
      });
    }

    sync(_gridScroll, _chartScroll);
    sync(_chartScroll, _gridScroll);
    // The date header follows the chart sideways.
    _chartHScroll.addListener(() {
      if (_headerHScroll.hasClients) _headerHScroll.jumpTo(_chartHScroll.offset.clamp(0, _headerHScroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _gridScroll.dispose();
    _chartScroll.dispose();
    _chartHScroll.dispose();
    _headerHScroll.dispose();
    super.dispose();
  }

  FileActions get _files => FileActions(context, c);

  void _zoom(double by, {double? anchorX}) => _setDayWidth(_dayWidth * by, anchorX: anchorX);

  /// Changes the zoom, keeping the day at [anchorX] (from the chart's left
  /// edge; default the middle) where it is on screen.
  void _setDayWidth(double width, {double? anchorX}) {
    final next = width.clamp(_minDayWidth, _maxDayWidth);
    if (next == _dayWidth) return;
    final h = _chartHScroll.hasClients ? _chartHScroll.position : null;
    final anchor = anchorX ?? (h == null ? 0 : h.viewportDimension / 2);
    final contentX = (h?.pixels ?? 0) + anchor;
    final ratio = next / _dayWidth;
    setState(() => _dayWidth = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chartHScroll.hasClients) return;
      final p = _chartHScroll.position;
      _chartHScroll.jumpTo((contentX * ratio - anchor).clamp(0, p.maxScrollExtent));
    });
  }

  /// Zooms so the whole plan fits the chart's width.
  void _fit(GanttLayout layout) {
    if (!_chartHScroll.hasClients) return;
    final fit = _chartHScroll.position.viewportDimension / layout.days;
    setState(() => _dayWidth = fit.clamp(_minDayWidth, _maxDayWidth));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartHScroll.hasClients) _chartHScroll.jumpTo(0);
    });
  }

  String get _zoomLabel => '${(_dayWidth / _defaultDayWidth * 100).round()}%';

  /// Scroll-wheel handling the scroll views don't do on their own: ⌘/Ctrl +
  /// wheel zooms around the pointer; over the date header, the wheel scrolls
  /// sideways.
  void _onChartSignal(PointerSignalEvent e, {required bool header}) {
    if (e is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    final zoomKey = Platform.isMacOS ? keys.isMetaPressed : keys.isControlPressed;
    if (zoomKey) {
      GestureBinding.instance.pointerSignalResolver.register(e, (event) {
        final dy = (event as PointerScrollEvent).scrollDelta.dy;
        if (dy == 0) return;
        // The header's position is already on-screen; the body's is within the scrolled chart.
        final offset = header || !_chartHScroll.hasClients ? 0.0 : _chartHScroll.offset;
        _zoom(dy < 0 ? 1.15 : 1 / 1.15, anchorX: event.localPosition.dx - offset);
      });
    } else if (header) {
      GestureBinding.instance.pointerSignalResolver.register(e, (event) {
        final d = (event as PointerScrollEvent).scrollDelta;
        final by = d.dx != 0 ? d.dx : d.dy;
        if (!_chartHScroll.hasClients || by == 0) return;
        _chartHScroll.jumpTo((_chartHScroll.offset + by).clamp(0, _chartHScroll.position.maxScrollExtent));
      });
    }
  }

  void _scrollToToday(GanttLayout layout) {
    if (!_chartHScroll.hasClients) return;
    final target = layout.x(layout.today) - 120;
    _chartHScroll.animateTo(target.clamp(0, _chartHScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final mac = Platform.isMacOS;
    SingleActivator key(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, meta: mac, control: !mac, shift: shift);
    int? sel() => c.selected;
    return {
      key(LogicalKeyboardKey.keyN): _files.newProject,
      key(LogicalKeyboardKey.keyO): _files.open,
      key(LogicalKeyboardKey.keyS): () => _files.save(),
      key(LogicalKeyboardKey.keyS, shift: true): () => _files.saveAs(),
      key(LogicalKeyboardKey.keyE): () => _files.exportPng(_dayWidth),
      key(LogicalKeyboardKey.keyZ): c.undo,
      key(LogicalKeyboardKey.keyZ, shift: true): c.redo,
      key(LogicalKeyboardKey.enter): () => c.addTask(after: sel()),
      key(LogicalKeyboardKey.bracketRight): () => sel() == null ? null : c.indent(sel()!),
      key(LogicalKeyboardKey.bracketLeft): () => sel() == null ? null : c.outdent(sel()!),
      key(LogicalKeyboardKey.arrowUp, shift: true): () => sel() == null ? null : c.moveUp(sel()!),
      key(LogicalKeyboardKey.arrowDown, shift: true): () => sel() == null ? null : c.moveDown(sel()!),
      key(LogicalKeyboardKey.backspace): () => sel() == null ? null : c.deleteTask(sel()!),
      key(LogicalKeyboardKey.equal): () => _zoom(1.25),
      key(LogicalKeyboardKey.minus): () => _zoom(0.8),
      key(LogicalKeyboardKey.digit0): () => _setDayWidth(_defaultDayWidth),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final layout = GanttLayout(c.schedule, dayWidth: _dayWidth);
        return CallbackShortcuts(
          bindings: _shortcuts(),
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: Column(children: [
                _Toolbar(state: this, layout: layout),
                _SummaryBar(controller: c),
                const Divider(height: 1),
                Expanded(child: _gridAndChart(layout)),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _gridAndChart(GanttLayout layout) {
    final rows = c.project.tasks.length;
    const bottomRoom = GanttLayout.rowHeight * 4;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        width: GridColumns.width,
        child: Column(children: [
          const TaskGridHeader(),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _gridScroll,
                itemExtent: GanttLayout.rowHeight,
                itemCount: rows + 4,
                itemBuilder: (context, i) => i < rows
                    ? TaskGridRow(key: ValueKey(c.project.tasks[i].id), controller: c, index: i)
                    : (i == rows
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => c.addTask(after: rows == 0 ? null : rows - 1),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add task'),
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),
          ),
        ]),
      ),
      const VerticalDivider(width: 1, color: GanttColors.weekLine),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          // At least as tall as the window, so the shading reaches the bottom.
          final viewportHeight = box.maxHeight - GanttLayout.headerHeight;
          final bodyHeight = (layout.rowsHeight + bottomRoom) > viewportHeight ? layout.rowsHeight + bottomRoom : viewportHeight;
          return Column(children: [
            // The date header: pinned at the top, follows the chart sideways.
            Listener(
              onPointerSignal: (e) => _onChartSignal(e, header: true),
              child: SizedBox(
                height: GanttLayout.headerHeight,
                child: SingleChildScrollView(
                  controller: _headerHScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: CustomPaint(size: Size(layout.width, GanttLayout.headerHeight), painter: GanttHeaderPainter(layout)),
                ),
              ),
            ),
            // The rows: scroll both ways, with both scrollbars always shown at
            // the window's edges.
            Expanded(
              child: Scrollbar(
                controller: _chartScroll,
                thumbVisibility: true,
                child: Scrollbar(
                  controller: _chartHScroll,
                  thumbVisibility: true,
                  trackVisibility: true,
                  notificationPredicate: (n) => n.depth == 1 && n.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _chartScroll,
                    child: SingleChildScrollView(
                      controller: _chartHScroll,
                      scrollDirection: Axis.horizontal,
                      child: Listener(
                        onPointerSignal: (e) => _onChartSignal(e, header: false),
                        child: GestureDetector(
                          onTapDown: (d) => c.select((d.localPosition.dy / GanttLayout.rowHeight).floor()),
                          child: CustomPaint(
                            size: Size(layout.width, bodyHeight),
                            painter: GanttBodyPainter(layout, selected: c.selected, minHeight: viewportHeight),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    ]);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.layout});

  final _HomePageState state;
  final GanttLayout layout;

  @override
  Widget build(BuildContext context) {
    final c = state.c;
    final sel = c.selected;
    final files = state._files;
    final mod = Platform.isMacOS ? '⌘' : 'Ctrl+';
    Widget btn(IconData icon, String tip, VoidCallback? onTap) =>
        IconButton(icon: Icon(icon, size: 20), tooltip: tip, onPressed: onTap);
    Widget gap() => const SizedBox(width: 8, height: 24, child: VerticalDivider());
    final file = c.filePath?.split(Platform.pathSeparator).last;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          btn(Icons.note_add_outlined, 'New project (${mod}N)', files.newProject),
          btn(Icons.folder_open_outlined, 'Open (${mod}O)', files.open),
          btn(Icons.save_outlined, 'Save (${mod}S)', () => files.save()),
          btn(Icons.save_as_outlined, 'Save as ($mod⇧S)', () => files.saveAs()),
          btn(Icons.image_outlined, 'Export chart as PNG (${mod}E)', () => files.exportPng(state._dayWidth)),
          gap(),
          btn(Icons.undo, 'Undo (${mod}Z)', c.canUndo ? c.undo : null),
          btn(Icons.redo, 'Redo ($mod⇧Z)', c.canRedo ? c.redo : null),
          gap(),
          btn(Icons.add, 'Add task below (${mod}Enter)', () => c.addTask(after: sel)),
          btn(Icons.format_indent_increase, 'Indent ($mod])', sel != null && c.canIndent(sel) ? () => c.indent(sel) : null),
          btn(Icons.format_indent_decrease, 'Outdent ($mod[)', sel != null && c.canOutdent(sel) ? () => c.outdent(sel) : null),
          btn(Icons.arrow_upward, 'Move up ($mod⇧↑)', sel != null ? () => c.moveUp(sel) : null),
          btn(Icons.arrow_downward, 'Move down ($mod⇧↓)', sel != null ? () => c.moveDown(sel) : null),
          btn(Icons.delete_outline, 'Delete task ($mod⌫)', sel != null ? () => c.deleteTask(sel) : null),
          gap(),
          btn(Icons.zoom_out, 'Zoom out ($mod- or $mod+scroll)', () => state._zoom(0.8)),
          Tooltip(
            message: 'Zoom. Click for 100% (${mod}0).',
            child: TextButton(
              onPressed: () => state._setDayWidth(_HomePageState._defaultDayWidth),
              style: TextButton.styleFrom(minimumSize: const Size(52, 32), padding: EdgeInsets.zero),
              child: Text(state._zoomLabel),
            ),
          ),
          btn(Icons.zoom_in, 'Zoom in ($mod= or $mod+scroll)', () => state._zoom(1.25)),
          btn(Icons.fit_screen_outlined, 'Fit the whole plan in the window', () => state._fit(layout)),
          btn(Icons.today_outlined, 'Scroll to today', () => state._scrollToToday(layout)),
          gap(),
          btn(Icons.tune, 'Project settings', () => showProjectSettings(context, c)),
          const Spacer(),
          Text(
            '${file ?? 'Not saved yet'}${c.isDirty ? ' — edited' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: GanttColors.muted),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.schedule;
    final p = s.project;
    final t = Theme.of(context).textTheme;
    final problems = s.dates.values.where((d) => d.problem != null).length;
    final late = s.isLate;
    final lateBy = late ? s.calendar.workdaysBetween(p.deadline!, s.finish) - 1 : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Text(p.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 24),
        Text('${formatDay(s.start)} – ${formatDay(s.finish)}', style: t.bodyMedium),
        const SizedBox(width: 8),
        Text('· ${s.calendar.workdaysBetween(s.start, s.finish)} working days', style: t.bodyMedium?.copyWith(color: GanttColors.muted)),
        if (p.deadline != null) ...[
          const SizedBox(width: 24),
          Icon(late ? Icons.warning_amber_rounded : Icons.flag_outlined, size: 18, color: late ? GanttColors.deadline : GanttColors.muted),
          const SizedBox(width: 4),
          Text(
            late ? 'Deadline ${formatDay(p.deadline!)}: late by $lateBy working day${lateBy == 1 ? '' : 's'}' : 'Deadline ${formatDay(p.deadline!)}: on track',
            style: t.bodyMedium?.copyWith(color: late ? GanttColors.deadline : null, fontWeight: late ? FontWeight.w600 : null),
          ),
        ],
        if (problems > 0) ...[
          const SizedBox(width: 24),
          const Icon(Icons.error_outline, size: 18, color: GanttColors.problem),
          const SizedBox(width: 4),
          Text('$problems task${problems == 1 ? '' : 's'} with link problems', style: t.bodyMedium?.copyWith(color: GanttColors.problem)),
        ],
      ]),
    );
  }
}

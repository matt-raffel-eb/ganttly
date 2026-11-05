import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/project.dart';
import '../state/project_controller.dart';
import 'gantt/gantt_painter.dart';

/// The task grid's columns.
enum GridColumn { id, name, days, start, finish, links }

/// Column widths of the task grid. All but [GridColumn.id] can be resized.
/// Kept in `settings.json`, keyed by the column's name.
class GridColumns {
  const GridColumns._(this._widths);

  /// The default widths.
  static const defaults = GridColumns._({
    GridColumn.id: 40,
    GridColumn.name: 300,
    GridColumn.days: 60,
    GridColumn.start: 100,
    GridColumn.finish: 100,
    GridColumn.links: 110,
  });

  /// The narrowest each column can be made.
  static const minimums = {
    GridColumn.id: 40.0,
    GridColumn.name: 80.0,
    GridColumn.days: 40.0,
    GridColumn.start: 70.0,
    GridColumn.finish: 70.0,
    GridColumn.links: 50.0,
  };

  final Map<GridColumn, double> _widths;

  double operator [](GridColumn c) => _widths[c]!;

  /// All the columns together.
  double get width => _widths.values.fold(0, (a, b) => a + b);

  static bool resizable(GridColumn c) => c != GridColumn.id;

  /// [c] at [width] (whole pixels), kept to its minimum.
  GridColumns resized(GridColumn c, double width) {
    if (!resizable(c)) return this;
    final w = width < minimums[c]! ? minimums[c]! : width.roundToDouble();
    return GridColumns._({..._widths, c: w});
  }

  Map<String, double> toJson() => {for (final c in GridColumn.values.where(resizable)) c.name: this[c]};

  /// Reads the widths saved in the settings. A missing or bad value takes its default.
  static GridColumns fromJson(Object? json) {
    var cols = defaults;
    if (json is! Map) return cols;
    for (final c in GridColumn.values.where(resizable)) {
      final v = json[c.name];
      if (v is num && v.isFinite && v > 0 && v < 5000) cols = cols.resized(c, v.toDouble());
    }
    return cols;
  }
}

/// The grid's column titles. Drag a title's right edge to resize its column;
/// double-click anywhere on a title to give the column its default width.
class TaskGridHeader extends StatelessWidget {
  const TaskGridHeader({super.key, required this.columns, this.onResize, this.onResizeEnd, this.maxGrowth = double.infinity});

  final GridColumns columns;

  /// Called while dragging, and on a double-click, with the column's new width.
  final void Function(GridColumn column, double width)? onResize;

  /// Called when a drag or a double-click is done, to save the widths.
  final VoidCallback? onResizeEnd;

  /// How much wider all the columns together may get (the chart needs the rest).
  final double maxGrowth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    Widget cell(GridColumn col, String text, {TextAlign align = TextAlign.left, String? tip}) {
      final w = columns[col];
      final title = Padding(
        padding: const EdgeInsets.only(left: 6, right: 6, bottom: 6),
        child: Tooltip(message: tip ?? '', child: Text(text, style: style, textAlign: align)),
      );
      final resize = onResize;
      if (!GridColumns.resizable(col) || resize == null) {
        return SizedBox(width: w, child: Align(alignment: Alignment.bottomLeft, child: SizedBox(width: w, child: title)));
      }
      return SizedBox(
        width: w,
        child: GestureDetector(
          key: ValueKey('header-${col.name}'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            resize(col, GridColumns.defaults[col]);
            onResizeEnd?.call();
          },
          child: Stack(children: [
            Positioned(left: 0, right: 0, bottom: 0, child: title),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 6,
              child: ResizeHandle(
                key: ValueKey('resize-${col.name}'),
                lineAt: Alignment.centerRight,
                lineInset: 10,
                onStart: () => columns[col],
                onDrag: (start, dx) {
                  // Shrinking is always allowed; growing stops where the chart would get too narrow.
                  final now = columns[col], want = start + dx, cap = now + maxGrowth;
                  resize(col, want <= now || want <= cap ? want : (cap > now ? cap : now));
                },
                onEnd: onResizeEnd,
              ),
            ),
          ]),
        ),
      );
    }

    return Container(
      height: GanttLayout.headerHeight,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GanttColors.weekLine))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        cell(GridColumn.id, '#', align: TextAlign.right),
        cell(GridColumn.name, 'Task'),
        cell(GridColumn.days, 'Days', align: TextAlign.right, tip: 'Working days. 0 makes a milestone.'),
        cell(GridColumn.start, 'Start', tip: 'Type a date to pin the start (start no earlier than). Clear it to unpin.'),
        cell(GridColumn.finish, 'Finish'),
        cell(GridColumn.links, 'After', tip: 'Predecessor task numbers, e.g. "2, 5+3" (5 plus 3 working days).'),
      ]),
    );
  }
}

/// A thin strip that shows a line and the resize cursor, and reports a
/// sideways drag: [onDrag] gets the value [onStart] returned when the drag
/// began and how far the pointer has moved since the button went down. The
/// line darkens while the pointer is over it or dragging.
class ResizeHandle extends StatefulWidget {
  const ResizeHandle({
    super.key,
    required this.onStart,
    required this.onDrag,
    this.onEnd,
    this.onDoubleTap,
    this.lineAt = Alignment.center,
    this.lineInset = 0,
  });

  final double Function() onStart;
  final void Function(double start, double dx) onDrag;
  final VoidCallback? onEnd;
  final VoidCallback? onDoubleTap;

  /// Where the line sits across the strip.
  final Alignment lineAt;

  /// Space above and below the line.
  final double lineInset;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  double _start = 0, _downX = 0;
  bool _hover = false, _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragStart: (d) {
          _start = widget.onStart();
          _downX = d.globalPosition.dx;
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: (d) => widget.onDrag(_start, d.globalPosition.dx - _downX),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onEnd?.call();
        },
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.lineInset),
          child: Align(
            alignment: widget.lineAt,
            child: Container(width: active ? 2 : 1, color: active ? GanttColors.muted : GanttColors.weekLine),
          ),
        ),
      ),
    );
  }
}

/// One editable row; the height matches the chart's rows.
class TaskGridRow extends StatelessWidget {
  const TaskGridRow({super.key, required this.controller, required this.index, required this.columns});

  final ProjectController controller;
  final int index;
  final GridColumns columns;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.project;
    final t = p.tasks[index];
    final d = c.schedule[t.id];
    final selected = c.selected == index;
    final bold = d.isSummary ? FontWeight.w600 : FontWeight.w400;
    final pinned = t.startNoEarlierThan != null;

    return GestureDetector(
      onTap: () => c.select(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: GanttLayout.rowHeight,
        decoration: BoxDecoration(
          color: selected ? GanttColors.selected : null,
          border: const Border(bottom: BorderSide(color: GanttColors.gridLine)),
        ),
        child: Row(children: [
          SizedBox(
            width: columns[GridColumn.id],
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('${t.id}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: GanttColors.muted)),
            ),
          ),
          SizedBox(
            width: columns[GridColumn.name],
            child: Row(children: [
              SizedBox(width: 6 + t.outlineLevel * 16.0),
              if (d.problem != null)
                Tooltip(message: d.problem!, child: const Icon(Icons.error_outline, size: 15, color: GanttColors.problem)),
              if (d.isMilestone) const Icon(Icons.change_history, size: 13, color: GanttColors.muted),
              Expanded(
                child: _EditCell(
                  key: ValueKey('name-${t.id}'),
                  value: t.name,
                  weight: bold,
                  onFocus: () => c.select(index),
                  onCommit: (s) {
                    if (s.trim().isEmpty) return false;
                    c.updateTask(index, (x) => x.name == s.trim() ? x : x.copyWith(name: s.trim()));
                    return true;
                  },
                ),
              ),
            ]),
          ),
          SizedBox(
            width: columns[GridColumn.days],
            child: d.isSummary
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('${c.schedule.calendar.workdaysBetween(d.start, d.finish)}',
                        textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: bold, color: GanttColors.muted)),
                  )
                : _EditCell(
                    key: ValueKey('days-${t.id}'),
                    value: '${t.durationDays}',
                    align: TextAlign.right,
                    digitsOnly: true,
                    onFocus: () => c.select(index),
                    onCommit: (s) {
                      final n = int.tryParse(s.trim());
                      if (n == null || n < 0 || n > 9999) return false;
                      c.updateTask(index, (x) => x.durationDays == n ? x : x.copyWith(durationDays: n));
                      return true;
                    },
                  ),
          ),
          SizedBox(
            width: columns[GridColumn.start],
            child: d.isSummary
                ? _ReadOnly(formatDay(d.start), weight: bold)
                : Row(children: [
                    Expanded(
                      child: _EditCell(
                        key: ValueKey('start-${t.id}'),
                        value: formatDay(d.start),
                        color: pinned ? Theme.of(context).colorScheme.primary : null,
                        onFocus: () => c.select(index),
                        onCommit: (s) {
                          if (s.trim().isEmpty) {
                            c.updateTask(index, (x) => x.startNoEarlierThan == null ? x : x.copyWith(clearStartNoEarlierThan: true));
                            return true;
                          }
                          final date = parseDay(s, near: p.start);
                          if (date == null) return false;
                          if (date == d.start && !pinned) return true; // unchanged
                          c.updateTask(index, (x) => x.copyWith(startNoEarlierThan: date));
                          return true;
                        },
                      ),
                    ),
                    if (pinned)
                      const Tooltip(
                        message: 'Pinned start. Clear the date to unpin.',
                        child: Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 12, color: GanttColors.muted)),
                      ),
                  ]),
          ),
          SizedBox(width: columns[GridColumn.finish], child: _ReadOnly(formatDay(d.finish), weight: bold)),
          SizedBox(
            width: columns[GridColumn.links],
            child: _EditCell(
              key: ValueKey('links-${t.id}'),
              value: formatDependencies(t.dependencies),
              onFocus: () => c.select(index),
              onCommit: (s) {
                final deps = parseDependencies(s);
                if (deps == null) return false;
                c.updateTask(index, (x) => formatDependencies(x.dependencies) == formatDependencies(deps) ? x : x.copyWith(dependencies: deps));
                return true;
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly(this.text, {this.weight = FontWeight.w400});

  final String text;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: weight, color: GanttColors.text)),
      );
}

/// A borderless text field that commits on Enter or when focus leaves. If
/// [onCommit] rejects the text, the cell goes back to its value.
class _EditCell extends StatefulWidget {
  const _EditCell({
    super.key,
    required this.value,
    required this.onCommit,
    this.onFocus,
    this.align = TextAlign.left,
    this.weight = FontWeight.w400,
    this.color,
    this.digitsOnly = false,
  });

  final String value;
  final bool Function(String) onCommit;
  final VoidCallback? onFocus;
  final TextAlign align;
  final FontWeight weight;
  final Color? color;
  final bool digitsOnly;

  @override
  State<_EditCell> createState() => _EditCellState();
}

class _EditCellState extends State<_EditCell> {
  late final TextEditingController _text = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();
  bool _bad = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        widget.onFocus?.call();
      } else {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(_EditCell old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _text.text != widget.value) _text.text = widget.value;
  }

  void _commit() {
    if (_text.text == widget.value) return;
    final ok = widget.onCommit(_text.text);
    if (!ok) {
      setState(() => _bad = true);
      _text.text = widget.value;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _bad = false);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      focusNode: _focus,
      textAlign: widget.align,
      style: TextStyle(fontSize: 13, fontWeight: widget.weight, color: widget.color ?? GanttColors.text),
      inputFormatters: widget.digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        filled: _bad,
        fillColor: GanttColors.problem.withValues(alpha: 0.15),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon 11/2".
String formatDay(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.month}/${d.day}';

/// Reads "11/2", "11/2/2026", "Mon 11/2" or "2026-11-02". A date without a
/// year takes the year that puts it nearest to [near].
DateTime? parseDay(String text, {required DateTime near}) {
  final s = text.trim().replaceFirst(RegExp(r'^[A-Za-z]+\s+'), '');
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m != null) return _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?$').firstMatch(s);
  if (m == null) return null;
  final month = int.parse(m[1]!), dom = int.parse(m[2]!);
  if (m[3] != null) {
    final y = int.parse(m[3]!);
    return _valid(y < 100 ? 2000 + y : y, month, dom);
  }
  DateTime? best;
  for (final y in [near.year - 1, near.year, near.year + 1]) {
    final c = _valid(y, month, dom);
    if (c != null && (best == null || c.difference(near).abs() < best.difference(near).abs())) best = c;
  }
  return best;
}

DateTime? _valid(int y, int m, int d) {
  final x = day(y, m, d);
  return x.year == y && x.month == m && x.day == d ? x : null;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/project.dart';
import '../state/project_controller.dart';
import 'gantt/gantt_painter.dart';

/// Column widths of the task grid.
class GridColumns {
  static const id = 40.0;
  static const name = 300.0;
  static const days = 60.0;
  static const start = 100.0;
  static const finish = 100.0;
  static const links = 110.0;
  static const width = id + name + days + start + finish + links;
}

class TaskGridHeader extends StatelessWidget {
  const TaskGridHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    Widget cell(String text, double w, {TextAlign align = TextAlign.left, String? tip}) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Tooltip(message: tip ?? '', child: Text(text, style: style, textAlign: align)),
          ),
        );
    return Container(
      height: GanttLayout.headerHeight,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GanttColors.weekLine))),
      child: Row(children: [
        cell('#', GridColumns.id, align: TextAlign.right),
        cell('Task', GridColumns.name),
        cell('Days', GridColumns.days, align: TextAlign.right, tip: 'Working days. 0 makes a milestone.'),
        cell('Start', GridColumns.start, tip: 'Type a date to pin the start (start no earlier than). Clear it to unpin.'),
        cell('Finish', GridColumns.finish),
        cell('After', GridColumns.links, tip: 'Predecessor task numbers, e.g. "2, 5+3" (5 plus 3 working days).'),
      ]),
    );
  }
}

/// One editable row; the height matches the chart's rows.
class TaskGridRow extends StatelessWidget {
  const TaskGridRow({super.key, required this.controller, required this.index});

  final ProjectController controller;
  final int index;

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
            width: GridColumns.id,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('${t.id}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: GanttColors.muted)),
            ),
          ),
          SizedBox(
            width: GridColumns.name,
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
            width: GridColumns.days,
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
            width: GridColumns.start,
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
          SizedBox(width: GridColumns.finish, child: _ReadOnly(formatDay(d.finish), weight: bold)),
          SizedBox(
            width: GridColumns.links,
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

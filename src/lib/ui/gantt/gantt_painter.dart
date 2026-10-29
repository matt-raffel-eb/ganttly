import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/scheduler.dart';
import '../../model/project.dart';

/// Sizes and the date range shared by the grid, the chart and the PNG export.
class GanttLayout {
  GanttLayout(this.schedule, {this.dayWidth = 22, DateTime? today})
      : today = dateOnly(today ?? DateTime.now()) {
    final s = schedule;
    var first = s.start;
    var last = s.finish;
    final deadline = s.project.deadline;
    if (deadline != null && deadline.isAfter(last)) last = deadline;
    // A little room on both sides, starting on a Monday.
    first = first.subtract(Duration(days: first.weekday - DateTime.monday + 7));
    last = last.add(Duration(days: 14 - (last.weekday - DateTime.monday)));
    rangeStart = first;
    days = last.difference(first).inDays + 1;
  }

  static const double rowHeight = 28;
  static const double headerHeight = 44;

  final Schedule schedule;
  final double dayWidth;
  final DateTime today;
  late final DateTime rangeStart;
  late final int days;

  double get width => days * dayWidth;
  double get rowsHeight => schedule.project.tasks.length * rowHeight;

  double x(DateTime d) => dateOnly(d).difference(rangeStart).inDays * dayWidth;
  DateTime dayAt(int i) => rangeStart.add(Duration(days: i));
}

/// Colours used by the chart.
class GanttColors {
  static const weekend = Color(0xFFF1F1F3);
  static const gridLine = Color(0xFFE4E4E8);
  static const weekLine = Color(0xFFD2D2D8);
  static const text = Color(0xFF1F2330);
  static const muted = Color(0xFF6B7080);
  static const summary = Color(0xFF3A3F55);
  static const selected = Color(0x1A3D5AFE);
  static const today = Color(0xFF9AA0AE);
  static const deadline = Color(0xFFD93025);
  static const problem = Color(0xFFD93025);
  static const link = Color(0xFF8A8FA0);

  /// One colour per top-level block, in order.
  static const palette = [
    Color(0xFF4472C4),
    Color(0xFFED7D31),
    Color(0xFF70AD47),
    Color(0xFF00A2C7),
    Color(0xFFBF8F00),
    Color(0xFF8E5BD0),
    Color(0xFF5E7C8B),
    Color(0xFFD45D79),
  ];
}

/// The two-line date header: month names over day numbers.
class GanttHeaderPainter extends CustomPainter {
  GanttHeaderPainter(this.layout);

  final GanttLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final cal = l.schedule.calendar;
    final deadline = l.schedule.project.deadline;
    canvas.drawRect(Offset.zero & Size(l.width, GanttLayout.headerHeight), Paint()..color = Colors.white);
    for (var i = 0; i < l.days; i++) {
      final d = l.dayAt(i);
      final x = i * l.dayWidth;
      if (!cal.isWorkday(d)) {
        canvas.drawRect(Rect.fromLTWH(x, 18, l.dayWidth, GanttLayout.headerHeight - 18), Paint()..color = GanttColors.weekend);
      }
      if (deadline != null && d == deadline) {
        canvas.drawRect(Rect.fromLTWH(x, 18, l.dayWidth, GanttLayout.headerHeight - 18), Paint()..color = GanttColors.deadline.withValues(alpha: 0.18));
      }
      if (i == 0 || d.day == 1) {
        _text(canvas, _monthLabel(d), Offset(x + 3, 2), 11, bold: true);
        if (i != 0) canvas.drawLine(Offset(x, 0), Offset(x, 18), Paint()..color = GanttColors.weekLine);
      }
      final isDeadline = deadline != null && d == deadline;
      final style = isDeadline ? GanttColors.deadline : (d == l.today ? GanttColors.text : GanttColors.muted);
      if (l.dayWidth >= 14) {
        _text(canvas, 'MTWTFSS'[d.weekday - 1], Offset(x + l.dayWidth / 2, 18), 9, color: style, center: true);
      }
      // Zoomed far out, only Mondays are numbered so the numbers don't overlap.
      if (l.dayWidth >= 14 || d.weekday == DateTime.monday) {
        _text(canvas, '${d.day}', Offset(x + (l.dayWidth >= 14 ? l.dayWidth / 2 : 1), 29), 9,
            color: style, center: l.dayWidth >= 14, bold: d == l.today);
      }
    }
    canvas.drawLine(Offset(0, GanttLayout.headerHeight - 0.5), Offset(l.width, GanttLayout.headerHeight - 0.5),
        Paint()..color = GanttColors.weekLine);
  }

  @override
  bool shouldRepaint(GanttHeaderPainter old) =>
      old.layout.schedule != layout.schedule || old.layout.dayWidth != layout.dayWidth;
}

/// The rows: weekend shading, bars, milestones, links, today and the deadline.
class GanttBodyPainter extends CustomPainter {
  GanttBodyPainter(this.layout, {this.selected, this.minHeight = 0});

  final GanttLayout layout;
  final int? selected;
  final double minHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    final s = l.schedule;
    final p = s.project;
    final height = math.max(l.rowsHeight, math.max(minHeight, size.height));
    canvas.drawRect(Offset.zero & Size(l.width, height), Paint()..color = Colors.white);

    // Non-working days and the deadline column.
    for (var i = 0; i < l.days; i++) {
      final d = l.dayAt(i);
      final x = i * l.dayWidth;
      if (!s.calendar.isWorkday(d)) {
        canvas.drawRect(Rect.fromLTWH(x, 0, l.dayWidth, height), Paint()..color = GanttColors.weekend);
      }
      if (d.weekday == DateTime.monday) {
        canvas.drawLine(Offset(x, 0), Offset(x, height), Paint()..color = GanttColors.gridLine);
      }
      if (p.deadline != null && d == p.deadline) {
        canvas.drawRect(Rect.fromLTWH(x, 0, l.dayWidth, height), Paint()..color = GanttColors.deadline.withValues(alpha: 0.12));
      }
    }

    // Row lines and the selected row.
    for (var r = 0; r < p.tasks.length; r++) {
      final y = r * GanttLayout.rowHeight;
      if (r == selected) {
        canvas.drawRect(Rect.fromLTWH(0, y, l.width, GanttLayout.rowHeight), Paint()..color = GanttColors.selected);
      }
      canvas.drawLine(Offset(0, y + GanttLayout.rowHeight - 0.5), Offset(l.width, y + GanttLayout.rowHeight - 0.5),
          Paint()..color = GanttColors.gridLine);
    }

    _paintLinks(canvas);

    // Bars.
    var block = -1;
    for (var r = 0; r < p.tasks.length; r++) {
      final t = p.tasks[r];
      if (t.outlineLevel == 0) block++;
      final colour = GanttColors.palette[math.max(block, 0) % GanttColors.palette.length];
      final d = s[t.id];
      final y = r * GanttLayout.rowHeight;
      if (d.isMilestone) {
        _diamond(canvas, Offset(l.x(d.start) + l.dayWidth / 2, y + GanttLayout.rowHeight / 2), 6,
            d.problem != null ? GanttColors.problem : colour);
        _text(canvas, t.name, Offset(l.x(d.start) + l.dayWidth / 2 + 10, y + 8), 10, color: GanttColors.muted);
        continue;
      }
      final left = l.x(d.start);
      final right = l.x(d.finish) + l.dayWidth;
      if (d.isSummary) {
        final rect = Rect.fromLTRB(left, y + 9, right, y + 15);
        canvas.drawRect(rect, Paint()..color = GanttColors.summary);
        final cap = Path()
          ..moveTo(left, y + 9)
          ..lineTo(left + 6, y + 9)
          ..lineTo(left, y + 21)
          ..close()
          ..moveTo(right, y + 9)
          ..lineTo(right - 6, y + 9)
          ..lineTo(right, y + 21)
          ..close();
        canvas.drawPath(cap, Paint()..color = GanttColors.summary);
      } else {
        // Working-day segments only, so a bar breaks over weekends and holidays.
        final rrect = RRect.fromRectAndRadius(Rect.fromLTRB(left, y + 6, right, y + GanttLayout.rowHeight - 6), const Radius.circular(3));
        canvas.drawRRect(rrect, Paint()..color = colour.withValues(alpha: 0.28));
        for (var day = d.start; !day.isAfter(d.finish); day = day.add(const Duration(days: 1))) {
          if (!s.calendar.isWorkday(day)) continue;
          canvas.drawRect(Rect.fromLTWH(l.x(day), y + 6, l.dayWidth, GanttLayout.rowHeight - 12), Paint()..color = colour);
        }
        if (t.percentComplete > 0) {
          final w = (right - left) * t.percentComplete / 100;
          canvas.drawRect(Rect.fromLTWH(left, y + 12, w, 4), Paint()..color = Colors.black.withValues(alpha: 0.35));
        }
      }
      if (d.problem != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(left - 2, y + 4, right + 2, y + GanttLayout.rowHeight - 4), const Radius.circular(4)),
          Paint()
            ..color = GanttColors.problem
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // Today: a faint dotted line through the middle of its column.
    final tx = l.x(l.today) + l.dayWidth / 2;
    if (tx >= 0 && tx <= l.width) {
      final paint = Paint()
        ..color = GanttColors.today
        ..strokeWidth = 1;
      for (var y = 0.0; y < height; y += 6) {
        canvas.drawLine(Offset(tx, y), Offset(tx, math.min(y + 3, height)), paint);
      }
    }
  }

  void _paintLinks(Canvas canvas) {
    final l = layout;
    final s = l.schedule;
    final p = s.project;
    final paint = Paint()
      ..color = GanttColors.link
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rowOf = {for (var r = 0; r < p.tasks.length; r++) p.tasks[r].id: r};
    for (var r = 0; r < p.tasks.length; r++) {
      final t = p.tasks[r];
      final to = s[t.id];
      for (final dep in t.dependencies) {
        final fromRow = rowOf[dep.taskId];
        if (fromRow == null || dep.taskId == t.id) continue;
        final from = s[dep.taskId];
        final x1 = from.isMilestone ? l.x(from.finish) + l.dayWidth / 2 + 6 : l.x(from.finish) + l.dayWidth;
        final y1 = fromRow * GanttLayout.rowHeight + GanttLayout.rowHeight / 2;
        final x2 = to.isMilestone ? l.x(to.start) + l.dayWidth / 2 - 6 : l.x(to.start);
        final y2 = r * GanttLayout.rowHeight + GanttLayout.rowHeight / 2;
        final path = Path()..moveTo(x1, y1);
        if (x2 >= x1 + 8) {
          path
            ..lineTo(x1 + 4, y1)
            ..lineTo(x1 + 4, y2)
            ..lineTo(x2, y2);
        } else {
          // The successor starts before the predecessor's bar ends: go round.
          final yMid = (y2 > y1 ? r * GanttLayout.rowHeight : (r + 1) * GanttLayout.rowHeight).toDouble();
          path
            ..lineTo(x1 + 4, y1)
            ..lineTo(x1 + 4, yMid)
            ..lineTo(x2 - 6, yMid)
            ..lineTo(x2 - 6, y2)
            ..lineTo(x2, y2);
        }
        canvas.drawPath(path, paint);
        final head = Path()
          ..moveTo(x2, y2)
          ..lineTo(x2 - 5, y2 - 3.5)
          ..lineTo(x2 - 5, y2 + 3.5)
          ..close();
        canvas.drawPath(head, Paint()..color = GanttColors.link);
      }
    }
  }

  @override
  bool shouldRepaint(GanttBodyPainter old) =>
      old.layout.schedule != layout.schedule ||
      old.layout.dayWidth != layout.dayWidth ||
      old.selected != selected ||
      old.minHeight != minHeight;
}

void _diamond(Canvas canvas, Offset c, double r, Color colour) {
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close(),
    Paint()..color = colour,
  );
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

void _text(Canvas canvas, String s, Offset at, double size,
    {Color color = GanttColors.text, bool bold = false, bool center = false}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
}

/// Paints [text] for other painters (the PNG export's task table).
void paintGanttText(Canvas canvas, String text, Offset at, double size,
        {Color color = GanttColors.text, bool bold = false, double? maxWidth}) =>
    maxWidth == null
        ? _text(canvas, text, at, size, color: color, bold: bold)
        : (TextPainter(
            text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: maxWidth))
            .paint(canvas, at);

/// For tests: the chart as a picture.
ui.Picture recordGantt(GanttLayout layout) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  GanttHeaderPainter(layout).paint(c, Size(layout.width, GanttLayout.headerHeight));
  c.translate(0, GanttLayout.headerHeight);
  GanttBodyPainter(layout).paint(c, Size(layout.width, layout.rowsHeight));
  return rec.endRecording();
}

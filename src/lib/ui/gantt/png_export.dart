import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/scheduler.dart';
import 'gantt_painter.dart';

/// The whole chart as a PNG, not just the part on screen: a title, a task
/// table (name, start, finish) and the chart, drawn by the same painters as
/// the screen.
Future<Uint8List> ganttPng(GanttLayout layout, {double pixelRatio = 2}) async {
  final s = layout.schedule;
  final p = s.project;
  const titleHeight = 56.0;
  const tableWidth = 420.0;
  const pad = 16.0;
  final width = pad + tableWidth + layout.width + pad;
  final height = titleHeight + GanttLayout.headerHeight + layout.rowsHeight + pad;

  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(pixelRatio);
  c.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);

  // Title and dates.
  paintGanttText(c, p.name, const Offset(pad, 12), 18, bold: true);
  final late = s.isLate;
  final summary = StringBuffer('${_d(s.start)} – ${_d(s.finish)}');
  if (p.deadline != null) summary.write('   ·   Deadline ${_d(p.deadline!)}${late ? '  (late)' : ''}');
  paintGanttText(c, summary.toString(), const Offset(pad, 36), 11, color: late ? GanttColors.deadline : GanttColors.muted);

  // Task table.
  c.save();
  c.translate(pad, titleHeight);
  paintGanttText(c, 'Task', const Offset(4, 26), 11, bold: true);
  paintGanttText(c, 'Start', const Offset(tableWidth - 150, 26), 11, bold: true);
  paintGanttText(c, 'Finish', const Offset(tableWidth - 76, 26), 11, bold: true);
  c.drawLine(const Offset(0, GanttLayout.headerHeight - 0.5), const Offset(tableWidth, GanttLayout.headerHeight - 0.5),
      Paint()..color = GanttColors.weekLine);
  for (var r = 0; r < p.tasks.length; r++) {
    final t = p.tasks[r];
    final d = s[t.id];
    final y = GanttLayout.headerHeight + r * GanttLayout.rowHeight;
    final indent = 4 + t.outlineLevel * 14.0;
    paintGanttText(c, t.name, Offset(indent, y + 7), 11,
        bold: d.isSummary, maxWidth: tableWidth - 160 - indent, color: d.problem != null ? GanttColors.problem : GanttColors.text);
    paintGanttText(c, _d(d.start), Offset(tableWidth - 150, y + 7), 11, bold: d.isSummary);
    paintGanttText(c, _d(d.finish), Offset(tableWidth - 76, y + 7), 11, bold: d.isSummary);
    c.drawLine(Offset(0, y + GanttLayout.rowHeight - 0.5), Offset(tableWidth, y + GanttLayout.rowHeight - 0.5),
        Paint()..color = GanttColors.gridLine);
  }
  c.restore();

  // Chart.
  c.save();
  c.translate(pad + tableWidth, titleHeight);
  GanttHeaderPainter(layout).paint(c, Size(layout.width, GanttLayout.headerHeight));
  c.translate(0, GanttLayout.headerHeight);
  GanttBodyPainter(layout).paint(c, Size(layout.width, layout.rowsHeight));
  c.restore();

  final image = await rec.endRecording().toImage((width * pixelRatio).ceil(), (height * pixelRatio).ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _d(DateTime d) => '${_days[d.weekday - 1]} ${d.month}/${d.day}';

/// Used by tests and the export dialog to name the file.
String suggestedPngName(Schedule s) => '${s.project.name.replaceAll(RegExp(r'[^\w\- ]'), '').trim()}.png';

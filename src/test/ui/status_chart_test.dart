import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/engine/scheduler.dart';
import 'package:ganttly/model/project.dart';
import 'package:ganttly/ui/gantt/gantt_painter.dart';

void main() {
  test('the chart: Done keeps its colour and gets a tick; Cancelled is an outline with no fill', () async {
    // Three 2-day tasks starting on a Monday, one per status.
    final p = Project(name: 'P', start: day(2026, 11, 2), tasks: const [
      Task(id: 1, name: 'Open', durationDays: 2),
      Task(id: 2, name: 'Finished', durationDays: 2, status: TaskStatus.done),
      Task(id: 3, name: 'Dropped', durationDays: 2, status: TaskStatus.cancelled),
    ]);
    final layout = GanttLayout(computeSchedule(p), today: day(2027, 1, 1));
    final size = Size(layout.width, layout.rowsHeight);
    final rec = ui.PictureRecorder();
    GanttBodyPainter(layout).paint(Canvas(rec), size);
    final image = await rec.endRecording().toImage(size.width.ceil(), size.height.ceil());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    Color at(double x, double y) {
      final i = (y.floor() * image.width + x.floor()) * 4;
      return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    }

    final s = layout.schedule;
    double mid(int id) => layout.x(s[id].start) + layout.dayWidth / 2;
    double rowY(int r) => r * GanttLayout.rowHeight + GanttLayout.rowHeight / 2;
    double end(int id) => layout.x(s[id].finish) + layout.dayWidth;
    // Each top-level task starts a new colour.
    Color colour(int row) => GanttColors.palette[row];

    expect(at(mid(1), rowY(0) - 4), colour(0));
    expect(at(mid(2), rowY(1) - 4), colour(1), reason: 'a done bar keeps its colour');
    expect(at(mid(3), rowY(2) - 4), Colors.white, reason: 'a cancelled bar has no fill');

    bool tickNear(int row, int id) {
      for (var dx = 4.0; dx <= 14; dx++) {
        for (var dy = -5.0; dy <= 4; dy++) {
          final c = at(end(id) + dx, rowY(row) + dy);
          if (c.g > c.r + 0.2 && c.g > c.b + 0.2) return true; // green
        }
      }
      return false;
    }

    expect(tickNear(1, 2), isTrue, reason: 'done: a tick after the bar');
    expect(tickNear(0, 1), isFalse);
    image.dispose();
  });
}

import 'package:flutter/material.dart';

import '../model/project.dart';
import '../state/project_controller.dart';
import 'task_grid.dart';

/// Project name, start, deadline and holidays.
Future<void> showProjectSettings(BuildContext context, ProjectController controller) {
  return showDialog<void>(context: context, builder: (_) => _ProjectSettings(controller));
}

class _ProjectSettings extends StatefulWidget {
  const _ProjectSettings(this.controller);

  final ProjectController controller;

  @override
  State<_ProjectSettings> createState() => _ProjectSettingsState();
}

class _ProjectSettingsState extends State<_ProjectSettings> {
  late final Project p = widget.controller.project;
  late final TextEditingController _name = TextEditingController(text: p.name);
  late DateTime _start = p.start;
  late DateTime? _deadline = p.deadline;
  late final TextEditingController _holidays = TextEditingController(
    text: (p.holidays.toList()..sort()).map(_iso).join('\n'),
  );
  String? _holidayError;

  @override
  void dispose() {
    _name.dispose();
    _holidays.dispose();
    super.dispose();
  }

  Set<DateTime>? _parseHolidays() {
    final out = <DateTime>{};
    for (final line in _holidays.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
      final d = parseDay(line.split(RegExp(r'\s{2,}|\t|#')).first, near: _start);
      if (d == null) return null;
      out.add(d);
    }
    return out;
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      ).then((d) => d == null ? null : dateOnly(d));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Project settings'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 16),
          Row(children: [
            const SizedBox(width: 90, child: Text('Start')),
            TextButton(
              onPressed: () async {
                final d = await _pick(_start);
                if (d != null) setState(() => _start = d);
              },
              child: Text('${formatDay(_start)} ${_start.year}'),
            ),
          ]),
          Row(children: [
            const SizedBox(width: 90, child: Text('Deadline')),
            TextButton(
              onPressed: () async {
                final d = await _pick(_deadline ?? _start);
                if (d != null) setState(() => _deadline = d);
              },
              child: Text(_deadline == null ? 'None' : '${formatDay(_deadline!)} ${_deadline!.year}'),
            ),
            if (_deadline != null)
              IconButton(tooltip: 'No deadline', icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _deadline = null)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _holidays,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Holidays (one date per line, e.g. 2026-11-26)',
              helperText: 'Weekends are always non-working.',
              errorText: _holidayError,
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final holidays = _parseHolidays();
            if (holidays == null) {
              setState(() => _holidayError = 'Each line must be a date such as 2026-11-26 or 11/26.');
              return;
            }
            final name = _name.text.trim().isEmpty ? p.name : _name.text.trim();
            widget.controller.updateProject(
              name: name,
              start: _start,
              deadline: _deadline,
              clearDeadline: _deadline == null,
              holidays: holidays,
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

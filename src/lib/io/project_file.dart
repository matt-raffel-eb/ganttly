import 'dart:convert';

import '../model/project.dart';

/// The `.ganttly` file: UTF-8 JSON (docs/file-format.md).
///
/// Only what the user entered is saved; dates are worked out again on load.
class ProjectFile {
  static const int formatVersion = 1;
  static const String extension = 'ganttly';

  static String encode(Project p) => const JsonEncoder.withIndent('  ').convert(toJson(p));

  static Project decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      throw ProjectFileException('Not a Ganttly project file (${e.message}).');
    }
    if (json is! Map<String, dynamic>) throw const ProjectFileException('Not a Ganttly project file.');
    return fromJson(json);
  }

  static Map<String, dynamic> toJson(Project p) => {
        'format': 'ganttly',
        'version': formatVersion,
        'name': p.name,
        'start': _date(p.start),
        if (p.deadline != null) 'deadline': _date(p.deadline!),
        'holidays': (p.holidays.toList()..sort()).map(_date).toList(),
        'tasks': [
          for (final t in p.tasks)
            {
              'id': t.id,
              'name': t.name,
              'duration': t.durationDays,
              if (t.outlineLevel != 0) 'level': t.outlineLevel,
              if (t.dependencies.isNotEmpty)
                'dependsOn': [
                  for (final d in t.dependencies) d.lagDays == 0 ? d.taskId : {'id': d.taskId, 'lag': d.lagDays},
                ],
              if (t.startNoEarlierThan != null) 'startNoEarlierThan': _date(t.startNoEarlierThan!),
              if (t.percentComplete != 0) 'percentComplete': t.percentComplete,
              if (t.notes.isNotEmpty) 'notes': t.notes,
            },
        ],
      };

  static Project fromJson(Map<String, dynamic> j) {
    if (j['format'] != 'ganttly') throw const ProjectFileException('Not a Ganttly project file.');
    final version = j['version'];
    if (version is! int || version > formatVersion) {
      throw ProjectFileException('This file needs a newer Ganttly (file version $version).');
    }
    try {
      final tasks = <Task>[
        for (final t in (j['tasks'] as List? ?? const []).cast<Map<String, dynamic>>())
          Task(
            id: t['id'] as int,
            name: t['name'] as String? ?? '',
            durationDays: t['duration'] as int? ?? 1,
            outlineLevel: t['level'] as int? ?? 0,
            dependencies: [
              for (final d in (t['dependsOn'] as List? ?? const []))
                d is int ? Dependency(d) : Dependency(d['id'] as int, lagDays: d['lag'] as int? ?? 0),
            ],
            startNoEarlierThan: t['startNoEarlierThan'] == null ? null : _parse(t['startNoEarlierThan']),
            percentComplete: t['percentComplete'] as int? ?? 0,
            notes: t['notes'] as String? ?? '',
          ),
      ];
      final ids = tasks.map((t) => t.id).toSet();
      if (ids.length != tasks.length) throw const ProjectFileException('Two tasks share an id.');
      return Project(
        name: j['name'] as String? ?? 'Untitled project',
        start: _parse(j['start']),
        deadline: j['deadline'] == null ? null : _parse(j['deadline']),
        holidays: {for (final h in (j['holidays'] as List? ?? const [])) _parse(h)},
        tasks: tasks,
      );
    } on ProjectFileException {
      rethrow;
    } catch (e) {
      throw ProjectFileException('The project file is damaged ($e).');
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _parse(Object? s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s as String);
    if (m == null) throw ProjectFileException('Bad date "$s" (expected YYYY-MM-DD).');
    return day(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}

class ProjectFileException implements Exception {
  const ProjectFileException(this.message);
  final String message;

  @override
  String toString() => message;
}

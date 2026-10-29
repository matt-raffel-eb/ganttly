import '../model/project.dart';
import 'work_calendar.dart';

/// A task's computed dates, both inclusive working days.
class TaskDates {
  const TaskDates({required this.start, required this.finish, this.isSummary = false, this.isMilestone = false, this.problem});

  final DateTime start;
  final DateTime finish;
  final bool isSummary;
  final bool isMilestone;

  /// Why the dates couldn't be worked out normally (a circular or unknown
  /// dependency), or null.
  final String? problem;
}

/// The computed plan. It is rebuilt from the [Project] after every edit; it
/// is never edited or saved itself.
class Schedule {
  Schedule._(this.project, this.calendar, this.dates);

  final Project project;
  final WorkCalendar calendar;

  /// By task id.
  final Map<int, TaskDates> dates;

  DateTime get start => dates.values.fold(project.start, (m, d) => d.start.isBefore(m) ? d.start : m);
  DateTime get finish => dates.values.fold(project.start, (m, d) => d.finish.isAfter(m) ? d.finish : m);

  /// True when a deadline is set and the plan finishes after it.
  bool get isLate => project.deadline != null && finish.isAfter(project.deadline!);

  TaskDates operator [](int taskId) => dates[taskId]!;
}

/// Works out every task's dates.
///
/// Rules (finish-to-start only):
/// - A leaf starts on the first working day that is on or after the project
///   start, its own "start no earlier than", every ancestor's constraints, and
///   the day after each predecessor finishes (plus lag). It lasts its
///   duration in working days.
/// - A milestone (duration 0) sits on the day its latest predecessor
///   finishes, or on its earliest allowed day when it has none.
/// - A summary spans its rows. Its own dependencies and "start no earlier
///   than" hold back every row under it.
/// - A circular or unknown dependency is reported on the task and otherwise
///   ignored, so one bad link never blanks the chart.
Schedule computeSchedule(Project project) => _Scheduler(project).run();

class _Scheduler {
  _Scheduler(this.p) : cal = WorkCalendar(p.holidays);

  final Project p;
  final WorkCalendar cal;
  final Map<int, TaskDates> _done = {};
  final Set<int> _visiting = {};
  late final Map<int, int> _indexById = {for (var i = 0; i < p.tasks.length; i++) p.tasks[i].id: i};

  Schedule run() {
    for (final t in p.tasks) {
      _dates(t.id);
    }
    return Schedule._(p, cal, Map.unmodifiable(_done));
  }

  /// The rows directly or indirectly under the row at [index].
  Iterable<int> _descendants(int index) sync* {
    final level = p.tasks[index].outlineLevel;
    for (var i = index + 1; i < p.tasks.length && p.tasks[i].outlineLevel > level; i++) {
      yield i;
    }
  }

  /// The summaries above the row at [index], nearest first.
  Iterable<int> _ancestors(int index) sync* {
    var level = p.tasks[index].outlineLevel;
    for (var i = index - 1; i >= 0 && level > 0; i--) {
      if (p.tasks[i].outlineLevel < level) {
        yield i;
        level = p.tasks[i].outlineLevel;
      }
    }
  }

  TaskDates _dates(int id) {
    final known = _done[id];
    if (known != null) return known;
    final index = _indexById[id]!;
    final task = p.tasks[index];
    if (_visiting.contains(id)) {
      // Reached again while working it out: a loop. The caller reports it.
      throw _Circular(id);
    }
    _visiting.add(id);
    try {
      final result = p.isSummaryAt(index) ? _summary(index) : _leaf(index, task);
      _done[id] = result;
      return result;
    } finally {
      _visiting.remove(id);
    }
  }

  TaskDates _summary(int index) {
    DateTime? start, finish;
    String? problem;
    for (final i in _descendants(index)) {
      final d = _dates(p.tasks[i].id);
      if (start == null || d.start.isBefore(start)) start = d.start;
      if (finish == null || d.finish.isAfter(finish)) finish = d.finish;
    }
    // The summary's own links are applied to its rows; check them here too so a bad one shows.
    problem = _earliest(p.tasks[index], <String>[]).$2;
    return TaskDates(start: start!, finish: finish!, isSummary: true, problem: problem);
  }

  TaskDates _leaf(int index, Task task) {
    final problems = <String>[];
    var (earliest, _) = _earliest(task, problems);
    for (final a in _ancestors(index)) {
      final (fromAncestor, _) = _earliest(p.tasks[a], problems);
      if (fromAncestor.isAfter(earliest)) earliest = fromAncestor;
    }
    final problem = problems.isEmpty ? null : problems.toSet().join('; ');
    if (task.isMilestone) {
      final d = cal.onOrAfter(earliest);
      return TaskDates(start: d, finish: d, isMilestone: true, problem: problem);
    }
    final start = cal.onOrAfter(earliest);
    return TaskDates(start: start, finish: cal.addWorkdays(start, task.durationDays - 1), problem: problem);
  }

  /// The earliest day [task]'s own start rules allow, and any problem with them.
  (DateTime, String?) _earliest(Task task, List<String> problems) {
    var earliest = p.start;
    if (task.startNoEarlierThan != null && task.startNoEarlierThan!.isAfter(earliest)) {
      earliest = task.startNoEarlierThan!;
    }
    String? problem;
    for (final dep in task.dependencies) {
      if (!_indexById.containsKey(dep.taskId) || dep.taskId == task.id) {
        problem = dep.taskId == task.id ? 'Depends on itself' : 'Unknown predecessor ${dep.taskId}';
        problems.add(problem);
        continue;
      }
      final TaskDates pred;
      try {
        pred = _dates(dep.taskId);
      } on _Circular {
        problem = 'Circular dependency on ${dep.taskId}';
        problems.add(problem);
        continue;
      }
      // After a predecessor that takes time: the next working day. A milestone
      // that follows other work marks the end of its day, so the same applies;
      // a free-standing milestone marks the start of its day. A milestone
      // successor sits on the day the predecessor ends.
      final predTask = p.tasks[_indexById[dep.taskId]!];
      final startOfDayMarker = pred.isMilestone && predTask.dependencies.isEmpty;
      final next = task.isMilestone || startOfDayMarker ? pred.finish : cal.addWorkdays(pred.finish, 1);
      final allowed = dep.lagDays == 0 ? next : cal.addWorkdays(next, dep.lagDays);
      if (allowed.isAfter(earliest)) earliest = allowed;
    }
    return (earliest, problem);
  }
}

class _Circular implements Exception {
  const _Circular(this.id);
  final int id;
}

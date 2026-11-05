/// The project data: what the user edits and what the file stores.
///
/// Dates are calendar days with no time of day, held as UTC midnight
/// ([day]), so time zones never move a task.
library;

/// A calendar day as UTC midnight.
DateTime day(int year, int month, int dayOfMonth) => DateTime.utc(year, month, dayOfMonth);

/// [d] with its time of day dropped, as UTC midnight.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// A finish-to-start link: this task starts after [taskId] finishes, plus
/// [lagDays] working days (negative lag overlaps the two).
class Dependency {
  const Dependency(this.taskId, {this.lagDays = 0});

  final int taskId;
  final int lagDays;

  @override
  bool operator ==(Object other) => other is Dependency && other.taskId == taskId && other.lagDays == lagDays;

  @override
  int get hashCode => Object.hash(taskId, lagDays);

  @override
  String toString() => lagDays == 0 ? '$taskId' : '$taskId${lagDays > 0 ? '+' : ''}$lagDays';
}

/// Where a task stands. A summary's status is worked out from the tasks
/// under it ([Project.statusAt]); its own is ignored.
enum TaskStatus {
  notStarted('Not started'),
  started('Started'),
  done('Done'),
  cancelled('Cancelled');

  const TaskStatus(this.label);

  final String label;

  /// The file's value (the enum name); anything else reads as [notStarted].
  static TaskStatus fromJson(Object? v) => values.firstWhere((s) => s.name == v, orElse: () => notStarted);
}

/// One row of the plan. A task followed by rows with a deeper [outlineLevel]
/// is a summary: its dates come from those rows, and its own duration is
/// ignored. A leaf with [durationDays] 0 is a milestone.
class Task {
  const Task({
    required this.id,
    required this.name,
    this.durationDays = 1,
    this.outlineLevel = 0,
    this.dependencies = const [],
    this.startNoEarlierThan,
    this.percentComplete = 0,
    this.notes = '',
    this.status = TaskStatus.notStarted,
  });

  /// Stable across edits and reordering; dependencies point at it.
  final int id;
  final String name;

  /// Working days. 0 makes a milestone.
  final int durationDays;

  /// 0 is top level; each step in is one more.
  final int outlineLevel;
  final List<Dependency> dependencies;

  /// A pinned earliest start. Null: as soon as the project and the
  /// dependencies allow.
  final DateTime? startNoEarlierThan;
  final int percentComplete;
  final String notes;
  final TaskStatus status;

  bool get isMilestone => durationDays == 0;

  Task copyWith({
    String? name,
    int? durationDays,
    int? outlineLevel,
    List<Dependency>? dependencies,
    DateTime? startNoEarlierThan,
    bool clearStartNoEarlierThan = false,
    int? percentComplete,
    String? notes,
    TaskStatus? status,
  }) =>
      Task(
        id: id,
        name: name ?? this.name,
        durationDays: durationDays ?? this.durationDays,
        outlineLevel: outlineLevel ?? this.outlineLevel,
        dependencies: dependencies ?? this.dependencies,
        startNoEarlierThan: clearStartNoEarlierThan ? null : (startNoEarlierThan ?? this.startNoEarlierThan),
        percentComplete: percentComplete ?? this.percentComplete,
        notes: notes ?? this.notes,
        status: status ?? this.status,
      );
}

/// The whole plan: its start, its non-working days and its rows in order.
class Project {
  const Project({
    required this.name,
    required this.start,
    this.holidays = const {},
    this.tasks = const [],
    this.deadline,
  });

  final String name;

  /// No task starts before this day.
  final DateTime start;

  /// Non-working weekdays (weekends are always off).
  final Set<DateTime> holidays;
  final List<Task> tasks;

  /// Optional target finish; the chart marks it and flags a plan that runs past it.
  final DateTime? deadline;

  Project copyWith({
    String? name,
    DateTime? start,
    Set<DateTime>? holidays,
    List<Task>? tasks,
    DateTime? deadline,
    bool clearDeadline = false,
  }) =>
      Project(
        name: name ?? this.name,
        start: start ?? this.start,
        holidays: holidays ?? this.holidays,
        tasks: tasks ?? this.tasks,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
      );

  /// One more than the largest task id.
  int get nextTaskId => tasks.fold(0, (m, t) => t.id > m ? t.id : m) + 1;

  int indexOf(int taskId) => tasks.indexWhere((t) => t.id == taskId);

  /// True when the row at [index] has rows under it.
  bool isSummaryAt(int index) =>
      index + 1 < tasks.length && tasks[index + 1].outlineLevel > tasks[index].outlineLevel;

  /// The status of the row at [index]. For a summary, worked out from the
  /// tasks under it, leaving out cancelled ones: Done when all are done,
  /// Started when any is started or done, else Not started. A summary whose
  /// tasks are all cancelled is Cancelled.
  TaskStatus statusAt(int index) {
    if (!isSummaryAt(index)) return tasks[index].status;
    final level = tasks[index].outlineLevel;
    final under = <TaskStatus>[];
    for (var i = index + 1; i < tasks.length && tasks[i].outlineLevel > level; i++) {
      if (!isSummaryAt(i) && tasks[i].status != TaskStatus.cancelled) under.add(tasks[i].status);
    }
    if (under.isEmpty) return TaskStatus.cancelled;
    if (under.every((s) => s == TaskStatus.done)) return TaskStatus.done;
    if (under.any((s) => s != TaskStatus.notStarted)) return TaskStatus.started;
    return TaskStatus.notStarted;
  }

  factory Project.blank({DateTime? start}) {
    final s = dateOnly(start ?? DateTime.now());
    return Project(name: 'Untitled project', start: s, tasks: const [Task(id: 1, name: 'New task')]);
  }
}

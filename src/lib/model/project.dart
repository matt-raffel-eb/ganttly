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

  factory Project.blank({DateTime? start}) {
    final s = dateOnly(start ?? DateTime.now());
    return Project(name: 'Untitled project', start: s, tasks: const [Task(id: 1, name: 'New task')]);
  }
}

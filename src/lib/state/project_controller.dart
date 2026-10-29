import 'package:flutter/foundation.dart';

import '../engine/scheduler.dart';
import '../model/project.dart';

/// The open project and everything the screens need about it: the computed
/// schedule, the selected row, undo/redo and whether there are unsaved edits.
///
/// Every edit replaces the (immutable) [project], recomputes [schedule] and
/// notifies listeners, so the grid and the chart always show the same plan.
class ProjectController extends ChangeNotifier {
  ProjectController([Project? project]) : _project = project ?? Project.blank() {
    _schedule = computeSchedule(_project);
  }

  static const int _undoLimit = 200;

  Project _project;
  late Schedule _schedule;
  final List<Project> _undo = [];
  final List<Project> _redo = [];
  String? _filePath;
  bool _dirty = false;
  int? _selected;

  Project get project => _project;
  Schedule get schedule => _schedule;
  String? get filePath => _filePath;
  bool get isDirty => _dirty;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// The selected row index, or null.
  int? get selected => _selected;

  void select(int? index) {
    if (index == _selected) return;
    _selected = index == null || index < 0 || index >= _project.tasks.length ? null : index;
    notifyListeners();
  }

  // ---- files ----------------------------------------------------------------

  void newProject() => _replaceAll(Project.blank(), path: null);

  void opened(Project p, String path) => _replaceAll(p, path: path);

  void saved(String path) {
    _filePath = path;
    _dirty = false;
    notifyListeners();
  }

  void _replaceAll(Project p, {required String? path}) {
    _project = p;
    _schedule = computeSchedule(p);
    _undo.clear();
    _redo.clear();
    _filePath = path;
    _dirty = false;
    _selected = p.tasks.isEmpty ? null : 0;
    notifyListeners();
  }

  // ---- undo -----------------------------------------------------------------

  void _apply(Project next, {int? select}) {
    _undo.add(_project);
    if (_undo.length > _undoLimit) _undo.removeAt(0);
    _redo.clear();
    _set(next, select: select);
  }

  void _set(Project next, {int? select}) {
    _project = next;
    _schedule = computeSchedule(next);
    _dirty = true;
    if (select != null) {
      _selected = select;
    } else if (_selected != null && _selected! >= next.tasks.length) {
      _selected = next.tasks.isEmpty ? null : next.tasks.length - 1;
    }
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_project);
    _set(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_project);
    _set(_redo.removeLast());
  }

  // ---- project edits --------------------------------------------------------

  void updateProject({String? name, DateTime? start, DateTime? deadline, bool clearDeadline = false, Set<DateTime>? holidays}) {
    _apply(_project.copyWith(
      name: name,
      start: start == null ? null : dateOnly(start),
      deadline: deadline == null ? null : dateOnly(deadline),
      clearDeadline: clearDeadline,
      holidays: holidays?.map(dateOnly).toSet(),
    ));
  }

  // ---- task edits -----------------------------------------------------------

  void updateTask(int index, Task Function(Task) change) {
    final tasks = [..._project.tasks];
    final updated = change(tasks[index]);
    if (identical(updated, tasks[index])) return;
    tasks[index] = updated;
    _apply(_project.copyWith(tasks: tasks));
  }

  /// Adds a task below [after] (or at the end), at the same outline level,
  /// and selects it.
  void addTask({int? after}) {
    final tasks = [..._project.tasks];
    final at = after == null ? tasks.length : _endOfBlock(after) + 1;
    final level = after == null || tasks.isEmpty ? 0 : tasks[after].outlineLevel;
    tasks.insert(at, Task(id: _project.nextTaskId, name: 'New task', outlineLevel: level));
    _apply(_project.copyWith(tasks: tasks), select: at);
  }

  /// Deletes the row at [index] with the rows under it, and every link to them.
  void deleteTask(int index) {
    final end = _endOfBlock(index);
    final gone = {for (var i = index; i <= end; i++) _project.tasks[i].id};
    final tasks = [
      for (var i = 0; i < _project.tasks.length; i++)
        if (i < index || i > end)
          _project.tasks[i].copyWith(
            dependencies: _project.tasks[i].dependencies.where((d) => !gone.contains(d.taskId)).toList(),
          ),
    ];
    final select = tasks.isEmpty ? null : (index < tasks.length ? index : tasks.length - 1);
    _apply(_project.copyWith(tasks: tasks), select: select);
    if (tasks.isEmpty) _selected = null;
  }

  /// Moves the row at [index] (with the rows under it) one level in, under
  /// the row above. Not possible for the first row or past one level deeper
  /// than the row above.
  bool canIndent(int index) => index > 0 && _project.tasks[index].outlineLevel <= _project.tasks[index - 1].outlineLevel;
  bool canOutdent(int index) => _project.tasks[index].outlineLevel > 0;

  void indent(int index) {
    if (canIndent(index)) _shiftBlock(index, 1);
  }

  void outdent(int index) {
    if (canOutdent(index)) _shiftBlock(index, -1);
  }

  void _shiftBlock(int index, int by) {
    final end = _endOfBlock(index);
    final tasks = [
      for (var i = 0; i < _project.tasks.length; i++)
        i >= index && i <= end ? _project.tasks[i].copyWith(outlineLevel: _project.tasks[i].outlineLevel + by) : _project.tasks[i],
    ];
    _apply(_project.copyWith(tasks: tasks), select: index);
  }

  /// Moves the row at [index] (with the rows under it) above the previous
  /// block at the same level (up) or below the next one (down).
  void moveUp(int index) {
    final level = _project.tasks[index].outlineLevel;
    var prev = index - 1;
    while (prev >= 0 && _project.tasks[prev].outlineLevel > level) {
      prev--;
    }
    if (prev < 0 || _project.tasks[prev].outlineLevel < level) return;
    _swapBlocks(prev, index, moved: index);
  }

  void moveDown(int index) {
    final next = _endOfBlock(index) + 1;
    if (next >= _project.tasks.length || _project.tasks[next].outlineLevel != _project.tasks[index].outlineLevel) return;
    _swapBlocks(index, next, moved: index);
  }

  /// Swaps the adjacent blocks starting at [first] and [second]; the row
  /// [moved] stays selected.
  void _swapBlocks(int first, int second, {required int moved}) {
    final t = _project.tasks;
    final a = t.sublist(first, second);
    final b = t.sublist(second, _endOfBlock(second) + 1);
    final tasks = [...t.sublist(0, first), ...b, ...a, ...t.sublist(_endOfBlock(second) + 1)];
    _apply(_project.copyWith(tasks: tasks), select: tasks.indexOf(t[moved]));
  }

  /// The last row of the block that starts at [index] (itself and the rows under it).
  int _endOfBlock(int index) {
    final level = _project.tasks[index].outlineLevel;
    var end = index;
    while (end + 1 < _project.tasks.length && _project.tasks[end + 1].outlineLevel > level) {
      end++;
    }
    return end;
  }
}

/// Reads a predecessor list such as "2, 5+3, 7-1": task ids, each with an
/// optional lag in working days. Returns null if any part isn't valid.
List<Dependency>? parseDependencies(String text) {
  final parts = text.split(RegExp(r'[,;\s]+')).where((s) => s.isNotEmpty);
  final out = <Dependency>[];
  for (final part in parts) {
    final m = RegExp(r'^(\d+)(?:([+-])(\d+))?$').firstMatch(part);
    if (m == null) return null;
    final lag = m[3] == null ? 0 : int.parse(m[3]!) * (m[2] == '-' ? -1 : 1);
    out.add(Dependency(int.parse(m[1]!), lagDays: lag));
  }
  return out;
}

String formatDependencies(List<Dependency> deps) => deps.join(', ');

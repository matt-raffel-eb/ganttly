import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/io/project_file.dart';
import 'package:ganttly/model/project.dart';

void main() {
  Project plan(List<TaskStatus> under) => Project(name: 'P', start: day(2026, 11, 2), tasks: [
        const Task(id: 1, name: 'Summary', status: TaskStatus.done), // its own status is ignored
        for (var i = 0; i < under.length; i++) Task(id: i + 2, name: 'T$i', outlineLevel: 1, status: under[i]),
      ]);

  test('a summary\'s status comes from the tasks under it', () {
    const n = TaskStatus.notStarted, s = TaskStatus.started, d = TaskStatus.done, x = TaskStatus.cancelled;
    expect(plan([n, n]).statusAt(0), n);
    expect(plan([n, s]).statusAt(0), s);
    expect(plan([n, d]).statusAt(0), s, reason: 'some work is done, so it has started');
    expect(plan([d, d]).statusAt(0), d);
    expect(plan([d, x]).statusAt(0), d, reason: 'cancelled tasks are left out');
    expect(plan([n, x]).statusAt(0), n);
    expect(plan([x, x]).statusAt(0), x);
    expect(plan([s, x]).statusAt(1), s, reason: 'a leaf has its own status');
  });

  test('nested summaries: only the leaves count', () {
    final p = Project(name: 'P', start: day(2026, 11, 2), tasks: const [
      Task(id: 1, name: 'Top'),
      Task(id: 2, name: 'Middle', outlineLevel: 1, status: TaskStatus.notStarted),
      Task(id: 3, name: 'Leaf A', outlineLevel: 2, status: TaskStatus.done),
      Task(id: 4, name: 'Leaf B', outlineLevel: 1, status: TaskStatus.done),
    ]);
    expect(p.statusAt(0), TaskStatus.done);
    expect(p.statusAt(1), TaskStatus.done);
  });

  test('status is saved, left out when Not started, and an unknown value reads as Not started', () {
    final p = Project(name: 'P', start: day(2026, 11, 2), tasks: const [
      Task(id: 1, name: 'A', status: TaskStatus.cancelled),
      Task(id: 2, name: 'B'),
    ]);
    final json = ProjectFile.toJson(p);
    final tasks = json['tasks'] as List;
    expect(tasks[0]['status'], 'cancelled');
    expect((tasks[1] as Map).containsKey('status'), isFalse);
    expect(ProjectFile.decode(ProjectFile.encode(p)).tasks.map((t) => t.status), [TaskStatus.cancelled, TaskStatus.notStarted]);

    tasks[0]['status'] = 'paused';
    expect(ProjectFile.fromJson(json).tasks[0].status, TaskStatus.notStarted);
  });
}

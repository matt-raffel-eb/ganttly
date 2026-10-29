import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/io/project_file.dart';
import 'package:ganttly/model/project.dart';
import 'package:ganttly/state/project_controller.dart';

import '../sample.dart';

void main() {
  ProjectController three() => ProjectController(Project(
        name: 'p',
        start: day(2026, 11, 2),
        tasks: const [
          Task(id: 1, name: 'a', durationDays: 2),
          Task(id: 2, name: 'b', dependencies: [Dependency(1)]),
          Task(id: 3, name: 'c', dependencies: [Dependency(2)]),
        ],
      ));

  test('an edit recomputes the schedule, marks the project edited and can be undone and redone', () {
    final c = three();
    expect(c.schedule[3].start, day(2026, 11, 5));
    c.updateTask(0, (t) => t.copyWith(durationDays: 4));
    expect(c.schedule[3].start, day(2026, 11, 9));
    expect(c.isDirty, isTrue);
    c.undo();
    expect(c.schedule[3].start, day(2026, 11, 5));
    c.redo();
    expect(c.schedule[3].start, day(2026, 11, 9));
  });

  test('deleting a task removes the links to it', () {
    final c = three()..deleteTask(1);
    expect(c.project.tasks.map((t) => t.id), [1, 3]);
    expect(c.project.tasks[1].dependencies, isEmpty);
  });

  test('add, indent, outdent and move keep blocks together', () {
    final c = three()..addTask(after: 0);
    expect(c.project.tasks[1].id, 4);
    expect(c.selected, 1);
    c.indent(1);
    expect(c.project.tasks[1].outlineLevel, 1);
    expect(c.project.isSummaryAt(0), isTrue);
    expect(c.canIndent(1), isFalse, reason: 'already one level under the row above');
    c.moveDown(0); // the a-block (a + its child) moves below b
    expect(c.project.tasks.map((t) => t.id), [2, 1, 4, 3]);
    expect(c.selected, 1);
    c.outdent(2);
    expect(c.project.tasks[2].outlineLevel, 0);
  });

  test('predecessor text: ids with optional lag', () {
    expect(parseDependencies('2, 5+3 7-1'), const [Dependency(2), Dependency(5, lagDays: 3), Dependency(7, lagDays: -1)]);
    expect(parseDependencies(''), isEmpty);
    expect(parseDependencies('two'), isNull);
    expect(formatDependencies(const [Dependency(2), Dependency(5, lagDays: 3)]), '2, 5+3');
  });

  test('the project file round-trips', () {
    final p = sampleFromFile();
    final back = ProjectFile.decode(ProjectFile.encode(p));
    expect(ProjectFile.encode(back), ProjectFile.encode(p));
    expect(back.holidays, contains(day(2026, 11, 26)));
    expect(back.deadline, day(2026, 12, 18));
  });

  test('a bad or newer file is refused with a message', () {
    expect(() => ProjectFile.decode('nope'), throwsA(isA<ProjectFileException>()));
    expect(() => ProjectFile.decode('{"format":"ganttly","version":99}'),
        throwsA(isA<ProjectFileException>().having((e) => e.message, 'message', contains('newer'))));
    expect(() => ProjectFile.decode('{"format":"ganttly","version":1,"start":"11/2","tasks":[]}'),
        throwsA(isA<ProjectFileException>()));
  });
}

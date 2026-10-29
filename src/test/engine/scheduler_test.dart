import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/engine/scheduler.dart';
import 'package:ganttly/engine/work_calendar.dart';
import 'package:ganttly/model/project.dart';

import '../sample.dart';

void main() {
  group('WorkCalendar', () {
    final cal = WorkCalendar({day(2026, 11, 26), day(2026, 11, 27)});

    test('weekends and holidays are off', () {
      expect(cal.isWorkday(day(2026, 10, 30)), isTrue); // Fri
      expect(cal.isWorkday(day(2026, 10, 31)), isFalse); // Sat
      expect(cal.isWorkday(day(2026, 11, 26)), isFalse); // Thanksgiving
    });

    test('addWorkdays works like Excel WORKDAY', () {
      expect(cal.addWorkdays(day(2026, 10, 30), 1), day(2026, 11, 2));
      expect(cal.addWorkdays(day(2026, 11, 23), 4), day(2026, 12, 1)); // over Thanksgiving
      expect(cal.addWorkdays(day(2026, 11, 23), -1), day(2026, 11, 20));
      expect(cal.addWorkdays(day(2026, 11, 23), 0), day(2026, 11, 23));
    });

    test('workdaysBetween works like NETWORKDAYS', () {
      expect(cal.workdaysBetween(day(2026, 11, 23), day(2026, 12, 1)), 5);
      expect(cal.onOrAfter(day(2026, 10, 31)), day(2026, 11, 2));
    });
  });

  group('computeSchedule', () {
    Project p(List<Task> tasks, {Set<DateTime> holidays = const {}}) =>
        Project(name: 't', start: day(2026, 11, 2), holidays: holidays, tasks: tasks);

    test('a task starts at the project start and lasts its working days', () {
      final s = computeSchedule(p([const Task(id: 1, name: 'a', durationDays: 3)]));
      expect(s[1].start, day(2026, 11, 2));
      expect(s[1].finish, day(2026, 11, 4));
    });

    test('a successor starts the working day after its predecessor, plus lag', () {
      final s = computeSchedule(p([
        const Task(id: 1, name: 'a', durationDays: 5), // Mon-Fri
        const Task(id: 2, name: 'b', dependencies: [Dependency(1)]),
        const Task(id: 3, name: 'c', dependencies: [Dependency(1, lagDays: 2)]),
        const Task(id: 4, name: 'd', dependencies: [Dependency(1, lagDays: -2)]),
      ]));
      expect(s[2].start, day(2026, 11, 9));
      expect(s[3].start, day(2026, 11, 11));
      expect(s[4].start, day(2026, 11, 5));
    });

    test('a pinned start holds a task back but never pulls it earlier', () {
      final s = computeSchedule(p([
        Task(id: 1, name: 'a', startNoEarlierThan: day(2026, 11, 7)), // Sat: next working day
        Task(id: 2, name: 'b', startNoEarlierThan: day(2026, 10, 1)),
      ]));
      expect(s[1].start, day(2026, 11, 9));
      expect(s[2].start, day(2026, 11, 2));
    });

    test('milestones: after work they sit on its last day and the next task starts the day after', () {
      final s = computeSchedule(p([
        const Task(id: 1, name: 'build', durationDays: 5),
        const Task(id: 2, name: 'done', durationDays: 0, dependencies: [Dependency(1)]),
        const Task(id: 3, name: 'next', dependencies: [Dependency(2)]),
        const Task(id: 4, name: 'kickoff', durationDays: 0),
        const Task(id: 5, name: 'first', dependencies: [Dependency(4)]),
      ]));
      expect(s[2].start, day(2026, 11, 6));
      expect(s[2].isMilestone, isTrue);
      expect(s[3].start, day(2026, 11, 9));
      expect(s[5].start, day(2026, 11, 2), reason: 'a free-standing milestone marks the start of its day');
    });

    test('a summary spans its rows, and its own links hold back every row under it', () {
      final s = computeSchedule(p([
        const Task(id: 1, name: 'first', durationDays: 3),
        const Task(id: 2, name: 'phase', dependencies: [Dependency(1)]),
        const Task(id: 3, name: 'x', durationDays: 2, outlineLevel: 1),
        const Task(id: 4, name: 'y', durationDays: 1, outlineLevel: 1, dependencies: [Dependency(3)]),
      ]));
      expect(s[2].isSummary, isTrue);
      expect(s[3].start, day(2026, 11, 5));
      expect(s[2].start, day(2026, 11, 5));
      expect(s[2].finish, day(2026, 11, 9));
    });

    test('holidays move the work', () {
      final s = computeSchedule(p(
        [Task(id: 1, name: 'a', durationDays: 3, startNoEarlierThan: day(2026, 11, 25))],
        holidays: {day(2026, 11, 26), day(2026, 11, 27)},
      ));
      expect(s[1].finish, day(2026, 12, 1));
    });

    test('circular, self and unknown links are reported, not fatal', () {
      final s = computeSchedule(p([
        const Task(id: 1, name: 'a', dependencies: [Dependency(2)]),
        const Task(id: 2, name: 'b', dependencies: [Dependency(1)]),
        const Task(id: 3, name: 'c', dependencies: [Dependency(3)]),
        const Task(id: 4, name: 'd', dependencies: [Dependency(99)]),
      ]));
      expect([s[1].problem, s[2].problem].whereType<String>().single, contains('Circular'));
      expect(s[3].problem, 'Depends on itself');
      expect(s[4].problem, 'Unknown predecessor 99');
      expect(s[4].start, day(2026, 11, 2));
    });

    test('the sample (Website relaunch) schedules as planned: go live Fri 12/18, on the deadline', () {
      final s = computeSchedule(sampleFromFile());
      TaskDates of(String name) => s[s.project.tasks.firstWhere((t) => t.name == name).id];
      expect(of('Requirements signed off').start, day(2026, 11, 4));
      expect(of('Information architecture').start, day(2026, 11, 5));
      expect(of('Page templates and components').finish, day(2026, 11, 30), reason: 'over Thanksgiving');
      expect(of('Migrate content').start, day(2026, 12, 7));
      expect(of('Go live').start, day(2026, 12, 18));
      expect(of('Launch announcement').start, day(2026, 12, 21));
      expect(s[1].isSummary, isTrue);
      expect(s.isLate, isTrue, reason: 'the announcement runs past the deadline');
    });
  });
}

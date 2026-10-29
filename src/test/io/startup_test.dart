import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ganttly/io/app_settings.dart';
import 'package:ganttly/io/project_file.dart';
import 'package:ganttly/io/startup.dart';
import 'package:ganttly/model/project.dart';

import '../sample.dart';

void main() {
  late Directory tmp;
  late AppSettings settings;
  final sample = Project(name: 'The sample', start: day(2026, 11, 2));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ganttly_test');
    settings = AppSettings(Directory('${tmp.path}/settings'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<StartupProject> start() => loadStartupProject(settings, sample: () async => sample);

  test('a fresh start (nothing remembered) opens the sample', () async {
    final s = await start();
    expect(s.project.name, 'The sample');
    expect(s.path, isNull);
    expect(s.notice, isNull);
  });

  test('after a project is opened or saved, the next start reopens it', () async {
    final file = File('${tmp.path}/plan.ganttly')..writeAsStringSync(ProjectFile.encode(sampleFromFile()));
    settings.rememberProject(file.path);
    expect(AppSettings(settings.directory).lastProjectPath, file.path, reason: 'kept on disk');
    final s = await start();
    expect(s.project.name, 'Website relaunch');
    expect(s.path, file.path);
    expect(s.notice, isNull);
  });

  test('a remembered file that is gone or damaged falls back to the sample, says so, and is forgotten', () async {
    settings.rememberProject('${tmp.path}/gone.ganttly');
    var s = await start();
    expect(s.project.name, 'The sample');
    expect(s.notice, contains('gone.ganttly'));
    expect(settings.lastProjectPath, isNull);

    final bad = File('${tmp.path}/bad.ganttly')..writeAsStringSync('not json');
    settings.rememberProject(bad.path);
    s = await start();
    expect(s.project.name, 'The sample');
    expect(s.notice, contains('bad.ganttly'));
  });

  test('a damaged settings file is ignored', () async {
    settings.directory.createSync(recursive: true);
    File('${settings.directory.path}/settings.json').writeAsStringSync('{oops');
    expect(settings.lastProjectPath, isNull);
    settings.rememberProject('/x.ganttly');
    expect(settings.lastProjectPath, '/x.ganttly');
  });
}

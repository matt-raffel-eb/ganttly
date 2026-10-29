import 'dart:io';

import '../model/project.dart';
import '../model/sample_project.dart';
import 'app_settings.dart';
import 'project_file.dart';

/// What the app opens with.
class StartupProject {
  const StartupProject(this.project, {this.path, this.notice});

  final Project project;

  /// The file it came from, or null for the sample.
  final String? path;

  /// A message to show once the window is up (e.g. the last project is gone).
  final String? notice;
}

/// The last project opened or saved, if it can still be read; otherwise the
/// sample. A last project that can't be read is forgotten, with a notice.
Future<StartupProject> loadStartupProject(
  AppSettings? settings, {
  Future<Project> Function() sample = loadSampleProject,
}) async {
  final path = settings?.lastProjectPath;
  String? notice;
  if (path != null) {
    final name = path.split(Platform.pathSeparator).last;
    try {
      return StartupProject(ProjectFile.decode(await File(path).readAsString()), path: path);
    } on FileSystemException {
      notice = 'Couldn\'t reopen $name: the file was moved or deleted. Showing the sample instead.';
    } on ProjectFileException catch (e) {
      notice = 'Couldn\'t reopen $name: ${e.message} Showing the sample instead.';
    }
    settings!.forgetProject();
  }
  return StartupProject(await sample(), notice: notice);
}

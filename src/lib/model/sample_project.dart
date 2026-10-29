import 'package:flutter/services.dart';

import '../io/project_file.dart';
import 'project.dart';

/// The example project the app opens with: a normal `.ganttly` file bundled
/// as an asset (assets/samples/), loaded like any project.
const String sampleAsset = 'assets/samples/website-relaunch.ganttly';

/// The bundled sample, or a blank project if it can't be read.
Future<Project> loadSampleProject([AssetBundle? bundle]) async {
  try {
    return ProjectFile.decode(await (bundle ?? rootBundle).loadString(sampleAsset));
  } on Exception {
    return Project.blank();
  }
}

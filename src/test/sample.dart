import 'dart:io';

import 'package:ganttly/io/project_file.dart';
import 'package:ganttly/model/project.dart';
import 'package:ganttly/model/sample_project.dart';

/// The bundled sample project, read straight from the file (tests run in src/).
Project sampleFromFile() => ProjectFile.decode(File(sampleAsset).readAsStringSync());

import 'package:flutter/material.dart';

import 'io/app_settings.dart';
import 'io/startup.dart';
import 'state/project_controller.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reopen the last project opened or saved; the sample on a first start.
  final settings = AppSettings.forThisMachine();
  final start = await loadStartupProject(settings);
  final controller = ProjectController(start.project);
  if (start.path != null) controller.opened(start.project, start.path!);
  runApp(GanttlyApp(controller: controller, settings: settings, startupNotice: start.notice));
}

class GanttlyApp extends StatelessWidget {
  const GanttlyApp({super.key, required this.controller, this.settings, this.startupNotice});

  final ProjectController controller;

  /// Where the last project is remembered; null keeps nothing (tests).
  final AppSettings? settings;
  final String? startupNotice;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ganttly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3D5AFE), useMaterial3: true, visualDensity: VisualDensity.compact),
      home: HomePage(controller: controller, settings: settings, startupNotice: startupNotice),
    );
  }
}

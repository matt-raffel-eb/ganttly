import 'package:flutter/material.dart';

import 'model/sample_project.dart';
import 'state/project_controller.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GanttlyApp(controller: ProjectController(await loadSampleProject())));
}

class GanttlyApp extends StatelessWidget {
  const GanttlyApp({super.key, required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ganttly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3D5AFE), useMaterial3: true, visualDensity: VisualDensity.compact),
      home: HomePage(controller: controller),
    );
  }
}

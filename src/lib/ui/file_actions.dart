import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../io/project_file.dart';
import '../state/project_controller.dart';
import 'gantt/gantt_painter.dart';
import 'gantt/png_export.dart';

const _projectTypes = [
  XTypeGroup(label: 'Ganttly project', extensions: [ProjectFile.extension], uniformTypeIdentifiers: ['public.json', 'public.data']),
];

/// New, Open, Save, Save As and Export PNG, with the dialogs they need.
class FileActions {
  FileActions(this.context, this.controller);

  final BuildContext context;
  final ProjectController controller;

  Future<void> newProject() async {
    if (await _okToDiscard()) controller.newProject();
  }

  Future<void> open() async {
    if (!await _okToDiscard()) return;
    final file = await openFile(acceptedTypeGroups: _projectTypes);
    if (file == null) return;
    try {
      controller.opened(ProjectFile.decode(await file.readAsString()), file.path);
    } on ProjectFileException catch (e) {
      _error('Couldn\'t open ${file.name}', e.message);
    } on FileSystemException catch (e) {
      _error('Couldn\'t open ${file.name}', e.message);
    }
  }

  /// Saves to the current file, or asks where when there is none. Returns
  /// false if the user cancelled or the save failed.
  Future<bool> save() async {
    final path = controller.filePath;
    if (path == null) return saveAs();
    return _write(path);
  }

  Future<bool> saveAs() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: _projectTypes,
      suggestedName: '${_safeName(controller.project.name)}.${ProjectFile.extension}',
    );
    if (location == null) return false;
    var path = location.path;
    if (!path.toLowerCase().endsWith('.${ProjectFile.extension}')) path = '$path.${ProjectFile.extension}';
    return _write(path);
  }

  Future<bool> _write(String path) async {
    try {
      await File(path).writeAsString(ProjectFile.encode(controller.project));
      controller.saved(path);
      return true;
    } on FileSystemException catch (e) {
      _error('Couldn\'t save', e.message);
      return false;
    }
  }

  Future<void> exportPng(double dayWidth) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [XTypeGroup(label: 'PNG image', extensions: ['png'])],
      suggestedName: '${_safeName(controller.project.name)}.png',
    );
    if (location == null) return;
    var path = location.path;
    if (!path.toLowerCase().endsWith('.png')) path = '$path.png';
    try {
      final bytes = await ganttPng(GanttLayout(controller.schedule, dayWidth: dayWidth));
      await File(path).writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${path.split(Platform.pathSeparator).last}')));
      }
    } on FileSystemException catch (e) {
      _error('Couldn\'t export the chart', e.message);
    }
  }

  /// True when there are no unsaved edits, or the user chose to discard or save them.
  Future<bool> _okToDiscard() async {
    if (!controller.isDirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save changes?'),
        content: Text('"${controller.project.name}" has unsaved changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: const Text('Don\'t save')),
          FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (choice == 'discard') return true;
    if (choice == 'save') return save();
    return false;
  }

  void _error(String title, String message) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }
}

String _safeName(String name) {
  final s = name.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
  return s.isEmpty ? 'project' : s;
}

import 'dart:convert';
import 'dart:io';

/// Small per-user settings kept between launches (`settings.json`): for now,
/// the last project opened or saved, so the app reopens it.
///
/// Stored in the usual place for each system:
/// - macOS: ~/Library/Application Support/Ganttly
/// - Windows: %APPDATA%\Ganttly
/// - Linux: $XDG_CONFIG_HOME/ganttly (or ~/.config/ganttly)
class AppSettings {
  AppSettings(this.directory);

  /// Where the settings file lives. Tests pass a temporary folder.
  final Directory directory;

  /// The settings folder for this user and system, or null if it can't be worked out.
  static AppSettings? forThisMachine() {
    final env = Platform.environment;
    String? dir;
    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null) dir = '$home/Library/Application Support/Ganttly';
    } else if (Platform.isWindows) {
      final appData = env['APPDATA'];
      if (appData != null) dir = '$appData\\Ganttly';
    } else if (Platform.isLinux) {
      final config = env['XDG_CONFIG_HOME'] ?? (env['HOME'] == null ? null : '${env['HOME']}/.config');
      if (config != null) dir = '$config/ganttly';
    }
    return dir == null ? null : AppSettings(Directory(dir));
  }

  File get _file => File('${directory.path}${Platform.pathSeparator}settings.json');

  Map<String, dynamic> _read() {
    try {
      final json = jsonDecode(_file.readAsStringSync());
      return json is Map<String, dynamic> ? json : {};
    } on Exception {
      return {}; // No file yet, or unreadable: start fresh.
    }
  }

  /// The project file to reopen on start-up, or null.
  String? get lastProjectPath => _read()['lastProject'] as String?;

  /// Remembers [path] as the project to reopen. Never throws: losing this
  /// setting must not stop an open or a save.
  void rememberProject(String path) {
    try {
      final s = _read()..['lastProject'] = path;
      directory.createSync(recursive: true);
      _file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(s));
    } on Exception {
      // Ignore: the app still works, it just opens the sample next time.
    }
  }

  void forgetProject() {
    try {
      final s = _read()..remove('lastProject');
      if (_file.existsSync()) _file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(s));
    } on Exception {
      // Ignore, as above.
    }
  }
}

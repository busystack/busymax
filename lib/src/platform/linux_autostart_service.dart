import 'dart:io';

import 'package:path/path.dart' as path;

import 'common/desktop_services.dart';

const busyMaxAutostartFileName = 'io.busystack.busymax-autostart.desktop';

final class LinuxAutostartService implements DesktopAutostartService {
  LinuxAutostartService({
    Map<String, String>? environment,
    String? executable,
    bool? isLinux,
  }) : _environment = environment ?? Platform.environment,
       _executable = executable ?? Platform.resolvedExecutable,
       _isLinux = isLinux ?? Platform.isLinux;

  final Map<String, String> _environment;
  final String _executable;
  final bool _isLinux;

  Future<bool> isEnabled() async {
    if (!_isLinux) return false;
    return _autostartFile().exists();
  }

  @override
  Future<DesktopAutostartState> state() async {
    return await isEnabled()
        ? DesktopAutostartState.enabled
        : DesktopAutostartState.disabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!_isLinux) {
      throw UnsupportedError('Launch at login is supported only on Linux.');
    }
    final file = _autostartFile();
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }

    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.$pid.tmp');
    try {
      await temporary.writeAsString(_desktopEntry());
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  File _autostartFile() {
    final configHome = _configHome();
    return File(path.join(configHome, 'autostart', busyMaxAutostartFileName));
  }

  String _configHome() {
    final configured = _environment['XDG_CONFIG_HOME']?.trim();
    if (configured != null && configured.isNotEmpty) {
      if (!path.isAbsolute(configured)) {
        throw const FileSystemException(
          'XDG_CONFIG_HOME must be an absolute path.',
        );
      }
      return configured;
    }
    final home = _environment['HOME']?.trim();
    if (home == null || home.isEmpty || !path.isAbsolute(home)) {
      throw const FileSystemException(
        'A user configuration directory is unavailable.',
      );
    }
    return path.join(home, '.config');
  }

  String _desktopEntry() {
    final snap = _environment['SNAP']?.trim().isNotEmpty ?? false;
    final command = snap
        ? 'busymax $busyMaxStartMinimizedArgument'
        : '${_desktopExecArgument(_executable)} '
              '$busyMaxStartMinimizedArgument';
    return '''[Desktop Entry]
Type=Application
Version=1.0
Name=BusyMax
Comment=Run BusyMax in the background for reminders
Exec=$command
Icon=io.busystack.busymax
Terminal=false
X-GNOME-Autostart-enabled=true
X-BusyMax-Autostart=true
''';
  }
}

String _desktopExecArgument(String value) {
  if (value.isEmpty || value.contains('\n') || value.contains('\r')) {
    throw const FormatException('The executable path is invalid.');
  }
  final escaped = value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll(r'$', r'\$')
      .replaceAll('`', r'\`')
      .replaceAll('%', '%%');
  return '"$escaped"';
}

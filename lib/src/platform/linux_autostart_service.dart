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
    final file = _autostartFile();
    final String contents;
    try {
      contents = await file.readAsString();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return false; // ENOENT
      rethrow;
    }
    final entry = <String, String>{};
    var inDesktopEntry = false;
    for (final rawLine in contents.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[')) {
        inDesktopEntry = line == '[Desktop Entry]';
        continue;
      }
      final separator = line.indexOf('=');
      if (inDesktopEntry && separator > 0) {
        entry[line.substring(0, separator).trim()] = line
            .substring(separator + 1)
            .trim();
      }
    }
    if (entry['Hidden'] == 'true' ||
        entry['X-GNOME-Autostart-enabled'] == 'false' ||
        entry['Type'] != 'Application' ||
        (entry['Exec']?.isEmpty ?? true)) {
      return false;
    }
    final desktops = (_environment['XDG_CURRENT_DESKTOP'] ?? '').split(':');
    final onlyShowIn = entry['OnlyShowIn']?.split(';');
    final notShowIn = entry['NotShowIn']?.split(';');
    if (onlyShowIn != null &&
        !desktops.any(
          (desktop) => desktop.isNotEmpty && onlyShowIn.contains(desktop),
        )) {
      return false;
    }
    if (notShowIn != null &&
        desktops.any(
          (desktop) => desktop.isNotEmpty && notShowIn.contains(desktop),
        )) {
      return false;
    }
    final tryExec = entry['TryExec'];
    if (tryExec != null && tryExec.isNotEmpty) {
      final candidates = path.isAbsolute(tryExec)
          ? [tryExec]
          : tryExec.contains('/')
          ? <String>[]
          : (_environment['PATH'] ?? '')
                .split(':')
                .where((part) => part.isNotEmpty)
                .map((directory) => path.join(directory, tryExec));
      for (final candidate in candidates) {
        final stat = await File(candidate).stat();
        if (stat.type == FileSystemEntityType.file && stat.mode & 0x49 != 0) {
          return true;
        }
      }
      return false;
    }
    return true;
  }

  @override
  Future<DesktopAutostartState> state() async {
    if (!_isLinux) return DesktopAutostartState.unavailable;
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
    final temporaryDirectory = await file.parent.createTemp(
      '.busymax-autostart-',
    );
    final temporary = File(path.join(temporaryDirectory.path, 'entry.desktop'));
    try {
      await temporary.writeAsString(_desktopEntry());
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
      await temporaryDirectory.delete();
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

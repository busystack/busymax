import 'dart:io';

import 'package:path/path.dart' as path;

import 'common/desktop_services.dart';

const busyMaxAutostartFileName = 'io.busystack.busymax-autostart.desktop';

final class LinuxAutostartService implements DesktopAutostartService {
  LinuxAutostartService({
    Map<String, String>? environment,
    String? executable,
    bool? isLinux,
    int? processId,
  }) : _environment = environment ?? Platform.environment,
       _executable = executable ?? Platform.resolvedExecutable,
       _isLinux = isLinux ?? Platform.isLinux,
       _processId = processId ?? pid;

  final Map<String, String> _environment;
  final String _executable;
  final bool _isLinux;
  final int _processId;
  Future<void> _mutationTail = Future<void>.value();

  Future<bool> isEnabled() async => (await state()).isEnabled;

  Future<String?> _readEntry(File file) async {
    try {
      return await file.readAsString();
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode == 2) return null; // ENOENT
      rethrow;
    }
  }

  Future<bool> _entryIsEnabled(String contents) async {
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
    if (_wasStartedByExternalDesktopEntry) {
      return DesktopAutostartState.enabledExternally;
    }
    // XDG uses the first existing entry, even when it is hidden or disabled.
    // Snap's autostart mechanism only uses its own user configuration file.
    for (final file in [_autostartFile(), ..._systemAutostartFiles()]) {
      final contents = await _readEntry(file);
      if (contents == null) continue;
      return await _entryIsEnabled(contents)
          ? DesktopAutostartState.enabled
          : DesktopAutostartState.disabled;
    }
    return DesktopAutostartState.disabled;
  }

  @override
  Future<void> setEnabled(bool enabled) {
    final ready = _mutationTail.then<void>(
      (_) {},
      // A failed write belongs to its caller and must not prevent a later
      // settings change from retrying the mutation.
      onError: (Object _, StackTrace _) {},
    );
    final mutation = ready.then((_) => _setEnabled(enabled));
    _mutationTail = mutation;
    return mutation;
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!_isLinux) {
      throw UnsupportedError('Launch at login is supported only on Linux.');
    }
    if (_wasStartedByExternalDesktopEntry) {
      throw StateError('Launch at login is managed by the desktop.');
    }
    final file = _autostartFile();
    if (!enabled) {
      for (final systemFile in _systemAutostartFiles()) {
        if (await _readEntry(systemFile) != null) {
          // Deleting the user entry would expose an inherited entry again.
          await _writeEntry(file, '''[Desktop Entry]
Type=Application
Name=BusyMax
Hidden=true
''');
          return;
        }
      }
      if (await file.exists()) await file.delete();
      return;
    }

    await _writeEntry(file, _desktopEntry());
  }

  Future<void> _writeEntry(File file, String contents) async {
    await file.parent.create(recursive: true);
    final temporaryDirectory = await file.parent.createTemp(
      '.busymax-autostart-',
    );
    final temporary = File(path.join(temporaryDirectory.path, 'entry.desktop'));
    try {
      await temporary.writeAsString(contents);
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

  bool get _isSnap => _environment['SNAP']?.trim().isNotEmpty ?? false;

  bool get _wasStartedByExternalDesktopEntry {
    if (!_isSnap) return false;
    // GIO metadata can be inherited from an IDE or terminal. Only use it when
    // it identifies this process, and never read/write paths outside the Snap.
    if (_environment['GIO_LAUNCHED_DESKTOP_FILE_PID'] != '$_processId') {
      return false;
    }
    final launchedFile = _environment['GIO_LAUNCHED_DESKTOP_FILE'];
    if (launchedFile == null || !path.isAbsolute(launchedFile)) return false;
    final normalized = path.normalize(launchedFile);
    return path.extension(normalized) == '.desktop' &&
        path.basename(path.dirname(normalized)) == 'autostart' &&
        !path.equals(
          path.dirname(normalized),
          path.normalize(path.join(_configHome(), 'autostart')),
        );
  }

  Iterable<File> _systemAutostartFiles() sync* {
    if (_isSnap) return;
    final configured = _environment['XDG_CONFIG_DIRS'];
    final directories = configured == null || configured.isEmpty
        ? ['/etc/xdg']
        : configured.split(':');
    for (final directory in directories.toSet()) {
      // The XDG base directory specification ignores relative paths.
      if (!path.isAbsolute(directory)) continue;
      yield File(path.join(directory, 'autostart', busyMaxAutostartFileName));
    }
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
    final command = _isSnap
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

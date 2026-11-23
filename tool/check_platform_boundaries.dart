import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _linuxOnlyPackages = <String>[
  'package:yaru/',
  'package:ubuntu_localizations/',
  'package:dbus/',
  'package:desktop_notifications/',
  'package:xdg_status_notifier_item/',
  'package:posix/',
];

const _fluentPackages = <String>[
  'package:fluent_ui/',
  'package:fluentui_system_icons/',
];

const _desktopOnlyPackages = <String>[
  ..._linuxOnlyPackages,
  ..._fluentPackages,
  'package:flutter_timezone/',
  'package:tray_manager/',
  'package:yaru_window/',
];

Iterable<String> _dependencies(String source) sync* {
  final parsed = parseString(content: source, throwIfDiagnostics: false);
  for (final directive in parsed.unit.directives) {
    if (directive is UriBasedDirective) {
      if (directive.uri.stringValue case final String uri) yield uri;
    }
    if (directive is NamespaceDirective) {
      for (final configuration in directive.configurations) {
        if (configuration.uri.stringValue case final String uri) yield uri;
      }
    }
  }
}

void main() {
  final root = Directory.current;
  final failures = findPlatformBoundaryViolations(root);
  if (failures.isNotEmpty) {
    stderr.writeln('BusyMax platform boundary violations:');
    for (final failure in failures) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('BusyMax platform boundaries are valid.');
}

List<String> findPlatformBoundaryViolations(Directory root) {
  final lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) {
    return ['BusyMax lib directory not found at ${lib.path}.'];
  }
  final failures = <String>[];
  final dartFiles = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final file in dartFiles) {
    final relative = _relative(root.path, file.path);
    final source = file.readAsStringSync();
    final isWindows =
        relative == 'lib/main_windows.dart' || relative.contains('/windows/');
    final isCommonPlatform =
        relative.contains('/app/common/') ||
        relative.contains('/ui/common/') ||
        relative.contains('/platform/common/');
    final isLinux =
        relative == 'lib/main_linux.dart' ||
        relative.contains('/linux/') ||
        _isLegacyLinuxPresentation(relative);
    final isSharedBusiness =
        relative.startsWith('lib/src/') &&
        !isWindows &&
        !isLinux &&
        !relative.contains('/presentation/');

    for (final import in _dependencies(source)) {
      if ((isWindows || isCommonPlatform) &&
          _linuxOnlyPackages.any(import.startsWith)) {
        failures.add('$relative imports Linux-only $import');
      }
      if ((isCommonPlatform || isSharedBusiness || isLinux) &&
          _fluentPackages.any(import.startsWith)) {
        failures.add('$relative imports Windows-only $import');
      }
      if (isWindows && _isLinuxSourceImport(import)) {
        failures.add('$relative imports Linux source $import');
      }
    }
  }

  _checkWindowsReachability(root, failures);
  _checkAndroidReachability(root, failures);
  _checkNativePluginIsolation(root, failures);
  failures.sort();
  return failures;
}

void _checkAndroidReachability(Directory root, List<String> failures) {
  for (final entry in const [
    'lib/main_android.dart',
    'lib/src/android/android_background.dart',
  ]) {
    _checkReachability(
      root,
      entry,
      entry == 'lib/main_android.dart'
          ? 'Android foreground graph'
          : 'Android headless graph',
      failures,
    );
  }
}

void _checkReachability(
  Directory root,
  String entry,
  String label,
  List<String> failures,
) {
  final entrypoint = File('${root.path}/$entry');
  if (!entrypoint.existsSync()) {
    failures.add('$label entrypoint is missing: $entry');
    return;
  }
  final queue = <File>[entrypoint];
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!visited.add(file.path) || !file.existsSync()) continue;
    final relative = _relative(root.path, file.path);
    for (final import in _dependencies(file.readAsStringSync())) {
      final resolved = _resolveLocalImport(root, file, import);
      final dependency = resolved == null
          ? import
          : _relative(root.path, resolved.path);
      if (_desktopOnlyPackages.any(import.startsWith) ||
          _isDesktopSourceImport(dependency)) {
        failures.add('$label: $relative reaches desktop-only $import');
      }
      if (resolved != null) queue.add(resolved);
    }
  }
}

void _checkNativePluginIsolation(Directory root, List<String> failures) {
  final linuxPlugins = File(
    '${root.path}/linux/flutter/generated_plugins.cmake',
  );
  if (linuxPlugins.existsSync()) {
    final source = linuxPlugins.readAsStringSync();
    if (source.contains('tray_manager')) {
      failures.add(
        'Linux plugin graph registers tray_manager instead of the existing '
        'DBus/XDG tray adapter.',
      );
    }
    if (source.contains('flutter_timezone')) {
      failures.add(
        'Linux plugin graph registers flutter_timezone instead of the '
        'existing Linux timezone source.',
      );
    }
  }
  final windowsPlugins = File(
    '${root.path}/windows/flutter/generated_plugins.cmake',
  );
  if (!windowsPlugins.existsSync()) {
    failures.add('Windows generated plugin graph is missing.');
    return;
  }
  final windowsSource = windowsPlugins.readAsStringSync();
  for (final plugin in const ['tray_manager', 'flutter_timezone']) {
    if (windowsSource.contains(plugin)) {
      failures.add(
        'Windows plugin graph still registers retired $plugin; '
        'BusyMax owns its tray and time-zone OS channels.',
      );
    }
  }
}

void _checkWindowsReachability(Directory root, List<String> failures) {
  final entrypoint = File('${root.path}/lib/main_windows.dart');
  final queue = <File>[entrypoint];
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!visited.add(file.path) || !file.existsSync()) continue;
    final relative = _relative(root.path, file.path);
    for (final import in _dependencies(file.readAsStringSync())) {
      final resolved = _resolveLocalImport(root, file, import);
      final dependency = resolved == null
          ? import
          : _relative(root.path, resolved.path);
      if (_linuxOnlyPackages.any(import.startsWith) ||
          _isLinuxSourceImport(dependency)) {
        failures.add('Windows graph: $relative reaches $import');
      }
      if (resolved != null) queue.add(resolved);
    }
  }
}

File? _resolveLocalImport(Directory root, File source, String import) {
  if (import.startsWith('package:busymax/')) {
    return File(
      '${root.path}/lib/${import.substring('package:busymax/'.length)}',
    );
  }
  final uri = Uri.tryParse(import);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return File(Uri.file(source.absolute.path).resolveUri(uri).toFilePath());
}

bool _isDesktopSourceImport(String import) {
  final normalized = import.replaceAll('\\', '/').toLowerCase();
  return normalized.endsWith('/main_linux.dart') ||
      normalized.endsWith('/main_windows.dart') ||
      normalized.contains('/ui/linux/') ||
      normalized.contains('/ui/windows/') ||
      normalized.contains('/platform/linux/') ||
      normalized.contains('/platform/windows/') ||
      normalized.contains('/app/windows/') ||
      normalized.contains('/linux/');
}

bool _isLinuxSourceImport(String import) {
  final normalized = import.replaceAll('\\', '/').toLowerCase();
  return normalized.contains('/linux/') ||
      normalized.contains('linux_') ||
      normalized.contains('/gtk_') ||
      normalized.contains('gtk_');
}

bool _isLegacyLinuxPresentation(String relative) {
  // Existing Yaru feature widgets remain the Linux presentation while the
  // Windows entrypoint uses lib/src/ui/windows exclusively.
  return relative.contains('/presentation/') &&
      !relative.contains('/ui/windows/');
}

String _relative(String root, String path) {
  final normalizedRoot = root
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceAll('\\', '/');
  final prefix = '$normalizedRoot/';
  return normalizedPath.startsWith(prefix)
      ? normalizedPath.substring(prefix.length)
      : normalizedPath;
}

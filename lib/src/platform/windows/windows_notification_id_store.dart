import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// A persistent one-to-one mapping between BusyMax schedule identifiers and
/// the signed 31-bit integer key required by the Windows notification API.
/// Entries are intentionally retained after cancellation so replacement and
/// cancellation remain stable for the lifetime of a BusyMax profile.
final class WindowsNotificationIdStore {
  WindowsNotificationIdStore(this.file);

  static const maximumId = 0x7fffffff;
  final File file;
  final _ids = <String, int>{};
  bool _loaded = false;
  int _nextId = 1;
  Future<void> _serial = Future<void>.value();

  static Future<WindowsNotificationIdStore> openDefault() async {
    final directory = await getApplicationSupportDirectory();
    return WindowsNotificationIdStore(
      File(path.join(directory.path, 'windows_notification_ids.json')),
    );
  }

  Future<void> initialize() {
    final completer = Completer<void>();
    _serial = _serial.then((_) async {
      try {
        await _load();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<int> idFor(String notificationScheduleId) {
    if (notificationScheduleId.isEmpty ||
        notificationScheduleId.length > 2048) {
      throw ArgumentError.value(
        notificationScheduleId,
        'notificationScheduleId',
        'The notification schedule identifier is invalid.',
      );
    }
    final completer = Completer<int>();
    _serial = _serial.then((_) async {
      try {
        await _load();
        final existing = _ids[notificationScheduleId];
        if (existing != null) {
          completer.complete(existing);
          return;
        }
        if (_nextId > maximumId) {
          throw StateError('The Windows notification ID space is exhausted.');
        }
        final id = _nextId++;
        _ids[notificationScheduleId] = id;
        await _persist();
        completer.complete(id);
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _load() async {
    if (_loaded) return;
    final backup = File('${file.path}.bak');
    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    if (!await file.exists()) {
      _loaded = true;
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on Object {
      throw const FormatException(
        'The Windows notification ID store is invalid.',
      );
    }
    if (decoded is! Map<String, Object?> || decoded['version'] != 1) {
      throw const FormatException(
        'The Windows notification ID store has an unsupported format.',
      );
    }
    final rawIds = decoded['ids'];
    if (rawIds is! Map<String, Object?>) {
      throw const FormatException(
        'The Windows notification ID store has no ID map.',
      );
    }
    final loadedIds = <String, int>{};
    final used = <int>{};
    for (final entry in rawIds.entries) {
      final id = entry.value;
      if (entry.key.isEmpty ||
          entry.key.length > 2048 ||
          id is! int ||
          id < 1 ||
          id > maximumId ||
          !used.add(id)) {
        throw const FormatException(
          'The Windows notification ID store contains invalid IDs.',
        );
      }
      loadedIds[entry.key] = id;
    }
    final storedNext = decoded['nextId'];
    final minimumNext = used.isEmpty
        ? 1
        : used.reduce((left, right) => left > right ? left : right) + 1;
    if (storedNext is! int ||
        storedNext < minimumNext ||
        storedNext > maximumId + 1) {
      throw const FormatException(
        'The Windows notification ID store has an invalid sequence.',
      );
    }
    _ids
      ..clear()
      ..addAll(loadedIds);
    _nextId = storedNext;
    _loaded = true;
  }

  Future<void> _persist() async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.new');
    final backup = File('${file.path}.bak');
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'nextId': _nextId, 'ids': _ids}),
      flush: true,
    );
    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
    } on Object {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }
}

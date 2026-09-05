import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:busymax/src/platform/windows/windows_notification_id_store.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'busymax-notification-ids-',
    );
    file = File('${directory.path}/ids.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('assigns a unique ID to every schedule identifier', () async {
    final store = WindowsNotificationIdStore(file);
    final ids = await Future.wait([
      store.idFor('schedule-a'),
      store.idFor('schedule-b'),
      store.idFor('schedule-c'),
    ]);
    expect(ids.toSet(), hasLength(3));
    expect(ids, everyElement(inInclusiveRange(1, 0x7fffffff)));
  });

  test('keeps IDs stable in memory and after restart', () async {
    final first = WindowsNotificationIdStore(file);
    final id = await first.idFor('schedule-stable');
    expect(await first.idFor('schedule-stable'), id);

    final restarted = WindowsNotificationIdStore(file);
    expect(await restarted.idFor('schedule-stable'), id);
    expect(await restarted.idFor('schedule-new'), isNot(id));
  });

  test('rejects persisted collisions instead of overwriting a toast', () async {
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'nextId': 2,
        'ids': {'schedule-a': 1, 'schedule-b': 1},
      }),
    );
    final store = WindowsNotificationIdStore(file);
    await expectLater(store.idFor('schedule-a'), throwsFormatException);
  });

  test('serializes concurrent allocation without collisions', () async {
    final store = WindowsNotificationIdStore(file);
    final ids = await Future.wait([
      for (var index = 0; index < 100; index++) store.idFor('schedule-$index'),
    ]);
    expect(ids.toSet(), hasLength(100));
  });

  test(
    'recovers the last committed map after interrupted replacement',
    () async {
      final first = WindowsNotificationIdStore(file);
      final id = await first.idFor('schedule-before-crash');
      final backup = File('${file.path}.bak');
      await file.rename(backup.path);

      final restarted = WindowsNotificationIdStore(file);
      await restarted.initialize();
      expect(await restarted.idFor('schedule-before-crash'), id);
      expect(await file.exists(), isTrue);
      expect(await backup.exists(), isFalse);
    },
  );

  test('initialization rejects a corrupt persisted map', () async {
    await file.writeAsString('{not-json');
    final store = WindowsNotificationIdStore(file);
    await expectLater(store.initialize(), throwsFormatException);
    await expectLater(store.idFor('schedule-a'), throwsFormatException);
  });
}

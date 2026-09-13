import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_settings_store.dart';
import '../support/recording_notification_backend.dart';

void main() {
  test(
    'visible Linux actions reach the current scheduler after invalidation',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final backend = RecordingNotificationBackend();
      final settings = AppSettings.defaults();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          initialAppSettingsProvider.overrideWithValue(settings),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          desktopNotificationBackendProvider.overrideWithValue(backend),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: 'microsoft',
              authority: 'https://login.microsoftonline.com/common',
              providerAccountId: 'account',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              createdAtUtc: '',
              updatedAtUtc: '',
            ),
          );
      await database
          .into(database.notificationSchedule)
          .insert(
            NotificationScheduleCompanion.insert(
              id: 'reminder',
              accountId: 'account',
              sourceType: 'task',
              sourceId: 'task',
              scheduledAtUtc:
                  DateTime.now().toUtc().millisecondsSinceEpoch - 1000,
              title: 'Report',
              createdAtLocal: 0,
              updatedAtLocal: 0,
            ),
          );
      final subscription = container.listen(
        notificationSchedulerProvider,
        (_, _) {},
      );
      final retired = subscription.read();
      await _waitUntil(
        () async =>
            (await database.select(database.notificationSchedule).getSingle())
                .sentAtUtc !=
            null,
      );
      await container
          .read(appSettingsControllerProvider.notifier)
          .setNotifyTaskReminders(false);
      await container.pump();
      expect(subscription.read(), same(retired));
      container.invalidate(notificationSchedulerProvider);
      await container.pump();
      expect(subscription.read(), isNot(same(retired)));
      await backend.invoke(0, 'snooze');
      final row = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(row.sentAtUtc, null);
      expect(row.snoozedUntilUtc, isNotNull);
      expect(
        row.generation,
        isNot(backend.requests.single.payload!['notificationGeneration']),
      );
      // Make the snooze due immediately; the current disabled preference wins.
      await database
          .update(database.notificationSchedule)
          .write(
            const NotificationScheduleCompanion(snoozedUntilUtc: Value(0)),
          );
      await subscription.read().checkNow();
      await retired.checkNow();
      expect(backend.requests, hasLength(1));
    },
  );
}

Future<void> _waitUntil(FutureOr<bool> Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for notification');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

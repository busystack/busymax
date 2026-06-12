import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/demo/screenshot_fake_data.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/task_providers/task_provider.dart';

void main() {
  test(
    'seeds fake accounts, calendars, task lists, events, and tasks',
    () async {
      final database = await openScreenshotFakeDataDatabase(
        now: DateTime(2026, 6, 11, 12),
      );
      addTearDown(database.close);

      final accounts = await AccountsRepository(
        database: database,
      ).listSignedInAccounts();
      expect(
        accounts.map((account) => account.id),
        containsAll([
          screenshotFakeGoogleAccountId,
          screenshotFakeMicrosoftAccountId,
        ]),
      );

      expect(
        await database.select(database.calendarSources).get(),
        hasLength(4),
      );
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(7),
      );
      expect(await database.select(database.taskLists).get(), hasLength(6));
      expect(await database.select(database.tasks).get(), hasLength(9));
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test('fake sync engines do not mutate seeded data', () async {
    final database = await openScreenshotFakeDataDatabase(
      now: DateTime(2026, 6, 11, 12),
    );
    addTearDown(database.close);

    await screenshotNoOpSyncEngine(
      database: database,
      accountId: screenshotFakeGoogleAccountId,
    ).incrementalSync();
    await screenshotNoOpCalendarSyncEngine(
      database: database,
      accountId: screenshotFakeMicrosoftAccountId,
      provider: TaskProvider.microsoft,
    ).incrementalSync();

    expect(await database.select(database.calendarEvents).get(), hasLength(7));
    expect(await database.select(database.tasks).get(), hasLength(9));
  });
}

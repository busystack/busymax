import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/demo/demo_seed.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo seed uses the current schema and current calendar date', () async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final now = DateTime(2026, 7, 23, 10, 15);

    await seedBusyMaxDemoData(database, now: now);

    final account = await database.select(database.accounts).getSingle();
    final sources = await database.select(database.calendarSources).get();
    final events = await database.select(database.calendarEvents).get();
    final lists = await database.select(database.taskLists).get();
    final tasks = await database.select(database.tasks).get();

    expect(account.id, busyMaxDemoAccountId);
    expect(account.authState, accountAuthStateSignedIn);
    expect(account.provider, 'google');
    expect(sources, hasLength(2));
    expect(events, hasLength(6));
    expect(lists, hasLength(2));
    expect(tasks, hasLength(6));
    expect(
      events.where((event) => event.startDate == '2026-07-23'),
      isNotEmpty,
    );
    expect(tasks.where((task) => task.dueUtc == '2026-07-23'), hasLength(2));
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(await database.select(database.notificationSchedule).get(), isEmpty);
  });

  test('demo data is immediately available through schedule queries', () async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final today = DateTime(2026, 7, 23);

    await seedBusyMaxDemoData(database, now: today);

    final items = await ScheduleRepository(
      database,
    ).listItems(range: ScheduleRange.day(today));

    expect(items.map((item) => item.title), contains('Product planning'));
    expect(items.map((item) => item.title), contains('Focus day'));
    expect(items.map((item) => item.title), contains('Send meeting notes'));
  });
}

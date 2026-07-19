import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/schedule/application/compact_agenda_data.dart';
import 'package:busymax/src/features/schedule/application/compact_agenda_snapshot.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact agenda bridge loader does not open the database', () async {
    var loadedFromBridge = false;
    final expected = _agendaData();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          throw StateError('compact agenda opened databaseProvider');
        }),
        compactAgendaDataLoaderProvider.overrideWithValue((ref, query) async {
          loadedFromBridge = true;
          expect(query, CompactAgendaQuery.initial);
          return expected;
        }),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(compactAgendaDataProvider.future);

    expect(loadedFromBridge, isTrue);
    expect(data.generatedAt, expected.generatedAt);
    expect(data.items.single.title, 'Bridge event');
  });

  test('compact agenda retries temporary SQLITE_BUSY failures', () async {
    var attempts = 0;
    final expected = _agendaData();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = FutureProvider((ref) {
      return loadCompactAgendaDataWithRetry(
        ref,
        CompactAgendaQuery.initial,
        retryDelays: const [Duration.zero, Duration.zero],
        delay: (_) async {},
        loader: (ref, query) async {
          attempts += 1;
          if (attempts < 3) {
            throw Exception('SQLite exception(5): database is locked');
          }
          return expected;
        },
      );
    });

    final data = await container.read(provider.future);

    expect(attempts, 3);
    expect(data.items.single.title, 'Bridge event');
  });

  test('compact agenda snapshot round-trips schedule data', () {
    final expected = _agendaData(
      items: [
        _event('Planning', start: DateTime(2026, 6, 10, 9)),
        _task('Review notes', start: DateTime(2026, 6, 10, 11)),
      ],
    );

    final decoded = decodeCompactAgendaData(encodeCompactAgendaData(expected));

    expect(decoded.today, expected.today);
    expect(decoded.range.end, expected.range.end);
    expect(decoded.items, hasLength(2));
    expect(decoded.items[0], isA<CalendarScheduleItem>());
    expect(decoded.items[0].title, 'Planning');
    final event = decoded.items[0] as CalendarScheduleItem;
    expect(event.providerRecurringEventId, 'series-master');
    expect(event.recurrence, ['RRULE:FREQ=WEEKLY']);
    expect(event.attendees, [
      {'email': 'guest@example.com'},
    ]);
    expect(decoded.items[1], isA<TaskScheduleItem>());
    expect(decoded.items[1].title, 'Review notes');
    expect(decoded.hasSignedInAccounts, isTrue);
    expect(decoded.hasSources, isTrue);
  });

  test('compact agenda query snapshot uses stable primitive fields', () {
    const query = CompactAgendaQuery(
      futureDays: 60,
      overdueLimit: 16,
      noDateLimit: 24,
    );

    final decoded = decodeCompactAgendaQuery(encodeCompactAgendaQuery(query));

    expect(decoded.futureDays, 60);
    expect(decoded.overdueLimit, 16);
    expect(decoded.noDateLimit, 24);
  });
}

CompactAgendaData _agendaData({List<ScheduleItem>? items}) {
  final today = DateTime(2026, 6, 10);
  return CompactAgendaData(
    today: today,
    range: ScheduleRange(
      start: today,
      end: today.add(const Duration(days: 30)),
    ),
    items: items ?? [_event('Bridge event', start: today)],
    hasMoreOverdueTasks: false,
    hasMoreNoDateTasks: false,
    hasSignedInAccounts: true,
    hasSources: true,
    generatedAt: today.add(const Duration(minutes: 5)),
  );
}

CalendarScheduleItem _event(String title, {required DateTime start}) {
  return CalendarScheduleItem(
    id: title,
    accountId: 'account',
    provider: TaskProvider.google,
    sourceId: 'calendar',
    providerCalendarId: 'provider-calendar',
    providerRecurringEventId: 'series-master',
    title: title,
    allDay: false,
    start: start,
    end: start.add(const Duration(hours: 1)),
    startTimeZone: 'America/Vancouver',
    endTimeZone: 'America/Vancouver',
    location: 'Room 1',
    description: 'Description',
    descriptionContentType: 'text/plain',
    descriptionHtml: '<p>Description</p>',
    recurrence: const ['RRULE:FREQ=WEEKLY'],
    attendees: const [
      {'email': 'guest@example.com'},
    ],
    colorHex: '#4477aa',
    categories: const ['Work'],
    reminderMinutesBeforeStart: const [10],
    sourceName: 'Work',
    accountDisplayName: 'Account',
    accountEmail: 'account@example.com',
  );
}

TaskScheduleItem _task(String title, {DateTime? start}) {
  return TaskScheduleItem(
    id: title,
    accountId: 'account',
    provider: TaskProvider.microsoft,
    sourceId: 'tasks',
    title: title,
    completed: false,
    allDay: true,
    start: start,
    notes: 'Notes',
    categories: const ['Blue'],
    reminder: start?.subtract(const Duration(minutes: 30)),
    sourceName: 'Tasks',
    accountDisplayName: 'Account',
    accountEmail: 'account@example.com',
  );
}

import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:busymax/src/ui/common/schedule/schedule_planner_events.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../support/local_journal_fixture.dart';

IcalProperty _dateProperty(String name, String value, {bool date = false}) =>
    IcalProperty(
      group: null,
      originalPhysicalLines: const [],
      isDirty: true,
      name: name,
      rawValue: value,
      parameters: date
          ? const [
              IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
            ]
          : const [],
    );

void main() {
  test(
    'journal markers share visual collision columns without gaining time',
    () {
      final date = DateTime(2026, 11, 28, 9);
      final longEvent = icv.Event(
        startTime: date,
        endTime: date.add(const Duration(minutes: 45)),
      );
      icv.Event mark(int offset) {
        final start = date.add(Duration(minutes: offset, seconds: 30));
        return icv.Event(
          startTime: start,
          endTime: start.add(const Duration(microseconds: 1)),
          eventType: ScheduleItemKind.journal,
        );
      }

      final events = [longEvent, mark(35), mark(54), mark(67), mark(110)];
      for (final width in [90.0, 320.0]) {
        final arranged = const SchedulePlannerEventArranger().arrange(
          events: events,
          height: 1440,
          width: width,
          heightPerMinute: 1,
        );
        Rect rect(icv.OrganizedEvent tile) => Rect.fromLTRB(
          tile.left,
          tile.top,
          width - tile.right,
          1440 - tile.bottom,
        );
        for (var i = 0; i < arranged.length; i++) {
          final tile = arranged[i];
          expect(tile.event, same(events[i]));
          expect(tile.startDuration, events[i].startTime);
          if (i > 0) {
            expect(tile.startDuration, tile.endDuration);
            expect(rect(tile).height, 22);
          }
          for (final other in arranged.skip(i + 1)) {
            expect(rect(tile).deflate(0.001).overlaps(rect(other)), isFalse);
          }
        }
        expect(arranged[1].top, 575.5);
        expect(rect(arranged.last).width, width - 8);
        expect(arranged.first.endDuration, longEvent.endTime);
      }
    },
  );

  test(
    'search retains pending journal recovery after account sign-out',
    () async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final source = await seedLocalJournalCollection(database);
      final journals = JournalRepository(database);
      await journals.create(source, title: 'Local journal change');
      await journals.create(source, title: 'Previously cached journal');
      final cached = (await journals.listEntries()).singleWhere(
        (entry) => entry.title == 'Previously cached journal',
      );
      await (database.delete(database.pendingOps)..where(
            (operation) => operation.davObjectId.equals(cached.davObjectId),
          ))
          .go();
      await (database.update(
        database.accounts,
      )..where((account) => account.id.equals(source.accountId))).write(
        AccountsCompanion(
          authState: Value(AccountConnectionState.signedOut.storageValue),
        ),
      );

      final repository = ScheduleRepository(database);
      final range = ScheduleRange.day(DateTime(2026, 11, 28));
      const filters = ScheduleFilters(
        includeJournals: true,
        ignoreDateRange: true,
      );
      final result = await repository.listItems(range: range, filters: filters);
      expect(result.single.title, 'Local journal change');
      expect(result.single.accountId, source.accountId);
      expect(
        await repository.listItems(
          range: range,
          filters: const ScheduleFilters(includeJournals: true),
        ),
        isEmpty,
      );
    },
  );

  test(
    'schedule keeps journal occurrences, points and undated search distinct',
    () async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final source = await seedLocalJournalCollection(database);
      final journal = JournalRepository(database);
      await journal.create(
        source,
        title: 'Undated',
        descriptions: [
          // The second block must be indexed through the schedule query.
          const DavRawPropertyValue(value: 'First paragraph'),
          const DavRawPropertyValue(value: 'Second paragraph has the answer'),
        ],
      );
      await journal.create(
        source,
        title: 'Daily log',
        start: _dateProperty('DTSTART', '20261126T090000'),
        details: [_dateProperty('RRULE', 'FREQ=DAILY;COUNT=3')],
      );
      await journal.create(
        source,
        title: 'Calendar date',
        start: _dateProperty('DTSTART', '20261128', date: true),
      );
      final repository = ScheduleRepository(database);
      final range = ScheduleRange(
        start: DateTime(2026, 11, 26, 9),
        end: DateTime(2026, 11, 28, 9),
      );
      final found = (await repository.listItems(
        range: range,
        filters: const ScheduleFilters(includeJournals: true),
      )).whereType<JournalScheduleItem>().toList();
      final daily = found.where((item) => item.title == 'Daily log');
      expect(daily.map((item) => item.start), [
        DateTime(2026, 11, 26, 9),
        DateTime(2026, 11, 27, 9),
      ]);
      expect(daily.map((item) => item.id).toSet(), hasLength(2));
      expect(found.every((item) => item.end == null), isTrue);
      expect(
        found.singleWhere((item) => item.title == 'Calendar date').allDay,
        isTrue,
      );
      final point = SchedulePlannerEvents.fromItem(
        daily.first,
        Brightness.light,
      )!;
      final arranged = const SchedulePlannerEventArranger()
          .arrange(
            events: [point],
            height: 1440,
            width: 200,
            heightPerMinute: 1,
          )
          .single;
      expect(arranged.top, 9 * 60);
      expect(arranged.endDuration, arranged.startDuration);

      final criteria = ScheduleSearchCriteria(
        type: ScheduleSearchType.journals,
        date: ScheduleSearchDate.undated,
        referenceDate: DateTime(2026, 11, 26),
        firstWeekday: DateTime.monday,
        sourceIds: const {},
        taskListKeys: const {},
        journalSourceIds: {source.id},
      );
      final result = await repository.listItems(
        range: range,
        filters: criteria.filters('paragraph answer'),
      );
      expect(result.single.title, 'Undated');
      expect(
        await repository.listItems(
          range: range,
          filters: criteria.copyWith(journalSourceIds: {}).filters(''),
        ),
        isEmpty,
      );
    },
  );
}

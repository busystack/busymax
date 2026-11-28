import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:busymax/src/ui/common/schedule/schedule_planner_events.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

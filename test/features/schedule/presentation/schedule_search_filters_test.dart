import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_search_filters.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('Linux custom range uses native desktop date fields', (
    tester,
  ) async {
    const channel = MethodChannel(nativeDateTimePickerChannelName);
    final calls = <MethodCall>[];
    final responses = <String?>['2026-06-15', '2026-06-12', null];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return responses.removeAt(0);
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    var criteria = ScheduleSearchCriteria(
      referenceDate: DateTime(2026, 6, 12),
      firstWeekday: DateTime.monday,
      sourceIds: {},
      taskListKeys: {},
      date: ScheduleSearchDate.custom,
      customStart: DateTime(2026, 6, 12),
      customEnd: DateTime(2026, 6, 14),
    );
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setState) => ScheduleSearchFilters(
                value: criteria,
                onChanged: (value) => setState(() => criteria = value),
                onClear: () {},
                accounts: const [],
                sources: const [],
                taskLists: const [],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(DesktopDateField), findsNWidgets(2));
    final labels = AppLocalizations.of(
      tester.element(find.byType(ScheduleSearchFilters)),
    );

    Future<void> pickDate(String label) async {
      final field = find.byWidgetPredicate(
        (widget) => widget is DesktopDateField && widget.label == label,
      );
      final button = find.descendant(
        of: field,
        matching: find.byType(YaruIconButton),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await pickDate(labels.startDate);
    expect(calls.single.method, 'pickDate');
    expect(calls.single.arguments, containsPair('initialDate', '2026-06-12'));
    expect(criteria.customStart, DateTime(2026, 6, 15));
    expect(criteria.customEnd, DateTime(2026, 6, 15));
    expect(criteria.range!.end, DateTime(2026, 6, 16));

    await pickDate(labels.endDate);
    expect(calls.last.arguments, containsPair('initialDate', '2026-06-15'));
    expect(criteria.customStart, DateTime(2026, 6, 12));
    expect(criteria.customEnd, DateTime(2026, 6, 12));
    expect(criteria.range!.end, DateTime(2026, 6, 13));

    final beforeCancel = criteria;
    await pickDate(labels.endDate);
    expect(criteria, beforeCancel);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

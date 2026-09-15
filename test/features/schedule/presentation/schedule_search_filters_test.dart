import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_search_filters.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('uses the Settings-style BusyMax sidebar and grouped rows', (
    tester,
  ) async {
    final state = _FilterState(
      _criteria(
        date: ScheduleSearchDate.custom,
        sourceIds: {'calendar'},
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'tasks'),
        },
      ),
    );
    await _pumpFilters(tester, state: state);

    expect(find.byType(BusyMaxSidebarSurface), findsOneWidget);
    expect(find.byType(BusyMaxGroupedList), findsNWidgets(4));
    expect(find.byType(BusyMaxComboRow<ScheduleSearchType>), findsOneWidget);
    expect(find.byType(BusyMaxComboRow<ScheduleSearchDate>), findsOneWidget);
    expect(
      find.byType(BusyMaxComboRow<ScheduleTaskCompletion>),
      findsOneWidget,
    );
    expect(find.byType(BusyMaxComboRow<ScheduleTaskDueState>), findsOneWidget);
    expect(find.byType(DesktopDateValueRow), findsNWidgets(2));
    expect(find.byType(BusyMaxSwitchRow), findsNWidgets(2));
    expect(find.byType(BusyMaxActionRow), findsOneWidget);
    expect(find.text('Deleted calendar'), findsNothing);
    expect(find.text('Deleted task list'), findsNothing);
  });

  testWidgets('uses grouped editor fields and conditional filter rows', (
    tester,
  ) async {
    final state = _FilterState(
      _criteria(
        sourceIds: {'calendar'},
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'tasks'),
        },
      ),
    );
    await _pumpFilters(tester, state: state);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScheduleSearchFilters)),
    );

    final personField = find.descendant(
      of: find.byKey(const ValueKey('schedule-search-person')),
      matching: find.byType(TextField),
    );
    final locationField = find.descendant(
      of: find.byKey(const ValueKey('schedule-search-location')),
      matching: find.byType(TextField),
    );
    expect(personField, findsOneWidget);
    expect(locationField, findsOneWidget);
    expect(tester.widget<TextField>(personField).decoration, isNotNull);

    await tester.enterText(personField, 'Taylor');
    await tester.enterText(locationField, 'Office');
    await tester.pump();
    expect(state.value.person, 'Taylor');
    expect(state.value.location, 'Office');

    _combo<ScheduleSearchType>(
      tester,
      l10n.searchType,
    ).onSelected(ScheduleSearchType.tasks);
    await tester.pump();
    expect(find.byKey(const ValueKey('schedule-search-person')), findsNothing);
    expect(state.value.person, isEmpty);
    expect(_comboFinder(l10n.searchTaskStatus), findsOneWidget);
    expect(_comboFinder(l10n.searchTaskDue), findsOneWidget);

    _combo<ScheduleSearchType>(
      tester,
      l10n.searchType,
    ).onSelected(ScheduleSearchType.events);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('schedule-search-person')),
      findsOneWidget,
    );
    expect(_comboFinder(l10n.searchTaskStatus), findsNothing);
    expect(_comboFinder(l10n.searchTaskDue), findsNothing);
    expect(find.text('Work tasks'), findsNothing);
    expect(find.text('Work calendar'), findsOneWidget);
  });

  testWidgets('source switches are temporary and Clear Filters delegates', (
    tester,
  ) async {
    var cleared = false;
    final state = _FilterState(
      _criteria(
        sourceIds: {'calendar'},
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'tasks'),
        },
      ),
    );
    await _pumpFilters(tester, state: state, onClear: () => cleared = true);

    tester
        .widget<BusyMaxSwitchRow>(
          find.byKey(const ValueKey(('schedule-search-source', 'calendar'))),
        )
        .onChanged(false);
    await tester.pump();
    expect(state.value.sourceIds, isEmpty);
    expect(_sources.first.selected, isTrue);

    tester
        .widget<BusyMaxSwitchRow>(
          find.byKey(
            const ValueKey(('schedule-search-task-list', 'account', 'tasks')),
          ),
        )
        .onChanged(false);
    await tester.pump();
    expect(state.value.taskListKeys, isEmpty);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScheduleSearchFilters)),
    );
    expect(find.text(l10n.searchNoSources), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('schedule-search-clear-filters')),
    );
    expect(cleared, isTrue);
  });

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

    final state = _FilterState(
      _criteria(
        date: ScheduleSearchDate.custom,
        customStart: DateTime(2026, 6, 12),
        customEnd: DateTime(2026, 6, 14),
      ),
    );
    await _pumpFilters(tester, state: state, includeSources: false);
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
    expect(state.value.customStart, DateTime(2026, 6, 15));
    expect(state.value.customEnd, DateTime(2026, 6, 15));
    expect(state.value.range!.end, DateTime(2026, 6, 16));

    await pickDate(labels.endDate);
    expect(calls.last.arguments, containsPair('initialDate', '2026-06-15'));
    expect(state.value.customStart, DateTime(2026, 6, 12));
    expect(state.value.customEnd, DateTime(2026, 6, 12));
    expect(state.value.range!.end, DateTime(2026, 6, 13));

    final beforeCancel = state.value;
    await pickDate(labels.endDate);
    expect(state.value, beforeCancel);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Finder _comboFinder(String title) => find.byWidgetPredicate(
  (widget) => widget is BusyMaxComboRow<dynamic> && widget.title == title,
);

BusyMaxComboRow<T> _combo<T>(WidgetTester tester, String title) =>
    tester.widget<BusyMaxComboRow<T>>(
      find.byWidgetPredicate(
        (widget) => widget is BusyMaxComboRow<T> && widget.title == title,
      ),
    );

Future<void> _pumpFilters(
  WidgetTester tester, {
  required _FilterState state,
  VoidCallback? onClear,
  bool includeSources = true,
}) async {
  tester.view
    ..physicalSize = const Size(400, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedTestApp(
      child: Scaffold(
        body: SizedBox(
          width: BusyMaxSizes.sidebarWidth,
          child: StatefulBuilder(
            builder: (context, setState) => ScheduleSearchFilters(
              value: state.value,
              onChanged: (value) => setState(() => state.value = value),
              onClear: onClear ?? () {},
              accounts: includeSources ? _accounts : const [],
              sources: includeSources ? _sources : const [],
              taskLists: includeSources ? _taskLists : const [],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScheduleSearchCriteria _criteria({
  ScheduleSearchDate date = ScheduleSearchDate.any,
  DateTime? customStart,
  DateTime? customEnd,
  Set<String> sourceIds = const {},
  Set<ScheduleTaskListKey> taskListKeys = const {},
}) => ScheduleSearchCriteria(
  referenceDate: DateTime(2026, 6, 12),
  firstWeekday: DateTime.monday,
  sourceIds: sourceIds,
  taskListKeys: taskListKeys,
  date: date,
  customStart: customStart,
  customEnd: customEnd,
);

class _FilterState {
  _FilterState(this.value);

  ScheduleSearchCriteria value;
}

const _accounts = [
  AccountEntity(
    id: 'account',
    provider: BusyProvider.google,
    authority: 'https://accounts.google.com',
    providerAccountId: 'person@example.com',
    authState: accountAuthStateSignedIn,
    displayName: 'Personal',
  ),
];

const _sources = [
  CalendarSourceEntity(
    id: 'calendar',
    accountId: 'account',
    provider: BusyProvider.google,
    providerCalendarId: 'calendar',
    summary: 'Work calendar',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: false,
  ),
  CalendarSourceEntity(
    id: 'deleted-calendar',
    accountId: 'account',
    provider: BusyProvider.google,
    providerCalendarId: 'deleted-calendar',
    summary: 'Deleted calendar',
    selected: true,
    hidden: false,
    readOnly: false,
    isDeleted: true,
  ),
];

const _taskLists = [
  TaskListEntity(
    accountId: 'account',
    id: 'tasks',
    title: 'Work tasks',
    localDirty: false,
    pendingDelete: false,
    rawJson: '{}',
  ),
  TaskListEntity(
    accountId: 'account',
    id: 'deleted-tasks',
    title: 'Deleted task list',
    localDirty: false,
    pendingDelete: true,
    rawJson: '{}',
  ),
];

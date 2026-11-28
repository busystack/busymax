import 'dart:io';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/journal/presentation/journal_pane.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/local_journal_fixture.dart';
import '../test/support/memory_settings_store.dart';
import '../test/support/schedule_parity_fixture.dart';
import 'support/journal_workflow.dart' show waitJournalWidget;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android integrated journal creation and details', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final database = AppDatabase.memoryForTests();
    await tester.runAsync(() async {
      await seedScheduleParityFixture(database);
      await database.delete(database.calendarEvents).go();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      for (var index = 0; index < 12; index++) {
        final id = 'native-overflow-$index';
        await database
            .into(database.calendarEvents)
            .insert(
              CalendarEventsCompanion.insert(
                id: id,
                accountId: 'google:populated',
                calendarSourceId: 'calendar',
                provider: 'google',
                providerCalendarId: 'calendar',
                providerEventId: id,
                title: 'Native overflow event $index',
                allDay: const Value(true),
                startDate: Value(today),
                rawJson: const Value('{}'),
                createdAtLocal: 1,
                updatedAtLocal: 1,
              ),
            );
      }
      final source = await seedLocalJournalCollection(database);
      await JournalRepository(database)
          .create(source, title: 'Android schedule fixture');
      final dated = IcalDocument.parse(
        [
          'BEGIN:VCALENDAR',
          'BEGIN:VJOURNAL',
          'DTSTART;VALUE=DATE:${today.replaceAll('-', '')}',
          'END:VJOURNAL',
          'END:VCALENDAR',
          '',
        ].join('\r\n'),
      ).calendarComponents.single;
      await JournalRepository(database).create(
        source,
        title: 'Native overflow journal',
        start: dated.firstProperty('DTSTART'),
      );
    });
    final container = ProviderContainer(
      overrides: [
        buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
        initialAppSettingsProvider.overrideWithValue(
          AppSettings.defaults().copyWith(
            androidScheduleViewMode: ScheduleViewMode.agenda,
          ),
        ),
        databaseProvider.overrideWithValue(database),
        androidNotificationServiceProvider.overrideWith((ref) {
          final service = AndroidNotificationService(
            database: database,
            settings: AppSettings.defaults,
          );
          ref.onDispose(service.dispose);
          return service;
        }),
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    tester.testTextInput.register();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AndroidBusyMaxApp(),
      ),
    );
    final view = find.byTooltip('View');
    await waitJournalWidget(tester, view);
    await tester.tap(view);
    final agenda = find.widgetWithText(
      CheckedPopupMenuItem<ScheduleViewMode>,
      'Agenda',
    );
    await waitJournalWidget(tester, agenda.hitTestable());
    await tester.tap(agenda.hitTestable());
    final note = find.text('Android schedule fixture');
    await waitJournalWidget(tester, note);
    expect(find.byIcon(Icons.book_outlined), findsWidgets);

    await tester.tap(note);
    await waitJournalWidget(tester, find.byType(JournalPane));
    await waitJournalWidget(tester, find.byTooltip('Edit journal entry'));
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    await tester.tap(find.byTooltip('Edit journal entry'));
    final title = find.descendant(
      of: find.byType(JournalPane),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Title',
      ),
    );
    await waitJournalWidget(tester, title);
    await tester.enterText(title, 'Edited on Android Schedule');
    final save = find.descendant(
      of: find.byType(JournalPane),
      matching: find.text('Save'),
    );
    Future<void> saveEditor() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        save,
        220,
        scrollable: find
            .descendant(
              of: find.byType(JournalPane),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await waitJournalWidget(tester, save.hitTestable());
      await tester.tap(save.hitTestable());
      await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
    }

    await saveEditor();
    await waitJournalWidget(tester, find.text('Edited on Android Schedule'));
    await tester.tap(find.byTooltip('Create'));
    final create = find
        .widgetWithText(ListTile, 'New journal entry')
        .hitTestable();
    await waitJournalWidget(tester, create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await waitJournalWidget(tester, title);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('New journal entry'),
      ),
      findsOneWidget,
    );
    await tester.enterText(title, 'Created on Android Schedule');
    await saveEditor();
    await waitJournalWidget(tester, find.text('Created on Android Schedule'));
    await tester.tap(view);
    final month = find.widgetWithText(
      CheckedPopupMenuItem<ScheduleViewMode>,
      'Month',
    );
    await waitJournalWidget(tester, month.hitTestable());
    await tester.tap(month.hitTestable());
    final more = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextButton &&
              widget.child is Text &&
              RegExp(r'^\+?\d+ more$')
                  .hasMatch((widget.child as Text).data ?? ''),
        )
        .hitTestable();
    await waitJournalWidget(tester, more);
    await tester.tap(more);
    final list = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    await waitJournalWidget(tester, list);
    Future<Finder> row(String title) async {
      final position = tester.state<ScrollableState>(list).position;
      position.jumpTo(position.minScrollExtent);
      await tester.pump();
      final finder = find.widgetWithText(ListTile, title);
      await tester.scrollUntilVisible(finder, 180, scrollable: list);
      expect(finder.hitTestable(), findsOneWidget);
      return finder;
    }

    final task = await row('Date-only task');
    expect(tester.widget<ListTile>(task).trailing, isNull);
    expect(
      find.descendant(of: task, matching: find.byType(Checkbox)),
      findsOneWidget,
    );
    final journal = await row('Native overflow journal');
    expect(
      find.descendant(of: journal, matching: find.byIcon(Icons.book_outlined)),
      findsOneWidget,
    );
    final event = await row('Native overflow event 0');
    expect(
      find.descendant(
        of: event,
        matching: find.byIcon(Icons.calendar_today_outlined),
      ),
      findsOneWidget,
    );
    binding.reportData = {
      'journalTest': 'Android integrated journal creation and details',
      'journalCases': [
        'JOURNAL_SCHEDULE_ANDROID details-edit-create PASS',
        'JOURNAL_SCHEDULE_ANDROID month-overflow-leading-controls PASS',
      ],
    };
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

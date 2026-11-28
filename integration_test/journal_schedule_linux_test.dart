import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_year_view.dart';
import 'package:busymax/src/journal/presentation/journal_pane.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yaru/yaru.dart';

import '../test/support/local_journal_fixture.dart';
import '../test/support/memory_settings_store.dart';
import 'support/journal_workflow.dart' show waitJournalWidget;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Linux journals use the schedule sources, creation and details', (
    tester,
  ) async {
    expect(Platform.isLinux, isTrue);
    final database = AppDatabase.memoryForTests();
    final today = DateTime.now();
    late String sourceId;
    await tester.runAsync(() async {
      final source = await seedLocalJournalCollection(database);
      sourceId = source.id;
      await JournalRepository(database).create(
        source,
        title: 'Schedule journal fixture',
        start: IcalProperty(
          group: null,
          name: 'DTSTART',
          originalPhysicalLines: const [],
          isDirty: true,
          parameters: const [
            IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
          ],
          rawValue:
              '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}',
        ),
      );
    });
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    container.read(appRouterProvider).go('/schedule');
    tester.testTextInput.register();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinuxBusyMaxApp(),
      ),
    );
    final settings = container.read(appSettingsControllerProvider.notifier);
    await tester.runAsync(
      () => settings.setThemeModePreference(BusyMaxThemeModePreference.light),
    );

    for (final mode in [
      ScheduleViewMode.day,
      ScheduleViewMode.week,
      ScheduleViewMode.month,
      ScheduleViewMode.agenda,
    ]) {
      await tester.runAsync(() => settings.setScheduleViewMode(mode));
      await waitJournalWidget(tester, find.text('Schedule journal fixture'));
      expect(find.byIcon(YaruIcons.book), findsWidgets);
      debugPrint('JOURNAL_SCHEDULE_LINUX ${mode.name} PASS');
    }
    await tester.runAsync(
      () => settings.setScheduleViewMode(ScheduleViewMode.year),
    );
    await waitJournalWidget(tester, find.byType(ScheduleYearView));
    debugPrint('JOURNAL_SCHEDULE_LINUX year PASS');
    await tester.runAsync(
      () => settings.setScheduleViewMode(ScheduleViewMode.agenda),
    );
    final fixture = find.text('Schedule journal fixture');
    await waitJournalWidget(tester, fixture);
    await tester.runAsync(
      () => settings.setThemeModePreference(BusyMaxThemeModePreference.dark),
    );
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(fixture)).brightness, Brightness.dark);
    await tester.ensureVisible(fixture.first);
    await tester.tap(fixture.first);
    await waitJournalWidget(tester, find.byType(JournalPane));
    await waitJournalWidget(tester, find.byTooltip('Edit journal entry'));
    expect(find.byIcon(YaruIcons.pen), findsWidgets);
    await tester.tap(find.byTooltip('Edit journal entry'));
    final title = find.descendant(
      of: find.byType(JournalPane),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Title',
      ),
    );
    await waitJournalWidget(tester, title);
    await tester.enterText(title, 'Edited in Schedule');
    final save = find.descendant(
      of: find.byType(JournalPane),
      matching: find.text('Save'),
    );
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
    await tester.tap(save.first);
    await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
    await waitJournalWidget(tester, find.text('Edited in Schedule'));
    final visibility = find.byKey(ValueKey(('journal-visibility', sourceId)));
    await waitJournalWidget(tester, visibility);
    await tester.tap(visibility);
    await waitJournalWidget(
      tester,
      find.text('Edited in Schedule'),
      absent: true,
    );
    await tester.tap(visibility);
    await waitJournalWidget(tester, find.text('Edited in Schedule'));
    debugPrint('JOURNAL_SCHEDULE_LINUX source-visibility PASS');
    final create = tester.widget<BusyMaxLinuxHeaderMenuButton<dynamic>>(
      find.byKey(const ValueKey('schedule-create-button')),
    );
    final action = create.entries.singleWhere(
      (item) => item.label == 'New journal entry',
    );
    expect(action.enabled, isTrue);
    (create as dynamic).onSelected(action.value);
    await waitJournalWidget(tester, find.byType(JournalPane));
    await waitJournalWidget(tester, title);
    expect(find.text('New journal entry'), findsOneWidget);
    await tester.enterText(title, 'Created from Schedule');
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
    await tester.tap(save.first);
    await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
    await waitJournalWidget(tester, find.text('Created from Schedule'));
    await tester.tap(find.text('Created from Schedule'));
    await waitJournalWidget(tester, find.byTooltip('Delete'));
    await tester.tap(find.byTooltip('Delete'));
    final confirm = find.widgetWithText(FilledButton, 'Delete');
    await waitJournalWidget(tester, confirm);
    await tester.tap(confirm);
    await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
    await waitJournalWidget(
      tester,
      find.text('Created from Schedule'),
      absent: true,
    );
    debugPrint('JOURNAL_SCHEDULE_LINUX details-edit-create PASS');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

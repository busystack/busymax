import 'dart:io';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/journal/presentation/journal_pane.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/local_journal_fixture.dart';
import '../test/support/memory_settings_store.dart';
import 'support/journal_workflow.dart' show waitJournalWidget;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android integrated journal creation and details', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    final database = AppDatabase.memoryForTests();
    await tester.runAsync(() async {
      final source = await seedLocalJournalCollection(database);
      await JournalRepository(database)
          .create(source, title: 'Android schedule fixture');
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
    await waitJournalWidget(tester, find.text('Created on Android Schedule'));
    binding.reportData = {
      'journalTest': 'Android integrated journal creation and details',
      'journalCases': ['JOURNAL_SCHEDULE_ANDROID details-edit-create PASS'],
    };
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

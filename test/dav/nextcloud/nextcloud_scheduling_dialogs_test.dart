import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/dav/presentation/nextcloud_scheduling_dialog.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_scheduling_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/memory_settings_store.dart';
import 'nextcloud_scheduling_fixture.dart';

void main() {
  for (final windows in [false, true]) {
    final platform = windows ? 'Windows' : 'Linux';
    testWidgets(
      '$platform inbox requires confirmation and never queues an event deletion',
      (tester) async {
        final fixture = SchedulingFixture();
        await tester.runAsync(fixture.seedScheduling);
        addTearDown(fixture.close);
        await _pump(tester, fixture, windows);
        expect(find.text('Invitation'), findsOneWidget);
        await tester.tap(find.text('Acknowledge message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
        await tester.tap(find.text('Acknowledge message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Acknowledge message').last);
        await _settle(tester);
        expect(find.text('No scheduling messages.'), findsOneWidget);
        expect(
          fixture.requests.where((r) => r.method == 'DELETE'),
          hasLength(1),
        );
        expect(
          await tester.runAsync(
            () => fixture.database.select(fixture.database.pendingOps).get(),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '$platform failed recipient availability is unknown in a native dialog',
      (tester) async {
        final fixture = SchedulingFixture()..requestStatus = '3.8;Denied';
        await tester.runAsync(fixture.seedScheduling);
        addTearDown(fixture.close);
        final draft =
            EventEditorDraft.newEvent(
              accountId: 'account',
              sourceId: 'source',
              providerCalendarId: 'calendar',
              start: DateTime.utc(2026, 9, 6, 9),
              end: DateTime.utc(2026, 9, 6, 12),
            ).copyWith(
              attendees: const [
                EventAttendeeDraft(email: 'guest@example.test'),
              ],
              startTimeZone: 'UTC',
              endTimeZone: 'UTC',
            );
        await _pump(tester, fixture, windows, draft: draft);
        expect(find.text('Availability unknown'), findsOneWidget);
        expect(
          find.text('No busy periods reported for this interval'),
          findsNothing,
        );
        expect(
          find.byType(windows ? AlertDialog : fluent.ContentDialog),
          findsNothing,
        );
        expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(
          await tester.runAsync(
            () => fixture.database.select(fixture.database.pendingOps).get(),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  SchedulingFixture fixture,
  bool windows, {
  EventEditorDraft? draft,
}) async {
  await tester.binding.setSurfaceSize(const Size(760, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final home = Builder(
    builder: (context) => Center(
      child: windows
          ? fluent.Button(
              onPressed: () => showWindowsNextcloudSchedulingDialog(
                context,
                accountId: 'account',
                collectionId: 'collection',
                draft: draft,
              ),
              child: const Text('Open'),
            )
          : TextButton(
              onPressed: () => showLinuxNextcloudSchedulingDialog(
                context,
                accountId: 'account',
                collectionId: 'collection',
                draft: draft,
              ),
              child: const Text('Open'),
            ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudSchedulingServiceProvider(
          'account',
        ).overrideWithValue(NextcloudSchedulingService(fixture.collections)),
      ],
      child: windows
          ? fluent.FluentApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                ...AppLocalizations.localizationsDelegates,
                fluent.FluentLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            )
          : MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: home),
            ),
    ),
  );
  await tester.tap(find.text('Open'));
  await _settle(tester);
}

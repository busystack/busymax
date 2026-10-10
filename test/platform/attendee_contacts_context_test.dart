import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_event_editor_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contacts_fixture.dart';
import '../support/memory_settings_store.dart';
import '../test_localized_app.dart';
import 'contacts_settings_routes_test.dart' show complete, settle;

void main() {
  for (final platform in ['Linux', 'Windows', 'Android']) {
    for (final scenario in [
      'switch-visible',
      'switch-delayed',
      'disable-visible',
      'disable-delayed',
      'remove-visible',
      'remove-delayed',
      'dispose-delayed',
    ]) {
      final delayed = scenario.endsWith('delayed');
      testWidgets('$platform fences $scenario suggestions', (tester) async {
        tester.view.physicalSize = const Size(1800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = ContactsFixture(AppDatabase.memoryForTests());
        final repository = CalendarRepository(database: fixture.database);
        await tester.runAsync(() async {
          await fixture.addParent(BusyProvider.google);
          await fixture.addParent(BusyProvider.microsoft);
          await fixture.controller.enableLinkedContacts('google');
          await fixture.controller.synchronizeAccount('contacts:google');
          for (final provider in [
            BusyProvider.google,
            BusyProvider.microsoft,
          ]) {
            await repository.upsertSource(
              accountId: provider.name,
              source: CalendarSourceDto(
                provider: provider,
                providerCalendarId: provider.name,
                summary: provider == BusyProvider.google
                    ? 'Calendar A'
                    : 'Calendar B',
                accessRole: 'owner',
              ),
            );
          }
        });
        final sources = (await tester.runAsync(
          () =>
              repository.watchSourcesForAccounts(['google', 'microsoft']).first,
        ))!;
        final a = sources.firstWhere((s) => s.accountId == 'google');
        final b = sources.firstWhere((s) => s.accountId == 'microsoft');
        final draft =
            EventEditorDraft.newEvent(
              accountId: a.accountId,
              sourceId: a.id,
              providerCalendarId: a.providerCalendarId,
              start: DateTime(2026, 10, 10, 12),
              end: DateTime(2026, 10, 10, 13),
            ).copyWith(
              title: 'Keep my draft',
              attendees: const [
                EventAttendeeDraft(
                  email: 'manual@example.test',
                  displayName: 'Retained',
                  responseStatus: 'accepted',
                ),
              ],
            );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(fixture.database),
            busyMaxContactsControllerProvider.overrideWithValue(
              fixture.controller,
            ),
            localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
            initialAppSettingsProvider.overrideWithValue(
              AppSettings.defaults(),
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await complete(tester, fixture.controller.close);
          container.dispose();
          await tester.runAsync(fixture.database.close);
        });
        final Widget editor = platform == 'Linux'
            ? EventEditor(
                initialDraft: draft,
                sources: sources,
                onSave: (_) {},
                onCancel: () {},
              )
            : AndroidEventEditor(sources: sources, draft: draft);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: platform == 'Windows'
                ? fluent.FluentApp(
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Consumer(
                      builder: (context, ref, _) => fluent.Button(
                        child: const Text('Open'),
                        onPressed: () => showWindowsEventEditorDialog(
                          context,
                          ref,
                          initialAccountId: a.accountId,
                          initialSourceId: a.id,
                        ),
                      ),
                    ),
                  )
                : localizedTestApp(
                    child: platform == 'Linux'
                        ? Scaffold(body: editor)
                        : editor,
                  ),
          ),
        );
        if (platform == 'Windows') {
          await tester.tap(find.text('Open'));
        }
        await settle(tester);
        if (platform == 'Linux') {
          await tester.ensureVisible(find.text('Add Guest').first);
          await tester.tap(find.text('Add Guest').first);
          await tester.pump();
        }
        final actualSource = (await complete(
          tester,
          fixture.controller.sourceSettings,
        )).single.source;
        final entered = Completer<void>();
        final release = Completer<void>();
        Future<void>? blocker;
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        if (delayed) {
          blocker = fixture.store.write((tx) async {
            entered.complete();
            await release.future;
          });
          await complete(tester, () => entered.future);
        }
        final guestInput = platform == 'Windows'
            ? find
                  .byWidgetPredicate(
                    (w) => w is fluent.TextBox && w.placeholder == 'Add Guest',
                  )
                  .last
            : find.byWidgetPredicate(
                (w) =>
                    w is TextField &&
                        w.decoration?.labelText == 'Add guest email' ||
                    w is TextField && w.decoration?.labelText == 'Guests',
              );
        // Each route uses its production attendee input, located by the
        // localized label/controller rather than an alternative lookup widget.
        final input = guestInput.evaluate().isNotEmpty
            ? guestInput.first
            : find.byType(EditableText).last;
        await tester.ensureVisible(input);
        await tester.enterText(
          input,
          platform == 'Android' ? 'manual@example.test, ada' : 'ada',
        );
        await settle(tester);
        if (!delayed) expect(find.textContaining('Ada Fixture'), findsWidgets);
        if (scenario.startsWith('switch') && platform == 'Windows') {
          final combo = tester.widget<fluent.ComboBox<CalendarSourceEntity>>(
            find.byType(fluent.ComboBox<CalendarSourceEntity>),
          );
          combo.onChanged!(b);
        } else if (scenario.startsWith('switch') && platform == 'Android') {
          final dropdown = tester.widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>).first,
          );
          dropdown.onChanged!(b.id);
        } else if (scenario.startsWith('switch')) {
          // Drive the existing account selector's public selection callback.
          final selector = find.byWidgetPredicate(
            (w) =>
                w.runtimeType.toString() == 'BusyMaxComboRow<String>' &&
                (w as dynamic).title == 'Account',
          );
          (tester.widget(selector) as dynamic).onSelected('microsoft');
        }
        Future<void>? eligibilityChange;
        if (scenario.startsWith('disable')) {
          final source = delayed
              ? null
              : (await complete(
                  tester,
                  fixture.controller.sourceSettings,
                )).single.source;
          // Source key comes from the provider fixture; a delayed lookup is
          // queued behind the held adapter transaction, so this durable change
          // completes before the UI can present its old result.
          final key = source?.key ?? actualSource.key;
          eligibilityChange = fixture.controller.setSourceEnabled(
            key,
            enabled: false,
          );
        }
        if (scenario.startsWith('remove')) {
          eligibilityChange = fixture.controller.removeContactsAccount(
            'contacts:google',
          );
        }
        if (scenario.startsWith('dispose')) {
          await tester.pumpWidget(const SizedBox());
        }
        await tester.pump();
        if (scenario.startsWith('switch') || scenario.startsWith('dispose')) {
          expect(find.textContaining('Ada Fixture'), findsNothing);
        }
        if (delayed) {
          release.complete();
          await complete(tester, () => blocker!);
        }
        if (eligibilityChange != null) {
          await complete(tester, () => eligibilityChange!);
        }
        await settle(tester);
        expect(find.textContaining('Ada Fixture'), findsNothing);
        if (!scenario.startsWith('dispose') && platform == 'Linux') {
          expect(find.text('manual@example.test'), findsWidgets);
        }
        if (!scenario.startsWith('dispose') && platform == 'Android') {
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: input,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
                .text,
            contains('manual@example.test'),
          );
        }
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

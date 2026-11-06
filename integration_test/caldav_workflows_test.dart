import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/tasks/presentation/new_task_dialog.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/dav/support/caldav_fixture.dart';
import '../test/dav/support/caldav_qa_targets.dart';
import '../test/support/memory_settings_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['BUSYMAX_CALDAV_NATIVE'] == '1';
  for (final server in calDavQaTargets.entries) {
    testWidgets(
      '${server.key}: native CalDAV connect and existing event/task editors',
      (tester) async {
        tester.testTextInput.register();
        addTearDown(tester.testTextInput.unregister);
        final f = CalDavFixture(Uri.parse(server.value), onStage: debugPrint);
        debugPrint('CalDAV native: preparing ${server.key}');
        await tester.runAsync(() => f.open(username: 'bob'));
        debugPrint('CalDAV native: opening account settings');
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(f.database),
            secretStoreProvider.overrideWithValue(f.secrets),
            authorizationPersistenceProvider.overrideWithValue(f.persistence),
            davAccountOnboardingServiceProvider.overrideWithValue(f.onboarding),
            localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
            localTimeZoneProvider.overrideWithValue('America/Vancouver'),
            networkAvailabilityProvider.overrideWith(
              (ref) => Stream.value(NetworkAvailability.online),
            ),
            desktopWindowServiceProvider.overrideWithValue(
              const NoOpDesktopWindowService(),
            ),
            davAccountHttpClientProvider.overrideWith((ref, id) {
              final client = DavAccountHttpClient(
                accountId: id,
                persistence: f.persistence,
                createClient: (_) => f.newClient(),
              );
              ref.onDispose(client.close);
              return client;
            }),
            davAccountSyncEngineFactoryProvider.overrideWithValue(
              (id) => DavAccountSyncEngine(
                database: f.database,
                secretStore: f.secrets,
                httpClient: DavAccountHttpClient(
                  accountId: id,
                  persistence: f.persistence,
                  createClient: (_) => f.newClient(),
                ),
                accountId: id,
              ),
            ),
          ],
        );
        try {
          Widget app(Widget home) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: BusyMaxYaruTheme.build(
                brightness: Brightness.light,
                accentColor: Colors.orange,
              ),
              home: Scaffold(body: home),
            ),
          );
          await tester.pumpWidget(
            app(const SettingsScreen(initialPage: SettingsPage.accounts)),
          );
          await _until(
            tester,
            () async => find
                .byKey(const ValueKey('add-account-caldav'))
                .evaluate()
                .isNotEmpty,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('add-account-caldav')),
          );
          await tester.tap(find.byKey(const ValueKey('add-account-caldav')));
          debugPrint('CalDAV native: opening connect dialog');
          await _until(
            tester,
            () async => find
                .byKey(const Key('caldav-password-field'))
                .evaluate()
                .isNotEmpty,
          );
          final credentials = (await tester.runAsync(
            () => calDavQaCredentials(f.uri, directory: f.fixtureDirectory),
          ))!;
          await tester.enterText(
            find.byKey(const Key('caldav-server-field')),
            server.value,
          );
          await tester.enterText(
            find.byKey(const Key('caldav-username-field')),
            'alice',
          );
          await tester.enterText(
            find.byKey(const Key('caldav-password-field')),
            credentials['alice'] as String,
          );
          await tester.tap(find.text('Connect').last);
          debugPrint('CalDAV native: waiting for connected account');
          await _until(
            tester,
            () async =>
                (await f.database.select(f.database.accounts).get()).length ==
                2,
          );
          final accounts = (await tester.runAsync(
            () => f.database.select(f.database.accounts).get(),
          ))!;
          expect(accounts.every((a) => a.provider == 'caldav'), isTrue);
          debugPrint('CalDAV native: account connected; opening event editor');
          await tester.pumpWidget(app(_EditorActions(f)));
          await _until(
            tester,
            () async =>
                find.byKey(const Key('qa-create-event')).evaluate().isNotEmpty,
          );
          await tester.tap(find.byKey(const Key('qa-create-event')));
          await _until(
            tester,
            () async => find
                .byKey(const Key('event-title-field'))
                .evaluate()
                .isNotEmpty,
          );
          debugPrint('CalDAV native: event editor ready');
          final title = find.byKey(const Key('event-title-field'));
          await tester.enterText(title, 'Native CalDAV café');
          await tester.pump();
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is EditableText &&
                  w.controller.text == 'Native CalDAV café',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Save').last);
          await _until(
            tester,
            () async =>
                (await f.database.select(f.database.calendarEvents).get()).any(
                  (e) => e.title == 'Native CalDAV café',
                ),
          );
          await _until(
            tester,
            () async =>
                find.byKey(const Key('event-title-field')).evaluate().isEmpty,
          );
          await tester.tap(find.byKey(const Key('qa-create-task')));
          await _until(
            tester,
            () async =>
                find.byKey(const Key('task-title-field')).evaluate().isNotEmpty,
          );
          debugPrint('CalDAV native: task editor ready');
          final taskTitle = find.byKey(const Key('task-title-field'));
          await tester.enterText(taskTitle, 'Native CalDAV task');
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is EditableText &&
                  w.controller.text == 'Native CalDAV task',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Create').last);
          await _until(
            tester,
            () async => (await f.database.select(f.database.tasks).get()).any(
              (t) => t.title == 'Native CalDAV task',
            ),
          );
          await tester.runAsync(() => f.synchronize());
          final objects = (await tester.runAsync(
            () => f.database.select(f.database.davObjects).get(),
          ))!;
          for (final object in objects.where(
            (o) =>
                {f.collectionId, f.eventCollectionId}.contains(o.collectionId),
          )) {
            final response = await tester.runAsync(
              () => f.independentRequest('GET', Uri.parse(object.requestUri)),
            );
            expect(response!.statusCode, 200);
            expect(response.body, contains('Native CalDAV'));
          }
          expect(
            await tester.runAsync(
              () => f.database.select(f.database.pendingOps).get(),
            ),
            isEmpty,
          );
          debugPrint(
            'BUSYMAX_CALDAV_NATIVE_PASS ${server.key} ${Platform.operatingSystem}',
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          await tester.runAsync(() => f.close());
        }
      },
      skip: !enabled,
    );
  }
}

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() predicate,
) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (await tester.runAsync(predicate) == true && i >= 5) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  throw TestFailure('Native CalDAV operation did not converge.');
}

class _EditorActions extends ConsumerWidget {
  const _EditorActions(this.fixture);
  final CalDavFixture fixture;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      TextButton(
        key: const Key('qa-create-event'),
        child: const Text('QA event editor'),
        onPressed: () async {
          final rows = await fixture.database
              .select(fixture.database.calendarSources)
              .get();
          final source = rows.singleWhere(
            (s) => s.davCollectionId == fixture.eventCollectionId,
          );
          final collection =
              (await fixture.database
                      .select(fixture.database.davCollections)
                      .get())
                  .singleWhere((c) => c.id == fixture.eventCollectionId);
          final accounts = await ref
              .read(accountsRepositoryProvider)
              .watchAccounts()
              .first;
          if (!context.mounted) return;
          final result = await showBusyMaxEventEditorDialog(
            context,
            initialDraft: EventEditorDraft.newEvent(
              accountId: fixture.id,
              sourceId: source.id,
              providerCalendarId: source.providerCalendarId,
              start: DateTime(2027, 3, 14, 9),
              end: DateTime(2027, 3, 14, 10),
            ),
            sources: [
              CalendarSourceEntity.fromRow(source, davCollection: collection),
            ],
            accounts: accounts,
          );
          if (result?.draft != null) {
            await ref
                .read(calendarRepositoryProvider)
                .createLocalEvent(result!.draft!);
          }
        },
      ),
      TextButton(
        key: const Key('qa-create-task'),
        child: const Text('QA task editor'),
        onPressed: () async {
          final lists = await fixture.database
              .select(fixture.database.taskLists)
              .get();
          final list = lists.singleWhere(
            (l) => l.davCollectionId == fixture.collectionId,
          );
          final accounts = await ref
              .read(accountsRepositoryProvider)
              .watchAccounts()
              .first;
          if (!context.mounted) return;
          await showBusyMaxNewTaskDialog(
            context,
            ref: ref,
            accounts: accounts,
            initialAccountId: fixture.id,
            initialListId: list.id,
          );
        },
      ),
    ],
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/l10n/generated/app_localizations_en.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/dav/support/caldav_fixture.dart';
import '../test/dav/support/caldav_qa_targets.dart';
import '../test/support/memory_settings_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const encoded = String.fromEnvironment('BUSYMAX_CALDAV_NATIVE_FIXTURE');
  for (final server in calDavQaTargets.entries) {
    testWidgets(
      '${server.key}: Android account connection and native calendar/task editing',
      (tester) async {
        tester.testTextInput.register();
        addTearDown(tester.testTextInput.unregister);
        final material = (await tester.runAsync(() async {
          final configuration =
              jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
          final directory = await Directory.systemTemp.createTemp(
            'busymax-caldav-native-material-',
          );
          await File('${directory.path}/ca.pem')
              .writeAsString(configuration['ca'] as String);
          await File('${directory.path}/credentials.json')
              .writeAsString(jsonEncode(configuration['credentials']));
          await File('${directory.path}/busystack-credentials.json')
              .writeAsString(jsonEncode(configuration['busystackCredentials']));
          return directory;
        }))!;
        final f = CalDavFixture(
          Uri.parse(server.value),
          fixtureDirectory: material.path,
          onStage: debugPrint,
        );
        expect(
          await tester.runAsync(() async {
            await f.open(username: 'bob');
            return true;
          }),
          isTrue,
        );
        final container = ProviderContainer(
          overrides: [
            buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
            initialAppSettingsProvider.overrideWithValue(
              AppSettings.defaults(),
            ),
            androidNotificationServiceProvider.overrideWith((ref) {
              final service = AndroidNotificationService(
                database: f.database,
                settings: AppSettings.defaults,
              );
              ref.onDispose(service.dispose);
              return service;
            }),
            databaseProvider.overrideWithValue(f.database),
            secretStoreProvider.overrideWithValue(f.secrets),
            authorizationPersistenceProvider.overrideWithValue(f.persistence),
            davAccountOnboardingServiceProvider.overrideWithValue(f.onboarding),
            localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
            localTimeZoneProvider.overrideWithValue('America/Vancouver'),
            networkAvailabilityProvider.overrideWith(
              (ref) => Stream.value(NetworkAvailability.online),
            ),
            networkConnectivityMonitorProvider.overrideWith((ref) {
              final monitor =
                  NetworkConnectivityMonitor.withoutPlatformObservation();
              ref.onDispose(monitor.dispose);
              return monitor;
            }),
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
        Widget app(Widget home) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        );
        try {
          await tester.pumpWidget(app(const AndroidSettingsScreen()));
          final add = find.text('Add CalDAV account');
          await _until(tester, () async => add.evaluate().isNotEmpty);
          await tester.ensureVisible(add);
          await tester.tap(add);
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
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Connect').last);
          await _until(
            tester,
            () async =>
                (await f.database.select(f.database.accounts).get()).length ==
                2,
          );
          await tester.pumpWidget(app(_AndroidActions(f)));
          await _until(
            tester,
            () async => find.byKey(const Key('qa-event')).evaluate().isNotEmpty,
          );
          await tester.tap(find.byKey(const Key('qa-event')));
          final title = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Title',
          );
          await _until(tester, () async => title.evaluate().isNotEmpty);
          await tester.enterText(title, 'Android CalDAV café');
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Save').last);
          await _until(
            tester,
            () async =>
                (await f.database.select(f.database.calendarEvents).get()).any(
                  (e) => e.title == 'Android CalDAV café',
                ),
          );
          await _until(tester, () async => title.evaluate().isEmpty);
          await tester.tap(find.byKey(const Key('qa-task')));
          await _until(tester, () async => title.evaluate().isNotEmpty);
          await tester.enterText(title, 'Android CalDAV task');
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.text('Save').last);
          await _until(
            tester,
            () async => (await f.database.select(f.database.tasks).get()).any(
              (t) => t.title == 'Android CalDAV task',
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
            expect(response.body, contains('Android CalDAV'));
          }
          expect(
            await tester.runAsync(
              () => f.database.select(f.database.pendingOps).get(),
            ),
            isEmpty,
          );
          // Exercise the complete application route and actual settings view:
          // a rejected collection must remain visible alongside healthy pulls.
          late String aliceId, creationId;
          const failedTitle = 'Android denied collection';
          await tester.runAsync(() async {
            aliceId = (await f.database.select(f.database.accounts).get())
                .singleWhere((a) => a.providerAccountId == 'alice')
                .id;
            final restricted =
                (await f.database.select(f.database.davCollections).get())
                    .singleWhere(
                      (c) =>
                          c.accountId == aliceId &&
                          (c.displayName == 'BusyMax QA restricted' ||
                              c.hrefKey.endsWith('/restricted/')),
                    );
            await (f.database.update(
              f.database.davAccountServices,
            )..where((r) => r.accountId.equals(aliceId))).write(
              DavAccountServicesCompanion(
                calendarHomeHref: Value(restricted.requestUri),
              ),
            );
            await expectLater(
              DavCollectionAdministration(
                database: f.database,
                secrets: f.secrets,
                client: container.read(davAccountHttpClientProvider(aliceId)),
                accountId: aliceId,
                refresh: () async {},
                requireNetwork: () async {},
              ).create(failedTitle, const {'VTODO'}),
              throwsA(
                isA<DavException>().having((e) => e.statusCode, 'denied', 403),
              ),
            );
            creationId =
                (await f.database
                        .select(f.database.davCollectionCreations)
                        .get())
                    .singleWhere(
                      (o) =>
                          o.accountId == aliceId &&
                          o.displayName == failedTitle,
                    )
                    .id;
            await container
                .read(accountSyncOperationsProvider)
                .syncAccount(aliceId, full: true);
            final activity = container.read(accountSyncActivityProvider);
            expect(activity.failure(aliceId, 'dav'), isNull);
            expect(
              activity.collectionCreationFailures(aliceId)[creationId]!.pending,
              isFalse,
            );
          });
          await tester.pumpWidget(app(const AndroidSettingsScreen()));
          final feedback = find.byKey(
            ValueKey(('collection-creation-feedback', aliceId, creationId)),
          );
          await _until(tester, () async => feedback.evaluate().isNotEmpty);
          final l10n = AppLocalizationsEn();
          expect(find.text(failedTitle), findsOneWidget);
          expect(
            find.text(
              l10n.taskListCreateFailed(l10n.davCollectionCreationDenied),
            ),
            findsOneWidget,
          );
          debugPrint(
            'BUSYMAX_CALDAV_NATIVE_FEEDBACK_PASS ${server.key} android',
          );
          debugPrint('BUSYMAX_CALDAV_NATIVE_PASS ${server.key} android');
        } finally {
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          await tester.runAsync(() async {
            await f.close();
            await material.delete(recursive: true);
          });
        }
      },
      skip: encoded.isEmpty || !Platform.isAndroid,
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
  throw TestFailure('Android CalDAV operation did not converge.');
}

class _AndroidActions extends ConsumerWidget {
  const _AndroidActions(this.fixture);
  final CalDavFixture fixture;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        TextButton(
          key: const Key('qa-event'),
          child: const Text('QA event editor'),
          onPressed: () async {
            final source =
                (await fixture.database
                        .select(fixture.database.calendarSources)
                        .get())
                    .singleWhere(
                      (s) => s.davCollectionId == fixture.eventCollectionId,
                    );
            final collection =
                (await fixture.database
                        .select(fixture.database.davCollections)
                        .get())
                    .singleWhere((c) => c.id == fixture.eventCollectionId);
            if (!context.mounted) return;
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AndroidEventEditor(
                  sources: [
                    CalendarSourceEntity.fromRow(
                      source,
                      davCollection: collection,
                    ),
                  ],
                  draft: EventEditorDraft.newEvent(
                    accountId: fixture.id,
                    sourceId: source.id,
                    providerCalendarId: source.providerCalendarId,
                    start: DateTime(2027, 3, 14, 9),
                    end: DateTime(2027, 3, 14, 10),
                  ),
                ),
              ),
            );
          },
        ),
        TextButton(
          key: const Key('qa-task'),
          child: const Text('QA task editor'),
          onPressed: () async {
            final list =
                (await fixture.database
                        .select(fixture.database.taskLists)
                        .get())
                    .singleWhere(
                      (l) => l.davCollectionId == fixture.collectionId,
                    );
            if (!context.mounted) return;
            await showAndroidTaskEditor(
              context,
              ref,
              creationList: TaskListEntity.fromRow(list),
              creationProvider: BusyProvider.caldav,
            );
          },
        ),
      ],
    ),
  );
}

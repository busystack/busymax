import '../../../support/desktop_registration_config.dart';
import '../../../support/contacts_fixture.dart';
import '../../../support/dav_contacts_fixture.dart' as carddav;
import '../../../platform/contacts_settings_routes_test.dart'
    show complete, settle;

import '../../../core/auth/authorization_transition_test.dart' show Harness;

import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';

import 'dart:async';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/calendar_colors.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/storage/dav_settings_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:busymax/src/webcal/webcal_http_client.dart';
import 'package:busymax/src/webcal/webcal_subscription_service.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../../../test_localized_app.dart';
import '../../../support/fake_autostart_service.dart';
import '../../../support/memory_settings_store.dart';

import 'package:busymax/src/platform/common/desktop_services.dart';

const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
  for (final enabled in [true, false]) {
    testWidgets(
      'ordinary Nextcloud account Reconnect renews linked request credentials; suggestions enabled=$enabled',
      (tester) async {
        final database = AppDatabase.memoryForTests();
        final secrets = InMemorySecretStore();
        final persistence = AuthorizationPersistence(
          database: database,
          secrets: secrets,
        );
        final f = ContactsFixture(
          database,
          realDav: true,
          readAuthorizationGeneration: persistence.generation,
          readLinkedDavCredential: (id) async {
            final credential = await persistence.readCurrentCredential(id);
            return credential is NextcloudSecretRecord
                ? BusyMaxLinkedDavCredential(
                    server: credential.canonicalServer,
                    username: credential.loginName,
                    password: credential.appPassword,
                  )
                : null;
          },
        );
        addTearDown(() => complete(tester, f.close));
        var polls = 0, browsers = 0;
        final service = DavAccountOnboardingService(
          database: database,
          secretStore: secrets,
          authorizationPersistence: persistence,
          nextcloudLoginFlow: NextcloudLoginFlowV2(
            client: MockClient((request) async {
              return http.Response(
                jsonEncode(
                  request.url.path.endsWith('/poll')
                      ? {
                          'server': carddav.server.toString(),
                          'loginName': 'alex',
                          'appPassword': ++polls == 1
                              ? 'password-A'
                              : 'password-B',
                        }
                      : {
                          'poll': {
                            'token': 'synthetic',
                            'endpoint': carddav.server
                                .resolve('login/v2/poll')
                                .toString(),
                          },
                          'login': carddav.server
                              .resolve('login/v2/browser')
                              .toString(),
                        },
                ),
                200,
              );
            }),
            browserLauncher: (_) async {
              browsers++;
              return true;
            },
            delay: (_) async {},
          ),
          idFactory: () => 'ordinary-reconnect',
          discover:
              ({
                required accountId,
                required provider,
                required accountAuthority,
                required credential,
                cancellationToken,
              }) async => DavDiscoveryResult(
                accountId: accountId,
                provider: provider,
                service: DavServiceDiscovery(
                  canonicalServiceUri: accountAuthority,
                  canonicalOrigin: accountAuthority.replace(path: ''),
                  principalHref: accountAuthority.resolve('principals/alex/'),
                  calendarHomeHref: accountAuthority.resolve('calendars/alex/'),
                  calendarUserAddresses: const [],
                  scheduleInboxHref: null,
                  scheduleOutboxHref: null,
                  capabilities: const AccountServiceCapabilities(
                    hasPrincipal: true,
                    hasCalendarHome: true,
                  ),
                  discoveredAtUtc: DateTime.utc(2026, 10, 21),
                  lastValidatedAtUtc: DateTime.utc(2026, 10, 21),
                  providerProfileVersion: 1,
                ),
                collections: const [],
              ),
        );
        final remote = carddav.DavFixture();
        var revokedA = false;
        f.respondDav = (request) async {
          if (revokedA &&
              request.headers['authorization'] ==
                  'Basic ${base64Encode(utf8.encode('alex:password-A'))}') {
            return http.Response('', 401);
          }
          return remote.respond(request);
        };
        final parent = (await complete(
          tester,
          () => service.connectNextcloud(
            enteredServer: carddav.server.toString(),
          ),
        )).accountId;
        final contactId = BusyMaxContactsController.linkedContactAccountId(
          parent,
        );
        Object? revokedFailure;
        await complete(tester, () async {
          await f.controller.enableLinkedNextcloudContacts(parent);
          await f.controller.synchronizeAccount(contactId);
          final source = (await f.controller.sourceSettings()).first.source;
          await f.store.setSourceEnabled(source.key, enabled: false);
          revokedA = true;
          try {
            await f.controller.synchronizeAccount(contactId);
          } on Object catch (error) {
            revokedFailure = error;
          }
          if (!enabled) await f.controller.disableContactsAccount(contactId);
        });
        expect(revokedFailure, isA<ContactsException>());
        final before = await complete(
          tester,
          () => f.store.read((tx) => tx.account(contactId)),
        );
        final preferences = await complete(tester, f.controller.sourceSettings);
        final accounts = await complete(tester, f.accounts.listVisibleAccounts);
        final connected = Completer<void>();
        final container = _container(
          selectedAccountId: parent,
          authRepository: AuthRepository(
            database: database,
            accountsRepository: f.accounts,
            authorizationPersistence: persistence,
            oAuth: OAuthService(
              config: _emptyBuildConfig,
              tokenStore: secrets,
              persistence: persistence,
              loopbackFlow: OAuthLoopbackFlow(),
              httpClient: MockClient(
                (_) async =>
                    throw StateError('Nextcloud reconnect must not use Google'),
              ),
            ),
          ),
          accounts: accounts,
          accountsRepository: f.accounts,
          contactsFixture: f,
          davOnboardingService: service,
          signedInSyncRunner: (_, _) async {
            if (!connected.isCompleted) connected.complete();
          },
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        expect(
          identical(
            container.read(davAccountOnboardingServiceProvider),
            service,
          ),
          isTrue,
        );
        await _pumpSettings(
          tester,
          container,
          logicalSize: const Size(1200, 1400),
        );
        await settle(tester);
        final reconnect = find.byKey(ValueKey('reconnect-account-$parent'));
        await tester.ensureVisible(reconnect);
        await tester.pumpAndSettle();
        await tester.tap(reconnect);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('nextcloud-server-field')),
              )
              .controller!
              .text,
          accounts.single.authority,
        );
        await tester.tap(find.text('Connect').last);
        await tester.pumpAndSettle();
        await complete(tester, () => connected.future);
        await settle(tester);
        expect(polls, 2);
        expect(browsers, 2);
        expect(container.read(authSessionControllerProvider).accountId, parent);
        expect(
          (await complete(
            tester,
            () => persistence.readCurrentCredential(parent),
          ) as NextcloudSecretRecord).appPassword,
          'password-B',
        );
        final requestCount = f.requests.length;
        if (enabled) {
          await complete(
            tester,
            () => f.controller.synchronizeAccount(contactId),
          );
          final requests = f.requests.skip(requestCount).toList();
          expect(requests, isNotEmpty);
          expect(
            requests.every(
              (r) =>
                  r.headers['authorization'] ==
                  'Basic ${base64Encode(utf8.encode('alex:password-B'))}',
            ),
            isTrue,
          );
        }
        final after = await complete(
          tester,
          () => f.store.read((tx) => tx.account(contactId)),
        );
        expect(after!.enabled, enabled);
        expect(after.generation, before!.generation);
        for (final preference in preferences) {
          expect(
            await complete(
              tester,
              () => f.store.sourceEnabled(preference.source.key),
            ),
            preference.enabled,
          );
        }
        expect(browsers, 2);
        await _disposeDiagnosticsWidget(tester);
        await complete(tester, f.controller.close);
      },
    );
  }

  testWidgets(
    'successful empty Nextcloud discovery is distinct from undiscovered and failed discovery',
    (tester) async {
      final f = ContactsFixture(AppDatabase.memoryForTests());
      await tester.runAsync(
        () => f.accounts.upsertSignedInAccount(
          id: 'nextcloud',
          provider: BusyProvider.nextcloud,
          providerAccountId: 'qa',
          authority: 'https://cloud.example.test',
          grantedScopes: '',
        ),
      );
      final accounts = (await tester.runAsync(f.accounts.listVisibleAccounts))!;
      final container = _container(
        selectedAccountId: 'nextcloud',
        authRepository: _FakeAuthRepository(),
        accounts: accounts,
        contactsFixture: f,
        accountsRepository: f.accounts,
      );
      addTearDown(() async {
        container.dispose();
        await tester.runAsync(f.close);
      });
      await _pumpSettings(
        tester,
        container,
        logicalSize: const Size(1200, 1400),
      );
      await settle(tester);
      expect(
        find.text(
          'Discovery has not completed. Refresh or reconnect this account.',
        ),
        findsOneWidget,
      );
      await tester.runAsync(
        () => f.database
            .into(f.database.davAccountServices)
            .insert(
              DavAccountServicesCompanion.insert(
                accountId: 'nextcloud',
                canonicalServiceUri:
                    'https://cloud.example.test/remote.php/dav/',
                canonicalOrigin: 'https://cloud.example.test',
                discoveredAtUtc: '2026-10-20T12:00:00Z',
              ),
            ),
      );
      await settle(tester);
      expect(find.text('No collections found.'), findsOneWidget);
      // Inventory discovery is not an invented Calendar or Tasks sync time.
      for (final domain in ['calendar', 'tasks']) {
        expect(
          tester
              .widget<BusyMaxActionRow>(
                find.byKey(ValueKey('account-sync-$domain-nextcloud')),
              )
              .subtitle,
          'No successful sync time recorded',
        );
      }
      await tester.runAsync(
        () => f.database.customUpdate(
          "UPDATE dav_account_services SET last_discovery_error_code = 'DavNetworkFailure' WHERE account_id = 'nextcloud'",
          updates: {f.database.davAccountServices},
        ),
      );
      await settle(tester);
      expect(find.text('No collections found.'), findsNothing);
      expect(
        find.text(
          'Collections could not be loaded. Cached data is retained; retry synchronization.',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await _disposeDiagnosticsWidget(tester);
    },
  );

  for (final combinedColorChange in [false, true]) {
    testWidgets(
      'Google local selection and pending/failed CalendarList.hidden changes stay distinct; combined color=$combinedColorChange',
      (tester) async {
        final f = ContactsFixture(AppDatabase.memoryForTests());
        await tester.runAsync(() => f.addParent(BusyProvider.google));
        final repository = CalendarRepository(database: f.database);
        late PendingOp otherBlocked;
        Future<List<PendingOp>> targetOperations() => (f.database.select(
          f.database.pendingOps,
        )..where((row) => row.accountId.equals('google'))).get();
        await tester.runAsync(() async {
          for (final primary in [false, true]) {
            await repository.upsertSource(
              accountId: 'google',
              source: CalendarSourceDto(
                provider: BusyProvider.google,
                providerCalendarId: primary ? 'primary' : 'qa',
                summary: primary ? 'QA Primary' : 'QA Calendar',
                primaryCalendar: primary,
                backgroundColor: '#9a9cff',
                foregroundColor: '#000000',
                colorId: '1',
                rawJson: {
                  'hidden': false,
                  'backgroundColor': '#9a9cff',
                  'foregroundColor': '#000000',
                  'colorId': '1',
                },
              ),
            );
          }
          await f.accounts.upsertSignedInAccount(
            id: 'other-google',
            provider: BusyProvider.google,
            providerAccountId: 'other-subject',
            grantedScopes: 'calendar tasks',
          );
          await repository.upsertSource(
            accountId: 'other-google',
            source: const CalendarSourceDto(
              provider: BusyProvider.google,
              providerCalendarId: 'other-qa',
              summary: 'Other account calendar',
              rawJson: {'hidden': false},
            ),
          );
          final otherId = CalendarRepository.sourceId(
            accountId: 'other-google',
            provider: BusyProvider.google,
            providerCalendarId: 'other-qa',
          );
          await repository.setSourceProviderHidden(otherId, true);
          final otherOp = await f.database
              .select(f.database.pendingOps)
              .getSingle();
          await f.database.pendingOpsDao.updateAttempt(
            id: otherOp.id,
            attemptCount: 1,
            nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
            lastErrorCode: 'forbidden',
          );
          otherBlocked = (await f.database.pendingOpsDao.getOp(otherOp.id))!;
        });
        final accounts = (await tester.runAsync(
          f.accounts.listVisibleAccounts,
        ))!;
        late final PendingOpResolutionService visibilityResolution;
        final container = _container(
          selectedAccountId: 'google',
          authRepository: _FakeAuthRepository(),
          accounts: accounts,
          contactsFixture: f,
          accountsRepository: f.accounts,
          calendarSourceStream: repository.watchSourcesForAccounts([
            'google',
            'other-google',
          ]),
          calendarRepository: repository,
          operationResolution: (id) {
            expect(id, 'google');
            return visibilityResolution;
          },
        );
        addTearDown(() async {
          container.dispose();
          await tester.runAsync(f.close);
        });
        await _pumpSettings(
          tester,
          container,
          logicalSize: const Size(1200, 1400),
        );
        await settle(tester);
        final sources = container
            .read(calendarSourcesStreamProvider)
            .requireValue;
        final ordinary = sources.singleWhere(
          (s) => s.accountId == 'google' && !s.primaryCalendar,
        );
        final primary = sources.singleWhere((s) => s.primaryCalendar);
        final local = find.byKey(
          ValueKey('settings-calendar-schedule-${ordinary.id}'),
        );
        await tester.ensureVisible(local);
        await tester.tap(local);
        await settle(tester);
        expect(
          (await complete(
            tester,
            () => f.database.select(f.database.calendarSources).get(),
          )).singleWhere((s) => s.id == ordinary.id).selected,
          isFalse,
        );
        expect(await complete(tester, targetOperations), isEmpty);
        await complete(
          tester,
          () => repository.setSourceProviderHidden(ordinary.id, true),
        );
        await settle(tester);
        expect(find.text('Google visibility change pending'), findsOneWidget);
        final requests = <http.Request>[];
        var denied = true;
        final client = GoogleCalendarApiClient(
          baseUri: Uri.parse('https://www.googleapis.com'),
          httpClient: MockClient((request) async {
            requests.add(request);
            return denied
                ? http.Response(
                    '{"error":{"code":403,"message":"denied"}}',
                    403,
                  )
                : http.Response(
                    jsonEncode({
                      'id': 'qa',
                      'summary': 'QA Calendar',
                      'backgroundColor': '#9a9cff',
                      'foregroundColor': '#000000',
                      'colorId': '1',
                      'hidden': jsonDecode(request.body)['hidden'],
                    }),
                    200,
                  );
          }),
        );
        final engine = CalendarSyncEngine(
          database: f.database,
          client: client,
          accountId: 'google',
        );
        visibilityResolution = PendingOpResolutionService(
          database: f.database,
          accountId: 'google',
          syncTasks: () async => fail('Visibility must not synchronize Tasks'),
          syncCalendar: engine.dispatchPendingWrites,
        );
        await complete(
          tester,
          () => CalendarSyncEngine(
            database: f.database,
            client: client,
            accountId: 'google',
          ).dispatchPendingWrites(),
        );
        await settle(tester);
        expect(requests.single.method, 'PATCH');
        expect(requests.single.url.path, contains('/users/me/calendarList/qa'));
        expect(jsonDecode(requests.single.body)['hidden'], isTrue);
        expect(
          find.text(
            'Google visibility change failed. Google’s last confirmed state is shown. BusyMax still follows the pending change. Retry or discard it.',
          ),
          findsWidgets,
        );
        final remote = tester.widget<YaruSwitch>(
          find.byKey(ValueKey('settings-calendar-provider-${ordinary.id}')),
        );
        expect(remote.value, isTrue);
        // Ordinary sync cannot replay a permanent permission rejection.
        await complete(tester, engine.dispatchPendingWrites);
        expect(requests, hasLength(1));
        final retry = find.byKey(
          ValueKey('settings-calendar-visibility-retry-${ordinary.id}'),
        );
        expect(retry, findsOneWidget);
        denied = false;
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await settle(tester);
        expect(requests, hasLength(2));
        expect(jsonDecode(requests.last.body)['hidden'], isTrue);
        expect(await complete(tester, targetOperations), isEmpty);

        // A second rejected hide can instead be discarded locally. This keeps
        // the user's independent selection and does not send another PATCH.
        final queuedBeforeFailure = await complete(tester, () async {
          await repository.setSourceProviderHidden(ordinary.id, false);
          await engine.dispatchPendingWrites();
          denied = true;
          if (combinedColorChange) {
            await repository.setSourceColor(
              ordinary.id,
              calendarColorChoices(BusyProvider.google).last,
            );
          }
          await repository.setSourceProviderHidden(ordinary.id, true);
          final queued = (await targetOperations()).single;
          await engine.dispatchPendingWrites();
          return queued;
        });
        final patch = jsonDecode(queuedBeforeFailure.requestJson) as Map;
        expect(patch['hidden'], isTrue);
        expect(patch.containsKey('backgroundColor'), combinedColorChange);
        expect(patch.containsKey('foregroundColor'), combinedColorChange);
        await settle(tester);
        final beforeDiscard = requests.length;
        final blocked = (await complete(tester, targetOperations)).single;
        final beforeRestore = (await complete(
          tester,
          () => f.database.select(f.database.calendarSources).get(),
        )).singleWhere((s) => s.id == ordinary.id);
        if (combinedColorChange) {
          expect(
            beforeRestore.backgroundColor,
            isNot(ordinary.backgroundColor),
          );
        }
        final discard = find.byKey(
          ValueKey('settings-calendar-visibility-discard-${ordinary.id}'),
        );
        expect(discard, findsOneWidget);
        await tester.ensureVisible(discard);
        await tester.tap(discard);
        await tester.pumpAndSettle();
        final confirmation =
            'Discard the pending changes to “QA Calendar”?\n\n'
            'These settings will return to their previous values:\n'
            '${combinedColorChange ? '• Calendar color\n' : ''}'
            '• Show in Google’s calendar list\n\n'
            'Your BusyMax calendar selection is kept. No changes will be sent to Google.';
        expect(find.text(confirmation), findsOneWidget);
        expect(find.textContaining('Google Tasks'), findsNothing);
        // Cancelling keeps the entire patch and its optimistic settings intact.
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect((await complete(tester, targetOperations)).single, blocked);
        expect(
          (await complete(
            tester,
            () => f.database.select(f.database.calendarSources).get(),
          )).singleWhere((s) => s.id == ordinary.id),
          beforeRestore,
        );
        await tester.tap(discard);
        await tester.pumpAndSettle();
        expect(find.text(confirmation), findsOneWidget);
        await tester.tap(find.text('Discard').last);
        await settle(tester);
        expect(requests.length, beforeDiscard);
        expect(await complete(tester, targetOperations), isEmpty);
        expect(tester.widget<YaruSwitch>(local).value, isFalse);
        expect(tester.widget<YaruSwitch>(local).onChanged, isNotNull);
        await tester.ensureVisible(local);
        await tester.tap(local);
        await settle(tester);
        final restored = (await complete(
          tester,
          () => f.database.select(f.database.calendarSources).get(),
        )).singleWhere((s) => s.id == ordinary.id);
        expect(restored.hidden, isFalse);
        expect(restored.selected, isTrue);
        expect(restored.backgroundColor, ordinary.backgroundColor);
        expect(restored.foregroundColor, ordinary.foregroundColor);
        expect(restored.colorId, ordinary.colorId);
        expect(
          await complete(
            tester,
            () => f.database.pendingOpsDao.getOp(otherBlocked.id),
          ),
          otherBlocked,
        );
        final primarySwitch = tester.widget<YaruSwitch>(
          find.byKey(ValueKey('settings-calendar-provider-${primary.id}')),
        );
        expect(primarySwitch.value, isTrue);
        expect(primarySwitch.onChanged, isNull);
        await complete(
          tester,
          () => expectLater(
            repository.setSourceProviderHidden(primary.id, true),
            throwsA(isA<CalendarMutationNotAllowed>()),
          ),
        );
        expect(
          find.text('Google’s primary calendar stays in its calendar list.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _disposeDiagnosticsWidget(tester);
      },
    );
  }

  testWidgets(
    'Calendar and Tasks show loading, recorded per-service times, empty success and cached errors truthfully',
    (tester) async {
      final f = ContactsFixture(AppDatabase.memoryForTests());
      await tester.runAsync(() => f.addParent(BusyProvider.google));
      final accounts = (await tester.runAsync(f.accounts.listVisibleAccounts))!;
      final sources = StreamController<List<CalendarSourceEntity>>();
      final container = _container(
        selectedAccountId: 'google',
        authRepository: _FakeAuthRepository(),
        accounts: accounts,
        contactsFixture: f,
        accountsRepository: f.accounts,
        calendarSourceStream: sources.stream,
      );
      addTearDown(() async {
        container.dispose();
        await sources.close();
        await tester.runAsync(f.close);
      });
      await _pumpSettings(
        tester,
        container,
        logicalSize: const Size(1200, 1400),
      );
      await settle(tester);
      expect(find.text('Loading collections…'), findsWidgets);
      expect(find.text('No calendars synced yet.'), findsNothing);
      sources.add([]);
      await settle(tester);
      expect(
        find.text(
          'Discovery has not completed. Refresh or reconnect this account.',
        ),
        findsOneWidget,
      );
      await complete(
        tester,
        () => f.database.customUpdate(
          "INSERT INTO domain_sync_schedules(account_id,domain,last_successful_pull_utc) VALUES ('google','tasks','2026-10-19T12:00:00Z')",
          updates: {f.database.domainSyncSchedules},
        ),
      );
      await settle(tester);
      final calendarStatus = tester.widget<BusyMaxActionRow>(
        find.byKey(const ValueKey('account-sync-calendar-google')),
      );
      final tasksStatus = tester.widget<BusyMaxActionRow>(
        find.byKey(const ValueKey('account-sync-tasks-google')),
      );
      expect(calendarStatus.subtitle, 'No successful sync time recorded');
      expect(tasksStatus.subtitle, contains('Last successful sync:'));
      final activity = container.read(accountSyncActivityProvider);
      final gate = Completer<void>();
      final syncing = activity.run('google', 'calendar', () async {
        await gate.future;
      });
      await tester.pump();
      expect(find.text('Syncing…'), findsWidgets);
      gate.complete();
      await syncing;
      await complete(
        tester,
        () => f.database.customUpdate(
          "INSERT INTO domain_sync_schedules(account_id,domain,last_successful_pull_utc) VALUES ('google','calendar','2026-10-20T12:00:00Z')",
          updates: {f.database.domainSyncSchedules},
        ),
      );
      await settle(tester);
      expect(find.text('No collections found.'), findsOneWidget);
      const cached = CalendarSourceEntity(
        id: 'cached',
        accountId: 'google',
        provider: BusyProvider.google,
        providerCalendarId: 'cached',
        summary: 'Cached QA calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
      );
      sources.add([cached]);
      await settle(tester);
      await expectLater(
        activity.run<void>('google', 'calendar', () async {
          throw const OAuthException('OAuthTemporaryTransport', 'synthetic');
        }),
        throwsA(isA<OAuthException>()),
      );
      await settle(tester);
      expect(find.text('Cached QA calendar'), findsOneWidget);
      final failed = tester.widget<BusyMaxActionRow>(
        find.byKey(const ValueKey('account-sync-calendar-google')),
      );
      expect(failed.subtitle, contains('Last successful sync:'));
      expect(failed.subtitle, isNot(tasksStatus.subtitle));
      expect(find.text('No collections found.'), findsNothing);
      sources.addError(
        StateError('synthetic cached collection stream failure'),
      );
      await settle(tester);
      expect(find.text('Cached QA calendar'), findsOneWidget);
      expect(
        find.text(
          'Collections could not be loaded. Cached data is retained; retry synchronization.',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await _disposeDiagnosticsWidget(tester);
    },
  );

  for (final summariesFail in [false, true]) {
    testWidgets(
      'Google reconnect reuses issuing registration with ${summariesFail ? 'failed' : 'loading'} summaries and revoked grant',
      (tester) async {
        await tester.runAsync(() async {
          final h = Harness(buildConfig: syntheticDesktopConfig());
          addTearDown(() async {
            h.staging.dispose();
            await h.db.close();
          });
          await h.seed();
          await h.makeGoogleUserOwned();
          await h.repository.markReconnectRequired('opaque');
          final before = await h.secrets.readCredential(
            'opaque',
          ) as GoogleDesktopCredential;
          final observing = _ObservedAuthRepository(h);
          final container = _container(
            selectedAccountId: 'opaque',
            authRepository: observing,
            accounts: await h.accounts.listVisibleAccounts(),
            accountsRepository: h.accounts,
            buildConfig: h.buildConfig,
            productionHarness: h,
            signedInSyncRunner: (_, _) async {},
            registrationSummaryStream: summariesFail
                ? Stream.error(StateError('synthetic summaries failure'))
                : const Stream.empty(),
          );
          addTearDown(container.dispose);
          await _pumpSettings(
            tester,
            container,
            logicalSize: const Size(1200, 1200),
          );
          final reconnect = find.byKey(
            const ValueKey('reconnect-account-opaque'),
          );
          await tester.ensureVisible(reconnect);
          await tester.tap(reconnect);
          await tester.pump();
          await observing.started.future;
          await observing.finished;
          await tester.pumpAndSettle();
          expect(observing.lastRequest!.intent, AuthorizationIntent.reconnect);
          expect(h.flow.clients, [before.registration.clientId]);
          expect(
            find.byKey(const ValueKey('registration-reconnect-account')),
            findsNothing,
          );
          expect((await h.accounts.accountById('opaque'))!.isSignedIn, isTrue);
          await tester.pumpWidget(const SizedBox());
        });
      },
    );
  }

  testWidgets(
    'Microsoft missing binding exposes explicit replacement that recovers the selected account',
    (tester) async {
      await tester.runAsync(() async {
        final h = Harness(buildConfig: syntheticDesktopConfig());
        addTearDown(() async {
          h.staging.dispose();
          await h.db.close();
        });
        await h.seedMicrosoft(shared: false);
        const id = 'microsoft:ms-user';
        await h.secrets.deleteCredential(id);
        final observing = _ObservedAuthRepository(h);
        final container = _container(
          selectedAccountId: id,
          authRepository: observing,
          accounts: await h.accounts.listVisibleAccounts(),
          accountsRepository: h.accounts,
          buildConfig: h.buildConfig,
          productionHarness: h,
          signedInSyncRunner: (_, _) async {},
        );
        addTearDown(container.dispose);
        await _pumpSettings(
          tester,
          container,
          logicalSize: const Size(1200, 1200),
        );
        await tester.tap(
          find.byKey(const ValueKey('reconnect-account-microsoft:ms-user')),
        );
        await tester.pump();
        await observing.started.future;
        await observing.finished;
        await tester.pumpAndSettle();
        expect(h.flow.clients, isEmpty);
        final recovery = find.byKey(
          const ValueKey('replace-registration-recovery-microsoft:ms-user'),
        );
        expect(recovery, findsOneWidget);
        observing.started = Completer<void>();
        await tester.ensureVisible(recovery);
        await tester.tap(recovery);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('registration-busymax')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await observing.started.future;
        await observing.finished;
        await tester.pumpAndSettle();
        expect(
          observing.lastRequest!.intent,
          AuthorizationIntent.replaceRegistration,
        );
        expect(observing.lastRequest!.accountId, id);
        expect(
          (await h.secrets.readCredential(
            id,
          ) as MicrosoftDesktopCredential).subject,
          'ms-user',
        );
        expect(await h.db.select(h.db.accounts).get(), hasLength(1));
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets(
    'six connected accounts retain independent Add actions and target removal',
    (tester) async {
      final accounts = <AccountEntity>[
        for (final provider in [
          BusyProvider.google,
          BusyProvider.microsoft,
          BusyProvider.nextcloud,
        ])
          for (var i = 1; i <= 2; i++)
            AccountEntity(
              id: '${provider.name}:$i',
              provider: provider,
              providerAccountId: provider == BusyProvider.nextcloud
                  ? 'alex'
                  : 'subject-$i',
              authority: provider == BusyProvider.nextcloud
                  ? 'https://cloud$i.example.test'
                  : provider == BusyProvider.google
                  ? 'https://accounts.google.com'
                  : 'https://login.microsoftonline.com/common',
              credentialKind: provider == BusyProvider.nextcloud
                  ? CredentialKind.nextcloudAppPassword
                  : CredentialKind.oauth,
              authState: 'signed_in',
              email: provider == BusyProvider.nextcloud
                  ? null
                  : 'qa$i@example.test',
              displayName:
                  'Quality Assurance $i with a deliberately long account name',
            ),
      ];
      final auth = _FakeAuthRepository();
      final container = _container(
        selectedAccountId: 'google:2',
        authRepository: auth,
        accounts: accounts,
        buildConfig: _configuredBuildConfig,
        signedInSyncRunner: (_, _) async {},
      );
      addTearDown(container.dispose);
      await _pumpSettings(tester, container, logicalSize: const Size(640, 900));
      for (final label in [
        'Add Google account',
        'Add Microsoft account',
        'Add Nextcloud account',
      ]) {
        final row = tester.widget<BusyMaxActionRow>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(BusyMaxActionRow),
          ),
        );
        expect(row.onTap, isNotNull);
      }
      expect(
        find.text(
          'Quality Assurance 1 with a deliberately long account name · https://cloud1.example.test',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Quality Assurance 2 with a deliberately long account name · https://cloud2.example.test',
        ),
        findsOneWidget,
      );
      final remove = find.byKey(const ValueKey('remove-account-google:1'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-account-removal')));
      await tester.pumpAndSettle();
      expect(auth.removalCalls.single.accountId, 'google:1');
      expect(container.read(selectedAccountIdProvider), 'google:2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Linux contacts source switch immediately saves, filters and rolls back failed persistence',
    (tester) async {
      final f = ContactsFixture(AppDatabase.memoryForTests());
      await tester.runAsync(() async {
        await f.addParent(BusyProvider.google);
        await f.controller.enableLinkedContacts('google');
        await f.controller.synchronizeAccount('contacts:google');
      });
      final parent = (await tester.runAsync(
        () => f.accounts.accountById('google'),
      ))!;
      final container = _container(
        selectedAccountId: 'google',
        authRepository: _FakeAuthRepository(),
        accounts: [parent],
        contactsFixture: f,
        accountsRepository: f.accounts,
      );
      addTearDown(() async {
        await _disposeDiagnosticsWidget(tester);
        container.dispose();
        await complete(tester, f.controller.close);
        await tester.runAsync(f.database.close);
      });
      await _pumpSettings(
        tester,
        container,
        logicalSize: const Size(1200, 1800),
        initialPage: SettingsPage.accounts,
      );
      await settle(tester);
      final source = (await complete(
        tester,
        f.controller.sourceSettings,
      )).single.source;
      expect(find.text('Enable contact editing'), findsNothing);
      expect(find.text('Read and write access'), findsNothing);
      expect(
        find.text('Read-only contacts for attendee suggestions'),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('reconnect-contacts-google')),
        findsOneWidget,
      );
      final toggle = find.byKey(ValueKey('contact-source-${source.key}'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await settle(tester);
      expect(tester.widget<YaruSwitch>(toggle).value, isFalse);
      expect(
        await complete(
          tester,
          () =>
              f.controller.suggestAttendees('ada', busyMaxAccountId: 'google'),
        ),
        isEmpty,
      );
      await tester.runAsync(
        () => f.database.customStatement(
          "CREATE TRIGGER reject_source_preference BEFORE UPDATE ON bm_contact_source_preferences BEGIN SELECT RAISE(ABORT,'fixture preference rejected'); END",
        ),
      );
      await tester.tap(toggle);
      await settle(tester);
      expect(tester.widget<YaruSwitch>(toggle).value, isFalse);
      expect(
        find.text('Could not save contact source preference'),
        findsOneWidget,
      );
      expect(
        (await complete(tester, f.controller.sourceSettings)).single.enabled,
        isFalse,
      );
      await tester.runAsync(
        () =>
            f.database.customStatement('DROP TRIGGER reject_source_preference'),
      );
      await tester.tap(toggle);
      await settle(tester);
      expect(tester.widget<YaruSwitch>(toggle).value, isTrue);
      expect(
        await complete(
          tester,
          () =>
              f.controller.suggestAttendees('ada', busyMaxAccountId: 'google'),
        ),
        hasLength(1),
      );
      expect(
        (await complete(
          tester,
          () => f.store.read((tx) => tx.account('contacts:google')),
        ))!.enabled,
        isTrue,
      );
      await _disposeDiagnosticsWidget(tester);
    },
  );
  testWidgets('Settings reports unsaved preferences and retries persistence', (
    tester,
  ) async {
    final store = FailingMemorySettingsStore();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      settingsStore: store,
    );
    addTearDown(container.dispose);
    await _pumpDefaultSettings(
      tester,
      container,
      logicalSize: const Size(1000, 900),
    );
    final traySwitch = find.descendant(
      of: find.ancestor(
        of: find.text('Show tray icon'),
        matching: find.byType(BusyMaxSwitchRow),
      ),
      matching: find.byType(YaruSwitch),
    );
    await tester.tap(traySwitch);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not save settings. Your changes may be lost when BusyMax restarts.',
      ),
      findsOneWidget,
    );
    expect(container.read(appSettingsControllerProvider).showTrayIcon, isFalse);
    expect(store.value, isEmpty);
    store.failSaves = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
    expect(store.value['showTrayIcon'], isFalse);
  });

  registerSettingsAuthorizationCancellationRegressions();
  for (final shared in [false, true]) {
    for (final kind in ['invalid_client', 'invalid_grant', 'server_error']) {
      testWidgets(
        'Settings renders typed exchange recovery and enables stored reconnect retry $kind shared=$shared',
        (tester) async {
          await tester.runAsync(() async {
            final h = Harness(buildConfig: syntheticDesktopConfig());
            addTearDown(() async {
              h.staging.dispose();
              await h.db.close();
            });
            await h.seed();
            if (!shared) await h.makeGoogleUserOwned();
            final before = (await h.secrets.readCredential('opaque'))!.toJson();
            final observing = _ObservedAuthRepository(h);
            final container = _container(
              selectedAccountId: 'opaque',
              authRepository: observing,
              accounts: await h.accounts.listVisibleAccounts(),
              accountsRepository: h.accounts,
              buildConfig: _configuredBuildConfig,
              productionHarness: h,
              signedInSyncRunner: (_, _) async {},
            );
            addTearDown(container.dispose);
            await _pumpSettings(
              tester,
              container,
              logicalSize: const Size(1200, 1200),
            );
            await container.read(registrationSummariesProvider.future);
            await tester.pump();
            h.beforeRequest = (r) async => http.Response(
              jsonEncode({
                'error': kind,
                'error_description': 'sensitive-description',
              }),
              kind == 'server_error' ? 503 : 400,
            );
            await _startStoredGoogleReconnect(
              tester,
              observing,
              replacement: shared,
            );
            await observing.finished;
            await tester.pumpAndSettle();
            final message = kind == 'invalid_client'
                ? 'Check the client type, supported accounts, permissions, and redirect in your registration. Select the configuration again if it was imported.'
                : kind == 'invalid_grant'
                ? 'This authorization attempt could not be completed. Start authorization again; your existing connection is preserved.'
                : 'Authorization could not complete because of a temporary provider problem. Try again; your existing connection is preserved.';
            expect(find.text(message), findsOneWidget);
            expect(find.textContaining('sensitive'), findsNothing);
            expect(
              (await h.secrets.readCredential('opaque'))!.toJson(),
              before,
            );
            expect((await h.summary('opaque')).showRetirementNotice, shared);
            h.beforeRequest = null;
            await _startStoredGoogleReconnect(
              tester,
              observing,
              replacement: shared,
            );
            await observing.finished;
            await tester.pumpAndSettle();
            expect(
              (await h.secrets.readCredential(
                'opaque',
              ) as GoogleDesktopCredential).tokenSet.accessToken,
              'candidate-access',
            );
            await tester.pumpWidget(const SizedBox());
          });
        },
      );
    }
  }
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window'),
          (call) async => call.method == 'state' ? <String, Object?>{} : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window/events'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('yaru_window'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window/events'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  test('Settings defaults generic routes to System', () {
    expect(const SettingsScreen().initialPage, SettingsPage.system);
    expect(settingsPageFromRouteValue(null), SettingsPage.system);
    expect(settingsPageFromRouteValue('unknown'), SettingsPage.system);
    expect(settingsPageFromRouteValue('system'), SettingsPage.system);
    expect(settingsPageFromRouteValue('accounts'), SettingsPage.accounts);
  });

  testWidgets('Settings opens the System page by default', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpDefaultSettings(
      tester,
      container,
      logicalSize: const Size(1000, 700),
    );

    expect(
      tester
          .widget<BusyMaxSidebarNavigationTile>(
            find.byKey(const ValueKey('settings-navigation-system')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Add Google account'), findsNothing);
  });

  testWidgets(
    'launch at login toggles both ways through the real provider chain',
    (tester) async {
      final service = FakeAutostartService();
      final container = _autostartContainer(service);
      addTearDown(container.dispose);
      expect(
        await container.read(launchAtLoginEnabledProvider.future),
        isFalse,
      );
      await _pumpDefaultSettings(
        tester,
        container,
        logicalSize: const Size(1000, 900),
      );

      expect(_launchSwitch(tester).value, isFalse);
      await tester.tap(_launchSwitchFinder);
      await tester.pumpAndSettle();
      expect(service.current, DesktopAutostartState.enabled);
      expect(_launchSwitch(tester).value, isTrue);
      expect(await container.read(launchAtLoginEnabledProvider.future), isTrue);

      await tester.tap(_launchSwitchFinder);
      await tester.pumpAndSettle();
      expect(service.current, DesktopAutostartState.disabled);
      expect(_launchSwitch(tester).value, isFalse);
      expect(
        await container.read(launchAtLoginEnabledProvider.future),
        isFalse,
      );
      expect(service.writes, [true, false]);
    },
  );

  testWidgets(
    'launch at login blocks repeated clicks through write and readback',
    (tester) async {
      final service = FakeAutostartService();
      final container = _autostartContainer(service);
      addTearDown(container.dispose);
      await _pumpDefaultSettings(
        tester,
        container,
        logicalSize: const Size(1000, 900),
      );
      service.writeBarrier = Completer<void>();
      await tester.tap(_launchSwitchFinder);
      await tester.tap(_launchSwitchFinder);
      await tester.pump();
      expect(service.writes, [true]);
      expect(_launchSwitch(tester).onChanged, isNull);
      service.readBarrier = Completer<void>();
      service.writeBarrier!.complete();
      await tester.pump();
      expect(container.read(launchAtLoginControllerProvider), isTrue);
      expect(_launchSwitch(tester).onChanged, isNull);
      service.readBarrier!.complete();
      await tester.pumpAndSettle();
      expect(_launchSwitch(tester).value, isTrue);
      expect(_launchSwitch(tester).onChanged, isNotNull);
    },
  );

  testWidgets(
    'launch at login reports write failure and reads actual state again',
    (tester) async {
      final service = FakeAutostartService();
      final container = _autostartContainer(service);
      addTearDown(container.dispose);
      await _pumpDefaultSettings(
        tester,
        container,
        logicalSize: const Size(1000, 900),
      );
      final reads = service.reads;
      service.writeError = StateError('write failed');
      await tester.tap(_launchSwitchFinder);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update the launch-at-login setting.'),
        findsOneWidget,
      );
      expect(service.reads, greaterThan(reads));
      expect(_launchSwitch(tester).value, isFalse);
      expect(_launchSwitch(tester).onChanged, isNotNull);
      service.writeError = null;
      await tester.tap(_launchSwitchFinder);
      await tester.pumpAndSettle();
      expect(_launchSwitch(tester).value, isTrue);
    },
  );

  testWidgets(
    'launch at login distinguishes failed reads and unavailable state',
    (tester) async {
      final service = FakeAutostartService()
        ..readError = StateError('read failed');
      final container = _autostartContainer(service);
      addTearDown(container.dispose);
      await _pumpDefaultSettings(
        tester,
        container,
        logicalSize: const Size(1000, 900),
      );
      expect(
        find.text('Could not determine the launch-at-login state.'),
        findsOneWidget,
      );
      expect(_launchSwitch(tester).onChanged, isNull);
      service.readError = null;
      service.current = DesktopAutostartState.unavailable;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('Launch at login is unavailable on this system.'),
        findsOneWidget,
      );
      expect(_launchSwitch(tester).onChanged, isNull);
      expect(service.writes, isEmpty);
    },
  );

  testWidgets(
    'launch at login refreshes external changes on resume and reopening',
    (tester) async {
      final service = FakeAutostartService();
      final container = _autostartContainer(service);
      addTearDown(container.dispose);
      await _pumpDefaultSettings(
        tester,
        container,
        logicalSize: const Size(1000, 900),
      );
      service.current = DesktopAutostartState.enabled;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_launchSwitch(tester).value, isTrue);
      await tester.pumpWidget(const SizedBox());
      service.current = DesktopAutostartState.disabled;
      await _pumpDefaultSettings(tester, container);
      expect(_launchSwitch(tester).value, isFalse);
    },
  );

  testWidgets('external startup is shown as on with desktop instructions', (
    tester,
  ) async {
    final service = FakeAutostartService()
      ..current = DesktopAutostartState.enabledExternally;
    final container = _autostartContainer(service);
    addTearDown(container.dispose);
    await _pumpDefaultSettings(
      tester,
      container,
      logicalSize: const Size(1000, 900),
    );
    expect(_launchSwitch(tester).value, isTrue);
    expect(_launchSwitch(tester).onChanged, isNull);
    expect(
      find.text(
        "BusyMax was launched by your desktop's startup settings. "
        'Remove its entry there, then quit and reopen BusyMax to use this switch.',
      ),
      findsOneWidget,
    );
    expect(service.writes, isEmpty);
  });

  testWidgets('Settings inventories visible and provider-hidden calendars', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      calendarSources: const [
        CalendarSourceEntity(
          id: 'visible',
          accountId: 'google:g',
          provider: BusyProvider.google,
          providerCalendarId: 'visible@example.com',
          summary: 'Visible calendar',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
        ),
        CalendarSourceEntity(
          id: 'hidden',
          accountId: 'google:g',
          provider: BusyProvider.google,
          providerCalendarId: 'hidden@example.com',
          summary: 'Hidden calendar',
          selected: true,
          hidden: true,
          readOnly: false,
          isDeleted: false,
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    expect(find.text('Visible calendar'), findsOneWidget);
    expect(find.text('Hidden calendar'), findsOneWidget);
    final visibleSchedule = tester.widget<YaruSwitch>(
      find.byKey(const ValueKey('settings-calendar-schedule-visible')),
    );
    final hiddenSchedule = tester.widget<YaruSwitch>(
      find.byKey(const ValueKey('settings-calendar-schedule-hidden')),
    );
    final hiddenProvider = tester.widget<YaruSwitch>(
      find.byKey(const ValueKey('settings-calendar-provider-hidden')),
    );
    final visibleProvider = tester.widget<YaruSwitch>(
      find.byKey(const ValueKey('settings-calendar-provider-visible')),
    );
    expect(visibleSchedule.value, isTrue);
    expect(visibleSchedule.onChanged, isNotNull);
    expect(hiddenSchedule.value, isFalse);
    expect(hiddenSchedule.onChanged, isNull);
    expect(hiddenProvider.value, isFalse);
    expect(hiddenProvider.onChanged, isNotNull);
    expect(visibleProvider.value, isTrue);
    expect(visibleProvider.onChanged, isNotNull);
    expect(find.text('Visibility'), findsNothing);
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('settings-calendar-column-schedule')),
          )
          .dx,
      closeTo(
        tester
            .getCenter(
              find.byKey(const ValueKey('settings-calendar-schedule-visible')),
            )
            .dx,
        0.01,
      ),
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('settings-calendar-column-provider')),
          )
          .dx,
      closeTo(
        tester
            .getCenter(
              find.byKey(const ValueKey('settings-calendar-provider-visible')),
            )
            .dx,
        0.01,
      ),
    );

    final accountHeading = tester.widget<Text>(
      find.byKey(const ValueKey('settings-account-heading-google:g')),
    );
    final calendarHeading = tester.widget<Text>(find.text('Calendars'));
    expect(
      accountHeading.style!.fontSize,
      greaterThan(calendarHeading.style!.fontSize!),
    );
    final foreground = Theme.of(
      tester.element(
        find.byKey(const ValueKey('settings-account-heading-google:g')),
      ),
    ).colorScheme.onSurface;
    expect(accountHeading.style?.fontWeight, FontWeight.bold);
    expect(accountHeading.style?.color, foreground);
    expect(calendarHeading.style?.fontWeight, FontWeight.bold);
    expect(calendarHeading.style?.color, foreground);
    expect(
      tester.getTopLeft(find.text('Calendars')).dx,
      closeTo(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('settings-account-heading-google:g')),
            )
            .dx,
        0.01,
      ),
    );
  });

  testWidgets('Linux sharing entry opens owner ACL permissions', (
    tester,
  ) async {
    var permissionReads = 0;
    final sharingClient = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/acl')) {
          permissionReads++;
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        return http.Response('unexpected request', 404);
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
    );
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      googleSharingClient: sharingClient,
      calendarSources: const [
        CalendarSourceEntity(
          id: 'owned',
          accountId: 'google:g',
          provider: BusyProvider.google,
          providerCalendarId: 'owned@example.com',
          summary: 'Owned',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
          accessRole: 'owner',
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedTestApp(
          child: const SettingsScreen(initialPage: SettingsPage.accounts),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.text('Manage calendar sharing');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-sharing-recipient')), findsOneWidget);
    expect(permissionReads, 1);
  });

  testWidgets('Every Settings page uses only its headerbar title', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    const expectedTitles = <SettingsPage, String>{
      SettingsPage.system: 'System',
      SettingsPage.accounts: 'Accounts',
      SettingsPage.schedule: 'Schedule',
      SettingsPage.notifications: 'Notifications',
      SettingsPage.privacy: 'Privacy',
      SettingsPage.diagnostics: 'Diagnostics',
    };
    for (final entry in expectedTitles.entries) {
      await tester.tap(
        find.byKey(ValueKey('settings-navigation-${entry.key.name}')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-page-heading')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-header-title')),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Settings section headings use the foreground and bold weight', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 900));
    final foreground = Theme.of(tester.element(find.text('Calendar import')))
        .colorScheme
        .onSurface;
    for (final label in [
      'Google',
      'Calendar import',
      'Calendar subscriptions',
    ]) {
      final heading = tester.widget<Text>(find.text(label));
      expect(heading.style?.fontWeight, FontWeight.bold);
      expect(heading.style?.color, foreground);
    }

    await tester.tap(
      find.byKey(const ValueKey('settings-navigation-schedule')),
    );
    await tester.pumpAndSettle();
    final scheduleHeading = tester.widget<Text>(find.text('Schedule display'));
    expect(scheduleHeading.style?.fontWeight, FontWeight.bold);
    expect(scheduleHeading.style?.color, foreground);
  });

  testWidgets('Schedule lets users choose a default or Last used destination', (
    tester,
  ) async {
    const calendar = CalendarSourceEntity(
      id: 'calendar-1',
      accountId: 'google:g',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar-1',
      summary: 'Work calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    const list = TaskListEntity(
      accountId: 'google:g',
      id: 'tasks-1',
      title: 'Work tasks',
      localDirty: false,
      pendingDelete: false,
      rawJson: '{}',
    );
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      calendarSources: const [calendar],
      taskLists: const [list],
    );
    addTearDown(container.dispose);
    await _pumpSettings(
      tester,
      container,
      initialPage: SettingsPage.schedule,
      logicalSize: const Size(1000, 900),
    );
    expect(find.text('New events and tasks'), findsOneWidget);
    final rows = tester
        .widgetList<BusyMaxComboRow<CreationDestination?>>(
          find.byType(BusyMaxComboRow<CreationDestination?>),
        )
        .toList();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.title), [
      'Default calendar',
      'Default task list',
    ]);
    expect(rows.map((row) => row.selected), [null, null]);
    rows[0].onSelected(
      const CreationDestination(accountId: 'google:g', id: 'calendar-1'),
    );
    rows[1].onSelected(
      const CreationDestination(accountId: 'google:g', id: 'tasks-1'),
    );
    await tester.pumpAndSettle();
    final settings = container.read(appSettingsControllerProvider);
    expect(settings.defaultCalendar?.id, 'calendar-1');
    expect(settings.defaultTaskList?.id, 'tasks-1');
    final updatedRows = tester
        .widgetList<BusyMaxComboRow<CreationDestination?>>(
          find.byType(BusyMaxComboRow<CreationDestination?>),
        )
        .toList();
    updatedRows[0].onSelected(null);
    updatedRows[1].onSelected(null);
    await tester.pumpAndSettle();
    expect(
      container.read(appSettingsControllerProvider).defaultCalendar,
      isNull,
    );
    expect(
      container.read(appSettingsControllerProvider).defaultTaskList,
      isNull,
    );
  });

  testWidgets('Settings Flutter header uses native geometry and title style', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    final titleRoot = find.byKey(const ValueKey('settings-header-title'));
    final title = tester.widget<Text>(
      find.descendant(of: titleRoot, matching: find.text('Accounts')),
    );
    final context = tester.element(titleRoot);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    expect(title.style?.fontSize, bodyStyle?.fontSize);
    expect(title.style?.fontFamily, bodyStyle?.fontFamily);
    expect(title.style?.fontWeight, FontWeight.bold);
    expect(
      tester.getSize(find.byKey(const ValueKey('settings-header-back-button'))),
      const Size.square(BusyMaxSizes.headerIconButton),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('busymax-main-menu-button'))),
      const Size.square(BusyMaxSizes.headerIconButton),
    );
    final header = tester.getRect(find.byType(BusyMaxLinuxHeaderLayout));
    expect(tester.getRect(titleRoot).center.dx, closeTo(header.center.dx, .01));
    BusyMaxLinuxHeaderIcon iconFor(String key) => tester
        .widget<BusyMaxGtkHeaderIcon>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(BusyMaxGtkHeaderIcon),
          ),
        )
        .icon;
    expect(iconFor('settings-header-back-button'), BusyMaxLinuxHeaderIcon.back);
    expect(
      iconFor('busymax-main-menu-button'),
      BusyMaxLinuxHeaderIcon.mainMenu,
    );
  });

  testWidgets('Settings removes the selected Microsoft account', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'microsoft:m',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    expect(find.byKey(const Key('revoke-google-authorization')), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, [
      const _AccountRemovalCall('microsoft:m', revokeAuthorization: false),
    ]);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('Settings keeps Google revocation opt-in', (tester) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    final revoke = find.byKey(const Key('revoke-google-authorization'));
    expect(revoke, findsOneWidget);
    expect(tester.widget<YaruCheckboxListTile>(revoke).value, isFalse);
    await tester.tap(revoke);
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, [
      const _AccountRemovalCall('google:g', revokeAuthorization: true),
    ]);
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets(
    'Settings reports failed Nextcloud revocation after complete local removal',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final secrets = InMemorySecretStore();
      await AccountsRepository(database: database).upsertSignedInAccount(
        id: _nextcloudAccount.id,
        provider: BusyProvider.nextcloud,
        authority: _nextcloudAccount.authority,
        providerAccountId: _nextcloudAccount.providerAccountId,
        credentialKind: CredentialKind.nextcloudAppPassword,
        displayName: _nextcloudAccount.displayName,
        grantedScopes: '',
      );
      await secrets.saveCredential(
        _nextcloudAccount.id,
        NextcloudSecretRecord(
          canonicalServer: Uri.parse(_nextcloudAccount.authority),
          loginName: _nextcloudAccount.providerAccountId,
          appPassword: 'test-app-password',
        ),
      );
      await secrets.setActiveAccountId(_nextcloudAccount.id);
      final onboarding = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _unusedNextcloudLoginFlow(),
        discover: ({
          required accountId,
          required provider,
          required accountAuthority,
          required credential,
          cancellationToken,
        }) async => throw StateError('Discovery is not used by removal.'),
        nextcloudCredentialRevoker:
            ({required accountId, required credential}) async {
              throw const DavException(
                kind: DavErrorKind.network,
                code: 'RevocationOffline',
                safeMessage: 'Offline.',
              );
            },
      );
      final auth = _FakeAuthRepository();
      final container = _container(
        selectedAccountId: _nextcloudAccount.id,
        authRepository: auth,
        accounts: const [_googleAccount, _nextcloudAccount],
        davOnboardingService: onboarding,
        databaseOverride: database,
      );
      addTearDown(container.dispose);

      await _pumpSettings(tester, container);
      await _openAccountRemovalDialog(tester);
      expect(
        find.byKey(const Key('revoke-google-authorization')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('confirm-account-removal')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The account was removed locally, but its Nextcloud app password '
          'could not be revoked.',
        ),
        findsOneWidget,
      );
      expect(auth.removalCalls, isEmpty);
      expect(container.read(selectedAccountIdProvider), _googleAccount.id);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await secrets.readCredential(_nextcloudAccount.id), isNull);
      expect(await secrets.readActiveAccountId(), isNull);
    },
  );

  testWidgets('Settings cancels account removal without mutation', (
    tester,
  ) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, isEmpty);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('subscription dialog groups, validates, and submits its form', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final transport = _SettingsWebCalTransport();
    final service = WebCalSubscriptionService(
      database: database,
      secretStore: InMemorySecretStore(),
      httpTransport: transport,
      idFactory: () => 'settings-subscription',
      nowUtc: () => DateTime.utc(2026, 9, 19),
      onNotificationScheduleChanged: () async {},
    );
    late BuildContext hostContext;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webCalSubscriptionServiceProvider.overrideWithValue(service),
        ],
        child: localizedTestApp(
          theme: BusyMaxYaruTheme.build(
            brightness: Brightness.dark,
            accentColor: YaruColors.orange,
          ),
          child: Consumer(
            builder: (context, ref, child) {
              hostContext = context;
              widgetRef = ref;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );

    final flow = showAddCalendarSubscriptionFlow(
      hostContext,
      widgetRef,
      initialUrl: 'webcal://calendar.example.test/feed',
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.byType(BusyMaxGroupedList), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(BusyMaxDialogShell),
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(3));
    expect(
      tester.widget<TextField>(fields.first).decoration?.border,
      InputBorder.none,
    );
    expect(
      tester.widget<TextField>(fields.first).controller!.text,
      'webcal://calendar.example.test/feed',
    );
    expect(
      find.textContaining('https://calendar.example.test'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').contains('/feed'),
      ),
      findsNothing,
    );

    await tester.enterText(fields.first, 'not a subscription URL');
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('confirm-add-subscription')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(fields.first, 'webcal://calendar.example.test/feed');
    await tester.enterText(fields.at(1), 'Team schedule');
    await tester.enterText(fields.at(2), '#336699');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-add-subscription')));
    await tester.pumpAndSettle();
    await flow;

    expect(transport.requests, [
      Uri.parse('https://calendar.example.test/feed'),
    ]);
    final subscription = await database
        .select(database.webCalSubscriptions)
        .getSingle();
    final source = await database.select(database.calendarSources).getSingle();
    expect(subscription.safeOrigin, 'https://calendar.example.test');
    expect(subscription.refreshMode, WebCalRefreshMode.automatic.storageValue);
    expect(source.summary, 'Team schedule');
    expect(source.backgroundColor, '#336699');
  });

  testWidgets('subscription dialog cancellation performs no request', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final transport = _SettingsWebCalTransport();
    final service = WebCalSubscriptionService(
      database: database,
      secretStore: InMemorySecretStore(),
      httpTransport: transport,
    );
    late BuildContext hostContext;
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webCalSubscriptionServiceProvider.overrideWithValue(service),
        ],
        child: localizedTestApp(
          child: Consumer(
            builder: (context, ref, child) {
              hostContext = context;
              widgetRef = ref;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );

    final flow = showAddCalendarSubscriptionFlow(
      hostContext,
      widgetRef,
      initialUrl: 'https://calendar.example.test/feed',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await flow;

    expect(transport.requests, isEmpty);
    expect(await database.select(database.webCalSubscriptions).get(), isEmpty);
  });

  testWidgets('Settings exposes one readable dark account-removal action', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: YaruColors.orange,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedTestApp(
          theme: theme,
          child: const SettingsScreen(initialPage: SettingsPage.accounts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remove account…'), findsOneWidget);
    expect(
      find.text(
        'Stop syncing and remove this account’s data from this device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign out this account'), findsNothing);
    expect(find.text('Disconnect this account'), findsNothing);
    expect(find.text('Delete local data for this account'), findsNothing);

    final removeRowFinder = find.ancestor(
      of: find.text('Remove account…'),
      matching: find.byType(BusyMaxActionRow),
    );
    final removeRow = tester.widget<BusyMaxActionRow>(removeRowFinder);
    final removeTitle = tester.widget<Text>(find.text('Remove account…'));
    final trash = tester.widget<Icon>(
      find.descendant(
        of: removeRowFinder,
        matching: find.byIcon(YaruIcons.trash),
      ),
    );
    expect(removeRow.destructive, isFalse);
    expect(removeTitle.style?.color, isNot(theme.colorScheme.error));
    expect(trash.color, theme.colorScheme.error);

    await tester.ensureVisible(removeRowFinder);
    await tester.tap(find.text('Remove account…'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<ElevatedButton>(
      find.byKey(const Key('confirm-account-removal')),
    );
    expect(
      confirm.style?.backgroundColor?.resolve(const <WidgetState>{}),
      theme.colorScheme.error,
    );
    expect(
      confirm.style?.foregroundColor?.resolve(const <WidgetState>{}),
      theme.colorScheme.onError,
    );
  });

  testWidgets('Settings reports a local account-removal failure in place', (
    tester,
  ) async {
    final auth = _FakeAuthRepository()
      ..removeError = StateError('local cleanup failed');
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);
    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(container.read(selectedAccountIdProvider), 'google:g');
    expect(
      find.text('Could not finish removing the account. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Settings prevents duplicate account-removal submission', (
    tester,
  ) async {
    final removal = Completer<AccountRemovalResult>();
    final auth = _FakeAuthRepository()..removalCompleter = removal;
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);
    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    // Account mutation starts only after the dialog route has completed its
    // exit transition and released its modal protection.
    await tester.pumpAndSettle();

    expect(auth.removalCalls, hasLength(1));
    expect(find.text('Removing account…'), findsOneWidget);
    final removingRow = tester.widget<BusyMaxActionRow>(
      find.ancestor(
        of: find.text('Removing account…'),
        matching: find.byType(BusyMaxActionRow),
      ),
    );
    expect(removingRow.enabled, isFalse);
    await tester.tap(find.text('Removing account…'), warnIfMissed: false);
    await tester.pump();
    expect(auth.removalCalls, hasLength(1));

    removal.complete(
      const AccountRemovalResult(
        authorizationRevocationStatus:
            AccountAuthorizationRevocationStatus.notRequested,
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings reports partial Google revocation failure', (
    tester,
  ) async {
    final auth = _FakeAuthRepository()
      ..removalResult = const AccountRemovalResult(
        authorizationRevocationStatus:
            AccountAuthorizationRevocationStatus.failed,
      );
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount, _microsoftAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);
    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('revoke-google-authorization')));
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The account was removed from this device, but BusyMax could not '
        'revoke Google access. You can revoke it from your Google Account.',
      ),
      findsOneWidget,
    );
    expect(container.read(selectedAccountIdProvider), 'microsoft:m');
  });

  testWidgets('Settings shows reconnect-required account state', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_reconnectRequiredGoogleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(
      find.byKey(const ValueKey('reconnect-account-google:g')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your Google account needs to be reconnected to resume calendar and task synchronization.',
      ),
      findsWidgets,
    );
    expect(find.text('New task list'), findsNothing);
    expect(find.text('Remove account…'), findsOneWidget);

    await _openAccountRemovalDialog(tester);
    expect(find.byKey(const Key('revoke-google-authorization')), findsNothing);
  });

  testWidgets('Settings exposes add account actions', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Add Microsoft account'), findsOneWidget);
  });

  testWidgets(
    'Settings presents DAV calendars and task lists as named controls',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final container = _container(
        selectedAccountId: _nextcloudAccount.id,
        authRepository: _FakeAuthRepository(),
        accounts: const [_nextcloudAccount],
        davCollections: [
          _davCollection(
            id: 'personal-calendar',
            name: 'Personal',
            supportsEvents: true,
            color: '#3366cc',
          ),
          _davCollection(
            id: 'task-list',
            name: 'NCC Task List',
            supportsTasks: true,
            tasksSelected: false,
            readOnly: true,
            lastSyncAtUtc: DateTime.utc(2026, 8, 10),
            syncErrorCode: 'CalDavUnavailable',
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpSettings(
        tester,
        container,
        logicalSize: const Size(1000, 900),
      );

      expect(find.text('Calendars and task lists'), findsOneWidget);
      expect(find.text('Collections'), findsNothing);
      expect(find.text('Refresh calendars and task lists'), findsOneWidget);

      final calendar = find.byKey(
        const ValueKey('dav-collection-personal-calendar'),
      );
      final taskList = find.byKey(const ValueKey('dav-collection-task-list'));
      expect(
        find.descendant(
          of: calendar,
          matching: find.byType(YaruSwitchListTile),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: taskList,
          matching: find.byType(YaruSwitchListTile),
        ),
        findsOneWidget,
      );
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('NCC Task List'), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.descendant(
                of: find.byKey(
                  const ValueKey('dav-collection-settings-personal-calendar'),
                ),
                matching: find.byType(IconButton),
              ),
            )
            .label,
        contains('Personal'),
      );
      expect(
        find.byKey(const ValueKey('dav-collection-settings-personal-calendar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dav-collection-settings-task-list')),
        findsOneWidget,
      );
      expect(
        find.text('Task list · Read-only · Sync issue: CalDavUnavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('Last synchronized:'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('eligible DAV account can refresh collections', (tester) async {
    final calls = <String>[];
    final container = _container(
      selectedAccountId: _nextcloudAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_nextcloudAccount],
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 900));
    await tester.ensureVisible(find.text('Refresh calendars and task lists'));
    await tester.tap(find.text('Refresh calendars and task lists'));
    await tester.pumpAndSettle();

    expect(calls, [_nextcloudAccount.id]);
  });

  testWidgets('reconnect-required DAV account cannot refresh collections', (
    tester,
  ) async {
    final calls = <String>[];
    final container = _container(
      selectedAccountId: _reconnectRequiredNextcloudAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_reconnectRequiredNextcloudAccount],
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 900));

    expect(find.text('Refresh calendars and task lists'), findsNothing);
    expect(find.text(accountReconnectRequiredActionLabel), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('DAV collection refresh re-reads eligibility before dispatch', (
    tester,
  ) async {
    final calls = <String>[];
    final repository = _MutableEligibilityAccountsRepository([
      _nextcloudAccount,
    ]);
    final cachedCollection = _davCollection(
      id: 'cached-calendar',
      name: 'Cached calendar',
      supportsEvents: true,
    );
    final container = _container(
      selectedAccountId: _nextcloudAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_nextcloudAccount],
      accountsRepository: repository,
      davCollections: [cachedCollection],
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 900));
    repository.canonicalAccounts = const [_reconnectRequiredNextcloudAccount];
    await tester.ensureVisible(find.text('Refresh calendars and task lists'));
    await tester.tap(find.text('Refresh calendars and task lists'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(
      find.text('Sync failed: This account needs to be reconnected.'),
      findsOneWidget,
    );
    expect(find.text('Cached calendar'), findsOneWidget);
  });

  testWidgets('Settings nests controls for combined DAV content', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: _nextcloudAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_nextcloudAccount],
      davCollections: [
        _davCollection(
          id: 'combined',
          name: 'Team schedule',
          supportsEvents: true,
          supportsTasks: true,
          shared: true,
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 900));

    final combined = find.byKey(const ValueKey('dav-collection-combined'));
    expect(find.text('Team schedule'), findsOneWidget);
    expect(find.text('Events and tasks · Shared'), findsOneWidget);
    expect(
      find.descendant(of: combined, matching: find.byType(YaruSwitchListTile)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: combined, matching: find.text('Calendar events')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: combined, matching: find.text('Tasks')),
      findsOneWidget,
    );
  });

  testWidgets('Settings sidebar separates settings pages', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    expect(find.text('Add Google account'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Localization'), findsNothing);
    expect(find.text('Sync'), findsNothing);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Day starts at'), findsOneWidget);
    expect(find.text('Day ends at'), findsOneWidget);
    expect(find.text('Add Google account'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-navigation-system')));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Current locale'), findsOneWidget);
    expect(find.text('Force full resync'), findsNothing);
    expect(find.text('Launch at login'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Current locale')).dy,
      lessThan(tester.getTopLeft(find.text('Show tray icon')).dy),
    );
    expect(find.text('Theme family'), findsNothing);
    expect(find.text('Add Google account'), findsNothing);
  });

  testWidgets('Russian System section uses a standalone noun', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(1000, 700),
      locale: const Locale('ru'),
    );

    final systemNavigation = find.byKey(
      const ValueKey('settings-navigation-system'),
    );
    expect(
      find.descendant(of: systemNavigation, matching: find.text('Система')),
      findsOneWidget,
    );
    expect(find.text('Системная'), findsNothing);

    await tester.tap(systemNavigation);
    await tester.pumpAndSettle();

    expect(find.text('Система'), findsNWidgets(2));
    expect(find.text('Системная'), findsWidgets);
  }, skip: !Platform.isLinux);

  testWidgets('Settings workspace uses the native window surface', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFF0F1F2),
      view: Color(0xFFFFFFFF),
      sidebar: Color(0xFFE5E6E7),
    );
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: YaruColors.orange,
      gtkThemeColors: gtkColors,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedTestApp(
          child: Theme(data: theme, child: const SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, gtkColors.window);
    expect(scaffold.backgroundColor, isNot(gtkColors.view));
  });

  testWidgets('Settings uses Yaru master-detail rows with selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    expect(find.byType(BusyMaxSidebarNavigation), findsOneWidget);
    expect(
      find.byType(YaruMasterTile),
      findsNWidgets(SettingsPage.values.length),
    );
    expect(find.byType(YaruNavigationRail), findsNothing);
    expect(find.byType(BusyMaxSidebarSurface), findsOneWidget);
    expect(
      tester
          .widget<BusyMaxSidebarSurface>(find.byType(BusyMaxSidebarSurface))
          .showEndBorder,
      isFalse,
    );
    final navigationTiles = tester
        .widgetList<BusyMaxSidebarNavigationTile>(
          find.byType(BusyMaxSidebarNavigationTile),
        )
        .toList(growable: false);
    expect(
      navigationTiles.first.key,
      const ValueKey('settings-navigation-system'),
    );
    final accountsTile = tester.widget<BusyMaxSidebarNavigationTile>(
      find.byKey(const ValueKey('settings-navigation-accounts')),
    );
    final scheduleTile = tester.widget<BusyMaxSidebarNavigationTile>(
      find.byKey(const ValueKey('settings-navigation-schedule')),
    );
    expect(accountsTile.selected, isTrue);
    expect(scheduleTile.selected, isFalse);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('settings-navigation-accounts')),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('settings-navigation-schedule')),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isFalse,
    );

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<BusyMaxSidebarNavigationTile>(
            find.byKey(const ValueKey('settings-navigation-schedule')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('settings-navigation-schedule')),
          )
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('Diagnostics stays inside Settings shell', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 700));

    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Force full resync'), findsOneWidget);
    expect(
      find.text(
        'Completely reload data from every connected account. Use this only '
        'to troubleshoot synchronization problems.',
      ),
      findsOneWidget,
    );
    expect(find.text('Google Tasks API'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Sync')).style,
      tester.widget<Text>(find.text('Google Tasks API')).style,
    );
    final resyncSection = tester.getRect(
      find.byKey(const ValueKey('diagnostics-full-resync-section')),
    );
    final diagnosticsContent = tester.getRect(find.text('Google Tasks API'));
    expect(diagnosticsContent.top - resyncSection.bottom, BusyMaxSpacing.lg);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Add Google account'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Force full resync runs for a connected account', (tester) async {
    final calls = <String>[];
    final container = _container(
      selectedAccountId: _googleAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(1000, 700),
      initialPage: SettingsPage.diagnostics,
    );
    await tester.tap(find.text('Force full resync'));
    await tester.pumpAndSettle();

    expect(calls, [_googleAccount.id]);
    await _disposeDiagnosticsWidget(tester);
  });

  testWidgets('Force full resync skips reconnect-required accounts', (
    tester,
  ) async {
    final calls = <String>[];
    const reconnect = AccountEntity(
      id: 'google:reauth',
      provider: BusyProvider.google,
      authority: 'https://accounts.google.com',
      providerAccountId: 'reauth',
      authState: accountAuthStateReauthRequired,
    );
    final container = _container(
      selectedAccountId: _googleAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount, reconnect],
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(1000, 700),
      initialPage: SettingsPage.diagnostics,
    );
    await tester.tap(find.text('Force full resync'));
    await tester.pumpAndSettle();

    expect(calls, [_googleAccount.id]);
    await _disposeDiagnosticsWidget(tester);
  });

  testWidgets('Force full resync is disabled without eligible accounts', (
    tester,
  ) async {
    final calls = <String>[];
    final container = _container(
      selectedAccountId: _reconnectRequiredGoogleAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_reconnectRequiredGoogleAccount],
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(1000, 700),
      initialPage: SettingsPage.diagnostics,
    );

    final row = tester.widget<BusyMaxActionRow>(
      find.ancestor(
        of: find.text('Force full resync'),
        matching: find.byType(BusyMaxActionRow),
      ),
    );
    expect(row.enabled, isFalse);
    expect(row.onTap, isNull);
    expect(calls, isEmpty);
    await _disposeDiagnosticsWidget(tester);
  });

  testWidgets('Force full resync re-reads eligibility before dispatch', (
    tester,
  ) async {
    final calls = <String>[];
    final repository = _MutableEligibilityAccountsRepository([_googleAccount]);
    final container = _container(
      selectedAccountId: _googleAccount.id,
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      accountsRepository: repository,
      signedInSyncRunner: (accountId, full) async => calls.add(accountId),
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(1000, 700),
      initialPage: SettingsPage.diagnostics,
    );
    repository.canonicalAccounts = const [_reconnectRequiredGoogleAccount];
    await tester.tap(find.text('Force full resync'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
    await _disposeDiagnosticsWidget(tester);
  });

  testWidgets('Settings uses single-pane navigation at narrow widths', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      buildConfig: _configuredBuildConfig,
      activeAccountIdOverride: null,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(640, 700));

    expect(find.text('Accounts'), findsWidgets);
    expect(find.text('Schedule'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(_settingsMenuItemWithLabel('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Day starts at'), findsOneWidget);
    expect(find.text('Day ends at'), findsOneWidget);
  });

  testWidgets('Settings narrow layout supports large text', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(
      tester,
      container,
      logicalSize: const Size(640, 700),
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey('settings-page-selector')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quiet-hour times are exposed and follow the master switch', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container, logicalSize: const Size(1000, 800));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    var timeRows = tester.widgetList<DesktopTimeValueRow>(
      find.byType(DesktopTimeValueRow),
    );
    expect(
      timeRows.map((row) => row.label),
      containsAll(<String>['Quiet hours start', 'Quiet hours end']),
    );
    expect(timeRows.every((row) => !row.enabled), isTrue);

    await tester.ensureVisible(find.text('Quiet hours'));
    await tester.tap(find.text('Quiet hours'));
    await tester.pumpAndSettle();

    timeRows = tester.widgetList<DesktopTimeValueRow>(
      find.byType(DesktopTimeValueRow),
    );
    expect(timeRows.every((row) => row.enabled), isTrue);
  });

  test('Schedule display hours persist and keep a valid range', () async {
    final store = _MemorySettingsStore();
    final first = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    await first.setScheduleDayStartMinute(9 * 60);
    await first.setScheduleDayEndMinute(18 * 60);

    final second = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    expect(second.state.scheduleDayStartMinute, 9 * 60);
    expect(second.state.scheduleDayEndMinute, 18 * 60);

    await second.setScheduleDayStartMinute(23 * 60);

    expect(second.state.scheduleDayStartMinute, 23 * 60);
    expect(second.state.scheduleDayEndMinute, 24 * 60);
  });

  testWidgets('Linux schedule settings exposes and persists first weekday', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);
    await _pumpSettings(
      tester,
      container,
      initialPage: SettingsPage.schedule,
      logicalSize: const Size(1000, 800),
    );

    final row = tester.widget<BusyMaxComboRow<BusyMaxFirstDayOfWeekPreference>>(
      find.byWidgetPredicate(
        (widget) => widget is BusyMaxComboRow<BusyMaxFirstDayOfWeekPreference>,
      ),
    );
    expect(row.values, BusyMaxFirstDayOfWeekPreference.values);
    expect(row.selected, BusyMaxFirstDayOfWeekPreference.system);
    expect(row.labelFor(row.selected), startsWith('System Default ('));
    row.onSelected(BusyMaxFirstDayOfWeekPreference.saturday);
    await tester.pumpAndSettle();
    expect(
      container.read(appSettingsControllerProvider).firstDayOfWeekPreference,
      BusyMaxFirstDayOfWeekPreference.saturday,
    );
  });

  testWidgets('Settings owns calendar import but not task-list creation', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount, _microsoftAccount],
      buildConfig: _configuredBuildConfig,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('New task list'), findsNothing);
    expect(find.text('Calendar import'), findsOneWidget);
    expect(
      find.text(
        'Select a file, review its events, then choose the writable calendar '
        'that should receive them.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('import-ics-file')), findsOneWidget);
    expect(find.text('Import .ics file'), findsOneWidget);
    expect(find.text('Remove account…'), findsNWidgets(2));
  });

  testWidgets('Settings lists accounts without account switching controls', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount, _microsoftAccount],
      buildConfig: _configuredBuildConfig,
    );
    addTearDown(container.dispose);

    await _pumpSettings(tester, container);

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Google User · google@example.com'), findsOneWidget);
    expect(find.text('Microsoft'), findsOneWidget);
    expect(find.text('Microsoft User · microsoft@example.com'), findsOneWidget);
    expect(find.text('Google Tasks'), findsNothing);
    expect(find.text('Microsoft To Do'), findsNothing);
    expect(find.text('Current account'), findsNothing);
    expect(find.text('Switch account'), findsNothing);
    expect(find.text('Fluent UI'), findsNothing);
    expect(container.read(selectedAccountIdProvider), 'google:g');
  });

  testWidgets('Settings back button returns to schedule', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpRoutedSettings(tester, container);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('schedule route'), findsOneWidget);
  });

  testWidgets('Alt+Left uses Settings schedule fallback', (tester) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpRoutedSettings(tester, container);
    await _sendAltLeft(tester);

    expect(find.text('schedule route'), findsOneWidget);
  });

  testWidgets('Settings back returns to the route that opened it', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    final router = await _pumpRoutedSettings(
      tester,
      container,
      initialLocation: '/tasks',
    );
    unawaited(router.push('/settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(_settingsMenuItemWithLabel('Notifications'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['page'], 'notifications');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('tasks route'), findsOneWidget);
  });

  testWidgets('Alt+Left pops Settings to the route that opened it', (
    tester,
  ) async {
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    final router = await _pumpRoutedSettings(
      tester,
      container,
      initialLocation: '/tasks',
    );
    unawaited(router.push('/settings'));
    await tester.pumpAndSettle();

    await _sendAltLeft(tester);

    expect(find.text('tasks route'), findsOneWidget);
  });

  testWidgets('Removing last account leaves Settings open', (tester) async {
    final auth = _FakeAuthRepository();
    final container = _container(
      selectedAccountId: 'google:g',
      authRepository: auth,
      accounts: const [_googleAccount],
    );
    addTearDown(container.dispose);

    await _pumpRoutedSettings(tester, container);

    await _openAccountRemovalDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-account-removal')));
    await tester.pumpAndSettle();

    expect(auth.removalCalls, [
      const _AccountRemovalCall('google:g', revokeAuthorization: false),
    ]);
    expect(container.read(selectedAccountIdProvider), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Add Google account'), findsOneWidget);
  });
}

Finder _settingsMenuItemWithLabel(String label) {
  return find.ancestor(
    of: find.text(label).last,
    matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
  );
}

Future<void> _openAccountRemovalDialog(WidgetTester tester) async {
  final removeAction = find.text('Remove account…').first;
  await tester.ensureVisible(removeAction);
  await tester.pumpAndSettle();
  await tester.tap(removeAction);
  await tester.pumpAndSettle();
  expect(find.textContaining('from BusyMax?'), findsOneWidget);
}

Future<void> _sendAltLeft(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

ProviderContainer _container({
  required String selectedAccountId,
  required AuthRepository authRepository,
  required List<AccountEntity> accounts,
  BuildConfig buildConfig = _emptyBuildConfig,
  String? activeAccountIdOverride = _useDefaultActiveAccountId,
  DavAccountOnboardingService? davOnboardingService,
  List<DavCollectionSettingsEntity> davCollections = const [],
  List<CalendarSourceEntity> calendarSources = const [],
  GoogleCalendarApiClient? googleSharingClient,
  List<TaskListEntity> taskLists = const [],
  DesktopAutostartService? autostartService,
  LocalSettingsStore? settingsStore,
  AccountsRepository? accountsRepository,
  SignedInSyncRunner? signedInSyncRunner,
  Harness? productionHarness,
  ContactsFixture? contactsFixture,
  Stream<Map<String, RegistrationSummary>>? registrationSummaryStream,
  Stream<List<CalendarSourceEntity>>? calendarSourceStream,
  CalendarRepository? calendarRepository,
  AppDatabase? databaseOverride,
  PendingOpResolutionService Function(String)? operationResolution,
}) {
  final database =
      databaseOverride ??
      contactsFixture?.database ??
      productionHarness?.db ??
      AppDatabase.memoryForTests();
  if (databaseOverride == null &&
      contactsFixture == null &&
      productionHarness == null) {
    addTearDown(database.close);
  }
  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      if (operationResolution != null)
        pendingOpResolutionServiceForAccountProvider.overrideWith(
          (ref, id) => operationResolution(id),
        ),
      if (calendarRepository != null)
        calendarRepositoryProvider.overrideWithValue(calendarRepository),
      if (registrationSummaryStream != null)
        registrationSummariesProvider.overrideWith(
          (ref) => registrationSummaryStream,
        ),
      if (contactsFixture != null) ...[
        databaseProvider.overrideWithValue(contactsFixture.database),
        busyMaxContactsControllerProvider.overrideWithValue(
          contactsFixture.controller,
        ),
      ],
      if (productionHarness != null) ...[
        databaseProvider.overrideWithValue(productionHarness.db),
        registrationStagingProvider.overrideWithValue(
          productionHarness.staging,
        ),
        authorizationPersistenceProvider.overrideWithValue(
          productionHarness.persistence,
        ),
        applicationOAuthGatewayProvider.overrideWithValue(
          productionHarness.google,
        ),
        applicationMicrosoftOAuthServiceProvider.overrideWithValue(
          productionHarness.microsoft,
        ),
      ],
      if (autostartService != null)
        desktopAutostartServiceProvider.overrideWithValue(autostartService),
      authRepositoryProvider.overrideWithValue(authRepository),
      if (davOnboardingService != null)
        davAccountOnboardingServiceProvider.overrideWithValue(
          davOnboardingService,
        ),
      accountsRepositoryProvider.overrideWithValue(
        accountsRepository ?? _FakeAccountsRepository(accounts),
      ),
      if (signedInSyncRunner != null)
        signedInSyncRunnerProvider.overrideWithValue(signedInSyncRunner),
      accountsStreamProvider.overrideWith((ref) => Stream.value(accounts)),
      accountManagementStreamProvider.overrideWith(
        (ref) => Stream.value(accounts),
      ),
      davCollectionsStreamProvider.overrideWith(
        (ref) => Stream.value(davCollections),
      ),
      calendarSourcesStreamProvider.overrideWith(
        (ref) => calendarSourceStream ?? Stream.value(calendarSources),
      ),
      if (googleSharingClient != null)
        googleCalendarApiClientForAccountProvider.overrideWith(
          (ref, accountId) => googleSharingClient,
        ),
      scheduleTaskListsProvider.overrideWith((ref) async => taskLists),
      davConflictsStreamProvider.overrideWith((ref) => Stream.value(const [])),
      webCalSubscriptionsProvider.overrideWith((ref) => Stream.value(const [])),
      selectedAccountIdProvider.overrideWith((ref) => selectedAccountId),
      if (activeAccountIdOverride != _useDefaultActiveAccountId)
        activeAccountProvider.overrideWithValue(activeAccountIdOverride),
      localSettingsStoreProvider.overrideWithValue(
        settingsStore ?? _MemorySettingsStore(),
      ),
      buildConfigProvider.overrideWithValue(buildConfig),
    ],
  );
}

const _useDefaultActiveAccountId = '__busymax_default_active_account__';

ProviderContainer _autostartContainer(FakeAutostartService service) =>
    _container(
      selectedAccountId: 'google:g',
      authRepository: _FakeAuthRepository(),
      accounts: const [_googleAccount],
      autostartService: service,
    );

final _launchSwitchFinder = find.descendant(
  of: find.byKey(const ValueKey('launch-at-login-switch')),
  matching: find.byType(YaruSwitch),
);

YaruSwitch _launchSwitch(WidgetTester tester) =>
    tester.widget<YaruSwitch>(_launchSwitchFinder);

NextcloudLoginFlowV2 _unusedNextcloudLoginFlow() => NextcloudLoginFlowV2(
  client: MockClient((_) async => http.Response('', 500)),
  browserLauncher: (_) async => false,
);

Future<void> _pumpSettings(
  WidgetTester tester,
  ProviderContainer container, {
  Size? logicalSize,
  TextScaler? textScaler,
  Locale locale = const Locale('en'),
  SettingsPage initialPage = SettingsPage.accounts,
}) async {
  if (logicalSize != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
  final settings = textScaler == null
      ? SettingsScreen(initialPage: initialPage)
      : Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: SettingsScreen(initialPage: initialPage),
          ),
        );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(locale: locale, child: settings),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _disposeDiagnosticsWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _pumpDefaultSettings(
  WidgetTester tester,
  ProviderContainer container, {
  Size? logicalSize,
}) async {
  if (logicalSize != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedTestApp(child: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpRoutedSettings(
  WidgetTester tester,
  ProviderContainer container, {
  String initialLocation = '/settings',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) =>
            const SettingsScreen(initialPage: SettingsPage.accounts),
      ),
      GoRoute(
        path: '/schedule',
        builder: (_, _) => const Text('schedule route'),
      ),
      GoRoute(path: '/tasks', builder: (_, _) => const Text('tasks route')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          ...GlobalUbuntuLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _FakeAuthRepository implements AuthRepository {
  final removalCalls = <_AccountRemovalCall>[];
  AccountRemovalResult removalResult = const AccountRemovalResult(
    authorizationRevocationStatus:
        AccountAuthorizationRevocationStatus.notRequested,
  );
  Completer<AccountRemovalResult>? removalCompleter;
  Object? removeError;

  @override
  Future<AccountRemovalResult> removeAccount({
    required String accountId,
    bool revokeAuthorization = false,
  }) async {
    removalCalls.add(
      _AccountRemovalCall(accountId, revokeAuthorization: revokeAuthorization),
    );
    final error = removeError;
    if (error != null) {
      throw error;
    }
    final completer = removalCompleter;
    return completer == null ? removalResult : completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AccountRemovalCall {
  const _AccountRemovalCall(
    this.accountId, {
    required this.revokeAuthorization,
  });

  final String accountId;
  final bool revokeAuthorization;

  @override
  bool operator ==(Object other) {
    return other is _AccountRemovalCall &&
        other.accountId == accountId &&
        other.revokeAuthorization == revokeAuthorization;
  }

  @override
  int get hashCode => Object.hash(accountId, revokeAuthorization);
}

class _FakeAccountsRepository implements AccountsRepository {
  const _FakeAccountsRepository(this.accounts);

  final List<AccountEntity> accounts;

  @override
  Future<List<AccountEntity>> listVisibleAccounts() async => accounts;

  @override
  Future<List<AccountEntity>> listSignedInAccounts() async => accounts;

  @override
  Future<List<AccountEntity>> listSyncEligibleAccounts() async =>
      accounts.where((account) => account.isSyncEligible).toList();

  @override
  Future<AccountEntity?> accountById(String accountId) async {
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MutableEligibilityAccountsRepository
    implements AccountsRepository {
  _MutableEligibilityAccountsRepository(this.canonicalAccounts);

  List<AccountEntity> canonicalAccounts;

  @override
  Future<List<AccountEntity>> listSyncEligibleAccounts() async =>
      canonicalAccounts.where((account) => account.isSyncEligible).toList();

  @override
  Future<AccountEntity?> accountById(String accountId) async {
    for (final account in canonicalAccounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SettingsWebCalTransport implements WebCalHttpTransport {
  final requests = <Uri>[];

  @override
  Future<WebCalHttpResponse> get(
    Uri uri, {
    WebCalHttpValidators validators = const WebCalHttpValidators(),
    Uri? validatorTarget,
  }) async {
    requests.add(uri);
    return WebCalHttpResponse(
      statusCode: 200,
      finalUri: uri,
      body: Uint8List.fromList(
        utf8.encode('''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:settings-subscription-event\r
DTSTART:20260920T160000Z\r
DTEND:20260920T170000Z\r
SUMMARY:Team event\r
END:VEVENT\r
END:VCALENDAR\r
'''),
      ),
      etag: '"settings-test"',
      lastModified: null,
      contentType: 'text/calendar; charset=utf-8',
      conditionalRequestSent: false,
    );
  }
}

class _MemorySettingsStore implements LocalSettingsStore {
  Map<String, Object?> value = {};

  @override
  Future<Map<String, Object?>> load() async => value;

  @override
  Future<void> save(Map<String, Object?> json) async {
    value = json;
  }
}

const _googleAccount = AccountEntity(
  id: 'google:g',
  provider: BusyProvider.google,
  authority: 'https://accounts.google.com',
  providerAccountId: 'g',
  displayName: 'Google User',
  email: 'google@example.com',
  authState: 'signed_in',
);

const _microsoftAccount = AccountEntity(
  id: 'microsoft:m',
  provider: BusyProvider.microsoft,
  authority: 'https://login.microsoftonline.com/common',
  providerAccountId: 'm',
  displayName: 'Microsoft User',
  email: 'microsoft@example.com',
  authState: 'signed_in',
);

const _nextcloudAccount = AccountEntity(
  id: 'nextcloud:n',
  provider: BusyProvider.nextcloud,
  authority: 'https://cloud.example.test',
  providerAccountId: 'alex',
  credentialKind: CredentialKind.nextcloudAppPassword,
  displayName: 'Nextcloud User',
  authState: accountAuthStateSignedIn,
);

const _reconnectRequiredNextcloudAccount = AccountEntity(
  id: 'nextcloud:n',
  provider: BusyProvider.nextcloud,
  authority: 'https://cloud.example.test',
  providerAccountId: 'alex',
  credentialKind: CredentialKind.nextcloudAppPassword,
  displayName: 'Nextcloud User',
  authState: accountAuthStateReauthRequired,
);

DavCollectionSettingsEntity _davCollection({
  required String id,
  required String name,
  bool supportsEvents = false,
  bool supportsTasks = false,
  bool eventsSelected = true,
  bool tasksSelected = true,
  bool readOnly = false,
  bool shared = false,
  DateTime? lastSyncAtUtc,
  String? syncErrorCode,
  String? color,
}) {
  return DavCollectionSettingsEntity(
    id: id,
    accountId: _nextcloudAccount.id,
    provider: BusyProvider.nextcloud,
    accountLabel: _nextcloudAccount.displayName!,
    accountAuthority: _nextcloudAccount.authority,
    connectionState: AccountConnectionState.connected,
    name: name,
    color: color,
    readOnly: readOnly,
    shared: shared,
    supportsEvents: supportsEvents,
    supportsTasks: supportsTasks,
    eventsSelected: eventsSelected,
    tasksSelected: tasksSelected,
    lastSyncAtUtc: lastSyncAtUtc,
    syncErrorCode: syncErrorCode,
    capabilities: CollectionCapabilities(
      canRead: true,
      canWriteContent: !readOnly,
      supportsEvents: supportsEvents,
      supportsTasks: supportsTasks,
    ),
  );
}

const _reconnectRequiredGoogleAccount = AccountEntity(
  id: 'google:g',
  provider: BusyProvider.google,
  authority: 'https://accounts.google.com',
  providerAccountId: 'g',
  displayName: 'Google User',
  email: 'google@example.com',
  authState: accountAuthStateReauthRequired,
);

const _emptyBuildConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  microsoftOAuthClientId: '',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

const _configuredBuildConfig = BuildConfig(
  googleOAuthClientId: 'google-client',
  googleOAuthClientSecret: '',
  microsoftOAuthClientId: 'microsoft-client',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

/// Observation only: all preparation, validation, and persistence run in the
/// real repository/service composition. This gives widget tests a barrier for
/// completion rather than relying on rendering pumps to finish database I/O.
class _ObservedAuthRepository extends AuthRepository {
  _ObservedAuthRepository(Harness h)
    : super(
        oAuth: h.google,
        microsoftOAuth: h.microsoft,
        database: h.db,
        authorizationPersistence: h.persistence,
      );
  Future<void>? finished;
  AuthorizationRequest? lastRequest;
  Completer<void> started = Completer<void>();
  @override
  Future<AuthSessionState> signIn({AuthorizationRequest? request}) {
    lastRequest = request;
    if (!started.isCompleted) started.complete();
    final operation = super.signIn(request: request);
    finished = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<AuthSessionState> signInWithMicrosoft({
    AuthorizationRequest? request,
  }) {
    lastRequest = request;
    if (!started.isCompleted) started.complete();
    final operation = super.signInWithMicrosoft(request: request);
    finished = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

void registerSettingsAuthorizationCancellationRegressions() {
  for (final shared in [false, true]) {
    for (final dispose in [false, true]) {
      for (final pause in ['binding', 'browser', 'exchange', 'identity']) {
        testWidgets(
          'real Settings ${dispose ? 'disposal' : 'Cancel control'} owns OAuth $pause shared=$shared',
          (tester) async {
            // The production database/transport futures run in the real I/O zone.
            // Rendering pumps cannot be used as a substitute for their barriers.
            await tester.runAsync(() async {
              final h = Harness(buildConfig: syntheticDesktopConfig());
              addTearDown(() async {
                h.staging.dispose();
                await h.db.close();
              });
              await h.seed();
              if (!shared) await h.makeGoogleUserOwned();
              final before = (await h.secrets.readCredential('opaque'))!
                  .toJson();
              final observing = _ObservedAuthRepository(h);
              final container = _container(
                selectedAccountId: 'opaque',
                authRepository: observing,
                accounts: await h.accounts.listVisibleAccounts(),
                accountsRepository: h.accounts,
                buildConfig: _configuredBuildConfig,
                productionHarness: h,
                signedInSyncRunner: (_, _) async {},
              );
              addTearDown(container.dispose);
              await _pumpSettings(
                tester,
                container,
                logicalSize: const Size(1200, 1200),
              );
              final summaries = await container.read(
                registrationSummariesProvider.future,
              );
              await tester.pump();
              expect(summaries['opaque']!.showRetirementNotice, shared);
              final entered = Completer<void>(), release = Completer<void>();
              Future<void>? holding;
              if (pause == 'binding') {
                holding = h.persistence.run('opaque', () async {
                  entered.complete();
                  await release.future;
                });
                await entered.future;
              } else if (pause == 'browser') {
                h.flow.barrier = release;
              } else {
                h.beforeRequest = (request) async {
                  if ((pause == 'exchange' && request.method == 'POST') ||
                      (pause == 'identity' && request.method == 'GET')) {
                    if (!entered.isCompleted) entered.complete();
                    await release.future;
                  }
                  return null;
                };
              }
              await _startStoredGoogleReconnect(
                tester,
                observing,
                replacement: shared,
              );
              if (pause == 'browser') {
                await h.flow.started.future;
              } else if (pause != 'binding') {
                await entered.future;
              }
              await tester.pump();
              if (dispose) {
                await tester.pumpWidget(const SizedBox());
              } else {
                final cancel = find.text('Cancel connection');
                await tester.ensureVisible(cancel);
                await tester.tap(cancel);
                await tester.pump();
              }
              release.complete();
              await holding;
              await observing.finished;
              await tester.pumpAndSettle();
              expect(
                (await h.secrets.readCredential('opaque'))!.toJson(),
                before,
              );
              expect((await h.summary('opaque')).showRetirementNotice, shared);
              if (pause == 'binding') expect(h.flow.clients, isEmpty);
              if (dispose) {
                await _pumpSettings(
                  tester,
                  container,
                  logicalSize: const Size(1200, 1200),
                );
              }
              h.beforeRequest = null;
              h.flow.barrier = null;
              await _startStoredGoogleReconnect(
                tester,
                observing,
                replacement: shared,
              );
              await observing.finished;
              await tester.pumpAndSettle();
              expect(
                (await h.secrets.readCredential(
                  'opaque',
                ) as GoogleDesktopCredential).tokenSet.accessToken,
                'candidate-access',
              );
              expect((await h.summary('opaque')).showRetirementNotice, false);
              await tester.pumpWidget(const SizedBox());
            });
          },
        );
      }
    }
  }
}

Future<void> _startStoredGoogleReconnect(
  WidgetTester tester,
  _ObservedAuthRepository observing, {
  required bool replacement,
}) async {
  observing.started = Completer<void>();
  if (replacement) {
    final advanced = find.byKey(const ValueKey('account-advanced-opaque'));
    await tester.ensureVisible(advanced);
    final fade = tester.widget<AnimatedCrossFade>(
      find
          .descendant(of: advanced, matching: find.byType(AnimatedCrossFade))
          .first,
    );
    if (fade.crossFadeState == CrossFadeState.showSecond) {
      await tester.tap(
        find.descendant(of: advanced, matching: find.text('Advanced')),
      );
      await tester.pumpAndSettle();
    }
  }
  final action = replacement
      ? find.text('Migrate now')
      : find.byKey(const ValueKey('reconnect-account-opaque'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  if (replacement) {
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('registration-reconnect-account')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('registration-busymax')));
    // Start the reverse animation before advancing its frame timestamp.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pump();
  await observing.started.future.timeout(const Duration(seconds: 3));
  await tester.pump();
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/storage/dav_settings_repository.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/demo/demo_profile.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/calendar_colors.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yaru/yaru.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

import '../test/support/contacts_fixture.dart';
import '../test/support/dav_contacts_fixture.dart' as carddav;
import '../test/support/desktop_registration_config.dart';

// Explicit opt-in. Every account, provider response, secret and database below
// is synthetic; the owner's profile, keyring and providers are never opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
  testWidgets(
    'native Accounts supports multiple identities, themes, narrow windows, keyboard and safe confirmation',
    (tester) async {
      expect(Platform.environment['XDG_DATA_HOME'], '$output/data');
      final semantics = tester.ensureSemantics();
      await tester.runAsync(YaruWindowTitleBar.ensureInitialized);
      final f = ContactsFixture(AppDatabase.memoryForTests(), realDav: true);
      final davContacts = carddav.DavFixture();
      f.respondDav = davContacts.respond;
      final secrets = InMemorySecretStore();
      final icons = GtkHeaderIconService();
      await tester.runAsync(icons.initialize);
      final windowPreferences = await tester.runAsync(
        () => const GtkWindowPreferencesService().load(),
      );
      await tester.runAsync(() async {
        for (final provider in [
          BusyProvider.google,
          BusyProvider.microsoft,
          BusyProvider.nextcloud,
        ]) {
          for (var number = 1; number <= 2; number++) {
            final id = '${provider.name}:qa-$number';
            await f.accounts.upsertSignedInAccount(
              id: id,
              provider: provider,
              authority: provider == BusyProvider.nextcloud
                  ? 'https://cloud$number.example.test/team'
                  : null,
              providerAccountId: provider == BusyProvider.nextcloud
                  ? 'qa-user'
                  : 'qa-$number',
              displayName:
                  'Quality Assurance $number — a deliberately long synthetic account identity',
              email: provider == BusyProvider.nextcloud
                  ? null
                  : 'qa-$number@example.test',
              grantedScopes: '',
            );
            if (provider != BusyProvider.nextcloud) {
              await f.database.customStatement(
                'INSERT INTO domain_sync_schedules(account_id,domain,last_successful_pull_utc) VALUES (?, ?, ?)',
                [id, 'tasks', '2026-10-19T12:00:00Z'],
              );
            }
            if (provider == BusyProvider.nextcloud) {
              await secrets.saveCredential(
                id,
                NextcloudSecretRecord(
                  canonicalServer: Uri.parse(
                    'https://cloud$number.example.test/team',
                  ),
                  loginName: 'qa-user',
                  appPassword: 'synthetic-only',
                ),
              );
              await f.database
                  .into(f.database.davAccountServices)
                  .insert(
                    DavAccountServicesCompanion.insert(
                      accountId: id,
                      canonicalServiceUri:
                          'https://cloud$number.example.test/team/remote.php/dav/',
                      canonicalOrigin: 'https://cloud$number.example.test',
                      discoveredAtUtc: '2026-10-19T12:00:00Z',
                    ),
                  );
              if (number == 1) {
                for (final mask in [1, 2]) {
                  await f.database
                      .into(f.database.davCollections)
                      .insert(
                        DavCollectionsCompanion.insert(
                          id: '$id:single-$mask',
                          accountId: id,
                          hrefKey: '/team/single-$mask/',
                          requestUri:
                              'https://cloud$number.example.test/team/single-$mask/',
                          displayName: mask == 1
                              ? 'Personal appointments'
                              : 'Personal tasks',
                          resourceTypesJson: const Value(
                            '["{DAV:}collection","{urn:ietf:params:xml:ns:caldav}calendar"]',
                          ),
                          supportedComponentMask: Value(mask),
                          eventProjectionEnabled: Value(mask == 1),
                          taskProjectionEnabled: Value(mask == 2),
                          currentUserPrivilegesJson: const Value(
                            '["{DAV:}read","{DAV:}write-properties"]',
                          ),
                          createdAtUtc: '2026-10-19T12:00:00Z',
                          updatedAtUtc: '2026-10-19T12:00:00Z',
                        ),
                      );
                }
              }
              await f.database
                  .into(f.database.davCollections)
                  .insert(
                    DavCollectionsCompanion.insert(
                      id: '$id:collection',
                      accountId: id,
                      hrefKey: '/team/calendar/',
                      requestUri:
                          'https://cloud$number.example.test/team/calendar/',
                      displayName: 'Team events and tasks $number',
                      resourceTypesJson: const Value(
                        '["{DAV:}collection","{urn:ietf:params:xml:ns:caldav}calendar"]',
                      ),
                      supportedComponentMask: const Value(3),
                      eventProjectionEnabled: const Value(true),
                      taskProjectionEnabled: const Value(true),
                      currentUserPrivilegesJson: const Value(
                        '["{DAV:}read","{DAV:}write-properties"]',
                      ),
                      createdAtUtc: '2026-10-19T12:00:00Z',
                      updatedAtUtc: '2026-10-19T12:00:00Z',
                    ),
                  );
            } else {
              await CalendarRepository(database: f.database).upsertSource(
                accountId: id,
                source: CalendarSourceDto(
                  provider: provider,
                  providerCalendarId: provider == BusyProvider.microsoft
                      ? MicrosoftSharedPrimaryCalendarAddress(
                          owner: 'owner-$number@example.test',
                          graphCalendarId: 'qa',
                        ).sourceCalendarId
                      : 'qa-$number',
                  summary: provider == BusyProvider.google
                      ? 'QA calendar $number'
                      : 'Shared primary QA calendar $number',
                  primaryCalendar:
                      provider == BusyProvider.google && number == 1,
                  readOnly: provider == BusyProvider.microsoft,
                  accessRole: provider == BusyProvider.microsoft
                      ? 'unavailable'
                      : 'owner',
                  rawJson: const {'hidden': false},
                ),
              );
              if (provider == BusyProvider.google && number == 2) {
                await CalendarRepository(database: f.database).setSourceColor(
                  CalendarRepository.sourceId(
                    accountId: id,
                    provider: provider,
                    providerCalendarId: 'qa-$number',
                  ),
                  calendarColorChoices(provider).last,
                );
                await CalendarRepository(database: f.database)
                    .setSourceProviderHidden(
                      CalendarRepository.sourceId(
                        accountId: id,
                        provider: provider,
                        providerCalendarId: 'qa-$number',
                      ),
                      true,
                    );
              }
            }
          }
        }
        f.davSecrets['independent-qa'] = jsonEncode({
          'version': 1,
          'server': 'https://contacts.example.test',
          'username': 'independent-qa',
          'password': 'synthetic-only',
          'readOnly': true,
        });
        await f.store.write(
          (tx) => tx.putAccount(
            const ContactAccount(
              id: 'independent-qa',
              provider: ContactProviderKind.carddav,
              displayName: 'Independent QA address book',
              subject: 'independent-qa',
              enabled: false,
              grantedScopes: {'carddav:read'},
            ),
          ),
        );
      });
      final calendar = CalendarRepository(database: f.database);
      final revocations = <http.Request>[];
      final appClient = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(
          request.url.toString(),
          'https://cloud2.example.test/team/ocs/v2.php/core/apppassword',
        );
        revocations.add(request);
        return http.Response('', 204);
      });
      final davSettings = DavSettingsRepository(database: f.database);
      Completer<void>? inventoryGate, syncEntered, syncGate;
      var googleDenied = true;
      final patches = <http.Request>[];
      final googleClient = GoogleCalendarApiClient(
        baseUri: Uri.parse('https://www.googleapis.com'),
        httpClient: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/calendar/v3/users/me/calendarList/qa-2');
          patches.add(request);
          return googleDenied
              ? http.Response('{"error":{"code":403}}', 403)
              : http.Response(
                  jsonEncode({
                    'id': 'qa-2',
                    'summary': 'QA calendar 2',
                    'hidden': jsonDecode(request.body)['hidden'],
                    'backgroundColor': '#9a9cff',
                    'foregroundColor': '#000000',
                    'colorId': '1',
                  }),
                  200,
                );
        }),
      );
      final googleEngine = CalendarSyncEngine(
        database: f.database,
        client: googleClient,
        accountId: 'google:qa-2',
      );
      final googleRecovery = PendingOpResolutionService(
        database: f.database,
        accountId: 'google:qa-2',
        syncTasks: () async =>
            fail('Calendar recovery must not dispatch Tasks'),
        syncCalendar: googleEngine.dispatchPendingWrites,
      );
      late final ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(f.database),
          baseHttpClientProvider.overrideWithValue(appClient),
          gtkHeaderIconServiceProvider.overrideWithValue(icons),
          initialGtkWindowPreferencesProvider.overrideWithValue(
            windowPreferences,
          ),
          secretStoreProvider.overrideWithValue(secrets),
          busyMaxContactsStoreProvider.overrideWithValue(f.store),
          busyMaxContactsControllerProvider.overrideWithValue(f.controller),
          davSettingsRepositoryProvider.overrideWithValue(davSettings),
          davCollectionsStreamProvider.overrideWith((ref) async* {
            await inventoryGate?.future;
            yield* davSettings.watchCollections();
          }),
          pendingOpResolutionServiceForAccountProvider.overrideWith((ref, id) {
            expect(id, 'google:qa-2');
            return googleRecovery;
          }),
          localSettingsStoreProvider.overrideWithValue(
            InMemoryLocalSettingsStore(),
          ),
          buildConfigProvider.overrideWithValue(syntheticDesktopConfig()),
          selectedAccountIdProvider.overrideWith((ref) => 'google:qa-1'),
          signedInSyncRunnerProvider.overrideWithValue((id, _) async {
            await container.read(accountSyncActivityProvider).run(
              id,
              'dav',
              () async {
                syncEntered?.complete();
                await syncGate?.future;
                if (id.startsWith('nextcloud:')) {
                  await f.accounts.setConnectionState(
                    id,
                    AccountConnectionState.connected,
                  );
                  await f.database.customUpdate(
                    'UPDATE dav_account_services SET last_discovery_error_code = NULL WHERE account_id = ?',
                    variables: [Variable(id)],
                    updates: {f.database.davAccountServices},
                  );
                }
              },
            );
          }),
        ],
      );
      final font = await tester.runAsync(
        () => const GtkFontService().getGtkFont(),
      );
      final textScale = ValueNotifier<double>(1);
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.runAsync(
          () => const GtkThemeService().setPreferDark(
            brightness == Brightness.dark,
          ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: const [
                ...AppLocalizations.localizationsDelegates,
                ...GlobalUbuntuLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: BusyMaxYaruTheme.build(
                brightness: brightness,
                accentColor: YaruColors.orange,
                gtkFontFamily: font?.family,
                gtkFontSize: font?.size,
              ),
              builder: (context, child) => ValueListenableBuilder<double>(
                valueListenable: textScale,
                child: GtkHeaderIconScope(
                  service: icons,
                  child: LinuxWindowHost(child: child!),
                ),
                builder: (context, scale, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
              home: const SettingsScreen(initialPage: SettingsPage.accounts),
            ),
          ),
        );
        await _resize(tester, 1200, 1000);
        await tester.pumpAndSettle();
        final theme = brightness.name;
        for (final provider in ['google', 'microsoft', 'nextcloud']) {
          for (final number in [1, 2]) {
            expect(
              find.byKey(ValueKey('account-entry-$provider:qa-$number')),
              findsOneWidget,
            );
          }
        }
        const additions = {
          'Add Google account',
          'Add Microsoft account',
          'Add Nextcloud account',
          'Add Apple iCloud Calendar account',
        };
        for (final label in additions) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Personal appointments'), findsNothing);
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .controller!
            .jumpTo(0);
        await _capture(tester, '$output/$theme-overview.png');
        final origin = find.byKey(
          const ValueKey('account-entry-nextcloud:qa-1'),
        );
        await tester.ensureVisible(origin);
        final originFocus = tester
            .widget<BusyMaxActionRow>(
              find.descendant(
                of: origin,
                matching: find.byType(BusyMaxActionRow),
              ),
            )
            .focusNode!;
        final overviewScroll = tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .controller!;
        final originOffset = overviewScroll.offset;
        await tester.tap(origin);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('qa-user · https://cloud1.example.test/team'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remove-account-nextcloud:qa-2')),
          findsNothing,
        );
        await _capture(tester, '$output/$theme-nextcloud-healthy.png');
        await _tap(tester, find.text('Personal appointments'));
        expect(
          (await tester.runAsync(
            () => davSettings.collectionById('nextcloud:qa-1:single-1'),
          ))!.eventsSelected,
          isFalse,
        );
        await _tap(tester, find.text('Team events and tasks 1'));
        expect(
          (await tester.runAsync(
            () => davSettings.collectionById('nextcloud:qa-1:collection'),
          ))!.tasksSelected,
          isTrue,
        );
        await _tap(
          tester,
          find.byKey(
            const ValueKey('dav-tasks-toggle-nextcloud:qa-1:collection'),
          ),
        );
        expect(
          (await tester.runAsync(
            () => davSettings.collectionById('nextcloud:qa-1:collection'),
          ))!.tasksSelected,
          isFalse,
        );
        expect(
          (await tester.runAsync(
            () => davSettings.collectionById('nextcloud:qa-2:collection'),
          ))!.tasksSelected,
          isTrue,
        );
        await _tap(tester, find.text('Team events and tasks 1'));
        await tester.runAsync(() async {
          await davSettings.setEventsSelected('nextcloud:qa-1:single-1', true);
          await davSettings.setTasksSelected('nextcloud:qa-1:collection', true);
        });
        inventoryGate = Completer<void>();
        container.invalidate(davCollectionsStreamProvider);
        await tester.pump();
        await tester.pump();
        expect(find.text('Loading collections…'), findsWidgets);
        await _capture(tester, '$output/$theme-loading.png', settle: false);
        inventoryGate.complete();
        inventoryGate = null;
        await tester.pumpAndSettle();
        await _networkFailure(tester, container, f);
        expect(find.text('Could not reach the service'), findsOneWidget);
        expect(find.textContaining('DavException'), findsNothing);
        expect(find.textContaining('synthetic-correlation'), findsNothing);
        await _capture(tester, '$output/$theme-nextcloud-network-error.png');
        await _resize(tester, 640, 700);
        await _capture(tester, '$output/$theme-narrow.png');
        await _resize(tester, 640, 500);
        await _capture(tester, '$output/$theme-short.png');
        textScale.value = 1.6;
        await tester.pumpAndSettle();
        await _capture(tester, '$output/$theme-enlarged.png');
        textScale.value = 1;
        await tester.pumpAndSettle();
        await _resize(tester, 1200, 1000);
        syncEntered = Completer<void>();
        syncGate = Completer<void>();
        await tester.tap(
          find.byKey(const ValueKey('account-recovery-nextcloud:qa-1')),
        );
        await tester.pump();
        await tester.runAsync(() => syncEntered!.future);
        await _back(tester);
        expect(originFocus.hasFocus, isTrue);
        expect(overviewScroll.offset, closeTo(originOffset, 1));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('account-detail-nextcloud:qa-1')),
          findsOneWidget,
        );
        await _back(tester);
        await _open(tester, 'nextcloud:qa-2');
        syncGate.complete();
        await tester.pumpAndSettle();
        syncGate = syncEntered = null;
        expect(
          find.byKey(const ValueKey('account-detail-nextcloud:qa-2')),
          findsOneWidget,
        );
        final secondCollection = (await tester.runAsync(
          () =>
              (f.database.select(f.database.davCollections)
                    ..where((r) => r.id.equals('nextcloud:qa-2:collection')))
                  .getSingle(),
        ))!;
        await tester.runAsync(
          () => (f.database.delete(
            f.database.davCollections,
          )..where((r) => r.id.equals(secondCollection.id))).go(),
        );
        await tester.pumpAndSettle();
        expect(find.text('No collections found.'), findsOneWidget);
        await tester.runAsync(() async {
          await f.database
              .into(f.database.davCollections)
              .insert(secondCollection);
          await f.accounts.setConnectionState(
            'nextcloud:qa-2',
            AccountConnectionState.reauthenticationRequired,
          );
        });
        await tester.pumpAndSettle();
        await _tap(
          tester,
          find.byKey(const ValueKey('account-recovery-nextcloud:qa-2')),
        );
        await _tap(tester, find.text('Cancel').last);
        await tester.runAsync(
          () => f.accounts.setConnectionState(
            'nextcloud:qa-2',
            AccountConnectionState.connected,
          ),
        );
        await tester.pumpAndSettle();
        await _back(tester);

        await _open(tester, 'google:qa-2');
        final sourceId = CalendarRepository.sourceId(
          accountId: 'google:qa-2',
          provider: BusyProvider.google,
          providerCalendarId: 'qa-2',
        );
        await tester.runAsync(() async {
          await calendar.setSourceColor(
            sourceId,
            calendarColorChoices(BusyProvider.google).last,
          );
          await calendar.setSourceProviderHidden(sourceId, true);
        });
        await tester.pumpAndSettle();
        expect(find.text('Google visibility change pending'), findsOneWidget);
        await _tap(tester, find.text('QA calendar 2'));
        googleDenied = true;
        await tester.runAsync(googleEngine.dispatchPendingWrites);
        await tester.pumpAndSettle();
        final retry = find.byKey(
          ValueKey('settings-calendar-visibility-retry-$sourceId'),
        );
        final discard = find.byKey(
          ValueKey('settings-calendar-visibility-discard-$sourceId'),
        );
        expect(tester.getSemantics(retry).label, contains('QA calendar 2'));
        await _capture(tester, '$output/$theme-google-visibility-recovery.png');
        await _tap(tester, discard);
        expect(
          find.textContaining(
            '• Calendar color\n• Show in Google’s calendar list',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Google Tasks'), findsNothing);
        await _capture(tester, '$output/$theme-google-discard.png');
        await _tap(tester, find.text('Cancel').last);
        googleDenied = false;
        final beforeRetry = patches.length;
        await _tap(tester, retry);
        await _waitForCalendarQueue(tester, f.database);
        expect(patches.length, beforeRetry + 1);
        expect(
          (await tester.runAsync(
            () => f.database.select(f.database.pendingOps).get(),
          ))!,
          isEmpty,
        );
        await tester.runAsync(() async {
          await calendar.setSourceProviderHidden(sourceId, false);
          await googleEngine.dispatchPendingWrites();
          await calendar.setSourceColor(
            sourceId,
            calendarColorChoices(BusyProvider.google).first,
          );
          await calendar.setSourceProviderHidden(sourceId, true);
          googleDenied = true;
          await googleEngine.dispatchPendingWrites();
        });
        await tester.pumpAndSettle();
        await _tap(tester, discard);
        await _tap(tester, find.text('Discard').last);
        await _waitForCalendarQueue(tester, f.database);
        expect(
          (await tester.runAsync(
            () => f.database.select(f.database.pendingOps).get(),
          ))!,
          isEmpty,
        );
        final local = find.byKey(
          ValueKey('settings-calendar-schedule-$sourceId'),
        );
        expect(tester.widget<YaruSwitch>(local).onChanged, isNotNull);
        await _tap(tester, local);
        expect(
          (await tester.runAsync(
            () => calendar.watchSourcesForAccounts(['google:qa-2']).first,
          ))!.single.selected,
          isFalse,
        );
        await tester.runAsync(() => calendar.setSourceSelected(sourceId, true));
        await _back(tester);

        await _open(tester, 'google:qa-1');
        await _tap(tester, find.text('QA calendar 1'));
        final primaryId = CalendarRepository.sourceId(
          accountId: 'google:qa-1',
          provider: BusyProvider.google,
          providerCalendarId: 'qa-1',
        );
        expect(
          tester
              .widget<YaruSwitch>(
                find.byKey(ValueKey('settings-calendar-provider-$primaryId')),
              )
              .onChanged,
          isNull,
        );
        expect(
          find.text('Google’s primary calendar stays in its calendar list.'),
          findsOneWidget,
        );
        if (brightness == Brightness.light) {
          f.consentSubject = 'qa-1';
          await tester.runAsync(
            () => f.controller.enableLinkedContacts('google:qa-1'),
          );
          await tester.runAsync(
            () => f.controller.synchronizeAccount('contacts:google:qa-1'),
          );
          await tester.pumpAndSettle();
        }
        final source = (await tester.runAsync(f.controller.sourceSettings))!
            .firstWhere((s) => s.source.accountId == 'contacts:google:qa-1');
        final sourceSwitch = find.byKey(
          ValueKey('contact-source-${source.source.key}'),
        );
        await _tap(tester, sourceSwitch);
        expect(
          (await tester.runAsync(f.controller.sourceSettings))!
              .firstWhere((s) => s.source.key == source.source.key)
              .enabled,
          isFalse,
        );
        await _tap(tester, sourceSwitch);
        await _expand(
          tester,
          find.byKey(const ValueKey('account-advanced-google:qa-1')),
        );
        await _capture(tester, '$output/$theme-google-advanced.png');
        await _back(tester);

        await _open(tester, 'microsoft:qa-1');
        await tester.runAsync(() async {
          await f.accounts.setConnectionState(
            'microsoft:qa-1',
            AccountConnectionState.temporarilyUnavailable,
          );
          try {
            await container.read(accountSyncActivityProvider).run(
              'microsoft:qa-1',
              'calendar',
              () async {
                throw const DavException(
                  kind: DavErrorKind.network,
                  code: 'DavNetworkFailure',
                  safeMessage: 'Synthetic diagnostic',
                );
              },
            );
          } on DavException {
            /* Calendar failed independently of Tasks. */
          }
          await container
              .read(accountSyncActivityProvider)
              .run('microsoft:qa-1', 'tasks', () async {});
        });
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey('account-domain-feedback-calendar-microsoft:qa-1'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('account-domain-feedback-tasks-microsoft:qa-1'),
          ),
          findsNothing,
        );
        expect(
          find.textContaining('Access unavailable; showing cached data.'),
          findsWidgets,
        );
        await _capture(tester, '$output/$theme-microsoft-unavailable.png');
        // Opening a new shared calendar retains the existing connection-state
        // eligibility rule. Keep the failed Calendar outcome visible while
        // restoring the synthetic account's connection for this dialog check.
        await tester.runAsync(
          () => f.accounts.setConnectionState(
            'microsoft:qa-1',
            AccountConnectionState.connected,
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Open shared primary calendar'));
        expect(
          find.textContaining('Opens the specified owner’s primary calendar.'),
          findsOneWidget,
        );
        await _tap(tester, find.text('Cancel').last);
        await _back(tester);

        await _tap(
          tester,
          find.byKey(const ValueKey('contact-account-entry-independent-qa')),
        );
        expect(find.text('https://contacts.example.test'), findsOneWidget);
        if (brightness == Brightness.light) {
          final contactReady = Completer<void>();
          final subscription = f.controller.changes.listen((_) async {
            final sources = await f.controller.sourceSettings();
            if (!contactReady.isCompleted &&
                sources.any((s) => s.source.accountId == 'independent-qa') &&
                f.davSecrets['independent-qa']!.contains(
                  'synthetic-replacement-only',
                )) {
              contactReady.complete();
            }
          });
          await _tap(
            tester,
            find.byKey(
              const ValueKey('contact-account-recovery-independent-qa'),
            ),
          );
          await tester.enterText(
            find.byType(TextField).last,
            'synthetic-replacement-only',
          );
          await tester.pumpAndSettle();
          final reconnectButton = find.descendant(
            of: find.byType(BusyMaxPromptDialog),
            matching: find.widgetWithText(
              ElevatedButton,
              'Reconnect this account',
            ),
          );
          expect(
            tester.widget<ElevatedButton>(reconnectButton).onPressed,
            isNotNull,
          );
          await _tap(tester, reconnectButton);
          expect(find.byType(BusyMaxPromptDialog), findsNothing);
          await tester.runAsync(
            () => contactReady.future.timeout(const Duration(seconds: 10)),
          );
          await subscription.cancel();
          await tester.runAsync(
            () => f.controller.synchronizeAccount('independent-qa'),
          );
          await tester.pumpAndSettle();
          expect(
            f.davSecrets['independent-qa'],
            contains('synthetic-replacement-only'),
          );
          expect(davContacts.requests, isNotEmpty);
          expect(
            davContacts.requests.where(
              (r) => ['PUT', 'DELETE', 'PROPPATCH'].contains(r.method),
            ),
            isEmpty,
          );
        }
        await _capture(tester, '$output/$theme-independent-contacts.png');
        await _back(tester);
        await _open(tester, 'nextcloud:qa-2');
        await tester.runAsync(
          () => f.database.customStatement(
            "CREATE TEMP TRIGGER reject_qa_removal BEFORE DELETE ON accounts WHEN OLD.id = 'nextcloud:qa-2' BEGIN SELECT RAISE(ABORT, 'synthetic deletion failure'); END",
          ),
        );
        await _tap(
          tester,
          find.byKey(const ValueKey('remove-account-nextcloud:qa-2')),
        );
        await _capture(tester, '$output/$theme-remove-confirmation.png');
        await _tap(tester, find.byKey(const Key('confirm-account-removal')));
        await tester.runAsync(() async {
          // Join the service's guarded removal while local deletion is blocked
          // by the fixture trigger, then wait for restoration to finish.
          await expectLater(
            container
                .read(davAccountOnboardingServiceProvider)
                .removeAccount('nextcloud:qa-2'),
            throwsA(isNotNull),
          );
        });
        await tester.pumpAndSettle();
        expect(
          find.text('Could not finish removing the account. Try again.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('account-detail-nextcloud:qa-2')),
          findsOneWidget,
        );
        expect(
          await tester.runAsync(() => f.accounts.accountById('nextcloud:qa-2')),
          isNotNull,
        );
        expect(
          await tester.runAsync(() => secrets.readCredential('nextcloud:qa-2')),
          isNotNull,
        );
        await tester.runAsync(
          () => f.database.customStatement('DROP TRIGGER reject_qa_removal'),
        );
        await _back(tester);
        await tester.ensureVisible(find.text('Add Nextcloud account'));
        Focus.of(tester.element(find.text('Add Nextcloud account')))
            .requestFocus();
        await tester.pumpAndSettle();
        final visited = <String>{'Add Nextcloud account'};
        for (
          var step = 0;
          step < 28 && !visited.containsAll(additions);
          step++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final title = FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<BusyMaxActionRow>()
              ?.title;
          if (title != null) visited.add(title);
        }
        expect(visited, containsAll(additions));
        await _capture(tester, '$output/$theme-keyboard-focus.png');
        expect(tester.takeException(), isNull);
      }
      await _open(tester, 'nextcloud:qa-2');
      await _tap(
        tester,
        find.byKey(const ValueKey('remove-account-nextcloud:qa-2')),
      );
      await _tap(tester, find.byKey(const Key('confirm-account-removal')));
      await tester.runAsync(
        () =>
            (f.database.select(f.database.accounts)
                  ..where((r) => r.id.equals('nextcloud:qa-2')))
                .watch()
                .firstWhere((rows) => rows.isEmpty)
                .timeout(const Duration(seconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-detail-nextcloud:qa-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('account-entry-nextcloud:qa-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('account-entry-nextcloud:qa-1')),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(() => secrets.readCredential('nextcloud:qa-2')),
        isNull,
      );
      expect(
        (await tester.runAsync(f.accounts.listVisibleAccounts))!,
        hasLength(5),
      );
      expect(revocations, hasLength(1));
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        startsWith('account-entry-'),
      );
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        isNot(contains('nextcloud:qa-2')),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
      icons.dispose();
      appClient.close();
      semantics.dispose();
      textScale.dispose();
      await tester.runAsync(f.close);
    },
    skip: output == null,
  );
}

Future<void> _resize(WidgetTester tester, int width, int height) async {
  await tester.runAsync(() async {
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import ctypes, re, subprocess, sys
x = ctypes.CDLL('libX11.so.6')
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XOpenDisplay.restype = ctypes.c_void_p
x.XResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_uint, ctypes.c_uint]
x.XFlush.argtypes = [ctypes.c_void_p]
x.XCloseDisplay.argtypes = [ctypes.c_void_p]
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
windows = re.findall(r'^\s*(0x[0-9a-f]+) "BusyMax":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in windows if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1, 'Expected one BusyMax window on the isolated display'
connection = x.XOpenDisplay(None)
x.XResizeWindow(connection, int(main[0][0], 16), int(sys.argv[1]), int(sys.argv[2]))
x.XFlush(connection)
x.XCloseDisplay(connection)
''',
      '$width',
      '$height',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  String path, {
  bool settle = true,
}) async {
  if (settle) await tester.pumpAndSettle();
  await tester.runAsync(() async {
    // Capture the isolated application window, including its modal overlays.
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import sys, gi, re, subprocess
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
windows = re.findall(r'^\s*(0x[0-9a-f]+) "BusyMax":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in windows if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1, 'Expected one isolated BusyMax application window'
info = subprocess.check_output(['/usr/bin/xwininfo', '-id', main[0][0]], text=True)
def field(name):
    return int(re.search(name + r':\s*(-?\d+)', info).group(1))
window = Gdk.get_default_root_window()
pixbuf = Gdk.pixbuf_get_from_window(window, field('Absolute upper-left X'), field('Absolute upper-left Y'), field('Width'), field('Height'))
pixbuf.savev(sys.argv[1], 'png', [], [])
''',
      path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _waitForCalendarQueue(
  WidgetTester tester,
  AppDatabase database,
) async {
  await tester.runAsync(
    () => database
        .select(database.pendingOps)
        .watch()
        .firstWhere((rows) => rows.isEmpty)
        .timeout(const Duration(seconds: 10)),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String id) =>
    _tap(tester, find.byKey(ValueKey('account-entry-$id')));

Future<void> _back(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('settings-header-back-button')));

Future<void> _expand(WidgetTester tester, Finder target) => _tap(
  tester,
  find.descendant(of: target, matching: find.text('Advanced')).first,
);

Future<void> _networkFailure(
  WidgetTester tester,
  ProviderContainer container,
  ContactsFixture f,
) async {
  await tester.runAsync(() async {
    try {
      await container.read(accountSyncActivityProvider).run(
        'nextcloud:qa-1',
        'dav',
        () async {
          throw const DavException(
            kind: DavErrorKind.network,
            code: 'DavNetworkFailure',
            safeMessage: 'Synthetic private diagnostic',
            correlationId: 'synthetic-correlation',
          );
        },
      );
    } on DavException {
      /* The activity store retains the typed failure. */
    }
    await f.accounts.setConnectionState(
      'nextcloud:qa-1',
      AccountConnectionState.temporarilyUnavailable,
    );
    await f.database.customUpdate(
      "UPDATE dav_account_services SET last_discovery_error_code = 'DavNetworkFailure' WHERE account_id = 'nextcloud:qa-1'",
      updates: {f.database.davAccountServices},
    );
  });
  await tester.pumpAndSettle();
}

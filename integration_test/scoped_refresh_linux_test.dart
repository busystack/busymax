import 'dart:async';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/services.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yaru/yaru.dart';

import '../test/support/memory_settings_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native Linux schedule scopes refresh and retains coverage geometry',
    (tester) async {
      // Flutter test gestures cannot operate an OS-level menu grab. The
      // window, GTK icons, Dart action and provider path still run natively.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(nativeMenuChannelName),
        (_) async => throw MissingPluginException(),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(nativeMenuChannelName),
          null,
        ),
      );
      final root = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
      expect(root, isNotNull);
      expect(Platform.environment['XDG_DATA_HOME'], '$root/data');
      final db = AppDatabase.memoryForTests();
      final repository = CalendarRepository(database: db);
      final icons = GtkHeaderIconService();
      final started = Completer<void>();
      final release = Completer<void>();
      final requests = <String>[];
      var rejected = false;
      var coverageAvailable = false;
      final coverageAttempts = <Object>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        expect(request.url.path, contains('/calendars/a/events'));
        if (!started.isCompleted) {
          started.complete();
          await release.future;
        }
        if (rejected) {
          return http.Response(
            '{"error":{"message":"synthetic private body"}}',
            403,
          );
        }
        return http.Response('{"items":[],"nextSyncToken":"synthetic"}', 200);
      });
      final settings = AppSettings.defaults().copyWith(
        scheduleViewMode: ScheduleViewMode.day,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialAppSettingsProvider.overrideWithValue(settings),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          notificationReconcilerProvider.overrideWithValue(
            CallbackNotificationReconciler(() async {}),
          ),
          googleCalendarApiClientForAccountProvider('one').overrideWithValue(
            GoogleCalendarApiClient(
              httpClient: client,
              baseUri: Uri.parse('https://calendar.example.test/calendar/v3'),
            ),
          ),
          networkConnectivityMonitorProvider.overrideWith((ref) {
            final monitor =
                NetworkConnectivityMonitor.withoutPlatformObservation();
            ref.onDispose(monitor.dispose);
            return monitor;
          }),
          scheduleRepositoryProvider.overrideWithValue(
            ScheduleRepository(
              db,
              ensureCloudCoverage: (range, filters) async {
                coverageAttempts.add((
                  range.start,
                  range.end,
                  filters.sourceIds,
                ));
                return coverageAvailable;
              },
            ),
          ),
        ],
      );
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        client.close();
        icons.dispose();
        await db.close();
      });
      await tester.runAsync(() async {
        await YaruWindowTitleBar.ensureInitialized();
        await icons.initialize();
        final accounts = container.read(accountsRepositoryProvider);
        for (final account in ['one', 'two']) {
          await accounts.upsertSignedInAccount(
            id: account,
            provider: BusyProvider.google,
            providerAccountId: account,
            displayName: 'Synthetic $account',
            grantedScopes: 'calendar tasks',
          );
        }
        for (final (account, id) in [
          ('one', 'a'),
          ('one', 'b'),
          ('two', 'a'),
        ]) {
          await repository.upsertSource(
            accountId: account,
            source: CalendarSourceDto(
              provider: BusyProvider.google,
              providerCalendarId: id,
              summary: '$account / $id',
              backgroundColor: '#345678',
            ),
          );
        }
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: GtkHeaderIconScope(
            service: icons,
            child: MaterialApp(
              locale: const Locale('en'),
              theme: BusyMaxYaruTheme.build(
                brightness: Brightness.light,
                accentColor: YaruColors.orange,
              ),
              builder: (context, child) => LinuxWindowHost(child: child!),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ScheduleWorkspace(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sourceId = CalendarRepository.sourceId(
        accountId: 'one',
        provider: BusyProvider.google,
        providerCalendarId: 'a',
      );
      final row = find.byKey(ValueKey(('schedule-calendar', 'one', sourceId)));
      final options = find.byKey(ValueKey(('calendar-options', sourceId)));
      final original = tester.getRect(row);
      final status = find.byKey(const ValueKey('schedule-coverage-status'));
      final statusBounds = tester.getRect(status);
      final scope = calendarSyncScope('one', sourceId);

      Future<void> refresh() async {
        await tester.tap(options);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Refresh calendar').last);
        await tester.pump();
      }

      await refresh();
      await started.future.timeout(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        container.read(accountSyncActivityProvider).executing(scope),
        isTrue,
      );
      expect(tester.getRect(row), original);
      release.complete();
      await tester.pumpAndSettle();
      expect(container.read(accountSyncActivityProvider).busy(scope), isFalse);
      expect(find.byType(SnackBar), findsNothing);
      expect(requests, hasLength(1));

      rejected = true;
      await refresh();
      await tester.pumpAndSettle();
      expect(
        container.read(accountSyncActivityProvider).outcome(scope)?.error,
        isNotNull,
      );
      expect(find.textContaining('synthetic private body'), findsNothing);
      await refresh();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final previous = coverageAttempts.length;
      coverageAvailable = true;
      await tester.tap(status);
      await tester.pumpAndSettle();
      expect(
        find.text('Some events could not be checked. Showing downloaded data.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(coverageAttempts.length, greaterThan(previous));
      expect(tester.getRect(status), statusBounds);
      expect(tester.getRect(row), original);
    },
  );
}

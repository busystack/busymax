import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_nextcloud_scheduling_screen.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/android/presentation/android_availability_dialog.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_policy.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_federation_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_sharing_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/dav/presentation/nextcloud_collection_dialog.dart';
import 'package:busymax/src/dav/presentation/nextcloud_scheduling_dialog.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_dialogs.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_scheduling_dialog.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/dav/support/nextcloud_extended_fixture.dart';
import '../test/support/memory_settings_store.dart';

/// Real native controls, production discovery/queue/sync and HTTPS Nextcloud.
/// The define contains only disposable QA credentials and public certificates.
/// No normal profile, OS trust store or real person's address is used.
void main() {
  const encoded = String.fromEnvironment('BUSYMAX_NEXTCLOUD_UI_FIXTURE');
  final resultFile = Platform.environment['BUSYMAX_NEXTCLOUD_UI_RESULT_FILE'];
  if (resultFile != null) {
    File(resultFile).writeAsStringSync(
      jsonEncode({'state': 'starting', 'configured': encoded.isNotEmpty}),
    );
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String, String>{};
  var currentStage = 'starting';
  final previousReporter = reportTestException;
  reportTestException = (details, description) {
    errors[description] = '$currentStage: ${details.exceptionAsString()}';
    previousReporter(details, description);
  };
  void stage(String name) {
    currentStage = name;
    if (resultFile != null) {
      File(resultFile).writeAsStringSync(
        jsonEncode({'state': name, 'configured': encoded.isNotEmpty}),
      );
    }
  }

  unawaited(
    binding.allTestsPassed.future.then((passed) async {
      final success =
          passed && encoded.isNotEmpty && binding.results.length >= 4;
      if (resultFile != null) {
        await File(resultFile).writeAsString(
          jsonEncode({
            'passed': success,
            'configured': encoded.isNotEmpty,
            'platform': Platform.operatingSystem,
            'tests': binding.results.keys.toList(),
            'failures': [
              for (final failure in binding.failureMethodsDetails)
                {
                  'test': failure.methodName,
                  'details': errors[failure.methodName] ?? failure.details,
                },
            ],
          }),
        );
      }
      debugPrint(
        'BUSYMAX_NEXTCLOUD_UI_RESULT ${success ? 'PASS' : 'FAIL'} ${Platform.operatingSystem}',
      );
      if (!Platform.isAndroid) await stdout.flush();
      if (Platform.isLinux || Platform.isWindows) exit(success ? 0 : 1);
    }),
  );
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (encoded.isEmpty) {
    test(
      'requires isolated HTTPS QA accounts',
      () {},
      skip: 'Supply BUSYMAX_NEXTCLOUD_UI_FIXTURE as base64 JSON environment values.',
    );
    return;
  }
  final environment = Map<String, String>.from(
    jsonDecode(utf8.decode(base64Decode(encoded))) as Map,
  );

  testWidgets(
    'native trash restores an original task and confirms permanent deletion',
    (tester) async {
      stage('trash');
      final fixture = (await tester.runAsync(
        () => NextcloudExtendedFixture.open(
          components: const ['VTODO'],
          environment: environment,
        ),
      ))!;
      addTearDown(fixture.close);
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VTODO\r\n'
          'UID:${fixture.uid}\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:${fixture.title}\r\n'
          'STATUS:COMPLETED\r\nPERCENT-COMPLETE:100\r\nX-BUSYMAX-QA:preserve-native\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
      final object = (await tester.runAsync(() => fixture.importRaw(raw)))!;
      final trash = NextcloudTrashService(fixture.collections);
      Future<void> remove() async {
        final response = await (await fixture.collections.openContext()).send(
          'DELETE',
          Uri.parse(object.requestUri),
        );
        expect(response.statusCode, 204);
        await fixture.synchronize();
      }

      await tester.runAsync(remove);
      var item = (await tester.runAsync(
        () => trash.list(includeContent: true),
      ))!.items.singleWhere((i) => i.title == fixture.title);
      await _open(tester, fixture, 'trash');
      await _trashAction(tester, item, permanent: false);
      await _until(tester, () => _trashAbsent(trash, item.href));
      await tester.runAsync(() async {
        final response = await (await fixture.collections.openContext()).send(
          'GET',
          Uri.parse(object.requestUri),
        );
        expect(response.statusCode, 200);
        expect(response.bodyText, contains(fixture.uid));
        expect(response.bodyText, contains('PERCENT-COMPLETE:100'));
        expect(response.bodyText, contains('X-BUSYMAX-QA:preserve-native'));
      });
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(remove);
      item = (await tester.runAsync(() => trash.list(includeContent: true)))!
          .items
          .singleWhere((i) => i.title == fixture.title);
      await _open(tester, fixture, 'trash');
      await _trashAction(tester, item, permanent: true);
      // Opening the destructive confirmation must not delete anything.
      expect(
        (await tester.runAsync(() => trash.list(includeContent: true)))!.items
            .any((i) => i.href == item.href),
        isTrue,
      );
      await _tap(tester, find.text('Permanently delete').last);
      await _until(tester, () => _trashAbsent(trash, item.href));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'native meeting UI acknowledges, replies, updates and cancels without losing the event',
    (tester) async {
      stage('scheduling');
      // Capture the real text-input client ID. The debug-only client ID -1
      // used by an unregistered TestTextInput is ignored in release builds.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final owner = (await tester.runAsync(
        () => NextcloudExtendedFixture.open(environment: environment),
      ))!;
      addTearDown(owner.close);
      final attendee = (await tester.runAsync(
        () => NextcloudExtendedFixture.open(
          environment: environment,
          username:
              environment['BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_ATTENDEE_USERNAME'] ??
              'attendee',
        ),
      ))!;
      addTearDown(attendee.close);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      final meetingTitle = '${owner.title} meeting';
      await tester.runAsync(() async {
        final organizer = await NextcloudSchedulingPolicy.load(
          owner.database,
          owner.collection,
        );
        final guest = await NextcloudSchedulingPolicy.load(
          attendee.database,
          attendee.collection,
        );
        final raw =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\n'
            'UID:${owner.uid}\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:$meetingTitle\r\n'
            'DTSTART:20261106T180000Z\r\nDTEND:20261106T190000Z\r\n'
            'ORGANIZER:${organizer.organizerAddress}\r\nATTENDEE;PARTSTAT=NEEDS-ACTION:${guest.organizerAddress}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
        await DavPendingOperationQueue(database: owner.database).enqueueCreate(
          accountId: owner.id,
          collectionId: owner.collection.id,
          object: DavNewObject(
            uid: owner.uid,
            initialMemberName: '${owner.id}.ics',
            rawIcs: raw,
            componentType: 'VEVENT',
          ),
        );
        await owner.synchronize();
        await attendee.synchronize();
      });
      final scheduling = NextcloudSchedulingService(attendee.collections);
      final message = (await tester.runAsync(
        () => scheduling.inbox(attendee.collection.id),
      ))!.singleWhere((m) => m.rawIcs.contains(owner.uid));
      final event = (await tester.runAsync(
        () => attendee.meetingObject(owner.uid),
      ))!;
      addTearDown(() async {
        // Also clean up when a UI assertion fails. This is the exact recipient
        // resource created by this test, not a UID-wide deletion.
        await (await attendee.collections.openContext()).send(
          'DELETE',
          Uri.parse(event.requestUri),
          headers: const {
            'X-NC-Scheduling': 'false',
            'X-NC-CalDAV-No-Trashbin': '1',
          },
        );
      });
      await _open(tester, attendee, 'inbox');
      await _tap(
        tester,
        find.byKey(
          ValueKey(('nextcloud-inbox-acknowledge', message.href.toString())),
        ),
      );
      // Confirmation is a distinct user action on every platform.
      await _tap(tester, find.text('Acknowledge message').last);
      await _until(
        tester,
        () async =>
            (await scheduling.inbox(attendee.collection.id))
                .every((m) => m.href != message.href),
      );
      await tester.runAsync(() async {
        expect(
          (await (await attendee.collections.openContext()).send(
            'GET',
            Uri.parse(event.requestUri),
          )).statusCode,
          200,
        );
      });
      await tester.pumpWidget(const SizedBox());
      for (final (label, status) in [
        ('Accept', 'ACCEPTED'),
        ('Tentative', 'TENTATIVE'),
        ('Decline', 'DECLINED'),
      ]) {
        stage('scheduling reply $status');
        await _openSchedule(tester, attendee);
        await _tap(tester, find.text(meetingTitle).last);
        await _tap(tester, find.text(label).last);
        await _until(tester, () async {
          await owner.synchronize();
          final current = IcalSemanticDocument.parse(
            (await owner.meetingObject(owner.uid)).rawIcsBody,
          );
          return current.components.first.documentComponent
                  .propertiesNamed('ATTENDEE')
                  .single
                  .parameterValue('PARTSTAT') ==
              status;
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      stage('scheduling organizer edit');
      await _openSchedule(tester, owner);
      await _tap(tester, find.text(meetingTitle).last);
      await _tap(
        tester,
        Platform.isLinux
            ? find.byTooltip('Edit event')
            : find.text('Edit event').last,
      );
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == meetingTitle,
      );
      await _until(tester, () async => titleField.evaluate().isNotEmpty);
      await tester.enterText(titleField, '$meetingTitle updated');
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == '$meetingTitle updated',
        ),
        findsOneWidget,
      );
      stage('scheduling organizer save');
      await _tap(tester, find.text('Save').last);
      if (!Platform.isAndroid) {
        await _until(
          tester,
          () async =>
              find.text('Notify guests?').hitTestable().evaluate().isNotEmpty,
        );
        await _tap(tester, find.text('Save').last);
      }
      stage('scheduling organizer delivery');
      try {
        await _until(tester, () async {
          await attendee.synchronize();
          return (await attendee.meetingObject(owner.uid)).rawIcsBody
              .contains('$meetingTitle updated');
        });
      } on Object {
        final pending = await tester.runAsync(
          () => owner.database.select(owner.database.pendingOps).get(),
        );
        final current = await tester.runAsync(
          () => owner.meetingObject(owner.uid),
        );
        final diagnostic = jsonEncode({
          'ownerStoredSummary': current == null
              ? null
              : IcalSemanticDocument.parse(current.rawIcsBody)
                    .components
                    .first
                    .summary,
          'pending': pending
              ?.map(
                (p) => {
                  'type': p.operationType,
                  'state': p.state,
                  'code': p.lastErrorCode,
                },
              )
              .toList(),
          'visible': find
              .byType(Text)
              .evaluate()
              .toList()
              .reversed
              .take(50)
              .map((e) => (e.widget as Text).data)
              .toList(),
        });
        fail('The organizer update was not delivered. $diagnostic');
      }
      await tester.pumpWidget(const SizedBox());
      stage('scheduling cancellation');
      final ownerEvents = await tester.runAsync(
        () => (owner.database.select(
          owner.database.calendarEvents,
        )..where((row) => row.icalUid.equals(owner.uid))).get(),
      );
      expect(ownerEvents, isNotEmpty);
      expect(
        ownerEvents!.every((event) => event.title == '$meetingTitle updated'),
        isTrue,
        reason: 'The organizer projection must reflect the delivered editor update.',
      );
      await _openSchedule(tester, owner);
      await _tap(tester, find.text('$meetingTitle updated').last);
      if (Platform.isAndroid) {
        await _tap(tester, find.text('Edit event').last);
        final editorScroll = find
            .descendant(
              of: find.byType(AndroidEventEditor),
              matching: find.byType(Scrollable),
            )
            .first;
        await _until(
          tester,
          () async => editorScroll.hitTestable().evaluate().isNotEmpty,
        );
        await tester.scrollUntilVisible(
          find.text('Delete Event'),
          300,
          scrollable: editorScroll,
        );
        await _tap(tester, find.text('Delete Event').last);
        await _tap(tester, find.text('Delete').last);
      } else {
        await _tap(
          tester,
          Platform.isLinux
              ? find.byTooltip('Cancel meeting')
              : find.text('Cancel meeting').last,
        );
        await _tap(tester, find.text('Send cancellation').last);
      }
      await _until(tester, () async {
        final cancelled = await (await attendee.collections.openContext()).send(
          'GET',
          Uri.parse(event.requestUri),
        );
        return cancelled.statusCode == 404 ||
            (cancelled.statusCode == 200 &&
                cancelled.bodyText.contains('STATUS:CANCELLED'));
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets('native federation accepts and declines real peer invitations', (
    tester,
  ) async {
    stage('federation');
    final peer = (await tester.runAsync(
      () => NextcloudExtendedFixture.open(
        prefix: 'BUSYMAX_NEXTCLOUD_FEDERATION_LIVE',
        environment: environment,
      ),
    ))!;
    addTearDown(peer.close);
    final incoming = NextcloudFederationService(peer.collections);
    for (final accept in [true, false]) {
      debugPrint('Native federation action: ${accept ? 'accept' : 'decline'}');
      final owner = (await tester.runAsync(
        () => NextcloudExtendedFixture.open(environment: environment),
      ))!;
      addTearDown(owner.close);
      final sharing = NextcloudSharingService(owner.collections);
      final recipient = (await tester.runAsync(() async {
        await owner.importEvent();
        final result = (await sharing.search(
          environment['BUSYMAX_NEXTCLOUD_FEDERATION_LIVE_CLOUD_ID']!,
        )).single;
        await sharing.changeShare(owner.collection.id, result, writable: true);
        return result;
      }))!;
      final invitation = (await tester.runAsync(incoming.pending))!
          .singleWhere((i) => i.displayName == owner.title);
      await _open(tester, peer, 'federation');
      await _tap(
        tester,
        find.byKey(
          ValueKey(
            'nextcloud-federation-${accept ? 'accept' : 'decline'}-${invitation.id}',
          ),
        ),
      );
      await _until(
        tester,
        () async =>
            (await incoming.pending()).every((i) => i.id != invitation.id),
      );
      if (accept) {
        // A separate fixture runner executes the official server background
        // job. Observe the resulting content, not a successful OCS response.
        await _until(tester, () async {
          await peer.synchronize();
          final objects = await peer.database
              .select(peer.database.davObjects)
              .get();
          return objects.any((o) => o.rawIcsBody.contains(owner.uid));
        });
        expect(
          (await tester.runAsync(() => peer.meetingObject(owner.uid)))!
              .rawIcsBody,
          contains(owner.title),
        );
      } else {
        await tester.runAsync(peer.synchronize);
        expect(
          (await tester.runAsync(
            () => peer.database.select(peer.database.davCollections).get(),
          ))!.where((c) => c.displayName == owner.title),
          isEmpty,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () =>
            sharing.changeShare(owner.collection.id, recipient, writable: null),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
  testWidgets('native draft availability distinguishes busy, free and unknown', (
    tester,
  ) async {
    stage('availability');
    final owner = (await tester.runAsync(
      () => NextcloudExtendedFixture.open(environment: environment),
    ))!;
    addTearDown(owner.close);
    final guest = (await tester.runAsync(
      () => NextcloudExtendedFixture.open(
        environment: environment,
        username:
            environment['BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_ATTENDEE_USERNAME']!,
      ),
    ))!;
    addTearDown(guest.close);
    final address = (await tester.runAsync(
      () async => (await NextcloudSchedulingPolicy.load(
        guest.database,
        guest.collection,
      )).organizerAddress,
    ))!;
    await tester.runAsync(
      () => guest.importRaw(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\n'
        'UID:${guest.uid}\r\nDTSTAMP:20261101T000000Z\r\nSUMMARY:${guest.title}\r\n'
        'DTSTART:20261120T120000Z\r\nDTEND:20261120T130000Z\r\nTRANSP:OPAQUE\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      ),
    );
    EventEditorDraft draft(int hour, bool missing) => EventEditorDraft(
      accountId: owner.id,
      sourceId: owner.collection.id,
      providerCalendarId: owner.created.toString(),
      title: owner.title,
      allDay: false,
      start: DateTime(2026, 11, 20, hour),
      end: DateTime(2026, 11, 20, hour + 1),
      startTimeZone: 'UTC',
      endTimeZone: 'UTC',
      attendees: [
        EventAttendeeDraft(email: address.replaceFirst('mailto:', '')),
        if (missing)
          EventAttendeeDraft(email: 'missing-${owner.id}@busymax.invalid'),
      ],
    );
    await _open(tester, owner, 'availability', draft: draft(12, true));
    await _until(
      tester,
      () async =>
          find.text('Busy periods').evaluate().isNotEmpty &&
          find.text('Availability unknown').evaluate().isNotEmpty,
    );
    expect(
      find.text('No busy periods reported for this interval'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await _open(tester, owner, 'availability', draft: draft(16, false));
    await _until(
      tester,
      () async => find
          .text('No busy periods reported for this interval')
          .evaluate()
          .isNotEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _openSchedule(
  WidgetTester tester,
  NextcloudExtendedFixture fixture,
) async {
  final settings = AppSettings.defaults().copyWith(
    scheduleViewMode: ScheduleViewMode.agenda,
    androidScheduleViewMode: ScheduleViewMode.agenda,
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        secretStoreProvider.overrideWithValue(fixture.secrets),
        activeAccountProvider.overrideWithValue(fixture.id),
        localTimeZoneProvider.overrideWithValue('UTC'),
        networkAvailabilityProvider.overrideWith(
          (ref) => Stream.value(NetworkAvailability.online),
        ),
        desktopWindowServiceProvider.overrideWithValue(
          const NoOpDesktopWindowService(),
        ),
        localSettingsStoreProvider.overrideWithValue(
          MemorySettingsStore(settings.toJson()),
        ),
        initialAppSettingsProvider.overrideWithValue(settings),
        calendarRepositoryProvider.overrideWithValue(
          CalendarRepository(
            database: fixture.database,
            localTimeZone: 'UTC',
            nextcloudCollections: (_) => fixture.collections,
          ),
        ),
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(fixture.database),
        ),
        nextcloudCollectionServiceProvider(fixture.id)
            .overrideWithValue(fixture.collections),
        davAccountSyncEngineFactoryProvider.overrideWithValue((accountId) {
          if (accountId != fixture.id) {
            throw StateError('Native QA synchronization crossed accounts.');
          }
          return DavAccountSyncEngine(
            database: fixture.database,
            secretStore: fixture.secrets,
            httpClient: fixture.client,
            accountId: accountId,
          );
        }),
        pendingCalendarMutationSyncRequesterForAccountProvider(fixture.id)
            .overrideWith((ref) {
              final requester = PendingMutationSyncRequester(
                sync: fixture.synchronize,
                debounce: Duration.zero,
              );
              ref.onDispose(requester.dispose);
              return requester;
            }),
      ],
      child: Platform.isWindows
          ? fluent.FluentApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const WindowsSchedulePage(),
            )
          : MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: BusyMaxYaruTheme.build(
                brightness: Brightness.light,
                accentColor: Colors.orange,
              ),
              home: Platform.isAndroid
                  ? const AndroidScheduleScreen()
                  : const Scaffold(body: ScheduleWorkspace()),
            ),
    ),
  );
  await _until(tester, () async => true, minimumFrames: 10);
}

Future<void> _open(
  WidgetTester tester,
  NextcloudExtendedFixture fixture,
  String view, {
  EventEditorDraft? draft,
}) async {
  final content = Builder(
    builder: (context) => Center(
      child: Platform.isWindows
          ? fluent.Button(
              onPressed: () => view == 'federation'
                  ? showWindowsNextcloudFederationDialog(
                      context,
                      accountId: fixture.id,
                    )
                  : view == 'trash'
                  ? showWindowsNextcloudTrashDialog(
                      context,
                      accountId: fixture.id,
                    )
                  : showWindowsNextcloudSchedulingDialog(
                      context,
                      accountId: fixture.id,
                      collectionId: fixture.collection.id,
                      draft: draft,
                    ),
              child: const Text('Open QA workflow'),
            )
          : TextButton(
              onPressed: () => Platform.isAndroid && view == 'availability'
                  ? showAndroidGuestAvailabilityDialog(
                      context,
                      accountId: fixture.id,
                      provider: BusyProvider.nextcloud,
                      collectionId: fixture.collection.id,
                      draft: draft!,
                      calendarTimeZone: 'UTC',
                    )
                  : view == 'federation'
                  ? showLinuxNextcloudFederationDialog(
                      context,
                      accountId: fixture.id,
                    )
                  : view == 'trash'
                  ? showLinuxNextcloudTrashDialog(
                      context,
                      accountId: fixture.id,
                    )
                  : showLinuxNextcloudSchedulingDialog(
                      context,
                      accountId: fixture.id,
                      collectionId: fixture.collection.id,
                      draft: draft,
                    ),
              child: const Text('Open QA workflow'),
            ),
    ),
  );
  final home = Platform.isAndroid
      ? (view == 'availability'
            ? content
            : view == 'federation'
            ? AndroidNextcloudFederationScreen(accountId: fixture.id)
            : view == 'trash'
            ? AndroidNextcloudTrashScreen(accountId: fixture.id)
            : AndroidNextcloudSchedulingScreen(
                accountId: fixture.id,
                collectionId: fixture.collection.id,
              ))
      : content;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudCollectionServiceProvider(fixture.id)
            .overrideWithValue(fixture.collections),
        nextcloudFederationServiceProvider(fixture.id)
            .overrideWithValue(NextcloudFederationService(fixture.collections)),
        nextcloudSharingServiceProvider(fixture.id)
            .overrideWithValue(NextcloudSharingService(fixture.collections)),
        nextcloudTrashServiceProvider(fixture.id)
            .overrideWithValue(NextcloudTrashService(fixture.collections)),
        nextcloudSchedulingServiceProvider(fixture.id)
            .overrideWithValue(NextcloudSchedulingService(fixture.collections)),
      ],
      child: Platform.isWindows
          ? fluent.FluentApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            )
          : MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: BusyMaxYaruTheme.build(
                brightness: Brightness.light,
                accentColor: Colors.orange,
              ),
              home: Platform.isAndroid && view != 'availability'
                  ? home
                  : Scaffold(body: home),
            ),
    ),
  );
  if (!Platform.isAndroid || view == 'availability') {
    await _tap(tester, find.text('Open QA workflow'));
  }
  await _until(tester, () async => true, minimumFrames: 10);
}

Future<bool> _trashAbsent(NextcloudTrashService trash, Uri href) async {
  try {
    return (await trash.list()).items.every((item) => item.href != href);
  } on DavException catch (error) {
    if (error.kind == DavErrorKind.network ||
        error.kind == DavErrorKind.timeout) {
      // A failed observation is not absence. Only this read may be repeated;
      // the UI mutation above is issued once and keeps its uncertain outcome.
      return false;
    }
    rethrow;
  }
}

Future<void> _trashAction(
  WidgetTester tester,
  NextcloudTrashItem item, {
  required bool permanent,
}) async {
  if (Platform.isAndroid) {
    await _tap(
      tester,
      find.byKey(ValueKey(('nextcloud-trash-menu', item.href.toString()))),
    );
    await _tap(
      tester,
      find.text(permanent ? 'Permanently delete' : 'Restore').last,
    );
  } else {
    await _tap(
      tester,
      find.byKey(
        ValueKey((
          permanent ? 'nextcloud-trash-delete' : 'nextcloud-trash-restore',
          item.href.toString(),
        )),
      ),
    );
    if (!permanent) await _tap(tester, find.text('Restore').last);
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  bool exists(Finder target) {
    try {
      return target.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  try {
    await _until(tester, () async => exists(finder));
    await tester.ensureVisible(finder);
    await _until(tester, () async => exists(finder.hitTestable()));
  } on Object {
    final labels = find
        .byType(Text)
        .evaluate()
        .toList()
        .reversed
        .take(60)
        .map((e) => (e.widget as Text).data)
        .join(' | ');
    fail('Missing native control. Visible labels: $labels');
  }
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() condition, {
  int minimumFrames = 0,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  var frames = 0;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final done = await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      return condition();
    });
    if (done == true && frames++ >= minimumFrames) return;
  }
  fail(
    'The real Nextcloud workflow did not reach its verified state within the observation budget.',
  );
}

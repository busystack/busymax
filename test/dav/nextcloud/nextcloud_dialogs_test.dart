import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/dav/presentation/nextcloud_collection_dialog.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_dialogs.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../support/memory_settings_store.dart';
import '../../test_localized_app.dart';
import 'nextcloud_admin_fixture.dart';

import 'package:busymax/src/dav/nextcloud/nextcloud_federation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window'),
          (call) async => call.method == 'state' ? <String, Object?>{} : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('yaru_window/events'),
          (call) async => null,
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
  });

  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets(
      '$platform accepts and declines account-owned federation invitations',
      (tester) async {
        final fixture = NextcloudAdminFixture();
        await tester.runAsync(fixture.seed);
        addTearDown(fixture.close);
        Map<String, Object?> invitation(int id) => {
          'id': id,
          'displayName': 'Remote calendar $id',
          'sharedBy': 'owner@cloud.test/subpath',
          'sharedByDisplayName': 'Owner',
          'remoteUrl': 'https://untrusted.test/never-send-credentials',
          'permissions': 31,
          'components': 'VEVENT,VTODO',
        };
        fixture.federationInvitations.add(invitation(1));
        await _pumpFederation(tester, fixture, platform);
        expect(find.text('Remote calendar 1'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('nextcloud-federation-accept-1')),
        );
        await _settle(tester);
        expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(
          find.text('No pending shared calendar invitations.'),
          findsOneWidget,
        );
        fixture.federationInvitations.add(invitation(2));
        final refresh = platform == 'Android'
            ? find.byTooltip('Refresh')
            : find.text('Refresh');
        await tester.tap(refresh);
        await _settle(tester);
        expect(find.text('Remote calendar 2'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('nextcloud-federation-decline-2')),
        );
        await _settle(tester);
        expect(
          fixture.requests.where((r) => r.method == 'DELETE'),
          hasLength(1),
        );
        expect(
          fixture.requests.every((r) => r.url.host == 'cloud.example.test'),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final (property, invalid, valid, message) in [
    ('displayname', ' ', 'Repaired QA collection', 'This field is required.'),
    (
      'calendar-color',
      'red?',
      '#12345678',
      'Enter a six- or eight-digit hexadecimal color, starting with #.',
    ),
    ('calendar-order', 'first', '4', 'Enter a whole number.'),
    (
      'calendar-timezone',
      'not a timezone',
      'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VTIMEZONE\r\nTZID:Etc/UTC\r\nEND:VTIMEZONE\r\nEND:VCALENDAR\r\n',
      'Enter a valid calendar timezone document containing VTIMEZONE and TZID.',
    ),
  ]) {
    testWidgets(
      'Linux validates $property locally, retains its draft and allows correction',
      (tester) async {
        final fixture = NextcloudAdminFixture();
        await tester.runAsync(fixture.seed);
        addTearDown(fixture.close);
        await _pump(tester, fixture, false);
        if (property == 'calendar-timezone') {
          await tester.ensureVisible(find.text('Advanced'));
          await tester.tap(find.text('Advanced'));
          await tester.pumpAndSettle();
        }
        final field = find.byKey(ValueKey('nextcloud-$property'));
        await tester.ensureVisible(field);
        await tester.enterText(field, invalid);
        await tester.pump();
        final requests = fixture.requests.length;
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(fixture.requests.length, requests);
        expect(tester.widget<TextField>(field).controller!.text, invalid);
        expect(find.text('Nextcloud could not be reached.'), findsNothing);
        await tester.enterText(field, valid);
        await tester.pump();
        await tester.tap(find.text('Save'));
        await _settle(tester);
        expect(
          fixture.requests.where((r) => r.method == 'PROPPATCH'),
          hasLength(1),
        );
        expect(find.text(message), findsNothing);
        expect(tester.widget<TextField>(field).controller!.text, valid);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final windows in [false, true]) {
    final platform = windows ? 'Windows' : 'Linux';
    testWidgets('$platform initiates a federated calendar share', (
      tester,
    ) async {
      final fixture = NextcloudAdminFixture();
      await tester.runAsync(fixture.seed);
      addTearDown(fixture.close);
      await _pump(tester, fixture, windows);
      const cloudId = 'alex@remote.example.test';
      if (windows) {
        final search = find
            .byWidgetPredicate(
              (widget) =>
                  widget is fluent.TextBox && widget.placeholder == null,
            )
            .last;
        await tester.enterText(search, cloudId);
      } else {
        final search = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Find people or groups',
        );
        await tester.enterText(search, cloudId);
      }
      await tester.ensureVisible(find.text('Search'));
      await tester.tap(find.text('Search'));
      await _settle(tester);
      expect(find.text(cloudId), findsWidgets);
      await tester.ensureVisible(find.text('Read-only').last);
      await tester.tap(find.text('Read-only').last);
      FocusManager.instance.primaryFocus?.unfocus();
      await _waitForShare(tester, fixture);
      expect(fixture.shares, hasLength(1));
      expect(fixture.shares.values.single, isFalse);
      expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$platform can save metadata on a content-read-only collection',
      (tester) async {
        final fixture = NextcloudAdminFixture();
        await tester.runAsync(fixture.seed);
        addTearDown(fixture.close);
        await _pump(tester, fixture, windows);
        final title = find.byKey(const ValueKey('nextcloud-displayname'));
        expect(title, findsOneWidget);
        if (windows) {
          expect(tester.widget<fluent.TextBox>(title).enabled, isTrue);
          expect(find.byType(AlertDialog), findsNothing);
        } else {
          expect(tester.widget<TextField>(title).enabled, isTrue);
          expect(find.byType(fluent.ContentDialog), findsNothing);
          expect(find.byType(BusyMaxDialogShell), findsOneWidget);
          expect(find.byType(BusyMaxGroupedList), findsWidgets);
          expect(find.byType(AlertDialog), findsNothing);
        }
        expect(fixture.requests.where((r) => r.method == 'PROPPATCH'), isEmpty);
        await tester.enterText(title, 'New name');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await _settle(tester);
        expect(fixture.displayName, 'New name');
        expect(
          fixture.requests.where((r) => r.method == 'PROPPATCH'),
          hasLength(1),
        );
        if (!windows) {
          expect(
            find.byKey(const ValueKey('nextcloud-collection-dialog')),
            findsOneWidget,
          );
        }
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
    testWidgets('$platform cancels dirty metadata without a DAV write', (
      tester,
    ) async {
      final fixture = NextcloudAdminFixture();
      await tester.runAsync(fixture.seed);
      addTearDown(fixture.close);
      await _pump(tester, fixture, windows);
      await tester.enterText(
        find.byKey(const ValueKey('nextcloud-displayname')),
        'Discard me',
      );
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.method == 'PROPPATCH'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final oldFails in [false, true]) {
    testWidgets(
      'Android recipient results ignore superseded responses (old fails: $oldFails)',
      (tester) async {
        final fixture = NextcloudAdminFixture();
        await tester.runAsync(fixture.seed);
        final oldStarted = Completer<void>();
        final releaseOld = Completer<void>();
        addTearDown(() async {
          if (!releaseOld.isCompleted) releaseOld.complete();
          await fixture.close();
        });
        fixture.principalSearchResponse = (request) async {
          final old = request.body.contains('Old query');
          if (old) {
            if (!oldStarted.isCompleted) oldStarted.complete();
            await releaseOld.future;
            if (oldFails) return http.Response('', 503);
          }
          final name = old ? 'Old recipient' : 'New recipient';
          final path =
              '/remote.php/dav/principals/users/${old ? 'old' : 'new'}/';
          return fixture.multi(
            path,
            '<d:displayname>$name</d:displayname><d:principal-URL><d:href>$path</d:href></d:principal-URL>',
          );
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localSettingsStoreProvider.overrideWithValue(
                MemorySettingsStore(),
              ),
              nextcloudSharingServiceProvider('account')
                  .overrideWithValue(fixture.sharing),
            ],
            child: localizedTestApp(
              child: const AndroidNextcloudSharingScreen(
                accountId: 'account',
                collectionId: 'collection',
                title: 'Work',
              ),
            ),
          ),
        );
        await _settle(tester);
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Find people or groups',
        );
        await tester.enterText(field, 'Old query');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        for (var i = 0; i < 30 && !oldStarted.isCompleted; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(oldStarted.isCompleted, isTrue);
        await tester.enterText(field, 'New query');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(find.text('New recipient'), findsOneWidget);
        releaseOld.complete();
        await _settle(tester);
        expect(find.text('Old recipient'), findsNothing);
        expect(find.text('New recipient'), findsOneWidget);
        expect(find.text('Operation failed'), findsNothing);
        expect(tester.widget<TextField>(field).controller!.text, 'New query');

        final staleSelection = tester
            .widget<PopupMenuButton<bool>>(
              find.byType(PopupMenuButton<bool>).last,
            )
            .onSelected!;
        await tester.enterText(field, 'Edited query');
        await tester.pump();
        expect(find.text('New recipient'), findsNothing);
        staleSelection(false);
        await _settle(tester);
        expect(fixture.shares, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Android initiates a federated calendar share', (tester) async {
    final fixture = NextcloudAdminFixture();
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await tester.binding.setSurfaceSize(const Size(430, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          nextcloudSharingServiceProvider('account')
              .overrideWithValue(fixture.sharing),
        ],
        child: localizedTestApp(
          child: const AndroidNextcloudSharingScreen(
            accountId: 'account',
            collectionId: 'collection',
            title: 'Work',
          ),
        ),
      ),
    );
    await _settle(tester);
    const cloudId = 'alex@remote.example.test';
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Find people or groups',
      ),
      cloudId,
    );
    await tester.tap(find.byIcon(Icons.search).last);
    await _settle(tester);
    expect(find.text(cloudId), findsWidgets);
    await tester.tap(find.byType(PopupMenuButton<bool>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read-only').last);
    FocusManager.instance.primaryFocus?.unfocus();
    await _waitForShare(tester, fixture);
    expect(fixture.shares, hasLength(1));
    expect(fixture.shares.values.single, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested collection confirmation keeps the parent modal active', (
    tester,
  ) async {
    final fixture = NextcloudAdminFixture();
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pump(tester, fixture, false);

    await tester.enterText(
      find.byKey(const ValueKey('nextcloud-displayname')),
      'Unsaved',
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    expect(find.byType(AnimatedModalBarrier), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nextcloud-collection-dialog')),
      findsOneWidget,
    );
    expect(find.byType(BusyMaxConfirmDialog), findsNothing);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nextcloud-collection-dialog')),
      findsNothing,
    );
    expect(find.byType(AnimatedModalBarrier), findsNothing);
    expect(
      fixture.requests.where((request) => request.method == 'PROPPATCH'),
      isEmpty,
    );
  });

  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets(
      '$platform bounds automatic identification of small unnamed trash items',
      (tester) async {
        final fixture = NextcloudAdminFixture()..trashObjectCount = 20;
        await tester.runAsync(fixture.seed);
        addTearDown(fixture.close);
        await _pumpTrash(tester, fixture, platform: platform);
        await _settle(tester);
        expect(fixture.requests.where((r) => r.method == 'GET'), hasLength(5));
        expect(
          fixture.requests.where((r) => r.body.contains('calendar-data')),
          isEmpty,
        );
        expect(find.text('Deleted event'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets(
      '$platform shows trash metadata before an on-demand detail read completes',
      (tester) async {
        final fixture = NextcloudAdminFixture()
          ..trashDescriptionBytes = 65 * 1024;
        await tester.runAsync(fixture.seed);
        addTearDown(fixture.close);
        await _pumpTrash(tester, fixture, platform: platform);
        expect(find.text('41.ics'), findsOneWidget);
        expect(find.text('42.ics'), findsOneWidget);
        expect(
          fixture.requests.where(
            (r) => r.method == 'GET' || r.body.contains('calendar-data'),
          ),
          isEmpty,
        );
        final started = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        fixture.beforeResponse = (request) async {
          if (request.method == 'GET') {
            started.complete();
            await release.future;
          }
        };
        final href =
            '${NextcloudAdminFixture.origin}${NextcloudAdminFixture.bin}objects/41.ics';
        if (platform == 'Android') {
          await tester.tap(
            find.byKey(ValueKey(('nextcloud-trash-menu', href))),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Show'));
        } else {
          await tester.tap(
            find.byKey(ValueKey(('nextcloud-trash-details', href))),
          );
        }
        for (var i = 0; i < 30 && !started.isCompleted; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(started.isCompleted, isTrue);
        expect(find.text('42.ics'), findsOneWidget);
        expect(find.text('Deleted event'), findsNothing);
        release.complete();
        await _settle(tester);
        expect(find.text('Deleted event'), findsOneWidget);
        expect(find.text('42.ics'), findsOneWidget);
        expect(find.text('Deleted task'), findsNothing);
        expect(fixture.requests.where((r) => r.method == 'GET'), hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'trash keeps the newest listing when refreshes finish in reverse order',
    (tester) async {
      final fixture = NextcloudAdminFixture()
        ..trashDescriptionBytes = 65 * 1024;
      await tester.runAsync(fixture.seed);
      addTearDown(fixture.close);
      await _pumpTrash(tester, fixture, platform: 'Android');
      expect(find.text('42.ics'), findsOneWidget);
      final olderStarted = Completer<void>();
      final releaseOlder = Completer<void>();
      addTearDown(() {
        if (!releaseOlder.isCompleted) releaseOlder.complete();
      });
      fixture.beforeResponse = (request) async {
        // Hold the older listing after its object inventory has been captured.
        if (request.method == 'PROPFIND' &&
            request.url.path == NextcloudAdminFixture.home &&
            request.headers['depth'] == '1' &&
            !olderStarted.isCompleted) {
          olderStarted.complete();
          await releaseOlder.future;
        }
      };
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 50 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(done(), isTrue);
      }

      var olderDone = false, newerDone = false;
      final older = refresh().whenComplete(() => olderDone = true);
      await until(() => olderStarted.isCompleted);
      fixture.restored.add('${NextcloudAdminFixture.bin}objects/42.ics');
      final newer = refresh().whenComplete(() => newerDone = true);
      await until(() => newerDone);
      await newer;
      await tester.pump();
      expect(find.text('41.ics'), findsOneWidget);
      expect(find.text('42.ics'), findsNothing);
      releaseOlder.complete();
      await until(() => olderDone);
      await older;
      await tester.pump();
      expect(find.text('41.ics'), findsOneWidget);
      expect(find.text('42.ics'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('trash uses shared rows and confirms permanent deletion', (
    tester,
  ) async {
    final fixture = NextcloudAdminFixture()..trashDescriptionBytes = 65 * 1024;
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pumpTrash(tester, fixture);

    expect(find.byType(BusyMaxDialogShell), findsOneWidget);
    expect(find.byType(BusyMaxGroupedList), findsWidgets);
    for (final id in [41, 42]) {
      final action = find.byKey(
        ValueKey((
          'nextcloud-trash-details',
          '${NextcloudAdminFixture.origin}${NextcloudAdminFixture.bin}objects/$id.ics',
        )),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await _settle(tester);
    }
    expect(find.text('Deleted event'), findsOneWidget);
    expect(find.text('Deleted task'), findsOneWidget);
    expect(find.textContaining('30'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    final deleteActions = find.widgetWithText(
      BusyMaxActionRow,
      'Permanently delete',
    );
    await tester.tap(deleteActions.first);
    await tester.pumpAndSettle();
    var confirmation = find.byType(BusyMaxConfirmDialog);
    expect(confirmation, findsOneWidget);
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted event'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted task'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      fixture.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );

    await tester.tap(deleteActions.last);
    await tester.pumpAndSettle();
    confirmation = find.byType(BusyMaxConfirmDialog);
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted task'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('Deleted event'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: confirmation,
        matching: find.widgetWithText(ElevatedButton, 'Permanently delete'),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (fixture.requests.any((request) => request.method == 'DELETE') &&
          find.byType(YaruCircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    final deletes = fixture.requests
        .where((request) => request.method == 'DELETE')
        .toList();
    expect(deletes, hasLength(1));
    expect(deletes.single.url.path, endsWith('/objects/42.ics'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('trash disables operations denied by the server', (tester) async {
    final fixture = NextcloudAdminFixture()..denyTrashObject = true;
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pumpTrash(tester, fixture);

    final restore = tester.widget<BusyMaxActionRow>(
      find.widgetWithText(BusyMaxActionRow, 'Restore').first,
    );
    final delete = tester.widget<BusyMaxActionRow>(
      find.widgetWithText(BusyMaxActionRow, 'Permanently delete').first,
    );
    expect(restore.enabled, isFalse);
    expect(delete.enabled, isFalse);
  });

  testWidgets('collection dialog scrolls in a narrow enlarged RTL window', (
    tester,
  ) async {
    final fixture = NextcloudAdminFixture();
    await tester.runAsync(fixture.seed);
    addTearDown(fixture.close);
    await _pump(
      tester,
      fixture,
      false,
      size: const Size(430, 420),
      brightness: Brightness.dark,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.5),
    );

    final dialog = find.byKey(const ValueKey('nextcloud-collection-dialog'));
    expect(dialog, findsOneWidget);
    expect(Directionality.of(tester.element(dialog)), TextDirection.rtl);
    expect(
      find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _waitForShare(
  WidgetTester tester,
  NextcloudAdminFixture fixture,
) async {
  for (var i = 0; i < 30 && fixture.shares.isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(
  WidgetTester tester,
  NextcloudAdminFixture fixture,
  bool windows, {
  Size size = const Size(1000, 850),
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final home = Builder(
    builder: (context) => Center(
      child: windows
          ? fluent.Button(
              onPressed: () => showWindowsNextcloudCollectionDialog(
                context,
                accountId: 'account',
                collectionId: 'collection',
              ),
              child: const Text('Open'),
            )
          : TextButton(
              onPressed: () => showLinuxNextcloudCollectionDialog(
                context,
                accountId: 'account',
                collectionId: 'collection',
              ),
              child: const Text('Open'),
            ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudSharingServiceProvider('account')
            .overrideWithValue(fixture.sharing),
      ],
      child: windows
          ? fluent.FluentApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            )
          : localizedTestApp(
              locale: locale,
              textScaler: textScaler,
              theme: BusyMaxYaruTheme.build(
                brightness: brightness,
                accentColor: YaruColors.orange,
              ),
              child: Scaffold(body: home),
            ),
    ),
  );
  await tester.tap(find.text('Open'));
  await _settle(tester);
}

Future<void> _pumpTrash(
  WidgetTester tester,
  NextcloudAdminFixture fixture, {
  String platform = 'Linux',
}) async {
  await tester.binding.setSurfaceSize(const Size(760, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final home = Builder(
    builder: (context) => Center(
      child: platform == 'Windows'
          ? fluent.Button(
              onPressed: () => showWindowsNextcloudTrashDialog(
                context,
                accountId: 'account',
              ),
              child: const Text('Open trash'),
            )
          : BusyMaxPushButton.standard(
              onPressed: () =>
                  showLinuxNextcloudTrashDialog(context, accountId: 'account'),
              child: const Text('Open trash'),
            ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudTrashServiceProvider('account')
            .overrideWithValue(fixture.trash),
      ],
      child: platform == 'Windows'
          ? fluent.FluentApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            )
          : localizedTestApp(
              theme: BusyMaxYaruTheme.build(
                brightness: Brightness.dark,
                accentColor: YaruColors.orange,
              ),
              child: platform == 'Android'
                  ? const AndroidNextcloudTrashScreen(accountId: 'account')
                  : Scaffold(body: home),
            ),
    ),
  );
  if (platform != 'Android') await tester.tap(find.text('Open trash'));
  await _settle(tester);
}

Future<void> _pumpFederation(
  WidgetTester tester,
  NextcloudAdminFixture fixture,
  String platform,
) async {
  await tester.binding.setSurfaceSize(const Size(760, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final home = Builder(
    builder: (context) => Center(
      child: platform == 'Windows'
          ? fluent.Button(
              onPressed: () => showWindowsNextcloudFederationDialog(
                context,
                accountId: 'account',
              ),
              child: const Text('Open invitations'),
            )
          : TextButton(
              onPressed: () {
                if (platform == 'Windows') {
                  showWindowsNextcloudFederationDialog(
                    context,
                    accountId: 'account',
                  );
                } else {
                  showLinuxNextcloudFederationDialog(
                    context,
                    accountId: 'account',
                  );
                }
              },
              child: const Text('Open invitations'),
            ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        nextcloudFederationServiceProvider('account')
            .overrideWithValue(NextcloudFederationService(fixture.collections)),
      ],
      child: platform == 'Windows'
          ? fluent.FluentApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            )
          : localizedTestApp(
              theme: BusyMaxYaruTheme.build(
                brightness: Brightness.dark,
                accentColor: YaruColors.orange,
              ),
              child: platform == 'Android'
                  ? const AndroidNextcloudFederationScreen(accountId: 'account')
                  : Scaffold(body: home),
            ),
    ),
  );
  if (platform != 'Android') await tester.tap(find.text('Open invitations'));
  await _settle(tester);
}

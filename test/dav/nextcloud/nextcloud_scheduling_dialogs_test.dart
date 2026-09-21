import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/dav/presentation/nextcloud_scheduling_dialog.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/ui/windows/windows_nextcloud_scheduling_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';
import '../../support/memory_settings_store.dart';
import '../../test_localized_app.dart';
import 'nextcloud_scheduling_fixture.dart';

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
        if (!windows) {
          expect(find.byType(BusyMaxDialogShell), findsOneWidget);
          expect(find.byType(BusyMaxGroupedList), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
        }
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

  testWidgets('acknowledgment keeps the scheduling modal barrier active', (
    tester,
  ) async {
    final fixture = SchedulingFixture();
    await tester.runAsync(fixture.seedScheduling);
    addTearDown(fixture.close);
    await _pump(tester, fixture, false);

    await tester.tap(find.text('Acknowledge message'));
    await tester.pumpAndSettle();
    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    expect(find.byType(AnimatedModalBarrier), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nextcloud-scheduling-dialog')),
      findsOneWidget,
    );
    expect(find.byType(BusyMaxConfirmDialog), findsNothing);
    expect(
      fixture.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedModalBarrier), findsNothing);
  });

  testWidgets('Linux scheduling dialog presents loading and error states', (
    tester,
  ) async {
    final fixture = SchedulingFixture()
      ..failInbox = true
      ..inboxGate = Completer<void>();
    await tester.runAsync(fixture.seedScheduling);
    addTearDown(() {
      if (!fixture.inboxGate!.isCompleted) fixture.inboxGate!.complete();
      return fixture.close();
    });
    await _pump(tester, fixture, false, waitForLoad: false);

    expect(find.byType(YaruCircularProgressIndicator), findsOneWidget);
    fixture.inboxGate!.complete();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(YaruCircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }

    expect(find.byType(YaruCircularProgressIndicator), findsNothing);
    expect(
      find.text(
        'Nextcloud could not be reached. Cached items and pending work are unchanged.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('nextcloud-scheduling-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('scheduling dialog remains usable in narrow enlarged RTL', (
    tester,
  ) async {
    final fixture = SchedulingFixture();
    await tester.runAsync(fixture.seedScheduling);
    addTearDown(fixture.close);
    await _pump(
      tester,
      fixture,
      false,
      size: const Size(430, 400),
      brightness: Brightness.dark,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(1.5),
    );

    final dialog = find.byKey(const ValueKey('nextcloud-scheduling-dialog'));
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
  bool waitForLoad = true,
  Size size = const Size(760, 640),
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
  if (waitForLoad) {
    await _settle(tester);
  } else {
    await tester.pump();
  }
}

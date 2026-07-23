import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_empty_states.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('schedule exposes a labeled loading state', (tester) async {
    final accounts = StreamController<List<AccountEntity>>();
    addTearDown(accounts.close);

    await _pumpWorkspace(tester, accountsFactory: () => accounts.stream);
    await tester.pump();

    expect(find.byType(ScheduleLoadingState), findsOneWidget);
    expect(find.text('Loading schedule...'), findsOneWidget);
  });

  testWidgets('schedule errors are generic and retry the data pipeline', (
    tester,
  ) async {
    var attempts = 0;
    await _pumpWorkspace(
      tester,
      accountsFactory: () {
        attempts += 1;
        if (attempts == 1) {
          return Stream<List<AccountEntity>>.error(
            StateError('private account database details'),
          );
        }
        return Stream.value(const <AccountEntity>[]);
      },
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleUnavailableState), findsOneWidget);
    expect(find.text('Schedule unavailable'), findsOneWidget);
    expect(
      find.textContaining('private account database details'),
      findsNothing,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byType(ScheduleUnavailableState), findsNothing);
    expect(find.byType(ScheduleNoSourcesState), findsOneWidget);
    expect(find.text('Connect an account'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('standard search shortcut opens and dismisses schedule search', (
    tester,
  ) async {
    await _pumpWorkspace(
      tester,
      accountsFactory: () => Stream.value(const <AccountEntity>[]),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxSearchField), findsOneWidget);
    expect(find.byType(YaruSearchField), findsOneWidget);
    expect(_searchFieldHasPrimaryFocus(tester), isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_searchFieldHasPrimaryFocus(tester), isTrue);

    await tester.enterText(find.byType(TextField), 'planning');
    await tester.pump();
    await tester.tap(find.byIcon(YaruIcons.edit_clear));
    await tester.pump();

    expect(find.byType(BusyMaxSearchField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byType(BusyMaxSearchField), findsNothing);
  });

  testWidgets(
    'native search owns Linux entry state without a Flutter duplicate',
    (tester) async {
      const channel = MethodChannel('busymax_test/schedule_native_search');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final headerBarService = LinuxHeaderBarService(
        channel: channel,
        isLinux: true,
      );

      await _pumpWorkspace(
        tester,
        accountsFactory: () => Stream.value(const <AccountEntity>[]),
        headerBarService: headerBarService,
      );
      await tester.pumpAndSettle();

      await headerBarService.handleNativeMethodCall(const MethodCall('search'));
      await tester.pumpAndSettle();

      expect(find.byType(BusyMaxSearchField), findsNothing);
      expect(
        calls.where((call) => call.method == 'setState').last.arguments,
        containsPair('searchActive', true),
      );

      await headerBarService.handleNativeMethodCall(
        const MethodCall('searchQueryChanged', 'planning'),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'setState').last.arguments,
        containsPair('searchQuery', 'planning'),
      );

      await headerBarService.handleNativeMethodCall(
        const MethodCall('searchCleared'),
      );
      await tester.pumpAndSettle();
      final clearedState = calls
          .where((call) => call.method == 'setState')
          .last
          .arguments;
      expect(clearedState, containsPair('searchActive', true));
      expect(clearedState, containsPair('searchQuery', ''));

      await headerBarService.handleNativeMethodCall(
        const MethodCall('searchEscapePressed'),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'setState').last.arguments,
        containsPair('searchActive', false),
      );
    },
  );
}

bool _searchFieldHasPrimaryFocus(WidgetTester tester) {
  final searchElement = tester.element(find.byType(BusyMaxSearchField));
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (identical(focusContext, searchElement)) {
    return true;
  }
  var found = false;
  if (focusContext is Element) {
    focusContext.visitAncestorElements((ancestor) {
      found = identical(ancestor, searchElement);
      return !found;
    });
  }
  return found;
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required Stream<List<AccountEntity>> Function() accountsFactory,
  LinuxHeaderBarService? headerBarService,
}) async {
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  final resolvedHeaderBarService =
      headerBarService ?? LinuxHeaderBarService(isLinux: false);
  addTearDown(resolvedHeaderBarService.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsStreamProvider.overrideWith((ref) => accountsFactory()),
        localTimeZoneProvider.overrideWithValue('UTC'),
        localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        linuxHeaderBarServiceProvider.overrideWithValue(
          resolvedHeaderBarService,
        ),
      ],
      child: localizedTestApp(child: const ScheduleWorkspace()),
    ),
  );
}

class _MemorySettingsStore implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_empty_states.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required Stream<List<AccountEntity>> Function() accountsFactory,
}) async {
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  final headerBarService = LinuxHeaderBarService(isLinux: false);
  addTearDown(headerBarService.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsStreamProvider.overrideWith((ref) => accountsFactory()),
        localTimeZoneProvider.overrideWithValue('UTC'),
        localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        linuxHeaderBarServiceProvider.overrideWithValue(headerBarService),
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

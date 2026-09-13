import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/windows/windows_busymax_app.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';
import '../../support/recording_notification_backend.dart';

void main() {
  testWidgets(
    'Windows keeps reminders active after theme changes and starts Due today',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final backend = RecordingNotificationBackend();
      final settings = AppSettings.defaults().copyWith(
        showTrayIcon: false,
        runInBackgroundWhenClosed: false,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          initialAppSettingsProvider.overrideWithValue(settings),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          desktopNotificationBackendProvider.overrideWithValue(backend),
          systemAppearanceSourceProvider.overrideWithValue(_Appearance()),
          activeAccountProvider.overrideWithValue('account'),
          authSessionControllerProvider.overrideWith(
            (ref) => _SignedOutController(),
          ),
        ],
      );
      await tester.runAsync(() async {
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'account',
                provider: 'microsoft',
                authority: 'https://login.microsoftonline.com/common',
                providerAccountId: 'account',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        await database
            .into(database.taskLists)
            .insert(
              TaskListsCompanion.insert(
                accountId: 'account',
                id: 'list',
                title: 'Tasks',
                rawJson: '{}',
                createdLocalAtUtc: '',
                updatedLocalAtUtc: '',
              ),
            );
      });
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WindowsBusyMaxApp(),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final controller = container.read(
          appSettingsControllerProvider.notifier,
        );
        await controller.setThemeModePreference(
          BusyMaxThemeModePreference.dark,
        );
      });
      await tester.pump();
      await tester.runAsync(() async {
        await database
            .into(database.notificationSchedule)
            .insert(
              NotificationScheduleCompanion.insert(
                id: 'reminder',
                accountId: 'account',
                sourceType: 'task',
                sourceId: 'task',
                scheduledAtUtc:
                    DateTime.now().toUtc().millisecondsSinceEpoch - 1000,
                title: 'File report',
                createdAtLocal: 0,
                updatedAtLocal: 0,
              ),
            );
      });
      await _pumpUntil(
        tester,
        () => backend.requests.any((request) => request.title == 'File report'),
      );
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await tester.runAsync(() async {
        await database
            .into(database.tasks)
            .insert(
              TasksCompanion.insert(
                accountId: 'account',
                taskListId: 'list',
                id: 'task',
                title: 'File report',
                dueUtc: Value(today),
                status: const Value('needsAction'),
                rawJson: '{}',
                createdLocalAtUtc: '',
                updatedLocalAtUtc: '',
              ),
            );
        await container
            .read(appSettingsControllerProvider.notifier)
            .setNotifyDueToday(true);
      });
      await _pumpUntil(
        tester,
        () =>
            container
                .read(appSettingsControllerProvider)
                .lastDueTodayNotificationDate ==
            today,
      );
      expect(backend.requests, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        container.dispose();
        await database.close();
      });
    },
  );
}

class _SignedOutController extends StateNotifier<AuthSessionState>
    implements AuthSessionController {
  _SignedOutController() : super(const AuthSessionState.signedOut());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Appearance implements SystemAppearanceSource {
  @override
  Color? get accentColor => null;
  @override
  Brightness get brightness => Brightness.light;
  @override
  bool get highContrast => false;
  @override
  Stream<void> get changes => const Stream.empty();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for notification');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

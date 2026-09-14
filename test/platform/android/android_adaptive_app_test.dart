import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const platformChannel = MethodChannel('io.busystack.busymax/android');
  const eventChannel = MethodChannel('io.busystack.busymax/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      return switch (call.method) {
        'takeInitialActivation' => null,
        'googleAuthorizationAvailable' => false,
        'microsoftAuthorizationAvailable' => false,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(eventChannel, (_) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(platformChannel, null);
    messenger.setMockMethodCallHandler(eventChannel, null);
  });

  testWidgets(
    'compact Android shell uses bottom navigation and accessible taps',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Schedule'), findsWidgets);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets('wide Android shell uses a rail in dark RTL mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = AppSettings.defaults().copyWith(
      localeTag: 'ar',
      themeModePreference: BusyMaxThemeModePreference.dark,
    );
    final harness = await _pumpApp(tester, settings);
    addTearDown(harness.dispose);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(AndroidHomeShell))),
      TextDirection.rtl,
    );
    expect(
      Theme.of(tester.element(find.byType(AndroidHomeShell))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact shell tolerates 200 percent text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('required Android viewport matrix renders every destination', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    const viewports = <(Size, double)>[
      (Size(360, 800), 1),
      (Size(412, 915), 1.3),
      (Size(800, 1280), 2),
      (Size(915, 412), 1.3),
      (Size(320, 500), 2),
    ];

    for (final (size, textScale) in viewports) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      tester.binding.handleTextScaleFactorChanged();
      final harness = await _pumpApp(tester, AppSettings.defaults());
      expect(
        tester.takeException(),
        isNull,
        reason:
            'destination 0 at ${size.width}x${size.height} '
            'and text scale $textScale',
      );
      for (final destination in <int>[1, 2]) {
        harness.container
                .read(androidSelectedDestinationProvider.notifier)
                .state =
            destination;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'destination $destination at ${size.width}x${size.height} '
              'and text scale $textScale',
        );
      }
      await harness.dispose();
    }
  });
}

Future<_AndroidAppHarness> _pumpApp(
  WidgetTester tester,
  AppSettings settings,
) async {
  final database = AppDatabase.memoryForTests();
  final notifications = AndroidNotificationService(
    database: database,
    settings: () => settings,
  );
  final container = ProviderContainer(
    overrides: [
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      databaseProvider.overrideWithValue(database),
      initialAppSettingsProvider.overrideWithValue(settings),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
      notificationReconcilerProvider.overrideWithValue(
        CallbackNotificationReconciler(() async {}),
      ),
      androidNotificationServiceProvider.overrideWithValue(notifications),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AndroidBusyMaxApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _AndroidAppHarness(tester, container, database);
}

final class _AndroidAppHarness {
  const _AndroidAppHarness(this.tester, this.container, this.database);

  final WidgetTester tester;
  final ProviderContainer container;
  final AppDatabase database;

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await database.close();
  }
}

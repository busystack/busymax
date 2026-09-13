import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/platform/windows/windows_activation_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/platform/windows/windows_notification_backend.dart';
import 'package:busymax/src/platform/windows/windows_notification_id_store.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'busymax-windows-notifications-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  WindowsNotificationIdStore ids() =>
      WindowsNotificationIdStore(File('${directory.path}/ids.json'));

  for (final route in ['due-today', 'sync-failure', 'conflict']) {
    test(
      '$route body click survives warm, cold, and forwarded activation',
      () async {
        final plugin = _FakeNotificationsPlugin();
        final warm = <DesktopActivation>[];
        final backend = await WindowsNotificationBackend.create(
          appUserModelId: 'BusyStack.BusyMax_test',
          plugin: plugin,
          idStore: ids(),
          onActivation: warm.add,
        );
        addTearDown(backend.close);
        final service = DesktopNotificationService(
          backend: backend,
          settings: AppSettings.defaults().copyWith(notifyDueToday: true),
        );
        switch (route) {
          case 'due-today':
            await service.notifyDueToday(3);
          case 'sync-failure':
            await service.notifySyncFailure(StateError('sync failed'));
          case 'conflict':
            await service.notifyConflict('conflict');
        }
        final response = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: plugin.payloads.single,
        );
        plugin.response!(response);
        expect(warm, hasLength(1));
        expect(warm.single.requiresVisibleWindow, isTrue);
        expect(warm.single.payload, {'notificationRoute': route});
        expect(
          warm.single.notificationDestination,
          route == 'due-today'
              ? DesktopNavigationDestination.tasks
              : DesktopNavigationDestination.settings,
        );
        final cold = <DesktopActivation>[];
        final coldBackend = await WindowsNotificationBackend.create(
          appUserModelId: 'BusyStack.BusyMax_test',
          plugin: _FakeNotificationsPlugin()..launchResponse = response,
          idStore: ids(),
          onActivation: cold.add,
        );
        addTearDown(coldBackend.close);
        expect(cold.single.toJson(), warm.single.toJson());

        const channel = MethodChannel('busymax/test/summary-forwarder');
        final primary = WindowsActivationService(channel: channel);
        final received = <DesktopActivation>[];
        final subscription = primary.activations.listen(received.add);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'forwardActivation') {
                primary.acceptEncoded(call.arguments);
                return true;
              }
              return null;
            });
        addTearDown(() async {
          await subscription.cancel();
          await primary.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        await primary.initialize();
        Future<bool>? forwarded;
        final forwarder = await WindowsNotificationBackend.create(
          appUserModelId: 'BusyStack.BusyMax_test',
          plugin: _FakeNotificationsPlugin()..launchResponse = response,
          activationForwarderOnly: true,
          onActivation: (activation) {
            forwarded = forwardWindowsActivationToPrimary(
              activation,
              channel: channel,
            );
          },
        );
        addTearDown(forwarder.close);
        expect(forwarded, isNotNull);
        expect(await forwarded, isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(received.single.toJson(), warm.single.toJson());
      },
    );
  }

  test(
    'summary routes reject reminder actions, mixed payloads, and mismatched identities',
    () async {
      final plugin = _FakeNotificationsPlugin();
      final activations = <DesktopActivation>[];
      final backend = await WindowsNotificationBackend.create(
        appUserModelId: 'BusyStack.BusyMax_test',
        plugin: plugin,
        idStore: ids(),
        onActivation: activations.add,
      );
      addTearDown(backend.close);
      for (final extra in [
        {'action': 'snooze'},
        {'action': 'dismiss'},
        {'notificationScheduleId': 'fabricated'},
        {'stableId': 'different'},
        {'notificationRoute': 'unknown'},
      ]) {
        plugin.response!(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: jsonEncode({
              'version': 1,
              'stableId': 'due-today',
              'notificationRoute': 'due-today',
              ...extra,
            }),
          ),
        );
      }
      expect(activations, isEmpty);
    },
  );

  test('missing AUMID fails initialization', () async {
    await expectLater(
      WindowsNotificationBackend.create(
        appUserModelId: '',
        onActivation: (_) {},
        plugin: _FakeNotificationsPlugin(),
        idStore: ids(),
      ),
      throwsArgumentError,
    );
  });

  test('native initialization false is a typed visible failure', () async {
    await expectLater(
      WindowsNotificationBackend.create(
        appUserModelId: 'BusyStack.BusyMax_test',
        onActivation: (_) {},
        plugin: _FakeNotificationsPlugin(initializeResult: false),
        idStore: ids(),
      ),
      throwsA(
        isA<WindowsNotificationInitializationException>().having(
          (error) => error.code,
          'code',
          'toast-registration-failed',
        ),
      ),
    );
  });

  test('initialization exception is converted to a sanitized code', () async {
    await expectLater(
      WindowsNotificationBackend.create(
        appUserModelId: 'BusyStack.BusyMax_test',
        onActivation: (_) {},
        plugin: _FakeNotificationsPlugin(
          initializeError: StateError('private native detail'),
        ),
        idStore: ids(),
      ),
      throwsA(
        isA<WindowsNotificationInitializationException>().having(
          (error) => error.code,
          'code',
          'initialization-failed',
        ),
      ),
    );
  });

  test(
    'installed package identity is queried through the runner bridge',
    () async {
      const channel = MethodChannel('busymax/test/package-identity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'hasPackageIdentity');
            return true;
          });
      expect(
        await WindowsNotificationBackend.hasPackageIdentity(channel: channel),
        isTrue,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(
        await WindowsNotificationBackend.hasPackageIdentity(channel: channel),
        isFalse,
      );
    },
  );

  test('activation forwarder opens no application storage', () async {
    final corruptStore = ids();
    await corruptStore.file.writeAsString('{not-json');
    final backend = await WindowsNotificationBackend.create(
      appUserModelId: 'BusyStack.BusyMax_test',
      onActivation: (_) {},
      plugin: _FakeNotificationsPlugin(),
      idStore: corruptStore,
      activationForwarderOnly: true,
    );
    await expectLater(
      backend.notify(_request('must-not-write')),
      throwsStateError,
    );
    expect(await corruptStore.file.readAsString(), '{not-json');
  });

  test('display and cancellation use the same stable persisted ID', () async {
    final plugin = _FakeNotificationsPlugin();
    final backend = await WindowsNotificationBackend.create(
      appUserModelId: 'BusyStack.BusyMax_test',
      onActivation: (_) {},
      plugin: plugin,
      idStore: ids(),
    );
    await backend.notify(_request('schedule-1'));
    await backend.cancel('schedule-1');
    expect(plugin.shownIds, hasLength(1));
    expect(plugin.cancelledIds, [plugin.shownIds.single]);

    final restartedPlugin = _FakeNotificationsPlugin();
    final restarted = await WindowsNotificationBackend.create(
      appUserModelId: 'BusyStack.BusyMax_test',
      onActivation: (_) {},
      plugin: restartedPlugin,
      idStore: ids(),
    );
    await restarted.notify(_request('schedule-1'));
    expect(restartedPlugin.shownIds.single, plugin.shownIds.single);
  });

  test('body activation uses validated common activation model', () async {
    final activations = <DesktopActivation>[];
    final plugin = _FakeNotificationsPlugin();
    final backend = await WindowsNotificationBackend.create(
      appUserModelId: 'BusyStack.BusyMax_test',
      onActivation: activations.add,
      plugin: plugin,
      idStore: ids(),
    );
    await backend.notify(_request('schedule-body'));
    plugin.response!(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: plugin.payloads.single,
      ),
    );
    expect(activations, hasLength(1));
    expect(activations.single.kind, DesktopActivationKind.notification);
    expect(activations.single.action, 'default');
    expect(
      activations.single.payload?['notificationScheduleId'],
      'schedule-body',
    );
  });

  test(
    'delivery generation survives warm and cold Windows action routing',
    () async {
      final activations = <DesktopActivation>[];
      final plugin = _FakeNotificationsPlugin();
      final backend = await WindowsNotificationBackend.create(
        appUserModelId: 'BusyStack.BusyMax_test',
        onActivation: activations.add,
        plugin: plugin,
        idStore: ids(),
      );
      await backend.notify(
        const BusyMaxNotificationRequest(
          stableId: 'schedule|generation-1',
          title: 'Reminder',
          payload: {
            'notificationScheduleId': 'schedule',
            'notificationGeneration': 'generation-1',
          },
          actions: [BusyMaxNotificationAction('snooze', 'Snooze')],
        ),
      );
      final actionPayload =
          plugin.details.single.windows!.actions.single.arguments;
      final response = NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        payload: actionPayload,
      );
      plugin.response!(response);
      final coldPlugin = _FakeNotificationsPlugin()..launchResponse = response;
      await WindowsNotificationBackend.create(
        appUserModelId: 'BusyStack.BusyMax_test',
        onActivation: activations.add,
        plugin: coldPlugin,
        idStore: ids(),
      );
      expect(activations, hasLength(2));
      for (final activation in activations) {
        expect(activation.action, 'snooze');
        expect(activation.payload!['notificationGeneration'], 'generation-1');
        expect(
          DesktopActivation.tryDecode(activation.encode())?.payload,
          activation.payload,
        );
      }
      await backend.cancel('schedule|generation-1');
      expect(plugin.cancelledIds, [plugin.shownIds.single]);
    },
  );

  test('Open, Snooze, and Dismiss route through one validated path', () async {
    final activations = <DesktopActivation>[];
    final plugin = _FakeNotificationsPlugin();
    final backend = await WindowsNotificationBackend.create(
      appUserModelId: 'BusyStack.BusyMax_test',
      onActivation: activations.add,
      plugin: plugin,
      idStore: ids(),
    );
    await backend.notify(_request('schedule-actions'));
    final actions = plugin.details.single.windows!.actions;
    for (final expected in ['open', 'snooze', 'dismiss']) {
      final action = actions.singleWhere(
        (candidate) => jsonDecode(candidate.arguments)['action'] == expected,
      );
      plugin.response!(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          payload: action.arguments,
        ),
      );
    }
    expect(activations.map((activation) => activation.action), [
      'open',
      'snooze',
      'dismiss',
    ]);
  });
}

BusyMaxNotificationRequest _request(String id) => BusyMaxNotificationRequest(
  stableId: id,
  title: 'Reminder',
  payload: {'notificationScheduleId': id, 'itemKind': 'event'},
  actions: const [
    BusyMaxNotificationAction('open', 'Open'),
    BusyMaxNotificationAction('snooze', 'Snooze'),
    BusyMaxNotificationAction('dismiss', 'Dismiss'),
  ],
);

final class _FakeNotificationsPlugin
    implements WindowsNotificationPluginAdapter {
  _FakeNotificationsPlugin({
    this.initializeResult = true,
    this.initializeError,
  });

  final bool initializeResult;
  final Object? initializeError;
  DidReceiveNotificationResponseCallback? response;
  NotificationResponse? launchResponse;
  final shownIds = <int>[];
  final cancelledIds = <int>[];
  final payloads = <String?>[];
  final details = <NotificationDetails>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    if (initializeError case final error?) throw error;
    response = onDidReceiveNotificationResponse;
    return initializeResult;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => NotificationAppLaunchDetails(
    launchResponse != null,
    notificationResponse: launchResponse,
  );

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shownIds.add(id);
    payloads.add(payload);
    details.add(notificationDetails!);
  }

  @override
  Future<void> cancel({required int id}) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> dispose() async {}
}

import 'package:busymax/src/features/tray/domain/tray_presentation.dart';
import 'package:busymax/src/platform/windows/windows_tray_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const presentation = BusyMaxTrayMenuPresentation(
  showBusyMaxLabel: 'Open BusyMax',
  newEventLabel: 'New event',
  newTaskLabel: 'New task',
  todayLabel: 'Today',
  eventRows: [],
  taskSummaryLabel: null,
  emptyStateLabel: 'No events',
  openTodayAgendaLabel: 'Open today',
  syncNowLabel: 'Synchronize',
  synchronizationStatusLabel: 'Up to date',
  settingsLabel: 'Settings',
  quitBusyMaxLabel: 'Quit',
  offlineTitle: 'Offline',
  offlineDescription: '',
  canCreateEvent: false,
  canCreateTask: true,
  canSynchronize: true,
  offline: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('busymax/windows/tray');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> native(String method, [Object? arguments]) async {
    final reply = <ByteData?>[];
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      reply.add,
    );
    expect(reply, hasLength(1));
    const StandardMethodCodec().decodeEnvelope(reply.single!);
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'publishes native menu capabilities and routes commands by stable identity',
    () async {
      final calls = <MethodCall>[];
      final commands = <WindowsTrayCommand>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      final service = WindowsTrayService(
        loadPresentation: () async => presentation,
        onCommand: (command) async => commands.add(command),
      );
      addTearDown(service.stop);
      expect(await service.start(), isTrue);
      final rows =
          (calls.singleWhere((call) => call.method == 'setMenu').arguments
                  as List)
              .cast<Map>();
      final createEvent = rows.singleWhere((row) => row['key'] == 'new-event');
      final settings = rows.singleWhere((row) => row['key'] == 'settings');
      expect(createEvent['disabled'], isTrue);
      await native('command', createEvent['id']);
      expect(commands, isEmpty);
      await native('command', settings['id']);
      await native('open');
      expect(commands, [WindowsTrayCommand.settings, WindowsTrayCommand.open]);
      final path = calls.first.arguments as String;
      expect(
        path,
        endsWith('/data/flutter_assets/assets/windows/busymax_tray.ico'),
      );
      await service.refresh();
      final refreshed =
          (calls.lastWhere((call) => call.method == 'setMenu').arguments
                  as List)
              .cast<Map>();
      expect(
        refreshed.singleWhere((row) => row['key'] == 'settings')['id'],
        settings['id'],
      );
    },
  );

  test('Explorer recovery changes availability and exposes only bounded error codes', () async {
    final failures = <String?>[];
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final service = WindowsTrayService(
      loadPresentation: () async => presentation,
      onCommand: (_) async {},
      onUnavailable: (code) async => failures.add(code),
    );
    addTearDown(service.stop);
    expect(await service.start(), isTrue);
    await native('onTrayAvailabilityChanged', {
      'available': false,
      'errorCode': 'tray-add-failed',
    });
    expect(service.isAvailable, isFalse);
    expect(failures, ['tray-add-failed']);
    await native('onTrayAvailabilityChanged', {'available': true});
    expect(service.isAvailable, isTrue);
    expect(service.lastFailure, isNull);
    await native('onTrayAvailabilityChanged', {
      'available': false,
      'errorCode': 'C:/private/user',
    });
    expect(service.lastFailure, 'tray-native-recovery-failed');
  });

  test('failed native startup releases an installed icon without reporting success', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'setToolTip') {
        throw PlatformException(code: 'tray-tooltip-modify-failed');
      }
      return null;
    });
    final service = WindowsTrayService(
      loadPresentation: () async => presentation,
      onCommand: (_) async {},
    );
    addTearDown(service.stop);
    expect(await service.start(), isFalse);
    expect(service.isAvailable, isFalse);
    expect(calls, ['setIcon', 'setToolTip', 'destroy']);
  });
}

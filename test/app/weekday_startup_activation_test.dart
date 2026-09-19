import 'dart:async';
import 'dart:io';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/system_accent.dart';
import 'package:busymax/src/app/windows/windows_busymax_app.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in _TestPlatform.values) {
    group('${platform.name} root activation readiness', () {
      testWidgets(
        'retains ICS and webcal requests during delayed automatic startup',
        (tester) async {
          final native = _NativeWeekdayResponder(platform);
          final harness = await _RootHarness.mount(
            tester,
            platform: platform,
            native: native,
            signedIn: true,
          );
          addTearDown(harness.dispose);
          final fixture = await harness.writeIcs('delayed', uid: 'delayed');
          const subscription = 'webcal://calendar.example.test/delayed';

          harness.activate(
            DesktopActivation(
              kind: DesktopActivationKind.icsFile,
              value: fixture.path,
            ),
          );
          await harness.pumpFrames(3);
          expect(find.text(_importTitle), findsNothing);
          expect(_editable(subscription), findsNothing);

          native.succeed(DateTime.tuesday);
          await harness.pumpUntil(find.text(_importTitle));
          expect(find.text(_importTitle), findsOneWidget);
          expect(harness.effectiveFirstWeekday, DateTime.tuesday);
          expect(native.weekdayReads, 1);

          if (platform == _TestPlatform.windows) {
            harness.activate(
              const DesktopActivation(
                kind: DesktopActivationKind.notification,
                action: 'open',
                payload: {'notificationRoute': 'due-today'},
              ),
            );
            await harness.pumpFrames(1);
            expect(windowsAppRouter.state.uri.path, '/tasks');
          }

          if (find.text('Cancel').evaluate().isNotEmpty) {
            await harness.dismiss('Cancel');
          }
          harness.activate(
            const DesktopActivation(
              kind: DesktopActivationKind.webCal,
              value: subscription,
            ),
          );
          await harness.pumpUntil(_editable(subscription));
          expect(_editableValues(tester), contains(subscription));
          expect(_editable(subscription), findsOneWidget);
          await harness.dismiss('Cancel');
          await harness.pumpFrames(3);
          expect(find.text(_importTitle), findsNothing);
          expect(_editable(subscription), findsNothing);

          const afterStartup =
              'webcal://calendar.example.test/already-initialized';
          harness.activate(
            const DesktopActivation(
              kind: DesktopActivationKind.webCal,
              value: afterStartup,
            ),
          );
          await harness.pumpUntil(_editable(afterStartup));
          expect(_editableValues(tester), contains(afterStartup));
          expect(native.weekdayReads, 1);
          await harness.dismiss('Cancel');
          await harness.dispose();
        },
      );

      testWidgets('presents multiple startup requests once and in order', (
        tester,
      ) async {
        final native = _NativeWeekdayResponder(platform);
        final harness = await _RootHarness.mount(
          tester,
          platform: platform,
          native: native,
        );
        addTearDown(harness.dispose);
        const first = 'webcal://calendar.example.test/first';
        const second = 'webcal://calendar.example.test/second';

        harness.activate(
          const DesktopActivation(
            kind: DesktopActivationKind.webCal,
            value: first,
          ),
        );
        harness.activate(
          const DesktopActivation(
            kind: DesktopActivationKind.webCal,
            value: second,
          ),
        );
        await harness.pumpFrames(4);
        expect(_editable(first), findsNothing);
        expect(_editable(second), findsNothing);

        native.succeed(DateTime.saturday);
        await harness.pumpUntil(_editable(first));
        expect(_editableValues(tester), contains(first));
        expect(_editableValues(tester), isNot(contains(second)));
        await harness.dismiss('Cancel');

        await harness.pumpUntil(
          find.byWidgetPredicate(
            (widget) =>
                widget is EditableText && widget.controller.text == second,
          ),
        );
        expect(_editable(second), findsOneWidget);
        expect(_editableValues(tester), contains(second));
        await harness.dismiss('Cancel');
        await harness.pumpFrames(4);
        expect(_editable(first), findsNothing);
        expect(_editable(second), findsNothing);
        await harness.dispose();
      });

      for (final outcome in _FallbackOutcome.values) {
        testWidgets('processes a queued request after ${outcome.name}', (
          tester,
        ) async {
          final native = _NativeWeekdayResponder(platform);
          final harness = await _RootHarness.mount(
            tester,
            platform: platform,
            native: native,
          );
          addTearDown(harness.dispose);
          final url = 'webcal://calendar.example.test/${outcome.name}';

          harness.activate(
            DesktopActivation(kind: DesktopActivationKind.webCal, value: url),
          );
          await harness.pumpFrames(2);
          expect(_editable(url), findsNothing);
          switch (outcome) {
            case _FallbackOutcome.nativeUnavailable:
              native.succeed(null);
            case _FallbackOutcome.platformFailure:
              native.fail();
            case _FallbackOutcome.timeout:
              await tester.pump(const Duration(seconds: 2, milliseconds: 1));
          }

          await harness.pumpUntil(_editable(url));
          expect(_editableValues(tester), contains(url));
          expect(harness.effectiveFirstWeekday, DateTime.sunday);
          expect(native.weekdayReads, 1);
          await harness.dismiss('Cancel');
          await harness.dispose();
        });
      }

      testWidgets(
        'loads a persisted manual preference before skipping native readiness',
        (tester) async {
          final native = _NativeWeekdayResponder(platform);
          final settings = _DelayedSettingsStore();
          final harness = await _RootHarness.mount(
            tester,
            platform: platform,
            native: native,
            settingsStore: settings,
          );
          addTearDown(harness.dispose);
          const url = 'webcal://calendar.example.test/manual';

          harness.activate(
            const DesktopActivation(
              kind: DesktopActivationKind.webCal,
              value: url,
            ),
          );
          await harness.pumpFrames(3);
          expect(_editable(url), findsNothing);

          settings.complete({
            'firstDayOfWeekPreference': 'wednesday',
            'showTrayIcon': false,
            'runInBackgroundWhenClosed': false,
          });
          await harness.pumpUntil(_editable(url));
          expect(_editableValues(tester), contains(url));
          expect(harness.effectiveFirstWeekday, DateTime.wednesday);
          expect(native.isPending, isTrue);
          await harness.dismiss('Cancel');
          await harness.dispose();
        },
      );

      testWidgets('disposal cancels native and navigator-frame waits', (
        tester,
      ) async {
        final nativeWait = _NativeWeekdayResponder(platform);
        final first = await _RootHarness.mount(
          tester,
          platform: platform,
          native: nativeWait,
        );
        addTearDown(first.dispose);
        first.activate(
          const DesktopActivation(
            kind: DesktopActivationKind.webCal,
            value: 'webcal://calendar.example.test/dispose-native',
          ),
        );
        await first.pumpFrames(2);
        await first.removeApp();
        nativeWait.succeed(DateTime.friday);
        await first.pumpFrames(3);
        expect(find.text(_subscriptionTitle), findsNothing);
        expect(tester.takeException(), isNull);
        await first.dispose();

        final frameWait = _NativeWeekdayResponder(platform);
        final second = await _RootHarness.mount(
          tester,
          platform: platform,
          native: frameWait,
        );
        addTearDown(second.dispose);
        second.activate(
          const DesktopActivation(
            kind: DesktopActivationKind.webCal,
            value: 'webcal://calendar.example.test/dispose-frame',
          ),
        );
        frameWait.succeed(DateTime.thursday);
        await tester.idle();
        await second.removeApp();
        await second.pumpFrames(3);
        expect(find.text(_subscriptionTitle), findsNothing);
        expect(tester.takeException(), isNull);
        await second.dispose();
      });

      testWidgets('continues after the first flow takes its error path', (
        tester,
      ) async {
        final native = _NativeWeekdayResponder(platform)
          ..succeed(DateTime.monday);
        final harness = await _RootHarness.mount(
          tester,
          platform: platform,
          native: native,
          signedIn: true,
        );
        addTearDown(harness.dispose);
        final missing = '${harness.directory.path}/missing.ics';
        const next = 'webcal://calendar.example.test/after-error';

        harness.activate(
          DesktopActivation(
            kind: DesktopActivationKind.icsFile,
            value: missing,
          ),
        );
        harness.activate(
          const DesktopActivation(
            kind: DesktopActivationKind.webCal,
            value: next,
          ),
        );

        if (platform == _TestPlatform.windows) {
          await harness.pumpUntil(find.textContaining('Could not import'));
          expect(_editable(next), findsNothing);
          await harness.dismiss('Close');
        }
        await harness.pumpUntil(_editable(next));
        expect(_editableValues(tester), contains(next));
        if (platform == _TestPlatform.linux) {
          expect(find.textContaining('Could not import'), findsOneWidget);
        }
        await harness.dismiss('Cancel');
        await harness.dispose();
      });
    });
  }
}

const _importTitle = 'Import calendar events';
const _subscriptionTitle = 'Add calendar subscription';

enum _TestPlatform {
  linux('io.busystack.busymax/gtk_settings'),
  windows('busymax/windows_weekday');

  const _TestPlatform(this.weekdayChannel);
  final String weekdayChannel;
}

enum _FallbackOutcome { nativeUnavailable, platformFailure, timeout }

final class _RootHarness {
  _RootHarness._({
    required this.tester,
    required this.platform,
    required this.native,
    required this.database,
    required this.activations,
    required this.container,
    required this.directory,
    required this.networkMonitor,
  });

  final WidgetTester tester;
  final _TestPlatform platform;
  final _NativeWeekdayResponder native;
  final AppDatabase database;
  final _ActivationService activations;
  final ProviderContainer container;
  final Directory directory;
  final NetworkConnectivityMonitor networkMonitor;
  var _disposed = false;
  var _appMounted = true;

  static Future<_RootHarness> mount(
    WidgetTester tester, {
    required _TestPlatform platform,
    required _NativeWeekdayResponder native,
    LocalSettingsStore? settingsStore,
    bool signedIn = false,
  }) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      platform.weekdayChannel,
      native.handleMessage,
    );
    if (platform == _TestPlatform.linux) {
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window'),
        (call) async => call.method == 'state' ? <String, Object?>{} : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window/events'),
        (call) async => null,
      );
    }
    late Directory directory;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp(
        'busymax-weekday-activation-',
      );
    });
    final database = AppDatabase.memoryForTests();
    final activations = _ActivationService();
    final networkMonitor =
        NetworkConnectivityMonitor.withoutPlatformObservation();
    final initialSettings = settingsStore == null
        ? AppSettings.defaults().copyWith(
            showTrayIcon: false,
            runInBackgroundWhenClosed: false,
          )
        : null;
    final overrides = <Override>[
      buildConfigProvider.overrideWithValue(_missingConfig),
      databaseProvider.overrideWithValue(database),
      if (initialSettings != null)
        initialAppSettingsProvider.overrideWithValue(initialSettings),
      localSettingsStoreProvider.overrideWithValue(
        settingsStore ?? MemorySettingsStore(),
      ),
      desktopActivationServiceProvider.overrideWithValue(activations),
      desktopWindowServiceProvider.overrideWithValue(
        const NoOpDesktopWindowService(),
      ),
      networkConnectivityMonitorProvider.overrideWithValue(networkMonitor),
      networkAvailabilityProvider.overrideWith(
        (ref) => Stream.value(NetworkAvailability.online),
      ),
      authSessionControllerProvider.overrideWith(
        (ref) => signedIn ? _SignedInController() : _SignedOutController(),
      ),
      if (platform == _TestPlatform.linux) ...[
        gtkFontSettingsProvider.overrideWith((ref) => Stream.value(null)),
        gtkThemeColorsProvider.overrideWith((ref) => Stream.value(null)),
        ubuntuSystemAccentColorProvider.overrideWith(
          (ref) => const Stream<Color>.empty(),
        ),
      ],
      if (platform == _TestPlatform.windows)
        systemAppearanceSourceProvider.overrideWithValue(const _Appearance()),
    ];
    final container = ProviderContainer(overrides: overrides);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.localeTestValue = const Locale(
      'en',
      'US',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: platform == _TestPlatform.linux
            ? const LinuxBusyMaxApp()
            : const WindowsBusyMaxApp(),
      ),
    );
    await tester.pump();
    return _RootHarness._(
      tester: tester,
      platform: platform,
      native: native,
      database: database,
      activations: activations,
      container: container,
      directory: directory,
      networkMonitor: networkMonitor,
    );
  }

  int get effectiveFirstWeekday {
    final context = platform == _TestPlatform.linux
        ? rootNavigatorKey.currentContext
        : windowsRootNavigatorKey.currentContext;
    expect(context, isNotNull);
    return BusyMaxWeekPreferencesScope.firstWeekdayOf(context!);
  }

  void activate(DesktopActivation activation) => activations.add(activation);

  Future<File> writeIcs(String name, {required String uid}) async {
    final fixture = File('${directory.path}/$name.ics');
    await tester.runAsync(
      () => fixture.writeAsString(_validIcs.replaceFirst('TEST_UID', uid)),
    );
    return fixture;
  }

  Future<void> pumpFrames(int count) async {
    for (var index = 0; index < count; index += 1) {
      await tester.pump();
    }
  }

  Future<void> pumpUntil(Finder finder) async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finder, findsWidgets, reason: 'Timed out waiting for $finder');
  }

  Future<void> dismiss(String label) async {
    final button = find.text(label);
    expect(button, findsWidgets);
    await tester.tap(button.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> removeApp() async {
    if (!_appMounted) return;
    _appMounted = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await removeApp();
    container.dispose();
    native.finishPending();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(platform.weekdayChannel, null);
    if (platform == _TestPlatform.linux) {
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window/events'),
        null,
      );
    }
    await tester.runAsync(() async {
      await activations.dispose();
      await networkMonitor.dispose();
      await database.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.binding.platformDispatcher.clearLocaleTestValue();
  }
}

final class _NativeWeekdayResponder {
  _NativeWeekdayResponder(this.platform);

  final _TestPlatform platform;
  final _response = Completer<ByteData?>();
  static const _codec = StandardMethodCodec();
  var weekdayReads = 0;

  bool get isPending => !_response.isCompleted;

  Future<ByteData?> handleMessage(ByteData? message) {
    final call = _codec.decodeMethodCall(message);
    if (call.method == 'getFirstWeekday') {
      weekdayReads += 1;
      return _response.future;
    }
    return Future.value(_codec.encodeSuccessEnvelope(null));
  }

  void succeed(int? weekday) {
    if (!_response.isCompleted) {
      _response.complete(_codec.encodeSuccessEnvelope(weekday));
    }
  }

  void fail() {
    if (!_response.isCompleted) {
      _response.complete(
        _codec.encodeErrorEnvelope(
          code: 'native-failure',
          message: '${platform.name} weekday unavailable',
        ),
      );
    }
  }

  void finishPending() => succeed(null);
}

final class _ActivationService implements DesktopActivationService {
  final _controller = StreamController<DesktopActivation>.broadcast();

  void add(DesktopActivation activation) => _controller.add(activation);

  @override
  Stream<DesktopActivation> get activations => _controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() => _controller.close();
}

final class _SignedOutController extends StateNotifier<AuthSessionState>
    implements AuthSessionController {
  _SignedOutController() : super(const AuthSessionState.signedOut());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SignedInController extends StateNotifier<AuthSessionState>
    implements AuthSessionController {
  _SignedInController()
    : super(const AuthSessionState.signedIn('test-account'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Appearance implements SystemAppearanceSource {
  const _Appearance();

  @override
  Color? get accentColor => null;

  @override
  Brightness get brightness => Brightness.light;

  @override
  bool get highContrast => false;

  @override
  Stream<void> get changes => const Stream.empty();
}

final class _DelayedSettingsStore implements LocalSettingsStore {
  final _load = Completer<Map<String, Object?>>();

  void complete(Map<String, Object?> settings) => _load.complete(settings);

  @override
  Future<Map<String, Object?>> load() => _load.future;

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

List<String> _editableValues(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .map((widget) => widget.controller.text)
    .toList(growable: false);

Finder _editable(String value) => find.byWidgetPredicate(
  (widget) => widget is EditableText && widget.controller.text == value,
);

const _missingConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  oauthAuthorizationEndpoint: 'https://example.test/authorize',
  oauthTokenEndpoint: 'https://example.test/token',
  oauthRevocationEndpoint: 'https://example.test/revoke',
);

const _validIcs = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:TEST_UID@example.test\r
DTSTART:20261001T090000Z\r
DTEND:20261001T100000Z\r
SUMMARY:Startup activation\r
END:VEVENT\r
END:VCALENDAR\r
''';

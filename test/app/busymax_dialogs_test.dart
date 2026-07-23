import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialogs.dart';
import 'package:busymax/src/app/busymax_shortcuts.dart';
import 'package:busymax/src/platform/linux_header_bar_provider.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeDialogChannel = MethodChannel(nativeDialogChannelName);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeDialogChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeDialogChannel, null);
  });

  testWidgets('confirmation uses the native host when available', (
    tester,
  ) async {
    const channel = MethodChannel('busymax_test/native_confirmation');
    const headerChannel = MethodChannel(
      'busymax_test/native_confirmation_header',
    );
    final calls = <MethodCall>[];
    final headerCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(headerChannel, (call) async {
          headerCalls.add(call);
          return call.method == 'initialize' ? true : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(headerChannel, null);
    });
    final headerBarService = LinuxHeaderBarService(
      channel: headerChannel,
      isLinux: true,
    );
    addTearDown(headerBarService.dispose);
    await headerBarService.initialize();

    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = showBusyMaxConfirm(
      hostContext,
      title: 'Discard changes?',
      message: 'Unsaved changes will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
      headerBarService: headerBarService,
      nativeDialogService: const NativeDialogService(channel: channel),
    );
    await tester.pump();

    expect(await result, isTrue);
    expect(find.byType(BusyMaxConfirmDialog), findsNothing);
    expect(calls.single.method, 'confirm');
    expect(
      headerCalls.where((call) => call.method == 'setModalBarrierVisible'),
      isEmpty,
    );
  });

  testWidgets('modal coordinator synchronizes the native barrier', (
    tester,
  ) async {
    const channel = MethodChannel('busymax_test/modal_barrier');
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

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    await service.initialize();

    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = showBusyMaxConfirm(
      hostContext,
      title: 'Remove item?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
      headerBarService: service,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    expect(
      calls.where((call) => call.method == 'setModalBarrierVisible'),
      hasLength(1),
    );
    expect(calls.last.arguments, isTrue);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    final barrierCalls = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCalls, hasLength(2));
    expect(barrierCalls.first.arguments, isTrue);
    expect(barrierCalls.last.arguments, isFalse);
  });

  testWidgets('nested modals keep the native barrier active', (tester) async {
    const channel = MethodChannel('busymax_test/nested_modal_barrier');
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

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    await service.initialize();

    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final first = showBusyMaxModalDialog<void>(
      hostContext,
      headerBarService: service,
      builder: (context) => const Dialog(child: Text('First dialog')),
    );
    await tester.pumpAndSettle();
    final second = showBusyMaxModalDialog<void>(
      hostContext,
      headerBarService: service,
      builder: (context) => const Dialog(child: Text('Second dialog')),
    );
    await tester.pumpAndSettle();

    expect(
      calls.where((call) => call.method == 'setModalBarrierVisible'),
      hasLength(1),
    );

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await second;
    expect(
      calls.where((call) => call.method == 'setModalBarrierVisible'),
      hasLength(1),
    );

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await first;

    final barrierCalls = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCalls, hasLength(2));
    expect(barrierCalls.last.arguments, isFalse);
  });

  testWidgets('modal coordinator resolves the service from ProviderScope', (
    tester,
  ) async {
    const channel = MethodChannel('busymax_test/automatic_modal_barrier');
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

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    await service.initialize();
    late BuildContext hostContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [linuxHeaderBarServiceProvider.overrideWithValue(service)],
        child: localizedTestApp(
          child: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final result = showBusyMaxConfirm(
      hostContext,
      title: 'Remove item?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Remove',
    );
    await tester.pumpAndSettle();

    expect(calls.first.method, 'initialize');
    expect(
      calls
          .where((call) => call.method == 'setModalBarrierVisible')
          .single
          .arguments,
      isTrue,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
    final barrierCalls = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCalls.last.arguments, isFalse);
  });

  testWidgets('editor dialog requires an explicit cancel action', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = showBusyMaxModalEditorDialog<String>(
      hostContext,
      builder: (dialogContext) => SizedBox(
        width: 320,
        height: 200,
        child: Center(
          child: TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancelled'),
            child: const Text('Cancel editor'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('Cancel editor'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Cancel editor'), findsOneWidget);

    await tester.tap(find.text('Cancel editor'));
    await tester.pumpAndSettle();
    expect(await result, 'cancelled');
  });

  testWidgets('text prompt preserves input until an explicit action', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = showBusyMaxTextPrompt(
      hostContext,
      title: 'Rename item',
      label: 'Name',
      actionLabel: 'Rename',
      initialValue: 'Draft name',
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Edited name');
    await tester.tapAt(const Offset(2, 2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Rename item'), findsOneWidget);
    expect(find.text('Edited name'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('modal shortcut boundary blocks application navigation', (
    tester,
  ) async {
    var applicationNavigationCount = 0;
    await tester.pumpWidget(
      localizedTestApp(
        child: Shortcuts(
          shortcuts: const {
            BusyMaxShortcutActivators.settings: _ApplicationNavigationIntent(),
            BusyMaxShortcutActivators.keyboardShortcuts:
                _ApplicationNavigationIntent(),
          },
          child: Actions(
            actions: {
              _ApplicationNavigationIntent:
                  CallbackAction<_ApplicationNavigationIntent>(
                    onInvoke: (_) {
                      applicationNavigationCount += 1;
                      return null;
                    },
                  ),
            },
            child: const BusyMaxModalShortcutBoundary(
              child: Material(child: TextField(autofocus: true)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final key in [LogicalKeyboardKey.comma, LogicalKeyboardKey.slash]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    expect(applicationNavigationCount, 0);
  });
}

class _ApplicationNavigationIntent extends Intent {
  const _ApplicationNavigationIntent();
}

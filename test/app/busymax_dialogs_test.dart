import 'dart:async';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialogs.dart';
import 'package:busymax/src/app/busymax_shortcuts.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/linux_header_bar_provider.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

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

  testWidgets(
    'prompt action header and confirmation title bar use the dialog surface',
    (tester) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: Brightness.dark,
        accentColor: const Color(0xFFE95420),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;
      expect(colors.window, isNot(colors.dialog));

      await tester.pumpWidget(
        localizedTestApp(
          theme: theme,
          child: const BusyMaxPromptDialog(
            title: 'Rename calendar',
            label: 'Name',
            actionLabel: 'Rename',
          ),
        ),
      );

      expect(find.byType(BusyMaxEditorHeader), findsOneWidget);
      expect(find.byType(YaruDialogTitleBar), findsNothing);
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, colors.dialog);
      expect(dialog.surfaceTintColor, colors.dialog);

      await tester.pumpWidget(
        localizedTestApp(
          theme: theme,
          child: const BusyMaxConfirmDialog(
            title: 'Discard changes?',
            message: 'Unsaved changes will be lost.',
            confirmLabel: 'Discard',
            destructive: true,
          ),
        ),
      );

      final titleBar = tester.widget<YaruDialogTitleBar>(
        find.byType(YaruDialogTitleBar),
      );
      final confirmation = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final titleBarTheme = Theme.of(
        tester.element(find.byType(YaruDialogTitleBar)),
      ).appBarTheme;
      final cancelButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Cancel'),
      );
      final discardButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Discard'),
      );
      final standardShape =
          theme.filledButtonTheme.style!.shape!.resolve({})!
              as RoundedRectangleBorder;
      final destructiveShape =
          theme.elevatedButtonTheme.style!.shape!.resolve({})!
              as RoundedRectangleBorder;
      expect(titleBar.backgroundColor, colors.dialog);
      expect(titleBar.border, BorderSide.none);
      expect(titleBarTheme.backgroundColor, colors.dialog);
      expect(titleBarTheme.surfaceTintColor, colors.dialog);
      expect(titleBarTheme.shadowColor, Colors.transparent);
      expect(confirmation.backgroundColor, colors.dialog);
      expect(confirmation.surfaceTintColor, colors.dialog);
      expect(cancelButton.style, isNull);
      expect(discardButton.style?.shape?.resolve({}), isNull);
      expect(
        standardShape.borderRadius,
        BorderRadius.circular(kYaruButtonRadius),
      );
      expect(
        destructiveShape.borderRadius,
        BorderRadius.circular(kYaruButtonRadius),
      );
    },
  );

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

  testWidgets('confirmation fallback scrolls in a short window at 2x text', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(480, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const message =
        'Unsaved changes will be permanently discarded. '
        'This cannot be undone, and any edits made since the last save will '
        'be lost. Review the warning carefully before choosing an action.';
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const BusyMaxConfirmDialog(
              title: 'Discard all unsaved changes?',
              message: message,
              confirmLabel: 'Discard changes',
              destructive: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final scrollView = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollView, findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    await tester.drag(scrollView, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Discard changes'), findsOneWidget);
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

  testWidgets('serializes rapid manual native barrier transitions', (
    tester,
  ) async {
    const channel = MethodChannel('busymax_test/serialized_modal_barrier');
    final firstUpdate = Completer<void>();
    final transitions = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') {
            return true;
          }
          if (call.method == 'setModalBarrierVisible') {
            transitions.add(call.arguments! as bool);
            if (transitions.length == 1) {
              await firstUpdate.future;
            }
          }
          return null;
        });
    addTearDown(() {
      if (!firstUpdate.isCompleted) {
        firstUpdate.complete();
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    await service.initialize();

    final acquire = acquireBusyMaxModalBarrier(service);
    await tester.pump();
    expect(transitions, [true]);

    final release = releaseBusyMaxModalBarrier(service);
    await tester.pump();
    expect(
      transitions,
      [true],
      reason: 'the native hide must wait for the in-flight native show',
    );

    firstUpdate.complete();
    await Future.wait([acquire, release]);

    expect(transitions, [true, false]);
  });

  testWidgets('failed native barrier acquisition rolls back and can retry', (
    tester,
  ) async {
    final service = _FailingModalBarrierService();
    addTearDown(service.dispose);

    await expectLater(
      acquireBusyMaxModalBarrier(service),
      throwsA(isA<StateError>()),
    );
    expect(
      service.transitions,
      [true, false],
      reason: 'a failed native show requires a best-effort native rollback',
    );

    await acquireBusyMaxModalBarrier(service);
    await releaseBusyMaxModalBarrier(service);

    expect(service.transitions, [true, false, true, false]);
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

  testWidgets(
    'text prompt uses the shared grouped input and selects its value',
    (tester) async {
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
        message: 'Choose a distinctive name.',
      );
      await tester.pumpAndSettle();

      expect(find.byType(BusyMaxGroupedList), findsOneWidget);
      expect(find.text('Choose a distinctive name.'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Draft name');
      expect(
        textField.controller?.selection,
        const TextSelection(baseOffset: 0, extentOffset: 10),
      );
      expect(textField.decoration?.labelText, 'Name');
      expect(textField.decoration?.filled, isFalse);
      expect(textField.decoration?.border, InputBorder.none);
      expect(find.byType(BusyMaxEditorHeader), findsOneWidget);
      expect(find.byType(YaruDialogTitleBar), findsNothing);
      expect(find.byType(OverflowBar), findsNothing);
      final inputGroupRect = tester.getRect(find.byType(BusyMaxGroupedList));
      final cancelRect = tester.getRect(
        find.widgetWithText(FilledButton, 'Cancel'),
      );
      final renameRect = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Rename'),
      );
      expect(cancelRect.bottom, lessThan(inputGroupRect.top));
      expect(renameRect.bottom, lessThan(inputGroupRect.top));

      await tester.enterText(find.byType(TextField), 'Edited name');
      await tester.tapAt(const Offset(2, 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Rename item'), findsOneWidget);
      expect(find.text('Edited name'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    },
  );

  testWidgets(
    'text prompt rejects blank input and submits valid text on Enter',
    (tester) async {
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
      );
      await tester.pumpAndSettle();

      final renameButton = find.widgetWithText(ElevatedButton, 'Rename');
      expect(tester.widget<ElevatedButton>(renameButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(renameButton).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(BusyMaxPromptDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(renameButton).onPressed, isNotNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(await result, 'Work');
      expect(find.byType(BusyMaxPromptDialog), findsNothing);
    },
  );

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

class _FailingModalBarrierService extends LinuxHeaderBarService {
  _FailingModalBarrierService() : super(isLinux: false);

  final transitions = <bool>[];
  var _failNextShow = true;

  @override
  Future<void> setModalBarrierVisible(bool value) async {
    transitions.add(value);
    if (value && _failNextShow) {
      _failNextShow = false;
      throw StateError('simulated native response failure');
    }
  }
}

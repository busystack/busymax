import 'dart:async';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialogs.dart';
import 'package:busymax/src/app/busymax_shortcuts.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      final confirmation = tester.widget<Dialog>(find.byType(Dialog));
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
      expect(confirmation.clipBehavior, Clip.antiAlias);
      expect(find.byType(BusyMaxDialogShell), findsOneWidget);
      expect(cancelButton.style, isNull);
      expect(discardButton.style?.shape?.resolve({}), isNull);
      expect(
        theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
        colors.control,
      );
      expect(
        discardButton.style?.backgroundColor?.resolve({}),
        theme.colorScheme.error,
      );
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

  testWidgets('modal route blocks the complete application surface', (
    tester,
  ) async {
    var backgroundActivations = 0;
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return TextButton(
                onPressed: () => backgroundActivations += 1,
                child: const Text('Background action'),
              );
            },
          ),
        ),
      ),
    );

    final result = showBusyMaxModalDialog<bool>(
      hostContext,
      barrierDismissible: false,
      builder: (_) => const BusyMaxConfirmDialog(
        title: 'Remove item?',
        message: 'This action cannot be undone.',
        confirmLabel: 'Remove',
        destructive: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    expect(find.byType(AnimatedModalBarrier), findsOneWidget);
    await tester.tap(find.text('Background action'), warnIfMissed: false);
    await tester.pump();
    expect(backgroundActivations, 0);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.byType(AnimatedModalBarrier), findsNothing);
  });

  testWidgets('open modal barrier follows live theme changes', (tester) async {
    const accent = Color(0xFF3584E4);
    final lightTheme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: accent,
    );
    final darkTheme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: accent,
    );
    final themeMode = ValueNotifier(ThemeMode.light);
    addTearDown(themeMode.dispose);
    late BuildContext hostContext;

    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: themeMode,
        builder: (context, mode, child) {
          return MaterialApp(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );

    final result = showBusyMaxModalDialog<void>(
      hostContext,
      builder: (context) => const Dialog(child: Text('Theme-aware dialog')),
    );
    await tester.pumpAndSettle();

    Color? currentBarrierColor() {
      return tester
          .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier).last)
          .color
          .value;
    }

    expect(
      currentBarrierColor(),
      lightTheme.extension<BusyMaxSurfaceColors>()!.shade,
    );

    themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();

    expect(
      currentBarrierColor(),
      darkTheme.extension<BusyMaxSurfaceColors>()!.shade,
    );

    themeMode.value = ThemeMode.light;
    await tester.pumpAndSettle();

    expect(
      currentBarrierColor(),
      lightTheme.extension<BusyMaxSurfaceColors>()!.shade,
    );

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await result;
  });

  testWidgets('confirmation scrolls in a short window at 2x text', (
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
      of: find.byType(BusyMaxDialogShell),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollView, findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(BusyMaxDialogShell),
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

  testWidgets('nested modals retain independent local barriers', (
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

    final first = showBusyMaxModalDialog<void>(
      hostContext,
      builder: (context) => const Dialog(child: Text('First dialog')),
    );
    await tester.pumpAndSettle();
    final second = showBusyMaxModalDialog<void>(
      hostContext,
      barrierColor: Colors.transparent,
      builder: (context) => const Dialog(child: Text('Second dialog')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedModalBarrier), findsOneWidget);
    expect(find.text('First dialog'), findsOneWidget);
    expect(find.text('Second dialog'), findsOneWidget);

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await second;
    expect(find.byType(AnimatedModalBarrier), findsOneWidget);
    expect(find.text('First dialog'), findsOneWidget);

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await first;
    expect(find.byType(AnimatedModalBarrier), findsNothing);
  });

  testWidgets('modal future completes only after route removal', (
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

    var completed = false;
    final result = showBusyMaxModalDialog<void>(
      hostContext,
      builder: (dialogContext) => Dialog(
        child: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close route'),
        ),
      ),
    );
    unawaited(result.then((_) => completed = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close route'));
    await tester.pump();
    expect(completed, isFalse);
    expect(find.byType(AnimatedModalBarrier), findsOneWidget);
    await tester.pumpAndSettle();

    await result;
    expect(completed, isTrue);
    expect(find.byType(AnimatedModalBarrier), findsNothing);
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
            BusyMaxShortcutActivators.back: _ApplicationNavigationIntent(),
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

    for (final key in [LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyK]) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

    expect(applicationNavigationCount, 0);
  });

  testWidgets('closing the final modal restores the previous focus', (
    tester,
  ) async {
    final hostFocus = FocusNode();
    final dialogFocus = FocusNode();
    addTearDown(hostFocus.dispose);
    addTearDown(dialogFocus.dispose);
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return Scaffold(
              body: TextField(focusNode: hostFocus, autofocus: true),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(hostFocus.hasFocus, isTrue);

    final result = showBusyMaxModalDialog<void>(
      hostContext,
      builder: (dialogContext) => BusyMaxDialogShell(
        title: 'Keep editing?',
        actions: [
          BusyMaxPushButton.standard(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
        children: [TextField(focusNode: dialogFocus, autofocus: true)],
      ),
    );
    await tester.pumpAndSettle();
    expect(hostFocus.hasFocus, isFalse);
    expect(dialogFocus.hasFocus, isTrue);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await result;
    expect(hostFocus.hasFocus, isTrue);
  });
}

class _ApplicationNavigationIntent extends Intent {
  const _ApplicationNavigationIntent();
}

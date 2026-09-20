import 'dart:io';
import 'dart:ui';

import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _accent = Color(0xFF8B5CF6);

void main() {
  test('standard and suggested roles resolve the complete Ubuntu contract', () {
    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        final theme = _theme(
          brightness: brightness,
          highContrast: highContrast,
        );
        final colors = theme.extension<BusyMaxSurfaceColors>()!;
        final standard = theme.filledButtonTheme.style!;
        final suggested = theme.elevatedButtonTheme.style!;
        final disabledHover = {WidgetState.disabled, WidgetState.hovered};

        for (final style in [standard, suggested]) {
          expect(
            style.padding?.resolve({}),
            const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
          );
          expect(style.minimumSize?.resolve({}), const Size(34, 34));
          expect(style.textStyle?.resolve({})?.fontFamily, 'Ubuntu Sans');
          expect(style.textStyle?.resolve({})?.fontWeight, FontWeight.bold);
          expect(style.visualDensity, VisualDensity.standard);
          expect(style.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
          expect(style.elevation?.resolve({WidgetState.pressed}), 0);
          expect(style.shadowColor?.resolve({}), Colors.transparent);
          expect(style.surfaceTintColor?.resolve({}), Colors.transparent);
          expect(
            style.overlayColor?.resolve({WidgetState.hovered}),
            Colors.transparent,
          );
          expect(style.splashFactory, NoSplash.splashFactory);
          expect(style.backgroundBuilder, isNotNull);
          final shape = style.shape?.resolve({})! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(BusyMaxRadius.sm));
        }

        expect(standard.foregroundColor?.resolve({}), colors.foreground);
        expect(standard.backgroundColor?.resolve({}), colors.control);
        expect(
          standard.backgroundColor?.resolve({WidgetState.hovered}),
          colors.controlHover,
        );
        expect(
          standard.backgroundColor?.resolve({WidgetState.pressed}),
          colors.controlActive,
        );
        expect(
          standard.backgroundColor?.resolve(disabledHover),
          colors.disabledControl,
        );

        final accent = theme.colorScheme.primary;
        final onAccent = theme.colorScheme.onPrimary;
        expect(suggested.foregroundColor?.resolve({}), onAccent);
        expect(suggested.backgroundColor?.resolve({}), accent);
        expect(
          suggested.backgroundColor?.resolve({WidgetState.hovered}),
          Color.alphaBlend(onAccent.withValues(alpha: 0.10), accent),
        );
        expect(
          suggested.backgroundColor?.resolve({WidgetState.pressed}),
          Color.alphaBlend(Colors.black.withValues(alpha: 0.20), accent),
        );
        expect(
          suggested.backgroundColor?.resolve({
            WidgetState.focused,
            WidgetState.pressed,
          }),
          suggested.backgroundColor?.resolve({WidgetState.pressed}),
        );
        expect(
          suggested.backgroundColor?.resolve(disabledHover),
          colors.disabledControl,
        );
      }
    }
  });

  testWidgets('destructive role shares geometry and owns every color state', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        late BuildContext buttonContext;
        final theme = _theme(
          brightness: brightness,
          highContrast: highContrast,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                buttonContext = context;
                return BusyMaxPushButton.destructive(
                  context: context,
                  onPressed: () {},
                  child: const Text('Delete'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final widget = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final style = widget.style!.merge(theme.elevatedButtonTheme.style);
        final colors = theme.extension<BusyMaxSurfaceColors>()!;
        final error = theme.colorScheme.error;
        final onError = theme.colorScheme.onError;
        expect(buttonContext, isNotNull);
        expect(
          style.padding?.resolve({}),
          const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
        );
        expect(style.minimumSize?.resolve({}), const Size(34, 34));
        expect(style.textStyle?.resolve({})?.fontWeight, FontWeight.bold);
        expect(style.foregroundColor?.resolve({}), onError);
        expect(style.backgroundColor?.resolve({}), error);
        expect(
          style.backgroundColor?.resolve({WidgetState.hovered}),
          Color.alphaBlend(onError.withValues(alpha: 0.10), error),
        );
        expect(
          style.backgroundColor?.resolve({WidgetState.pressed}),
          Color.alphaBlend(Colors.black.withValues(alpha: 0.20), error),
        );
        expect(
          style.backgroundColor?.resolve({
            WidgetState.disabled,
            WidgetState.pressed,
          }),
          colors.disabledControl,
        );
        expect(
          style.overlayColor?.resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        expect(style.backgroundBuilder, isNotNull);
      }
    }
  });

  testWidgets(
    'rendered button has stable layout and whole-control focus ring',
    (tester) async {
      final previousStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy = previousStrategy;
      });
      final states = WidgetStatesController();
      addTearDown(states.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(brightness: Brightness.dark),
          home: Center(
            child: BusyMaxPushButton.standard(
              key: const ValueKey('button'),
              statesController: states,
              onPressed: () {},
              child: const Text('Action'),
            ),
          ),
        ),
      );

      final button = find.byKey(const ValueKey('button'));
      final restingSize = tester.getSize(button);
      final restingRect = tester.getRect(button);
      for (final state in [
        WidgetState.hovered,
        WidgetState.pressed,
        WidgetState.focused,
      ]) {
        states.value = {state};
        await tester.pump();
        expect(tester.getSize(button), restingSize);
        expect(tester.getRect(button), restingRect);
      }

      final decoration = _focusDecoration(tester, button);
      final border = decoration.border! as Border;
      expect(border.top.width, 2);
      expect(border.top.strokeAlign, BorderSide.strokeAlignInside);
      expect(border.top.color.a, closeTo(0.50, 0.001));
      expect(decoration.borderRadius, BorderRadius.circular(BusyMaxRadius.sm));

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      states.value = {};
      await tester.pump();
      states.value = {WidgetState.focused};
      await tester.pump();
      expect(_focusBorder(tester, button).top.color, Colors.transparent);
    },
  );

  testWidgets(
    'real hover, press, focus, and keyboard activation are preserved',
    (tester) async {
      final previousStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy = previousStrategy;
      });
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(brightness: Brightness.light),
          home: Scaffold(
            body: Center(
              child: BusyMaxPushButton.standard(
                autofocus: true,
                onPressed: () => activations += 1,
                child: const Text('Activate'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final button = find.byType(FilledButton);
      expect(_focusBorder(tester, button).top.color.a, closeTo(0.50, 0.001));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      final colors = _theme(
        brightness: Brightness.light,
      ).extension<BusyMaxSurfaceColors>()!;
      expect(_buttonMaterial(tester, button).color, colors.controlHover);

      await mouse.down(tester.getCenter(button));
      await tester.pump();
      expect(_buttonMaterial(tester, button).color, colors.controlActive);
      await mouse.up();
      await tester.pump();
      expect(activations, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activations, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(activations, 3);
    },
  );

  testWidgets('disabled action exposes no activation semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(brightness: Brightness.light),
        home: const Center(
          child: FilledButton(onPressed: null, child: Text('Disabled')),
        ),
      ),
    );

    final data = tester.getSemantics(find.byType(FilledButton));
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets(
    'editor header actions match shared buttons and loading is stable',
    (tester) async {
      Future<
        ({Size cancel, Size save, TextStyle cancelText, TextStyle saveText})
      >
      measure({required bool saving}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: _theme(brightness: Brightness.dark),
            home: Column(
              children: [
                BusyMaxEditorHeader(
                  title: 'Editor',
                  cancelLabel: 'Cancel',
                  saveLabel: 'Save changes',
                  onCancel: () {},
                  onSave: () {},
                  saving: saving,
                ),
                BusyMaxPushButton.standard(
                  key: const ValueKey('ordinary-cancel'),
                  onPressed: () {},
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        final cancel = find.widgetWithText(FilledButton, 'Cancel').first;
        final save = find.byType(ElevatedButton).first;
        final cancelText = tester.widget<RichText>(
          find.descendant(of: cancel, matching: find.byType(RichText)).first,
        );
        final saveText = tester.widget<RichText>(
          find.descendant(of: save, matching: find.byType(RichText)).first,
        );
        return (
          cancel: tester.getSize(cancel),
          save: tester.getSize(save),
          cancelText: cancelText.text.style!,
          saveText: saveText.text.style!,
        );
      }

      final resting = await measure(saving: false);
      final loading = await measure(saving: true);
      expect(resting.cancel.height, 34);
      expect(resting.save.height, 34);
      expect(resting.cancelText.fontWeight, FontWeight.bold);
      expect(resting.saveText.fontWeight, FontWeight.bold);
      expect(resting.cancelText.fontSize, resting.saveText.fontSize);
      expect(loading.save, resting.save);
      expect(find.text('Save changes'), findsOneWidget);
    },
  );

  testWidgets('mounted button follows live accent and GTK font changes', (
    tester,
  ) async {
    ThemeData liveTheme(Color accent, String font) => buildBusyMaxTheme(
      brightness: Brightness.dark,
      accentColor: accent,
      gtkFontFamily: font,
      gtkFontSize: 11,
    );

    final theme = ValueNotifier(
      liveTheme(const Color(0xFF7C4DFF), 'First GTK Sans'),
    );
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeData>(
        valueListenable: theme,
        builder: (context, value, child) => MaterialApp(
          theme: value,
          home: Center(
            child: BusyMaxPushButton.suggested(
              onPressed: () {},
              child: const Text('Live action'),
            ),
          ),
        ),
      ),
    );

    final button = find.byType(ElevatedButton);
    expect(_buttonMaterial(tester, button).color, const Color(0xFF7C4DFF));
    expect(
      _buttonText(tester, button).text.style?.fontFamily,
      'First GTK Sans',
    );

    theme.value = liveTheme(const Color(0xFF2E7D32), 'Second GTK Sans');
    await tester.pumpAndSettle();
    expect(_buttonMaterial(tester, button).color, const Color(0xFF2E7D32));
    expect(
      _buttonText(tester, button).text.style?.fontFamily,
      'Second GTK Sans',
    );
  });

  testWidgets('long RTL labels grow under text scaling without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(brightness: Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: BusyMaxEditorHeader(
          title: 'Editor',
          cancelLabel: 'Cancel all pending changes',
          saveLabel: 'Save every pending change',
          onCancel: () {},
          onSave: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThan(34));
    expect(tester.getSize(find.byType(ElevatedButton)).height, greaterThan(34));
  });

  test('Linux action call sites do not bypass the shared push-button role', () {
    final rawFeatureButtons = <String, List<String>>{};
    final constructor = RegExp(
      r'\b(TextButton|FilledButton|ElevatedButton|OutlinedButton)\s*\(',
    );
    for (final entity in Directory(
      'lib/src/features',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll('\\', '/');
      final matches = constructor
          .allMatches(entity.readAsStringSync())
          .map((match) => match.group(1)!)
          .toList();
      if (matches.isNotEmpty) {
        rawFeatureButtons[path] = matches;
      }
    }

    // These are intentionally specialized calendar cells/navigation labels,
    // a month-overflow command, and a time-period selector. Any new raw
    // feature-level constructor must be reviewed against the action roles.
    expect(rawFeatureButtons, {
      'lib/src/features/schedule/presentation/mini_calendar.dart': [
        'TextButton',
        'TextButton',
      ],
      'lib/src/features/schedule/presentation/schedule_month_view.dart': [
        'TextButton',
      ],
      'lib/src/features/tasks/presentation/desktop_date_time_fields.dart': [
        'TextButton',
      ],
    });

    // These two formerly raw commands are ordinary actions.
    final eventEditor = File(
      'lib/src/features/calendar/presentation/event_editor.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/src/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();
    expect(
      eventEditor,
      contains(
        'BusyMaxPushButton.standard(\n                onPressed: () => showLinuxNextcloudSchedulingDialog',
      ),
    );
    expect(
      settings,
      contains(
        'BusyMaxPushButton.standard(\n                          onPressed: () =>',
      ),
    );
  });
}

ThemeData _theme({required Brightness brightness, bool highContrast = false}) {
  return buildBusyMaxTheme(
    brightness: brightness,
    accentColor: _accent,
    gtkFontFamily: 'Ubuntu Sans',
    gtkFontSize: 11,
    highContrast: highContrast,
  );
}

BoxDecoration _focusDecoration(WidgetTester tester, Finder button) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: button, matching: find.byType(DecoratedBox)),
      )
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((decoration) {
        final border = decoration.border;
        return border is Border && border.top.width == 2;
      });
}

Border _focusBorder(WidgetTester tester, Finder button) {
  return _focusDecoration(tester, button).border! as Border;
}

Material _buttonMaterial(WidgetTester tester, Finder button) {
  return tester
      .widgetList<Material>(
        find.descendant(of: button, matching: find.byType(Material)),
      )
      .firstWhere((material) => material.type == MaterialType.button);
}

RichText _buttonText(WidgetTester tester, Finder button) {
  return tester.widget<RichText>(
    find.descendant(of: button, matching: find.byType(RichText)).first,
  );
}

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/ui/windows/windows_time_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final use24 in [true, false]) {
    testWidgets('keyboard selects and saves time ($use24)', (tester) async {
      final format = ValueNotifier(use24);
      addTearDown(format.dispose);
      final selected = DateTime.utc(2026, 9, 13, 9, 5, 17);
      final changes = <DateTime>[];
      await _pump(tester, selected, format, changes.add);
      await _openByKeyboard(tester);
      await _tabToWheel(tester, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await _tabToWheel(tester, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      if (!use24) {
        await _tabToWheel(tester, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      _expectWheel(tester, 0, 10, use24 ? 24 : 12);
      _expectWheel(tester, 1, 4, 60);
      if (!use24) _expectWheel(tester, 2, 1, 2);
      await _tabToButton(tester, 'time-confirm');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, [selected.copyWith(hour: use24 ? 10 : 22, minute: 4)]);
      expect(find.byType(ListWheelScrollView), findsNothing);
    });
  }

  testWidgets('keyboard wraps both wheels and commits the visible selection', (
    tester,
  ) async {
    final format = ValueNotifier(true);
    addTearDown(format.dispose);
    final selected = DateTime.utc(2026, 9, 13, 23, 0);
    final changes = <DateTime>[];
    await _pump(tester, selected, format, changes.add);
    await _openByKeyboard(tester);
    await _tabToWheel(tester, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await _tabToWheel(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectWheel(tester, 0, 0, 24);
    _expectWheel(tester, 1, 59, 60);
    await _tabToButton(tester, 'time-confirm');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [selected.copyWith(hour: 0, minute: 59)]);
  });

  testWidgets('keyboard cancellation discards pending time', (tester) async {
    final format = ValueNotifier(true);
    addTearDown(format.dispose);
    final selected = DateTime.utc(2026, 9, 13, 9, 5);
    final changes = <DateTime>[];
    var cancelled = 0;
    await _pump(
      tester,
      selected,
      format,
      changes.add,
      onCancel: () => cancelled++,
    );
    await _openByKeyboard(tester);
    await _tabToWheel(tester, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectWheel(tester, 0, 10, 24);
    await _tabToButton(tester, 'time-cancel');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(cancelled, 1);
    expect(find.text('09'), findsOneWidget);
  });

  testWidgets(
    'an initially empty picker retains its pending selection across format changes',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <DateTime>[];
      await _pump(tester, null, format, changes.add);
      tester
          .state<WindowsTimePickerState>(find.byType(WindowsTimePicker))
          .open();
      await tester.pumpAndSettle();
      final wheels = tester
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      (wheels[0].controller! as FixedExtentScrollController).jumpToItem(2);
      (wheels[1].controller! as FixedExtentScrollController).jumpToItem(5);
      (wheels[2].controller! as FixedExtentScrollController).jumpToItem(1);
      await tester.pumpAndSettle();
      format.value = true;
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await _confirm(tester);
      expect(changes.single.hour, 14);
      expect(changes.single.minute, 5);
    },
  );
  for (final hour in [0, 9, 12, 14, 23]) {
    for (final use24 in [false, true]) {
      testWidgets(
        'real picker shows and confirms $hour:05 ($use24) without date drift',
        (tester) async {
          final format = ValueNotifier(use24);
          addTearDown(format.dispose);
          final selected = DateTime.utc(2026, 9, 13, hour, 5, 17, 18, 19);
          final changes = <DateTime>[];
          await _pump(tester, selected, format, changes.add);
          expect(
            find.text(
              use24
                  ? hour.toString().padLeft(2, '0')
                  : '${twelveHourComponent(hour)}',
            ),
            findsOneWidget,
          );
          expect(find.text('05'), findsOneWidget);
          await tester.tap(find.text('05'));
          await tester.pumpAndSettle();
          expect(
            find.byType(ListWheelScrollView),
            findsNWidgets(use24 ? 2 : 3),
          );
          final hourWheel = tester.widget<ListWheelScrollView>(
            find.byType(ListWheelScrollView).first,
          );
          final labels =
              (hourWheel.childDelegate as ListWheelChildLoopingListDelegate)
                  .children;
          final texts = labels
              .map((child) => ((child as Center).child as Text).data)
              .toList();
          expect(
            texts,
            use24
                ? List.generate(24, (h) => '$h'.padLeft(2, '0'))
                : ['12', ...List.generate(11, (h) => '${h + 1}')],
          );
          expect(
            (hourWheel.controller! as FixedExtentScrollController)
                    .selectedItem %
                (use24 ? 24 : 12),
            use24 ? hour : hour % 12,
          );
          expect(
            find.descendant(
              of: find.byType(ListWheelScrollView).first,
              matching: find.byType(Button),
            ),
            findsNothing,
          );
          await _confirm(tester);
          expect(changes, isEmpty);
          expect(
            tester
                .widget<WindowsTimePicker>(find.byType(WindowsTimePicker))
                .selected,
            selected,
          );
        },
      );
    }
  }

  testWidgets(
    'period selection, pending edits and format changes retain UTC date',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final selected = DateTime.utc(2026, 9, 13, 0, 5, 17);
      final changes = <DateTime>[];
      await _pump(tester, selected, format, changes.add);
      await tester.tap(find.text('05'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PM').last);
      await tester.pumpAndSettle();
      final minute = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).at(1),
      );
      (minute.controller! as FixedExtentScrollController).jumpToItem(6);
      await tester.pumpAndSettle();
      format.value = true;
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.byType(ListWheelScrollView), findsNWidgets(2));
      final hours = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).first,
      );
      expect(
        (hours.controller! as FixedExtentScrollController).selectedItem % 24,
        12,
      );
      format.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      await _confirm(tester);
      expect(changes, [selected.copyWith(hour: 12, minute: 6)]);
      expect(changes.single.isUtc, isTrue);
    },
  );

  testWidgets('cancellation preserves selected value after period change', (
    tester,
  ) async {
    final format = ValueNotifier(false);
    addTearDown(format.dispose);
    final selected = DateTime(2026, 9, 13, 12, 5);
    final changes = <DateTime>[];
    var cancelled = 0;
    await _pump(
      tester,
      selected,
      format,
      changes.add,
      onCancel: () => cancelled++,
    );
    await tester.tap(find.text('05'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AM').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('time-cancel')));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(cancelled, 1);
    expect(find.text('PM'), findsOneWidget);
    format.value = true;
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.text('12'), findsOneWidget);
  });
}

Future<void> _openByKeyboard(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  expect(find.byType(ListWheelScrollView), findsWidgets);
}

Future<void> _tabToWheel(WidgetTester tester, int index) async {
  final wheel = find.byType(ListWheelScrollView).at(index);
  for (var attempt = 0; attempt < 12; attempt++) {
    if (Focus.maybeOf(tester.element(wheel))?.hasPrimaryFocus ?? false) {
      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  expect(
    (Focus.maybeOf(tester.element(wheel))?.hasPrimaryFocus ?? false),
    isTrue,
    reason: 'Wheel $index must be reachable by Tab',
  );
}

Future<void> _tabToButton(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  for (var attempt = 0; attempt < 12; attempt++) {
    if (Focus.of(
      tester.element(
        find.descendant(of: button, matching: find.byType(Text)).first,
      ),
    ).hasPrimaryFocus) {
      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  fail('$key must be reachable by Tab');
}

void _expectWheel(WidgetTester tester, int index, int value, int count) {
  final wheel = tester.widget<ListWheelScrollView>(
    find.byType(ListWheelScrollView).at(index),
  );
  final controller = wheel.controller! as FixedExtentScrollController;
  expect(controller.selectedItem % count, value);
  final delegate = wheel.childDelegate;
  final children = delegate is ListWheelChildLoopingListDelegate
      ? delegate.children
      : (delegate as ListWheelChildListDelegate).children;
  expect(
    find.descendant(
      of: find.byWidget(children[value]),
      matching: find.byType(Text),
    ),
    findsWidgets,
  );
  final selectedLabel = find.descendant(
    of: find.byWidget(children[value]),
    matching: find.byType(Text),
  );
  expect(
    tester.getCenter(selectedLabel).dy,
    closeTo(tester.getCenter(find.byType(ListWheelScrollView).at(index)).dy, 1),
  );
  expect(
    controller.offset / wheel.itemExtent,
    closeTo(controller.selectedItem.toDouble(), 0.001),
  );
}

Future<void> _pump(
  WidgetTester tester,
  DateTime? selected,
  ValueNotifier<bool> format,
  ValueChanged<DateTime> onChanged, {
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    FluentApp(
      locale: const Locale('de'),
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: format,
        builder: (context, use24, _) => BusyMaxTimeFormatScope(
          formatter: BusyMaxTimeFormatter(locale: 'de', use24Hour: use24),
          child: child!,
        ),
      ),
      home: Center(
        child: SizedBox(
          width: 240,
          child: WindowsTimePicker(
            selected: selected,
            onChanged: onChanged,
            onCancel: onCancel,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('time-confirm')));
  await tester.pumpAndSettle();
}

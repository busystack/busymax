import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/ui/windows/windows_time_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluent_ui/src/controls/pickers/pickers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'an initially empty picker retains its pending selection across format changes',
    (tester) async {
      final format = ValueNotifier(false);
      addTearDown(format.dispose);
      final changes = <DateTime>[];
      await _pump(tester, null, format, changes.add);
      tester.state<TimePickerState>(find.byType(TimePicker)).open();
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
              .map(
                (child) =>
                    (((child as ListTile).title as Center).child as Text).data,
              )
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
          final selectedTile = labels[use24 ? hour : hour % 12] as ListTile;
          expect(selectedTile.onPressed, isNull);
          await _confirm(tester);
          expect(changes, isEmpty);
          expect(
            tester.widget<TimePicker>(find.byType(TimePicker)).selected,
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
    await tester.tap(
      find
          .descendant(
            of: find.byType(YesNoPickerControl),
            matching: find.byType(Button),
          )
          .last,
    );
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
  await tester.tap(
    find
        .descendant(
          of: find.byType(YesNoPickerControl),
          matching: find.byType(Button),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

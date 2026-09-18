import 'package:busymax/src/android/presentation/android_date_picker.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'open picker follows preference changes without losing selection',
    (tester) async {
      final preference = ValueNotifier(BusyMaxFirstDayOfWeekPreference.monday);
      addTearDown(preference.dispose);
      DateTime? result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: preference,
            builder: (context, value, _) => BusyMaxWeekPreferencesScope(
              preference: value,
              systemWeekday: DateTime.sunday,
              platformLocaleTag: 'en-US',
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBusyMaxDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 15),
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2026, 12, 31),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      BuildContext pickerContext = tester.element(
        find.byType(DatePickerDialog),
      );
      expect(
        MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex,
        DateTime.monday,
      );

      await tester.tap(find.text('17'));
      await tester.pump();
      preference.value = BusyMaxFirstDayOfWeekPreference.saturday;
      await tester.pumpAndSettle();
      pickerContext = tester.element(find.byType(DatePickerDialog));
      expect(
        MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex,
        DateTime.saturday,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 9, 17));
    },
  );

  testWidgets('picker preserves input mode, limits, and cancellation', (
    tester,
  ) async {
    DateTime? result = DateTime(2000);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showBusyMaxDatePicker(
                context: context,
                initialDate: DateTime(2026, 9, 15),
                firstDate: DateTime(2026, 9, 10),
                lastDate: DateTime(2026, 9, 20),
                initialEntryMode: DatePickerEntryMode.input,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

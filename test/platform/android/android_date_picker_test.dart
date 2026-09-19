import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_date_picker.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'system label, open picker, and real week range update from one controller',
    (tester) async {
      final source = _WeekdaySource(DateTime.monday);
      final controller = BusyMaxSystemFirstWeekdayController(source);
      final preference = ValueNotifier(BusyMaxFirstDayOfWeekPreference.system);
      final language = ValueNotifier(const Locale('en'));
      addTearDown(controller.dispose);
      addTearDown(preference.dispose);
      addTearDown(language.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: language,
          builder: (context, locale, _) => MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('de')],
            builder: (context, child) => ValueListenableBuilder<int?>(
              valueListenable: controller,
              builder: (context, systemWeekday, _) => ValueListenableBuilder(
                valueListenable: preference,
                builder: (context, selected, _) => BusyMaxWeekPreferencesScope(
                  preference: selected,
                  systemWeekday: systemWeekday,
                  // A Sunday regional convention proves the native
                  // desktop value wins independently of UI language.
                  platformLocaleTag: 'en-US',
                  child: child!,
                ),
              ),
            ),
            home: Builder(
              builder: (context) {
                final firstWeekday = BusyMaxWeekPreferencesScope.firstWeekdayOf(
                  context,
                );
                final range = ScheduleRange.week(
                  DateTime(2026, 9, 16),
                  firstWeekday: firstWeekday,
                );
                return Column(
                  children: [
                    Text(
                      busyMaxFirstDayOfWeekPreferenceLabel(
                        context,
                        BusyMaxFirstDayOfWeekPreference.system,
                      ),
                    ),
                    Text('range starts ${range.start.weekday}'),
                    TextButton(
                      onPressed: () => showBusyMaxDatePicker(
                        context: context,
                        initialDate: DateTime(2026, 9, 16),
                        firstDate: DateTime(2026),
                        lastDate: DateTime(2026, 12, 31),
                      ),
                      child: const Text('Open system picker'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('System Default (Monday)'), findsOneWidget);
      expect(find.text('range starts 1'), findsOneWidget);

      await tester.tap(find.text('Open system picker'));
      await tester.pumpAndSettle();
      BuildContext pickerContext = tester.element(
        find.byType(DatePickerDialog),
      );
      expect(
        MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex,
        DateTime.monday,
      );

      source.change(DateTime.sunday);
      await tester.pumpAndSettle();
      expect(find.text('System Default (Sunday)'), findsOneWidget);
      pickerContext = tester.element(find.byType(DatePickerDialog));
      expect(MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex, 0);

      preference.value = BusyMaxFirstDayOfWeekPreference.saturday;
      source.change(DateTime.wednesday);
      await tester.pumpAndSettle();
      expect(find.text('System Default (Wednesday)'), findsOneWidget);
      pickerContext = tester.element(find.byType(DatePickerDialog));
      expect(
        MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex,
        DateTime.saturday,
      );

      preference.value = BusyMaxFirstDayOfWeekPreference.system;
      await tester.pumpAndSettle();
      pickerContext = tester.element(find.byType(DatePickerDialog));
      expect(
        MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex,
        DateTime.wednesday,
      );

      language.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(find.text('Systemstandard (Mittwoch)'), findsOneWidget);
      pickerContext = tester.element(find.byType(DatePickerDialog));
      expect(
        MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex,
        DateTime.wednesday,
      );
    },
  );

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

final class _WeekdaySource implements BusyMaxSystemFirstWeekdaySource {
  _WeekdaySource(this.value);

  int? value;
  final _changes = StreamController<void>.broadcast(sync: true);

  void change(int? weekday) {
    value = weekday;
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<int?> read() async => value;

  @override
  void dispose() => unawaited(_changes.close());
}

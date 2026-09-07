import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/recurrence/presentation/recurrence_editor.dart';
import 'package:busymax/src/l10n/app_locale.dart';
import 'package:busymax/src/l10n/localized_formatters.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';

void main() {
  const polish = Locale('pl');

  setUpAll(() => initializeDateFormatting('pl'));

  test('Polish is generated and selectable once as Polski', () {
    final options = busyMaxLocaleOptions.where((option) => option.tag == 'pl');
    final l10n = lookupAppLocalizations(polish);

    expect(options, hasLength(1));
    expect(options.single.endonym, 'Polski');
    expect(AppLocalizations.supportedLocales, contains(polish));
    expect(busyMaxSupportedLocales, contains(polish));
    expect(AppLocalizations.delegate.isSupported(polish), isTrue);
    expect(l10n.settings, 'Ustawienia');
    expect(l10n.today, 'Dzisiaj');
    expect(l10n.viewAgenda, 'Plan dnia');
    expect(l10n.currentLocale, 'Język aplikacji');
  });

  test('Polish regional preferences resolve without an extra option', () {
    for (final tag in ['pl', 'pl-PL', 'pl_PL']) {
      expect(normalizeBusyMaxLocaleTag(tag), 'pl');
      expect(busyMaxLocaleFromTag(tag), polish);
      expect(busyMaxLocaleEndonym(tag), 'Polski');
      final settings = AppSettings.fromJson({'localeTag': tag});
      expect(settings.locale, polish);
      expect(AppSettings.fromJson(settings.toJson()).localeTag, 'pl');
    }
    expect(
      resolveBusyMaxLocales(const [
        Locale('pl', 'PL'),
      ], busyMaxSupportedLocales),
      polish,
    );
    expect(
      resolveBusyMaxLocales(const [
        Locale('eo'),
        Locale('pl', 'PL'),
      ], busyMaxSupportedLocales),
      polish,
    );
  });

  test('Polish preference persists and resets to system', () async {
    final store = _MemorySettingsStore();
    final first = AppSettingsController(store);
    addTearDown(first.dispose);
    await first.ready;
    await first.setLocaleTag('pl');
    expect(store.value['localeTag'], 'pl');

    final restored = AppSettingsController(store);
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.state.locale, polish);
    await restored.setLocaleTag(null);
    expect(restored.state.locale, isNull);
    expect(store.value['localeTag'], isNull);
  });

  test('Polish count forms handle zero, teens and compound numbers', () {
    final l10n = lookupAppLocalizations(polish);
    expect(l10n.trayTasksDueToday(1), '1 zadanie na dzisiaj');
    expect(l10n.reminderMinutesBefore(1), '1 minutę wcześniej');
    expect(l10n.reminderHoursBefore(1), '1 godzinę wcześniej');
    expect(l10n.repeatTimesSummary(1), '1 raz');
    expect(l10n.repeatEveryWeeks(1), 'Co tydzień');
    expect(l10n.repeatEveryMonths(1), 'Co miesiąc');
    expect(l10n.repeatEveryYears(1), 'Co rok');

    for (final count in [2, 3, 4, 22, 24, 102, 104]) {
      expect(l10n.trayTasksDueToday(count), '$count zadania na dzisiaj');
      expect(l10n.reminderMinutesBefore(count), '$count minuty wcześniej');
      expect(l10n.reminderHoursBefore(count), '$count godziny wcześniej');
      expect(l10n.repeatEveryWeeks(count), 'Co $count tygodnie');
      expect(l10n.repeatEveryMonths(count), 'Co $count miesiące');
      expect(l10n.repeatEveryYears(count), 'Co $count lata');
    }
    for (final count in [0, 5, 11, 12, 14, 21, 25, 101, 111, 112, 114]) {
      expect(l10n.trayTasksDueToday(count), '$count zadań na dzisiaj');
      expect(l10n.reminderMinutesBefore(count), '$count minut wcześniej');
      expect(l10n.reminderHoursBefore(count), '$count godzin wcześniej');
      expect(l10n.repeatEveryWeeks(count), 'Co $count tygodni');
      expect(l10n.repeatEveryMonths(count), 'Co $count miesięcy');
      expect(l10n.repeatEveryYears(count), 'Co $count lat');
    }
    expect(
      l10n.dueTodayNotificationBody(0),
      'Brak zadań z terminem na dzisiaj.',
    );
    expect(l10n.dueTodayNotificationBody(1), '1 zadanie ma termin na dzisiaj.');
    expect(
      l10n.dueTodayNotificationBody(2),
      '2 zadania mają termin na dzisiaj.',
    );
    expect(l10n.dueTodayNotificationBody(12), '12 zadań ma termin na dzisiaj.');
    expect(l10n.repeatEveryDays(1), 'Codziennie');
    expect(l10n.repeatEveryDays(2), 'Co 2 dni');
    expect(l10n.nextcloudTrashRetention(1), contains('1 dzień'));
    expect(l10n.nextcloudTrashRetention(2), contains('2 dni'));
    expect(l10n.nextcloudTrashRetention(12), contains('12 dni'));
  });

  test('Polish dates retain grammatical context and decimal commas', () {
    final date = DateTime(2026, 9, 7);
    expect(localizedMonthHeading('pl', date), 'wrzesień');
    expect(localizedInlineMonth('pl', date), 'września');
    expect(localizedWeekdayLabel('pl', date), 'poniedziałek');
    expect(localizedDayHeading('pl', date), contains('7 września 2026'));
    expect(localizedNumber('pl', 1.5), '1,5');
  });

  for (final windows in [false, true]) {
    final platform = windows ? 'Windows' : 'Linux';
    testWidgets('Polish loads on $platform', (tester) async {
      await tester.pumpWidget(
        _polishApp(
          windows: windows,
          child: Builder(
            builder: (context) {
              expect(Localizations.localeOf(context), polish);
              expect(Directionality.of(context), TextDirection.ltr);
              final l10n = AppLocalizations.of(context);
              return Text('${l10n.settings} · ${l10n.today}');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ustawienia · Dzisiaj'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Polish recurrence on $platform', (tester) async {
      await tester.pumpWidget(
        _polishApp(
          windows: windows,
          child: Builder(
            builder: (context) => Column(
              children: [
                Text(
                  recurrenceRuleSummary(
                    context,
                    _rule(RecurrenceFrequency.weekly, days: ['TU', 'WE']),
                  ),
                ),
                Text(
                  recurrenceRuleSummary(
                    context,
                    _rule(
                      RecurrenceFrequency.monthly,
                      days: ['WE'],
                      position: 1,
                      count: 2,
                    ),
                  ),
                ),
                Text(
                  recurrenceRuleSummary(
                    context,
                    _rule(
                      RecurrenceFrequency.monthly,
                      days: ['SU'],
                      position: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Co tydzień we wtorek i w środę'), findsOneWidget);
      expect(find.text('Co miesiąc 1. środa · 2 razy'), findsOneWidget);
      expect(
        find.text('Co miesiąc niedziela (ostatnie wystąpienie)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _polishApp({required bool windows, required Widget child}) {
  if (windows) {
    return fluent.FluentApp(
      locale: const Locale('pl'),
      localizationsDelegates: const [AppLocalizations.delegate],
      localeListResolutionCallback: resolveBusyMaxLocales,
      supportedLocales: busyMaxSupportedLocales,
      home: child,
    );
  }
  return MaterialApp(
    locale: const Locale('pl'),
    localizationsDelegates: const [
      ...AppLocalizations.localizationsDelegates,
      ...GlobalUbuntuLocalizations.delegates,
    ],
    localeListResolutionCallback: resolveBusyMaxLocales,
    supportedLocales: busyMaxSupportedLocales,
    home: child,
  );
}

RecurrenceRule _rule(
  RecurrenceFrequency frequency, {
  required List<String> days,
  int? position,
  int? count,
}) {
  return RecurrenceRule(
    frequency: frequency,
    interval: 1,
    byDay: days,
    byMonth: const [],
    byMonthDay: const [],
    bySetPosition: position,
    count: count,
    untilRaw: null,
    recurrenceDates: const [],
    exceptionDates: const [],
    rawRules: const [],
    isSupported: true,
  );
}

class _MemorySettingsStore implements LocalSettingsStore {
  Map<String, Object?> value = <String, Object?>{};

  @override
  Future<Map<String, Object?>> load() async => value;

  @override
  Future<void> save(Map<String, Object?> json) async {
    value = Map<String, Object?>.from(json);
  }
}

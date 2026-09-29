import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_recurrence_dialog.dart';
import 'package:busymax/src/features/recurrence/domain/event_recurrence_codec.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets(
    'Android recurrence dialog retains interval, weekdays and count',
    (tester) async {
      final base = DateTime(2026, 6, 8, 9);
      final initial = EventRecurrenceCodec.decode(BusyProvider.google, const [
        'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;WKST=MO;COUNT=12',
      ], baseDate: base);
      RecurrenceRule? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showAndroidRecurrenceDialog(
                      context,
                      initial: initial,
                      baseDate: base,
                      allDay: false,
                      timeZone: 'America/Vancouver',
                      limits: EventRecurrenceCodec.limitsFor(
                        BusyProvider.google,
                      ),
                      providerLabel: 'Google',
                    ),
                child: const Text('Edit recurrence'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit recurrence'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, initial);
    },
  );

  test('frequency seed is provider-safe and anchored to the start day', () {
    final rule = androidRuleForFrequency(
      RecurrenceFrequency.weekly,
      DateTime(2026, 6, 10),
    );
    expect(rule.byDay, ['WE']);
    expect(
      EventRecurrenceCodec.canEncode(BusyProvider.microsoft, rule),
      isTrue,
    );
  });

  testWidgets('invalid interval and count cannot silently save stale rules', (
    tester,
  ) async {
    final base = DateTime(2026, 6, 8, 9);
    RecurrenceRule? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showAndroidRecurrenceDialog(
                context,
                initial: androidRuleForFrequency(
                  RecurrenceFrequency.weekly,
                  base,
                ),
                baseDate: base,
                allDay: false,
                timeZone: 'UTC',
                limits: EventRecurrenceCodec.limitsFor(BusyProvider.google),
                providerLabel: 'Google',
              ),
              child: const Text('Edit recurrence'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit recurrence'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'android-recurrence-interval-RecurrenceFrequency.weekly',
        ),
      ),
      'oops',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'android-recurrence-interval-RecurrenceFrequency.weekly',
        ),
      ),
      '2',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result?.interval, 2);
  });
}

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/features/recurrence/domain/event_recurrence_codec.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_editing.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_recurrence_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Windows frequency changes retain the count shown by the editor',
    (tester) async {
      final start = DateTime(2026, 11, 17, 9);
      final initial = EventRecurrenceCodec.decode(BusyProvider.google, [
        'RRULE:FREQ=DAILY;INTERVAL=2;COUNT=7',
      ], baseDate: start);
      RecurrenceRule? result;
      await tester.pumpWidget(
        FluentApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Button(
              onPressed: () async => result = await showWindowsRecurrenceDialog(
                context,
                initial: initial,
                baseDate: start,
                allDay: false,
                timeZone: 'UTC',
                providerLabel: 'Google',
                limits: RecurrenceRuleLimits.rfc5545,
              ),
              child: const Text('Edit recurrence'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit recurrence'));
      await tester.pumpAndSettle();
      tester
          .widget<ComboBox<RecurrenceFrequency>>(
            find.byType(ComboBox<RecurrenceFrequency>),
          )
          .onChanged!(RecurrenceFrequency.weekly);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ComboBox<RecurrenceEnd>>(
              find.byType(ComboBox<RecurrenceEnd>),
            )
            .value,
        RecurrenceEnd.count,
      );

      final count = find.byKey(
        const ValueKey((RecurrenceFrequency.weekly, 'count')),
      );
      tester.widget<NumberBox<int>>(count).onChanged!(null);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      tester.widget<NumberBox<int>>(count).onChanged!(7);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(result?.frequency, RecurrenceFrequency.weekly);
      expect(result?.interval, 2);
      expect(result?.count, 7);
    },
  );
}

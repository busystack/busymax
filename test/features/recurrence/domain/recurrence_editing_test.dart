import 'package:busymax/src/features/recurrence/domain/event_recurrence_codec.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_editing.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 17);

  test('frequency changes retain the displayed recurrence end', () {
    final initial = const RecurrenceRule.none()
        .withFrequency(RecurrenceFrequency.daily, start)
        .copyWith(interval: 2, count: 7);
    final weekly = initial.withFrequency(RecurrenceFrequency.weekly, start);
    expect(weekly.endMode, RecurrenceEnd.count);
    expect(weekly.count, 7);
    expect(weekly.interval, 2);
    expect(weekly.byDay, ['TU']);
    expect(
      weekly.withFrequency(RecurrenceFrequency.none, start).endMode,
      RecurrenceEnd.never,
    );
  });

  test('unsupported rules need a deliberate frequency selection', () {
    final initial = EventRecurrenceCodec.decode(BusyProvider.google, [
      'RRULE:FREQ=HOURLY;COUNT=4',
    ], baseDate: start);
    expect(RecurrenceRuleLimits.rfc5545.supports(initial), isFalse);
    final replacement = initial.withFrequency(RecurrenceFrequency.daily, start);
    expect(RecurrenceRuleLimits.rfc5545.supports(replacement), isTrue);
    expect(replacement.rawRules, isEmpty);
  });
}

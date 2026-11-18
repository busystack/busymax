import 'package:busymax/src/features/calendar/application/save_event_draft.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/domain/event_editor_draft.dart';
import 'package:busymax/src/features/calendar/domain/event_timing_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';

class _Repository extends Mock implements CalendarRepository {}

void main() {
  final draft = EventEditorDraft.newEvent(
    accountId: 'account',
    sourceId: 'calendar',
    providerCalendarId: 'provider-calendar',
    start: DateTime(2026, 11, 17, 9),
    end: DateTime(2026, 11, 17, 10),
  ).copyWith(title: 'Planning');

  test(
    'a failed mutation leaves preferences, sync and recovery alone',
    () async {
      final repository = _Repository();
      final failure = StateError('write failed');
      when(() => repository.createLocalEvent(draft)).thenThrow(failure);
      await expectLater(
        saveEventDraft(
          repository: repository,
          draft: draft,
          guestPolicy: CalendarGuestUpdatePolicy.send,
          rememberDestination: () async => fail('destination changed'),
          requestSync: () => fail('sync requested'),
          clearRecovery: () async => fail('draft deleted'),
        ),
        throwsA(same(failure)),
      );
    },
  );

  test(
    'notification and cleanup failures retain the committed outcome',
    () async {
      final repository = _Repository();
      when(() => repository.createLocalEvent(draft)).thenThrow(
        EventNotificationRefreshFailure(
          StateError('notification schedule failed'),
        ),
      );
      final calls = <String>[];
      final result = await saveEventDraft(
        repository: repository,
        draft: draft,
        guestPolicy: CalendarGuestUpdatePolicy.send,
        rememberDestination: () async => calls.add('destination'),
        requestSync: () => calls.add('sync'),
        clearRecovery: () async {
          calls.add('recovery');
          throw StateError('storage unavailable');
        },
      );

      expect(result, EventSaveOutcome.followUpPending);
      expect(calls, ['recovery', 'sync', 'destination']);
      verify(() => repository.createLocalEvent(draft)).called(1);
    },
  );
}

import 'package:busymax/src/features/calendar/domain/event_move_policy.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google uses native movement only within one account', () {
    expect(
      _strategy(
        sourceProvider: BusyProvider.google,
        destinationProvider: BusyProvider.google,
      ),
      CalendarEventMoveStrategy.googleNative,
    );
    expect(
      _strategy(
        sourceProvider: BusyProvider.google,
        destinationProvider: BusyProvider.google,
        destinationAccountId: 'other-account',
      ),
      CalendarEventMoveStrategy.copyThenDelete,
    );
  });

  test('Google special events and individual occurrences are copied', () {
    expect(
      _strategy(
        sourceProvider: BusyProvider.google,
        destinationProvider: BusyProvider.google,
        eventType: 'birthday',
      ),
      CalendarEventMoveStrategy.copyThenDelete,
    );
    expect(
      _strategy(
        sourceProvider: BusyProvider.google,
        destinationProvider: BusyProvider.google,
        recurring: true,
        recurringScope: RecurringEventMutationScope.singleOccurrence,
      ),
      CalendarEventMoveStrategy.copyThenDelete,
    );
  });

  test('same-account CalDAV movement uses the DAV resource operation', () {
    for (final provider in [
      BusyProvider.caldav,
      BusyProvider.nextcloud,
      BusyProvider.appleICloud,
    ]) {
      expect(
        _strategy(
          sourceProvider: provider,
          destinationProvider: provider,
          sourceDavCollectionId: 'source-collection',
          destinationDavCollectionId: 'destination-collection',
        ),
        CalendarEventMoveStrategy.davNative,
      );
    }
  });

  for (final destinationPrincipal in [
    null,
    'https://dav.example.test/principals/user',
    'https://dav.example.test/principals/other',
    'https://other.example.test/principals/user',
  ]) {
    test(
      'cross-account DAV move presentation uses the discovered scheduling identity: $destinationPrincipal',
      () {
        final strategy = _strategy(
          sourceProvider: BusyProvider.caldav,
          destinationProvider: BusyProvider.caldav,
          destinationAccountId: 'other-account',
          sourceDavCollectionId: 'source',
          destinationDavCollectionId: 'destination',
          sourceDavSchedulingPrincipal: Uri.parse(
            'https://dav.example.test/principals/user',
          ),
          destinationDavSchedulingPrincipal: destinationPrincipal == null
              ? null
              : Uri.parse(destinationPrincipal),
          recurring: true,
          recurringScope: RecurringEventMutationScope.entireSeries,
        );
        expect(
          strategy,
          destinationPrincipal == 'https://dav.example.test/principals/user'
              ? CalendarEventMoveStrategy.davNative
              : CalendarEventMoveStrategy.copyThenDelete,
        );
      },
    );
  }

  test('Microsoft movement uses explicit copy then delete', () {
    expect(
      _strategy(
        sourceProvider: BusyProvider.microsoft,
        destinationProvider: BusyProvider.microsoft,
      ),
      CalendarEventMoveStrategy.copyThenDelete,
    );
  });
}

CalendarEventMoveStrategy _strategy({
  required BusyProvider sourceProvider,
  required BusyProvider destinationProvider,
  String sourceAccountId = 'account',
  String destinationAccountId = 'account',
  String? sourceDavCollectionId,
  String? destinationDavCollectionId,
  String? eventType = 'default',
  bool recurring = false,
  RecurringEventMutationScope? recurringScope,
  Uri? sourceDavSchedulingPrincipal,
  Uri? destinationDavSchedulingPrincipal,
}) {
  return calendarEventMoveStrategy(
    sourceAccountId: sourceAccountId,
    sourceId: 'source',
    sourceProviderCalendarId: 'source-calendar',
    sourceProvider: sourceProvider,
    sourceDavCollectionId: sourceDavCollectionId,
    destinationAccountId: destinationAccountId,
    destinationId: 'destination',
    destinationProviderCalendarId: 'destination-calendar',
    destinationProvider: destinationProvider,
    destinationDavCollectionId: destinationDavCollectionId,
    eventType: eventType,
    recurring: recurring,
    recurringScope: recurringScope,
    sourceDavSchedulingPrincipal: sourceDavSchedulingPrincipal,
    destinationDavSchedulingPrincipal: destinationDavSchedulingPrincipal,
  );
}

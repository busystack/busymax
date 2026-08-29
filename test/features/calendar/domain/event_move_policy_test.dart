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
    for (final provider in [BusyProvider.nextcloud, BusyProvider.appleICloud]) {
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
  );
}

import '../../../providers/busy_provider.dart';
import '../presentation/event_editor_draft.dart';

enum CalendarEventMoveStrategy { none, googleNative, davNative, copyThenDelete }

CalendarEventMoveStrategy calendarEventMoveStrategy({
  required String sourceAccountId,
  required String sourceId,
  required String sourceProviderCalendarId,
  required BusyProvider sourceProvider,
  required String? sourceDavCollectionId,
  required String destinationAccountId,
  required String destinationId,
  required String destinationProviderCalendarId,
  required BusyProvider destinationProvider,
  required String? destinationDavCollectionId,
  required String? eventType,
  required bool recurring,
  required RecurringEventMutationScope? recurringScope,
}) {
  final changed =
      sourceAccountId != destinationAccountId ||
      sourceId != destinationId ||
      sourceProviderCalendarId != destinationProviderCalendarId ||
      sourceProvider != destinationProvider;
  if (!changed) return CalendarEventMoveStrategy.none;

  final movesWholeResource =
      !recurring || recurringScope == RecurringEventMutationScope.entireSeries;
  if (!movesWholeResource || sourceAccountId != destinationAccountId) {
    return CalendarEventMoveStrategy.copyThenDelete;
  }

  if (sourceProvider == BusyProvider.google &&
      destinationProvider == BusyProvider.google &&
      (eventType == null || eventType.isEmpty || eventType == 'default')) {
    return CalendarEventMoveStrategy.googleNative;
  }

  final davProvider =
      sourceProvider == BusyProvider.nextcloud ||
      sourceProvider == BusyProvider.appleICloud;
  if (davProvider &&
      destinationProvider == sourceProvider &&
      sourceDavCollectionId != null &&
      destinationDavCollectionId != null) {
    return CalendarEventMoveStrategy.davNative;
  }

  return CalendarEventMoveStrategy.copyThenDelete;
}

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
  Uri? sourceDavSchedulingPrincipal,
  Uri? destinationDavSchedulingPrincipal,
}) {
  final changed =
      sourceAccountId != destinationAccountId ||
      sourceId != destinationId ||
      sourceProviderCalendarId != destinationProviderCalendarId ||
      sourceProvider != destinationProvider;
  if (!changed) return CalendarEventMoveStrategy.none;

  final movesWholeResource =
      !recurring || recurringScope == RecurringEventMutationScope.entireSeries;
  final sameDavIdentity =
      sourceProvider.isDav &&
      destinationProvider.isDav &&
      sourceDavSchedulingPrincipal != null &&
      sourceDavSchedulingPrincipal == destinationDavSchedulingPrincipal;
  if (!movesWholeResource ||
      (sourceAccountId != destinationAccountId && !sameDavIdentity)) {
    return CalendarEventMoveStrategy.copyThenDelete;
  }

  if (sourceProvider == BusyProvider.google &&
      destinationProvider == BusyProvider.google &&
      (eventType == null || eventType.isEmpty || eventType == 'default')) {
    return CalendarEventMoveStrategy.googleNative;
  }

  final davProvider = sourceProvider.isDav;
  if (davProvider &&
      destinationProvider.isDav &&
      (destinationProvider == sourceProvider || sameDavIdentity) &&
      sourceDavCollectionId != null &&
      destinationDavCollectionId != null) {
    return CalendarEventMoveStrategy.davNative;
  }

  return CalendarEventMoveStrategy.copyThenDelete;
}

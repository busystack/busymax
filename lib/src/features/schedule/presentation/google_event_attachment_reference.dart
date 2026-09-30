import '../../../features/calendar/data/calendar_repository.dart';
import '../../../google_calendar/google_calendar_api_client.dart';
import '../../../providers/busy_provider.dart';
import '../../../schedule/event_attachment_link.dart';
import '../../../schedule/schedule_item.dart';

final class GoogleEventAttachmentReferenceChange {
  const GoogleEventAttachmentReferenceChange({
    required this.links,
    required this.cacheUpdated,
  });

  final List<EventAttachmentLink> links;
  final bool cacheUpdated;
}

/// Changes an existing event's reference, never the underlying Drive file.
/// The provider request reads the complete authoritative array and uses its
/// ETag. A successful remote write is not reported as failed just because a
/// subsequent local projection could not be refreshed.
Future<GoogleEventAttachmentReferenceChange>
changeGoogleEventAttachmentReference({
  required CalendarScheduleItem item,
  required GoogleCalendarApiClient client,
  required CalendarRepository repository,
  String? addFileUrl,
  String? addTitle,
  String? removeFileUrl,
}) async {
  final eventId = item.providerEventId;
  if (item.provider != BusyProvider.google ||
      !item.capabilities.canEdit ||
      eventId == null ||
      eventId.isEmpty) {
    throw UnsupportedError('This event cannot change attachment references.');
  }
  final event = await client.changeEventAttachmentReferences(
    calendarId: item.providerCalendarId,
    eventId: eventId,
    addFileUrl: addFileUrl,
    addTitle: addTitle,
    removeFileUrl: removeFileUrl,
  );
  var cacheUpdated = true;
  try {
    await repository.upsertEvent(
      accountId: item.accountId,
      event: event,
      preservePendingLocalChanges: true,
    );
  } on Object {
    cacheUpdated = false;
  }
  return GoogleEventAttachmentReferenceChange(
    links: eventAttachmentLinks(event.attachmentsJson),
    cacheUpdated: cacheUpdated,
  );
}

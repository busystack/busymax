import '../../../google_calendar/google_calendar_api_client.dart';
import '../../../schedule/event_attachment_link.dart';
import '../../../schedule/schedule_item.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../../microsoft_calendar/microsoft_event_attachment.dart';
import '../../../providers/busy_provider.dart';
import '../../calendar/data/calendar_repository.dart';
import 'attachment_upload_coordinator.dart';
import 'google_event_attachment_reference.dart';

/// Reject provider-controlled path components before presenting a suggested
/// destination. The user still explicitly chooses the final save location.
String? safeAttachmentFileName(String name) {
  final value = name.trim();
  if (value.isEmpty ||
      value == '.' ||
      value == '..' ||
      value.endsWith('.') ||
      value.length > 255 ||
      value.contains('/') ||
      value.contains('\\') ||
      RegExp(r'[<>:"|?*]').hasMatch(value) ||
      RegExp(
        r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(value) ||
      value.codeUnits.any((unit) => unit < 32 || unit == 127)) {
    return null;
  }
  return value;
}

const maximumEventAttachmentBytes = 150 * 1024 * 1024;

Future<({List<EventAttachmentLink> links, bool cacheUpdated})>
changeEventAttachmentReference({
  required CalendarScheduleItem item,
  required GoogleCalendarApiClient Function() googleClient,
  required CalendarRepository repository,
  String? addUrl,
  String? removeUrl,
}) async {
  if (item.provider == BusyProvider.google) {
    final result = await changeGoogleEventAttachmentReference(
      item: item,
      client: googleClient(),
      repository: repository,
      addFileUrl: addUrl,
      removeFileUrl: removeUrl,
    );
    return (links: result.links, cacheUpdated: result.cacheUpdated);
  }
  if (item.provider != BusyProvider.nextcloud || !item.capabilities.canEdit) {
    throw UnsupportedError('This event cannot change attachment references.');
  }
  final detail = await repository.changeNextcloudUriAttachmentReference(
    accountId: item.accountId,
    eventId: item.id,
    addUrl: addUrl,
    removeUrl: removeUrl,
  );
  return (
    links: eventAttachmentLinks(detail?.attachments),
    cacheUpdated: detail != null,
  );
}

Future<({String name, List<int> bytes})> downloadEventAttachment({
  required CalendarScheduleItem item,
  required MicrosoftEventAttachment attachment,
  required MicrosoftCalendarApiClient client,
}) async {
  final name = safeAttachmentFileName(attachment.name);
  if (name == null) throw const FormatException('Invalid attachment name.');
  final eventId = item.providerEventId;
  if (eventId == null || !attachment.canDownload) {
    throw UnsupportedError('This attachment cannot be downloaded.');
  }
  final bytes = await client.downloadEventAttachment(
    calendarId: item.providerCalendarId,
    eventId: eventId,
    attachment: attachment,
  );
  return (name: name, bytes: bytes);
}

Future<void> deleteEventAttachment({
  required CalendarScheduleItem item,
  required MicrosoftEventAttachment attachment,
  required MicrosoftCalendarApiClient client,
  required AttachmentUploadCoordinator uploads,
}) async {
  final eventId = item.providerEventId;
  if (eventId == null || attachment.id.isEmpty || !item.capabilities.canEdit) {
    throw UnsupportedError('This attachment cannot be deleted.');
  }
  await client.deleteEventAttachment(
    calendarId: item.providerCalendarId,
    eventId: eventId,
    attachmentId: attachment.id,
  );
  uploads.attachmentRemoved(
    AttachmentUploadCoordinator.eventKey(
      item.accountId,
      item.providerCalendarId,
      eventId,
    ),
    attachment.id,
  );
}

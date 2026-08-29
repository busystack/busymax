import 'dart:convert';

import '../../../db/app_database.dart';
import '../../../providers/busy_provider.dart';

/// Authoritative event state loaded from the local calendar event store.
///
/// Schedule items intentionally contain only data needed to render and operate
/// the schedule. Editing starts from this model so provider fields that are not
/// part of the schedule projection remain available and unchanged.
final class CalendarEventDetail {
  const CalendarEventDetail({
    required this.id,
    required this.accountId,
    required this.sourceId,
    required this.provider,
    required this.providerCalendarId,
    required this.providerEventId,
    required this.davCollectionId,
    required this.davObjectId,
    required this.davComponentId,
    required this.icalUid,
    required this.recurrenceIdKey,
    required this.occurrenceKey,
    required this.projectionVersion,
    required this.providerRecurringEventId,
    required this.providerOriginalStartKey,
    required this.etagOrChangeKey,
    required this.status,
    required this.title,
    required this.description,
    required this.location,
    required this.allDay,
    required this.startDate,
    required this.startDateTime,
    required this.startTimeZone,
    required this.endDate,
    required this.endDateTime,
    required this.endTimeZone,
    required this.recurrence,
    required this.reminders,
    required this.attendees,
    required this.categories,
    required this.organizer,
    required this.creator,
    required this.guestsCanModify,
    required this.locked,
    required this.colorId,
    required this.colorHex,
    required this.visibility,
    required this.transparencyOrShowAs,
    required this.eventType,
    required this.webLink,
    required this.conference,
    required this.attachments,
    required this.isCancelled,
    required this.isDeleted,
    required this.raw,
    required this.createdAtServer,
    required this.updatedAtServer,
    required this.createdAtLocal,
    required this.updatedAtLocal,
    required this.syncStatus,
    required this.baselineRaw,
  });

  factory CalendarEventDetail.fromRow(CalendarEvent row) {
    final raw = _decodeJson(row.rawJson);
    final rawMap = raw is Map ? Map<String, Object?>.from(raw) : const {};
    return CalendarEventDetail(
      id: row.id,
      accountId: row.accountId,
      sourceId: row.calendarSourceId,
      provider: BusyProviderCodec.requireStorageValue(row.provider),
      providerCalendarId: row.providerCalendarId,
      providerEventId: row.providerEventId,
      davCollectionId: row.davCollectionId,
      davObjectId: row.davObjectId,
      davComponentId: row.davComponentId,
      icalUid: row.icalUid,
      recurrenceIdKey: row.recurrenceIdKey,
      occurrenceKey: row.occurrenceKey,
      projectionVersion: row.projectionVersion,
      providerRecurringEventId: row.providerRecurringEventId,
      providerOriginalStartKey: row.providerOriginalStartKey,
      etagOrChangeKey: row.etagOrChangeKey,
      status: row.status,
      title: row.title,
      description: row.description,
      location: row.location,
      allDay: row.allDay,
      startDate: row.startDate,
      startDateTime: row.startDateTime,
      startTimeZone: row.startTimeZone,
      endDate: row.endDate,
      endDateTime: row.endDateTime,
      endTimeZone: row.endTimeZone,
      recurrence: _decodeJson(row.recurrenceJson),
      reminders: _decodeJson(row.remindersJson),
      attendees: _decodeJson(row.attendeesJson),
      categories: _decodeJson(row.categoriesJson),
      organizer: _decodeJson(row.organizerJson),
      creator: _decodeJson(row.creatorJson),
      guestsCanModify: rawMap['guestsCanModify'] == true,
      locked: rawMap['locked'] == true,
      colorId: row.colorId,
      colorHex: row.colorHex,
      visibility: row.visibility,
      transparencyOrShowAs: row.transparencyOrShowAs,
      eventType: row.eventType,
      webLink: row.webLink,
      conference: _decodeJson(row.conferenceJson),
      attachments: _decodeJson(row.attachmentsJson),
      isCancelled: row.isCancelled,
      isDeleted: row.isDeleted,
      raw: raw,
      createdAtServer: row.createdAtServer,
      updatedAtServer: row.updatedAtServer,
      createdAtLocal: row.createdAtLocal,
      updatedAtLocal: row.updatedAtLocal,
      syncStatus: row.syncStatus,
      baselineRaw: _decodeJson(row.baselineRawJson),
    );
  }

  final String id;
  final String accountId;
  final String sourceId;
  final BusyProvider provider;
  final String providerCalendarId;
  final String providerEventId;
  final String? davCollectionId;
  final String? davObjectId;
  final String? davComponentId;
  final String? icalUid;
  final String? recurrenceIdKey;
  final String? occurrenceKey;
  final int projectionVersion;
  final String? providerRecurringEventId;
  final String? providerOriginalStartKey;
  final String? etagOrChangeKey;
  final String? status;
  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final String? startDate;
  final String? startDateTime;
  final String? startTimeZone;
  final String? endDate;
  final String? endDateTime;
  final String? endTimeZone;
  final Object? recurrence;
  final Object? reminders;
  final Object? attendees;
  final Object? categories;
  final Object? organizer;
  final Object? creator;
  final bool guestsCanModify;
  final bool locked;
  final String? colorId;
  final String? colorHex;
  final String? visibility;
  final String? transparencyOrShowAs;
  final String? eventType;
  final String? webLink;
  final Object? conference;
  final Object? attachments;
  final bool isCancelled;
  final bool isDeleted;
  final Object? raw;
  final String? createdAtServer;
  final String? updatedAtServer;
  final int createdAtLocal;
  final int updatedAtLocal;
  final String syncStatus;
  final Object? baselineRaw;
}

Object? _decodeJson(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

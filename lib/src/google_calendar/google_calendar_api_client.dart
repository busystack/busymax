import 'dart:convert';

import 'package:http/http.dart' as http;

import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_provider_capabilities.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'google_calendar_errors.dart';
import 'google_calendar_mapper.dart';
import 'google_calendar_models.dart';

class GoogleCalendarApiClient
    implements
        CloudCalendarClient,
        CompleteRecurringInstanceClient,
        PrivateCalendarImportClient,
        DetailedFreeBusyClient,
        CalendarListManagementClient {
  GoogleCalendarApiClient({
    required http.Client httpClient,
    required Uri baseUri,
    Future<String> Function()? authorizationHeaderProvider,
    Future<void> Function()? unauthorizedRefreshProvider,
  }) : _httpClient = httpClient,
       _baseUri = baseUri,
       _authorizationHeaderProvider = authorizationHeaderProvider,
       _unauthorizedRefreshProvider = unauthorizedRefreshProvider;

  final http.Client _httpClient;
  final Uri _baseUri;
  final Future<String> Function()? _authorizationHeaderProvider;
  final Future<void> Function()? _unauthorizedRefreshProvider;

  @override
  BusyProvider get provider => BusyProvider.google;

  @override
  CalendarProviderCapabilities get capabilities =>
      googleCalendarProviderCapabilities;

  @override
  Future<List<CalendarSourceDto>> listCalendars() async {
    final calendars = <CalendarSourceDto>[];
    String? pageToken;
    do {
      final json = await _requestJson(
        'GET',
        _uri(
          '/calendar/v3/users/me/calendarList',
          query: _compactQuery({
            'maxResults': '250',
            'showHidden': 'true',
            'showDeleted': 'true',
            'pageToken': pageToken,
          }),
        ),
      );
      final page = GoogleCalendarPage.fromJson(json);
      calendars.addAll(page.items.map(googleCalendarSourceFromJson));
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return calendars;
  }

  Future<GoogleColorsDto> getColors() async {
    return GoogleColorsDto.fromJson(
      await _requestJson('GET', _uri('/calendar/v3/colors')),
    );
  }

  /// Labels belong to one calendar; never cache these against an account or
  /// reuse an ID after the editor changes calendars.
  Future<List<GoogleEventLabel>> getEventLabels(String calendarId) async {
    final json = await _requestJson(
      'GET',
      _uri('/calendar/v3/calendars/${_enc(calendarId)}'),
    );
    final properties = json['labelProperties'];
    if (properties == null) {
      throw const FormatException('Calendar label metadata is unavailable.');
    }
    if (properties is! Map || properties['eventLabels'] is! List) {
      throw const FormatException('Malformed calendar label properties.');
    }
    final entries = properties['eventLabels'] as List;
    if (entries.any((entry) => entry is! Map)) {
      throw const FormatException('Malformed calendar event labels.');
    }
    return List.unmodifiable([
      for (final entry in entries)
        GoogleEventLabel.fromJson(Map<String, Object?>.from(entry as Map)),
    ]);
  }

  Future<List<GoogleAclRule>> listAclRules(String calendarId) async {
    final path = '/calendar/v3/calendars/${_enc(calendarId)}/acl';
    final rules = <GoogleAclRule>[];
    final seenTokens = <String>{};
    String? pageToken;
    do {
      final json = await _requestJson(
        'GET',
        _uri(path, query: _compactQuery({'pageToken': pageToken})),
      );
      final items = json['items'];
      if (items is! List || items.any((item) => item is! Map)) {
        throw const FormatException('Malformed Google calendar ACL list.');
      }
      for (final item in items) {
        rules.add(
          GoogleAclRule.fromJson(Map<String, Object?>.from(item as Map)),
        );
      }
      pageToken = json['nextPageToken']?.toString();
      if (pageToken != null &&
          pageToken.isNotEmpty &&
          !seenTokens.add(pageToken)) {
        throw const FormatException('Repeated Google calendar ACL page.');
      }
    } while (pageToken != null && pageToken.isNotEmpty);
    return List.unmodifiable(rules);
  }

  Future<GoogleAclRule> addAclUser(
    String calendarId, {
    required String email,
    required String role,
  }) async {
    _validateAclUserRole(role);
    if (!RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$').hasMatch(email)) {
      throw ArgumentError.value(email, 'email', 'Invalid recipient address');
    }
    final json = await _requestJson(
      'POST',
      _uri('/calendar/v3/calendars/${_enc(calendarId)}/acl'),
      body: {
        'role': role,
        'scope': {'type': 'user', 'value': email},
      },
    );
    return GoogleAclRule.fromJson(json);
  }

  Future<GoogleAclRule> changeAclRole(
    String calendarId,
    GoogleAclRule rule,
    String role,
  ) async {
    _validateAclUserRole(role);
    if (rule.role == 'owner' || rule.scopeType != 'user') {
      throw ArgumentError('This ACL rule is not mutable here.');
    }
    final json = await _requestJson(
      'PATCH',
      _uri('/calendar/v3/calendars/${_enc(calendarId)}/acl/${_enc(rule.id)}'),
      body: {'role': role},
    );
    return GoogleAclRule.fromJson(json);
  }

  Future<void> revokeAclUser(String calendarId, GoogleAclRule rule) {
    if (rule.role == 'owner' || rule.scopeType != 'user') {
      throw ArgumentError('This ACL rule is not revocable here.');
    }
    return _requestEmpty(
      'DELETE',
      _uri('/calendar/v3/calendars/${_enc(calendarId)}/acl/${_enc(rule.id)}'),
    );
  }

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) async {
    final json = await _requestJson(
      'POST',
      _uri('/calendar/v3/calendars'),
      body: googleCalendarMutationToJson(mutation),
    );
    // Calendar-list color is a separate resource mutation. The replay layer
    // persists this acknowledged identity before queueing that follow-up, so a
    // color failure can never cause another calendar creation POST.
    return googleCalendarSourceFromJson(json);
  }

  @override
  Future<CalendarSourceDto> updateCalendar(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    var updatedGlobalMetadata = false;
    final calendarBody = googleCalendarMutationToJson(mutation);
    if (calendarBody.isNotEmpty) {
      await _requestJson(
        'PATCH',
        _uri('/calendar/v3/calendars/${_enc(calendarId)}'),
        body: calendarBody,
      );
      updatedGlobalMetadata = true;
    }
    if (_hasCalendarListColor(mutation)) {
      return _updateCalendarListColor(calendarId, mutation);
    }
    if (!updatedGlobalMetadata) {
      throw ArgumentError('Calendar update has no writable fields.');
    }
    return _getCalendarListEntry(calendarId);
  }

  Future<CalendarSourceDto> _getCalendarListEntry(String calendarId) async {
    final json = await _requestJson(
      'GET',
      _uri('/calendar/v3/users/me/calendarList/${_enc(calendarId)}'),
    );
    return googleCalendarSourceFromJson(json);
  }

  Future<CalendarSourceDto> _updateCalendarListColor(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    final usesRgb =
        mutation.backgroundColor != null || mutation.foregroundColor != null;
    final json = await _requestJson(
      'PATCH',
      _uri(
        '/calendar/v3/users/me/calendarList/${_enc(calendarId)}',
        query: usesRgb ? const {'colorRgbFormat': 'true'} : null,
      ),
      body: googleCalendarListColorMutationToJson(mutation),
    );
    return googleCalendarSourceFromJson(json);
  }

  @override
  Future<CalendarSourceDto> updateCalendarListEntry(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    final usesRgb =
        mutation.backgroundColor != null || mutation.foregroundColor != null;
    final json = await _requestJson(
      'PATCH',
      _uri(
        '/calendar/v3/users/me/calendarList/${_enc(calendarId)}',
        query: usesRgb ? const {'colorRgbFormat': 'true'} : null,
      ),
      body: googleCalendarListMutationToJson(mutation),
    );
    return googleCalendarSourceFromJson(json);
  }

  Future<CalendarSourceDto> insertCalendarListEntry(String calendarId) async {
    final json = await _requestJson(
      'POST',
      _uri('/calendar/v3/users/me/calendarList'),
      body: {'id': calendarId},
    );
    return googleCalendarSourceFromJson(json);
  }

  @override
  Future<void> deleteCalendarListEntry(String calendarId) {
    return _requestEmpty(
      'DELETE',
      _uri('/calendar/v3/users/me/calendarList/${_enc(calendarId)}'),
    );
  }

  @override
  Future<void> deleteCalendar(String calendarId) {
    return _requestEmpty(
      'DELETE',
      _uri('/calendar/v3/calendars/${_enc(calendarId)}'),
    );
  }

  @override
  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  }) async {
    final events = <CalendarEventDto>[];
    String? pageToken = pageTokenOrUrl;
    do {
      final page = await _listEventsPage(
        calendarId: calendarId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        pageToken: pageToken,
        singleEvents: true,
      );
      events.addAll(page.events);
      pageToken = page.nextPageTokenOrUrl;
    } while (pageToken != null &&
        pageToken.isNotEmpty &&
        pageTokenOrUrl == null);
    return events;
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    final body = googleEventMutationToJson(mutation);
    final json = await _requestJson(
      'POST',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events',
        query: {
          'conferenceDataVersion': '1',
          'supportsAttachments': 'true',
          if (body.containsKey('eventLabelId')) 'eventLabelVersion': '1',
          'sendUpdates': _googleGuestUpdatePolicy(guestUpdatePolicy),
        },
      ),
      body: body,
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  /// Calendar's import operation creates a private copy identified by the
  /// iCalendar UID; it is not an ordinary event insertion or invitation send.
  @override
  Future<CalendarEventDto> importEvent({
    required String calendarId,
    required String iCalUid,
    required CalendarEventMutation mutation,
  }) async {
    if (iCalUid.trim().isEmpty) {
      throw const FormatException('iCalendar UID is required for import.');
    }
    final body = googleEventMutationToJson(mutation)
      ..remove('id')
      ..['iCalUID'] = iCalUid.trim();
    final json = await _requestJson(
      'POST',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/import',
        query: {
          'supportsAttachments': 'true',
          if (body.containsKey('eventLabelId')) 'eventLabelVersion': '1',
        },
      ),
      body: body,
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<List<CalendarEventDto>> eventsWithICalUid({
    required String calendarId,
    required String iCalUid,
    bool includeCancelled = false,
  }) async {
    final events = <CalendarEventDto>[];
    String? pageToken;
    final visited = <String>{};
    do {
      if (pageToken != null && !visited.add(pageToken)) {
        throw const FormatException('Google series pagination loop.');
      }
      final json = await _requestJson(
        'GET',
        _uri(
          '/calendar/v3/calendars/${_enc(calendarId)}/events',
          query: _compactQuery({
            'iCalUID': iCalUid,
            'singleEvents': 'false',
            'showDeleted': includeCancelled ? 'true' : 'false',
            'maxResults': '250',
            'pageToken': pageToken,
          }),
        ),
      );
      final page = GoogleCalendarPage.fromJson(json);
      events.addAll(
        page.items.map((item) => googleCalendarEventFromJson(calendarId, item)),
      );
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return events;
  }

  @override
  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    final json = await _requestJson(
      'GET',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
      ),
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  /// Changes only the attachment collection, starting from a fresh complete
  /// event resource. Google's array patch semantics replace the entire array.
  Future<CalendarEventDto> changeEventAttachmentReferences({
    required String calendarId,
    required String eventId,
    String? addFileUrl,
    String? addTitle,
    String? removeFileUrl,
  }) async {
    if ((addFileUrl == null) == (removeFileUrl == null)) {
      throw ArgumentError('Specify exactly one attachment change.');
    }
    final candidate = addFileUrl ?? removeFileUrl!;
    final uri = Uri.tryParse(candidate.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Attachment URL must be a valid HTTPS URL.');
    }
    final eventUri = _uri(
      '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
    );
    final current = await _requestJson('GET', eventUri);
    final etag = current['etag']?.toString();
    if (etag == null || etag.isEmpty) {
      throw const FormatException('Event is missing a conflict token.');
    }
    final raw = current['attachments'];
    if (raw != null && (raw is! List || raw.any((entry) => entry is! Map))) {
      throw const FormatException('Malformed event attachment collection.');
    }
    final attachments = <Map<String, Object?>>[
      for (final entry in raw is List ? raw : const <Object>[])
        Map<String, Object?>.from(entry as Map),
    ];
    if (addFileUrl != null) {
      if (attachments.any((entry) => entry['fileUrl'] == uri.toString())) {
        return googleCalendarEventFromJson(calendarId, current);
      }
      if (attachments.length >= 25) {
        throw StateError('Google events allow at most 25 attachments.');
      }
      attachments.add({
        'fileUrl': uri.toString(),
        if (addTitle != null && addTitle.trim().isNotEmpty)
          'title': addTitle.trim(),
      });
    } else {
      final before = attachments.length;
      attachments.removeWhere((entry) => entry['fileUrl'] == uri.toString());
      if (attachments.length == before) {
        return googleCalendarEventFromJson(calendarId, current);
      }
    }
    late final Map<String, Object?> updated;
    try {
      updated = await _requestJson(
        'PATCH',
        eventUri.replace(
          queryParameters: {
            'supportsAttachments': 'true',
            'sendUpdates': 'none',
          },
        ),
        body: {'attachments': attachments},
        headers: {'If-Match': etag},
      );
    } on Object catch (error, stack) {
      // A failed response can follow a committed write. Read the authoritative
      // resource before allowing an operator to retry the array replacement.
      try {
        final after = await _requestJson('GET', eventUri);
        final afterRaw = after['attachments'];
        if (afterRaw is List && afterRaw.every((entry) => entry is Map)) {
          final present = afterRaw.any(
            (entry) => (entry as Map)['fileUrl'] == uri.toString(),
          );
          if (present == (addFileUrl != null)) {
            return googleCalendarEventFromJson(calendarId, after);
          }
        }
      } on Object {
        // Preserve the original failure if reconciliation is unavailable.
      }
      Error.throwWithStackTrace(error, stack);
    }
    return googleCalendarEventFromJson(calendarId, updated);
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
    String? ifMatch,
  }) async {
    // A normal event edit is a PATCH. Sending the cached attachment array
    // would replace the provider's entire collection, including references
    // added after our last sync. The dedicated attachment operation reads the
    // fresh event and uses its ETag before replacing that array.
    final body = googleEventMutationToJson(mutation)..remove('attachments');
    final json = await _requestJson(
      'PATCH',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
        query: {
          'conferenceDataVersion': '1',
          if (body.containsKey('eventLabelId')) 'eventLabelVersion': '1',
          'sendUpdates': _googleGuestUpdatePolicy(guestUpdatePolicy),
        },
      ),
      body: body,
      headers: {if (ifMatch != null) 'If-Match': ifMatch},
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  Future<CalendarEventDto> replaceEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    final body = googleEventMutationToJson(mutation);
    final json = await _requestJson(
      'PUT',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
        query: {
          'conferenceDataVersion': '1',
          if (body.containsKey('eventLabelId')) 'eventLabelVersion': '1',
          'sendUpdates': _googleGuestUpdatePolicy(guestUpdatePolicy),
        },
      ),
      body: body,
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
    String? ifMatch,
  }) {
    return _requestEmpty(
      'DELETE',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
        query: {'sendUpdates': _googleGuestUpdatePolicy(guestUpdatePolicy)},
      ),
      headers: {if (ifMatch != null) 'If-Match': ifMatch},
    );
  }

  @override
  Future<CalendarEventDto?> respondToEvent({
    required String calendarId,
    required String eventId,
    required CalendarInvitationResponse response,
    String? attendeeEmail,
    bool sendResponse = true,
  }) async {
    final email = attendeeEmail?.trim();
    if (email == null || email.isEmpty) {
      throw ArgumentError.value(
        attendeeEmail,
        'attendeeEmail',
        'Google invitation responses require the self attendee email.',
      );
    }
    final json = await _requestJson(
      'PATCH',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
        query: {'sendUpdates': sendResponse ? 'all' : 'none'},
      ),
      body: {
        'attendeesOmitted': true,
        'attendees': [
          {
            'email': email,
            'responseStatus': _googleInvitationResponse(response),
          },
        ],
      },
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<List<CalendarEventDto>> listEventInstances({
    required String calendarId,
    required String recurringEventId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) => _listEventInstances(
    calendarId: calendarId,
    recurringEventId: recurringEventId,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );

  @override
  Future<List<CalendarEventDto>> listAllEventInstances({
    required String calendarId,
    required String recurringEventId,
  }) => _listEventInstances(
    calendarId: calendarId,
    recurringEventId: recurringEventId,
  );

  Future<List<CalendarEventDto>> _listEventInstances({
    required String calendarId,
    required String recurringEventId,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    assert((rangeStart == null) == (rangeEnd == null));
    final events = <CalendarEventDto>[];
    String? pageToken;
    do {
      final json = await _requestJson(
        'GET',
        _uri(
          '/calendar/v3/calendars/${_enc(calendarId)}/events/'
          '${_enc(recurringEventId)}/instances',
          query: _compactQuery({
            'timeMin': rangeStart == null ? null : _rfc3339(rangeStart),
            'timeMax': rangeEnd == null ? null : _rfc3339(rangeEnd),
            'showDeleted': 'true',
            'pageToken': pageToken,
          }),
        ),
      );
      final page = GoogleCalendarPage.fromJson(json);
      events.addAll(
        page.items.map((item) => googleCalendarEventFromJson(calendarId, item)),
      );
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return events;
  }

  @override
  Future<CalendarEventDto> moveEvent({
    required String sourceCalendarId,
    required String eventId,
    required String destinationCalendarId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri(
        '/calendar/v3/calendars/${_enc(sourceCalendarId)}/events/'
        '${_enc(eventId)}/move',
        query: {
          'destination': destinationCalendarId,
          'sendUpdates': _googleGuestUpdatePolicy(guestUpdatePolicy),
        },
      ),
    );
    return googleCalendarEventFromJson(destinationCalendarId, json);
  }

  @override
  Future<CalendarSyncPageDto> syncEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? syncTokenOrDeltaLink,
    bool primaryCalendar = false,
  }) async {
    try {
      final events = <CalendarEventDto>[];
      CalendarSyncPageDto? lastPage;
      String? pageToken;
      if (syncTokenOrDeltaLink != null && syncTokenOrDeltaLink.isNotEmpty) {
        do {
          final page = await _listEventsPage(
            calendarId: calendarId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            pageToken: pageToken,
            syncToken: syncTokenOrDeltaLink,
            singleEvents: true,
          );
          lastPage = page;
          events.addAll(page.events);
          pageToken = page.nextPageTokenOrUrl;
        } while (pageToken != null && pageToken.isNotEmpty);
        return CalendarSyncPageDto(
          events: events,
          nextSyncTokenOrDeltaLink: lastPage.nextSyncTokenOrDeltaLink,
        );
      }
      do {
        final page = await _listEventsPage(
          calendarId: calendarId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          pageToken: pageToken,
          singleEvents: true,
        );
        lastPage = page;
        events.addAll(page.events);
        pageToken = page.nextPageTokenOrUrl;
      } while (pageToken != null && pageToken.isNotEmpty);
      return CalendarSyncPageDto(
        events: events,
        nextSyncTokenOrDeltaLink: lastPage.nextSyncTokenOrDeltaLink,
      );
    } on GoogleCalendarApiError catch (error) {
      if (error.isInvalidSyncToken) {
        return const CalendarSyncPageDto(events: [], requiresFullSync: true);
      }
      rethrow;
    }
  }

  Future<CalendarSyncPageDto> _listEventsPage({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageToken,
    String? syncToken,
    required bool singleEvents,
  }) async {
    final isIncremental = syncToken != null && syncToken.isNotEmpty;
    final json = await _requestJson(
      'GET',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events',
        query: _compactQuery({
          if (!isIncremental) 'timeMin': _rfc3339(rangeStart),
          if (!isIncremental) 'timeMax': _rfc3339(rangeEnd),
          'singleEvents': singleEvents.toString(),
          'showDeleted': 'true',
          'maxResults': '2500',
          'pageToken': pageToken,
          'syncToken': syncToken,
        }),
      ),
    );
    final page = GoogleCalendarPage.fromJson(json);
    return CalendarSyncPageDto(
      events: page.items
          .map((item) => googleCalendarEventFromJson(calendarId, item))
          .toList(),
      nextPageTokenOrUrl: page.nextPageToken,
      nextSyncTokenOrDeltaLink: page.nextSyncToken,
    );
  }

  @override
  Future<List<BusySlotDto>> freeBusy({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final results = await freeBusyDetails(
      calendarIds: calendarIds,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    return [for (final result in results) ...result.busySlots];
  }

  @override
  Future<List<FreeBusyCalendarResultDto>> freeBusyDetails({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri('/calendar/v3/freeBusy'),
      body: {
        'timeMin': _rfc3339(rangeStart),
        'timeMax': _rfc3339(rangeEnd),
        'items': [
          for (final id in calendarIds) {'id': id},
        ],
      },
    );
    final calendars = json['calendars'];
    if (calendars is! Map) {
      return [
        for (final calendarId in calendarIds)
          FreeBusyCalendarResultDto(
            calendarId: calendarId,
            status: FreeBusyEvaluationStatus.missing,
          ),
      ];
    }
    final responses = {
      for (final entry in calendars.entries)
        entry.key.toString().toLowerCase(): entry,
    };
    return [
      for (final calendarId in calendarIds)
        _googleFreeBusyResult(calendarId, responses[calendarId.toLowerCase()]),
    ];
  }

  FreeBusyCalendarResultDto _googleFreeBusyResult(
    String requestedCalendarId,
    MapEntry<Object?, Object?>? entry,
  ) {
    if (entry == null) {
      return FreeBusyCalendarResultDto(
        calendarId: requestedCalendarId,
        status: FreeBusyEvaluationStatus.missing,
      );
    }
    final value = entry.value;
    if (value is! Map) {
      return FreeBusyCalendarResultDto(
        calendarId: requestedCalendarId,
        status: FreeBusyEvaluationStatus.failed,
        errors: const ['Malformed free/busy result.'],
      );
    }
    final errors = <String>[
      if (value['errors'] case final List<dynamic> values)
        for (final error in values)
          if (error is Map)
            error['reason']?.toString() ??
                error['domain']?.toString() ??
                'error'
          else
            error.toString(),
    ];
    final busy = value['busy'];
    if (busy is! List) {
      return FreeBusyCalendarResultDto(
        calendarId: requestedCalendarId,
        status: FreeBusyEvaluationStatus.failed,
        errors: errors.isEmpty ? const ['Malformed free/busy result.'] : errors,
      );
    }
    var malformedInterval = false;
    final slots = <BusySlotDto>[];
    for (final item in busy) {
      if (item is Map) {
        final start = DateTime.tryParse(item['start']?.toString() ?? '');
        final end = DateTime.tryParse(item['end']?.toString() ?? '');
        if (start != null && end != null) {
          slots.add(
            BusySlotDto(
              calendarId: entry.key.toString(),
              start: start,
              end: end,
            ),
          );
          continue;
        }
      }
      malformedInterval = true;
    }
    if (malformedInterval) errors.add('Malformed busy interval.');
    return FreeBusyCalendarResultDto(
      calendarId: requestedCalendarId,
      status: errors.isEmpty
          ? FreeBusyEvaluationStatus.success
          : FreeBusyEvaluationStatus.failed,
      busySlots: slots,
      errors: errors,
    );
  }

  Future<void> _requestEmpty(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _send(method, uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleCalendarApiError.fromResponse(response);
    }
  }

  Future<Map<String, Object?>> _requestJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
  }) async {
    final response = await _send(method, uri, body: body, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleCalendarApiError.fromResponse(response);
    }
    if (response.body.trim().isEmpty) {
      return const {};
    }
    return (jsonDecode(response.body) as Map).cast<String, Object?>();
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
    bool retried = false,
  }) async {
    final authorizationHeaderProvider = _authorizationHeaderProvider;
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authorizationHeaderProvider != null)
        'Authorization': await authorizationHeaderProvider(),
      ...headers,
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: requestHeaders),
      'POST' => await _httpClient.post(
        uri,
        headers: requestHeaders,
        body: encodedBody,
      ),
      'PATCH' => await _httpClient.patch(
        uri,
        headers: requestHeaders,
        body: encodedBody,
      ),
      'PUT' => await _httpClient.put(
        uri,
        headers: requestHeaders,
        body: encodedBody,
      ),
      'DELETE' => await _httpClient.delete(uri, headers: requestHeaders),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };
    final unauthorizedRefreshProvider = _unauthorizedRefreshProvider;
    if (response.statusCode == 401 &&
        !retried &&
        unauthorizedRefreshProvider != null) {
      await unauthorizedRefreshProvider();
      return _send(method, uri, body: body, headers: headers, retried: true);
    }
    return response;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(
      path: '$basePath$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }
}

bool _hasCalendarListColor(CalendarMutation mutation) {
  return mutation.backgroundColor != null ||
      mutation.foregroundColor != null ||
      mutation.colorId != null;
}

String _enc(String value) => Uri.encodeComponent(value);

void _validateAclUserRole(String role) {
  if (!const {
    'freeBusyReader',
    'reader',
    'writerWithoutPrivateAccess',
    'writer',
  }.contains(role)) {
    throw ArgumentError.value(role, 'role', 'Unsupported sharing role');
  }
}

String _rfc3339(DateTime value) => value.toUtc().toIso8601String();

Map<String, String> _compactQuery(Map<String, String?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null && entry.value!.isNotEmpty)
        entry.key: entry.value!,
  };
}

String _googleGuestUpdatePolicy(CalendarGuestUpdatePolicy policy) =>
    switch (policy) {
      CalendarGuestUpdatePolicy.send => 'all',
      CalendarGuestUpdatePolicy.doNotSend => 'none',
    };

String _googleInvitationResponse(CalendarInvitationResponse response) =>
    switch (response) {
      CalendarInvitationResponse.accept => 'accepted',
      CalendarInvitationResponse.tentative => 'tentative',
      CalendarInvitationResponse.decline => 'declined',
    };

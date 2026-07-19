import 'dart:convert';

import 'package:http/http.dart' as http;

import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_provider_capabilities.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../calendar_providers/cloud_calendar_client.dart';
import '../task_providers/task_provider.dart';
import 'google_calendar_errors.dart';
import 'google_calendar_mapper.dart';
import 'google_calendar_models.dart';

class GoogleCalendarApiClient implements CloudCalendarClient {
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
  BusyProvider get provider => TaskProvider.google;

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

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) async {
    final json = await _requestJson(
      'POST',
      _uri('/calendar/v3/calendars'),
      body: googleCalendarMutationToJson(mutation),
    );
    return googleCalendarSourceFromJson(json);
  }

  @override
  Future<CalendarSourceDto> updateCalendar(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    final json = await _requestJson(
      'PATCH',
      _uri('/calendar/v3/calendars/${_enc(calendarId)}'),
      body: googleCalendarMutationToJson(mutation),
    );
    return googleCalendarSourceFromJson(json);
  }

  Future<CalendarSourceDto> updateCalendarListEntry(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    final json = await _requestJson(
      'PATCH',
      _uri('/calendar/v3/users/me/calendarList/${_enc(calendarId)}'),
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
  }) async {
    final json = await _requestJson(
      'POST',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events',
        query: const {'conferenceDataVersion': '1'},
      ),
      body: googleEventMutationToJson(mutation),
    );
    return googleCalendarEventFromJson(calendarId, json);
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

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  }) async {
    final json = await _requestJson(
      'PATCH',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
        query: const {'conferenceDataVersion': '1'},
      ),
      body: googleEventMutationToJson(mutation),
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  Future<CalendarEventDto> replaceEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  }) async {
    final json = await _requestJson(
      'PUT',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
        query: const {'conferenceDataVersion': '1'},
      ),
      body: googleEventMutationToJson(mutation),
    );
    return googleCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) {
    return _requestEmpty(
      'DELETE',
      _uri(
        '/calendar/v3/calendars/${_enc(calendarId)}/events/${_enc(eventId)}',
      ),
    );
  }

  @override
  Future<List<CalendarEventDto>> listEventInstances({
    required String calendarId,
    required String recurringEventId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final events = <CalendarEventDto>[];
    String? pageToken;
    do {
      final json = await _requestJson(
        'GET',
        _uri(
          '/calendar/v3/calendars/${_enc(calendarId)}/events/'
          '${_enc(recurringEventId)}/instances',
          query: _compactQuery({
            'timeMin': _rfc3339(rangeStart),
            'timeMax': _rfc3339(rangeEnd),
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

  Future<CalendarEventDto> moveEvent({
    required String sourceCalendarId,
    required String eventId,
    required String destinationCalendarId,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri(
        '/calendar/v3/calendars/${_enc(sourceCalendarId)}/events/'
        '${_enc(eventId)}/move',
        query: {'destination': destinationCalendarId},
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
            singleEvents: false,
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
          singleEvents: false,
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
      return const [];
    }
    final slots = <BusySlotDto>[];
    for (final entry in calendars.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final busy = value['busy'];
      if (busy is! List) {
        continue;
      }
      for (final item in busy.whereType<Map>()) {
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
        }
      }
    }
    return slots;
  }

  Future<void> _requestEmpty(String method, Uri uri) async {
    final response = await _send(method, uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleCalendarApiError.fromResponse(response);
    }
  }

  Future<Map<String, Object?>> _requestJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(method, uri, body: body);
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
    bool retried = false,
  }) async {
    final authorizationHeaderProvider = _authorizationHeaderProvider;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authorizationHeaderProvider != null)
        'Authorization': await authorizationHeaderProvider(),
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: headers),
      'POST' => await _httpClient.post(
        uri,
        headers: headers,
        body: encodedBody,
      ),
      'PATCH' => await _httpClient.patch(
        uri,
        headers: headers,
        body: encodedBody,
      ),
      'PUT' => await _httpClient.put(uri, headers: headers, body: encodedBody),
      'DELETE' => await _httpClient.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };
    final unauthorizedRefreshProvider = _unauthorizedRefreshProvider;
    if (response.statusCode == 401 &&
        !retried &&
        unauthorizedRefreshProvider != null) {
      await unauthorizedRefreshProvider();
      return _send(method, uri, body: body, retried: true);
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

String _enc(String value) => Uri.encodeComponent(value);

String _rfc3339(DateTime value) => value.toUtc().toIso8601String();

Map<String, String> _compactQuery(Map<String, String?> values) {
  return {
    for (final entry in values.entries)
      if (entry.value != null && entry.value!.isNotEmpty)
        entry.key: entry.value!,
  };
}

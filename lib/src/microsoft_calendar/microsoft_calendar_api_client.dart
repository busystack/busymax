import 'dart:convert';

import 'package:http/http.dart' as http;

import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_provider_capabilities.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../calendar_providers/cloud_calendar_client.dart';
import '../task_providers/task_provider.dart';
import 'microsoft_calendar_errors.dart';
import 'microsoft_calendar_mapper.dart';
import 'microsoft_calendar_models.dart';

class MicrosoftCalendarApiClient implements CloudCalendarClient {
  MicrosoftCalendarApiClient({
    required http.Client httpClient,
    required Uri baseUri,
    required String responseTimeZone,
    Future<String> Function()? authorizationHeaderProvider,
    Future<void> Function()? unauthorizedRefreshProvider,
  }) : _httpClient = httpClient,
       _baseUri = baseUri,
       _responseTimeZone = responseTimeZone,
       _authorizationHeaderProvider = authorizationHeaderProvider,
       _unauthorizedRefreshProvider = unauthorizedRefreshProvider;

  final http.Client _httpClient;
  final Uri _baseUri;
  final String _responseTimeZone;
  final Future<String> Function()? _authorizationHeaderProvider;
  final Future<void> Function()? _unauthorizedRefreshProvider;

  @override
  BusyProvider get provider => TaskProvider.microsoft;

  @override
  CalendarProviderCapabilities get capabilities =>
      microsoftCalendarProviderCapabilities;

  @override
  Future<List<CalendarSourceDto>> listCalendars() async {
    final calendars = <CalendarSourceDto>[];
    Uri? uri = _uri('/me/calendars');
    while (uri != null) {
      final page = MicrosoftGraphCollectionPage.fromJson(
        await _requestJson('GET', uri),
      );
      calendars.addAll(page.items.map(microsoftCalendarSourceFromJson));
      uri = _fullUriOrNull(page.nextLink);
    }
    return calendars;
  }

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) async {
    final json = await _requestJson(
      'POST',
      _uri('/me/calendars'),
      body: microsoftCalendarMutationToJson(mutation),
    );
    return microsoftCalendarSourceFromJson(json);
  }

  @override
  Future<CalendarSourceDto> updateCalendar(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    final json = await _requestJson(
      'PATCH',
      _uri('/me/calendars/${_enc(calendarId)}'),
      body: microsoftCalendarMutationToJson(mutation),
    );
    return microsoftCalendarSourceFromJson(json);
  }

  @override
  Future<void> deleteCalendar(String calendarId) {
    return _requestEmpty('DELETE', _uri('/me/calendars/${_enc(calendarId)}'));
  }

  @override
  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  }) async {
    final events = <CalendarEventDto>[];
    Uri? uri = pageTokenOrUrl == null
        ? _calendarViewUri(
            calendarId: calendarId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          )
        : _fullUriOrNull(pageTokenOrUrl);
    while (uri != null) {
      final page = MicrosoftGraphCollectionPage.fromJson(
        await _requestJson('GET', uri),
      );
      events.addAll(
        page.items.map(
          (item) => microsoftCalendarEventFromJson(calendarId, item),
        ),
      );
      uri = pageTokenOrUrl == null ? _fullUriOrNull(page.nextLink) : null;
    }
    return events;
  }

  Future<List<CalendarEventDto>> listSeriesMasters({
    required String calendarId,
    String? nextLink,
  }) async {
    final page = MicrosoftGraphCollectionPage.fromJson(
      await _requestJson(
        'GET',
        nextLink == null
            ? _uri('/me/calendars/${_enc(calendarId)}/events')
            : Uri.parse(nextLink),
      ),
    );
    return page.items
        .map((item) => microsoftCalendarEventFromJson(calendarId, item))
        .toList();
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri('/me/calendars/${_enc(calendarId)}/events'),
      body: microsoftEventMutationToJson(mutation),
    );
    return microsoftCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    final json = await _requestJson(
      'GET',
      _uri('/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}'),
    );
    return microsoftCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  }) async {
    final json = await _requestJson(
      'PATCH',
      _uri('/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}'),
      body: microsoftEventMutationToJson(mutation),
    );
    return microsoftCalendarEventFromJson(calendarId, json);
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) {
    return _requestEmpty(
      'DELETE',
      _uri('/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}'),
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
    Uri? uri = _uri(
      '/me/calendars/${_enc(calendarId)}/events/${_enc(recurringEventId)}'
      '/instances',
      query: {
        'startDateTime': _graphDateTime(rangeStart),
        'endDateTime': _graphDateTime(rangeEnd),
      },
    );
    while (uri != null) {
      final page = MicrosoftGraphCollectionPage.fromJson(
        await _requestJson('GET', uri),
      );
      events.addAll(
        page.items.map(
          (item) => microsoftCalendarEventFromJson(calendarId, item),
        ),
      );
      uri = _fullUriOrNull(page.nextLink);
    }
    return events;
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
      final hasContinuation =
          syncTokenOrDeltaLink != null && syncTokenOrDeltaLink.isNotEmpty;
      final uri = hasContinuation
          ? Uri.parse(syncTokenOrDeltaLink)
          : primaryCalendar
          ? _primaryCalendarViewDeltaUri(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            )
          : _calendarViewUri(
              calendarId: calendarId,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            );
      final page = await _collectionPage(uri);
      return CalendarSyncPageDto(
        events: page.items
            .map((item) => microsoftCalendarEventFromJson(calendarId, item))
            .toList(),
        nextPageTokenOrUrl: page.nextLink,
        nextSyncTokenOrDeltaLink: page.deltaLink,
      );
    } on MicrosoftCalendarApiError catch (error) {
      if (syncTokenOrDeltaLink != null &&
          syncTokenOrDeltaLink.isNotEmpty &&
          error.isInvalidSyncState) {
        return const CalendarSyncPageDto(events: [], requiresFullSync: true);
      }
      rethrow;
    }
  }

  @override
  Future<List<BusySlotDto>> freeBusy({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    return const [];
  }

  Future<MicrosoftGraphCollectionPage> _collectionPage(Uri uri) async {
    return MicrosoftGraphCollectionPage.fromJson(
      await _requestJson('GET', uri),
    );
  }

  Uri _calendarViewUri({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _uri(
      '/me/calendars/${_enc(calendarId)}/calendarView',
      query: {
        'startDateTime': _graphDateTime(rangeStart),
        'endDateTime': _graphDateTime(rangeEnd),
      },
    );
  }

  Uri _primaryCalendarViewDeltaUri({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _uri(
      '/me/calendarView/delta',
      query: {
        'startDateTime': _graphDateTime(rangeStart),
        'endDateTime': _graphDateTime(rangeEnd),
      },
    );
  }

  Future<void> _requestEmpty(String method, Uri uri) async {
    final response = await _send(method, uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MicrosoftCalendarApiError.fromResponse(response);
    }
  }

  Future<Map<String, Object?>> _requestJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(method, uri, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MicrosoftCalendarApiError.fromResponse(response);
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
      'Prefer': 'outlook.timezone="$_responseTimeZone"',
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

Uri? _fullUriOrNull(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return Uri.parse(value);
}

String _enc(String value) => Uri.encodeComponent(value);

String _graphDateTime(DateTime value) => value.toUtc().toIso8601String();

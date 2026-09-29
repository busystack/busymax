import 'dart:convert';

import 'package:http/http.dart' as http;

import '../calendar_providers/calendar_mutation.dart';
import '../calendar_providers/calendar_provider_capabilities.dart';
import '../calendar_providers/calendar_sync_dto.dart';
import '../calendar_providers/cloud_calendar_client.dart';
import '../core/time/provider_date_time.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'microsoft_calendar_errors.dart';
import 'microsoft_calendar_mapper.dart';
import 'microsoft_calendar_models.dart';
import 'microsoft_event_attachment.dart';

class MicrosoftCalendarApiClient
    implements CloudCalendarClient, DetailedFreeBusyClient {
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
  BusyProvider get provider => BusyProvider.microsoft;

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

  /// Loads metadata only. Graph does not include attachments in the normal
  /// event feed, and its hasAttachments flag does not imply an empty list.
  Future<List<MicrosoftEventAttachment>> listEventAttachments({
    required String calendarId,
    required String eventId,
  }) async {
    final result = <MicrosoftEventAttachment>[];
    final seen = <Uri>{};
    Uri? uri = _uri(
      '/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}/attachments',
    );
    while (uri != null) {
      if (!seen.add(uri)) {
        throw const FormatException('Attachment pagination loop.');
      }
      final page = MicrosoftGraphCollectionPage.fromJson(
        await _requestJson('GET', uri),
      );
      result.addAll(page.items.map(MicrosoftEventAttachment.fromJson));
      uri = page.nextLink == null ? null : _trustedNextLink(page.nextLink!);
    }
    return result;
  }

  Future<List<int>> downloadEventAttachment({
    required String calendarId,
    required String eventId,
    required MicrosoftEventAttachment attachment,
  }) async {
    if (!attachment.canDownload) {
      throw UnsupportedError(
        'This attachment has no downloadable file content.',
      );
    }
    final response = await _send(
      'GET',
      _uri(
        '/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}'
        '/attachments/${_enc(attachment.id)}/\$value',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MicrosoftCalendarApiError.fromResponse(response);
    }
    return response.bodyBytes;
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
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
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
    String? ifMatch,
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
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
    String? ifMatch,
  }) {
    return _requestEmpty(
      'DELETE',
      _uri('/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}'),
    );
  }

  @override
  Future<CalendarEventDto> moveEvent({
    required String sourceCalendarId,
    required String eventId,
    required String destinationCalendarId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) {
    throw UnsupportedError(
      'Microsoft Graph does not expose an event move operation.',
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
    await _requestEmpty(
      'POST',
      _uri(
        '/me/calendars/${_enc(calendarId)}/events/${_enc(eventId)}/'
        '${_microsoftInvitationAction(response)}',
      ),
      body: {'sendResponse': sendResponse},
    );
    return null;
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
    final results = await freeBusyDetails(
      calendarIds: calendarIds,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    if (results.any((result) => !result.succeeded)) {
      throw StateError('Microsoft availability is incomplete.');
    }
    return [for (final result in results) ...result.busySlots];
  }

  @override
  Future<List<FreeBusyCalendarResultDto>> freeBusyDetails({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    if (calendarIds.isEmpty) return const [];
    List<FreeBusyCalendarResultDto> failed(String reason) => [
      for (final id in calendarIds)
        FreeBusyCalendarResultDto(
          calendarId: id,
          status: FreeBusyEvaluationStatus.failed,
          errors: [reason],
        ),
    ];
    final start = rangeStart.toUtc();
    final end = rangeEnd.toUtc();
    if (!end.isAfter(start) ||
        end.difference(start) >= const Duration(days: 62)) {
      return failed(
        'Microsoft availability requires a positive range shorter than 62 days.',
      );
    }
    final authorization = _authorizationHeaderProvider;
    if (authorization != null) {
      try {
        if (_isPersonalMicrosoftBearer(await authorization())) {
          return failed(
            'Microsoft personal accounts do not support availability lookup.',
          );
        }
      } on Object catch (error) {
        return failed('$error');
      }
    }
    final results = <FreeBusyCalendarResultDto>[];
    for (var offset = 0; offset < calendarIds.length; offset += 20) {
      final batch = calendarIds.skip(offset).take(20).toList();
      final requested = batch.where((id) => id.trim().isNotEmpty).toList();
      final mapped = <String, FreeBusyCalendarResultDto>{};
      for (final id in batch.where((id) => id.trim().isEmpty)) {
        mapped[id.toLowerCase()] = FreeBusyCalendarResultDto(
          calendarId: id,
          status: FreeBusyEvaluationStatus.failed,
          errors: const ['A recipient address is required.'],
        );
      }
      if (requested.isNotEmpty) {
        try {
          final response = await _requestJson(
            'POST',
            _uri('/me/calendar/getSchedule'),
            body: {
              'schedules': requested,
              'startTime': _utcScheduleTime(start),
              'endTime': _utcScheduleTime(end),
              'availabilityViewInterval': 30,
            },
          );
          final value = response['value'];
          if (value is! List) {
            throw const FormatException(
              'Microsoft availability response has no recipient results.',
            );
          }
          for (final raw in value) {
            if (raw is! Map) continue;
            final item = raw.cast<String, Object?>();
            final id = item['scheduleId']?.toString();
            if (id == null ||
                !requested.any(
                  (requestedId) =>
                      requestedId.toLowerCase() == id.toLowerCase(),
                )) {
              continue;
            }
            mapped[id.toLowerCase()] = _scheduleResult(id, item);
          }
        } on Object catch (error) {
          for (final id in requested) {
            mapped[id.toLowerCase()] = FreeBusyCalendarResultDto(
              calendarId: id,
              status: FreeBusyEvaluationStatus.failed,
              errors: ['$error'],
            );
          }
        }
      }
      for (final id in batch) {
        results.add(
          mapped[id.toLowerCase()] ??
              FreeBusyCalendarResultDto(
                calendarId: id,
                status: FreeBusyEvaluationStatus.missing,
                errors: const ['The provider omitted this recipient.'],
              ),
        );
      }
    }
    return results;
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

  Future<void> _requestEmpty(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(method, uri, body: body);
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

  Uri _trustedNextLink(String value) {
    final uri = Uri.tryParse(value);
    final pathPrefix = _baseUri.path.endsWith('/')
        ? _baseUri.path
        : '${_baseUri.path}/';
    if (uri == null ||
        uri.scheme != _baseUri.scheme ||
        uri.host != _baseUri.host ||
        uri.port != _baseUri.port ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith(pathPrefix)) {
      throw const FormatException(
        'Untrusted Microsoft Graph continuation URL.',
      );
    }
    return uri;
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

Map<String, String> _utcScheduleTime(DateTime value) => {
  'dateTime': value.toUtc().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
  'timeZone': 'UTC',
};

bool _isPersonalMicrosoftBearer(String authorization) {
  final token = authorization.replaceFirst(
    RegExp(r'^Bearer\s+', caseSensitive: false),
    '',
  );
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return claims is Map &&
        claims['tid']?.toString().toLowerCase() ==
            '9188040d-6c67-4c5b-b112-36a304b66dad';
  } on Object {
    return false;
  }
}

FreeBusyCalendarResultDto _scheduleResult(
  String id,
  Map<String, Object?> response,
) {
  final error = response['error'];
  if (error is Map) {
    final code = error['responseCode']?.toString();
    final message = error['message']?.toString();
    return FreeBusyCalendarResultDto(
      calendarId: id,
      status: FreeBusyEvaluationStatus.failed,
      errors: [
        if (code != null && code.isNotEmpty) code,
        if (message != null && message.isNotEmpty) message,
      ],
    );
  }
  final items = response['scheduleItems'];
  if (items is! List) {
    return FreeBusyCalendarResultDto(
      calendarId: id,
      status: FreeBusyEvaluationStatus.missing,
      errors: const ['The provider omitted schedule information.'],
    );
  }
  final slots = <BusySlotDto>[];
  for (final raw in items) {
    if (raw is! Map) {
      return FreeBusyCalendarResultDto(
        calendarId: id,
        status: FreeBusyEvaluationStatus.failed,
        errors: const ['Invalid schedule item.'],
      );
    }
    final item = raw.cast<String, Object?>();
    final status = item['status']?.toString().toLowerCase();
    if (status == 'free' || status == 'workingelsewhere') continue;
    if (status != 'busy' && status != 'tentative' && status != 'oof') {
      return FreeBusyCalendarResultDto(
        calendarId: id,
        status: FreeBusyEvaluationStatus.failed,
        errors: const ['Unknown schedule item status.'],
      );
    }
    final startValue = item['start'];
    final endValue = item['end'];
    if (startValue is! Map || endValue is! Map) {
      return FreeBusyCalendarResultDto(
        calendarId: id,
        status: FreeBusyEvaluationStatus.failed,
        errors: const ['Schedule item is missing its interval.'],
      );
    }
    final start = providerDateTimeAsUtcInstant(
      startValue['dateTime']?.toString(),
      startValue['timeZone']?.toString(),
    );
    final end = providerDateTimeAsUtcInstant(
      endValue['dateTime']?.toString(),
      endValue['timeZone']?.toString(),
    );
    if (start == null || end == null || !end.isAfter(start)) {
      return FreeBusyCalendarResultDto(
        calendarId: id,
        status: FreeBusyEvaluationStatus.failed,
        errors: const ['Schedule item has an invalid interval.'],
      );
    }
    slots.add(BusySlotDto(calendarId: id, start: start, end: end));
  }
  return FreeBusyCalendarResultDto(
    calendarId: id,
    status: FreeBusyEvaluationStatus.success,
    busySlots: slots,
  );
}

String _microsoftInvitationAction(CalendarInvitationResponse response) =>
    switch (response) {
      CalendarInvitationResponse.accept => 'accept',
      CalendarInvitationResponse.tentative => 'tentativelyAccept',
      CalendarInvitationResponse.decline => 'decline',
    };

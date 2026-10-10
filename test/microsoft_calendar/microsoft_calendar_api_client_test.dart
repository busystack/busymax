import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_models.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_event_attachment.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final refreshFails in [false, true]) {
    test(
      'attachment streaming refreshes ordinary 401 (failure=$refreshFails)',
      () async {
        var requests = 0, refreshes = 0;
        final client = MicrosoftCalendarApiClient(
          httpClient: MockClient((request) async {
            requests++;
            expect(
              request.url.path.endsWith('/attachments/file/\$value'),
              isTrue,
            );
            return requests == 1
                ? http.Response('{}', 401)
                : http.Response.bytes([1, 2, 3], 200);
          }),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          responseTimeZone: 'UTC',

          authorizationHeaderProvider: () async =>
              refreshes == 0 ? 'Bearer old' : 'Bearer new',
          unauthorizedRefreshProvider: () async {
            refreshes++;
            if (refreshFails) throw StateError('fixture refresh failed');
          },
        );
        final download = client.downloadEventAttachment(
          calendarId: 'cal',
          eventId: 'event',
          attachment: const MicrosoftEventAttachment(
            id: 'file',
            name: 'fixture.bin',
            kind: MicrosoftEventAttachmentKind.file,
          ),
        );
        if (refreshFails) {
          await expectLater(
            download,
            throwsA(
              isA<KnownUnsentRequestException>().having(
                (e) => e.kind,
                'kind',
                RequestPreDispatchFailureKind.authentication,
              ),
            ),
          );
          expect(requests, 1);
        } else {
          expect(await download, [1, 2, 3]);
          expect(requests, 2);
        }
        expect(refreshes, 1);
      },
    );
  }

  test(
    'primary permission 429 retains code and Retry-After without retrying',
    () async {
      var requests = 0;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'error': {'code': 'TooManyRequests', 'message': 'Throttled'},
            }),
            429,
            headers: {'retry-after': '113'},
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      await expectLater(
        client.addPrimaryCalendarPermission(
          email: 'friend@example.test',
          role: 'read',
        ),
        throwsA(
          isA<MicrosoftCalendarApiError>()
              .having((e) => e.statusCode, 'status', 429)
              .having((e) => e.code, 'code', 'TooManyRequests')
              .having((e) => e.isRateLimited, 'throttle', true)
              .having(
                (e) => e.retryAfter,
                'retry-after',
                const Duration(seconds: 113),
              ),
        ),
      );
      expect(requests, 1);
    },
  );

  test('primary permission ignores an unusable Retry-After value', () async {
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'TooManyRequests', 'message': 'Throttled'},
          }),
          429,
          headers: {'retry-after': 'invalid'},
        ),
      ),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    await expectLater(
      client.addPrimaryCalendarPermission(
        email: 'friend@example.test',
        role: 'read',
      ),
      throwsA(
        isA<MicrosoftCalendarApiError>()
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.retryAfter, 'retry-after', isNull),
      ),
    );
  });

  test('primary sharing authorization fails before Graph dispatch', () async {
    const failure = OAuthException('TokenUnavailable', 'Token unavailable');
    var requests = 0;
    var ordinaryHeaders = 0;
    var sharedHeaders = 0;
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        requests++;
        return _json({'value': <Object>[]});
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      authorizationHeaderProvider: () async {
        ordinaryHeaders++;
        throw failure;
      },
      sharedCalendarAuthorizationHeaderProvider: () async {
        sharedHeaders++;
        return 'Bearer shared';
      },
    );
    await expectLater(
      client.addPrimaryCalendarPermission(
        email: 'friend@example.test',
        role: 'read',
      ),
      throwsA(
        isA<RequestNotDispatchedException>()
            .having(
              (error) => error.kind,
              'kind',
              RequestPreDispatchFailureKind.authentication,
            )
            .having((error) => error.cause, 'cause', same(failure)),
      ),
    );
    expect(requests, 0);
    expect(ordinaryHeaders, 1);
    expect(sharedHeaders, 0);
  });

  test('primary sharing 401 and failed refresh is known uncommitted', () async {
    const failure = OAuthRefreshException(
      'RefreshDenied',
      'Refresh denied',
      statusCode: 400,
    );
    var recovered = false;
    var requests = 0;
    var refreshes = 0;
    var sharedHeaders = 0;
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        requests++;
        if (!recovered) return http.Response('{}', 401);
        return _json({
          'id': 'grant',
          'role': 'read',
          'allowedRoles': ['read', 'write'],
          'isRemovable': true,
          'emailAddress': {'address': 'friend@example.test'},
        });
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      authorizationHeaderProvider: () async => 'Bearer calendar',
      sharedCalendarAuthorizationHeaderProvider: () async {
        sharedHeaders++;
        return 'Bearer shared';
      },
      unauthorizedRefreshProvider: () async {
        refreshes++;
        throw failure;
      },
    );
    await expectLater(
      client.addPrimaryCalendarPermission(
        email: 'friend@example.test',
        role: 'read',
      ),
      throwsA(
        isA<RequestNotDispatchedException>()
            .having(
              (error) => error.kind,
              'kind',
              RequestPreDispatchFailureKind.authentication,
            )
            .having((error) => error.cause, 'cause', same(failure)),
      ),
    );
    expect(requests, 1);
    expect(refreshes, 1);
    expect(sharedHeaders, 0);
    recovered = true;
    await client.addPrimaryCalendarPermission(
      email: 'friend@example.test',
      role: 'read',
    );
    expect(requests, 2);
    expect(refreshes, 1);
  });

  test('lost Graph sharing response is not known-unsent', () async {
    var requests = 0;
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        requests++;
        throw http.ClientException('response lost');
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      authorizationHeaderProvider: () async => 'Bearer calendar',
    );
    await expectLater(
      client.addPrimaryCalendarPermission(
        email: 'friend@example.test',
        role: 'read',
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(requests, 1);
  });

  test(
    'primary calendar permissions paginate and enforce allowed roles',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        if (request.method == 'GET') {
          return _json({
            'value': [
              {
                'id': 'grant',
                'role': 'read',
                'allowedRoles': ['read', 'write'],
                'isRemovable': true,
                'emailAddress': {'address': 'alex@example.test'},
              },
            ],
            if (request.url.queryParameters[r'$skiptoken'] == null)
              '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/calendar/calendarPermissions?%24skiptoken=next',
          });
        }
        if (request.method == 'DELETE') return http.Response('', 204);
        return _json({
          'id': 'grant',
          'role': request.method == 'POST'
              ? 'read'
              : jsonDecode(request.body)['role'],
          'allowedRoles': ['read', 'write'],
          'isRemovable': true,
          'emailAddress': {'address': 'alex@example.test'},
        });
      });
      final grants = await client.listPrimaryCalendarPermissions();
      expect(grants, hasLength(2));
      expect(requests.last.url.queryParameters[r'$skiptoken'], 'next');
      final created = await client.addPrimaryCalendarPermission(
        email: 'alex@example.test',
        role: 'read',
      );
      expect(created.address, 'alex@example.test');
      expect(jsonDecode(requests.last.body), {
        'emailAddress': {'address': 'alex@example.test'},
        'role': 'read',
      });
      await client.changePrimaryCalendarPermission(grants.first, 'write');
      expect(requests.last.method, 'PATCH');
      await expectLater(
        client.changePrimaryCalendarPermission(
          grants.first,
          'delegateWithPrivateEventAccess',
        ),
        throwsArgumentError,
      );
      await client.revokePrimaryCalendarPermission(grants.first);
      expect(requests.last.method, 'DELETE');
      const nonRemovable = MicrosoftCalendarPermission(
        id: 'default',
        role: 'freeBusyRead',
        allowedRoles: ['read'],
        isRemovable: false,
      );
      expect(
        () => client.revokePrimaryCalendarPermission(nonRemovable),
        throwsArgumentError,
      );
      expect(
        (await client.changePrimaryCalendarPermission(
          nonRemovable,
          'read',
        )).role,
        'read',
      );
    },
  );
  test(
    'master category lookup paginates and keeps every named color',
    () async {
      final requests = <http.Request>[];
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.queryParameters[r'$skiptoken'] == 'next') {
            return _json({
              'value': [
                {'id': 'c2', 'displayName': 'Personal', 'color': 'preset1'},
              ],
            });
          }
          return _json({
            'value': [
              {'id': 'c1', 'displayName': 'Work', 'color': 'preset7'},
            ],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/outlook/masterCategories?%24skiptoken=next',
          });
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final categories = await client.listMasterCategories();
      expect(categories.map((item) => item.displayName), ['Work', 'Personal']);
      expect(categories.map((item) => item.color), ['preset7', 'preset1']);
      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/v1.0/me/outlook/masterCategories');
    },
  );

  test('malformed master category response does not look empty', () async {
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((_) async => _json({'value': null})),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    await expectLater(client.listMasterCategories(), throwsFormatException);
  });

  test('master categories use the optional category grant, not ordinary calendar authorization', () async {
    final headers = <String>[];
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        headers.add(request.headers['Authorization'] ?? '');
        return _json({'value': <Object>[]});
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      authorizationHeaderProvider: () async => 'Bearer calendar',
      categoryAuthorizationHeaderProvider: () async => 'Bearer categories',
    );
    expect(await client.listMasterCategories(), isEmpty);
    await client.listCalendars();
    expect(headers, ['Bearer categories', 'Bearer calendar']);
  });

  test(
    'series exception snapshot retains moved and cancelled identities',
    () async {
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1.0/me/calendars/cal/events/master');
          expect(
            request.url.queryParameters[r'$expand'],
            'exceptionOccurrences',
          );
          return _json({
            'id': 'master',
            'exceptionOccurrences': [
              {
                ..._eventJson(id: 'moved', subject: 'Moved'),
                'originalStart': '2026-08-31T16:00:00Z',
                'seriesMasterId': 'master',
              },
            ],
            'cancelledOccurrences': ['occurrence-2'],
          });
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final snapshot = await client.getSeriesExceptionSnapshot(
        calendarId: 'cal',
        recurringEventId: 'master',
      );
      expect(
        snapshot.exceptions.single.providerOriginalStartKey,
        '2026-08-31T16:00:00Z',
      );
      expect(snapshot.cancelledIds, {'occurrence-2'});
    },
  );
  test(
    'delegated primary routes retain owner mailbox and use shared consent',
    () async {
      final requests = <http.Request>[];
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/calendar')) {
            return _json({
              'id': 'owner-calendar-id',
              'name': 'Owner',
              'canEdit': true,
              'isDefaultCalendar': true,
            });
          }
          if (path.endsWith('/attachments')) {
            return _json({'value': <Object>[]});
          }
          if (path.endsWith('/calendarView') || path.endsWith('/instances')) {
            return _json({
              'value': [_eventJson(id: 'owner-event', subject: 'Shared')],
            });
          }
          return _json(_eventJson(id: 'owner-event', subject: 'Shared'));
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
        authorizationHeaderProvider: () async => 'Bearer ordinary',
        sharedCalendarAuthorizationHeaderProvider: () async => 'Bearer shared',
      );
      final source = await client.getSharedPrimaryCalendar('owner@example.com');
      final key = source.providerCalendarId;
      expect(source.primaryCalendar, isFalse);
      expect(source.readOnly, isFalse);
      expect(
        MicrosoftSharedPrimaryCalendarAddress.parse(key)?.graphCalendarId,
        'owner-calendar-id',
      );
      final start = DateTime.utc(2026, 6, 1);
      final end = DateTime.utc(2026, 7, 1);
      await client.listEvents(
        calendarId: key,
        rangeStart: start,
        rangeEnd: end,
      );
      await client.getEvent(calendarId: key, eventId: 'owner-event');
      await client.updateEvent(
        calendarId: key,
        eventId: 'owner-event',
        mutation: const CalendarEventMutation(title: 'Updated'),
      );
      await client.listEventInstances(
        calendarId: key,
        recurringEventId: 'master',
        rangeStart: start,
        rangeEnd: end,
      );
      await client.listEventAttachments(
        calendarId: key,
        eventId: 'owner-event',
      );
      expect(requests, hasLength(6));
      for (final request in requests) {
        expect(
          request.url.path,
          startsWith('/v1.0/users/owner%40example.com/'),
        );
        expect(request.headers['authorization'], 'Bearer shared');
      }
      expect(
        requests[1].url.path,
        contains('/calendars/owner-calendar-id/calendarView'),
      );
      expect(requests[4].url.path, contains('/events/master/instances'));
    },
  );

  test('malformed event attachment collection does not become empty', () async {
    final client = _client((_) => _json({'error': 'missing collection'}));
    await expectLater(
      client.listEventAttachments(calendarId: 'cal', eventId: 'event'),
      throwsFormatException,
    );
  });

  test(
    'small event attachment add and removal use event-scoped routes',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : _json({
                'id': 'attachment-1',
                'name': 'Plan.txt',
                '@odata.type': '#microsoft.graph.fileAttachment',
              });
      });
      final created = await client.createSmallEventAttachment(
        calendarId: 'cal',
        eventId: 'event',
        name: 'Plan.txt',
        contentType: 'text/plain',
        bytes: [65],
      );
      await client.deleteEventAttachment(
        calendarId: 'cal',
        eventId: 'event',
        attachmentId: created.id,
      );
      expect(requests.map((request) => request.method), ['POST', 'DELETE']);
      expect(
        requests.first.url.path,
        '/v1.0/me/calendars/cal/events/event/attachments',
      );
      expect((jsonDecode(requests.first.body) as Map)['contentBytes'], 'QQ==');
      expect(
        requests.last.url.path,
        '/v1.0/me/calendars/cal/events/event/attachments/attachment-1',
      );
    },
  );

  test(
    'large event attachment upload never sends Graph bearer to upload URL',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        if (request.method == 'POST') {
          return _json({
            'uploadUrl': 'https://outlook.office.com/upload/session',
            'nextExpectedRanges': ['0-'],
            'expirationDateTime': '2099-01-01T00:00:00Z',
          });
        }
        return request.headers['Content-Range']!.startsWith('bytes 2097152-')
            ? http.Response(
                '',
                201,
                headers: {
                  'Location': "https://outlook.office.com/api/v2.0/Events('event')/Attachments('new-id')",
                },
              )
            : _json({
                'nextExpectedRanges': ['2097152-'],
              });
      });
      final id = await client.uploadEventFileAttachment(
        calendarId: 'cal',
        eventId: 'event',
        name: 'large.bin',
        contentType: 'application/octet-stream',
        bytes: List<int>.filled(3 * 1024 * 1024, 65),
      );
      expect(id, 'new-id');
      expect(
        requests.first.url.path,
        '/v1.0/me/events/event/attachments/createUploadSession',
      );
      expect(requests.first.headers['authorization'], 'Bearer token');
      expect(requests.skip(1).map((request) => request.method), ['PUT', 'PUT']);
      expect(
        requests
            .skip(1)
            .every((request) => !request.headers.containsKey('authorization')),
        isTrue,
      );
    },
  );

  test(
    'event attachment metadata paginates without treating flags as files',
    () async {
      final paths = <String>[];
      final client = _client((request) {
        paths.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer token');
        return request.url.queryParameters.containsKey(r'$skiptoken')
            ? _json({
                'value': [
                  {
                    'id': 'ref',
                    'name': 'Plan',
                    '@odata.type': '#microsoft.graph.referenceAttachment',
                    'sourceUrl': 'https://example.test/plan',
                  },
                ],
              })
            : _json({
                'value': [
                  {
                    'id': 'file',
                    'name': 'Agenda.pdf',
                    '@odata.type': '#microsoft.graph.fileAttachment',
                    'size': 5,
                  },
                ],
                '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/calendars/cal/events/event/attachments?\$skiptoken=next',
              });
      });
      final attachments = await client.listEventAttachments(
        calendarId: 'cal',
        eventId: 'event',
      );
      expect(paths, [
        '/v1.0/me/calendars/cal/events/event/attachments',
        '/v1.0/me/calendars/cal/events/event/attachments',
      ]);
      expect(attachments.map((attachment) => attachment.kind), [
        MicrosoftEventAttachmentKind.file,
        MicrosoftEventAttachmentKind.reference,
      ]);
      expect(attachments.first.size, 5);
      expect(attachments.last.canDownload, isFalse);
    },
  );

  test(
    'event attachment download is explicit and rejects reference kinds',
    () async {
      final client = _client((request) {
        expect(
          request.url.path,
          r'/v1.0/me/calendars/cal/events/event/attachments/file/$value',
        );
        return http.Response.bytes([1, 2, 3], 200);
      });
      final data = await client.downloadEventAttachment(
        calendarId: 'cal',
        eventId: 'event',
        attachment: const MicrosoftEventAttachment(
          id: 'file',
          name: 'a.bin',
          kind: MicrosoftEventAttachmentKind.file,
        ),
      );
      expect(data, [1, 2, 3]);
      expect(
        () => client.downloadEventAttachment(
          calendarId: 'cal',
          eventId: 'event',
          attachment: const MicrosoftEventAttachment(
            id: 'ref',
            name: 'link',
            kind: MicrosoftEventAttachmentKind.reference,
          ),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'untrusted attachment pagination never forwards authorization',
    () async {
      var calls = 0;
      final client = _client((request) {
        calls++;
        return _json({
          'value': [],
          '@odata.nextLink': 'https://attacker.example/steal',
        });
      });
      await expectLater(
        client.listEventAttachments(calendarId: 'cal', eventId: 'event'),
        throwsFormatException,
      );
      expect(calls, 1);
    },
  );

  test(
    'getSchedule preserves mixed recipient outcomes and UTC intervals',
    () async {
      late http.Request captured;
      final client = _client((request) {
        captured = request;
        return _json({
          'value': [
            {
              'scheduleId': 'busy@example.test',
              'scheduleItems': [
                {
                  'status': 'busy',
                  'start': {
                    'dateTime': '2026-03-08T09:00:00',
                    'timeZone': 'UTC',
                  },
                  'end': {'dateTime': '2026-03-08T10:00:00', 'timeZone': 'UTC'},
                },
              ],
            },
            {'scheduleId': 'free@example.test', 'scheduleItems': []},
            {
              'scheduleId': 'denied@example.test',
              'error': {'responseCode': '5003', 'message': 'No access'},
            },
          ],
        });
      });
      final results = await client.freeBusyDetails(
        calendarIds: const [
          'busy@example.test',
          'free@example.test',
          'denied@example.test',
          'missing@example.test',
        ],
        rangeStart: DateTime.utc(2026, 3, 8),
        rangeEnd: DateTime.utc(2026, 3, 9),
      );
      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1.0/me/calendar/getSchedule');
      expect((jsonDecode(captured.body) as Map)['startTime'], {
        'dateTime': '2026-03-08T00:00:00.000',
        'timeZone': 'UTC',
      });
      expect(results.map((result) => result.status), [
        FreeBusyEvaluationStatus.success,
        FreeBusyEvaluationStatus.success,
        FreeBusyEvaluationStatus.failed,
        FreeBusyEvaluationStatus.missing,
      ]);
      expect(results[0].busySlots.single.start, DateTime.utc(2026, 3, 8, 9));
      expect(results[1].busySlots, isEmpty);
      expect(results[2].errors, contains('5003'));
    },
  );

  test('getSchedule rejects invalid intervals without a request', () async {
    final client = _client((_) => throw StateError('No request expected'));
    final results = await client.freeBusyDetails(
      calendarIds: const ['guest@example.test'],
      rangeStart: DateTime.utc(2026, 1, 2),
      rangeEnd: DateTime.utc(2026, 1, 1),
    );
    expect(results.single.status, FreeBusyEvaluationStatus.failed);
  });

  test(
    'personal Microsoft token never calls unsupported getSchedule',
    () async {
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient(
          (_) async => throw StateError('No request expected'),
        ),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
        authorizationHeaderProvider: () async => 'Bearer opaque',
        accountTenantId: '9188040d-6c67-4c5b-b112-36a304b66dad',
      );
      final results = await client.freeBusyDetails(
        calendarIds: const ['guest@example.test'],
        rangeStart: DateTime.utc(2026, 1, 1),
        rangeEnd: DateTime.utc(2026, 1, 2),
      );
      expect(results.single.status, FreeBusyEvaluationStatus.failed);
      expect(results.single.errors.single, contains('personal'));
    },
  );

  test(
    'unknown account metadata is not assumed to support getSchedule',
    () async {
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient(
          (_) async => throw StateError('No request expected'),
        ),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
        authorizationHeaderProvider: () async => 'Bearer opaque',
      );
      final results = await client.freeBusyDetails(
        calendarIds: const ['guest@example.test'],
        rangeStart: DateTime.utc(2026, 1, 1),
        rangeEnd: DateTime.utc(2026, 1, 2),
      );
      expect(results.single.status, FreeBusyEvaluationStatus.failed);
      expect(results.single.errors.single, contains('type is unknown'));
    },
  );

  test(
    'getSchedule batches at 20 recipients and retains failed batch',
    () async {
      var calls = 0;
      final client = _client((request) {
        calls++;
        if (calls == 2) {
          return http.Response('{"error":{"code":"ErrorAccessDenied"}}', 403);
        }
        final recipients =
            (jsonDecode(request.body) as Map)['schedules'] as List;
        expect(recipients, hasLength(20));
        return _json({
          'value': [
            for (final recipient in recipients)
              {'scheduleId': recipient, 'scheduleItems': []},
          ],
        });
      });
      final results = await client.freeBusyDetails(
        calendarIds: [
          for (var index = 0; index < 25; index++) 'guest$index@example.test',
        ],
        rangeStart: DateTime.utc(2026, 1, 1),
        rangeEnd: DateTime.utc(2026, 1, 2),
      );
      expect(calls, 2);
      expect(results.take(20).every((value) => value.succeeded), isTrue);
      expect(
        results
            .skip(20)
            .every((value) => value.status == FreeBusyEvaluationStatus.failed),
        isTrue,
      );
    },
  );

  test('calendar update sends the documented Microsoft color enum', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json({
        'id': 'cal-1',
        'name': 'Work',
        'color': 'lightBlue',
        'hexColor': '#0078D4',
        'canEdit': true,
      });
    });

    final source = await client.updateCalendar(
      'cal-1',
      const CalendarMutation(colorId: 'lightBlue'),
    );

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/v1.0/me/calendars/cal-1');
    expect(jsonDecode(captured.body), {'color': 'lightBlue'});
    expect(source.colorId, 'lightBlue');
    expect(source.backgroundColor, '#0078D4');
  });

  test(
    'event create, update, and delete use Microsoft Graph endpoints',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return _json(_eventJson(id: 'event-1', subject: 'Planning'));
      });

      await client.createEvent(
        calendarId: 'cal-1',
        mutation: const CalendarEventMutation(
          title: 'Planning',
          allDay: false,
          startDateTime: '2026-06-10T09:00:00',
          endDateTime: '2026-06-10T10:00:00',
          reminders: {'isReminderOn': true, 'reminderMinutesBeforeStart': 15},
        ),
      );
      await client.updateEvent(
        calendarId: 'cal-1',
        eventId: 'event-1',
        mutation: const CalendarEventMutation(title: 'Renamed'),
      );
      await client.deleteEvent(calendarId: 'cal-1', eventId: 'event-1');

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/v1.0/me/calendars/cal-1/events');
      expect(jsonDecode(requests[0].body), {
        'subject': 'Planning',
        'isAllDay': false,
        'start': {'dateTime': '2026-06-10T09:00:00', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-06-10T10:00:00', 'timeZone': 'UTC'},
        'isReminderOn': true,
        'reminderMinutesBeforeStart': 15,
      });
      expect(requests[1].method, 'PATCH');
      expect(requests[1].url.path, '/v1.0/me/calendars/cal-1/events/event-1');
      expect(jsonDecode(requests[1].body), {'subject': 'Renamed'});
      expect(requests[2].method, 'DELETE');
      expect(requests[2].url.path, '/v1.0/me/calendars/cal-1/events/event-1');
    },
  );

  test('Microsoft RSVP uses the dedicated Graph actions', () async {
    final requests = <http.Request>[];
    final client = _client((request) {
      requests.add(request);
      return http.Response('', 202);
    });

    await client.respondToEvent(
      calendarId: 'cal-1',
      eventId: 'event-1',
      response: CalendarInvitationResponse.accept,
    );
    await client.respondToEvent(
      calendarId: 'cal-1',
      eventId: 'event-1',
      response: CalendarInvitationResponse.tentative,
      sendResponse: false,
    );
    await client.respondToEvent(
      calendarId: 'cal-1',
      eventId: 'event-1',
      response: CalendarInvitationResponse.decline,
    );

    expect(requests.map((request) => request.url.path), [
      '/v1.0/me/calendars/cal-1/events/event-1/accept',
      '/v1.0/me/calendars/cal-1/events/event-1/tentativelyAccept',
      '/v1.0/me/calendars/cal-1/events/event-1/decline',
    ]);
    expect(jsonDecode(requests[0].body), {'sendResponse': true});
    expect(jsonDecode(requests[1].body), {'sendResponse': false});
  });

  test('event update does not send raw onlineMeeting as provider', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json(_eventJson(id: 'event-1', subject: 'Edited'));
    });

    await client.updateEvent(
      calendarId: 'cal-1',
      eventId: 'event-1',
      mutation: const CalendarEventMutation(
        title: 'Edited',
        conference: {'joinUrl': 'https://teams.example/join'},
      ),
    );

    final body = jsonDecode(captured.body) as Map<String, Object?>;
    expect(body, {'subject': 'Edited'});
    expect(body, isNot(contains('onlineMeetingProvider')));
  });

  test(
    'primary initial sync uses delta view and preserves calendar identity',
    () async {
      late http.Request captured;
      const deltaLink =
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=terminal-token';
      final client = _client((request) {
        captured = request;
        return _json({
          'value': [_eventJson(id: 'event-1', subject: 'Planning')],
          '@odata.deltaLink': deltaLink,
        });
      });

      final page = await client.syncEvents(
        calendarId: 'actual-calendar-id',
        rangeStart: DateTime.utc(2026, 6, 10, 8),
        rangeEnd: DateTime.utc(2026, 6, 11, 8),
        primaryCalendar: true,
      );

      expect(captured.method, 'GET');
      expect(captured.url.path, '/v1.0/me/calendarView/delta');
      expect(captured.url.queryParameters, {
        'startDateTime': '2026-06-10T08:00:00.000Z',
        'endDateTime': '2026-06-11T08:00:00.000Z',
      });
      expect(page.events.single.providerCalendarId, 'actual-calendar-id');
      expect(page.nextSyncTokenOrDeltaLink, deltaLink);
    },
  );

  test('non-primary initial sync uses ordinary per-calendar view', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json({'value': <Object?>[]});
    });

    final page = await client.syncEvents(
      calendarId: 'cal-2',
      rangeStart: DateTime.utc(2026, 6, 10, 8),
      rangeEnd: DateTime.utc(2026, 6, 11, 8),
      primaryCalendar: false,
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/v1.0/me/calendars/cal-2/calendarView');
    expect(captured.url.queryParameters, {
      'startDateTime': '2026-06-10T08:00:00.000Z',
      'endDateTime': '2026-06-11T08:00:00.000Z',
    });
    expect(page.nextSyncTokenOrDeltaLink, isNull);
  });

  test(
    'incremental sync follows the saved opaque delta link exactly',
    () async {
      const savedDeltaLink =
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=opaque%2Btoken%2Fvalue';
      const nextDeltaLink =
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=next-token';
      late http.Request captured;
      final client = _client((request) {
        captured = request;
        return _json({'value': <Object?>[], '@odata.deltaLink': nextDeltaLink});
      });

      final page = await client.syncEvents(
        calendarId: 'actual-calendar-id',
        rangeStart: DateTime.utc(2030),
        rangeEnd: DateTime.utc(2031),
        syncTokenOrDeltaLink: savedDeltaLink,
        primaryCalendar: true,
      );

      expect(captured.url.toString(), savedDeltaLink);
      expect(page.nextSyncTokenOrDeltaLink, nextDeltaLink);
    },
  );

  test('delta tombstones map to deleted events', () async {
    final client = _client(
      (_) => _json({
        'value': [
          {
            'id': 'event-1',
            '@removed': {'reason': 'deleted'},
          },
        ],
      }),
    );

    final page = await client.syncEvents(
      calendarId: 'actual-calendar-id',
      rangeStart: DateTime.utc(2026, 6, 10),
      rangeEnd: DateTime.utc(2026, 6, 11),
      syncTokenOrDeltaLink:
          'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
          r'$deltatoken=current',
      primaryCalendar: true,
    );

    expect(page.events.single.providerCalendarId, 'actual-calendar-id');
    expect(page.events.single.isDeleted, isTrue);
  });

  test('expired Microsoft delta state requests a full sync', () async {
    const scenarios = [
      (statusCode: 410, code: 'ErrorInvalidSyncState'),
      (statusCode: 400, code: 'syncStateNotFound'),
    ];

    for (final scenario in scenarios) {
      final client = _client(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': scenario.code,
              'message': 'The sync state is no longer valid.',
            },
          }),
          scenario.statusCode,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final page = await client.syncEvents(
        calendarId: 'actual-calendar-id',
        rangeStart: DateTime.utc(2026, 6, 10),
        rangeEnd: DateTime.utc(2026, 6, 11),
        syncTokenOrDeltaLink:
            'https://graph.microsoft.com/v1.0/me/calendarView/delta?'
            r'$deltatoken=expired',
        primaryCalendar: true,
      );

      expect(
        page.requiresFullSync,
        isTrue,
        reason: '${scenario.statusCode}/${scenario.code}',
      );
      expect(page.events, isEmpty);
    }
  });
}

MicrosoftCalendarApiClient _client(
  http.Response Function(http.Request request) handler,
) {
  return MicrosoftCalendarApiClient(
    httpClient: MockClient((request) async => handler(request)),
    baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
    responseTimeZone: 'UTC',
    authorizationHeaderProvider: () async => 'Bearer token',
    accountTenantId: '11111111-1111-1111-1111-111111111111',
  );
}

http.Response _json(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, Object?> _eventJson({required String id, required String subject}) {
  return {
    'id': id,
    'subject': subject,
    'isAllDay': false,
    'start': {'dateTime': '2026-06-10T09:00:00', 'timeZone': 'UTC'},
    'end': {'dateTime': '2026-06-10T10:00:00', 'timeZone': 'UTC'},
    'lastModifiedDateTime': '2026-06-10T00:00:00Z',
  };
}

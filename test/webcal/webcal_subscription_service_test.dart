import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/webcal/webcal_http_client.dart';
import 'package:busymax/src/webcal/webcal_subscription_service.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;
  late _FakeTransport transport;
  late WebCalSubscriptionService service;
  late int notificationRebuilds;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 8, 29, 20);
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    transport = _FakeTransport();
    notificationRebuilds = 0;
    service = WebCalSubscriptionService(
      database: database,
      secretStore: secrets,
      httpTransport: transport,
      nowUtc: () => now,
      idFactory: () => 'subscription-1',
      onNotificationScheduleChanged: () async => notificationRebuilds += 1,
    );
  });

  tearDown(() async => database.close());

  test(
    'add stores a redacted read-only snapshot with stable identities',
    () async {
      const credential =
          'https://calendar.example.test/feed?private-token=secret';
      transport.responses.add(
        _response(
          uri: Uri.parse(credential),
          etag: '"one"',
          body: utf8.encode(
            _calendar('''
SOURCE:$credential
BEGIN:VEVENT
UID:uid-one
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Published event
URL:$credential
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT15M
DESCRIPTION:Reminder
END:VALARM
END:VEVENT
'''),
          ),
        ),
      );

      final id = await service.addSubscription(
        subscriptionUrl: credential,
        localName: 'Team schedule',
        color: '#336699',
        refreshMode: WebCalRefreshMode.hourly,
      );

      expect(id, 'subscription-1');
      final account = await database.select(database.accounts).getSingle();
      expect(account.id, 'webcal-account-subscription-1');
      expect(account.provider, 'webcal');
      expect(account.credentialKind, 'webcal_subscription');
      expect(account.authority, 'https://calendar.example.test');
      expect(account.providerAccountId, isNot(contains('private-token')));
      expect(account.tasksEnabled, isFalse);
      expect(await secrets.readActiveAccountId(), isNull);

      final source = await database
          .select(database.calendarSources)
          .getSingle();
      expect(source.id, 'webcal-calendar-subscription-1');
      expect(source.providerCalendarId, 'subscription-1');
      expect(source.readOnly, isTrue);
      expect(source.accessRole, 'reader');
      expect(source.backgroundColor, '#336699');
      expect(source.rawJson, '{"transport":"webcal"}');

      final subscription = await database
          .select(database.webCalSubscriptions)
          .getSingle();
      expect(subscription.safeOrigin, 'https://calendar.example.test');
      expect(subscription.snapshotIcsBody, isNot(contains(credential)));
      expect(subscription.etag, '"one"');
      expect(subscription.refreshMode, 'hourly');
      expect(
        DateTime.parse(subscription.nextRefreshAtUtc).difference(now),
        greaterThanOrEqualTo(const Duration(hours: 1)),
      );

      final event = await database.select(database.calendarEvents).getSingle();
      final itemId = _stable('webcal-item', 'subscription-1\u0000uid-one');
      expect(event.providerEventId, itemId);
      expect(event.id, _stable('webcal-event', '$itemId\u0000master'));
      expect(event.syncStatus, 'synced');
      expect(event.webLink, isNull);
      expect(event.rawJson, isNot(contains(credential)));
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(notificationRebuilds, 1);

      final secret =
          await secrets.readCredential(account.id) as WebCalSecretRecord;
      expect(secret.normalizedSubscriptionUri, credential);
      expect(secret.toString(), isNot(contains(credential)));
    },
  );

  test('duplicate add is rejected before another fetch', () async {
    const uri = 'https://calendar.example.test/feed';
    transport.responses.add(_response(uri: Uri.parse(uri), body: _oneEvent));
    await service.addSubscription(subscriptionUrl: uri);

    await expectLater(
      service.addSubscription(
        subscriptionUrl: 'webcal://calendar.example.test/feed',
      ),
      throwsA(
        isA<WebCalSubscriptionException>().having(
          (error) => error.code,
          'code',
          'WebCalDuplicateSubscription',
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test(
    'snapshot removes original and validator-target URIs from parameters',
    () async {
      final origin = Uri.parse(
        'https://calendar.example.test/feed?private-token=one',
      );
      final target = Uri.parse(
        'https://cdn.example.test/current.ics?private-token=two',
      );
      transport.responses.add(
        _response(
          uri: target,
          body: utf8.encode(
            _calendar('''
BEGIN:VEVENT
UID:parameter-secret
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Safe title
DESCRIPTION;ALTREP="${origin.toString()}":Origin
LOCATION;ALTREP="${target.toString()}":Target
END:VEVENT
'''),
          ),
        ),
      );

      await service.addSubscription(subscriptionUrl: origin.toString());

      final snapshot =
          (await database.select(database.webCalSubscriptions).getSingle())
              .snapshotIcsBody;
      expect(snapshot, isNot(contains(origin.toString())));
      expect(snapshot, isNot(contains(target.toString())));
      expect(snapshot, isNot(contains('ALTREP')));
    },
  );

  test(
    'escaped TEXT values cannot expose original or target credentials',
    () async {
      const original = r'https://calendar.example.test/feed?token=a,b\c';
      final target = Uri.parse(
        'https://cdn.example.test/current.ics?token=a;b',
      );
      transport.responses.add(
        _response(
          uri: target,
          body: utf8.encode(
            _calendar(r'''
BEGIN:VEVENT
UID:text-secret
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:https://calendar.example.test/feed?token=a\,b\\c
DESCRIPTION:https://calendar.example.test/feed?token=a\,b\\c
LOCATION:https://cdn.example.test/current.ics?token=a\;b
END:VEVENT
'''),
          ),
        ),
      );

      await service.addSubscription(subscriptionUrl: original);

      final snapshot = await database
          .select(database.webCalSubscriptions)
          .getSingle();
      final event = await database.select(database.calendarEvents).getSingle();
      final projectedText = [
        event.title,
        event.description,
        event.location,
      ].join('\n');
      expect(snapshot.snapshotIcsBody, isNot(contains(original)));
      expect(snapshot.snapshotIcsBody, isNot(contains(target.toString())));
      expect(snapshot.snapshotIcsBody, isNot(contains('SUMMARY:')));
      expect(snapshot.snapshotIcsBody, isNot(contains('DESCRIPTION:')));
      expect(snapshot.snapshotIcsBody, isNot(contains('LOCATION:')));
      expect(projectedText, isNot(contains(original)));
      expect(projectedText, isNot(contains(target.toString())));
      expect(event.title, isEmpty);
      expect(event.description, isNull);
      expect(event.location, isNull);
    },
  );

  test(
    'malformed refresh preserves snapshot, events, validators, and alarms',
    () async {
      const uri = 'https://calendar.example.test/feed';
      transport.responses.add(
        _response(uri: Uri.parse(uri), etag: '"good"', body: _alarmedEvent),
      );
      await service.addSubscription(subscriptionUrl: uri);
      final beforeSubscription = await database
          .select(database.webCalSubscriptions)
          .getSingle();
      final beforeEvents = await database.select(database.calendarEvents).get();
      final beforeNotifications = await database
          .select(database.notificationSchedule)
          .get();

      transport.responses.add(
        _response(
          uri: Uri.parse(uri),
          etag: '"bad"',
          body: utf8.encode('<html>not a calendar</html>'),
          contentType: 'text/html',
        ),
      );
      await expectLater(
        service.refreshSubscription('subscription-1', force: true),
        throwsA(isA<WebCalSubscriptionException>()),
      );

      final afterSubscription = await database
          .select(database.webCalSubscriptions)
          .getSingle();
      expect(
        afterSubscription.snapshotIcsBody,
        beforeSubscription.snapshotIcsBody,
      );
      expect(afterSubscription.semanticHash, beforeSubscription.semanticHash);
      expect(afterSubscription.etag, '"good"');
      expect(
        afterSubscription.validatorTargetFingerprint,
        beforeSubscription.validatorTargetFingerprint,
      );
      expect(afterSubscription.lastFailureCode, 'WebCalContentTypeRejected');
      expect(afterSubscription.consecutiveFailureCount, 1);
      expect(
        (await database.select(database.calendarEvents).get()).map(
          (row) => row.id,
        ),
        beforeEvents.map((row) => row.id),
      );
      expect(
        (await database.select(database.notificationSchedule).get()).map(
          (row) => row.id,
        ),
        beforeNotifications.map((row) => row.id),
      );
      expect(notificationRebuilds, 1);
    },
  );

  test('conditional 304 is accepted only for the bound target', () async {
    final origin = Uri.parse('https://calendar.example.test/feed');
    final target = Uri.parse('https://cdn.example.test/current.ics');
    transport.responses.add(
      _response(uri: target, etag: '"one"', body: _oneEvent),
    );
    await service.addSubscription(subscriptionUrl: origin.toString());
    transport.responses.add(
      WebCalHttpResponse(
        statusCode: 304,
        finalUri: target,
        body: null,
        etag: '"one"',
        lastModified: null,
        contentType: null,
        conditionalRequestSent: true,
      ),
    );

    await service.refreshSubscription('subscription-1', force: true);

    expect(transport.requests.last.uri, origin);
    expect(transport.requests.last.validatorTarget, target);
    expect(transport.requests.last.validators.etag, '"one"');
    expect(
      (await database.select(database.webCalSubscriptions).getSingle())
          .consecutiveFailureCount,
      0,
    );

    transport.responses.add(
      WebCalHttpResponse(
        statusCode: 304,
        finalUri: target,
        body: null,
        etag: null,
        lastModified: null,
        contentType: null,
        conditionalRequestSent: false,
      ),
    );
    await expectLater(
      service.refreshSubscription('subscription-1', force: true),
      throwsA(
        isA<WebCalSubscriptionException>().having(
          (error) => error.code,
          'code',
          'WebCalInvalidNotModified',
        ),
      ),
    );
  });

  test('empty successful snapshot clears events atomically', () async {
    final uri = Uri.parse('https://calendar.example.test/feed');
    transport.responses.add(_response(uri: uri, body: _oneEvent));
    await service.addSubscription(subscriptionUrl: uri.toString());
    expect(await database.select(database.calendarEvents).get(), isNotEmpty);

    transport.responses.add(
      _response(
        uri: uri,
        body: utf8.encode(
          _calendar('''
BEGIN:VFREEBUSY
UID:freebusy
DTSTART:20260830T000000Z
DTEND:20260831T000000Z
END:VFREEBUSY
'''),
        ),
      ),
    );
    await service.refreshSubscription('subscription-1', force: true);

    expect(await database.select(database.calendarEvents).get(), isEmpty);
    expect(
      (await database.select(database.webCalSubscriptions).getSingle())
          .snapshotIcsBody,
      contains('VFREEBUSY'),
    );
  });

  test('single-event identity survives text and time changes', () async {
    final uri = Uri.parse('https://calendar.example.test/feed');
    transport.responses.add(_response(uri: uri, body: _oneEvent));
    await service.addSubscription(subscriptionUrl: uri.toString());
    final before = await database.select(database.calendarEvents).getSingle();

    transport.responses.add(
      _response(
        uri: uri,
        body: utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:uid-one
DTSTART:20260902T180000Z
DTEND:20260902T193000Z
SEQUENCE:8
SUMMARY:Changed title and time
END:VEVENT
'''),
        ),
      ),
    );
    await service.refreshSubscription('subscription-1', force: true);

    final after = await database.select(database.calendarEvents).getSingle();
    expect(after.id, before.id);
    expect(after.providerEventId, before.providerEventId);
    expect(after.title, 'Changed title and time');
    expect(after.startDateTime, '2026-09-02T18:00:00.000Z');
  });

  test(
    'due-aware refresh skips early work and force bypasses due time',
    () async {
      final uri = Uri.parse('https://calendar.example.test/feed');
      transport.responses.add(
        _response(
          uri: uri,
          body: utf8.encode(
            _calendar('''
REFRESH-INTERVAL;VALUE=DURATION:PT12H
BEGIN:VEVENT
UID:uid-one
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:One
END:VEVENT
'''),
          ),
        ),
      );
      await service.addSubscription(subscriptionUrl: uri.toString());
      final subscription = await database
          .select(database.webCalSubscriptions)
          .getSingle();
      expect(subscription.serverRefreshIntervalSeconds, 12 * 60 * 60);
      expect(
        DateTime.parse(subscription.nextRefreshAtUtc).difference(now),
        greaterThanOrEqualTo(const Duration(hours: 12)),
      );

      await service.refreshSubscription('subscription-1');
      expect(transport.requests, hasLength(1));

      transport.responses.add(_response(uri: uri, body: _oneEvent));
      await service.refreshSubscription('subscription-1', force: true);
      expect(transport.requests, hasLength(2));
    },
  );

  test('rename, color, and unsubscribe remain local and cascade', () async {
    final uri = Uri.parse('https://calendar.example.test/feed');
    transport.responses.add(_response(uri: uri, body: _oneEvent));
    await service.addSubscription(subscriptionUrl: uri.toString());

    await service.renameSubscription('subscription-1', 'Renamed');
    await service.changeSubscriptionColor('subscription-1', '#AABBCC');
    expect(
      (await database.select(database.accounts).getSingle()).displayName,
      'Renamed',
    );
    expect(
      (await database.select(database.calendarSources).getSingle()).summary,
      'Renamed',
    );
    expect(
      (await database.select(database.calendarEvents).getSingle()).colorHex,
      '#AABBCC',
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);

    await service.unsubscribe('subscription-1');
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(await database.select(database.calendarSources).get(), isEmpty);
    expect(await database.select(database.webCalSubscriptions).get(), isEmpty);
    expect(await database.select(database.calendarEvents).get(), isEmpty);
    expect(
      await secrets.readCredential('webcal-account-subscription-1'),
      isNull,
    );
  });

  test(
    'unsubscribe waits for an in-flight refresh and cannot restore secret',
    () async {
      final uri = Uri.parse('https://calendar.example.test/feed');
      transport.responses.add(_response(uri: uri, body: _oneEvent));
      await service.addSubscription(subscriptionUrl: uri.toString());

      final response = Completer<WebCalHttpResponse>();
      transport.responses.add(response.future);
      final refresh = service.refreshSubscription(
        'subscription-1',
        force: true,
      );
      while (transport.requests.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      final unsubscribe = service.unsubscribe('subscription-1');
      var unsubscribeFinished = false;
      unawaited(unsubscribe.whenComplete(() => unsubscribeFinished = true));
      await Future<void>.delayed(Duration.zero);
      expect(unsubscribeFinished, isFalse);

      response.complete(_response(uri: uri, etag: '"two"', body: _oneEvent));
      await refresh;
      await unsubscribe;

      expect(await database.select(database.accounts).get(), isEmpty);
      expect(
        await database.select(database.webCalSubscriptions).get(),
        isEmpty,
      );
      expect(
        await secrets.readCredential('webcal-account-subscription-1'),
        isNull,
      );
    },
  );

  test('covered schedule reads do not wait for an in-flight refresh', () async {
    final uri = Uri.parse('https://calendar.example.test/feed');
    transport.responses.add(_response(uri: uri, body: _oneEvent));
    await service.addSubscription(subscriptionUrl: uri.toString());

    final response = Completer<WebCalHttpResponse>();
    transport.responses.add(response.future);
    final refresh = service.refreshSubscription('subscription-1', force: true);
    while (transport.requests.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }

    final repository = ScheduleRepository(
      database,
      ensureProjectionCoverage: (range) => service.ensureProjectionCoverage(
        rangeStartUtc: range.start.toUtc(),
        rangeEndUtc: range.end.toUtc(),
      ),
    );
    final items = await repository
        .listItems(
          range: ScheduleRange.day(DateTime.utc(2026, 8, 30)),
          filters: const ScheduleFilters(includeTasks: false),
        )
        .timeout(const Duration(seconds: 1));

    expect(items.map((item) => item.title), ['One']);
    expect(response.isCompleted, isFalse);

    response.complete(_response(uri: uri, body: _oneEvent));
    await refresh;
  });

  test('304 reprojects an aging cached recurring snapshot', () async {
    final uri = Uri.parse('https://calendar.example.test/feed');
    transport.responses.add(
      _response(
        uri: uri,
        etag: '"one"',
        body: utf8.encode(
          _calendar('''
BEGIN:VEVENT
UID:long-series
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
RRULE:FREQ=YEARLY;COUNT=20
SUMMARY:Annual event
END:VEVENT
'''),
        ),
      ),
    );
    await service.addSubscription(subscriptionUrl: uri.toString());
    expect(
      (await database.select(database.calendarEvents).get()).any(
        (event) => event.startDateTime?.startsWith('2031-') == true,
      ),
      isFalse,
    );

    now = DateTime.utc(2029, 8, 29, 20);
    transport.responses.add(
      WebCalHttpResponse(
        statusCode: 304,
        finalUri: uri,
        body: null,
        etag: '"one"',
        lastModified: null,
        contentType: null,
        conditionalRequestSent: true,
      ),
    );
    await service.refreshSubscription('subscription-1', force: true);

    final events = await database.select(database.calendarEvents).get();
    expect(
      events.any((event) => event.startDateTime?.startsWith('2031-') == true),
      isTrue,
    );
    final subscription = await database
        .select(database.webCalSubscriptions)
        .getSingle();
    expect(subscription.projectionVersion, webCalProjectionVersion);
    expect(
      DateTime.parse(
        subscription.projectionRangeEndUtc!,
      ).isAfter(DateTime.utc(2031)),
      isTrue,
    );
    expect(transport.requests.last.uri, uri);
    expect(notificationRebuilds, 2);
  });

  test(
    'requested schedule range extends projection without a network fetch',
    () async {
      final uri = Uri.parse('https://calendar.example.test/feed');
      transport.responses.add(
        _response(
          uri: uri,
          body: utf8.encode(
            _calendar('''
BEGIN:VEVENT
UID:long-series
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
RRULE:FREQ=YEARLY;COUNT=20
SUMMARY:Annual event
END:VEVENT
'''),
          ),
        ),
      );
      await service.addSubscription(subscriptionUrl: uri.toString());

      await service.ensureProjectionCoverage(
        rangeStartUtc: DateTime.utc(2035, 8, 1),
        rangeEndUtc: DateTime.utc(2035, 9, 1),
      );

      expect(transport.requests, hasLength(1));
      expect(
        (await database.select(database.calendarEvents).get()).any(
          (event) => event.startDateTime?.startsWith('2035-') == true,
        ),
        isTrue,
      );
    },
  );
}

final class _FakeTransport implements WebCalHttpTransport {
  final responses = <Object>[];
  final requests =
      <({Uri uri, WebCalHttpValidators validators, Uri? validatorTarget})>[];

  @override
  Future<WebCalHttpResponse> get(
    Uri uri, {
    WebCalHttpValidators validators = const WebCalHttpValidators(),
    Uri? validatorTarget,
  }) async {
    requests.add((
      uri: uri,
      validators: validators,
      validatorTarget: validatorTarget,
    ));
    final next = responses.removeAt(0);
    if (next is WebCalHttpResponse) return next;
    if (next is Future<WebCalHttpResponse>) return next;
    throw next;
  }
}

WebCalHttpResponse _response({
  required Uri uri,
  required List<int> body,
  String? etag,
  String? contentType = 'text/calendar; charset=utf-8',
}) => WebCalHttpResponse(
  statusCode: 200,
  finalUri: uri,
  body: Uint8List.fromList(body),
  etag: etag,
  lastModified: null,
  contentType: contentType,
  conditionalRequestSent: false,
);

List<int> get _oneEvent => utf8.encode(
  _calendar('''
BEGIN:VEVENT
UID:uid-one
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:One
END:VEVENT
'''),
);

List<int> get _alarmedEvent => utf8.encode(
  _calendar('''
BEGIN:VEVENT
UID:uid-alarm
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Alarmed
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT15M
DESCRIPTION:Reminder
END:VALARM
END:VEVENT
'''),
);

String _calendar(String components) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax WebCal Test//EN\r
${components.trim().replaceAll('\n', '\r\n')}\r
END:VCALENDAR\r
''';

String _stable(String prefix, String input) =>
    '$prefix-${sha256.convert(utf8.encode(input))}';

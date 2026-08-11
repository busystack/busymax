import 'dart:math';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('new resource factory uses distinct opaque filename and RFC UID', () {
    final ids = ['uid-value', 'filename-value'];
    final factory = DavNewObjectFactory(
      idFactory: () => ids.removeAt(0),
      nowUtc: () => DateTime.utc(2026, 8, 8, 12),
    );

    final task = factory.task(summary: 'Title only');

    expect(task.uid, 'uid-value@busymax.local');
    expect(task.initialMemberName, 'filename-value.ics');
    expect(task.initialMemberName, isNot(contains('Title')));
    expect(task.rawIcs, contains('BEGIN:VTODO'));
    expect(task.rawIcs, contains('UID:uid-value@busymax.local'));
    expect(task.rawIcs, contains('DTSTAMP:20260808T120000Z'));
  });

  test(
    'create uses If-None-Match semantics and bounds filename collisions',
    () async {
      final putUris = <Uri>[];
      var puts = 0;
      late String stored;
      final remote = _FakeMutationRemote(
        put:
            ({
              required uri,
              required rawIcs,
              required ifMatch,
              required ifNoneMatch,
            }) async {
              putUris.add(uri);
              expect(ifNoneMatch, isTrue);
              expect(ifMatch, isNull);
              puts += 1;
              if (puts == 1) return _precondition;
              stored = rawIcs;
              return _success;
            },
        fetcher: (href, uri) async => _live(href, uri, '"created"', stored),
      );
      final service = DavConditionalMutationService(
        remoteClient: remote,
        memberIdFactory: () => 'collision-retry',
      );
      final object = DavNewObject(
        uid: 'new@example.test',
        initialMemberName: 'first.ics',
        rawIcs: _event('Baseline'),
        componentType: 'VEVENT',
      );

      final result = await service.create(
        collectionUri: _collectionUri,
        object: object,
        capabilities: _writable,
        correlationId: 'create',
      );

      expect(result.outcome, DavMutationOutcome.succeeded);
      expect(putUris.map((uri) => uri.path), [
        '${_collectionUri.path}first.ics',
        '${_collectionUri.path}collision-retry.ics',
      ]);
      expect(result.canonicalObject?.etag, '"created"');
    },
  );

  test(
    'lost create response is resolved by GET and never blindly repeated',
    () async {
      var puts = 0;
      final intended = _event('Created');
      final remote = _FakeMutationRemote(
        put:
            ({
              required uri,
              required rawIcs,
              required ifMatch,
              required ifNoneMatch,
            }) async {
              puts += 1;
              throw const DavException(
                kind: DavErrorKind.network,
                code: 'ConnectionDroppedAfterWrite',
                safeMessage: 'Connection dropped.',
              );
            },
        fetcher: (href, uri) async => _live(href, uri, '"server"', intended),
      );
      final service = DavConditionalMutationService(remoteClient: remote);

      final result = await service.create(
        collectionUri: _collectionUri,
        object: DavNewObject(
          uid: 'event@example.test',
          initialMemberName: 'new.ics',
          rawIcs: intended,
          componentType: 'VEVENT',
        ),
        capabilities: _writable,
        correlationId: 'unknown-create',
      );

      expect(result.outcome, DavMutationOutcome.succeeded);
      expect(puts, 1);
    },
  );

  test(
    '412 update auto-merges disjoint properties and retries exact current ETag',
    () async {
      final baseline = _event('Baseline', location: 'One');
      final remoteBody = _event('Baseline', location: 'Remote room');
      final calls = <({String? ifMatch, String raw})>[];
      var fetches = 0;
      late String merged;
      final remote = _FakeMutationRemote(
        put:
            ({
              required uri,
              required rawIcs,
              required ifMatch,
              required ifNoneMatch,
            }) async {
              calls.add((ifMatch: ifMatch, raw: rawIcs));
              if (calls.length == 1) return _precondition;
              merged = rawIcs;
              return _success;
            },
        fetcher: (href, uri) async {
          fetches += 1;
          return fetches == 1
              ? _live(href, uri, '"remote-etag"', remoteBody)
              : _live(href, uri, '"canonical"', merged);
        },
      );
      final patch = DavMutationPatch(
        target: _target,
        scope: DavMutationScope.object,
        operations: [DavPatchOperation.setText('SUMMARY', 'Local title')],
      );

      final result =
          await DavConditionalMutationService(
            remoteClient: remote,
            nowUtc: () => DateTime.utc(2026, 8, 8),
          ).update(
            hrefKey: _href,
            uri: _uri,
            baselineEtag: '"baseline-etag"',
            baselineRawIcs: baseline,
            patch: patch,
            capabilities: _writable,
            correlationId: 'merge',
          );

      expect(result.outcome, DavMutationOutcome.succeeded);
      expect(calls.map((call) => call.ifMatch), [
        '"baseline-etag"',
        '"remote-etag"',
      ]);
      expect(calls.last.raw, contains('SUMMARY:Local title'));
      expect(calls.last.raw, contains('LOCATION:Remote room'));
    },
  );

  test(
    'overlapping update creates conflict and does not overwrite remote',
    () async {
      final calls = <String?>[];
      final remote = _FakeMutationRemote(
        put:
            ({
              required uri,
              required rawIcs,
              required ifMatch,
              required ifNoneMatch,
            }) async {
              calls.add(ifMatch);
              return _precondition;
            },
        fetcher: (href, uri) async =>
            _live(href, uri, '"remote"', _event('Remote title')),
      );
      final result = await DavConditionalMutationService(remoteClient: remote)
          .update(
            hrefKey: _href,
            uri: _uri,
            baselineEtag: '"baseline"',
            baselineRawIcs: _event('Baseline'),
            patch: DavMutationPatch(
              target: _target,
              scope: DavMutationScope.object,
              operations: [DavPatchOperation.setText('SUMMARY', 'Local title')],
            ),
            capabilities: _writable,
            correlationId: 'conflict',
          );

      expect(result.outcome, DavMutationOutcome.conflict);
      expect(result.conflict?.conflictCode, 'DavConflictOverlappingProperties');
      expect(calls, ['"baseline"']);
    },
  );

  test('lost update response adopts matching server content', () async {
    late String intended;
    var puts = 0;
    final remote = _FakeMutationRemote(
      put:
          ({
            required uri,
            required rawIcs,
            required ifMatch,
            required ifNoneMatch,
          }) async {
            puts += 1;
            intended = rawIcs;
            throw const DavException(
              kind: DavErrorKind.timeout,
              code: 'DavResponseTimeout',
              safeMessage: 'Timed out.',
            );
          },
      fetcher: (href, uri) async => _live(href, uri, '"updated"', intended),
    );

    final result = await DavConditionalMutationService(remoteClient: remote)
        .update(
          hrefKey: _href,
          uri: _uri,
          baselineEtag: '"baseline"',
          baselineRawIcs: _event('Baseline'),
          patch: DavMutationPatch(
            target: _target,
            scope: DavMutationScope.object,
            operations: [DavPatchOperation.setText('SUMMARY', 'Intended')],
          ),
          capabilities: _writable,
          correlationId: 'unknown-update',
        );

    expect(result.outcome, DavMutationOutcome.succeeded);
    expect(puts, 1);
  });

  test(
    'stale delete conflicts while unknown delete with 404 is completed',
    () async {
      final stale = _FakeMutationRemote(
        delete: ({required uri, required ifMatch}) async => _precondition,
        fetcher: (href, uri) async =>
            _live(href, uri, '"changed"', _event('Remote changed')),
      );
      final conflict = await DavConditionalMutationService(remoteClient: stale)
          .delete(
            hrefKey: _href,
            uri: _uri,
            baselineEtag: '"baseline"',
            baselineRawIcs: _event('Baseline'),
            isEvent: true,
            capabilities: _writable,
            correlationId: 'stale-delete',
          );
      expect(conflict.outcome, DavMutationOutcome.conflict);
      expect(conflict.conflict?.conflictCode, 'DavConflictStaleDelete');

      var deletes = 0;
      final unknown = _FakeMutationRemote(
        delete: ({required uri, required ifMatch}) async {
          deletes += 1;
          throw const DavException(
            kind: DavErrorKind.network,
            code: 'Dropped',
            safeMessage: 'Dropped.',
          );
        },
        fetcher: (href, uri) async =>
            DavFetchedMember.missing(hrefKey: href, requestUri: uri),
      );
      final deleted = await DavConditionalMutationService(remoteClient: unknown)
          .delete(
            hrefKey: _href,
            uri: _uri,
            baselineEtag: '"baseline"',
            baselineRawIcs: _event('Baseline'),
            isEvent: true,
            capabilities: _writable,
            correlationId: 'unknown-delete',
          );
      expect(deleted.outcome, DavMutationOutcome.succeeded);
      expect(deletes, 1);
    },
  );

  test('MOVE preserves the resource and adopts the destination object', () async {
    final targetUri = Uri.parse(
      'https://cloud.example.test/remote.php/dav/calendars/alex/home/event.ics',
    );
    final destinationHref = targetUri.path;
    var moves = 0;
    final remote = _FakeMutationRemote(
      move:
          ({
            required sourceUri,
            required destinationUri,
            required ifMatch,
          }) async {
            moves += 1;
            expect(sourceUri, _uri);
            expect(destinationUri, targetUri);
            expect(ifMatch, 'W/"baseline"');
            return _success;
          },
      fetcher: (href, uri) async {
        expect(href, destinationHref);
        return _live(href, uri, '"moved"', _event('Baseline'));
      },
    );

    final result = await DavConditionalMutationService(remoteClient: remote)
        .move(
          sourceHrefKey: _href,
          sourceUri: _uri,
          destinationHrefKey: destinationHref,
          destinationUri: targetUri,
          baselineEtag: 'W/"baseline"',
          baselineRawIcs: _event('Baseline'),
          isEvent: true,
          sourceCapabilities: _writable,
          destinationCapabilities: _writable,
          correlationId: 'move',
        );

    expect(moves, 1);
    expect(result.outcome, DavMutationOutcome.succeeded);
    expect(result.canonicalObject?.hrefKey, destinationHref);
  });

  test(
    'lost MOVE response reconciles destination without repeating MOVE',
    () async {
      final destinationUri = Uri.parse(
        'https://cloud.example.test/remote.php/dav/calendars/alex/home/event.ics',
      );
      final destinationHref = destinationUri.path;
      var moves = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              throw const DavException(
                kind: DavErrorKind.network,
                code: 'ConnectionDroppedAfterMove',
                safeMessage: 'Connection dropped.',
              );
            },
        fetcher: (href, uri) async => href == destinationHref
            ? _live(href, uri, '"moved"', _event('Baseline'))
            : DavFetchedMember.missing(hrefKey: href, requestUri: uri),
      );

      final result = await DavConditionalMutationService(remoteClient: remote)
          .move(
            sourceHrefKey: _href,
            sourceUri: _uri,
            destinationHrefKey: destinationHref,
            destinationUri: destinationUri,
            baselineEtag: 'W/"baseline"',
            baselineRawIcs: _event('Baseline'),
            isEvent: true,
            sourceCapabilities: _writable,
            destinationCapabilities: _writable,
            correlationId: 'unknown-move',
          );

      expect(moves, 1);
      expect(result.outcome, DavMutationOutcome.succeeded);
    },
  );

  test('read-only capability blocks mutation before any request', () async {
    var requested = false;
    final remote = _FakeMutationRemote(
      put:
          ({
            required uri,
            required rawIcs,
            required ifMatch,
            required ifNoneMatch,
          }) async {
            requested = true;
            return _success;
          },
    );
    await expectLater(
      DavConditionalMutationService(remoteClient: remote).update(
        hrefKey: _href,
        uri: _uri,
        baselineEtag: '"etag"',
        baselineRawIcs: _event('Baseline'),
        patch: DavMutationPatch(
          target: _target,
          scope: DavMutationScope.object,
          operations: [DavPatchOperation.setText('SUMMARY', 'No')],
        ),
        capabilities: const CollectionCapabilities(supportsEvents: true),
        correlationId: 'read-only',
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavReadOnly',
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test(
    'HTTP mutation client maps UID conflicts and invalid calendar data',
    () async {
      final requests = <http.Request>[];
      final profile = davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: Uri.parse('https://cloud.example.test'),
      );
      final transport = DavHttpTransport(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('conflict.ics')) {
            return http.Response(
              '<d:error xmlns:d="DAV:" '
              'xmlns:c="urn:ietf:params:xml:ns:caldav">'
              '<c:no-uid-conflict/></d:error>',
              409,
            );
          }
          if (request.url.path.endsWith('invalid.ics')) {
            return http.Response(
              '<d:error xmlns:d="DAV:" '
              'xmlns:s="http://sabredav.org/ns">'
              '<s:exception>UnsupportedMediaType</s:exception>'
              '</d:error>',
              415,
            );
          }
          return http.Response('', request.method == 'PUT' ? 201 : 204);
        }),
        profile: profile,
        accountAuthority: Uri.parse('https://cloud.example.test'),
        delay: (_) async {},
        random: Random(1),
      );
      final client = DavMutationHttpClient(
        transport: transport,
        accountId: 'account',
        collectionId: 'collection',
        credential: DavBasicCredential(username: 'alex', password: 'secret'),
      );

      await client.conditionalPut(
        uri: _uri,
        rawIcs: _event('Create'),
        correlationId: 'put',
        ifNoneMatch: true,
      );
      await client.conditionalDelete(
        uri: _uri,
        ifMatch: 'W/"opaque"',
        correlationId: 'delete',
      );
      final moveDestination = _collectionUri.resolve('moved.ics');
      await client.conditionalMove(
        sourceUri: _uri,
        destinationUri: moveDestination,
        ifMatch: 'W/"move"',
        correlationId: 'move',
      );
      expect(requests[0].headers['if-none-match'], '*');
      expect(requests[0].headers, isNot(contains('if-match')));
      expect(requests[1].headers['if-match'], 'W/"opaque"');
      expect(requests[2].method, 'MOVE');
      expect(requests[2].headers['destination'], moveDestination.toString());
      expect(requests[2].headers['depth'], 'infinity');
      expect(requests[2].headers['overwrite'], 'F');
      expect(requests[2].headers['if-match'], 'W/"move"');

      await expectLater(
        client.conditionalPut(
          uri: _collectionUri.resolve('conflict.ics'),
          rawIcs: _event('Conflict'),
          correlationId: 'uid',
          ifNoneMatch: true,
        ),
        throwsA(
          isA<DavException>()
              .having((error) => error.kind, 'kind', DavErrorKind.uidConflict)
              .having((error) => error.code, 'code', 'DavUidConflict'),
        ),
      );
      await expectLater(
        client.conditionalPut(
          uri: _collectionUri.resolve('invalid.ics'),
          rawIcs: _event('Invalid'),
          correlationId: 'invalid',
          ifNoneMatch: true,
        ),
        throwsA(
          isA<DavException>()
              .having(
                (error) => error.kind,
                'kind',
                DavErrorKind.invalidCalendarData,
              )
              .having((error) => error.code, 'code', 'DavMalformedResource')
              .having((error) => error.statusCode, 'statusCode', 415),
        ),
      );
    },
  );
}

typedef _PutCallback =
    Future<DavConditionalResponse> Function({
      required Uri uri,
      required String rawIcs,
      required String? ifMatch,
      required bool ifNoneMatch,
    });
typedef _DeleteCallback =
    Future<DavConditionalResponse> Function({
      required Uri uri,
      required String ifMatch,
    });
typedef _MoveCallback =
    Future<DavConditionalResponse> Function({
      required Uri sourceUri,
      required Uri destinationUri,
      required String ifMatch,
    });
typedef _FetchCallback =
    Future<DavFetchedMember> Function(String href, Uri uri);

final class _FakeMutationRemote implements DavMutationRemoteClient {
  _FakeMutationRemote({this.put, this.delete, this.move, this.fetcher});

  final _PutCallback? put;
  final _DeleteCallback? delete;
  final _MoveCallback? move;
  final _FetchCallback? fetcher;

  @override
  Future<DavConditionalResponse> conditionalDelete({
    required Uri uri,
    required String ifMatch,
    required String correlationId,
  }) => delete!(uri: uri, ifMatch: ifMatch);

  @override
  Future<DavConditionalResponse> conditionalPut({
    required Uri uri,
    required String rawIcs,
    required String correlationId,
    String? ifMatch,
    bool ifNoneMatch = false,
  }) => put!(
    uri: uri,
    rawIcs: rawIcs,
    ifMatch: ifMatch,
    ifNoneMatch: ifNoneMatch,
  );

  @override
  Future<DavConditionalResponse> conditionalMove({
    required Uri sourceUri,
    required Uri destinationUri,
    required String ifMatch,
    required String correlationId,
  }) => move!(
    sourceUri: sourceUri,
    destinationUri: destinationUri,
    ifMatch: ifMatch,
  );

  @override
  Future<DavFetchedMember> fetch({
    required String hrefKey,
    required Uri uri,
    required String correlationId,
  }) => fetcher!(hrefKey, uri);
}

const _success = DavConditionalResponse(
  status: DavConditionalStatus.success,
  statusCode: 204,
  etag: null,
);
const _precondition = DavConditionalResponse(
  status: DavConditionalStatus.preconditionFailed,
  statusCode: 412,
  etag: null,
);

const _writable = CollectionCapabilities(
  canWriteContent: true,
  canAddMembers: true,
  canDeleteMembers: true,
  supportsEvents: true,
  supportsTasks: true,
);
const _target = IcalComponentKey(
  componentType: 'VEVENT',
  uid: 'event@example.test',
);
final _collectionUri = Uri.parse(
  'https://cloud.example.test/remote.php/dav/calendars/alex/work/',
);
const _href = '/remote.php/dav/calendars/alex/work/event.ics';
final _uri = Uri.parse('https://cloud.example.test$_href');

DavFetchedMember _live(String href, Uri uri, String etag, String body) =>
    DavFetchedMember.live(
      hrefKey: href,
      requestUri: uri,
      etag: etag,
      contentType: 'text/calendar',
      rawIcsBody: body,
    );

String _event(String summary, {String location = 'One'}) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:event@example.test\r
DTSTART:20260808T090000Z\r
DTEND:20260808T100000Z\r
SUMMARY:$summary\r
LOCATION:$location\r
X-UNKNOWN:keep\r
END:VEVENT\r
END:VCALENDAR\r
''';

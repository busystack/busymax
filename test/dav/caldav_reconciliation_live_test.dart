import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/caldav_fixture.dart';
import 'support/caldav_qa_targets.dart';

void main() {
  final enabled = Platform.environment['BUSYMAX_CALDAV_LIVE'] == '1';
  for (final target in calDavQaTargets.entries) {
    test(
      '${target.key}: injected well-known 303 resolves real service and inventory',
      () async {
        final endpoint = Uri.parse(target.value);
        var injected = 0;
        final f = CalDavFixture(
          endpoint.replace(path: '/'),
          wrapDiscoveryClient: (client) => _Gateway(client, (request) async {
            if (request.url.path != '/.well-known/caldav') return null;
            expect(request.method, 'HEAD');
            injected++;
            return http.StreamedResponse(
              const Stream.empty(),
              303,
              headers: {'location': endpoint.toString()},
              request: request,
            );
          }),
        );
        await f.open();
        addTearDown(f.close);
        expect(injected, greaterThan(0));
        final service = await f.database
            .select(f.database.davAccountServices)
            .getSingle();
        expect(service.principalHref, isNotEmpty);
        expect(service.calendarHomeHref, isNotEmpty);
        expect(
          (await f.independentRequest(
            'PROPFIND',
            f.createdCollectionUri!,
            body: '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
            headers: {'depth': '0', 'content-type': 'application/xml'},
          )).statusCode,
          207,
        );
      },
      skip: !enabled,
    );

    for (final outcome in ['live', 'deleted', 'denied', 'network']) {
      test(
        '${target.key}: injected property404 reconciles $outcome with independent readback',
        () async {
          final f = CalDavFixture(Uri.parse(target.value));
          await f.open();
          addTearDown(f.close);
          final uri = f.createdCollectionUri!.resolve('ambiguous.ics');
          final uid =
              'ambiguous-${DateTime.now().microsecondsSinceEpoch}@example.invalid';
          String body(String title) =>
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VTODO\r\nUID:$uid\r\nDTSTAMP:20261107T000000Z\r\nSUMMARY:$title\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
          expect(
            (await f.independentRequest(
              'PUT',
              uri,
              body: body('Before'),
              headers: {'content-type': 'text/calendar', 'if-none-match': '*'},
            )).statusCode,
            201,
          );
          await f.synchronize(full: true);
          final repository = DavObjectRepository(database: f.database);
          final before = (await repository.liveObjects(f.collectionId!))
              .singleWhere((o) => o.requestUri == uri.toString());
          final cursor = (await repository.cursor(f.collectionId!))!;
          expect(
            (await f.independentRequest(
              'PUT',
              uri,
              body: body('After'),
              headers: {
                'content-type': 'text/calendar',
                'if-match': before.etag!,
              },
            )).statusCode,
            anyOf(200, 204),
          );
          var reports = 0, gets = 0;
          final gateway = _Gateway(f.newClient(), (request) async {
            if (request.method == 'REPORT' &&
                request is http.Request &&
                request.body.contains('calendar-multiget')) {
              reports++;
              if (outcome == 'deleted') {
                expect(
                  (await f.independentRequest('DELETE', uri)).statusCode,
                  anyOf(200, 204),
                );
              }
              final xml =
                  '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>${uri.path}</d:href><d:propstat><d:prop><d:getetag/><c:calendar-data/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response></d:multistatus>';
              return http.StreamedResponse(
                Stream.value(utf8.encode(xml)),
                207,
                request: request,
              );
            }
            if (request.method == 'GET' && request.url == uri) {
              gets++;
              if (outcome == 'network') {
                throw http.ClientException('injected gateway interruption');
              }
              if (outcome == 'denied') {
                return http.StreamedResponse(
                  const Stream.empty(),
                  403,
                  request: request,
                );
              }
            }
            return null;
          });
          addTearDown(gateway.close);
          final authority = Uri.parse(target.value);
          final profile = davProviderProfile(
            BusyProvider.caldav,
            caldavServer: authority,
          );
          final remote = DavCollectionHttpClient(
            transport: DavHttpTransport(
              client: gateway,
              profile: profile,
              accountAuthority: authority,
              limits: const DavTransportLimits(maximumReadAttempts: 1),
            ),
            profile: profile,
            accountAuthority: authority,
            accountId: f.id,
            collectionId: f.collectionId!,
            collectionUri: f.createdCollectionUri!,
            credential: DavBasicCredential(
              username: f.username,
              password: f.password,
            ),
          );
          final run = DavSyncEngine(
            database: f.database,
            objectRepository: repository,
            remoteClient: remote,
            accountId: f.id,
            collectionId: f.collectionId!,
            provider: BusyProvider.caldav,
          ).synchronize(correlationId: 'injected-multiget');
          final unresolved = outcome == 'denied' || outcome == 'network';
          if (unresolved) {
            await expectLater(run, throwsA(anything));
          } else {
            await run;
          }
          expect(reports, 1);
          expect(gets, 1);
          await f.reopen();
          final persisted = DavObjectRepository(database: f.database);
          final after = (await persisted.objectByHref(
            f.collectionId!,
            before.hrefKey,
          ))!;
          expect(after.serverDeleted, outcome == 'deleted');
          expect(
            after.rawIcsBody,
            contains(
              unresolved || outcome == 'deleted'
                  ? 'SUMMARY:Before'
                  : 'SUMMARY:After',
            ),
          );
          final stable = (await persisted.cursor(f.collectionId!))!;
          expect(
            stable.baselineGeneration,
            cursor.baselineGeneration + (unresolved ? 0 : 1),
          );
          if (unresolved) expect(stable.cursorValue, cursor.cursorValue);
          final readback = await f.independentRequest('GET', uri);
          expect(readback.statusCode, outcome == 'deleted' ? 404 : 200);
          if (outcome != 'deleted') {
            expect(readback.body, contains('SUMMARY:After'));
          }
          expect(
            (await f.database.select(f.database.tasks).get()).where(
              (t) => t.title == (unresolved ? 'Before' : 'After'),
            ),
            outcome == 'deleted' ? isEmpty : hasLength(1),
          );
        },
        skip: !enabled,
      );
    }
  }
}

typedef _Intercept = Future<http.StreamedResponse?> Function(http.BaseRequest);

final class _Gateway extends http.BaseClient {
  _Gateway(this.delegate, this.intercept);
  final http.Client delegate;
  final _Intercept intercept;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      await intercept(request) ?? await delegate.send(request);
  @override
  void close() => delegate.close();
}

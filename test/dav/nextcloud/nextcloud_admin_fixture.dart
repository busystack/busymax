import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_sharing_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';

class NextcloudAdminFixture {
  final database = AppDatabase(NativeDatabase.memory());
  final secrets = InMemorySecretStore();
  final requests = <http.Request>[];
  late final client = MockClient(respond);
  late final collections = NextcloudCollectionService(
    database: database,
    secrets: secrets,
    client: client,
    accountId: 'account',
    requireNetwork: () async {},
    refresh: () async {
      refreshes++;
      if (failRefresh) throw StateError('refresh unavailable');
    },
  );
  late final sharing = NextcloudSharingService(collections);
  late final trash = NextcloudTrashService(collections);
  int refreshes = 0;
  bool failRefresh = false,
      denyMetadata = false,
      denyParent = false,
      published = false;
  String? failedProperty;
  bool omitPropertyResults = false;
  bool applyPropertyChanges = true;
  bool denyTrashObject = false, denySharing = false, ignoreSharing = false;
  String? deletedCollectionType;
  bool unexpectedTrashHref = false;
  String displayName = 'Work';
  final shares = <String, bool>{};
  final restored = <String>{};
  static const origin = 'https://cloud.example.test';
  static const home = '/remote.php/dav/calendars/alex/';
  static const collection = '${home}work/';
  static const bin = '${home}trash-bin/';

  Future<void> seed() async {
    const now = '2026-09-05T12:00:00Z';
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'nextcloud',
            authority: origin,
            providerAccountId: 'alex',
            credentialKind: 'nextcloud_app_password',
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    await secrets.saveCredential(
      'account',
      NextcloudSecretRecord(
        canonicalServer: Uri.parse(origin),
        loginName: 'alex',
        appPassword: 'test-only-password',
      ),
    );
    await database
        .into(database.davAccountServices)
        .insert(
          DavAccountServicesCompanion.insert(
            accountId: 'account',
            canonicalServiceUri: '$origin/remote.php/dav/',
            canonicalOrigin: origin,
            principalHref: const Value(
              '/remote.php/dav/principals/users/alex/',
            ),
            calendarHomeHref: const Value('$origin$home'),
            capabilitiesJson: Value(
              jsonEncode({
                'serverFeatures': [
                  'oc-resource-sharing',
                  'nc-calendar-trashbin',
                  'nc-calendar-webcal-cache',
                ],
              }),
            ),
            discoveredAtUtc: now,
          ),
        );
    for (final (id, path, types, mask) in [
      (
        'collection',
        collection,
        ['{DAV:}collection', '{urn:ietf:params:xml:ns:caldav}calendar'],
        3,
      ),
      (
        'bin',
        bin,
        ['{DAV:}collection', '{http://nextcloud.com/ns}trash-bin'],
        0,
      ),
    ]) {
      await database
          .into(database.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: id,
              accountId: 'account',
              hrefKey: path,
              requestUri: '$origin$path',
              displayName: 'Work',
              resourceTypesJson: Value(jsonEncode(types)),
              supportedComponentMask: Value(mask),
              currentUserPrivilegesJson: const Value(
                '["{DAV:}read","{DAV:}write-properties"]',
              ),
              readOnly: const Value(true),
              eventProjectionEnabled: Value(mask != 0),
              taskProjectionEnabled: Value(mask != 0),
              safeDisplayMetadataJson: Value(
                jsonEncode({
                  'principalHref': '/remote.php/dav/principals/users/alex/',
                  'calendarHomeHref': '$origin$home',
                  'parentPrivileges': ['{DAV:}unbind'],
                }),
              ),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
    }
  }

  Future<void> close() async {
    client.close();
    await database.close();
  }

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    if (request.method == 'PROPFIND') {
      if (request.body.contains('principal-collection-set')) {
        return multi(
          request.url.path,
          '<d:principal-collection-set><d:href>/remote.php/dav/principals/users/</d:href><d:href>/remote.php/dav/principals/groups/</d:href></d:principal-collection-set>',
        );
      }
      if (request.url.path == home) {
        if (request.headers['depth'] == '1') {
          return http.Response(
            '<d:multistatus $nextcloudXmlNamespaces>'
            '<d:response><d:href>$home</d:href><d:propstat><d:prop>'
            '<d:resourcetype><d:collection/></d:resourcetype>'
            '<d:current-user-privilege-set><d:privilege><d:${denyParent ? 'read' : 'all'}/></d:privilege></d:current-user-privilege-set>'
            '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
            '${deletedCollectionType == null || restored.contains('${home}deleted/') ? '' : '<d:response><d:href>${home}deleted/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/><nc:deleted-calendar/></d:resourcetype><d:displayname>Deleted collection</d:displayname><c:supported-calendar-component-set><c:comp name="$deletedCollectionType"/></c:supported-calendar-component-set><nc:deleted-at>2026-09-05T14:00:00Z</nc:deleted-at></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'}'
            '</d:multistatus>',
            207,
          );
        }
        return multi(
          home,
          '<d:current-user-privilege-set><d:privilege><d:${denyParent ? 'read' : 'unbind'}/></d:privilege></d:current-user-privilege-set>',
        );
      }
      if (request.url.path == bin) {
        return multi(
          bin,
          '<d:resourcetype><d:collection/><nc:trash-bin/></d:resourcetype>'
          '<d:current-user-privilege-set><d:privilege><d:all/></d:privilege></d:current-user-privilege-set>'
          '<nc:trash-bin-retention-duration>2592000</nc:trash-bin-retention-duration>',
        );
      }
      return multi(
        request.url.path,
        '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype><d:displayname>$displayName</d:displayname><d:owner><d:href>/remote.php/dav/principals/users/alex/</d:href></d:owner><d:current-user-privilege-set><d:privilege><d:read/></d:privilege>${denyMetadata ? '' : '<d:privilege><d:write-properties/></d:privilege>'}</d:current-user-privilege-set><a:calendar-color>#3584e4</a:calendar-color><a:calendar-order>2</a:calendar-order><oc:calendar-enabled>1</oc:calendar-enabled><c:schedule-calendar-transp><c:opaque/></c:schedule-calendar-transp><cs:allowed-sharing-modes><cs:can-be-shared/><cs:can-be-published/></cs:allowed-sharing-modes><oc:invite>${shares.entries.map((s) => '<oc:user><d:href>${s.key}</d:href><oc:common-name>Bob</oc:common-name><oc:access><oc:${s.value ? 'read-write' : 'read'}/></oc:access><oc:invite-accepted/></oc:user>').join()}</oc:invite>${published ? '<cs:publish-url><d:href>https://cloud.example.test/published/server-selected</d:href></cs:publish-url>' : ''}',
      );
    }
    if (request.method == 'PROPPATCH') {
      final document = XmlDocument.parse(request.body);
      final properties = document.descendantElements
          .firstWhere((e) => e.name.local == 'prop')
          .childElements;
      if (failedProperty != null) {
        return multi(request.url.path, '<a:$failedProperty/>', status: 403);
      }
      if (applyPropertyChanges) {
        for (final p in properties) {
          if (p.name.local == 'displayname') displayName = p.innerText;
        }
      }
      if (omitPropertyResults) return multi(request.url.path, '');
      return multi(
        request.url.path,
        properties.map((e) => '<${e.name.qualified}/>').join(),
      );
    }
    if (request.method == 'REPORT' &&
        request.body.contains('principal-property-search')) {
      final group = request.url.path.contains('/groups/');
      final path =
          '/remote.php/dav/principals/${group ? 'groups/team' : 'users/bob'}/';
      return multi(
        path,
        '<d:displayname>${group ? 'Team' : 'Bob'}</d:displayname><d:principal-URL><d:href>$path</d:href></d:principal-URL><c:calendar-user-type>${group ? 'GROUP' : 'INDIVIDUAL'}</c:calendar-user-type>',
      );
    }
    if (request.method == 'REPORT' && request.body.contains('calendar-query')) {
      final task = request.body.contains('VTODO');
      final path = '${bin}objects/${task ? 42 : 41}.ics';
      if (restored.contains(path)) {
        return http.Response('<d:multistatus $nextcloudXmlNamespaces/>', 207);
      }
      final component = task ? 'VTODO' : 'VEVENT';
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:$component\r\nUID:trash-${task ? 'task' : 'event'}\r\nDTSTAMP:20260905T120000Z\r\nDTSTART:20260905T120000Z\r\n${task ? 'DUE' : 'DTEND'}:20260905T130000Z\r\nSUMMARY:Deleted ${task ? 'task' : 'event'}\r\nEND:$component\r\nEND:VCALENDAR\r\n';
      return multi(
        unexpectedTrashHref ? '${collection}active.ics' : path,
        '<d:current-user-privilege-set><d:privilege><d:${denyTrashObject ? 'read' : 'unbind'}/></d:privilege></d:current-user-privilege-set><d:getetag>"exact-trash-etag"</d:getetag><c:calendar-data>${raw.replaceAll('&', '&amp;').replaceAll('<', '&lt;')}</c:calendar-data><nc:deleted-at>2026-09-05T14:00:00Z</nc:deleted-at><nc:calendar-uri>work</nc:calendar-uri>',
      );
    }
    if (request.method == 'POST') {
      final root = XmlDocument.parse(request.body).rootElement;
      if (root.name.local == 'share') {
        if (denySharing) {
          return multi(request.url.path, '<oc:share/>', status: 403);
        }
        if (ignoreSharing) return http.Response('', 200);
        final action = root.childElements.single;
        final href = action.childElements
            .firstWhere((e) => e.name.local == 'href')
            .innerText;
        if (action.name.local == 'remove') {
          shares.remove(href);
        } else {
          shares[href] = action.childElements.any(
            (e) => e.name.local == 'read-write',
          );
        }
      } else {
        published = root.name.local == 'publish-calendar';
      }
      return http.Response('', 200);
    }
    if (request.method == 'MOVE' || request.method == 'DELETE') {
      restored.add(request.url.path);
      return http.Response('', 204);
    }
    return http.Response('', 404);
  }

  http.Response multi(
    String path,
    String properties, {
    int status = 200,
  }) => http.Response(
    '<d:multistatus $nextcloudXmlNamespaces><d:response><d:href>$path</d:href><d:propstat><d:prop>$properties</d:prop><d:status>HTTP/1.1 $status ${status == 200 ? 'OK' : 'Forbidden'}</d:status></d:propstat></d:response></d:multistatus>',
    207,
  );
}

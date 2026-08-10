import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'discovers principal, home, mixed collections, ACLs, and safe HREFs',
    () async {
      final requests = <http.Request>[];
      var requestIndex = 0;
      final client = MockClient((request) async {
        requests.add(request);
        final response = switch (requestIndex) {
          0 => http.Response(
            '',
            200,
            headers: {
              'dav': '1, 3, calendar-access, sync-collection',
              'allow': 'OPTIONS, PROPFIND, REPORT, GET, PUT, DELETE',
            },
          ),
          1 => _multistatus(_currentPrincipalResponse),
          2 => _multistatus(_principalPropertiesResponse),
          3 => _multistatus(_inventoryResponse),
          _ => throw StateError('Unexpected discovery request.'),
        };
        requestIndex += 1;
        return response;
      });
      final authority = Uri.parse('https://cloud.example.test/nextcloud');
      final profile = davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: authority,
      );
      final service = DavDiscoveryService(
        transport: DavHttpTransport(
          client: client,
          profile: profile,
          accountAuthority: authority,
          delay: (_) async {},
        ),
        profile: profile,
        accountAuthority: authority,
        accountId: 'account',
        credential: DavBasicCredential(
          username: 'alex',
          password: 'app-secret',
        ),
        nowUtc: () => DateTime.utc(2026, 8, 8, 12),
      );

      late final DavDiscoveryResult result;
      try {
        result = await service.discover(correlationId: 'discover-1');
      } on Object catch (error) {
        fail(
          'Discovery failed after ${requests.length} requests: $error; '
          'targets=${requests.map((request) => request.url).join(',')}',
        );
      }

      expect(requests.map((request) => request.method), [
        'OPTIONS',
        'PROPFIND',
        'PROPFIND',
        'PROPFIND',
      ]);
      expect(requests[1].headers['depth'], '0');
      expect(requests[2].headers['depth'], '0');
      expect(requests[3].headers['depth'], '1');
      expect(
        requests,
        everyElement(
          isA<http.Request>().having(
            (request) => request.headers['authorization'],
            'authorization',
            startsWith('Basic '),
          ),
        ),
      );

      expect(
        result.service.principalHref.path,
        '/nextcloud/remote.php/dav/principals/users/alex/',
      );
      expect(
        result.service.calendarHomeHref.path,
        '/nextcloud/remote.php/dav/calendars/alex/',
      );
      expect(result.service.calendarUserAddresses.single.scheme, 'mailto');
      expect(result.service.capabilities.hasSchedulingInbox, isTrue);
      expect(result.collections, hasLength(3));

      final work = result.collections.singleWhere(
        (collection) => collection.displayName == 'Work & Team',
      );
      expect(
        work.hrefKey,
        '/nextcloud/remote.php/dav/calendars/alex/Team%2FWork/',
      );
      expect(work.kind, DavCollectionKind.mixedCalendar);
      expect(work.eventProjectionEnabled, isTrue);
      expect(work.taskProjectionEnabled, isTrue);
      expect(work.capabilities.canCreateEvent, isTrue);
      expect(work.capabilities.canCreateTask, isTrue);
      expect(work.capabilities.supportsSyncCollection, isTrue);
      expect(work.capabilities.supportsCalendarMultiget, isTrue);
      expect(work.maximumResourceSize, 1048576);
      expect(work.syncToken, 'https://cloud.example.test/token/opaque');
      expect(work.color, '#3584e4ff');
      expect(work.safeDisplayMetadata['owner-display-name'], 'Alex');

      final subscribed = result.collections.singleWhere(
        (collection) => collection.displayName == 'Subscribed',
      );
      expect(subscribed.kind, DavCollectionKind.subscribedCalendar);
      expect(subscribed.capabilities.isReadOnly, isTrue);
      // An absent component-set means all CalDAV component types, not VEVENT.
      expect(subscribed.eventProjectionEnabled, isTrue);
      expect(subscribed.taskProjectionEnabled, isTrue);

      final inbox = result.collections.singleWhere(
        (collection) => collection.kind == DavCollectionKind.schedulingInbox,
      );
      expect(inbox.eventProjectionEnabled, isFalse);
      expect(inbox.taskProjectionEnabled, isFalse);
    },
  );

  test(
    'successful inventory commits one collection and two projections',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const nowText = '2026-08-08T12:00:00.000Z';
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: 'nextcloud',
              authority: 'https://cloud.example.test/nextcloud',
              providerAccountId: 'alex',
              credentialKind: 'nextcloud_app_password',
              createdAtUtc: nowText,
              updatedAtUtc: nowText,
            ),
          );
      var nextId = 0;
      final repository = DavDiscoveryRepository(
        database: database,
        idFactory: () => 'collection-${nextId += 1}',
      );
      final result = _repositoryDiscoveryResult();

      await repository.commitSuccessfulInventory(result);

      final services = await database.select(database.davAccountServices).get();
      expect(services, hasLength(1));
      expect(services.single.capabilitiesJson, isNot(contains('app-secret')));
      final collections = await database.select(database.davCollections).get();
      expect(collections, hasLength(1));
      expect(collections.single.id, 'collection-1');
      expect(collections.single.readOnly, isFalse);
      final sources = await database.select(database.calendarSources).get();
      final lists = await database.select(database.taskLists).get();
      expect(sources, hasLength(1));
      expect(lists, hasLength(1));
      expect(sources.single.davCollectionId, collections.single.id);
      expect(lists.single.davCollectionId, collections.single.id);

      await repository.commitSuccessfulInventory(
        DavDiscoveryResult(
          accountId: result.accountId,
          provider: result.provider,
          service: result.service,
          collections: const [],
        ),
      );
      final missing = await database
          .select(database.davCollections)
          .getSingle();
      expect(missing.serverMissing, isTrue);
      expect(
        (await database.select(database.calendarSources).getSingle()).isDeleted,
        isTrue,
      );
      expect(
        (await database.select(database.taskLists).getSingle()).serverMissing,
        isTrue,
      );
    },
  );
}

http.Response _multistatus(String body) => http.Response(
  body,
  207,
  headers: {'content-type': 'application/xml; charset=utf-8'},
);

DavDiscoveryResult _repositoryDiscoveryResult() {
  final now = DateTime.utc(2026, 8, 8, 12);
  const capabilities = CollectionCapabilities(
    canRead: true,
    canWriteContent: true,
    canAddMembers: true,
    canDeleteMembers: true,
    supportsEvents: true,
    supportsTasks: true,
    supportsSyncCollection: true,
    supportsCalendarMultiget: true,
  );
  return DavDiscoveryResult(
    accountId: 'account',
    provider: BusyProvider.nextcloud,
    service: DavServiceDiscovery(
      canonicalServiceUri: Uri.parse(
        'https://cloud.example.test/nextcloud/remote.php/dav/',
      ),
      canonicalOrigin: Uri.parse('https://cloud.example.test'),
      principalHref: Uri.parse(
        'https://cloud.example.test/nextcloud/remote.php/dav/principals/users/alex/',
      ),
      calendarHomeHref: Uri.parse(
        'https://cloud.example.test/nextcloud/remote.php/dav/calendars/alex/',
      ),
      calendarUserAddresses: const [],
      scheduleInboxHref: null,
      scheduleOutboxHref: null,
      capabilities: AccountServiceCapabilities(
        hasPrincipal: true,
        hasCalendarHome: true,
      ),
      discoveredAtUtc: now,
      lastValidatedAtUtc: now,
      providerProfileVersion: 1,
    ),
    collections: [
      DavCollectionDiscovery(
        hrefKey: '/nextcloud/remote.php/dav/calendars/alex/work/',
        requestUri: Uri.parse(
          'https://cloud.example.test/nextcloud/remote.php/dav/calendars/alex/work/',
        ),
        displayName: 'Work',
        description: null,
        resourceTypes: const {'{DAV:}collection', '{urn:test}calendar'},
        supportedComponentMask: davComponentEvent | davComponentTodo,
        supportedCalendarData: const [
          {'contentType': 'text/calendar', 'version': '2.0'},
        ],
        supportedReports: const {'{DAV:}sync-collection'},
        currentUserPrivileges: const {'{DAV:}read', '{DAV:}write-content'},
        ownerHref: '/principals/alex/',
        safeDisplayMetadata: const {'owner-display-name': 'Alex'},
        color: '#3584e4ff',
        sortOrder: 1,
        calendarTimeZone: null,
        calendarTimeZoneId: 'America/Vancouver',
        scheduleTransparency: null,
        maximumResourceSize: 1048576,
        maximumInstances: null,
        syncToken: 'opaque',
        ctag: 'ctag',
        capabilities: capabilities,
        kind: DavCollectionKind.mixedCalendar,
        eventProjectionEnabled: true,
        taskProjectionEnabled: true,
      ),
    ],
  );
}

const _currentPrincipalResponse = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"><d:response>
 <d:href>/nextcloud/.well-known/caldav</d:href><d:propstat><d:prop>
  <d:current-user-principal><d:href>/nextcloud/remote.php/dav/principals/users/alex/</d:href></d:current-user-principal>
 </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response></d:multistatus>''';

const _principalPropertiesResponse = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
 <d:response><d:href>/nextcloud/remote.php/dav/principals/users/alex/</d:href>
  <d:propstat><d:prop>
   <c:calendar-home-set><d:href>/nextcloud/remote.php/dav/calendars/alex/</d:href></c:calendar-home-set>
   <c:calendar-user-address-set><d:href>mailto:alex@example.test</d:href></c:calendar-user-address-set>
   <c:schedule-inbox-URL><d:href>/nextcloud/remote.php/dav/calendars/alex/inbox/</d:href></c:schedule-inbox-URL>
   <c:schedule-outbox-URL><d:href>/nextcloud/remote.php/dav/calendars/alex/outbox/</d:href></c:schedule-outbox-URL>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
</d:multistatus>''';

const _inventoryResponse = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
 xmlns:cs="http://calendarserver.org/ns/" xmlns:a="http://apple.com/ns/ical/"
 xmlns:nc="http://nextcloud.com/ns">
 <d:response><d:href>/nextcloud/remote.php/dav/calendars/alex/</d:href>
  <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
  <d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
 <d:response><d:href>/nextcloud/remote.php/dav/calendars/alex/Team%2FWork/</d:href>
  <d:propstat><d:prop>
   <d:resourcetype><d:collection/><c:calendar/></d:resourcetype>
   <d:displayname>Work &amp; Team</d:displayname>
   <d:owner><d:href>/nextcloud/remote.php/dav/principals/users/alex/</d:href></d:owner>
   <d:current-user-privilege-set>
    <d:privilege><d:read/></d:privilege><d:privilege><d:write-content/></d:privilege>
    <d:privilege><d:bind/></d:privilege><d:privilege><d:unbind/></d:privilege>
   </d:current-user-privilege-set>
   <d:supported-report-set>
    <d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report>
    <d:supported-report><d:report><c:calendar-multiget/></d:report></d:supported-report>
    <d:supported-report><d:report><c:calendar-query/></d:report></d:supported-report>
   </d:supported-report-set>
   <d:sync-token>https://cloud.example.test/token/opaque</d:sync-token>
   <c:supported-calendar-component-set><c:comp name="VEVENT"/><c:comp name="VTODO"/></c:supported-calendar-component-set>
   <c:supported-calendar-data><c:calendar-data content-type="text/calendar" version="2.0"/></c:supported-calendar-data>
   <c:max-resource-size>1048576</c:max-resource-size><c:max-instances>1000</c:max-instances>
   <a:calendar-color>#3584e4ff</a:calendar-color><a:calendar-order>2</a:calendar-order>
   <nc:owner-display-name>Alex</nc:owner-display-name>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
 <d:response><d:href>/nextcloud/remote.php/dav/calendars/alex/subscribed/</d:href>
  <d:propstat><d:prop>
   <d:resourcetype><d:collection/><c:calendar/><cs:subscribed/></d:resourcetype>
   <d:displayname>Subscribed</d:displayname>
   <d:current-user-privilege-set><d:privilege><d:read/></d:privilege></d:current-user-privilege-set>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
 <d:response><d:href>/nextcloud/remote.php/dav/calendars/alex/inbox/</d:href>
  <d:propstat><d:prop><d:resourcetype><d:collection/><c:schedule-inbox/></d:resourcetype>
   <d:displayname>Inbox</d:displayname></d:prop>
   <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
 </d:response>
</d:multistatus>''';

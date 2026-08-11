import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _enabledVariable = 'BUSYMAX_NEXTCLOUD_SHARING_LIVE';

void main() {
  final enabled = Platform.environment[_enabledVariable] == '1';

  test(
    'Nextcloud user and group shares enforce live ACL changes',
    () async {
      final authority = Uri.parse(
        _requiredEnvironment('BUSYMAX_NEXTCLOUD_SHARING_LIVE_URL'),
      );
      final owner = _SharingUser.fromEnvironment(authority, 'OWNER');
      final writer = _SharingUser.fromEnvironment(authority, 'WRITER');
      final reader = _SharingUser.fromEnvironment(authority, 'READER');
      final groupMember = _SharingUser.fromEnvironment(
        authority,
        'GROUP_MEMBER',
      );
      final groupName = _requiredEnvironment(
        'BUSYMAX_NEXTCLOUD_SHARING_LIVE_GROUP',
      );
      addTearDown(owner.close);
      addTearDown(writer.close);
      addTearDown(reader.close);
      addTearDown(groupMember.close);

      final ownerDiscovery = await owner.discover('sharing-owner-discovery');
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final slug = 'busymax-qa-shared-$suffix';
      final displayName = 'BusyMax QA Shared $suffix';
      final collectionUri = _collectionChild(
        ownerDiscovery.service.calendarHomeHref,
        slug,
      );
      await owner.createEventCollection(
        collectionUri,
        displayName: displayName,
      );
      var collectionDeleted = false;
      addTearDown(() async {
        if (!collectionDeleted) await owner.deleteCollection(collectionUri);
      });

      await owner.updateShares(
        collectionUri,
        set: [
          _ShareGrant.user(writer.username, writable: true),
          _ShareGrant.user(reader.username, writable: false),
          _ShareGrant.group(groupName, writable: false),
        ],
      );

      var writerCollection = _sharedCollection(
        await writer.discover('sharing-writer-discovery'),
        displayName,
      );
      var readerCollection = _sharedCollection(
        await reader.discover('sharing-reader-discovery'),
        displayName,
      );
      final groupCollection = _sharedCollection(
        await groupMember.discover('sharing-group-discovery'),
        displayName,
      );
      expect(writerCollection.capabilities.canCreateEvent, isTrue);
      expect(writerCollection.capabilities.isReadOnly, isFalse);
      expect(readerCollection.capabilities.canCreateEvent, isFalse);
      expect(readerCollection.capabilities.isReadOnly, isTrue);
      expect(groupCollection.capabilities.canCreateEvent, isFalse);
      expect(groupCollection.capabilities.isReadOnly, isTrue);

      final eventUid = 'busymax-shared-$suffix@example.invalid';
      final writerMutations = writer.mutations('shared-writer');
      final created = await writerMutations.create(
        collectionUri: writerCollection.requestUri,
        object: DavNewObject(
          uid: eventUid,
          initialMemberName: 'busymax-shared-$suffix.ics',
          rawIcs: _event(eventUid),
          componentType: 'VEVENT',
        ),
        capabilities: writerCollection.capabilities,
        correlationId: 'sharing-writer-create',
      );
      expect(created.outcome, DavMutationOutcome.succeeded);

      await expectLater(
        reader
            .mutations('shared-reader')
            .create(
              collectionUri: readerCollection.requestUri,
              object: DavNewObject(
                uid: 'busymax-readonly-$suffix@example.invalid',
                initialMemberName: 'busymax-readonly-$suffix.ics',
                rawIcs: _event('busymax-readonly-$suffix@example.invalid'),
                componentType: 'VEVENT',
              ),
              capabilities: readerCollection.capabilities,
              correlationId: 'sharing-reader-rejected-create',
            ),
        throwsA(
          isA<DavException>()
              .having((error) => error.kind, 'kind', DavErrorKind.authorization)
              .having((error) => error.code, 'code', 'DavReadOnly'),
        ),
      );

      await owner.updateShares(
        collectionUri,
        set: [_ShareGrant.user(writer.username, writable: false)],
        remove: [_ShareGrant.user(reader.username, writable: false)],
      );
      writerCollection = _sharedCollection(
        await writer.discover('sharing-writer-downgraded'),
        displayName,
      );
      expect(writerCollection.capabilities.isReadOnly, isTrue);
      expect(writerCollection.capabilities.canCreateEvent, isFalse);
      expect(
        _hasSharedCollection(
          await reader.discover('sharing-reader-removed'),
          displayName,
        ),
        isFalse,
      );

      await owner.deleteCollection(collectionUri);
      collectionDeleted = true;
      expect(
        _hasSharedCollection(
          await writer.discover('sharing-collection-removed'),
          displayName,
        ),
        isFalse,
      );
      expect(
        _hasSharedCollection(
          await groupMember.discover('sharing-group-collection-removed'),
          displayName,
        ),
        isFalse,
      );
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 and disposable user/group environment '
              'variables to run the live Nextcloud sharing test.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

final class _SharingUser {
  _SharingUser({
    required this.authority,
    required this.username,
    required this.credential,
    required this.client,
    required this.profile,
    required this.transport,
  });

  factory _SharingUser.fromEnvironment(Uri authority, String role) {
    final username = _requiredEnvironment(
      'BUSYMAX_NEXTCLOUD_SHARING_LIVE_${role}_USERNAME',
    );
    final password = _requiredEnvironment(
      'BUSYMAX_NEXTCLOUD_SHARING_LIVE_${role}_PASSWORD',
    );
    final profile = DavProviderProfile(
      provider: BusyProvider.nextcloud,
      bootstrapUri: authority,
      calendarEnabled: true,
      tasksEnabled: true,
      allowCollectionMutations: false,
      allowSchedulingMutations: false,
      allowMove: false,
      allowInsecureLoopbackForTesting:
          authority.scheme == 'http' &&
          const {'127.0.0.1', 'localhost', '::1'}.contains(authority.host),
    );
    final client = http.Client();
    return _SharingUser(
      authority: authority,
      username: username,
      credential: DavBasicCredential(username: username, password: password),
      client: client,
      profile: profile,
      transport: DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: authority,
      ),
    );
  }

  final Uri authority;
  final String username;
  final DavBasicCredential credential;
  final http.Client client;
  final DavProviderProfile profile;
  final DavHttpTransport transport;

  Future<DavDiscoveryResult> discover(String correlationId) =>
      DavDiscoveryService(
        transport: transport,
        profile: profile,
        accountAuthority: authority,
        accountId: 'sharing-$username',
        credential: credential,
      ).discover(correlationId: correlationId);

  DavConditionalMutationService mutations(String collectionId) =>
      DavConditionalMutationService(
        remoteClient: DavMutationHttpClient(
          transport: transport,
          accountId: 'sharing-$username',
          collectionId: collectionId,
          credential: credential,
        ),
      );

  Future<void> createEventCollection(
    Uri collectionUri, {
    required String displayName,
  }) async {
    final response = await transport.send(
      DavRequest.xml(
        method: 'MKCALENDAR',
        uri: collectionUri,
        accountId: 'sharing-$username',
        correlationId: 'sharing-create-collection',
        retryClass: DavRetryClass.never,
        body:
            '''<?xml version="1.0" encoding="utf-8"?>
<c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:set><d:prop>
    <d:resourcetype><d:collection/><c:calendar/></d:resourcetype>
    <d:displayname>${_xmlText(displayName)}</d:displayname>
    <c:supported-calendar-component-set><c:comp name="VEVENT"/></c:supported-calendar-component-set>
  </d:prop></d:set>
</c:mkcalendar>''',
      ),
      credential: credential,
    );
    expect(response.statusCode, 201);
  }

  Future<void> updateShares(
    Uri collectionUri, {
    List<_ShareGrant> set = const [],
    List<_ShareGrant> remove = const [],
  }) async {
    final response = await transport.send(
      DavRequest.xml(
        method: 'POST',
        uri: collectionUri,
        accountId: 'sharing-$username',
        correlationId: 'sharing-update-acl',
        retryClass: DavRetryClass.never,
        body:
            '''<?xml version="1.0" encoding="utf-8"?>
<oc:share xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
  ${set.map((grant) => grant.setXml).join()}
  ${remove.map((grant) => grant.removeXml).join()}
</oc:share>''',
      ),
      credential: credential,
    );
    expect(response.statusCode, 200);
  }

  Future<void> deleteCollection(Uri collectionUri) async {
    final response = await transport.send(
      DavRequest(
        method: 'DELETE',
        uri: collectionUri,
        accountId: 'sharing-$username',
        correlationId: 'sharing-delete-collection',
      ),
      credential: credential,
    );
    expect(response.statusCode, anyOf(204, 404));
  }

  void close() => client.close();
}

final class _ShareGrant {
  const _ShareGrant._(this.href, this.writable);

  factory _ShareGrant.user(String username, {required bool writable}) =>
      _ShareGrant._('principal:principals/users/$username', writable);

  factory _ShareGrant.group(String group, {required bool writable}) =>
      _ShareGrant._('principal:principals/groups/$group', writable);

  final String href;
  final bool writable;

  String get setXml =>
      '<oc:set><d:href>${_xmlText(href)}</d:href>'
      '${writable ? '<oc:read-write/>' : ''}</oc:set>';

  String get removeXml =>
      '<oc:remove><d:href>${_xmlText(href)}</d:href></oc:remove>';
}

DavCollectionDiscovery _sharedCollection(
  DavDiscoveryResult discovery,
  String displayName,
) => discovery.collections.singleWhere(
  (collection) => collection.displayName.startsWith(displayName),
);

bool _hasSharedCollection(DavDiscoveryResult discovery, String displayName) =>
    discovery.collections.any(
      (collection) => collection.displayName.startsWith(displayName),
    );

Uri _collectionChild(Uri home, String slug) {
  final basePath = home.path.endsWith('/') ? home.path : '${home.path}/';
  return home.replace(path: '$basePath$slug/', query: null, fragment: null);
}

String _event(String uid) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax//Nextcloud Sharing Integration Test//EN\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260812T160000Z\r
DTEND:20260812T170000Z\r
SUMMARY:BusyMax shared event\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _xmlText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('$name is required when $_enabledVariable=1.');
  }
  return value;
}

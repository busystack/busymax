import 'dart:typed_data';

import '../dav_errors.dart';
import '../dav_href.dart';
import '../dav_provider_profile.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';

final class DavRemoteMember {
  const DavRemoteMember({
    required this.hrefKey,
    required this.requestUri,
    required this.etag,
  });

  final String hrefKey;
  final Uri requestUri;
  final String etag;
}

final class DavSyncPage {
  const DavSyncPage({
    required this.changedMembers,
    required this.deletedHrefKeys,
    required this.nextSyncToken,
    required this.truncated,
  });

  final List<DavRemoteMember> changedMembers;
  final Set<String> deletedHrefKeys;
  final String nextSyncToken;
  final bool truncated;
}

final class DavMemberInventory {
  const DavMemberInventory({required this.members});

  final List<DavRemoteMember> members;
}

final class DavFetchedMember {
  const DavFetchedMember._({
    required this.hrefKey,
    required this.requestUri,
    required this.missing,
    required this.etag,
    required this.contentType,
    required this.rawIcsBody,
  });

  const DavFetchedMember.live({
    required String hrefKey,
    required Uri requestUri,
    required String etag,
    required String? contentType,
    required String rawIcsBody,
  }) : this._(
         hrefKey: hrefKey,
         requestUri: requestUri,
         missing: false,
         etag: etag,
         contentType: contentType,
         rawIcsBody: rawIcsBody,
       );

  const DavFetchedMember.missing({
    required String hrefKey,
    required Uri requestUri,
  }) : this._(
         hrefKey: hrefKey,
         requestUri: requestUri,
         missing: true,
         etag: null,
         contentType: null,
         rawIcsBody: null,
       );

  final String hrefKey;
  final Uri requestUri;
  final bool missing;
  final String? etag;
  final String? contentType;
  final String? rawIcsBody;
}

abstract interface class DavCollectionRemoteClient {
  Future<DavSyncPage> syncCollectionPage({
    required String syncToken,
    required String correlationId,
    DavCancellationToken? cancellationToken,
  });

  Future<DavMemberInventory> listMemberEtags({
    required String correlationId,
    DavCancellationToken? cancellationToken,
  });

  Future<List<DavFetchedMember>> fetchMembers(
    List<DavRemoteMember> members, {
    required String correlationId,
    required bool useCalendarMultiget,
    DavCancellationToken? cancellationToken,
  });
}

final class DavCollectionHttpClient implements DavCollectionRemoteClient {
  DavCollectionHttpClient({
    required DavHttpTransport transport,
    required DavProviderProfile profile,
    required Uri accountAuthority,
    required String accountId,
    required String collectionId,
    required Uri collectionUri,
    required DavBasicCredential credential,
    DavXmlParser xmlParser = const DavXmlParser(),
  }) : _transport = transport,
       _profile = profile,
       _accountAuthority = accountAuthority,
       _accountId = accountId,
       _collectionId = collectionId,
       _collectionUri = collectionUri,
       _credential = credential,
       _xmlParser = xmlParser;

  final DavHttpTransport _transport;
  final DavProviderProfile _profile;
  final Uri _accountAuthority;
  final String _accountId;
  final String _collectionId;
  final Uri _collectionUri;
  final DavBasicCredential _credential;
  final DavXmlParser _xmlParser;

  @override
  Future<DavSyncPage> syncCollectionPage({
    required String syncToken,
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) async {
    final response = await _transport.send(
      DavRequest.xml(
        method: 'REPORT',
        uri: _collectionUri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: const {'depth': '1'},
        body: _syncCollectionBody(syncToken),
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    if (response.statusCode != 207 && response.statusCode != 507) {
      throw _statusException(response, operation: 'synchronize');
    }
    final multistatus = _xmlParser.parseMultistatus(
      response.bodyBytes,
      correlationId: correlationId,
    );
    if (multistatus.hasCondition(davNamespace, 'valid-sync-token')) {
      throw DavException(
        kind: DavErrorKind.invalidSyncToken,
        code: 'DavSyncTokenInvalid',
        safeMessage: 'The DAV synchronization token is no longer valid.',
        statusCode: response.statusCode,
        correlationId: correlationId,
      );
    }
    final nextToken = multistatus.syncToken;
    if (nextToken == null || nextToken.isEmpty) {
      throw DavException(
        kind: DavErrorKind.protocol,
        code: 'DavSyncResponseMissingToken',
        safeMessage: 'The DAV synchronization response omitted its token.',
        correlationId: correlationId,
      );
    }
    final changed = <DavRemoteMember>[];
    final deleted = <String>{};
    var truncated =
        response.statusCode == 507 ||
        multistatus.hasCondition(
          davNamespace,
          'number-of-matches-within-limits',
        );
    for (final entry in multistatus.responses) {
      final target = _resolveMember(entry.href, response, correlationId);
      if (target == null) continue;
      final hasLimitStatus =
          entry.statusCode == 507 ||
          entry.propstats.any((propstat) => propstat.statusCode == 507);
      if (hasLimitStatus) {
        truncated = true;
        continue;
      }
      final resourceMissing =
          entry.statusCode == 404 ||
          (entry.statusCode == null &&
              entry.propstats.isNotEmpty &&
              entry.propstats.every((propstat) => propstat.statusCode == 404));
      if (resourceMissing) {
        deleted.add(target.hrefKey);
        continue;
      }
      if (entry.statusCode case final status? when status >= 400) {
        throw _memberStatusException(status, correlationId);
      }
      final etag = entry
          .successfulProperty(davNamespace, 'getetag')
          ?.text
          .trim();
      if (etag == null || etag.isEmpty) {
        throw DavException(
          kind: DavErrorKind.protocol,
          code: 'DavSyncMemberMissingEtag',
          safeMessage: 'A changed DAV object did not contain an ETag.',
          correlationId: correlationId,
        );
      }
      changed.add(
        DavRemoteMember(
          hrefKey: target.hrefKey,
          requestUri: target.uri,
          etag: etag,
        ),
      );
    }
    return DavSyncPage(
      changedMembers: List.unmodifiable(changed),
      deletedHrefKeys: Set.unmodifiable(deleted),
      nextSyncToken: nextToken,
      truncated: truncated,
    );
  }

  @override
  Future<DavMemberInventory> listMemberEtags({
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) async {
    final response = await _transport.send(
      DavRequest.xml(
        method: 'PROPFIND',
        uri: _collectionUri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: const {'depth': '1'},
        body: _memberEtagPropfind,
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    if (response.statusCode != 207) {
      throw _statusException(response, operation: 'list members');
    }
    final multistatus = _xmlParser.parseMultistatus(
      response.bodyBytes,
      correlationId: correlationId,
    );
    final members = <DavRemoteMember>[];
    for (final entry in multistatus.responses) {
      final target = _resolveMember(entry.href, response, correlationId);
      if (target == null) continue;
      if (entry.statusCode == 404) continue;
      if (entry.statusCode case final status? when status >= 400) {
        throw _memberStatusException(status, correlationId);
      }
      final etag = entry
          .successfulProperty(davNamespace, 'getetag')
          ?.text
          .trim();
      if (etag == null || etag.isEmpty) {
        throw DavException(
          kind: DavErrorKind.protocol,
          code: 'DavInventoryMemberMissingEtag',
          safeMessage: 'A DAV collection member did not contain an ETag.',
          correlationId: correlationId,
        );
      }
      members.add(
        DavRemoteMember(
          hrefKey: target.hrefKey,
          requestUri: target.uri,
          etag: etag,
        ),
      );
    }
    return DavMemberInventory(members: List.unmodifiable(members));
  }

  @override
  Future<List<DavFetchedMember>> fetchMembers(
    List<DavRemoteMember> members, {
    required String correlationId,
    required bool useCalendarMultiget,
    DavCancellationToken? cancellationToken,
  }) async {
    if (members.isEmpty) return const [];
    if (!useCalendarMultiget) {
      return Future.wait([
        for (final member in members)
          _getMember(
            member,
            correlationId: correlationId,
            cancellationToken: cancellationToken,
          ),
      ]);
    }
    final response = await _transport.send(
      DavRequest.xml(
        method: 'REPORT',
        uri: _collectionUri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: const {'depth': '1'},
        body: _calendarMultigetBody(members),
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    if (response.statusCode != 207) {
      throw _statusException(response, operation: 'fetch members');
    }
    final multistatus = _xmlParser.parseMultistatus(
      response.bodyBytes,
      correlationId: correlationId,
    );
    final requested = {for (final member in members) member.hrefKey: member};
    final returned = <String, DavFetchedMember>{};
    for (final entry in multistatus.responses) {
      final target = _resolveMember(entry.href, response, correlationId);
      if (target == null || !requested.containsKey(target.hrefKey)) {
        throw DavException(
          kind: DavErrorKind.protocol,
          code: 'DavMultigetReturnedUnexpectedMember',
          safeMessage: 'The DAV server returned an unexpected object.',
          correlationId: correlationId,
        );
      }
      if (entry.statusCode == 404) {
        returned[target.hrefKey] = DavFetchedMember.missing(
          hrefKey: target.hrefKey,
          requestUri: target.uri,
        );
        continue;
      }
      if (entry.statusCode case final status? when status >= 400) {
        throw _memberStatusException(status, correlationId);
      }
      final etag = entry
          .successfulProperty(davNamespace, 'getetag')
          ?.text
          .trim();
      final calendarData = entry.successfulProperty(
        caldavNamespace,
        'calendar-data',
      );
      if (etag == null || etag.isEmpty || calendarData == null) {
        final onlyMissingPropstats =
            entry.propstats.isNotEmpty &&
            entry.propstats.every((propstat) => propstat.statusCode == 404);
        if (onlyMissingPropstats) {
          returned[target.hrefKey] = DavFetchedMember.missing(
            hrefKey: target.hrefKey,
            requestUri: target.uri,
          );
          continue;
        }
        throw DavException(
          kind: DavErrorKind.protocol,
          code: 'DavMultigetMemberDataMissing',
          safeMessage: 'A DAV object response omitted calendar data or ETag.',
          correlationId: correlationId,
        );
      }
      returned[target.hrefKey] = DavFetchedMember.live(
        hrefKey: target.hrefKey,
        requestUri: target.uri,
        etag: etag,
        contentType: calendarData.element.getAttribute('content-type'),
        rawIcsBody: calendarData.text,
      );
    }

    // An omitted multiget member is ambiguous, so resolve it with a safe GET
    // rather than treating an incomplete response as deletion.
    for (final member in members) {
      returned[member.hrefKey] ??= await _getMember(
        member,
        correlationId: correlationId,
        cancellationToken: cancellationToken,
      );
    }
    return [for (final member in members) returned[member.hrefKey]!];
  }

  Future<DavFetchedMember> _getMember(
    DavRemoteMember member, {
    required String correlationId,
    required DavCancellationToken? cancellationToken,
  }) async {
    final response = await _transport.send(
      DavRequest(
        method: 'GET',
        uri: member.requestUri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: const {'accept': 'text/calendar'},
        retryClass: DavRetryClass.safeRead,
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    if (response.statusCode == 404) {
      return DavFetchedMember.missing(
        hrefKey: member.hrefKey,
        requestUri: response.requestUri,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _statusException(response, operation: 'fetch object');
    }
    final etag = response.etag;
    if (etag == null || etag.isEmpty) {
      throw DavException(
        kind: DavErrorKind.protocol,
        code: 'DavGetMemberMissingEtag',
        safeMessage: 'A DAV object response omitted its ETag.',
        correlationId: correlationId,
      );
    }
    return DavFetchedMember.live(
      hrefKey: member.hrefKey,
      requestUri: response.requestUri,
      etag: etag,
      contentType: response.headers['content-type'],
      rawIcsBody: response.bodyText,
    );
  }

  ({String hrefKey, Uri uri})? _resolveMember(
    String href,
    DavResponse response,
    String correlationId,
  ) {
    final uri = resolveDavHref(
      href: href,
      responseRequestUri: response.requestUri,
      profile: _profile,
      accountAuthority: _accountAuthority,
      correlationId: correlationId,
    );
    final key = normalizedDavHrefKey(_profile.provider, uri);
    final collectionKey = normalizedDavHrefKey(
      _profile.provider,
      _collectionUri,
    );
    if (_sameCollectionTarget(key, collectionKey)) return null;
    if (!_isDirectMember(key, collectionKey)) {
      throw DavException(
        kind: DavErrorKind.protocol,
        code: 'DavObjectOutsideCollection',
        safeMessage:
            'A DAV response referenced an object outside its collection.',
        correlationId: correlationId,
      );
    }
    return (hrefKey: key, uri: uri);
  }

  DavException _statusException(
    DavResponse response, {
    required String operation,
  }) {
    final conditions = _tryErrorConditions(
      response.bodyBytes,
      response.correlationId,
    );
    if (conditions.contains(
      const DavPropertyName(davNamespace, 'valid-sync-token'),
    )) {
      return DavException(
        kind: DavErrorKind.invalidSyncToken,
        code: 'DavSyncTokenInvalid',
        safeMessage: 'The DAV synchronization token is no longer valid.',
        statusCode: response.statusCode,
        correlationId: response.correlationId,
      );
    }
    final mapped = switch (response.statusCode) {
      401 => (DavErrorKind.authentication, 'DavAuthRejected'),
      403 => (DavErrorKind.authorization, 'DavPermissionDenied'),
      404 || 410 => (DavErrorKind.notFound, 'DavCollectionRemoved'),
      409 || 412 || 423 => (DavErrorKind.conflict, 'DavResourceConflict'),
      429 => (DavErrorKind.rateLimited, 'DavRateLimited'),
      507 => (DavErrorKind.limitExceeded, 'DavQuotaOrSizeLimit'),
      >= 500 => (DavErrorKind.server, 'DavServerUnavailable'),
      _ => (DavErrorKind.protocol, 'DavProtocolViolation'),
    };
    return DavException(
      kind: mapped.$1,
      code: mapped.$2,
      safeMessage: 'The DAV server could not $operation.',
      statusCode: response.statusCode,
      correlationId: response.correlationId,
      retryAfter: parseDavRetryAfter(response.headers['retry-after']),
    );
  }

  Set<DavPropertyName> _tryErrorConditions(
    Uint8List body,
    String correlationId,
  ) {
    if (body.isEmpty) return const {};
    try {
      return _xmlParser.parseDavError(body, correlationId: correlationId);
    } on DavException {
      return const {};
    }
  }
}

DavException _memberStatusException(int status, String correlationId) =>
    DavException(
      kind: status == 403
          ? DavErrorKind.authorization
          : status >= 500
          ? DavErrorKind.server
          : DavErrorKind.protocol,
      code: 'DavMemberStatus$status',
      safeMessage: 'A DAV collection member returned an error status.',
      statusCode: status,
      correlationId: correlationId,
    );

bool _sameCollectionTarget(String memberKey, String collectionKey) =>
    memberKey == collectionKey ||
    (collectionKey.endsWith('/') &&
        memberKey == collectionKey.substring(0, collectionKey.length - 1)) ||
    (memberKey.endsWith('/') &&
        memberKey.substring(0, memberKey.length - 1) == collectionKey);

bool _isDirectMember(String memberKey, String collectionKey) {
  final prefix = collectionKey.endsWith('/')
      ? collectionKey
      : '$collectionKey/';
  if (!memberKey.startsWith(prefix)) return false;
  final remainder = memberKey.substring(prefix.length);
  return remainder.isNotEmpty && !remainder.contains('/');
}

String _xmlText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _syncCollectionBody(String token) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token>${_xmlText(token)}</d:sync-token>
  <d:sync-level>1</d:sync-level>
  <d:prop><d:getetag/></d:prop>
</d:sync-collection>''';

String _calendarMultigetBody(List<DavRemoteMember> members) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<c:calendar-multiget xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data content-type="text/calendar" version="2.0"/></d:prop>
  ${members.map((member) => '<d:href>${_xmlText(member.hrefKey)}</d:href>').join()}
</c:calendar-multiget>''';

const _memberEtagPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>''';

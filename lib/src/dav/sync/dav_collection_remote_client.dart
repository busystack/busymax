import 'dart:typed_data';

import '../dav_errors.dart';
import '../dav_href.dart';
import '../dav_provider_profile.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';
import '../xml/dav_propfind_inventory.dart';

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
    this.maximumSyncResults,
    DavXmlParser xmlParser = const DavXmlParser(),
  }) : assert(maximumSyncResults == null || maximumSyncResults > 0),
       _transport = transport,
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

  /// Optional RFC 6578 request bound; omitted by default for existing callers.
  final int? maximumSyncResults;
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
        // RFC 6578 section 3.2 requires Depth: 0 here. The sync-level in
        // the REPORT body selects direct collection members; Depth must not.
        headers: const {'depth': '0'},
        body: _syncCollectionBody(syncToken, maximumSyncResults),
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    if (response.statusCode != 207) {
      throw _statusException(response, operation: 'synchronize');
    }
    // RFC 6578 response grammar is stricter than a general DAV multistatus.
    // Keep bounded, entity-safe decoding in the shared parser while validating
    // protocol-specific cardinality here, before its first-property accessors.
    final root = _xmlParser
        .parseDocument(response.bodyBytes, correlationId: correlationId)
        .rootElement;
    final tokens = root.childElements
        .where(
          (e) =>
              e.name.namespaceUri == davNamespace &&
              e.name.local == 'sync-token',
        )
        .toList();
    if (tokens.length != 1 || tokens.single.childElements.isNotEmpty) {
      throw _syncProtocol('DavSyncResponseMissingToken', correlationId);
    }
    for (final element in root.childElements.where(
      (e) => e.name.namespaceUri == davNamespace && e.name.local == 'response',
    )) {
      int count(String name) => element.childElements
          .where(
            (e) => e.name.namespaceUri == davNamespace && e.name.local == name,
          )
          .length;
      if (count('href') != 1 ||
          count('status') > 1 ||
          count('error') > 1 ||
          (count('status') != 0 && count('propstat') != 0)) {
        throw _syncProtocol('DavSyncInvalidResponse', correlationId);
      }
      for (final stat in element.childElements.where(
        (e) =>
            e.name.namespaceUri == davNamespace && e.name.local == 'propstat',
      )) {
        int statCount(String name) => stat.childElements
            .where(
              (e) =>
                  e.name.namespaceUri == davNamespace && e.name.local == name,
            )
            .length;
        if (statCount('status') != 1 ||
            statCount('prop') != 1 ||
            statCount('error') > 1) {
          throw _syncProtocol('DavSyncInvalidResponse', correlationId);
        }
      }
    }
    final multistatus = _xmlParser.parseMultistatus(
      response.bodyBytes,
      correlationId: correlationId,
    );
    if (multistatus.errorConditions.isNotEmpty) {
      if (multistatus.errorConditions.length == 1 &&
          multistatus.errorConditions.contains(
            const DavPropertyName(davNamespace, 'valid-sync-token'),
          )) {
        throw _invalidSyncToken(response.statusCode, correlationId);
      }
      throw _syncProtocol('DavSyncInvalidResponse', correlationId);
    }
    final nextToken = multistatus.syncToken;
    if (nextToken == null || nextToken.isEmpty) {
      throw _syncProtocol('DavSyncResponseMissingToken', correlationId);
    }
    final tokenUri = Uri.tryParse(nextToken);
    if (tokenUri == null ||
        !tokenUri.hasScheme ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(nextToken) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(nextToken)) {
      throw _syncProtocol('DavSyncResponseInvalidToken', correlationId);
    }
    final changed = <DavRemoteMember>[];
    final deleted = <String>{};
    final seen = <String>{};
    final collectionKey = normalizedDavHrefKey(
      _profile.provider,
      _collectionUri,
    );
    var collectionSeen = false;
    var truncated = false;
    for (final entry in multistatus.responses) {
      final target = _resolveTarget(entry.href, response, correlationId);
      if (_sameCollectionTarget(target.hrefKey, collectionKey)) {
        if (collectionSeen) {
          throw _syncProtocol('DavSyncDuplicateResponse', correlationId);
        }
        collectionSeen = true;
        if (entry.statusCode == 507) {
          if (entry.propstats.isNotEmpty ||
              entry.errorConditions.any(
                (e) =>
                    e !=
                    const DavPropertyName(
                      davNamespace,
                      'number-of-matches-within-limits',
                    ),
              )) {
            throw _syncProtocol('DavSyncInvalidTruncation', correlationId);
          }
          // The 507 on the request URI is mandatory; its DAV:error condition
          // is only SHOULD, so absence of that optional condition is valid.
          truncated = true;
          continue;
        }
        if (entry.statusCode == 403 &&
            entry.errorConditions.contains(
              const DavPropertyName(davNamespace, 'valid-sync-token'),
            )) {
          throw _invalidSyncToken(403, correlationId);
        }
        if (entry.errorConditions.isNotEmpty) {
          throw _syncProtocol('DavSyncInvalidTruncation', correlationId);
        }
        if (entry.statusCode case final status?
            when status < 200 || status >= 300) {
          throw _memberStatusException(status, correlationId);
        }
        for (final stat in entry.propstats) {
          if (!stat.isSuccessful || stat.errorConditions.isNotEmpty) {
            throw _syncProtocol('DavSyncInvalidResponse', correlationId);
          }
        }
        continue;
      }
      _requireDirectMember(target.hrefKey, collectionKey, correlationId);
      if (!seen.add(target.hrefKey)) {
        throw _syncProtocol('DavSyncDuplicateResponse', correlationId);
      }
      if (entry.statusCode == 404 &&
          entry.propstats.isEmpty &&
          entry.errorConditions.isEmpty) {
        deleted.add(target.hrefKey);
        continue;
      }
      if (entry.statusCode != null) {
        // A member-level 507 is an error, never a pagination marker.
        throw _memberStatusException(entry.statusCode!, correlationId);
      }
      if (entry.errorConditions.isNotEmpty || entry.propstats.isEmpty) {
        throw _syncProtocol('DavSyncInvalidMemberResponse', correlationId);
      }
      for (final stat in entry.propstats) {
        if (!stat.isSuccessful) {
          throw _memberStatusException(stat.statusCode, correlationId);
        }
        if (stat.errorConditions.isNotEmpty) {
          throw _syncProtocol('DavSyncInvalidMemberResponse', correlationId);
        }
      }
      final etags = entry.propstats
          .expand((s) => s.properties)
          .where(
            (p) => p.name == const DavPropertyName(davNamespace, 'getetag'),
          )
          .toList();
      if (etags.length != 1 || etags.single.text.trim().isEmpty) {
        throw _syncProtocol('DavSyncMemberMissingEtag', correlationId);
      }
      changed.add(
        DavRemoteMember(
          hrefKey: target.hrefKey,
          requestUri: target.uri,
          etag: etags.single.text.trim(),
        ),
      );
    }
    if (truncated && nextToken == syncToken) {
      throw _syncProtocol('DavSyncPaginationTokenLoop', correlationId);
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
    final multistatus = parseDavPropfindInventory(
      _xmlParser,
      response.bodyBytes,
      correlationId: correlationId,
    );
    final members = <DavRemoteMember>[];
    final seen = <String>{};
    var foundCollection = false;
    final collectionKey = normalizedDavHrefKey(
      _profile.provider,
      _collectionUri,
    );
    for (final entry in multistatus.responses) {
      if (entry.statusCode case final status?) {
        if (status >= 400) throw _memberStatusException(status, correlationId);
        throw _syncProtocol('DavInventoryInvalidResourceStatus', correlationId);
      }
      final uri = resolveDavHref(
        href: entry.href,
        responseRequestUri: response.requestUri,
        profile: _profile,
        accountAuthority: _accountAuthority,
        correlationId: correlationId,
      );
      final key = normalizedDavHrefKey(_profile.provider, uri);
      if (_sameCollectionTarget(key, collectionKey)) {
        if (foundCollection) {
          throw _syncProtocol('DavInventoryDuplicateCollection', correlationId);
        }
        foundCollection = true;
        // getetag is optional on collections. A property-level 404 means the
        // property is unavailable, not that the collection is missing.
        for (final stat in entry.propstats) {
          if (!stat.isSuccessful && stat.statusCode != 404) {
            throw _memberStatusException(stat.statusCode, correlationId);
          }
          if (stat.properties.isEmpty) {
            throw _syncProtocol('DavInventoryInvalidCollection', correlationId);
          }
        }
        continue;
      }
      if (!seen.add(key)) {
        throw _syncProtocol('DavInventoryDuplicateMember', correlationId);
      }
      final target = _resolveMember(entry.href, response, correlationId);
      if (target == null) {
        throw _syncProtocol('DavInventoryInvalidMember', correlationId);
      }
      for (final stat in entry.propstats) {
        if (!stat.isSuccessful) {
          throw _memberStatusException(stat.statusCode, correlationId);
        }
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
    if (!foundCollection) {
      throw _syncProtocol('DavInventoryMissingCollection', correlationId);
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
    final seen = <String>{};
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
      // Duplicate members cannot supply authoritative evidence. Reject even
      // identical duplicates rather than allowing response order to decide.
      if (!seen.add(target.hrefKey)) {
        throw _syncProtocol('DavMultigetDuplicateMember', correlationId);
      }
      if (entry.statusCode != null && entry.propstats.isNotEmpty) {
        throw _syncProtocol('DavMultigetInvalidMember', correlationId);
      }
      if (entry.errorConditions.isNotEmpty) {
        throw _syncProtocol('DavMultigetInvalidMember', correlationId);
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
        // RFC 4918 section 13: propstat describes properties, not resource
        // existence. Missing mandatory properties require safe GET just like
        // an omitted response. No deletion is inferred from property failures.
        continue;
      }
      returned[target.hrefKey] = DavFetchedMember.live(
        hrefKey: target.hrefKey,
        requestUri: target.uri,
        etag: etag,
        contentType: calendarData.element.getAttribute('content-type'),
        rawIcsBody: calendarData.text,
      );
    }

    // An omitted or incomplete multiget member is ambiguous; use a safe GET
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
    if (response.statusCode != 200) {
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
    final target = _resolveTarget(href, response, correlationId);
    final collectionKey = normalizedDavHrefKey(
      _profile.provider,
      _collectionUri,
    );
    if (_sameCollectionTarget(target.hrefKey, collectionKey)) return null;
    _requireDirectMember(target.hrefKey, collectionKey, correlationId);
    return target;
  }

  ({String hrefKey, Uri uri}) _resolveTarget(
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
    return (hrefKey: normalizedDavHrefKey(_profile.provider, uri), uri: uri);
  }

  void _requireDirectMember(
    String key,
    String collectionKey,
    String correlationId,
  ) {
    if (!_isDirectMember(key, collectionKey)) {
      throw _syncProtocol('DavObjectOutsideCollection', correlationId);
    }
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
      kind: status == 401
          ? DavErrorKind.authentication
          : status == 403
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

String _syncCollectionBody(String token, int? maximumResults) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token>${_xmlText(token)}</d:sync-token>
  <d:sync-level>1</d:sync-level>
  ${maximumResults == null ? '' : '<d:limit><d:nresults>$maximumResults</d:nresults></d:limit>'}
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

DavException _syncProtocol(String code, String correlationId) => DavException(
  kind: DavErrorKind.protocol,
  code: code,
  safeMessage: 'The DAV synchronization response is incomplete or invalid.',
  correlationId: correlationId,
);

DavException _invalidSyncToken(int status, String correlationId) =>
    DavException(
      kind: DavErrorKind.invalidSyncToken,
      code: 'DavSyncTokenInvalid',
      safeMessage: 'The DAV synchronization token is no longer valid.',
      statusCode: status,
      correlationId: correlationId,
    );

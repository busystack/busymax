import 'dart:convert';

import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../http/dav_http_transport.dart';
import '../storage/dav_object_repository.dart';
import 'dav_collection_remote_client.dart';

final class DavSyncLimits {
  const DavSyncLimits({
    this.maximumSyncPages = 1000,
    this.maximumMembersPerMultiget = 100,
    this.maximumResourceBytes = 16 * 1024 * 1024,
  });

  final int maximumSyncPages;
  final int maximumMembersPerMultiget;
  final int maximumResourceBytes;
}

final class DavCollectionSyncResult {
  const DavCollectionSyncResult({
    required this.initialOrRebaseline,
    required this.usedSyncCollection,
    required this.pages,
    required this.membersSeen,
    required this.objectsFetched,
    required this.objectsDeleted,
    required this.finalCursorKind,
    required this.finalCursorValue,
    required this.affectedObjectIds,
  });

  final bool initialOrRebaseline;
  final bool usedSyncCollection;
  final int pages;
  final int membersSeen;
  final int objectsFetched;
  final int objectsDeleted;
  final String finalCursorKind;
  final String finalCursorValue;
  final Set<String> affectedObjectIds;
}

final class DavSyncEngine {
  DavSyncEngine({
    required AppDatabase database,
    required DavObjectRepository objectRepository,
    required DavCollectionRemoteClient remoteClient,
    required String accountId,
    required String collectionId,
    required BusyProvider provider,
    DavSyncLimits limits = const DavSyncLimits(),
    DateTime Function()? nowUtc,
    Future<void> Function(String accountId)? onNotificationsNeedRebuild,
    Future<void> Function(String collectionId)? onCollectionNeedsRediscovery,
  }) : _database = database,
       _objectRepository = objectRepository,
       _remoteClient = remoteClient,
       _accountId = accountId,
       _collectionId = collectionId,
       _provider = provider,
       _limits = limits,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _onNotificationsNeedRebuild = onNotificationsNeedRebuild,
       _onCollectionNeedsRediscovery = onCollectionNeedsRediscovery;

  final AppDatabase _database;
  final DavObjectRepository _objectRepository;
  final DavCollectionRemoteClient _remoteClient;
  final String _accountId;
  final String _collectionId;
  final BusyProvider _provider;
  final DavSyncLimits _limits;
  final DateTime Function() _nowUtc;
  final Future<void> Function(String accountId)? _onNotificationsNeedRebuild;
  final Future<void> Function(String collectionId)?
  _onCollectionNeedsRediscovery;

  Future<DavCollectionSyncResult> synchronize({
    required String correlationId,
    DateTime? projectionRangeStartUtc,
    DateTime? projectionRangeEndUtc,
    DavCancellationToken? cancellationToken,
    bool forceRebaseline = false,
  }) async {
    cancellationToken?.throwIfCancelled(correlationId: correlationId);
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(_collectionId))).getSingleOrNull();
    if (collection == null || collection.accountId != _accountId) {
      throw const DavException(
        kind: DavErrorKind.notFound,
        code: 'DavCollectionNotFound',
        safeMessage: 'The DAV collection is no longer available.',
      );
    }
    if (collection.deleted || collection.serverMissing) {
      throw const DavException(
        kind: DavErrorKind.notFound,
        code: 'DavCollectionRemoved',
        safeMessage: 'The DAV collection was removed from the server.',
      );
    }
    final reports = _stringSet(collection.supportedReportsJson);
    final supportsSyncCollection = reports.contains('{DAV:}sync-collection');
    final supportsCalendarMultiget = reports.contains(
      '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
    );
    final cursor = await _objectRepository.cursor(_collectionId);
    final generation = await _objectRepository.nextBaselineGeneration(
      _collectionId,
    );
    final window = davProjectionWindow(_nowUtc());
    final projectionStart = (projectionRangeStartUtc ?? window.start).toUtc();
    final projectionEnd = (projectionRangeEndUtc ?? window.end).toUtc();
    final projectionStale = _projectionStateStale(
      cursor,
      projectionStart,
      projectionEnd,
    );
    await _objectRepository.markSyncStarted(
      accountId: _accountId,
      collectionId: _collectionId,
      provider: _provider,
      generation: generation,
    );

    try {
      final localObjects = await _objectRepository.liveObjects(_collectionId);
      final localByHref = {
        for (final object in localObjects) object.hrefKey: object,
      };
      late final _CollectedRemoteChanges remote;
      var initialOrRebaseline = false;
      if (supportsSyncCollection) {
        final savedToken =
            !forceRebaseline && cursor?.cursorKind == 'dav_sync_token'
            ? cursor?.cursorValue
            : null;
        initialOrRebaseline = savedToken == null || savedToken.isEmpty;
        try {
          remote = await _collectSyncPages(
            syncToken: savedToken ?? '',
            initial: initialOrRebaseline,
            correlationId: correlationId,
            cancellationToken: cancellationToken,
          );
        } on DavException catch (error) {
          if (error.kind != DavErrorKind.invalidSyncToken ||
              initialOrRebaseline) {
            rethrow;
          }
          initialOrRebaseline = true;
          remote = await _collectSyncPages(
            syncToken: '',
            initial: true,
            correlationId: correlationId,
            cancellationToken: cancellationToken,
          );
        }
      } else {
        initialOrRebaseline = true;
        remote = await _collectFallbackInventory(
          correlationId: correlationId,
          cancellationToken: cancellationToken,
        );
      }

      final fetch = <DavRemoteMember>[];
      for (final member in remote.liveMembers.values) {
        final local = localByHref[member.hrefKey];
        if (local == null ||
            local.serverDeleted ||
            local.etag != member.etag ||
            local.parserVersion != davRawObjectParserVersion) {
          fetch.add(member);
        }
      }
      final prepared = <DavPreparedObject>[];
      final deleted = {...remote.deletedHrefKeys};
      final membership = {...remote.membershipHrefKeys};
      for (
        var offset = 0;
        offset < fetch.length;
        offset += _limits.maximumMembersPerMultiget
      ) {
        final end = (offset + _limits.maximumMembersPerMultiget).clamp(
          0,
          fetch.length,
        );
        final batch = fetch.sublist(offset, end);
        final fetched = await _remoteClient.fetchMembers(
          batch,
          correlationId: correlationId,
          useCalendarMultiget: supportsCalendarMultiget,
          cancellationToken: cancellationToken,
        );
        if (fetched.length != batch.length) {
          throw const DavException(
            kind: DavErrorKind.protocol,
            code: 'DavObjectFetchIncomplete',
            safeMessage: 'The DAV server returned an incomplete object batch.',
          );
        }
        for (final object in fetched) {
          if (object.missing) {
            deleted.add(object.hrefKey);
            membership.remove(object.hrefKey);
            continue;
          }
          final serverMaximum = collection.maximumResourceSize;
          final maximumBytes = serverMaximum == null || serverMaximum <= 0
              ? _limits.maximumResourceBytes
              : serverMaximum < _limits.maximumResourceBytes
              ? serverMaximum
              : _limits.maximumResourceBytes;
          prepared.add(
            DavPreparedObject.parse(
              hrefKey: object.hrefKey,
              requestUri: object.requestUri,
              etag: object.etag,
              contentType: object.contentType,
              rawIcsBody: object.rawIcsBody!,
              maximumResourceBytes: maximumBytes,
            ),
          );
        }
      }

      final completedAt = _nowUtc().toUtc();
      final finalCursorKind = supportsSyncCollection
          ? 'dav_sync_token'
          : 'snapshot_generation';
      final finalCursorValue = supportsSyncCollection
          ? remote.finalToken!
          : generation.toString();
      final affected = await _objectRepository.commit(
        DavCollectionCommit(
          accountId: _accountId,
          collectionId: _collectionId,
          provider: _provider,
          objects: prepared,
          deletedHrefKeys: deleted,
          completeMembership: remote.completeMembership,
          membershipHrefKeys: membership,
          finalCursorKind: finalCursorKind,
          finalCursorValue: finalCursorValue,
          baselineGeneration: generation,
          completedAtUtc: completedAt,
          projectionRangeStartUtc: projectionStart,
          projectionRangeEndUtc: projectionEnd,
          forceReprojection: projectionStale,
        ),
      );
      await _onNotificationsNeedRebuild?.call(_accountId);
      return DavCollectionSyncResult(
        initialOrRebaseline: initialOrRebaseline,
        usedSyncCollection: supportsSyncCollection,
        pages: remote.pages,
        membersSeen: membership.length,
        objectsFetched: prepared.length,
        objectsDeleted: deleted.length,
        finalCursorKind: finalCursorKind,
        finalCursorValue: finalCursorValue,
        affectedObjectIds: Set.unmodifiable(affected),
      );
    } on DavException catch (error) {
      await _objectRepository.markSyncFailed(
        collectionId: _collectionId,
        errorCode: error.code,
      );
      if (error.kind == DavErrorKind.notFound) {
        await _onCollectionNeedsRediscovery?.call(_collectionId);
      }
      rethrow;
    } on Object {
      await _objectRepository.markSyncFailed(
        collectionId: _collectionId,
        errorCode: 'DavUnexpectedSyncFailure',
      );
      rethrow;
    }
  }

  Future<_CollectedRemoteChanges> _collectSyncPages({
    required String syncToken,
    required bool initial,
    required String correlationId,
    required DavCancellationToken? cancellationToken,
  }) async {
    var requestToken = syncToken;
    final seenTokens = <String>{syncToken};
    final live = <String, DavRemoteMember>{};
    final deleted = <String>{};
    var pages = 0;
    while (pages < _limits.maximumSyncPages) {
      final page = await _remoteClient.syncCollectionPage(
        syncToken: requestToken,
        correlationId: correlationId,
        cancellationToken: cancellationToken,
      );
      pages += 1;
      for (final member in page.changedMembers) {
        live[member.hrefKey] = member;
        deleted.remove(member.hrefKey);
      }
      for (final href in page.deletedHrefKeys) {
        live.remove(href);
        deleted.add(href);
      }
      if (!page.truncated) {
        return _CollectedRemoteChanges(
          liveMembers: live,
          deletedHrefKeys: deleted,
          membershipHrefKeys: initial ? live.keys.toSet() : const {},
          completeMembership: initial,
          finalToken: page.nextSyncToken,
          pages: pages,
        );
      }
      if (!seenTokens.add(page.nextSyncToken)) {
        throw const DavException(
          kind: DavErrorKind.protocol,
          code: 'DavSyncPaginationTokenLoop',
          safeMessage: 'The DAV synchronization pagination did not advance.',
        );
      }
      requestToken = page.nextSyncToken;
    }
    throw const DavException(
      kind: DavErrorKind.limitExceeded,
      code: 'DavSyncPageLimitExceeded',
      safeMessage: 'The DAV synchronization returned too many pages.',
    );
  }

  Future<_CollectedRemoteChanges> _collectFallbackInventory({
    required String correlationId,
    required DavCancellationToken? cancellationToken,
  }) async {
    final inventory = await _remoteClient.listMemberEtags(
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
    final live = {
      for (final member in inventory.members) member.hrefKey: member,
    };
    return _CollectedRemoteChanges(
      liveMembers: live,
      deletedHrefKeys: const {},
      membershipHrefKeys: live.keys.toSet(),
      completeMembership: true,
      finalToken: null,
      pages: 1,
    );
  }
}

final class _CollectedRemoteChanges {
  const _CollectedRemoteChanges({
    required this.liveMembers,
    required this.deletedHrefKeys,
    required this.membershipHrefKeys,
    required this.completeMembership,
    required this.finalToken,
    required this.pages,
  });

  final Map<String, DavRemoteMember> liveMembers;
  final Set<String> deletedHrefKeys;
  final Set<String> membershipHrefKeys;
  final bool completeMembership;
  final String? finalToken;
  final int pages;
}

Set<String> _stringSet(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) return const {};
  return decoded.map((value) => value.toString()).toSet();
}

bool _projectionStateStale(SyncCursor? cursor, DateTime start, DateTime end) {
  if (cursor == null || cursor.stateJson == null) return true;
  try {
    final decoded = jsonDecode(cursor.stateJson!);
    return decoded is! Map ||
        decoded['projectionRangeStartUtc'] != start.toIso8601String() ||
        decoded['projectionRangeEndUtc'] != end.toIso8601String() ||
        decoded['projectionVersion'] != davProjectionVersion;
  } on FormatException {
    return true;
  }
}

({DateTime start, DateTime end}) davProjectionWindow(DateTime nowUtc) {
  final utc = nowUtc.toUtc();
  return (
    start: DateTime.utc(utc.year - 1, utc.month),
    end: DateTime.utc(utc.year + 2, utc.month + 1),
  );
}

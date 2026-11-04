import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:xml/xml.dart';

import '../dav_errors.dart';
import '../http/dav_http_transport.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_collection_mutation_helpers.dart';
import '../xml/dav_xml.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';

enum NextcloudTrashKind {
  event,
  task,
  unknownObject,
  calendar,
  taskList,
  mixedCollection,
}

String? _displayName(DavMultistatusResponse row) {
  final name = row.successfulProperty(davNamespace, 'displayname')?.text.trim();
  return name == null || name.isEmpty ? null : name;
}

final class NextcloudTrashItem {
  const NextcloudTrashItem._({
    required this.accountId,
    required this.href,
    required this.trashBinHref,
    required this.kind,
    required this.title,
    required this.deletedAt,
    required this.etag,
    required this.canRestore,
    required this.canPermanentlyDelete,
    required this.authorizationGeneration,
    required this.calendarHomeHref,
    this.uid,
    this.calendarUri,
    this.sourceCalendarUri,
    this.contentLoaded = false,
  });
  final String accountId;
  final Uri href;
  final Uri trashBinHref;
  final NextcloudTrashKind kind;
  final String title;
  final String? deletedAt;
  final String? etag;
  final bool canRestore;
  final bool canPermanentlyDelete;
  final int authorizationGeneration;
  final Uri calendarHomeHref;
  final String? uid;
  final String? calendarUri;
  final String? sourceCalendarUri;
  final bool contentLoaded;

  bool get isObject => switch (kind) {
    NextcloudTrashKind.event ||
    NextcloudTrashKind.task ||
    NextcloudTrashKind.unknownObject => true,
    _ => false,
  };
}

final class NextcloudTrashListing {
  const NextcloudTrashListing(this.items, this.retentionSeconds);
  final List<NextcloudTrashItem> items;
  final int? retentionSeconds;
}

/// Nextcloud CalDAV trash. No Files API and no local-deleted-row restoration.
final class NextcloudTrashService {
  NextcloudTrashService(this.collections);
  final NextcloudCollectionService collections;

  Future<NextcloudTrashListing> list({
    DavCancellationToken? cancellationToken,
    bool includeContent = false,
  }) => _list(
    cancellationToken: cancellationToken,
    includeContent: includeContent,
  );

  /// Enrich only an explicitly selected object. The metadata snapshot remains
  /// usable if this bounded read fails; mutations still revalidate live ACLs.
  Future<NextcloudTrashItem> details(
    NextcloudTrashItem item, {
    DavCancellationToken? cancellationToken,
  }) async {
    if (item.accountId != collections.accountId) {
      throw nextcloudOperationError(403, 'DavTrashIdentityMismatch');
    }
    if (!item.isObject || item.contentLoaded) return item;
    final context = await collections.openContext();
    if (item.authorizationGeneration != context.authorizationGeneration) {
      throw nextcloudOperationError(412, 'DavTrashIdentityChanged');
    }
    final etag = item.etag;
    if (etag == null || etag.startsWith('W/')) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    final response = await context.send(
      'GET',
      context.resolve(item.href.toString(), context.authority),
      headers: {'If-Match': etag},
      cancellationToken: cancellationToken,
    );
    if (response.statusCode != 200) {
      throw nextcloudOperationError(response.statusCode, 'DavTrashReadFailed');
    }
    if (response.etag != etag) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    final content = IcalSemanticDocument.parse(response.bodyText).components
        .where((c) => c.componentType == 'VEVENT' || c.componentType == 'VTODO')
        .firstOrNull;
    if (content == null) {
      throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
    }
    final kind = content.componentType == 'VTODO'
        ? NextcloudTrashKind.task
        : NextcloudTrashKind.event;
    if (item.kind != NextcloudTrashKind.unknownObject && item.kind != kind) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    return NextcloudTrashItem._(
      accountId: item.accountId,
      href: item.href,
      trashBinHref: item.trashBinHref,
      kind: kind,
      title: content.summary ?? item.title,
      deletedAt: item.deletedAt,
      etag: etag,
      canRestore: item.canRestore,
      canPermanentlyDelete: item.canPermanentlyDelete,
      authorizationGeneration: item.authorizationGeneration,
      calendarHomeHref: item.calendarHomeHref,
      uid: content.uid,
      calendarUri: item.calendarUri,
      sourceCalendarUri: item.sourceCalendarUri,
      contentLoaded: true,
    );
  }

  Future<NextcloudTrashListing> _list({
    DavCancellationToken? cancellationToken,
    bool includeContent = true,
    NextcloudTrashItem? revalidateItem,
  }) async {
    cancellationToken?.throwIfCancelled();
    final context = await collections.openContext();
    cancellationToken?.throwIfCancelled();
    if (!context.features.contains('nc-calendar-trashbin')) {
      throw nextcloudOperationError(405, 'DavTrashUnsupported');
    }
    final rows =
        await (collections.database.select(collections.database.davCollections)
              ..where(
                (r) =>
                    r.accountId.equals(collections.accountId) &
                    r.serverMissing.equals(false),
              ))
            .get();
    final bins = rows
        .where(
          (r) => (jsonDecode(r.resourceTypesJson) as List).contains(
            '{$nextcloudNamespace}trash-bin',
          ),
        )
        .toList();
    if (bins.isEmpty) {
      throw nextcloudOperationError(404, 'DavTrashNotDiscovered');
    }
    final items = <String, NextcloudTrashItem>{};
    int? retention;
    for (final bin in bins) {
      final binUri = context.resolve(bin.requestUri, context.authority);
      final metadata = jsonDecode(bin.safeDisplayMetadataJson ?? '{}') as Map;
      final homeHref = metadata['calendarHomeHref'];
      if (homeHref is! String) {
        throw nextcloudOperationError(409, 'DavDiscoveryRequired');
      }
      final home = context.resolve(homeHref, context.authority);
      final binState = await context.propfind(
        binUri,
        cancellationToken: cancellationToken,
        // Nextcloud's IProperties supplies the custom resource type while
        // resolving display properties. Request the same shape as inventory;
        // a minimal built-in-only PROPFIND can report just DAV:collection.
        '<d:resourcetype/><d:displayname/><d:current-user-privilege-set/><nc:trash-bin-retention-duration/>',
      );
      final binEntry = binState.responses
          .where((r) => context.resolve(r.href, binUri) == binUri)
          .firstOrNull;
      if (binEntry == null ||
          !nextcloudPropertyNames(
            binEntry.successfulProperty(davNamespace, 'resourcetype'),
          ).contains('{$nextcloudNamespace}trash-bin')) {
        throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
      }
      retention ??= int.tryParse(
        binEntry
                .successfulProperty(
                  nextcloudNamespace,
                  'trash-bin-retention-duration',
                )
                ?.text
                .trim() ??
            '',
      );
      final canRestoreIntoBin = davPrivilege(
        nextcloudPropertyNames(
          binEntry.successfulProperty(
            davNamespace,
            'current-user-privilege-set',
          ),
        ),
        'bind',
      );
      final objects = context.resolve(
        davCollectionUri(binUri).resolve('objects').toString(),
        binUri,
      );
      // The server has no cursor/pagination for this container. Discover only
      // identity metadata first; never request all deleted calendar bodies.
      final index = <Uri, DavMultistatusResponse>{};
      const metadataProperties =
          '<d:displayname/><d:getetag/><d:getcontentlength/><d:getcontenttype/>'
          '<d:current-user-privilege-set/><nc:deleted-at/><nc:calendar-uri/><nc:source-calendar-uri/>';
      {
        // A VCALENDAR query covers both events and tasks in one inventory.
        final response = await context.send(
          'REPORT',
          objects,
          cancellationToken: cancellationToken,
          headers: {'depth': '1'},
          xml:
              '<c:calendar-query $nextcloudXmlNamespaces><d:prop>$metadataProperties</d:prop><c:filter><c:comp-filter name="VCALENDAR"/></c:filter></c:calendar-query>',
        );
        if (response.statusCode != 207) {
          throw nextcloudOperationError(
            response.statusCode,
            'DavTrashReadFailed',
          );
        }
        final data = const DavXmlParser().parseMultistatus(response.bodyBytes);
        if (data.errorConditions.isNotEmpty) {
          throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
        }
        for (final row in data.responses) {
          if ((row.statusCode ?? 200) >= 400) {
            throw nextcloudOperationError(
              row.statusCode!,
              'DavTrashReadFailed',
            );
          }
          final href = context.resolve(row.href, response.requestUri);
          if (!href.path.startsWith(davCollectionUri(objects).path) ||
              href.path == davCollectionUri(objects).path) {
            throw nextcloudOperationError(502, 'DavTrashUnexpectedHref');
          }
          if (index.containsKey(href) &&
              index[href]!.successfulProperty(davNamespace, 'getetag')?.text !=
                  row.successfulProperty(davNamespace, 'getetag')?.text) {
            throw nextcloudOperationError(409, 'DavTrashItemChanged');
          }
          index[href] = row;
        }
      }
      void addItem(
        Uri href,
        DavMultistatusResponse row,
        String? raw, {
        NextcloudTrashKind? knownKind,
      }) {
        final content = raw == null
            ? null
            : IcalSemanticDocument.parse(raw).components
                  .where(
                    (c) =>
                        c.componentType == 'VEVENT' ||
                        c.componentType == 'VTODO',
                  )
                  .firstOrNull;
        if (raw != null && content == null) {
          throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
        }
        // Nextcloud advertises unbind on modifiable deleted objects, including
        // writable shares. The bin's owner ACL alone is not sufficient.
        final canRemove = davPrivilege(
          nextcloudPropertyNames(
            row.successfulProperty(davNamespace, 'current-user-privilege-set'),
          ),
          'unbind',
        );
        items[href.toString()] = NextcloudTrashItem._(
          accountId: collections.accountId,
          authorizationGeneration: context.authorizationGeneration,
          calendarHomeHref: home,
          uid: content?.uid,
          contentLoaded: raw != null,
          href: href,
          trashBinHref: binUri,
          kind:
              knownKind ??
              switch (content?.componentType) {
                'VEVENT' => NextcloudTrashKind.event,
                'VTODO' => NextcloudTrashKind.task,
                _ =>
                  row
                              .successfulProperty(
                                davNamespace,
                                'getcontenttype',
                              )
                              ?.text
                              .contains('VTODO') ==
                          true
                      ? NextcloudTrashKind.task
                      : row
                                .successfulProperty(
                                  davNamespace,
                                  'getcontenttype',
                                )
                                ?.text
                                .contains('VEVENT') ==
                            true
                      ? NextcloudTrashKind.event
                      : NextcloudTrashKind.unknownObject,
              },
          title:
              content?.summary ?? _displayName(row) ?? href.pathSegments.last,
          deletedAt: row
              .successfulProperty(nextcloudNamespace, 'deleted-at')
              ?.text,
          etag: row.successfulProperty(davNamespace, 'getetag')?.text,
          canRestore: canRemove && canRestoreIntoBin,
          canPermanentlyDelete: canRemove,
          calendarUri: row
              .successfulProperty(nextcloudNamespace, 'calendar-uri')
              ?.text,
          sourceCalendarUri: row
              .successfulProperty(nextcloudNamespace, 'source-calendar-uri')
              ?.text,
        );
      }

      // Nextcloud's SabreDAV ignores calendar-data component projection. Budget
      // complete bodies by advertised size instead: <=1 MiB raw per multiget,
      // at most 32 hrefs, leaving headroom for XML escaping under 16 MiB.
      const detailBudget = 1024 * 1024;
      final batches = <List<Uri>>[];
      var batch = <Uri>[];
      var bytes = 0;
      for (final entry in index.entries) {
        if (!includeContent) {
          if (revalidateItem != null) {
            if (entry.key != revalidateItem.href) continue;
            final etag = entry.value
                .successfulProperty(davNamespace, 'getetag')
                ?.text;
            // Component metadata is optional. A matching strong ETag proves
            // the previously parsed type/UID still identifies this same body.
            if (etag == null ||
                etag.startsWith('W/') ||
                etag != revalidateItem.etag) {
              throw nextcloudOperationError(412, 'DavTrashItemChanged');
            }
          }
          addItem(
            entry.key,
            entry.value,
            null,
            knownKind: revalidateItem?.kind,
          );
          continue;
        }
        final size = int.tryParse(
          entry.value
                  .successfulProperty(davNamespace, 'getcontentlength')
                  ?.text ??
              '',
        );
        if (size == null || size < 0 || size > detailBudget) {
          if (batch.isNotEmpty) {
            batches.add(batch);
            batch = [];
            bytes = 0;
          }
          // Unusually large objects remain discoverable from metadata. They
          // are restored/deleted with the same ETag and ACL checks, without
          // downloading attachments simply to display a trash title.
          if (size != null && size > 16 * detailBudget) {
            addItem(entry.key, entry.value, null);
            continue;
          }
          final response = await context.send(
            'GET',
            entry.key,
            cancellationToken: cancellationToken,
            headers: {
              if (entry.value.successfulProperty(davNamespace, 'getetag')?.text
                  case final etag?)
                'If-Match': etag,
            },
          );
          if (response.statusCode == 404 || response.statusCode == 410) {
            continue;
          }
          if (response.statusCode != 200) {
            throw nextcloudOperationError(
              response.statusCode,
              'DavTrashReadFailed',
            );
          }
          if (response.etag !=
              entry.value.successfulProperty(davNamespace, 'getetag')?.text) {
            throw nextcloudOperationError(409, 'DavTrashItemChanged');
          }
          addItem(entry.key, entry.value, response.bodyText);
          continue;
        }
        if (batch.length == 32 || bytes + size > detailBudget) {
          batches.add(batch);
          batch = [];
          bytes = 0;
        }
        batch.add(entry.key);
        bytes += size;
      }
      if (batch.isNotEmpty) batches.add(batch);
      for (final batch in batches) {
        final response = await context.send(
          'REPORT',
          objects,
          cancellationToken: cancellationToken,
          xml:
              '<c:calendar-multiget $nextcloudXmlNamespaces><d:prop><d:getetag/><c:calendar-data/></d:prop>'
              '${batch.map((h) => '<d:href>${XmlText(h.path).toXmlString()}</d:href>').join()}'
              '</c:calendar-multiget>',
        );
        if (response.statusCode != 207) {
          throw nextcloudOperationError(
            response.statusCode,
            'DavTrashReadFailed',
          );
        }
        final data = const DavXmlParser().parseMultistatus(response.bodyBytes);
        if (data.errorConditions.isNotEmpty) {
          throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
        }
        final seen = <Uri>{};
        for (final row in data.responses) {
          final href = context.resolve(row.href, response.requestUri);
          if (!batch.contains(href) || !seen.add(href)) {
            throw nextcloudOperationError(502, 'DavTrashUnexpectedHref');
          }
          if (row.statusCode == 404 || row.statusCode == 410) continue;
          if ((row.statusCode ?? 200) >= 400) {
            throw nextcloudOperationError(
              row.statusCode!,
              'DavTrashReadFailed',
            );
          }
          if (row.successfulProperty(davNamespace, 'getetag')?.text !=
              index[href]!.successfulProperty(davNamespace, 'getetag')?.text) {
            throw nextcloudOperationError(409, 'DavTrashItemChanged');
          }
          final raw = row
              .successfulProperty(caldavNamespace, 'calendar-data')
              ?.text;
          if (raw == null) {
            throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
          }
          addItem(href, index[href]!, raw);
        }
        if (seen.length != batch.length) {
          throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
        }
      }
      // Deleted calendars live in their actual calendar home, not the bin's
      // objects child. Read a fresh inventory, including after confirmation:
      // a cached deleted row must never authorize deleting a restored calendar.
      final inventory = await context.propfind(
        home,
        '<d:resourcetype/><d:displayname/><d:current-user-privilege-set/><d:getetag/><c:supported-calendar-component-set/><nc:deleted-at/>',
        depth: '1',
        cancellationToken: cancellationToken,
      );
      if (inventory.errorConditions.isNotEmpty || inventory.responses.isEmpty) {
        throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
      }
      final parent = inventory.responses
          .where((r) => context.resolve(r.href, home) == home)
          .firstOrNull;
      final canRemoveCalendar = davPrivilege(
        nextcloudPropertyNames(
          parent?.successfulProperty(
            davNamespace,
            'current-user-privilege-set',
          ),
        ),
        'unbind',
      );
      for (final row in inventory.responses) {
        final types = row.successfulProperty(davNamespace, 'resourcetype');
        if ((row.statusCode ?? 200) >= 400 || types == null) {
          throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
        }
        if (!nextcloudPropertyNames(types)
            .contains('{$nextcloudNamespace}deleted-calendar')) {
          continue;
        }
        final href = context.resolve(row.href, home);
        if (!href.path.startsWith(davCollectionUri(home).path)) {
          throw nextcloudOperationError(502, 'DavTrashUnexpectedHref');
        }
        final components =
            row
                .successfulProperty(
                  caldavNamespace,
                  'supported-calendar-component-set',
                )
                ?.element
                .descendantElements
                .map((e) => e.getAttribute('name'))
                .toSet() ??
            {};
        final kind = components.contains('VTODO')
            ? (components.contains('VEVENT')
                  ? NextcloudTrashKind.mixedCollection
                  : NextcloudTrashKind.taskList)
            : NextcloudTrashKind.calendar;
        items[href.toString()] = NextcloudTrashItem._(
          accountId: collections.accountId,
          authorizationGeneration: context.authorizationGeneration,
          calendarHomeHref: home,
          href: href,
          trashBinHref: binUri,
          kind: kind,
          title:
              row.successfulProperty(davNamespace, 'displayname')?.text ?? '',
          deletedAt: row
              .successfulProperty(nextcloudNamespace, 'deleted-at')
              ?.text,
          etag: row.successfulProperty(davNamespace, 'getetag')?.text,
          canRestore: canRemoveCalendar && canRestoreIntoBin,
          canPermanentlyDelete: canRemoveCalendar,
        );
      }
    }
    return NextcloudTrashListing(List.unmodifiable(items.values), retention);
  }

  Future<NextcloudMutationOutcome> restore(NextcloudTrashItem item) =>
      _mutate(item, permanent: false);
  Future<NextcloudMutationOutcome> permanentlyDelete(NextcloudTrashItem item) =>
      _mutate(item, permanent: true);

  Future<NextcloudMutationOutcome> _mutate(
    NextcloudTrashItem item, {
    required bool permanent,
  }) async {
    if (item.accountId != collections.accountId) {
      throw nextcloudOperationError(403, 'DavTrashIdentityMismatch');
    }
    // Re-list after confirmation: expired or changed entries cannot be replayed
    // against a guessed href, UID, account or replacement collection.
    final current = (await _list(includeContent: false, revalidateItem: item))
        .items
        .where(
          (r) =>
              r.href == item.href &&
              r.kind == item.kind &&
              r.trashBinHref == item.trashBinHref,
        )
        .firstOrNull;
    if (current == null) {
      throw nextcloudOperationError(410, 'DavTrashItemExpired');
    }
    if (current.authorizationGeneration != item.authorizationGeneration) {
      throw nextcloudOperationError(412, 'DavTrashIdentityChanged');
    }
    if (item.etag != null && current.etag != item.etag) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    if (current.deletedAt != item.deletedAt) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    if (permanent ? !current.canPermanentlyDelete : !current.canRestore) {
      throw nextcloudOperationError(403, 'DavTrashPermissionDenied');
    }
    if (!permanent) await _requireNoPendingChanges(current);
    final context = await collections.openContext();
    if (context.authorizationGeneration != current.authorizationGeneration) {
      throw nextcloudOperationError(412, 'DavTrashIdentityChanged');
    }
    final source = context.resolve(current.href.toString(), context.authority);
    final destination = context.resolve(
      davCollectionUri(current.trashBinHref).resolve('restore/file').toString(),
      context.authority,
    );
    try {
      final response = await context.send(
        permanent ? 'DELETE' : 'MOVE',
        source,
        headers: {
          if (current.etag != null) 'If-Match': current.etag!,
          if (!permanent) 'Destination': destination.toString(),
          if (!permanent) 'Overwrite': 'F',
          // Only an explicitly confirmed permanent action bypasses retention.
          if (permanent) 'X-NC-CalDAV-No-Trashbin': '1',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw nextcloudOperationError(
          response.statusCode,
          permanent ? 'DavTrashDeleteFailed' : 'DavTrashRestoreFailed',
        );
      }
    } on DavException catch (error) {
      if (!{
        DavErrorKind.unknownOutcome,
        DavErrorKind.timeout,
        DavErrorKind.network,
        DavErrorKind.server,
      }.contains(error.kind)) {
        rethrow;
      }
      // Never repeat a MOVE with an uncertain outcome or fabricate a new UID.
      await collections.refreshResult();
      throw nextcloudOperationError(409, 'DavTrashOutcomeUnknown');
    }
    return collections.refreshResult();
  }

  Future<void> _requireNoPendingChanges(NextcloudTrashItem item) async {
    final rows = await (collections.database.select(
      collections.database.davCollections,
    )..where((r) => r.accountId.equals(collections.accountId))).get();
    final ids = <String>{};
    for (final row in rows) {
      final uri = Uri.parse(row.requestUri);
      final isCollection =
          item.kind != NextcloudTrashKind.event &&
          item.kind != NextcloudTrashKind.task &&
          item.kind != NextcloudTrashKind.unknownObject;
      if (isCollection
          ? uri == item.href
          : uri.path.startsWith(davCollectionUri(item.calendarHomeHref).path) &&
                uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ==
                    item.calendarUri) {
        ids.add(row.id);
      }
    }
    if (ids.isEmpty) return;
    final pending =
        await (collections.database.select(collections.database.pendingOps)
              ..where(
                (r) =>
                    r.accountId.equals(collections.accountId) &
                    (r.davCollectionId.isIn(ids) |
                        r.destinationCollectionId.isIn(ids)),
              )
              ..limit(1))
            .get();
    // Do not discard user edits or replay an old delete immediately after a
    // restore. Resolve this collection's pending work before restoring it.
    if (pending.isNotEmpty) {
      throw nextcloudOperationError(409, 'DavTrashHasPendingChanges');
    }
  }
}

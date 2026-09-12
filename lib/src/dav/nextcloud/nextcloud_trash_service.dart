import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:xml/xml.dart';

import '../dav_errors.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_collection_mutation_helpers.dart';
import '../xml/dav_xml.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';

enum NextcloudTrashKind { event, task, calendar, taskList, mixedCollection }

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
    this.calendarUri,
    this.sourceCalendarUri,
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
  final String? calendarUri;
  final String? sourceCalendarUri;
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

  Future<NextcloudTrashListing> list() async {
    final context = await collections.openContext();
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
      final binState = await context.propfind(
        binUri,
        '<d:resourcetype/><d:current-user-privilege-set/><nc:trash-bin-retention-duration/>',
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
      for (final component in ['VEVENT', 'VTODO']) {
        final response = await context.send(
          'REPORT',
          objects,
          headers: {'depth': '1'},
          xml:
              '<c:calendar-query $nextcloudXmlNamespaces><d:prop><d:getetag/><d:current-user-privilege-set/><c:calendar-data/><nc:deleted-at/><nc:calendar-uri/><nc:source-calendar-uri/></d:prop><c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="$component"/></c:comp-filter></c:filter></c:calendar-query>',
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
          if (!href.path.startsWith(davCollectionUri(objects).path)) {
            throw nextcloudOperationError(502, 'DavTrashUnexpectedHref');
          }
          final raw = row
              .successfulProperty(caldavNamespace, 'calendar-data')
              ?.text;
          if (raw == null) {
            throw nextcloudOperationError(502, 'DavTrashReadIncomplete');
          }
          final document = IcalSemanticDocument.parse(raw);
          final content = document.components
              .where((c) => c.componentType == component)
              .firstOrNull;
          if (content == null) continue;
          // Nextcloud advertises unbind on modifiable deleted objects, including
          // writable shares. The bin's owner ACL alone is not sufficient.
          final canRemove = davPrivilege(
            nextcloudPropertyNames(
              row.successfulProperty(
                davNamespace,
                'current-user-privilege-set',
              ),
            ),
            'unbind',
          );
          items[href.toString()] = NextcloudTrashItem._(
            accountId: collections.accountId,
            href: href,
            trashBinHref: binUri,
            kind: component == 'VEVENT'
                ? NextcloudTrashKind.event
                : NextcloudTrashKind.task,
            title: content.summary ?? '',
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
      }
      // Deleted calendars live in their actual calendar home, not the bin's
      // objects child. Read a fresh inventory, including after confirmation:
      // a cached deleted row must never authorize deleting a restored calendar.
      final homeHref = metadata['calendarHomeHref'];
      if (homeHref is! String) {
        throw nextcloudOperationError(409, 'DavDiscoveryRequired');
      }
      final home = context.resolve(homeHref, context.authority);
      final inventory = await context.propfind(
        home,
        '<d:resourcetype/><d:displayname/><d:current-user-privilege-set/><d:getetag/><c:supported-calendar-component-set/><nc:deleted-at/>',
        depth: '1',
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
        if (!nextcloudPropertyNames(
          types,
        ).contains('{$nextcloudNamespace}deleted-calendar')) {
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
    final current = (await list()).items
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
    if (item.etag != null && current.etag != item.etag) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    if (current.deletedAt != item.deletedAt) {
      throw nextcloudOperationError(412, 'DavTrashItemChanged');
    }
    if (permanent ? !current.canPermanentlyDelete : !current.canRestore) {
      throw nextcloudOperationError(403, 'DavTrashPermissionDenied');
    }
    final context = await collections.openContext();
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
}

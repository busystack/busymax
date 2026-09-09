import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../dav_errors.dart';
import '../http/dav_http_transport.dart';
import '../ical/ical_document.dart';
import '../mutation/dav_collection_mutation_helpers.dart';
import '../xml/dav_xml.dart';
import 'nextcloud_dav_context.dart';

enum NextcloudCollectionRole { owned, shared, delegated, subscription, deleted }

final class NextcloudCollectionState {
  const NextcloudCollectionState({
    required this.collection,
    required this.properties,
    required this.privileges,
    required this.role,
    required this.canRemove,
  });
  final DavCollection collection;
  final Map<DavPropertyName, DavProperty> properties;
  final Set<String> privileges;
  final NextcloudCollectionRole role;
  final bool canRemove;
  bool get canWriteMetadata => davPrivilege(privileges, 'write-properties');
  bool get mixed => collection.supportedComponentMask & 3 == 3;
  String? text(String namespace, String name) =>
      properties[DavPropertyName(namespace, name)]?.text.trim();
  DavProperty? property(String namespace, String name) =>
      properties[DavPropertyName(namespace, name)];
}

/// The same backing collection serves event and task management, including
/// mixed collections. Local visibility and sidebar order are never modified.
final class NextcloudCollectionService {
  NextcloudCollectionService({
    required this.database,
    required this.secrets,
    required this.client,
    required this.accountId,
    required this.requireNetwork,
    required this.refresh,
  });
  final AppDatabase database;
  final SecretStore secrets;
  final http.Client client;
  final String accountId;
  final Future<void> Function() requireNetwork;
  final Future<void> Function() refresh;

  Future<NextcloudDavContext> openContext() => NextcloudDavContext.open(
    database: database,
    secrets: secrets,
    client: client,
    accountId: accountId,
    requireNetwork: requireNetwork,
  );

  Future<DavCollection> requiredCollection(String id) async {
    final row =
        await (database.select(database.davCollections)..where(
              (r) =>
                  r.id.equals(id) &
                  r.accountId.equals(accountId) &
                  r.deleted.equals(false) &
                  r.serverMissing.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) throw nextcloudOperationError(404, 'DavCollectionRemoved');
    return row;
  }

  Future<NextcloudCollectionState> load(
    String id, {
    NextcloudDavContext? context,
  }) async {
    final current = context ?? await openContext();
    final row = await requiredCollection(id);
    final target = current.resolve(row.requestUri, current.authority);
    final response = await current.propfind(
      target,
      nextcloudCollectionProperties,
    );
    final entry = response.responses
        .where((r) => current.resolve(r.href, target).path == target.path)
        .firstOrNull;
    if (entry == null || (entry.statusCode ?? 200) >= 400) {
      throw nextcloudOperationError(
        entry?.statusCode ?? 502,
        'DavCollectionReadFailed',
      );
    }
    final properties = {
      for (final stat in entry.propstats.where((s) => s.isSuccessful))
        for (final p in stat.properties) p.name: p,
    };
    final privileges = nextcloudPropertyNames(
      properties[const DavPropertyName(
        davNamespace,
        'current-user-privilege-set',
      )],
    );
    final metadata = jsonDecode(row.safeDisplayMetadataJson ?? '{}') as Map;
    final principal =
        metadata['principalHref'] as String? ?? current.service.principalHref;
    final owner =
        nextcloudPropertyHref(
          properties[const DavPropertyName(davNamespace, 'owner')],
        ) ??
        row.ownerHref;
    bool samePrincipal(String? left, String? right) =>
        left != null &&
        right != null &&
        Uri.parse(left).path.replaceFirst(RegExp(r'/+$'), '') ==
            Uri.parse(right).path.replaceFirst(RegExp(r'/+$'), '');
    final types = nextcloudPropertyNames(
      properties[const DavPropertyName(davNamespace, 'resourcetype')],
    );
    final shared =
        owner != null && principal != null && !samePrincipal(owner, principal);
    final role = types.contains('{http://calendarserver.org/ns/}subscribed')
        ? NextcloudCollectionRole.subscription
        : types.contains('{http://nextcloud.com/ns}deleted-calendar')
        ? NextcloudCollectionRole.deleted
        : shared
        ? NextcloudCollectionRole.shared
        : metadata['delegated'] == true
        ? NextcloudCollectionRole.delegated
        : NextcloudCollectionRole.owned;
    final home =
        metadata['calendarHomeHref'] as String? ??
        current.service.calendarHomeHref;
    var canRemove = false;
    if (home != null && role != NextcloudCollectionRole.deleted) {
      final homeUri = current.resolve(home, current.authority);
      // The parent is discovered, and must actually own this child target.
      if (target.path.startsWith(davCollectionUri(homeUri).path)) {
        try {
          final parent = await current.propfind(
            homeUri,
            '<d:current-user-privilege-set/>',
          );
          final parentEntry = parent.responses
              .where(
                (r) => current.resolve(r.href, homeUri).path == homeUri.path,
              )
              .firstOrNull;
          canRemove = davPrivilege(
            nextcloudPropertyNames(
              parentEntry?.successfulProperty(
                davNamespace,
                'current-user-privilege-set',
              ),
            ),
            'unbind',
          );
        } on DavException catch (error) {
          // A reader may manage this collection's metadata without being
          // allowed to inspect its parent. Fail closed only for removal.
          if (error.kind != DavErrorKind.authorization) rethrow;
        }
      }
    }
    return NextcloudCollectionState(
      collection: row,
      properties: Map.unmodifiable(properties),
      privileges: Set.unmodifiable(privileges),
      role: role,
      canRemove: canRemove,
    );
  }

  Future<NextcloudMutationOutcome> update(
    String id,
    Map<DavPropertyName, String> changes,
  ) async {
    if (changes.isEmpty) return NextcloudMutationOutcome.committed;
    _validateChanges(changes);
    final context = await openContext();
    final state = await load(id, context: context);
    if (!state.canWriteMetadata) {
      throw nextcloudOperationError(403, 'DavWritePropertiesDenied');
    }
    final target = Uri.parse(state.collection.requestUri);
    final xml =
        '<d:propertyupdate $nextcloudXmlNamespaces><d:set><d:prop>${changes.entries.map((e) => _propertyXml(e.key, e.value)).join()}</d:prop></d:set></d:propertyupdate>';
    try {
      final response = await context.send('PROPPATCH', target, xml: xml);
      _requirePropertySuccess(response, changes.keys.toSet(), context, target);
    } on DavException catch (error) {
      if (!_uncertain(error)) rethrow;
      try {
        final actual = await load(id, context: context);
        if (!changes.entries.every(
          (e) => _matchesProperty(actual, e.key, e.value),
        )) {
          throw nextcloudOperationError(409, 'DavCollectionOutcomeUnknown');
        }
      } on Object {
        throw nextcloudOperationError(409, 'DavCollectionOutcomeUnknown');
      }
    }
    return refreshResult();
  }

  Future<NextcloudMutationOutcome> remove(String id) async {
    final context = await openContext();
    final state = await load(id, context: context);
    if (!state.canRemove) {
      throw nextcloudOperationError(403, 'DavCollectionRemovalDenied');
    }
    // Never discard unsynchronized work through collection administration.
    final pending =
        await (database.select(database.pendingOps)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  (r.davCollectionId.equals(id) |
                      r.destinationCollectionId.equals(id)),
            ))
            .get();
    if (pending.isNotEmpty) {
      throw nextcloudOperationError(409, 'DavCollectionHasPendingChanges');
    }
    final target = Uri.parse(state.collection.requestUri);
    try {
      final response = await context.send('DELETE', target);
      if (response.statusCode != 404 &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
        throw nextcloudOperationError(
          response.statusCode,
          'DavCollectionRemovalFailed',
        );
      }
    } on DavException catch (error) {
      if (!_uncertain(error)) rethrow;
      final probe = await context.send(
        'PROPFIND',
        target,
        xml:
            '<d:propfind $nextcloudXmlNamespaces><d:prop><d:resourcetype/></d:prop></d:propfind>',
        headers: {'depth': '0'},
      );
      if (probe.statusCode != 404 && probe.statusCode != 410) {
        throw nextcloudOperationError(409, 'DavCollectionOutcomeUnknown');
      }
    }
    return refreshResult();
  }

  Future<NextcloudMutationOutcome> refreshResult() async {
    try {
      await refresh();
      return NextcloudMutationOutcome.committed;
    } on Object {
      return NextcloudMutationOutcome.refreshPending;
    }
  }
}

const nextcloudCollectionProperties =
    '<d:resourcetype/><d:displayname/><d:owner/><d:current-user-privilege-set/><c:supported-calendar-component-set/><a:calendar-color/><a:calendar-order/><c:calendar-description/><c:calendar-timezone/><c:schedule-calendar-transp/><oc:calendar-enabled/><oc:invite/><cs:allowed-sharing-modes/><cs:publish-url/>';

final nextcloudWritableProperties = <DavPropertyName>{
  DavPropertyName(davNamespace, 'displayname'),
  DavPropertyName(appleIcalNamespace, 'calendar-color'),
  DavPropertyName(appleIcalNamespace, 'calendar-order'),
  DavPropertyName(caldavNamespace, 'calendar-description'),
  DavPropertyName(caldavNamespace, 'calendar-timezone'),
  DavPropertyName(caldavNamespace, 'schedule-calendar-transp'),
  DavPropertyName(owncloudNamespace, 'calendar-enabled'),
};

void _validateChanges(Map<DavPropertyName, String> changes) {
  for (final entry in changes.entries) {
    if (!nextcloudWritableProperties.contains(entry.key) ||
        entry.value.length > 65536) {
      throw ArgumentError('Unsupported collection property');
    }
    final value = entry.value;
    switch (entry.key.localName) {
      case 'displayname':
        if (value.trim().isEmpty) throw ArgumentError('Empty collection name');
      case 'calendar-color':
        if (!RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value)) {
          throw ArgumentError('Invalid collection color');
        }
      case 'calendar-order':
        if (int.tryParse(value) == null) {
          throw ArgumentError('Invalid collection order');
        }
      case 'calendar-enabled':
        if (value != '0' && value != '1') {
          throw ArgumentError('Invalid enabled state');
        }
      case 'schedule-calendar-transp':
        if (value != 'opaque' && value != 'transparent') {
          throw ArgumentError('Invalid transparency');
        }
      case 'calendar-timezone':
        if (value.isNotEmpty) {
          final document = IcalDocument.parse(value);
          if (document.root.name != 'VCALENDAR' ||
              document.root.components.isEmpty ||
              document.root.components.any((c) => c.name != 'VTIMEZONE')) {
            throw ArgumentError('Invalid calendar timezone document');
          }
        }
    }
  }
}

String _propertyXml(DavPropertyName name, String value) {
  final prefix = switch (name.namespaceUri) {
    davNamespace => 'd',
    appleIcalNamespace => 'a',
    caldavNamespace => 'c',
    owncloudNamespace => 'oc',
    _ => throw ArgumentError('Unknown property'),
  };
  final body = name.localName == 'schedule-calendar-transp'
      ? '<c:$value/>'
      : escapeDavXmlText(value);
  return '<$prefix:${name.localName}>$body</$prefix:${name.localName}>';
}

bool _matchesProperty(
  NextcloudCollectionState state,
  DavPropertyName name,
  String value,
) => name.localName == 'schedule-calendar-transp'
    ? nextcloudPropertyNames(
        state.properties[name],
      ).contains('{$caldavNamespace}$value')
    : state.properties[name]?.text.trim() == value.trim();
bool _uncertain(DavException error) => const {
  DavErrorKind.timeout,
  DavErrorKind.network,
  DavErrorKind.server,
}.contains(error.kind);

void _requirePropertySuccess(
  DavResponse response,
  Set<DavPropertyName> requested,
  NextcloudDavContext context,
  Uri target,
) {
  if (response.statusCode != 207) {
    throw nextcloudOperationError(
      response.statusCode,
      'DavPropertyUpdateFailed',
    );
  }
  final data = const DavXmlParser().parseMultistatus(response.bodyBytes);
  final succeeded = <DavPropertyName>{};
  for (final item in data.responses) {
    if (context.resolve(item.href, target).path != target.path) continue;
    if ((item.statusCode ?? 200) >= 400) {
      throw nextcloudOperationError(
        item.statusCode!,
        'DavPropertyUpdateFailed',
      );
    }
    for (final stat in item.propstats) {
      if (stat.properties.any((p) => requested.contains(p.name)) &&
          !stat.isSuccessful) {
        throw nextcloudOperationError(
          stat.statusCode,
          'DavPropertyUpdateFailed',
        );
      }
      if (stat.isSuccessful) {
        succeeded.addAll(stat.properties.map((p) => p.name));
      }
    }
  }
  if (!succeeded.containsAll(requested)) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'DavPropertyUpdateIncomplete',
      safeMessage: 'The server did not report every requested property result.',
      statusCode: 207,
    );
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';

import '../dav_errors.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';

/// A handle returned by the owning account, never an arbitrary remote URL.
final class NextcloudFederationInvitation {
  const NextcloudFederationInvitation._({
    required this.accountId,
    required this.authority,
    required this.id,
    required this.displayName,
    required this.sharedBy,
    required this.sharedByDisplayName,
    required this.remoteUrl,
    required this.permissions,
    required this.components,
    required this.authorizationGeneration,
  });
  final String accountId;
  final Uri authority;
  final int id;
  final String displayName, sharedBy, sharedByDisplayName, remoteUrl;
  final int permissions;
  final String components;
  final int authorizationGeneration;
}

/// Nextcloud's DAV OCS API, separate from both DAV sharing and Files sharing.
/// Only these installation-local routes can be requested. Invitation metadata
/// (especially remoteUrl) is display/identity data, never a credential target.
final class NextcloudFederationService {
  NextcloudFederationService(this.collections);
  final NextcloudCollectionService collections;

  Future<List<NextcloudFederationInvitation>> pending({
    bool refreshDiscovery = true,
  }) async {
    final context = refreshDiscovery
        ? await collections.openContext()
        : await NextcloudDavContext.open(
            database: collections.database,
            secrets: collections.secrets,
            client: collections.client,
            accountId: collections.accountId,
            requireNetwork: collections.requireNetwork,
          );
    final data = await _request(context, 'GET');
    if (data is! List || data.length > 1000) {
      throw nextcloudOperationError(502, 'NextcloudFederationResponseInvalid');
    }
    final ids = <int>{};
    final invitations = List<NextcloudFederationInvitation>.unmodifiable(
      data.map((value) {
        if (value is! Map ||
            value['id'] is! int ||
            (value['id'] as int) <= 0 ||
            !ids.add(value['id'] as int) ||
            value['permissions'] is! int ||
            [
              'displayName',
              'sharedBy',
              'sharedByDisplayName',
              'remoteUrl',
              'components',
            ].any(
              (key) =>
                  value[key] is! String || (value[key] as String).length > 4096,
            )) {
          throw nextcloudOperationError(
            502,
            'NextcloudFederationResponseInvalid',
          );
        }
        return NextcloudFederationInvitation._(
          accountId: context.accountId,
          authority: context.authority,
          id: value['id'] as int,
          displayName: value['displayName'] as String,
          sharedBy: value['sharedBy'] as String,
          sharedByDisplayName: value['sharedByDisplayName'] as String,
          remoteUrl: value['remoteUrl'] as String,
          permissions: value['permissions'] as int,
          components: value['components'] as String,
          authorizationGeneration: context.authorizationGeneration,
        );
      }),
    );
    await _storeCount(context, invitations.length);
    return invitations;
  }

  /// Called only by the existing account refresh; never schedules a wakeup.
  Future<void> discoverPending({bool force = false}) async {
    final db = collections.database;
    final account = await (db.select(
      db.accounts,
    )..where((r) => r.id.equals(collections.accountId))).getSingleOrNull();
    final metadata = federationSummary(account?.providerMetadataJson);
    final checked = DateTime.tryParse('${metadata['checkedAt']}');
    final generation =
        await (db.select(db.authorizationGenerations)
              ..where((r) => r.accountId.equals(collections.accountId)))
            .getSingleOrNull();
    if (!force &&
        metadata['generation'] == (generation?.generation ?? 0) &&
        checked != null &&
        DateTime.now().toUtc().difference(checked) <
            const Duration(minutes: 15)) {
      return;
    }
    // Do not recursively start account synchronization when discovery is stale.
    await pending(refreshDiscovery: false);
  }

  Future<void> _storeCount(NextcloudDavContext context, int count) async {
    final db = collections.database;
    await db.transaction(() async {
      final account = await (db.select(
        db.accounts,
      )..where((r) => r.id.equals(context.accountId))).getSingleOrNull();
      final generation = await (db.select(
        db.authorizationGenerations,
      )..where((r) => r.accountId.equals(context.accountId))).getSingleOrNull();
      if (account == null ||
          account.provider != 'nextcloud' ||
          account.authority != context.authority.toString() ||
          (generation?.generation ?? 0) != context.authorizationGeneration) {
        return;
      }
      final metadata = account.providerMetadataJson == null
          ? <String, Object?>{}
          : (jsonDecode(account.providerMetadataJson!) as Map)
                .cast<String, Object?>();
      metadata['federation'] = {
        'count': count,
        'generation': context.authorizationGeneration,
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await (db.update(
        db.accounts,
      )..where((r) => r.id.equals(context.accountId))).write(
        AccountsCompanion(providerMetadataJson: Value(jsonEncode(metadata))),
      );
    });
  }

  Future<NextcloudMutationOutcome> accept(
    NextcloudFederationInvitation invitation,
  ) => _respond(invitation, accept: true);
  Future<NextcloudMutationOutcome> decline(
    NextcloudFederationInvitation invitation,
  ) => _respond(invitation, accept: false);

  Future<NextcloudMutationOutcome> _respond(
    NextcloudFederationInvitation invitation, {
    required bool accept,
  }) async {
    if (invitation.accountId != collections.accountId) {
      throw nextcloudOperationError(403, 'NextcloudFederationIdentityChanged');
    }
    final current = (await pending())
        .where((i) => i.id == invitation.id)
        .firstOrNull;
    if (current == null) {
      throw nextcloudOperationError(
        410,
        'NextcloudFederationInvitationExpired',
      );
    }
    if (current.authority != invitation.authority ||
        current.authorizationGeneration != invitation.authorizationGeneration ||
        current.remoteUrl != invitation.remoteUrl ||
        current.sharedBy != invitation.sharedBy ||
        current.permissions != invitation.permissions ||
        current.components != invitation.components) {
      throw nextcloudOperationError(
        412,
        'NextcloudFederationInvitationChanged',
      );
    }
    final context = await collections.openContext();
    if (context.authority != current.authority ||
        context.authorizationGeneration != current.authorizationGeneration) {
      throw nextcloudOperationError(412, 'NextcloudFederationIdentityChanged');
    }
    await _request(context, accept ? 'POST' : 'DELETE', id: current.id);
    // Acceptance commits a server-side action. A failed DAV refresh must not
    // offer to send that action again or imply that the cache is ready yet.
    return collections.refreshResult();
  }

  Future<Object?> _request(
    NextcloudDavContext context,
    String method, {
    int? id,
  }) async {
    final base = context.authority.path.replaceFirst(RegExp(r'/+$'), '');
    final uri = context.authority.replace(
      path:
          '$base/ocs/v2.php/apps/dav/api/v1/federated_calendars/pending${id == null ? '' : '/$id'}',
      query: 'format=json',
      fragment: null,
    );
    final response = await context.send(
      method,
      uri,
      headers: const {'OCS-APIRequest': 'true', 'accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw nextcloudOperationError(
        response.statusCode,
        'NextcloudFederationRequestFailed',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.bodyText);
    } on FormatException {
      /* fail closed below */
    }
    final ocs = decoded is Map ? decoded['ocs'] : null;
    final meta = ocs is Map ? ocs['meta'] : null;
    final status = meta is Map ? int.tryParse('${meta['statuscode']}') : null;
    if (meta is! Map || status == null || meta['status'] is! String) {
      throw DavException(
        kind: method == 'GET'
            ? DavErrorKind.protocol
            : DavErrorKind.unknownOutcome,
        code: 'NextcloudFederationResponseInvalid',
        safeMessage: 'The federation response could not be confirmed. Refresh before retrying.',
      );
    }
    if (meta['status'] != 'ok' || !{100, 200}.contains(status)) {
      throw nextcloudOperationError(
        status >= 400 && status < 600 ? status : 502,
        'NextcloudFederationRequestRejected',
      );
    }
    return (ocs as Map)['data'];
  }
}

/// Only a count and freshness marker are retained; remote details stay in the
/// explicitly opened invitation screen. No system notification is generated.
Map<String, Object?> federationSummary(String? raw) {
  try {
    final data = jsonDecode(raw ?? '{}');
    final summary = data is Map ? data['federation'] : null;
    return summary is Map ? summary.cast<String, Object?>() : const {};
  } on FormatException {
    return const {};
  }
}

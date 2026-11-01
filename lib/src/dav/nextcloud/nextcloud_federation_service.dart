import 'dart:convert';

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

  Future<List<NextcloudFederationInvitation>> pending() async {
    final context = await collections.openContext();
    final data = await _request(context, 'GET');
    if (data is! List || data.length > 1000) {
      throw nextcloudOperationError(502, 'NextcloudFederationResponseInvalid');
    }
    final ids = <int>{};
    return List.unmodifiable(
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

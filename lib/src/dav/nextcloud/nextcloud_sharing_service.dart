import 'package:xml/xml.dart';

import '../dav_errors.dart';
import '../mutation/dav_collection_mutation_helpers.dart';
import '../xml/dav_xml.dart';
import 'nextcloud_collection_service.dart';
import 'nextcloud_dav_context.dart';

final class NextcloudShareRecipient {
  const NextcloudShareRecipient._({
    required this.href,
    required this.label,
    required this.group,
  });
  final String href;
  final String label;
  final bool group;
}

final class NextcloudCollectionShare {
  const NextcloudCollectionShare({
    required this.recipient,
    required this.writable,
    required this.status,
  });
  final NextcloudShareRecipient recipient;
  final bool writable;
  final String status;
}

final class NextcloudSharingState {
  const NextcloudSharingState({
    required this.collection,
    required this.shares,
    required this.canShare,
    required this.canPublish,
    required this.publishUrl,
  });
  final NextcloudCollectionState collection;
  final List<NextcloudCollectionShare> shares;
  final bool canShare;
  final bool canPublish;
  final Uri? publishUrl;
}

/// DAV resource sharing, never the OCS Files sharing API. Recipients can only
/// originate in a successful server principal search or current-share read.
final class NextcloudSharingService {
  NextcloudSharingService(this.collections);
  final NextcloudCollectionService collections;
  final _knownRecipients = <String>{};

  Future<NextcloudSharingState> load(
    String id, {
    NextcloudDavContext? context,
  }) async {
    final current = context ?? await collections.openContext();
    final state = await collections.load(id, context: current);
    final modes = nextcloudPropertyNames(
      state.property(calendarServerNamespace, 'allowed-sharing-modes'),
    );
    final shares = <NextcloudCollectionShare>[];
    final invite = state.property(owncloudNamespace, 'invite');
    for (final user in invite?.element.childElements ?? const <XmlElement>[]) {
      final href = user.descendantElements
          .where(
            (e) =>
                e.name.namespaceUri == davNamespace && e.name.local == 'href',
          )
          .firstOrNull
          ?.innerText
          .trim();
      if (href == null || href.isEmpty || href.length > 4096) continue;
      final name = user.descendantElements
          .where((e) => e.name.local == 'common-name')
          .firstOrNull
          ?.innerText
          .trim();
      final group = user.descendantElements.any(
        (e) =>
            e.name.namespaceUri == owncloudNamespace &&
            e.name.local == 'group-share',
      );
      final writable = user.descendantElements.any(
        (e) =>
            e.name.namespaceUri == owncloudNamespace &&
            e.name.local == 'read-write',
      );
      final status =
          user.descendantElements
              .where((e) => e.name.local.startsWith('invite-'))
              .firstOrNull
              ?.name
              .local ??
          '';
      _knownRecipients.add(href);
      shares.add(
        NextcloudCollectionShare(
          recipient: NextcloudShareRecipient._(
            href: href,
            label: name?.isNotEmpty == true ? name! : href,
            group: group,
          ),
          writable: writable,
          status: status,
        ),
      );
    }
    Uri? publishUrl;
    final href = nextcloudPropertyHref(
      state.property(calendarServerNamespace, 'publish-url'),
    );
    if (href != null) {
      final uri = Uri.tryParse(href);
      if (uri != null &&
          const {'http', 'https', 'webcal'}.contains(uri.scheme) &&
          uri.userInfo.isEmpty)
        publishUrl = uri;
    }
    final canAdminister =
        state.role != NextcloudCollectionRole.shared &&
        state.role != NextcloudCollectionRole.subscription &&
        state.role != NextcloudCollectionRole.deleted;
    return NextcloudSharingState(
      collection: state,
      shares: List.unmodifiable(shares),
      canShare:
          canAdminister &&
          modes.contains('{$calendarServerNamespace}can-be-shared'),
      canPublish:
          canAdminister &&
          state.collection.supportedComponentMask & 1 != 0 &&
          modes.contains('{$calendarServerNamespace}can-be-published'),
      publishUrl: publishUrl,
    );
  }

  Future<List<NextcloudShareRecipient>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    if (text.length > 256) throw ArgumentError('Principal search is too long');
    final context = await collections.openContext();
    final root = context.resolve(
      context.service.canonicalServiceUri,
      context.authority,
    );
    final advertised = await context.propfind(
      root,
      '<d:principal-collection-set/>',
    );
    final targets = <Uri>{};
    for (final response in advertised.responses) {
      final property = response.successfulProperty(
        davNamespace,
        'principal-collection-set',
      );
      for (final element
          in property?.element.descendantElements ?? const <XmlElement>[]) {
        if (element.name.namespaceUri == davNamespace &&
            element.name.local == 'href')
          targets.add(context.resolve(element.innerText.trim(), root));
      }
    }
    if (targets.isEmpty || targets.length > 16)
      throw nextcloudOperationError(403, 'DavPrincipalSearchUnavailable');
    final found = <String, NextcloudShareRecipient>{};
    for (final target in targets) {
      final response = await context.send(
        'REPORT',
        target,
        headers: {'depth': '0'},
        xml:
            '<d:principal-property-search $nextcloudXmlNamespaces><d:property-search><d:prop><d:displayname/></d:prop><d:match>${escapeDavXmlText(text)}</d:match></d:property-search><d:prop><d:displayname/><d:principal-URL/><c:calendar-user-type/></d:prop></d:principal-property-search>',
      );
      if (response.statusCode != 207)
        throw nextcloudOperationError(
          response.statusCode,
          'DavPrincipalSearchDenied',
        );
      final result = const DavXmlParser().parseMultistatus(response.bodyBytes);
      if (result.errorConditions.isNotEmpty)
        throw nextcloudOperationError(502, 'DavPrincipalSearchIncomplete');
      for (final entry in result.responses) {
        if ((entry.statusCode ?? 200) >= 400) continue;
        final href =
            nextcloudPropertyHref(
              entry.successfulProperty(davNamespace, 'principal-URL'),
            ) ??
            entry.href;
        final uri = context.resolve(href, response.requestUri);
        final base = davCollectionUri(root).path;
        if (!uri.path.startsWith(base)) continue;
        final relative = uri.path
            .substring(base.length)
            .replaceFirst(RegExp(r'/+$'), '');
        // Derive the scheme from the returned principal path, not a user name.
        if (!relative.startsWith('principals/users/') &&
            !relative.startsWith('principals/groups/'))
          continue;
        final scheme = 'principal:$relative';
        final label = entry
            .successfulProperty(davNamespace, 'displayname')
            ?.text
            .trim();
        found[scheme] = NextcloudShareRecipient._(
          href: scheme,
          label: label?.isNotEmpty == true ? label! : scheme,
          group:
              entry
                      .successfulProperty(caldavNamespace, 'calendar-user-type')
                      ?.text
                      .trim() ==
                  'GROUP' ||
              relative.startsWith('principals/groups/'),
        );
        _knownRecipients.add(scheme);
        if (found.length >= 20) return List.unmodifiable(found.values);
      }
    }
    return List.unmodifiable(found.values);
  }

  Future<NextcloudMutationOutcome> changeShare(
    String id,
    NextcloudShareRecipient recipient, {
    required bool? writable,
  }) async {
    if (!_knownRecipients.contains(recipient.href))
      throw nextcloudOperationError(403, 'DavPrincipalNotResolved');
    final context = await collections.openContext();
    final state = await load(id, context: context);
    if (!state.canShare) throw nextcloudOperationError(403, 'DavSharingDenied');
    final action = writable == null ? 'remove' : 'set';
    final xml =
        '<oc:share $nextcloudXmlNamespaces><oc:$action><d:href>${escapeDavXmlText(recipient.href)}</d:href>${writable == true ? '<oc:read-write/>' : ''}</oc:$action></oc:share>';
    try {
      final response = await context.send(
        'POST',
        Uri.parse(state.collection.collection.requestUri),
        xml: xml,
      );
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw nextcloudOperationError(response.statusCode, 'DavSharingFailed');
    } on DavException catch (error) {
      if (!{
        DavErrorKind.network,
        DavErrorKind.timeout,
        DavErrorKind.server,
      }.contains(error.kind))
        rethrow;
      final refreshed = await load(id, context: context);
      final actual = refreshed.shares
          .where((s) => s.recipient.href == recipient.href)
          .firstOrNull;
      if (writable == null ? actual != null : actual?.writable != writable)
        throw nextcloudOperationError(409, 'DavCollectionOutcomeUnknown');
    }
    try {
      await load(id, context: context);
    } on Object {
      return NextcloudMutationOutcome.refreshPending;
    }
    return collections.refreshResult();
  }

  Future<NextcloudMutationOutcome> setPublished(
    String id,
    bool published,
  ) async {
    final context = await collections.openContext();
    final state = await load(id, context: context);
    if (!state.canPublish)
      throw nextcloudOperationError(403, 'DavPublishingDenied');
    if ((state.publishUrl != null) == published)
      return NextcloudMutationOutcome.committed;
    final action = published ? 'publish-calendar' : 'unpublish-calendar';
    try {
      final response = await context.send(
        'POST',
        Uri.parse(state.collection.collection.requestUri),
        xml: '<cs:$action $nextcloudXmlNamespaces/>',
      );
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw nextcloudOperationError(
          response.statusCode,
          'DavPublishingFailed',
        );
    } on DavException catch (error) {
      if (!{
        DavErrorKind.network,
        DavErrorKind.timeout,
        DavErrorKind.server,
      }.contains(error.kind))
        rethrow;
      final refreshed = await load(id, context: context);
      if ((refreshed.publishUrl != null) != published)
        throw nextcloudOperationError(409, 'DavCollectionOutcomeUnknown');
    }
    try {
      final refreshed = await load(id, context: context);
      if ((refreshed.publishUrl != null) != published)
        return NextcloudMutationOutcome.refreshPending;
    } on Object {
      return NextcloudMutationOutcome.refreshPending;
    }
    return collections.refreshResult();
  }
}

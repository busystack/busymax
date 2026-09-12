import 'dart:convert';

import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../dav_href.dart';
import '../dav_provider_profile.dart';
import '../discovery/dav_discovery_models.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';

/// Shared context for Nextcloud DAV administration. Authentication, redirect
/// checks, limits and diagnostics remain owned by the existing DAV transport.
final class NextcloudDavContext {
  NextcloudDavContext._(
    this.accountId,
    this.authority,
    this.profile,
    this.transport,
    this.credential,
    this.service,
    this.features,
    this.principals,
  );
  final String accountId;
  final Uri authority;
  final DavProviderProfile profile;
  final DavHttpTransport transport;
  final DavBasicCredential credential;
  final DavAccountService service;
  final Set<String> features;
  final List<DavPrincipalContext> principals;

  static Future<NextcloudDavContext> open({
    required AppDatabase database,
    required SecretStore secrets,
    required http.Client client,
    required String accountId,
    required Future<void> Function() requireNetwork,
  }) async {
    await requireNetwork();
    final account = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(accountId))).getSingleOrNull();
    if (account == null || account.provider != 'nextcloud') {
      throw nextcloudOperationError(404, 'NextcloudAccountUnavailable');
    }
    final secret = await secrets.readCredential(accountId);
    final authority = Uri.tryParse(account.authority);
    if (secret is! NextcloudSecretRecord ||
        secret.canonicalServer != authority ||
        secret.loginName != account.providerAccountId) {
      throw nextcloudOperationError(401, 'DavCredentialsRevoked');
    }
    final service = await (database.select(
      database.davAccountServices,
    )..where((r) => r.accountId.equals(accountId))).getSingleOrNull();
    if (service == null) {
      throw nextcloudOperationError(409, 'DavDiscoveryRequired');
    }
    final profile = davProviderProfile(
      BusyProvider.nextcloud,
      nextcloudServer: authority,
    );
    final metadata = jsonDecode(service.capabilitiesJson) as Map;
    final features = (metadata['serverFeatures'] as List? ?? [])
        .whereType<String>()
        .toSet();
    final contexts = [
      for (final value in metadata['principalContexts'] as List? ?? [])
        if (value is Map)
          DavPrincipalContext.fromJson(value.cast<String, Object?>()),
    ];
    final transport = DavHttpTransport(
      client: client,
      profile: profile,
      accountAuthority: authority!,
    )..setServerFeatures(features);
    return NextcloudDavContext._(
      accountId,
      authority,
      profile,
      transport,
      DavBasicCredential(
        username: secret.loginName,
        password: secret.appPassword,
      ),
      service,
      features,
      List.unmodifiable(contexts),
    );
  }

  Uri resolve(String href, Uri responseUri) => resolveDavHref(
    href: href,
    responseRequestUri: responseUri,
    profile: profile,
    accountAuthority: authority,
  );

  Future<DavResponse> send(
    String method,
    Uri uri, {
    String? xml,
    Map<String, String> headers = const {},
  }) => transport.send(
    xml == null
        ? DavRequest(
            method: method,
            uri: uri,
            accountId: accountId,
            correlationId: const Uuid().v4(),
            headers: headers,
            retryClass: method == 'GET'
                ? DavRetryClass.safeRead
                : DavRetryClass.never,
          )
        : DavRequest.xml(
            method: method,
            uri: uri,
            accountId: accountId,
            correlationId: const Uuid().v4(),
            body: xml,
            headers: headers,
            retryClass: method == 'PROPFIND' || method == 'REPORT'
                ? DavRetryClass.safeRead
                : DavRetryClass.never,
          ),
    credential: credential,
  );

  Future<DavMultistatus> propfind(
    Uri uri,
    String properties, {
    String depth = '0',
  }) async {
    final response = await send(
      'PROPFIND',
      uri,
      xml:
          '<d:propfind $nextcloudXmlNamespaces><d:prop>$properties</d:prop></d:propfind>',
      headers: {'depth': depth},
    );
    if (response.statusCode != 207) {
      throw nextcloudOperationError(
        response.statusCode,
        'DavCollectionReadFailed',
      );
    }
    return const DavXmlParser().parseMultistatus(response.bodyBytes);
  }
}

const nextcloudXmlNamespaces =
    'xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.com/ns" xmlns:a="http://apple.com/ns/ical/"';

DavException nextcloudOperationError(int status, String code) => DavException(
  kind: switch (status) {
    401 => DavErrorKind.authentication,
    403 => DavErrorKind.authorization,
    404 || 410 => DavErrorKind.notFound,
    409 || 412 => DavErrorKind.conflict,
    429 => DavErrorKind.rateLimited,
    >= 500 => DavErrorKind.server,
    _ => DavErrorKind.protocol,
  },
  code: code,
  statusCode: status,
  safeMessage: 'Nextcloud could not complete the requested operation.',
);

bool davPrivilege(
  Set<String> privileges,
  String localName, {
  String namespace = davNamespace,
}) =>
    privileges.contains('{DAV:}all') ||
    privileges.contains('{$namespace}$localName') ||
    (namespace == davNamespace &&
        const {
          'write-content',
          'write-properties',
          'bind',
          'unbind',
        }.contains(localName) &&
        privileges.contains('{DAV:}write'));

Set<String> nextcloudPropertyNames(DavProperty? property) => {
  for (final element
      in property?.element.descendantElements ?? const <XmlElement>[])
    '{${element.name.namespaceUri}}${element.name.local}',
};

String? nextcloudPropertyHref(DavProperty? property) => property
    ?.element
    .descendantElements
    .where((e) => e.name.namespaceUri == davNamespace && e.name.local == 'href')
    .firstOrNull
    ?.innerText
    .trim();

enum NextcloudMutationOutcome { committed, refreshPending }

final class NextcloudRefreshPending implements Exception {
  const NextcloudRefreshPending();
  @override
  String toString() => 'Nextcloud change committed; refresh pending';
}

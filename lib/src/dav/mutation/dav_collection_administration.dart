import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../dav_href.dart';
import '../dav_provider_profile.dart';
import '../http/dav_account_http_client.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';
import 'dav_collection_mutation_helpers.dart';

enum DavCollectionAdministrationOutcome {
  committed,
  refreshPending,
  reconciled,
  reconciledRefreshPending,
}

/// Standards-based collection mutations through BusyMax's existing bounded,
/// credential-scoped DAV transport. Nextcloud extensions remain in their service.
final class DavCollectionAdministration {
  DavCollectionAdministration({
    required this.database,
    required this.secrets,
    required this.client,
    required this.accountId,
    required this.refresh,
    required this.requireNetwork,
    String Function()? creationIdFactory,
  }) : _creationIdFactory = creationIdFactory ?? const Uuid().v4;
  final AppDatabase database;
  final SecretStore secrets;
  final http.Client client;
  final String accountId;
  final Future<void> Function() refresh;
  final Future<void> Function() requireNetwork;
  final String Function() _creationIdFactory;
  static final _activeCreations =
      <String, Future<DavCollectionAdministrationOutcome>>{};
  static bool creationIsActive(String accountId, String operationId) =>
      _activeCreations.containsKey('$accountId/$operationId');

  Future<_Context> _open() async {
    await requireNetwork();
    final account = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(accountId))).getSingleOrNull();
    final secret = await secrets.readCredential(accountId);
    if (account == null ||
        account.provider != 'caldav' ||
        secret is! CalDavSecretRecord ||
        secret.serviceAuthority.toString() != account.authority ||
        secret.username != account.providerAccountId) {
      throw _error(401, 'DavCredentialsRevoked');
    }
    final service = await (database.select(
      database.davAccountServices,
    )..where((r) => r.accountId.equals(accountId))).getSingleOrNull();
    if (service == null ||
        service.calendarHomeHref == null ||
        service.lastDiscoveryErrorCode != null) {
      throw _error(409, 'DavDiscoveryRequired');
    }
    final generation = await (database.select(
      database.authorizationGenerations,
    )..where((r) => r.accountId.equals(accountId))).getSingleOrNull();
    final profile = davProviderProfile(
      BusyProvider.caldav,
      caldavServer: secret.serviceAuthority,
    );
    final home = resolveDavHref(
      href: service.calendarHomeHref!,
      responseRequestUri: secret.serviceAuthority,
      profile: profile,
      accountAuthority: secret.serviceAuthority,
    );
    return _Context(
      secret.serviceAuthority,
      home,
      profile,
      DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: secret.serviceAuthority,
      ),
      DavBasicCredential(username: secret.username, password: secret.password),
      generation?.generation ?? 0,
    );
  }

  Future<DavResponse> _send(
    _Context c,
    String method,
    Uri target, {
    String? xml,
    Map<String, String> headers = const {},
    DavCancellationToken? cancellation,
  }) => c.transport.send(
    DavRequest(
      method: method,
      uri: target,
      accountId: accountId,
      correlationId: 'collection-$method',
      headers: {
        davAuthorizationGenerationHeader: '${c.generation}',
        if (xml != null) 'content-type': 'application/xml; charset=utf-8',
        ...headers,
      },
      bodyBytes: xml == null ? null : utf8.encode(xml),
      retryClass: method == 'PROPFIND' || method == 'OPTIONS'
          ? DavRetryClass.safeRead
          : DavRetryClass.never,
    ),
    credential: c.credential,
    cancellationToken: cancellation,
  );

  Future<DavMultistatusResponse?> _read(
    _Context c,
    Uri target, {
    DavCancellationToken? cancellation,
  }) async {
    final response = await _send(
      c,
      'PROPFIND',
      target,
      xml:
          '<d:propfind $_namespaces><d:prop>$_properties</d:prop></d:propfind>',
      headers: const {'depth': '0'},
      cancellation: cancellation,
    );
    if (response.statusCode == 404 || response.statusCode == 410) return null;
    if (response.statusCode != 207) {
      throw _error(response.statusCode, 'DavCollectionReadFailed');
    }
    final data = const DavXmlParser().parseMultistatus(response.bodyBytes);
    if (data.errorConditions.isNotEmpty) {
      throw _error(502, 'DavCollectionReadIncomplete');
    }
    final entries = data.responses
        .where(
          (r) =>
              resolveDavHref(
                href: r.href,
                responseRequestUri: target,
                profile: c.profile,
                accountAuthority: c.authority,
              ).path ==
              target.path,
        )
        .toList();
    if (entries.length != 1 ||
        (entries.single.statusCode ?? 200) >= 400 ||
        entries.single.successfulProperty(davNamespace, 'resourcetype') ==
            null) {
      throw _error(502, 'DavCollectionReadIncomplete');
    }
    return entries.single;
  }

  Future<Uri> _target(_Context c, String id) async {
    final row =
        await (database.select(database.davCollections)..where(
              (r) =>
                  r.id.equals(id) &
                  r.accountId.equals(accountId) &
                  r.deleted.equals(false) &
                  r.serverMissing.equals(false),
            ))
            .getSingleOrNull();
    if (row == null) throw _error(404, 'DavCollectionRemoved');
    final target = resolveDavHref(
      href: row.requestUri,
      responseRequestUri: c.home,
      profile: c.profile,
      accountAuthority: c.authority,
    );
    if (!target.path.startsWith(davCollectionUri(c.home).path) ||
        target.path == c.home.path) {
      throw _error(403, 'DavCollectionOutsideHome');
    }
    return target;
  }

  void _requirePrivilege(DavMultistatusResponse entry, String name) {
    final property = entry.successfulProperty(
      davNamespace,
      'current-user-privilege-set',
    );
    if (property == null) {
      return; // Unknown: the user-requested method is authoritative.
    }
    final names = property.element.descendantElements
        .where((e) => e.name.namespaceUri == davNamespace)
        .map((e) => e.name.local)
        .toSet();
    if (!names.contains('all') &&
        !names.contains('write') &&
        !names.contains(name)) {
      throw _error(403, 'DavPermissionDenied');
    }
  }

  Future<DavCollectionAdministrationOutcome> create(
    String title,
    Set<String> components, {
    DavCancellationToken? cancellation,
  }) async {
    if (title.trim().isEmpty ||
        title.length > 1024 ||
        components.isEmpty ||
        !const {'VEVENT', 'VTODO'}.containsAll(components)) {
      throw ArgumentError('Invalid collection');
    }
    final c = await _open();
    final pending =
        await (database.select(database.davCollectionCreations)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.displayName.equals(title.trim()) &
                  r.state.isIn(const ['prepared', 'dispatched']),
            ))
            .get();
    if (pending.isNotEmpty) throw _error(409, 'DavCollectionCreationPending');
    final existing =
        await (database.select(database.davCollections)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.displayName.equals(title.trim()) &
                  r.deleted.equals(false) &
                  r.serverMissing.equals(false),
            ))
            .get();
    if (existing.any(
      (r) =>
          components.contains('VEVENT') && r.eventProjectionEnabled ||
          components.contains('VTODO') && r.taskProjectionEnabled,
    )) {
      throw _error(409, 'DavCollectionNameConflict');
    }
    final id = _creationIdFactory();
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(id)) {
      throw ArgumentError('Invalid creation operation ID');
    }
    // Reserve an unpredictable operation-specific member. Persist both intent
    // and URL before dispatch: a title-derived URL is not operation identity.
    final target = davCollectionUri(c.home).resolve('busymax-$id/');
    final sortedComponents = components.toList()..sort();
    await database
        .into(database.davCollectionCreations)
        .insert(
          DavCollectionCreationsCompanion.insert(
            id: id,
            accountId: accountId,
            authority: c.authority.toString(),
            homeUri: c.home.toString(),
            targetUri: target.toString(),
            displayName: title.trim(),
            componentsJson: jsonEncode(sortedComponents),
            createdAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );
    return resumeCreation(id, cancellation: cancellation);
  }

  /// Only a persisted, account-bound operation ID authorizes recovery/retry.
  /// Used by normal account synchronization after interrupted foreground work.
  Future<DavCollectionAdministrationOutcome> resumeCreation(
    String operationId, {
    DavCancellationToken? cancellation,
  }) async {
    final key = '$accountId/$operationId';
    final active = _activeCreations[key];
    if (active != null) return active;
    final work = _resumeCreation(operationId, cancellation);
    _activeCreations[key] = work;
    try {
      return await work;
    } finally {
      if (identical(_activeCreations[key], work)) _activeCreations.remove(key);
    }
  }

  Future<DavCollectionAdministrationOutcome> _resumeCreation(
    String operationId,
    DavCancellationToken? cancellation,
  ) async {
    final operation =
        await (database.select(database.davCollectionCreations)..where(
              (r) => r.id.equals(operationId) & r.accountId.equals(accountId),
            ))
            .getSingleOrNull();
    if (operation == null) {
      throw _error(404, 'DavCollectionCreationUnavailable');
    }
    final c = await _open();
    if (operation.authority != c.authority.toString() ||
        operation.homeUri != c.home.toString() ||
        operation.targetUri !=
            davCollectionUri(c.home)
                .resolve('busymax-${operation.id}/')
                .toString()) {
      throw _error(409, 'DavCollectionCreationIdentityChanged');
    }
    final target = Uri.parse(operation.targetUri);
    final title = operation.displayName;
    final components = (jsonDecode(operation.componentsJson) as List)
        .cast<String>()
        .toSet();
    if (components.isEmpty ||
        !const {'VEVENT', 'VTODO'}.containsAll(components)) {
      throw _error(409, 'DavCollectionCreationInvalid');
    }
    if (operation.state == 'rejected') {
      throw _error(409, 'DavCollectionNameConflict');
    }
    if (operation.state == 'committed') {
      return _creationRefresh(reconciled: true);
    }
    final parent = await _read(c, c.home, cancellation: cancellation);
    if (parent == null) throw _error(404, 'DavCalendarHomeUnavailable');
    _requirePrivilege(parent, 'bind');
    final options = await _send(
      c,
      'OPTIONS',
      c.home,
      cancellation: cancellation,
    );
    if (options.statusCode < 200 || options.statusCode >= 300) {
      throw _error(options.statusCode, 'DavCollectionCapabilitiesUnavailable');
    }
    final methods = (options.headers['allow'] ?? '')
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .toSet();
    final features = (options.headers['dav'] ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .toSet();
    // MKCALENDAR is required by calendar-access (RFC 4791). Some conforming
    // implementations omit it from home Allow; no server-name inference.
    final method =
        methods.contains('MKCALENDAR') || features.contains('calendar-access')
        ? 'MKCALENDAR'
        : features.contains('extended-mkcol') && methods.contains('MKCOL')
        ? 'MKCOL'
        : null;
    if (method == null) throw _error(405, 'DavCollectionCreationUnsupported');
    bool matches(DavMultistatusResponse entry) {
      final componentProperty = entry.successfulProperty(
        caldavNamespace,
        'supported-calendar-component-set',
      );
      final actual = componentProperty?.element.descendantElements
          .where(
            (e) =>
                e.name.namespaceUri == caldavNamespace &&
                e.name.local == 'comp',
          )
          .map((e) => e.getAttribute('name'))
          .toSet();
      return entry.successfulProperty(davNamespace, 'displayname')?.text ==
              title.trim() &&
          (actual != null &&
              actual.length == components.length &&
              actual.containsAll(components)) &&
          entry
              .successfulProperty(davNamespace, 'resourcetype')!
              .element
              .descendantElements
              .any(
                (e) =>
                    e.name.namespaceUri == caldavNamespace &&
                    e.name.local == 'calendar',
              );
    }

    final existing = await _read(c, target, cancellation: cancellation);
    if (existing != null) {
      if (operation.state != 'dispatched' || !matches(existing)) {
        await _creationState(operationId, 'rejected');
        throw _error(409, 'DavCollectionNameConflict');
      }
      await _creationState(operationId, 'committed');
      return _creationRefresh(reconciled: true);
    }
    // The absence check above is mandatory before a retry of a dispatched
    // operation. MKCALENDAR/MKCOL are never blindly replayed by the transport.
    if (operation.state == 'prepared') {
      final claimed =
          await (database.update(database.davCollectionCreations)..where(
                (r) =>
                    r.id.equals(operationId) &
                    r.accountId.equals(accountId) &
                    r.state.equals('prepared'),
              ))
              .write(
                const DavCollectionCreationsCompanion(
                  state: Value('dispatched'),
                ),
              );
      if (claimed != 1) throw _error(409, 'DavCollectionCreationPending');
    }
    final tag = method == 'MKCOL' ? 'd:mkcol' : 'c:mkcalendar';
    // MKCALENDAR creates a calendar resource type itself. DAV:resourcetype is
    // protected there; only Extended MKCOL specifies it in the request body.
    final resourceType = method == 'MKCOL'
        ? '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>'
        : '';
    final xml =
        '<$tag $_namespaces><d:set><d:prop>$resourceType<d:displayname>${escapeDavXmlText(title.trim())}</d:displayname><c:supported-calendar-component-set>${components.map((v) => '<c:comp name="$v"/>').join()}</c:supported-calendar-component-set></d:prop></d:set></$tag>';
    try {
      final response = await _send(
        c,
        method,
        target,
        xml: xml,
        cancellation: cancellation,
      );
      if (response.statusCode != 201) {
        if (response.statusCode == 403 && response.bodyBytes.isNotEmpty) {
          Set<DavPropertyName> conditions;
          try {
            conditions = const DavXmlParser().parseDavError(response.bodyBytes);
          } on DavException {
            conditions = const {};
          }
          if (conditions.contains(
            const DavPropertyName(
              caldavNamespace,
              'supported-calendar-component',
            ),
          )) {
            await _creationState(operationId, 'rejected');
            throw const DavException(
              kind: DavErrorKind.unsupportedComponent,
              code: 'DavUnsupportedComponent',
              statusCode: 403,
              safeMessage: 'The server does not support the requested collection component set.',
            );
          }
        }
        // A definitive rejection is not evidence of an uncertain commit. In
        // particular a fresh request that loses a namespace race must never
        // adopt the conflicting collection on a subsequent recovery pass.
        if (const {
              400,
              405,
              409,
              412,
              415,
              422,
            }.contains(response.statusCode) &&
            operation.state == 'prepared') {
          await _creationState(operationId, 'rejected');
        } else if (const {401, 403}.contains(response.statusCode) &&
            operation.state == 'prepared') {
          await _creationState(operationId, 'prepared');
        }
        throw _error(response.statusCode, 'DavCollectionCreationFailed');
      }
    } on DavException catch (error) {
      final pendingNamespaceRace =
          operation.state == 'dispatched' &&
          const {405, 409, 412}.contains(error.statusCode);
      if (!_uncertain(error) && !pendingNamespaceRace) rethrow;
      final observed = await _read(c, target);
      if (observed == null || !matches(observed)) {
        throw DavException(
          kind: DavErrorKind.unknownOutcome,
          code: 'DavCollectionOutcomeUnknown',
          correlationId: operationId,
          safeMessage: 'The collection operation is pending reconciliation.',
        );
      }
      await _creationState(operationId, 'committed');
      return _creationRefresh(reconciled: true);
    }
    await _creationState(operationId, 'committed');
    return _creationRefresh(reconciled: false);
  }

  Future<void> _creationState(String id, String state) async {
    final updated =
        await (database.update(database.davCollectionCreations)
              ..where((r) => r.id.equals(id) & r.accountId.equals(accountId)))
            .write(DavCollectionCreationsCompanion(state: Value(state)));
    if (updated != 1) throw _error(404, 'DavAccountRemoved');
  }

  Future<DavCollectionAdministrationOutcome> _creationRefresh({
    required bool reconciled,
  }) async {
    final result = await _refresh();
    if (!reconciled) return result;
    return result == DavCollectionAdministrationOutcome.refreshPending
        ? DavCollectionAdministrationOutcome.reconciledRefreshPending
        : DavCollectionAdministrationOutcome.reconciled;
  }

  Future<DavCollectionAdministrationOutcome> update(
    String id,
    Map<DavPropertyName, String> changes,
  ) async {
    if (changes.isEmpty) return DavCollectionAdministrationOutcome.committed;
    for (final entry in changes.entries) {
      if (!_writable.contains(entry.key) ||
          entry.value.length > 65536 ||
          (entry.key.localName == 'displayname' &&
              entry.value.trim().isEmpty) ||
          (entry.key.localName == 'calendar-color' &&
              !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$')
                  .hasMatch(entry.value)) ||
          (entry.key.localName == 'calendar-order' &&
              int.tryParse(entry.value) == null)) {
        throw ArgumentError('Invalid collection property');
      }
    }
    final c = await _open();
    final target = await _target(c, id);
    final before = await _read(c, target);
    if (before == null) throw _error(404, 'DavCollectionRemoved');
    _requirePrivilege(before, 'write-properties');
    bool matches(DavMultistatusResponse? e) =>
        e != null &&
        changes.entries.every(
          (p) =>
              e
                  .successfulProperty(p.key.namespaceUri!, p.key.localName)
                  ?.text
                  .trim() ==
              p.value.trim(),
        );
    if (matches(before)) return _refresh();
    final xml =
        '<d:propertyupdate $_namespaces><d:set><d:prop>${changes.entries.map((e) => '<${_prefix(e.key.namespaceUri)}:${e.key.localName}>${escapeDavXmlText(e.value)}</${_prefix(e.key.namespaceUri)}:${e.key.localName}>').join()}</d:prop></d:set></d:propertyupdate>';
    try {
      final response = await _send(c, 'PROPPATCH', target, xml: xml);
      if (response.statusCode != 207) {
        throw _error(response.statusCode, 'DavPropertyUpdateFailed');
      }
      final data = const DavXmlParser().parseMultistatus(response.bodyBytes);
      final succeeded = <DavPropertyName>{};
      for (final entry in data.responses) {
        if (resolveDavHref(
                  href: entry.href,
                  responseRequestUri: target,
                  profile: c.profile,
                  accountAuthority: c.authority,
                ).path !=
                target.path ||
            (entry.statusCode ?? 200) >= 400) {
          throw _error(502, 'DavPropertyUpdateIncomplete');
        }
        for (final stat in entry.propstats) {
          if (!stat.isSuccessful &&
              stat.properties.any((p) => changes.containsKey(p.name))) {
            throw _error(stat.statusCode, 'DavPropertyUpdateFailed');
          }
          if (stat.isSuccessful) {
            succeeded.addAll(stat.properties.map((p) => p.name));
          }
        }
      }
      if (!succeeded.containsAll(changes.keys)) {
        throw _error(502, 'DavPropertyUpdateIncomplete');
      }
    } on DavException catch (error) {
      if (!_uncertain(error)) rethrow;
      if (!matches(await _read(c, target))) {
        throw _error(409, 'DavCollectionOutcomeUnknown');
      }
    }
    return _refresh();
  }

  Future<DavCollectionAdministrationOutcome> remove(String id) async {
    final c = await _open();
    final target = await _target(c, id);
    final pending =
        await (database.select(database.pendingOps)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  (r.davCollectionId.equals(id) |
                      r.destinationCollectionId.equals(id)),
            ))
            .get();
    if (pending.isNotEmpty) throw _error(409, 'DavCollectionHasPendingChanges');
    if (await _read(c, target) == null) return _refresh();
    final parent = await _read(c, c.home);
    if (parent == null) throw _error(404, 'DavCalendarHomeUnavailable');
    _requirePrivilege(parent, 'unbind');
    try {
      final response = await _send(c, 'DELETE', target);
      if (response.statusCode != 404 &&
          response.statusCode != 410 &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
        throw _error(response.statusCode, 'DavCollectionRemovalFailed');
      }
    } on DavException catch (error) {
      if (!_uncertain(error)) rethrow;
      if (await _read(c, target) != null) {
        throw _error(409, 'DavCollectionOutcomeUnknown');
      }
    }
    return _refresh();
  }

  Future<DavCollectionAdministrationOutcome> _refresh() async {
    try {
      await refresh();
      return DavCollectionAdministrationOutcome.committed;
    } on Object {
      return DavCollectionAdministrationOutcome.refreshPending;
    }
  }
}

final class _Context {
  const _Context(
    this.authority,
    this.home,
    this.profile,
    this.transport,
    this.credential,
    this.generation,
  );
  final Uri authority, home;
  final DavProviderProfile profile;
  final DavHttpTransport transport;
  final DavBasicCredential credential;
  final int generation;
}

const _namespaces =
    'xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/"';
const _properties =
    '<d:resourcetype/><d:displayname/><d:current-user-privilege-set/><c:supported-calendar-component-set/><c:calendar-description/><a:calendar-color/><a:calendar-order/>';
final _writable = {
  const DavPropertyName(davNamespace, 'displayname'),
  const DavPropertyName(caldavNamespace, 'calendar-description'),
  const DavPropertyName(appleIcalNamespace, 'calendar-color'),
  const DavPropertyName(appleIcalNamespace, 'calendar-order'),
};
String _prefix(String? namespace) => switch (namespace) {
  davNamespace => 'd',
  caldavNamespace => 'c',
  appleIcalNamespace => 'a',
  _ => throw ArgumentError('Invalid namespace'),
};
bool _uncertain(DavException error) => const {
  DavErrorKind.unknownOutcome,
  DavErrorKind.timeout,
  DavErrorKind.network,
  DavErrorKind.server,
}.contains(error.kind);
DavException _error(int status, String code) => DavException(
  kind: switch (status) {
    401 => DavErrorKind.authentication,
    403 => DavErrorKind.authorization,
    404 || 410 => DavErrorKind.notFound,
    409 || 412 => DavErrorKind.conflict,
    >= 500 => DavErrorKind.server,
    _ => DavErrorKind.protocol,
  },
  code: code,
  statusCode: status,
  safeMessage: 'The server could not complete the collection operation.',
);

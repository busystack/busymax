import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../dav_provider_profile.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';
import 'dav_collection_mutation_helpers.dart';

enum DavCalendarCollectionCreationStatus { created, createdRefreshPending }

final class DavCalendarCollectionCreationResult {
  const DavCalendarCollectionCreationResult(this.status);

  final DavCalendarCollectionCreationStatus status;

  bool get refreshPending =>
      status == DavCalendarCollectionCreationStatus.createdRefreshPending;
}

abstract interface class DavCalendarCollectionMutationClient {
  Future<DavCalendarCollectionCreationResult> createEventCalendar(
    String title, {
    DavCancellationToken? cancellationToken,
  });
}

/// Creates a Nextcloud VEVENT collection, then lets normal DAV discovery own
/// all local collection and calendar-source projection.
final class DavCalendarCollectionMutationService
    implements DavCalendarCollectionMutationClient {
  DavCalendarCollectionMutationService({
    required AppDatabase database,
    required SecretStore secretStore,
    required http.Client httpClient,
    required String accountId,
    required Future<void> Function() refreshAfterMutation,
    Future<void> Function()? requireNetwork,
    DavTransportLimits transportLimits = const DavTransportLimits(),
    DavXmlParser xmlParser = const DavXmlParser(),
    String Function()? correlationIdFactory,
  }) : _database = database,
       _secretStore = secretStore,
       _httpClient = httpClient,
       _accountId = accountId,
       _refreshAfterMutation = refreshAfterMutation,
       _requireNetwork = requireNetwork ?? _noNetworkCheck,
       _transportLimits = transportLimits,
       _xmlParser = xmlParser,
       _correlationIdFactory = correlationIdFactory ?? const Uuid().v4;

  final AppDatabase _database;
  final SecretStore _secretStore;
  final http.Client _httpClient;
  final String _accountId;
  final Future<void> Function() _refreshAfterMutation;
  final Future<void> Function() _requireNetwork;
  final DavTransportLimits _transportLimits;
  final DavXmlParser _xmlParser;
  final String Function() _correlationIdFactory;

  @override
  Future<DavCalendarCollectionCreationResult> createEventCalendar(
    String title, {
    DavCancellationToken? cancellationToken,
  }) async {
    final displayName = _requiredCalendarTitle(title);
    cancellationToken?.throwIfCancelled();
    await _requireNetwork();
    final context = await _loadContext();
    final existing = await _activeCollections();
    if (existing.any(
      (collection) =>
          collection.eventProjectionEnabled &&
          collection.displayName == displayName,
    )) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'DavCalendarNameConflict',
        safeMessage: 'A Nextcloud calendar already uses this name.',
      );
    }

    final homeUri = davCollectionUri(context.calendarHomeUri);
    final memberName = nextcloudCollectionMemberName(
      displayName,
      homeUri: homeUri,
      existingCollectionUris: [
        for (final collection in existing) Uri.parse(collection.requestUri),
      ],
    );
    final targetUri = homeUri.resolve('$memberName/');
    _validateTarget(
      profile: context.profile,
      authority: context.authority,
      calendarHome: homeUri,
      target: targetUri,
    );

    try {
      final response = await context.transport.send(
        DavRequest.xml(
          method: 'MKCALENDAR',
          uri: targetUri,
          accountId: _accountId,
          correlationId: _correlationIdFactory(),
          body: _eventCalendarMkcalendarXml(displayName),
          retryClass: DavRetryClass.never,
        ),
        credential: context.credential,
        cancellationToken: cancellationToken,
      );
      if (response.statusCode != HttpStatus.created) {
        throw _calendarCreationStatusError(
          response.statusCode,
          correlationId: response.correlationId,
        );
      }
    } on DavException catch (error) {
      if (!_calendarCreationMayHaveCommitted(error) ||
          !await _isMatchingEventCalendar(
            context,
            targetUri,
            displayName: displayName,
            cancellationToken: cancellationToken,
          )) {
        rethrow;
      }
    }

    try {
      await _refreshAfterMutation();
      return const DavCalendarCollectionCreationResult(
        DavCalendarCollectionCreationStatus.created,
      );
    } on Object {
      return const DavCalendarCollectionCreationResult(
        DavCalendarCollectionCreationStatus.createdRefreshPending,
      );
    }
  }

  Future<_DavCalendarCollectionContext> _loadContext() async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    if (account == null ||
        BusyProviderCodec.requireStorageValue(account.provider) !=
            BusyProvider.nextcloud) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCalendarMutationRequiresNextcloud',
        safeMessage: 'Calendar collection creation requires Nextcloud.',
      );
    }
    final authority = Uri.tryParse(account.authority);
    if (authority == null) {
      throw _invalidCalendarMutationContext();
    }
    final secret = await _secretStore.readCredential(_accountId);
    if (secret is! NextcloudSecretRecord ||
        secret.canonicalServer != authority ||
        secret.loginName != account.providerAccountId) {
      throw const DavException(
        kind: DavErrorKind.authentication,
        code: 'DavCredentialsRevoked',
        safeMessage: 'The Nextcloud credential is unavailable or invalid.',
      );
    }
    final service = await (_database.select(
      _database.davAccountServices,
    )..where((row) => row.accountId.equals(_accountId))).getSingleOrNull();
    final calendarHomeValue = service?.calendarHomeHref?.trim();
    final calendarHome = calendarHomeValue == null || calendarHomeValue.isEmpty
        ? null
        : Uri.tryParse(calendarHomeValue);
    if (calendarHome == null) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCalendarHomeUnavailable',
        safeMessage: 'The Nextcloud calendar home is unavailable.',
      );
    }
    final profile = davProviderProfile(
      BusyProvider.nextcloud,
      nextcloudServer: authority,
    );
    if (!profile.allowCollectionMutations ||
        !profile.isTrustedCredentialDestination(
          calendarHome,
          accountAuthority: authority,
        )) {
      throw _invalidCalendarMutationContext();
    }
    return _DavCalendarCollectionContext(
      authority: authority,
      profile: profile,
      transport: DavHttpTransport(
        client: _httpClient,
        profile: profile,
        accountAuthority: authority,
        limits: _transportLimits,
      ),
      credential: DavBasicCredential(
        username: secret.loginName,
        password: secret.appPassword,
      ),
      calendarHomeUri: calendarHome,
    );
  }

  Future<List<DavCollection>> _activeCollections() {
    return (_database.select(_database.davCollections)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.deleted.equals(false) &
              row.serverMissing.equals(false),
        ))
        .get();
  }

  Future<bool> _isMatchingEventCalendar(
    _DavCalendarCollectionContext context,
    Uri uri, {
    required String displayName,
    DavCancellationToken? cancellationToken,
  }) async {
    try {
      final response = await context.transport.send(
        DavRequest.xml(
          method: 'PROPFIND',
          uri: uri,
          accountId: _accountId,
          correlationId: _correlationIdFactory(),
          headers: const {'depth': '0'},
          body: _eventCalendarProbeXml,
          retryClass: DavRetryClass.safeRead,
        ),
        credential: context.credential,
        cancellationToken: cancellationToken,
      );
      if (response.statusCode != HttpStatus.multiStatus) return false;
      final multistatus = _xmlParser.parseMultistatus(
        response.bodyBytes,
        correlationId: response.correlationId,
      );
      for (final item in multistatus.responses) {
        final resourceType = item.successfulProperty(
          davNamespace,
          'resourcetype',
        );
        final components = item.successfulProperty(
          caldavNamespace,
          'supported-calendar-component-set',
        );
        final name = item
            .successfulProperty(davNamespace, 'displayname')
            ?.text
            .trim();
        final isCollection = resourceType?.childElements.any(
          (element) =>
              element.name.namespaceUri == davNamespace &&
              element.name.local == 'collection',
        );
        final isCalendar = resourceType?.childElements.any(
          (element) =>
              element.name.namespaceUri == caldavNamespace &&
              element.name.local == 'calendar',
        );
        final supportsEvents = components?.childElements.any(
          (element) =>
              element.name.namespaceUri == caldavNamespace &&
              element.name.local == 'comp' &&
              element.getAttribute('name')?.toUpperCase() == 'VEVENT',
        );
        if (isCollection == true &&
            isCalendar == true &&
            supportsEvents == true &&
            name == displayName) {
          return true;
        }
      }
    } on Object {
      return false;
    }
    return false;
  }
}

final class _DavCalendarCollectionContext {
  const _DavCalendarCollectionContext({
    required this.authority,
    required this.profile,
    required this.transport,
    required this.credential,
    required this.calendarHomeUri,
  });

  final Uri authority;
  final DavProviderProfile profile;
  final DavHttpTransport transport;
  final DavBasicCredential credential;
  final Uri calendarHomeUri;
}

void _validateTarget({
  required DavProviderProfile profile,
  required Uri authority,
  required Uri calendarHome,
  required Uri target,
}) {
  final home = davCollectionUri(calendarHome);
  final targetPath = target.path;
  final relativePath = targetPath.startsWith(home.path)
      ? targetPath.substring(home.path.length)
      : '';
  final memberPath = relativePath.endsWith('/')
      ? relativePath.substring(0, relativePath.length - 1)
      : relativePath;
  if (!profile.isTrustedCredentialDestination(
        target,
        accountAuthority: authority,
      ) ||
      target.query.isNotEmpty ||
      target.fragment.isNotEmpty ||
      !target.path.endsWith('/') ||
      relativePath.isEmpty ||
      memberPath.isEmpty ||
      memberPath.contains('/')) {
    throw _invalidCalendarMutationContext();
  }
}

String _requiredCalendarTitle(String title) {
  final value = title.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(title, 'title', 'A calendar name is required.');
  }
  return value;
}

String _eventCalendarMkcalendarXml(String displayName) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<c:mkcalendar xmlns:d="$davNamespace" xmlns:c="$caldavNamespace">'
    '<d:set><d:prop>'
    '<d:displayname>${escapeDavXmlText(displayName)}</d:displayname>'
    '<c:supported-calendar-component-set>'
    '<c:comp name="VEVENT"/>'
    '</c:supported-calendar-component-set>'
    '</d:prop></d:set>'
    '</c:mkcalendar>';

const _eventCalendarProbeXml =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propfind xmlns:d="DAV:" '
    'xmlns:c="urn:ietf:params:xml:ns:caldav">'
    '<d:prop><d:resourcetype/><d:displayname/>'
    '<c:supported-calendar-component-set/></d:prop>'
    '</d:propfind>';

bool _calendarCreationMayHaveCommitted(DavException error) =>
    switch (error.kind) {
      DavErrorKind.timeout ||
      DavErrorKind.network ||
      DavErrorKind.server => true,
      _ => false,
    };

DavException _calendarCreationStatusError(
  int statusCode, {
  required String correlationId,
}) {
  final mapped = switch (statusCode) {
    HttpStatus.unauthorized => (
      DavErrorKind.authentication,
      'DavAuthRejected',
      'Nextcloud rejected the account credential.',
    ),
    HttpStatus.forbidden => (
      DavErrorKind.authorization,
      'DavCalendarParentNotWritable',
      'Nextcloud did not allow calendar creation.',
    ),
    HttpStatus.conflict || HttpStatus.preconditionFailed => (
      DavErrorKind.conflict,
      'DavCalendarCollectionConflict',
      'A Nextcloud calendar already exists at the selected location.',
    ),
    HttpStatus.methodNotAllowed || HttpStatus.notImplemented => (
      DavErrorKind.unsupportedComponent,
      'DavMkcalendarUnsupported',
      'This Nextcloud server does not support calendar creation.',
    ),
    HttpStatus.tooManyRequests => (
      DavErrorKind.rateLimited,
      'DavRateLimited',
      'Nextcloud temporarily limited calendar creation.',
    ),
    >= 500 => (
      DavErrorKind.server,
      'DavServerUnavailable',
      'Nextcloud could not complete calendar creation.',
    ),
    _ => (
      DavErrorKind.protocol,
      'DavCalendarCollectionCreationRejected',
      'Nextcloud rejected calendar creation.',
    ),
  };
  return DavException(
    kind: mapped.$1,
    code: mapped.$2,
    safeMessage: mapped.$3,
    statusCode: statusCode,
    correlationId: correlationId,
  );
}

DavException _invalidCalendarMutationContext() => const DavException(
  kind: DavErrorKind.protocol,
  code: 'DavCalendarMutationContextInvalid',
  safeMessage: 'The Nextcloud calendar connection is invalid.',
);

Future<void> _noNetworkCheck() async {}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../dav_provider_profile.dart';
import '../discovery/dav_discovery_models.dart';
import '../http/dav_http_transport.dart';
import '../storage/dav_collection_capabilities.dart';
import '../xml/dav_xml.dart';
import 'dav_collection_mutation_helpers.dart';

export 'dav_collection_mutation_helpers.dart'
    show nextcloudCollectionMemberName;

const nextcloudDefaultTaskListColor = '#0082C9';

abstract interface class DavTaskListMutationClient {
  Future<void> createTaskList(String title);

  Future<void> renameTaskList(String collectionId, String title);

  Future<void> deleteTaskList(String collectionId);
}

/// Applies Nextcloud Tasks list mutations to their backing CalDAV calendar
/// collections, then refreshes discovery so local projections remain
/// authoritative to the server.
final class DavTaskListMutationService implements DavTaskListMutationClient {
  DavTaskListMutationService({
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
  Future<void> createTaskList(String title) async {
    final displayName = _requiredTitle(title);
    await _requireNetwork();
    final context = await _loadContext(requireCalendarHome: true);
    final existing = await _activeCollections();
    if (existing.any(
      (collection) =>
          collection.taskProjectionEnabled &&
          collection.displayName == displayName,
    )) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'DavTaskListNameConflict',
        safeMessage: 'A Nextcloud task list already uses this name.',
      );
    }

    final homeUri = davCollectionUri(context.calendarHomeUri!);
    final memberName = nextcloudCollectionMemberName(
      displayName,
      homeUri: homeUri,
      existingCollectionUris: [
        for (final collection in existing) Uri.parse(collection.requestUri),
      ],
    );
    final targetUri = homeUri.resolve(memberName);
    final correlationId = _correlationIdFactory();
    try {
      final response = await context.transport.send(
        DavRequest.xml(
          method: 'MKCOL',
          uri: targetUri,
          accountId: _accountId,
          correlationId: correlationId,
          body: _taskCollectionMkcolXml(
            displayName: displayName,
            color: nextcloudDefaultTaskListColor,
          ),
          retryClass: DavRetryClass.never,
        ),
        credential: context.credential,
      );
      _requireSuccessfulMutation(response, operation: 'create the task list');
    } on DavException catch (error) {
      if (!_mayHaveCommitted(error) ||
          !await _isMatchingTaskCollection(
            context,
            targetUri,
            displayName: displayName,
          )) {
        rethrow;
      }
    }
    await _refreshAfterMutation();
  }

  @override
  Future<void> renameTaskList(String collectionId, String title) async {
    final displayName = _requiredTitle(title);
    final context = await _loadContext();
    final collection = await _requiredTaskCollection(collectionId);
    final capabilities = collectionCapabilitiesFromStored(collection);
    if (!capabilities.canWriteProperties) {
      throw _readOnlyError();
    }
    final existing = await _activeCollections();
    if (existing.any(
      (candidate) =>
          candidate.id != collection.id &&
          candidate.taskProjectionEnabled &&
          candidate.displayName == displayName,
    )) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'DavTaskListNameConflict',
        safeMessage: 'A Nextcloud task list already uses this name.',
      );
    }
    if (collection.displayName == displayName) return;

    final response = await context.transport.send(
      DavRequest.xml(
        method: 'PROPPATCH',
        uri: Uri.parse(collection.requestUri),
        accountId: _accountId,
        collectionId: collection.id,
        correlationId: _correlationIdFactory(),
        body: _displayNameProppatchXml(displayName),
        retryClass: DavRetryClass.never,
      ),
      credential: context.credential,
    );
    _requireSuccessfulMutation(response, operation: 'rename the task list');
    await _refreshAfterMutation();
  }

  @override
  Future<void> deleteTaskList(String collectionId) async {
    final context = await _loadContext();
    final collection = await _requiredTaskCollection(collectionId);
    final capabilities = collectionCapabilitiesFromStored(collection);
    final shared = await _isSharedWithAccount(collection);
    // Nextcloud Tasks exposes Delete for writable owned lists and Unshare for
    // collections shared with the current account.
    if (capabilities.isReadOnly && !shared) {
      throw _readOnlyError();
    }

    final response = await context.transport.send(
      DavRequest(
        method: 'DELETE',
        uri: Uri.parse(collection.requestUri),
        accountId: _accountId,
        collectionId: collection.id,
        correlationId: _correlationIdFactory(),
        retryClass: DavRetryClass.never,
      ),
      credential: context.credential,
    );
    if (response.statusCode != HttpStatus.notFound) {
      _requireSuccessfulMutation(response, operation: 'delete the task list');
    }
    await _refreshAfterMutation();
  }

  Future<_DavTaskListContext> _loadContext({
    bool requireCalendarHome = false,
  }) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    if (account == null ||
        BusyProviderCodec.requireStorageValue(account.provider) !=
            BusyProvider.nextcloud) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavTaskListMutationRequiresNextcloud',
        safeMessage: 'Task-list collection changes require Nextcloud.',
      );
    }
    final authority = Uri.tryParse(account.authority);
    if (authority == null) {
      throw _invalidContextError();
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
    final calendarHome = Uri.tryParse(service?.calendarHomeHref ?? '');
    if (requireCalendarHome && calendarHome == null) {
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
    return _DavTaskListContext(
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

  Future<DavCollection> _requiredTaskCollection(String collectionId) async {
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    if (collection == null ||
        collection.accountId != _accountId ||
        collection.deleted ||
        collection.serverMissing ||
        !collection.taskProjectionEnabled ||
        collection.supportedComponentMask & davComponentTodo == 0) {
      throw const DavException(
        kind: DavErrorKind.notFound,
        code: 'DavTaskListCollectionNotFound',
        safeMessage: 'The Nextcloud task list is no longer available.',
      );
    }
    return collection;
  }

  Future<bool> _isSharedWithAccount(DavCollection collection) async {
    final service = await (_database.select(
      _database.davAccountServices,
    )..where((row) => row.accountId.equals(_accountId))).getSingleOrNull();
    final owner = _normalizedHrefPath(collection.ownerHref);
    final principal = _normalizedHrefPath(service?.principalHref);
    return owner != null && principal != null && owner != principal;
  }

  Future<bool> _isMatchingTaskCollection(
    _DavTaskListContext context,
    Uri uri, {
    required String displayName,
  }) async {
    try {
      final response = await context.transport.send(
        DavRequest.xml(
          method: 'PROPFIND',
          uri: uri,
          accountId: _accountId,
          correlationId: _correlationIdFactory(),
          headers: const {'depth': '0'},
          body: _taskCollectionProbeXml,
          retryClass: DavRetryClass.safeRead,
        ),
        credential: context.credential,
      );
      if (response.statusCode == HttpStatus.notFound ||
          response.statusCode != HttpStatus.multiStatus) {
        return false;
      }
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
        final isCalendar = resourceType?.childElements.any(
          (element) =>
              element.name.namespaceUri == caldavNamespace &&
              element.name.local == 'calendar',
        );
        final supportsTasks = components?.childElements.any(
          (element) =>
              element.name.namespaceUri == caldavNamespace &&
              element.name.local == 'comp' &&
              element.getAttribute('name')?.toUpperCase() == 'VTODO',
        );
        if (isCalendar == true &&
            supportsTasks == true &&
            name == displayName) {
          return true;
        }
      }
    } on Object {
      return false;
    }
    return false;
  }

  void _requireSuccessfulMutation(
    DavResponse response, {
    required String operation,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _statusError(
        response.statusCode,
        operation: operation,
        correlationId: response.correlationId,
      );
    }
    if (response.statusCode != HttpStatus.multiStatus) return;
    final multistatus = _xmlParser.parseMultistatus(
      response.bodyBytes,
      correlationId: response.correlationId,
    );
    if (multistatus.responses.isEmpty) {
      throw DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCollectionMutationEmptyMultistatus',
        safeMessage: 'Nextcloud returned an invalid collection response.',
        statusCode: response.statusCode,
        correlationId: response.correlationId,
      );
    }
    for (final item in multistatus.responses) {
      final responseStatus = item.statusCode;
      if (responseStatus != null &&
          (responseStatus < 200 || responseStatus >= 300)) {
        throw _statusError(
          responseStatus,
          operation: operation,
          correlationId: response.correlationId,
        );
      }
      for (final propstat in item.propstats) {
        if (!propstat.isSuccessful) {
          throw _statusError(
            propstat.statusCode,
            operation: operation,
            correlationId: response.correlationId,
          );
        }
      }
    }
  }
}

final class _DavTaskListContext {
  const _DavTaskListContext({
    required this.transport,
    required this.credential,
    required this.calendarHomeUri,
  });

  final DavHttpTransport transport;
  final DavBasicCredential credential;
  final Uri? calendarHomeUri;
}

String _requiredTitle(String title) {
  final value = title.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(title, 'title', 'A task-list name is required.');
  }
  return value;
}

String _taskCollectionMkcolXml({
  required String displayName,
  required String color,
}) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:mkcol xmlns:d="$davNamespace" '
    'xmlns:c="$caldavNamespace" '
    'xmlns:a="$appleIcalNamespace" '
    'xmlns:o="$owncloudNamespace">'
    '<d:set><d:prop>'
    '<d:resourcetype><d:collection/><c:calendar/></d:resourcetype>'
    '<d:displayname>${escapeDavXmlText(displayName)}</d:displayname>'
    '<a:calendar-color>${escapeDavXmlText(color)}</a:calendar-color>'
    '<o:calendar-enabled>1</o:calendar-enabled>'
    '<c:supported-calendar-component-set>'
    '<c:comp name="VTODO"/>'
    '</c:supported-calendar-component-set>'
    '</d:prop></d:set>'
    '</d:mkcol>';

String _displayNameProppatchXml(String displayName) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propertyupdate xmlns:d="$davNamespace">'
    '<d:set><d:prop>'
    '<d:displayname>${escapeDavXmlText(displayName)}</d:displayname>'
    '</d:prop></d:set>'
    '</d:propertyupdate>';

const _taskCollectionProbeXml =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propfind xmlns:d="DAV:" '
    'xmlns:c="urn:ietf:params:xml:ns:caldav">'
    '<d:prop><d:resourcetype/><d:displayname/>'
    '<c:supported-calendar-component-set/></d:prop>'
    '</d:propfind>';

bool _mayHaveCommitted(DavException error) => switch (error.kind) {
  DavErrorKind.timeout || DavErrorKind.network || DavErrorKind.server => true,
  _ => false,
};

DavException _statusError(
  int statusCode, {
  required String operation,
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
      'DavPermissionDenied',
      'Nextcloud did not allow this task-list change.',
    ),
    HttpStatus.notFound || HttpStatus.gone => (
      DavErrorKind.notFound,
      'DavTaskListCollectionNotFound',
      'The Nextcloud task list is no longer available.',
    ),
    HttpStatus.conflict ||
    HttpStatus.preconditionFailed ||
    HttpStatus.locked ||
    HttpStatus.methodNotAllowed => (
      DavErrorKind.conflict,
      'DavTaskListCollectionConflict',
      'Nextcloud could not $operation because the collection changed.',
    ),
    HttpStatus.tooManyRequests => (
      DavErrorKind.rateLimited,
      'DavRateLimited',
      'Nextcloud temporarily limited task-list changes.',
    ),
    HttpStatus.insufficientStorage => (
      DavErrorKind.limitExceeded,
      'DavQuotaOrSizeLimit',
      'Nextcloud has insufficient storage for this task-list change.',
    ),
    >= 500 => (
      DavErrorKind.server,
      'DavServerUnavailable',
      'Nextcloud could not complete the task-list change.',
    ),
    _ => (
      DavErrorKind.protocol,
      'DavTaskListCollectionMutationRejected',
      'Nextcloud rejected the task-list change.',
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

DavException _readOnlyError() => const DavException(
  kind: DavErrorKind.authorization,
  code: 'DavCollectionReadOnly',
  safeMessage: 'This Nextcloud task list is read-only.',
  categoryOverride: DavErrorCategory.davReadOnly,
);

DavException _invalidContextError() => const DavException(
  kind: DavErrorKind.protocol,
  code: 'DavTaskListMutationContextInvalid',
  safeMessage: 'The Nextcloud task-list connection is invalid.',
);

String? _normalizedHrefPath(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.path.isEmpty) return null;
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

Future<void> _noNetworkCheck() async {}

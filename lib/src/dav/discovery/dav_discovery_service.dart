import 'package:xml/xml.dart';

import '../../providers/provider_capabilities.dart';
import '../dav_errors.dart';
import '../dav_href.dart';
import '../dav_provider_profile.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';
import 'dav_discovery_models.dart';

final class DavDiscoveryService {
  DavDiscoveryService({
    required DavHttpTransport transport,
    required DavProviderProfile profile,
    required Uri accountAuthority,
    required String accountId,
    required DavBasicCredential credential,
    DavXmlParser xmlParser = const DavXmlParser(),
    DateTime Function()? nowUtc,
  }) : _transport = transport,
       _profile = profile,
       _accountAuthority = accountAuthority,
       _accountId = accountId,
       _credential = credential,
       _xmlParser = xmlParser,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final DavHttpTransport _transport;
  final DavProviderProfile _profile;
  final Uri _accountAuthority;
  final String _accountId;
  final DavBasicCredential _credential;
  final DavXmlParser _xmlParser;
  final DateTime Function() _nowUtc;

  Future<DavDiscoveryResult> discover({
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) async {
    final options = await _transport.send(
      DavRequest(
        method: 'OPTIONS',
        uri: davWellKnownUri(_profile),
        accountId: _accountId,
        correlationId: correlationId,
        retryClass: DavRetryClass.safeRead,
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    _requireSuccessfulOrDav(options);
    final serviceCapabilities = _serviceCapabilities(options);

    final principalResponse = await _propfind(
      uri: options.requestUri,
      depth: '0',
      body: _currentPrincipalPropfind,
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
    final principalSet = _xmlParser.parseMultistatus(
      principalResponse.bodyBytes,
      correlationId: correlationId,
    );
    final principalHref = _requiredHrefProperty(
      principalSet,
      davNamespace,
      'current-user-principal',
      responseUri: principalResponse.requestUri,
      correlationId: correlationId,
    );

    final homeResponse = await _propfind(
      uri: principalHref,
      depth: '0',
      body: _principalPropertiesPropfind,
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
    final principalProperties = _xmlParser.parseMultistatus(
      homeResponse.bodyBytes,
      correlationId: correlationId,
    );
    final calendarHome = _requiredHrefProperty(
      principalProperties,
      caldavNamespace,
      'calendar-home-set',
      responseUri: homeResponse.requestUri,
      correlationId: correlationId,
    );
    final addresses = _calendarAddressListProperty(
      principalProperties,
      caldavNamespace,
      'calendar-user-address-set',
      responseUri: homeResponse.requestUri,
      correlationId: correlationId,
    );
    final inbox = _optionalHrefProperty(
      principalProperties,
      caldavNamespace,
      'schedule-inbox-URL',
      responseUri: homeResponse.requestUri,
      correlationId: correlationId,
    );
    final outbox = _optionalHrefProperty(
      principalProperties,
      caldavNamespace,
      'schedule-outbox-URL',
      responseUri: homeResponse.requestUri,
      correlationId: correlationId,
    );

    final inventoryResponse = await _propfind(
      uri: calendarHome,
      depth: '1',
      body: _calendarHomeInventoryPropfind,
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
    final inventory = _xmlParser.parseMultistatus(
      inventoryResponse.bodyBytes,
      correlationId: correlationId,
    );
    final collections = _parseCollections(
      inventory,
      responseUri: inventoryResponse.requestUri,
      home: calendarHome,
      inbox: inbox,
      outbox: outbox,
      correlationId: correlationId,
    );
    final now = _nowUtc().toUtc();
    final canonicalService = principalResponse.requestUri;
    return DavDiscoveryResult(
      accountId: _accountId,
      provider: _profile.provider,
      service: DavServiceDiscovery(
        canonicalServiceUri: canonicalService,
        canonicalOrigin: canonicalService.replace(
          path: '',
          query: null,
          fragment: null,
        ),
        principalHref: principalHref,
        calendarHomeHref: calendarHome,
        calendarUserAddresses: addresses,
        scheduleInboxHref: inbox,
        scheduleOutboxHref: outbox,
        capabilities: AccountServiceCapabilities(
          hasPrincipal: true,
          hasCalendarHome: true,
          hasSchedulingInbox: inbox != null,
          hasSchedulingOutbox: outbox != null,
          supportedReports: serviceCapabilities.supportedReports,
          serverFeatures: serviceCapabilities.serverFeatures,
        ),
        discoveredAtUtc: now,
        lastValidatedAtUtc: now,
        providerProfileVersion: davProviderProfileVersion,
      ),
      collections: List.unmodifiable(collections),
    );
  }

  Future<DavResponse> _propfind({
    required Uri uri,
    required String depth,
    required String body,
    required String correlationId,
    required DavCancellationToken? cancellationToken,
  }) async {
    final response = await _transport.send(
      DavRequest.xml(
        method: 'PROPFIND',
        uri: uri,
        accountId: _accountId,
        correlationId: correlationId,
        body: body,
        headers: {'depth': depth},
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    _requireMultistatus(response);
    return response;
  }

  AccountServiceCapabilities _serviceCapabilities(DavResponse response) {
    final davTokens = (response.headers['dav'] ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final allow = (response.headers['allow'] ?? '')
        .split(',')
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    return AccountServiceCapabilities(
      hasPrincipal: true,
      hasCalendarHome: true,
      supportedReports: {if (allow.contains('REPORT')) 'REPORT'},
      serverFeatures: {...davTokens, ...allow.map((method) => 'allow:$method')},
    );
  }

  List<DavCollectionDiscovery> _parseCollections(
    DavMultistatus inventory, {
    required Uri responseUri,
    required Uri home,
    required Uri? inbox,
    required Uri? outbox,
    required String correlationId,
  }) {
    final result = <DavCollectionDiscovery>[];
    final homeKey = normalizedDavHrefKey(_profile.provider, home);
    for (final response in inventory.responses) {
      final responseStatus = response.statusCode;
      if (response.isMissing ||
          (responseStatus != null && responseStatus >= 400)) {
        continue;
      }
      final requestUri = resolveDavHref(
        href: response.href,
        responseRequestUri: responseUri,
        profile: _profile,
        accountAuthority: _accountAuthority,
        correlationId: correlationId,
      );
      final hrefKey = normalizedDavHrefKey(_profile.provider, requestUri);
      if (hrefKey == homeKey) {
        continue;
      }
      final resourceTypes = _nestedNames(
        response.successfulProperty(davNamespace, 'resourcetype'),
      );
      final isCalendar = resourceTypes.contains(
        _name(caldavNamespace, 'calendar'),
      );
      final isInbox =
          _sameRequestTarget(requestUri, inbox) ||
          resourceTypes.contains(_name(caldavNamespace, 'schedule-inbox'));
      final isOutbox =
          _sameRequestTarget(requestUri, outbox) ||
          resourceTypes.contains(_name(caldavNamespace, 'schedule-outbox'));
      final isSubscribed = resourceTypes.contains(
        _name(calendarServerNamespace, 'subscribed'),
      );
      if (!isCalendar && !isInbox && !isOutbox) {
        continue;
      }

      final componentProperty = response.successfulProperty(
        caldavNamespace,
        'supported-calendar-component-set',
      );
      final componentMask = _componentMask(componentProperty);
      final supportsEvents = componentMask & davComponentEvent != 0;
      final supportsTasks = componentMask & davComponentTodo != 0;
      final reports = _reportNames(
        response.successfulProperty(davNamespace, 'supported-report-set'),
      );
      final privileges = _privilegeNames(
        response.successfulProperty(davNamespace, 'current-user-privilege-set'),
      );
      final hasAggregateAll = privileges.contains(_name(davNamespace, 'all'));
      final hasAggregateWrite =
          hasAggregateAll || privileges.contains(_name(davNamespace, 'write'));
      final capabilities = CollectionCapabilities(
        canRead:
            hasAggregateWrite ||
            privileges.contains(_name(davNamespace, 'read')),
        canReadPrivileges:
            hasAggregateAll ||
            privileges.contains(
              _name(davNamespace, 'read-current-user-privilege-set'),
            ),
        canWriteContent:
            hasAggregateWrite ||
            privileges.contains(_name(davNamespace, 'write-content')),
        canWriteProperties:
            hasAggregateWrite ||
            privileges.contains(_name(davNamespace, 'write-properties')),
        canAddMembers:
            hasAggregateWrite ||
            privileges.contains(_name(davNamespace, 'bind')),
        canDeleteMembers:
            hasAggregateWrite ||
            privileges.contains(_name(davNamespace, 'unbind')),
        canReadFreeBusy:
            hasAggregateAll ||
            privileges.contains(_name(caldavNamespace, 'read-free-busy')),
        supportsEvents: supportsEvents,
        supportsTasks: supportsTasks,
        supportsSyncCollection: reports.contains(
          _name(davNamespace, 'sync-collection'),
        ),
        supportsCalendarMultiget: reports.contains(
          _name(caldavNamespace, 'calendar-multiget'),
        ),
        supportsCalendarQuery: reports.contains(
          _name(caldavNamespace, 'calendar-query'),
        ),
        supportedCalendarData: _calendarDataFormats(
          response.successfulProperty(
            caldavNamespace,
            'supported-calendar-data',
          ),
        ).map((entry) => entry['contentType'] ?? '').toSet(),
        maximumResourceSize: _integerProperty(
          response.successfulProperty(caldavNamespace, 'max-resource-size'),
        ),
        maximumInstances: _integerProperty(
          response.successfulProperty(caldavNamespace, 'max-instances'),
        ),
        providerAllowsCollectionMutation: _profile.allowCollectionMutations,
        providerAllowsSchedulingMutation: _profile.allowSchedulingMutations,
      );
      final kind = _classify(
        isInbox: isInbox,
        isOutbox: isOutbox,
        isSubscribed: isSubscribed,
        hrefKey: hrefKey,
        supportsEvents: supportsEvents,
        supportsTasks: supportsTasks,
        capabilities: capabilities,
      );
      final calendarData = _calendarDataFormats(
        response.successfulProperty(caldavNamespace, 'supported-calendar-data'),
      );
      result.add(
        DavCollectionDiscovery(
          hrefKey: hrefKey,
          requestUri: requestUri,
          displayName:
              _textProperty(
                response.successfulProperty(davNamespace, 'displayname'),
              ) ??
              _fallbackDisplayName(hrefKey),
          description: _textProperty(
            response.successfulProperty(
              caldavNamespace,
              'calendar-description',
            ),
          ),
          resourceTypes: resourceTypes,
          supportedComponentMask: componentMask,
          supportedCalendarData: calendarData,
          supportedReports: reports,
          currentUserPrivileges: privileges,
          ownerHref: _rawHref(
            response.successfulProperty(davNamespace, 'owner'),
          ),
          safeDisplayMetadata: _safeDisplayMetadata(response),
          color: _textProperty(
            response.successfulProperty(appleIcalNamespace, 'calendar-color'),
          ),
          sortOrder: _integerProperty(
            response.successfulProperty(appleIcalNamespace, 'calendar-order'),
          ),
          calendarTimeZone: _textProperty(
            response.successfulProperty(caldavNamespace, 'calendar-timezone'),
          ),
          calendarTimeZoneId: _textProperty(
            response.successfulProperty(
              caldavNamespace,
              'calendar-timezone-id',
            ),
          ),
          scheduleTransparency: _nestedNames(
            response.successfulProperty(
              caldavNamespace,
              'schedule-calendar-transp',
            ),
          ).firstOrNull,
          maximumResourceSize: capabilities.maximumResourceSize,
          maximumInstances: capabilities.maximumInstances,
          syncToken: _textProperty(
            response.successfulProperty(davNamespace, 'sync-token'),
          ),
          ctag: _textProperty(
            response.successfulProperty(calendarServerNamespace, 'getctag'),
          ),
          capabilities: capabilities,
          kind: kind,
          eventProjectionEnabled:
              !isInbox &&
              !isOutbox &&
              _profile.calendarEnabled &&
              supportsEvents,
          taskProjectionEnabled:
              !isInbox && !isOutbox && _profile.tasksEnabled && supportsTasks,
        ),
      );
    }
    return result;
  }

  DavCollectionKind _classify({
    required bool isInbox,
    required bool isOutbox,
    required bool isSubscribed,
    required String hrefKey,
    required bool supportsEvents,
    required bool supportsTasks,
    required CollectionCapabilities capabilities,
  }) {
    if (isInbox) return DavCollectionKind.schedulingInbox;
    if (isOutbox) return DavCollectionKind.schedulingOutbox;
    if (isSubscribed) return DavCollectionKind.subscribedCalendar;
    final lowered = hrefKey.toLowerCase();
    if (lowered.contains('/notifications/') || lowered.contains('/trashbin/')) {
      return DavCollectionKind.notifications;
    }
    if (supportsEvents && supportsTasks) return DavCollectionKind.mixedCalendar;
    if (supportsEvents) {
      return capabilities.isReadOnly
          ? DavCollectionKind.readOnlyEventCalendar
          : DavCollectionKind.writableEventCalendar;
    }
    if (supportsTasks) {
      return capabilities.isReadOnly
          ? DavCollectionKind.readOnlyTaskList
          : DavCollectionKind.writableTaskList;
    }
    return DavCollectionKind.unsupported;
  }

  Uri _requiredHrefProperty(
    DavMultistatus multistatus,
    String namespaceUri,
    String localName, {
    required Uri responseUri,
    required String correlationId,
  }) {
    final result = _optionalHrefProperty(
      multistatus,
      namespaceUri,
      localName,
      responseUri: responseUri,
      correlationId: correlationId,
    );
    if (result == null) {
      throw DavException(
        kind: DavErrorKind.protocol,
        code: 'DavUnsupportedServer',
        safeMessage: 'The DAV server omitted a required discovery property.',
        correlationId: correlationId,
        categoryOverride: DavErrorCategory.davUnsupportedServer,
      );
    }
    return result;
  }

  Uri? _optionalHrefProperty(
    DavMultistatus multistatus,
    String namespaceUri,
    String localName, {
    required Uri responseUri,
    required String correlationId,
  }) {
    for (final response in multistatus.responses) {
      final property = response.successfulProperty(namespaceUri, localName);
      final href = _hrefChildren(property).firstOrNull;
      if (href != null) {
        return resolveDavHref(
          href: href,
          responseRequestUri: responseUri,
          profile: _profile,
          accountAuthority: _accountAuthority,
          correlationId: correlationId,
        );
      }
    }
    return null;
  }

  List<Uri> _calendarAddressListProperty(
    DavMultistatus multistatus,
    String namespaceUri,
    String localName, {
    required Uri responseUri,
    required String correlationId,
  }) {
    final result = <Uri>[];
    for (final response in multistatus.responses) {
      final property = response.successfulProperty(namespaceUri, localName);
      for (final href in _hrefChildren(property)) {
        final parsed = Uri.tryParse(href);
        if (parsed != null &&
            (parsed.scheme.toLowerCase() == 'mailto' ||
                parsed.scheme.toLowerCase() == 'urn') &&
            !parsed.hasFragment) {
          result.add(parsed);
        } else {
          result.add(
            resolveDavHref(
              href: href,
              responseRequestUri: responseUri,
              profile: _profile,
              accountAuthority: _accountAuthority,
              correlationId: correlationId,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }

  void _requireSuccessfulOrDav(DavResponse response) {
    if ((response.statusCode >= 200 && response.statusCode < 300) ||
        response.statusCode == 207) {
      return;
    }
    throw _statusException(response);
  }

  void _requireMultistatus(DavResponse response) {
    if (response.statusCode != 207) {
      throw _statusException(response);
    }
  }

  DavException _statusException(DavResponse response) {
    final mapped = switch (response.statusCode) {
      401 => (
        DavErrorKind.authentication,
        DavErrorCategory.davAuthRejected,
        'DavAuthRejected',
      ),
      403 => (
        DavErrorKind.authorization,
        DavErrorCategory.davPermissionDenied,
        'DavPermissionDenied',
      ),
      404 => (
        DavErrorKind.protocol,
        DavErrorCategory.davUnsupportedServer,
        'DavUnsupportedServer',
      ),
      429 => (
        DavErrorKind.rateLimited,
        DavErrorCategory.davRateLimited,
        'DavRateLimited',
      ),
      >= 500 => (
        DavErrorKind.server,
        DavErrorCategory.davServerUnavailable,
        'DavServerUnavailable',
      ),
      _ => (
        DavErrorKind.protocol,
        DavErrorCategory.davDiscoveryFailed,
        'DavDiscoveryFailed',
      ),
    };
    return DavException(
      kind: mapped.$1,
      code: mapped.$3,
      safeMessage: 'The DAV server rejected the discovery request.',
      statusCode: response.statusCode,
      correlationId: response.correlationId,
      retryAfter: parseDavRetryAfter(response.headers['retry-after']),
      categoryOverride: mapped.$2,
    );
  }
}

String _name(String? namespace, String local) => '{$namespace}$local';

Set<String> _nestedNames(DavProperty? property) => {
  if (property != null)
    for (final element in property.element.descendantElements)
      _name(element.name.namespaceUri, element.name.local),
};

Set<String> _reportNames(DavProperty? property) {
  if (property == null) return const {};
  final result = <String>{};
  for (final report in property.element.descendantElements.where(
    (element) =>
        element.name.namespaceUri == davNamespace &&
        element.name.local == 'report',
  )) {
    final child = report.childElements.firstOrNull;
    if (child != null) {
      result.add(_name(child.name.namespaceUri, child.name.local));
    }
  }
  return result;
}

Set<String> _privilegeNames(DavProperty? property) {
  if (property == null) return const {};
  final result = <String>{};
  for (final privilege in property.element.descendantElements.where(
    (element) =>
        element.name.namespaceUri == davNamespace &&
        element.name.local == 'privilege',
  )) {
    final child = privilege.childElements.firstOrNull;
    if (child != null) {
      result.add(_name(child.name.namespaceUri, child.name.local));
    }
  }
  return result;
}

int _componentMask(DavProperty? property) {
  if (property == null) {
    return davComponentEvent |
        davComponentTodo |
        davComponentJournal |
        davComponentFreeBusy;
  }
  var result = 0;
  for (final component in property.element.descendantElements.where(
    (element) =>
        element.name.namespaceUri == caldavNamespace &&
        element.name.local == 'comp',
  )) {
    result |= switch (component.getAttribute('name')?.toUpperCase()) {
      'VEVENT' => davComponentEvent,
      'VTODO' => davComponentTodo,
      'VTIMEZONE' => davComponentTimezone,
      'VJOURNAL' => davComponentJournal,
      'VFREEBUSY' => davComponentFreeBusy,
      _ => 0,
    };
  }
  return result;
}

List<Map<String, String>> _calendarDataFormats(DavProperty? property) {
  if (property == null) return const [];
  return [
    for (final element in property.element.descendantElements)
      if (element.name.namespaceUri == caldavNamespace &&
          element.name.local == 'calendar-data')
        {
          if (element.getAttribute('content-type') case final value?)
            'contentType': value,
          if (element.getAttribute('version') case final value?)
            'version': value,
        },
  ];
}

String? _textProperty(DavProperty? property) {
  final value = property?.text.trim();
  return value == null || value.isEmpty ? null : value;
}

int? _integerProperty(DavProperty? property) =>
    int.tryParse(_textProperty(property) ?? '');

Iterable<String> _hrefChildren(DavProperty? property) sync* {
  if (property == null) return;
  for (final element in property.element.descendantElements) {
    if (element.name.namespaceUri == davNamespace &&
        element.name.local == 'href') {
      final value = element.innerText.trim();
      if (value.isNotEmpty) yield value;
    }
  }
}

String? _rawHref(DavProperty? property) => _hrefChildren(property).firstOrNull;

bool _sameRequestTarget(Uri left, Uri? right) =>
    right != null && left.path == right.path;

String _fallbackDisplayName(String hrefKey) =>
    hrefKey.split('/').where((part) => part.isNotEmpty).lastOrNull ??
    'Calendar';

Map<String, String> _safeDisplayMetadata(DavMultistatusResponse response) {
  final result = <String, String>{};
  for (final name in ['owner-display-name', 'calendar-enabled']) {
    final value = _textProperty(
      response.successfulProperty(nextcloudNamespace, name),
    );
    if (value != null && value.length <= 512) {
      result[name] = value;
    }
  }
  return result;
}

const _currentPrincipalPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>''';

const _principalPropertiesPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <c:calendar-home-set/><c:calendar-user-address-set/>
    <c:schedule-inbox-URL/><c:schedule-outbox-URL/>
  </d:prop>
</d:propfind>''';

const _calendarHomeInventoryPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
 xmlns:cs="http://calendarserver.org/ns/" xmlns:a="http://apple.com/ns/ical/"
 xmlns:nc="http://nextcloud.com/ns">
  <d:prop>
    <d:resourcetype/><d:displayname/><d:owner/>
    <d:current-user-privilege-set/><d:supported-report-set/><d:sync-token/>
    <c:supported-calendar-component-set/><c:supported-calendar-data/>
    <c:calendar-description/><c:calendar-timezone/><c:calendar-timezone-id/>
    <c:schedule-calendar-transp/><c:max-resource-size/><c:max-instances/>
    <cs:getctag/><a:calendar-color/><a:calendar-order/>
    <nc:owner-display-name/><nc:calendar-enabled/>
  </d:prop>
</d:propfind>''';

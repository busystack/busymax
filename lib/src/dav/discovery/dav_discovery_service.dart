import 'package:xml/xml.dart';

import '../../providers/provider_capabilities.dart';
import '../../providers/busy_provider.dart';
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
    _transport.setServerFeatures(serviceCapabilities.serverFeatures);

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
      principal: principalHref,
    );
    final contexts = <DavPrincipalContext>[
      _principalContext(
        principalHref,
        calendarHome,
        addresses,
        inbox,
        outbox,
        inventory,
        false,
        inventoryResponse.requestUri,
        correlationId,
      ),
    ];
    if (_profile.provider == BusyProvider.nextcloud &&
        serviceCapabilities.serverFeatures.contains('calendar-proxy')) {
      final principals = <String, Uri>{};
      for (final name in [
        'calendar-proxy-read-for',
        'calendar-proxy-write-for',
      ]) {
        for (final response in principalProperties.responses) {
          for (final stat in response.propstats) {
            if (stat.property(calendarServerNamespace, name) != null &&
                !stat.isSuccessful &&
                stat.statusCode != 404)
              throw _incompleteInventory();
          }
          for (final href in _hrefChildren(
            response.successfulProperty(calendarServerNamespace, name),
          )) {
            final uri = resolveDavHref(
              href: href,
              responseRequestUri: homeResponse.requestUri,
              profile: _profile,
              accountAuthority: _accountAuthority,
              correlationId: correlationId,
            );
            if (!_sameRequestTarget(uri, principalHref))
              principals[normalizedDavHrefKey(_profile.provider, uri)] = uri;
          }
        }
      }
      if (principals.length > 32) throw _incompleteInventory();
      for (final principal in principals.values) {
        final response = await _propfind(
          uri: principal,
          depth: '0',
          body: _principalPropertiesPropfind,
          correlationId: correlationId,
          cancellationToken: cancellationToken,
        );
        final properties = _xmlParser.parseMultistatus(
          response.bodyBytes,
          correlationId: correlationId,
        );
        final homes = _validatedHrefs(
          properties,
          caldavNamespace,
          'calendar-home-set',
          response.requestUri,
          correlationId,
        );
        if (homes.isEmpty || homes.length > 32) throw _incompleteInventory();
        final delegatedAddresses = _calendarAddressListProperty(
          properties,
          caldavNamespace,
          'calendar-user-address-set',
          responseUri: response.requestUri,
          correlationId: correlationId,
        );
        final delegatedInbox = _optionalHrefProperty(
          properties,
          caldavNamespace,
          'schedule-inbox-URL',
          responseUri: response.requestUri,
          correlationId: correlationId,
        );
        final delegatedOutbox = _optionalHrefProperty(
          properties,
          caldavNamespace,
          'schedule-outbox-URL',
          responseUri: response.requestUri,
          correlationId: correlationId,
        );
        for (final home in homes) {
          final listed = await _propfind(
            uri: home,
            depth: '1',
            body: _calendarHomeInventoryPropfind,
            correlationId: correlationId,
            cancellationToken: cancellationToken,
          );
          final entries = _xmlParser.parseMultistatus(
            listed.bodyBytes,
            correlationId: correlationId,
          );
          final discovered = _parseCollections(
            entries,
            responseUri: listed.requestUri,
            home: home,
            inbox: delegatedInbox,
            outbox: delegatedOutbox,
            correlationId: correlationId,
            principal: principal,
            delegated: true,
          );
          contexts.add(
            _principalContext(
              principal,
              home,
              delegatedAddresses,
              delegatedInbox,
              delegatedOutbox,
              entries,
              true,
              listed.requestUri,
              correlationId,
            ),
          );
          for (final collection in discovered) {
            if (!collections.any(
              (existing) => existing.hrefKey == collection.hrefKey,
            ))
              collections.add(collection);
          }
        }
      }
    }
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
        principalContexts: List.unmodifiable(contexts),
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

  List<Uri> _validatedHrefs(
    DavMultistatus data,
    String namespace,
    String name,
    Uri responseUri,
    String correlationId,
  ) => [
    for (final response in data.responses)
      for (final href in _hrefChildren(
        response.successfulProperty(namespace, name),
      ))
        resolveDavHref(
          href: href,
          responseRequestUri: responseUri,
          profile: _profile,
          accountAuthority: _accountAuthority,
          correlationId: correlationId,
        ),
  ];

  DavPrincipalContext _principalContext(
    Uri principal,
    Uri home,
    List<Uri> addresses,
    Uri? inbox,
    Uri? outbox,
    DavMultistatus inventory,
    bool delegated,
    Uri responseUri,
    String correlationId,
  ) {
    Set<String> privileges(Uri? target) {
      if (target == null) return const {};
      for (final entry in inventory.responses) {
        final uri = resolveDavHref(
          href: entry.href,
          responseRequestUri: responseUri,
          profile: _profile,
          accountAuthority: _accountAuthority,
          correlationId: correlationId,
        );
        if (_sameRequestTarget(uri, target))
          return _privilegeNames(
            entry.successfulProperty(
              davNamespace,
              'current-user-privilege-set',
            ),
          );
      }
      return const {};
    }

    return DavPrincipalContext(
      principalHref: principal,
      calendarHomeHref: home,
      calendarUserAddresses: addresses,
      scheduleInboxHref: inbox,
      scheduleOutboxHref: outbox,
      scheduleDefaultCalendarHref: _optionalHrefProperty(
        inventory,
        caldavNamespace,
        'schedule-default-calendar-URL',
        responseUri: responseUri,
        correlationId: correlationId,
      ),
      homePrivileges: privileges(home),
      outboxPrivileges: privileges(outbox),
      delegated: delegated,
    );
  }

  DavException _incompleteInventory() => const DavException(
    kind: DavErrorKind.protocol,
    code: 'DavIncompleteInventory',
    safeMessage:
        'DAV discovery was incomplete. Cached sources have been retained.',
  );

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
    required Uri principal,
    bool delegated = false,
  }) {
    final result = <DavCollectionDiscovery>[];
    if (inventory.responses.isEmpty || inventory.errorConditions.isNotEmpty)
      throw _incompleteInventory();
    final homeKey = normalizedDavHrefKey(_profile.provider, home);
    final homePrivileges = <String>{};
    for (final response in inventory.responses) {
      final target = resolveDavHref(
        href: response.href,
        responseRequestUri: responseUri,
        profile: _profile,
        accountAuthority: _accountAuthority,
        correlationId: correlationId,
      );
      if (normalizedDavHrefKey(_profile.provider, target) == homeKey)
        homePrivileges.addAll(
          _privilegeNames(
            response.successfulProperty(
              davNamespace,
              'current-user-privilege-set',
            ),
          ),
        );
    }
    for (final response in inventory.responses) {
      final responseStatus = response.statusCode;
      if (response.isMissing ||
          (responseStatus != null && responseStatus >= 400)) {
        throw _incompleteInventory();
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
      if (response.successfulProperty(davNamespace, 'resourcetype') == null)
        throw _incompleteInventory();
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
      final isTrash = resourceTypes.contains(
        _name(nextcloudNamespace, 'trash-bin'),
      );
      final isDeletedCalendar = resourceTypes.contains(
        _name(nextcloudNamespace, 'deleted-calendar'),
      );
      if (!isCalendar &&
          !isInbox &&
          !isOutbox &&
          !isSubscribed &&
          !isTrash &&
          !isDeletedCalendar) {
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
      final contentResource =
          !isSubscribed &&
          !isTrash &&
          !isDeletedCalendar &&
          !isInbox &&
          !isOutbox;
      final capabilities = CollectionCapabilities(
        canRead:
            hasAggregateAll || privileges.contains(_name(davNamespace, 'read')),
        canReadPrivileges:
            hasAggregateAll ||
            privileges.contains(
              _name(davNamespace, 'read-current-user-privilege-set'),
            ),
        canWriteContent:
            contentResource &&
            (hasAggregateWrite ||
                privileges.contains(_name(davNamespace, 'write-content'))),
        canWriteProperties:
            hasAggregateWrite ||
            privileges.contains(_name(davNamespace, 'write-properties')),
        canAddMembers:
            contentResource &&
            (hasAggregateWrite ||
                privileges.contains(_name(davNamespace, 'bind'))),
        canDeleteMembers:
            contentResource &&
            (hasAggregateWrite ||
                privileges.contains(_name(davNamespace, 'unbind'))),
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
      final kind = isTrash
          ? DavCollectionKind.trashBin
          : isDeletedCalendar
          ? DavCollectionKind.deletedCalendar
          : _classify(
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
          principalHref: principal,
          calendarHomeHref: home,
          delegated: delegated,
          parentPrivileges: Set.unmodifiable(homePrivileges),
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
              !isTrash &&
              !isDeletedCalendar &&
              capabilities.canRead &&
              _profile.calendarEnabled &&
              supportsEvents,
          taskProjectionEnabled:
              !isInbox &&
              !isOutbox &&
              !isTrash &&
              !isDeletedCalendar &&
              capabilities.canRead &&
              _profile.tasksEnabled &&
              supportsTasks,
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
  for (final name in [
    'owner-display-name',
    'deleted-at',
    'calendar-uri',
    'source-calendar-uri',
    'trash-bin-retention-duration',
  ]) {
    final value = _textProperty(
      response.successfulProperty(nextcloudNamespace, name),
    );
    if (value != null && value.length <= 512) {
      result[name] = value;
    }
  }
  final enabled = _textProperty(
    response.successfulProperty(owncloudNamespace, 'calendar-enabled'),
  );
  if (enabled != null) result['calendar-enabled'] = enabled;
  for (final (namespace, name) in [
    (owncloudNamespace, 'invite'),
    (calendarServerNamespace, 'allowed-sharing-modes'),
    (calendarServerNamespace, 'publish-url'),
  ]) {
    final property = response.successfulProperty(namespace, name);
    if (property != null) result[name] = property.element.toXmlString();
  }
  return result;
}

const _currentPrincipalPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>''';

const _principalPropertiesPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/">
  <d:prop>
    <c:calendar-home-set/><c:calendar-user-address-set/>
    <c:schedule-inbox-URL/><c:schedule-outbox-URL/>
    <d:current-user-privilege-set/><cs:calendar-proxy-read-for/><cs:calendar-proxy-write-for/>
  </d:prop>
</d:propfind>''';

const _calendarHomeInventoryPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
 xmlns:cs="http://calendarserver.org/ns/" xmlns:a="http://apple.com/ns/ical/"
 xmlns:nc="http://nextcloud.com/ns" xmlns:oc="http://owncloud.org/ns">
  <d:prop>
    <d:resourcetype/><d:displayname/><d:owner/>
    <d:current-user-privilege-set/><d:supported-report-set/><d:sync-token/>
    <c:supported-calendar-component-set/><c:supported-calendar-data/>
    <c:calendar-description/><c:calendar-timezone/><c:calendar-timezone-id/>
    <c:schedule-calendar-transp/><c:max-resource-size/><c:max-instances/>
    <c:schedule-default-calendar-URL/>
    <cs:getctag/><a:calendar-color/><a:calendar-order/>
    <nc:owner-display-name/><oc:calendar-enabled/>
    <oc:invite/><cs:allowed-sharing-modes/><cs:publish-url/>
    <nc:deleted-at/><nc:calendar-uri/><nc:source-calendar-uri/><nc:trash-bin-retention-duration/>
  </d:prop>
</d:propfind>''';

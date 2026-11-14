import 'package:uuid/uuid.dart';

import '../mutation/dav_collection_mutation_helpers.dart' show davCollectionUri;

import 'dart:async';

import 'package:xml/xml.dart';

import '../../providers/provider_capabilities.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../dav_href.dart';
import '../dav_provider_profile.dart';
import '../http/dav_http_transport.dart';
import '../xml/dav_xml.dart';
import '../xml/dav_propfind_inventory.dart';
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
    this.collectionMethodCache = const {},
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
  final Map<String, (DateTime, bool)> collectionMethodCache;
  final _methodResults = <String, (DateTime, bool)>{};

  Future<DavDiscoveryResult> discover({
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) async {
    final entry = await _discoveryEntry(correlationId, cancellationToken);
    final options = entry.$1;
    final principalResponse = entry.$2;
    final serviceCapabilities = _serviceCapabilities(options);
    final serverFeatures = {...serviceCapabilities.serverFeatures};
    _transport.setServerFeatures(serverFeatures);
    final endpointOptions = <Uri, DavResponse>{};
    final moveCapableCollectionHrefs = <String>{};
    Future<void> probeCollectionMethods(
      DavMultistatus inventory,
      Uri responseUri,
    ) async {
      if (_profile.provider != BusyProvider.caldav) return;
      final probes = <Future<void> Function()>[];
      for (final entry in inventory.responses) {
        final type = entry.successfulProperty(davNamespace, 'resourcetype');
        if (type == null ||
            !type.element.descendantElements.any(
              (e) =>
                  e.name.namespaceUri == caldavNamespace &&
                  e.name.local == 'calendar',
            )) {
          continue;
        }
        if (entry.successfulProperty(davNamespace, 'supported-method-set') !=
            null) {
          continue;
        }
        final target = resolveDavHref(
          href: entry.href,
          responseRequestUri: responseUri,
          profile: _profile,
          accountAuthority: _accountAuthority,
          correlationId: correlationId,
        );
        final key = normalizedDavHrefKey(_profile.provider, target);
        final cached = _methodResults[key] ?? collectionMethodCache[key];
        if (cached != null &&
            !_nowUtc().isBefore(cached.$1) &&
            _nowUtc().difference(cached.$1) < const Duration(hours: 24)) {
          _methodResults[key] = cached;
          if (cached.$2) moveCapableCollectionHrefs.add(key);
          continue;
        }
        probes.add(() async {
          try {
            final response = await _transport.send(
              DavRequest(
                method: 'OPTIONS',
                uri: target,
                accountId: _accountId,
                correlationId: correlationId,
                retryClass: DavRetryClass.safeRead,
              ),
              credential: _credential,
              cancellationToken: cancellationToken,
            );
            if (!const {403, 405, 501}.contains(response.statusCode)) {
              _requireSuccessfulOrDav(response);
            }
            final move =
                response.statusCode >= 200 &&
                response.statusCode < 300 &&
                _allowedMethods(response).contains('MOVE');
            _methodResults[key] = (_nowUtc(), move);
            if (move) moveCapableCollectionHrefs.add(key);
          } on DavException catch (error) {
            if (error.kind == DavErrorKind.authentication ||
                error.kind == DavErrorKind.tls ||
                error.kind == DavErrorKind.cancelled) {
              rethrow;
            }
            // Optional method detection must not prevent readable inventory.
          }
        });
      }
      // Bound optional probes to the DAV account concurrency budget.
      for (var offset = 0; offset < probes.length; offset += 4) {
        await Future.wait(probes.skip(offset).take(4).map((probe) => probe()));
      }
    }

    final inventories = <String, DavMultistatus>{};
    var inventoryRequests = 0;
    Future<DavMultistatus> inventoryAt(Uri home, [int depth = 0]) async {
      cancellationToken?.throwIfCancelled();
      final key = normalizedDavHrefKey(
        _profile.provider,
        davCollectionUri(home),
      );
      if (inventories[key] case final cached?) return cached;
      if (depth > 8 || ++inventoryRequests > 256) throw _incompleteInventory();
      final response = await _propfind(
        uri: home,
        depth: '1',
        body: _calendarHomeInventoryPropfind,
        correlationId: correlationId,
        cancellationToken: cancellationToken,
      );
      final data = parseDavPropfindInventory(
        _xmlParser,
        response.bodyBytes,
        correlationId: correlationId,
      );
      final entries = <String, DavMultistatusResponse>{};
      for (final entry in data.responses) {
        final target = resolveDavHref(
          href: entry.href,
          responseRequestUri: response.requestUri,
          profile: _profile,
          accountAuthority: _accountAuthority,
          correlationId: correlationId,
        );
        final targetKey = normalizedDavHrefKey(
          _profile.provider,
          davCollectionUri(target),
        );
        if (entries.containsKey(targetKey) ||
            entry.successfulProperty(davNamespace, 'resourcetype') == null) {
          throw _incompleteInventory();
        }
        if (targetKey != key) {
          final prefix = davCollectionUri(home).path;
          final path = davCollectionUri(target).path;
          if (!path.startsWith(prefix) ||
              path
                      .substring(prefix.length)
                      .split('/')
                      .where((v) => v.isNotEmpty)
                      .length !=
                  1) {
            throw _incompleteInventory();
          }
        }
        entries[targetKey] = DavMultistatusResponse(
          href: target.toString(),
          propstats: entry.propstats,
          statusCode: entry.statusCode,
          reasonPhrase: entry.reasonPhrase,
          errorConditions: entry.errorConditions,
        );
      }
      final self = entries[key];
      if (self == null) throw _incompleteInventory();
      final selfTypes = _nestedNames(
        self.successfulProperty(davNamespace, 'resourcetype'),
      );
      if (!selfTypes.contains(_name(davNamespace, 'collection'))) {
        throw _incompleteInventory();
      }
      // A calendar-home-set may name the calendar itself. Its object members
      // are not child collections to discover.
      if (!selfTypes.contains(_name(caldavNamespace, 'calendar'))) {
        for (final entry in entries.values.toList()) {
          final target = Uri.parse(entry.href);
          if (_sameRequestTarget(target, home)) continue;
          final types = _nestedNames(
            entry.successfulProperty(davNamespace, 'resourcetype'),
          );
          if (types.length == 1 &&
              types.contains(_name(davNamespace, 'collection'))) {
            final nested = await inventoryAt(target, depth + 1);
            for (final child in nested.responses) {
              final childKey = normalizedDavHrefKey(
                _profile.provider,
                davCollectionUri(Uri.parse(child.href)),
              );
              entries[childKey] = child;
            }
          }
        }
      }
      final result = DavMultistatus(
        responses: entries.values.toList(),
        syncToken: data.syncToken,
        errorConditions: data.errorConditions,
      );
      inventories[key] = result;
      return result;
    }

    Future<DavEndpointCapabilities> capabilitiesAt(
      Uri target,
      DavMultistatus properties,
    ) async {
      if (_profile.provider != BusyProvider.nextcloud &&
          _profile.provider != BusyProvider.caldav) {
        return DavEndpointCapabilities(href: target);
      }
      final response = endpointOptions[target] ??= await _transport.send(
        DavRequest(
          method: 'OPTIONS',
          uri: target,
          accountId: _accountId,
          correlationId: correlationId,
          retryClass: DavRetryClass.safeRead,
        ),
        credential: _credential,
        cancellationToken: cancellationToken,
      );
      _requireSuccessfulOrDav(response);
      final features = _serviceCapabilities(response).serverFeatures;
      serverFeatures.addAll(features);
      _transport.setServerFeatures(serverFeatures);
      return DavEndpointCapabilities(
        href: target,
        serverFeatures: features,
        allowedMethods: _allowedMethods(response),
        supportedReports: {
          for (final entry in properties.responses)
            if (_sameRequestTarget(
              resolveDavHref(
                href: entry.href,
                responseRequestUri: target,
                profile: _profile,
                accountAuthority: _accountAuthority,
                correlationId: correlationId,
              ),
              target,
            ))
              ..._reportNames(
                entry.successfulProperty(davNamespace, 'supported-report-set'),
              ),
        },
      );
    }

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

    final principalCapabilities = await capabilitiesAt(
      principalHref,
      principalProperties,
    );
    // Calendar plugins need not be registered at the generic DAV root.
    // Negotiate before inventory so extensions also apply to this first read.
    await capabilitiesAt(
      calendarHome,
      const DavMultistatus(responses: [], syncToken: null, errorConditions: {}),
    );

    final inventory = await inventoryAt(calendarHome);
    await probeCollectionMethods(inventory, calendarHome);
    final collections = _parseCollections(
      inventory,
      moveCapableCollectionHrefs: moveCapableCollectionHrefs,
      responseUri: calendarHome,
      home: calendarHome,
      supportsMove:
          endpointOptions[calendarHome] != null &&
          _allowedMethods(endpointOptions[calendarHome]!).contains('MOVE'),
      inbox: inbox,
      outbox: outbox,
      correlationId: correlationId,
      principal: principalHref,
    );
    final contexts = <DavPrincipalContext>[
      await _principalContext(
        principalHref,
        calendarHome,
        addresses,
        inbox,
        outbox,
        inventory,
        false,
        calendarHome,
        correlationId,
        principalProperties,
        [principalCapabilities, await capabilitiesAt(calendarHome, inventory)],
        cancellationToken,
      ),
    ];
    // A principal may advertise more than one home. Keep the first as the
    // account's established creation home, but inventory every returned home.
    final ownHomes = _validatedHrefs(
      principalProperties,
      caldavNamespace,
      'calendar-home-set',
      homeResponse.requestUri,
      correlationId,
    );
    if (ownHomes.length > 32) throw _incompleteInventory();
    for (final home in ownHomes.where(
      (home) => !_sameRequestTarget(home, calendarHome),
    )) {
      await capabilitiesAt(
        home,
        const DavMultistatus(
          responses: [],
          syncToken: null,
          errorConditions: {},
        ),
      );
      final entries = await inventoryAt(home);
      await probeCollectionMethods(entries, home);
      final discovered = _parseCollections(
        entries,
        moveCapableCollectionHrefs: moveCapableCollectionHrefs,
        responseUri: home,
        home: home,
        supportsMove:
            endpointOptions[home] != null &&
            _allowedMethods(endpointOptions[home]!).contains('MOVE'),
        inbox: inbox,
        outbox: outbox,
        correlationId: correlationId,
        principal: principalHref,
      );
      contexts.add(
        await _principalContext(
          principalHref,
          home,
          addresses,
          inbox,
          outbox,
          entries,
          false,
          home,
          correlationId,
          principalProperties,
          [principalCapabilities, await capabilitiesAt(home, entries)],
          cancellationToken,
        ),
      );
      for (final collection in discovered) {
        if (!collections.any(
          (existing) => existing.hrefKey == collection.hrefKey,
        )) {
          collections.add(collection);
        }
      }
    }
    if (_profile.provider == BusyProvider.nextcloud &&
        serverFeatures.contains('calendar-proxy')) {
      final principals = <String, Uri>{};
      for (final name in [
        'calendar-proxy-read-for',
        'calendar-proxy-write-for',
      ]) {
        for (final response in principalProperties.responses) {
          for (final stat in response.propstats) {
            if (stat.property(calendarServerNamespace, name) != null &&
                !stat.isSuccessful &&
                stat.statusCode != 404) {
              throw _incompleteInventory();
            }
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
            if (!_sameRequestTarget(uri, principalHref)) {
              principals[normalizedDavHrefKey(_profile.provider, uri)] = uri;
            }
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
        final delegatedCapabilities = await capabilitiesAt(
          principal,
          properties,
        );
        for (final home in homes) {
          await capabilitiesAt(
            home,
            const DavMultistatus(
              responses: [],
              syncToken: null,
              errorConditions: {},
            ),
          );
          final entries = await inventoryAt(home);
          await probeCollectionMethods(entries, home);
          final discovered = _parseCollections(
            entries,
            moveCapableCollectionHrefs: moveCapableCollectionHrefs,
            responseUri: home,
            home: home,
            inbox: delegatedInbox,
            outbox: delegatedOutbox,
            correlationId: correlationId,
            principal: principal,
            delegated: true,
          );
          contexts.add(
            await _principalContext(
              principal,
              home,
              delegatedAddresses,
              delegatedInbox,
              delegatedOutbox,
              entries,
              true,
              home,
              correlationId,
              properties,
              [delegatedCapabilities, await capabilitiesAt(home, entries)],
              cancellationToken,
            ),
          );
          for (final collection in discovered) {
            if (!collections.any(
              (existing) => existing.hrefKey == collection.hrefKey,
            )) {
              collections.add(collection);
            }
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
          supportedReports: {
            for (final context in contexts)
              for (final endpoint in context.endpointCapabilities)
                ...endpoint.supportedReports,
          },
          serverFeatures: Set.unmodifiable(serverFeatures),
        ),
        discoveredAtUtc: now,
        lastValidatedAtUtc: now,
        providerProfileVersion: davProviderProfileVersion,
        principalContexts: List.unmodifiable(contexts),
        allowedMethods: _allowedMethods(options),
      ),
      collections: List.unmodifiable(collections),
    );
  }

  Future<(DavResponse, DavResponse)> _discoveryEntry(
    String correlationId,
    DavCancellationToken? cancellationToken,
  ) async {
    Future<DavResponse> optionsAt(Uri uri, {bool redirect = false}) =>
        _transport.send(
          DavRequest(
            method: 'OPTIONS',
            uri: uri,
            accountId: _accountId,
            correlationId: correlationId,
            retryClass: DavRetryClass.safeRead,
            redirectPolicy: redirect
                ? DavRedirectPolicy.discovery
                : DavRedirectPolicy.none,
          ),
          credential: _credential,
          cancellationToken: cancellationToken,
        );
    if (_profile.provider != BusyProvider.caldav) {
      final options = await optionsAt(
        davWellKnownUri(_profile),
        redirect: true,
      );
      _requireSuccessfulOrDav(options);
      _transport.setServerFeatures(
        _serviceCapabilities(options).serverFeatures,
      );
      return (
        options,
        await _propfind(
          uri: options.requestUri,
          depth: '0',
          body: _currentPrincipalPropfind,
          correlationId: correlationId,
          cancellationToken: cancellationToken,
        ),
      );
    }
    // RFC 6764's well-known resource is at the HTTP origin. An explicit
    // endpoint remains usable when that optional redirect is not configured.
    final bootstrap = _profile.bootstrapUri;
    // A supplied path selects an installation. An HTML landing page may use
    // origin well-known only when its validated redirect stays in that path.
    final candidates = bootstrap.path.isNotEmpty && bootstrap.path != '/'
        ? {bootstrap}
        : {davWellKnownUri(_profile), bootstrap};
    for (final uri in candidates) {
      var response = uri == davWellKnownUri(_profile)
          ? await _wellKnownPrincipal(correlationId, cancellationToken)
          : await _propfind(
              uri: uri,
              depth: '0',
              body: _currentPrincipalPropfind,
              requireMultistatus: false,
              correlationId: correlationId,
              cancellationToken: cancellationToken,
            );
      if (bootstrap.path.isNotEmpty &&
          bootstrap.path != '/' &&
          response.statusCode == 200) {
        final located = await _wellKnownPrincipal(
          correlationId,
          cancellationToken,
        );
        if (located.requestUri.origin == bootstrap.origin &&
            located.requestUri.path.startsWith(
              davCollectionUri(bootstrap).path,
            )) {
          response = located;
        }
      }
      final hasFallback = uri != candidates.last;
      if (hasFallback &&
          (const {403, 404, 405, 410, 501}.contains(response.statusCode) ||
              (response.statusCode >= 200 &&
                  response.statusCode < 300 &&
                  response.statusCode != 207))) {
        // An installation landing page or misconfigured well-known resource
        // can return ordinary successful HTML. It is not a DAV entry point;
        // the other same-origin candidate must still prove a complete inventory.
        continue;
      }
      _requireMultistatus(response);
      final properties = _xmlParser.parseMultistatus(
        response.bodyBytes,
        correlationId: correlationId,
      );
      // Validate the mandatory principal reference before accepting the entry.
      final principal = _optionalHrefProperty(
        properties,
        davNamespace,
        'current-user-principal',
        responseUri: response.requestUri,
        correlationId: correlationId,
      );
      if (principal == null && hasFallback) continue;
      _requiredHrefProperty(
        properties,
        davNamespace,
        'current-user-principal',
        responseUri: response.requestUri,
        correlationId: correlationId,
      );
      final options = await optionsAt(response.requestUri);
      _requireSuccessfulOrDav(options);
      return (options, response);
    }
    throw _incompleteInventory();
  }

  /// RFC 6764 bootstrapping resolves the service with a retrieval request.
  /// In particular a 303 is never a reason to replay PROPFIND. The pinned
  /// transport owns HTTPS/origin validation, bounds, loops and cancellation.
  Future<DavResponse> _wellKnownPrincipal(
    String correlationId,
    DavCancellationToken? cancellationToken,
  ) async {
    final response = await _transport.send(
      DavRequest(
        method: 'HEAD',
        uri: davWellKnownUri(_profile),
        accountId: _accountId,
        correlationId: correlationId,
        retryClass: DavRetryClass.safeRead,
        redirectPolicy: DavRedirectPolicy.discovery,
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    final bootstrap = _profile.bootstrapUri;
    final endpoint = response.requestUri;
    if (bootstrap.path.isNotEmpty &&
        bootstrap.path != '/' &&
        endpoint.path != bootstrap.path &&
        !endpoint.path.startsWith(davCollectionUri(bootstrap).path)) {
      throw DavException(
        kind: DavErrorKind.redirectRejected,
        code: 'DavDiscoveryInstallationRedirectRejected',
        safeMessage: 'The DAV service is outside the selected installation.',
        correlationId: correlationId,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode != 405) return response;
    }
    return _propfind(
      uri: endpoint,
      depth: '0',
      body: _currentPrincipalPropfind,
      requireMultistatus: false,
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
  }

  Future<DavResponse> _propfind({
    required Uri uri,
    required String depth,
    required String body,
    required String correlationId,
    required DavCancellationToken? cancellationToken,
    bool requireMultistatus = true,
  }) async {
    final response = await _transport.send(
      DavRequest.xml(
        method: 'PROPFIND',
        uri: uri,
        accountId: _accountId,
        correlationId: correlationId,
        body: body,
        headers: {'depth': depth},
        redirectPolicy: DavRedirectPolicy.discovery,
      ),
      credential: _credential,
      cancellationToken: cancellationToken,
    );
    if (requireMultistatus) _requireMultistatus(response);
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

  Future<DavPrincipalContext> _principalContext(
    Uri principal,
    Uri home,
    List<Uri> addresses,
    Uri? inbox,
    Uri? outbox,
    DavMultistatus inventory,
    bool delegated,
    Uri responseUri,
    String correlationId,
    DavMultistatus principalProperties,
    List<DavEndpointCapabilities> endpointCapabilities,
    DavCancellationToken? cancellationToken,
  ) async {
    Set<String>? privileges(Uri? target, DavMultistatus data, Uri base) {
      if (target == null) return const {};
      for (final entry in data.responses) {
        final uri = resolveDavHref(
          href: entry.href,
          responseRequestUri: base,
          profile: _profile,
          accountAuthority: _accountAuthority,
          correlationId: correlationId,
        );
        if (_sameRequestTarget(uri, target)) {
          final property = entry.successfulProperty(
            davNamespace,
            'current-user-privilege-set',
          );
          if (property == null) return null;
          return _privilegeNames(property);
        }
      }
      return null;
    }

    var outboxPrivileges = privileges(outbox, inventory, responseUri);
    if (_profile.provider == BusyProvider.nextcloud &&
        outbox != null &&
        outboxPrivileges == null) {
      // Outboxes are not necessarily children of this home inventory. Inspect
      // only this principal's advertised target; another identity cannot lend
      // its scheduling privileges to this context.
      try {
        final response = await _propfind(
          uri: outbox,
          depth: '0',
          body: '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-privilege-set/></d:prop></d:propfind>',
          correlationId: correlationId,
          cancellationToken: cancellationToken,
        );
        outboxPrivileges = privileges(
          outbox,
          _xmlParser.parseMultistatus(
            response.bodyBytes,
            correlationId: correlationId,
          ),
          response.requestUri,
        );
      } on DavException catch (error) {
        if (error.statusCode != 403 && error.statusCode != 404) rethrow;
        outboxPrivileges = const {};
      }
    }

    final directCalendar = inventory.responses.any(
      (entry) =>
          _sameRequestTarget(Uri.parse(entry.href), home) &&
          _nestedNames(entry.successfulProperty(davNamespace, 'resourcetype'))
              .contains(_name(caldavNamespace, 'calendar')),
    );
    final creationMethods = <String>{};
    var creationCapability = DavCollectionCreationCapability.unknown;
    if (!directCalendar && _profile.provider == BusyProvider.caldav) {
      for (final endpoint in endpointCapabilities.where(
        (e) => e.href == home,
      )) {
        if (endpoint.allowedMethods.contains('MKCALENDAR')) {
          creationMethods.add('MKCALENDAR');
        }
        if (endpoint.allowedMethods.contains('MKCOL') &&
            endpoint.serverFeatures.contains('extended-mkcol')) {
          creationMethods.add('MKCOL');
        }
      }
    }
    if (!directCalendar &&
        _profile.provider == BusyProvider.caldav &&
        creationMethods.isEmpty) {
      // Allow is resource-specific: an existing home need not advertise methods
      // that create a new child (RFC 9110). Probe a fresh child, never mutate it.
      final target = davCollectionUri(home)
          .resolve('busymax-options-${const Uuid().v4()}/');
      try {
        final response = await _transport.send(
          DavRequest(
            method: 'OPTIONS',
            uri: target,
            accountId: _accountId,
            correlationId: correlationId,
            retryClass: DavRetryClass.safeRead,
          ),
          credential: _credential,
          cancellationToken: cancellationToken,
        );
        if (response.statusCode == 401) _requireSuccessfulOrDav(response);
        // A 405 refuses OPTIONS, but its required Allow field still describes
        // this target's methods (RFC 9110 section 15.5.6), even when empty.
        final hasMethodEvidence =
            response.headers.containsKey('allow') &&
            (response.statusCode == 405 ||
                response.statusCode >= 200 && response.statusCode < 300);
        if (response.statusCode == 403) {
          creationCapability = DavCollectionCreationCapability.denied;
        } else if (hasMethodEvidence) {
          creationCapability = DavCollectionCreationCapability.unsupported;
        }
        if (hasMethodEvidence) {
          final methods = _allowedMethods(response);
          if (methods.contains('MKCALENDAR')) creationMethods.add('MKCALENDAR');
          if (methods.contains('MKCOL') &&
              _serviceCapabilities(response).serverFeatures
                  .contains('extended-mkcol')) {
            creationMethods.add('MKCOL');
          }
        }
      } on DavException catch (error) {
        if (error.kind == DavErrorKind.authentication ||
            error.kind == DavErrorKind.tls ||
            error.kind == DavErrorKind.cancelled) {
          rethrow;
        }
        // Optional creation hints cannot hide readable calendars.
      }
    }
    return DavPrincipalContext(
      principalHref: principal,
      calendarHomeHref: home,
      calendarUserAddresses: addresses,
      scheduleInboxHref: inbox,
      scheduleOutboxHref: outbox,
      scheduleDefaultCalendarHref: _optionalHrefProperty(
        principalProperties,
        caldavNamespace,
        'schedule-default-calendar-URL',
        responseUri: principal,
        correlationId: correlationId,
      ),
      calendarHomeIsCalendar: directCalendar,
      collectionCreationCapability: directCalendar
          ? DavCollectionCreationCapability.unsupported
          : creationCapability,
      collectionCreationMethods: _profile.provider == BusyProvider.caldav
          ? creationMethods
          : null,
      homePrivileges: directCalendar
          ? const {}
          : privileges(home, inventory, responseUri) ?? const {},
      homePrivilegesKnown:
          !directCalendar && privileges(home, inventory, responseUri) != null,
      outboxPrivileges: outboxPrivileges ?? const {},
      inboxPrivileges: privileges(inbox, inventory, responseUri) ?? const {},
      inboxPrivilegesKnown: privileges(inbox, inventory, responseUri) != null,
      endpointCapabilities: endpointCapabilities,
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
    return AccountServiceCapabilities(
      hasPrincipal: true,
      hasCalendarHome: true,
      serverFeatures: davTokens,
    );
  }

  Set<String> _allowedMethods(DavResponse response) =>
      (response.headers['allow'] ?? '')
          .split(',')
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toSet();

  List<DavCollectionDiscovery> _parseCollections(
    DavMultistatus inventory, {
    required Uri responseUri,
    required Uri home,
    required Uri? inbox,
    required Uri? outbox,
    required String correlationId,
    required Uri principal,
    bool delegated = false,
    bool supportsMove = false,
    Set<String> moveCapableCollectionHrefs = const {},
  }) {
    final result = <DavCollectionDiscovery>[];
    if (inventory.responses.isEmpty || inventory.errorConditions.isNotEmpty) {
      throw _incompleteInventory();
    }
    final homeKey = normalizedDavHrefKey(_profile.provider, home);
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
      final resourceTypes = _nestedNames(
        response.successfulProperty(davNamespace, 'resourcetype'),
      );
      if (response.successfulProperty(davNamespace, 'resourcetype') == null) {
        throw _incompleteInventory();
      }
      final isCalendar = resourceTypes.contains(
        _name(caldavNamespace, 'calendar'),
      );
      if (hrefKey == homeKey && !isCalendar) continue;
      final parentUri = davCollectionUri(requestUri).resolve('..');
      DavMultistatusResponse? parent;
      if (hrefKey != homeKey) {
        for (final candidate in inventory.responses) {
          if (_sameRequestTarget(Uri.parse(candidate.href), parentUri)) {
            parent = candidate;
          }
        }
      }
      final parentProperty = parent?.successfulProperty(
        davNamespace,
        'current-user-privilege-set',
      );
      final homePrivileges = _privilegeNames(parentProperty);
      final homePrivilegesKnown = parentProperty != null;
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
      _validateOptionalCollectionProperty(
        response,
        caldavNamespace,
        'supported-calendar-component-set',
      );
      _validateOptionalCollectionProperty(
        response,
        caldavNamespace,
        'supported-calendar-data',
      );
      final componentMask = _componentMask(componentProperty);
      final supportsEvents = componentMask & davComponentEvent != 0;
      final supportsTasks = componentMask & davComponentTodo != 0;
      final reports = _reportNames(
        response.successfulProperty(davNamespace, 'supported-report-set'),
      );
      final privilegeProperty = response.successfulProperty(
        davNamespace,
        'current-user-privilege-set',
      );
      final privilegesKnown = privilegeProperty != null;
      final privileges = _privilegeNames(privilegeProperty);
      final hasAggregateAll = privileges.contains(_name(davNamespace, 'all'));
      final hasAggregateWrite =
          hasAggregateAll || privileges.contains(_name(davNamespace, 'write'));
      final contentResource =
          !isSubscribed &&
          !isTrash &&
          !isDeletedCalendar &&
          !isInbox &&
          !isOutbox;
      final calendarData = isCalendar || isSubscribed
          ? _calendarDataFormats(
              response.successfulProperty(
                caldavNamespace,
                'supported-calendar-data',
              ),
            )
          : const <Map<String, String>>[];
      final advertisedMethods = response.successfulProperty(
        davNamespace,
        'supported-method-set',
      );
      final collectionSupportsMove = advertisedMethods == null
          ? (_profile.provider == BusyProvider.caldav
                ? moveCapableCollectionHrefs.contains(
                    normalizedDavHrefKey(_profile.provider, requestUri),
                  )
                : supportsMove)
          : advertisedMethods.element.descendantElements.any(
              (e) =>
                  e.name.namespaceUri == davNamespace &&
                  e.name.local == 'supported-method' &&
                  e.getAttribute('name')?.toUpperCase() == 'MOVE',
            );
      final capabilities = CollectionCapabilities(
        permissionsKnown: privilegesKnown,
        allowsItemMutations: contentResource,
        supportsMove: contentResource && collectionSupportsMove,
        canRead:
            !privilegesKnown ||
            hasAggregateAll ||
            privileges.contains(_name(davNamespace, 'read')),
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
        supportedCalendarData: calendarData
            .map((entry) => entry['contentType']!)
            .toSet(),
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
          safeDisplayMetadata: {
            ..._safeDisplayMetadata(response),
            'privilegesKnown': '$privilegesKnown',
            'readAccessConfirmed': '${capabilities.canRead}',
            'supportsMove': '${capabilities.supportsMove}',
            if (_methodResults[normalizedDavHrefKey(
                  _profile.provider,
                  requestUri,
                )]
                case final result?)
              'methodProbeAtUtc': result.$1.toUtc().toIso8601String(),
            'parentPrivilegesKnown': '$homePrivilegesKnown',
            if (parent != null) 'parentCollectionHref': parentUri.toString(),
          },
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
    final children = privilege.childElements.toList();
    if (children.length != 1 || children.single.name.namespaceUri == null) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavPrivilegesMalformed',
        safeMessage: 'The server returned malformed privilege information.',
      );
    }
    final child = children.single;
    result.add(_name(child.name.namespaceUri, child.name.local));
  }
  return result;
}

void _validateOptionalCollectionProperty(
  DavMultistatusResponse response,
  String namespace,
  String name,
) {
  for (final stat in response.propstats) {
    if (stat.property(namespace, name) != null &&
        !stat.isSuccessful &&
        stat.statusCode != 404) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCollectionPropertiesIncomplete',
        safeMessage:
            'The server did not return complete collection capabilities.',
      );
    }
  }
}

int _componentMask(DavProperty? property) {
  if (property == null) {
    return davComponentEvent |
        davComponentTodo |
        davComponentJournal |
        davComponentFreeBusy;
  }
  var result = 0;
  final components = property.element.childElements
      .where(
        (element) =>
            element.name.namespaceUri == caldavNamespace &&
            element.name.local == 'comp',
      )
      .toList();
  if (components.isEmpty ||
      components.any((c) => c.getAttribute('name')?.isNotEmpty != true)) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'DavComponentsMalformed',
      safeMessage: 'The server returned malformed component restrictions.',
    );
  }
  for (final component in components) {
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
  if (property == null) {
    return const [
      {'contentType': 'text/calendar', 'version': '2.0'},
    ];
  }
  final formats = [
    for (final element in property.element.descendantElements)
      if (element.name.namespaceUri == caldavNamespace &&
          element.name.local == 'calendar-data')
        {
          'contentType':
              element.getAttribute('content-type') ?? 'text/calendar',
          'version': element.getAttribute('version') ?? '2.0',
        },
  ];
  if (formats.isEmpty ||
      formats.any(
        (f) => f['contentType']?.isNotEmpty != true || f['version'] == '',
      )) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'DavCalendarDataMalformed',
      safeMessage: 'The server returned malformed calendar data formats.',
    );
  }
  if (!formats.any(
    (f) =>
        f['contentType']?.toLowerCase() == 'text/calendar' &&
        (f['version'] == null || f['version'] == '2.0'),
  )) {
    throw const DavException(
      kind: DavErrorKind.unsupportedComponent,
      code: 'DavCalendarDataUnsupported',
      safeMessage: 'The server does not support iCalendar version 2.0.',
    );
  }
  return formats;
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
    <c:schedule-default-calendar-URL/>
    <d:current-user-privilege-set/><d:supported-report-set/><cs:calendar-proxy-read-for/><cs:calendar-proxy-write-for/>
  </d:prop>
</d:propfind>''';

const _calendarHomeInventoryPropfind = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
 xmlns:cs="http://calendarserver.org/ns/" xmlns:a="http://apple.com/ns/ical/"
 xmlns:nc="http://nextcloud.com/ns" xmlns:oc="http://owncloud.org/ns">
  <d:prop>
    <d:resourcetype/><d:displayname/><d:owner/>
    <d:current-user-privilege-set/><d:supported-report-set/><d:supported-method-set/><d:sync-token/>
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

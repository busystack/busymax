import 'package:uuid/uuid.dart';

import '../../providers/provider_capabilities.dart';
import '../dav_errors.dart';
import '../http/dav_http_transport.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../sync/dav_collection_remote_client.dart';
import '../xml/dav_xml.dart';
import 'dav_conflict_analyzer.dart';
import 'dav_mutation_patch.dart';

enum DavConditionalStatus { success, missing, preconditionFailed }

final class DavConditionalResponse {
  const DavConditionalResponse({
    required this.status,
    required this.statusCode,
    required this.etag,
  });

  final DavConditionalStatus status;
  final int statusCode;
  final String? etag;
}

abstract interface class DavMutationRemoteClient {
  Future<DavConditionalResponse> conditionalPut({
    required Uri uri,
    required String rawIcs,
    required String correlationId,
    String? ifMatch,
    bool ifNoneMatch = false,
  });

  Future<DavConditionalResponse> conditionalDelete({
    required Uri uri,
    required String ifMatch,
    required String correlationId,
  });

  Future<DavConditionalResponse> conditionalMove({
    required Uri sourceUri,
    required Uri destinationUri,
    required String ifMatch,
    required String correlationId,
  });

  Future<DavFetchedMember> fetch({
    required String hrefKey,
    required Uri uri,
    required String correlationId,
  });
}

final class DavMutationHttpClient implements DavMutationRemoteClient {
  DavMutationHttpClient({
    required DavHttpTransport transport,
    required String accountId,
    required String collectionId,
    required DavBasicCredential credential,
    DavXmlParser xmlParser = const DavXmlParser(),
  }) : _transport = transport,
       _accountId = accountId,
       _collectionId = collectionId,
       _credential = credential,
       _xmlParser = xmlParser;

  final DavHttpTransport _transport;
  final String _accountId;
  final String _collectionId;
  final DavBasicCredential _credential;
  final DavXmlParser _xmlParser;

  @override
  Future<DavConditionalResponse> conditionalPut({
    required Uri uri,
    required String rawIcs,
    required String correlationId,
    String? ifMatch,
    bool ifNoneMatch = false,
  }) async {
    if ((ifMatch == null) == !ifNoneMatch || ifMatch?.trim().isEmpty == true) {
      throw ArgumentError(
        'A conditional PUT requires exactly one precondition.',
      );
    }
    final response = await _transport.send(
      DavRequest.icalendar(
        method: 'PUT',
        uri: uri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        body: rawIcs,
        headers: {
          if (ifNoneMatch) 'if-none-match': '*',
          if (ifMatch != null) 'if-match': ifMatch,
        },
      ),
      credential: _credential,
    );
    return _conditionalResponse(response, operation: 'update the object');
  }

  @override
  Future<DavConditionalResponse> conditionalDelete({
    required Uri uri,
    required String ifMatch,
    required String correlationId,
  }) async {
    if (ifMatch.trim().isEmpty) {
      throw ArgumentError('A conditional DELETE requires an exact ETag.');
    }
    final response = await _transport.send(
      DavRequest(
        method: 'DELETE',
        uri: uri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: {'if-match': ifMatch},
        retryClass: DavRetryClass.conditionalMutation,
      ),
      credential: _credential,
    );
    return _conditionalResponse(response, operation: 'delete the object');
  }

  @override
  Future<DavConditionalResponse> conditionalMove({
    required Uri sourceUri,
    required Uri destinationUri,
    required String ifMatch,
    required String correlationId,
  }) async {
    if (ifMatch.trim().isEmpty ||
        sourceUri.scheme != destinationUri.scheme ||
        sourceUri.host != destinationUri.host ||
        sourceUri.port != destinationUri.port ||
        sourceUri.userInfo.isNotEmpty ||
        destinationUri.userInfo.isNotEmpty ||
        sourceUri.hasQuery ||
        destinationUri.hasQuery ||
        sourceUri.hasFragment ||
        destinationUri.hasFragment) {
      throw ArgumentError('A DAV MOVE requires valid same-origin resources.');
    }
    final response = await _transport.send(
      DavRequest(
        method: 'MOVE',
        uri: sourceUri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: {
          'destination': destinationUri.toString(),
          'depth': 'infinity',
          'overwrite': 'F',
          'if-match': ifMatch,
        },
        retryClass: DavRetryClass.conditionalMutation,
      ),
      credential: _credential,
    );
    return _conditionalResponse(response, operation: 'move the object');
  }

  @override
  Future<DavFetchedMember> fetch({
    required String hrefKey,
    required Uri uri,
    required String correlationId,
  }) async {
    final response = await _transport.send(
      DavRequest(
        method: 'GET',
        uri: uri,
        accountId: _accountId,
        collectionId: _collectionId,
        correlationId: correlationId,
        headers: const {'accept': 'text/calendar'},
        retryClass: DavRetryClass.safeRead,
      ),
      credential: _credential,
    );
    if (response.statusCode == 404) {
      return DavFetchedMember.missing(hrefKey: hrefKey, requestUri: uri);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mutationException(response, operation: 'fetch the object');
    }
    final etag = response.etag;
    if (etag == null || etag.isEmpty) {
      throw DavException(
        kind: DavErrorKind.protocol,
        code: 'DavMutationFetchMissingEtag',
        safeMessage: 'The DAV object response omitted its ETag.',
        correlationId: correlationId,
      );
    }
    return DavFetchedMember.live(
      hrefKey: hrefKey,
      requestUri: response.requestUri,
      etag: etag,
      contentType: response.headers['content-type'],
      rawIcsBody: response.bodyText,
    );
  }

  DavConditionalResponse _conditionalResponse(
    DavResponse response, {
    required String operation,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return DavConditionalResponse(
        status: DavConditionalStatus.success,
        statusCode: response.statusCode,
        etag: response.etag,
      );
    }
    if (response.statusCode == 404) {
      return DavConditionalResponse(
        status: DavConditionalStatus.missing,
        statusCode: response.statusCode,
        etag: response.etag,
      );
    }
    if (response.statusCode == 412) {
      return DavConditionalResponse(
        status: DavConditionalStatus.preconditionFailed,
        statusCode: response.statusCode,
        etag: response.etag,
      );
    }
    throw _mutationException(response, operation: operation);
  }

  DavException _mutationException(
    DavResponse response, {
    required String operation,
  }) {
    Set<DavPropertyName> conditions = const {};
    if (response.bodyBytes.isNotEmpty) {
      try {
        conditions = _xmlParser.parseDavError(
          response.bodyBytes,
          correlationId: response.correlationId,
        );
      } on DavException {
        // The normal error remains typed by status; raw XML is never exposed.
      }
    }
    bool has(String namespace, String local) =>
        conditions.contains(DavPropertyName(namespace, local));
    final mapped = switch (response.statusCode) {
      401 => (DavErrorKind.authentication, 'DavAuthRejected'),
      403 => (DavErrorKind.authorization, 'DavPermissionDenied'),
      409 when has(caldavNamespace, 'no-uid-conflict') => (
        DavErrorKind.uidConflict,
        'DavUidConflict',
      ),
      409 => (DavErrorKind.conflict, 'DavResourceConflict'),
      423 => (DavErrorKind.conflict, 'DavResourceLocked'),
      429 => (DavErrorKind.rateLimited, 'DavRateLimited'),
      415 => (DavErrorKind.invalidCalendarData, 'DavMalformedResource'),
      507 when has(caldavNamespace, 'max-resource-size') => (
        DavErrorKind.maximumResourceSize,
        'DavMaximumResourceSize',
      ),
      507 => (DavErrorKind.limitExceeded, 'DavQuotaOrSizeLimit'),
      >= 500 => (DavErrorKind.server, 'DavServerUnavailable'),
      _ when has(caldavNamespace, 'valid-calendar-data') => (
        DavErrorKind.invalidCalendarData,
        'DavMalformedResource',
      ),
      _ when has(caldavNamespace, 'supported-calendar-component') => (
        DavErrorKind.unsupportedComponent,
        'DavUnsupportedComponent',
      ),
      _ => (DavErrorKind.protocol, 'DavMutationRejected'),
    };
    return DavException(
      kind: mapped.$1,
      code: mapped.$2,
      safeMessage: 'The DAV server could not $operation.',
      statusCode: response.statusCode,
      correlationId: response.correlationId,
      retryAfter: parseDavRetryAfter(response.headers['retry-after']),
    );
  }
}

enum DavMutationOutcome { succeeded, conflict }

final class DavMutationResult {
  const DavMutationResult._({
    required this.outcome,
    required this.canonicalObject,
    required this.conflict,
    required this.conflictRemoteObject,
    required this.localCandidateRawIcs,
  });

  const DavMutationResult.succeeded(DavFetchedMember? canonicalObject)
    : this._(
        outcome: DavMutationOutcome.succeeded,
        canonicalObject: canonicalObject,
        conflict: null,
        conflictRemoteObject: null,
        localCandidateRawIcs: null,
      );

  const DavMutationResult.conflict(
    DavConflictAnalysis conflict, {
    DavFetchedMember? remoteObject,
    String? localCandidateRawIcs,
  }) : this._(
         outcome: DavMutationOutcome.conflict,
         canonicalObject: null,
         conflict: conflict,
         conflictRemoteObject: remoteObject,
         localCandidateRawIcs: localCandidateRawIcs,
       );

  final DavMutationOutcome outcome;
  final DavFetchedMember? canonicalObject;
  final DavConflictAnalysis? conflict;
  final DavFetchedMember? conflictRemoteObject;
  final String? localCandidateRawIcs;
}

final class DavNewObject {
  const DavNewObject({
    required this.uid,
    required this.initialMemberName,
    required this.rawIcs,
    required this.componentType,
  });

  final String uid;
  final String initialMemberName;
  final String rawIcs;
  final String componentType;
}

final class DavNewObjectFactory {
  DavNewObjectFactory({
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final String Function() _idFactory;
  final DateTime Function() _nowUtc;

  DavNewObject task({
    required String summary,
    String? description,
    String? dueRaw,
    List<IcalParameter> dueParameters = const [],
  }) {
    final uid = '${_idFactory()}@busymax.local';
    final timestamp = _utcIcal(_nowUtc());
    final component = IcalComponent(
      name: 'VTODO',
      children: [
        _newProperty('UID', uid),
        _newProperty('DTSTAMP', timestamp),
        _newProperty('CREATED', timestamp),
        _newProperty('LAST-MODIFIED', timestamp),
        _newProperty('SUMMARY', encodeIcalText(summary)),
        if (description != null)
          _newProperty('DESCRIPTION', encodeIcalText(description)),
        if (dueRaw != null)
          _newProperty('DUE', dueRaw, parameters: dueParameters),
      ],
      originalBeginLine: 'BEGIN:VTODO',
      originalEndLine: 'END:VTODO',
      structurallyDirty: true,
    );
    return DavNewObject(
      uid: uid,
      initialMemberName: '${_idFactory()}.ics',
      rawIcs: IcalDocument.create(components: [component]).serialize(),
      componentType: 'VTODO',
    );
  }

  DavNewObject event({
    required String summary,
    required String startRaw,
    required List<IcalParameter> startParameters,
    String? endRaw,
    List<IcalParameter> endParameters = const [],
    String? durationRaw,
    String? description,
    String? location,
  }) {
    if ((endRaw == null) == (durationRaw == null)) {
      throw ArgumentError('An event requires exactly one of end or duration.');
    }
    final uid = '${_idFactory()}@busymax.local';
    final component = IcalComponent(
      name: 'VEVENT',
      children: [
        _newProperty('UID', uid),
        _newProperty('DTSTAMP', _utcIcal(_nowUtc())),
        _newProperty('DTSTART', startRaw, parameters: startParameters),
        if (endRaw != null)
          _newProperty('DTEND', endRaw, parameters: endParameters),
        if (durationRaw != null) _newProperty('DURATION', durationRaw),
        _newProperty('SUMMARY', encodeIcalText(summary)),
        if (description != null)
          _newProperty('DESCRIPTION', encodeIcalText(description)),
        if (location != null)
          _newProperty('LOCATION', encodeIcalText(location)),
      ],
      originalBeginLine: 'BEGIN:VEVENT',
      originalEndLine: 'END:VEVENT',
      structurallyDirty: true,
    );
    return DavNewObject(
      uid: uid,
      initialMemberName: '${_idFactory()}.ics',
      rawIcs: IcalDocument.create(components: [component]).serialize(),
      componentType: 'VEVENT',
    );
  }
}

final class DavConditionalMutationService {
  DavConditionalMutationService({
    required DavMutationRemoteClient remoteClient,
    DavConflictAnalyzer conflictAnalyzer = const DavConflictAnalyzer(),
    String Function()? memberIdFactory,
    DateTime Function()? nowUtc,
    this.maximumConditionalAttempts = 3,
  }) : _remoteClient = remoteClient,
       _conflictAnalyzer = conflictAnalyzer,
       _memberIdFactory = memberIdFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final DavMutationRemoteClient _remoteClient;
  final DavConflictAnalyzer _conflictAnalyzer;
  final String Function() _memberIdFactory;
  final DateTime Function() _nowUtc;
  final int maximumConditionalAttempts;

  Future<DavMutationResult> create({
    required Uri collectionUri,
    required DavNewObject object,
    required CollectionCapabilities capabilities,
    required String correlationId,
  }) async {
    final allowed = object.componentType == 'VEVENT'
        ? capabilities.canCreateEvent
        : object.componentType == 'VTODO'
        ? capabilities.canCreateTask
        : false;
    if (!allowed) throw _readOnlyError(correlationId);
    var memberName = object.initialMemberName;
    for (var attempt = 0; attempt < maximumConditionalAttempts; attempt += 1) {
      final uri = _memberUri(collectionUri, memberName);
      final hrefKey = uri.path;
      try {
        final response = await _remoteClient.conditionalPut(
          uri: uri,
          rawIcs: object.rawIcs,
          correlationId: correlationId,
          ifNoneMatch: true,
        );
        if (response.status == DavConditionalStatus.preconditionFailed) {
          memberName = '${_memberIdFactory()}.ics';
          continue;
        }
        if (response.status == DavConditionalStatus.missing) continue;
        final canonical = await _remoteClient.fetch(
          hrefKey: hrefKey,
          uri: uri,
          correlationId: correlationId,
        );
        if (!canonical.missing &&
            _sameIntendedObject(object.rawIcs, canonical.rawIcsBody!)) {
          return DavMutationResult.succeeded(canonical);
        }
      } on DavException catch (error) {
        if (!_isUnknownOutcome(error)) rethrow;
        final resolved = await _remoteClient.fetch(
          hrefKey: hrefKey,
          uri: uri,
          correlationId: correlationId,
        );
        if (!resolved.missing) {
          if (_sameIntendedObject(object.rawIcs, resolved.rawIcsBody!)) {
            return DavMutationResult.succeeded(resolved);
          }
          memberName = '${_memberIdFactory()}.ics';
        }
      }
    }
    throw DavException(
      kind: DavErrorKind.conflict,
      code: 'DavCreateCollisionLimitExceeded',
      safeMessage: 'The DAV server could not allocate a new object name.',
      correlationId: correlationId,
    );
  }

  Future<DavMutationResult> update({
    required String hrefKey,
    required Uri uri,
    required String baselineEtag,
    required String baselineRawIcs,
    required DavMutationPatch patch,
    required CollectionCapabilities capabilities,
    required String correlationId,
  }) async {
    final event = patch.target.componentType.toUpperCase() == 'VEVENT';
    if (baselineEtag.isEmpty ||
        (event ? !capabilities.canUpdateEvent : !capabilities.canUpdateTask)) {
      throw _readOnlyError(correlationId);
    }
    var expectedEtag = baselineEtag;
    var comparisonBaseline = baselineRawIcs;
    var candidate = patch.applyTo(baselineRawIcs, nowUtc: _nowUtc());
    DavFetchedMember? lastCurrent;
    for (var attempt = 0; attempt < maximumConditionalAttempts; attempt += 1) {
      try {
        final response = await _remoteClient.conditionalPut(
          uri: uri,
          rawIcs: candidate,
          correlationId: correlationId,
          ifMatch: expectedEtag,
        );
        if (response.status == DavConditionalStatus.success) {
          final canonical = await _remoteClient.fetch(
            hrefKey: hrefKey,
            uri: uri,
            correlationId: correlationId,
          );
          if (!canonical.missing) {
            return DavMutationResult.succeeded(canonical);
          }
        }
      } on DavException catch (error) {
        if (!_isUnknownOutcome(error)) rethrow;
      }

      final current = await _remoteClient.fetch(
        hrefKey: hrefKey,
        uri: uri,
        correlationId: correlationId,
      );
      lastCurrent = current;
      if (current.missing) {
        return DavMutationResult.conflict(
          _resourceMissingConflict(patch.changedProperties),
          remoteObject: current,
          localCandidateRawIcs: candidate,
        );
      }
      if (_sameIntendedObject(candidate, current.rawIcsBody!)) {
        return DavMutationResult.succeeded(current);
      }
      final analysis = _conflictAnalyzer.analyzeUpdate(
        baselineRawIcs: comparisonBaseline,
        currentRemoteRawIcs: current.rawIcsBody!,
        localPatch: patch,
        nowUtc: _nowUtc(),
      );
      if (!analysis.canRetryWithRemoteEtag) {
        return DavMutationResult.conflict(
          analysis,
          remoteObject: current,
          localCandidateRawIcs: candidate,
        );
      }
      expectedEtag = current.etag!;
      comparisonBaseline = current.rawIcsBody!;
      candidate = analysis.mergedRawIcs!;
    }
    return DavMutationResult.conflict(
      _retryLimitConflict(patch.changedProperties),
      remoteObject: lastCurrent,
      localCandidateRawIcs: candidate,
    );
  }

  Future<DavMutationResult> move({
    required String sourceHrefKey,
    required Uri sourceUri,
    required String destinationHrefKey,
    required Uri destinationUri,
    required String baselineEtag,
    required String baselineRawIcs,
    required bool isEvent,
    required CollectionCapabilities sourceCapabilities,
    required CollectionCapabilities destinationCapabilities,
    required String correlationId,
    DavMutationPatch? postMovePatch,
  }) async {
    final canDelete = isEvent
        ? sourceCapabilities.canDeleteEvent
        : sourceCapabilities.canDeleteTask;
    final canCreate = isEvent
        ? destinationCapabilities.canCreateEvent
        : destinationCapabilities.canCreateTask;
    final canUpdate = isEvent
        ? destinationCapabilities.canUpdateEvent
        : destinationCapabilities.canUpdateTask;
    if (baselineEtag.isEmpty ||
        !canDelete ||
        !canCreate ||
        (postMovePatch != null && !canUpdate) ||
        sourceHrefKey == destinationHrefKey ||
        sourceUri.scheme != destinationUri.scheme ||
        sourceUri.host != destinationUri.host ||
        sourceUri.port != destinationUri.port) {
      throw _readOnlyError(correlationId);
    }
    final sourceSemantic = IcalSemanticDocument.parse(baselineRawIcs);
    if (sourceSemantic.components.isEmpty ||
        sourceSemantic.components.first.componentType !=
            (isEvent ? 'VEVENT' : 'VTODO') ||
        (postMovePatch != null &&
            (postMovePatch.target.componentType !=
                    sourceSemantic.components.first.componentType ||
                postMovePatch.target.uid != sourceSemantic.primaryUid))) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'DavMoveObjectInvalid',
        safeMessage: 'The DAV object could not be moved safely.',
      );
    }

    var expectedEtag = baselineEtag;
    var expectedRawIcs = baselineRawIcs;
    DavFetchedMember? lastRemote;
    for (var attempt = 0; attempt < maximumConditionalAttempts; attempt += 1) {
      try {
        final response = await _remoteClient.conditionalMove(
          sourceUri: sourceUri,
          destinationUri: destinationUri,
          ifMatch: expectedEtag,
          correlationId: correlationId,
        );
        if (response.status == DavConditionalStatus.success) {
          final destination = await _remoteClient.fetch(
            hrefKey: destinationHrefKey,
            uri: destinationUri,
            correlationId: correlationId,
          );
          if (!destination.missing &&
              _sameIntendedObject(expectedRawIcs, destination.rawIcsBody!)) {
            return _finishMoveAtDestination(
              destination,
              postMovePatch: postMovePatch,
              destinationCapabilities: destinationCapabilities,
              correlationId: correlationId,
            );
          }
        }
      } on DavException catch (error) {
        if (!_isUnknownOutcome(error)) rethrow;
      }

      final destination = await _remoteClient.fetch(
        hrefKey: destinationHrefKey,
        uri: destinationUri,
        correlationId: correlationId,
      );
      final source = await _remoteClient.fetch(
        hrefKey: sourceHrefKey,
        uri: sourceUri,
        correlationId: correlationId,
      );
      lastRemote = destination.missing ? source : destination;
      if (source.missing) {
        if (destination.missing) {
          return DavMutationResult.conflict(
            _moveConflict('DavConflictMoveSourceRemoved', const {'DELETE'}),
            remoteObject: source,
            localCandidateRawIcs: _moveCandidate(
              expectedRawIcs,
              postMovePatch,
              _nowUtc(),
            ),
          );
        }
        final destinationRaw = destination.rawIcsBody!;
        final alreadyFinal = _sameIntendedObject(
          _moveCandidate(expectedRawIcs, postMovePatch, _nowUtc()),
          destinationRaw,
        );
        if (alreadyFinal) {
          return DavMutationResult.succeeded(destination);
        }
        if (_sameIntendedObject(expectedRawIcs, destinationRaw)) {
          return _finishMoveAtDestination(
            destination,
            postMovePatch: postMovePatch,
            destinationCapabilities: destinationCapabilities,
            correlationId: correlationId,
          );
        }
        return DavMutationResult.conflict(
          _moveConflict('DavConflictMoveDestinationChanged', const {
            'RESOURCE',
          }),
          remoteObject: destination,
          localCandidateRawIcs: _moveCandidate(
            expectedRawIcs,
            postMovePatch,
            _nowUtc(),
          ),
        );
      }
      if (!destination.missing) {
        return DavMutationResult.conflict(
          _moveConflict('DavConflictMoveDestinationExists', const {
            'DESTINATION',
          }),
          remoteObject: destination,
          localCandidateRawIcs: _moveCandidate(
            expectedRawIcs,
            postMovePatch,
            _nowUtc(),
          ),
        );
      }
      if (!_sameIntendedObject(expectedRawIcs, source.rawIcsBody!)) {
        return DavMutationResult.conflict(
          _moveConflict('DavConflictStaleMove', const {'RESOURCE'}),
          remoteObject: source,
          localCandidateRawIcs: _moveCandidate(
            expectedRawIcs,
            postMovePatch,
            _nowUtc(),
          ),
        );
      }
      expectedEtag = source.etag!;
      expectedRawIcs = source.rawIcsBody!;
    }
    return DavMutationResult.conflict(
      _retryLimitConflict(const {'MOVE'}),
      remoteObject: lastRemote,
      localCandidateRawIcs: _moveCandidate(
        expectedRawIcs,
        postMovePatch,
        _nowUtc(),
      ),
    );
  }

  Future<DavMutationResult> _finishMoveAtDestination(
    DavFetchedMember destination, {
    required DavMutationPatch? postMovePatch,
    required CollectionCapabilities destinationCapabilities,
    required String correlationId,
  }) {
    if (postMovePatch == null) {
      return Future.value(DavMutationResult.succeeded(destination));
    }
    return update(
      hrefKey: destination.hrefKey,
      uri: destination.requestUri,
      baselineEtag: destination.etag!,
      baselineRawIcs: destination.rawIcsBody!,
      patch: postMovePatch,
      capabilities: destinationCapabilities,
      correlationId: correlationId,
    );
  }

  Future<DavMutationResult> delete({
    required String hrefKey,
    required Uri uri,
    required String baselineEtag,
    required String baselineRawIcs,
    required bool isEvent,
    required CollectionCapabilities capabilities,
    required String correlationId,
  }) async {
    if (baselineEtag.isEmpty ||
        (isEvent
            ? !capabilities.canDeleteEvent
            : !capabilities.canDeleteTask)) {
      throw _readOnlyError(correlationId);
    }
    var expectedEtag = baselineEtag;
    var comparisonBaseline = baselineRawIcs;
    DavFetchedMember? lastCurrent;
    for (var attempt = 0; attempt < maximumConditionalAttempts; attempt += 1) {
      try {
        final response = await _remoteClient.conditionalDelete(
          uri: uri,
          ifMatch: expectedEtag,
          correlationId: correlationId,
        );
        if (response.status == DavConditionalStatus.success ||
            response.status == DavConditionalStatus.missing) {
          return const DavMutationResult.succeeded(null);
        }
      } on DavException catch (error) {
        if (!_isUnknownOutcome(error)) rethrow;
      }
      final current = await _remoteClient.fetch(
        hrefKey: hrefKey,
        uri: uri,
        correlationId: correlationId,
      );
      lastCurrent = current;
      if (current.missing) {
        return const DavMutationResult.succeeded(null);
      }
      final analysis = _conflictAnalyzer.analyzeDelete(
        baselineRawIcs: comparisonBaseline,
        currentRemoteRawIcs: current.rawIcsBody!,
      );
      if (!analysis.canRetryWithRemoteEtag) {
        return DavMutationResult.conflict(
          analysis,
          remoteObject: current,
          localCandidateRawIcs: baselineRawIcs,
        );
      }
      expectedEtag = current.etag!;
      comparisonBaseline = current.rawIcsBody!;
    }
    return DavMutationResult.conflict(
      _retryLimitConflict(const {'DELETE'}),
      remoteObject: lastCurrent,
      localCandidateRawIcs: baselineRawIcs,
    );
  }
}

IcalProperty _newProperty(
  String name,
  String value, {
  List<IcalParameter> parameters = const [],
}) => IcalProperty(
  group: null,
  name: name,
  parameters: List.unmodifiable(parameters),
  rawValue: value,
  originalPhysicalLines: const [],
  isDirty: true,
);

Uri _memberUri(Uri collectionUri, String memberName) {
  if (!RegExp(r'^[A-Za-z0-9-]+[.]ics$').hasMatch(memberName)) {
    throw ArgumentError.value(memberName, 'memberName');
  }
  final base = collectionUri.path.endsWith('/')
      ? collectionUri
      : collectionUri.replace(path: '${collectionUri.path}/');
  return base.resolve(memberName);
}

bool _sameIntendedObject(String intended, String current) {
  try {
    final intendedSemantic = IcalSemanticDocument.parse(intended);
    final currentSemantic = IcalSemanticDocument.parse(current);
    return intendedSemantic.primaryUid == currentSemantic.primaryUid &&
        intendedSemantic.semanticHash == currentSemantic.semanticHash;
  } on DavException {
    return false;
  }
}

bool _isUnknownOutcome(DavException error) =>
    error.kind == DavErrorKind.network || error.kind == DavErrorKind.timeout;

DavException _readOnlyError(String correlationId) => DavException(
  kind: DavErrorKind.authorization,
  code: 'DavReadOnly',
  safeMessage: 'This DAV collection does not allow that change.',
  correlationId: correlationId,
);

DavConflictAnalysis _resourceMissingConflict(Set<String> localChanges) =>
    DavConflictAnalysis(
      outcome: DavConflictOutcome.conflict,
      localChangedProperties: Set.unmodifiable(localChanges),
      remoteChangedProperties: const {'DELETE'},
      mergedRawIcs: null,
      conflictCode: 'DavConflictRemoteObjectRemoved',
    );

DavConflictAnalysis _retryLimitConflict(Set<String> localChanges) =>
    DavConflictAnalysis(
      outcome: DavConflictOutcome.conflict,
      localChangedProperties: Set.unmodifiable(localChanges),
      remoteChangedProperties: const {'RESOURCE'},
      mergedRawIcs: null,
      conflictCode: 'DavConflictRetryLimitExceeded',
    );

DavConflictAnalysis _moveConflict(String code, Set<String> remoteChanges) =>
    DavConflictAnalysis(
      outcome: DavConflictOutcome.conflict,
      localChangedProperties: const {'MOVE'},
      remoteChangedProperties: Set.unmodifiable(remoteChanges),
      mergedRawIcs: null,
      conflictCode: code,
    );

String _moveCandidate(
  String sourceRawIcs,
  DavMutationPatch? postMovePatch,
  DateTime nowUtc,
) => postMovePatch == null
    ? sourceRawIcs
    : postMovePatch.applyTo(sourceRawIcs, nowUtc: nowUtc.toUtc());

String _utcIcal(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

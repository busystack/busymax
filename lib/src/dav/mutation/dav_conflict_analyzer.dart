import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import 'dav_mutation_patch.dart';

enum DavConflictOutcome { remoteUnchanged, autoMerged, conflict }

final class DavConflictAnalysis {
  const DavConflictAnalysis({
    required this.outcome,
    required this.localChangedProperties,
    required this.remoteChangedProperties,
    required this.mergedRawIcs,
    required this.conflictCode,
  });

  final DavConflictOutcome outcome;
  final Set<String> localChangedProperties;
  final Set<String> remoteChangedProperties;
  final String? mergedRawIcs;
  final String? conflictCode;

  bool get canRetryWithRemoteEtag =>
      outcome == DavConflictOutcome.remoteUnchanged ||
      outcome == DavConflictOutcome.autoMerged;
}

final class DavConflictAnalyzer {
  const DavConflictAnalyzer();

  DavConflictAnalysis analyzeUpdate({
    required String baselineRawIcs,
    required String currentRemoteRawIcs,
    required DavMutationPatch localPatch,
    required DateTime nowUtc,
  }) {
    final baseline = IcalSemanticDocument.parse(baselineRawIcs);
    final current = IcalSemanticDocument.parse(currentRemoteRawIcs);
    final localChanges = localPatch.changedProperties;
    if (baseline.semanticHash == current.semanticHash) {
      return DavConflictAnalysis(
        outcome: DavConflictOutcome.remoteUnchanged,
        localChangedProperties: Set.unmodifiable(localChanges),
        remoteChangedProperties: const {},
        mergedRawIcs: localPatch.applyTo(currentRemoteRawIcs, nowUtc: nowUtc),
        conflictCode: null,
      );
    }

    final baselineKeys = _componentKeys(baseline);
    final currentKeys = _componentKeys(current);
    if (!_sameSet(baselineKeys, currentKeys)) {
      return _conflict(localChanges, const {
        'RECURRENCE-SET',
      }, 'DavConflictRecurrenceSetChanged');
    }
    // Adding or deleting a component changes the resource/recurrence set as a
    // whole. It is safe only when the remote resource is byte-semantically at
    // the baseline (handled above); any concurrent semantic edit is manual.
    if (localChanges.contains('COMPONENT-SET')) {
      return _conflict(localChanges, const {
        'RESOURCE',
      }, 'DavConflictBroadRecurrenceChange');
    }
    final baselineTarget = _requireTarget(baseline, localPatch.target);
    final currentTarget = _requireTarget(current, localPatch.target);
    final remoteChanges = changedIcalProperties(
      baselineTarget.documentComponent,
      currentTarget.documentComponent,
    );
    if (_nestedComponentHash(baselineTarget.documentComponent) !=
        _nestedComponentHash(currentTarget.documentComponent)) {
      remoteChanges.add('VALARM');
    }
    if (_timeZoneHash(baseline) != _timeZoneHash(current)) {
      remoteChanges.add('VTIMEZONE');
    }
    final broadRemote = remoteChanges.any(
      const {
        'UID',
        'DTSTART',
        'RRULE',
        'RDATE',
        'EXDATE',
        'RECURRENCE-ID',
        'RECURRENCE-SET',
        'VTIMEZONE',
      }.contains,
    );
    final overlap = localChanges.intersection(remoteChanges);
    if (overlap.isNotEmpty ||
        (localPatch.isBroadRecurrenceMutation && remoteChanges.isNotEmpty) ||
        (broadRemote && localChanges.isNotEmpty)) {
      return _conflict(
        localChanges,
        remoteChanges,
        overlap.isNotEmpty
            ? 'DavConflictOverlappingProperties'
            : 'DavConflictBroadRecurrenceChange',
      );
    }
    final merged = localPatch.applyTo(currentRemoteRawIcs, nowUtc: nowUtc);
    return DavConflictAnalysis(
      outcome: DavConflictOutcome.autoMerged,
      localChangedProperties: Set.unmodifiable(localChanges),
      remoteChangedProperties: Set.unmodifiable(remoteChanges),
      mergedRawIcs: merged,
      conflictCode: null,
    );
  }

  DavConflictAnalysis analyzeDelete({
    required String baselineRawIcs,
    required String currentRemoteRawIcs,
  }) {
    final baseline = IcalSemanticDocument.parse(baselineRawIcs);
    final current = IcalSemanticDocument.parse(currentRemoteRawIcs);
    if (baseline.semanticHash == current.semanticHash) {
      return const DavConflictAnalysis(
        outcome: DavConflictOutcome.remoteUnchanged,
        localChangedProperties: {'DELETE'},
        remoteChangedProperties: {},
        mergedRawIcs: null,
        conflictCode: null,
      );
    }
    return const DavConflictAnalysis(
      outcome: DavConflictOutcome.conflict,
      localChangedProperties: {'DELETE'},
      remoteChangedProperties: {'RESOURCE'},
      mergedRawIcs: null,
      conflictCode: 'DavConflictStaleDelete',
    );
  }
}

DavConflictAnalysis _conflict(
  Set<String> local,
  Set<String> remote,
  String code,
) => DavConflictAnalysis(
  outcome: DavConflictOutcome.conflict,
  localChangedProperties: Set.unmodifiable(local),
  remoteChangedProperties: Set.unmodifiable(remote),
  mergedRawIcs: null,
  conflictCode: code,
);

IcalSemanticComponent _requireTarget(
  IcalSemanticDocument document,
  IcalComponentKey target,
) {
  final matches = document.components.where(
    (component) =>
        component.componentType == target.componentType.toUpperCase() &&
        component.uid == target.uid &&
        component.recurrenceIdKey == target.recurrenceIdKey,
  );
  if (matches.length != 1) {
    throw const DavException(
      kind: DavErrorKind.conflict,
      code: 'DavConflictTargetComponentChanged',
      safeMessage: 'The edited calendar component changed on the server.',
    );
  }
  return matches.single;
}

Set<String> _componentKeys(IcalSemanticDocument document) => {
  for (final component in document.components)
    '${component.componentType}\u0000${component.uid}\u0000'
        '${component.recurrenceIdKey ?? ''}',
};

bool _sameSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _nestedComponentHash(IcalComponent component) =>
    component.components.map(semanticComponentHash).join('\n');

String _timeZoneHash(IcalSemanticDocument document) =>
    document.timeZones.map(semanticComponentHash).join('\n');

import '../../features/calendar/presentation/event_editor_draft.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../ical/ical_timezone.dart';
import '../mutation/dav_mutation_patch.dart';
import '../mutation/dav_projection_mutations.dart';
import 'nextcloud_scheduling_policy.dart';
import 'nextcloud_scheduling_mutations.dart';

/// One resource-level patch for a reply, even when a series contains many
/// detached exceptions. Only the current principal's participant state is
/// changed; organizer sequence and other participants are preserved.
DavMutationPatch buildNextcloudResponsePatch({
  required String baselineRawIcs,
  required String uid,
  required NextcloudSchedulingPolicy policy,
  required String participationStatus,
  required DateTime nowUtc,
  String? occurrenceKey,
  bool entireSeries = false,
}) {
  if (!policy.canReply ||
      !{'ACCEPTED', 'TENTATIVE', 'DECLINED'}.contains(participationStatus)) {
    throw schedulingDenied('DavSendReplyDenied');
  }
  final semantic = IcalSemanticDocument.parse(baselineRawIcs);
  final components = semantic.components
      .where((c) => c.componentType == 'VEVENT' && c.uid == uid)
      .toList();
  if (components.isEmpty ||
      components.any(
        (c) =>
            c.organizers.any((o) => policy.ownsAddress(o['value']?.toString())),
      )) {
    throw schedulingDenied('DavAttendeeResponseUnavailable');
  }
  final selected = occurrenceKey == null || entireSeries
      ? components.map((c) => c.documentComponent.deepCopy()).toList()
      : [
          detachedDavEventOccurrence(
            baselineRawIcs: baselineRawIcs,
            uid: uid,
            occurrenceKey: occurrenceKey,
          ),
        ];
  final operations = <DavPatchOperation>[];
  for (final component in selected) {
    final key = IcalComponentKey(
      componentType: 'VEVENT',
      uid: uid,
      recurrenceIdKey: icalRecurrenceIdKey(
        component.firstProperty('RECURRENCE-ID'),
      ),
    );
    final original = components
        .where((c) => c.recurrenceIdKey == key.recurrenceIdKey)
        .firstOrNull;
    final own = component
        .propertiesNamed('ATTENDEE')
        .where((p) => policy.ownsAddress(p.rawValue))
        .toList();
    if (own.isEmpty) throw schedulingDenied('DavAttendeeIdentityUnavailable');
    if (original != null &&
        own.every(
          (p) =>
              p.parameterValue('PARTSTAT') == participationStatus &&
              p.parameterValue('RSVP') == 'FALSE',
        )) {
      continue;
    }
    final document = IcalDocument.create(components: [component]);
    final patcher = IcalDocumentPatcher(document);
    patcher.replaceRepeatedRaw(key, 'ATTENDEE', [
      for (final attendee in component.propertiesNamed('ATTENDEE'))
        (
          value: attendee.rawValue,
          parameters: policy.ownsAddress(attendee.rawValue)
              ? [
                  ...attendee.parameters.where(
                    (p) => !{
                      'PARTSTAT',
                      'RSVP',
                      'SCHEDULE-STATUS',
                    }.contains(p.name),
                  ),
                  IcalParameter(
                    name: 'PARTSTAT',
                    values: [participationStatus],
                    wasQuoted: false,
                  ),
                  const IcalParameter(
                    name: 'RSVP',
                    values: ['FALSE'],
                    wasQuoted: false,
                  ),
                ]
              : attendee.parameters,
        ),
    ]);
    patcher.replaceSingletonRaw(key, 'DTSTAMP', nextcloudIcalUtc(nowUtc));
    patcher.replaceSingletonRaw(key, 'LAST-MODIFIED', nextcloudIcalUtc(nowUtc));
    operations.addAll([
      if (original != null)
        DavPatchOperation.removeComponent(componentKey: key),
      DavPatchOperation.addComponent(patcher.requireComponent(key)),
    ]);
  }
  // The caller treats an already-applied reply as a no-op, without queuing.
  if (operations.isEmpty) throw const NextcloudResponseUnchanged();
  final patch = DavMutationPatch(
    target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
    scope: entireSeries || occurrenceKey == null
        ? DavMutationScope.recurrenceMaster
        : DavMutationScope.occurrence,
    operations: operations,
  );
  policy.validateChange(
    baseline: baselineRawIcs,
    candidate: patch.applyTo(baselineRawIcs, nowUtc: nowUtc),
  );
  return patch;
}

final class NextcloudResponseUnchanged implements Exception {
  const NextcloudResponseUnchanged();
}

/// Explicit guest edits to a series also affect its stored exceptions. This
/// is one object patch, not a loop over visible occurrence projections.
DavMutationPatch nextcloudSeriesGuestPatch({
  required DavMutationPatch initial,
  required String baselineRawIcs,
  required List<EventAttendeeDraft> attendees,
  required DateTime nowUtc,
  required bool entireSeries,
  String? fromRecurrenceKey,
}) {
  final prepared = initial.applyTo(baselineRawIcs, nowUtc: nowUtc);
  final semantic = IcalSemanticDocument.parse(prepared);
  final resolver = IcalTimeZoneResolver.fromDocument(semantic);
  final from = fromRecurrenceKey == null
      ? null
      : semantic.components
            .where((c) => c.recurrenceIdKey == fromRecurrenceKey)
            .firstOrNull
            ?.recurrenceId;
  if (!entireSeries && from == null) {
    throw schedulingDenied('DavOccurrenceIdentityUnavailable');
  }
  final operations = [...initial.operations];
  for (final component in semantic.components.where(
    (c) => c.uid == initial.target.uid && c.componentType == 'VEVENT',
  )) {
    if (!entireSeries &&
        (component.recurrenceId == null ||
            resolver
                .toUtc(component.recurrenceId!)
                .isBefore(resolver.toUtc(from!)))) {
      continue;
    }
    final target = IcalComponentKey(
      componentType: 'VEVENT',
      uid: component.uid!,
      recurrenceIdKey: component.recurrenceIdKey,
    );
    final values = nextcloudAttendeeValues(
      attendees,
      component.documentComponent,
    );
    final guestChange = DavPatchOperation.replaceRepeatedRaw(
      'ATTENDEE',
      values,
    );
    final trial = DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceException,
      operations: [guestChange],
    );
    final changed = trial.applyTo(prepared, nowUtc: nowUtc);
    if (IcalSemanticDocument.parse(changed).semanticHash ==
        semantic.semanticHash) {
      continue;
    }
    final updated = DavMutationPatch(
      target: target,
      scope: DavMutationScope.recurrenceException,
      operations: [
        guestChange,
        ...nextcloudSchedulingStamps(
          baseline: component,
          changes: [guestChange],
          nowUtc: nowUtc,
          organizer: true,
        ),
      ],
    ).applyTo(prepared, nowUtc: nowUtc);
    final replacement = IcalSemanticDocument.parse(updated).components
        .singleWhere(
          (c) =>
              c.uid == target.uid &&
              c.recurrenceIdKey == target.recurrenceIdKey,
        );
    operations.addAll([
      DavPatchOperation.removeComponent(componentKey: target),
      DavPatchOperation.addComponent(replacement.documentComponent),
    ]);
  }
  return DavMutationPatch(
    target: initial.target,
    scope: initial.scope,
    operations: operations,
  );
}

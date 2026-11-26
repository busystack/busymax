import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_recurrence.dart';
import '../dav/ical/ical_semantics.dart';
import '../dav/ical/ical_timezone.dart';
import 'journal_component.dart';

enum JournalMethod { publish, add, cancel }

final class JournalMessage {
  JournalMessage._(this.method, this.entries, this.stored);

  final JournalMethod method;
  final List<IcalSemanticComponent> entries;
  final IcalDocument stored;

  static JournalMessage parse(IcalDocument input) {
    final properties = input.root.propertiesNamed('METHOD');
    if (properties.length != 1) throw _invalidMessage();
    final method = JournalMethod.values
        .where(
          (m) =>
              m.name.toUpperCase() == properties.single.rawValue.toUpperCase(),
        )
        .firstOrNull;
    if (method == null) throw _invalidMessage();
    final document = IcalDocument.parse(input.serialize());
    document.root.children.removeWhere(
      (node) => node is IcalProperty && node.name == 'METHOD',
    );
    document.root.structurallyDirty = true;
    final semantic = IcalSemanticDocument.fromDocument(document);
    final entries = semantic.components;
    if (semantic.primaryUid == null ||
        entries.isEmpty ||
        document.calendarComponents.any(
          (c) => c.name != 'VJOURNAL' && c.name != 'VTIMEZONE',
        ) ||
        method == JournalMethod.add && entries.length != 1) {
      throw _invalidMessage();
    }
    JournalComponent.validateAuthored(semantic);
    final organizer = _organizer(entries.first);
    if (organizer == null || Uri.tryParse(organizer)?.hasScheme != true) {
      throw _invalidMessage();
    }
    for (final entry in entries) {
      final component = entry.documentComponent;
      final descriptions = component.propertiesNamed('DESCRIPTION').length;
      final sequence = entry.sequence;
      if (_organizer(entry) != organizer ||
          entry.dtstamp == null ||
          component.firstProperty('ATTENDEE') != null ||
          component.firstProperty('REQUEST-STATUS') != null ||
          (component.firstProperty('SEQUENCE') != null &&
              (sequence == null || sequence < 0)) ||
          (method != JournalMethod.cancel &&
              (descriptions != 1 || entry.start == null)) ||
          (method == JournalMethod.cancel &&
              (sequence == null ||
                  descriptions > 1 ||
                  (entry.status != null && entry.status != 'CANCELLED'))) ||
          (method == JournalMethod.add &&
              ((sequence ?? 0) <= 0 ||
                  entry.recurrenceId != null ||
                  entry.recurrenceRules.isNotEmpty ||
                  entry.recurrenceDates.isNotEmpty ||
                  entry.exceptionDates.isNotEmpty))) {
        throw _invalidMessage();
      }
    }
    return JournalMessage._(method, entries, document);
  }

  String initialResource() {
    if (method != JournalMethod.publish) throw _unresolvable();
    return stored.serialize();
  }

  /// Maps a reviewed message to an update to the existing UID set. A null
  /// result represents a stale or already-applied message.
  String? update(String rawIcs) {
    final baseline = IcalSemanticDocument.parse(rawIcs);
    if (baseline.primaryUid != entries.first.uid ||
        baseline.dominantComponentType != 'VJOURNAL') {
      throw _unresolvable();
    }
    final master = baseline.components
        .where((c) => c.recurrenceId == null)
        .firstOrNull;
    final indexed = {for (final c in baseline.components) c.recurrenceIdKey: c};
    final priorOrganizer = _organizer(master ?? baseline.components.first);
    if (priorOrganizer == null || priorOrganizer != _organizer(entries.first)) {
      throw _unresolvable();
    }
    // Keep the existing calendar envelope and unrelated siblings. A new
    // definition can be appended, but replacing a shared zone could change
    // the meaning of dates in components outside the message's scope.
    final document = baseline.document;
    final zoneIds = {
      for (final zone in baseline.timeZones)
        zone.firstProperty('TZID')?.rawValue: zone,
    };
    for (final zone in stored.calendarComponents.where(
      (c) => c.name == 'VTIMEZONE',
    )) {
      final id = zone.firstProperty('TZID')?.rawValue;
      final old = zoneIds[id];
      if (old != null &&
          semanticComponentHash(old) != semanticComponentHash(zone)) {
        throw _unresolvable();
      }
      if (old == null) document.root.children.add(zone.deepCopy());
    }
    var changed = false;
    void put(IcalSemanticComponent? old, IcalComponent replacement) {
      final index = old == null
          ? -1
          : document.root.children.indexOf(old.documentComponent);
      if (index < 0) {
        document.root.children.add(replacement);
      } else {
        document.root.children[index] = replacement;
      }
      changed = true;
    }

    final resolver = IcalTimeZoneResolver.fromDocument(baseline);
    for (final incoming in entries) {
      final identity = incoming.recurrenceIdKey;
      final old = indexed[identity];
      final reference = old ?? master;
      if (reference == null ||
          _organizer(reference) != null &&
              _organizer(reference) != priorOrganizer) {
        throw _unresolvable();
      }
      if (_revisionOrder(incoming, reference) <= 0) continue;
      switch (method) {
        case JournalMethod.publish:
          put(old, incoming.documentComponent.deepCopy());
        case JournalMethod.add:
          final start = incoming.start!;
          if (master == null ||
              master.start == null ||
              !_sameForm(master.start!, start)) {
            throw _unresolvable();
          }
          final startProperty = incoming.documentComponent.firstProperty(
            'DTSTART',
          )!;
          final added = incoming.documentComponent.deepCopy();
          final rid = _asRecurrenceId(startProperty);
          final key = icalRecurrenceIdKey(rid);
          if (_hasOccurrence(baseline, start, resolver) ||
              indexed.containsKey(key)) {
            throw _unresolvable();
          }
          added.children.add(rid);
          put(null, added);
          final revised = master.documentComponent.deepCopy();
          _replace(revised, 'DTSTAMP', incoming.dtstamp!.rawValue);
          _replace(revised, 'SEQUENCE', '${incoming.sequence}');
          put(master, revised);
        case JournalMethod.cancel:
          if (identity == null && master == null ||
              (incoming.sequence ?? 0) <= (reference.sequence ?? 0)) {
            throw _unresolvable();
          }
          if (identity == null) {
            for (final instance in baseline.components) {
              if (_revisionOrder(incoming, instance) > 0) {
                put(instance, _cancelled(instance.documentComponent, incoming));
              }
            }
          } else {
            final idProperty = incoming.documentComponent.firstProperty(
              'RECURRENCE-ID',
            )!;
            if (old == null &&
                (master == null ||
                    !_hasOccurrence(
                      baseline,
                      incoming.recurrenceId!,
                      resolver,
                    ))) {
              throw _unresolvable();
            }
            final instance = _cancelled(reference.documentComponent, incoming);
            _replace(
              instance,
              'RECURRENCE-ID',
              idProperty.rawValue,
              parameters: idProperty.parameters,
            );
            if (old == null) {
              instance.children.removeWhere(
                (node) =>
                    node is IcalProperty &&
                    const {'RDATE', 'EXDATE', 'RRULE'}.contains(node.name),
              );
              _replace(
                instance,
                'DTSTART',
                idProperty.rawValue,
                parameters: idProperty.parameters
                    .where((p) => p.name != 'RANGE')
                    .toList(),
              );
            }
            put(old, instance);
            if (incoming.recurrenceRange == 'THISANDFUTURE') {
              final first = resolver.toUtc(incoming.recurrenceId!);
              for (final sibling in baseline.components) {
                final id = sibling.recurrenceId;
                if (id != null &&
                    resolver.toUtc(id).isAfter(first) &&
                    _revisionOrder(incoming, sibling) > 0) {
                  put(sibling, _cancelled(sibling.documentComponent, incoming));
                }
              }
            }
          }
      }
    }
    if (!changed) return null;
    document.root.structurallyDirty = true;
    final candidate = document.serialize();
    JournalComponent.validateAuthored(IcalSemanticDocument.parse(candidate));
    return candidate;
  }
}

String? _organizer(IcalSemanticComponent entry) =>
    entry.documentComponent.firstProperty('ORGANIZER')?.rawValue;

int _revisionOrder(
  IcalSemanticComponent incoming,
  IcalSemanticComponent prior,
) {
  final sequence = (incoming.sequence ?? 0).compareTo(prior.sequence ?? 0);
  return sequence == 0
      ? incoming.dtstamp!.localValue.compareTo(
          prior.dtstamp?.localValue ?? DateTime.utc(1),
        )
      : sequence;
}

bool _sameForm(IcalTemporalValue left, IcalTemporalValue right) =>
    left.kind == right.kind && left.timeZoneId == right.timeZoneId;

bool _hasOccurrence(
  IcalSemanticDocument baseline,
  IcalTemporalValue id,
  IcalTimeZoneResolver resolver,
) {
  final document = IcalDocument.parse(baseline.document.serialize());
  document.root.children.removeWhere(
    (node) =>
        node is IcalComponent && node.firstProperty('RECURRENCE-ID') != null,
  );
  final start = resolver.toUtc(id);
  return IcalRecurrenceExpander()
      .expand(
        IcalSemanticDocument.fromDocument(document),
        rangeStartUtc: start,
        rangeEndUtc: start.add(const Duration(seconds: 1)),
      )
      .any((row) => resolver.toUtc(row.recurrenceId) == start);
}

IcalProperty _asRecurrenceId(IcalProperty start) => IcalProperty(
  group: null,
  name: 'RECURRENCE-ID',
  rawValue: start.rawValue,
  parameters: start.parameters
      .where((p) => p.name == 'VALUE' || p.name == 'TZID')
      .toList(),
  originalPhysicalLines: const [],
  isDirty: true,
);

IcalComponent _cancelled(IcalComponent source, IcalSemanticComponent message) {
  final result = source.deepCopy();
  _replace(result, 'STATUS', 'CANCELLED');
  _replace(result, 'DTSTAMP', message.dtstamp!.rawValue);
  _replace(result, 'SEQUENCE', '${message.sequence}');
  return result;
}

void _replace(
  IcalComponent component,
  String name,
  String value, {
  List<IcalParameter>? parameters,
}) {
  final old = component.firstProperty(name);
  final replacement = IcalProperty(
    group: old?.group,
    name: name,
    rawValue: value,
    parameters: parameters ?? old?.parameters ?? const [],
    originalPhysicalLines: const [],
    isDirty: true,
  );
  final index = component.children.indexOf(old ?? replacement);
  if (index < 0) {
    component.children.add(replacement);
  } else {
    component.children[index] = replacement;
  }
  component.structurallyDirty = true;
}

DavException _invalidMessage() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalInvalidJournalMessage',
  safeMessage:
      'The journal message does not meet the requirements for its method.',
);

DavException _unresolvable() => const DavException(
  kind: DavErrorKind.conflict,
  code: 'IcalUnresolvableJournalMessage',
  safeMessage: 'The journal message could not be matched to a compatible entry or recurrence.',
);

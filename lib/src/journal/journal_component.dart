import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';

bool isDerivedJournalProperty(IcalProperty? property) =>
    property?.parameterValue('DERIVED')?.toUpperCase() == 'TRUE';

/// A journal's user-facing data, derived from its authoritative component.
final class JournalComponent {
  JournalComponent(this.component) {
    if (component.name != 'VJOURNAL') {
      throw ArgumentError('Expected a VJOURNAL component.');
    }
  }

  final IcalComponent component;

  String? get title => component.firstProperty('SUMMARY')?.decodedTextValue;
  String? get status => component.firstProperty('STATUS')?.rawValue;
  IcalTemporalValue? get start =>
      parseIcalTemporal(component.firstProperty('DTSTART'));
  List<IcalProperty> get descriptions =>
      component.propertiesNamed('DESCRIPTION').toList(growable: false);

  String get searchText => [
    for (final name in const [
      'SUMMARY',
      'DESCRIPTION',
      'COMMENT',
      'CONTACT',
      'CATEGORIES',
      'ORGANIZER',
      'ATTENDEE',
      'CLASS',
      'STATUS',
      'URL',
      'RELATED-TO',
      'CONCEPT',
      'REFID',
      'X-KEYWORDS',
    ])
      for (final property in component.propertiesNamed(name))
        property.decodedTextValue,
  ].join('\n').toLowerCase();

  /// Storage and projections also consume read-only provider redactions. Apply
  /// authored validation only when a journal is intentionally written.
  static void validateAuthored(IcalSemanticDocument document) {
    if (document.dominantComponentType != 'VJOURNAL') return;
    const singleton = {
      'CLASS',
      'CREATED',
      'DTSTART',
      'LAST-MODIFIED',
      'ORGANIZER',
      'RECURRENCE-ID',
      'SEQUENCE',
      'STATUS',
      'SUMMARY',
      'URL',
      'COLOR',
    };
    const disallowed = {
      'DTEND',
      'DUE',
      'DURATION',
      'COMPLETED',
      'PERCENT-COMPLETE',
      'TRANSP',
      'CONFERENCE',
    };
    const statuses = {'DRAFT', 'FINAL', 'CANCELLED'};
    final identities = <String?>{};
    final zones = {
      for (final zone in document.timeZones)
        zone.firstProperty('TZID')?.rawValue,
    };
    if (document.document.root.firstProperty('METHOD') != null) {
      throw _invalidJournal();
    }
    final master = document.components
        .where((c) => c.recurrenceId == null)
        .firstOrNull;
    for (final semantic in document.components) {
      final journal = semantic.documentComponent;
      if (!identities.add(semantic.recurrenceIdKey) ||
          journal.propertiesNamed('DTSTAMP').length != 1 ||
          semantic.dtstamp?.kind != IcalTemporalKind.utcDateTime ||
          (semantic.status != null && !statuses.contains(semantic.status)) ||
          singleton.any((name) => journal.propertiesNamed(name).length > 1) ||
          (journal.firstProperty('DTSTART') != null &&
              semantic.start == null) ||
          disallowed.any((name) => journal.firstProperty(name) != null) ||
          journal.components.any((child) => child.name == 'VALARM') ||
          !_hasValidStatusChildren(journal) ||
          journal.properties.any((property) {
            final zone = property.parameterValue('TZID');
            return zone != null && !zones.contains(zone);
          })) {
        throw _invalidJournal();
      }
      _validateRecurrence(semantic, master);
    }
  }
}

void _validateRecurrence(
  IcalSemanticComponent entry,
  IcalSemanticComponent? master,
) {
  final anchor = entry.start;
  final identity = entry.recurrenceId;
  if (master != null &&
      identity != null &&
      (master.start == null || !_sameRecurrenceForm(master.start!, identity))) {
    throw _inconsistentRecurrence();
  }
  final component = entry.documentComponent;
  final rules = component.propertiesNamed('RRULE');
  final dates = component.properties.where(
    (p) => p.name == 'RDATE' || p.name == 'EXDATE',
  );
  if (anchor == null) {
    if (rules.isNotEmpty || dates.isNotEmpty) throw _inconsistentRecurrence();
    return;
  }
  for (final rule in rules) {
    final parts = rule.rawValue.toUpperCase().split(';');
    final until = parts.where((part) => part.startsWith('UNTIL=')).firstOrNull;
    if (until != null) {
      final raw = until.substring('UNTIL='.length);
      final compatible = switch (anchor.kind) {
        IcalTemporalKind.date => RegExp(r'^\d{8}$').hasMatch(raw),
        IcalTemporalKind.floatingDateTime => RegExp(
          r'^\d{8}T\d{6}$',
        ).hasMatch(raw),
        _ => RegExp(r'^\d{8}T\d{6}Z$').hasMatch(raw),
      };
      if (!compatible || parts.any((part) => part.startsWith('COUNT='))) {
        throw _inconsistentRecurrence();
      }
    }
    if (anchor.isDate &&
        parts.any(
          (part) =>
              part.startsWith('BYHOUR=') ||
              part.startsWith('BYMINUTE=') ||
              part.startsWith('BYSECOND='),
        )) {
      throw _inconsistentRecurrence();
    }
  }
  for (final property in dates) {
    final type = property.parameterValue('VALUE')?.toUpperCase() ?? 'DATE-TIME';
    if (type == 'PERIOD' && property.name == 'RDATE' && !anchor.isDate) {
      continue;
    }
    if (type != (anchor.isDate ? 'DATE' : 'DATE-TIME')) {
      throw _inconsistentRecurrence();
    }
  }
}

bool _sameRecurrenceForm(IcalTemporalValue first, IcalTemporalValue second) =>
    first.isDate == second.isDate &&
    (first.kind == IcalTemporalKind.utcDateTime) ==
        (second.kind == IcalTemporalKind.utcDateTime);

DavException _inconsistentRecurrence() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalJournalRecurrenceDateMismatch',
  safeMessage:
      'The journal date must agree with its recurrence dates, rule '
      'end and occurrence identities. Update the series together.',
);

bool _hasValidStatusChildren(IcalComponent parent) => parent.components.every(
  (child) => child.name == 'VSTATUS'
      ? const {'VJOURNAL', 'PARTICIPANT'}.contains(parent.name) &&
            parent.propertiesNamed('STATUS').length == 1 &&
            child.propertiesNamed('STATUS').length == 1 &&
            child.components.isEmpty
      : _hasValidStatusChildren(child),
);

DavException _invalidJournal() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalInvalidJournal',
  safeMessage: 'The journal contains invalid calendar data.',
);

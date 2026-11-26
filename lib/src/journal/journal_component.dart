import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';

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
    for (final semantic in document.components) {
      final journal = semantic.documentComponent;
      if (!identities.add(semantic.recurrenceIdKey) ||
          journal.propertiesNamed('DTSTAMP').length != 1 ||
          semantic.dtstamp?.kind != IcalTemporalKind.utcDateTime ||
          (semantic.status != null && !statuses.contains(semantic.status)) ||
          singleton.any((name) => journal.propertiesNamed(name).length > 1) ||
          disallowed.any((name) => journal.firstProperty(name) != null) ||
          journal.components.any((child) => child.name == 'VALARM') ||
          !_hasValidStatusChildren(journal) ||
          journal.properties.any((property) {
            final zone = property.parameterValue('TZID');
            return zone != null && !zones.contains(zone);
          })) {
        throw _invalidJournal();
      }
    }
  }
}

bool _hasValidStatusChildren(IcalComponent parent) => parent.components.every(
  (child) => child.name == 'VSTATUS'
      ? parent.propertiesNamed('STATUS').length == 1 &&
            child.propertiesNamed('STATUS').length == 1
      : _hasValidStatusChildren(child),
);

DavException _invalidJournal() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalInvalidJournal',
  safeMessage: 'The journal contains invalid calendar data.',
);

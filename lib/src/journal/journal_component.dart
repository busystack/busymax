import '../dav/dav_errors.dart';
import '../dav/ical/ical_attachments.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';

const duplicateJournalPositionCode = 'IcalDuplicateJournalRecurrencePosition';

bool isDerivedJournalProperty(IcalProperty? property) =>
    property?.parameterValue('DERIVED')?.toUpperCase() == 'TRUE';

/// Identifies the original position independently of its storage key or RANGE.
String? journalRecurrencePosition(IcalTemporalValue? value) => switch (value) {
  null => null,
  IcalTemporalValue(kind: IcalTemporalKind.utcDateTime) =>
    value.localValue.toUtc().toIso8601String(),
  _ => value.recurrenceKey,
};

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
      'GEO',
      'LOCATION',
      'PRIORITY',
    };
    const statuses = {'DRAFT', 'FINAL', 'CANCELLED'};
    final identities = <String?>{};
    final zones = {
      for (final zone in document.timeZones)
        zone.firstProperty('TZID')?.rawValue,
    };
    final calendar = document.document.root;
    if (calendar.firstProperty('METHOD') != null ||
        calendar.propertiesNamed('VERSION').length != 1 ||
        calendar.firstProperty('VERSION')?.rawValue != '2.0' ||
        calendar.propertiesNamed('PRODID').length != 1 ||
        (calendar.firstProperty('PRODID')?.rawValue.trim().isEmpty ?? true) ||
        document.primaryUid == null ||
        document.components.any((c) => c.componentType != 'VJOURNAL')) {
      throw _invalidJournal();
    }
    final master = document.components
        .where((c) => c.recurrenceId == null)
        .firstOrNull;
    for (final semantic in document.components) {
      final journal = semantic.documentComponent;
      if (!identities.add(journalRecurrencePosition(semantic.recurrenceId))) {
        throw const DavException(
          kind: DavErrorKind.invalidCalendarData,
          code: duplicateJournalPositionCode,
          safeMessage: 'Multiple journal components use the same original recurrence position.',
        );
      }
      if (journal.propertiesNamed('UID').length != 1 ||
          journal.propertiesNamed('DTSTAMP').length != 1 ||
          semantic.dtstamp?.kind != IcalTemporalKind.utcDateTime ||
          (semantic.status != null && !statuses.contains(semantic.status)) ||
          singleton.any((name) => journal.propertiesNamed(name).length > 1) ||
          (journal.firstProperty('DTSTART') != null &&
              semantic.start == null) ||
          disallowed.any((name) => journal.firstProperty(name) != null) ||
          !_validJournalChildren(journal) ||
          !_validJournalValues(journal) ||
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

bool _validJournalValues(IcalComponent component) {
  for (final property in component.properties) {
    final valueType = property.parameterValue('VALUE')?.toUpperCase();
    final uri =
        const {
          'URL',
          'ORGANIZER',
          'ATTENDEE',
          'CONCEPT',
        }.contains(property.name) ||
        const {
              'LINK',
              'RELATED-TO',
              'IMAGE',
              'STYLED-DESCRIPTION',
              'STRUCTURED-DATA',
            }.contains(property.name) &&
            (valueType == 'URI' || valueType == 'XML-REFERENCE');
    if (uri && !_absoluteUri(property.rawValue)) return false;
    if (property.name == 'LINK' &&
        !const {'URI', 'UID', 'XML-REFERENCE'}.contains(valueType)) {
      return false;
    }
    if (const {'DTSTART', 'RECURRENCE-ID'}.contains(property.name)) {
      final temporal = parseIcalTemporal(property);
      if (temporal == null ||
          temporal.isDate && valueType != 'DATE' ||
          property.parameterValue('TZID') != null &&
              temporal.kind != IcalTemporalKind.tzidDateTime) {
        return false;
      }
    }
  }
  try {
    return readIcalAttachmentProperties(
      component.propertiesNamed('ATTACH').toList(),
    ).every((attachment) {
      if (attachment.kind == IcalAttachmentKind.binary) {
        return attachment.canSave;
      }
      final uri = attachment.uri;
      return uri != null &&
          _absoluteUri(uri) &&
          Uri.parse(uri).scheme.toLowerCase() != 'file';
    });
  } on FormatException {
    return false;
  }
}

bool _absoluteUri(String value) =>
    !value.contains(RegExp(r'\s')) && Uri.tryParse(value)?.hasScheme == true;

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
    if (parts.any(
      (part) => part.startsWith('RSCALE=') || part.startsWith('SKIP='),
    )) {
      throw const DavException(
        kind: DavErrorKind.unsupportedComponent,
        code: 'IcalJournalRscaleUnsupported',
        safeMessage: 'This journal uses a recurrence calendar BusyMax cannot write. The original entry remains exportable.',
      );
    }
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
    first.kind == second.kind;

DavException _inconsistentRecurrence() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalJournalRecurrenceDateMismatch',
  safeMessage:
      'The journal date must agree with its recurrence dates, rule '
      'end and occurrence identities. Update the series together.',
);

const journalChildTypes = {
  'VJOURNAL': {'PARTICIPANT', 'VLOCATION', 'VRESOURCE', 'VSTATUS'},
  'PARTICIPANT': {'VLOCATION', 'VRESOURCE', 'VSTATUS'},
};

const journalChildRequiredFields = {
  'PARTICIPANT': {'UID', 'PARTICIPANT-TYPE'},
  'VLOCATION': {'UID'},
  'VRESOURCE': {'UID'},
  'VSTATUS': {'STATUS'},
};

const journalChildOptionalSingletons = {
  'PARTICIPANT': {
    'CALENDAR-ADDRESS',
    'CREATED',
    'DESCRIPTION',
    'DTSTAMP',
    'GEO',
    'LAST-MODIFIED',
    'PRIORITY',
    'SEQUENCE',
    'STATUS',
    'SUMMARY',
    'URL',
  },
  'VLOCATION': {'DESCRIPTION', 'GEO', 'LOCATION-TYPE', 'NAME'},
  'VRESOURCE': {'DESCRIPTION', 'GEO', 'NAME', 'RESOURCE-TYPE'},
  'VSTATUS': {'DESCRIPTION', 'DTSTAMP', 'REASON', 'SUBSTATE', 'SUMMARY'},
};

const journalChildRepeatableFields = {
  'PARTICIPANT': {
    'ATTACH',
    'CATEGORIES',
    'COMMENT',
    'CONTACT',
    'LOCATION',
    'REQUEST-STATUS',
    'RELATED-TO',
    'RESOURCES',
    'STRUCTURED-LOCATION',
    'STRUCTURED-RESOURCE',
    'STYLED-DESCRIPTION',
    'STRUCTURED-DATA',
  },
  'VLOCATION': {'STRUCTURED-DATA'},
  'VRESOURCE': {'STRUCTURED-DATA'},
  'VSTATUS': {'COMMENT', 'STYLED-DESCRIPTION'},
};

bool _validJournalChildren(IcalComponent parent) => parent.components.every(
  (child) =>
      (journalChildTypes[parent.name]?.contains(child.name) ?? false) &&
      journalChildRequiredFields[child.name]!.every(
        (name) =>
            child.propertiesNamed(name).length == 1 &&
            child.firstProperty(name)!.rawValue.trim().isNotEmpty,
      ) &&
      journalChildOptionalSingletons[child.name]!.every(
        (name) => child.propertiesNamed(name).length <= 1,
      ) &&
      (child.name != 'VSTATUS' ||
          parent.propertiesNamed('STATUS').length == 1) &&
      _validJournalValues(child) &&
      _validJournalChildren(child),
);

DavException _invalidJournal() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalInvalidJournal',
  safeMessage: 'The journal contains invalid calendar data.',
);

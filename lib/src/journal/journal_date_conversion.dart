import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';
import '../dav/ical/ical_timezone.dart';

/// Converts a dated series while preserving the original civil positions.
/// For all-day origins, the new master's clock time is used on each day.
String convertJournalSeriesDate(
  String raw,
  IcalTemporalValue from,
  IcalProperty newStart,
) {
  final to = parseIcalTemporal(newStart)!;
  final fromCivil = from.rawValue.replaceFirst(RegExp(r'Z$'), '');
  final toCivil = to.rawValue.replaceFirst(RegExp(r'Z$'), '');
  if (to.isDate ||
      (from.isDate
          ? !toCivil.startsWith('${fromCivil}T')
          : fromCivil != toCivil)) {
    throw _conversionUnavailable();
  }

  final original = IcalSemanticDocument.parse(raw);
  final master = original.components.singleWhere(
    (item) => item.recurrenceId == null,
  );
  if (master.recurrenceRules.length > 1) throw _conversionUnavailable();
  // Determine the destination resolver using the new DTSTART, so its TZID is
  // included when a known IANA definition must be added.
  final prepared = IcalDocument.parse(raw);
  final prototype = prepared.calendarComponents.singleWhere(
    (item) =>
        item.name == 'VJOURNAL' && item.firstProperty('RECURRENCE-ID') == null,
  );
  final position = prototype.children.indexWhere(
    (node) => node is IcalProperty && node.name == 'DTSTART',
  );
  prototype.children[position] = newStart.deepCopy();
  prototype.structurallyDirty = true;
  final target = IcalSemanticDocument.parse(
    completeIcalTimeZones(prepared.serialize()),
  );
  final fromZone = IcalTimeZoneResolver.fromDocument(original);
  final toZone = IcalTimeZoneResolver.fromDocument(target);

  String civil(String value) => value.replaceFirst(RegExp(r'Z$'), '');
  String temporal(String value) {
    final lexical = from.isDate
        ? '${value}T${toCivil.substring(9)}'
        : civil(value);
    return to.kind == IcalTemporalKind.utcDateTime ? '${lexical}Z' : lexical;
  }

  final targetTemporalParams = newStart.parameters
      .where((item) => item.name == 'TZID' || item.name == 'VALUE')
      .toList();
  for (final component in target.components) {
    for (final property in component.documentComponent.properties) {
      if (property.name == 'DTSTART' && component.recurrenceId == null) {
        continue;
      }
      if (property.name == 'RRULE') {
        property.rawValue = property.rawValue
            .split(';')
            .map((part) {
              final separator = part.indexOf('=');
              if (separator <= 0) throw _conversionUnavailable();
              final name = part.substring(0, separator);
              final value = part.substring(separator + 1);
              if (name.toUpperCase() == 'RSCALE' ||
                  name.toUpperCase() == 'SKIP') {
                throw _conversionUnavailable();
              }
              if (name.toUpperCase() != 'UNTIL') return part;
              final boundary = parseIcalTemporal(
                IcalProperty(
                  group: null,
                  name: 'UNTIL',
                  rawValue: value,
                  originalPhysicalLines: const [],
                  parameters: from.isDate
                      ? [
                          IcalParameter(
                            name: 'VALUE',
                            values: ['DATE'],
                            wasQuoted: false,
                          ),
                        ]
                      : const [],
                ),
              );
              if (boundary == null) throw _conversionUnavailable();
              var civilBoundary = value;
              if (from.timeZoneId case final fromId?) {
                final utc = fromZone.toUtc(boundary);
                final wall = fromZone.fromUtc(utc, fromId);
                civilBoundary = _wallText(wall);
                final roundTrip = _temporalWithZone(civilBoundary, fromId);
                if (fromZone.toUtc(roundTrip) != utc) {
                  throw _conversionUnavailable();
                }
              }
              var adjusted = temporal(civilBoundary);
              if (to.timeZoneId case final toId?) {
                final wall = _temporalWithZone(adjusted, toId);
                final utc = toZone.toUtc(wall);
                if (_wallText(toZone.fromUtc(utc, toId)) != adjusted) {
                  throw _conversionUnavailable();
                }
                adjusted = '${_wallText(utc)}Z';
              }
              return '$name=$adjusted';
            })
            .join(';');
        property.isDirty = true;
      }
      if (!const {
        'DTSTART',
        'RECURRENCE-ID',
        'RDATE',
        'EXDATE',
      }.contains(property.name)) {
        continue;
      }
      if (property.parameterValue('VALUE')?.toUpperCase() == 'PERIOD') {
        throw _conversionUnavailable();
      }
      final group = property.rawValue.split(',');
      for (final value in group) {
        final parsed = parseIcalTemporal(
          IcalProperty(
            group: null,
            name: property.name,
            rawValue: value,
            originalPhysicalLines: const [],
            parameters: property.parameters,
          ),
        );
        if (parsed == null ||
            parsed.kind != from.kind ||
            parsed.timeZoneId != from.timeZoneId) {
          throw _conversionUnavailable();
        }
      }
      property
        ..rawValue = group.map(temporal).join(',')
        ..isDirty = true;
      property.parameters
        ..removeWhere((item) => item.name == 'VALUE' || item.name == 'TZID')
        ..addAll(targetTemporalParams);
    }
  }
  return target.document.serialize();
}

IcalTemporalValue _temporalWithZone(String raw, String zone) =>
    parseIcalTemporal(
      IcalProperty(
        group: null,
        name: 'DTSTART',
        rawValue: raw,
        originalPhysicalLines: const [],
        parameters: [
          IcalParameter(name: 'TZID', values: [zone], wasQuoted: false),
        ],
      ),
    )!;

String _wallText(DateTime wall) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${wall.year.toString().padLeft(4, '0')}${two(wall.month)}${two(wall.day)}'
      'T${two(wall.hour)}${two(wall.minute)}${two(wall.second)}';
}

DavException _conversionUnavailable() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalJournalDateConversionUnavailable',
  safeMessage: 'This series cannot keep its original recurrence positions with the selected date change. Keep the same civil start when switching time modes, or edit a single occurrence.',
);

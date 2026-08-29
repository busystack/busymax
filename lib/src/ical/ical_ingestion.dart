import 'dart:convert';
import 'dart:typed_data';

import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';

const icalIngestionDecodedBodyLimit = 16 * 1024 * 1024;

enum IcalIngestionPolicy { fileImport, webCal }

final class IcalIngestionException implements Exception {
  const IcalIngestionException(this.code, this.safeMessage);

  final String code;
  final String safeMessage;

  @override
  String toString() => 'IcalIngestionException($code: $safeMessage)';
}

final class IcalRejectedEvent {
  const IcalRejectedEvent({required this.uid, required this.code});

  final String? uid;
  final String code;
}

final class IcalRecurrenceSet {
  const IcalRecurrenceSet({required this.uid, required this.semantic});

  final String uid;
  final IcalSemanticDocument semantic;
}

final class IcalIngestionResult {
  const IcalIngestionResult({
    required this.document,
    required this.recurrenceSets,
    required this.rejectedEvents,
    required this.unprojectedComponentTypes,
    required this.serverRefreshIntervalSeconds,
  });

  final IcalDocument document;
  final List<IcalRecurrenceSet> recurrenceSets;
  final List<IcalRejectedEvent> rejectedEvents;
  final Set<String> unprojectedComponentTypes;
  final int? serverRefreshIntervalSeconds;
}

abstract final class IcalIngestion {
  static IcalIngestionResult parseBytes(
    List<int> input, {
    required IcalIngestionPolicy policy,
  }) {
    if (input.length > icalIngestionDecodedBodyLimit) {
      throw const IcalIngestionException(
        'IcalBodyTooLarge',
        'The calendar data exceeds the 16 MiB limit.',
      );
    }
    var bytes = Uint8List.fromList(input);
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf) {
      bytes = Uint8List.sublistView(bytes, 3);
    }
    final String source;
    try {
      source = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const IcalIngestionException(
        'IcalInvalidUtf8',
        'The calendar data is not valid UTF-8.',
      );
    }
    return parseString(source, policy: policy);
  }

  static IcalIngestionResult parseString(
    String source, {
    required IcalIngestionPolicy policy,
  }) {
    if (utf8.encode(source).length > icalIngestionDecodedBodyLimit) {
      throw const IcalIngestionException(
        'IcalBodyTooLarge',
        'The calendar data exceeds the 16 MiB limit.',
      );
    }
    final IcalDocument document;
    try {
      document = IcalDocument.parse(source);
    } on DavException catch (error) {
      throw IcalIngestionException(error.code, error.safeMessage);
    }
    _validateCalendarEnvelope(document);

    final timeZones = document.calendarComponents
        .where((component) => component.name == 'VTIMEZONE')
        .toList(growable: false);
    final grouped = <String, List<IcalSemanticComponent>>{};
    final rejected = <IcalRejectedEvent>[];
    final unknown = <String>{};
    for (final component in document.calendarComponents) {
      if (component.name != 'VEVENT') {
        if (component.name != 'VTIMEZONE') unknown.add(component.name);
        continue;
      }
      try {
        final semantic = IcalSemanticComponent.fromDocumentComponent(component);
        final uid = semantic.uid!;
        grouped.putIfAbsent(uid, () => []).add(semantic);
      } on DavException catch (error) {
        if (policy == IcalIngestionPolicy.webCal) {
          throw IcalIngestionException(error.code, error.safeMessage);
        }
        rejected.add(
          IcalRejectedEvent(
            uid: component.firstProperty('UID')?.rawValue.trim(),
            code: error.code,
          ),
        );
      }
    }

    final sets = <IcalRecurrenceSet>[];
    for (final entry in grouped.entries) {
      final keys = <String>{};
      var duplicate = false;
      for (final component in entry.value) {
        final key = component.recurrenceId?.recurrenceKey ?? '';
        if (!keys.add(key)) duplicate = true;
      }
      if (duplicate) {
        if (policy == IcalIngestionPolicy.webCal) {
          throw const IcalIngestionException(
            'IcalDuplicateLogicalComponent',
            'The calendar contains duplicate event recurrence components.',
          );
        }
        rejected.add(
          IcalRejectedEvent(
            uid: entry.key,
            code: 'IcalDuplicateLogicalComponent',
          ),
        );
        continue;
      }
      try {
        final recurrenceDocument = IcalDocument.create(
          components: [
            for (final zone in timeZones) zone.deepCopy(),
            for (final component in entry.value)
              component.documentComponent.deepCopy(),
          ],
        );
        sets.add(
          IcalRecurrenceSet(
            uid: entry.key,
            semantic: IcalSemanticDocument.fromDocument(recurrenceDocument),
          ),
        );
      } on DavException catch (error) {
        if (policy == IcalIngestionPolicy.webCal) {
          throw IcalIngestionException(error.code, error.safeMessage);
        }
        rejected.add(IcalRejectedEvent(uid: entry.key, code: error.code));
      }
    }
    return IcalIngestionResult(
      document: document,
      recurrenceSets: List.unmodifiable(sets),
      rejectedEvents: List.unmodifiable(rejected),
      unprojectedComponentTypes: Set.unmodifiable(unknown),
      serverRefreshIntervalSeconds: _refreshIntervalSeconds(document),
    );
  }
}

void _validateCalendarEnvelope(IcalDocument document) {
  final versions = document.root.propertiesNamed('VERSION').toList();
  if (versions.length != 1 || versions.single.rawValue.trim() != '2.0') {
    throw const IcalIngestionException(
      'IcalInvalidVersion',
      'The calendar must contain exactly one VERSION:2.0 property.',
    );
  }
  final productIds = document.root.propertiesNamed('PRODID').toList();
  if (productIds.length != 1 || productIds.single.rawValue.trim().isEmpty) {
    throw const IcalIngestionException(
      'IcalInvalidProductIdentifier',
      'The calendar must contain exactly one non-empty PRODID property.',
    );
  }
  if (document.calendarComponents.isEmpty) {
    throw const IcalIngestionException(
      'IcalCalendarHasNoComponents',
      'The calendar contains no calendar components.',
    );
  }
}

int? _refreshIntervalSeconds(IcalDocument document) {
  final property = document.root.firstProperty('REFRESH-INTERVAL');
  if (property == null ||
      property.parameterValue('VALUE')?.toUpperCase() != 'DURATION') {
    return null;
  }
  try {
    final duration = parseIcalDuration(property.rawValue.toUpperCase());
    if (duration == null ||
        duration.negative ||
        duration.duration <= Duration.zero) {
      return null;
    }
    return duration.duration.inSeconds;
  } on DavException {
    return null;
  }
}

String sanitizedCanonicalSnapshot(
  IcalDocument input, {
  required Iterable<Uri> secretUris,
}) {
  final document = input.deepCopy();
  final secrets = secretUris.map((uri) => uri.toString()).toSet();
  void sanitize(IcalComponent component, {required bool topLevel}) {
    component.children.removeWhere((node) {
      if (node is! IcalProperty) return false;
      if (topLevel && (node.name == 'SOURCE' || node.name == 'URL')) {
        return true;
      }
      final value = node.rawValue.trim();
      return secrets.any(value.contains);
    });
    for (final child in component.components) {
      sanitize(child, topLevel: false);
    }
    component.structurallyDirty = true;
  }

  sanitize(document.root, topLevel: true);
  return document.serialize(canonicalizeUntouched: true);
}

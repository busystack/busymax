import 'package:drift/drift.dart';

import '../dav/dav_errors.dart';
import '../dav/ical/ical_document.dart';
import '../dav/ical/ical_semantics.dart';
import '../dav/ical/ical_timezone.dart';
import '../db/app_database.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/calendar/presentation/event_editor_draft.dart';
import '../features/recurrence/domain/event_recurrence_codec.dart';
import '../providers/busy_provider.dart';
import 'ical_ingestion.dart';

final class IcalImportPreview {
  const IcalImportPreview({
    required this.ingestion,
    required this.eventCount,
    required this.invalidEventCount,
    required this.fieldsThatWillBeOmitted,
  });

  final IcalIngestionResult ingestion;
  final int eventCount;
  final int invalidEventCount;
  final Set<String> fieldsThatWillBeOmitted;
}

final class IcalImportSkippedSet {
  const IcalImportSkippedSet({required this.uid, required this.reason});

  final String uid;
  final String reason;
}

final class IcalImportReport {
  const IcalImportReport({
    required this.queued,
    required this.duplicatesSkipped,
    required this.unsupportedRecurrenceSets,
    required this.invalidEvents,
    required this.fieldsIntentionallyOmitted,
  });

  final int queued;
  final int duplicatesSkipped;
  final List<IcalImportSkippedSet> unsupportedRecurrenceSets;
  final int invalidEvents;
  final Set<String> fieldsIntentionallyOmitted;
}

final class IcalImportService {
  IcalImportService({
    required AppDatabase database,
    required CalendarRepository calendarRepository,
  }) : _database = database,
       _calendarRepository = calendarRepository;

  final AppDatabase _database;
  final CalendarRepository _calendarRepository;

  IcalImportPreview parsePreview(List<int> bytes) {
    final ingestion = IcalIngestion.parseBytes(
      bytes,
      policy: IcalIngestionPolicy.fileImport,
    );
    final omitted = <String>{};
    if (ingestion.document.root.firstProperty('METHOD') != null) {
      omitted.add('scheduling method');
    }
    for (final set in ingestion.recurrenceSets) {
      for (final event in set.semantic.components) {
        if (event.attendees.isNotEmpty) omitted.add('attendees');
        if (event.organizers.isNotEmpty) omitted.add('organizer');
        if (event.url != null) omitted.add('URL');
        if (event.documentComponent.propertiesNamed('ATTACH').isNotEmpty) {
          omitted.add('attachments');
        }
        if (event.documentComponent.propertiesNamed('IMAGE').isNotEmpty) {
          omitted.add('images');
        }
        if (event.documentComponent.propertiesNamed('SOURCE').isNotEmpty) {
          omitted.add('source links');
        }
        if (event.documentComponent.propertiesNamed('CONFERENCE').isNotEmpty) {
          omitted.add('conference links');
        }
        if (event.alarms.any((alarm) => _alarmMinutes([alarm]).isEmpty)) {
          omitted.add('unsupported alarms');
        }
      }
    }
    for (final componentType in ingestion.unprojectedComponentTypes) {
      omitted.add('$componentType components');
    }
    return IcalImportPreview(
      ingestion: ingestion,
      eventCount: ingestion.recurrenceSets.length,
      invalidEventCount: ingestion.rejectedEvents.length,
      fieldsThatWillBeOmitted: Set.unmodifiable(omitted),
    );
  }

  Future<List<CalendarSourceEntity>> writableDestinations() async {
    final rows =
        await (_database.select(_database.calendarSources)..where(
              (row) =>
                  row.readOnly.equals(false) &
                  row.isDeleted.equals(false) &
                  row.provider.equals(BusyProvider.webCal.storageValue).not(),
            ))
            .get();
    final pendingIds = <String>{
      for (final op
          in await (_database.select(_database.pendingOps)..where(
                (row) =>
                    row.operationType.equals('calendar.create') &
                    row.state.isIn(const ['pending', 'retry', 'in_progress']),
              ))
              .get())
        if (op.calendarSourceId != null) op.calendarSourceId!,
    };
    return [
      for (final row in rows)
        CalendarSourceEntity.fromRow(
          row,
          pendingCreate: pendingIds.contains(row.id),
        ),
    ];
  }

  Future<IcalImportReport> importPreview({
    required IcalImportPreview preview,
    required CalendarSourceEntity destination,
  }) async {
    if (!destination.capabilities.canCreateEvents ||
        destination.provider == BusyProvider.webCal) {
      throw ArgumentError('The selected calendar is not writable.');
    }
    final receipts = await (_database.select(
      _database.icalImportReceipts,
    )..where((row) => row.calendarSourceId.equals(destination.id))).get();
    final importedUids = {for (final receipt in receipts) receipt.icalUid};
    final drafts = <({String icalUid, EventEditorDraft draft})>[];
    final unsupported = <IcalImportSkippedSet>[];
    var duplicates = 0;
    final omitted = {...preview.fieldsThatWillBeOmitted};
    for (final set in preview.ingestion.recurrenceSets) {
      if (importedUids.contains(set.uid)) {
        duplicates += 1;
        continue;
      }
      final prepared = _prepareDraft(set, destination);
      if (prepared.reason != null) {
        unsupported.add(
          IcalImportSkippedSet(uid: set.uid, reason: prepared.reason!),
        );
        continue;
      }
      omitted.addAll(prepared.omittedFields);
      drafts.add((icalUid: set.uid, draft: prepared.draft!));
    }
    await _calendarRepository.createImportedEventsBatch(
      destination: destination,
      events: drafts,
    );
    return IcalImportReport(
      queued: drafts.length,
      duplicatesSkipped: duplicates,
      unsupportedRecurrenceSets: List.unmodifiable(unsupported),
      invalidEvents: preview.invalidEventCount,
      fieldsIntentionallyOmitted: Set.unmodifiable(omitted),
    );
  }
}

_PreparedImportDraft _prepareDraft(
  IcalRecurrenceSet set,
  CalendarSourceEntity destination,
) {
  final semantic = set.semantic;
  final masters = semantic.components
      .where((component) => component.recurrenceId == null)
      .toList();
  if (masters.length != 1) {
    return const _PreparedImportDraft.unsupported(
      'The recurrence set does not contain exactly one master event.',
    );
  }
  if (semantic.components.length != 1) {
    return const _PreparedImportDraft.unsupported(
      'Detached recurrence exceptions are not supported by this destination import.',
    );
  }
  final master = masters.single;
  final title = master.summary?.trim();
  if (title == null || title.isEmpty) {
    return const _PreparedImportDraft.unsupported(
      'BusyMax requires an event summary.',
    );
  }
  final startValue = master.start;
  if (startValue == null) {
    return const _PreparedImportDraft.unsupported(
      'The event does not contain DTSTART.',
    );
  }
  if (startValue.kind == IcalTemporalKind.floatingDateTime) {
    return const _PreparedImportDraft.unsupported(
      'Floating date-times cannot be imported without guessing a timezone.',
    );
  }
  final resolver = IcalTimeZoneResolver.fromDocument(semantic);
  final providerTimeZones = IcalTimeZoneResolver.system();
  try {
    if (startValue.kind == IcalTemporalKind.tzidDateTime) {
      resolver.toUtc(startValue);
      providerTimeZones.toUtc(startValue);
    }
    if (master.end?.kind == IcalTemporalKind.tzidDateTime) {
      resolver.toUtc(master.end!);
      providerTimeZones.toUtc(master.end!);
    }
  } on DavException catch (error) {
    if (error.code == 'IcalUnknownTimeZone') {
      return const _PreparedImportDraft.unsupported(
        'The destination cannot represent this embedded custom timezone.',
      );
    }
    return _PreparedImportDraft.unsupported(error.safeMessage);
  }

  final allDay = startValue.kind == IcalTemporalKind.date;
  final start = _draftDateTime(startValue);
  final endValue = master.end;
  final DateTime end;
  String? endTimeZone;
  if (endValue != null) {
    if (endValue.kind == IcalTemporalKind.floatingDateTime) {
      return const _PreparedImportDraft.unsupported(
        'Floating date-times cannot be imported without guessing a timezone.',
      );
    }
    if ((endValue.kind == IcalTemporalKind.date) != allDay) {
      return const _PreparedImportDraft.unsupported(
        'The event start and end use incompatible value types.',
      );
    }
    end = _draftDateTime(endValue);
    endTimeZone = _timeZone(endValue);
  } else if (master.duration != null) {
    end = _addWallDuration(startValue, master.duration!.duration);
    endTimeZone = _timeZone(startValue);
  } else if (allDay) {
    end = DateTime(start.year, start.month, start.day + 1);
  } else {
    return const _PreparedImportDraft.unsupported(
      'Zero-duration date-time events cannot be represented by BusyMax.',
    );
  }
  if (!end.isAfter(start)) {
    return const _PreparedImportDraft.unsupported(
      'The event has a non-positive duration.',
    );
  }

  final recurrenceMap = <String, Object?>{
    'rules': master.recurrenceRules,
    'dates': master.recurrenceDates,
    'excludedDates': master.exceptionDates,
  };
  Object? recurrence;
  if (master.recurrenceRules.isNotEmpty ||
      master.recurrenceDates.isNotEmpty ||
      master.exceptionDates.isNotEmpty) {
    if (destination.provider == BusyProvider.microsoft &&
        (master.recurrenceDates.isNotEmpty ||
            master.exceptionDates.isNotEmpty)) {
      return const _PreparedImportDraft.unsupported(
        'Microsoft cannot represent this event’s RDATE or EXDATE set.',
      );
    }
    final rule = EventRecurrenceCodec.decode(
      BusyProvider.google,
      recurrenceMap,
      baseDate: start,
    );
    if (!rule.repeats ||
        !EventRecurrenceCodec.canEncode(destination.provider, rule)) {
      return _PreparedImportDraft.unsupported(
        '${destination.provider.displayName} cannot represent this recurrence rule.',
      );
    }
    recurrence = EventRecurrenceCodec.encode(
      destination.provider,
      rule,
      baseDate: start,
      allDay: allDay,
      timeZone: _timeZone(startValue),
      original: recurrenceMap,
    );
  }

  final reminderMinutes = _alarmMinutes(master.alarms);
  final reminders = switch (destination.provider) {
    BusyProvider.microsoft when reminderMinutes.isNotEmpty => {
      'isReminderOn': true,
      'reminderMinutesBeforeStart': reminderMinutes.first,
    },
    BusyProvider.google ||
    BusyProvider.appleICloud ||
    BusyProvider.nextcloud when reminderMinutes.isNotEmpty => {
      'useDefault': false,
      'overrides': [
        for (final minutes in reminderMinutes)
          {'method': 'popup', 'minutes': minutes},
      ],
    },
    _ => null,
  };
  final omitted = <String>{};
  if (destination.provider == BusyProvider.microsoft &&
      reminderMinutes.length > 1) {
    omitted.add('additional reminders');
  }
  if (destination.provider == BusyProvider.google &&
      master.categories.isNotEmpty) {
    omitted.add('categories');
  }
  final categories = destination.provider == BusyProvider.google
      ? const <String>[]
      : master.categories;
  return _PreparedImportDraft(
    draft:
        EventEditorDraft.newEvent(
          accountId: destination.accountId,
          sourceId: destination.id,
          providerCalendarId: destination.providerCalendarId,
          start: start,
          end: end,
        ).copyWith(
          title: title,
          allDay: allDay,
          startTimeZone: _timeZone(startValue),
          endTimeZone: endTimeZone,
          description: master.description,
          location: master.location,
          recurrence: recurrence,
          recurrenceChanged: recurrence != null,
          reminders: reminders,
          remindersChanged: reminders != null,
          attendees: const [],
          attendeesChanged: false,
          showAs: _transparency(master.transparency, destination.provider),
          visibilityOrSensitivity: master.classification?.toLowerCase(),
          categories: categories,
          categoriesChanged: categories.isNotEmpty,
          createConference: false,
          clearConference: true,
          isOrganizer: true,
        ),
    reason: null,
    omittedFields: omitted,
  );
}

DateTime _draftDateTime(IcalTemporalValue value) {
  final wall = value.localValue;
  if (value.kind == IcalTemporalKind.utcDateTime) return wall.toUtc();
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
}

DateTime _addWallDuration(IcalTemporalValue value, Duration duration) {
  final wall = value.localValue.add(duration);
  if (value.kind == IcalTemporalKind.utcDateTime) return wall.toUtc();
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );
}

String? _timeZone(IcalTemporalValue value) => switch (value.kind) {
  IcalTemporalKind.utcDateTime => 'UTC',
  IcalTemporalKind.tzidDateTime => value.timeZoneId,
  IcalTemporalKind.date || IcalTemporalKind.floatingDateTime => null,
};

String? _transparency(String? value, BusyProvider provider) {
  final normalized = value?.toUpperCase();
  if (provider == BusyProvider.microsoft) {
    return normalized == 'TRANSPARENT' ? 'free' : 'busy';
  }
  return switch (normalized) {
    'TRANSPARENT' => 'transparent',
    'OPAQUE' => 'opaque',
    _ => null,
  };
}

List<int> _alarmMinutes(List<IcalComponent> alarms) {
  final values = <int>[];
  for (final alarm in alarms) {
    final action = alarm.firstProperty('ACTION')?.rawValue.toUpperCase();
    final trigger = alarm.firstProperty('TRIGGER');
    if ((action != 'DISPLAY' && action != 'AUDIO') || trigger == null) continue;
    if (trigger.parameterValue('RELATED')?.toUpperCase() == 'END') continue;
    try {
      final duration = parseIcalDuration(trigger.rawValue.toUpperCase());
      if (duration == null || !duration.negative) continue;
      final before = -duration.duration;
      if (before.inSeconds <= 0 || before.inSeconds % 60 != 0) continue;
      if (!values.contains(before.inMinutes)) values.add(before.inMinutes);
    } on DavException {
      // Unsupported alarms are intentionally omitted and reported by preview.
    }
  }
  return values;
}

final class _PreparedImportDraft {
  const _PreparedImportDraft({
    required this.draft,
    required this.reason,
    this.omittedFields = const {},
  });

  const _PreparedImportDraft.unsupported(String reason)
    : draft = null,
      reason = reason,
      omittedFields = const {};

  final EventEditorDraft? draft;
  final String? reason;
  final Set<String> omittedFields;
}

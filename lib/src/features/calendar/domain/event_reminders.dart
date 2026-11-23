import '../../../providers/busy_provider.dart';
import 'dav_event_reminders.dart';

const googleReminderLimit = 5;
const eventReminderMinuteOptions = [5, 10, 30, 60, 1440, 0];

/// Edits only the rows the provider exposes as start-relative reminders.
final class EventReminderEditor {
  const EventReminderEditor(this.provider, this.payload);

  final BusyProvider provider;
  final Object? payload;

  List<int> get minutes => switch (provider) {
    BusyProvider.google => [
      for (final row in googlePopupReminderRows(payload)) row.minutes,
    ],
    BusyProvider.microsoft => [
      if (payload
          case {
            'isReminderOn': true,
            'reminderMinutesBeforeStart': final int minutes,
          }
          when minutes >= 0)
        minutes,
    ],
    _ => [
      for (final row in davEventEditableReminderRows(payload) ?? const [])
        row.minutes,
    ],
  };

  bool get canAdd => switch (provider) {
    BusyProvider.google =>
      googleReminderOverrideCount(payload) < googleReminderLimit,
    BusyProvider.microsoft => minutes.isEmpty,
    _ => minutes.length < eventReminderMinuteOptions.length,
  };

  bool get hasUnsupportedRows =>
      provider == BusyProvider.google && googleHasUnsupportedReminder(payload);

  Object edit(int? index, int minutes) => _update(index, minutes);
  Object remove(int index) => _update(index, null);

  Object _update(int? index, int? minutes) {
    if (provider == BusyProvider.google) {
      final overrideIndex = index == null
          ? null
          : googlePopupReminderRows(payload)[index].index;
      return minutes == null
          ? removeGooglePopupReminder(payload, overrideIndex: overrideIndex!)
          : editGooglePopupReminder(
              payload,
              overrideIndex: overrideIndex,
              minutes: minutes,
            );
    }
    if (provider == BusyProvider.microsoft) {
      return {
        if (payload case final Map<String, Object?> original)
          for (final entry in original.entries)
            if (entry.key != 'reminderMinutesBeforeStart')
              entry.key: entry.value,
        'isReminderOn': minutes != null,
        if (minutes != null) 'reminderMinutesBeforeStart': minutes,
      };
    }
    final rows = [...?davEventEditableReminderRows(payload)];
    if (index == null) {
      rows.add(DavEventReminderRow(minutes: minutes!));
    } else if (minutes == null) {
      rows.removeAt(index);
    } else {
      rows[index] = rows[index].copyWith(minutes: minutes);
    }
    return davEventReminderPayload(rows);
  }

  /// Convert only the interoperable reminder offsets when changing providers.
  Object? forDestination(BusyProvider destination) {
    if (destination == provider || provider.isDav && destination.isDav) {
      return payload;
    }
    final offsets = minutes.toSet();
    return switch (destination) {
      BusyProvider.google => {
        'useDefault': false,
        'overrides': [
          for (final minute in offsets.take(googleReminderLimit))
            {'method': 'popup', 'minutes': minute},
        ],
      },
      BusyProvider.microsoft => {
        'isReminderOn': offsets.isNotEmpty,
        if (offsets.isNotEmpty) 'reminderMinutesBeforeStart': offsets.first,
      },
      _ => {'minutes': offsets.toList()},
    };
  }
}

List<int> eventReminderValuesFor(int selected) =>
    eventReminderMinuteOptions.contains(selected)
    ? eventReminderMinuteOptions
    : [...eventReminderMinuteOptions, selected];

int nextEventReminderMinute(List<int> existing) =>
    eventReminderMinuteOptions.firstWhere(
      (minute) => !existing.contains(minute),
      orElse: () => eventReminderMinuteOptions.first,
    );

int? googleReminderMode(Object? value) {
  if (value == null) {
    return -1;
  }
  if (value is! Map) {
    return null;
  }
  if (value['useDefault'] == true) {
    return -1;
  }
  if (value['useDefault'] != false || value['overrides'] is! List) {
    return null;
  }
  return (value['overrides'] as List).isEmpty ? -2 : -3;
}

List<({int index, int minutes})> googlePopupReminderRows(Object? value) {
  if (value is! Map || value['overrides'] is! List) {
    return const [];
  }
  final overrides = value['overrides'] as List;
  return [
    for (var index = 0; index < overrides.length; index++)
      if (overrides[index] case final Map entry
          when entry['method'] == 'popup' &&
              entry['minutes'] is int &&
              (entry['minutes'] as int) >= 0)
        (index: index, minutes: entry['minutes'] as int),
  ];
}

int googleReminderOverrideCount(Object? value) =>
    value is Map && value['overrides'] is List
    ? (value['overrides'] as List).length
    : 0;

bool googleHasUnsupportedReminder(Object? value) {
  if (value is! Map || value['overrides'] is! List) {
    return false;
  }
  return googlePopupReminderRows(value).length !=
      (value['overrides'] as List).length;
}

Map<String, Object?> setGoogleReminderMode(Object? value, int mode) {
  if (mode == -1) {
    return const {'useDefault': true};
  }
  if (mode == -2) {
    return const {'useDefault': false, 'overrides': []};
  }
  if (mode != -3) {
    throw ArgumentError.value(mode, 'mode');
  }
  final original = value is Map ? value.cast<String, Object?>() : const {};
  final existing = original['overrides'];
  return {
    ...original,
    'useDefault': false,
    'overrides': existing is List && existing.isNotEmpty
        ? [...existing]
        : [
            {'method': 'popup', 'minutes': 10},
          ],
  };
}

Map<String, Object?> editGooglePopupReminder(
  Object? value, {
  required int? overrideIndex,
  required int minutes,
}) {
  if (minutes < 0) {
    throw ArgumentError.value(minutes, 'minutes');
  }
  final original = value is Map ? value.cast<String, Object?>() : const {};
  final overrides = [
    if (original['overrides'] case final List entries) ...entries,
  ];
  if (overrideIndex == null) {
    if (overrides.length >= googleReminderLimit) {
      throw StateError('Google allows at most five event reminders.');
    }
    overrides.add({'method': 'popup', 'minutes': minutes});
  } else {
    if (overrideIndex < 0 ||
        overrideIndex >= overrides.length ||
        overrides[overrideIndex] is! Map ||
        (overrides[overrideIndex] as Map)['method'] != 'popup') {
      throw RangeError.index(overrideIndex, overrides);
    }
    overrides[overrideIndex] = {
      ...(overrides[overrideIndex] as Map).cast<String, Object?>(),
      'minutes': minutes,
    };
  }
  return {...original, 'useDefault': false, 'overrides': overrides};
}

Map<String, Object?> removeGooglePopupReminder(
  Object? value, {
  required int overrideIndex,
}) {
  final original = value is Map ? value.cast<String, Object?>() : const {};
  final overrides = [
    if (original['overrides'] case final List entries) ...entries,
  ];
  if (overrideIndex < 0 ||
      overrideIndex >= overrides.length ||
      overrides[overrideIndex] is! Map ||
      (overrides[overrideIndex] as Map)['method'] != 'popup') {
    throw RangeError.index(overrideIndex, overrides);
  }
  overrides.removeAt(overrideIndex);
  return {...original, 'useDefault': false, 'overrides': overrides};
}

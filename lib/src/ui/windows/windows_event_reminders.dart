import '../../providers/busy_provider.dart';

const windowsEventReminderMinuteOptions = [0, 5, 10, 30, 60, 1440];

List<int> decodeWindowsEventReminderMinutes(Object? reminders) {
  if (reminders is! Map) return const [];
  final direct = reminders['reminderMinutesBeforeStart'];
  if (direct is int) return normalizeWindowsEventReminderMinutes([direct]);
  final overrides = reminders['overrides'];
  if (overrides is List) {
    final result = <int>[];
    for (final value in overrides) {
      if (value is Map && value['minutes'] is int) {
        result.add(value['minutes'] as int);
      }
    }
    return normalizeWindowsEventReminderMinutes(result);
  }
  final davMinutes = reminders['minutes'];
  return davMinutes is List
      ? normalizeWindowsEventReminderMinutes(davMinutes.whereType<int>())
      : const [];
}

List<int> normalizeWindowsEventReminderMinutes(Iterable<int> values) {
  final result = <int>[];
  for (final value in values) {
    if (value < 0 || result.contains(value)) continue;
    result.add(value);
  }
  return result;
}

Object encodeWindowsEventReminderPayload(
  BusyProvider provider,
  List<int> minutes,
) {
  final normalized = normalizeWindowsEventReminderMinutes(minutes);
  if (provider == BusyProvider.microsoft) {
    return normalized.isEmpty
        ? const <String, Object?>{'isReminderOn': false}
        : <String, Object?>{
            'isReminderOn': true,
            'reminderMinutesBeforeStart': normalized.first,
          };
  }
  return <String, Object?>{
    'useDefault': false,
    'overrides': [
      for (final value in normalized)
        <String, Object?>{'method': 'popup', 'minutes': value},
    ],
  };
}

List<int> windowsEventReminderValuesFor(int selected) =>
    windowsEventReminderMinuteOptions.contains(selected)
    ? windowsEventReminderMinuteOptions
    : [...windowsEventReminderMinuteOptions, selected];

int nextWindowsEventReminderMinute(List<int> existing) {
  for (final value in windowsEventReminderMinuteOptions) {
    if (!existing.contains(value)) return value;
  }
  return windowsEventReminderMinuteOptions.first;
}

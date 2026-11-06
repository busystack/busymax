final class DavEventReminderRow {
  const DavEventReminderRow({required this.minutes, this.originalIndex});

  final int minutes;
  final int? originalIndex;

  DavEventReminderRow copyWith({required int minutes}) =>
      DavEventReminderRow(minutes: minutes, originalIndex: originalIndex);

  Map<String, Object?> toJson() => {
    if (originalIndex != null) 'originalIndex': originalIndex,
    'minutes': minutes,
  };

  static DavEventReminderRow fromJson(Object? value) {
    if (value is! Map ||
        value['minutes'] is! int ||
        (value['minutes'] as int) < 0 ||
        (value['originalIndex'] != null && value['originalIndex'] is! int)) {
      throw const FormatException('Invalid recovered DAV reminder.');
    }
    return DavEventReminderRow(
      minutes: value['minutes'] as int,
      originalIndex: value['originalIndex'] as int?,
    );
  }
}

List<DavEventReminderRow>? davEventEditableReminderRows(Object? value) {
  if (value == null) return const [];
  if (value is! Map) return null;
  if (value['davEditableRows'] is List) {
    try {
      return [
        for (final row in value['davEditableRows'] as List)
          DavEventReminderRow.fromJson(row),
      ];
    } on FormatException {
      return null;
    }
  }
  if (value['alarms'] case final List alarms) {
    final rows = <DavEventReminderRow>[];
    for (var index = 0; index < alarms.length; index++) {
      final alarm = alarms[index];
      if (alarm is! Map || alarm['properties'] is! List) return null;
      final properties = alarm['properties'] as List;
      String? property(String name) {
        for (final item in properties) {
          if (item is Map && item['name'] == name) {
            return item['value']?.toString();
          }
        }
        return null;
      }

      if (property('ACTION')?.toUpperCase() != 'DISPLAY') continue;
      final triggerProperty = properties
          .whereType<Map>()
          .where((item) => item['name']?.toString().toUpperCase() == 'TRIGGER')
          .firstOrNull;
      final triggerParameters = triggerProperty?['parameters'];
      if (triggerParameters is List &&
          triggerParameters.whereType<Map>().any((parameter) {
            if (parameter['name']?.toString().toUpperCase() != 'RELATED') {
              return false;
            }
            final values = parameter['values'];
            return values is! List ||
                values.length != 1 ||
                values.single.toString().toUpperCase() != 'START';
          })) {
        continue;
      }
      final trigger = property('TRIGGER')?.toUpperCase();
      final match = trigger == null
          ? null
          : RegExp(r'^-PT([0-9]+)M$').firstMatch(trigger);
      if (match != null) {
        rows.add(
          DavEventReminderRow(
            minutes: int.parse(match.group(1)!),
            originalIndex: index,
          ),
        );
      }
    }
    return rows;
  }
  if (value['minutes'] case final List minutes) {
    if (minutes.any((minute) => minute is! int || minute < 0)) return null;
    return [
      for (final minute in minutes) DavEventReminderRow(minutes: minute as int),
    ];
  }
  return null;
}

Object davEventReminderPayload(List<DavEventReminderRow> rows) => {
  'davEditableRows': [for (final row in rows) row.toJson()],
};

bool davEventRemindersHaveIdentities(Object? value) =>
    value is Map &&
    (value['alarms'] is List || value['davEditableRows'] is List);

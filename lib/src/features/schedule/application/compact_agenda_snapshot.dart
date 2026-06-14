import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_range.dart';
import '../../../task_providers/task_provider.dart';
import 'compact_agenda_data.dart';
import 'compact_agenda_sections.dart';

Map<String, Object?> encodeCompactAgendaQuery(CompactAgendaQuery query) {
  return {
    'futureDays': query.futureDays,
    'overdueLimit': query.overdueLimit,
    'noDateLimit': query.noDateLimit,
  };
}

CompactAgendaQuery decodeCompactAgendaQuery(Object? raw) {
  if (raw is! Map) {
    return CompactAgendaQuery.initial;
  }
  final map = raw.cast<Object?, Object?>();
  return CompactAgendaQuery(
    futureDays: _intValue(map, 'futureDays', compactAgendaInitialDays),
    overdueLimit: _intValue(
      map,
      'overdueLimit',
      compactAgendaInitialOverdueLimit,
    ),
    noDateLimit: _intValue(map, 'noDateLimit', compactAgendaInitialNoDateLimit),
  );
}

Map<String, Object?> encodeCompactAgendaData(CompactAgendaData data) {
  return {
    'today': data.today.toIso8601String(),
    'rangeStart': data.range.start.toIso8601String(),
    'rangeEnd': data.range.end.toIso8601String(),
    'items': data.items.map(encodeScheduleItem).toList(),
    'hasMoreOverdueTasks': data.hasMoreOverdueTasks,
    'hasMoreNoDateTasks': data.hasMoreNoDateTasks,
    'hasSignedInAccounts': data.hasSignedInAccounts,
    'hasSources': data.hasSources,
    'generatedAt': data.generatedAt.toIso8601String(),
  };
}

CompactAgendaData decodeCompactAgendaData(Object? raw) {
  final map = _mapValue(raw);
  return CompactAgendaData(
    today: _requiredDateTime(map, 'today'),
    range: ScheduleRange(
      start: _requiredDateTime(map, 'rangeStart'),
      end: _requiredDateTime(map, 'rangeEnd'),
    ),
    items: _listValue(map['items']).map(decodeScheduleItem).toList(),
    hasMoreOverdueTasks: _boolValue(map, 'hasMoreOverdueTasks'),
    hasMoreNoDateTasks: _boolValue(map, 'hasMoreNoDateTasks'),
    hasSignedInAccounts: _boolValue(map, 'hasSignedInAccounts'),
    hasSources: _boolValue(map, 'hasSources'),
    generatedAt: _requiredDateTime(map, 'generatedAt'),
  );
}

Map<String, Object?> encodeScheduleItem(ScheduleItem item) {
  final common = <String, Object?>{
    'kind': item is TaskScheduleItem ? 'task' : 'calendarEvent',
    'id': item.id,
    'accountId': item.accountId,
    'provider': item.provider.storageValue,
    'sourceId': item.sourceId,
    'title': item.title,
    'sourceName': item.sourceName,
    'accountDisplayName': item.accountDisplayName,
    'accountEmail': item.accountEmail,
    'start': item.start?.toIso8601String(),
    'end': item.end?.toIso8601String(),
    'allDay': item.allDay,
    'categories': item.categories,
  };
  if (item is TaskScheduleItem) {
    return {
      ...common,
      'completed': item.completed,
      'notes': item.notes,
      'reminder': item.reminder?.toIso8601String(),
    };
  }
  final event = item as CalendarScheduleItem;
  return {
    ...common,
    'providerCalendarId': event.providerCalendarId,
    'startTimeZone': event.startTimeZone,
    'endTimeZone': event.endTimeZone,
    'location': event.location,
    'description': event.description,
    'descriptionContentType': event.descriptionContentType,
    'descriptionHtml': event.descriptionHtml,
    'colorHex': event.colorHex,
    'reminderMinutesBeforeStart': event.reminderMinutesBeforeStart,
  };
}

ScheduleItem decodeScheduleItem(Object? raw) {
  final map = _mapValue(raw);
  final kind = _requiredString(map, 'kind');
  final provider = TaskProviderParsing.fromStorageValue(
    _optionalString(map, 'provider'),
  );
  final common = _ScheduleItemCommon(
    id: _requiredString(map, 'id'),
    accountId: _requiredString(map, 'accountId'),
    provider: provider,
    sourceId: _requiredString(map, 'sourceId'),
    title: _requiredString(map, 'title'),
    sourceName: _optionalString(map, 'sourceName'),
    accountDisplayName: _optionalString(map, 'accountDisplayName'),
    accountEmail: _optionalString(map, 'accountEmail'),
    start: _optionalDateTime(map, 'start'),
    end: _optionalDateTime(map, 'end'),
    allDay: _boolValue(map, 'allDay'),
    categories: _stringListValue(map['categories']),
  );
  if (kind == 'task') {
    return TaskScheduleItem(
      id: common.id,
      accountId: common.accountId,
      provider: common.provider,
      sourceId: common.sourceId,
      title: common.title,
      completed: _boolValue(map, 'completed'),
      allDay: common.allDay,
      start: common.start,
      end: common.end,
      notes: _optionalString(map, 'notes'),
      categories: common.categories,
      reminder: _optionalDateTime(map, 'reminder'),
      sourceName: common.sourceName,
      accountDisplayName: common.accountDisplayName,
      accountEmail: common.accountEmail,
    );
  }
  if (kind != 'calendarEvent') {
    throw FormatException('Unsupported compact agenda item kind $kind.');
  }
  return CalendarScheduleItem(
    id: common.id,
    accountId: common.accountId,
    provider: common.provider,
    sourceId: common.sourceId,
    providerCalendarId:
        _optionalString(map, 'providerCalendarId') ?? common.sourceId,
    title: common.title,
    allDay: common.allDay,
    start: common.start,
    end: common.end,
    startTimeZone: _optionalString(map, 'startTimeZone'),
    endTimeZone: _optionalString(map, 'endTimeZone'),
    location: _optionalString(map, 'location'),
    description: _optionalString(map, 'description'),
    descriptionContentType: _optionalString(map, 'descriptionContentType'),
    descriptionHtml: _optionalString(map, 'descriptionHtml'),
    colorHex: _optionalString(map, 'colorHex'),
    categories: common.categories,
    reminderMinutesBeforeStart: _intListValue(
      map['reminderMinutesBeforeStart'],
    ),
    sourceName: common.sourceName,
    accountDisplayName: common.accountDisplayName,
    accountEmail: common.accountEmail,
  );
}

class _ScheduleItemCommon {
  const _ScheduleItemCommon({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.sourceId,
    required this.title,
    required this.sourceName,
    required this.accountDisplayName,
    required this.accountEmail,
    required this.start,
    required this.end,
    required this.allDay,
    required this.categories,
  });

  final String id;
  final String accountId;
  final TaskProvider provider;
  final String sourceId;
  final String title;
  final String? sourceName;
  final String? accountDisplayName;
  final String? accountEmail;
  final DateTime? start;
  final DateTime? end;
  final bool allDay;
  final List<String> categories;
}

Map<Object?, Object?> _mapValue(Object? value) {
  if (value is! Map) {
    throw const FormatException('Compact agenda snapshot is not a map.');
  }
  return value.cast<Object?, Object?>();
}

List<Object?> _listValue(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.cast<Object?>();
}

List<String> _stringListValue(Object? value) {
  return _listValue(value).map((item) => item.toString()).toList();
}

List<int> _intListValue(Object? value) {
  return _listValue(value)
      .map((item) => item is int ? item : int.tryParse(item.toString()))
      .nonNulls
      .toList();
}

String _requiredString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    throw FormatException('Compact agenda snapshot missing $key.');
  }
  return value.toString();
}

String? _optionalString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

DateTime _requiredDateTime(Map<Object?, Object?> map, String key) {
  final value = _optionalDateTime(map, key);
  if (value == null) {
    throw FormatException('Compact agenda snapshot missing $key.');
  }
  return value;
}

DateTime? _optionalDateTime(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

bool _boolValue(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  return value?.toString() == 'true';
}

int _intValue(Map<Object?, Object?> map, String key, int fallback) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

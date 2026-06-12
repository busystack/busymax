import '../task_providers/task_provider.dart';

enum ScheduleItemKind { calendarEvent, task, localReminder }

sealed class ScheduleItem {
  String get id;
  String get accountId;
  BusyProvider get provider;
  String get sourceId;
  String get title;
  String? get sourceName;
  String? get accountDisplayName;
  String? get accountEmail;
  DateTime? get start;
  DateTime? get end;
  bool get allDay;
  List<String> get categories;
  ScheduleItemKind get kind;
}

class CalendarScheduleItem implements ScheduleItem {
  const CalendarScheduleItem({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.sourceId,
    required this.providerCalendarId,
    required this.title,
    required this.allDay,
    this.start,
    this.end,
    this.startTimeZone,
    this.endTimeZone,
    this.location,
    this.description,
    this.descriptionContentType,
    this.descriptionHtml,
    this.colorHex,
    this.categories = const [],
    this.reminderMinutesBeforeStart = const [],
    this.sourceName,
    this.accountDisplayName,
    this.accountEmail,
  });

  @override
  final String id;
  @override
  final String accountId;
  @override
  final BusyProvider provider;
  @override
  final String sourceId;
  final String providerCalendarId;
  @override
  final String title;
  @override
  final DateTime? start;
  @override
  final DateTime? end;
  final String? startTimeZone;
  final String? endTimeZone;
  @override
  final bool allDay;
  final String? location;
  final String? description;
  final String? descriptionContentType;
  final String? descriptionHtml;
  final String? colorHex;
  @override
  final List<String> categories;
  final List<int> reminderMinutesBeforeStart;
  @override
  final String? sourceName;
  @override
  final String? accountDisplayName;
  @override
  final String? accountEmail;

  @override
  ScheduleItemKind get kind => ScheduleItemKind.calendarEvent;
}

class TaskScheduleItem implements ScheduleItem {
  const TaskScheduleItem({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.sourceId,
    required this.title,
    required this.completed,
    required this.allDay,
    this.start,
    this.end,
    this.notes,
    this.categories = const [],
    this.reminder,
    this.sourceName,
    this.accountDisplayName,
    this.accountEmail,
  });

  @override
  final String id;
  @override
  final String accountId;
  @override
  final BusyProvider provider;
  @override
  final String sourceId;
  @override
  final String title;
  @override
  final DateTime? start;
  @override
  final DateTime? end;
  @override
  final bool allDay;
  final bool completed;
  final String? notes;
  @override
  final List<String> categories;
  final DateTime? reminder;
  @override
  final String? sourceName;
  @override
  final String? accountDisplayName;
  @override
  final String? accountEmail;

  @override
  ScheduleItemKind get kind => ScheduleItemKind.task;
}

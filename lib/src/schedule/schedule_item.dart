import 'package:busymax/src/providers/busy_provider.dart';
import '../features/tasks/domain/task_checklist_item.dart';

enum ScheduleItemKind { calendarEvent, task, localReminder }

class ScheduleItemCapabilities {
  const ScheduleItemCapabilities({
    required this.canEdit,
    required this.canDelete,
  });

  static const editable = ScheduleItemCapabilities(
    canEdit: true,
    canDelete: true,
  );
  static const readOnly = ScheduleItemCapabilities(
    canEdit: false,
    canDelete: false,
  );

  final bool canEdit;
  final bool canDelete;
}

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
  ScheduleItemCapabilities get capabilities;
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
    this.providerRecurringEventId,
    this.end,
    this.location,
    this.description,
    this.descriptionContentType,
    this.descriptionHtml,
    this.attendees = const [],
    this.organizer,
    this.joinMeetingUrl,
    this.isOrganizer,
    this.currentUserResponse,
    this.colorHex,
    this.categories = const [],
    this.reminderMinutesBeforeStart = const [],
    this.sourceName,
    this.accountDisplayName,
    this.accountEmail,
    this.capabilities = ScheduleItemCapabilities.editable,
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
  final String? providerRecurringEventId;
  @override
  final String title;
  @override
  final DateTime? start;
  @override
  final DateTime? end;
  @override
  final bool allDay;
  final String? location;
  final String? description;
  final String? descriptionContentType;
  final String? descriptionHtml;
  final List<Map<String, Object?>> attendees;
  final Map<String, Object?>? organizer;
  final String? joinMeetingUrl;
  final bool? isOrganizer;
  final String? currentUserResponse;
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
  final ScheduleItemCapabilities capabilities;

  bool get canRespondToInvitation {
    return isOrganizer == false &&
        currentUserResponse != null &&
        (provider == BusyProvider.google || provider == BusyProvider.microsoft);
  }

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
    this.parentId,
    this.parentTitle,
    this.hierarchyDepth = 0,
    this.hasSubtasks = false,
    this.checklistItems = const [],
    this.sourceName,
    this.accountDisplayName,
    this.accountEmail,
    this.capabilities = ScheduleItemCapabilities.editable,
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
  final String? parentId;
  final String? parentTitle;
  final int hierarchyDepth;
  final bool hasSubtasks;
  final List<TaskChecklistItemEntity> checklistItems;
  @override
  final String? sourceName;
  @override
  final String? accountDisplayName;
  @override
  final String? accountEmail;
  @override
  final ScheduleItemCapabilities capabilities;

  @override
  ScheduleItemKind get kind => ScheduleItemKind.task;
}

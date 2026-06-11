import 'dart:convert';

import 'package:drift/drift.dart';

import '../calendar_providers/calendar_colors.dart';
import '../calendar_providers/calendar_description.dart';
import '../db/app_database.dart';
import '../task_providers/task_provider.dart';
import 'schedule_filters.dart';
import 'schedule_item.dart';
import 'schedule_range.dart';
import 'schedule_sorting.dart';

class ScheduleRepository {
  const ScheduleRepository(this._database);

  final AppDatabase _database;

  Future<List<ScheduleItem>> listItems({
    required ScheduleRange range,
    ScheduleFilters filters = const ScheduleFilters(),
  }) async {
    final accountIds = await _accountIds(filters);
    if (accountIds.isEmpty) {
      return const [];
    }

    final accounts = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.isIn(accountIds))).get();
    final providers = {
      for (final account in accounts)
        account.id: TaskProviderParsing.fromStorageValue(account.provider),
    };
    final accountDisplayNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    final accountEmails = {
      for (final account in accounts) account.id: account.email,
    };
    final searching = filters.query.trim().isNotEmpty;

    final items = <ScheduleItem>[
      if (filters.includeCalendarEvents)
        ...await _calendarItems(
          range,
          filters,
          searching,
          accountIds,
          providers,
          accountDisplayNames,
          accountEmails,
        ),
      if (filters.includeTasks)
        ...await _taskItems(
          range,
          filters,
          searching,
          accountIds,
          providers,
          accountDisplayNames,
          accountEmails,
        ),
    ];
    final filtered = filters.query.trim().isEmpty
        ? items
        : items
              .where((item) => matchesScheduleQuery(item, filters.query))
              .toList();
    filtered.sort(compareScheduleItems);
    return filtered;
  }

  Future<List<String>> _accountIds(ScheduleFilters filters) async {
    if (filters.accountIds.isNotEmpty) {
      return filters.accountIds.toList();
    }
    final accounts = await (_database.select(
      _database.accounts,
    )..where((row) => row.authState.equals('signed_in'))).get();
    return accounts.map((account) => account.id).toList();
  }

  Future<List<ScheduleItem>> _calendarItems(
    ScheduleRange range,
    ScheduleFilters filters,
    bool searching,
    List<String> accountIds,
    Map<String, BusyProvider> providers,
    Map<String, String?> accountDisplayNames,
    Map<String, String?> accountEmails,
  ) async {
    if (filters.sourceFilterActive && filters.sourceIds.isEmpty) {
      return const [];
    }
    final query =
        _database.select(_database.calendarEvents).join([
            leftOuterJoin(
              _database.calendarSources,
              _database.calendarSources.id.equalsExp(
                _database.calendarEvents.calendarSourceId,
              ),
            ),
          ])
          ..where(_database.calendarEvents.accountId.isIn(accountIds))
          ..where(_database.calendarEvents.isDeleted.equals(false));
    if (filters.sourceFilterActive) {
      query.where(
        _database.calendarEvents.calendarSourceId.isIn(filters.sourceIds),
      );
    }
    final rows = await query.get();
    final items = <ScheduleItem>[];
    for (final row in rows) {
      final event = row.readTable(_database.calendarEvents);
      final source = row.readTableOrNull(_database.calendarSources);
      final start = _eventStart(event);
      final end = _eventEnd(event);
      final descriptionBody = _eventDescriptionBody(event);
      final provider =
          providers[event.accountId] ??
          TaskProviderParsing.fromStorageValue(event.provider);
      if (!searching && !_intersects(range, start, end)) {
        continue;
      }
      items.add(
        CalendarScheduleItem(
          id: event.id,
          accountId: event.accountId,
          provider: provider,
          sourceId: event.calendarSourceId,
          providerCalendarId: event.providerCalendarId,
          title: event.title,
          allDay: event.allDay,
          start: start,
          end: end,
          location: event.location,
          description: event.description,
          descriptionContentType: descriptionBody.contentType,
          descriptionHtml: descriptionBody.html,
          categories: _stringListFromJson(event.categoriesJson),
          colorHex:
              event.colorHex ??
              calendarSourceBackgroundColorHex(
                provider: provider,
                backgroundColor: source?.backgroundColor,
                colorId: source?.colorId,
              ),
          sourceName: source?.summary,
          accountDisplayName: accountDisplayNames[event.accountId],
          accountEmail: accountEmails[event.accountId],
        ),
      );
    }
    return items;
  }

  Future<List<ScheduleItem>> _taskItems(
    ScheduleRange range,
    ScheduleFilters filters,
    bool searching,
    List<String> accountIds,
    Map<String, BusyProvider> providers,
    Map<String, String?> accountDisplayNames,
    Map<String, String?> accountEmails,
  ) async {
    if (filters.taskListFilterActive && filters.taskListIds.isEmpty) {
      return const [];
    }
    final query =
        _database.select(_database.tasks).join([
            leftOuterJoin(
              _database.taskLists,
              _database.taskLists.accountId.equalsExp(
                    _database.tasks.accountId,
                  ) &
                  _database.taskLists.id.equalsExp(_database.tasks.taskListId),
            ),
          ])
          ..where(_database.tasks.accountId.isIn(accountIds))
          ..where(_database.tasks.pendingDelete.equals(false));
    if (filters.taskListFilterActive) {
      query.where(_database.tasks.taskListId.isIn(filters.taskListIds));
    }
    final rows = await query.get();
    final items = <ScheduleItem>[];
    for (final row in rows) {
      final task = row.readTable(_database.tasks);
      if (!filters.showCompletedTasks && task.status == 'completed') {
        continue;
      }
      final provider = providers[task.accountId] ?? TaskProvider.google;
      final start = _taskStart(task, provider);
      final end = _taskEnd(task, provider);
      if (start == null && !filters.showNoDateTasks) {
        continue;
      }
      if (start != null && !searching && !_intersects(range, start, end)) {
        continue;
      }
      final list = row.readTableOrNull(_database.taskLists);
      items.add(
        TaskScheduleItem(
          id: task.id,
          accountId: task.accountId,
          provider: provider,
          sourceId: task.taskListId,
          title: task.title,
          completed: task.status == 'completed',
          allDay: _taskAllDay(task, provider),
          start: start,
          end: end,
          notes: task.notes ?? task.bodyContent,
          categories: _stringListFromJson(task.categoriesJson),
          sourceName: list?.title,
          accountDisplayName: accountDisplayNames[task.accountId],
          accountEmail: accountEmails[task.accountId],
        ),
      );
    }
    return items;
  }
}

({String? contentType, String? html}) _eventDescriptionBody(
  CalendarEvent event,
) {
  if (event.provider != TaskProvider.microsoft.storageValue) {
    return (contentType: null, html: null);
  }
  final rawJson = event.rawJson;
  if (rawJson == null || rawJson.isEmpty) {
    return (contentType: null, html: null);
  }
  final raw = jsonDecode(rawJson) as Map<String, Object?>;
  final body = raw['body'];
  if (body is! Map) {
    return (contentType: null, html: null);
  }
  final map = body.cast<String, Object?>();
  final contentType = map['contentType']?.toString();
  if (!isHtmlContentType(contentType)) {
    return (contentType: contentType, html: null);
  }
  final html = map['content']?.toString();
  return (contentType: contentType, html: html);
}

bool matchesScheduleQuery(ScheduleItem item, String query) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) {
    return true;
  }
  final fields = <String>[
    item.title,
    item.sourceName ?? '',
    item.provider.displayName,
    item.accountDisplayName ?? '',
    item.accountEmail ?? '',
    if (item is CalendarScheduleItem) ...[
      item.location ?? '',
      item.description ?? '',
      ...item.categories,
    ],
    if (item is TaskScheduleItem) ...[item.notes ?? '', ...item.categories],
  ].map((value) => value.toLowerCase()).toList();
  return terms.every((term) => fields.any((field) => field.contains(term)));
}

DateTime? _taskStart(Task task, BusyProvider provider) {
  if (provider == TaskProvider.microsoft) {
    return _parseDateTime(task.microsoftStartDateTime) ??
        _parseDateTime(task.microsoftDueDateTime) ??
        _parseDate(task.dueUtc);
  }
  return _parseDate(task.dueUtc);
}

DateTime? _taskEnd(Task task, BusyProvider provider) {
  final start = _taskStart(task, provider);
  if (start == null) {
    return null;
  }
  if (_taskAllDay(task, provider)) {
    return start.add(const Duration(days: 1));
  }
  return start.add(const Duration(minutes: 30));
}

bool _taskAllDay(Task task, BusyProvider provider) {
  if (provider == TaskProvider.google) {
    return true;
  }
  final scheduleDateTimes = [
    task.microsoftStartDateTime,
    task.microsoftDueDateTime,
  ].whereType<String>().where((value) => value.isNotEmpty);
  return scheduleDateTimes.isEmpty ||
      scheduleDateTimes.every(_isDateOnlyOrMidnight);
}

bool _isDateOnlyOrMidnight(String value) {
  return !value.contains('T') || _isMidnightDateTime(value);
}

bool _isMidnightDateTime(String value) {
  final separatorIndex = value.indexOf('T');
  if (separatorIndex < 0 || separatorIndex + 1 >= value.length) {
    return false;
  }
  final time = value.substring(separatorIndex + 1);
  return time.length >= 5 && time.substring(0, 5) == '00:00';
}

bool _intersects(ScheduleRange range, DateTime? start, DateTime? end) {
  if (start == null) {
    return true;
  }
  final effectiveEnd = end ?? start.add(const Duration(minutes: 1));
  return effectiveEnd.isAfter(range.start) && start.isBefore(range.end);
}

DateTime? _eventStart(CalendarEvent event) {
  if (!event.allDay) {
    return _parseDateTime(event.startDateTime);
  }
  return _parseDate(event.startDate) ?? _parseDate(event.startDateTime);
}

DateTime? _eventEnd(CalendarEvent event) {
  if (!event.allDay) {
    return _parseDateTime(event.endDateTime);
  }
  return _parseDate(event.endDate) ?? _parseDate(event.endDateTime);
}

DateTime? _parseDate(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return DateTime.tryParse(value.substring(0, 10));
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<String> _stringListFromJson(String? value) {
  if (value == null || value.isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return [
        for (final item in decoded)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ];
    }
  } on FormatException {
    return const [];
  }
  return const [];
}

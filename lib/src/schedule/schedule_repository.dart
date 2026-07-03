import 'dart:convert';

import 'package:drift/drift.dart';

import '../calendar_providers/calendar_colors.dart';
import '../calendar_providers/calendar_description.dart';
import '../db/app_database.dart';
import '../core/time/provider_date_time.dart';
import '../task_providers/task_provider.dart';
import 'schedule_filters.dart';
import 'schedule_item.dart';
import 'schedule_projection.dart';
import 'schedule_range.dart';
import 'schedule_sorting.dart';

class ScheduleRepository {
  const ScheduleRepository(this._database);

  final AppDatabase _database;

  Future<List<ScheduleItem>> listItems({
    required ScheduleRange range,
    ScheduleFilters filters = const ScheduleFilters(),
  }) async {
    final context = await _accountContext(filters);
    if (context == null) {
      return const [];
    }
    final searching = filters.query.trim().isNotEmpty;

    final items = <ScheduleItem>[
      if (filters.includeCalendarEvents)
        ...await _calendarItems(
          range,
          filters,
          searching,
          context.accountIds,
          context.providers,
          context.accountDisplayNames,
          context.accountEmails,
        ),
      if (filters.includeTasks)
        ...await _taskItems(
          range,
          filters,
          searching,
          context.accountIds,
          context.providers,
          context.accountDisplayNames,
          context.accountEmails,
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

  Future<ScheduleTaskBucketPage> listOverdueTasks({
    required DateTime before,
    required int limit,
    ScheduleFilters filters = const ScheduleFilters(),
  }) async {
    return _limitedTaskBucket(
      limit: limit,
      filters: filters,
      databaseFilter: _taskScheduledBefore(ScheduleProjection.day(before)),
      itemFilter: (item) {
        final start = item.start;
        return start != null &&
            ScheduleProjection.day(
              start,
            ).isBefore(ScheduleProjection.day(before));
      },
    );
  }

  Future<ScheduleTaskBucketPage> listNoDateTasks({
    required int limit,
    ScheduleFilters filters = const ScheduleFilters(),
  }) async {
    return _limitedTaskBucket(
      limit: limit,
      filters: filters,
      databaseFilter: _taskNoDate(),
      itemFilter: (item) => item.start == null,
    );
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

  Future<_ScheduleAccountContext?> _accountContext(
    ScheduleFilters filters,
  ) async {
    final accountIds = await _accountIds(filters);
    if (accountIds.isEmpty) {
      return null;
    }
    final accounts = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.isIn(accountIds))).get();
    return _ScheduleAccountContext(
      accountIds: accountIds,
      providers: {
        for (final account in accounts)
          account.id: TaskProviderParsing.fromStorageValue(account.provider),
      },
      accountDisplayNames: {
        for (final account in accounts) account.id: account.displayName,
      },
      accountEmails: {
        for (final account in accounts) account.id: account.email,
      },
    );
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
          startTimeZone: event.startTimeZone,
          endTimeZone: event.endTimeZone,
          location: event.location,
          description: event.description,
          descriptionContentType: descriptionBody.contentType,
          descriptionHtml: descriptionBody.html,
          categories: _stringListFromJson(event.categoriesJson),
          reminderMinutesBeforeStart: _eventReminderMinutes(
            provider,
            event.remindersJson,
            source: source,
          ),
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
          ..where(_database.tasks.pendingDelete.equals(false))
          ..where(_database.tasks.serverMissing.equals(false))
          ..where(
            _database.tasks.deleted.isNull() |
                _database.tasks.deleted.equals(false),
          )
          ..where(
            _database.tasks.hidden.isNull() |
                _database.tasks.hidden.equals(false),
          )
          ..where(
            _database.taskLists.id.isNull() |
                _database.taskLists.serverMissing.equals(false),
          );
    if (filters.taskListFilterActive) {
      query.where(_database.tasks.taskListId.isIn(filters.taskListIds));
    }
    if (!filters.showCompletedTasks) {
      query.where(_taskIncomplete());
    }
    if (!searching) {
      final inRange = _taskScheduledInRange(range);
      query.where(filters.showNoDateTasks ? inRange | _taskNoDate() : inRange);
    }
    final rows = await query.get();
    final items = <ScheduleItem>[];
    for (final row in rows) {
      final item = _taskItemFromRow(
        row,
        providers,
        accountDisplayNames,
        accountEmails,
      );
      if (!filters.showCompletedTasks && item.completed) {
        continue;
      }
      final start = item.start;
      final end = item.end;
      if (start == null && !filters.showNoDateTasks) {
        continue;
      }
      if (start != null && !searching && !_intersects(range, start, end)) {
        continue;
      }
      items.add(item);
    }
    return items;
  }

  Future<ScheduleTaskBucketPage> _limitedTaskBucket({
    required int limit,
    required ScheduleFilters filters,
    required Expression<bool> databaseFilter,
    required bool Function(TaskScheduleItem item) itemFilter,
  }) async {
    if (!filters.includeTasks ||
        (filters.taskListFilterActive && filters.taskListIds.isEmpty)) {
      return const ScheduleTaskBucketPage(items: [], hasMore: false);
    }

    final context = await _accountContext(filters);
    if (context == null) {
      return const ScheduleTaskBucketPage(items: [], hasMore: false);
    }

    final effectiveLimit = limit < 1 ? 1 : limit;
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
          ..where(_database.tasks.accountId.isIn(context.accountIds))
          ..where(_database.tasks.pendingDelete.equals(false))
          ..where(_database.tasks.serverMissing.equals(false))
          ..where(
            _database.tasks.deleted.isNull() |
                _database.tasks.deleted.equals(false),
          )
          ..where(
            _database.tasks.hidden.isNull() |
                _database.tasks.hidden.equals(false),
          )
          ..where(
            _database.taskLists.id.isNull() |
                _database.taskLists.serverMissing.equals(false),
          )
          ..where(databaseFilter)
          ..limit(effectiveLimit + 1);
    if (filters.taskListFilterActive) {
      query.where(_database.tasks.taskListId.isIn(filters.taskListIds));
    }
    if (!filters.showCompletedTasks) {
      query.where(_taskIncomplete());
    }
    query.orderBy([
      OrderingTerm.asc(_database.tasks.dueUtc),
      OrderingTerm.asc(_database.tasks.microsoftStartDateTime),
      OrderingTerm.asc(_database.tasks.microsoftDueDateTime),
      OrderingTerm.asc(_database.taskLists.title),
      OrderingTerm.asc(_database.tasks.parent),
      OrderingTerm.asc(_database.tasks.position),
      OrderingTerm.asc(_database.tasks.title),
    ]);

    final rows = await query.get();
    final items = <TaskScheduleItem>[];
    for (final row in rows) {
      final item = _taskItemFromRow(
        row,
        context.providers,
        context.accountDisplayNames,
        context.accountEmails,
      );
      if (!filters.showCompletedTasks && item.completed) {
        continue;
      }
      if (!itemFilter(item)) {
        continue;
      }
      items.add(item);
      if (items.length > effectiveLimit) {
        break;
      }
    }

    final visibleItems = items.take(effectiveLimit).toList()
      ..sort(compareScheduleItems);
    return ScheduleTaskBucketPage(
      items: visibleItems,
      hasMore: items.length > effectiveLimit,
    );
  }

  TaskScheduleItem _taskItemFromRow(
    TypedResult row,
    Map<String, BusyProvider> providers,
    Map<String, String?> accountDisplayNames,
    Map<String, String?> accountEmails,
  ) {
    final task = row.readTable(_database.tasks);
    final provider = providers[task.accountId] ?? TaskProvider.google;
    final list = row.readTableOrNull(_database.taskLists);
    final start = _taskStart(task, provider);
    return TaskScheduleItem(
      id: task.id,
      accountId: task.accountId,
      provider: provider,
      sourceId: task.taskListId,
      title: task.title,
      completed: task.status == 'completed',
      allDay: _taskAllDay(task, provider),
      start: start,
      end: _taskEnd(task, provider),
      notes: task.notes ?? task.bodyContent,
      categories: _stringListFromJson(task.categoriesJson),
      reminder: task.microsoftIsReminderOn == true
          ? providerDateTimeAsLocal(
              task.microsoftReminderDateTime,
              task.microsoftReminderTimeZone,
            )
          : null,
      sourceName: list?.title,
      accountDisplayName: accountDisplayNames[task.accountId],
      accountEmail: accountEmails[task.accountId],
    );
  }

  Expression<bool> _taskIncomplete() {
    return _database.tasks.status.isNull() |
        _database.tasks.status.equals('completed').not();
  }

  Expression<bool> _taskNoDate() {
    return _database.tasks.dueUtc.isNull() &
        _database.tasks.microsoftStartDateTime.isNull() &
        _database.tasks.microsoftDueDateTime.isNull();
  }

  Expression<bool> _taskScheduledBefore(DateTime before) {
    final beforeKey = _dateKey(before);
    return _textBefore(_database.tasks.dueUtc, beforeKey) |
        _textBefore(_database.tasks.microsoftStartDateTime, beforeKey) |
        _textBefore(_database.tasks.microsoftDueDateTime, beforeKey);
  }

  Expression<bool> _taskScheduledInRange(ScheduleRange range) {
    final startKey = _dateKey(range.start);
    final endKey = _dateKey(range.end);
    return _textInRange(_database.tasks.dueUtc, startKey, endKey) |
        _textInRange(_database.tasks.microsoftStartDateTime, startKey, endKey) |
        _textInRange(_database.tasks.microsoftDueDateTime, startKey, endKey);
  }
}

class ScheduleTaskBucketPage {
  const ScheduleTaskBucketPage({required this.items, required this.hasMore});

  final List<TaskScheduleItem> items;
  final bool hasMore;
}

class _ScheduleAccountContext {
  const _ScheduleAccountContext({
    required this.accountIds,
    required this.providers,
    required this.accountDisplayNames,
    required this.accountEmails,
  });

  final List<String> accountIds;
  final Map<String, BusyProvider> providers;
  final Map<String, String?> accountDisplayNames;
  final Map<String, String?> accountEmails;
}

Expression<bool> _textBefore(GeneratedColumn<String> value, String upperBound) {
  return value.isNotNull() & value.isSmallerThanValue(upperBound);
}

Expression<bool> _textInRange(
  GeneratedColumn<String> value,
  String lowerBound,
  String upperBound,
) {
  return value.isNotNull() &
      value.isBiggerOrEqualValue(lowerBound) &
      value.isSmallerThanValue(upperBound);
}

String _dateKey(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return [
    day.year.toString().padLeft(4, '0'),
    day.month.toString().padLeft(2, '0'),
    day.day.toString().padLeft(2, '0'),
  ].join('-');
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
  return scheduleDateTimes.isEmpty || scheduleDateTimes.every(_isDateOnly);
}

bool _isDateOnly(String value) => !value.contains('T');

bool _intersects(ScheduleRange range, DateTime? start, DateTime? end) {
  if (start == null) {
    return true;
  }
  final effectiveEnd = end ?? start.add(const Duration(minutes: 1));
  return effectiveEnd.isAfter(range.start) && start.isBefore(range.end);
}

DateTime? _eventStart(CalendarEvent event) {
  if (!event.allDay) {
    return _parseCalendarDateTime(event.startDateTime);
  }
  return _parseDate(event.startDate) ?? _parseDate(event.startDateTime);
}

DateTime? _eventEnd(CalendarEvent event) {
  if (!event.allDay) {
    return _parseCalendarDateTime(event.endDateTime);
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

DateTime? _parseCalendarDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final offsetWallTime = _parseOffsetWallDateTime(value);
  if (offsetWallTime != null) {
    return offsetWallTime;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return null;
  }
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

DateTime? _parseOffsetWallDateTime(String value) {
  if (!RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value)) {
    return null;
  }
  final wallTime = value.replaceFirst(RegExp(r'[+-]\d{2}:?\d{2}$'), '');
  return DateTime.tryParse(wallTime);
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

List<int> _eventReminderMinutes(
  BusyProvider provider,
  String? value, {
  CalendarSource? source,
}) {
  if (value == null || value.isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return const [];
    }
    final map = decoded.cast<String, Object?>();
    final minutes = switch (provider) {
      TaskProvider.microsoft =>
        map['isReminderOn'] == true
            ? [map['reminderMinutesBeforeStart']]
            : const <Object?>[],
      TaskProvider.google =>
        map['useDefault'] == true
            ? _googleDefaultReminderMinutes(source)
            : switch (map['overrides']) {
                final List<Object?> overrides => [
                  for (final item in overrides)
                    if (item is Map && item['method'] == 'popup')
                      item['minutes'],
                ],
                _ => const <Object?>[],
              },
    };
    return [
      for (final value in minutes)
        if (value is int && value >= 0) value,
    ]..sort();
  } on FormatException {
    return const [];
  }
}

List<Object?> _googleDefaultReminderMinutes(CalendarSource? source) {
  final raw = source?.rawJson;
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const [];
    }
    final reminders = decoded['defaultReminders'];
    if (reminders is! List) {
      return const [];
    }
    return [
      for (final item in reminders)
        if (item is Map && item['method'] == 'popup') item['minutes'],
    ];
  } on FormatException {
    return const [];
  }
}

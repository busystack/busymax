import 'dart:convert';

import 'package:drift/drift.dart';

import '../calendar_providers/calendar_colors.dart';
import '../calendar_providers/calendar_description.dart';
import '../core/time/provider_date_time.dart';
import '../dav/storage/dav_collection_capabilities.dart';
import '../db/app_database.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'schedule_filters.dart';
import 'schedule_item.dart';
import 'schedule_projection.dart';
import 'schedule_range.dart';
import 'schedule_sorting.dart';

class ScheduleRepository {
  const ScheduleRepository(this._database);

  final AppDatabase _database;

  Future<ScheduleTaskTarget?> findTaskTarget({
    required String accountId,
    required String taskListId,
    required String taskId,
  }) async {
    return watchTaskTarget(
      accountId: accountId,
      taskListId: taskListId,
      taskId: taskId,
    ).first;
  }

  /// Watches one live, visible task identified by its full database key.
  ///
  /// A stream is used for deep links so a route can remain pending while an
  /// initial sync inserts the requested task, without polling or retry loops.
  Stream<ScheduleTaskTarget?> watchTaskTarget({
    required String accountId,
    required String taskListId,
    required String taskId,
  }) {
    final query =
        _database.select(_database.tasks).join([
            innerJoin(
              _database.taskLists,
              _database.taskLists.accountId.equalsExp(
                    _database.tasks.accountId,
                  ) &
                  _database.taskLists.id.equalsExp(_database.tasks.taskListId),
            ),
            innerJoin(
              _database.accounts,
              _database.accounts.id.equalsExp(_database.tasks.accountId),
            ),
            leftOuterJoin(
              _database.davCollections,
              _database.davCollections.id.equalsExp(
                _database.taskLists.davCollectionId,
              ),
            ),
          ])
          ..where(_database.tasks.accountId.equals(accountId))
          ..where(_database.tasks.taskListId.equals(taskListId))
          ..where(_database.tasks.id.equals(taskId))
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
          ..where(_database.taskLists.pendingDelete.equals(false))
          ..where(_database.taskLists.serverMissing.equals(false))
          ..where(
            _database.taskLists.davCollectionId.isNull() |
                _database.davCollections.tasksSelected.equals(true),
          )
          ..where(
            _database.accounts.authState.isIn(accountCachedAvailableStates),
          );
    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }
      final task = row.readTable(_database.tasks);
      return ScheduleTaskTarget(
        accountId: task.accountId,
        taskListId: task.taskListId,
        taskId: task.id,
      );
    });
  }

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

  /// Adds every available ancestor of the tasks already present in [items].
  ///
  /// Agenda task buckets are paginated independently. Without this closure, a
  /// no-date child can be loaded while its overdue parent sits beyond the
  /// current overdue page, leaving one logical task tree split across sections.
  Future<List<ScheduleItem>> includeTaskAncestors(
    List<ScheduleItem> items, {
    ScheduleFilters filters = const ScheduleFilters(),
  }) async {
    final visibleTasks = items.whereType<TaskScheduleItem>().toList();
    if (!filters.includeTasks ||
        visibleTasks.isEmpty ||
        (filters.taskListFilterActive && filters.taskListKeys.isEmpty)) {
      return List<ScheduleItem>.of(items);
    }

    final context = await _accountContext(filters);
    if (context == null) return List<ScheduleItem>.of(items);

    final query =
        _database.select(_database.tasks).join([
            leftOuterJoin(
              _database.taskLists,
              _database.taskLists.accountId.equalsExp(
                    _database.tasks.accountId,
                  ) &
                  _database.taskLists.id.equalsExp(_database.tasks.taskListId),
            ),
            leftOuterJoin(
              _database.davCollections,
              _database.davCollections.id.equalsExp(
                _database.taskLists.davCollectionId,
              ),
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
          ..where(
            _database.taskLists.davCollectionId.isNull() |
                _database.davCollections.tasksSelected.equals(true),
          );
    if (filters.taskListFilterActive) {
      query.where(_taskListFilter(filters.taskListKeys));
    }

    final rows = await query.get();
    if (rows.isEmpty) return List<ScheduleItem>.of(items);

    final tasks = <Task>[];
    final rowsById = <String, TypedResult>{};
    for (final row in rows) {
      final task = row.readTable(_database.tasks);
      tasks.add(task);
      rowsById[_taskKey(task.accountId, task.taskListId, task.id)] = row;
    }
    final hierarchy = _TaskHierarchyContext(tasks);
    final tasksById = <String, Task>{
      for (final task in tasks)
        _taskKey(task.accountId, task.taskListId, task.id): task,
    };
    final includedKeys = {
      for (final task in visibleTasks)
        _taskKey(task.accountId, task.sourceId, task.id),
    };
    final ancestorKeys = <String>{};

    for (final visibleTask in visibleTasks) {
      Task? current =
          tasksById[_taskKey(
            visibleTask.accountId,
            visibleTask.sourceId,
            visibleTask.id,
          )];
      final visiting = <String>{};
      while (current != null) {
        final currentKey = _taskKey(
          current.accountId,
          current.taskListId,
          current.id,
        );
        if (!visiting.add(currentKey)) break;
        final parent = hierarchy.parentOf(current);
        if (parent == null || parent.id == current.id) break;
        final parentKey = _taskKey(
          parent.accountId,
          parent.taskListId,
          parent.id,
        );
        if (includedKeys.add(parentKey)) ancestorKeys.add(parentKey);
        current = parent;
      }
    }

    if (ancestorKeys.isEmpty) return List<ScheduleItem>.of(items);
    return [
      ...items,
      for (final key in ancestorKeys)
        if (rowsById[key] case final row?)
          _taskItemFromRow(
            row,
            context.providers,
            context.accountDisplayNames,
            context.accountEmails,
            hierarchy,
          ),
    ];
  }

  Future<List<String>> _accountIds(ScheduleFilters filters) async {
    final query = _database.select(_database.accounts)
      ..where((row) => row.authState.isIn(accountCachedAvailableStates));
    if (filters.accountIds.isNotEmpty) {
      query.where((row) => row.id.isIn(filters.accountIds));
    }
    final accounts = await query.get();
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
          account.id: BusyProviderCodec.requireStorageValue(account.provider),
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
          ..where(_database.calendarEvents.isDeleted.equals(false))
          ..where(_database.calendarEvents.isCancelled.equals(false));
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
          BusyProviderCodec.requireStorageValue(event.provider);
      final attendees = _jsonMapListFromString(event.attendeesJson);
      final organizer = _jsonMapFromString(event.organizerJson);
      final conference = _jsonValueFromString(event.conferenceJson);
      final raw = _jsonMapFromString(event.rawJson) ?? const {};
      final isOrganizer = _eventIsOrganizer(provider, organizer, raw);
      final sourceWritable =
          source != null && !source.readOnly && !source.isDeleted;
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
          providerRecurringEventId: event.providerRecurringEventId,
          title: event.title,
          allDay: event.allDay,
          start: start,
          end: end,
          location: event.location,
          description: event.description,
          descriptionContentType: descriptionBody.contentType,
          descriptionHtml: descriptionBody.html,
          attendees: attendees,
          organizer: organizer,
          joinMeetingUrl: _eventJoinMeetingUrl(provider, conference, raw),
          isOrganizer: isOrganizer,
          guestsCanModify: provider == BusyProvider.google
              ? raw['guestsCanModify'] == true
              : null,
          locked: provider == BusyProvider.google && raw['locked'] == true,
          currentUserResponse: _eventCurrentUserResponse(
            provider,
            attendees,
            raw,
          ),
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
          capabilities: ScheduleItemCapabilities(
            canEdit:
                sourceWritable &&
                _eventAllowsFullEditing(provider, isOrganizer, raw),
            canDelete: sourceWritable,
          ),
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
    if (filters.taskListFilterActive && filters.taskListKeys.isEmpty) {
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
            leftOuterJoin(
              _database.davCollections,
              _database.davCollections.id.equalsExp(
                _database.taskLists.davCollectionId,
              ),
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
          )
          ..where(
            _database.taskLists.davCollectionId.isNull() |
                _database.davCollections.tasksSelected.equals(true),
          );
    if (filters.taskListFilterActive) {
      query.where(_taskListFilter(filters.taskListKeys));
    }
    if (!filters.showCompletedTasks) {
      query.where(_taskIncomplete());
    }
    if (!searching) {
      final inRange =
          _taskScheduledInRange(range) |
          _database.tasks.davCollectionId.isNotNull();
      query.where(filters.showNoDateTasks ? inRange | _taskNoDate() : inRange);
    }
    final rows = await query.get();
    final hierarchy = await _taskHierarchy(rows);
    final items = <ScheduleItem>[];
    for (final row in rows) {
      final item = _taskItemFromRow(
        row,
        providers,
        accountDisplayNames,
        accountEmails,
        hierarchy,
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
        (filters.taskListFilterActive && filters.taskListKeys.isEmpty)) {
      return const ScheduleTaskBucketPage(items: [], hasMore: false);
    }

    final context = await _accountContext(filters);
    if (context == null) {
      return const ScheduleTaskBucketPage(items: [], hasMore: false);
    }

    final effectiveLimit = limit < 1 ? 1 : limit;
    final includesDav = context.providers.values.any(
      (provider) =>
          provider == BusyProvider.appleICloud ||
          provider == BusyProvider.nextcloud,
    );
    final query =
        _database.select(_database.tasks).join([
            leftOuterJoin(
              _database.taskLists,
              _database.taskLists.accountId.equalsExp(
                    _database.tasks.accountId,
                  ) &
                  _database.taskLists.id.equalsExp(_database.tasks.taskListId),
            ),
            leftOuterJoin(
              _database.davCollections,
              _database.davCollections.id.equalsExp(
                _database.taskLists.davCollectionId,
              ),
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
          ..where(
            _database.taskLists.davCollectionId.isNull() |
                _database.davCollections.tasksSelected.equals(true),
          )
          ..where(
            includesDav
                ? databaseFilter | _database.tasks.davCollectionId.isNotNull()
                : databaseFilter,
          );
    if (filters.taskListFilterActive) {
      query.where(_taskListFilter(filters.taskListKeys));
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
    final hierarchy = await _taskHierarchy(rows);
    final items = <TaskScheduleItem>[];
    for (final row in rows) {
      final item = _taskItemFromRow(
        row,
        context.providers,
        context.accountDisplayNames,
        context.accountEmails,
        hierarchy,
      );
      if (!filters.showCompletedTasks && item.completed) {
        continue;
      }
      if (!itemFilter(item)) {
        continue;
      }
      items.add(item);
    }

    items.sort(compareScheduleItems);
    final orderedItems = ScheduleProjection.arrangeHierarchy(items);
    final visibleItems = orderedItems.take(effectiveLimit).toList();
    return ScheduleTaskBucketPage(
      items: visibleItems,
      hasMore: orderedItems.length > effectiveLimit,
    );
  }

  TaskScheduleItem _taskItemFromRow(
    TypedResult row,
    Map<String, BusyProvider> providers,
    Map<String, String?> accountDisplayNames,
    Map<String, String?> accountEmails,
    _TaskHierarchyContext hierarchy,
  ) {
    final task = row.readTable(_database.tasks);
    final provider = providers[task.accountId];
    if (provider == null) {
      throw StateError('Schedule task account provider is unavailable.');
    }
    final list = row.readTableOrNull(_database.taskLists);
    final davCollection = row.readTableOrNull(_database.davCollections);
    final start = _taskStart(task, provider);
    final parent = hierarchy.parentOf(task);
    final unresolvedParentId = task.parent ?? task.parentUid;
    final checklistItems = decodeTaskChecklistItems(
      task.microsoftChecklistItemsJson,
    );
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
      parentId: parent?.id ?? unresolvedParentId,
      parentTitle: parent?.title,
      hierarchyDepth: hierarchy.depthOf(task),
      hasSubtasks: hierarchy.hasChildren(task) || checklistItems.isNotEmpty,
      checklistItems: checklistItems,
      sourceName: list?.title,
      accountDisplayName: accountDisplayNames[task.accountId],
      accountEmail: accountEmails[task.accountId],
      capabilities: _taskScheduleCapabilities(davCollection),
    );
  }

  Future<_TaskHierarchyContext> _taskHierarchy(
    List<TypedResult> visibleRows,
  ) async {
    if (visibleRows.isEmpty) return _TaskHierarchyContext.empty;
    final visibleTasks = [
      for (final row in visibleRows) row.readTable(_database.tasks),
    ];
    final accountIds = {for (final task in visibleTasks) task.accountId};
    final listKeys = {
      for (final task in visibleTasks)
        _taskListKey(task.accountId, task.taskListId),
    };
    final allRows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.isIn(accountIds) &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false) &
                  (row.deleted.isNull() | row.deleted.equals(false)) &
                  (row.hidden.isNull() | row.hidden.equals(false)),
            ))
            .get();
    return _TaskHierarchyContext(
      allRows
          .where(
            (task) => listKeys.contains(
              _taskListKey(task.accountId, task.taskListId),
            ),
          )
          .toList(),
    );
  }

  Expression<bool> _taskIncomplete() {
    return _database.tasks.status.isNull() |
        _database.tasks.status.equals('completed').not();
  }

  Expression<bool> _taskListFilter(Set<ScheduleTaskListKey> taskListKeys) {
    Expression<bool> matches = const Constant(false);
    for (final key in taskListKeys) {
      matches =
          matches |
          (_database.tasks.accountId.equals(key.accountId) &
              _database.tasks.taskListId.equals(key.taskListId));
    }
    return matches;
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

class ScheduleTaskTarget {
  const ScheduleTaskTarget({
    required this.accountId,
    required this.taskListId,
    required this.taskId,
  });

  final String accountId;
  final String taskListId;
  final String taskId;

  @override
  bool operator ==(Object other) {
    return other is ScheduleTaskTarget &&
        other.accountId == accountId &&
        other.taskListId == taskListId &&
        other.taskId == taskId;
  }

  @override
  int get hashCode => Object.hash(accountId, taskListId, taskId);
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

class _TaskHierarchyContext {
  _TaskHierarchyContext(List<Task> tasks)
    : _byId = {
        for (final task in tasks)
          _taskKey(task.accountId, task.taskListId, task.id): task,
      },
      _byUid = {
        for (final task in tasks)
          if (task.icalUid != null && task.icalUid!.isNotEmpty)
            _taskKey(task.accountId, task.taskListId, task.icalUid!): task,
      } {
    for (final task in tasks) {
      final parent = parentOf(task);
      if (parent != null && parent.id != task.id) {
        _parentsWithChildren.add(
          _taskKey(parent.accountId, parent.taskListId, parent.id),
        );
      }
    }
  }

  static final empty = _TaskHierarchyContext(const []);

  final Map<String, Task> _byId;
  final Map<String, Task> _byUid;
  final Map<String, Task?> _parents = {};
  final Map<String, int> _depths = {};
  final Set<String> _parentsWithChildren = {};

  Task? parentOf(Task task) {
    final key = _taskKey(task.accountId, task.taskListId, task.id);
    if (_parents.containsKey(key)) return _parents[key];
    Task? parent;
    final parentId = task.parent;
    if (parentId != null && parentId.isNotEmpty) {
      final lookup = _taskKey(task.accountId, task.taskListId, parentId);
      parent = _byId[lookup] ?? _byUid[lookup];
    }
    final parentUid = task.parentUid;
    if (parent == null && parentUid != null && parentUid.isNotEmpty) {
      final lookup = _taskKey(task.accountId, task.taskListId, parentUid);
      parent = _byUid[lookup] ?? _byId[lookup];
    }
    _parents[key] = parent;
    return parent;
  }

  int depthOf(Task task) => _resolveDepth(task, <String>{});

  int _resolveDepth(Task task, Set<String> visiting) {
    final key = _taskKey(task.accountId, task.taskListId, task.id);
    final cached = _depths[key];
    if (cached != null) return cached;
    if (!visiting.add(key)) return 0;
    final parent = parentOf(task);
    final depth = parent == null
        ? (task.parent != null || task.parentUid != null ? 1 : 0)
        : parent.id == task.id
        ? 0
        : 1 + _resolveDepth(parent, visiting);
    visiting.remove(key);
    _depths[key] = depth;
    return depth;
  }

  bool hasChildren(Task task) => _parentsWithChildren.contains(
    _taskKey(task.accountId, task.taskListId, task.id),
  );
}

String _taskListKey(String accountId, String taskListId) =>
    '$accountId\u0000$taskListId';

String _taskKey(String accountId, String taskListId, String taskId) =>
    '$accountId\u0000$taskListId\u0000$taskId';

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
  if (event.provider != BusyProvider.microsoft.storageValue) {
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
    if (item is TaskScheduleItem) ...[
      item.notes ?? '',
      item.parentTitle ?? '',
      ...item.categories,
      ...item.checklistItems.map((subtask) => subtask.title),
    ],
  ].map((value) => value.toLowerCase()).toList();
  return terms.every((term) => fields.any((field) => field.contains(term)));
}

DateTime? _taskStart(Task task, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return _parseDateTime(task.microsoftStartDateTime) ??
        _parseDateTime(task.microsoftDueDateTime) ??
        _parseDate(task.dueUtc);
  }
  if (_isDavProvider(provider)) {
    final native = _davTaskScheduleTemporal(task);
    return _parseDavTaskTemporal(native) ?? _parseDateTime(task.dueUtc);
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
  if (provider == BusyProvider.google) {
    return true;
  }
  if (_isDavProvider(provider)) {
    final native = _davTaskScheduleTemporal(task);
    return native?.kind == 'date' ||
        (native == null && _isDateOnly(task.dueUtc ?? ''));
  }
  final scheduleDateTimes = [
    task.microsoftStartDateTime,
    task.microsoftDueDateTime,
  ].whereType<String>().where((value) => value.isNotEmpty);
  return scheduleDateTimes.isEmpty || scheduleDateTimes.every(_isDateOnly);
}

bool _isDateOnly(String value) => !value.contains('T');

bool _isDavProvider(BusyProvider provider) =>
    provider == BusyProvider.appleICloud || provider == BusyProvider.nextcloud;

_DavTaskTemporal? _davTaskScheduleTemporal(Task task) {
  final source = task.providerMetadataJson;
  if (source == null || source.isEmpty) return null;
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return null;
    for (final entry in const [
      (nativeKey: 'nativeStart', utcKey: 'startUtc'),
      (nativeKey: 'nativeDue', utcKey: 'dueUtc'),
    ]) {
      final value = decoded[entry.nativeKey];
      if (value is! Map) continue;
      final raw = value['raw'];
      final kind = value['kind'];
      if (raw is String && raw.isNotEmpty && kind is String) {
        final instantRaw = decoded[entry.utcKey];
        return _DavTaskTemporal(
          raw: raw,
          kind: kind,
          instantUtc: instantRaw is String
              ? DateTime.tryParse(instantRaw)?.toUtc()
              : null,
        );
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}

DateTime? _parseDavTaskTemporal(_DavTaskTemporal? temporal) {
  if (temporal == null) return null;
  if (temporal.instantUtc != null) return temporal.instantUtc!.toLocal();
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(?:Z)?)?$',
  ).firstMatch(temporal.raw);
  if (match == null) return null;
  final parts = [
    for (var index = 1; index <= 6; index++)
      int.tryParse(match.group(index) ?? '') ?? 0,
  ];
  final wall = DateTime(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  if (temporal.kind != 'utcDateTime') return wall;
  return DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  ).toLocal();
}

ScheduleItemCapabilities _taskScheduleCapabilities(DavCollection? collection) {
  if (collection == null) return ScheduleItemCapabilities.editable;
  try {
    final capabilities = collectionCapabilitiesFromStored(collection);
    return ScheduleItemCapabilities(
      canEdit: capabilities.canUpdateTask,
      canDelete: capabilities.canDeleteTask,
    );
  } on Object {
    // Corrupt or stale capability state must fail closed in mutation UI.
    return ScheduleItemCapabilities.readOnly;
  }
}

final class _DavTaskTemporal {
  const _DavTaskTemporal({
    required this.raw,
    required this.kind,
    required this.instantUtc,
  });

  final String raw;
  final String kind;
  final DateTime? instantUtc;
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
    final projected = _projectedEventUtc(event.rawJson, 'startUtc');
    if (projected != null) return projected.toLocal();
    return providerDateTimeAsLocal(event.startDateTime, event.startTimeZone);
  }
  return _parseDate(event.startDate) ?? _parseDate(event.startDateTime);
}

DateTime? _eventEnd(CalendarEvent event) {
  if (!event.allDay) {
    final projected = _projectedEventUtc(event.rawJson, 'endUtc');
    if (projected != null) return projected.toLocal();
    return providerDateTimeAsLocal(event.endDateTime, event.endTimeZone);
  }
  return _parseDate(event.endDate) ?? _parseDate(event.endDateTime);
}

DateTime? _projectedEventUtc(String? rawJson, String key) {
  if (rawJson == null || rawJson.isEmpty) return null;
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map || decoded[key] is! String) return null;
    return DateTime.tryParse(decoded[key] as String)?.toUtc();
  } on FormatException {
    return null;
  }
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

Object? _jsonValueFromString(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

List<Map<String, Object?>> _jsonMapListFromString(String? value) {
  final decoded = _jsonValueFromString(value);
  if (decoded is! List) {
    return const [];
  }
  return [
    for (final item in decoded)
      if (item is Map) Map<String, Object?>.from(item),
  ];
}

Map<String, Object?>? _jsonMapFromString(String? value) {
  final decoded = _jsonValueFromString(value);
  return decoded is Map ? Map<String, Object?>.from(decoded) : null;
}

bool? _eventIsOrganizer(
  BusyProvider provider,
  Map<String, Object?>? organizer,
  Map<String, Object?> raw,
) {
  return switch (provider) {
    BusyProvider.google => organizer?['self'] as bool?,
    BusyProvider.microsoft => raw['isOrganizer'] as bool?,
    BusyProvider.appleICloud ||
    BusyProvider.nextcloud ||
    BusyProvider.webCal => null,
  };
}

bool _eventAllowsFullEditing(
  BusyProvider provider,
  bool? isOrganizer,
  Map<String, Object?> raw,
) {
  if (provider == BusyProvider.webCal) return false;
  if (provider != BusyProvider.google) return true;
  return raw['locked'] != true &&
      (isOrganizer == true || raw['guestsCanModify'] == true);
}

String? _eventCurrentUserResponse(
  BusyProvider provider,
  List<Map<String, Object?>> attendees,
  Map<String, Object?> raw,
) {
  if (provider == BusyProvider.google) {
    for (final attendee in attendees) {
      if (attendee['self'] == true) {
        return attendee['responseStatus']?.toString();
      }
    }
    return null;
  }
  if (provider == BusyProvider.microsoft) {
    final responseStatus = raw['responseStatus'];
    if (responseStatus is Map) {
      return responseStatus['response']?.toString();
    }
  }
  return null;
}

String? _eventJoinMeetingUrl(
  BusyProvider provider,
  Object? conference,
  Map<String, Object?> raw,
) {
  if (conference is Map) {
    if (provider == BusyProvider.microsoft) {
      final joinUrl = conference['joinUrl']?.toString().trim();
      if (_isWebUrl(joinUrl)) return joinUrl;
    }
    if (provider == BusyProvider.google) {
      final entryPoints = conference['entryPoints'];
      if (entryPoints is List) {
        for (final entry in entryPoints.whereType<Map>()) {
          if (entry['entryPointType']?.toString() != 'video') continue;
          final uri = entry['uri']?.toString().trim();
          if (_isWebUrl(uri)) return uri;
        }
      }
    }
  }
  final fallback = switch (provider) {
    BusyProvider.google => raw['hangoutLink']?.toString().trim(),
    BusyProvider.microsoft => raw['onlineMeetingUrl']?.toString().trim(),
    BusyProvider.appleICloud ||
    BusyProvider.nextcloud ||
    BusyProvider.webCal => null,
  };
  return _isWebUrl(fallback) ? fallback : null;
}

bool _isWebUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
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
      BusyProvider.microsoft =>
        map['isReminderOn'] == true
            ? [map['reminderMinutesBeforeStart']]
            : const <Object?>[],
      BusyProvider.google =>
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
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud ||
      BusyProvider.webCal => switch (map['minutes'] ?? map['overrides']) {
        final List<Object?> values => values,
        final int value => [value],
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

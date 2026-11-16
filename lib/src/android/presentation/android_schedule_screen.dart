import '../../features/calendar/domain/event_move_policy.dart';
import '../../features/calendar/domain/event_timing_policy.dart';
import 'android_event_description_editor.dart';
import '../../calendar_providers/calendar_description.dart';
import 'android_time_zone_picker.dart';
import '../../schedule/schedule_sidebar_order.dart';
import '../../schedule/schedule_sidebar_sources.dart';
import '../../schedule/schedule_event_rescheduling.dart';
import 'android_event_actions.dart';
import '../../schedule/schedule_agenda_query.dart';
import '../android_workspace_navigation.dart';
import '../../features/tasks/domain/task_checklist_item.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/calendar/presentation/dav_event_reminders.dart';
import 'android_dav_attachments_section.dart';
import '../../features/recurrence/presentation/recurrence_summary.dart';

import 'package:busymax/src/core/auth/authorization_attempt.dart';

import 'dart:async';
import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../contacts/busymax_contacts_controller.dart';
import '../../app/common/busymax_motion_widgets.dart';
import '../../app/common/busymax_mutation_list.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../calendar_providers/calendar_provider_capabilities.dart';
import '../../core/logging/redacting_logger.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../features/calendar/domain/google_status_event.dart';
import '../../features/calendar/presentation/google_status_event_labels.dart';
import '../../features/maps/application/external_location_launcher.dart';
import '../../features/schedule/application/saved_schedule_location.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../features/schedule/presentation/schedule_item_exporter.dart';
import '../../features/schedule/presentation/cloud_calendar_series_export.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';
import '../../l10n/nextcloud_collection_error_description.dart';
import '../../l10n/time_format_scope.dart';
import '../../l10n/week_preferences_scope.dart';
import '../../microsoft_calendar/microsoft_calendar_models.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_item.dart';
import '../../schedule/schedule_projection.dart';
import '../../schedule/schedule_range.dart';
import '../../schedule/schedule_view_mode.dart';
import '../../schedule/schedule_source_visibility.dart';
import '../../schedule/task_list_mutation_intent.dart';
import '../../schedule/schedule_search_criteria.dart';
import 'android_schedule_search_filters.dart';
import '../../features/schedule/presentation/schedule_search_result_text.dart';
import '../android_notifications.dart';
import 'android_availability_dialog.dart';
import 'android_event_attachments_dialog.dart';
import 'android_recurrence_dialog.dart';
import 'android_date_picker.dart';
import 'android_settings_screen.dart';
import 'android_tasks_screen.dart';
import 'android_task_motion.dart';

final _androidScheduleItemsProvider = FutureProvider.autoDispose
    .family<
      ScheduleAgendaPage,
      ({
        DateTime anchor,
        ScheduleViewMode mode,
        String query,
        int firstWeekday,
        ScheduleSearchCriteria? search,
        int agendaDays,
        int overdueLimit,
        int noDateLimit,
        DateTime? notificationDate,
      })
    >((ref, key) async {
      ref.watch(scheduleDataRevisionProvider);
      final sourceState = ref.watch(calendarSourcesStreamProvider);
      final listState = ref.watch(scheduleTaskListsProvider);
      final sources = sourceState.hasError && sourceState.hasValue
          ? sourceState.requireValue
          : await ref.watch(calendarSourcesStreamProvider.future);
      final lists = listState.hasError && listState.hasValue
          ? listState.requireValue
          : await ref.watch(scheduleTaskListsProvider.future);
      final settings = ref.watch(appSettingsControllerProvider);
      final visibility = ScheduleSourceVisibility.fromSources(
        calendarSources: sources,
        taskLists: lists,
        settings: settings,
      );
      final repository = ref.watch(scheduleRepositoryProvider);
      if (key.notificationDate != null) {
        return ScheduleAgendaPage(
          items: await repository.listAllTasks(
            filters: ScheduleFilters(
              includeCalendarEvents: false,
              taskCompletion: ScheduleTaskCompletion.open,
              notificationDeadline: key.notificationDate,
            ),
          ),
        );
      }
      if (key.search == null && key.mode == ScheduleViewMode.agenda) {
        return queryScheduleAgenda(
          repository,
          range: ScheduleRange.days(DateTime.now(), count: key.agendaDays),
          sourceIds: visibility.visibleCalendarSourceIds,
          taskListKeys: visibility.visibleTaskListKeys,
          overdueLimit: key.overdueLimit,
          noDateLimit: key.noDateLimit,
        );
      }
      return ScheduleAgendaPage(
        items: await repository.listItems(
          range:
              key.search?.range ??
              _rangeFor(key.anchor, key.mode, firstWeekday: key.firstWeekday),
          filters:
              key.search?.filters(key.query) ??
              ScheduleFilters(
                query: key.query,
                sourceIds: visibility.visibleCalendarSourceIds,
                taskListKeys: visibility.visibleTaskListKeys,
                sourceFilterActive: true,
                taskListFilterActive: true,
                taskCompletion: ScheduleTaskCompletion.all,
                showNoDateTasks: false,
              ),
        ),
      );
    });

class AndroidScheduleScreen extends ConsumerStatefulWidget {
  const AndroidScheduleScreen({super.key});

  @override
  ConsumerState<AndroidScheduleScreen> createState() =>
      _AndroidScheduleScreenState();
}

class _AndroidScheduleScreenState extends ConsumerState<AndroidScheduleScreen>
    with RouteAware {
  AndroidWorkspaceRequest? _queuedRequest;
  ModalRoute<dynamic>? _workspaceRoute;
  DateTime _anchor = DateTime.now();
  DateTime? _searchAnchor;
  List<ScheduleItem>? _cachedSearchItems;
  ScheduleSearchCriteria? _cachedSearchCriteria;
  String? _cachedSearchQuery;
  ScheduleAgendaPage? _cachedAgendaPage;
  String? _cachedAgendaScope;
  int _agendaDays = 30;
  int _overdueLimit = 8;
  int _noDateLimit = 8;
  DateTime? _notificationDate;
  bool _searching = false;
  bool _allTaskLists = false;
  TaskListEntity? _creationTaskList;
  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  ScheduleSearchCriteria? _searchCriteria;
  ScheduleSearchCriteria? _initialSearchCriteria;
  var _searchFirstWeekday = DateTime.monday;
  var _searchRequestGeneration = 0;
  var _navigationGeneration = 0;
  var _navigationDirection = 0;
  var _taskMutationGeneration = 0;
  TaskListMutationIntent? _taskMutationIntent;
  final Set<String> _taskMutationsInFlight = {};
  final Set<String> _openDetails = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _workspaceRoute && route != null) {
      androidWorkspaceRouteObserver.unsubscribe(this);
      androidWorkspaceRouteObserver.subscribe(this, route);
      _workspaceRoute = route;
    }
    final firstWeekday = _firstWeekday(context);
    if (_searchFirstWeekday == firstWeekday) return;
    _searchFirstWeekday = firstWeekday;
    _searchCriteria = _searchCriteria?.copyWith(firstWeekday: firstWeekday);
    _initialSearchCriteria = _initialSearchCriteria?.copyWith(
      firstWeekday: firstWeekday,
    );
  }

  @override
  void dispose() {
    androidWorkspaceRouteObserver.unsubscribe(this);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    final request = _queuedRequest;
    if (request != null) {
      _queuedRequest = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openWorkspaceRequest(request));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final replacements = ref.watch(taskListIdReplacementsProvider);
    _searchCriteria = _searchCriteria?.remapTaskLists(replacements);
    _initialSearchCriteria = _initialSearchCriteria?.remapTaskLists(
      replacements,
    );
    final settings = ref.watch(appSettingsControllerProvider);
    if (_allTaskLists && _searchCriteria != null) {
      final lists = ref.watch(scheduleTaskListsProvider).valueOrNull;
      if (lists != null) {
        _searchCriteria = _searchCriteria!.copyWith(
          taskListKeys: {
            for (final list in lists)
              ScheduleTaskListKey(
                accountId: list.accountId,
                taskListId: list.id,
              ),
          },
        );
      }
    }
    ref.listen(androidWorkspaceRequestProvider, (_, request) {
      if (request != null) unawaited(_openWorkspaceRequest(request));
    });
    final mode = settings.androidScheduleViewMode ?? settings.scheduleViewMode;
    final page = ref.watch(
      _androidScheduleItemsProvider((
        anchor: DateTime(_anchor.year, _anchor.month, _anchor.day),
        mode: mode,
        query: _query,
        search: _searching ? _searchCriteria : null,
        firstWeekday: _firstWeekday(context),
        agendaDays: _agendaDays,
        overdueLimit: _overdueLimit,
        noDateLimit: _noDateLimit,
        notificationDate: _notificationDate,
      )),
    );
    var items = page.whenData((value) => value.items);
    if (!_searching && mode == ScheduleViewMode.agenda) {
      final sourceInventory = ref.watch(calendarSourcesStreamProvider);
      final taskInventory = ref.watch(scheduleTaskListsProvider);
      final visibility = ScheduleSourceVisibility.fromSources(
        calendarSources: sourceInventory.valueOrNull ?? const [],
        taskLists: taskInventory.valueOrNull ?? const [],
        settings: settings,
      );
      final sourceKeys = visibility.visibleCalendarSourceIds.toList()..sort();
      final listKeys =
          visibility.visibleTaskListKeys
              .map((key) => '${key.accountId}\u0000${key.taskListId}')
              .toList()
            ..sort();
      final scope = jsonEncode([
        ScheduleProjection.day(DateTime.now()).toIso8601String(),
        sourceKeys,
        listKeys,
      ]);
      if (!sourceInventory.isLoading &&
          !taskInventory.isLoading &&
          _cachedAgendaScope != scope) {
        _cachedAgendaPage = null;
        _cachedAgendaScope = scope;
      }
      if (page.hasValue) {
        _cachedAgendaPage = page.requireValue;
      }
      if (!items.hasValue && _cachedAgendaPage != null) {
        items = items.copyWithPrevious(AsyncData(_cachedAgendaPage!.items));
      }
    }
    final searchCriteria = _searchCriteria;
    if (_searching && searchCriteria != null) {
      if (_cachedSearchCriteria != searchCriteria ||
          _cachedSearchQuery != _query) {
        _cachedSearchItems = null;
        _cachedSearchCriteria = searchCriteria;
        _cachedSearchQuery = _query;
      }
      if (items.hasValue) {
        _cachedSearchItems = items.requireValue;
      } else if (_cachedSearchItems != null) {
        items = items.copyWithPrevious(AsyncData(_cachedSearchItems!));
      }
    }
    final displayedRange =
        searchCriteria?.range ??
        _rangeFor(
          DateTime(_anchor.year, _anchor.month, _anchor.day),
          mode,
          firstWeekday: _firstWeekday(context),
        );
    final coverageFilters = _searching && searchCriteria != null
        ? searchCriteria.filters(_query)
        : ScheduleFilters(
            sourceIds: ScheduleSourceVisibility.fromSources(
              calendarSources:
                  ref.watch(calendarSourcesStreamProvider).valueOrNull ??
                  const [],
              taskLists: const [],
              settings: settings,
            ).visibleCalendarSourceIds,
            sourceFilterActive: true,
          );
    final bool? coverageComplete =
        items.hasValue && coverageFilters.requiresCalendarCoverage
        ? ref
              .read(scheduleRepositoryProvider)
              .cloudCoverageCompleteFor(
                displayedRange,
                filters: coverageFilters,
              )
        : true;
    final presentation = _searching && searchCriteria != null
        ? _buildSearchPresentation(
            items: items,
            criteria: searchCriteria,
            query: _query,
          )
        : _buildCalendarPresentation(
            items: items,
            mode: mode,
            agendaPage: page.valueOrNull ?? _cachedAgendaPage,
          );
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _closeSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          title: BusyMaxBinaryPresentation(
            alternateActive: _searching,
            child: _searching
                ? TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: context.l10n.windowsSearch,
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .clearButtonTooltip,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _notificationDate = null;
                    }),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: mode == ScheduleViewMode.agenda ? null : _selectDate,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(_periodLabel(context, _anchor, mode)),
                        ),
                      ),
                    ),
                  ),
          ),
          actions: [
            IconButton(
              tooltip: context.l10n.windowsSearch,
              onPressed: _searching ? _closeSearch : _openSearch,
              icon: Icon(_searching ? Icons.close : Icons.search),
            ),
            IconButton(
              tooltip: _searching
                  ? context.l10n.searchFiltersAction
                  : context.l10n.collectionSettings,
              onPressed: () =>
                  _searching ? _showSearchFilters() : _showSources(context),
              icon: const Icon(Icons.tune),
            ),
            if (!_searching)
              PopupMenuButton<String>(
                key: const ValueKey('android-workspace-menu'),
                tooltip: context.l10n.scheduleDisplaySettings,
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const AndroidSettingsScreen(),
                      ),
                    );
                  } else if (value == 'tasks') {
                    unawaited(_browseTasks());
                  } else {
                    unawaited(
                      ref
                          .read(appSettingsControllerProvider.notifier)
                          .setAndroidScheduleViewMode(
                            ScheduleViewMode.values.byName(value),
                          ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  for (final candidate in ScheduleViewMode.values)
                    CheckedPopupMenuItem(
                      value: candidate.name,
                      checked: candidate == mode,
                      child: Text(_modeLabel(context, candidate)),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'tasks',
                    child: Text(context.l10n.allTasks),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text(context.l10n.settings),
                  ),
                ],
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (constraints.maxWidth >= 840) ...[
                SizedBox(width: 300, child: _sourcesPane()),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    BusyMaxVerticalReveal(
                      visible: !_searching,
                      child: _navigationRow(context, mode),
                    ),
                    if (coverageComplete != true && items.hasValue)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            coverageComplete == null
                                ? Icons.sync
                                : Icons.cloud_off_outlined,
                          ),
                          title: Text(
                            coverageComplete == null
                                ? context.l10n.scheduleLoading
                                : context.l10n.scheduleRangeIncomplete,
                          ),
                          dense: true,
                        ),
                      ),
                    Expanded(
                      child: BusyMaxBinaryPresentation(
                        alternateActive: _searching,
                        child: presentation,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'android-schedule-add',
          onPressed: () => _createItem(context),
          tooltip: context.l10n.create,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCalendarPresentation({
    required AsyncValue<List<ScheduleItem>> items,
    required ScheduleViewMode mode,
    ScheduleAgendaPage? agendaPage,
  }) {
    // A provider-family key change may be loading for longer than the period
    // motion. Keep the destination calendar mounted with an empty, coherent
    // projection instead of replacing it with the progress indicator.
    final rawItems = items.valueOrNull ?? const <ScheduleItem>[];
    final displayedItems = mode == ScheduleViewMode.agenda
        ? scheduleAgendaItems(
            rawItems,
            ScheduleRange.days(DateTime.now(), count: _agendaDays),
          )
        : rawItems;
    return Stack(
      fit: StackFit.expand,
      children: [
        BusyMaxDirectionalEntrance(
          generation: _navigationGeneration,
          direction: _navigationDirection,
          child: _ScheduleBody(
            anchor: _anchor,
            mode: mode,
            items: displayedItems,
            onSelectDate: (date) => setState(() => _anchor = date),
            onModeChanged: (value) => unawaited(
              ref
                  .read(appSettingsControllerProvider.notifier)
                  .setAndroidScheduleViewMode(value),
            ),
            onOpen: (item) => _showItem(context, item),
            onToggleTask: _toggleTask,
            taskMutationIntent: _taskMutationIntent,
            taskMutationsInFlight: _taskMutationsInFlight,
            onTaskMutationConsumed: _consumeTaskMutation,
            agendaPage: agendaPage,
            onLoadMore: () => setState(() => _agendaDays += 30),
            onLoadMoreOverdue: () => setState(() => _overdueLimit += 8),
            onLoadMoreNoDate: () => setState(() => _noDateLimit += 8),
            onCreate: (start, end) =>
                _createItem(context, start: start, end: end),
            onToggleChecklist: _toggleChecklist,
            onReschedule: _rescheduleEvent,
            dayStartMinute: ref
                .watch(appSettingsControllerProvider)
                .scheduleDayStartMinute,
            dayEndMinute: ref
                .watch(appSettingsControllerProvider)
                .scheduleDayEndMinute,
            agendaEmptyBuilder: items.isLoading
                ? (context) => const SizedBox.shrink()
                : null,
          ),
        ),
        if (items.isLoading)
          const IgnorePointer(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (items.hasError && !items.hasValue)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _Message(
                icon: Icons.error_outline,
                title: context.l10n.scheduleUnavailable,
                detail: '${items.error}',
              ),
            ),
          ),
        if (items.hasError && items.hasValue)
          Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: ListTile(
                title: Text(context.l10n.scheduleUnavailable),
                trailing: TextButton(
                  onPressed: _retrySchedule,
                  child: Text(context.l10n.retry),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchPresentation({
    required AsyncValue<List<ScheduleItem>> items,
    required ScheduleSearchCriteria criteria,
    required String query,
  }) {
    if (items.isLoading && items.valueOrNull == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.hasError && items.valueOrNull == null) {
      return Column(
        children: [
          Expanded(
            child: _Message(
              icon: Icons.error_outline,
              title:
                  criteria.type == ScheduleSearchType.tasks ||
                      ref.watch(scheduleTaskListsProvider).hasError
                  ? context.l10n.collectionsLoadFailed
                  : context.l10n.scheduleUnavailable,
              detail: context.l10n.networkOfflineTryAgain,
            ),
          ),
          TextButton(
            onPressed: () => _retrySchedule(),
            child: Text(context.l10n.retry),
          ),
        ],
      );
    }
    return Column(
      children: [
        if (items.hasError)
          ListTile(
            title: Text(context.l10n.scheduleUnavailable),
            trailing: TextButton(
              onPressed: () => _retrySchedule(),
              child: Text(context.l10n.retry),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _retrySchedule();
            },
            child: _AgendaList(
              key: const ValueKey('android-search-results'),
              items: items.valueOrNull ?? const [],
              onOpen: (item) => _showItem(context, item),
              onToggleTask: _toggleTask,
              onToggleChecklist: _toggleChecklist,
              searchCriteria: criteria,
              searchQuery: query,
              taskMutationIntent: _taskMutationIntent,
              taskMutationsInFlight: _taskMutationsInFlight,
              onTaskMutationConsumed: _consumeTaskMutation,
              emptyBuilder: (context) => _Message(
                icon: Icons.search_off,
                title: !criteria.hasSources
                    ? context.l10n.searchNoSources
                    : context.l10n.scheduleNoSearchResults,
                detail: context.l10n.scheduleNoSearchResultsDescription,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _retrySchedule() {
    ref.invalidate(scheduleTaskListsProvider);
    ref.invalidate(calendarSourcesStreamProvider);
    ref.invalidate(_androidScheduleItemsProvider);
  }

  Future<void> _browseTasks({TaskListEntity? list}) async {
    await _openSearch(focus: false);
    if (!mounted || _searchCriteria == null) return;
    List<TaskListEntity> lists;
    try {
      lists = await ref.read(scheduleTaskListsProvider.future);
    } on Object {
      lists = ref.read(scheduleTaskListsProvider).valueOrNull ?? const [];
    }
    if (!mounted) return;
    setState(() {
      _allTaskLists = list == null;
      _creationTaskList = list;
      _searchCriteria = _searchCriteria!.copyWith(
        type: ScheduleSearchType.tasks,
        date: ScheduleSearchDate.any,
        taskListKeys: {
          for (final candidate in lists)
            if (list == null ||
                (candidate.accountId == list.accountId &&
                    candidate.id == list.id))
              ScheduleTaskListKey(
                accountId: candidate.accountId,
                taskListId: candidate.id,
              ),
        },
      );
      _initialSearchCriteria = _searchCriteria;
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _openWorkspaceRequest(AndroidWorkspaceRequest request) async {
    ref.read(androidWorkspaceRequestProvider.notifier).state = null;
    if (_workspaceRoute?.isCurrent == false) {
      _queuedRequest = request;
      return;
    }
    if (request.summary) {
      await _browseTasks();
      if (mounted) {
        setState(() {
          _anchor = request.date;
          _notificationDate = request.date;
        });
      }
      return;
    }
    final repository = ref.read(scheduleRepositoryProvider);
    final items = await repository.listItems(
      range: ScheduleRange.day(request.date),
      filters: ScheduleFilters(
        accountIds: request.accountId == null ? const {} : {request.accountId!},
        ignoreDateRange: true,
        taskCompletion: ScheduleTaskCompletion.all,
        includeCalendarEvents: !request.task,
        includeTasks: request.task,
      ),
    );
    final item = items.where((item) => item.id == request.itemId).firstOrNull;
    if (!mounted) return;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notificationItemUnavailable)),
      );
      return;
    }
    if (!request.task && _searching) _closeSearch();
    setState(() => _anchor = item.start ?? request.date);
    if (!request.task) {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setAndroidScheduleViewMode(ScheduleViewMode.day);
    }
    if (request.task) await _browseTasks();
    if (mounted) await _showItem(context, item);
  }

  Future<void> _rescheduleEvent(ScheduleRescheduleRequest request) async {
    try {
      await ScheduleReschedulingCoordinator(
        repository: ref.read(calendarRepositoryProvider),
        chooseScope: (_, following) =>
            showAndroidRecurringScope(context, supportsFollowing: following),
        chooseGuestUpdates: (draft) => showAndroidGuestDeliveryDialog(
          context,
          provider: request.item.provider,
        ),
        confirmSeriesTimingChange: (change, scope) =>
            confirmAndroidSeriesTimingChange(context, change, scope),
        requestSync: (accountId) async => ref
            .read(
              pendingCalendarMutationSyncRequesterForAccountProvider(accountId),
            )
            .request(),
      ).commit(request, isActive: () => mounted);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.scheduleRescheduleFailed} $error'),
          ),
        );
      }
    }
  }

  Future<void> _toggleChecklist(
    TaskScheduleItem parent,
    TaskChecklistItemEntity step,
  ) async {
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(parent.accountId))
          .patchChecklistSubtask(
            taskListId: parent.sourceId,
            parentTaskId: parent.id,
            checklistItemId: step.id,
            completed: !step.completed,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _openSearch({bool focus = true}) async {
    final generation = ++_searchRequestGeneration;
    List<CalendarSourceEntity> sources;
    List<TaskListEntity> lists;
    try {
      sources = await ref.read(calendarSourcesStreamProvider.future);
    } on Object {
      sources = ref.read(calendarSourcesStreamProvider).valueOrNull ?? const [];
    }
    try {
      lists = await ref.read(scheduleTaskListsProvider.future);
    } on Object {
      lists = ref.read(scheduleTaskListsProvider).valueOrNull ?? const [];
    }
    if (!mounted || generation != _searchRequestGeneration) return;
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: sources,
      taskLists: lists,
      settings: ref.read(appSettingsControllerProvider),
    );
    final now = DateTime.now();
    setState(() {
      if (!_searching) _searchAnchor = _anchor;
      _initialSearchCriteria = ScheduleSearchCriteria(
        referenceDate: DateTime(now.year, now.month, now.day),
        firstWeekday: _firstWeekday(context),
        sourceIds: visibility.visibleCalendarSourceIds,
        taskListKeys: visibility.visibleTaskListKeys,
      ).remapTaskLists(ref.read(taskListIdReplacementsProvider));
      _searchCriteria = _initialSearchCriteria;
      _searching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focus ||
          !mounted ||
          !_searching ||
          generation != _searchRequestGeneration) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchRequestGeneration += 1;
    _searchFocusNode.unfocus();
    setState(() {
      _searching = false;
      _cachedSearchItems = null;
      _anchor = _searchAnchor ?? _anchor;
      _searchAnchor = null;
      _notificationDate = null;
      _allTaskLists = false;
      _creationTaskList = null;
      _searchCriteria = null;
      _initialSearchCriteria = null;
      _query = '';
      _searchController.clear();
    });
  }

  Widget _navigationRow(BuildContext context, ScheduleViewMode mode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          if (mode != ScheduleViewMode.agenda)
            IconButton(
              tooltip: context.l10n.shortcutPreviousPeriod,
              onPressed: () => _movePeriod(mode, -1),
              icon: const Icon(Icons.chevron_left),
            ),
          FilledButton.tonal(
            onPressed: () => setState(() {
              _navigationDirection = 0;
              _anchor = DateTime.now();
            }),
            child: Text(context.l10n.today),
          ),
          if (mode != ScheduleViewMode.agenda)
            IconButton(
              tooltip: context.l10n.shortcutNextPeriod,
              onPressed: () => _movePeriod(mode, 1),
              icon: const Icon(Icons.chevron_right),
            ),
          const Spacer(),
          Flexible(
            child: Text(
              _modeLabel(context, mode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _movePeriod(ScheduleViewMode mode, int direction) {
    setState(() {
      _anchor = _move(_anchor, mode, direction);
      _navigationDirection = direction;
      _navigationGeneration += 1;
    });
  }

  Future<void> _showSearchFilters() async {
    if (_searchCriteria == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final firstWeekday = _firstWeekday(context);
          return SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: AndroidScheduleSearchFilters(
                  value: _searchCriteria!.copyWith(firstWeekday: firstWeekday),
                  accounts:
                      ref.read(accountsStreamProvider).valueOrNull ?? const [],
                  sources:
                      ref.read(calendarSourcesStreamProvider).valueOrNull ??
                      const [],
                  taskLists:
                      ref.read(scheduleTaskListsProvider).valueOrNull ??
                      const [],
                  onChanged: (value) {
                    setState(() {
                      _notificationDate = null;
                      _allTaskLists = false;
                      _searchCriteria = value.copyWith(
                        firstWeekday: _firstWeekday(context),
                      );
                    });
                    update(() {});
                  },
                  onClear: () {
                    setState(
                      () => _searchCriteria = _initialSearchCriteria?.copyWith(
                        firstWeekday: _firstWeekday(context),
                      ),
                    );
                    update(() {});
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sourcesPane({bool dismissOnNavigate = false}) => _AndroidSourcesPane(
    selectedDate: _anchor,
    onNavigate: (date, mode) {
      if (dismissOnNavigate) Navigator.pop(context);
      setState(() => _anchor = date);
      unawaited(
        ref
            .read(appSettingsControllerProvider.notifier)
            .setAndroidScheduleViewMode(mode),
      );
    },
    onBrowseTasks: (list) {
      if (dismissOnNavigate) Navigator.pop(context);
      unawaited(_browseTasks(list: list));
    },
  );

  Future<void> _showSources(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: _sourcesPane(dismissOnNavigate: true),
      ),
    ),
  );

  Future<void> _selectDate() async {
    final selected = await showBusyMaxDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected != null && mounted) setState(() => _anchor = selected);
  }

  Future<void> _createItem(
    BuildContext context, {
    DateTime? start,
    DateTime? end,
  }) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(context.l10n.newEvent),
              onTap: () => Navigator.pop(context, 'event'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(context.l10n.newTask),
              onTap: () => Navigator.pop(context, 'task'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || type == null) return;
    if (type == 'event') {
      await _createEvent(context, start: start, end: end);
      return;
    }
    final lists = ref.read(scheduleTaskListsProvider).valueOrNull ?? const [];
    if (lists.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.noTaskListsSynced)));
      return;
    }
    final accounts =
        ref.read(accountsStreamProvider).valueOrNull ?? const <AccountEntity>[];
    final settings = ref.read(appSettingsControllerProvider);
    final list =
        (lists.any(
              (l) =>
                  l.accountId == _creationTaskList?.accountId &&
                  l.id == _creationTaskList?.id,
            )
            ? _creationTaskList
            : null) ??
        preferredCreationDestination(
          lists,
          selected: settings.defaultTaskList,
          lastUsed: settings.lastUsedTaskList,
          destinationOf: (list) =>
              CreationDestination(accountId: list.accountId, id: list.id),
        ) ??
        await selectAndroidTaskList(
          context,
          lists,
          title: context.l10n.newTask,
          accountLabels: {
            for (final account in accounts) account.id: account.selectorLabel,
          },
        );
    if (list == null || !context.mounted) return;
    final account = accounts
        .where((value) => value.id == list.accountId)
        .firstOrNull;
    if (account == null) return;
    final result = await showAndroidTaskEditor(
      context,
      ref,
      creationList: list,
      creationProvider: account.provider,
      initialDue: start ?? DateTime(_anchor.year, _anchor.month, _anchor.day),
      onMutationStarted: _consumeEditorResult,
      onMutationCommitted: _consumeEditorResult,
      onMutationFailed: _clearEditorMutation,
    );
    if (result == null) return;
  }

  Future<void> _showItem(BuildContext context, ScheduleItem item) async {
    if (item is TaskScheduleItem && androidTaskEditorIsActive(context)) {
      await showAndroidTaskEditor(
        context,
        ref,
        task: item,
        onMutationStarted: _consumeEditorResult,
        onMutationCommitted: _consumeEditorResult,
        onMutationFailed: _clearEditorMutation,
      );
      return;
    }
    final identity = '${item.accountId}\u0000${item.sourceId}\u0000${item.id}';
    if (!_openDetails.add(identity)) return;
    var editing = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
            ),
            child: SingleChildScrollView(
              key: const ValueKey('android-schedule-details-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.sourceName ?? item.provider.displayName} · ${item.accountEmail ?? item.accountDisplayName ?? item.accountId}',
                  ),
                  if (item is CalendarScheduleItem)
                    Text(scheduleEventIntervalLabel(context, item))
                  else if (item.start != null)
                    Text(
                      item.allDay
                          ? '${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(item.start!)} · ${context.l10n.allDay}'
                          : formatClockDateTime(
                              context,
                              item.start!,
                              DateFormat.yMMMd(
                                Localizations.localeOf(context).toLanguageTag(),
                              ).format(item.start!),
                            ),
                    ),
                  if (item is CalendarScheduleItem) ...[
                    if (item.mayNotifyParticipants)
                      Text(context.l10n.caldavSchedulingWarning),
                    for (final line in googleStatusDetailLines(
                      context.l10n,
                      item.eventType,
                      item.googleStatusProperties,
                    ))
                      Text(line),
                    if (calendarEventDescription(item).trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _AndroidEventDescription(item: item),
                      ),
                    if (item.organizer != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          '${context.l10n.organizer}: '
                          '${scheduleEventPersonName(item.organizer)}',
                        ),
                      ),
                    if (item.currentUserResponse case final response?)
                      Text(
                        '${context.l10n.yourResponse}: '
                        '${scheduleEventResponseLabel(context, response)}',
                      ),
                    for (final attendee in item.attendees)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          scheduleEventAttendeeLabel(context, attendee),
                        ),
                        subtitle: attendee['scheduleStatus'] == null
                            ? null
                            : Text(
                                '${context.l10n.nextcloudSchedulingStatus}: ${attendee['scheduleStatus']}',
                              ),
                      ),
                    if (item.joinMeetingUrl case final meetingLink?)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            _openEventWebLink(meetingLink, meeting: true),
                          );
                        },
                        icon: const Icon(Icons.video_call_outlined),
                        label: Text(context.l10n.joinMeeting),
                      ),
                    if (item.eventLinkUrl case final eventLink?)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(_openEventWebLink(eventLink));
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: Text(context.l10n.eventLink),
                      ),
                    if (item.attachmentsMayExist ||
                        item.attachmentLinks.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file),
                        title: Text(context.l10n.attachments),
                      ),
                    for (final attachment in item.attachmentLinks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_new),
                        title: Text(attachment.name),
                        subtitle: attachment.mimeType == null
                            ? null
                            : Text(attachment.mimeType!),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(_openEventWebLink(attachment.url));
                        },
                      ),
                    if (item.provider.isDav && item.attachmentsLoaded)
                      AndroidDavAttachmentsSection.event(
                        eventId: item.id,
                        showHeading:
                            !item.attachmentsMayExist &&
                            item.attachmentLinks.isEmpty,
                      ),
                    if (item.attachmentsMayExist && !item.attachmentsLoaded)
                      Text(context.l10n.attachmentsNotLoaded),
                    if (item.provider == BusyProvider.microsoft &&
                        item.providerEventId != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            showAndroidEventAttachmentsDialog(context, item),
                          );
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(context.l10n.attachments),
                      ),
                    for (final uri in calendarEventDescriptionLinks(item))
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(_openEventWebLink(uri.toString()));
                        },
                        child: Text(uri.toString()),
                      ),
                  ],
                  if (projectedScheduleItemLocationDestination(item)
                      case final destination?)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place),
                      title: Text(
                        savedScheduleLocationDisplayText(item, destination),
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => unawaited(
                        const ExternalLocationLauncher(
                          platform: _androidLocationPlatform,
                        ).open(destination),
                      ),
                    ),
                  if (item.categories.isNotEmpty)
                    Text(
                      '${context.l10n.categories}: ${item.categories.join(', ')}',
                    ),
                  if (item is CalendarScheduleItem)
                    for (final minutes in item.reminderMinutesBeforeStart)
                      Text(
                        '${context.l10n.reminder}: ${context.l10n.reminderMinutesBefore(minutes)}',
                      ),
                  if (item is TaskScheduleItem) ...[
                    Text(
                      item.cancelled
                          ? context.l10n.taskStatusCancelled
                          : item.completed
                          ? context.l10n.taskStatusCompleted
                          : context.l10n.openStatus,
                    ),
                    if (item.due != null)
                      Text(
                        '${context.l10n.dueDate}: ${DateFormat.yMMMd().format(item.due!)}',
                      ),
                    if (item.reminder != null)
                      Text(
                        '${context.l10n.reminder}: ${formatClockDateTime(context, item.reminder!, DateFormat.yMMMd().format(item.reminder!))}',
                      ),
                    if (item.provider.isDav)
                      AndroidDavAttachmentsSection.task(
                        target: (
                          accountId: item.accountId,
                          taskListId: item.sourceId,
                          taskId: item.id,
                        ),
                      ),
                  ],
                  if (item case TaskScheduleItem(:final notes?)
                      when notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(notes),
                    ),
                  if (item is TaskScheduleItem)
                    for (final link in item.availableSourceLinks)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(_openEventWebLink(link.url));
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          link.label?.isNotEmpty == true
                              ? link.label!
                              : context.l10n.openInProvider,
                        ),
                      ),
                  if (item is CalendarScheduleItem &&
                      item.canRespondToInvitation) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              _respondToInvitation(
                                item,
                                CalendarInvitationResponse.accept,
                              ),
                            );
                          },
                          child: Text(context.l10n.acceptInvitation),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              _respondToInvitation(
                                item,
                                CalendarInvitationResponse.tentative,
                              ),
                            );
                          },
                          child: Text(context.l10n.tentativeInvitation),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(
                              _respondToInvitation(
                                item,
                                CalendarInvitationResponse.decline,
                              ),
                            );
                          },
                          child: Text(context.l10n.declineInvitation),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (item.capabilities.canEdit || item is TaskScheduleItem)
                    FilledButton.icon(
                      onPressed: () async {
                        if (editing) return;
                        editing = true;
                        Navigator.pop(sheetContext);
                        if (item is CalendarScheduleItem) {
                          await _editEvent(context, item);
                        } else if (item is TaskScheduleItem) {
                          final result = await showAndroidTaskEditor(
                            context,
                            ref,
                            task: item,
                            onMutationStarted: _consumeEditorResult,
                            onMutationCommitted: _consumeEditorResult,
                            onMutationFailed: _clearEditorMutation,
                          );
                          if (result == null) return;
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: Text(
                        item is CalendarScheduleItem
                            ? context.l10n.editEvent
                            : item.capabilities.canEdit
                            ? context.l10n.editTask
                            : context.l10n.taskDetails,
                      ),
                    ),
                  if (item.capabilities.canDelete)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        item is CalendarScheduleItem && item.isNextcloudAttendee
                            ? context.l10n.nextcloudDeclineAndRemove
                            : context.l10n.delete,
                      ),
                      onPressed: () async {
                        if (await _deleteItem(item) && sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                  ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportItem(sheetContext, item),
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(context.l10n.export),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      _openDetails.remove(identity);
    }
  }

  Future<bool> _deleteItem(ScheduleItem item) async {
    if (!item.capabilities.canDelete) return false;
    try {
      RecurringEventMutationScope? scope;
      if (item is CalendarScheduleItem &&
          item.providerRecurringEventId != null) {
        final detail = await ref
            .read(calendarRepositoryProvider)
            .loadEventDetail(item.id);
        if (!mounted || detail == null) return false;
        scope = await showAndroidRecurringScope(
          context,
          supportsFollowing:
              !item.isNextcloudAttendee &&
              eventSupportsThisAndFollowing(detail),
        );
        if (scope == null || !mounted) return false;
      }
      var policy = CalendarGuestUpdatePolicy.send;
      if (item is CalendarScheduleItem &&
          (item.mayNotifyParticipants ||
              (item.provider != BusyProvider.caldav &&
                  item.isOrganizer == true &&
                  item.attendees.any(
                    (a) => a['self'] != true && a['organizer'] != true,
                  )))) {
        final result = await showAndroidGuestDeliveryDialog(
          context,
          provider: item.provider,
          deleting: true,
        );
        if (result == null || !mounted) return false;
        policy = result;
      } else {
        final attendee =
            item is CalendarScheduleItem && item.isNextcloudAttendee;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              attendee
                  ? context.l10n.nextcloudDeclineAndRemove
                  : item is TaskScheduleItem
                  ? context.l10n.deleteTask
                  : context.l10n.deleteEvent,
            ),
            content: Text(
              attendee
                  ? context.l10n.nextcloudDeclineRemovalWarning
                  : item is TaskScheduleItem
                  ? '${context.l10n.deleteTaskConfirmation(item.title)}${item.isAssigned ? '\n\n${context.l10n.deleteAssignedTaskWarning}' : ''}'
                  : context.l10n.deleteCalendarConfirmation(item.title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  attendee
                      ? context.l10n.nextcloudDeclineAndRemove
                      : context.l10n.delete,
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return false;
      }
      if (item is CalendarScheduleItem) {
        final account = await ref
            .read(calendarRepositoryProvider)
            .deleteLocalEvent(
              item.id,
              recurringScope: scope,
              guestUpdatePolicy: policy,
            );
        ref
            .read(
              pendingCalendarMutationSyncRequesterForAccountProvider(account),
            )
            .request();
      } else if (item is TaskScheduleItem) {
        await ref
            .read(tasksRepositoryForAccountProvider(item.accountId))
            .deleteTask(
              item.sourceId,
              item.id,
              confirmedAssignedSourceDeletion: item.isAssigned,
            );
      }
      return true;
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
      return false;
    }
  }

  Future<void> _openEventWebLink(String value, {bool meeting = false}) async {
    if (await openScheduleWebLink(value) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          meeting
              ? context.l10n.joinMeetingFailed
              : context.l10n.eventLinkOpenFailed,
        ),
      ),
    );
  }

  Future<void> _exportItem(BuildContext context, ScheduleItem item) async {
    try {
      String? raw;
      if (item is CalendarScheduleItem) {
        final repository = ref.read(calendarRepositoryProvider);
        final detail = await repository.loadEventDetail(item.id);
        if (!mounted || !context.mounted) return;
        final recurring =
            detail != null &&
            (detail.recurrence != null ||
                detail.providerRecurringEventId != null);
        final series =
            recurring &&
                canExportAuthoritativeEventSeries(
                  provider: item.provider,
                  providerEventId: item.providerEventId,
                  davCollectionId: detail.davCollectionId,
                )
            ? await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(context.l10n.export),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(context.l10n.singleOccurrence),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(context.l10n.entireSeries),
                    ),
                  ],
                ),
              )
            : false;
        if (series == null) return;
        if (series && item.provider == BusyProvider.google) {
          raw = await exportGoogleEventSeries(
            client: ref.read(
              googleCalendarApiClientForAccountProvider(item.accountId),
            ),
            calendarId: item.providerCalendarId,
            eventId: item.providerEventId!,
            nowUtc: DateTime.now().toUtc(),
          );
        } else if (series && item.provider == BusyProvider.microsoft) {
          raw = await exportMicrosoftEventSeries(
            client: ref.read(
              microsoftCalendarApiClientForAccountProvider(item.accountId),
            ),
            calendarId: item.providerCalendarId,
            eventId: item.providerEventId!,
            nowUtc: DateTime.now().toUtc(),
          );
        } else if (series || !recurring) {
          raw = await repository.nativeEventExport(item.id);
        }
        raw ??= scheduleItemToICalendar(item, nowUtc: DateTime.now().toUtc());
      } else if (item is TaskScheduleItem) {
        raw = await ref
            .read(tasksRepositoryForAccountProvider(item.accountId))
            .nativeTaskExport(item.sourceId, item.id);
        raw ??= scheduleItemToICalendar(item, nowUtc: DateTime.now().toUtc());
      }
      if (raw == null) return;
      final uri = await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: item is TaskScheduleItem ? 'task.ics' : 'event.ics',
        mimeType: 'text/calendar',
        bytes: Uint8List.fromList(utf8.encode(raw)),
      );
      if (context.mounted && uri != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.exportedFile(uri))));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _createEvent(
    BuildContext context, {
    DateTime? start,
    DateTime? end,
  }) async {
    final sources =
        (ref.read(calendarSourcesStreamProvider).valueOrNull ??
                const <CalendarSourceEntity>[])
            .where((source) => source.capabilities.canCreateEvents)
            .toList();
    if (sources.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.noWritableCalendars)));
      return;
    }
    final settings = ref.read(appSettingsControllerProvider);
    final source =
        preferredCreationDestination(
          sources,
          selected: settings.defaultCalendar,
          lastUsed: settings.lastUsedCalendar,
          destinationOf: (source) =>
              CreationDestination(accountId: source.accountId, id: source.id),
        ) ??
        (sources.length == 1
            ? sources.single
            : await showModalBottomSheet<CalendarSourceEntity>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(title: Text(context.l10n.newEvent)),
                      for (final candidate in sources)
                        ListTile(
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(candidate.summary),
                          subtitle: Text(
                            '${candidate.provider.displayName} · '
                            '${candidate.authenticatedAccountEmail ?? candidate.accountId}',
                          ),
                          onTap: () => Navigator.pop(sheetContext, candidate),
                        ),
                    ],
                  ),
                ),
              ));
    if (source == null || !context.mounted) return;
    start ??= DateTime(_anchor.year, _anchor.month, _anchor.day, 9);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AndroidEventEditor(
          sources: sources,
          draft: EventEditorDraft.newEvent(
            accountId: source.accountId,
            sourceId: source.id,
            providerCalendarId: source.providerCalendarId,
            start: start!,
            end: end ?? start.add(const Duration(hours: 1)),
          ),
        ),
      ),
    );
  }

  Future<void> _editEvent(
    BuildContext context,
    CalendarScheduleItem item,
  ) async {
    await showAndroidEventEditor(context, ref, eventId: item.id);
  }

  Future<void> _respondToInvitation(
    CalendarScheduleItem item,
    CalendarInvitationResponse response,
  ) async {
    if (!item.canRespondToInvitation) return;
    try {
      RecurringEventMutationScope? scope;
      if (item.provider == BusyProvider.nextcloud &&
          item.providerRecurringEventId != null) {
        scope = await showModalBottomSheet<RecurringEventMutationScope>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(context.l10n.chooseRecurringEventScope)),
                for (final value in RecurringEventMutationScope.values)
                  if (value != RecurringEventMutationScope.thisAndFuture)
                    ListTile(
                      title: Text(_scopeLabel(context, value)),
                      onTap: () => Navigator.pop(sheetContext, value),
                    ),
              ],
            ),
          ),
        );
        if (scope == null || !mounted) return;
      }
      final accountId = await ref
          .read(calendarRepositoryProvider)
          .respondToLocalEvent(item.id, response, recurringScope: scope);
      ref
          .read(
            pendingCalendarMutationSyncRequesterForAccountProvider(accountId),
          )
          .request();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.invitationResponseFailed(
              item.provider == BusyProvider.nextcloud
                  ? localizedNextcloudCollectionError(context.l10n, error)
                  : redactForLog(error),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _toggleTask(TaskScheduleItem task) async {
    final key = '${task.accountId}\u0000${task.sourceId}\u0000${task.id}';
    if (!task.capabilities.canEdit || !_taskMutationsInFlight.add(key)) return;
    final intent = TaskListMutationIntent(
      presentation: TaskListMutationPresentation.completion,
      accountId: task.accountId,
      taskListId: task.sourceId,
      taskId: task.id,
      completed: !task.completed,
      occurrenceKey: task.occurrenceKey,
      generation: ++_taskMutationGeneration,
    );
    setState(() => _taskMutationIntent = intent);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(task.accountId))
          .patchTask(
            task.sourceId,
            task.id,
            TaskPatchInput.completion(
              !task.completed,
              includeCompletedTimestamp: false,
              observedOccurrenceKey: task.occurrenceKey,
            ),
          );
    } on Object catch (error) {
      if (mounted) {
        if (_taskMutationIntent?.generation == intent.generation) {
          setState(() => _taskMutationIntent = null);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TaskOccurrenceChangedException
                  ? context.l10n.taskDraftConflict
                  : '$error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _taskMutationsInFlight.remove(key));
    }
  }

  void _consumeTaskMutation(TaskListMutationIntent intent) {
    if (!mounted) return;
    if (_taskMutationIntent?.generation == intent.generation) {
      setState(() => _taskMutationIntent = null);
    }
  }

  void _consumeEditorResult(AndroidTaskEditorResult result) {
    if (!mounted) return;
    final presentation = switch (result.action) {
      AndroidTaskEditorAction.created => TaskListMutationPresentation.insertion,
      AndroidTaskEditorAction.deleted ||
      AndroidTaskEditorAction.moved => TaskListMutationPresentation.removal,
      AndroidTaskEditorAction.updated =>
        TaskListMutationPresentation.completion,
    };
    final taskListId = result.previousTaskListId ?? result.taskListId;
    final current = _taskMutationIntent;
    if (current?.presentation == presentation &&
        current?.accountId == result.accountId &&
        current?.taskListId == taskListId &&
        current?.taskId == result.taskId &&
        current?.occurrenceKey == result.occurrenceKey &&
        current?.completed == result.completed) {
      return;
    }
    setState(() {
      _taskMutationIntent = TaskListMutationIntent(
        presentation: presentation,
        accountId: result.accountId,
        taskListId: taskListId,
        taskId: result.taskId,
        completed: result.completed,
        occurrenceKey: result.occurrenceKey,
        generation: ++_taskMutationGeneration,
      );
    });
  }

  void _clearEditorMutation() {
    if (mounted) setState(() => _taskMutationIntent = null);
  }
}

Future<void> showAndroidEventEditor(
  BuildContext context,
  WidgetRef ref, {
  required String eventId,
}) async {
  final detail = await ref
      .read(calendarRepositoryProvider)
      .loadEventDetail(eventId);
  if (!context.mounted || detail == null) return;
  final sources = await ref.read(calendarSourcesStreamProvider.future);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AndroidEventEditor(
        sources: sources,
        draft: EventEditorDraft.fromEventDetail(detail),
      ),
    ),
  );
}

ExternalLocationPlatform _androidLocationPlatform() =>
    ExternalLocationPlatform.android;

class _AndroidSourcesPane extends ConsumerStatefulWidget {
  const _AndroidSourcesPane({
    required this.selectedDate,
    required this.onNavigate,
    required this.onBrowseTasks,
  });
  final DateTime selectedDate;
  final void Function(DateTime, ScheduleViewMode) onNavigate;
  final ValueChanged<TaskListEntity?> onBrowseTasks;
  @override
  ConsumerState<_AndroidSourcesPane> createState() =>
      _AndroidSourcesPaneState();
}

class _AndroidSourcesPaneState extends ConsumerState<_AndroidSourcesPane> {
  DateTime? _month;
  @override
  Widget build(BuildContext context) {
    ref.watch(sidebarOrderRegistrationProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final accounts = ref.watch(accountsStreamProvider);
    final orderedAccounts = settings.sidebarOrder.apply(
      SidebarOrderSection.accounts,
      accounts.valueOrNull ?? const <AccountEntity>[],
      (a) => a.id,
    );
    final subscriptionsState = ref.watch(sidebarSubscriptionSourcesProvider);
    final subscriptions = settings.sidebarOrder.apply(
      SidebarOrderSection.subscriptions,
      subscriptionsState.valueOrNull ?? const <CalendarSourceEntity>[],
      (source) => source.id,
    );
    final month =
        _month ?? DateTime(widget.selectedDate.year, widget.selectedDate.month);
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.l10n.previousMonth,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _month = DateTime(month.year, month.month - 1),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () =>
                    widget.onNavigate(month, ScheduleViewMode.month),
                onLongPress: () =>
                    widget.onNavigate(month, ScheduleViewMode.year),
                child: Text(DateFormat.yMMMM().format(month)),
              ),
            ),
            IconButton(
              tooltip: context.l10n.nextMonth,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => _month = DateTime(month.year, month.month + 1),
              ),
            ),
          ],
        ),
        SizedBox(
          height:
              360 *
              (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.5),
          child: _AndroidMonthGrid(
            displayedMonth: month,
            selectedDate: widget.selectedDate,
            items: const [],
            compact: true,
            onDaySelected: (d) => widget.onNavigate(d, ScheduleViewMode.day),
            onWeekSelected: (d) => widget.onNavigate(d, ScheduleViewMode.week),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.checklist),
          title: Text(context.l10n.allTasks),
          onTap: () => widget.onBrowseTasks(null),
        ),
        if (accounts.isLoading) const LinearProgressIndicator(),
        if (accounts.hasError)
          ListTile(
            title: Text(context.l10n.scheduleUnavailable),
            subtitle: Text('${accounts.error}'),
          ),
        for (final account in orderedAccounts.where((a) => !a.isSubscription))
          _account(account, orderedAccounts),
        if (subscriptions.isNotEmpty || subscriptionsState.isLoading) ...[
          ListTile(title: Text(context.l10n.subscriptions)),
          if (subscriptionsState.isLoading) const LinearProgressIndicator(),
          for (final source in subscriptions)
            _calendarSource(
              source,
              SidebarOrderSection.subscriptions,
              subscriptions.map((s) => s.id).toList(),
            ),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(context.l10n.settings),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const AndroidSettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _account(AccountEntity account, List<AccountEntity> accounts) {
    final settings = ref.watch(appSettingsControllerProvider);
    final sourcesState = ref.watch(sidebarCalendarSourcesProvider(account.id));
    final listsState = ref.watch(sidebarTaskListsProvider(account.id));
    final sources = settings.sidebarOrder.apply(
      SidebarOrderSection.calendars,
      calendarSourcesShownInSidebar(
        sourcesState.valueOrNull ?? const <CalendarSourceEntity>[],
        accountId: account.id,
      ),
      (s) => s.id,
      accountId: account.id,
    );
    final lists = settings.sidebarOrder.apply(
      SidebarOrderSection.taskLists,
      listsState.valueOrNull ?? const <TaskListEntity>[],
      (l) => l.id,
      accountId: account.id,
    );
    return ExpansionTile(
      initiallyExpanded: true,
      maintainState: true,
      tilePadding: const EdgeInsetsDirectional.only(start: 8),
      title: Text(account.displayLabel),
      subtitle: Text(account.selectorLabel),
      trailing: PopupMenuButton<String>(
        tooltip: context.l10n.options,
        onSelected: (action) async {
          if (action == 'settings') {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    AndroidSettingsScreen(notificationAccountId: account.id),
              ),
            );
          } else {
            await ref
                .read(appSettingsControllerProvider.notifier)
                .moveSidebarItem(
                  SidebarOrderSection.accounts,
                  account.id,
                  action == 'up' ? -1 : 1,
                  accounts.map((a) => a.id),
                );
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'settings', child: Text(context.l10n.accounts)),
          PopupMenuItem(value: 'up', child: Text(context.l10n.moveUp)),
          PopupMenuItem(value: 'down', child: Text(context.l10n.moveDown)),
        ],
      ),
      children: [
        if (sourcesState.isLoading || listsState.isLoading)
          const LinearProgressIndicator(),
        if (sourcesState.hasError || listsState.hasError)
          ListTile(
            title: Text(context.l10n.scheduleUnavailable),
            subtitle: Text('${sourcesState.error ?? listsState.error}'),
          ),
        for (final source in sources)
          _calendarSource(
            source,
            SidebarOrderSection.calendars,
            sources.map((s) => s.id).toList(),
            accountId: account.id,
          ),
        for (final list in lists)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(
              value: settings.isTaskListVisibleInSchedule(
                list.accountId,
                list.id,
              ),
              semanticLabel: '${context.l10n.scheduleSection}: ${list.title}',
              onChanged: (v) => ref
                  .read(appSettingsControllerProvider.notifier)
                  .setTaskListVisibleInSchedule(
                    accountId: list.accountId,
                    taskListId: list.id,
                    visible: v == true,
                  ),
            ),
            title: Text(list.title),
            onTap: () => widget.onBrowseTasks(list),
            trailing: _orderMenu(
              SidebarOrderSection.taskLists,
              list.id,
              lists.map((l) => l.id).toList(),
              account.id,
              () => showAndroidTaskListActions(context, ref, list, accounts),
            ),
          ),
      ],
    );
  }

  Widget _calendarSource(
    CalendarSourceEntity source,
    SidebarOrderSection section,
    List<String> siblings, {
    String? accountId,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(
      value: source.selected,
      semanticLabel: '${context.l10n.scheduleSection}: ${source.summary}',
      onChanged: (v) => ref
          .read(calendarRepositoryProvider)
          .setSourceSelected(source.id, v == true),
    ),
    title: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsetsDirectional.only(end: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _androidSourceColor(source.backgroundColor),
          ),
        ),
        Expanded(child: Text(source.summary)),
      ],
    ),
    onTap: () => showAndroidCalendarSourceActions(context, ref, source),
    trailing: _orderMenu(
      section,
      source.id,
      siblings,
      accountId,
      () => showAndroidCalendarSourceActions(context, ref, source),
    ),
  );

  Widget _orderMenu(
    SidebarOrderSection section,
    String id,
    List<String> siblings,
    String? accountId,
    VoidCallback actions,
  ) => PopupMenuButton<String>(
    tooltip: context.l10n.options,
    onSelected: (value) {
      if (value == 'actions') {
        actions();
        return;
      }
      unawaited(
        ref
            .read(appSettingsControllerProvider.notifier)
            .moveSidebarItem(
              section,
              id,
              value == 'up' ? -1 : 1,
              siblings,
              accountId: accountId,
            ),
      );
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'actions', child: Text(context.l10n.options)),
      PopupMenuItem(
        value: 'up',
        enabled: siblings.indexOf(id) > 0,
        child: Text(context.l10n.moveUp),
      ),
      PopupMenuItem(
        value: 'down',
        enabled: siblings.indexOf(id) < siblings.length - 1,
        child: Text(context.l10n.moveDown),
      ),
    ],
  );
}

Color _androidSourceColor(String? hex) => Color(
  0xff000000 |
      (int.tryParse((hex ?? '6d28d9').replaceFirst('#', ''), radix: 16) ??
          0x6d28d9),
);

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.anchor,
    required this.mode,
    required this.items,
    required this.onSelectDate,
    required this.onModeChanged,
    required this.onOpen,
    required this.onToggleTask,
    required this.onCreate,
    required this.onToggleChecklist,
    required this.dayStartMinute,
    required this.dayEndMinute,
    required this.onReschedule,
    this.taskMutationIntent,
    this.taskMutationsInFlight = const {},
    this.onTaskMutationConsumed,
    this.agendaEmptyBuilder,
    this.agendaPage,
    this.onLoadMore,
    this.onLoadMoreOverdue,
    this.onLoadMoreNoDate,
  });
  final DateTime anchor;
  final ScheduleViewMode mode;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final void Function(DateTime start, DateTime? end) onCreate;
  final void Function(TaskScheduleItem, TaskChecklistItemEntity)
  onToggleChecklist;
  final int dayStartMinute, dayEndMinute;
  final ValueChanged<ScheduleRescheduleRequest> onReschedule;
  final TaskListMutationIntent? taskMutationIntent;
  final Set<String> taskMutationsInFlight;
  final ValueChanged<TaskListMutationIntent>? onTaskMutationConsumed;
  final WidgetBuilder? agendaEmptyBuilder;
  final ScheduleAgendaPage? agendaPage;
  final VoidCallback? onLoadMore, onLoadMoreOverdue, onLoadMoreNoDate;

  @override
  Widget build(BuildContext context) => BusyMaxKeyedCrossfade(
    transitionKey: mode,
    child: switch (mode) {
      ScheduleViewMode.month => _MonthView(
        anchor: anchor,
        items: items,
        onSelectDate: onSelectDate,
        onOpen: onOpen,
        onToggleTask: onToggleTask,
        onCreate: onCreate,
        onReschedule: onReschedule,
        taskMutationsInFlight: taskMutationsInFlight,
      ),
      ScheduleViewMode.year => _YearView(
        anchor: anchor,
        items: items,
        onSelectDate: onSelectDate,
        onModeChanged: onModeChanged,
        onCreate: onCreate,
      ),
      ScheduleViewMode.week || ScheduleViewMode.day => _AndroidTimeGrid(
        key: ValueKey('android-${mode.name}-time-grid'),
        anchor: anchor,
        days: mode == ScheduleViewMode.day ? 1 : 7,
        firstWeekday: _firstWeekday(context),
        items: items,
        onOpen: onOpen,
        onToggleTask: onToggleTask,
        onCreate: onCreate,
        dayStartMinute: dayStartMinute,
        dayEndMinute: dayEndMinute,
        onReschedule: onReschedule,
      ),
      ScheduleViewMode.agenda => _AgendaList(
        key: const PageStorageKey('android-agenda'),
        items: items,
        onOpen: onOpen,
        onToggleTask: onToggleTask,
        onToggleChecklist: onToggleChecklist,
        taskMutationIntent: taskMutationIntent,
        taskMutationsInFlight: taskMutationsInFlight,
        onTaskMutationConsumed: onTaskMutationConsumed,
        emptyBuilder: agendaEmptyBuilder,
        onLoadMore: onLoadMore,
        onLoadMoreOverdue: onLoadMoreOverdue,
        onLoadMoreNoDate: onLoadMoreNoDate,
        hasMoreOverdue: agendaPage?.hasMoreOverdueTasks ?? false,
        hasMoreNoDate: agendaPage?.hasMoreNoDateTasks ?? false,
      ),
    },
  );
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    super.key,
    this.searchCriteria,
    this.searchQuery = '',
    required this.items,
    required this.onOpen,
    required this.onToggleTask,
    this.taskMutationIntent,
    this.taskMutationsInFlight = const {},
    this.onTaskMutationConsumed,
    this.emptyBuilder,
    this.onToggleChecklist,
    this.onLoadMore,
    this.onLoadMoreOverdue,
    this.onLoadMoreNoDate,
    this.hasMoreOverdue = false,
    this.hasMoreNoDate = false,
  });
  final void Function(TaskScheduleItem, TaskChecklistItemEntity)?
  onToggleChecklist;
  final VoidCallback? onLoadMore, onLoadMoreOverdue, onLoadMoreNoDate;
  final bool hasMoreOverdue, hasMoreNoDate;
  final ScheduleSearchCriteria? searchCriteria;
  final String searchQuery;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final TaskListMutationIntent? taskMutationIntent;
  final Set<String> taskMutationsInFlight;
  final ValueChanged<TaskListMutationIntent>? onTaskMutationConsumed;
  final WidgetBuilder? emptyBuilder;
  @override
  Widget build(BuildContext context) {
    final today = ScheduleProjection.day(DateTime.now());
    String group(ScheduleItem item) {
      if (item.start == null) return context.l10n.noDate;
      if (searchCriteria == null &&
          item is TaskScheduleItem &&
          item.actionable &&
          item.due != null &&
          item.due!.isBefore(today)) {
        return context.l10n.overdue;
      }
      final date = searchCriteria == null
          ? item.start
          : scheduleSearchResultDisplayDate(item);
      return date == null
          ? context.l10n.noDate
          : DateFormat.yMMMMEEEEd().format(date);
    }

    final ordered = List<ScheduleItem>.of(items)
      ..sort(compareScheduleSearchResultPresentation);
    if (searchCriteria == null) {
      int bucket(ScheduleItem item) => group(item) == context.l10n.overdue
          ? 0
          : item.start == null
          ? 1
          : 2;
      ordered.sort((a, b) {
        final order = bucket(a).compareTo(bucket(b));
        return order != 0
            ? order
            : compareScheduleSearchResultPresentation(a, b);
      });
    }
    final agendaItems = ScheduleProjection.arrangeHierarchy(ordered);
    final labels = <String, String>{};
    final depths = <String, int>{};
    String identity(ScheduleItem item) =>
        '${item.accountId}\u0000${item.sourceId}\u0000${item.id}';
    for (final item in agendaItems) {
      final parentKey = item is TaskScheduleItem && item.parentId != null
          ? '${item.accountId}\u0000${item.sourceId}\u0000${item.parentId}'
          : null;
      labels[identity(item)] = labels[parentKey] ?? group(item);
      depths[identity(item)] = parentKey == null
          ? 0
          : (depths[parentKey] ?? 0) + 1;
    }
    return Column(
      children: [
        Expanded(
          child: BusyMaxMutationList<ScheduleItem>(
            items: agendaItems,
            footer: Column(
              children: [
                if (hasMoreOverdue)
                  TextButton(
                    onPressed: onLoadMoreOverdue,
                    child: Text(context.l10n.agendaLoadMoreOverdue),
                  ),
                if (hasMoreNoDate)
                  TextButton(
                    onPressed: onLoadMoreNoDate,
                    child: Text(context.l10n.agendaLoadMoreNoDate),
                  ),
                if (onLoadMore != null)
                  TextButton(
                    onPressed: onLoadMore,
                    child: Text(context.l10n.agendaLoadMoreDays),
                  ),
              ],
            ),
            mutation: taskMutationIntent,
            identityOf: (item) => item is TaskScheduleItem
                ? '${item.accountId}\u0000${item.sourceId}\u0000${item.id}'
                : 'event\u0000${item.accountId}\u0000${item.sourceId}\u0000${item.id}',
            mutationApplied: (item, mutation) =>
                item is! TaskScheduleItem ||
                mutation.completionSettled(
                  currentCompleted: item.completed,
                  currentOccurrenceKey: item.occurrenceKey,
                ),
            onMutationConsumed: onTaskMutationConsumed,
            emptyBuilder:
                emptyBuilder ??
                (context) => Center(child: Text(context.l10n.noEventsOrTasks)),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, item, index) {
              final displayedCompleted = item is TaskScheduleItem
                  ? _displayedCompletion(item)
                  : false;
              final displayDate = searchCriteria == null
                  ? item.start
                  : scheduleSearchResultDisplayDate(item);
              final time = item.start == null
                  ? context.l10n.noDate
                  : item.allDay
                  ? context.l10n.allDay
                  : BusyMaxTimeFormatScope.of(context).format(item.start!);
              final isToday =
                  displayDate != null && _sameDay(displayDate, DateTime.now());
              final section = labels[identity(item)] ?? group(item);
              final previous = index > 0 && index <= agendaItems.length
                  ? agendaItems[index - 1]
                  : null;
              final showHeader =
                  previous == null ||
                  section != (labels[identity(previous)] ?? group(previous));
              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          '${isToday && section != context.l10n.overdue ? '${context.l10n.today} · ' : ''}$section',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: (depths[identity(item)] ?? 0).clamp(0, 5) * 16.0,
                      ),
                      child: ListTile(
                        minVerticalPadding: 12,
                        leading: item is TaskScheduleItem
                            ? IconButton(
                                tooltip:
                                    '${displayedCompleted ? context.l10n.taskStatusCompleted : context.l10n.openStatus}: ${item.title}',
                                onPressed:
                                    item.capabilities.canEdit &&
                                        !taskMutationsInFlight.contains(
                                          '${item.accountId}\u0000${item.sourceId}\u0000${item.id}',
                                        )
                                    ? () => onToggleTask(item)
                                    : null,
                                icon: AndroidTaskCompletionIcon(
                                  completed: displayedCompleted,
                                  animate: _animatesTaskCompletion(item),
                                ),
                              )
                            : const Icon(Icons.event),
                        title: item is TaskScheduleItem
                            ? AndroidTaskTitle(
                                title: item.title,
                                completed: displayedCompleted,
                                animate: _animatesTaskCompletion(item),
                              )
                            : Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        subtitle: Text(
                          searchCriteria != null
                              ? scheduleSearchResultText(
                                  context,
                                  item,
                                  searchCriteria!,
                                  searchQuery,
                                )
                              : '${item is TaskScheduleItem && item.parentId != null ? '${item.parentTitle ?? context.l10n.tasks} · ' : ''}$time · ${item.sourceName ?? item.provider.displayName} · ${item.accountEmail ?? item.accountDisplayName ?? item.provider.displayName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onOpen(item),
                      ),
                    ),
                    if (item is TaskScheduleItem)
                      for (final step in item.checklistItems)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start:
                                32 +
                                (depths[identity(item)] ?? 0).clamp(0, 5) *
                                    16.0,
                          ),
                          child: CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              step.title,
                              style: TextStyle(
                                decoration: step.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            value: step.completed,
                            onChanged:
                                item.capabilities.canEdit &&
                                    onToggleChecklist != null
                                ? (_) => onToggleChecklist!(item, step)
                                : null,
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _animatesTaskCompletion(TaskScheduleItem task) {
    final intent = taskMutationIntent;
    return intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent!.completionAppliesTo(task.occurrenceKey) &&
        intent.completed != null;
  }

  bool _displayedCompletion(TaskScheduleItem task) {
    final intent = taskMutationIntent;
    if (intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent!.completionAppliesTo(task.occurrenceKey) &&
        intent.completed != null) {
      return intent.completed!;
    }
    return task.completed;
  }
}

class _AndroidTimeGrid extends StatefulWidget {
  const _AndroidTimeGrid({
    super.key,
    required this.anchor,
    required this.days,
    required this.firstWeekday,
    required this.items,
    required this.onOpen,
    required this.onToggleTask,
    required this.onCreate,
    required this.onReschedule,
    required this.dayStartMinute,
    required this.dayEndMinute,
  });
  final DateTime anchor;
  final int days, firstWeekday, dayStartMinute, dayEndMinute;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final void Function(DateTime, DateTime?) onCreate;
  final ValueChanged<ScheduleRescheduleRequest> onReschedule;
  @override
  State<_AndroidTimeGrid> createState() => _AndroidTimeGridState();
}

class _AndroidTimeGridState extends State<_AndroidTimeGrid> {
  late final ScrollController _vertical = ScrollController(
    initialScrollOffset: widget.dayStartMinute * .9,
  );
  double _zoom = .9;
  @override
  void didUpdateWidget(covariant _AndroidTimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayStartMinute != widget.dayStartMinute &&
        _vertical.hasClients) {
      _vertical.jumpTo(
        (widget.dayStartMinute * _zoom).clamp(
          0,
          _vertical.position.maxScrollExtent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rulerStyle = Theme.of(context).textTheme.labelSmall;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    var rulerWidth = 56.0;
    for (var hour = 0; hour < 24; hour++) {
      painter.text = TextSpan(
        text: BusyMaxTimeFormatScope.of(context)
            .format(DateTime(2026, 1, 1, hour)),
        style: rulerStyle,
      );
      painter.layout();
      if (painter.width + 12 > rulerWidth) rulerWidth = painter.width + 12;
    }
    painter.dispose();
    final start = widget.days == 1
        ? ScheduleProjection.day(widget.anchor)
        : ScheduleRange.week(
            widget.anchor,
            firstWeekday: widget.firstWeekday,
          ).start;
    final dates = [
      for (var i = 0; i < widget.days; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.zoom_out, size: 20),
              Expanded(
                child: Slider(
                  value: _zoom,
                  min: .5,
                  max: 2,
                  divisions: 15,
                  semanticFormatterCallback: (value) =>
                      '${(value / .9 * 100).round()}%',
                  label: '${(_zoom / .9 * 100).round()}%',
                  onChanged: (value) {
                    final minute = _vertical.hasClients
                        ? _vertical.offset / _zoom
                        : widget.dayStartMinute.toDouble();
                    setState(() => _zoom = value);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _vertical.hasClients) {
                        _vertical.jumpTo(
                          (minute * value).clamp(
                            0,
                            _vertical.position.maxScrollExtent,
                          ),
                        );
                      }
                    });
                  },
                ),
              ),
              const Icon(Icons.zoom_in, size: 20),
              const SizedBox(width: 12),
              if (widget.items.any((item) => item.allDay))
                IconButton(
                  tooltip: context.l10n.allDay,
                  icon: const Icon(Icons.calendar_view_day_outlined),
                  onPressed: () => _showAndroidDayItems(
                    context,
                    widget.items.where((item) => item.allDay).toList(),
                    widget.onOpen,
                    widget.onToggleTask,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final widths = <double>[];
              for (final day in dates) {
                final placements = _timedPlacements(
                  ScheduleProjection.itemsForDay(
                    widget.items,
                    day,
                  ).where((i) => !i.allDay).toList(),
                  day,
                  minimumMinutes: (52 * scale / _zoom).ceil(),
                );
                final lanes = placements.fold<int>(
                  1,
                  (n, p) => p.lane + 1 > n ? p.lane + 1 : n,
                );
                final natural = widget.days == 1
                    ? constraints.maxWidth - rulerWidth
                    : (constraints.maxWidth - rulerWidth) / 7;
                widths.add(
                  natural.clamp(
                    (120 * scale).clamp(120.0, 200.0) * lanes,
                    double.infinity,
                  ),
                );
              }
              final hasAllDay = widget.items.any((i) => i.allDay);
              final allDayHeight = hasAllDay
                  ? (52.0 * scale + 48)
                        .clamp(
                          0.0,
                          (constraints.maxHeight - 72).clamp(0.0, 180.0),
                        )
                        .toDouble()
                  : 0.0;
              return SingleChildScrollView(
                key: PageStorageKey('android-time-horizontal-${widget.days}'),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: rulerWidth + widths.fold<double>(0, (a, b) => a + b),
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(width: rulerWidth),
                            for (var i = 0; i < dates.length; i++)
                              SizedBox(
                                width: widths[i],
                                child: Semantics(
                                  label: DateFormat.yMMMMEEEEd().format(
                                    dates[i],
                                  ),
                                  child: TextButton(
                                    onPressed: () =>
                                        widget.onCreate(dates[i], null),
                                    onLongPress: () =>
                                        widget.onCreate(dates[i], null),
                                    child: Text(
                                      DateFormat.E().add_d().format(dates[i]),
                                      style: TextStyle(
                                        color:
                                            _sameDay(dates[i], DateTime.now())
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasAllDay)
                        SizedBox(
                          height: allDayHeight.toDouble(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: rulerWidth,
                                child: Center(
                                  child: Text(
                                    context.l10n.allDay,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ),
                              ),
                              for (var i = 0; i < dates.length; i++)
                                SizedBox(
                                  width: widths[i],
                                  child: _AndroidAllDayCell(
                                    items: ScheduleProjection.itemsForDay(
                                      widget.items,
                                      dates[i],
                                    ).where((i) => i.allDay).toList(),
                                    onOpen: widget.onOpen,
                                    onToggleTask: widget.onToggleTask,
                                    onReschedule: widget.onReschedule,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _vertical,
                          child: SizedBox(
                            height: 1440 * _zoom,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: rulerWidth,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (var hour = 0; hour < 24; hour++)
                                        PositionedDirectional(
                                          top: hour * 60 * _zoom,
                                          end: 4,
                                          child: Text(
                                            BusyMaxTimeFormatScope.of(context)
                                                .format(
                                                  DateTime(2026, 1, 1, hour),
                                                ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                for (var i = 0; i < dates.length; i++)
                                  SizedBox(
                                    width: widths[i],
                                    child: _AndroidTimedDayColumn(
                                      day: dates[i],
                                      items: ScheduleProjection.itemsForDay(
                                        widget.items,
                                        dates[i],
                                      ).where((i) => !i.allDay).toList(),
                                      minuteHeight: _zoom,
                                      onOpen: widget.onOpen,
                                      onToggleTask: widget.onToggleTask,
                                      onCreate: widget.onCreate,
                                      onReschedule: widget.onReschedule,
                                      dayStartMinute: widget.dayStartMinute,
                                      dayEndMinute: widget.dayEndMinute,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AndroidAllDayCell extends StatelessWidget {
  const _AndroidAllDayCell({
    required this.items,
    required this.onOpen,
    required this.onToggleTask,
    required this.onReschedule,
  });
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final ValueChanged<ScheduleRescheduleRequest> onReschedule;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      border: BorderDirectional(
        start: BorderSide(color: Theme.of(context).dividerColor, width: .5),
      ),
    ),
    child: items.isEmpty
        ? null
        : SingleChildScrollView(
            primary: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AndroidCalendarChip(
                  item: items.first,
                  onOpen: onOpen,
                  onToggleTask: onToggleTask,
                  onReschedule: onReschedule,
                ),
                if (items.length > 1)
                  TextButton(
                    onPressed: () => _showAndroidDayItems(
                      context,
                      items,
                      onOpen,
                      onToggleTask,
                    ),
                    child: Text(context.l10n.moreItems(items.length - 1)),
                  ),
              ],
            ),
          ),
  );
}

class _AndroidTimedDayColumn extends StatefulWidget {
  const _AndroidTimedDayColumn({
    required this.day,
    required this.items,
    required this.minuteHeight,
    required this.onOpen,
    required this.onToggleTask,
    required this.onCreate,
    required this.onReschedule,
    required this.dayStartMinute,
    required this.dayEndMinute,
  });
  final DateTime day;
  final List<ScheduleItem> items;
  final double minuteHeight;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final void Function(DateTime, DateTime?) onCreate;
  final ValueChanged<ScheduleRescheduleRequest> onReschedule;
  final int dayStartMinute, dayEndMinute;
  @override
  State<_AndroidTimedDayColumn> createState() => _AndroidTimedDayColumnState();
}

class _AndroidTimedDayColumnState extends State<_AndroidTimedDayColumn> {
  int? _selectionStart, _selectionEnd;
  int minute(double y) =>
      ((y / widget.minuteHeight / 15).floor() * 15).clamp(0, 1425);
  @override
  Widget build(BuildContext context) {
    final minimumHeight =
        52 * (MediaQuery.textScalerOf(context).scale(14) / 14);
    final placements = _timedPlacements(
      widget.items,
      widget.day,
      minimumMinutes: (minimumHeight / widget.minuteHeight).ceil(),
    );
    final lanes = placements.fold<int>(
      1,
      (n, p) => p.lane + 1 > n ? p.lane + 1 : n,
    );
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        label:
            '${context.l10n.create}: ${context.l10n.createEventAtTime}: ${DateFormat.yMMMMEEEEd().format(widget.day)}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (d) => setState(
            () => _selectionStart = _selectionEnd = minute(d.localPosition.dy),
          ),
          onLongPressMoveUpdate: (d) =>
              setState(() => _selectionEnd = minute(d.localPosition.dy)),
          onLongPressCancel: () => setState(() {
            _selectionStart = _selectionEnd = null;
          }),
          onLongPressEnd: (_) {
            final a = _selectionStart, b = _selectionEnd;
            setState(() {
              _selectionStart = _selectionEnd = null;
            });
            if (a == null || b == null) return;
            final lo = a < b ? a : b, hi = (a > b ? a : b) + 15;
            widget.onCreate(
              DateTime(
                widget.day.year,
                widget.day.month,
                widget.day.day,
                0,
                lo,
              ),
              DateTime(
                widget.day.year,
                widget.day.month,
                widget.day.day,
                0,
                hi,
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: .5,
                ),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: 0,
                  height: widget.dayStartMinute * widget.minuteHeight,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: .55,
                    ),
                  ),
                ),
                Positioned(
                  top: widget.dayEndMinute * widget.minuteHeight,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: .55,
                    ),
                  ),
                ),
                for (var hour = 0; hour < 24; hour++)
                  Positioned(
                    top: hour * 60 * widget.minuteHeight,
                    left: 0,
                    right: 0,
                    child: Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: .55),
                    ),
                  ),
                for (final p in placements)
                  PositionedDirectional(
                    top: (p.startMinute * widget.minuteHeight + 1).clamp(
                      0.0,
                      (1440 * widget.minuteHeight - minimumHeight).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    start: p.lane * constraints.maxWidth / lanes + 2,
                    width: constraints.maxWidth / lanes - 4,
                    height:
                        ((p.endMinute - p.startMinute) * widget.minuteHeight)
                            .clamp(minimumHeight, 1440 * widget.minuteHeight),
                    child: _AndroidCalendarChip(
                      item: p.item,
                      onOpen: widget.onOpen,
                      onToggleTask: widget.onToggleTask,
                      onReschedule: widget.onReschedule,
                      showTime: true,
                    ),
                  ),
                if (_selectionStart != null && _selectionEnd != null)
                  Positioned(
                    top:
                        (_selectionStart! < _selectionEnd!
                            ? _selectionStart!
                            : _selectionEnd!) *
                        widget.minuteHeight,
                    height:
                        ((_selectionEnd! - _selectionStart!).abs() + 15) *
                        widget.minuteHeight,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: scheme.primary.withValues(alpha: .25),
                      ),
                    ),
                  ),
                if (_sameDay(widget.day, DateTime.now()))
                  Positioned(
                    top:
                        (DateTime.now().hour * 60 + DateTime.now().minute) *
                        widget.minuteHeight,
                    left: 0,
                    right: 0,
                    child: Divider(
                      height: 2,
                      thickness: 2,
                      color: scheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AndroidCalendarChip extends StatelessWidget {
  const _AndroidCalendarChip({
    required this.item,
    required this.onOpen,
    required this.onToggleTask,
    this.onReschedule,
    this.showTime = false,
  });
  final ScheduleItem item;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final ValueChanged<ScheduleRescheduleRequest>? onReschedule;
  final bool showTime;
  @override
  Widget build(BuildContext context) {
    final color = ScheduleProjection.colorForItem(
      item,
      Theme.of(context).brightness,
    );
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    return Semantics(
      label: '${item.title}, ${item.sourceName ?? item.provider.displayName}',
      child: Material(
        color: color.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: () => onOpen(item),
          onLongPress:
              item is CalendarScheduleItem &&
                  (item as CalendarScheduleItem).canReschedule &&
                  onReschedule != null
              ? () => showAndroidEventTimingActions(
                  context,
                  item as CalendarScheduleItem,
                  onReschedule!,
                )
              : () => onOpen(item),
          child: Container(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: color, width: 3),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task != null)
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip:
                          '${task.completed ? context.l10n.taskStatusCompleted : context.l10n.taskStatusInProcess}: ${task.title}',
                      onPressed: task.capabilities.canEdit
                          ? () => onToggleTask(task)
                          : null,
                      iconSize: 20,
                      icon: Icon(
                        task.completed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${task?.parentId != null ? '↳ ' : ''}${showTime && item.start != null ? '${BusyMaxTimeFormatScope.of(context).format(item.start!)} ' : ''}${item.title}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      decoration: task?.completed == true
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAndroidDayItems(
  BuildContext context,
  List<ScheduleItem> items,
  ValueChanged<ScheduleItem> onOpen,
  ValueChanged<TaskScheduleItem> onToggleTask,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          for (final item in items)
            ListTile(
              leading: item is TaskScheduleItem
                  ? IconButton(
                      tooltip:
                          '${context.l10n.taskStatusCompleted}: ${item.title}',
                      icon: Icon(
                        item.completed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                      onPressed: item.capabilities.canEdit
                          ? () => onToggleTask(item)
                          : null,
                    )
                  : const Icon(Icons.event),
              title: Text(item.title),
              subtitle: Text(
                '${item.sourceName ?? item.provider.displayName} · ${item.accountEmail ?? item.accountDisplayName ?? item.accountId}',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onOpen(item);
              },
            ),
        ],
      ),
    ),
  ),
);

final class _AndroidTimedPlacement {
  const _AndroidTimedPlacement({
    required this.item,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
  });

  final ScheduleItem item;
  final int startMinute;
  final int endMinute;
  final int lane;
}

List<_AndroidTimedPlacement> _timedPlacements(
  List<ScheduleItem> items,
  DateTime day, {
  int minimumMinutes = 0,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final candidates = <({ScheduleItem item, int start, int end})>[];
  for (final item in items) {
    final rawStart = item.start;
    if (rawStart == null) continue;
    final rawEnd = item.end != null && item.end!.isAfter(rawStart)
        ? item.end!
        : rawStart.add(const Duration(minutes: 30));
    final start = rawStart.isAfter(dayStart) ? rawStart : dayStart;
    final end = rawEnd.isBefore(dayEnd) ? rawEnd : dayEnd;
    if (!end.isAfter(start)) continue;
    final startMinute = start == dayStart ? 0 : start.hour * 60 + start.minute;
    final endMinute = end == dayEnd ? 24 * 60 : end.hour * 60 + end.minute;
    candidates.add((item: item, start: startMinute, end: endMinute));
  }
  candidates.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  });
  final laneEnds = <int>[];
  final result = <_AndroidTimedPlacement>[];
  for (final candidate in candidates) {
    final visibleEnd = candidate.end > candidate.start + minimumMinutes
        ? candidate.end
        : candidate.start + minimumMinutes;
    var lane = laneEnds.indexWhere((end) => end <= candidate.start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(visibleEnd);
    } else {
      laneEnds[lane] = visibleEnd;
    }
    result.add(
      _AndroidTimedPlacement(
        item: candidate.item,
        startMinute: candidate.start,
        endMinute: candidate.end,
        lane: lane,
      ),
    );
  }
  return result;
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.anchor,
    required this.items,
    required this.onSelectDate,
    required this.onOpen,
    required this.onToggleTask,
    required this.onCreate,
    required this.onReschedule,
    this.taskMutationsInFlight = const {},
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final void Function(DateTime, DateTime?) onCreate;
  final ValueChanged<ScheduleRescheduleRequest> onReschedule;
  final Set<String> taskMutationsInFlight;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final width = constraints.maxWidth.clamp(
        7 * 96.0 * scale.clamp(1, 1.5),
        double.infinity,
      );
      final height = (48 + 6 * (48 + 3 * 48 * scale)).clamp(
        constraints.maxHeight,
        double.infinity,
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            key: const PageStorageKey('android-month-scroll'),
            child: SizedBox(
              height: height,
              child: _AndroidMonthGrid(
                key: const ValueKey('android-month-grid'),
                displayedMonth: DateTime(anchor.year, anchor.month),
                selectedDate: anchor,
                items: items,
                onDaySelected: onSelectDate,
                onOpen: onOpen,
                onToggleTask: onToggleTask,
                onCreate: onCreate,
                onReschedule: onReschedule,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.items,
    required this.onSelectDate,
    required this.onModeChanged,
    required this.onCreate,
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  final void Function(DateTime, DateTime?) onCreate;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (constraints.maxWidth / (370 * scale.clamp(1, 1.4)))
          .floor()
          .clamp(1, 4);
      return GridView.builder(
        key: const ValueKey('android-year-grid'),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 64 + 7 * 48 * scale,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final month = DateTime(anchor.year, index + 1);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () {
                    onSelectDate(month);
                    onModeChanged(ScheduleViewMode.month);
                  },
                  child: Text(DateFormat.MMMM().format(month)),
                ),
                Expanded(
                  child: _AndroidMonthGrid(
                    displayedMonth: month,
                    selectedDate: anchor,
                    items: items,
                    onDaySelected: (day) {
                      onSelectDate(day);
                      onModeChanged(ScheduleViewMode.day);
                    },
                    onWeekSelected: (day) {
                      onSelectDate(day);
                      onModeChanged(ScheduleViewMode.week);
                    },
                    onCreate: onCreate,
                    compact: true,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _AndroidMonthGrid extends StatelessWidget {
  const _AndroidMonthGrid({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.items,
    required this.onDaySelected,
    this.compact = false,
    this.onWeekSelected,
    this.onOpen,
    this.onToggleTask,
    this.onCreate,
    this.onReschedule,
  });
  final DateTime displayedMonth, selectedDate;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onWeekSelected;
  final bool compact;
  final ValueChanged<ScheduleItem>? onOpen;
  final ValueChanged<TaskScheduleItem>? onToggleTask;
  final void Function(DateTime, DateTime?)? onCreate;
  final ValueChanged<ScheduleRescheduleRequest>? onReschedule;
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final minimumWidth = 48 + 7 * 48 * scale;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth.clamp(minimumWidth, double.infinity),
              height: constraints.maxHeight,
              child: _buildGrid(context),
            ),
          );
        },
      );
    }
    return _buildGrid(context);
  }

  Widget _buildGrid(BuildContext context) {
    final firstWeekday = _firstWeekday(context);
    final range = androidMonthGridRange(
      displayedMonth,
      firstWeekday: firstWeekday,
    );
    final days = [
      for (var i = 0; i < 42; i++)
        DateTime(range.start.year, range.start.month, range.start.day + i),
    ];
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              if (onWeekSelected != null) const SizedBox(width: 48),
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E().format(
                        DateTime(2026, 1, 5 + (firstWeekday + i - 1) % 7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var row = 0; row < 6; row++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onWeekSelected != null)
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      tooltip:
                          '${context.l10n.viewWeek}: ${DateFormat.yMMMd().format(days[row * 7])}',
                      icon: const Icon(Icons.view_week_outlined, size: 18),
                      onPressed: () => onWeekSelected!(days[row * 7]),
                    ),
                  ),
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _AndroidMonthDay(
                      day: days[row * 7 + col],
                      displayedMonth: displayedMonth,
                      selectedDate: selectedDate,
                      items: items,
                      compact: compact,
                      onSelected: onDaySelected,
                      onOpen: onOpen,
                      onToggleTask: onToggleTask,
                      onCreate: onCreate,
                      onReschedule: onReschedule,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AndroidMonthDay extends StatelessWidget {
  const _AndroidMonthDay({
    required this.day,
    required this.displayedMonth,
    required this.selectedDate,
    required this.items,
    required this.compact,
    required this.onSelected,
    this.onOpen,
    this.onToggleTask,
    this.onCreate,
    this.onReschedule,
  });
  final DateTime day, displayedMonth, selectedDate;
  final List<ScheduleItem> items;
  final bool compact;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<ScheduleItem>? onOpen;
  final ValueChanged<TaskScheduleItem>? onToggleTask;
  final void Function(DateTime, DateTime?)? onCreate;
  final ValueChanged<ScheduleRescheduleRequest>? onReschedule;
  @override
  Widget build(BuildContext context) {
    final matching = ScheduleProjection.itemsForDay(items, day);
    final selected = _sameDay(day, selectedDate),
        today = _sameDay(day, DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: DateFormat.yMMMMEEEEd().format(day),
      selected: selected,
      child: InkWell(
        onTap: () => onSelected(day),
        onLongPress: onCreate == null ? null : () => onCreate!(day, null),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? scheme.secondaryContainer : null,
            border: Border.all(
              color: today ? scheme.primary : Theme.of(context).dividerColor,
              width: today ? 2 : .35,
            ),
          ),
          child: compact
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: today ? FontWeight.bold : null,
                          color: day.month != displayedMonth.month
                              ? scheme.onSurfaceVariant.withValues(alpha: .5)
                              : null,
                        ),
                      ),
                      if (matching.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final item in matching.take(3))
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ScheduleProjection.colorForItem(
                                    item,
                                    Theme.of(context).brightness,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final rowHeight =
                        MediaQuery.textScalerOf(context).scale(16) + 36;
                    final count =
                        ((constraints.maxHeight -
                                    48 -
                                    (matching.length > 2 ? 48 : 0)) /
                                rowHeight)
                            .floor()
                            .clamp(0, 3);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => onSelected(day),
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontWeight: today
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              if (onCreate != null)
                                IconButton(
                                  tooltip:
                                      '${context.l10n.create}: ${DateFormat.yMMMd().format(day)}',
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => onCreate!(day, null),
                                ),
                            ],
                          ),
                        ),
                        if (onOpen != null && onToggleTask != null)
                          for (final item in matching.take(count))
                            SizedBox(
                              height: rowHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 1,
                                ),
                                child: _AndroidCalendarChip(
                                  item: item,
                                  onOpen: onOpen!,
                                  onToggleTask: onToggleTask!,
                                  onReschedule: onReschedule,
                                ),
                              ),
                            ),
                        if (matching.length > count &&
                            onOpen != null &&
                            onToggleTask != null)
                          TextButton(
                            onPressed: () => _showAndroidDayItems(
                              context,
                              matching,
                              onOpen!,
                              onToggleTask!,
                            ),
                            child: Text(
                              context.l10n.moreItems(matching.length - count),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AndroidEventDescription extends StatelessWidget {
  const _AndroidEventDescription({required this.item});
  final CalendarScheduleItem item;
  @override
  Widget build(BuildContext context) {
    if (item.descriptionHtml == null) {
      return SelectableText(calendarEventDescription(item));
    }
    final document = htmlCalendarDescriptionDocument(item.descriptionHtml!);
    final boundaries = <int>{
      0,
      document.text.length,
      for (final range in document.ranges) ...[range.start, range.end],
    }.toList()..sort();
    return SelectableText.rich(
      TextSpan(
        children: [
          for (var i = 1; i < boundaries.length; i++)
            TextSpan(
              text: document.text.substring(boundaries[i - 1], boundaries[i]),
              style: TextStyle(
                fontWeight:
                    document.ranges.any(
                      (r) =>
                          r.start <= boundaries[i - 1] &&
                          r.end >= boundaries[i] &&
                          r.styles.contains(
                            CalendarDescriptionInlineStyle.bold,
                          ),
                    )
                    ? FontWeight.bold
                    : null,
                fontStyle:
                    document.ranges.any(
                      (r) =>
                          r.start <= boundaries[i - 1] &&
                          r.end >= boundaries[i] &&
                          r.styles.contains(
                            CalendarDescriptionInlineStyle.italic,
                          ),
                    )
                    ? FontStyle.italic
                    : null,
                decoration:
                    document.ranges.any(
                      (r) =>
                          r.start <= boundaries[i - 1] &&
                          r.end >= boundaries[i] &&
                          r.styles.contains(
                            CalendarDescriptionInlineStyle.underline,
                          ),
                    )
                    ? TextDecoration.underline
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class AndroidEventEditor extends ConsumerStatefulWidget {
  const AndroidEventEditor({
    super.key,
    required this.sources,
    required this.draft,
  });
  final List<CalendarSourceEntity> sources;
  final EventEditorDraft draft;
  @override
  ConsumerState<AndroidEventEditor> createState() => _AndroidEventEditorState();
}

class _AndroidEventEditorState extends ConsumerState<AndroidEventEditor> {
  AuthorizationCancellation? _consentCancellation;

  late EventEditorDraft _draft = widget.draft;
  int _descriptionGeneration = 0;
  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _location = TextEditingController(
    text: _draft.location,
  );
  late final TextEditingController _description = TextEditingController(
    text: _draft.editableDescription,
  );
  late final TextEditingController _guests = TextEditingController(
    text: _draft.attendees
        .where((a) => !a.self && !a.organizer)
        .map((a) => a.email)
        .join(', '),
  );
  late final TextEditingController _categories = TextEditingController(
    text: _draft.categories.join(', '),
  );
  final Map<String, bool> _guestOptionalOverrides = {};
  final Map<String, String> _suggestedGuestNames = {};
  List<BusyMaxContactSuggestion> _guestSuggestions = const [];
  int _guestSuggestionGeneration = 0;
  StreamSubscription<void>? _contactsChanges;
  int? _reminderMinutes;
  Object? _editedGoogleReminders;
  List<AndroidNextcloudReminderRow>? _editedNextcloudReminders;
  late RecurrenceRule _recurrenceRule = EventRecurrenceCodec.decode(
    _provider,
    _draft.recurrence,
    baseDate: _draft.start,
  );
  bool _recurrenceChanged = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _recoveryLoaded = false;
  bool _recoveryWritesBlocked = false;
  Future<void> _recoveryIo = Future.value();
  Timer? _recoveryTimer;

  String get _recoveryKey =>
      'busymax.android.event-draft.${widget.draft.accountId}.'
      '${widget.draft.eventId ?? 'new-${widget.draft.sourceId}'}';

  @override
  void initState() {
    super.initState();
    _contactsChanges = ref
        .read(busyMaxContactsControllerProvider)
        .changes
        .listen((_) {
          _guestSuggestionGeneration++;
          if (mounted) setState(() => _guestSuggestions = const []);
        });
    unawaited(_restoreRecovery());
    _recoveryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_persistRecovery()),
    );
  }

  @override
  void dispose() {
    _guestSuggestionGeneration++;
    unawaited(_contactsChanges?.cancel());
    _consentCancellation?.cancel();
    _recoveryTimer?.cancel();
    if (_recoveryLoaded && _hasPendingEdits && !_allowPop) {
      unawaited(_persistRecovery());
    }
    _title.dispose();
    _location.dispose();
    _description.dispose();
    _guests.dispose();
    _categories.dispose();
    super.dispose();
  }

  BusyProvider get _deliveryProvider =>
      [
        BusyProvider.google,
        BusyProvider.microsoft,
        BusyProvider.nextcloud,
      ].contains(_provider)
      ? _provider
      : [
          BusyProvider.google,
          BusyProvider.microsoft,
        ].contains(_originalSource?.provider)
      ? _originalSource!.provider
      : _provider;

  CalendarSourceEntity? get _originalSource =>
      widget.sources.where((s) => s.id == widget.draft.sourceId).firstOrNull;
  bool get _moving =>
      _draft.eventId != null && _draft.sourceId != widget.draft.sourceId;
  bool get _canChangeTiming =>
      _canEdit &&
      (_draft.originalDetail == null ||
          detailAllowsTimingEdit(_draft.originalDetail!));
  CalendarEventMoveStrategy _moveStrategy(EventEditorDraft draft) {
    final source = _originalSource, destination = _source;
    if (source == null || destination == null || draft.eventId == null) {
      return CalendarEventMoveStrategy.none;
    }
    return calendarEventMoveStrategy(
      sourceAccountId: source.accountId,
      sourceId: source.id,
      sourceProviderCalendarId: source.providerCalendarId,
      sourceProvider: source.provider,
      sourceDavCollectionId: source.davCollectionId,
      sourceDavSchedulingPrincipal: source.davSchedulingPrincipal,
      destinationAccountId: destination.accountId,
      destinationId: destination.id,
      destinationProviderCalendarId: destination.providerCalendarId,
      destinationProvider: destination.provider,
      destinationDavCollectionId: destination.davCollectionId,
      destinationDavSchedulingPrincipal: destination.davSchedulingPrincipal,
      eventType: widget.draft.eventType,
      recurring: widget.draft.providerRecurringEventId != null,
      recurringScope: draft.recurringMutationScope,
    );
  }

  void _setStart(DateTime value) {
    setState(() {
      final end = _draft.end;
      _draft = _draft.copyWith(
        start: value,
        end: end == null || !end.isAfter(value)
            ? value.add(
                _draft.allDay
                    ? const Duration(days: 1)
                    : const Duration(hours: 1),
              )
            : end,
      );
      _adjustRecurrenceTiming();
    });
  }

  void _adjustRecurrenceTiming() {
    if (_draft.providerRecurringEventId != null ||
        !_recurrenceRule.isSupported ||
        !_recurrenceRule.repeats) {
      return;
    }
    final until = _recurrenceRule.untilDateFor(timeZone: _draft.startTimeZone);
    if (until != null) {
      _recurrenceRule = _recurrenceRule.withUntilDate(
        until,
        allDay: _draft.allDay,
        floating:
            _provider.isDav &&
            (_draft.startTimeZone == null || _draft.startTimeZone!.isEmpty),
        baseDate: _draft.start!,
        timeZone: _draft.startTimeZone,
      );
    }
    _recurrenceChanged = true;
  }

  void _selectDestination(CalendarSourceEntity source) {
    if (googleStatusEventTypes.contains(_draft.eventType) &&
        (source.provider != BusyProvider.google || !source.primaryCalendar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.googleStatusPrimaryOnly)),
      );
      return;
    }
    if (_provider != source.provider &&
        _recurrenceRule.repeats &&
        !EventRecurrenceCodec.canEncode(source.provider, _recurrenceRule) &&
        _draft.providerRecurringEventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.recurrenceUnsupportedByProvider(
              source.provider.displayName,
            ),
          ),
        ),
      );
      return;
    }
    final changedProvider = _provider != source.provider;
    final minutes = androidEventReminderMinutes(_provider, _draft.reminders);
    setState(() {
      final reminders = !changedProvider
          ? _draft.reminders
          : source.provider == BusyProvider.microsoft
          ? _eventReminders(source.provider, minutes?.firstOrNull ?? -2)
          : {
              'useDefault': false,
              'overrides': [
                for (final minute in minutes ?? <int>[])
                  {'method': 'popup', 'minutes': minute},
              ],
            };
      _draft = _draft.copyWith(
        accountId: source.accountId,
        sourceId: source.id,
        providerCalendarId: source.providerCalendarId,
        clearEventLabelId: _draft.sourceId != source.id,
        eventLabelChanged: _draft.sourceId != source.id,
        reminders: reminders,
        remindersChanged: changedProvider || _draft.remindersChanged,
        clearImportance: source.provider != BusyProvider.microsoft,
        clearColorId: changedProvider,
        clearShowAs: changedProvider,
        clearVisibilityOrSensitivity: changedProvider,
        clearRecurringMutationScope:
            _draft.providerRecurringEventId != null &&
            _draft.sourceId != source.id,
      );
      if (changedProvider) {
        _recurrenceChanged = true;
        _editedGoogleReminders = null;
        _editedNextcloudReminders = null;
        _reminderMinutes = null;
      }
      _guestSuggestionGeneration++;
      _guestSuggestions = const [];
    });
  }

  CalendarSourceEntity? get _source => widget.sources
      .where((source) => source.id == _draft.sourceId)
      .firstOrNull;

  BusyProvider get _provider =>
      _source?.provider ??
      _draft.originalDetail?.provider ??
      BusyProvider.google;

  bool get _canEdit {
    final source = _source;
    if (source == null) return false;
    return _draft.eventId == null || _moving
        ? source.capabilities.canCreateEvents
        : source.capabilities.canEditEvents;
  }

  bool get _canDelete =>
      _draft.eventId != null &&
      (_originalSource?.capabilities.canDeleteEvents ?? false);

  bool get _isNextcloudAttendee =>
      (_originalSource?.provider ?? _provider) == BusyProvider.nextcloud &&
      widget.draft.isOrganizer == false;

  bool get _hasPendingEdits =>
      _draft != widget.draft ||
      _guests.text !=
          widget.draft.attendees
              .where((attendee) => !attendee.self && !attendee.organizer)
              .map((attendee) => attendee.email)
              .join(', ') ||
      _categories.text != widget.draft.categories.join(', ') ||
      _guestOptionalOverrides.isNotEmpty ||
      _reminderMinutes != null ||
      _editedGoogleReminders != null ||
      _editedNextcloudReminders != null ||
      _recurrenceChanged;

  List<EventAttendeeDraft> _currentAttendees() {
    final merged = mergeAndroidEventAttendees(
      widget.draft.attendees,
      _guests.text,
    ).attendees;
    final originalEmails = {
      for (final attendee in widget.draft.attendees)
        attendee.email.toLowerCase(),
    };
    return merged
        .map((attendee) {
          final key = attendee.email.toLowerCase();
          final name = _suggestedGuestNames[key];
          return !originalEmails.contains(key) && name != null
              ? EventAttendeeDraft(email: attendee.email, displayName: name)
              : attendee;
        })
        .toList(growable: false);
  }

  Future<void> _loadGuestSuggestions(String query) async {
    final generation = ++_guestSuggestionGeneration;
    final accountId = _draft.accountId;
    final sourceId = _draft.sourceId;
    final term = query.split(',').last.trim();
    if (term.isEmpty) {
      setState(() => _guestSuggestions = const []);
      return;
    }
    try {
      final suggestions = await ref
          .read(busyMaxContactsControllerProvider)
          .suggestAttendees(
            term,
            busyMaxAccountId: accountId,
            excludedAddresses: {
              for (final attendee in _currentAttendees()) attendee.email,
            },
          );
      if (!mounted ||
          generation != _guestSuggestionGeneration ||
          _draft.accountId != accountId ||
          _draft.sourceId != sourceId ||
          _guests.text.split(',').last.trim() != term) {
        return;
      }
      setState(() => _guestSuggestions = suggestions);
    } on Object {
      if (!mounted ||
          generation != _guestSuggestionGeneration ||
          _draft.accountId != accountId ||
          _draft.sourceId != sourceId ||
          _guests.text.split(',').last.trim() != term) {
        return;
      }
      setState(() => _guestSuggestions = const []);
    }
  }

  Future<void> _selectGuestSuggestion(
    BusyMaxContactSuggestion suggestion,
  ) async {
    if (!_draft.canManageAttendees || !_guestSuggestions.contains(suggestion)) {
      return;
    }
    final generation = _guestSuggestionGeneration;
    final accountId = _draft.accountId;
    final sourceId = _draft.sourceId;
    try {
      if (!await ref
          .read(busyMaxContactsControllerProvider)
          .suggestionEligible(suggestion, busyMaxAccountId: accountId)) {
        return;
      }
    } on Object {
      return;
    }
    if (!mounted ||
        generation != _guestSuggestionGeneration ||
        _draft.accountId != accountId ||
        _draft.sourceId != sourceId ||
        !_draft.canManageAttendees ||
        !_guestSuggestions.contains(suggestion)) {
      return;
    }
    _guestSuggestionGeneration++;
    final emails = _guests.text
        .split(RegExp(r'[,;\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (emails.isNotEmpty && !_androidLooksLikeEmail(emails.last)) {
      emails.removeLast();
    }
    if (!emails.any(
      (email) => email.toLowerCase() == suggestion.email.toLowerCase(),
    )) {
      emails.add(suggestion.email);
    }
    setState(() {
      _guests.text = emails.join(', ');
      if (suggestion.displayName.isNotEmpty) {
        _suggestedGuestNames[suggestion.email.toLowerCase()] =
            suggestion.displayName;
      }
      _guestSuggestions = const [];
    });
  }

  Future<void> _editRecurrence() async {
    final start = _draft.start;
    if (start == null) return;
    if (_draft.providerRecurringEventId != null &&
        (_draft.recurringMutationScope == null ||
            _draft.recurringMutationScope ==
                RecurringEventMutationScope.singleOccurrence)) {
      final scope = await _selectRecurringScope();
      if (scope == null ||
          scope == RecurringEventMutationScope.singleOccurrence ||
          !mounted) {
        return;
      }
    }
    final result = await showAndroidRecurrenceDialog(
      context,
      initial: _recurrenceRule,
      baseDate: start,
      allDay: _draft.allDay,
      floating:
          _provider.isDav &&
          (_draft.startTimeZone == null || _draft.startTimeZone!.isEmpty),
      timeZone: _draft.startTimeZone,
      limits: EventRecurrenceCodec.limitsFor(_provider),
      providerLabel: _provider.displayName,
    );
    if (!mounted || result == null || result == _recurrenceRule) return;
    setState(() {
      _recurrenceRule = result;
      _recurrenceChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop || !_hasPendingEdits,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _allowPop) return;
        if (await _confirmDiscardChanges() && mounted) {
          await _clearRecovery(finalCleanup: true);
          if (!mounted) return;
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _saving ? null : _requestClose,
            icon: const Icon(Icons.close),
          ),
          title: Text(
            _draft.eventId == null
                ? context.l10n.newEvent
                : context.l10n.editEvent,
          ),
          actions: [
            TextButton(
              onPressed: _saving || !_canEdit || !_draft.canSave ? null : _save,
              child: Text(context.l10n.save),
            ),
          ],
        ),
        body: Form(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if ((_draft.attendees.isNotEmpty ||
                      widget.draft.attendees.isNotEmpty) &&
                  (_source?.usesImplicitScheduling == true ||
                      widget.sources.any(
                        (s) =>
                            s.id == widget.draft.sourceId &&
                            s.usesImplicitScheduling,
                      )))
                Text(
                  context.l10n.caldavSchedulingWarning,
                  key: const ValueKey('caldav-scheduling-warning'),
                ),
              TextFormField(
                controller: _title,
                enabled: _canEdit,
                decoration: InputDecoration(labelText: context.l10n.title),
                autofocus: _draft.eventId == null,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(title: v)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _source?.id,
                decoration: InputDecoration(labelText: context.l10n.calendar),
                items: [
                  for (final source in widget.sources.where(
                    (source) =>
                        source.id == _draft.sourceId ||
                        (source.capabilities.canCreateEvents &&
                            (_draft.eventId == null || !source.pendingCreate)),
                  ))
                    DropdownMenuItem(
                      value: source.id,
                      child: Text(
                        '${source.summary} · ${source.authenticatedAccountEmail ?? source.accountId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    !_canEdit ||
                        (_draft.eventId != null &&
                            !(_originalSource?.capabilities.canDeleteEvents ??
                                false))
                    ? null
                    : (id) => _selectDestination(
                        widget.sources.firstWhere((source) => source.id == id),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.allDay),
                value: _draft.allDay,
                onChanged:
                    !_canChangeTiming ||
                        _draft.eventType == 'focusTime' ||
                        _draft.eventType == 'outOfOffice'
                    ? null
                    : (value) => setState(() {
                        _draft = _draft.copyWith(allDay: value);
                        if (!_draft.copyWith(title: '_').canSave &&
                            _draft.start != null &&
                            _draft.end != null) {
                          _draft = _draft.copyWith(
                            end: _draft.start!.add(
                              value
                                  ? const Duration(days: 1)
                                  : const Duration(hours: 1),
                            ),
                          );
                        }
                        _adjustRecurrenceTiming();
                      }),
              ),
              _DateTimeTile(
                label: context.l10n.startDateTime,
                value: _draft.start!,
                allDay: _draft.allDay,
                onChanged: !_canChangeTiming ? null : _setStart,
              ),
              _DateTimeTile(
                label: context.l10n.endDateTime,
                value: _draft.end!,
                allDay: _draft.allDay,
                onChanged: !_canChangeTiming
                    ? null
                    : (value) =>
                          setState(() => _draft = _draft.copyWith(end: value)),
              ),
              if (!_draft.allDay) ...[
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(
                    '${context.l10n.startGroup} · ${context.l10n.selectTimeZone}',
                  ),
                  subtitle: Text(
                    _draft.startTimeZone ?? ref.read(localTimeZoneProvider),
                  ),
                  onTap: !_canChangeTiming
                      ? null
                      : () async {
                          final zone = await showAndroidTimeZonePicker(
                            context,
                            _draft.startTimeZone,
                          );
                          if (zone != null && mounted) {
                            setState(() {
                              _draft = _draft.copyWith(startTimeZone: zone);
                              _adjustRecurrenceTiming();
                            });
                          }
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(
                    '${context.l10n.endDateTime} · ${context.l10n.selectTimeZone}',
                  ),
                  subtitle: Text(
                    _draft.endTimeZone ??
                        _draft.startTimeZone ??
                        ref.read(localTimeZoneProvider),
                  ),
                  onTap: !_canChangeTiming
                      ? null
                      : () async {
                          final zone = await showAndroidTimeZonePicker(
                            context,
                            _draft.endTimeZone,
                          );
                          if (zone != null && mounted) {
                            setState(
                              () => _draft = _draft.copyWith(endTimeZone: zone),
                            );
                          }
                        },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('android-event-show-as-${_provider.name}'),
                initialValue:
                    _eventShowAsValues(_provider).contains(_draft.showAs)
                    ? _draft.showAs
                    : _eventShowAsValues(_provider).first,
                decoration: InputDecoration(
                  labelText: context.l10n.availabilityShowAs,
                ),
                items: [
                  for (final value in _eventShowAsValues(_provider))
                    DropdownMenuItem(
                      value: value,
                      child: Text(_eventAvailabilityLabel(context, value)),
                    ),
                ],
                onChanged:
                    !_canEdit ||
                        googleStatusEventTypes.contains(_draft.eventType)
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(showAs: value),
                      ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('android-event-visibility-${_provider.name}'),
                initialValue:
                    _eventVisibilityValues(_provider)
                        .contains(_draft.visibilityOrSensitivity)
                    ? _draft.visibilityOrSensitivity
                    : _eventVisibilityValues(_provider).first,
                decoration: InputDecoration(labelText: context.l10n.visibility),
                items: [
                  for (final value in _eventVisibilityValues(_provider))
                    DropdownMenuItem(
                      value: value,
                      child: Text(_eventVisibilityLabel(context, value)),
                    ),
                ],
                onChanged: !_canEdit || _draft.eventType == 'workingLocation'
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(
                          visibilityOrSensitivity: value,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                enabled: _canEdit,
                decoration: InputDecoration(
                  labelText: context.l10n.location,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(location: v)),
              ),
              const SizedBox(height: 12),
              AndroidEventDescriptionEditor(
                key: ValueKey((
                  'android-event-description',
                  _draft.sourceId,
                  _descriptionGeneration,
                )),
                provider: _provider,
                text: _draft.editableDescription,
                contentType: _draft.descriptionContentType,
                html: _draft.editableDescriptionHtml,
                enabled: _canEdit && !_draft.descriptionEditUnsafe,
                onChanged: (value) => setState(() {
                  _description.text = value.text;
                  _draft = _draft.copyWith(
                    description: value.text,
                    descriptionContentType: value.contentType,
                    descriptionHtml: value.html,
                  );
                }),
              ),
              const SizedBox(height: 12),
              if (_provider == BusyProvider.microsoft ||
                  _provider == BusyProvider.google)
                ExpansionTile(
                  title: Text(context.l10n.advancedSection),
                  children: [
                    if (_provider == BusyProvider.microsoft)
                      DropdownButtonFormField<String>(
                        initialValue: _draft.importance ?? 'normal',
                        decoration: InputDecoration(
                          labelText: context.l10n.importance,
                        ),
                        items: [
                          for (final value in ['low', 'normal', 'high'])
                            DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == 'low'
                                    ? context.l10n.importanceLow
                                    : value == 'high'
                                    ? context.l10n.importanceHigh
                                    : context.l10n.importanceNormal,
                              ),
                            ),
                        ],
                        onChanged: !_canEdit
                            ? null
                            : (value) => setState(
                                () =>
                                    _draft = _draft.copyWith(importance: value),
                              ),
                      ),
                    if (_provider == BusyProvider.microsoft)
                      SwitchListTile(
                        title: Text(context.l10n.requestResponses),
                        value: _draft.responseRequested ?? true,
                        onChanged: !_canEdit || !_draft.canManageAttendees
                            ? null
                            : (value) => setState(
                                () => _draft = _draft.copyWith(
                                  responseRequested: value,
                                ),
                              ),
                      ),
                    SwitchListTile(
                      title: Text(context.l10n.hideGuestList),
                      value: _draft.hideAttendees ?? false,
                      onChanged: !_canEdit || !_draft.canManageAttendees
                          ? null
                          : (value) => setState(
                              () => _draft = _draft.copyWith(
                                hideAttendees: value,
                              ),
                            ),
                    ),
                    if (_provider == BusyProvider.microsoft)
                      SwitchListTile(
                        title: Text(context.l10n.allowNewTimeProposals),
                        value: _draft.allowNewTimeProposals ?? true,
                        onChanged: !_canEdit || !_draft.canManageAttendees
                            ? null
                            : (value) => setState(
                                () => _draft = _draft.copyWith(
                                  allowNewTimeProposals: value,
                                ),
                              ),
                      ),
                  ],
                ),
              ListTile(
                key: const ValueKey('android-event-recurrence'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat),
                title: Text(context.l10n.repeat),
                subtitle: Text(
                  _recurrenceRule.isSupported
                      ? _recurrenceRule.repeats
                            ? recurrenceRuleSummary(
                                context,
                                _recurrenceRule,
                                timeZone: _draft.startTimeZone,
                              )
                            : context.l10n.repeatNone
                      : context.l10n.unsupportedRecurrencePreserved,
                ),
                onTap: _canEdit ? _editRecurrence : null,
              ),
              if (_draft.providerRecurringEventId != null) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.call_split),
                  title: Text(context.l10n.chooseRecurringEventScope),
                  subtitle: _draft.recurringMutationScope == null
                      ? null
                      : Text(
                          _scopeLabel(context, _draft.recurringMutationScope!),
                        ),
                  onTap: _canEdit ? _selectRecurringScope : null,
                ),
              ],
              const SizedBox(height: 12),
              if (_provider == BusyProvider.google)
                ..._googleReminderRows()
              else if (_provider == BusyProvider.nextcloud ||
                  _provider == BusyProvider.caldav)
                ..._nextcloudReminderRows()
              else ...[
                DropdownButtonFormField<int>(
                  key: ValueKey('android-event-reminder-${_draft.sourceId}'),
                  initialValue:
                      _reminderMinutes ??
                      androidEventReminderSelection(
                        _provider,
                        _draft.reminders,
                      ),
                  decoration: InputDecoration(labelText: context.l10n.reminder),
                  items: [
                    DropdownMenuItem(
                      value: -2,
                      child: Text(context.l10n.noReminders),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text(context.l10n.reminderAtStart),
                    ),
                    for (final value in <int>{
                      5,
                      10,
                      30,
                      60,
                      1440,
                      if ((_reminderMinutes ??
                              androidEventReminderSelection(
                                _provider,
                                _draft.reminders,
                              ))
                          case final int selected when selected > 0)
                        selected,
                    })
                      DropdownMenuItem(
                        value: value,
                        child: Text(context.l10n.reminderMinutesBefore(value)),
                      ),
                  ],
                  onChanged: !_canEdit
                      ? null
                      : (value) => setState(() => _reminderMinutes = value),
                ),
                if (_reminderMinutes == null)
                  if (androidEventReminderMinutes(_provider, _draft.reminders)
                      case final List<int> minutes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        minutes.isEmpty
                            ? context.l10n.noReminders
                            : minutes
                                  .map(
                                    (minute) => minute == 0
                                        ? context.l10n.reminderAtStart
                                        : context.l10n.reminderMinutesBefore(
                                            minute,
                                          ),
                                  )
                                  .join(', '),
                      ),
                    ),
                if (_reminderMinutes == null &&
                    androidEventReminderSelection(
                          _provider,
                          _draft.reminders,
                        ) ==
                        null &&
                    androidEventReminderMinutes(_provider, _draft.reminders) ==
                        null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(context.l10n.unsupportedReminder),
                  ),
              ],
              if (_draft.conference != null ||
                  (_provider == BusyProvider.google &&
                      (_source?.allowedConferenceSolutions.contains(
                            'hangoutsMeet',
                          ) ??
                          false)) ||
                  (_provider == BusyProvider.microsoft &&
                      (_source?.allowedConferenceSolutions.contains(
                            'teamsForBusiness',
                          ) ??
                          false)))
                SwitchListTile(
                  key: const ValueKey('android-event-create-conference'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _provider == BusyProvider.google
                        ? context.l10n.addGoogleMeet
                        : context.l10n.addTeamsMeeting,
                  ),
                  subtitle: _draft.conference == null
                      ? null
                      : Text(context.l10n.onlineMeetingAdded),
                  value: _draft.conference != null || _draft.createConference,
                  onChanged: _canEdit && _draft.conference == null
                      ? (value) => setState(
                          () =>
                              _draft = _draft.copyWith(createConference: value),
                        )
                      : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guests,
                enabled:
                    _canEdit &&
                    _provider != BusyProvider.caldav &&
                    _draft.canManageAttendees,
                decoration: InputDecoration(
                  labelText: context.l10n.guests,
                  hintText: context.l10n.addGuestEmail,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  setState(() {});
                  unawaited(_loadGuestSuggestions(value));
                },
              ),
              for (final suggestion in _guestSuggestions)
                ListTile(
                  key: ValueKey('android-guest-contact-${suggestion.email}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_outlined),
                  title: Text(
                    suggestion.displayName.isEmpty
                        ? suggestion.email
                        : suggestion.displayName,
                  ),
                  subtitle: suggestion.displayName.isEmpty
                      ? null
                      : Text(suggestion.email),
                  onTap: _canEdit && _draft.canManageAttendees
                      ? () => _selectGuestSuggestion(suggestion)
                      : null,
                ),
              for (final attendee in _currentAttendees().where(
                (a) => !a.self && !a.organizer,
              ))
                ListTile(
                  key: ValueKey('android-event-guest-${attendee.email}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(attendee.displayName ?? attendee.email),
                  subtitle: attendee.displayName == null
                      ? null
                      : Text(attendee.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<bool>(
                        value:
                            _guestOptionalOverrides[attendee.email
                                .toLowerCase()] ??
                            attendee.optional,
                        items: [
                          DropdownMenuItem(
                            value: false,
                            child: Text(context.l10n.attendeeRequired),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text(context.l10n.attendeeOptional),
                          ),
                        ],
                        onChanged: _canEdit && _draft.canManageAttendees
                            ? (optional) => setState(() {
                                if (optional == null ||
                                    optional == attendee.optional) {
                                  _guestOptionalOverrides.remove(
                                    attendee.email.toLowerCase(),
                                  );
                                } else {
                                  _guestOptionalOverrides[attendee.email
                                          .toLowerCase()] =
                                      optional;
                                }
                              })
                            : null,
                      ),
                      IconButton(
                        tooltip: context.l10n.delete,
                        onPressed: _canEdit && _draft.canManageAttendees
                            ? () => setState(() {
                                _guests.text =
                                    mergeAndroidEventAttendees(
                                          widget.draft.attendees,
                                          _guests.text,
                                        ).attendees
                                        .where(
                                          (a) =>
                                              !a.self &&
                                              !a.organizer &&
                                              a.email.toLowerCase() !=
                                                  attendee.email.toLowerCase(),
                                        )
                                        .map((a) => a.email)
                                        .join(', ');
                                _guestOptionalOverrides.remove(
                                  attendee.email.toLowerCase(),
                                );
                                _suggestedGuestNames.remove(
                                  attendee.email.toLowerCase(),
                                );
                              })
                            : null,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              if (_canCheckGuestAvailability) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _showGuestAvailability,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(context.l10n.nextcloudGuestAvailability),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _categories,
                enabled: _canEdit,
                decoration: InputDecoration(labelText: context.l10n.categories),
                onChanged: (_) => setState(() {}),
              ),
              if (_provider == BusyProvider.microsoft && _source != null)
                _microsoftCategoryField(_source!),
              if (_provider == BusyProvider.google &&
                  (_source?.primaryCalendar == true ||
                      googleStatusEventTypes.contains(_draft.eventType)))
                ..._googleStatusRows(),
              if (_provider == BusyProvider.google && _source != null)
                _googleEventLabelField(_source!),
              if (_canDelete) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    _isNextcloudAttendee
                        ? context.l10n.nextcloudDeclineAndRemove
                        : context.l10n.deleteEvent,
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _googleReminderRows() {
    final value = _editedGoogleReminders ?? _draft.reminders;
    final mode = androidGoogleReminderMode(value);
    final popupRows = androidGooglePopupReminderRows(value);
    return [
      DropdownButtonFormField<int>(
        key: ValueKey('android-event-reminder-mode-${_draft.sourceId}-$mode'),
        initialValue: mode,
        decoration: InputDecoration(labelText: context.l10n.reminders),
        items: [
          DropdownMenuItem(
            value: -1,
            child: Text(context.l10n.defaultReminder),
          ),
          DropdownMenuItem(value: -2, child: Text(context.l10n.noReminders)),
          DropdownMenuItem(value: -3, child: Text(context.l10n.reminders)),
        ],
        onChanged: !_canEdit
            ? null
            : (selection) {
                if (selection == null) return;
                setState(
                  () => _editedGoogleReminders = androidSetGoogleReminderMode(
                    value,
                    selection,
                  ),
                );
              },
      ),
      if (mode == -3) ...[
        for (final row in popupRows)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('android-event-popup-${row.index}'),
                  initialValue: row.minutes,
                  decoration: InputDecoration(labelText: context.l10n.reminder),
                  items: [
                    for (final minute in <int>{
                      0,
                      5,
                      10,
                      30,
                      60,
                      1440,
                      row.minutes,
                    })
                      DropdownMenuItem(
                        value: minute,
                        child: Text(
                          minute == 0
                              ? context.l10n.reminderAtStart
                              : context.l10n.reminderMinutesBefore(minute),
                        ),
                      ),
                  ],
                  onChanged: !_canEdit
                      ? null
                      : (minute) {
                          if (minute == null) return;
                          setState(
                            () => _editedGoogleReminders =
                                androidEditGooglePopupReminder(
                                  value,
                                  overrideIndex: row.index,
                                  minutes: minute,
                                ),
                          );
                        },
                ),
              ),
              IconButton(
                tooltip: context.l10n.removeReminder,
                onPressed: !_canEdit
                    ? null
                    : () => setState(
                        () => _editedGoogleReminders =
                            androidRemoveGooglePopupReminder(
                              value,
                              overrideIndex: row.index,
                            ),
                      ),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        if (androidGoogleReminderOverrideCount(value) < 5)
          TextButton.icon(
            onPressed: !_canEdit
                ? null
                : () => setState(
                    () =>
                        _editedGoogleReminders = androidEditGooglePopupReminder(
                          value,
                          overrideIndex: null,
                          minutes: 10,
                        ),
                  ),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addReminder),
          ),
        if (androidGoogleHasUnsupportedReminder(value))
          Text(context.l10n.unsupportedReminder),
      ],
    ];
  }

  List<Widget> _nextcloudReminderRows() {
    final rows =
        _editedNextcloudReminders ??
        androidNextcloudEditableReminderRows(_draft.reminders);
    if (rows == null) return [Text(context.l10n.unsupportedReminder)];
    return [
      Text(context.l10n.reminders),
      if (rows.isEmpty) Text(context.l10n.noReminders),
      for (var index = 0; index < rows.length; index++)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('android-event-dav-reminder-$index'),
                initialValue: rows[index].minutes,
                decoration: InputDecoration(labelText: context.l10n.reminder),
                items: [
                  for (final minute in <int>{
                    0,
                    5,
                    10,
                    30,
                    60,
                    1440,
                    rows[index].minutes,
                  })
                    DropdownMenuItem(
                      value: minute,
                      child: Text(
                        minute == 0
                            ? context.l10n.reminderAtStart
                            : context.l10n.reminderMinutesBefore(minute),
                      ),
                    ),
                ],
                onChanged: !_canEdit
                    ? null
                    : (minute) {
                        if (minute == null) return;
                        setState(() {
                          final edited = [...rows];
                          edited[index] = edited[index].copyWith(
                            minutes: minute,
                          );
                          _editedNextcloudReminders = edited;
                        });
                      },
              ),
            ),
            IconButton(
              tooltip: context.l10n.removeReminder,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: !_canEdit
                  ? null
                  : () => setState(() {
                      final edited = [...rows]..removeAt(index);
                      _editedNextcloudReminders = edited;
                    }),
            ),
          ],
        ),
      TextButton.icon(
        onPressed: !_canEdit
            ? null
            : () => setState(() {
                _editedNextcloudReminders = [
                  ...rows,
                  const AndroidNextcloudReminderRow(minutes: 10),
                ];
              }),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addReminder),
      ),
      if (androidNextcloudHasUnsupportedAlarms(_draft.reminders))
        Text(context.l10n.unsupportedReminder),
    ];
  }

  List<Widget> _googleStatusRows() {
    final l10n = context.l10n;
    final type = _draft.eventType ?? 'default';
    final types = <String>['default', ...googleStatusEventTypes];
    final rows = <Widget>[
      DropdownButtonFormField<String>(
        key: const Key('android-google-event-type'),
        isExpanded: true,
        initialValue: types.contains(type) ? type : 'default',
        decoration: InputDecoration(labelText: l10n.googleEventType),
        items: [
          for (final value in types)
            DropdownMenuItem(
              value: value,
              child: Text(googleEventTypeLabel(l10n, value)),
            ),
        ],
        onChanged: !_canEdit || _draft.eventId != null
            ? null
            : (value) {
                if (value == null) return;
                final start = _draft.start;
                setState(
                  () => _draft = _draft.copyWith(
                    eventType: value,
                    googleStatusProperties: defaultGoogleStatusProperties(
                      value,
                    ),
                    showAs: value == 'workingLocation'
                        ? 'transparent'
                        : 'opaque',
                    visibilityOrSensitivity: value == 'workingLocation'
                        ? 'public'
                        : 'default',
                    allDay: value == 'workingLocation' ? _draft.allDay : false,
                    end:
                        value == 'workingLocation' &&
                            _draft.allDay &&
                            start != null
                        ? DateTime(start.year, start.month, start.day + 1)
                        : _draft.end,
                  ),
                );
              },
      ),
    ];
    if (!googleStatusEventTypes.contains(type)) return rows;
    final properties = _draft.googleStatusProperties;
    if (type == 'focusTime' || type == 'outOfOffice') {
      const modes = [
        'declineNone',
        'declineOnlyNewConflictingInvitations',
        'declineAllConflictingInvitations',
      ];
      final mode = properties['autoDeclineMode']?.toString() ?? modes.first;
      rows.add(
        DropdownButtonFormField<String>(
          key: const Key('android-google-auto-decline'),
          initialValue: modes.contains(mode) ? mode : modes.first,
          decoration: InputDecoration(labelText: l10n.googleDeclineInvitations),
          items: [
            for (final value in modes)
              DropdownMenuItem(
                value: value,
                child: Text(googleAutoDeclineLabel(l10n, value)),
              ),
          ],
          onChanged: !_canEdit
              ? null
              : (value) {
                  if (value == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      googleStatusProperties: {
                        ...properties,
                        'autoDeclineMode': value,
                      },
                    ),
                  );
                },
        ),
      );
      if (type == 'focusTime') {
        rows.add(
          DropdownButtonFormField<String>(
            key: const Key('android-google-chat-status'),
            initialValue: properties['chatStatus'] == 'doNotDisturb'
                ? 'doNotDisturb'
                : 'available',
            decoration: InputDecoration(labelText: l10n.googleChatStatus),
            items: [
              DropdownMenuItem(
                value: 'available',
                child: Text(l10n.googleChatAvailable),
              ),
              DropdownMenuItem(
                value: 'doNotDisturb',
                child: Text(l10n.googleChatDoNotDisturb),
              ),
            ],
            onChanged: !_canEdit
                ? null
                : (value) {
                    if (value == null) return;
                    setState(
                      () => _draft = _draft.copyWith(
                        googleStatusProperties: {
                          ...properties,
                          'chatStatus': value,
                        },
                      ),
                    );
                  },
          ),
        );
      }
      rows.add(
        TextFormField(
          key: ValueKey('android-google-decline-message-$type'),
          initialValue: properties['declineMessage']?.toString() ?? '',
          enabled: _canEdit,
          decoration: InputDecoration(labelText: l10n.googleDeclineMessage),
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              googleStatusProperties: {...properties, 'declineMessage': value},
            ),
          ),
        ),
      );
      return rows;
    }
    const locations = ['homeOffice', 'officeLocation', 'customLocation'];
    final locationType = properties['type']?.toString() ?? locations.first;
    rows.add(
      DropdownButtonFormField<String>(
        key: const Key('android-google-working-location'),
        initialValue: locations.contains(locationType)
            ? locationType
            : locations.first,
        decoration: InputDecoration(labelText: l10n.googleWorkingLocation),
        items: [
          for (final value in locations)
            DropdownMenuItem(
              value: value,
              child: Text(googleWorkingLocationLabel(l10n, value)),
            ),
        ],
        onChanged: !_canEdit
            ? null
            : (value) {
                if (value == null) return;
                final next = {...properties}
                  ..remove('homeOffice')
                  ..remove('officeLocation')
                  ..remove('customLocation');
                next['type'] = value;
                next[value] = value == 'homeOffice'
                    ? <String, Object?>{}
                    : (properties[value] is Map
                          ? Map<String, Object?>.from(properties[value] as Map)
                          : <String, Object?>{});
                setState(
                  () => _draft = _draft.copyWith(googleStatusProperties: next),
                );
              },
      ),
    );
    if (locationType != 'homeOffice') {
      final detail = properties[locationType] is Map
          ? Map<String, Object?>.from(properties[locationType] as Map)
          : <String, Object?>{};
      rows.add(
        TextFormField(
          key: ValueKey('android-google-location-label-$locationType'),
          initialValue: detail['label']?.toString() ?? '',
          enabled: _canEdit,
          decoration: InputDecoration(labelText: l10n.googleWorkLocationLabel),
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(
              googleStatusProperties: {
                ...properties,
                locationType: {...detail, 'label': value},
              },
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _googleEventLabelField(CalendarSourceEntity source) {
    final labels = ref.watch(
      googleEventLabelsForCalendarProvider((
        accountId: source.accountId,
        calendarId: source.providerCalendarId,
      )),
    );
    final current = _draft.eventLabelId;
    return labels.when(
      loading: () => ListTile(
        title: Text(context.l10n.eventLabel),
        subtitle: Text(current ?? context.l10n.noneValue),
      ),
      error: (_, _) => ListTile(
        title: Text(context.l10n.eventLabel),
        subtitle: Text(current ?? context.l10n.noneValue),
        trailing: TextButton(
          onPressed: () => ref.invalidate(
            googleEventLabelsForCalendarProvider((
              accountId: source.accountId,
              calendarId: source.providerCalendarId,
            )),
          ),
          child: Text(context.l10n.retry),
        ),
      ),
      data: (available) {
        final byId = {for (final label in available) label.id: label};
        final ids = <String>[
          '',
          ...byId.keys,
          if (current != null && !byId.containsKey(current)) current,
        ];
        return DropdownButtonFormField<String>(
          key: ValueKey('android-event-label-${source.id}'),
          isExpanded: true,
          initialValue: current ?? '',
          decoration: InputDecoration(labelText: context.l10n.eventLabel),
          items: [
            for (final id in ids)
              DropdownMenuItem(
                key: ValueKey('android-event-label-option-$id'),
                value: id,
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (byId[id] case final label?)
                        TextSpan(
                          text: '● ',
                          style: TextStyle(
                            color: Color(
                              0xff000000 |
                                  int.parse(
                                    label.backgroundColor.substring(1),
                                    radix: 16,
                                  ),
                            ),
                          ),
                        ),
                      TextSpan(
                        text: id.isEmpty
                            ? context.l10n.noneValue
                            : byId[id]?.name ??
                                  context.l10n.unknownEventLabel(id),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: !_canEdit
              ? null
              : (id) => setState(
                  () => _draft = id == null || id.isEmpty
                      ? _draft.copyWith(clearEventLabelId: true)
                      : _draft.copyWith(eventLabelId: id),
                ),
        );
      },
    );
  }

  Widget _microsoftCategoryField(CalendarSourceEntity source) {
    final catalog = ref.watch(
      microsoftMasterCategoriesProvider(source.accountId),
    );
    return catalog.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => TextButton(
        onPressed: () async {
          _consentCancellation?.cancel();
          final consent = AuthorizationCancellation();
          _consentCancellation = consent;
          try {
            try {
              await ref
                  .read(microsoftCategoryAuthorizationProvider)
                  ?.authorizeCategoryAccess(
                    source.accountId,
                    cancellation: consent,
                  );
              if (!mounted || consent.isCancelled) return;
              if (mounted) {
                ref.invalidate(
                  microsoftMasterCategoriesProvider(source.accountId),
                );
              }
            } on Object {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.outlookCategoriesUnavailable),
                  ),
                );
              }
            }
          } finally {
            consent.cancel();
            if (identical(_consentCancellation, consent)) {
              _consentCancellation = null;
            }
          }
        },
        child: Text(context.l10n.loadOutlookCategories),
      ),
      data: (categories) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final category in categories)
            FilterChip(
              label: Text(category.displayName),
              avatar: microsoftCategorySwatchArgb(category.color) == null
                  ? null
                  : CircleAvatar(
                      backgroundColor: Color(
                        microsoftCategorySwatchArgb(category.color)!,
                      ),
                      radius: 7,
                    ),
              selected: _categories.text
                  .split(',')
                  .map((value) => value.trim())
                  .contains(category.displayName),
              onSelected: !_canEdit
                  ? null
                  : (selected) {
                      final values = _categories.text
                          .split(',')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList();
                      if (selected) {
                        if (!values.contains(category.displayName)) {
                          values.add(category.displayName);
                        }
                      } else {
                        values.remove(category.displayName);
                      }
                      setState(() => _categories.text = values.join(', '));
                    },
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final start = _draft.start;
    if (_title.text.trim().isEmpty || start == null) return;
    final attendeeEdit = applyAndroidEventAttendeeRoles(
      AndroidEventAttendeeEdit(
        attendees: _currentAttendees(),
        changed: !listEquals(_currentAttendees(), widget.draft.attendees),
      ),
      _guestOptionalOverrides,
    );
    // The display separator can also occur inside an existing category.
    // Preserve the original values when this field was not edited.
    final categories = _categories.text == widget.draft.categories.join(', ')
        ? widget.draft.categories
        : _categories.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
    var draft = _draft.copyWith(
      title: _title.text.trim(),
      location: _location.text.trim(),

      attendees: attendeeEdit.attendees,
      attendeesChanged: attendeeEdit.changed,
      categories: categories,
      categoriesChanged: !listEquals(categories, widget.draft.categories),
    );
    if (_reminderMinutes != null) {
      final value = _reminderMinutes!;
      draft = draft.copyWith(
        reminders: _eventReminders(_provider, value),
        remindersChanged: true,
        clearReminders: false,
      );
    }
    if (_provider == BusyProvider.google && _editedGoogleReminders != null) {
      draft = draft.copyWith(
        reminders: _editedGoogleReminders,
        remindersChanged: true,
      );
    }
    if (_provider.isDav && _editedNextcloudReminders != null) {
      draft = draft.copyWith(
        reminders: {
          'davEditableRows': [
            for (final row in _editedNextcloudReminders!) row.toJson(),
          ],
        },
        remindersChanged: true,
      );
    }
    if (_recurrenceChanged) {
      final rule = _recurrenceRule;
      draft = draft.copyWith(
        recurrence: rule.repeats
            ? EventRecurrenceCodec.encode(
                _provider,
                rule,
                baseDate: start,
                allDay: draft.allDay,
                timeZone: draft.startTimeZone,
                original: widget.draft.recurrence,
              )
            : null,
        recurrenceChanged: true,
        clearRecurrence: !rule.repeats,
      );
    }
    if (!draft.canSave) return;
    if (draft.providerRecurringEventId != null &&
        draft.recurringMutationScope == null) {
      final scope = await _selectRecurringScope();
      if (scope == null) return;
      draft = draft.copyWith(recurringMutationScope: scope);
    }
    if (!mounted) return;
    final strategy = _moveStrategy(draft);
    if (strategy == CalendarEventMoveStrategy.copyThenDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.copyEventAndDeleteOriginal),
          content: Text(
            context.l10n.copyEventMoveWarning(
              '${_originalSource?.authenticatedAccountEmail ?? widget.draft.accountId} · ${_originalSource?.summary}',
              '${_source?.authenticatedAccountEmail ?? draft.accountId} · ${_source?.summary}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.copyAndDelete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (!mounted) return;
    var guestPolicy = CalendarGuestUpdatePolicy.send;
    final externalGuests = [
      ...draft.attendees,
      ...widget.draft.attendees,
    ].any((a) => !a.self && !a.organizer);
    if ((_source?.usesImplicitScheduling == true &&
            draft.attendees.isNotEmpty) ||
        (draft.isOrganizer == true && externalGuests)) {
      final decision = await showAndroidGuestDeliveryDialog(
        context,
        provider: _deliveryProvider,
      );
      if (decision == null || !mounted) return;
      guestPolicy = decision;
    }
    setState(() => _saving = true);
    try {
      final seriesTiming = await ref
          .read(calendarRepositoryProvider)
          .prepareSeriesTimingChange(draft);
      if (!mounted) return;
      if (seriesTiming?.requiresConfirmation == true) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.repeat),
            content: Text(
              context.l10n.seriesPatternChangeConfirmation(
                recurrenceRuleSummary(
                  dialogContext,
                  seriesTiming!.previewRule(
                    following:
                        draft.recurringMutationScope ==
                        RecurringEventMutationScope.thisAndFuture,
                    original: true,
                  ),
                  timeZone: seriesTiming.timeZone,
                ),
                recurrenceRuleSummary(
                  dialogContext,
                  seriesTiming.previewRule(
                    following:
                        draft.recurringMutationScope ==
                        RecurringEventMutationScope.thisAndFuture,
                  ),
                  timeZone: seriesTiming.timeZone,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.save),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        draft = draft.copyWith(seriesTimingApproval: seriesTiming!.signature);
      }
      if ((_reminderMinutes ?? -2) >= 0 ||
          androidGooglePopupReminderRows(_editedGoogleReminders).isNotEmpty ||
          (_editedNextcloudReminders?.isNotEmpty ?? false)) {
        final notifications = ref.read(androidNotificationServiceProvider);
        final granted = await notifications.requestNotificationPermission();
        final readiness = notifications.readiness.value;
        if ((!granted || !readiness.remindersReady) && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                !granted ||
                        readiness.notificationsAllowed == false ||
                        readiness.remindersAllowed == false
                    ? context.l10n.notificationsBlocked
                    : context.l10n.notificationsUnknown,
              ),
              action: SnackBarAction(
                label: context.l10n.settingsSystem,
                onPressed: () =>
                    BusyMaxAndroidPlatform.instance.openNotificationSettings(),
              ),
            ),
          );
        }
      }
      if (draft.eventId == null) {
        await ref
            .read(calendarRepositoryProvider)
            .createLocalEvent(draft, guestUpdatePolicy: guestPolicy);
        unawaited(
          ref
              .read(appSettingsControllerProvider.notifier)
              .rememberCalendar(
                CreationDestination(
                  accountId: draft.accountId,
                  id: draft.sourceId,
                ),
              ),
        );
      } else {
        await ref
            .read(calendarRepositoryProvider)
            .updateLocalEvent(draft, guestUpdatePolicy: guestPolicy);
      }
      for (final accountId in {draft.accountId, widget.draft.accountId}) {
        ref
            .read(
              pendingCalendarMutationSyncRequesterForAccountProvider(accountId),
            )
            .request();
      }
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (_provider == BusyProvider.nextcloud ||
                      _provider == BusyProvider.caldav)
                  ? localizedNextcloudCollectionError(context.l10n, error)
                  : '$error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canCheckGuestAvailability {
    final source = _source;
    if (source == null ||
        _draft.start == null ||
        _draft.end == null ||
        !_draft.end!.isAfter(_draft.start!)) {
      return false;
    }
    final hasGuests = mergeAndroidEventAttendees(
      _draft.attendees,
      _guests.text,
    ).attendees.any((attendee) => !attendee.self && !attendee.organizer);
    if (!hasGuests) return false;
    if (source.provider == BusyProvider.google) {
      return true;
    }
    if (source.provider == BusyProvider.microsoft) {
      final account = ref
          .watch(accountsStreamProvider)
          .valueOrNull
          ?.where((candidate) => candidate.id == source.accountId)
          .firstOrNull;
      return microsoftAvailabilityAccountType(account?.tenantId) ==
          MicrosoftAvailabilityAccountType.workSchool;
    }
    return source.provider == BusyProvider.nextcloud &&
        source.davCollectionId != null &&
        source.davEffectivePermissions['canQueryFreeBusy'] == true;
  }

  Future<void> _showGuestAvailability() async {
    final source = _source;
    if (source == null || !_canCheckGuestAvailability) return;
    final attendees = mergeAndroidEventAttendees(
      _draft.attendees,
      _guests.text,
    ).attendees;
    await showAndroidGuestAvailabilityDialog(
      context,
      accountId: source.accountId,
      provider: source.provider,
      collectionId: source.davCollectionId,
      calendarTimeZone: source.timeZone,
      draft: _draft.copyWith(attendees: attendees),
    );
  }

  Future<void> _delete() async {
    var draft = widget.draft.copyWith(
      recurringMutationScope: _draft.recurringMutationScope,
    );
    if (draft.providerRecurringEventId != null &&
        draft.recurringMutationScope == null) {
      final detail = draft.originalDetail;
      final scope = await showAndroidRecurringScope(
        context,
        supportsFollowing:
            draft.isOrganizer != false &&
            (detail == null
                ? supportsThisAndFollowingEventMutation(
                    _originalSource?.provider ?? _provider,
                  )
                : eventSupportsThisAndFollowing(detail)),
      );
      if (scope == null) return;
      draft = draft.copyWith(recurringMutationScope: scope);
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          (_originalSource?.provider ?? _provider) == BusyProvider.nextcloud &&
                  draft.isOrganizer == false
              ? context.l10n.nextcloudDeclineAndRemove
              : context.l10n.deleteEvent,
        ),
        content: Text(
          (_originalSource?.provider ?? _provider) == BusyProvider.nextcloud &&
                  draft.isOrganizer == false
              ? context.l10n.nextcloudDeclineRemovalWarning
              : _originalSource?.usesImplicitScheduling == true &&
                    draft.attendees.isNotEmpty
              ? '${draft.title}\n\n${context.l10n.caldavSchedulingWarning}'
              : draft.title,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _isNextcloudAttendee
                  ? context.l10n.nextcloudDeclineAndRemove
                  : context.l10n.delete,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || _draft.eventId == null || !mounted) return;
    var guestPolicy = CalendarGuestUpdatePolicy.send;
    if ((_originalSource?.usesImplicitScheduling == true &&
            draft.attendees.isNotEmpty) ||
        (draft.isOrganizer == true &&
            draft.attendees.any((a) => !a.self && !a.organizer))) {
      final decision = await showAndroidGuestDeliveryDialog(
        context,
        provider: _originalSource?.provider ?? _provider,
        deleting: true,
      );
      if (decision == null || !mounted) return;
      guestPolicy = decision;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(calendarRepositoryProvider)
          .deleteLocalEvent(
            _draft.eventId!,
            recurringScope: draft.recurringMutationScope,
            guestUpdatePolicy: guestPolicy,
          );
      ref
          .read(
            pendingCalendarMutationSyncRequesterForAccountProvider(
              draft.accountId,
            ),
          )
          .request();
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (_originalSource?.provider ?? _provider) == BusyProvider.nextcloud
                  ? localizedNextcloudCollectionError(context.l10n, error)
                  : '$error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _scopeAvailable(RecurringEventMutationScope scope) {
    if (scope == RecurringEventMutationScope.singleOccurrence) return true;
    if (!_moving) {
      return scope != RecurringEventMutationScope.thisAndFuture ||
          (_provider != BusyProvider.nextcloud ||
                  _draft.isOrganizer != false) &&
              (_draft.originalDetail == null
                  ? supportsThisAndFollowingEventMutation(_provider)
                  : eventSupportsThisAndFollowing(_draft.originalDetail!));
    }
    if (scope == RecurringEventMutationScope.thisAndFuture) return false;
    return _moveStrategy(_draft.copyWith(recurringMutationScope: scope)) !=
            CalendarEventMoveStrategy.copyThenDelete ||
        (_recurrenceRule.isSupported && _recurrenceRule.repeats);
  }

  Future<RecurringEventMutationScope?> _selectRecurringScope() async {
    final scope = await showModalBottomSheet<RecurringEventMutationScope>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(context.l10n.chooseRecurringEventScope)),
              for (final value in RecurringEventMutationScope.values)
                ListTile(
                  leading: Icon(
                    _draft.recurringMutationScope == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(_scopeLabel(context, value)),
                  enabled: _scopeAvailable(value),
                  subtitle: _scopeAvailable(value)
                      ? null
                      : Text(
                          value == RecurringEventMutationScope.thisAndFuture
                              ? context.l10n.thisAndFutureMoveUnavailable
                              : context.l10n.entireSeriesMoveUnavailable,
                        ),
                  onTap: !_scopeAvailable(value)
                      ? null
                      : () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (scope != null && mounted) {
      setState(() => _draft = _draft.copyWith(recurringMutationScope: scope));
    }
    return scope;
  }

  Future<void> _requestClose() async {
    if (!_hasPendingEdits || await _confirmDiscardChanges()) {
      if (!mounted) return;
      await _clearRecovery(finalCleanup: true);
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmDiscardChanges() async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.discardChangesAction),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _restoreRecovery() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: _recoveryKey);
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map) return;
      final map = value.cast<String, Object?>();
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      final version = map['v'];
      final editingExistingEvent = widget.draft.eventId != null;
      final storedEventId = map['eventId']?.toString();
      final identityMatches = editingExistingEvent
          ? (version == 2 || storedEventId == widget.draft.eventId) &&
                map['baseTitle'] == widget.draft.title &&
                map['baseStart'] == widget.draft.start?.toIso8601String()
          : storedEventId == null;
      if (savedAt == null ||
          DateTime.now().difference(savedAt).abs() > const Duration(days: 14) ||
          (version != 2 && version != 3) ||
          !identityMatches) {
        await _clearRecovery();
        return;
      }
      final start = DateTime.tryParse(map['start']?.toString() ?? '');
      final end = DateTime.tryParse(map['end']?.toString() ?? '');
      if (start == null || end == null) {
        await _clearRecovery();
        return;
      }
      final recoveredSource = widget.sources
          .where(
            (source) =>
                source.id == map['sourceId'] &&
                source.accountId == map['accountId'] &&
                source.providerCalendarId == map['providerCalendarId'] &&
                (widget.draft.eventId == null
                    ? source.capabilities.canCreateEvents
                    : source.capabilities.canEditEvents),
          )
          .firstOrNull;
      if (recoveredSource == null) {
        await _clearRecovery();
        return;
      }
      final frequency = RecurrenceFrequency.values
          .where((value) => value.name == map['frequency'])
          .firstOrNull;
      final recoveredRule = map['recurrenceRule'] is String
          ? RecurrenceRule.fromJson(
              map['recurrenceRule'] as String,
              baseDate: start,
            )
          : null;
      final recurringScope = RecurringEventMutationScope.values
          .where((value) => value.name == map['recurringMutationScope'])
          .firstOrNull;
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final recover = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.discardChangesAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.nextcloudRestore),
            ),
          ],
        ),
      );
      if (recover != true) {
        await _clearRecovery();
        return;
      }
      if (!mounted) return;
      setState(() {
        _title.text = map['title']?.toString() ?? _title.text;
        _location.text = map['location']?.toString() ?? _location.text;
        _description.text = map['description']?.toString() ?? _description.text;
        _guests.text = map['guests']?.toString() ?? _guests.text;
        _guestOptionalOverrides.clear();
        if (map['guestOptionalOverrides'] case final Map overrides) {
          for (final entry in overrides.entries) {
            if (entry.key is String && entry.value is bool) {
              _guestOptionalOverrides[entry.key as String] =
                  entry.value as bool;
            }
          }
        }
        _suggestedGuestNames.clear();
        if (map['guestDisplayNames'] case final Map names) {
          for (final entry in names.entries) {
            if (entry.key is String && entry.value is String) {
              _suggestedGuestNames[entry.key as String] = entry.value as String;
            }
          }
        }
        _categories.text = map['categories']?.toString() ?? _categories.text;
        _reminderMinutes = map['reminderMinutes'] as int?;
        _editedGoogleReminders = map['googleReminders'] is Map
            ? (map['googleReminders'] as Map).cast<String, Object?>()
            : null;
        _editedNextcloudReminders = map['nextcloudReminders'] is List
            ? [
                for (final value in map['nextcloudReminders'] as List)
                  AndroidNextcloudReminderRow.fromJson(value),
              ]
            : null;
        if (recoveredRule != null && recoveredRule != _recurrenceRule) {
          _recurrenceRule = recoveredRule;
          _recurrenceChanged = true;
        } else if (recoveredRule == null &&
            frequency != null &&
            frequency != _recurrenceRule.frequency) {
          _recurrenceRule = androidRuleForFrequency(frequency, start);
          _recurrenceChanged = true;
        }
        _descriptionGeneration++;
        _draft = _draft.copyWith(
          accountId: recoveredSource.accountId,
          sourceId: recoveredSource.id,
          providerCalendarId: recoveredSource.providerCalendarId,
          title: _title.text,
          location: _location.text,
          description: _description.text,
          descriptionContentType: map['descriptionContentType']?.toString(),
          descriptionHtml: map['descriptionHtml']?.toString(),
          startTimeZone: map['startTimeZone']?.toString(),
          endTimeZone: map['endTimeZone']?.toString(),
          importance: map['importance']?.toString(),
          responseRequested: map['responseRequested'] as bool?,
          hideAttendees: map['hideAttendees'] as bool?,
          allowNewTimeProposals: map['allowNewTimeProposals'] as bool?,
          allDay: map['allDay'] as bool? ?? _draft.allDay,
          start: start,
          end: end,
          recurringMutationScope: recurringScope,
          clearRecurringMutationScope: recurringScope == null,
          showAs: map['showAs']?.toString(),
          clearShowAs: map['showAs'] == null,
          visibilityOrSensitivity: map['visibility']?.toString(),
          clearVisibilityOrSensitivity: map['visibility'] == null,
          createConference:
              map['createConference'] == true &&
              (recoveredSource.provider == BusyProvider.google
                  ? recoveredSource.allowedConferenceSolutions.contains(
                      'hangoutsMeet',
                    )
                  : recoveredSource.provider == BusyProvider.microsoft &&
                        recoveredSource.allowedConferenceSolutions.contains(
                          'teamsForBusiness',
                        )),
          eventLabelId:
              map['eventLabelChanged'] == true &&
                  recoveredSource.provider == BusyProvider.google &&
                  map['eventLabelSourceId'] == recoveredSource.id
              ? map['eventLabelId']?.toString()
              : null,
          clearEventLabelId:
              map['eventLabelChanged'] == true &&
              recoveredSource.provider == BusyProvider.google &&
              map['eventLabelSourceId'] == recoveredSource.id &&
              map['eventLabelId'] == null,
          eventLabelChanged:
              map['eventLabelChanged'] == true &&
              recoveredSource.provider == BusyProvider.google &&
              map['eventLabelSourceId'] == recoveredSource.id,
          eventType:
              recoveredSource.provider == BusyProvider.google &&
                  recoveredSource.primaryCalendar &&
                  (widget.draft.eventId == null ||
                      map['eventType'] == widget.draft.eventType)
              ? map['eventType']?.toString()
              : null,
          googleStatusProperties:
              recoveredSource.provider == BusyProvider.google &&
                  recoveredSource.primaryCalendar &&
                  map['googleStatusProperties'] is Map
              ? Map<String, Object?>.from(map['googleStatusProperties'] as Map)
              : null,
        );
      });
    } on Object {
      // A malformed/locked recovery entry must never block the editor.
    } finally {
      _recoveryLoaded = true;
    }
  }

  Future<void> _persistRecovery() async {
    if (!_recoveryLoaded ||
        !_hasPendingEdits ||
        _allowPop ||
        _recoveryWritesBlocked) {
      return;
    }
    final payload = jsonEncode({
      'v': 3,
      'savedAt': DateTime.now().toIso8601String(),
      'eventId': widget.draft.eventId,
      'baseTitle': widget.draft.title,
      'baseStart': widget.draft.start?.toIso8601String(),
      'accountId': _draft.accountId,
      'sourceId': _draft.sourceId,
      'providerCalendarId': _draft.providerCalendarId,
      'recurringMutationScope': _draft.recurringMutationScope?.name,
      'showAs': _draft.showAs,
      'visibility': _draft.visibilityOrSensitivity,
      'title': _title.text,
      'location': _location.text,
      'description': _description.text,
      'descriptionContentType': _draft.descriptionContentType,
      'descriptionHtml': _draft.editableDescriptionHtml,
      'startTimeZone': _draft.startTimeZone,
      'endTimeZone': _draft.endTimeZone,
      'importance': _draft.importance,
      'responseRequested': _draft.responseRequested,
      'hideAttendees': _draft.hideAttendees,
      'allowNewTimeProposals': _draft.allowNewTimeProposals,
      'guests': _guests.text,
      'guestOptionalOverrides': _guestOptionalOverrides,
      'guestDisplayNames': _suggestedGuestNames,
      'categories': _categories.text,
      'allDay': _draft.allDay,
      'start': _draft.start?.toIso8601String(),
      'end': _draft.end?.toIso8601String(),
      'reminderMinutes': _reminderMinutes,
      'googleReminders': _editedGoogleReminders,
      'nextcloudReminders': _editedNextcloudReminders == null
          ? null
          : [for (final row in _editedNextcloudReminders!) row.toJson()],
      'createConference': _draft.createConference,
      'eventLabelId': _draft.eventLabelId,
      'eventLabelChanged': _draft.eventLabelChanged,
      'eventLabelSourceId': _draft.sourceId,
      'eventType': _draft.eventType,
      'googleStatusProperties': _draft.googleStatusProperties,
      'frequency': _recurrenceRule.frequency.name,
      if (_recurrenceChanged && _recurrenceRule.isSupported)
        'recurrenceRule': _recurrenceRule.toJsonString(),
    });
    await _enqueueRecovery(() async {
      if (_recoveryWritesBlocked) return;
      await ref
          .read(secureStorageProvider)
          .write(key: _recoveryKey, value: payload);
    });
  }

  Future<void> _clearRecovery({bool finalCleanup = false}) {
    if (finalCleanup) {
      _recoveryWritesBlocked = true;
      _recoveryTimer?.cancel();
    }
    return _enqueueRecovery(
      () => ref.read(secureStorageProvider).delete(key: _recoveryKey),
    );
  }

  Future<void> _enqueueRecovery(Future<void> Function() operation) {
    final result = _recoveryIo.then((_) => operation());
    _recoveryIo = result.catchError((_) {});
    return result.catchError((_) {});
  }
}

bool _androidLooksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

final class AndroidEventAttendeeEdit {
  const AndroidEventAttendeeEdit({
    required this.attendees,
    required this.changed,
  });

  final List<EventAttendeeDraft> attendees;
  final bool changed;
}

AndroidEventAttendeeEdit applyAndroidEventAttendeeRoles(
  AndroidEventAttendeeEdit edit,
  Map<String, bool> optionalByEmail,
) {
  if (optionalByEmail.isEmpty) return edit;
  final attendees = [
    for (final attendee in edit.attendees)
      if (!attendee.self &&
          !attendee.organizer &&
          optionalByEmail.containsKey(attendee.email.toLowerCase()))
        attendee.withOptional(optionalByEmail[attendee.email.toLowerCase()]!)
      else
        attendee,
  ];
  return AndroidEventAttendeeEdit(
    attendees: attendees,
    changed: edit.changed || !listEquals(attendees, edit.attendees),
  );
}

/// Applies the Android email editor without destroying provider-owned guest
/// metadata. Existing matching guests retain names, optional/required state,
/// response status and organizer/self flags.
AndroidEventAttendeeEdit mergeAndroidEventAttendees(
  List<EventAttendeeDraft> original,
  String editedEmails,
) {
  final requested = <String, String>{};
  for (final value in editedEmails.split(RegExp(r'[,;\n]'))) {
    final email = value.trim();
    if (email.isNotEmpty) {
      requested.putIfAbsent(email.toLowerCase(), () => email);
    }
  }
  final result = <EventAttendeeDraft>[];
  final matched = <String>{};
  for (final attendee in original) {
    if (attendee.self || attendee.organizer) {
      result.add(attendee);
      continue;
    }
    final key = attendee.email.trim().toLowerCase();
    if (requested.containsKey(key) && matched.add(key)) result.add(attendee);
  }
  for (final entry in requested.entries) {
    if (matched.add(entry.key)) {
      result.add(EventAttendeeDraft(email: entry.value));
    }
  }
  return AndroidEventAttendeeEdit(
    attendees: listEquals(result, original) ? original : result,
    changed: !listEquals(result, original),
  );
}

String _scopeLabel(BuildContext context, RecurringEventMutationScope scope) =>
    switch (scope) {
      RecurringEventMutationScope.entireSeries => context.l10n.entireSeries,
      RecurringEventMutationScope.singleOccurrence =>
        context.l10n.singleOccurrence,
      RecurringEventMutationScope.thisAndFuture =>
        context.l10n.thisAndFollowingEvents,
    };

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.allDay,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final bool allDay;
  final ValueChanged<DateTime>? onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.schedule),
    title: Text(label),
    subtitle: Text(
      allDay
          ? DateFormat.yMMMd().format(value)
          : formatClockDateTime(
              context,
              value,
              DateFormat.yMMMd().format(value),
            ),
    ),
    enabled: onChanged != null,
    onTap: onChanged == null
        ? null
        : () async {
            final date = await showBusyMaxDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(1970),
              lastDate: DateTime(2200),
            );
            if (date == null || !context.mounted) return;
            if (allDay) return onChanged!(date);
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(value),
            );
            if (time != null) {
              onChanged!(
                DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          },
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

ScheduleRange _rangeFor(
  DateTime anchor,
  ScheduleViewMode mode, {
  required int firstWeekday,
}) => switch (mode) {
  ScheduleViewMode.day => ScheduleRange.day(anchor),
  ScheduleViewMode.week => ScheduleRange.week(
    anchor,
    firstWeekday: firstWeekday,
  ),
  ScheduleViewMode.month => androidMonthGridRange(
    anchor,
    firstWeekday: firstWeekday,
  ),
  ScheduleViewMode.year => androidYearGridRange(
    anchor,
    firstWeekday: firstWeekday,
  ),
  ScheduleViewMode.agenda => ScheduleRange.days(DateTime.now(), count: 30),
};

/// The exact civil-date interval rendered by the Android six-week month grid.
ScheduleRange androidMonthGridRange(
  DateTime month, {
  required int firstWeekday,
}) {
  final first = DateTime(month.year, month.month);
  final offset = (first.weekday - firstWeekday) % DateTime.daysPerWeek;
  final start = DateTime(first.year, first.month, first.day - offset);
  return ScheduleRange(
    start: start,
    end: DateTime(start.year, start.month, start.day + 42),
  );
}

/// Covers every leading and trailing date drawn by all twelve year miniatures.
ScheduleRange androidYearGridRange(DateTime year, {required int firstWeekday}) {
  final january = androidMonthGridRange(
    DateTime(year.year),
    firstWeekday: firstWeekday,
  );
  final december = androidMonthGridRange(
    DateTime(year.year, DateTime.december),
    firstWeekday: firstWeekday,
  );
  return ScheduleRange(start: january.start, end: december.end);
}

DateTime _move(DateTime date, ScheduleViewMode mode, int amount) =>
    switch (mode) {
      ScheduleViewMode.day || ScheduleViewMode.agenda => DateTime(
        date.year,
        date.month,
        date.day + amount,
      ),
      ScheduleViewMode.week => DateTime(
        date.year,
        date.month,
        date.day + 7 * amount,
      ),
      ScheduleViewMode.month => DateTime(date.year, date.month + amount, 1),
      ScheduleViewMode.year => DateTime(date.year + amount, date.month, 1),
    };

String _periodLabel(
  BuildContext context,
  DateTime date,
  ScheduleViewMode mode,
) => switch (mode) {
  ScheduleViewMode.day => DateFormat.yMMMMd().format(date),
  ScheduleViewMode.agenda => context.l10n.viewAgenda,
  ScheduleViewMode.week =>
    '${DateFormat.MMMd().format(ScheduleRange.week(date, firstWeekday: _firstWeekday(context)).start)} – '
        '${DateFormat.MMMd().format(_previousCivilDay(ScheduleRange.week(date, firstWeekday: _firstWeekday(context)).end))}',
  ScheduleViewMode.month => DateFormat.yMMMM().format(date),
  ScheduleViewMode.year => '${date.year}',
};

DateTime _previousCivilDay(DateTime value) =>
    DateTime(value.year, value.month, value.day - 1);

String _modeLabel(BuildContext context, ScheduleViewMode mode) =>
    switch (mode) {
      ScheduleViewMode.day => context.l10n.viewDay,
      ScheduleViewMode.week => context.l10n.viewWeek,
      ScheduleViewMode.month => context.l10n.viewMonth,
      ScheduleViewMode.year => context.l10n.viewYear,
      ScheduleViewMode.agenda => context.l10n.viewAgenda,
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _firstWeekday(BuildContext context) {
  return BusyMaxWeekPreferencesScope.firstWeekdayOf(context);
}

Object? _eventReminders(BusyProvider provider, int minutes) {
  if (minutes == -1 && provider == BusyProvider.google) {
    return const {'useDefault': true};
  }
  if (minutes < 0) {
    return provider == BusyProvider.microsoft
        ? const {'isReminderOn': false}
        : const {'useDefault': false, 'overrides': <Object>[]};
  }
  return provider == BusyProvider.microsoft
      ? {'isReminderOn': true, 'reminderMinutesBeforeStart': minutes}
      : {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': minutes},
          ],
        };
}

typedef AndroidNextcloudReminderRow = DavEventReminderRow;

List<DavEventReminderRow>? androidNextcloudEditableReminderRows(
  Object? value,
) => davEventEditableReminderRows(value);

bool androidNextcloudHasUnsupportedAlarms(Object? value) {
  if (value is! Map || value['alarms'] is! List) return false;
  final rows = androidNextcloudEditableReminderRows(value);
  return rows != null && rows.length < (value['alarms'] as List).length;
}

/// A negative selection is explicit default (-1) or no reminder (-2).
/// Null means a provider-specific representation that this single-choice
/// editor must preserve until the user actively replaces it.
int? androidEventReminderSelection(BusyProvider provider, Object? value) {
  if (value == null) return provider == BusyProvider.google ? -1 : -2;
  if (value is! Map) return null;
  if (provider == BusyProvider.microsoft) {
    if (value['isReminderOn'] == false) return -2;
    return value['reminderMinutesBeforeStart'] is int
        ? value['reminderMinutesBeforeStart'] as int
        : null;
  }
  if (value['useDefault'] == true) return -1;
  final overrides = value['overrides'];
  if (overrides is List) {
    if (overrides.isEmpty) return -2;
    if (overrides.length == 1 && overrides.single is Map) {
      final entry = overrides.single as Map;
      if (entry['method'] == 'popup' && entry['minutes'] is int) {
        return entry['minutes'] as int;
      }
    }
  }
  return null;
}

List<int>? androidEventReminderMinutes(BusyProvider provider, Object? value) {
  if (value is! Map) return null;
  if (provider == BusyProvider.microsoft) {
    if (value['isReminderOn'] == false) return const [];
    final minutes = value['reminderMinutesBeforeStart'];
    return minutes is int && minutes >= 0 ? [minutes] : null;
  }
  if (value['useDefault'] == true) return null;
  final overrides = value['overrides'];
  if (overrides is List) {
    final result = <int>[];
    for (final entry in overrides) {
      if (entry is! Map ||
          entry['method'] != 'popup' ||
          entry['minutes'] is! int ||
          (entry['minutes'] as int) < 0) {
        return null;
      }
      result.add(entry['minutes'] as int);
    }
    return result;
  }
  final minutes = value['minutes'];
  return minutes is List &&
          minutes.every((element) => element is int && element >= 0)
      ? minutes.cast<int>()
      : null;
}

int? androidGoogleReminderMode(Object? value) {
  if (value == null) return -1;
  if (value is! Map) return null;
  if (value['useDefault'] == true) return -1;
  if (value['useDefault'] != false || value['overrides'] is! List) {
    return null;
  }
  return (value['overrides'] as List).isEmpty ? -2 : -3;
}

List<({int index, int minutes})> androidGooglePopupReminderRows(Object? value) {
  if (value is! Map || value['overrides'] is! List) return const [];
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

int androidGoogleReminderOverrideCount(Object? value) =>
    value is Map && value['overrides'] is List
    ? (value['overrides'] as List).length
    : 0;

bool androidGoogleHasUnsupportedReminder(Object? value) {
  if (value is! Map || value['overrides'] is! List) return false;
  return androidGooglePopupReminderRows(value).length !=
      (value['overrides'] as List).length;
}

Map<String, Object?> androidSetGoogleReminderMode(Object? value, int mode) {
  if (mode == -1) return const {'useDefault': true};
  if (mode == -2) return const {'useDefault': false, 'overrides': []};
  if (mode != -3) throw ArgumentError.value(mode, 'mode');
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

Map<String, Object?> androidEditGooglePopupReminder(
  Object? value, {
  required int? overrideIndex,
  required int minutes,
}) {
  if (minutes < 0) throw ArgumentError.value(minutes, 'minutes');
  final original = value is Map ? value.cast<String, Object?>() : const {};
  final overrides = [...?original['overrides'] as List?];
  if (overrideIndex == null) {
    if (overrides.length >= 5) {
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

Map<String, Object?> androidRemoveGooglePopupReminder(
  Object? value, {
  required int overrideIndex,
}) {
  final original = value is Map ? value.cast<String, Object?>() : const {};
  final overrides = [...?original['overrides'] as List?];
  if (overrideIndex < 0 ||
      overrideIndex >= overrides.length ||
      overrides[overrideIndex] is! Map ||
      (overrides[overrideIndex] as Map)['method'] != 'popup') {
    throw RangeError.index(overrideIndex, overrides);
  }
  overrides.removeAt(overrideIndex);
  return {...original, 'useDefault': false, 'overrides': overrides};
}

List<String> _eventShowAsValues(BusyProvider provider) =>
    provider == BusyProvider.microsoft
    ? const ['free', 'tentative', 'busy', 'oof', 'workingElsewhere']
    : const ['opaque', 'transparent'];

String _eventAvailabilityLabel(BuildContext context, String value) =>
    switch (value) {
      'opaque' || 'busy' => context.l10n.busy,
      'transparent' || 'free' => context.l10n.availabilityFree,
      'tentative' => context.l10n.availabilityTentative,
      'oof' => context.l10n.availabilityOutOfOffice,
      'workingElsewhere' => context.l10n.availabilityWorkingElsewhere,
      _ => value,
    };

List<String> _eventVisibilityValues(BusyProvider provider) =>
    provider == BusyProvider.microsoft
    ? const ['normal', 'personal', 'private', 'confidential']
    : const ['default', 'public', 'private', 'confidential'];

String _eventVisibilityLabel(BuildContext context, String value) =>
    switch (value) {
      'default' => context.l10n.visibilityDefault,
      'public' => context.l10n.visibilityPublic,
      'private' => context.l10n.visibilityPrivate,
      'confidential' => context.l10n.visibilityConfidential,
      'normal' => context.l10n.sensitivityNormal,
      'personal' => context.l10n.sensitivityPersonal,
      _ => value,
    };

import '../../dav/ical/ical_attachments.dart';
import '../../dav/ical/dav_native_import.dart' show NativeImportResource;
import '../../features/attachments/presentation/dav_attachment_file_name.dart';
import '../../features/sync/sync_request.dart';
import '../../features/sync/sync_activity_icon.dart';
import 'android_sync_feedback.dart';
import 'android_schedule_coverage_dialog.dart';
import '../android_local_network_access.dart';
import '../../features/calendar/application/attendee_suggestion_session.dart';
import 'android_editor_group.dart';
import '../../features/accounts/domain/account_collection_creation_capabilities.dart';
import '../../ui/common/schedule/schedule_interactions.dart';
import '../../features/calendar/application/save_event_draft.dart';
import '../../features/calendar/domain/event_property_policy.dart';
import '../../features/connectivity/network_connectivity_service.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../calendar_providers/calendar_colors.dart';
import 'android_feedback_screen.dart';
import '../../ui/common/schedule/schedule_day_week_view.dart';
import '../../ui/common/schedule/schedule_month_view.dart';
import '../../ui/common/schedule/schedule_year_view.dart';
import '../../ui/common/schedule/schedule_agenda_view.dart';
import '../../ui/common/schedule/mini_calendar.dart';
import '../../schedule/schedule_navigation_intent.dart';
import '../../schedule/schedule_commands.dart';
import '../../schedule/schedule_creation_destinations.dart';
import '../../features/calendar/domain/event_move_policy.dart';
import '../../features/calendar/domain/event_timing_policy.dart';
import 'android_event_description_editor.dart';
import '../../calendar_providers/calendar_description.dart';
import 'android_time_zone_picker.dart';
import '../../schedule/schedule_sidebar_order.dart';
import '../../schedule/schedule_sidebar_sources.dart';
import '../../schedule/schedule_sidebar_visibility_icon.dart';
import '../../schedule/schedule_event_rescheduling.dart';
import 'android_event_actions.dart';
import '../../schedule/schedule_agenda_query.dart';
import '../android_workspace_navigation.dart';
import '../../features/tasks/domain/task_checklist_item.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/calendar/domain/dav_event_reminders.dart';
import '../../features/calendar/domain/event_reminders.dart';
import 'android_dav_attachments_section.dart';
import '../../features/recurrence/presentation/recurrence_summary.dart';

import 'package:busymax/src/core/auth/authorization_attempt.dart';

import 'dart:async';

import '../../ui/common/schedule/schedule_presentation.dart';

import '../../journal/presentation/journal_pane.dart';
import '../../db/app_database.dart' show DavCollection;
import '../../dav/storage/dav_collection_capabilities.dart';
import '../../journal/presentation/material_journal_controls.dart';

import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../db/creation_receipt_store.dart';
import '../android_creation_recovery.dart';
import '../../app/app_bootstrap.dart';
import '../../contacts/busymax_contacts_controller.dart';
import '../../app/common/busymax_design_values.dart';
import '../../app/common/busymax_motion_widgets.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../calendar_providers/calendar_provider_capabilities.dart';
import '../../core/logging/redacting_logger.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/domain/event_editor_draft.dart';
import '../../features/calendar/domain/google_status_event.dart';
import '../../features/calendar/presentation/google_status_event_labels.dart';
import '../../features/maps/application/external_location_launcher.dart';
import '../../features/schedule/application/saved_schedule_location.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../features/schedule/presentation/schedule_item_exporter.dart';
import '../../features/schedule/presentation/cloud_calendar_series_export.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_editing.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';
import '../../l10n/localized_formatters.dart';
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
import '../android_notifications.dart';
import 'android_availability_dialog.dart';
import 'android_event_attachments_dialog.dart';
import 'android_recurrence_dialog.dart';
import 'android_date_picker.dart';
import 'android_settings_screen.dart';
import 'android_tasks_screen.dart';

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
        journals: await ref.watch(scheduleJournalSourcesProvider.future),
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
          journalSourceIds: visibility.visibleJournalSourceIds,
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
              (key.search == null
                  ? null
                  : visibility.maskSearch(key.search!).filters(key.query)) ??
              ScheduleFilters(
                query: key.query,
                sourceIds: visibility.visibleCalendarSourceIds,
                taskListKeys: visibility.visibleTaskListKeys,
                journalSourceIds: visibility.visibleJournalSourceIds,
                sourceFilterActive: true,
                taskListFilterActive: true,
                journalSourceFilterActive: true,
                includeJournals: true,
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
  bool _sidebarVisible = true;
  bool _persistentSourcesAvailable = false;
  bool _searchFiltersVisible = true;
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
    if (_searchFirstWeekday == firstWeekday) {
      return;
    }
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
        if (mounted) {
          unawaited(_openWorkspaceRequest(request));
        }
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
      if (request != null) {
        unawaited(_openWorkspaceRequest(request));
      }
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
    final sourceInventory = ref.watch(calendarSourcesStreamProvider);
    final taskInventory = ref.watch(scheduleTaskListsProvider);
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: sourceInventory.valueOrNull ?? const [],
      taskLists: taskInventory.valueOrNull ?? const [],
      journals:
          ref.watch(scheduleJournalSourcesProvider).valueOrNull ?? const [],
      settings: settings,
    );
    var items = page.whenData((value) => value.items);
    if (!_searching && mode == ScheduleViewMode.agenda) {
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
        ...visibility.visibleJournalSourceIds.toList()..sort(),
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
    if (_notificationDate == null && visibility.hiddenAccountIds.isNotEmpty) {
      items = items.whenData(
        (visibleItems) => [
          for (final item in visibleItems)
            if (!visibility.hiddenAccountIds.contains(item.accountId)) item,
        ],
      );
    }
    final effectiveSearch = searchCriteria == null
        ? null
        : visibility.maskSearch(searchCriteria);
    final displayedRange =
        searchCriteria?.range ??
        (mode == ScheduleViewMode.agenda
            ? ScheduleRange.days(DateTime.now(), count: _agendaDays)
            : _rangeFor(
                DateTime(_anchor.year, _anchor.month, _anchor.day),
                mode,
                firstWeekday: _firstWeekday(context),
              ));
    final coverageFilters = _searching && effectiveSearch != null
        ? effectiveSearch.filters(_query)
        : ScheduleFilters(
            sourceIds: visibility.visibleCalendarSourceIds,
            sourceFilterActive: true,
          );
    final bool? coverageComplete =
        _notificationDate == null &&
            items.hasValue &&
            coverageFilters.requiresCalendarCoverage
        ? ref
              .read(scheduleRepositoryProvider)
              .cloudCoverageCompleteFor(
                displayedRange,
                filters: coverageFilters,
              )
        : true;
    final presentation = _searching && effectiveSearch != null
        ? _buildSearchPresentation(
            items: items,
            criteria: effectiveSearch,
            query: _query,
            coverageComplete: coverageComplete,
          )
        : _buildCalendarPresentation(
            items: items,
            mode: mode,
            agendaPage: page.valueOrNull ?? _cachedAgendaPage,
            coverageComplete: coverageComplete,
          );
    final coverageWarning = coverageComplete == false
        ? IconButton(
            key: const ValueKey('schedule-coverage-warning'),
            tooltip: context.l10n.scheduleCoverageWarning,
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            onPressed: () => unawaited(
              showScheduleCoverage(
                context,
                () => ref
                    .read(scheduleRepositoryProvider)
                    .retryCloudCoverage(displayedRange, coverageFilters),
                openSettings: () => unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const AndroidSettingsScreen(
                        category: AndroidSettingsCategory.accounts,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : null;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _searching
                ? context.l10n.searchFiltersAction
                : context.l10n.collectionSettings,
            icon: const Icon(Icons.view_sidebar_outlined),
            onPressed: () {
              if (_persistentSourcesAvailable) {
                setState(() {
                  if (_searching) {
                    _searchFiltersVisible = !_searchFiltersVisible;
                  } else {
                    _sidebarVisible = !_sidebarVisible;
                  }
                });
              } else if (_searching) {
                _showSearchFilters();
              } else {
                _showSources(context);
              }
            },
          ),
          bottom: _searching
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: _navigationRow(context, mode, coverageWarning),
                ),
          title: BusyMaxBinaryPresentation(
            alternateActive: _searching,
            child: _searching
                ? TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: context.l10n.windowsSearch,
                      border: InputBorder.none,
                      prefixIcon: coverageWarning,
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
                          child: Tooltip(
                            message: _periodLabel(context, _anchor, mode),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _periodLabel(context, _anchor, mode),
                                maxLines: 1,
                              ),
                            ),
                          ),
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
            if (!_searching && MediaQuery.sizeOf(context).width >= 760)
              IconButton(
                tooltip: context.l10n.refreshAll,
                icon: const SyncActivityIcon(
                  scope: allSyncScope,
                  refresh: Icon(Icons.refresh),
                  warning: Icon(Icons.warning_amber_rounded),
                  child: Icon(Icons.refresh),
                ),
                onPressed: () => unawaited(_refreshWorkspace()),
              ),
            PopupMenuButton<String>(
              key: const ValueKey('android-workspace-menu'),
              tooltip: context.l10n.options,
              icon: _searching || MediaQuery.sizeOf(context).width < 760
                  ? const SyncActivityIcon(
                      scope: allSyncScope,
                      refresh: Icon(Icons.refresh),
                      warning: Icon(Icons.warning_amber_rounded),
                      child: Icon(Icons.more_vert),
                    )
                  : null,
              onSelected: (value) async {
                switch (value) {
                  case 'refresh':
                    await _refreshWorkspace();
                  case 'settings':
                    if (context.mounted) {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const AndroidSettingsScreen(),
                        ),
                      );
                    }
                  case 'report':
                    if (context.mounted) {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const AndroidFeedbackScreen(),
                        ),
                      );
                    }
                  case 'about':
                    final info = await PackageInfo.fromPlatform();
                    if (context.mounted) {
                      showAboutDialog(
                        context: context,
                        applicationName: 'BusyMax',
                        applicationVersion: info.version,
                        applicationLegalese: '© BusyStack',
                      );
                    }
                }
              },
              itemBuilder: (context) => [
                if (_searching || MediaQuery.sizeOf(context).width < 760)
                  PopupMenuItem(
                    value: 'refresh',
                    child: Text(context.l10n.refreshAll),
                  ),
                PopupMenuItem(
                  value: 'settings',
                  child: Text(context.l10n.settings),
                ),
                PopupMenuItem(
                  value: 'report',
                  enabled: ref
                      .read(buildConfigProvider)
                      .feedbackEndpoint
                      .isNotEmpty,
                  child: Text(context.l10n.sendFeedback),
                ),
                PopupMenuItem(
                  value: 'about',
                  child: Text(context.l10n.aboutBusyMax),
                ),
              ],
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            _persistentSourcesAvailable =
                constraints.maxWidth >= 980 &&
                constraints.maxHeight >=
                    (_searching
                        ? 240
                        : miniCalendarPreferredHeight(context, 320) + 220);
            return Row(
              children: [
                if (_persistentSourcesAvailable &&
                    (_searching ? _searchFiltersVisible : _sidebarVisible)) ...[
                  SizedBox(
                    width: 320,
                    child: _searching ? _searchFilterPanel() : _sourcesPane(),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: Column(
                    children: [
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendarPresentation({
    required AsyncValue<List<ScheduleItem>> items,
    required ScheduleViewMode mode,
    ScheduleAgendaPage? agendaPage,
    required bool? coverageComplete,
  }) {
    final accounts = ref.watch(accountsStreamProvider);
    final sourceState = ref.watch(calendarSourcesStreamProvider);
    final listState = ref.watch(scheduleTaskListsProvider);
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: sourceState.valueOrNull ?? const [],
      taskLists: listState.valueOrNull ?? const [],
      journals:
          ref.watch(scheduleJournalSourcesProvider).valueOrNull ?? const [],
      settings: ref.watch(appSettingsControllerProvider),
    );
    if (!items.isLoading &&
        !items.hasError &&
        accounts.hasValue &&
        accounts.requireValue.isNotEmpty &&
        sourceState.hasValue &&
        listState.hasValue &&
        !visibility.hasCalendarSources &&
        !visibility.hasTaskLists &&
        visibility.visibleJournalSourceIds.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined),
              const SizedBox(height: 12),
              Text(
                context.l10n.scheduleNoVisibleSources,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                context.l10n.scheduleNoSourcesDescription,
                textAlign: TextAlign.center,
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const AndroidSettingsScreen(),
                      ),
                    ),
                    child: Text(context.l10n.settings),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(_refreshWorkspace()),
                    child: Text(context.l10n.refreshAll),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
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
            agendaRange: ScheduleRange.days(DateTime.now(), count: _agendaDays),
            canCreateEvent: _canCreateEvent,
            canCreateTask: _canCreateTask,
            onLoadMore: () => setState(() => _agendaDays += 30),
            onLoadMoreOverdue: () => setState(() => _overdueLimit += 8),
            onLoadMoreNoDate: () => setState(() => _noDateLimit += 8),
            onCreate: (start, end) => end == null
                ? _createItem(context, start: start)
                : _createEvent(context, start: start, end: end),
            onToggleChecklist: _toggleChecklist,
            onReschedule: _rescheduleEvent,
            dayStartMinute: ref
                .watch(appSettingsControllerProvider)
                .scheduleDayStartMinute,
            dayEndMinute: ref
                .watch(appSettingsControllerProvider)
                .scheduleDayEndMinute,
            agendaEmptyBuilder: items.isLoading || coverageComplete != true
                ? (context) => const SizedBox.shrink()
                : (context) =>
                      Center(child: Text(context.l10n.noScheduleItems)),
          ),
        ),
        if (items.isLoading)
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(context.l10n.scheduleLoading),
                ],
              ),
            ),
          ),
        if (items.hasError && !items.hasValue)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Expanded(
                    child: _Message(
                      icon: Icons.error_outline,
                      title: context.l10n.scheduleUnavailable,
                      detail: '${items.error}',
                    ),
                  ),
                  TextButton(
                    onPressed: _retrySchedule,
                    child: Text(context.l10n.retry),
                  ),
                ],
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
    required bool? coverageComplete,
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
            onRefresh: () {
              final filters = criteria.filters(query);
              final range = criteria.range;
              if (range == null || !filters.requiresCalendarCoverage) {
                _retrySchedule();
                return Future.value();
              }
              return ref
                  .read(scheduleRepositoryProvider)
                  .retryCloudCoverage(range, filters);
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
              emptyBuilder: (context) => coverageComplete != true
                  ? const SizedBox.shrink()
                  : _Message(
                      icon: Icons.search_off,
                      title: !criteria.hasSources
                          ? context.l10n.searchNoSources
                          : context.l10n.scheduleNoMatchingItems,
                      detail: context.l10n.scheduleNoSearchResultsDescription,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _retrySchedule() {
    ref.invalidate(scheduleTaskListsForAccountProvider);
    ref.invalidate(scheduleTaskListsProvider);
    ref.invalidate(calendarSourcesStreamProvider);
    ref.invalidate(_androidScheduleItemsProvider);
  }

  Future<void> _browseTasks({TaskListEntity? list}) async {
    await _openSearch(focus: false);
    if (!mounted || _searchCriteria == null) {
      return;
    }
    List<TaskListEntity> lists;
    try {
      lists = await ref.read(scheduleTaskListsProvider.future);
    } on Object {
      lists = ref.read(scheduleTaskListsProvider).valueOrNull ?? const [];
    }
    if (!mounted) {
      return;
    }
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
    final accountId = request.accountId;
    final itemId = request.itemId;
    final item = request.task
        ? accountId == null || itemId == null
              ? null
              : await repository.findReminderTask(
                  accountId: accountId,
                  taskListId: request.taskListId!,
                  taskId: itemId,
                )
        : (await repository.listItems(
            range: ScheduleRange.day(request.date),
            filters: ScheduleFilters(
              accountIds: accountId == null ? const {} : {accountId},
              ignoreDateRange: true,
              includeTasks: false,
            ),
          )).where((item) => item.id == itemId).firstOrNull;
    if (!mounted) {
      return;
    }
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notificationItemUnavailable)),
      );
      return;
    }
    if (!request.task && _searching) {
      _closeSearch();
    }
    if (!request.task) {
      setState(() => _anchor = item.start ?? request.date);
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setAndroidScheduleViewMode(ScheduleViewMode.day);
    }
    if (request.task) {
      await _browseTasks();
    }
    if (mounted) {
      await _showItem(context, item);
    }
  }

  Future<void> _rescheduleEvent(
    ScheduleRescheduleRequest request,
    bool Function() isActive,
  ) async {
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
      ).commit(request, isActive: () => mounted && isActive());
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
    if (!mounted || generation != _searchRequestGeneration) {
      return;
    }
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: sources,
      taskLists: lists,
      journals:
          ref.read(scheduleJournalSourcesProvider).valueOrNull ?? const [],
      settings: ref.read(appSettingsControllerProvider),
    );
    final now = DateTime.now();
    setState(() {
      if (!_searching) {
        _searchAnchor = _anchor;
      }
      _initialSearchCriteria = ScheduleSearchCriteria(
        referenceDate: DateTime(now.year, now.month, now.day),
        firstWeekday: _firstWeekday(context),
        sourceIds: visibility.visibleCalendarSourceIds,
        taskListKeys: visibility.visibleTaskListKeys,
        journalSourceIds: visibility.visibleJournalSourceIds,
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

  Future<void> _refreshWorkspace() => refreshAndroidAccounts(context, ref);

  Widget _searchFilterPanel() => AndroidScheduleSearchFilters(
    value: _searchCriteria!,
    accounts: _searchAccounts(
      ref.watch(accountsStreamProvider).valueOrNull ?? const [],
    ),
    sources: ref.watch(calendarSourcesStreamProvider).valueOrNull ?? const [],
    taskLists: ref.watch(scheduleTaskListsProvider).valueOrNull ?? const [],
    journalSources:
        ref.watch(scheduleJournalSourcesProvider).valueOrNull ?? const [],
    onChanged: (value) => setState(() {
      _notificationDate = null;
      _allTaskLists = false;
      _searchCriteria = value;
    }),
    onClear: () => setState(() => _searchCriteria = _initialSearchCriteria),
  );

  List<AccountEntity> _searchAccounts(List<AccountEntity> accounts) {
    final settings = ref.read(appSettingsControllerProvider);
    return [
      for (final account in accounts)
        if (settings.isAccountVisibleInSchedule(account.id)) account,
    ];
  }

  Widget _navigationRow(
    BuildContext context,
    ScheduleViewMode mode,
    Widget? coverageWarning,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        IconButton(
          tooltip: context.l10n.today,
          icon: const Icon(Icons.today_outlined),
          onPressed: () => setState(() {
            _navigationDirection = 0;
            _anchor = DateTime.now();
          }),
        ),
        if (mode != ScheduleViewMode.agenda) ...[
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _movePeriod(mode, -1),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _movePeriod(mode, 1),
          ),
        ],
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?coverageWarning,
                Flexible(
                  child: PopupMenuButton<ScheduleViewMode>(
                    tooltip: context.l10n.viewSelector,
                    onSelected: (value) => unawaited(
                      ref
                          .read(appSettingsControllerProvider.notifier)
                          .setAndroidScheduleViewMode(value),
                    ),
                    itemBuilder: (context) => [
                      for (final value in ScheduleViewMode.values)
                        CheckedPopupMenuItem(
                          value: value,
                          checked: value == mode,
                          child: Text(_modeLabel(context, value)),
                        ),
                    ],
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _modeLabel(context, mode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.create,
          icon: const Icon(Icons.add),
          onPressed: _canCreateEvent || _canCreateTask || _canCreateJournal
              ? () => _createItem(context)
              : null,
        ),
      ],
    ),
  );

  bool get _canCreateEvent =>
      (ref.watch(calendarSourcesStreamProvider).valueOrNull ??
              const <CalendarSourceEntity>[])
          .any((source) => source.capabilities.canCreateEvents);
  bool get _canCreateTask =>
      (ref.watch(scheduleTaskListsProvider).valueOrNull ??
              const <TaskListEntity>[])
          .where(
            (list) => ref.watch(scheduleTaskListCreateEligibleProvider(list)),
          )
          .toList()
          .isNotEmpty;

  bool get _canCreateJournal =>
      (ref.watch(scheduleJournalSourcesProvider).valueOrNull ?? const []).any(
        (source) =>
            collectionCapabilitiesFromStored(source).canAttemptCreateJournal,
      );

  Future<void> _journalDialog(
    BuildContext context,
    JournalPaneAction action, {
    JournalScheduleItem? item,
    String? sourceId,
    String? accountId,
    DateTime? initialDate,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 640,
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                journalPaneTitle(context.l10n, action),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: JournalPane(
                action: action,
                item: item,
                sourceId: sourceId,
                accountId: accountId,
                initialDate: initialDate,
                controls: const MaterialJournalControls(),
                openScheduleItem: _openJournalScheduleReference,
                onRefresh: (scope) async {
                  final account = await ref
                      .read(accountsRepositoryProvider)
                      .accountById(scope.accountId!);
                  if (!context.mounted || account == null) return;
                  if (!await ensureAndroidLocalNetworkAccess(
                        context,
                        account.authority,
                      ) ||
                      !context.mounted) {
                    return;
                  }
                  await refreshFromAndroid(context, ref, scope);
                },
                files: const JournalFileActions(
                  read: _readJournalFile,
                  export: _exportJournalFile,
                  exportDraft: _exportJournalDraft,
                  pickAttachment: _pickJournalAttachment,
                  saveAttachment: _saveJournalAttachment,
                  exportCollection: _exportJournalCollection,
                ),
                onClose: () => Navigator.of(context).pop(),
                detailActions: (actions) => Wrap(
                  spacing: 4,
                  children: [
                    for (final action in actions)
                      IconButton(
                        tooltip: action.label,
                        icon: Icon(switch (action.icon) {
                          JournalDetailAction.share => Icons.share_outlined,
                          JournalDetailAction.edit => Icons.edit_outlined,
                          JournalDetailAction.delete => Icons.delete_outline,
                          JournalDetailAction.close => Icons.close,
                        }),
                        onPressed: action.run,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _movePeriod(ScheduleViewMode mode, int direction) {
    setState(() {
      _anchor = adjacentScheduleDate(_anchor, mode, direction);
      _navigationDirection = direction;
      _navigationGeneration += 1;
    });
  }

  Future<void> _showSearchFilters() async {
    if (_searchCriteria == null) {
      return;
    }
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
                  accounts: _searchAccounts(
                    ref.read(accountsStreamProvider).valueOrNull ?? const [],
                  ),
                  sources:
                      ref.read(calendarSourcesStreamProvider).valueOrNull ??
                      const [],
                  taskLists:
                      ref.read(scheduleTaskListsProvider).valueOrNull ??
                      const [],
                  journalSources:
                      ref.read(scheduleJournalSourcesProvider).valueOrNull ??
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
    compact: dismissOnNavigate,
    selectedDate: _anchor,
    onJournalAction: (action, sourceId, accountId) async {
      if (action == JournalPaneAction.createCollection ||
          action == JournalPaneAction.renameCollection ||
          action == JournalPaneAction.removeCollection) {
        final account = await ref
            .read(accountsRepositoryProvider)
            .accountById(accountId);
        if (!mounted ||
            account == null ||
            !await ensureAndroidLocalNetworkAccess(
              context,
              account.authority,
            )) {
          return;
        }
      }
      if (mounted) {
        await _journalDialog(
          context,
          action,
          sourceId: sourceId,
          accountId: accountId,
        );
      }
    },
    onNavigate: (date, mode) {
      if (dismissOnNavigate) {
        Navigator.pop(context);
      }
      setState(() => _anchor = date);
      unawaited(
        ref
            .read(appSettingsControllerProvider.notifier)
            .setAndroidScheduleViewMode(mode),
      );
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
    if (selected != null && mounted) {
      setState(() => _anchor = selected);
    }
  }

  Future<void> _createItem(
    BuildContext context, {
    DateTime? start,
    DateTime? end,
    String? itemType,
  }) async {
    final type =
        itemType ??
        await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(context.l10n.newEvent),
                  enabled: _canCreateEvent,
                  onTap: _canCreateEvent
                      ? () => Navigator.pop(context, 'event')
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(context.l10n.newTask),
                  enabled: _canCreateTask,
                  onTap: _canCreateTask
                      ? () => Navigator.pop(context, 'task')
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.book_outlined),
                  title: Text(context.l10n.newJournalEntry),
                  enabled: _canCreateJournal,
                  onTap: _canCreateJournal
                      ? () => Navigator.pop(context, 'journal')
                      : null,
                ),
              ],
            ),
          ),
        );
    if (!context.mounted || type == null) {
      return;
    }
    if (type == 'journal') {
      await _journalDialog(
        context,
        JournalPaneAction.create,
        initialDate: start,
      );
      return;
    }
    if (type == 'event') {
      await _createEvent(context, start: start, end: end);
      return;
    }
    final lists =
        (ref.read(scheduleTaskListsProvider).valueOrNull ??
                const <TaskListEntity>[])
            .where(
              (list) => ref.read(scheduleTaskListCreateEligibleProvider(list)),
            )
            .toList();
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
    if (list == null || !context.mounted) {
      return;
    }
    final account = accounts
        .where((value) => value.id == list.accountId)
        .firstOrNull;
    if (account == null) {
      return;
    }
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
    if (result == null) {
      return;
    }
  }

  Future<void> _openJournalScheduleReference(
    BuildContext context,
    ScheduleWorkspaceCommand command,
  ) async {
    final repository = ref.read(scheduleRepositoryProvider);
    final filters = ScheduleFilters(
      accountIds: {if (command.accountId case final account?) account},
      taskCompletion: ScheduleTaskCompletion.all,
      showNoDateTasks: true,
    );
    final items = command.kind == ScheduleWorkspaceCommandKind.openTask
        ? await repository.listAllTasks(filters: filters)
        : await repository.listItems(
            range: ScheduleRange.day(command.date ?? DateTime.now()),
            filters: filters,
          );
    if (!context.mounted) return;
    final item = items.where(command.matchesItem).singleOrNull;
    if (item != null) {
      await _showItem(context, item);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.scheduleUnavailable)));
    }
  }

  Future<void> _showItem(BuildContext context, ScheduleItem item) async {
    if (item is JournalScheduleItem) {
      await _journalDialog(context, JournalPaneAction.open, item: item);
      return;
    }
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
    if (!_openDetails.add(identity)) {
      return;
    }
    final location = resolveSavedScheduleLocation(
      item: item,
      repository: ref.read(locationResolutionRepositoryProvider),
    );
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item is CalendarScheduleItem
                            ? Icons.calendar_today_outlined
                            : Icons.checklist_outlined,
                        color: ScheduleProjection.colorForItem(
                          item,
                          Theme.of(context).brightness,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              item is CalendarScheduleItem
                                  ? context.l10n.createEventAtTime
                                  : context.l10n.createTaskAtDate,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IconButton(
                        tooltip: context.l10n.export,
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () => _exportItem(sheetContext, item),
                      ),
                      if (item.capabilities.canEdit || item is TaskScheduleItem)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: item is CalendarScheduleItem
                              ? context.l10n.editEvent
                              : item.capabilities.canEdit
                              ? context.l10n.editTask
                              : context.l10n.taskDetails,
                          onPressed: () async {
                            if (editing) {
                              return;
                            }
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
                              if (result == null) {
                                return;
                              }
                            }
                          },
                        ),
                      if (item.capabilities.canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: switch (item) {
                            CalendarScheduleItem(isNextcloudAttendee: true) =>
                              context.l10n.nextcloudDeclineAndRemove,
                            CalendarScheduleItem(
                              isNextcloudMeeting: true,
                              isOrganizer: true,
                            ) =>
                              context.l10n.nextcloudCancelMeeting,
                            _ => context.l10n.delete,
                          },
                          onPressed: () async {
                            if (await _deleteItem(item) &&
                                sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
                        ),
                      IconButton(
                        tooltip: context.l10n.close,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  if (item is CalendarScheduleItem && item.canReschedule)
                    TextButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(context.l10n.moveEvent),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        unawaited(
                          showAndroidEventTimingActions(
                            context,
                            item,
                            (request) =>
                                _rescheduleEvent(request, () => mounted),
                          ),
                        );
                      },
                    ),
                  if (item is CalendarScheduleItem) ...[
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
                  ],
                  if (item is CalendarScheduleItem &&
                      item.canRespondToInvitation) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                item.currentUserResponse?.toLowerCase() ==
                                    'accepted'
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
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
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                const [
                                  'tentative',
                                  'tentativelyaccepted',
                                ].contains(
                                  item.currentUserResponse?.toLowerCase(),
                                )
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
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
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                item.currentUserResponse?.toLowerCase() ==
                                    'declined'
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
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
                  const SizedBox(height: 8),
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
                  Text(
                    '${item.sourceName ?? item.provider.displayName} · ${item.accountEmail ?? item.accountDisplayName ?? item.accountId}',
                  ),
                  if (item is CalendarScheduleItem) ...[
                    for (final line in googleStatusDetailLines(
                      context.l10n,
                      item.eventType,
                      item.googleStatusProperties,
                    ))
                      Text(line),
                    FutureBuilder<ExternalLocationDestination?>(
                      future: location,
                      initialData: projectedScheduleItemLocationDestination(
                        item,
                      ),
                      builder: (context, snapshot) {
                        final destination = snapshot.data;
                        if (destination == null) {
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place),
                          title: Text(
                            savedScheduleLocationDisplayText(item, destination),
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () async {
                            try {
                              final resolved = await location;
                              final result =
                                  await const ExternalLocationLauncher(
                                    platform: _androidLocationPlatform,
                                  ).open(resolved);
                              if (result ==
                                  ExternalLocationLaunchResult.opened) {
                                return;
                              }
                            } on Object {
                              /* Report failed external handoff below. */
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    this
                                        .context
                                        .l10n
                                        .externalLocationOpenFailed,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
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
                    if (item.isNextcloudAttendee)
                      Text(context.l10n.nextcloudAttendeeRestrictions),
                    if (item.mayNotifyParticipants)
                      Text(context.l10n.caldavSchedulingWarning),
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
                    for (final minutes in item.reminderMinutesBeforeStart)
                      Text(
                        '${context.l10n.reminder}: ${context.l10n.reminderMinutesBefore(minutes)}',
                      ),
                    if (item.categories.isNotEmpty)
                      Text(
                        '${context.l10n.categories}: ${item.categories.join(', ')}',
                      ),
                    if (calendarEventDescription(item).trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _AndroidEventDescription(item: item),
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
                    for (final uri in calendarEventDescriptionLinks(item))
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          unawaited(_openEventWebLink(uri.toString()));
                        },
                        child: Text(uri.toString()),
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
                  ],
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
                    if (item.categories.isNotEmpty)
                      Text(
                        '${context.l10n.categories}: ${item.categories.join(', ')}',
                      ),
                    FutureBuilder<ExternalLocationDestination?>(
                      future: location,
                      initialData: projectedScheduleItemLocationDestination(
                        item,
                      ),
                      builder: (context, snapshot) {
                        final destination = snapshot.data;
                        if (destination == null) {
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place),
                          title: Text(
                            savedScheduleLocationDisplayText(item, destination),
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () async {
                            try {
                              final resolved = await location;
                              final result =
                                  await const ExternalLocationLauncher(
                                    platform: _androidLocationPlatform,
                                  ).open(resolved);
                              if (result ==
                                  ExternalLocationLaunchResult.opened) {
                                return;
                              }
                            } on Object {
                              /* Report failed external handoff below. */
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    this
                                        .context
                                        .l10n
                                        .externalLocationOpenFailed,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                    if (item case TaskScheduleItem(:final notes?)
                        when notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(notes),
                      ),
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
    if (!item.capabilities.canDelete) {
      return false;
    }
    try {
      RecurringEventMutationScope? scope;
      if (item is CalendarScheduleItem &&
          item.providerRecurringEventId != null) {
        final detail = await ref
            .read(calendarRepositoryProvider)
            .loadEventDetail(item.id);
        if (!mounted || detail == null) {
          return false;
        }
        scope = await showAndroidRecurringScope(
          context,
          supportsFollowing:
              !item.isNextcloudAttendee &&
              eventSupportsThisAndFollowing(detail),
        );
        if (scope == null || !mounted) {
          return false;
        }
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
        if (result == null || !mounted) {
          return false;
        }
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
        if (confirmed != true || !mounted) {
          return false;
        }
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
    if (await openScheduleWebLink(value) || !mounted) {
      return;
    }
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
        if (!mounted || !context.mounted) {
          return;
        }
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
        if (series == null) {
          return;
        }
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
      if (raw == null) {
        return;
      }
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
    if (source == null || !context.mounted) {
      return;
    }
    start ??= DateTime(_anchor.year, _anchor.month, _anchor.day, 9);
    final zone = source.provider.isDav
        ? await BusyMaxAndroidPlatform.instance.currentTimeZoneId()
        : null;
    if (!context.mounted) {
      return;
    }
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
          ).copyWith(startTimeZone: zone, endTimeZone: zone),
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
    if (!item.canRespondToInvitation) {
      return;
    }
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
        if (scope == null || !mounted) {
          return;
        }
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
      if (!mounted) {
        return;
      }
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
    if (!task.capabilities.canEdit || !_taskMutationsInFlight.add(key)) {
      return;
    }
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
      if (mounted) {
        setState(() => _taskMutationsInFlight.remove(key));
      }
    }
  }

  void _consumeTaskMutation(TaskListMutationIntent intent) {
    if (!mounted) {
      return;
    }
    if (_taskMutationIntent?.generation == intent.generation) {
      setState(() => _taskMutationIntent = null);
    }
  }

  void _consumeEditorResult(AndroidTaskEditorResult result) {
    if (!mounted) {
      return;
    }
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
    if (mounted) {
      setState(() => _taskMutationIntent = null);
    }
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
  if (!context.mounted || detail == null) {
    return;
  }
  final sources = await ref.read(calendarSourcesStreamProvider.future);
  if (!context.mounted) {
    return;
  }
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
    required this.onJournalAction,
    this.compact = false,
  });
  final bool compact;
  final DateTime selectedDate;
  final void Function(DateTime, ScheduleViewMode) onNavigate;
  final Future<void> Function(JournalPaneAction, String?, String)
  onJournalAction;

  @override
  ConsumerState<_AndroidSourcesPane> createState() =>
      _AndroidSourcesPaneState();
}

class _AndroidSourcesPaneState extends ConsumerState<_AndroidSourcesPane> {
  DateTime? _month;
  final _accountDisclosures = <String, ExpansibleController>{};
  final _creatingCalendarAccounts = <String>{};
  final _creatingTaskListAccounts = <String>{};
  @override
  void dispose() {
    for (final controller in _accountDisclosures.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AndroidSourcesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _month = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    }
  }

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
    final authAccounts = orderedAccounts
        .where((account) => !account.isSubscription)
        .toList();
    final subscriptionsState = ref.watch(sidebarSubscriptionSourcesProvider);
    final subscriptions = settings.sidebarOrder.apply(
      SidebarOrderSection.subscriptions,
      calendarSourcesShownInSidebar(subscriptionsState.valueOrNull ?? const []),
      (source) => source.id,
    );
    final month =
        _month ?? DateTime(widget.selectedDate.year, widget.selectedDate.month);
    final monthItems =
        ref
            .watch(
              scheduleMiniCalendarItemsProvider((
                month: month,
                firstWeekday: _firstWeekday(context),
              )),
            )
            .valueOrNull ??
        const <ScheduleItem>[];
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.compact
                  ? constraints.maxHeight * .52
                  : constraints.maxHeight - 220,
            ),
            child: SingleChildScrollView(
              child: MiniCalendar(
                selectedDate: widget.selectedDate,
                firstWeekday: _firstWeekday(context),
                items: monthItems,
                onDisplayedMonthChanged: (date) =>
                    setState(() => _month = date),
                onSelected: (date) =>
                    widget.onNavigate(date, ScheduleViewMode.day),
                onMonthSelected: (date) =>
                    widget.onNavigate(date, ScheduleViewMode.month),
                onYearSelected: (date) =>
                    widget.onNavigate(date, ScheduleViewMode.year),
                onWeekSelected: (date) =>
                    widget.onNavigate(date, ScheduleViewMode.week),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BusyMaxDimensions.sidebarRowInset,
                0,
                BusyMaxDimensions.sidebarRowInset,
                BusyMaxSpacing.xLarge,
              ),
              children: [
                if (accounts.isLoading) const LinearProgressIndicator(),
                if (accounts.hasError)
                  ListTile(title: Text(context.l10n.scheduleUnavailable)),
                for (final account in authAccounts)
                  _account(account, authAccounts),
                if (subscriptions.isNotEmpty ||
                    subscriptionsState.isLoading) ...[
                  ListTile(title: Text(context.l10n.subscriptions)),
                  if (subscriptionsState.isLoading)
                    const LinearProgressIndicator(),
                  for (final source in subscriptions)
                    _calendarSource(
                      source,
                      SidebarOrderSection.subscriptions,
                      subscriptions.map((source) => source.id).toList(),
                    ),
                ],
                if (accounts.hasValue &&
                    !accounts.isLoading &&
                    !accounts.hasError &&
                    authAccounts.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: Text(context.l10n.addAccount),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const AndroidSettingsScreen(
                          category: AndroidSettingsCategory.accounts,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
      (listsState.valueOrNull ?? const <TaskListEntity>[]).where(
        (list) => !list.pendingDelete,
      ),
      (l) => l.id,
      accountId: account.id,
    );
    final journals = settings.sidebarOrder.apply(
      SidebarOrderSection.journals,
      (ref.watch(scheduleJournalSourcesProvider).valueOrNull ?? const []).where(
        (source) => source.accountId == account.id,
      ),
      (source) => source.id,
      accountId: account.id,
    );
    final disclosure = _accountDisclosures.putIfAbsent(
      account.id,
      ExpansibleController.new,
    );
    final networkAvailability =
        ref.watch(networkAvailabilityProvider).valueOrNull ??
        ref.read(networkConnectivityMonitorProvider).availability;
    final capabilities = AccountCollectionCreationCapabilities.resolve(
      account: account,
      networkAvailability: networkAvailability,
      calendarCreationRunning: _creatingCalendarAccounts.contains(account.id),
      taskListCreationRunning: _creatingTaskListAccounts.contains(account.id),
    );
    final invitations = account.provider == BusyProvider.nextcloud
        ? ref
                  .watch(nextcloudPendingInvitationCountProvider(account.id))
                  .valueOrNull ??
              0
        : 0;
    final secondaryLabel = scheduleAccountSecondaryLabel(account);
    final subtitle = [
      if (secondaryLabel != null) secondaryLabel,
      if (invitations > 0)
        '${context.l10n.nextcloudFederationInvitations} ($invitations)',
    ].join('\n');
    final visibility = ScheduleAccountVisibility.fromSources(
      accountId: account.id,
      settings: settings,
      calendars: account.calendarsEnabled
          ? sources
          : const <CalendarSourceEntity>[],
      taskLists: lists,
      journals: journals,
    );
    final visible = visibility != ScheduleAccountVisibility.hidden;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final tile = ExpansionTile(
      key: ValueKey(('schedule-account', account.id)),
      controller: disclosure,
      initiallyExpanded: true,
      maintainState: false,
      tilePadding: EdgeInsets.zero,
      leading: ScheduleSidebarVisibilityIcon(
        key: ValueKey(('account-visibility', account.id)),
        scope: accountSyncScope(account.id),
        label: '${account.provider.displayName}, ${account.displayLabel}',
        actionLabel: scheduleAccountVisibilityAction(context, visibility),
        visible: visible,
        accountVisibility: visibility,
        color: color,
        buttonBuilder: _androidSidebarVisibilityButton,
        warningIcon: Icons.warning_amber_rounded,
        ringSize: 24,
        icon: Icon(
          account.provider == BusyProvider.google
              ? Icons.g_mobiledata
              : account.provider == BusyProvider.microsoft
              ? Icons.window
              : Icons.cloud_outlined,
          color: color,
          size: 18,
        ),
        onPressed: () => unawaited(
          ref
              .read(appSettingsControllerProvider.notifier)
              .setAccountVisibleInSchedule(
                accountId: account.id,
                visible: !visible,
              ),
        ),
      ),
      title: Text(
        account.displayLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: disclosure,
            builder: (context, _) => IconButton(
              key: ValueKey(('account-collapse', account.id)),
              style: _androidSidebarTrailingStyle,
              tooltip: disclosure.isExpanded
                  ? MaterialLocalizations.of(context).expandedIconTapHint
                  : MaterialLocalizations.of(context).collapsedIconTapHint,
              icon: _androidSidebarActionIcon(
                Icon(
                  disclosure.isExpanded
                      ? Icons.expand_more
                      : Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                ),
              ),
              onPressed: disclosure.toggle,
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.xSmall),
          PopupMenuButton<String>(
            key: ValueKey(('account-collection-options', account.id)),
            style: _androidSidebarTrailingStyle,
            icon: _androidSidebarActionIcon(Icon(Icons.adaptive.more)),
            tooltip: context.l10n.options,
            onSelected: (action) async {
              if (action == 'refresh') {
                if (account.provider.isDav &&
                    !await ensureAndroidLocalNetworkAccess(
                      context,
                      account.authority,
                    )) {
                  return;
                }
                if (mounted) {
                  await refreshFromAndroid(
                    context,
                    ref,
                    accountSyncScope(account.id),
                  );
                }
              } else if (action == 'calendar' || action == 'task-list') {
                final running = action == 'calendar'
                    ? _creatingCalendarAccounts
                    : _creatingTaskListAccounts;
                if (!running.add(account.id)) return;
                setState(() {});
                try {
                  await createAndroidAccountCollection(
                    context,
                    ref,
                    account,
                    calendar: action == 'calendar',
                  );
                } finally {
                  running.remove(account.id);
                  if (mounted) setState(() {});
                }
              } else if (action == 'journal') {
                await widget.onJournalAction(
                  JournalPaneAction.createCollection,
                  null,
                  account.id,
                );
              } else if (action == 'settings') {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        AndroidSettingsScreen(accountDetailId: account.id),
                  ),
                );
              } else if (action == 'trash') {
                if (context.mounted) {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AndroidNextcloudTrashScreen(accountId: account.id),
                    ),
                  );
                }
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
              if (capabilities.supportsCalendarCreation)
                _androidAccountMenuItem(
                  'calendar',
                  context.l10n.newCalendar,
                  const SizedBox.square(
                    dimension: 24,
                    child: Stack(
                      alignment: AlignmentDirectional.topStart,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 18),
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: Icon(Icons.add, size: 13),
                        ),
                      ],
                    ),
                  ),
                  enabled: capabilities.calendarActionEnabled,
                ),
              if (capabilities.supportsTaskListCreation)
                _androidAccountMenuItem(
                  'task-list',
                  context.l10n.newTaskList,
                  const Icon(Icons.playlist_add),
                  enabled: capabilities.taskListActionEnabled,
                ),
              if (capabilities.supportsJournalCreation)
                _androidAccountMenuItem(
                  'journal',
                  context.l10n.newJournalSource,
                  const Icon(Icons.book_outlined),
                  enabled: capabilities.journalActionEnabled,
                ),
              if (capabilities.supportsCalendarCreation ||
                  capabilities.supportsTaskListCreation ||
                  (capabilities.supportsJournalCreation))
                const PopupMenuDivider(),
              _androidAccountMenuItem(
                'refresh',
                context.l10n.refreshAccount,
                const Icon(Icons.refresh),
              ),
              _androidAccountMenuItem(
                'settings',
                context.l10n.scheduleAccountSettings,
                const Icon(Icons.settings_outlined),
              ),
              if (account.provider == BusyProvider.nextcloud)
                _androidAccountMenuItem(
                  'trash',
                  context.l10n.nextcloudTrash,
                  const Icon(Icons.delete_outline),
                  enabled: networkAvailability != NetworkAvailability.offline,
                ),
              const PopupMenuDivider(),
              _androidAccountMenuItem(
                'up',
                context.l10n.moveUp,
                const Icon(Icons.arrow_upward),
                enabled: accounts.indexOf(account) > 0,
              ),
              _androidAccountMenuItem(
                'down',
                context.l10n.moveDown,
                const Icon(Icons.arrow_downward),
                enabled: accounts.indexOf(account) < accounts.length - 1,
              ),
            ],
          ),
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
        if (!account.calendarsEnabled)
          ListTile(
            title: Text('${context.l10n.calendars} · ${context.l10n.off}'),
          ),
        if (account.calendarsEnabled &&
            sources.isEmpty &&
            !sourcesState.isLoading &&
            !sourcesState.hasError)
          ListTile(title: Text(context.l10n.noCalendarsSynced)),
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
            leading: _taskListVisibility(list),
            title: Text(
              list.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _orderMenu(
              SidebarOrderSection.taskLists,
              list.id,
              lists.map((l) => l.id).toList(),
              account.id,
              (extra) => showAndroidTaskListActions(
                context,
                ref,
                list,
                accounts,
                extraActions: extra,
              ),
            ),
          ),
        for (final journal in journals)
          _journalSource(
            journal,
            account,
            journals.map((row) => row.id).toList(),
          ),
      ],
    );
    return ListTileTheme.merge(
      horizontalTitleGap: BusyMaxSpacing.small,
      child: tile,
    );
  }

  Widget _journalSource(
    DavCollection journal,
    AccountEntity account,
    List<String> siblings,
  ) {
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsControllerProvider);
    final visible =
        settings.isAccountVisibleInSchedule(account.id) &&
        journal.journalsSelected;
    final accountVisible = settings.isAccountVisibleInSchedule(account.id);
    final color = _journalSourceColor(
      journal.color,
      journal.id,
      Theme.of(context).brightness,
    );
    final scope = davCollectionSyncScope(account.id, journal.id);
    final caps = collectionCapabilitiesFromStored(journal);
    final collection = ref
        .watch(davCollectionsStreamProvider)
        .valueOrNull
        ?.where((row) => row.id == journal.id)
        .firstOrNull;
    return ListTile(
      key: ValueKey(('schedule-journal', journal.id)),
      contentPadding: EdgeInsets.zero,
      title: Text(
        journal.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: ScheduleSidebarVisibilityIcon(
        key: ValueKey(('journal-visibility', journal.id)),
        scope: scope,
        label: journal.displayName,
        actionLabel: visible ? l10n.hide : l10n.show,
        visible: visible,
        color: color,
        buttonBuilder: _androidSidebarVisibilityButton,
        warningIcon: Icons.warning_amber_rounded,
        ringSize: 24,
        icon: Icon(Icons.book_outlined, color: color, size: 18),
        onPressed: accountVisible
            ? () => unawaited(
                ref
                    .read(davSettingsRepositoryProvider)
                    .setJournalsSelected(journal.id, !visible),
              )
            : null,
      ),
      trailing: PopupMenuButton<String>(
        key: ValueKey(('journal-options', journal.id)),
        tooltip: l10n.options,
        style: _androidSidebarTrailingStyle,
        icon: _androidSidebarActionIcon(Icon(Icons.adaptive.more)),
        itemBuilder: (_) => [
          _androidAccountMenuItem(
            'refresh',
            l10n.refresh,
            const Icon(Icons.refresh),
          ),
          _androidAccountMenuItem(
            'rename',
            l10n.rename,
            const Icon(Icons.edit_outlined),
            enabled: caps.canMutateCollection,
          ),
          _androidAccountMenuItem(
            'import',
            l10n.importIcsFile,
            const Icon(Icons.file_open_outlined),
            enabled:
                caps.canAttemptCreateJournal || caps.canAttemptUpdateJournal,
          ),
          _androidAccountMenuItem(
            'export',
            l10n.export,
            const Icon(Icons.share_outlined),
          ),
          _androidAccountMenuItem(
            'delete',
            l10n.journalDeleteCollection,
            const Icon(Icons.delete_outline),
            enabled: collection?.canRemoveCollection == true,
          ),
          _androidAccountMenuItem(
            'up',
            l10n.moveUp,
            const Icon(Icons.arrow_upward),
            enabled: siblings.indexOf(journal.id) > 0,
          ),
          _androidAccountMenuItem(
            'down',
            l10n.moveDown,
            const Icon(Icons.arrow_downward),
            enabled: siblings.indexOf(journal.id) < siblings.length - 1,
          ),
        ],
        onSelected: (value) async {
          if (value == 'refresh') {
            if (!await ensureAndroidLocalNetworkAccess(
                  context,
                  account.authority,
                ) ||
                !mounted) {
              return;
            }
            await refreshFromAndroid(context, ref, scope);
          } else if (value == 'up' || value == 'down') {
            await ref
                .read(appSettingsControllerProvider.notifier)
                .moveSidebarItem(
                  SidebarOrderSection.journals,
                  journal.id,
                  value == 'up' ? -1 : 1,
                  siblings,
                  accountId: account.id,
                );
          } else {
            await widget.onJournalAction(
              switch (value) {
                'rename' => JournalPaneAction.renameCollection,
                'import' => JournalPaneAction.import,
                'delete' => JournalPaneAction.removeCollection,
                _ => JournalPaneAction.exportCollection,
              },
              journal.id,
              account.id,
            );
          }
        },
      ),
    );
  }

  Color _journalSourceColor(String? value, String id, Brightness brightness) {
    final hex = value == null
        ? null
        : int.tryParse(value.replaceFirst('#', ''), radix: 16);
    return hex == null
        ? ScheduleProjection.deterministicSourceColor(id, brightness)
        : Color(0xff000000 | hex);
  }

  Widget _taskListVisibility(TaskListEntity list) {
    final settings = ref.watch(appSettingsControllerProvider);
    final accountVisible = settings.isAccountVisibleInSchedule(list.accountId);
    final visible =
        accountVisible &&
        settings.isTaskListVisibleInSchedule(list.accountId, list.id);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return ScheduleSidebarVisibilityIcon(
      key: ValueKey(('task-list-visibility', list.accountId, list.id)),
      scope: taskListSyncScope(list.accountId, list.id),
      label: list.title,
      actionLabel: scheduleCollectionVisibilityAction(
        context,
        calendar: false,
        accountVisible: accountVisible,
        visible: visible,
      ),
      visible: visible,
      color: color,
      buttonBuilder: _androidSidebarVisibilityButton,
      warningIcon: Icons.warning_amber_rounded,
      ringSize: 24,
      icon: Icon(Icons.checklist_outlined, color: color, size: 18),
      onPressed: accountVisible
          ? () => unawaited(
              ref
                  .read(appSettingsControllerProvider.notifier)
                  .setTaskListVisibleInSchedule(
                    accountId: list.accountId,
                    taskListId: list.id,
                    visible: !visible,
                  ),
            )
          : null,
    );
  }

  Widget _calendarSource(
    CalendarSourceEntity source,
    SidebarOrderSection section,
    List<String> siblings, {
    String? accountId,
  }) {
    final color = _androidSourceColor(source, Theme.of(context).brightness);
    final accountVisible = ref
        .watch(appSettingsControllerProvider)
        .isAccountVisibleInSchedule(source.accountId);
    final visible = accountVisible && source.selected;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: BusyMaxSpacing.small,
      leading: ScheduleSidebarVisibilityIcon(
        key: ValueKey(('calendar-visibility', source.id)),
        scope: calendarSyncScope(source.accountId, source.id),
        label: source.summary,
        actionLabel: scheduleCollectionVisibilityAction(
          context,
          calendar: true,
          accountVisible: accountVisible,
          visible: visible,
        ),
        visible: visible,
        color: color,
        buttonBuilder: _androidSidebarVisibilityButton,
        warningIcon: Icons.warning_amber_rounded,
        ringSize: 24,
        icon: Icon(Icons.calendar_today_outlined, color: color, size: 18),
        onPressed: accountVisible
            ? () => unawaited(
                ref
                    .read(calendarRepositoryProvider)
                    .setSourceSelected(source.id, !visible),
              )
            : null,
      ),
      title: Text(source.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _orderMenu(
        section,
        source.id,
        siblings,
        accountId,
        (extra) => showAndroidCalendarSourceActions(
          context,
          ref,
          source,
          extraActions: extra,
        ),
      ),
    );
  }

  Widget _orderMenu(
    SidebarOrderSection section,
    String id,
    List<String> siblings,
    String? accountId,
    void Function(List<Widget> Function(BuildContext)) actions,
  ) => IconButton(
    tooltip: context.l10n.options,
    style: _androidSidebarTrailingStyle,
    icon: _androidSidebarActionIcon(const Icon(Icons.more_vert)),
    onPressed: () => actions(
      (sheetContext) => [
        for (final direction in [-1, 1])
          ListTile(
            leading: Icon(
              direction < 0 ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            title: Text(
              direction < 0 ? context.l10n.moveUp : context.l10n.moveDown,
            ),
            enabled: direction < 0
                ? siblings.indexOf(id) > 0
                : siblings.indexOf(id) < siblings.length - 1,
            onTap: () {
              Navigator.pop(sheetContext);
              unawaited(
                ref
                    .read(appSettingsControllerProvider.notifier)
                    .moveSidebarItem(
                      section,
                      id,
                      direction,
                      siblings,
                      accountId: accountId,
                    ),
              );
            },
          ),
      ],
    ),
  );
}

// Align the artwork at the outer end of each 48 dp touch target.
const _androidSidebarButtonStyle = ButtonStyle(
  fixedSize: WidgetStatePropertyAll(Size.square(kMinInteractiveDimension)),
  padding: WidgetStatePropertyAll(EdgeInsets.zero),
);

final _androidSidebarLeadingStyle = _androidSidebarButtonStyle.copyWith(
  alignment: AlignmentDirectional.centerStart,
);

final _androidSidebarTrailingStyle = _androidSidebarButtonStyle.copyWith(
  alignment: AlignmentDirectional.centerEnd,
);

Widget _androidSidebarActionIcon(Widget icon) => SizedBox(
  width: BusyMaxDimensions.sidebarActionWidth,
  child: Center(heightFactor: 1, child: icon),
);

Widget _androidSidebarVisibilityButton(
  BuildContext context,
  Widget icon,
  String tooltip,
  VoidCallback? onPressed,
) => IconButton(
  tooltip: tooltip,
  icon: _androidSidebarActionIcon(icon),
  onPressed: onPressed,
  iconSize: 28,
  style: _androidSidebarLeadingStyle,
);

PopupMenuItem<String> _androidAccountMenuItem(
  String value,
  String label,
  Widget icon, {
  bool enabled = true,
}) => PopupMenuItem(
  value: value,
  enabled: enabled,
  child: Row(
    children: [
      SizedBox.square(dimension: 24, child: Center(child: icon)),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
    ],
  ),
);

Color _androidSourceColor(CalendarSourceEntity source, Brightness brightness) {
  final color = calendarSourceBackgroundColorHex(
    provider: source.provider,
    colorId: source.colorId,
    backgroundColor: source.backgroundColor,
  );
  final value = int.tryParse((color ?? '').replaceFirst('#', ''), radix: 16);
  return value == null
      ? ScheduleProjection.deterministicSourceColor(source.id, brightness)
      : Color(0xff000000 | value);
}

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
    this.agendaRange,
    required this.canCreateEvent,
    required this.canCreateTask,
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
  final ScheduleRescheduleCallback onReschedule;
  final TaskListMutationIntent? taskMutationIntent;
  final Set<String> taskMutationsInFlight;
  final ValueChanged<TaskListMutationIntent>? onTaskMutationConsumed;
  final WidgetBuilder? agendaEmptyBuilder;
  final ScheduleAgendaPage? agendaPage;
  final ScheduleRange? agendaRange;
  final bool canCreateEvent, canCreateTask;
  final VoidCallback? onLoadMore, onLoadMoreOverdue, onLoadMoreNoDate;

  @override
  Widget build(BuildContext context) => BusyMaxKeyedCrossfade(
    transitionKey: mode,
    child: switch (mode) {
      ScheduleViewMode.month => GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 150) {
            return;
          }
          onSelectDate(
            adjacentScheduleDate(anchor, mode, velocity < 0 ? 1 : -1),
          );
        },
        child: ScheduleMonthView(
          key: const ValueKey('android-month-grid'),
          range: ScheduleRange.month(
            anchor,
            firstWeekday: _firstWeekday(context),
          ),
          selectedDate: anchor,
          items: items,
          firstWeekday: _firstWeekday(context),
          onDaySelected: onSelectDate,
          onCreateAtDay: (date, {anchorContext}) =>
              onCreate(DateTime(date.year, date.month, date.day, 9), null),
          onItemSelected: (_, item, [position]) => onOpen(item),
          onTaskCompletionChanged: (task, completed) => onToggleTask(task),
          onReschedule: onReschedule,
          onShowMore: (context, day, items) =>
              _showAndroidDayItems(context, day, items, onOpen, onToggleTask),
        ),
      ),
      ScheduleViewMode.year => GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() >= 150) {
            onSelectDate(
              adjacentScheduleDate(anchor, mode, velocity < 0 ? 1 : -1),
            );
          }
        },
        child: ScheduleYearView(
          key: const ValueKey('android-year-grid'),
          selectedDate: anchor,
          items: items,
          firstWeekday: _firstWeekday(context),
          onDaySelected: (date) {
            onSelectDate(date);
            onModeChanged(ScheduleViewMode.day);
          },
          onMonthSelected: (date) {
            onSelectDate(date);
            onModeChanged(ScheduleViewMode.month);
          },
          onWeekSelected: (date) {
            onSelectDate(date);
            onModeChanged(ScheduleViewMode.week);
          },
          onCreateAtDay: (date) =>
              onCreate(DateTime(date.year, date.month, date.day, 9), null),
        ),
      ),
      ScheduleViewMode.week || ScheduleViewMode.day => ScheduleDayWeekView(
        key: ValueKey('android-${mode.name}-time-grid'),
        range: _rangeFor(anchor, mode, firstWeekday: _firstWeekday(context)),
        selectedDate: anchor,
        daysShowed: mode == ScheduleViewMode.day ? 1 : 7,
        items: items,
        onDaySelected: onSelectDate,
        onEmptySlot: (date) => onCreate(date, null),
        onRangeCreated: canCreateEvent
            ? (interval) => onCreate(interval.start, interval.end)
            : null,
        onItemSelected: (_, item, [position]) => onOpen(item),
        onTaskCompletionChanged: (task, completed) => onToggleTask(task),
        dayStartMinute: dayStartMinute,
        dayEndMinute: dayEndMinute,
        onReschedule: onReschedule,
      ),
      ScheduleViewMode.agenda => _AgendaList(
        key: const PageStorageKey('android-agenda'),
        range: agendaRange,
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
    this.range,
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
  final ScheduleRange? range;
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
  Widget build(BuildContext context) => ScheduleAgendaView(
    range:
        searchCriteria?.range ??
        range ??
        ScheduleRange.days(DateTime.now(), count: 30),
    items: items,
    searchCriteria: searchCriteria,
    searchQuery: searchQuery,
    onItemSelected: (_, item, [position]) => onOpen(item),
    onTaskCompletionChanged: (task, completed) {
      if (task.completed != completed &&
          !taskMutationsInFlight.contains(
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}',
          )) {
        onToggleTask(task);
      }
    },
    onChecklistItemCompletionChanged: (parent, step, completed) {
      if (step.completed != completed) {
        onToggleChecklist?.call(parent, step);
      }
    },
    taskListMutationIntent: taskMutationIntent,
    onTaskListMutationConsumed: onTaskMutationConsumed,
    emptyBuilder:
        emptyBuilder ??
        (context) => Center(child: Text(context.l10n.noScheduleItems)),
    hasMoreOverdueTasks: hasMoreOverdue,
    hasMoreNoDateTasks: hasMoreNoDate,
    onLoadMore: onLoadMore,
    onLoadMoreOverdue: onLoadMoreOverdue,
    onLoadMoreNoDate: onLoadMoreNoDate,
  );
}

Future<void> _showAndroidDayItems(
  BuildContext context,
  DateTime day,
  List<ScheduleItem> items,
  ValueChanged<ScheduleItem> onOpen,
  ValueChanged<TaskScheduleItem> onToggleTask,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .7,
      child: Consumer(
        builder: (context, ref, _) {
          final current =
              ref
                  .watch(
                    _androidScheduleItemsProvider((
                      anchor: day,
                      mode: ScheduleViewMode.day,
                      query: '',
                      search: null,
                      firstWeekday: _firstWeekday(context),
                      agendaDays: 30,
                      overdueLimit: 8,
                      noDateLimit: 8,
                      notificationDate: null,
                    )),
                  )
                  .valueOrNull
                  ?.items ??
              items;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  DateFormat.yMMMMEEEEd(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: current.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = current[index];
                    return ListTile(
                      leading: SchedulePresentation.of(context).itemLeading(
                        context,
                        item,
                        (task, _) => onToggleTask(task),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          decoration: item is TaskScheduleItem && item.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        item.sourceName ?? item.provider.displayName,
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onOpen(item);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);

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
  final _guestInput = TextEditingController();
  bool _addingGuest = false;
  String? _guestError;
  final Map<String, bool> _guestOptionalOverrides = {};
  final Map<String, String> _suggestedGuestNames = {};
  List<BusyMaxContactSuggestion> _guestSuggestions = const [];
  final _suggestionSession = AttendeeSuggestionSession();
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
  String? _creationId;
  bool _recoveryWritesBlocked = false;
  Future<void> _recoveryIo = Future.value();
  Timer? _recoveryTimer;

  String get _recoveryKey =>
      'busymax.android.event-draft.${widget.draft.accountId}.'
      '${widget.draft.eventId ?? 'new-${widget.draft.sourceId}'}';

  @override
  void initState() {
    super.initState();
    if (widget.draft.eventId == null) _creationId = newAndroidCreationId();
    if (_draft.eventId == null &&
        _provider.isDav &&
        !_draft.allDay &&
        _draft.startTimeZone == null) {
      final zone = ref.read(localTimeZoneProvider);
      _draft = _draft.copyWith(
        startTimeZone: zone,
        endTimeZone: _draft.endTimeZone ?? zone,
      );
    }

    _contactsChanges = ref
        .read(busyMaxContactsControllerProvider)
        .changes
        .listen((_) {
          _suggestionSession.invalidate();
          if (mounted) {
            setState(() => _guestSuggestions = const []);
          }
        });
    unawaited(_restoreRecovery());
    _recoveryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_persistRecovery()),
    );
  }

  @override
  void dispose() {
    _suggestionSession.invalidate();
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
    _guestInput.dispose();
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
      _draft = _draft.copyWith(start: value).withValidEnd();
      _adjustRecurrenceTiming();
    });
  }

  void _adjustRecurrenceTiming({String? previousTimeZone}) {
    if (_draft.providerRecurringEventId != null ||
        !_recurrenceRule.isSupported ||
        !_recurrenceRule.repeats) {
      return;
    }
    _recurrenceRule = retimeRecurrenceEnd(
      _recurrenceRule,
      previousTimeZone: previousTimeZone ?? _draft.startTimeZone,
      start: _draft.start!,
      timeZone: _draft.startTimeZone,
      allDay: _draft.allDay,
      floating:
          _provider.isDav && (_draft.startTimeZone?.trim().isEmpty ?? true),
    );
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
        (!_recurrenceRule.isSupported ||
            !EventRecurrenceCodec.canEncode(
              source.provider,
              _recurrenceRule,
            )) &&
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
    final liveReminders =
        _provider == BusyProvider.google && _editedGoogleReminders != null
        ? _editedGoogleReminders
        : _provider.isDav && _editedNextcloudReminders != null
        ? davEventReminderPayload(_editedNextcloudReminders!)
        : _reminderMinutes != null
        ? _eventReminders(_provider, _reminderMinutes!)
        : _draft.reminders;
    final reminders = EventReminderEditor(
      _provider,
      liveReminders,
    ).forDestination(source.provider);
    setState(() {
      _draft = _draft.copyWith(
        accountId: source.accountId,
        sourceId: source.id,
        providerCalendarId: source.providerCalendarId,
        startTimeZone:
            source.provider.isDav &&
                _draft.eventId == null &&
                !_draft.allDay &&
                _draft.startTimeZone == null
            ? ref.read(localTimeZoneProvider)
            : _draft.startTimeZone,
        endTimeZone:
            source.provider.isDav &&
                _draft.eventId == null &&
                !_draft.allDay &&
                _draft.endTimeZone == null
            ? ref.read(localTimeZoneProvider)
            : _draft.endTimeZone,
        clearEventLabelId: _draft.sourceId != source.id,
        eventLabelChanged: _draft.sourceId != source.id,
        reminders: reminders,
        remindersChanged: changedProvider || _draft.remindersChanged,
        clearImportance: source.provider != BusyProvider.microsoft,
        clearColorId: changedProvider,
        showAs: changedProvider
            ? eventShowAsForProvider(_draft.showAs, source.provider)
            : _draft.showAs,
        visibilityOrSensitivity: changedProvider
            ? eventVisibilityForProvider(
                _draft.visibilityOrSensitivity,
                source.provider,
              )
            : _draft.visibilityOrSensitivity,
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
      _suggestionSession.invalidate();
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
    if (source == null) {
      return false;
    }
    return _draft.eventId == null || _moving
        ? source.capabilities.canCreateEvents
        : source.capabilities.canEditEvents;
  }

  bool get _canManageGuests =>
      _draft.canManageAttendees &&
      _provider != BusyProvider.appleICloud &&
      _provider != BusyProvider.caldav &&
      (_provider != BusyProvider.nextcloud ||
          _source?.davEffectivePermissions['canInvite'] == true);

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
    final accountId = _draft.accountId;
    final sourceId = _draft.sourceId;
    final suggestions = await _suggestionSession.search(
      contacts: () => ref.read(busyMaxContactsControllerProvider),
      query: query,
      accountId: accountId,
      attendees: _currentAttendees(),
      isCurrent: () =>
          mounted &&
          _draft.accountId == accountId &&
          _draft.sourceId == sourceId &&
          _guestInput.text.trim() == query.trim(),
    );
    if (mounted && suggestions != null) {
      setState(() => _guestSuggestions = suggestions);
    }
  }

  Future<void> _selectGuestSuggestion(
    BusyMaxContactSuggestion suggestion,
  ) async {
    if (!_canManageGuests || !_guestSuggestions.contains(suggestion)) {
      return;
    }
    final accountId = _draft.accountId;
    final sourceId = _draft.sourceId;
    final accepted = await _suggestionSession.accept(
      contacts: () => ref.read(busyMaxContactsControllerProvider),
      accountId: accountId,
      suggestion: suggestion,
      isCurrent: () =>
          mounted &&
          _draft.accountId == accountId &&
          _draft.sourceId == sourceId &&
          _canManageGuests &&
          _guestSuggestions.contains(suggestion),
    );
    if (!accepted || !mounted) return;
    final emails = _guests.text
        .split(RegExp(r'[,;\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (!emails.any(
      (email) => email.toLowerCase() == suggestion.email.toLowerCase(),
    )) {
      emails.add(suggestion.email);
    }
    setState(() {
      _guests.text = emails.join(', ');
      _guestInput.clear();
      _addingGuest = false;
      _guestError = null;
      if (suggestion.displayName.isNotEmpty) {
        _suggestedGuestNames[suggestion.email.toLowerCase()] =
            suggestion.displayName;
      }
      _guestSuggestions = const [];
    });
  }

  Future<void> _editRecurrence() async {
    final start = _draft.start;
    if (start == null) {
      return;
    }
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
    if (!mounted || result == null || result == _recurrenceRule) {
      return;
    }
    setState(() {
      _recurrenceRule = result;
      _recurrenceChanged = true;
    });
  }

  bool get _eventOrganizationPopulated =>
      _draft.categories.isNotEmpty ||
      _draft.eventLabelId != null ||
      _draft.conference != null ||
      _draft.createConference ||
      (_draft.importance != null && _draft.importance != 'normal') ||
      (_draft.showAs != null &&
          !const ['opaque', 'busy'].contains(_draft.showAs)) ||
      (_draft.visibilityOrSensitivity != null &&
          !const [
            'default',
            'normal',
            'public',
          ].contains(_draft.visibilityOrSensitivity));

  List<CalendarSourceEntity> get _selectableEventSources => [
    for (final source in widget.sources)
      if (source.id == _draft.sourceId ||
          (source.capabilities.canCreateEvents &&
              (_draft.eventId == null || !source.pendingCreate)))
        source,
  ];

  List<Widget> _eventDestinationRows() {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final ids = {for (final source in _selectableEventSources) source.accountId}
        .toList();
    String label(String id) =>
        accounts
            .where((account) => account.id == id)
            .firstOrNull
            ?.selectorLabel ??
        widget.sources
            .where((s) => s.accountId == id)
            .first
            .authenticatedAccountEmail ??
        id;
    ids.sort(
      (a, b) => label(a).toLowerCase().compareTo(label(b).toLowerCase()),
    );
    final canSelect =
        _canEdit &&
        (_draft.eventId == null ||
            (_originalSource?.capabilities.canDeleteEvents ?? false));
    final calendars =
        _selectableEventSources
            .where((s) => s.accountId == _draft.accountId)
            .toList()
          ..sort(
            (a, b) =>
                a.summary.toLowerCase().compareTo(b.summary.toLowerCase()),
          );
    return [
      DropdownButtonFormField<String>(
        key: ValueKey('android-event-account-${_draft.accountId}'),
        isExpanded: true,
        initialValue: _draft.accountId,
        decoration: InputDecoration(labelText: context.l10n.account),
        items: [
          for (final id in ids)
            DropdownMenuItem(
              value: id,
              child: Text(label(id), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: canSelect && ids.length > 1
            ? (id) {
                if (id == null) {
                  return;
                }
                final choices =
                    _selectableEventSources
                        .where((s) => s.accountId == id)
                        .toList()
                      ..sort(
                        (a, b) => a.summary.toLowerCase().compareTo(
                          b.summary.toLowerCase(),
                        ),
                      );
                _selectDestination(
                  choices.where((s) => s.primaryCalendar).firstOrNull ??
                      choices.first,
                );
              }
            : null,
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('android-event-calendar-${_draft.sourceId}'),
        isExpanded: true,
        initialValue: _source?.id,
        decoration: InputDecoration(labelText: context.l10n.calendar),
        items: [
          for (final source in calendars)
            DropdownMenuItem(
              value: source.id,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: _androidSourceColor(
                      source,
                      Theme.of(context).brightness,
                    ),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      source.summary,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!source.capabilities.canCreateEvents)
                    const Icon(Icons.lock_outline, size: 16),
                ],
              ),
            ),
        ],
        onChanged: canSelect && calendars.length > 1
            ? (id) =>
                  _selectDestination(calendars.firstWhere((s) => s.id == id))
            : null,
      ),
    ];
  }

  List<Widget> _eventTimeRows({required bool start}) {
    final value = (start ? _draft.start : _draft.end)!;
    void update(DateTime next) {
      if (start) {
        _setStart(next);
      } else {
        setState(() => _draft = _draft.copyWith(end: next));
      }
    }

    final zone = start ? _draft.startTimeZone : _draft.endTimeZone;
    return [
      ListTile(
        title: Text(start ? context.l10n.startDate : context.l10n.endDate),
        subtitle: Text(
          DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .format(value),
        ),
        leading: const Icon(Icons.event_outlined),
        enabled: _canChangeTiming,
        onTap: !_canChangeTiming
            ? null
            : () async {
                final date = await showBusyMaxDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(1970),
                  lastDate: DateTime(2200),
                );
                if (date != null && mounted) {
                  update(
                    DateTime(
                      date.year,
                      date.month,
                      date.day,
                      value.hour,
                      value.minute,
                      value.second,
                      value.millisecond,
                      value.microsecond,
                    ),
                  );
                }
              },
      ),
      if (!_draft.allDay) ...[
        ListTile(
          title: Text(start ? context.l10n.startTime : context.l10n.endTime),
          subtitle: Text(
            formatClockTime(context, TimeOfDay.fromDateTime(value)),
          ),
          leading: const Icon(Icons.schedule),
          enabled: _canChangeTiming,
          onTap: !_canChangeTiming
              ? null
              : () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(value),
                  );
                  if (time != null && mounted) {
                    update(
                      DateTime(
                        value.year,
                        value.month,
                        value.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  }
                },
        ),
        ListTile(
          title: Text(context.l10n.selectTimeZone),
          subtitle: Text(zone ?? ref.read(localTimeZoneProvider)),
          leading: const Icon(Icons.public),
          enabled: _canChangeTiming,
          onTap: !_canChangeTiming
              ? null
              : () async {
                  final selected = await showAndroidTimeZonePicker(
                    context,
                    zone,
                  );
                  if (selected == null || !mounted) {
                    return;
                  }
                  setState(() {
                    _draft = start
                        ? _draft.copyWith(startTimeZone: selected)
                        : _draft.copyWith(endTimeZone: selected);
                    if (start) {
                      _adjustRecurrenceTiming(previousTimeZone: zone);
                    }
                  });
                },
        ),
      ],
    ];
  }

  void _setEventCategories(List<String> values) => setState(() {
    _draft = _draft.copyWith(categories: values);
    _categories.text = values.join(', ');
  });

  void _addGuestEmail() {
    final email = _guestInput.text.trim();
    if (!_androidLooksLikeEmail(email)) {
      setState(() => _guestError = context.l10n.feedbackInvalidEmail);
      return;
    }
    final attendees = _currentAttendees();
    setState(() {
      if (!containsEventAttendee(attendees, email)) {
        _guests.text = [
          ...attendees
              .where((a) => !a.self && !a.organizer)
              .map((a) => a.email),
          email,
        ].join(', ');
      }
      _guestInput.clear();
      _guestError = null;
      _addingGuest = false;
      _guestSuggestions = const [];
      _suggestionSession.invalidate();
    });
  }

  List<Widget> _eventGuestRows() => [
    for (final attendee in _currentAttendees())
      ListTile(
        key: ValueKey('android-event-guest-${attendee.email}'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(attendee.displayName ?? attendee.email),
        subtitle: Text(
          [
            if (attendee.displayName != null) attendee.email,
            if (attendee.organizer) context.l10n.organizer,
          ].join(' · '),
        ),
        trailing:
            !_canEdit ||
                !_canManageGuests ||
                attendee.self ||
                attendee.organizer
            ? null
            : Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<bool>(
                    value:
                        _guestOptionalOverrides[attendee.email.toLowerCase()] ??
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(
                          () =>
                              _guestOptionalOverrides[attendee.email
                                      .toLowerCase()] =
                                  value,
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: context.l10n.delete,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _guests.text = _currentAttendees()
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
                      _suggestedGuestNames.remove(attendee.email.toLowerCase());
                    }),
                  ),
                ],
              ),
      ),
    if (_canEdit && _canManageGuests)
      if (!_addingGuest)
        TextButton.icon(
          onPressed: () => setState(() {
            _addingGuest = true;
            _guestError = null;
          }),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addGuest),
        )
      else ...[
        TextField(
          controller: _guestInput,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.l10n.addGuestEmail,
            errorText: _guestError,
          ),
          onChanged: (value) => unawaited(_loadGuestSuggestions(value)),
          onSubmitted: (_) => _addGuestEmail(),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: _addGuestEmail,
              child: Text(context.l10n.addGuest),
            ),
            TextButton(
              onPressed: () => setState(() {
                _addingGuest = false;
                _guestInput.clear();
                _guestSuggestions = const [];
                _suggestionSession.invalidate();
              }),
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
        for (final suggestion in _guestSuggestions)
          ListTile(
            key: ValueKey('android-guest-contact-${suggestion.email}'),
            title: Text(
              suggestion.displayName.isEmpty
                  ? suggestion.email
                  : suggestion.displayName,
            ),
            subtitle: Text(suggestion.email),
            onTap: () => _selectGuestSuggestion(suggestion),
          ),
      ],
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop || !_hasPendingEdits,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _allowPop) {
          return;
        }
        if (await _confirmDiscardChanges() && mounted) {
          await _clearRecovery(finalCleanup: true);
          if (!mounted) {
            return;
          }
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
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
              onPressed:
                  _saving || !_recoveryLoaded || !_canEdit || !_draft.canSave
                  ? null
                  : _save,
              child: Text(context.l10n.save),
            ),
          ],
        ),
        body: Form(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                AndroidEditorGroup(
                  children: [
                    TextFormField(
                      controller: _title,
                      enabled: _canEdit,
                      decoration: InputDecoration(
                        labelText: context.l10n.title,
                      ),
                      autofocus: _draft.eventId == null,
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(title: v)),
                    ),
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
                  ],
                ),
                AndroidEditorGroup(children: [..._eventDestinationRows()]),
                AndroidEditorGroup(
                  children: [
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
                              _draft = _draft
                                  .copyWith(allDay: value)
                                  .withValidEnd();
                              _adjustRecurrenceTiming();
                            }),
                    ),
                  ],
                ),
                AndroidEditorGroup(
                  title: context.l10n.startDateTime,
                  children: [..._eventTimeRows(start: true)],
                ),
                AndroidEditorGroup(
                  title: context.l10n.endDateTime,
                  children: [..._eventTimeRows(start: false)],
                ),
                AndroidEditorGroup(
                  children: [
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
                  ],
                ),
                if (_draft.providerRecurringEventId != null)
                  AndroidEditorGroup(
                    children: [
                      if (_draft.providerRecurringEventId != null) ...[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.call_split),
                          title: Text(context.l10n.chooseRecurringEventScope),
                          subtitle: _draft.recurringMutationScope == null
                              ? null
                              : Text(
                                  _scopeLabel(
                                    context,
                                    _draft.recurringMutationScope!,
                                  ),
                                ),
                          onTap: _canEdit ? _selectRecurringScope : null,
                        ),
                      ],
                    ],
                  ),
                if (_draft.providerRecurringEventId == null)
                  AndroidEditorGroup(
                    children: [
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
                        enabled: _canEdit,
                        onTap: _canEdit ? _editRecurrence : null,
                      ),
                    ],
                  ),
                AndroidEditorGroup(
                  title: context.l10n.reminder,
                  children: [
                    if (_provider == BusyProvider.google)
                      ..._googleReminderRows()
                    else if (_provider.isDav)
                      ..._nextcloudReminderRows()
                    else ...[
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey(
                          'android-event-reminder-${_draft.sourceId}',
                        ),
                        initialValue:
                            _reminderMinutes ??
                            androidEventReminderSelection(
                              _provider,
                              _draft.reminders,
                            ),
                        decoration: InputDecoration(
                          labelText: context.l10n.reminder,
                        ),
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
                              child: Text(
                                context.l10n.reminderMinutesBefore(value),
                              ),
                            ),
                        ],
                        onChanged: !_canEdit
                            ? null
                            : (value) =>
                                  setState(() => _reminderMinutes = value),
                      ),
                      if (_reminderMinutes == null)
                        if (androidEventReminderMinutes(
                              _provider,
                              _draft.reminders,
                            )
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
                                              : context.l10n
                                                    .reminderMinutesBefore(
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
                          androidEventReminderMinutes(
                                _provider,
                                _draft.reminders,
                              ) ==
                              null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(context.l10n.unsupportedReminder),
                        ),
                    ],
                  ],
                ),
                if (_canManageGuests || _currentAttendees().isNotEmpty)
                  AndroidEditorGroup(
                    title: context.l10n.guests,
                    children: [..._eventGuestRows()],
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
                AndroidEditorGroup(
                  title: context.l10n.organizationSection,
                  expanded: _eventOrganizationPopulated,
                  key: const ValueKey('android-event-organization'),
                  children: [
                    if ((_provider == BusyProvider.google ||
                            _provider == BusyProvider.microsoft) &&
                        _draft.isOrganizer != false)
                      AndroidEditorGroup(
                        title: context.l10n.meetingSection,
                        children: [
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
                              key: const ValueKey(
                                'android-event-create-conference',
                              ),
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _provider == BusyProvider.google
                                    ? context.l10n.addGoogleMeet
                                    : context.l10n.addTeamsMeeting,
                              ),
                              subtitle: _draft.conference == null
                                  ? null
                                  : Text(context.l10n.onlineMeetingAdded),
                              value:
                                  _draft.conference != null ||
                                  _draft.createConference,
                              onChanged: _canEdit && _draft.conference == null
                                  ? (value) => setState(
                                      () => _draft = _draft.copyWith(
                                        createConference: value,
                                      ),
                                    )
                                  : null,
                            ),
                          if (_provider == BusyProvider.microsoft)
                            SwitchListTile(
                              title: Text(context.l10n.requestResponses),
                              value: _draft.responseRequested ?? true,
                              onChanged: !_canEdit || !_canManageGuests
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
                            onChanged: !_canEdit || !_canManageGuests
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
                              onChanged: !_canEdit || !_canManageGuests
                                  ? null
                                  : (value) => setState(
                                      () => _draft = _draft.copyWith(
                                        allowNewTimeProposals: value,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    if (_provider == BusyProvider.microsoft || _provider.isDav)
                      AndroidCategoryEditor(
                        values: _draft.categories,
                        onChanged: _canEdit ? _setEventCategories : null,
                      ),
                    if (_provider == BusyProvider.microsoft && _source != null)
                      _microsoftCategoryField(_source!),
                    if (_provider == BusyProvider.microsoft)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
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
                    if (_provider == BusyProvider.google &&
                        (_source?.primaryCalendar == true ||
                            googleStatusEventTypes.contains(_draft.eventType)))
                      ..._googleStatusRows(),
                    if (_provider == BusyProvider.google && _source != null)
                      _googleEventLabelField(_source!),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
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
                            child: Text(
                              _eventAvailabilityLabel(context, value),
                            ),
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
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey(
                        'android-event-visibility-${_provider.name}',
                      ),
                      initialValue:
                          _eventVisibilityValues(_provider)
                              .contains(_draft.visibilityOrSensitivity)
                          ? _draft.visibilityOrSensitivity
                          : _eventVisibilityValues(_provider).first,
                      decoration: InputDecoration(
                        labelText: context.l10n.visibility,
                      ),
                      items: [
                        for (final value in _eventVisibilityValues(_provider))
                          DropdownMenuItem(
                            value: value,
                            child: Text(_eventVisibilityLabel(context, value)),
                          ),
                      ],
                      onChanged:
                          !_canEdit || _draft.eventType == 'workingLocation'
                          ? null
                          : (value) => setState(
                              () => _draft = _draft.copyWith(
                                visibilityOrSensitivity: value,
                              ),
                            ),
                    ),
                  ],
                ),
                AndroidEditorGroup(
                  children: [
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
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _googleReminderRows() {
    final value = _editedGoogleReminders ?? _draft.reminders;
    final mode = googleReminderMode(value);
    final popupRows = googlePopupReminderRows(value);
    return [
      DropdownButtonFormField<int>(
        isExpanded: true,
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
                if (selection == null) {
                  return;
                }
                setState(
                  () => _editedGoogleReminders = setGoogleReminderMode(
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
                  isExpanded: true,
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
                          if (minute == null) {
                            return;
                          }
                          setState(
                            () => _editedGoogleReminders =
                                editGooglePopupReminder(
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
                        () =>
                            _editedGoogleReminders = removeGooglePopupReminder(
                              value,
                              overrideIndex: row.index,
                            ),
                      ),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        if (googleReminderOverrideCount(value) < googleReminderLimit)
          TextButton.icon(
            onPressed: !_canEdit
                ? null
                : () => setState(
                    () => _editedGoogleReminders = editGooglePopupReminder(
                      value,
                      overrideIndex: null,
                      minutes: 10,
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addReminder),
          ),
        if (googleHasUnsupportedReminder(value))
          Text(context.l10n.unsupportedReminder),
      ],
    ];
  }

  List<Widget> _nextcloudReminderRows() {
    final rows =
        _editedNextcloudReminders ??
        androidNextcloudEditableReminderRows(_draft.reminders);
    if (rows == null) {
      return [Text(context.l10n.unsupportedReminder)];
    }
    return [
      Text(context.l10n.reminders),
      if (rows.isEmpty) Text(context.l10n.noReminders),
      for (var index = 0; index < rows.length; index++)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
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
                        if (minute == null) {
                          return;
                        }
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
                if (value == null) {
                  return;
                }
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
    if (!googleStatusEventTypes.contains(type)) {
      return rows;
    }
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
          isExpanded: true,
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
                  if (value == null) {
                    return;
                  }
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
            isExpanded: true,
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
                    if (value == null) {
                      return;
                    }
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
        isExpanded: true,
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
                if (value == null) {
                  return;
                }
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
              if (!mounted || consent.isCancelled) {
                return;
              }
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
              selected: _draft.categories.contains(category.displayName),
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
                      _setEventCategories(values);
                    },
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_recoveryLoaded) return;
    final start = _draft.start;
    if (_title.text.trim().isEmpty || start == null) {
      return;
    }
    final attendeeEdit = applyAndroidEventAttendeeRoles(
      AndroidEventAttendeeEdit(
        attendees: _currentAttendees(),
        changed: !listEquals(_currentAttendees(), widget.draft.attendees),
      ),
      _guestOptionalOverrides,
    );
    // The display separator can also occur inside an existing category.
    // Preserve the original values when this field was not edited.
    final categories = _draft.categories;
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
        reminders: davEventReminderPayload(_editedNextcloudReminders!),
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
    if (!draft.canSave) {
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (draft.providerRecurringEventId != null &&
          draft.recurringMutationScope == null) {
        final scope = await _selectRecurringScope();
        if (scope == null) {
          return;
        }
        draft = draft.copyWith(recurringMutationScope: scope);
      }
      if (!mounted) {
        return;
      }
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
        if (confirmed != true || !mounted) {
          return;
        }
      }
      if (!mounted) {
        return;
      }
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
        if (decision == null || !mounted) {
          return;
        }
        guestPolicy = decision;
      }
      final approved = await approveEventSeriesTiming(
        repository: () => ref.read(calendarRepositoryProvider),
        draft: draft,
        isActive: () => mounted,
        confirm: (change, following) async =>
            (await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(context.l10n.repeat),
                content: Text(
                  seriesTimingConfirmationMessage(
                    dialogContext,
                    change,
                    following: following,
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
            )) ==
            true,
      );
      if (approved == null || !mounted) return;
      draft = approved;
      if ((_reminderMinutes ?? -2) >= 0 ||
          googlePopupReminderRows(_editedGoogleReminders).isNotEmpty ||
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
      final settings = ref.read(appSettingsControllerProvider.notifier);
      final outcome = await saveEventDraft(
        repository: ref.read(calendarRepositoryProvider),
        draft: draft,
        creationId: _creationId,
        guestPolicy: guestPolicy,
        rememberDestination: () => settings.rememberCalendar(
          CreationDestination(accountId: draft.accountId, id: draft.sourceId),
        ),
        requestSync: () {
          for (final id in {draft.accountId, widget.draft.accountId}) {
            ref
                .read(
                  pendingCalendarMutationSyncRequesterForAccountProvider(id),
                )
                .request();
          }
        },
        clearRecovery: () =>
            _clearRecovery(finalCleanup: true, reportFailure: true),
      );
      if (mounted) {
        if (outcome == EventSaveOutcome.followUpPending) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.pendingLocally)));
        }
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool get _canCheckGuestAvailability {
    final source = _source;
    if (source == null || !_draft.hasValidInterval) {
      return false;
    }
    final hasGuests = mergeAndroidEventAttendees(
      _draft.attendees,
      _guests.text,
    ).attendees.any((attendee) => !attendee.self && !attendee.organizer);
    if (!hasGuests) {
      return false;
    }
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
    if (source == null || !_canCheckGuestAvailability) {
      return;
    }
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
      if (scope == null) {
        return;
      }
      draft = draft.copyWith(recurringMutationScope: scope);
    }
    if (!mounted) {
      return;
    }
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
    if (confirmed != true || _draft.eventId == null || !mounted) {
      return;
    }
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
      if (decision == null || !mounted) {
        return;
      }
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
        if (!mounted) {
          return;
        }
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _scopeAvailable(RecurringEventMutationScope scope) {
    if (scope == RecurringEventMutationScope.singleOccurrence) {
      return true;
    }
    if (!_moving) {
      return scope != RecurringEventMutationScope.thisAndFuture ||
          (_provider != BusyProvider.nextcloud ||
                  _draft.isOrganizer != false) &&
              (_draft.originalDetail == null
                  ? supportsThisAndFollowingEventMutation(_provider)
                  : eventSupportsThisAndFollowing(_draft.originalDetail!));
    }
    if (scope == RecurringEventMutationScope.thisAndFuture) {
      return false;
    }
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
      if (!mounted) {
        return;
      }
      await _clearRecovery(finalCleanup: true);
      if (!mounted) {
        return;
      }
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
      if (raw == null) {
        return;
      }
      final value = jsonDecode(raw);
      if (value is! Map) {
        return;
      }
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
      final creationId = editingExistingEvent
          ? null
          : recoverAndroidCreationId(map['creationId'], _recoveryKey, raw);
      if (creationId != null &&
          await CreationReceiptStore(ref.read(databaseProvider))
              .hasCommitted(CreationKind.event, creationId)) {
        if (mounted) await _clearRecovery();
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
      if (!mounted) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _creationId = creationId;
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
        final recoveredCategories = map['categories'];
        final values = recoveredCategories is List
            ? recoveredCategories.whereType<String>().toList()
            : recoveredCategories is String
            ? recoveredCategories
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList()
            : _draft.categories;
        _draft = _draft.copyWith(categories: values);
        _categories.text = values.join(', ');
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
          _recurrenceRule = const RecurrenceRule.none().withFrequency(
            frequency,
            start,
          );
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
      if (mounted) setState(() => _recoveryLoaded = true);
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
      if (_creationId != null) 'creationId': _creationId,
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
      'categories': _draft.categories,
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
      if (_recoveryWritesBlocked) {
        return;
      }
      await ref
          .read(secureStorageProvider)
          .write(key: _recoveryKey, value: payload);
    });
  }

  Future<void> _clearRecovery({
    bool finalCleanup = false,
    bool reportFailure = false,
  }) {
    if (finalCleanup) {
      _recoveryWritesBlocked = true;
      _recoveryTimer?.cancel();
    }
    return _enqueueRecovery(
      () => ref.read(secureStorageProvider).delete(key: _recoveryKey),
      reportFailure: reportFailure,
    );
  }

  Future<void> _enqueueRecovery(
    Future<void> Function() operation, {
    bool reportFailure = false,
  }) {
    final result = _recoveryIo.then((_) => operation());
    _recoveryIo = result.catchError((_) {});
    return reportFailure ? result : _recoveryIo;
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
  if (optionalByEmail.isEmpty) {
    return edit;
  }
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
    final key = eventAttendeeIdentity(attendee.email);
    if (requested.containsKey(key) && matched.add(key)) {
      result.add(attendee);
    }
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

/// Full Month renders only the civil weeks required by that month.
ScheduleRange androidMonthGridRange(
  DateTime month, {
  required int firstWeekday,
}) => ScheduleRange.month(month, firstWeekday: firstWeekday);

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
  return ScheduleRange(
    start: january.start,
    end: DateTime(
      december.start.year,
      december.start.month,
      december.start.day + 42,
    ),
  );
}

String _periodLabel(
  BuildContext context,
  DateTime date,
  ScheduleViewMode mode,
) => localizedScheduleHeading(
  Localizations.localeOf(context).toLanguageTag(),
  mode,
  ScheduleRange.week(date, firstWeekday: _firstWeekday(context)),
  date,
  agendaLabel: context.l10n.viewAgenda,
);

String _modeLabel(BuildContext context, ScheduleViewMode mode) =>
    switch (mode) {
      ScheduleViewMode.day => context.l10n.viewDay,
      ScheduleViewMode.week => context.l10n.viewWeek,
      ScheduleViewMode.month => context.l10n.viewMonth,
      ScheduleViewMode.year => context.l10n.viewYear,
      ScheduleViewMode.agenda => context.l10n.viewAgenda,
    };

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
  if (value is! Map || value['alarms'] is! List) {
    return false;
  }
  final rows = androidNextcloudEditableReminderRows(value);
  return rows != null && rows.length < (value['alarms'] as List).length;
}

/// A negative selection is explicit default (-1) or no reminder (-2).
/// Null means a provider-specific representation that this single-choice
/// editor must preserve until the user actively replaces it.
int? androidEventReminderSelection(BusyProvider provider, Object? value) {
  if (value == null) {
    return provider == BusyProvider.google ? -1 : -2;
  }
  if (value is! Map) {
    return null;
  }
  if (provider == BusyProvider.microsoft) {
    if (value['isReminderOn'] == false) {
      return -2;
    }
    return value['reminderMinutesBeforeStart'] is int
        ? value['reminderMinutesBeforeStart'] as int
        : null;
  }
  if (value['useDefault'] == true) {
    return -1;
  }
  final overrides = value['overrides'];
  if (overrides is List) {
    if (overrides.isEmpty) {
      return -2;
    }
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
  if (value is! Map) {
    return null;
  }
  if (provider.isDav &&
      (value.containsKey('davEditableRows') || value.containsKey('alarms'))) {
    return davEventEditableReminderRows(value)
        ?.map((row) => row.minutes)
        .toList();
  }
  if (provider == BusyProvider.microsoft) {
    if (value['isReminderOn'] == false) {
      return const [];
    }
    final minutes = value['reminderMinutesBeforeStart'];
    return minutes is int && minutes >= 0 ? [minutes] : null;
  }
  if (value['useDefault'] == true) {
    return null;
  }
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

Future<List<int>?> _readJournalFile() async =>
    (await BusyMaxAndroidPlatform.instance.openDocument(
      maximumBytes: 16 * 1024 * 1024,
    ))?.bytes;

Future<JournalAttachmentFile?> _pickJournalAttachment() async {
  final file = await BusyMaxAndroidPlatform.instance.openDocument(
    maximumBytes: maximumIcalAttachmentBytes,
  );
  return file == null
      ? null
      : (name: file.name ?? 'attachment.bin', bytes: file.bytes);
}

Future<String?> _saveJournalAttachment(IcalAttachment attachment) =>
    BusyMaxAndroidPlatform.instance.createDocument(
      suggestedName: davAttachmentFileName(attachment),
      mimeType: attachment.mimeType,
      bytes: attachment.decode(),
    );

Future<void> _exportJournalFile(String raw) async {
  await BusyMaxAndroidPlatform.instance.createDocument(
    suggestedName: 'busymax-journal.ics',
    mimeType: 'text/calendar',
    bytes: Uint8List.fromList(utf8.encode(raw)),
  );
}

Future<void> _exportJournalDraft(String json) async {
  await BusyMaxAndroidPlatform.instance.createDocument(
    suggestedName: 'busymax-journal-draft.json',
    mimeType: 'application/json',
    bytes: Uint8List.fromList(utf8.encode(json)),
  );
}

Future<String?> _exportJournalCollection(List<NativeImportResource> journals) =>
    BusyMaxAndroidPlatform.instance.exportDocumentTree(
      folderName:
          'BusyMax-journals-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      resources: [
        for (final (index, journal) in journals.indexed)
          AndroidExportResource(
            name: 'resource-${index + 1}.ics',
            bytes: Uint8List.fromList(utf8.encode(journal.rawIcs)),
          ),
      ],
    );

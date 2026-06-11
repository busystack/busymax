import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_about_dialog.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_layout.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../features/accounts/data/accounts_repository.dart';
import '../../../features/calendar/data/calendar_repository.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../schedule/schedule_commands.dart';
import '../../../schedule/schedule_filters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_repository.dart';
import '../../../schedule/schedule_scope.dart';
import '../../../schedule/schedule_source_visibility.dart';
import '../../../schedule/schedule_view_mode.dart';
import '../../calendar/presentation/event_editor.dart';
import '../../calendar/presentation/event_editor_draft.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../tasks/data/tasks_repository.dart';
import '../../tasks/presentation/new_task_dialog.dart';
import '../../tasks/presentation/task_details_pane.dart';
import 'schedule_agenda_view.dart';
import 'schedule_create_menu.dart';
import 'schedule_day_week_view.dart';
import 'schedule_item_details_popover.dart';
import 'schedule_item_exporter.dart';
import 'schedule_item_selection.dart';
import 'schedule_month_view.dart';
import 'schedule_sidebar.dart';
import 'schedule_toolbar.dart';
import 'schedule_year_view.dart';

class ScheduleWorkspace extends ConsumerStatefulWidget {
  const ScheduleWorkspace({super.key, this.initialScope = ScheduleScope.all});

  final ScheduleScope initialScope;

  @override
  ConsumerState<ScheduleWorkspace> createState() => _ScheduleWorkspaceState();
}

class _ScheduleWorkspaceState extends ConsumerState<ScheduleWorkspace> {
  static const _agendaInitialDays = 30;
  static const _agendaPageDays = 30;

  var _selectedDate = DateTime.now();
  var _mode = ScheduleViewMode.week;
  late ScheduleScope _scope;
  _TaskDetailsTarget? _taskDetailsTarget;
  StreamSubscription<BusyMaxHeaderBarAction>? _headerBarActions;
  var _headerBarReady = false;
  var _nativeHeaderBarAvailable = false;
  var _sidebarCollapsed = false;
  var _searchActive = false;
  var _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _latestCanShowSidebar = false;
  var _latestItems = const <ScheduleItem>[];
  var _agendaLoadedDays = _agendaInitialDays;
  ScheduleViewMode? _lastSettingsMode;
  _HeaderBarStateSnapshot? _lastHeaderBarState;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    _applyInitialScope();
    unawaited(_initializeHeaderBar());
  }

  @override
  void dispose() {
    if (_taskDetailsTarget != null) {
      unawaited(
        ref.read(linuxHeaderBarServiceProvider).setModalBarrierVisible(false),
      );
    }
    unawaited(_headerBarActions?.cancel());
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScheduleWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialScope != widget.initialScope) {
      _scope = widget.initialScope;
      _applyInitialScope();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    _syncModeFromSettings(settings.scheduleViewMode);
    final range = _range(context);
    final searchHasQuery = _searchQuery.trim().isNotEmpty;
    final accountsState = ref.watch(accountsStreamProvider);
    final accounts = accountsState.valueOrNull ?? const [];
    final accountsLoading =
        accountsState.isLoading && accountsState.valueOrNull == null;
    final accountIds = accounts.map((account) => account.id).toList();
    final sourcesStream = ref
        .watch(calendarRepositoryProvider)
        .watchSourcesForAccounts(accountIds);

    return StreamBuilder<List<CalendarSourceEntity>>(
      stream: sourcesStream,
      builder: (context, sourcesSnapshot) {
        final sourcesLoading =
            sourcesSnapshot.connectionState == ConnectionState.waiting &&
            !sourcesSnapshot.hasData;
        final sources = sourcesSnapshot.data ?? const <CalendarSourceEntity>[];
        return FutureBuilder<List<TaskListEntity>>(
          future: _taskListsForAccounts(accounts),
          builder: (context, listsSnapshot) {
            final taskListsLoading =
                listsSnapshot.connectionState == ConnectionState.waiting &&
                !listsSnapshot.hasData;
            final taskLists = listsSnapshot.data ?? const <TaskListEntity>[];
            final visibility = ScheduleSourceVisibility.fromSources(
              calendarSources: sources,
              taskLists: taskLists,
              settings: settings,
            );
            final firstWeekday = _firstWeekday(context);
            final visibleSources = sources
                .where(
                  (source) =>
                      visibility.visibleCalendarSourceIds.contains(source.id),
                )
                .toList();

            return FutureBuilder<List<ScheduleItem>>(
              future: _scheduleItems(
                repository: ref.watch(scheduleRepositoryProvider),
                range: range,
                searchHasQuery: searchHasQuery,
                accountIds: accountIds.toSet(),
                sourceIds: visibility.visibleCalendarSourceIds,
                taskListIds: visibility.visibleTaskListIds,
              ),
              builder: (context, snapshot) {
                final itemsLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;
                final scheduleLoading =
                    accountsLoading ||
                    sourcesLoading ||
                    taskListsLoading ||
                    itemsLoading;
                final scopedItems = ScheduleProjection.filterByScope(
                  snapshot.data ?? const <ScheduleItem>[],
                  _scope,
                );
                final items =
                    !searchHasQuery && _mode == ScheduleViewMode.agenda
                    ? _agendaItems(scopedItems, range)
                    : scopedItems;
                _latestItems = items;
                final miniCalendarItemsFuture = ref
                    .watch(scheduleRepositoryProvider)
                    .listItems(
                      range: ScheduleRange.month(
                        _selectedDate,
                        firstWeekday: firstWeekday,
                      ),
                      filters: ScheduleFilters(
                        accountIds: accountIds.toSet(),
                        sourceIds: visibility.visibleCalendarSourceIds,
                        taskListIds: visibility.visibleTaskListIds,
                        sourceFilterActive: true,
                        taskListFilterActive: true,
                        includeCalendarEvents: _scope != ScheduleScope.tasks,
                        includeTasks: _scope != ScheduleScope.events,
                        showCompletedTasks: true,
                        showNoDateTasks: false,
                      ),
                    );
                final displayRange = searchHasQuery
                    ? _rangeForSearchResults(items, range)
                    : range;
                final displayMode = searchHasQuery
                    ? ScheduleViewMode.agenda
                    : _mode;
                _consumePendingCommand(visibleSources, accounts, items);
                final showFallbackHeader = _showFlutterHeaderFallback;
                final main = Column(
                  children: [
                    if (showFallbackHeader) ...[
                      ScheduleToolbar(
                        mode: _mode,
                        range: range,
                        selectedDate: _selectedDate,
                        onToday: _goToToday,
                        onPrevious: _previous,
                        onNext: _next,
                        onModeChanged: _setMode,
                        onRefresh: () => unawaited(_refreshAll()),
                      ),
                      const Divider(height: 1),
                    ],
                    if (_searchActive) ...[
                      _ScheduleSearchField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        onClose: _closeSearch,
                      ),
                      const Divider(height: 1),
                    ],
                    Expanded(
                      child: _ScheduleBody(
                        isLoading: scheduleLoading,
                        mode: displayMode,
                        range: displayRange,
                        selectedDate: searchHasQuery
                            ? displayRange.start
                            : _selectedDate,
                        firstWeekday: _firstWeekday(context),
                        dayStartMinute: settings.scheduleDayStartMinute,
                        dayEndMinute: settings.scheduleDayEndMinute,
                        hasAnySources:
                            visibility.hasCalendarSources ||
                            visibility.hasTaskLists,
                        items: items,
                        onDaySelected: _setDate,
                        onYearDaySelected: _openDay,
                        onMonthSelected: _setMonth,
                        onEmptySlot: (start) => unawaited(
                          _openCreateChoice(accounts, visibleSources, start),
                        ),
                        onCreateAtDay: (day) => unawaited(
                          _openCreateChoice(
                            accounts,
                            visibleSources,
                            DateTime(day.year, day.month, day.day, 9),
                          ),
                        ),
                        onNewEvent: () => unawaited(
                          _openNewEvent(visibleSources, _selectedDate),
                        ),
                        onNewTask: () => unawaited(_openNewTask(accounts)),
                        onPrevious: _previous,
                        onNext: _next,
                        onAgendaLoadMore:
                            !searchHasQuery && _mode == ScheduleViewMode.agenda
                            ? _loadMoreAgendaDays
                            : null,
                        onItemSelected: (context, item, [globalPosition]) =>
                            unawaited(
                              _openItem(
                                context,
                                item,
                                visibleSources,
                                globalPosition: globalPosition,
                              ),
                            ),
                        onTaskCompletionChanged: _setTaskCompleted,
                      ),
                    ),
                  ],
                );
                return Scaffold(
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final showSidebar = BusyMaxLayoutRules.showSidebar(
                        constraints.maxWidth,
                      );
                      _updateHeaderBarState(
                        context,
                        range: range,
                        accounts: accounts,
                        visibleSources: visibleSources,
                        showSidebar: showSidebar,
                      );
                      final body = !showSidebar || _sidebarCollapsed
                          ? main
                          : Row(
                              children: [
                                SizedBox(
                                  width: BusyMaxSizes.sidebarWidth,
                                  child: FutureBuilder<List<ScheduleItem>>(
                                    future: miniCalendarItemsFuture,
                                    builder: (context, miniSnapshot) {
                                      final miniCalendarItems =
                                          ScheduleProjection.filterByScope(
                                            miniSnapshot.data ??
                                                const <ScheduleItem>[],
                                            _scope,
                                          );
                                      return ScheduleSidebar(
                                        selectedDate: _selectedDate,
                                        firstWeekday: firstWeekday,
                                        items: miniCalendarItems,
                                        onDateSelected: _openDay,
                                        onMonthSelected: _setMonth,
                                        onYearSelected: _setYear,
                                        onWeekSelected: _setWeek,
                                      );
                                    },
                                  ),
                                ),
                                Expanded(child: main),
                              ],
                            );
                      return _ScheduleTaskDetailsOverlay(
                        target: _taskDetailsTarget,
                        onClose: _closeTaskDetails,
                        child: body,
                      );
                    },
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.endFloat,
                  floatingActionButton: FloatingActionButton(
                    tooltip: context.l10n.create,
                    onPressed: () => unawaited(
                      _openCreateChoice(
                        accounts,
                        visibleSources,
                        DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          9,
                        ),
                      ),
                    ),
                    child: const Icon(YaruIcons.plus),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  bool get _showFlutterHeaderFallback {
    if (!Platform.isLinux) {
      return true;
    }
    return _headerBarReady && !_nativeHeaderBarAvailable;
  }

  Future<void> _initializeHeaderBar() async {
    final service = ref.read(linuxHeaderBarServiceProvider);
    await service.initialize();
    if (!mounted) {
      return;
    }
    _headerBarActions = service.actions.listen(_handleHeaderBarAction);
    setState(() {
      _headerBarReady = true;
      _nativeHeaderBarAvailable = service.isAvailable;
    });
  }

  void _updateHeaderBarState(
    BuildContext context, {
    required ScheduleRange range,
    required List<AccountEntity> accounts,
    required List<CalendarSourceEntity> visibleSources,
    required bool showSidebar,
  }) {
    _latestCanShowSidebar = showSidebar;
    if (!_nativeHeaderBarAvailable) {
      return;
    }
    final titleRange = _scheduleRangeLabel(
      context,
      _mode,
      range,
      _selectedDate,
    );
    final sidebarVisible = showSidebar && !_sidebarCollapsed;
    final headerBarState = _HeaderBarStateSnapshot(
      titleRange: titleRange,
      viewMode: _mode,
      canRefresh: accounts.isNotEmpty,
      searchActive: _searchActive,
      sidebarVisible: sidebarVisible,
      navigationVisible: _mode != ScheduleViewMode.agenda,
    );
    if (_lastHeaderBarState == headerBarState) {
      return;
    }
    _lastHeaderBarState = headerBarState;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final service = ref.read(linuxHeaderBarServiceProvider);
      unawaited(service.setScheduleControlsVisible(true));
      unawaited(service.setBackVisible(false));
      unawaited(
        service.setOnboardingControls(
          visible: false,
          canGoBack: false,
          canContinue: false,
          backLabel: '',
          continueLabel: '',
        ),
      );
      unawaited(service.setTitleRange(headerBarState.titleRange));
      unawaited(service.setViewMode(headerBarState.viewMode));
      unawaited(service.setNavigationVisible(headerBarState.navigationVisible));
      unawaited(service.setCanRefresh(headerBarState.canRefresh));
      unawaited(service.setSearchActive(headerBarState.searchActive));
      unawaited(service.setSidebarVisible(headerBarState.sidebarVisible));
    });
  }

  void _handleHeaderBarAction(BusyMaxHeaderBarAction action) {
    switch (action) {
      case BusyMaxHeaderBarAction.back:
      case BusyMaxHeaderBarAction.continueSetup:
        return;
      case BusyMaxHeaderBarAction.sidebarToggle:
        if (!_latestCanShowSidebar) {
          return;
        }
        setState(() => _sidebarCollapsed = !_sidebarCollapsed);
      case BusyMaxHeaderBarAction.today:
        _goToToday();
      case BusyMaxHeaderBarAction.previous:
        if (_mode == ScheduleViewMode.agenda) {
          return;
        }
        _previous();
      case BusyMaxHeaderBarAction.next:
        if (_mode == ScheduleViewMode.agenda) {
          return;
        }
        _next();
      case BusyMaxHeaderBarAction.viewModeDay:
        _setMode(ScheduleViewMode.day);
      case BusyMaxHeaderBarAction.viewModeWeek:
        _setMode(ScheduleViewMode.week);
      case BusyMaxHeaderBarAction.viewModeMonth:
        _setMode(ScheduleViewMode.month);
      case BusyMaxHeaderBarAction.viewModeYear:
        _setMode(ScheduleViewMode.year);
      case BusyMaxHeaderBarAction.viewModeAgenda:
        _setMode(ScheduleViewMode.agenda);
      case BusyMaxHeaderBarAction.search:
        if (_searchActive) {
          _closeSearch();
        } else {
          setState(() => _searchActive = true);
          _focusSearch();
        }
      case BusyMaxHeaderBarAction.refresh:
        unawaited(_refreshAll());
      case BusyMaxHeaderBarAction.settings:
        context.go('/settings');
      case BusyMaxHeaderBarAction.aboutBusyMax:
        unawaited(
          showBusyMaxAboutDialog(
            context,
            headerBarService: ref.read(linuxHeaderBarServiceProvider),
          ),
        );
    }
  }

  ScheduleRange _range(BuildContext context) {
    final firstWeekday = _firstWeekday(context);
    if (_scope == ScheduleScope.upcoming) {
      final start = _day(DateTime.now());
      return ScheduleRange(
        start: start,
        end: start.add(Duration(days: _agendaLoadedDays)),
      );
    }
    return switch (_mode) {
      ScheduleViewMode.day => ScheduleRange.day(_selectedDate),
      ScheduleViewMode.week => ScheduleRange.week(
        _selectedDate,
        firstWeekday: firstWeekday,
      ),
      ScheduleViewMode.month => ScheduleRange.month(
        _selectedDate,
        firstWeekday: firstWeekday,
      ),
      ScheduleViewMode.year => ScheduleRange.year(_selectedDate),
      ScheduleViewMode.agenda => ScheduleRange(
        start: _day(_selectedDate),
        end: _day(_selectedDate).add(Duration(days: _agendaLoadedDays)),
      ),
    };
  }

  ScheduleRange _rangeForSearchResults(
    List<ScheduleItem> items,
    ScheduleRange fallback,
  ) {
    final days = items
        .map((item) => item.start)
        .nonNulls
        .map(ScheduleProjection.day)
        .toList();
    if (days.isEmpty) {
      return fallback;
    }
    days.sort();
    return ScheduleRange(
      start: days.first,
      end: days.last.add(const Duration(days: 1)),
    );
  }

  Future<List<ScheduleItem>> _scheduleItems({
    required ScheduleRepository repository,
    required ScheduleRange range,
    required bool searchHasQuery,
    required Set<String> accountIds,
    required Set<String> sourceIds,
    required Set<String> taskListIds,
  }) async {
    final currentItems = repository.listItems(
      range: range,
      filters: ScheduleFilters(
        query: _searchQuery,
        accountIds: accountIds,
        sourceIds: sourceIds,
        taskListIds: taskListIds,
        sourceFilterActive: true,
        taskListFilterActive: true,
        includeCalendarEvents: _scope != ScheduleScope.tasks,
        includeTasks: _scope != ScheduleScope.events,
        showCompletedTasks: true,
        showNoDateTasks: true,
      ),
    );
    if (searchHasQuery || _mode != ScheduleViewMode.agenda) {
      return currentItems;
    }

    final overdueTasks = repository.listItems(
      range: _allOverdueTasksRange(range),
      filters: ScheduleFilters(
        accountIds: accountIds,
        taskListIds: taskListIds,
        taskListFilterActive: true,
        includeCalendarEvents: false,
        includeTasks: _scope != ScheduleScope.events,
        showCompletedTasks: false,
        showNoDateTasks: false,
      ),
    );
    final results = await Future.wait([currentItems, overdueTasks]);
    return [...results[0], ...results[1]];
  }

  ScheduleRange _allOverdueTasksRange(ScheduleRange displayRange) {
    return ScheduleRange(start: DateTime(1), end: displayRange.start);
  }

  List<ScheduleItem> _agendaItems(
    List<ScheduleItem> items,
    ScheduleRange range,
  ) {
    final startDay = ScheduleProjection.day(range.start);
    return items.where((item) {
      final start = item.start;
      if (start == null) {
        return true;
      }
      if (item is CalendarScheduleItem) {
        return ScheduleProjection.intersects(item, range);
      }
      if (item is TaskScheduleItem) {
        final itemDay = ScheduleProjection.day(start);
        if (itemDay.isBefore(startDay)) {
          return !item.completed;
        }
        return start.isBefore(range.end);
      }
      return ScheduleProjection.intersects(item, range);
    }).toList();
  }

  Future<List<TaskListEntity>> _taskListsForAccounts(
    List<AccountEntity> accounts,
  ) async {
    final allLists = <TaskListEntity>[];
    for (final account in accounts) {
      final repository = ref.read(
        taskListsRepositoryForAccountProvider(account.id),
      );
      allLists.addAll(await repository.listTaskLists());
    }
    return allLists;
  }

  void _setDate(DateTime date) {
    setState(() {
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
      _selectedDate = _day(date);
      if (_mode == ScheduleViewMode.agenda) {
        _resetAgendaLoadedDays();
      }
    });
  }

  void _openDay(DateTime date) {
    setState(() {
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
      _selectedDate = _day(date);
      _mode = ScheduleViewMode.day;
      _lastSettingsMode = ScheduleViewMode.day;
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(ScheduleViewMode.day),
    );
  }

  void _setWeek(DateTime weekStart) {
    setState(() {
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
      _selectedDate = _day(weekStart);
      _mode = ScheduleViewMode.week;
      _lastSettingsMode = ScheduleViewMode.week;
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(ScheduleViewMode.week),
    );
  }

  void _setMonth(DateTime month) {
    setState(() {
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
      _selectedDate = DateTime(month.year, month.month);
      _mode = ScheduleViewMode.month;
      _lastSettingsMode = ScheduleViewMode.month;
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(ScheduleViewMode.month),
    );
  }

  void _setYear(DateTime year) {
    setState(() {
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
      _selectedDate = DateTime(year.year);
      _mode = ScheduleViewMode.year;
      _lastSettingsMode = ScheduleViewMode.year;
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(ScheduleViewMode.year),
    );
  }

  void _applyInitialScope() {
    switch (_scope) {
      case ScheduleScope.today:
        _selectedDate = _day(DateTime.now());
      case ScheduleScope.upcoming:
        _selectedDate = _day(DateTime.now());
        _mode = ScheduleViewMode.agenda;
      case ScheduleScope.tasks:
        _mode = ScheduleViewMode.agenda;
      case ScheduleScope.all || ScheduleScope.events:
        break;
    }
  }

  void _syncModeFromSettings(ScheduleViewMode settingsMode) {
    final previousSettingsMode = _lastSettingsMode;
    if (previousSettingsMode == settingsMode) {
      return;
    }
    _lastSettingsMode = settingsMode;
    if (_scope != ScheduleScope.all && _scope != ScheduleScope.events) {
      return;
    }
    if (previousSettingsMode == null || _mode == previousSettingsMode) {
      if (_mode != ScheduleViewMode.agenda &&
          settingsMode == ScheduleViewMode.agenda) {
        _resetAgendaLoadedDays();
      }
      _mode = settingsMode;
    }
  }

  void _goToToday() {
    setState(() {
      _selectedDate = _day(DateTime.now());
      if (_mode == ScheduleViewMode.agenda) {
        _resetAgendaLoadedDays();
      }
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
    });
  }

  void _setMode(ScheduleViewMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
      _lastSettingsMode = mode;
      if (mode == ScheduleViewMode.agenda) {
        _resetAgendaLoadedDays();
      }
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(mode),
    );
  }

  void _focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  void _previous() {
    if (_mode == ScheduleViewMode.agenda) {
      return;
    }
    setState(() {
      _selectedDate = switch (_mode) {
        ScheduleViewMode.day => _selectedDate.subtract(const Duration(days: 1)),
        ScheduleViewMode.week => _selectedDate.subtract(
          const Duration(days: 7),
        ),
        ScheduleViewMode.month => DateTime(
          _selectedDate.year,
          _selectedDate.month - 1,
          _selectedDate.day,
        ),
        ScheduleViewMode.year => DateTime(
          _selectedDate.year - 1,
          _selectedDate.month,
          _selectedDate.day,
        ),
        ScheduleViewMode.agenda => _selectedDate,
      };
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
    });
  }

  void _next() {
    if (_mode == ScheduleViewMode.agenda) {
      return;
    }
    setState(() {
      _selectedDate = switch (_mode) {
        ScheduleViewMode.day => _selectedDate.add(const Duration(days: 1)),
        ScheduleViewMode.week => _selectedDate.add(const Duration(days: 7)),
        ScheduleViewMode.month => DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          _selectedDate.day,
        ),
        ScheduleViewMode.year => DateTime(
          _selectedDate.year + 1,
          _selectedDate.month,
          _selectedDate.day,
        ),
        ScheduleViewMode.agenda => _selectedDate,
      };
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
    });
  }

  void _loadMoreAgendaDays() {
    if (_mode != ScheduleViewMode.agenda) {
      return;
    }
    setState(() {
      _agendaLoadedDays += _agendaPageDays;
    });
  }

  void _resetAgendaLoadedDays() {
    _agendaLoadedDays = _agendaInitialDays;
  }

  Future<void> _openCreateChoice(
    List<AccountEntity> accounts,
    List<CalendarSourceEntity> sources,
    DateTime start,
  ) async {
    final choice = await showScheduleCreateMenu(context: context);
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case ScheduleCreateChoice.event:
        unawaited(_openNewEvent(sources, start));
      case ScheduleCreateChoice.task:
        await _openNewTask(accounts, due: _day(start));
    }
  }

  Future<void> _openNewEvent(
    List<CalendarSourceEntity> sources,
    DateTime start,
  ) async {
    if (sources.isEmpty) {
      return;
    }
    final source = sources.first;
    await _openEventEditor(
      EventEditorDraft.newEvent(
        accountId: source.accountId,
        sourceId: source.id,
        providerCalendarId: source.providerCalendarId,
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
      sources,
    );
  }

  Future<void> _openItem(
    BuildContext anchorContext,
    ScheduleItem item,
    List<CalendarSourceEntity> sources, {
    Offset? globalPosition,
  }) async {
    final action = await showScheduleItemDetailsPopover(
      context: context,
      anchorContext: anchorContext,
      item: item,
      anchorPoint: globalPosition,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case ScheduleItemDetailsAction.export:
        await _exportItem(item);
      case ScheduleItemDetailsAction.edit:
        _editItem(item, sources);
    }
  }

  void _editItem(ScheduleItem item, List<CalendarSourceEntity> sources) {
    if (item is CalendarScheduleItem) {
      unawaited(
        _openEventEditor(
          EventEditorDraft.existing(
            eventId: item.id,
            accountId: item.accountId,
            sourceId: item.sourceId,
            providerCalendarId: item.providerCalendarId,
            title: item.title,
            allDay: item.allDay,
            start: item.start,
            end: item.end,
            location: item.location,
            description: item.description,
            descriptionContentType: item.descriptionContentType,
            descriptionHtml: item.descriptionHtml,
            categories: item.categories,
          ),
          sources,
        ),
      );
      return;
    }
    if (item is TaskScheduleItem) {
      _openTaskDetails(item);
    }
  }

  Future<void> _exportItem(ScheduleItem item) async {
    try {
      final file = await exportScheduleItemWithSaveDialog(item);
      if (file == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exportedFile(file.path))),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exportFailed(redactForLog(error)))),
      );
    }
  }

  void _openTaskDetails(TaskScheduleItem item) {
    setState(() {
      _taskDetailsTarget = _TaskDetailsTarget(
        accountId: item.accountId,
        taskListId: item.sourceId,
        taskId: item.id,
      );
    });
    unawaited(
      ref.read(linuxHeaderBarServiceProvider).setModalBarrierVisible(true),
    );
  }

  void _closeTaskDetails() {
    if (_taskDetailsTarget == null) {
      return;
    }
    setState(() => _taskDetailsTarget = null);
    unawaited(
      ref.read(linuxHeaderBarServiceProvider).setModalBarrierVisible(false),
    );
  }

  Future<void> _saveEvent(EventEditorDraft draft) async {
    await ref.read(calendarRepositoryProvider).updateLocalEvent(draft);
    _requestCalendarMutationSync(draft.accountId);
    if (mounted) {
      setState(() {});
    }
  }

  void _requestCalendarMutationSync(String accountId) {
    unawaited(_syncCalendarMutation(accountId));
  }

  Future<void> _syncCalendarMutation(String accountId) async {
    try {
      await ref
          .read(calendarSyncEngineForAccountFactoryProvider)(accountId)
          .incrementalSync();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.refreshFailed(redactForLog(error))),
        ),
      );
    }
  }

  Future<void> _openEventEditor(
    EventEditorDraft draft,
    List<CalendarSourceEntity> sources,
  ) async {
    final result = await showBusyMaxEventEditorDialog(
      context,
      initialDraft: draft,
      sources: sources,
      categorySuggestionsByAccount: _categorySuggestionsByAccount(),
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
    );
    if (!mounted || result == null) {
      return;
    }
    final deletedEventId = result.deletedEventId;
    if (deletedEventId != null) {
      await _deleteEvent(deletedEventId);
      return;
    }
    final savedDraft = result.draft;
    if (savedDraft != null) {
      await _saveEvent(savedDraft);
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final accountId = await ref
        .read(calendarRepositoryProvider)
        .deleteLocalEvent(eventId);
    _requestCalendarMutationSync(accountId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openNewTask(
    List<AccountEntity> accounts, {
    DateTime? due,
  }) async {
    if (accounts.isEmpty) {
      return;
    }
    final draft = await showBusyMaxNewTaskDialog(
      context,
      ref: ref,
      accounts: accounts,
      initialAccountId: ref.read(activeAccountProvider),
      initialListId: null,
      initialDueUtc: due,
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
    );
    if (draft == null) {
      return;
    }
    await ref
        .read(tasksRepositoryForAccountProvider(draft.accountId))
        .createTask(
          draft.taskListId,
          TaskCreateInput(
            title: draft.title,
            dueUtc: draft.dueUtc,
            categories: draft.categories,
          ),
        );
  }

  Map<String, List<String>> _categorySuggestionsByAccount() {
    final byAccount = <String, Set<String>>{};
    for (final item in _latestItems) {
      if (item.categories.isEmpty) {
        continue;
      }
      byAccount
          .putIfAbsent(item.accountId, () => <String>{})
          .addAll(
            item.categories.where((category) => category.trim().isNotEmpty),
          );
    }
    return {
      for (final entry in byAccount.entries)
        entry.key: entry.value.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    };
  }

  Future<void> _setTaskCompleted(TaskScheduleItem item, bool completed) async {
    final fields = <String, Object?>{
      'status': completed ? 'completed' : 'needsAction',
      'completed': completed ? DateTime.now().toUtc().toIso8601String() : null,
    };
    await ref
        .read(tasksRepositoryForAccountProvider(item.accountId))
        .patchTask(item.sourceId, item.id, TaskPatchInput(fields));
  }

  Future<void> _refreshAll() async {
    try {
      final accounts = await ref
          .read(accountsRepositoryProvider)
          .listSignedInAccounts();
      if (accounts.isEmpty) {
        return;
      }
      await ref.read(allAccountsSyncRunnerProvider)();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.allTasksRefreshed)));
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.refreshFailed(redactForLog(error))),
        ),
      );
    }
  }

  void _consumePendingCommand(
    List<CalendarSourceEntity> sources,
    List<AccountEntity> accounts,
    List<ScheduleItem> items,
  ) {
    final command = ref.watch(scheduleWorkspaceCommandProvider);
    if (command == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(scheduleWorkspaceCommandProvider.notifier).state = null;
      switch (command.kind) {
        case ScheduleWorkspaceCommandKind.today:
          _goToToday();
        case ScheduleWorkspaceCommandKind.newEvent:
          unawaited(_openNewEvent(sources, _selectedDate));
        case ScheduleWorkspaceCommandKind.newTask:
          unawaited(_openNewTask(accounts));
        case ScheduleWorkspaceCommandKind.openDate:
          _openCommandDate(command.date);
        case ScheduleWorkspaceCommandKind.openCalendarEvent:
          _openCommandDate(command.date);
          final item = _findCommandItem<CalendarScheduleItem>(items, command);
          if (item != null) {
            unawaited(_openItem(context, item, sources));
          }
        case ScheduleWorkspaceCommandKind.openTask:
          _openCommandDate(command.date);
          final item = _findCommandItem<TaskScheduleItem>(items, command);
          if (item != null) {
            unawaited(_openItem(context, item, sources));
          }
      }
    });
  }

  void _openCommandDate(DateTime? date) {
    if (date == null) {
      return;
    }
    setState(() {
      if (_scope == ScheduleScope.today || _scope == ScheduleScope.upcoming) {
        _scope = ScheduleScope.all;
      }
      _selectedDate = _day(date);
      _mode = ScheduleViewMode.agenda;
      _lastSettingsMode = ScheduleViewMode.agenda;
      _resetAgendaLoadedDays();
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(ScheduleViewMode.agenda),
    );
  }
}

T? _findCommandItem<T extends ScheduleItem>(
  List<ScheduleItem> items,
  ScheduleWorkspaceCommand command,
) {
  for (final item in items) {
    if (item is T &&
        item.id == command.itemId &&
        item.accountId == command.accountId &&
        item.sourceId == command.sourceId) {
      return item;
    }
  }
  return null;
}

class _ScheduleSearchField extends StatelessWidget {
  const _ScheduleSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BusyMaxSpacing.md,
        vertical: BusyMaxSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(YaruIcons.search),
          suffixIcon: YaruIconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(YaruIcons.window_close),
            onPressed: onClose,
          ),
          hintText: MaterialLocalizations.of(context).searchFieldLabel,
        ),
      ),
    );
  }
}

@immutable
class _HeaderBarStateSnapshot {
  const _HeaderBarStateSnapshot({
    required this.titleRange,
    required this.viewMode,
    required this.canRefresh,
    required this.searchActive,
    required this.sidebarVisible,
    required this.navigationVisible,
  });

  final String titleRange;
  final ScheduleViewMode viewMode;
  final bool canRefresh;
  final bool searchActive;
  final bool sidebarVisible;
  final bool navigationVisible;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _HeaderBarStateSnapshot &&
            titleRange == other.titleRange &&
            viewMode == other.viewMode &&
            canRefresh == other.canRefresh &&
            searchActive == other.searchActive &&
            sidebarVisible == other.sidebarVisible &&
            navigationVisible == other.navigationVisible;
  }

  @override
  int get hashCode => Object.hash(
    titleRange,
    viewMode,
    canRefresh,
    searchActive,
    sidebarVisible,
    navigationVisible,
  );
}

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.isLoading,
    required this.mode,
    required this.range,
    required this.selectedDate,
    required this.firstWeekday,
    required this.dayStartMinute,
    required this.dayEndMinute,
    required this.hasAnySources,
    required this.items,
    required this.onDaySelected,
    required this.onYearDaySelected,
    required this.onMonthSelected,
    required this.onEmptySlot,
    required this.onCreateAtDay,
    required this.onNewEvent,
    required this.onNewTask,
    required this.onPrevious,
    required this.onNext,
    required this.onAgendaLoadMore,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
  });

  final bool isLoading;
  final ScheduleViewMode mode;
  final ScheduleRange range;
  final DateTime selectedDate;
  final int firstWeekday;
  final int dayStartMinute;
  final int dayEndMinute;
  final bool hasAnySources;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onYearDaySelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onEmptySlot;
  final ValueChanged<DateTime> onCreateAtDay;
  final VoidCallback onNewEvent;
  final VoidCallback onNewTask;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onAgendaLoadMore;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.expand();
    }
    if (!hasAnySources) {
      return const SizedBox.expand();
    }
    return switch (mode) {
      ScheduleViewMode.day => ScheduleDayWeekView(
        range: range,
        selectedDate: selectedDate,
        daysShowed: 1,
        dayStartMinute: dayStartMinute,
        dayEndMinute: dayEndMinute,
        items: items,
        onDaySelected: onDaySelected,
        onEmptySlot: onEmptySlot,
        onItemSelected: onItemSelected,
        onTaskCompletionChanged: onTaskCompletionChanged,
      ),
      ScheduleViewMode.week => ScheduleDayWeekView(
        range: range,
        selectedDate: selectedDate,
        daysShowed: 7,
        dayStartMinute: dayStartMinute,
        dayEndMinute: dayEndMinute,
        items: items,
        onDaySelected: onDaySelected,
        onEmptySlot: onEmptySlot,
        onItemSelected: onItemSelected,
        onTaskCompletionChanged: onTaskCompletionChanged,
      ),
      ScheduleViewMode.month => _HorizontalSchedulePager(
        onPrevious: onPrevious,
        onNext: onNext,
        child: ScheduleMonthView(
          range: range,
          selectedDate: selectedDate,
          items: items,
          firstWeekday: firstWeekday,
          onDaySelected: onDaySelected,
          onCreateAtDay: onCreateAtDay,
          onItemSelected: onItemSelected,
          onTaskCompletionChanged: onTaskCompletionChanged,
        ),
      ),
      ScheduleViewMode.year => _HorizontalSchedulePager(
        onPrevious: onPrevious,
        onNext: onNext,
        child: ScheduleYearView(
          selectedDate: selectedDate,
          items: items,
          firstWeekday: firstWeekday,
          onDaySelected: onYearDaySelected,
          onMonthSelected: onMonthSelected,
          onCreateAtDay: onCreateAtDay,
        ),
      ),
      ScheduleViewMode.agenda => ScheduleAgendaView(
        range: range,
        items: items,
        onLoadMore: onAgendaLoadMore,
        onItemSelected: onItemSelected,
        onTaskCompletionChanged: onTaskCompletionChanged,
      ),
    };
  }
}

class _HorizontalSchedulePager extends StatelessWidget {
  const _HorizontalSchedulePager({
    required this.child,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null || velocity.abs() < 250) {
          return;
        }
        if (velocity < 0) {
          onNext();
        } else {
          onPrevious();
        }
      },
      child: child,
    );
  }
}

class _ScheduleTaskDetailsOverlay extends StatelessWidget {
  const _ScheduleTaskDetailsOverlay({
    required this.child,
    required this.target,
    required this.onClose,
  });

  final Widget child;
  final _TaskDetailsTarget? target;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    if (target == null) {
      return child;
    }
    return Stack(
      children: [
        child,
        ModalBarrier(
          color: busyMaxModalBarrierColor(context),
          dismissible: false,
        ),
        Center(
          child: BusyMaxModalEditorSurface(
            maxWidth: BusyMaxSizes.compactDetailsWidth,
            maxHeight: 760,
            child: TaskDetailsPane(
              accountId: target.accountId,
              taskListId: target.taskListId,
              taskId: target.taskId,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskDetailsTarget {
  const _TaskDetailsTarget({
    required this.accountId,
    required this.taskListId,
    required this.taskId,
  });

  final String accountId;
  final String taskListId;
  final String taskId;
}

int _firstWeekday(BuildContext context) {
  final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  return index == 0 ? DateTime.sunday : index;
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

String _scheduleRangeLabel(
  BuildContext context,
  ScheduleViewMode mode,
  ScheduleRange range,
  DateTime selectedDate,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return switch (mode) {
    ScheduleViewMode.day => DateFormat.yMMMMEEEEd(locale).format(selectedDate),
    ScheduleViewMode.month => DateFormat.yMMMM(locale).format(selectedDate),
    ScheduleViewMode.year => DateFormat.y(locale).format(selectedDate),
    ScheduleViewMode.agenda => context.l10n.viewAgenda,
    ScheduleViewMode.week => _weekRangeLabel(locale, range),
  };
}

String _weekRangeLabel(String locale, ScheduleRange range) {
  final end = range.end.subtract(const Duration(days: 1));
  if (range.start.year == end.year && range.start.month == end.month) {
    return '${DateFormat.MMMd(locale).format(range.start)}-${DateFormat.d(locale).format(end)}, ${DateFormat.y(locale).format(end)}';
  }
  if (range.start.year == end.year) {
    return '${DateFormat.MMMd(locale).format(range.start)} - ${DateFormat.MMMd(locale).format(end)}, ${DateFormat.y(locale).format(end)}';
  }
  return '${DateFormat.yMMMd(locale).format(range.start)} - ${DateFormat.yMMMd(locale).format(end)}';
}

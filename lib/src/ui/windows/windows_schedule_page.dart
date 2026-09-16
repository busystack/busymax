import 'package:busymax/src/l10n/time_format_scope.dart';
import 'dart:async';
import '../../providers/busy_provider.dart';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../app/busymax_shortcuts.dart';
import '../../app/common/busymax_design_values.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../features/schedule/presentation/schedule_item_exporter.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_commands.dart';
import '../../schedule/schedule_projection.dart';
import '../../schedule/schedule_item.dart';
import '../../features/maps/application/external_location_launcher.dart';
import '../../features/schedule/application/saved_schedule_location.dart';
import '../../schedule/schedule_event_rescheduling.dart';
import '../../features/calendar/domain/event_timing_policy.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../common/schedule/schedule_interactions.dart';
import '../common/schedule/schedule_preview_label.dart';
import 'windows_schedule_day_week_view.dart';
import '../../schedule/schedule_range.dart';
import '../../schedule/schedule_source_visibility.dart';
import '../../schedule/schedule_view_mode.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_calendar_activation_flows.dart';
import 'windows_event_editor_dialog.dart';
import 'windows_guest_update_dialog.dart';
import 'windows_schedule_source_pane.dart';
import 'windows_schedule_search_pane.dart';
import '../../schedule/schedule_search_criteria.dart';
import '../../features/schedule/presentation/schedule_search_result_text.dart';
import 'windows_task_details_dialog.dart';
import 'windows_task_editor_dialog.dart';

class WindowsSchedulePage extends ConsumerStatefulWidget {
  const WindowsSchedulePage({super.key, this.externalLocationLauncher});

  final ExternalLocationLauncher? externalLocationLauncher;

  @override
  ConsumerState<WindowsSchedulePage> createState() =>
      _WindowsSchedulePageState();
}

class _WindowsSchedulePageState extends ConsumerState<WindowsSchedulePage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _selectedDate = DateTime.now();
  var _query = '';
  bool _searchActive = false;
  bool? _sourcePaneBeforeSearch;
  ScheduleSearchCriteria? _searchCriteria;
  ScheduleSearchCriteria? _initialSearchCriteria;
  ScheduleSourceVisibility? _latestVisibility;
  late ScheduleViewMode _mode;
  var _agendaDays = 30;
  var _agendaTaskLimit = 100;
  var _refreshRevision = 0;
  String? _taskListsKey;
  Future<List<TaskListEntity>>? _taskListsFuture;
  Object? _itemsKey;
  Future<List<ScheduleItem>>? _itemsFuture;
  var _sourcePaneCollapsed = false;
  Timer? _searchDebounce;
  ScheduleWorkspaceCommand? _pendingCommand;
  bool _resolvingCommand = false;
  bool _commandRefreshPending = false;
  CalendarSourceEntity? _creationCalendar;
  ScheduleTaskListKey? _creationTaskList;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(appSettingsControllerProvider).scheduleViewMode;
    _searchFocusNode.addListener(_searchFocusChanged);
    ref.listenManual(scheduleDataRevisionProvider, (previous, next) {
      if (!next.hasValue || !mounted) return;
      _reload();
      unawaited(_revealPendingCommand());
    });
    ref.listenManual(scheduleWorkspaceCommandProvider, (previous, command) {
      if (command == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ref.read(scheduleWorkspaceCommandProvider) != command) {
          return;
        }
        ref.read(scheduleWorkspaceCommandProvider.notifier).state = null;
        _pendingCommand = null;
        switch (command.kind) {
          case ScheduleWorkspaceCommandKind.today:
            _openDay(DateTime.now());
          case ScheduleWorkspaceCommandKind.agenda:
            _selectDate(command.date ?? DateTime.now());
            _setMode(ScheduleViewMode.agenda);
          case ScheduleWorkspaceCommandKind.newEvent:
            unawaited(_createEvent(start: command.date));
          case ScheduleWorkspaceCommandKind.newTask:
            unawaited(_createTask());
          case ScheduleWorkspaceCommandKind.openDate:
            _openDay(command.date ?? DateTime.now());
          case ScheduleWorkspaceCommandKind.openCalendarEvent:
          case ScheduleWorkspaceCommandKind.openTask:
            _searchDebounce?.cancel();
            _searchController.clear();
            _query = '';
            _searchActive = false;
            _searchCriteria = null;
            _initialSearchCriteria = null;
            _searchFocusNode.unfocus();
            _openDay(command.date ?? DateTime.now());
            _pendingCommand = command;
            unawaited(_revealPendingCommand());
        }
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_searchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _revealPendingCommand() async {
    final command = _pendingCommand;
    if (command == null) return;
    if (_resolvingCommand) {
      _commandRefreshPending = true;
      return;
    }
    _commandRefreshPending = false;
    _resolvingCommand = true;
    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final filters = ScheduleFilters(
        accountIds: {if (command.accountId != null) command.accountId!},
        taskCompletion: ScheduleTaskCompletion.all,
        showNoDateTasks: true,
      );
      final items = command.kind == ScheduleWorkspaceCommandKind.openTask
          ? await repository.listAllTasks(filters: filters)
          : await repository.listItems(
              range: ScheduleRange.day(command.date ?? DateTime.now()),
              filters: filters,
            );
      if (!mounted || _pendingCommand != command) return;
      final item = items.where(command.matchesItem).firstOrNull;
      if (item == null) return; // Keep pending while initial sync supplies it.
      _pendingCommand = null;
      await _showItemDetails(item);
    } on Object catch (_) {
      if (mounted) {
        unawaited(
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: Text(AppLocalizations.of(context).scheduleUnavailable),
              severity: InfoBarSeverity.error,
              action: Button(
                onPressed: () => unawaited(_revealPendingCommand()),
                child: Text(AppLocalizations.of(context).retry),
              ),
            ),
          ),
        );
      }
    } finally {
      _resolvingCommand = false;
      if (mounted &&
          _pendingCommand != null &&
          (_pendingCommand != command || _commandRefreshPending)) {
        unawaited(_revealPendingCommand());
      }
    }
  }

  void _reload() {
    setState(() {
      _refreshRevision += 1;
      _taskListsKey = null;
      _taskListsFuture = null;
      _itemsKey = null;
      _itemsFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsStreamProvider);
    if (accountsState.isLoading && accountsState.valueOrNull == null) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }
    if (accountsState.hasError && accountsState.valueOrNull == null) {
      return ScaffoldPage(
        content: Center(
          child: InfoBar(
            title: Text(AppLocalizations.of(context).scheduleUnavailable),
            severity: InfoBarSeverity.error,
          ),
        ),
      );
    }
    final accounts = accountsState.valueOrNull ?? const <AccountEntity>[];
    final accountIds = [for (final account in accounts) account.id];
    return StreamBuilder<List<CalendarSourceEntity>>(
      stream: ref
          .watch(calendarRepositoryProvider)
          .watchSourcesForAccounts(accountIds),
      builder: (context, sourcesSnapshot) {
        if (sourcesSnapshot.connectionState == ConnectionState.waiting &&
            !sourcesSnapshot.hasData) {
          return const ScaffoldPage(content: Center(child: ProgressRing()));
        }
        if (sourcesSnapshot.hasError && !sourcesSnapshot.hasData) {
          return ScaffoldPage(
            content: Center(
              child: InfoBar(
                title: Text(AppLocalizations.of(context).scheduleUnavailable),
                severity: InfoBarSeverity.error,
              ),
            ),
          );
        }
        final sources = sourcesSnapshot.data ?? const <CalendarSourceEntity>[];
        return FutureBuilder<List<TaskListEntity>>(
          future: _taskListsFor(accounts),
          builder: (context, listsSnapshot) {
            if (listsSnapshot.connectionState != ConnectionState.done &&
                !listsSnapshot.hasData) {
              return const ScaffoldPage(content: Center(child: ProgressRing()));
            }
            final taskLists = listsSnapshot.data ?? const <TaskListEntity>[];
            final settings = ref.watch(appSettingsControllerProvider);
            final visibility = ScheduleSourceVisibility.fromSources(
              calendarSources: sources,
              taskLists: taskLists,
              settings: settings,
            );
            return _buildPage(
              context,
              accounts: accounts,
              sources: sources,
              taskLists: taskLists,
              visibility: visibility,
            );
          },
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required List<AccountEntity> accounts,
    required List<CalendarSourceEntity> sources,
    required List<TaskListEntity> taskLists,
    required ScheduleSourceVisibility visibility,
  }) {
    _latestVisibility = visibility;
    if (_searchActive && _searchCriteria == null) _initializeSearch();
    _creationCalendar = writableCalendarSources(sources)
        .where(
          (source) => visibility.visibleCalendarSourceIds.contains(source.id),
        )
        .firstOrNull;
    _creationTaskList = visibility.visibleTaskListKeys.firstOrNull;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final range = _rangeForMode();
    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowSourcePane = BusyMaxBreakpoints.showsSourcePane(
          constraints.maxWidth,
        );
        final showSourcePane = canShowSourcePane && !_sourcePaneCollapsed;
        final sourcePane = _searchActive && _searchCriteria != null
            ? _searchPane(accounts, sources, taskLists)
            : WindowsScheduleSourcePane(
                selectedDate: _selectedDate,
                accounts: accounts,
                calendarSources: sources,
                taskLists: taskLists,
                visibleCalendarSourceIds: visibility.visibleCalendarSourceIds,
                visibleTaskListKeys: visibility.visibleTaskListKeys,
                onDateSelected: _openDay,
                onCalendarVisibilityChanged: _setCalendarVisible,
                onTaskListVisibilityChanged: _setTaskListVisible,
                onSourcesChanged: _reload,
              );
        return CallbackShortcuts(
          bindings: {
            BusyMaxShortcutActivators.search: _focusSearch,
            BusyMaxShortcutActivators.sidebar: () {
              if (canShowSourcePane) {
                setState(() => _sourcePaneCollapsed = !showSourcePane);
              } else {
                unawaited(
                  _showSourcesDialog(
                    accounts: accounts,
                    sources: sources,
                    taskLists: taskLists,
                    visibility: visibility,
                  ),
                );
              }
            },
            BusyMaxShortcutActivators.dismiss: _dismissSearch,
            const SingleActivator(
              LogicalKeyboardKey.arrowLeft,
              shift: true,
            ): () =>
                _invokeUnmodifiedShortcut(() => _movePeriod(-1)),
            const SingleActivator(
              LogicalKeyboardKey.arrowRight,
              shift: true,
            ): () =>
                _invokeUnmodifiedShortcut(() => _movePeriod(1)),
            const SingleActivator(LogicalKeyboardKey.keyE): () =>
                _invokeUnmodifiedShortcut(() => unawaited(_createEvent())),
            const SingleActivator(LogicalKeyboardKey.keyT): () =>
                _invokeUnmodifiedShortcut(() => unawaited(_createTask())),
            const SingleActivator(LogicalKeyboardKey.keyT, shift: true): () =>
                _invokeUnmodifiedShortcut(() => _selectDate(DateTime.now())),
            const SingleActivator(LogicalKeyboardKey.digit1): () =>
                _invokeUnmodifiedShortcut(() => _setMode(ScheduleViewMode.day)),
            const SingleActivator(LogicalKeyboardKey.numpad1): () =>
                _invokeUnmodifiedShortcut(() => _setMode(ScheduleViewMode.day)),
            const SingleActivator(LogicalKeyboardKey.digit2): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.week),
                ),
            const SingleActivator(LogicalKeyboardKey.numpad2): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.week),
                ),
            const SingleActivator(LogicalKeyboardKey.digit3): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.month),
                ),
            const SingleActivator(LogicalKeyboardKey.numpad3): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.month),
                ),
            const SingleActivator(LogicalKeyboardKey.digit4): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.year),
                ),
            const SingleActivator(LogicalKeyboardKey.numpad4): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.year),
                ),
            const SingleActivator(LogicalKeyboardKey.digit5): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.agenda),
                ),
            const SingleActivator(LogicalKeyboardKey.numpad5): () =>
                _invokeUnmodifiedShortcut(
                  () => _setMode(ScheduleViewMode.agenda),
                ),
          },
          child: Focus(
            autofocus: true,
            child: ScaffoldPage(
              header: PageHeader(
                title: Text(_periodTitle(l10n, locale, range)),
                commandBar: CommandBar(
                  compactBreakpointWidth: BusyMaxBreakpoints.compact,
                  primaryItems: [
                    if (!showSourcePane)
                      CommandBarButton(
                        icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more)),
                        label: Text(
                          _searchActive
                              ? l10n.searchFiltersAction
                              : l10n.showSidebar,
                        ),
                        onPressed: () {
                          if (canShowSourcePane) {
                            setState(() => _sourcePaneCollapsed = false);
                          } else {
                            unawaited(
                              _showSourcesDialog(
                                accounts: accounts,
                                sources: sources,
                                taskLists: taskLists,
                                visibility: visibility,
                              ),
                            );
                          }
                        },
                      ),
                    if (!_searchActive)
                      CommandBarButton(
                        icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.today)),
                        label: Text(l10n.today),
                        onPressed: () => _selectDate(DateTime.now()),
                      ),
                    if (!_searchActive && _mode != ScheduleViewMode.agenda) ...[
                      CommandBarButton(
                        icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.previous)),
                        tooltip: l10n.shortcutPreviousPeriodDescription,
                        onPressed: () => _movePeriod(-1),
                      ),
                      CommandBarButton(
                        icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.next)),
                        tooltip: l10n.shortcutNextPeriodDescription,
                        onPressed: () => _movePeriod(1),
                      ),
                    ],
                    CommandBarButton(
                      icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add)),
                      label: Text(l10n.newEvent),
                      onPressed: () => unawaited(_createEvent()),
                    ),
                  ],
                  secondaryItems: [
                    CommandBarButton(
                      icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.task)),
                      label: Text(l10n.newTask),
                      onPressed: () => unawaited(_createTask()),
                    ),
                    CommandBarButton(
                      icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.refresh)),
                      label: Text(l10n.refresh),
                      onPressed: _reload,
                    ),
                    CommandBarButton(
                      icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar)),
                      label: Text(l10n.importIcsFile),
                      onPressed: () => unawaited(
                        showWindowsIcsImportFlow(
                          context,
                          ref,
                        ).then((_) => _reload()),
                      ),
                    ),
                  ],
                ),
              ),
              content: Row(
                children: [
                  if (showSourcePane) ...[
                    SizedBox(
                      width: BusyMaxDimensions.sourcePaneWidth,
                      child: sourcePane,
                    ),
                    const Divider(direction: Axis.vertical),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            20,
                            0,
                            20,
                            12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextBox(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  placeholder: l10n.windowsSearch,
                                  suffix: _searchActive
                                      ? Tooltip(
                                          message: l10n.searchClearText,
                                          child: IconButton(
                                            icon: const Icon(FluentIcons.clear),
                                            onPressed: () {
                                              _searchDebounce?.cancel();
                                              _searchController.clear();
                                              setState(() => _query = '');
                                            },
                                          ),
                                        )
                                      : null,
                                  prefix: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      start: 10,
                                    ),
                                    child: Icon(
                                      windowsBusyMaxGlyph(BusyMaxGlyph.search),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (!_searchActive) _activateSearch();
                                    _searchDebounce?.cancel();
                                    _searchDebounce = Timer(
                                      const Duration(milliseconds: 250),
                                      () {
                                        if (!mounted) return;
                                        _query = value;
                                        _reload();
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_searchActive)
                                Tooltip(
                                  message: l10n.close,
                                  child: IconButton(
                                    icon: const Icon(FluentIcons.cancel),
                                    onPressed: _dismissSearch,
                                  ),
                                )
                              else
                                _ViewModeMenu(mode: _mode, onChanged: _setMode),
                            ],
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<List<ScheduleItem>>(
                            future: _itemsFor(
                              range: range,
                              accounts: accounts,
                              visibility: visibility,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                      ConnectionState.done &&
                                  (_searchActive || !snapshot.hasData)) {
                                return const Center(child: ProgressRing());
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: InfoBar(
                                    title: Text(l10n.scheduleUnavailable),
                                    severity: InfoBarSeverity.error,
                                    action: Button(
                                      onPressed: _reload,
                                      child: Text(l10n.retry),
                                    ),
                                  ),
                                );
                              }
                              final items = snapshot.data ?? const [];
                              if (items.isEmpty && _searchActive) {
                                return _WindowsScheduleEmptyState(
                                  searching: _searchActive,
                                  noVisibleSources:
                                      _searchCriteria?.hasSources == false,
                                );
                              }
                              if (_searchActive) {
                                return _AgendaList(
                                  key: const ValueKey('windows-search-results'),
                                  items: items,
                                  locale: locale,
                                  onOpen: _showItemDetails,
                                  searchCriteria: _searchCriteria,
                                  searchQuery: _query,
                                );
                              }
                              return _ScheduleModeView(
                                mode: _mode,
                                selectedDate: _selectedDate,
                                range: range,
                                items: items,
                                locale: locale,
                                onOpen: _showItemDetails,
                                onSelectDate: _openDay,
                                onLoadMoreAgenda: _loadMoreAgenda,
                                onVisibleDateChanged: _selectDate,
                                onEmptySlot: (start) =>
                                    unawaited(_createEvent(start: start)),
                                onRangeCreated:
                                    writableCalendarSources(sources).isEmpty
                                    ? null
                                    : (interval) => unawaited(
                                        _createEvent(interval: interval),
                                      ),
                                onReschedule: _rescheduleEvent,
                                onTaskCompletionChanged: _setTaskCompleted,
                                dayStartMinute: ref
                                    .read(appSettingsControllerProvider)
                                    .scheduleDayStartMinute,
                                dayEndMinute: ref
                                    .read(appSettingsControllerProvider)
                                    .scheduleDayEndMinute,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createEvent({
    DateTime? start,
    ScheduleInterval? interval,
  }) async {
    final changed = await showWindowsEventEditorDialog(
      context,
      ref,
      initialStart: start ?? _selectedDate,
      initialInterval: interval,
      initialAccountId: _creationCalendar?.accountId,
      initialSourceId: _creationCalendar?.id,
    );
    if (changed && mounted) _reload();
  }

  Future<void> _rescheduleEvent(
    ScheduleRescheduleRequest request,
    bool Function() isActive,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await ScheduleReschedulingCoordinator(
        repository: ref.read(calendarRepositoryProvider),
        chooseScope: (detail, following) =>
            showWindowsRecurringEventMutationScope(
              context,
              detail.provider,
              supportsFollowingOverride: following,
            ),
        chooseGuestUpdates: (_) => showWindowsGuestUpdateDialog(
          context,
          provider: request.item.provider,
          action: WindowsGuestUpdateAction.save,
        ),
        requestSync: (accountId) async => ref
            .read(
              pendingCalendarMutationSyncRequesterForAccountProvider(accountId),
            )
            .request(),
      ).commit(request, isActive: () => mounted && isActive());
      if (!mounted) return;
      _reload();
      if (result == ScheduleRescheduleResult.savedWithNotificationFailure) {
        unawaited(
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: Text(l10n.scheduleRescheduleNotificationsFailed),
              severity: InfoBarSeverity.warning,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _reload();
      unawaited(
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(
              error is StaleEventTiming
                  ? l10n.scheduleRescheduleStale
                  : l10n.scheduleRescheduleFailed,
            ),
            severity: InfoBarSeverity.error,
          ),
        ),
      );
    }
  }

  Future<void> _setTaskCompleted(TaskScheduleItem item, bool completed) async {
    await ref
        .read(tasksRepositoryForAccountProvider(item.accountId))
        .patchTask(
          item.sourceId,
          item.id,
          TaskPatchInput({
            'status': completed ? 'completed' : 'needsAction',
            'completed': completed
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          }),
        );
    if (mounted) _reload();
  }

  Future<void> _createTask() async {
    final changed = await showWindowsTaskEditorDialog(
      context,
      ref,
      initialDate: _selectedDate,
      initialAccountId: _creationTaskList?.accountId,
      initialTaskListId: _creationTaskList?.taskListId,
    );
    if (changed && mounted) _reload();
  }

  void _initializeSearch() {
    final visibility = _latestVisibility;
    if (visibility == null) return;
    final now = DateTime.now();
    _initialSearchCriteria = ScheduleSearchCriteria(
      referenceDate: DateTime(now.year, now.month, now.day),
      firstWeekday: DateTime.monday,
      sourceIds: visibility.visibleCalendarSourceIds,
      taskListKeys: visibility.visibleTaskListKeys,
    );
    _searchCriteria = _initialSearchCriteria;
  }

  void _activateSearch() {
    if (_searchActive) return;
    setState(() {
      _sourcePaneBeforeSearch = _sourcePaneCollapsed;
      _searchActive = true;
      _initializeSearch();
    });
  }

  void _searchFocusChanged() {
    if (_searchFocusNode.hasFocus) _activateSearch();
  }

  void _focusSearch() {
    _activateSearch();
    _searchFocusNode.requestFocus();
  }

  Widget _searchPane(
    List<AccountEntity> accounts,
    List<CalendarSourceEntity> sources,
    List<TaskListEntity> taskLists, {
    VoidCallback? refresh,
  }) => WindowsScheduleSearchPane(
    value: _searchCriteria!,
    accounts: accounts,
    sources: sources,
    taskLists: taskLists,
    onChanged: (value) {
      setState(() => _searchCriteria = value);
      refresh?.call();
    },
    onClear: () {
      setState(() => _searchCriteria = _initialSearchCriteria);
      refresh?.call();
    },
  );

  void _dismissSearch() {
    if (!_searchActive) return;
    _searchActive = false;
    _sourcePaneCollapsed = _sourcePaneBeforeSearch ?? _sourcePaneCollapsed;
    _sourcePaneBeforeSearch = null;
    _searchCriteria = null;
    _initialSearchCriteria = null;
    _searchDebounce?.cancel();
    _searchController.clear();
    _query = '';
    _searchFocusNode.unfocus();
    _reload();
  }

  void _invokeUnmodifiedShortcut(VoidCallback callback) {
    if (_searchActive) return;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return;
    }
    callback();
  }

  Future<List<TaskListEntity>> _taskListsFor(List<AccountEntity> accounts) {
    final key =
        accounts
            .where((account) => account.isTaskCapable)
            .map((account) => account.id)
            .toList()
          ..sort();
    final encodedKey = key.join('\u0000');
    if (_taskListsKey != encodedKey || _taskListsFuture == null) {
      _taskListsKey = encodedKey;
      _taskListsFuture = Future.wait([
        for (final accountId in key)
          ref
              .read(taskListsRepositoryForAccountProvider(accountId))
              .listTaskLists(),
      ]).then((groups) => [for (final group in groups) ...group]);
    }
    return _taskListsFuture!;
  }

  Future<List<ScheduleItem>> _itemsFor({
    required ScheduleRange range,
    required List<AccountEntity> accounts,
    required ScheduleSourceVisibility visibility,
  }) {
    final calendarIds = visibility.visibleCalendarSourceIds.toList()..sort();
    final taskKeys =
        visibility.visibleTaskListKeys
            .map((key) => '${key.accountId}/${key.taskListId}')
            .toList()
          ..sort();
    final accountIds = [for (final account in accounts) account.id]..sort();
    final normalKey = [
      _refreshRevision,
      _mode.name,
      range.start.toIso8601String(),
      range.end.toIso8601String(),
      _query,
      accountIds.join(','),
      calendarIds.join(','),
      taskKeys.join(','),
    ].join('|');
    final key = (normalKey, _searchActive, _searchCriteria);
    if (_itemsKey == key && _itemsFuture != null) return _itemsFuture!;
    _itemsKey = key;
    final filters = ScheduleFilters(
      query: _query,
      accountIds: accountIds.toSet(),
      sourceIds: visibility.visibleCalendarSourceIds,
      taskListKeys: visibility.visibleTaskListKeys,
      sourceFilterActive: true,
      taskListFilterActive: true,
      includeCalendarEvents: true,
      includeTasks: true,
      taskCompletion: ScheduleTaskCompletion.all,
      showNoDateTasks: _mode == ScheduleViewMode.agenda,
    );
    _itemsFuture = _searchActive && _searchCriteria != null
        ? ref
              .read(scheduleRepositoryProvider)
              .listItems(
                range: _searchCriteria!.range ?? range,
                filters: _searchCriteria!.filters(_query),
              )
        : _loadItems(range, filters);
    return _itemsFuture!;
  }

  Future<List<ScheduleItem>> _loadItems(
    ScheduleRange range,
    ScheduleFilters filters,
  ) async {
    final repository = ref.read(scheduleRepositoryProvider);
    final items = <ScheduleItem>[
      ...await repository.listItems(range: range, filters: filters),
    ];
    if (_mode == ScheduleViewMode.agenda) {
      final overdue = await repository.listOverdueTasks(
        before: range.start,
        limit: _agendaTaskLimit,
        filters: filters,
      );
      final noDate = await repository.listNoDateTasks(
        limit: _agendaTaskLimit,
        filters: filters,
      );
      items.addAll(overdue.items);
      items.addAll(noDate.items);
    }
    final unique = <String, ScheduleItem>{};
    for (final item in items) {
      unique['${item.kind.name}/${item.accountId}/${item.sourceId}/${item.id}'] =
          item;
    }
    final result = unique.values.toList()
      ..sort((left, right) {
        final leftStart = left.start;
        final rightStart = right.start;
        if (leftStart == null && rightStart != null) return 1;
        if (leftStart != null && rightStart == null) return -1;
        final dateOrder = leftStart?.compareTo(rightStart!) ?? 0;
        return dateOrder != 0
            ? dateOrder
            : left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    return result;
  }

  ScheduleRange _rangeForMode() => switch (_mode) {
    ScheduleViewMode.day => ScheduleRange.day(_selectedDate),
    ScheduleViewMode.week => ScheduleRange.week(_selectedDate),
    ScheduleViewMode.month => ScheduleRange.month(_selectedDate),
    ScheduleViewMode.year => ScheduleRange.year(_selectedDate),
    ScheduleViewMode.agenda => ScheduleRange(
      start: _dateOnly(_selectedDate),
      end: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + _agendaDays,
      ),
    ),
  };

  String _periodTitle(
    AppLocalizations l10n,
    String locale,
    ScheduleRange range,
  ) => switch (_mode) {
    ScheduleViewMode.day => DateFormat.yMMMMEEEEd(locale).format(_selectedDate),
    ScheduleViewMode.week =>
      '${DateFormat.yMMMd(locale).format(range.start)} – '
          '${DateFormat.yMMMd(locale).format(range.end.subtract(const Duration(days: 1)))}',
    ScheduleViewMode.month => DateFormat.yMMMM(locale).format(_selectedDate),
    ScheduleViewMode.year => DateFormat.y(locale).format(_selectedDate),
    ScheduleViewMode.agenda => l10n.viewAgenda,
  };

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
      _itemsKey = null;
    });
  }

  void _openDay(DateTime date) {
    _selectDate(date);
    _setMode(ScheduleViewMode.day);
  }

  void _movePeriod(int direction) {
    final next = switch (_mode) {
      ScheduleViewMode.day => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + direction,
      ),
      ScheduleViewMode.week => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + (7 * direction),
      ),
      ScheduleViewMode.month => DateTime(
        _selectedDate.year,
        _selectedDate.month + direction,
        1,
      ),
      ScheduleViewMode.year => DateTime(
        _selectedDate.year + direction,
        _selectedDate.month,
        1,
      ),
      ScheduleViewMode.agenda => _selectedDate,
    };
    _selectDate(next);
  }

  void _setMode(ScheduleViewMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _itemsKey = null;
    });
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setScheduleViewMode(mode),
    );
  }

  void _loadMoreAgenda() {
    setState(() {
      _agendaDays += 30;
      _agendaTaskLimit += 100;
      _itemsKey = null;
    });
  }

  void _setCalendarVisible(CalendarSourceEntity source, bool visible) {
    unawaited(
      ref
          .read(calendarRepositoryProvider)
          .setSourceSelected(source.id, visible)
          .then((_) => _reload()),
    );
  }

  void _setTaskListVisible(TaskListEntity list, bool visible) {
    unawaited(
      ref
          .read(appSettingsControllerProvider.notifier)
          .setTaskListVisibleInSchedule(
            accountId: list.accountId,
            taskListId: list.id,
            visible: visible,
          )
          .then((_) => _reload()),
    );
  }

  Future<void> _showSourcesDialog({
    required List<AccountEntity> accounts,
    required List<CalendarSourceEntity> sources,
    required List<TaskListEntity> taskLists,
    required ScheduleSourceVisibility visibility,
  }) {
    if (_searchActive && _searchCriteria != null) {
      return showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => ContentDialog(
            title: Text(AppLocalizations.of(context).searchFilters),
            content: SizedBox(
              width: 360,
              height: math.min(MediaQuery.sizeOf(context).height - 180, 620),
              child: _searchPane(
                accounts,
                sources,
                taskLists,
                refresh: () => update(() {}),
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).close),
              ),
            ],
          ),
        ),
      );
    }
    final visibleCalendars = {...visibility.visibleCalendarSourceIds};
    final visibleTaskLists = {...visibility.visibleTaskListKeys};
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: Text(AppLocalizations.of(context).showSidebar),
          content: SizedBox(
            width: 520,
            height: math.min(MediaQuery.sizeOf(context).height - 180, 620),
            child: WindowsScheduleSourcePane(
              selectedDate: _selectedDate,
              accounts: accounts,
              calendarSources: sources,
              taskLists: taskLists,
              visibleCalendarSourceIds: visibleCalendars,
              visibleTaskListKeys: visibleTaskLists,
              onDateSelected: (date) {
                Navigator.pop(dialogContext);
                _openDay(date);
              },
              onCalendarVisibilityChanged: (source, visible) {
                setDialogState(() {
                  if (visible) {
                    visibleCalendars.add(source.id);
                  } else {
                    visibleCalendars.remove(source.id);
                  }
                });
                _setCalendarVisible(source, visible);
              },
              onTaskListVisibilityChanged: (list, visible) {
                final key = ScheduleTaskListKey(
                  accountId: list.accountId,
                  taskListId: list.id,
                );
                setDialogState(() {
                  if (visible) {
                    visibleTaskLists.add(key);
                  } else {
                    visibleTaskLists.remove(key);
                  }
                });
                _setTaskListVisible(list, visible);
              },
              onSourcesChanged: _reload,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).close),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showItemDetails(ScheduleItem item) async {
    final locationDestination = await resolveSavedScheduleLocation(
      item: item,
      repository: ref.read(locationResolutionRepositoryProvider),
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = _itemDateLabel(context, item, locale);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                [
                  time,
                  ?item.sourceName,
                  ?item.accountDisplayName,
                  if (item case CalendarScheduleItem(:final description?))
                    description,
                  if (item case TaskScheduleItem(:final notes?)) notes,
                ].where((value) => value.trim().isNotEmpty).join('\n'),
              ),
              if (locationDestination != null) ...[
                const SizedBox(height: 12),
                _buildLocationRow(dialogContext, item, locationDestination),
              ] else if (item case CalendarScheduleItem(:final location?)) ...[
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(location),
                ],
              ],
              if (item is CalendarScheduleItem) ...[
                if (item.canSendReply) Text(l10n.nextcloudAttendeeRestrictions),
                if (item.organizer != null)
                  SelectableText(
                    '${l10n.organizer}: ${item.organizer!['displayName'] ?? item.organizer!['email'] ?? item.organizer!['value'] ?? ''}',
                  ),
                for (final attendee in item.attendees) ...[
                  SelectableText(
                    '${attendee['displayName'] ?? attendee['email'] ?? attendee['value'] ?? ''} · ${attendee['responseStatus'] ?? ''}',
                  ),
                  if (attendee['scheduleStatus'] != null)
                    SelectableText(
                      '${l10n.nextcloudSchedulingStatus}: ${attendee['scheduleStatus']}',
                    ),
                ],
                if (item.canRespondToInvitation) ...[
                  if (item.provider == BusyProvider.nextcloud)
                    Text(l10n.nextcloudSchedulingPending),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (response, label) in [
                        (
                          CalendarInvitationResponse.accept,
                          l10n.acceptInvitation,
                        ),
                        (
                          CalendarInvitationResponse.tentative,
                          l10n.tentativeInvitation,
                        ),
                        (
                          CalendarInvitationResponse.decline,
                          l10n.declineInvitation,
                        ),
                      ])
                        Button(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            unawaited(_respondToInvitation(item, response));
                          },
                          child: Text(label),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          if (item.capabilities.canEdit)
            Button(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_edit(item));
              },
              child: Text(
                item is TaskScheduleItem ? l10n.editTask : l10n.editEvent,
              ),
            ),
          if (item.capabilities.canDelete)
            Button(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_delete(item));
              },
              child: Text(switch (item) {
                CalendarScheduleItem(isNextcloudAttendee: true) =>
                  l10n.nextcloudDeclineAndRemove,
                CalendarScheduleItem(
                  isNextcloudMeeting: true,
                  isOrganizer: true,
                ) =>
                  l10n.nextcloudCancelMeeting,
                _ => l10n.delete,
              }),
            ),
          Button(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_export(item));
            },
            child: Text(l10n.export),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    BuildContext dialogContext,
    ScheduleItem item,
    ExternalLocationDestination destination,
  ) {
    final displayedLocation = savedScheduleLocationDisplayText(
      item,
      destination,
    );
    final action = Button(
      key: const ValueKey('windows-saved-location-open'),
      onPressed: () {
        Navigator.pop(dialogContext);
        unawaited(_openSavedLocation(destination));
      },
      child: Text(
        destination.kind == ExternalLocationDestinationKind.link
            ? AppLocalizations.of(dialogContext).openLink
            : AppLocalizations.of(dialogContext).mapsShow,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final locationText = SelectableText(displayedLocation);
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [locationText, const SizedBox(height: 8), action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: locationText),
            const SizedBox(width: 8),
            action,
          ],
        );
      },
    );
  }

  Future<void> _openSavedLocation(
    ExternalLocationDestination destination,
  ) async {
    try {
      final launcher =
          widget.externalLocationLauncher ??
          ExternalLocationLauncher(
            platform: () => ExternalLocationPlatform.windows,
          );
      final result = await launcher.open(destination);
      if (result == ExternalLocationLaunchResult.opened) return;
    } on Object {
      // The external handoff is best-effort and never affects saved data.
    }
    if (mounted) {
      unawaited(
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(
              AppLocalizations.of(context).externalLocationOpenFailed,
            ),
            severity: InfoBarSeverity.error,
          ),
        ),
      );
    }
  }

  Future<void> _edit(ScheduleItem item) async {
    if (!mounted) return;
    final currentContext = context;
    final bool changed;
    if (item is CalendarScheduleItem) {
      changed = await showWindowsEventEditorDialog(
        currentContext,
        ref,
        eventId: item.id,
      );
    } else if (item is TaskScheduleItem) {
      changed = await showWindowsTaskDetailsDialog(currentContext, ref, item);
    } else {
      return;
    }
    if (changed && mounted) _reload();
  }

  Future<void> _respondToInvitation(
    CalendarScheduleItem item,
    CalendarInvitationResponse response,
  ) async {
    if (!item.canRespondToInvitation) return;
    final l10n = AppLocalizations.of(context);
    try {
      RecurringEventMutationScope? scope;
      if (item.provider == BusyProvider.nextcloud &&
          item.providerRecurringEventId != null) {
        scope = await showWindowsRecurringEventMutationScope(
          context,
          item.provider,
          supportsFollowingOverride: false,
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
      if (mounted) _reload();
    } on Object {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          content: InfoBar(
            title: Text(l10n.operationFailed),
            severity: InfoBarSeverity.error,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _export(ScheduleItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      final rawICalendar = item is CalendarScheduleItem
          ? await ref
                .read(calendarRepositoryProvider)
                .nativeEventExport(item.id)
          : item is TaskScheduleItem && item.provider == BusyProvider.nextcloud
          ? await ref
                .read(tasksRepositoryForAccountProvider(item.accountId))
                .nativeTaskExport(item.sourceId, item.id)
          : null;
      final file = await exportScheduleItemWithSaveDialog(
        item,
        rawICalendar: rawICalendar,
      );
      if (file == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          title: Text(l10n.export),
          content: Text(l10n.exportedFile(file.path)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } on Object catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          title: Text(l10n.export),
          content: InfoBar(
            title: Text(l10n.exportFailed(l10n.operationFailed)),
            severity: InfoBarSeverity.error,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _delete(ScheduleItem item) async {
    if (!item.capabilities.canDelete) return;
    final l10n = AppLocalizations.of(context);
    RecurringEventMutationScope? scope;
    if (item is CalendarScheduleItem && item.providerRecurringEventId != null) {
      scope = await showDialog<RecurringEventMutationScope>(
        context: context,
        builder: (context) => ContentDialog(
          title: Text(l10n.deleteEvent),
          content: Text(l10n.chooseRecurringEventScope),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            Button(
              onPressed: () => Navigator.pop(
                context,
                RecurringEventMutationScope.singleOccurrence,
              ),
              child: Text(l10n.singleOccurrence),
            ),
            if (supportsThisAndFollowingEventMutation(item.provider) &&
                !item.isNextcloudAttendee)
              Button(
                onPressed: () => Navigator.pop(
                  context,
                  RecurringEventMutationScope.thisAndFuture,
                ),
                child: Text(l10n.thisAndFollowingEvents),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                RecurringEventMutationScope.entireSeries,
              ),
              child: Text(l10n.entireSeries),
            ),
          ],
        ),
      );
      if (scope == null) return;
    }
    var guestUpdatePolicy = CalendarGuestUpdatePolicy.send;
    final hasGuestDeliveryChoice =
        item is CalendarScheduleItem &&
        item.isOrganizer == true &&
        _calendarItemHasExternalGuests(item);
    if (hasGuestDeliveryChoice) {
      if (!mounted) return;
      final choice = await showWindowsGuestUpdateDialog(
        context,
        provider: item.provider,
        action: WindowsGuestUpdateAction.delete,
      );
      if (choice == null) return;
      guestUpdatePolicy = choice;
    } else if (scope == null ||
        (item is CalendarScheduleItem && item.isNextcloudAttendee)) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: Text(
            item is CalendarScheduleItem && item.isNextcloudAttendee
                ? l10n.nextcloudDeclineAndRemove
                : item is TaskScheduleItem
                ? l10n.deleteTask
                : l10n.deleteEvent,
          ),
          content: Text(
            item is CalendarScheduleItem && item.isNextcloudAttendee
                ? l10n.nextcloudDeclineRemovalWarning
                : item.title,
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return;
    }
    try {
      switch (item) {
        case CalendarScheduleItem():
          final accountId = await ref
              .read(calendarRepositoryProvider)
              .deleteLocalEvent(
                item.id,
                recurringScope: scope,
                guestUpdatePolicy: guestUpdatePolicy,
              );
          ref
              .read(
                pendingCalendarMutationSyncRequesterForAccountProvider(
                  accountId,
                ),
              )
              .request();
        case TaskScheduleItem():
          await ref
              .read(tasksRepositoryForAccountProvider(item.accountId))
              .deleteTask(item.sourceId, item.id);
      }
      if (mounted) _reload();
    } on Object catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          content: InfoBar(
            title: Text(l10n.operationFailed),
            severity: InfoBarSeverity.error,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    }
  }
}

bool _calendarItemHasExternalGuests(CalendarScheduleItem item) =>
    item.attendees.any(
      (attendee) => attendee['self'] != true && attendee['organizer'] != true,
    );

class _ViewModeMenu extends StatelessWidget {
  const _ViewModeMenu({required this.mode, required this.onChanged});

  final ScheduleViewMode mode;
  final ValueChanged<ScheduleViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropDownButton(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(windowsBusyMaxGlyph(_modeGlyph(mode))),
          const SizedBox(width: 8),
          Text(_modeLabel(AppLocalizations.of(context), mode)),
        ],
      ),
      items: [
        for (final value in ScheduleViewMode.values)
          MenuFlyoutItem(
            leading: Icon(windowsBusyMaxGlyph(_modeGlyph(value))),
            text: Text(_modeLabel(AppLocalizations.of(context), value)),
            onPressed: () => onChanged(value),
          ),
      ],
    );
  }
}

class _ScheduleModeView extends StatelessWidget {
  const _ScheduleModeView({
    required this.mode,
    required this.selectedDate,
    required this.range,
    required this.items,
    required this.locale,
    required this.onOpen,
    required this.onSelectDate,
    required this.onLoadMoreAgenda,
    required this.onVisibleDateChanged,
    required this.onEmptySlot,
    required this.onRangeCreated,
    required this.onReschedule,
    required this.onTaskCompletionChanged,
    required this.dayStartMinute,
    required this.dayEndMinute,
  });

  final ScheduleViewMode mode;
  final DateTime selectedDate;
  final ScheduleRange range;
  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onLoadMoreAgenda;
  final ValueChanged<DateTime> onVisibleDateChanged;
  final ValueChanged<DateTime> onEmptySlot;
  final ValueChanged<ScheduleInterval>? onRangeCreated;
  final ScheduleRescheduleCallback onReschedule;
  final void Function(TaskScheduleItem, bool) onTaskCompletionChanged;
  final int dayStartMinute;
  final int dayEndMinute;

  @override
  Widget build(BuildContext context) => switch (mode) {
    ScheduleViewMode.day || ScheduleViewMode.week => WindowsScheduleDayWeekView(
      key: ValueKey('windows-${mode.name}-planner'),
      initialDate: mode == ScheduleViewMode.day ? selectedDate : range.start,
      daysShowed: mode == ScheduleViewMode.day ? 1 : 7,
      items: items,
      onOpen: onOpen,
      onSelectDate: onSelectDate,
      onVisibleDateChanged: onVisibleDateChanged,
      onEmptySlot: onEmptySlot,
      onRangeCreated: onRangeCreated,
      onReschedule: onReschedule,
      onTaskCompletionChanged: onTaskCompletionChanged,
      dayStartMinute: dayStartMinute,
      dayEndMinute: dayEndMinute,
    ),
    ScheduleViewMode.month => WindowsScheduleMonthView(
      onReschedule: onReschedule,
      selectedDate: selectedDate,
      range: range,
      items: items,
      locale: locale,
      onOpen: onOpen,
      onSelectDate: onSelectDate,
    ),
    ScheduleViewMode.year => WindowsScheduleYearView(
      selectedDate: selectedDate,
      items: items,
      locale: locale,
      onSelectDate: onSelectDate,
    ),
    ScheduleViewMode.agenda => _AgendaList(
      items: items,
      locale: locale,
      onOpen: onOpen,
      onLoadMore: onLoadMoreAgenda,
    ),
  };
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    super.key,
    this.searchCriteria,
    this.searchQuery = '',
    required this.items,
    required this.locale,
    required this.onOpen,
    this.onLoadMore,
  });

  final ScheduleSearchCriteria? searchCriteria;
  final String searchQuery;
  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<ScheduleItem> onOpen;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final agendaItems = searchCriteria == null
        ? items
        : (List<ScheduleItem>.of(items)
            ..sort(compareScheduleSearchResultPresentation));
    final rows = <Widget>[];
    if (agendaItems.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text(AppLocalizations.of(context).noEventsOrTasks),
          ),
        ),
      );
    }
    DateTime? previousDay;
    var noDateShown = false;
    for (final item in agendaItems) {
      final displayDate = searchCriteria == null
          ? item.start
          : scheduleSearchResultDisplayDate(item);
      final day = displayDate == null ? null : _dateOnly(displayDate);
      if (day != previousDay) {
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 14, 4, 6),
            child: Text(
              day == null
                  ? AppLocalizations.of(context).noDate
                  : DateFormat.yMMMMEEEEd(locale).format(day),
              style: FluentTheme.of(context).typography.subtitle,
            ),
          ),
        );
        previousDay = day;
        noDateShown = day == null;
      } else if (day == null && !noDateShown) {
        rows.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 14, 4, 6),
            child: Text(
              AppLocalizations.of(context).noDate,
              style: FluentTheme.of(context).typography.subtitle,
            ),
          ),
        );
        noDateShown = true;
      }
      rows.add(
        _ScheduleItemCard(
          item: item,
          searchCriteria: searchCriteria,
          searchQuery: searchQuery,
          locale: locale,
          onPressed: () => onOpen(item),
        ),
      );
    }
    if (onLoadMore != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Button(
            onPressed: onLoadMore,
            child: Text(AppLocalizations.of(context).windowsAgendaLoadMore),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
      children: rows,
    );
  }
}

class WindowsScheduleMonthView extends StatelessWidget {
  const WindowsScheduleMonthView({
    super.key,
    required this.selectedDate,
    required this.onReschedule,
    required this.range,
    required this.items,
    required this.locale,
    required this.onOpen,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final ScheduleRescheduleCallback onReschedule;
  final ScheduleRange range;
  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime>[];
    var cursor = range.start;
    while (cursor.isBefore(range.end)) {
      days.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return ScheduleInteractionRegion(
      onReschedule: onReschedule,
      previewColor: FluentTheme.of(
        context,
      ).accentColor.defaultBrushFor(FluentTheme.of(context).brightness),
      previewBuilder: (context, interval, allDay) => Text(
        schedulePreviewLabel(context, interval, allDay),
        style: FluentTheme.of(context).typography.caption,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
            child: Row(
              children: [
                for (var index = 0; index < 7; index += 1)
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat.E(
                          locale,
                        ).format(DateTime(2026, 1, 5 + index)),
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final rowHeight = 30.0 * scale;
                final headingHeight = 32.0 * scale;
                final cellHeight = math.max(
                  headingHeight + rowHeight + 10,
                  (constraints.maxHeight - 16) / (days.length / 7),
                );
                return GridView.builder(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: cellHeight,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final dayItems = items
                        .where((item) => _itemOccursOn(item, day))
                        .toList();
                    final capacity = math.max(
                      0,
                      ((cellHeight - headingHeight - 10) / rowHeight).floor(),
                    );
                    final visibleCount = dayItems.length > capacity
                        ? math.max(0, capacity - 1)
                        : capacity;
                    return ScheduleDateTarget(
                      date: day,
                      child: Card(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: headingHeight,
                              child: HyperlinkButton(
                                onPressed: () => onSelectDate(day),
                                child: Text(
                                  '${day.day}',
                                  style: day.month == selectedDate.month
                                      ? null
                                      : TextStyle(
                                          color: FluentTheme.of(
                                            context,
                                          ).inactiveColor,
                                        ),
                                ),
                              ),
                            ),
                            for (final item in dayItems.take(visibleCount))
                              SizedBox(
                                height: rowHeight,
                                child: ScheduleEventInteraction(
                                  key: ValueKey(
                                    'windows-month-${item.accountId}-${item.sourceId}-${item.id}-$day',
                                  ),
                                  item: item,
                                  representedDate: day,
                                  dateOnly: true,
                                  child: _CompactScheduleItem(
                                    item: item,
                                    locale: locale,
                                    onPressed: () => onOpen(item),
                                  ),
                                ),
                              ),
                            if (dayItems.length > visibleCount)
                              SizedBox(
                                height: rowHeight,
                                child: Tooltip(
                                  message:
                                      '${DateFormat.yMMMMEEEEd(locale).format(day)} · ${AppLocalizations.of(context).scheduleItemCount(dayItems.length)}',
                                  child: Button(
                                    key: ValueKey(
                                      'month-overflow-${day.year}-${day.month}-${day.day}',
                                    ),
                                    onPressed: () =>
                                        _showDayItems(context, day, dayItems),
                                    child: Text(
                                      '+${dayItems.length - visibleCount}',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDayItems(
    BuildContext context,
    DateTime day,
    List<ScheduleItem> dayItems,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: Text(DateFormat.yMMMMEEEEd(locale).format(day)),
      content: SizedBox(
        height: math.min(420, MediaQuery.sizeOf(context).height * .55),
        child: ListView(
          children: [
            for (final item in dayItems)
              _CompactScheduleItem(
                item: item,
                locale: locale,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onOpen(item);
                },
              ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () {
            Navigator.pop(dialogContext);
            onSelectDate(day);
          },
          child: Text(AppLocalizations.of(context).viewDay),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    ),
  );
}

class WindowsScheduleYearView extends StatelessWidget {
  const WindowsScheduleYearView({
    super.key,
    required this.selectedDate,
    required this.items,
    required this.locale,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: math.max(
            1,
            ((constraints.maxWidth - 40) / (260 * scale)).floor(),
          ),
          mainAxisExtent: 300 * scale,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final month = DateTime(selectedDate.year, index + 1);
          final offset = month.weekday - 1;
          final dayCount = DateTime(month.year, month.month + 1, 0).day;
          return Card(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  DateFormat.MMMM(locale).format(month),
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      Expanded(
                        child: Center(
                          child: Text(
                            DateFormat.E(
                              locale,
                            ).format(DateTime(2026, 1, 5 + weekday)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FluentTheme.of(context).typography.caption,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, grid) => GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisExtent: grid.maxHeight / 6,
                      ),
                      itemCount: 42,
                      itemBuilder: (context, cell) {
                        final number = cell - offset + 1;
                        if (number < 1 || number > dayCount) {
                          return const SizedBox.shrink();
                        }
                        final day = DateTime(month.year, month.month, number);
                        final dayItems = items
                            .where((item) => _itemOccursOn(item, day))
                            .toList();
                        final selected = _dateOnly(selectedDate) == day;
                        final today = _dateOnly(DateTime.now()) == day;
                        return Tooltip(
                          message:
                              '${DateFormat.yMMMMEEEEd(locale).format(day)} · ${AppLocalizations.of(context).scheduleItemCount(dayItems.length)}',
                          child: Button(
                            key: ValueKey(
                              'year-day-${day.year}-${day.month}-${day.day}',
                            ),
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(EdgeInsets.zero),
                            ),
                            onPressed: () => onSelectDate(day),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: selected || today
                                    ? Border.all(
                                        color: FluentTheme.of(context)
                                            .accentColor
                                            .defaultBrushFor(
                                              FluentTheme.of(
                                                context,
                                              ).brightness,
                                            ),
                                        width: selected ? 2 : 1,
                                      )
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$number'),
                                  SizedBox(
                                    height: 5,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (final item in dayItems.take(3))
                                          Container(
                                            width: 4,
                                            height: 4,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _compactItemColor(
                                                context,
                                                item,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _compactItemColor(BuildContext context, ScheduleItem item) =>
    item is TaskScheduleItem
    ? ScheduleProjection.deterministicSourceColor(
        '${item.accountId}/${item.sourceId}',
        FluentTheme.of(context).brightness,
      )
    : ScheduleProjection.colorForItem(item, FluentTheme.of(context).brightness);

class _CompactScheduleItem extends StatelessWidget {
  const _CompactScheduleItem({
    required this.item,
    required this.locale,
    required this.onPressed,
  });

  final ScheduleItem item;
  final String locale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final start = item.start;
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final label = item.allDay || start == null
        ? item.title
        : '${BusyMaxTimeFormatScope.of(context).format(start)} ${item.title}';
    return Tooltip(
      message: [
        label,
        item.accountEmail ?? item.accountDisplayName,
        item.sourceName,
      ].whereType<String>().join(' · '),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Button(
          onPressed: onPressed,
          child: Row(
            children: [
              Icon(
                windowsBusyMaxGlyph(
                  task != null
                      ? task.completed
                            ? BusyMaxGlyph.check
                            : BusyMaxGlyph.task
                      : BusyMaxGlyph.calendar,
                ),
                size: 13,
                color: _compactItemColor(context, item),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
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
    );
  }
}

class _WindowsScheduleEmptyState extends StatelessWidget {
  const _WindowsScheduleEmptyState({
    required this.searching,
    required this.noVisibleSources,
  });

  final bool searching;
  final bool noVisibleSources;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar), size: 40),
          const SizedBox(height: 12),
          Text(
            searching
                ? noVisibleSources
                      ? l10n.searchNoSources
                      : l10n.scheduleNoSearchResults
                : noVisibleSources
                ? l10n.scheduleNoSources
                : l10n.noEventsOrTasks,
            style: FluentTheme.of(context).typography.subtitle,
          ),
          if (searching) ...[
            const SizedBox(height: 4),
            Text(l10n.scheduleNoSearchResultsDescription),
          ],
        ],
      ),
    );
  }
}

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({
    this.searchCriteria,
    this.searchQuery = '',
    required this.item,
    required this.locale,
    required this.onPressed,
  });

  final ScheduleSearchCriteria? searchCriteria;
  final String searchQuery;
  final ScheduleItem item;
  final String locale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(
            windowsBusyMaxGlyph(
              item.kind == ScheduleItemKind.task
                  ? BusyMaxGlyph.task
                  : BusyMaxGlyph.calendar,
            ),
          ),
          title: Text(
            item.title,
            style: task?.completed == true
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Text(
            searchCriteria != null
                ? scheduleSearchResultText(
                    context,
                    item,
                    searchCriteria!,
                    searchQuery,
                  )
                : [
                    _itemDateLabel(context, item, locale),
                    ?item.sourceName,
                  ].where((value) => value.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

BusyMaxGlyph _modeGlyph(ScheduleViewMode mode) => switch (mode) {
  ScheduleViewMode.day => BusyMaxGlyph.today,
  ScheduleViewMode.week => BusyMaxGlyph.calendar,
  ScheduleViewMode.month => BusyMaxGlyph.month,
  ScheduleViewMode.year => BusyMaxGlyph.calendar,
  ScheduleViewMode.agenda => BusyMaxGlyph.agenda,
};

String _modeLabel(AppLocalizations l10n, ScheduleViewMode mode) =>
    switch (mode) {
      ScheduleViewMode.day => l10n.viewDay,
      ScheduleViewMode.week => l10n.viewWeek,
      ScheduleViewMode.month => l10n.viewMonth,
      ScheduleViewMode.year => l10n.viewYear,
      ScheduleViewMode.agenda => l10n.viewAgenda,
    };

String _itemDateLabel(BuildContext context, ScheduleItem item, String locale) {
  final start = item.start;
  if (start == null) return '';
  return item.allDay
      ? DateFormat.yMMMd(locale).format(start)
      : formatClockDateTime(
          context,
          start,
          DateFormat.yMMMd(locale).format(start),
        );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

bool _itemOccursOn(ScheduleItem item, DateTime day) {
  final start = item.start;
  if (start == null) return false;
  if (item is! CalendarScheduleItem) return _sameDay(start, day);
  final dayStart = _dateOnly(day);
  final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
  final end = item.end ?? start;
  if (end.isAtSameMomentAs(start)) return _sameDay(start, day);
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}

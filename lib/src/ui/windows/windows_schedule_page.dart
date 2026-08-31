import 'dart:async';
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
import '../../schedule/schedule_item.dart';
import '../../schedule/schedule_range.dart';
import '../../schedule/schedule_source_visibility.dart';
import '../../schedule/schedule_view_mode.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_calendar_activation_flows.dart';
import 'windows_event_editor_dialog.dart';
import 'windows_guest_update_dialog.dart';
import 'windows_schedule_source_pane.dart';
import 'windows_task_details_dialog.dart';
import 'windows_task_editor_dialog.dart';

class WindowsSchedulePage extends ConsumerStatefulWidget {
  const WindowsSchedulePage({super.key});

  @override
  ConsumerState<WindowsSchedulePage> createState() =>
      _WindowsSchedulePageState();
}

class _WindowsSchedulePageState extends ConsumerState<WindowsSchedulePage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _selectedDate = DateTime.now();
  var _query = '';
  late ScheduleViewMode _mode;
  var _agendaDays = 30;
  var _agendaTaskLimit = 100;
  var _refreshRevision = 0;
  String? _taskListsKey;
  Future<List<TaskListEntity>>? _taskListsFuture;
  String? _itemsKey;
  Future<List<ScheduleItem>>? _itemsFuture;
  var _sourcePaneCollapsed = false;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(appSettingsControllerProvider).scheduleViewMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final range = _rangeForMode();
    return LayoutBuilder(
      builder: (context, constraints) {
        final canShowSourcePane = BusyMaxBreakpoints.showsSourcePane(
          constraints.maxWidth,
        );
        final showSourcePane = canShowSourcePane && !_sourcePaneCollapsed;
        final sourcePane = WindowsScheduleSourcePane(
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
          child: ScaffoldPage(
            header: PageHeader(
              title: Text(_periodTitle(l10n, locale, range)),
              commandBar: CommandBar(
                compactBreakpointWidth: BusyMaxBreakpoints.compact,
                primaryItems: [
                  if (!showSourcePane)
                    CommandBarButton(
                      icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more)),
                      label: Text(l10n.showSidebar),
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
                  CommandBarButton(
                    icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.today)),
                    label: Text(l10n.today),
                    onPressed: () => _selectDate(DateTime.now()),
                  ),
                  if (_mode != ScheduleViewMode.agenda) ...[
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
                                prefix: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 10,
                                  ),
                                  child: Icon(
                                    windowsBusyMaxGlyph(BusyMaxGlyph.search),
                                  ),
                                ),
                                onChanged: (value) {
                                  _query = value;
                                  _reload();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                ConnectionState.done) {
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
                            if (items.isEmpty &&
                                _mode != ScheduleViewMode.agenda) {
                              return _WindowsScheduleEmptyState(
                                searching: _query.isNotEmpty,
                                noVisibleSources:
                                    visibility
                                        .visibleCalendarSourceIds
                                        .isEmpty &&
                                    visibility.visibleTaskListKeys.isEmpty,
                              );
                            }
                            return _ScheduleModeView(
                              mode: _mode,
                              selectedDate: _selectedDate,
                              range: range,
                              items: items,
                              locale: locale,
                              onOpen: _showItemDetails,
                              onSelectDate: _mode == ScheduleViewMode.year
                                  ? _openMonth
                                  : _openDay,
                              onLoadMoreAgenda: _loadMoreAgenda,
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
        );
      },
    );
  }

  Future<void> _createEvent() async {
    final changed = await showWindowsEventEditorDialog(
      context,
      ref,
      initialStart: _selectedDate,
    );
    if (changed && mounted) _reload();
  }

  Future<void> _createTask() async {
    final changed = await showWindowsTaskEditorDialog(context, ref);
    if (changed && mounted) _reload();
  }

  void _focusSearch() => _searchFocusNode.requestFocus();

  void _dismissSearch() {
    if (!_searchFocusNode.hasFocus && _query.isEmpty) return;
    _searchController.clear();
    _query = '';
    _searchFocusNode.unfocus();
    _reload();
  }

  void _invokeUnmodifiedShortcut(VoidCallback callback) {
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
    final key = [
      _refreshRevision,
      _mode.name,
      range.start.toIso8601String(),
      range.end.toIso8601String(),
      _query,
      accountIds.join(','),
      calendarIds.join(','),
      taskKeys.join(','),
    ].join('|');
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
      showCompletedTasks: true,
      showNoDateTasks: _mode == ScheduleViewMode.agenda,
    );
    _itemsFuture = _loadItems(range, filters);
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
    if (_mode == ScheduleViewMode.agenda && _query.trim().isEmpty) {
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
      start: _dateOnly(DateTime.now()),
      end: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + _agendaDays,
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

  void _openMonth(DateTime date) {
    _selectDate(DateTime(date.year, date.month));
    _setMode(ScheduleViewMode.month);
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

  Future<void> _showItemDetails(ScheduleItem item) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = _itemDateLabel(item, locale);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(item.title),
        content: Text(
          [
            time,
            ?item.sourceName,
            ?item.accountDisplayName,
            if (item case CalendarScheduleItem(:final location?)) location,
            if (item case CalendarScheduleItem(:final description?))
              description,
            if (item case TaskScheduleItem(:final notes?)) notes,
          ].where((value) => value.trim().isNotEmpty).join('\n'),
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
              child: Text(l10n.delete),
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

  Future<void> _export(ScheduleItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await exportScheduleItemWithSaveDialog(item);
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
            if (supportsThisAndFollowingEventMutation(item.provider))
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
    } else if (scope == null) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: Text(
            item is TaskScheduleItem ? l10n.deleteTask : l10n.deleteEvent,
          ),
          content: Text(item.title),
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
          await ref
              .read(calendarRepositoryProvider)
              .deleteLocalEvent(
                item.id,
                recurringScope: scope,
                guestUpdatePolicy: guestUpdatePolicy,
              );
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
  });

  final ScheduleViewMode mode;
  final DateTime selectedDate;
  final ScheduleRange range;
  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onLoadMoreAgenda;

  @override
  Widget build(BuildContext context) => switch (mode) {
    ScheduleViewMode.day => _AgendaList(
      items: items,
      locale: locale,
      onOpen: onOpen,
      groupByDate: false,
    ),
    ScheduleViewMode.week => _WeekView(
      range: range,
      items: items,
      locale: locale,
      onOpen: onOpen,
      onSelectDate: onSelectDate,
    ),
    ScheduleViewMode.month => _MonthView(
      selectedDate: selectedDate,
      range: range,
      items: items,
      locale: locale,
      onOpen: onOpen,
      onSelectDate: onSelectDate,
    ),
    ScheduleViewMode.year => _YearView(
      selectedDate: selectedDate,
      items: items,
      locale: locale,
      onSelectDate: onSelectDate,
    ),
    ScheduleViewMode.agenda => _AgendaList(
      items: items,
      locale: locale,
      onOpen: onOpen,
      groupByDate: true,
      onLoadMore: onLoadMoreAgenda,
    ),
  };
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    required this.items,
    required this.locale,
    required this.onOpen,
    required this.groupByDate,
    this.onLoadMore,
  });

  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<ScheduleItem> onOpen;
  final bool groupByDate;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (items.isEmpty) {
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
    for (final item in items) {
      final day = item.start == null ? null : _dateOnly(item.start!);
      if (groupByDate && day != previousDay) {
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
      } else if (groupByDate && day == null && !noDateShown) {
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

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.range,
    required this.items,
    required this.locale,
    required this.onOpen,
    required this.onSelectDate,
  });

  final ScheduleRange range;
  final List<ScheduleItem> items;
  final String locale;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var offset = 0; offset < 7; offset += 1)
        DateTime(range.start.year, range.start.month, range.start.day + offset),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, 840),
          height: constraints.maxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(3, 0, 3, 12),
                    child: Card(
                      child: Column(
                        children: [
                          HyperlinkButton(
                            onPressed: () => onSelectDate(day),
                            child: Text(DateFormat.MMMEd(locale).format(day)),
                          ),
                          const Divider(),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(6),
                              children: [
                                for (final item in items.where(
                                  (item) => _itemOccursOn(item, day),
                                ))
                                  _CompactScheduleItem(
                                    item: item,
                                    locale: locale,
                                    onPressed: () => onOpen(item),
                                  ),
                              ],
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
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.selectedDate,
    required this.range,
    required this.items,
    required this.locale,
    required this.onOpen,
    required this.onSelectDate,
  });

  final DateTime selectedDate;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
          child: Row(
            children: [
              for (var index = 0; index < 7; index += 1)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(locale).format(DateTime(2026, 1, 5 + index)),
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: days.length > 35 ? 1.0 : 0.82,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final dayItems = items
                  .where((item) => _itemOccursOn(item, day))
                  .toList();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HyperlinkButton(
                        onPressed: () => onSelectDate(day),
                        child: Text(
                          '${day.day}',
                          style: day.month == selectedDate.month
                              ? null
                              : TextStyle(
                                  color: FluentTheme.of(context).inactiveColor,
                                ),
                        ),
                      ),
                      for (final item in dayItems.take(2))
                        _CompactScheduleItem(
                          item: item,
                          locale: locale,
                          onPressed: () => onOpen(item),
                        ),
                      if (dayItems.length > 2)
                        Text(
                          '+${dayItems.length - 2}',
                          textAlign: TextAlign.center,
                          style: FluentTheme.of(context).typography.caption,
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

class _YearView extends StatelessWidget {
  const _YearView({
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
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 900 ? 4 : 3,
          childAspectRatio: 1.45,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final month = DateTime(selectedDate.year, index + 1);
          final count = items.where((item) {
            final start = item.start;
            return start != null &&
                start.year == month.year &&
                start.month == month.month;
          }).length;
          return Button(
            onPressed: () => onSelectDate(month),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.MMMM(locale).format(month),
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context).scheduleItemCount(count)),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
        : '${DateFormat.jm(locale).format(start)} ${item.title}';
    return Padding(
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
                ? l10n.scheduleNoSearchResults
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
    required this.item,
    required this.locale,
    required this.onPressed,
  });

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
            [
              _itemDateLabel(item, locale),
              ?item.sourceName,
            ].where((value) => value.isNotEmpty).join(' · '),
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

String _itemDateLabel(ScheduleItem item, String locale) {
  final start = item.start;
  if (start == null) return '';
  return item.allDay
      ? DateFormat.yMMMd(locale).format(start)
      : DateFormat.yMMMd(locale).add_jm().format(start);
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

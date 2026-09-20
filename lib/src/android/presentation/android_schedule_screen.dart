import 'dart:async';
import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../app/common/busymax_motion_widgets.dart';
import '../../app/common/busymax_mutation_list.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../core/logging/redacting_logger.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../features/maps/application/external_location_launcher.dart';
import '../../features/schedule/application/saved_schedule_location.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';
import '../../l10n/time_format_scope.dart';
import '../../l10n/week_preferences_scope.dart';
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
import 'android_date_picker.dart';
import 'android_settings_screen.dart';
import 'android_tasks_screen.dart';
import 'android_task_motion.dart';

final _androidScheduleItemsProvider = FutureProvider.autoDispose
    .family<
      List<ScheduleItem>,
      ({
        DateTime anchor,
        ScheduleViewMode mode,
        String query,
        int firstWeekday,
        ScheduleSearchCriteria? search,
      })
    >((ref, key) async {
      ref.watch(scheduleDataRevisionProvider);
      final sources = await ref.watch(calendarSourcesStreamProvider.future);
      final lists = await ref.watch(scheduleTaskListsProvider.future);
      final settings = ref.watch(appSettingsControllerProvider);
      return ref
          .watch(scheduleRepositoryProvider)
          .listItems(
            range:
                key.search?.range ??
                _rangeFor(key.anchor, key.mode, firstWeekday: key.firstWeekday),
            filters:
                key.search?.filters(key.query) ??
                ScheduleFilters(
                  query: key.query,
                  sourceIds: {
                    for (final source in sources)
                      if (source.selected) source.id,
                  },
                  taskListKeys: {
                    for (final list in lists)
                      if (settings.isTaskListVisibleInSchedule(
                        list.accountId,
                        list.id,
                      ))
                        ScheduleTaskListKey(
                          accountId: list.accountId,
                          taskListId: list.id,
                        ),
                  },
                  sourceFilterActive: true,
                  taskListFilterActive: true,
                  taskCompletion: ScheduleTaskCompletion.all,
                  showNoDateTasks: key.mode == ScheduleViewMode.agenda,
                ),
          );
    });

class AndroidScheduleScreen extends ConsumerStatefulWidget {
  const AndroidScheduleScreen({super.key});

  @override
  ConsumerState<AndroidScheduleScreen> createState() =>
      _AndroidScheduleScreenState();
}

class _AndroidScheduleScreenState extends ConsumerState<AndroidScheduleScreen> {
  DateTime _anchor = DateTime.now();
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  ScheduleSearchCriteria? _searchCriteria;
  ScheduleSearchCriteria? _initialSearchCriteria;
  var _searchFirstWeekday = DateTime.monday;
  var _searchRequestGeneration = 0;
  var _navigationGeneration = 0;
  var _navigationDirection = 0;
  var _taskMutationGeneration = 0;
  TaskListMutationIntent? _taskMutationIntent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final mode = settings.androidScheduleViewMode ?? ScheduleViewMode.agenda;
    final items = ref.watch(
      _androidScheduleItemsProvider((
        anchor: DateTime(_anchor.year, _anchor.month, _anchor.day),
        mode: mode,
        query: _query,
        search: _searching ? _searchCriteria : null,
        firstWeekday: _firstWeekday(context),
      )),
    );
    return Scaffold(
      appBar: AppBar(
        title: BusyMaxBinaryPresentation(
          alternateActive: _searching,
          child: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.l10n.windowsSearch,
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _selectDate,
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
            PopupMenuButton<ScheduleViewMode>(
              tooltip: context.l10n.scheduleDisplaySettings,
              initialValue: mode,
              onSelected: ref
                  .read(appSettingsControllerProvider.notifier)
                  .setAndroidScheduleViewMode,
              itemBuilder: (context) => [
                for (final candidate in ScheduleViewMode.values)
                  PopupMenuItem(
                    value: candidate,
                    child: Text(_modeLabel(context, candidate)),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          BusyMaxVerticalReveal(
            visible: !_searching,
            child: _navigationRow(context, mode),
          ),
          Expanded(
            child: BusyMaxBinaryPresentation(
              alternateActive: _searching,
              child: BusyMaxDirectionalEntrance(
                generation: _navigationGeneration,
                direction: _navigationDirection,
                child: items.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _Message(
                    icon: Icons.error_outline,
                    title: context.l10n.scheduleUnavailable,
                    detail: '$error',
                  ),
                  data: (value) =>
                      value.isEmpty &&
                          (_searching || mode == ScheduleViewMode.agenda)
                      ? _Message(
                          icon: !_searching
                              ? Icons.event_busy
                              : Icons.search_off,
                          title: !_searching
                              ? context.l10n.noEventsOrTasks
                              : _searchCriteria?.hasSources == false
                              ? context.l10n.searchNoSources
                              : context.l10n.scheduleNoSearchResults,
                          detail: !_searching
                              ? context.l10n.noEventsOrTasks
                              : context.l10n.scheduleNoSearchResultsDescription,
                        )
                      : _searching
                      ? _AgendaList(
                          key: const ValueKey('android-search-results'),
                          items: value,
                          onOpen: (item) => _showItem(context, item),
                          onToggleTask: _toggleTask,
                          searchCriteria: _searchCriteria,
                          searchQuery: _query,
                          taskMutationIntent: _taskMutationIntent,
                          onTaskMutationConsumed: _consumeTaskMutation,
                        )
                      : _ScheduleBody(
                          anchor: _anchor,
                          mode: mode,
                          items: value,
                          onSelectDate: (date) =>
                              setState(() => _anchor = date),
                          onModeChanged: (value) => unawaited(
                            ref
                                .read(appSettingsControllerProvider.notifier)
                                .setAndroidScheduleViewMode(value),
                          ),
                          onOpen: (item) => _showItem(context, item),
                          onToggleTask: _toggleTask,
                          taskMutationIntent: _taskMutationIntent,
                          onTaskMutationConsumed: _consumeTaskMutation,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'android-schedule-add',
        onPressed: () => _createItem(context),
        tooltip: context.l10n.create,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openSearch() async {
    final generation = ++_searchRequestGeneration;
    final sources = await ref.read(calendarSourcesStreamProvider.future);
    final lists = await ref.read(scheduleTaskListsProvider.future);
    if (!mounted || generation != _searchRequestGeneration) return;
    final visibility = ScheduleSourceVisibility.fromSources(
      calendarSources: sources,
      taskLists: lists,
      settings: ref.read(appSettingsControllerProvider),
    );
    final now = DateTime.now();
    setState(() {
      _initialSearchCriteria = ScheduleSearchCriteria(
        referenceDate: DateTime(now.year, now.month, now.day),
        firstWeekday: _firstWeekday(context),
        sourceIds: visibility.visibleCalendarSourceIds,
        taskListKeys: visibility.visibleTaskListKeys,
      );
      _searchCriteria = _initialSearchCriteria;
      _searching = true;
    });
  }

  void _closeSearch() {
    _searchRequestGeneration += 1;
    setState(() {
      _searching = false;
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
                    setState(
                      () => _searchCriteria = value.copyWith(
                        firstWeekday: _firstWeekday(context),
                      ),
                    );
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

  Future<void> _showSources(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final sources = ref.watch(calendarSourcesStreamProvider);
          final lists = ref.watch(scheduleTaskListsProvider);
          final accounts =
              ref.watch(accountsStreamProvider).valueOrNull ??
              const <AccountEntity>[];
          final accountLabels = {
            for (final account in accounts) account.id: account.displayLabel,
          };
          final settings = ref.watch(appSettingsControllerProvider);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  ListTile(
                    title: Text(context.l10n.collectionSettings),
                    titleTextStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...(sources.valueOrNull ?? const <CalendarSourceEntity>[]).map(
                    (source) => CheckboxListTile(
                      secondary: const Icon(Icons.calendar_month),
                      title: Text(source.summary),
                      subtitle: Text(
                        '${source.provider.displayName} · '
                        '${source.authenticatedAccountEmail ?? source.accountId}',
                      ),
                      value: source.selected,
                      onChanged: (selected) => ref
                          .read(calendarRepositoryProvider)
                          .setSourceSelected(source.id, selected == true),
                    ),
                  ),
                  ...(lists.valueOrNull ?? const []).map(
                    (list) => CheckboxListTile(
                      secondary: const Icon(Icons.checklist),
                      title: Text(list.title),
                      subtitle: Text(
                        accountLabels[list.accountId] ?? list.accountId,
                      ),
                      value: settings.isTaskListVisibleInSchedule(
                        list.accountId,
                        list.id,
                      ),
                      onChanged: (visible) => ref
                          .read(appSettingsControllerProvider.notifier)
                          .setTaskListVisibleInSchedule(
                            accountId: list.accountId,
                            taskListId: list.id,
                            visible: visible == true,
                          ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(context.l10n.collectionSettings),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(this.context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const AndroidSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showBusyMaxDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected != null && mounted) setState(() => _anchor = selected);
  }

  Future<void> _createItem(BuildContext context) async {
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
      await _createEvent(context);
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
    final list = await selectAndroidTaskList(
      context,
      lists,
      title: context.l10n.newTask,
      accountLabels: {
        for (final account in accounts) account.id: account.displayLabel,
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
      initialDue: DateTime(_anchor.year, _anchor.month, _anchor.day),
    );
    if (result != null && mounted) _consumeEditorResult(result);
  }

  Future<void> _showItem(BuildContext context, ScheduleItem item) async {
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
                Text(item.sourceName ?? item.provider.displayName),
                if (item.start != null)
                  Text(
                    formatClockDateTime(
                      context,
                      item.start!,
                      DateFormat.yMMMd().format(item.start!),
                    ),
                  ),
                if (item case CalendarScheduleItem(
                  :final location?,
                ) when location.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place),
                    title: Text(location),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => unawaited(
                      const ExternalLocationLauncher(
                        platform: _androidLocationPlatform,
                      ).open(projectedScheduleItemLocationDestination(item)),
                    ),
                  ),
                if (item case TaskScheduleItem(
                  :final notes?,
                ) when notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(notes),
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
                if (item.capabilities.canEdit)
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      if (item is CalendarScheduleItem) {
                        await _editEvent(context, item);
                      } else if (item is TaskScheduleItem) {
                        final result = await showAndroidTaskEditor(
                          context,
                          ref,
                          task: item,
                        );
                        if (result != null && mounted) {
                          _consumeEditorResult(result);
                        }
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: Text(
                      item is CalendarScheduleItem
                          ? context.l10n.editEvent
                          : context.l10n.editTask,
                    ),
                  ),
                if (item.provider == BusyProvider.nextcloud) ...[
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
  }

  Future<void> _exportItem(BuildContext context, ScheduleItem item) async {
    try {
      final raw = item is CalendarScheduleItem
          ? await ref
                .read(calendarRepositoryProvider)
                .nativeEventExport(item.id)
          : item is TaskScheduleItem
          ? await ref
                .read(tasksRepositoryForAccountProvider(item.accountId))
                .nativeTaskExport(item.sourceId, item.id)
          : null;
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

  Future<void> _createEvent(BuildContext context) async {
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
    final source = sources.length == 1
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
          );
    if (source == null || !context.mounted) return;
    final start = DateTime(_anchor.year, _anchor.month, _anchor.day, 9);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AndroidEventEditor(
          sources: sources,
          draft: EventEditorDraft.newEvent(
            accountId: source.accountId,
            sourceId: source.id,
            providerCalendarId: source.providerCalendarId,
            start: start,
            end: start.add(const Duration(hours: 1)),
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
            context.l10n.invitationResponseFailed(redactForLog(error)),
          ),
        ),
      );
    }
  }

  Future<void> _toggleTask(TaskScheduleItem task) async {
    if (!task.capabilities.canEdit) return;
    final intent = TaskListMutationIntent(
      presentation: TaskListMutationPresentation.completion,
      accountId: task.accountId,
      taskListId: task.sourceId,
      taskId: task.id,
      completed: !task.completed,
      generation: ++_taskMutationGeneration,
    );
    setState(() => _taskMutationIntent = intent);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(task.accountId))
          .patchTask(
            task.sourceId,
            task.id,
            TaskPatchInput({
              'status': task.completed ? 'needsAction' : 'completed',
            }),
          );
    } on Object catch (error) {
      if (mounted) {
        if (_taskMutationIntent?.generation == intent.generation) {
          setState(() => _taskMutationIntent = null);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _consumeTaskMutation(TaskListMutationIntent intent) {
    if (_taskMutationIntent?.generation == intent.generation) {
      setState(() => _taskMutationIntent = null);
    }
  }

  void _consumeEditorResult(AndroidTaskEditorResult result) {
    setState(() {
      _taskMutationIntent = TaskListMutationIntent(
        presentation: switch (result.action) {
          AndroidTaskEditorAction.created =>
            TaskListMutationPresentation.insertion,
          AndroidTaskEditorAction.deleted ||
          AndroidTaskEditorAction.moved => TaskListMutationPresentation.removal,
          AndroidTaskEditorAction.updated =>
            TaskListMutationPresentation.completion,
        },
        accountId: result.accountId,
        taskListId: result.previousTaskListId ?? result.taskListId,
        taskId: result.taskId,
        generation: ++_taskMutationGeneration,
      );
    });
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

class _ScheduleBody extends StatelessWidget {
  const _ScheduleBody({
    required this.anchor,
    required this.mode,
    required this.items,
    required this.onSelectDate,
    required this.onModeChanged,
    required this.onOpen,
    required this.onToggleTask,
    this.taskMutationIntent,
    this.onTaskMutationConsumed,
  });
  final DateTime anchor;
  final ScheduleViewMode mode;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final TaskListMutationIntent? taskMutationIntent;
  final ValueChanged<TaskListMutationIntent>? onTaskMutationConsumed;

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
      ),
      ScheduleViewMode.year => _YearView(
        anchor: anchor,
        items: items,
        onSelectDate: onSelectDate,
        onModeChanged: onModeChanged,
      ),
      ScheduleViewMode.week || ScheduleViewMode.day => _AndroidTimeGrid(
        key: ValueKey('android-${mode.name}-time-grid'),
        anchor: anchor,
        days: mode == ScheduleViewMode.day ? 1 : 7,
        firstWeekday: _firstWeekday(context),
        items: items,
        onOpen: onOpen,
      ),
      ScheduleViewMode.agenda => _AgendaList(
        items: items,
        onOpen: onOpen,
        onToggleTask: onToggleTask,
        taskMutationIntent: taskMutationIntent,
        onTaskMutationConsumed: onTaskMutationConsumed,
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
    this.onTaskMutationConsumed,
  });
  final ScheduleSearchCriteria? searchCriteria;
  final String searchQuery;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  final TaskListMutationIntent? taskMutationIntent;
  final ValueChanged<TaskListMutationIntent>? onTaskMutationConsumed;
  @override
  Widget build(BuildContext context) {
    final agendaItems = searchCriteria == null
        ? items
        : (List<ScheduleItem>.of(items)
            ..sort(compareScheduleSearchResultPresentation));
    return BusyMaxMutationList<ScheduleItem>(
      items: agendaItems,
      mutation: taskMutationIntent,
      identityOf: (item) => item is TaskScheduleItem
          ? '${item.accountId}\u0000${item.sourceId}\u0000${item.id}'
          : 'event\u0000${item.accountId}\u0000${item.sourceId}\u0000${item.id}',
      mutationApplied: (item, mutation) =>
          item is! TaskScheduleItem ||
          mutation.completed == null ||
          item.completed == mutation.completed,
      onMutationConsumed: onTaskMutationConsumed,
      emptyBuilder: (context) =>
          Center(child: Text(context.l10n.noEventsOrTasks)),
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
        final previousDisplayDate = index == 0
            ? null
            : searchCriteria == null
            ? agendaItems[index - 1].start
            : scheduleSearchResultDisplayDate(agendaItems[index - 1]);
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (index == 0 ||
                  (displayDate == null && previousDisplayDate != null) ||
                  (displayDate != null &&
                      (previousDisplayDate == null ||
                          !_sameDay(displayDate, previousDisplayDate))))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    displayDate == null
                        ? context.l10n.noDate
                        : '${isToday ? '${context.l10n.today} · ' : ''}'
                              '${DateFormat.yMMMMEEEEd().format(displayDate)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isToday
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
              ListTile(
                minVerticalPadding: 12,
                leading: item is TaskScheduleItem
                    ? IconButton(
                        tooltip: displayedCompleted
                            ? context.l10n.taskStatusCompleted
                            : context.l10n.taskStatusInProcess,
                        onPressed: item.capabilities.canEdit
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
                      : '$time · ${item.sourceName ?? item.provider.displayName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onOpen(item),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _animatesTaskCompletion(TaskScheduleItem task) {
    final intent = taskMutationIntent;
    return intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent?.completed != null;
  }

  bool _displayedCompletion(TaskScheduleItem task) {
    final intent = taskMutationIntent;
    if (intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent?.completed != null) {
      return intent!.completed!;
    }
    return task.completed;
  }
}

class _AndroidTimeGrid extends StatelessWidget {
  const _AndroidTimeGrid({
    super.key,
    required this.anchor,
    required this.days,
    required this.firstWeekday,
    required this.items,
    required this.onOpen,
  });

  static const _axisWidth = 54.0;
  static const _minuteHeight = .72;

  final DateTime anchor;
  final int days;
  final int firstWeekday;
  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final start = days == 1
        ? DateTime(anchor.year, anchor.month, anchor.day)
        : ScheduleRange.week(anchor, firstWeekday: firstWeekday).start;
    final dates = [
      for (var index = 0; index < days; index++)
        DateTime(start.year, start.month, start.day + index),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleColumns = constraints.maxWidth >= 700
            ? days
            : (days < 3 ? days : 3);
        final availableWidth = constraints.maxWidth - _axisWidth;
        final columnWidth = days == 1
            ? availableWidth.clamp(112.0, double.infinity).toDouble()
            : (availableWidth / visibleColumns.clamp(1, 7))
                  .clamp(112.0, 220.0)
                  .toDouble();
        final contentWidth = _axisWidth + columnWidth * days;
        final compactHeight = constraints.maxHeight < 240;
        final dateHeaderHeight = compactHeight ? 36.0 : 48.0;
        final preferredAllDayHeight =
            (MediaQuery.textScalerOf(context).scale(28) + 70)
                .clamp(68.0, 148.0)
                .toDouble();
        final maximumAllDayHeight =
            (constraints.maxHeight - dateHeaderHeight - 32)
                .clamp(0.0, double.infinity)
                .toDouble();
        final allDayHeight = preferredAllDayHeight
            .clamp(0.0, maximumAllDayHeight)
            .toDouble();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: Column(
              children: [
                SizedBox(
                  height: dateHeaderHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: _axisWidth),
                      for (final day in dates)
                        SizedBox(
                          width: columnWidth,
                          child: Center(
                            child: Text(
                              DateFormat.E().add_d().format(day),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: allDayHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _axisWidth,
                        child: Center(
                          child: Text(
                            context.l10n.allDay,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                      for (final day in dates)
                        SizedBox(
                          width: columnWidth,
                          child: _AndroidAllDayCell(
                            items: ScheduleProjection.itemsForDay(
                              items,
                              day,
                            ).where((item) => item.allDay).toList(),
                            onOpen: onOpen,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: 24 * 60 * _minuteHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: _axisWidth,
                            child: Stack(
                              children: [
                                for (var hour = 0; hour < 24; hour++)
                                  PositionedDirectional(
                                    top: hour * 60 * _minuteHeight - 8,
                                    end: 6,
                                    child: Text(
                                      BusyMaxTimeFormatScope.of(
                                        context,
                                      ).format(DateTime(2026, 1, 1, hour)),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (final day in dates)
                            SizedBox(
                              width: columnWidth,
                              child: _AndroidTimedDayColumn(
                                day: day,
                                items: ScheduleProjection.itemsForDay(
                                  items,
                                  day,
                                ).where((item) => !item.allDay).toList(),
                                minuteHeight: _minuteHeight,
                                onOpen: onOpen,
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
    );
  }
}

class _AndroidAllDayCell extends StatelessWidget {
  const _AndroidAllDayCell({required this.items, required this.onOpen});

  final List<ScheduleItem> items;
  final ValueChanged<ScheduleItem> onOpen;

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
                _AndroidCalendarChip(item: items.first, onOpen: onOpen),
                if (items.length > 1)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        textStyle: Theme.of(context).textTheme.labelSmall,
                      ),
                      onPressed: () => _showAllDayItems(context),
                      child: Text(context.l10n.moreItems(items.length - 1)),
                    ),
                  ),
              ],
            ),
          ),
  );

  Future<void> _showAllDayItems(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: .62,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Icon(
                    item is TaskScheduleItem
                        ? Icons.check_circle_outline
                        : Icons.event_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.sourceName ?? item.provider.displayName),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onOpen(item);
                  },
                );
              },
            ),
          ),
        ),
      );
}

class _AndroidTimedDayColumn extends StatelessWidget {
  const _AndroidTimedDayColumn({
    required this.day,
    required this.items,
    required this.minuteHeight,
    required this.onOpen,
  });

  final DateTime day;
  final List<ScheduleItem> items;
  final double minuteHeight;
  final ValueChanged<ScheduleItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final placements = _timedPlacements(items, day);
    final laneCount = placements.fold<int>(
      1,
      (maximum, placement) =>
          placement.lane + 1 > maximum ? placement.lane + 1 : maximum,
    );
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: Theme.of(context).dividerColor, width: .5),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var hour = 0; hour < 24; hour++)
              Positioned(
                top: hour * 60 * minuteHeight,
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: .55),
                ),
              ),
            for (final placement in placements)
              Positioned(
                top: placement.startMinute * minuteHeight + 1,
                left: placement.lane * constraints.maxWidth / laneCount + 2,
                width: constraints.maxWidth / laneCount - 4,
                height:
                    ((placement.endMinute - placement.startMinute) *
                            minuteHeight)
                        .clamp(28.0, 24 * 60 * minuteHeight)
                        .toDouble(),
                child: _AndroidCalendarChip(
                  item: placement.item,
                  onOpen: onOpen,
                  showTime: true,
                ),
              ),
            if (_sameDay(now, day))
              Positioned(
                top: (now.hour * 60 + now.minute) * minuteHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AndroidCalendarChip extends StatelessWidget {
  const _AndroidCalendarChip({
    required this.item,
    required this.onOpen,
    this.showTime = false,
  });

  final ScheduleItem item;
  final ValueChanged<ScheduleItem> onOpen;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final color = ScheduleProjection.colorForItem(
      item,
      Theme.of(context).brightness,
    );
    return Material(
      color: color.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Text(
            showTime && item.start != null
                ? '${BusyMaxTimeFormatScope.of(context).format(item.start!)} ${item.title}'
                : item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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
  DateTime day,
) {
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
    var lane = laneEnds.indexWhere((end) => end <= candidate.start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(candidate.end);
    } else {
      laneEnds[lane] = candidate.end;
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
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleItem> onOpen;
  final ValueChanged<TaskScheduleItem> onToggleTask;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledDayText = MediaQuery.textScalerOf(context).scale(16);
        // The grid is inside the outer vertical scroller, so preserve the
        // user's text scale with real civil-day row height instead of
        // shrinking full-size Month labels to fit a viewport fraction.
        final gridHeight = 30 + 6 * (scaledDayText * 1.55 + 36);
        final agendaHeight = (constraints.maxHeight * .42).clamp(200.0, 420.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 180) return;
            onSelectDate(
              DateTime(anchor.year, anchor.month + (velocity < 0 ? 1 : -1)),
            );
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: gridHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: _AndroidMonthGrid(
                      key: const ValueKey('android-month-grid'),
                      displayedMonth: DateTime(anchor.year, anchor.month),
                      selectedDate: anchor,
                      items: items,
                      onDaySelected: onSelectDate,
                    ),
                  ),
                ),
                SizedBox(
                  height: agendaHeight,
                  child: _AgendaList(
                    items: ScheduleProjection.itemsForDay(items, anchor),
                    onOpen: onOpen,
                    onToggleTask: onToggleTask,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.items,
    required this.onSelectDate,
    required this.onModeChanged,
  });
  final DateTime anchor;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  @override
  Widget build(BuildContext context) => GridView.builder(
    key: const ValueKey('android-year-grid'),
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 330,
      mainAxisExtent: 245,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: 12,
    itemBuilder: (context, index) {
      final month = DateTime(anchor.year, index + 1);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            onSelectDate(month);
            onModeChanged(ScheduleViewMode.month);
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat.MMMM().format(month),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: IgnorePointer(
                    child: _AndroidMonthGrid(
                      displayedMonth: month,
                      selectedDate: anchor,
                      items: items,
                      onDaySelected: (_) {},
                      compact: true,
                    ),
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

class _AndroidMonthGrid extends StatelessWidget {
  const _AndroidMonthGrid({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.items,
    required this.onDaySelected,
    this.compact = false,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDaySelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = _firstWeekday(context);
    final month = DateTime(displayedMonth.year, displayedMonth.month);
    final range = androidMonthGridRange(
      displayedMonth,
      firstWeekday: firstWeekday,
    );
    final gridStart = range.start;
    final days = [
      for (var index = 0; index < 42; index++)
        DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    ];
    final weekdays = [
      for (var index = 0; index < 7; index++)
        ((firstWeekday + index - 1) % 7) + 1,
    ];
    return Column(
      children: [
        SizedBox(
          height: compact ? 16 : 22,
          child: Row(
            children: [
              for (final weekday in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E().format(DateTime(2026, 1, 5 + weekday - 1)),
                      maxLines: 1,
                      style: compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium,
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
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _AndroidMonthDay(
                      day: days[row * 7 + column],
                      displayedMonth: month,
                      selectedDate: selectedDate,
                      items: items,
                      compact: compact,
                      onSelected: onDaySelected,
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
  });

  final DateTime day;
  final DateTime displayedMonth;
  final DateTime selectedDate;
  final List<ScheduleItem> items;
  final bool compact;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final matching = ScheduleProjection.itemsForDay(items, day);
    final selected = _sameDay(day, selectedDate);
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${day.day}',
          style:
              (compact
                      ? Theme.of(context).textTheme.labelSmall
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    color: day.month == displayedMonth.month
                        ? null
                        : scheme.onSurfaceVariant.withValues(alpha: .45),
                  ),
        ),
        if (matching.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final item in matching.take(compact ? 2 : 3))
                Container(
                  width: compact ? 3 : 5,
                  height: compact ? 3 : 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
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
    );
    return InkWell(
      onTap: () => onSelected(day),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? scheme.secondaryContainer : null,
          border: compact
              ? null
              : Border.all(color: Theme.of(context).dividerColor, width: .35),
        ),
        child: compact
            ? FittedBox(fit: BoxFit.scaleDown, child: content)
            : Center(child: content),
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
  late EventEditorDraft _draft = widget.draft;
  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _location = TextEditingController(
    text: _draft.location,
  );
  late final TextEditingController _description = TextEditingController(
    text: _draft.description,
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
  int? _reminderMinutes;
  late RecurrenceFrequency _frequency = EventRecurrenceCodec.decode(
    _provider,
    _draft.recurrence,
    baseDate: _draft.start,
  ).frequency;
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
    unawaited(_restoreRecovery());
    _recoveryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_persistRecovery()),
    );
  }

  @override
  void dispose() {
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
    return _draft.eventId == null
        ? source.capabilities.canCreateEvents
        : source.capabilities.canEditEvents;
  }

  bool get _canDelete =>
      _draft.eventId != null &&
      (_source?.capabilities.canDeleteEvents ?? false);

  bool get _hasPendingEdits =>
      _draft != widget.draft ||
      _guests.text !=
          widget.draft.attendees
              .where((attendee) => !attendee.self && !attendee.organizer)
              .map((attendee) => attendee.email)
              .join(', ') ||
      _categories.text != widget.draft.categories.join(', ') ||
      _reminderMinutes != null ||
      _recurrenceChanged;

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
              onPressed: _saving || !_canEdit ? null : _save,
              child: Text(context.l10n.save),
            ),
          ],
        ),
        body: Form(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                initialValue: _source?.id,
                decoration: InputDecoration(labelText: context.l10n.calendar),
                items: [
                  for (final source in widget.sources)
                    DropdownMenuItem(
                      value: source.id,
                      child: Text(
                        '${source.summary} · ${source.authenticatedAccountEmail ?? source.accountId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _draft.eventId != null || !_canEdit
                    ? null
                    : (id) {
                        final source = widget.sources.firstWhere(
                          (s) => s.id == id,
                        );
                        setState(
                          () => _draft = _draft.copyWith(
                            accountId: source.accountId,
                            sourceId: source.id,
                            providerCalendarId: source.providerCalendarId,
                            clearShowAs: true,
                            clearVisibilityOrSensitivity: true,
                          ),
                        );
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.allDay),
                value: _draft.allDay,
                onChanged: !_canEdit
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(allDay: value),
                      ),
              ),
              _DateTimeTile(
                label: context.l10n.startDateTime,
                value: _draft.start!,
                allDay: _draft.allDay,
                onChanged: !_canEdit
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(start: value),
                      ),
              ),
              _DateTimeTile(
                label: context.l10n.endDateTime,
                value: _draft.end!,
                allDay: _draft.allDay,
                onChanged: !_canEdit
                    ? null
                    : (value) =>
                          setState(() => _draft = _draft.copyWith(end: value)),
              ),
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
                onChanged: !_canEdit
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(showAs: value),
                      ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('android-event-visibility-${_provider.name}'),
                initialValue:
                    _eventVisibilityValues(
                      _provider,
                    ).contains(_draft.visibilityOrSensitivity)
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
                onChanged: !_canEdit
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
              TextFormField(
                controller: _description,
                enabled: _canEdit,
                minLines: 3,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: context.l10n.description,
                ),
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(description: v)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency>(
                initialValue: _frequency,
                decoration: InputDecoration(labelText: context.l10n.repeat),
                items: [
                  DropdownMenuItem(
                    value: RecurrenceFrequency.none,
                    child: Text(context.l10n.repeatNone),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceFrequency.daily,
                    child: Text(context.l10n.repeatDaily),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceFrequency.weekly,
                    child: Text(context.l10n.repeatWeekly),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceFrequency.monthly,
                    child: Text(context.l10n.repeatMonthly),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceFrequency.yearly,
                    child: Text(context.l10n.repeatYearly),
                  ),
                ],
                onChanged: !_canEdit
                    ? null
                    : (value) => setState(() {
                        _frequency = value ?? RecurrenceFrequency.none;
                        _recurrenceChanged = true;
                      }),
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
              DropdownButtonFormField<int>(
                initialValue: _reminderMinutes,
                decoration: InputDecoration(labelText: context.l10n.reminder),
                items: [
                  DropdownMenuItem(
                    value: 0,
                    child: Text(context.l10n.repeatNone),
                  ),
                  for (final value in const [5, 10, 30, 60, 1440])
                    DropdownMenuItem(
                      value: value,
                      child: Text(context.l10n.reminderMinutesBefore(value)),
                    ),
                ],
                onChanged: !_canEdit
                    ? null
                    : (value) => setState(() => _reminderMinutes = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guests,
                enabled: _canEdit && _draft.canManageAttendees,
                decoration: InputDecoration(labelText: context.l10n.guests),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
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
              if (_canDelete) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.deleteEvent),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final start = _draft.start;
    if (_title.text.trim().isEmpty || start == null) return;
    final attendeeEdit = mergeAndroidEventAttendees(
      widget.draft.attendees,
      _guests.text,
    );
    final categories = _categories.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    var draft = _draft.copyWith(
      title: _title.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
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
        clearReminders: value == 0,
      );
    }
    if (_recurrenceChanged) {
      final rule = _simpleRecurrenceRule(_frequency, start);
      draft = draft.copyWith(
        recurrence: rule.repeats
            ? EventRecurrenceCodec.encode(
                _provider,
                rule,
                baseDate: start,
                allDay: draft.allDay,
                timeZone: draft.startTimeZone,
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
    setState(() => _saving = true);
    try {
      if ((_reminderMinutes ?? 0) > 0) {
        await ref
            .read(androidNotificationServiceProvider)
            .requestNotificationPermission();
      }
      if (draft.eventId == null) {
        await ref.read(calendarRepositoryProvider).createLocalEvent(draft);
      } else {
        await ref.read(calendarRepositoryProvider).updateLocalEvent(draft);
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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
    if (source.provider == BusyProvider.google) return true;
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
      draft: _draft.copyWith(attendees: attendees),
    );
  }

  Future<void> _delete() async {
    var draft = _draft;
    if (draft.providerRecurringEventId != null &&
        draft.recurringMutationScope == null) {
      final scope = await _selectRecurringScope();
      if (scope == null) return;
      draft = draft.copyWith(recurringMutationScope: scope);
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteEvent),
        content: Text(draft.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || _draft.eventId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(calendarRepositoryProvider)
          .deleteLocalEvent(
            _draft.eventId!,
            recurringScope: draft.recurringMutationScope,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<RecurringEventMutationScope?> _selectRecurringScope() async {
    final scope = await showModalBottomSheet<RecurringEventMutationScope>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(context.l10n.chooseRecurringEventScope)),
            for (final value in RecurringEventMutationScope.values)
              if (value != RecurringEventMutationScope.thisAndFuture ||
                  supportsThisAndFollowingEventMutation(_provider))
                ListTile(
                  leading: Icon(
                    _draft.recurringMutationScope == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(_scopeLabel(context, value)),
                  onTap: () => Navigator.pop(context, value),
                ),
          ],
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
        _categories.text = map['categories']?.toString() ?? _categories.text;
        _reminderMinutes = map['reminderMinutes'] as int?;
        if (frequency != null && frequency != _frequency) {
          _frequency = frequency;
          _recurrenceChanged = true;
        }
        _draft = _draft.copyWith(
          accountId: recoveredSource.accountId,
          sourceId: recoveredSource.id,
          providerCalendarId: recoveredSource.providerCalendarId,
          title: _title.text,
          location: _location.text,
          description: _description.text,
          allDay: map['allDay'] as bool? ?? _draft.allDay,
          start: start,
          end: end,
          recurringMutationScope: recurringScope,
          clearRecurringMutationScope: recurringScope == null,
          showAs: map['showAs']?.toString(),
          clearShowAs: map['showAs'] == null,
          visibilityOrSensitivity: map['visibility']?.toString(),
          clearVisibilityOrSensitivity: map['visibility'] == null,
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
      'guests': _guests.text,
      'categories': _categories.text,
      'allDay': _draft.allDay,
      'start': _draft.start?.toIso8601String(),
      'end': _draft.end?.toIso8601String(),
      'reminderMinutes': _reminderMinutes,
      'frequency': _frequency.name,
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

final class AndroidEventAttendeeEdit {
  const AndroidEventAttendeeEdit({
    required this.attendees,
    required this.changed,
  });

  final List<EventAttendeeDraft> attendees;
  final bool changed;
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

RecurrenceRule _simpleRecurrenceRule(
  RecurrenceFrequency frequency,
  DateTime base,
) {
  final weekday = const [
    'MO',
    'TU',
    'WE',
    'TH',
    'FR',
    'SA',
    'SU',
  ][base.weekday - 1];
  return const RecurrenceRule.none().copyWith(
    frequency: frequency,
    byDay: frequency == RecurrenceFrequency.weekly ? [weekday] : const [],
    byMonthDay:
        frequency == RecurrenceFrequency.monthly ||
            frequency == RecurrenceFrequency.yearly
        ? [base.day]
        : const [],
    byMonth: frequency == RecurrenceFrequency.yearly ? [base.month] : const [],
  );
}

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
  ScheduleViewMode.agenda => ScheduleRange(
    start: DateTime(anchor.year, anchor.month, anchor.day - 30),
    end: DateTime(anchor.year, anchor.month, anchor.day + 91),
  ),
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
  ScheduleViewMode.day ||
  ScheduleViewMode.agenda => DateFormat.yMMMMd().format(date),
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
  if (minutes <= 0) return null;
  return provider == BusyProvider.microsoft
      ? {'isReminderOn': true, 'reminderMinutesBeforeStart': minutes}
      : {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': minutes},
          ],
        };
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

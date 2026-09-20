import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../app/busymax_shortcuts.dart';
import '../../app/common/busymax_design_values.dart';
import '../../app/common/busymax_mutation_list.dart';
import '../../schedule/task_list_mutation_intent.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_item.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_task_details_dialog.dart';
import 'windows_task_editor_dialog.dart';
import 'windows_nextcloud_dialogs.dart';
import '../../providers/busy_provider.dart';

class WindowsTasksPage extends ConsumerStatefulWidget {
  const WindowsTasksPage({super.key});

  @override
  ConsumerState<WindowsTasksPage> createState() => _WindowsTasksPageState();
}

class _WindowsTasksPageState extends ConsumerState<WindowsTasksPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Future<List<TaskScheduleItem>>? _tasks;
  var _query = '';
  String? _accountId;
  ScheduleTaskListKey? _listKey;
  var _showCompleted = false;
  Timer? _searchDebounce;
  final _pendingCompletion = <String>{};
  var _mutationGeneration = 0;
  TaskListMutationIntent? _mutationIntent;

  @override
  void initState() {
    super.initState();
    ref.listenManual(scheduleDataRevisionProvider, (previous, next) {
      if (next.hasValue && mounted) _reload();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<List<TaskScheduleItem>> _load() async {
    final repository = ref.read(scheduleRepositoryProvider);
    final filters = ScheduleFilters(
      query: _query,
      accountIds: {if (_accountId != null) _accountId!},
      taskListKeys: {if (_listKey != null) _listKey!},
      taskListFilterActive: _listKey != null,
      includeCalendarEvents: false,
      includeTasks: true,
      taskCompletion: _showCompleted
          ? ScheduleTaskCompletion.all
          : ScheduleTaskCompletion.open,
      showNoDateTasks: true,
    );
    return repository.listAllTasks(filters: filters);
  }

  void _reload() => setState(() {
    _tasks = null;
  });

  void _retry() {
    if (ref.read(accountsStreamProvider).hasError) {
      ref.invalidate(accountsStreamProvider);
    }
    if (ref.read(scheduleTaskListsProvider).hasError) {
      ref.invalidate(scheduleTaskListsProvider);
    }
    _reload();
  }

  Future<void> _manageLists() async {
    final collections = await ref
        .read(davSettingsRepositoryProvider)
        .watchCollections()
        .first;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(l10n.nextcloudCollectionSettings),
        content: SizedBox(
          height: 340,
          child: ListView(
            children: [
              for (final collection in collections)
                if (collection.provider == BusyProvider.nextcloud &&
                    collection.supportsTasks)
                  ListTile(
                    title: Text(collection.name),
                    subtitle: Text(collection.accountLabel),
                    onPressed: () => showWindowsNextcloudCollectionDialog(
                      dialogContext,
                      accountId: collection.accountId,
                      collectionId: collection.id,
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask() async {
    final result = await showWindowsTaskEditorDialog(
      context,
      ref,
      initialAccountId: _listKey?.accountId ?? _accountId,
      initialTaskListId: _listKey?.taskListId,
    );
    if (result != null && mounted) {
      setState(() {
        _mutationIntent = TaskListMutationIntent(
          presentation: TaskListMutationPresentation.insertion,
          accountId: result.accountId,
          taskListId: result.taskListId,
          taskId: result.taskId,
          generation: ++_mutationGeneration,
        );
      });
      _reload();
    }
  }

  Future<void> _setCompleted(TaskScheduleItem task, bool completed) async {
    final key = '${task.accountId}/${task.sourceId}/${task.id}';
    if (!task.capabilities.canEdit || !_pendingCompletion.add(key)) return;
    setState(() {
      _mutationIntent = TaskListMutationIntent(
        presentation: TaskListMutationPresentation.completion,
        accountId: task.accountId,
        taskListId: task.sourceId,
        taskId: task.id,
        completed: completed,
        generation: ++_mutationGeneration,
      );
    });
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(task.accountId))
          .patchTask(
            task.sourceId,
            task.id,
            TaskPatchInput({
              'status': completed ? 'completed' : 'needsAction',
              'completed': completed
                  ? DateTime.now().toUtc().toIso8601String()
                  : null,
            }),
          );
      if (mounted) _reload();
    } on Object catch (_) {
      if (mounted) {
        setState(() => _mutationIntent = null);
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(AppLocalizations.of(context).operationFailed),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    } finally {
      _pendingCompletion.remove(key);
      if (mounted) setState(() {});
    }
  }

  void _dismissSearch() {
    if (!_searchFocusNode.hasFocus && _query.isEmpty) return;
    _searchDebounce?.cancel();
    _searchController.clear();
    _query = '';
    _mutationIntent = null;
    _searchFocusNode.unfocus();
    _reload();
  }

  bool _animatesCompletion(TaskScheduleItem task) {
    final intent = _mutationIntent;
    return intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent?.completed != null;
  }

  bool _displayedCompletion(TaskScheduleItem task) {
    final intent = _mutationIntent;
    if (intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent?.completed != null) {
      return intent!.completed!;
    }
    return task.completed;
  }

  void _createTaskFromShortcut() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return;
    }
    unawaited(_createTask());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final accountsState = ref.watch(accountsStreamProvider);
    final accounts = accountsState.valueOrNull ?? const [];
    final listsState = ref.watch(scheduleTaskListsProvider);
    final lists = listsState.valueOrNull ?? const [];

    // Reconcile only authoritative results. Refreshing providers may still
    // carry the previous data, and a loading/error state cannot prove removal.
    final accountsLoaded =
        !accountsState.isLoading &&
        !accountsState.hasError &&
        accountsState.hasValue;
    final listsLoaded =
        !listsState.isLoading && !listsState.hasError && listsState.hasValue;
    final missingAccount =
        accountsLoaded &&
        _accountId != null &&
        !accounts.any((a) => a.id == _accountId && a.isTaskCapable);
    final missingList =
        _listKey != null &&
        ((accountsLoaded &&
                !accounts.any(
                  (a) => a.id == _listKey!.accountId && a.isTaskCapable,
                )) ||
            (listsLoaded &&
                !lists.any(
                  (l) =>
                      l.accountId == _listKey!.accountId &&
                      l.id == _listKey!.taskListId,
                )));
    if (missingAccount || missingList) {
      if (missingAccount) _accountId = null;
      if (missingList || missingAccount) _listKey = null;
      _tasks = null;
    }

    return CallbackShortcuts(
      bindings: {
        BusyMaxShortcutActivators.search: _searchFocusNode.requestFocus,
        BusyMaxShortcutActivators.dismiss: _dismissSearch,
        const SingleActivator(LogicalKeyboardKey.keyT): _createTaskFromShortcut,
      },
      child: ScaffoldPage(
        header: PageHeader(
          title: Text(l10n.tasks),
          commandBar: CommandBar(
            primaryItems: [
              if (ref
                      .watch(accountManagementStreamProvider)
                      .valueOrNull
                      ?.any(
                        (account) => account.provider == BusyProvider.nextcloud,
                      ) ==
                  true)
                CommandBarButton(
                  icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.settings)),
                  label: Text(l10n.nextcloudCollectionSettings),
                  onPressed: () => unawaited(_manageLists()),
                ),
              CommandBarButton(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add)),
                label: Text(l10n.newTask),
                onPressed: () => unawaited(_createTask()),
              ),
              CommandBarButton(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.refresh)),
                label: Text(l10n.refresh),
                onPressed: _retry,
              ),
            ],
          ),
        ),
        content: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
              child: TextBox(
                controller: _searchController,
                focusNode: _searchFocusNode,
                placeholder: l10n.windowsSearch,
                prefix: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.search)),
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    () {
                      if (!mounted) return;
                      _mutationIntent = null;
                      _query = value;
                      _reload();
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InfoLabel(
                    label: l10n.accounts,
                    child: ComboBox<String>(
                      placeholder: Text(l10n.allTasks),
                      value: accounts.any((a) => a.id == _accountId)
                          ? _accountId
                          : null,
                      items: [
                        ComboBoxItem(value: '', child: Text(l10n.allTasks)),
                        for (final account in accounts.where(
                          (a) => a.isTaskCapable,
                        ))
                          ComboBoxItem(
                            value: account.id,
                            child: Text(account.selectorLabel),
                          ),
                      ],
                      onChanged: (value) {
                        _mutationIntent = null;
                        _accountId = value == '' ? null : value;
                        _listKey = null;
                        _reload();
                      },
                    ),
                  ),
                  InfoLabel(
                    label: l10n.taskLists,
                    child: ComboBox<ScheduleTaskListKey>(
                      placeholder: Text(l10n.allTasks),
                      value:
                          lists.any(
                            (l) =>
                                l.accountId == _listKey?.accountId &&
                                l.id == _listKey?.taskListId,
                          )
                          ? _listKey
                          : null,
                      items: [
                        ComboBoxItem(
                          value: const ScheduleTaskListKey(
                            accountId: '',
                            taskListId: '',
                          ),
                          child: Text(l10n.allTasks),
                        ),
                        for (final list in lists.where(
                          (l) =>
                              _accountId == null || l.accountId == _accountId,
                        ))
                          ComboBoxItem(
                            value: ScheduleTaskListKey(
                              accountId: list.accountId,
                              taskListId: list.id,
                            ),
                            child: Text(
                              '${accounts.where((a) => a.id == list.accountId).firstOrNull?.selectorLabel ?? list.accountId} · ${list.title}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        _mutationIntent = null;
                        _listKey = value?.accountId == '' ? null : value;
                        _reload();
                      },
                    ),
                  ),
                  Checkbox(
                    checked: _showCompleted,
                    content: Text(l10n.completed),
                    onChanged: (value) {
                      _mutationIntent = null;
                      _showCompleted = value ?? false;
                      _reload();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TaskScheduleItem>>(
                future: _tasks ??= _load(),
                builder: (context, snapshot) {
                  if ((snapshot.connectionState != ConnectionState.done &&
                          !snapshot.hasData) ||
                      (accountsState.isLoading && !accountsState.hasValue)) {
                    return const Center(child: ProgressRing());
                  }
                  if (snapshot.hasError ||
                      accountsState.hasError ||
                      listsState.hasError) {
                    return Center(
                      child: InfoBar(
                        title: Text(l10n.scheduleUnavailable),
                        severity: InfoBarSeverity.error,
                        action: Button(
                          onPressed: _retry,
                          child: Text(l10n.retry),
                        ),
                      ),
                    );
                  }
                  final tasks = snapshot.data ?? const [];
                  return BusyMaxMutationList<TaskScheduleItem>(
                    items: tasks,
                    mutation: _mutationIntent,
                    identityOf: (task) =>
                        '${task.accountId}\u0000${task.sourceId}\u0000${task.id}',
                    mutationApplied: (task, mutation) =>
                        mutation.completed == null ||
                        task.completed == mutation.completed,
                    onMutationConsumed: (mutation) {
                      if (_mutationIntent?.generation == mutation.generation) {
                        setState(() => _mutationIntent = null);
                      }
                    },
                    emptyBuilder: (context) => Center(
                      child: Text(
                        accounts.isEmpty
                            ? l10n.signInToViewTasks
                            : _query.isNotEmpty
                            ? l10n.scheduleNoSearchResults
                            : _listKey != null
                            ? l10n.noTasksInList
                            : l10n.noTasksYet,
                      ),
                    ),
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      24,
                      0,
                      24,
                      24,
                    ),
                    itemBuilder: (context, task, index) {
                      final displayedCompleted = _displayedCompletion(task);
                      final due = task.start == null
                          ? ''
                          : DateFormat.yMMMd(locale).format(task.start!);
                      return Padding(
                        padding: EdgeInsetsDirectional.only(
                          bottom: 8,
                          start: task.hierarchyDepth.clamp(0, 8) * 20.0,
                        ),
                        child: Card(
                          child: ListTile(
                            leading: Checkbox(
                              checked: displayedCompleted,
                              semanticLabel: task.title,
                              onChanged:
                                  task.capabilities.canEdit &&
                                      !_pendingCompletion.contains(
                                        '${task.accountId}/${task.sourceId}/${task.id}',
                                      )
                                  ? (value) => unawaited(
                                      _setCompleted(task, value ?? false),
                                    )
                                  : null,
                            ),
                            title: AnimatedDefaultTextStyle(
                              duration:
                                  MediaQuery.disableAnimationsOf(context) ||
                                      !_animatesCompletion(task)
                                  ? Duration.zero
                                  : BusyMaxMotion.taskCompletion,
                              curve: BusyMaxMotion.presentationCurve,
                              style:
                                  (FluentTheme.of(context).typography.body ??
                                          const TextStyle())
                                      .copyWith(
                                        decoration: displayedCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: displayedCompleted
                                            ? FluentTheme.of(
                                                context,
                                              ).inactiveColor
                                            : null,
                                      ),
                              child: Text(task.title),
                            ),
                            subtitle: Text(
                              [
                                due,
                                ?task.accountEmail ?? task.accountDisplayName,
                                ?task.sourceName,
                                if (task.parentTitle != null) task.parentTitle!,
                              ].where((value) => value.isNotEmpty).join(' · '),
                            ),
                            onPressed: () => unawaited(
                              showWindowsTaskDetailsDialog(
                                context,
                                ref,
                                task,
                              ).then((changed) {
                                if (changed) _reload();
                              }),
                            ),
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
      ),
    );
  }
}

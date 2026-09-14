import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../features/tasks/presentation/task_details_draft.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_item.dart';

final _androidTasksProvider = FutureProvider.autoDispose
    .family<
      List<TaskScheduleItem>,
      ({
        String query,
        String? accountId,
        String? listId,
        bool completed,
        bool noDate,
      })
    >((ref, key) {
      ref.watch(scheduleDataRevisionProvider);
      final lists =
          ref.watch(scheduleTaskListsProvider).valueOrNull ?? const [];
      final selected = lists
          .where(
            (list) => list.id == key.listId && list.accountId == key.accountId,
          )
          .firstOrNull;
      return ref
          .watch(scheduleRepositoryProvider)
          .listAllTasks(
            filters: ScheduleFilters(
              query: key.query,
              showCompletedTasks: key.completed,
              showNoDateTasks: key.noDate,
              taskListFilterActive: selected != null,
              taskListKeys: selected == null
                  ? const {}
                  : {
                      ScheduleTaskListKey(
                        accountId: selected.accountId,
                        taskListId: selected.id,
                      ),
                    },
              includeCalendarEvents: false,
            ),
          );
    });

class AndroidTasksScreen extends ConsumerStatefulWidget {
  const AndroidTasksScreen({super.key});
  @override
  ConsumerState<AndroidTasksScreen> createState() => _AndroidTasksScreenState();
}

class _AndroidTasksScreenState extends ConsumerState<AndroidTasksScreen> {
  String _query = '';
  String? _accountId;
  String? _listId;
  bool _showCompleted = true;
  bool _showNoDate = true;

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(scheduleTaskListsProvider).valueOrNull ?? const [];
    if (_listId != null &&
        !lists.any(
          (list) => list.id == _listId && list.accountId == _accountId,
        )) {
      _accountId = null;
      _listId = null;
    }
    final tasks = ref.watch(
      _androidTasksProvider((
        query: _query,
        accountId: _accountId,
        listId: _listId,
        completed: _showCompleted,
        noDate: _showNoDate,
      )),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tasks),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() {
              if (value == 'completed') _showCompleted = !_showCompleted;
              if (value == 'no-date') _showNoDate = !_showNoDate;
            }),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'completed',
                checked: _showCompleted,
                child: Text(context.l10n.completed),
              ),
              CheckedPopupMenuItem(
                value: 'no-date',
                checked: _showNoDate,
                child: Text(context.l10n.noDate),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                SearchBar(
                  hintText: context.l10n.windowsSearch,
                  leading: const Icon(Icons.search),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _listId == null
                      ? null
                      : _taskListKey(_accountId!, _listId!),
                  decoration: InputDecoration(
                    labelText: context.l10n.list,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.allTasks),
                    ),
                    for (final list in lists)
                      DropdownMenuItem(
                        value: _taskListKey(list.accountId, list.id),
                        child: Text(list.title),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    if (value == null) {
                      _accountId = null;
                      _listId = null;
                      return;
                    }
                    final separator = value.indexOf('\u0000');
                    _accountId = value.substring(0, separator);
                    _listId = value.substring(separator + 1);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => items.isEmpty
            ? Center(child: Text(context.l10n.noTasks))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final task = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 8.0 + 16 * task.hierarchyDepth.clamp(0, 3),
                      right: 12,
                    ),
                    leading: IconButton(
                      iconSize: 30,
                      tooltip: task.completed
                          ? context.l10n.taskStatusCompleted
                          : context.l10n.taskStatusInProcess,
                      onPressed: task.capabilities.canEdit
                          ? () => _toggle(task)
                          : null,
                      icon: Icon(
                        task.completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                    ),
                    title: Text(
                      task.title,
                      style: task.completed
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    subtitle: Text(
                      [
                        task.sourceName ?? task.provider.displayName,
                        if (task.start != null)
                          DateFormat.yMMMd().format(task.start!),
                        if (task.parentTitle != null) task.parentTitle!,
                      ].join(' · '),
                    ),
                    trailing: task.hasSubtasks
                        ? const Icon(Icons.account_tree_outlined)
                        : null,
                    onTap: () =>
                        showAndroidTaskEditor(context, ref, task: task),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: lists.isEmpty ? null : () => _create(lists),
        tooltip: context.l10n.newTask,
        child: const Icon(Icons.add_task),
      ),
    );
  }

  Future<void> _toggle(TaskScheduleItem task) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _create(List<TaskListEntity> lists) async {
    final current = lists
        .where((list) => list.id == _listId && list.accountId == _accountId)
        .firstOrNull;
    final selected =
        current ??
        await selectAndroidTaskList(
          context,
          lists,
          title: context.l10n.newTask,
        );
    if (selected == null || !mounted) return;
    final accounts =
        ref.read(accountsStreamProvider).valueOrNull ?? const <AccountEntity>[];
    final account = accounts
        .where((value) => value.id == selected.accountId)
        .firstOrNull;
    if (account == null) return;
    await showAndroidTaskEditor(
      context,
      ref,
      creationList: selected,
      creationProvider: account.provider,
    );
  }
}

Future<TaskListEntity?> selectAndroidTaskList(
  BuildContext context,
  List<TaskListEntity> lists, {
  required String title,
}) {
  if (lists.length == 1) return Future.value(lists.single);
  return showModalBottomSheet<TaskListEntity>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(title)),
          for (final list in lists)
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(list.title),
              onTap: () => Navigator.pop(sheetContext, list),
            ),
        ],
      ),
    ),
  );
}

Future<void> showAndroidTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  TaskScheduleItem? task,
  TaskListEntity? creationList,
  BusyProvider? creationProvider,
  DateTime? initialDue,
}) async {
  TaskEntity? entity;
  if (task != null) {
    entity = await ref
        .read(tasksRepositoryForAccountProvider(task.accountId))
        .watchTask(task.sourceId, task.id)
        .first;
    if (!context.mounted || entity == null) return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AndroidTaskEditor(
        accountId: task?.accountId ?? creationList!.accountId,
        provider: task?.provider ?? creationProvider!,
        task: entity,
        creationList: creationList,
        initialDue: initialDue,
      ),
    ),
  );
}

class AndroidTaskEditor extends ConsumerStatefulWidget {
  const AndroidTaskEditor({
    super.key,
    required this.accountId,
    required this.provider,
    this.task,
    this.creationList,
    this.initialDue,
  });
  final String accountId;
  final BusyProvider provider;
  final TaskEntity? task;
  final TaskListEntity? creationList;
  final DateTime? initialDue;
  @override
  ConsumerState<AndroidTaskEditor> createState() => _AndroidTaskEditorState();
}

class _AndroidTaskEditorState extends ConsumerState<AndroidTaskEditor> {
  late TaskDetailsDraft _draft = widget.task == null
      ? TaskDetailsDraft.forCreation(
          taskListId: widget.creationList!.id,
          provider: widget.provider,
          timeZone: ref.read(localTimeZoneProvider),
          due: widget.initialDue,
        )
      : TaskDetailsDraft.fromTask(
          widget.task!,
          ref.read(localTimeZoneProvider),
        );
  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: _draft.notes,
  );
  late final TextEditingController _location = TextEditingController(
    text: _draft.location,
  );
  late final TextEditingController _categories = TextEditingController(
    text: _draft.categories.join(', '),
  );
  bool _saving = false;
  late RecurrenceFrequency _recurrenceFrequency = _taskRecurrence().frequency;

  TaskCollectionCapabilities get _capabilities => switch (widget.provider) {
    BusyProvider.appleICloud || BusyProvider.nextcloud =>
      ref
              .read(
                davTaskCollectionCapabilitiesProvider((
                  accountId: widget.accountId,
                  taskListId: _draft.taskListId,
                )),
              )
              .valueOrNull ??
          noTaskCollectionCapabilities,
    BusyProvider.google ||
    BusyProvider.microsoft => adapterDefaultTaskCapabilities(widget.provider),
    BusyProvider.webCal => noTaskCollectionCapabilities,
  };

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _location.dispose();
    _categories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider == BusyProvider.appleICloud ||
        widget.provider == BusyProvider.nextcloud) {
      ref.watch(
        davTaskCollectionCapabilitiesProvider((
          accountId: widget.accountId,
          taskListId: _draft.taskListId,
        )),
      );
    }
    final capabilities = _capabilities;
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(
          widget.task == null ? context.l10n.newTask : context.l10n.editTask,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.task == null,
            decoration: InputDecoration(labelText: context.l10n.title),
            onChanged: (v) => _draft = _draft.copyWith(title: v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(labelText: context.l10n.notes),
            onChanged: (v) => _draft = _draft.copyWith(notes: v),
          ),
          if (capabilities.supportsDueDate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(context.l10n.dueDate),
              subtitle: Text(_draft.dueDate ?? context.l10n.noDate),
              trailing: _draft.dueDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(
                        () => _draft = _draft.copyWith(
                          dueDate: null,
                          microsoftDueTime: null,
                        ),
                      ),
                    ),
              onTap: _pickDue,
            ),
          if (capabilities.supportsDueTime && _draft.dueDate != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(context.l10n.endTime),
              subtitle: Text(_draft.microsoftDueTime ?? context.l10n.allDay),
              onTap: _pickDueTime,
            ),
          if (capabilities.supportsReminderDateTime)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.reminder),
              value: _draft.microsoftReminderEnabled,
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(
                  microsoftReminderEnabled: value,
                  microsoftReminderDate: value
                      ? (_draft.dueDate ?? _today())
                      : null,
                  microsoftReminderTime: value
                      ? (_draft.microsoftDueTime ?? '09:00')
                      : null,
                ),
              ),
            ),
          if (capabilities.supportsImportance)
            DropdownButtonFormField<String>(
              initialValue: _draft.importance,
              decoration: InputDecoration(labelText: context.l10n.importance),
              items: [
                DropdownMenuItem(
                  value: 'low',
                  child: Text(context.l10n.importanceLow),
                ),
                DropdownMenuItem(
                  value: 'normal',
                  child: Text(context.l10n.importanceNormal),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text(context.l10n.importanceHigh),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(importance: v)),
            ),
          if (capabilities.supportsRecurrence) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _recurrenceFrequency,
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
              onChanged: _setRecurrence,
            ),
          ],
          if (capabilities.supportsCategories) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _categories,
              decoration: InputDecoration(labelText: context.l10n.categories),
              onChanged: (v) => _draft = _draft.copyWith(
                categories: v
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
          ],
          if (capabilities.supportsLocation) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: InputDecoration(labelText: context.l10n.location),
              onChanged: (v) => _draft = _draft.copyWith(location: v),
            ),
          ],
          if (capabilities.supportsPercentComplete)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.completionPercent(_draft.percentComplete)),
                Slider(
                  value: _draft.percentComplete.toDouble(),
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(percentComplete: v.round()),
                  ),
                ),
              ],
            ),
          if (widget.task != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.deleteTask),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _pickDue() async {
    final current = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null) {
      setState(() => _draft = _draft.copyWith(dueDate: _date(value)));
    }
  }

  Future<void> _pickDueTime() async {
    final parts = (_draft.microsoftDueTime ?? '09:00').split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (value != null) {
      setState(
        () => _draft = _draft.copyWith(
          microsoftDueTime:
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  Future<void> _save() async {
    _draft = _draft.copyWith(
      title: _title.text.trim(),
      notes: _notes.text,
      location: _location.text,
      categories: _categories.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    if (_draft.title.trim().isEmpty ||
        !_draft.hasValidTaskUrlFor(_capabilities) ||
        _draft.scheduleIssueFor(_capabilities) != TaskScheduleIssue.none) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(widget.accountId),
      );
      if (widget.task == null) {
        await repository.createTask(
          _draft.taskListId,
          _draft.toCreateInput(
            _capabilities,
            localTimeZone: ref.read(localTimeZoneProvider),
          ),
        );
      } else {
        await repository.patchTask(
          _draft.taskListId,
          _draft.taskId,
          TaskPatchInput(
            _draft.toPatch(
              widget.task!,
              _capabilities,
              localTimeZone: ref.read(localTimeZoneProvider),
            ),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
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

  RecurrenceRule _taskRecurrence() {
    final creation = _draft.creationRecurrence;
    if (creation != null) return creation.rule;
    final raw = _draft.recurrenceJson;
    if (raw == null) return const RecurrenceRule.none();
    try {
      return EventRecurrenceCodec.decode(
        widget.provider,
        jsonDecode(raw),
        baseDate: DateTime.tryParse(_draft.dueDate ?? ''),
      );
    } on Object {
      return const RecurrenceRule.none();
    }
  }

  void _setRecurrence(RecurrenceFrequency? frequency) {
    if (frequency == null) return;
    final base = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final rule = _simpleTaskRecurrenceRule(frequency, base);
    setState(() {
      _recurrenceFrequency = frequency;
      if (widget.task == null) {
        _draft = _draft.copyWith(
          creationRecurrence: (provider: widget.provider, rule: rule),
        );
      } else {
        final encoded = rule.repeats
            ? EventRecurrenceCodec.encode(
                widget.provider,
                rule,
                baseDate: base,
                allDay: _draft.microsoftDueTime == null,
                timeZone: _draft.microsoftDueTimeZone,
                original: _draft.recurrenceJson == null
                    ? null
                    : jsonDecode(_draft.recurrenceJson!),
              )
            : null;
        _draft = _draft.copyWith(
          recurrenceJson: encoded == null ? null : jsonEncode(encoded),
        );
      }
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteTask),
        content: Text(context.l10n.deleteTaskConfirmation(widget.task!.title)),
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
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .deleteTask(widget.task!.taskListId, widget.task!.id);
      if (mounted) Navigator.pop(context);
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
}

String _taskListKey(String accountId, String listId) =>
    '$accountId\u0000$listId';

Future<void> showAndroidTaskById(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required String taskId,
}) async {
  final database = ref.read(databaseProvider);
  final row =
      await (database.select(database.tasks)..where(
            (task) =>
                task.accountId.equals(accountId) &
                task.id.equals(taskId) &
                task.pendingDelete.equals(false),
          ))
          .getSingleOrNull();
  final account = await ref
      .read(accountsRepositoryProvider)
      .accountById(accountId);
  if (!context.mounted || row == null || account == null) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AndroidTaskEditor(
        accountId: accountId,
        provider: account.provider,
        task: TaskEntity.fromRow(row),
      ),
    ),
  );
}

RecurrenceRule _simpleTaskRecurrenceRule(
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

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _today() => _date(DateTime.now());

import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../dav/ical/ical_task_alarm.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/tasks/presentation/task_details_draft.dart';
import '../../features/schedule/presentation/schedule_item_exporter.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_item.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_time_zone_dialog.dart';

Future<bool> showWindowsTaskDetailsDialog(
  BuildContext context,
  WidgetRef ref,
  TaskScheduleItem task,
) async {
  final repository = ref.read(
    tasksRepositoryForAccountProvider(task.accountId),
  );
  final original = await repository.watchTask(task.sourceId, task.id).first;
  final accounts = await ref
      .read(accountsRepositoryProvider)
      .watchAccounts()
      .first;
  final account = accounts
      .where((value) => value.id == task.accountId)
      .firstOrNull;
  if (original == null || account == null || !context.mounted) return false;
  var capabilities = switch (account.provider) {
    BusyProvider.nextcloud =>
      await ref.read(
            davTaskCollectionCapabilitiesProvider((
              accountId: task.accountId,
              taskListId: task.sourceId,
            )).future,
          ) ??
          noTaskCollectionCapabilities,
    BusyProvider.google ||
    BusyProvider.microsoft => adapterDefaultTaskCapabilities(account.provider),
    BusyProvider.appleICloud ||
    BusyProvider.webCal => noTaskCollectionCapabilities,
  };
  if (original.recurrenceIdKey != null &&
      !capabilities.supportsRecurringTaskOccurrenceEditing) {
    capabilities = capabilities.asReadOnly();
  }
  final taskLists = await ref
      .read(taskListsRepositoryForAccountProvider(task.accountId))
      .listTaskLists();
  var hierarchy = capabilities.supportsTaskHierarchy
      ? await repository.watchTaskHierarchy(task.sourceId, task.id).first
      : const TaskHierarchySnapshot(parent: null, subtasks: []);
  if (!context.mounted) return false;
  final localTimeZone = ref.read(localTimeZoneProvider);
  final originalDraft = TaskDetailsDraft.fromTask(original, localTimeZone);
  final title = TextEditingController(text: original.title);
  final notes = TextEditingController(text: original.notes);
  final categories = TextEditingController(
    text: originalDraft.categories.join(', '),
  );
  final location = TextEditingController(text: originalDraft.location);
  final taskUrl = TextEditingController(text: originalDraft.taskUrl);
  final subtaskTitle = TextEditingController();
  var completed = task.completed;
  var selectedTaskListId = original.taskListId;
  var due = _taskDueDateTime(originalDraft);
  var dueHasTime = originalDraft.microsoftDueTime != null;
  var dueTimeZone = originalDraft.microsoftDueTimeZone ?? localTimeZone;
  var start = _taskDateTime(
    originalDraft.microsoftStartDate,
    originalDraft.microsoftStartTime,
  );
  var startHasTime = originalDraft.microsoftStartTime != null;
  var startTimeZone = originalDraft.microsoftStartTimeZone ?? localTimeZone;
  var reminder = _taskDateTime(
    originalDraft.microsoftReminderDate,
    originalDraft.microsoftReminderTime,
  );
  var reminderEnabled = originalDraft.microsoftReminderEnabled;
  var reminderTimeZone =
      originalDraft.microsoftReminderTimeZone ?? localTimeZone;
  var recurrenceType = _recurrenceType(originalDraft.recurrenceJson);
  var recurrenceJson = originalDraft.recurrenceJson;
  var importance = originalDraft.importance;
  var priority = originalDraft.icalPriority;
  var taskStatus = originalDraft.taskStatus ?? '';
  var progress = originalDraft.percentComplete;
  var completedAt = _taskDateTime(
    originalDraft.completedDate,
    originalDraft.completedTime,
  );
  var classification = originalDraft.classification;
  var pinned = originalDraft.pinned;
  var hideSubtasks = originalDraft.hideSubtasks;
  var hideCompletedSubtasks = originalDraft.hideCompletedSubtasks;
  var alarms = [...originalDraft.alarms];
  var busy = false;
  var changed = false;
  var allowPop = false;
  TaskScheduleItem? nextTask;
  String? error;
  String? message;
  TaskDetailsDraft currentDraft() => originalDraft.copyWith(
    taskListId: selectedTaskListId,
    title: title.text.trim(),
    notes: notes.text,
    dueDate: due == null ? null : _dateOnly(due!),
    microsoftDueTime:
        due == null || !capabilities.supportsDueTime || !dueHasTime
        ? null
        : _timeOnly(due!),
    microsoftDueTimeZone: dueTimeZone,
    microsoftStartDate: start == null ? null : _dateOnly(start!),
    microsoftStartTime: start == null || !startHasTime
        ? null
        : _timeOnly(start!),
    microsoftStartTimeZone: startTimeZone,
    microsoftReminderEnabled: reminderEnabled,
    microsoftReminderDate: !reminderEnabled || reminder == null
        ? null
        : _dateOnly(reminder!),
    microsoftReminderTime: !reminderEnabled || reminder == null
        ? null
        : _timeOnly(reminder!),
    microsoftReminderTimeZone: reminderTimeZone,
    recurrenceJson: recurrenceJson,
    importance: importance,
    categories: _categories(categories.text),
    icalPriority: priority,
    percentComplete: progress,
    taskStatus: taskStatus.isEmpty ? null : taskStatus,
    completedDate: completedAt == null ? null : _dateOnly(completedAt!),
    completedTime: completedAt == null ? null : _timeOnly(completedAt!),
    location: location.text,
    taskUrl: taskUrl.text.trim(),
    classification: classification,
    pinned: pinned,
    hideSubtasks: hideSubtasks,
    hideCompletedSubtasks: hideCompletedSubtasks,
    alarms: alarms,
  );
  bool hasPendingEdits() =>
      !currentDraft().hasSameValues(originalDraft) ||
      (!capabilities.supportsTaskStatus && completed != task.completed);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final enabled = !busy && capabilities.canUpdateTasks;
        final provisionalDraft = currentDraft();
        final validUrl =
            taskUrl.text.trim().isEmpty ||
            (Uri.tryParse(taskUrl.text.trim())?.hasScheme ?? false);
        void closeDialog() {
          setState(() => allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          });
        }

        return PopScope<void>(
          canPop: allowPop || (!busy && !hasPendingEdits()),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || busy || allowPop) return;
            if (await _confirmDiscardTaskChanges(context) && context.mounted) {
              closeDialog();
            }
          },
          child: ContentDialog(
            title: Text(l10n.editTask),
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoLabel(
                    label: l10n.title,
                    child: TextBox(
                      controller: title,
                      enabled: enabled,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Checkbox(
                    checked: completed,
                    onChanged: busy || !capabilities.canUpdateTasks
                        ? null
                        : (value) => setState(() {
                            completed = value ?? false;
                            if (capabilities.supportsTaskStatus) {
                              taskStatus = completed
                                  ? 'COMPLETED'
                                  : 'NEEDS-ACTION';
                              progress = completed ? 100 : 0;
                              completedAt = completed ? DateTime.now() : null;
                            }
                          }),
                    content: Text(l10n.completed),
                  ),
                  if (capabilities.supportsDueDate) ...[
                    const SizedBox(height: 12),
                    _TaskDateTimeField(
                      label: l10n.dueDate,
                      value: due,
                      showTime: capabilities.supportsDueTime && dueHasTime,
                      timeZone: capabilities.supportsDueTime && dueHasTime
                          ? dueTimeZone
                          : null,
                      enabled: enabled,
                      onChanged: (value) => setState(() => due = value),
                      onChooseTimeZone: () async {
                        final value = await showWindowsTimeZoneDialog(
                          context,
                          selectedTimeZone: dueTimeZone,
                        );
                        if (value != null) setState(() => dueTimeZone = value);
                      },
                    ),
                    if (due != null && capabilities.supportsDueTime) ...[
                      const SizedBox(height: 8),
                      ToggleSwitch(
                        checked: !dueHasTime,
                        onChanged: enabled
                            ? (value) => setState(() => dueHasTime = !value)
                            : null,
                        content: Text(l10n.allDay),
                      ),
                    ],
                  ],
                  if (taskLists.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TaskListCombo(
                      taskLists: taskLists,
                      selectedTaskListId: selectedTaskListId,
                      enabled: enabled && capabilities.supportsCrossListMove,
                      onChanged: (value) =>
                          setState(() => selectedTaskListId = value),
                    ),
                  ],
                  if (capabilities.supportsStartDateTime) ...[
                    const SizedBox(height: 12),
                    _TaskDateTimeField(
                      label: l10n.startDateTime,
                      value: start,
                      showTime: startHasTime,
                      timeZone: startHasTime ? startTimeZone : null,
                      enabled: enabled,
                      onChanged: (value) => setState(() => start = value),
                      onChooseTimeZone: () async {
                        final value = await showWindowsTimeZoneDialog(
                          context,
                          selectedTimeZone: startTimeZone,
                        );
                        if (value != null) {
                          setState(() => startTimeZone = value);
                        }
                      },
                    ),
                    if (start != null) ...[
                      const SizedBox(height: 8),
                      ToggleSwitch(
                        checked: !startHasTime,
                        onChanged: enabled
                            ? (value) => setState(() => startHasTime = !value)
                            : null,
                        content: Text(l10n.allDay),
                      ),
                    ],
                  ],
                  if (capabilities.supportsReminderDateTime &&
                      !capabilities.supportsMultipleReminders) ...[
                    const SizedBox(height: 12),
                    ToggleSwitch(
                      checked: reminderEnabled,
                      onChanged: enabled
                          ? (value) => setState(() {
                              reminderEnabled = value;
                              reminder ??= (due ?? start ?? DateTime.now())
                                  .subtract(const Duration(minutes: 15));
                            })
                          : null,
                      content: Text(l10n.reminder),
                    ),
                    if (reminderEnabled) ...[
                      const SizedBox(height: 8),
                      _TaskDateTimeField(
                        label: l10n.reminderTime,
                        value: reminder,
                        showTime: true,
                        timeZone: reminderTimeZone,
                        enabled: enabled,
                        onChanged: (value) => setState(() {
                          reminder = value;
                          if (value == null) reminderEnabled = false;
                        }),
                        onChooseTimeZone: () async {
                          final value = await showWindowsTimeZoneDialog(
                            context,
                            selectedTimeZone: reminderTimeZone,
                          );
                          if (value != null) {
                            setState(() => reminderTimeZone = value);
                          }
                        },
                      ),
                    ],
                  ],
                  if (capabilities.supportsRecurrence &&
                      (due != null || start != null)) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.repeat,
                      value: recurrenceType,
                      values: {
                        'none': l10n.repeatNone,
                        'daily': l10n.repeatDaily,
                        'weekly': l10n.repeatWeekly,
                        'absoluteMonthly': l10n.repeatMonthly,
                        'absoluteYearly': l10n.repeatYearly,
                        if (recurrenceType == 'unsupported')
                          'unsupported': l10n.unsupportedRecurrencePreserved,
                      },
                      enabled: enabled && recurrenceType != 'unsupported',
                      onChanged: (value) => setState(() {
                        recurrenceType = value;
                        recurrenceJson = _recurrenceJsonFor(
                          value,
                          due: due,
                          start: start,
                          dav: account.provider == BusyProvider.nextcloud,
                        );
                      }),
                    ),
                  ],
                  if (capabilities.supportsImportance &&
                      !capabilities.supportsIcalPriority) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.importance,
                      value: importance,
                      values: {
                        'low': l10n.importanceLow,
                        'normal': l10n.importanceNormal,
                        'high': l10n.importanceHigh,
                      },
                      enabled: enabled,
                      onChanged: (value) => setState(() => importance = value),
                    ),
                  ],
                  if (capabilities.supportsCategories) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.categories,
                      child: TextBox(controller: categories, enabled: enabled),
                    ),
                  ],
                  if (capabilities.supportsTaskStatus) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.taskStatus,
                      value: taskStatus,
                      values: {
                        '': l10n.taskStatusNone,
                        'NEEDS-ACTION': l10n.taskStatusNeedsAction,
                        'IN-PROCESS': l10n.taskStatusInProcess,
                        'COMPLETED': l10n.taskStatusCompleted,
                        'CANCELLED': l10n.taskStatusCancelled,
                      },
                      enabled: enabled,
                      onChanged: (value) => setState(() {
                        taskStatus = value;
                        if (value == 'COMPLETED') {
                          progress = 100;
                          completed = true;
                          completedAt ??= DateTime.now();
                        } else if (value == 'IN-PROCESS') {
                          if (progress == 0 || progress == 100) progress = 1;
                          completed = false;
                          completedAt = null;
                        } else if (value == 'NEEDS-ACTION' || value.isEmpty) {
                          if (progress == 100) progress = 0;
                          completed = false;
                          completedAt = null;
                        }
                      }),
                    ),
                  ],
                  if (capabilities.supportsPercentComplete) ...[
                    const SizedBox(height: 12),
                    Text(l10n.completionPercent(progress)),
                    Slider(
                      value: progress.toDouble(),
                      max: 100,
                      divisions: 100,
                      onChanged: enabled
                          ? (value) => setState(() {
                              progress = value.round();
                              if (progress == 100) {
                                taskStatus = 'COMPLETED';
                                completed = true;
                                completedAt ??= DateTime.now();
                              } else if (progress == 0) {
                                taskStatus = 'NEEDS-ACTION';
                                completed = false;
                                completedAt = null;
                              } else {
                                taskStatus = 'IN-PROCESS';
                                completed = false;
                                completedAt = null;
                              }
                            })
                          : null,
                    ),
                  ],
                  if (capabilities.supportsIcalPriority) ...[
                    const SizedBox(height: 12),
                    Text(_priorityLabel(l10n, priority)),
                    Slider(
                      value: priority.toDouble(),
                      max: 9,
                      divisions: 9,
                      onChanged: enabled
                          ? (value) => setState(() => priority = value.round())
                          : null,
                    ),
                  ],
                  if (capabilities.supportsLocation) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.location,
                      child: TextBox(controller: location, enabled: enabled),
                    ),
                  ],
                  if (capabilities.supportsUrl) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.taskUrl,
                      child: TextBox(
                        controller: taskUrl,
                        enabled: enabled,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (!validUrl)
                      InfoBar(
                        title: Text(l10n.invalidTaskUrl),
                        severity: InfoBarSeverity.warning,
                      ),
                  ],
                  if (capabilities.supportsClassification) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.classification,
                      value: classification,
                      values: {
                        'PUBLIC': l10n.classificationPublic,
                        'CONFIDENTIAL': l10n.classificationConfidential,
                        'PRIVATE': l10n.classificationPrivate,
                      },
                      enabled: enabled && capabilities.canUpdateClassification,
                      onChanged: (value) =>
                          setState(() => classification = value),
                    ),
                  ],
                  if (capabilities.supportsPinning) ...[
                    const SizedBox(height: 12),
                    ToggleSwitch(
                      checked: pinned,
                      onChanged: enabled
                          ? (value) => setState(() => pinned = value)
                          : null,
                      content: Text(l10n.pinTask),
                    ),
                  ],
                  if (capabilities.supportsSubtaskVisibility) ...[
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: hideSubtasks,
                      onChanged: enabled
                          ? (value) => setState(() => hideSubtasks = value)
                          : null,
                      content: Text(l10n.hideSubtasks),
                    ),
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: hideCompletedSubtasks,
                      onChanged: enabled
                          ? (value) =>
                                setState(() => hideCompletedSubtasks = value)
                          : null,
                      content: Text(l10n.hideClosedSubtasks),
                    ),
                  ],
                  if (provisionalDraft.scheduleIssue !=
                      TaskScheduleIssue.none) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(
                        provisionalDraft.scheduleIssue ==
                                TaskScheduleIssue.dueBeforeStart
                            ? l10n.taskDueBeforeStart
                            : l10n.taskStartDueTimeModeMismatch,
                      ),
                      severity: InfoBarSeverity.warning,
                    ),
                  ],
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.notes,
                    child: TextBox(
                      controller: notes,
                      enabled: !busy && capabilities.canUpdateTasks,
                      maxLines: 5,
                    ),
                  ),
                  if (capabilities.supportsTaskHierarchy) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.subtasks,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hierarchy.parent case final parent?)
                            ListTile(
                              leading: Icon(
                                windowsBusyMaxGlyph(BusyMaxGlyph.previous),
                              ),
                              title: Text(parent.title),
                              subtitle: Text(l10n.parent),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (hasPendingEdits() &&
                                          !await _confirmDiscardTaskChanges(
                                            context,
                                          )) {
                                        return;
                                      }
                                      nextTask = _scheduleItemForTask(
                                        parent,
                                        account.provider,
                                      );
                                      closeDialog();
                                    },
                            ),
                          for (final subtask in hierarchy.subtasks)
                            ListTile(
                              leading: Checkbox(
                                checked: subtask.completed,
                                onChanged: enabled
                                    ? (value) async {
                                        setState(() => busy = true);
                                        try {
                                          if (subtask.kind ==
                                              TaskSubtaskKind.task) {
                                            final child = subtask.task!;
                                            await repository.patchTask(
                                              child.taskListId,
                                              child.id,
                                              TaskPatchInput({
                                                'status': value == true
                                                    ? 'completed'
                                                    : 'needsAction',
                                                'completed': value == true
                                                    ? DateTime.now()
                                                          .toUtc()
                                                          .toIso8601String()
                                                    : null,
                                              }),
                                            );
                                          } else {
                                            await repository
                                                .patchChecklistSubtask(
                                                  taskListId:
                                                      original.taskListId,
                                                  parentTaskId: original.id,
                                                  checklistItemId: subtask.id,
                                                  completed: value ?? false,
                                                );
                                          }
                                          hierarchy = await repository
                                              .watchTaskHierarchy(
                                                original.taskListId,
                                                original.id,
                                              )
                                              .first;
                                          setState(() {
                                            busy = false;
                                            changed = true;
                                            error = null;
                                          });
                                        } on Object catch (_) {
                                          setState(() {
                                            busy = false;
                                            error = l10n.operationFailed;
                                          });
                                        }
                                      }
                                    : null,
                              ),
                              title: Text(subtask.title),
                              onPressed:
                                  busy || subtask.kind != TaskSubtaskKind.task
                                  ? null
                                  : () async {
                                      if (hasPendingEdits() &&
                                          !await _confirmDiscardTaskChanges(
                                            context,
                                          )) {
                                        return;
                                      }
                                      nextTask = _scheduleItemForTask(
                                        subtask.task!,
                                        account.provider,
                                      );
                                      closeDialog();
                                    },
                              trailing:
                                  subtask.kind == TaskSubtaskKind.checklistItem
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            windowsBusyMaxGlyph(
                                              BusyMaxGlyph.edit,
                                            ),
                                          ),
                                          onPressed: enabled
                                              ? () async {
                                                  final value =
                                                      await _showTextInputDialog(
                                                        context,
                                                        title: l10n.rename,
                                                        initialValue:
                                                            subtask.title,
                                                      );
                                                  if (value == null ||
                                                      value == subtask.title) {
                                                    return;
                                                  }
                                                  setState(() => busy = true);
                                                  try {
                                                    await repository
                                                        .patchChecklistSubtask(
                                                          taskListId: original
                                                              .taskListId,
                                                          parentTaskId:
                                                              original.id,
                                                          checklistItemId:
                                                              subtask.id,
                                                          title: value,
                                                        );
                                                    hierarchy = await repository
                                                        .watchTaskHierarchy(
                                                          original.taskListId,
                                                          original.id,
                                                        )
                                                        .first;
                                                    setState(() {
                                                      busy = false;
                                                      changed = true;
                                                      error = null;
                                                    });
                                                  } on Object catch (_) {
                                                    setState(() {
                                                      busy = false;
                                                      error =
                                                          l10n.operationFailed;
                                                    });
                                                  }
                                                }
                                              : null,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            windowsBusyMaxGlyph(
                                              BusyMaxGlyph.delete,
                                            ),
                                          ),
                                          onPressed: enabled
                                              ? () async {
                                                  setState(() => busy = true);
                                                  try {
                                                    await repository
                                                        .deleteChecklistSubtask(
                                                          taskListId: original
                                                              .taskListId,
                                                          parentTaskId:
                                                              original.id,
                                                          checklistItemId:
                                                              subtask.id,
                                                        );
                                                    hierarchy = await repository
                                                        .watchTaskHierarchy(
                                                          original.taskListId,
                                                          original.id,
                                                        )
                                                        .first;
                                                    setState(() {
                                                      busy = false;
                                                      changed = true;
                                                      error = null;
                                                    });
                                                  } on Object catch (_) {
                                                    setState(() {
                                                      busy = false;
                                                      error =
                                                          l10n.operationFailed;
                                                    });
                                                  }
                                                }
                                              : null,
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextBox(
                                controller: subtaskTitle,
                                enabled: !busy && capabilities.canCreateTasks,
                                placeholder: l10n.createSubtask,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 8),
                              Button(
                                onPressed:
                                    busy ||
                                        !capabilities.canCreateTasks ||
                                        subtaskTitle.text.trim().isEmpty
                                    ? null
                                    : () async {
                                        setState(() => busy = true);
                                        try {
                                          await repository.createSubtask(
                                            taskListId: original.taskListId,
                                            parentTaskId: original.id,
                                            title: subtaskTitle.text,
                                          );
                                          subtaskTitle.clear();
                                          hierarchy = await repository
                                              .watchTaskHierarchy(
                                                original.taskListId,
                                                original.id,
                                              )
                                              .first;
                                          setState(() {
                                            busy = false;
                                            changed = true;
                                            error = null;
                                          });
                                        } on Object catch (_) {
                                          setState(() {
                                            busy = false;
                                            error = l10n.operationFailed;
                                          });
                                        }
                                      },
                                child: Text(l10n.createSubtask),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (capabilities.supportsTaskReparenting ||
                      capabilities.supportsDuplicate ||
                      capabilities.supportsNativeExport) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (capabilities.supportsTaskReparenting)
                          Button(
                            onPressed: enabled
                                ? () async {
                                    setState(() => busy = true);
                                    try {
                                      await repository.moveTask(
                                        TaskMoveInput(
                                          sourceTaskListId: original.taskListId,
                                          taskId: original.id,
                                        ),
                                      );
                                      hierarchy = await repository
                                          .watchTaskHierarchy(
                                            original.taskListId,
                                            original.id,
                                          )
                                          .first;
                                      setState(() {
                                        busy = false;
                                        changed = true;
                                        error = null;
                                      });
                                    } on Object catch (_) {
                                      setState(() {
                                        busy = false;
                                        error = l10n.operationFailed;
                                      });
                                    }
                                  }
                                : null,
                            child: Text(l10n.moveToTop),
                          ),
                        if (capabilities.supportsDuplicate)
                          Button(
                            onPressed: !busy && capabilities.canCreateTasks
                                ? () async {
                                    setState(() => busy = true);
                                    try {
                                      await repository.duplicateTask(
                                        original.taskListId,
                                        original.id,
                                      );
                                      setState(() {
                                        busy = false;
                                        changed = true;
                                        error = null;
                                        message = l10n.taskDuplicated;
                                      });
                                    } on Object catch (_) {
                                      setState(() {
                                        busy = false;
                                        error = l10n.operationFailed;
                                      });
                                    }
                                  }
                                : null,
                            child: Text(l10n.duplicateTask),
                          ),
                        if (capabilities.supportsNativeExport)
                          Button(
                            onPressed: busy
                                ? null
                                : () async {
                                    try {
                                      final raw = await repository
                                          .nativeTaskExport(
                                            original.taskListId,
                                            original.id,
                                          );
                                      if (raw == null) {
                                        throw StateError(
                                          'Native iCalendar data unavailable.',
                                        );
                                      }
                                      final file =
                                          await exportICalendarWithSaveDialog(
                                            suggestedName: taskExportFileName(
                                              title: original.title,
                                              dueDate: original.dueUtc,
                                            ),
                                            calendarData: raw,
                                          );
                                      if (file != null) {
                                        setState(() {
                                          error = null;
                                          message = l10n.exportedFile(
                                            file.path,
                                          );
                                        });
                                      }
                                    } on Object catch (_) {
                                      setState(() {
                                        error = l10n.operationFailed;
                                      });
                                    }
                                  },
                            child: Text(l10n.export),
                          ),
                      ],
                    ),
                  ],
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(message!),
                      severity: InfoBarSeverity.success,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(error!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                  if (capabilities.supportsMultipleReminders) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.reminder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0; index < alarms.length; index += 1)
                            ListTile(
                              title: Text(_alarmLabel(context, alarms[index])),
                              subtitle: alarms[index].absoluteUtc == null
                                  ? Text(l10n.unsupportedReminder)
                                  : null,
                              onPressed:
                                  !enabled || alarms[index].absoluteUtc == null
                                  ? null
                                  : () async {
                                      final value =
                                          await _showAbsoluteReminderDialog(
                                            context,
                                            initial: alarms[index].absoluteUtc!
                                                .toLocal(),
                                          );
                                      if (value != null) {
                                        setState(() {
                                          alarms[index] = alarms[index]
                                              .withAbsoluteTrigger(
                                                value.toUtc(),
                                              );
                                        });
                                      }
                                    },
                              trailing: IconButton(
                                icon: Icon(
                                  windowsBusyMaxGlyph(BusyMaxGlyph.delete),
                                ),
                                onPressed: enabled
                                    ? () =>
                                          setState(() => alarms.removeAt(index))
                                    : null,
                              ),
                            ),
                          Button(
                            onPressed: enabled
                                ? () async {
                                    final value =
                                        await _showAbsoluteReminderDialog(
                                          context,
                                          initial:
                                              (due ?? start ?? DateTime.now())
                                                  .subtract(
                                                    const Duration(minutes: 15),
                                                  ),
                                        );
                                    if (value != null) {
                                      setState(() {
                                        alarms = [
                                          ...alarms,
                                          IcalTaskAlarm.displayAbsolute(
                                            value.toUtc(),
                                          ),
                                        ];
                                      });
                                    }
                                  }
                                : null,
                            child: Text(l10n.addReminder),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: busy || !capabilities.canDeleteTasks
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => ContentDialog(
                            title: Text(l10n.deleteTask),
                            content: Text(
                              l10n.deleteTaskConfirmation(task.title),
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
                        setState(() => busy = true);
                        try {
                          await repository.deleteTask(task.sourceId, task.id);
                          changed = true;
                          closeDialog();
                        } on Object catch (_) {
                          setState(() {
                            busy = false;
                            error = l10n.operationFailed;
                          });
                        }
                      },
                child: Text(l10n.delete),
              ),
              Button(
                onPressed: busy
                    ? null
                    : () async {
                        if (hasPendingEdits() &&
                            !await _confirmDiscardTaskChanges(context)) {
                          return;
                        }
                        closeDialog();
                      },
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed:
                    busy ||
                        !capabilities.canUpdateTasks ||
                        title.text.trim().isEmpty ||
                        !validUrl ||
                        provisionalDraft.scheduleIssue != TaskScheduleIssue.none
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          final updatedDraft = currentDraft();
                          if (updatedDraft.scheduleIssue !=
                              TaskScheduleIssue.none) {
                            setState(() {
                              busy = false;
                              error = switch (updatedDraft.scheduleIssue) {
                                TaskScheduleIssue.dueBeforeStart =>
                                  l10n.taskDueBeforeStart,
                                TaskScheduleIssue.mixedTimeModes =>
                                  l10n.taskStartDueTimeModeMismatch,
                                TaskScheduleIssue.none => null,
                              };
                            });
                            return;
                          }
                          final patch = updatedDraft.toPatch(
                            original,
                            capabilities,
                            localTimeZone: localTimeZone,
                          );
                          if (!capabilities.supportsTaskStatus &&
                              completed != task.completed) {
                            patch
                              ..['status'] = completed
                                  ? 'completed'
                                  : 'needsAction'
                              ..['completed'] = completed
                                  ? DateTime.now().toUtc().toIso8601String()
                                  : null;
                          }
                          if (patch.isNotEmpty) {
                            await repository.patchTask(
                              task.sourceId,
                              task.id,
                              TaskPatchInput(patch),
                            );
                          }
                          if (selectedTaskListId != original.taskListId) {
                            await repository.moveTask(
                              TaskMoveInput(
                                sourceTaskListId: original.taskListId,
                                taskId: original.id,
                                destinationTaskListId: selectedTaskListId,
                              ),
                            );
                          }
                          changed = true;
                          closeDialog();
                        } on Object catch (_) {
                          setState(() {
                            busy = false;
                            error = l10n.operationFailed;
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        );
      },
    ),
  );
  title.dispose();
  notes.dispose();
  categories.dispose();
  location.dispose();
  taskUrl.dispose();
  subtaskTitle.dispose();
  if (nextTask case final taskToOpen?) {
    if (!context.mounted) return changed;
    return await showWindowsTaskDetailsDialog(context, ref, taskToOpen) ||
        changed;
  }
  return changed;
}

TaskScheduleItem _scheduleItemForTask(
  TaskEntity task,
  BusyProvider provider,
) => TaskScheduleItem(
  id: task.id,
  accountId: task.accountId,
  provider: provider,
  sourceId: task.taskListId,
  title: task.title,
  completed: task.status == 'completed' || task.status == 'COMPLETED',
  // The dialog reloads the provider-native schedule fields before rendering.
  allDay: true,
);

class _TaskListCombo extends StatelessWidget {
  const _TaskListCombo({
    required this.taskLists,
    required this.selectedTaskListId,
    required this.enabled,
    required this.onChanged,
  });

  final List<TaskListEntity> taskLists;
  final String selectedTaskListId;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => InfoLabel(
    label: AppLocalizations.of(context).list,
    child: ComboBox<String>(
      isExpanded: true,
      value: selectedTaskListId,
      items: [
        for (final taskList in taskLists)
          ComboBoxItem(value: taskList.id, child: Text(taskList.title)),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
    ),
  );
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _timeOnly(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

DateTime? _taskDueDateTime(TaskDetailsDraft draft) {
  return _taskDateTime(draft.dueDate, draft.microsoftDueTime);
}

DateTime? _taskDateTime(String? dateValue, String? timeValue) {
  final date = DateTime.tryParse(dateValue ?? '');
  if (date == null) return null;
  final parts = timeValue?.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    parts == null || parts.isEmpty ? 0 : int.tryParse(parts[0]) ?? 0,
    parts == null || parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0,
  );
}

class _TaskDateTimeField extends StatelessWidget {
  const _TaskDateTimeField({
    required this.label,
    required this.value,
    required this.showTime,
    required this.timeZone,
    required this.enabled,
    required this.onChanged,
    required this.onChooseTimeZone,
  });

  final String label;
  final DateTime? value;
  final bool showTime;
  final String? timeZone;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;
  final Future<void> Function() onChooseTimeZone;

  @override
  Widget build(BuildContext context) => InfoLabel(
    label: label,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DatePicker(
          selected: value,
          onChanged: enabled
              ? (date) => onChanged(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    value?.hour ?? 9,
                    value?.minute ?? 0,
                  ),
                )
              : null,
        ),
        if (showTime && value != null) ...[
          TimePicker(
            selected: value,
            onChanged: enabled
                ? (time) => onChanged(
                    DateTime(
                      value!.year,
                      value!.month,
                      value!.day,
                      time.hour,
                      time.minute,
                    ),
                  )
                : null,
          ),
          if (timeZone != null)
            Button(
              onPressed: enabled ? onChooseTimeZone : null,
              child: Text(timeZone!),
            ),
        ],
        if (value != null)
          IconButton(
            icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.close)),
            onPressed: enabled ? () => onChanged(null) : null,
          ),
      ],
    ),
  );
}

class _StringCombo extends StatelessWidget {
  const _StringCombo({
    required this.label,
    required this.value,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> values;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => InfoLabel(
    label: label,
    child: ComboBox<String>(
      isExpanded: true,
      value: value,
      items: [
        for (final entry in values.entries)
          ComboBoxItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
    ),
  );
}

String _alarmLabel(BuildContext context, IcalTaskAlarm alarm) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final absolute = alarm.absoluteUtc;
  if (absolute != null) {
    final local = absolute.toLocal();
    return l10n.dateTimeDisplay(
      DateFormat.yMMMd(locale).format(local),
      DateFormat.jm(locale).format(local),
    );
  }
  final offset = alarm.relativeOffset;
  if (offset == Duration.zero) {
    return alarm.isRelatedToDue
        ? l10n.reminderAtTaskDue
        : l10n.reminderAtTaskStart;
  }
  if (offset != null && offset.isNegative) {
    final minutes = offset.inMinutes.abs();
    const minutesPerDay = Duration.minutesPerHour * Duration.hoursPerDay;
    if (minutes % minutesPerDay == 0) {
      return l10n.reminderDaysBefore(minutes ~/ minutesPerDay);
    }
    if (minutes % Duration.minutesPerHour == 0) {
      return l10n.reminderHoursBefore(minutes ~/ Duration.minutesPerHour);
    }
    return l10n.reminderMinutesBefore(minutes);
  }
  return l10n.unsupportedReminder;
}

Future<DateTime?> _showAbsoluteReminderDialog(
  BuildContext context, {
  required DateTime initial,
}) {
  var value = initial;
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => ContentDialog(
        title: Text(AppLocalizations.of(context).reminderTime),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DatePicker(
              selected: value,
              onChanged: (date) => setState(() {
                value = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  value.hour,
                  value.minute,
                );
              }),
            ),
            TimePicker(
              selected: value,
              onChanged: (time) => setState(() {
                value = DateTime(
                  value.year,
                  value.month,
                  value.day,
                  time.hour,
                  time.minute,
                );
              }),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  String? result;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => ContentDialog(
        title: Text(title),
        content: TextBox(
          controller: controller,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (value) {
            final normalized = value.trim();
            if (normalized.isEmpty) return;
            result = normalized;
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () {
                    result = controller.text.trim();
                    Navigator.pop(dialogContext);
                  },
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> _confirmDiscardTaskChanges(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ContentDialog(
          title: Text(l10n.discardChanges),
          content: Text(l10n.discardChangesConfirmation),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.discardChangesAction),
            ),
          ],
        ),
      ) ??
      false;
}

String _recurrenceType(String? recurrenceJson) {
  if (recurrenceJson == null || recurrenceJson.isEmpty) return 'none';
  try {
    final decoded = jsonDecode(recurrenceJson);
    if (decoded is Map) {
      final pattern = decoded['pattern'];
      if (pattern is Map) {
        return switch (pattern['type']) {
          'daily' => 'daily',
          'weekly' => 'weekly',
          'absoluteMonthly' => 'absoluteMonthly',
          'absoluteYearly' => 'absoluteYearly',
          _ => 'unsupported',
        };
      }
      final rules = decoded['rules'];
      if (rules is List && rules.isNotEmpty) {
        final rule = rules.first.toString().toUpperCase();
        if (rule.contains('FREQ=DAILY')) return 'daily';
        if (rule.contains('FREQ=WEEKLY')) return 'weekly';
        if (rule.contains('FREQ=MONTHLY')) return 'absoluteMonthly';
        if (rule.contains('FREQ=YEARLY')) return 'absoluteYearly';
      }
    }
  } on FormatException {
    return 'unsupported';
  }
  return 'unsupported';
}

String? _recurrenceJsonFor(
  String type, {
  required DateTime? due,
  required DateTime? start,
  required bool dav,
}) {
  if (type == 'none') return null;
  final recurrenceStart = start ?? due ?? DateTime.now();
  if (dav) {
    final frequency = switch (type) {
      'daily' => 'DAILY',
      'weekly' => 'WEEKLY',
      'absoluteMonthly' => 'MONTHLY',
      'absoluteYearly' => 'YEARLY',
      _ => 'DAILY',
    };
    final parts = <String>['FREQ=$frequency', 'INTERVAL=1'];
    if (type == 'weekly') {
      parts.add('BYDAY=${_weekdayCode(recurrenceStart.weekday)}');
    } else if (type == 'absoluteMonthly') {
      parts.add('BYMONTHDAY=${recurrenceStart.day}');
    } else if (type == 'absoluteYearly') {
      parts
        ..add('BYMONTH=${recurrenceStart.month}')
        ..add('BYMONTHDAY=${recurrenceStart.day}');
    }
    return jsonEncode({
      'rules': [parts.join(';')],
      'dates': const <String>[],
      'excludedDates': const <String>[],
    });
  }
  final pattern = switch (type) {
    'daily' => {'type': 'daily', 'interval': 1},
    'weekly' => {
      'type': 'weekly',
      'interval': 1,
      'daysOfWeek': [_weekdayName(recurrenceStart.weekday)],
      'firstDayOfWeek': 'monday',
    },
    'absoluteMonthly' => {
      'type': 'absoluteMonthly',
      'interval': 1,
      'dayOfMonth': recurrenceStart.day,
    },
    'absoluteYearly' => {
      'type': 'absoluteYearly',
      'interval': 1,
      'dayOfMonth': recurrenceStart.day,
      'month': recurrenceStart.month,
    },
    _ => {'type': 'daily', 'interval': 1},
  };
  return jsonEncode({
    'pattern': pattern,
    'range': {'type': 'noEnd', 'startDate': _dateOnly(recurrenceStart)},
  });
}

String _weekdayCode(int weekday) => switch (weekday) {
  DateTime.monday => 'MO',
  DateTime.tuesday => 'TU',
  DateTime.wednesday => 'WE',
  DateTime.thursday => 'TH',
  DateTime.friday => 'FR',
  DateTime.saturday => 'SA',
  _ => 'SU',
};

String _weekdayName(int weekday) => switch (weekday) {
  DateTime.monday => 'monday',
  DateTime.tuesday => 'tuesday',
  DateTime.wednesday => 'wednesday',
  DateTime.thursday => 'thursday',
  DateTime.friday => 'friday',
  DateTime.saturday => 'saturday',
  _ => 'sunday',
};

String _priorityLabel(AppLocalizations l10n, int priority) => priority == 0
    ? l10n.priorityNone
    : priority <= 4
    ? l10n.priorityHighValue(priority)
    : priority == 5
    ? l10n.priorityMediumValue(priority)
    : l10n.priorityLowValue(priority);

List<String> _categories(String value) => value
    .split(',')
    .map((category) => category.trim())
    .where((category) => category.isNotEmpty)
    .toSet()
    .toList(growable: false);

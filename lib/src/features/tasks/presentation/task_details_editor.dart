import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../data/tasks_repository.dart';
import 'desktop_date_time_fields.dart';
import 'ical_task_fields_editor.dart';
import 'task_details_draft.dart';

class TaskDetailsEditor extends StatefulWidget {
  const TaskDetailsEditor({
    super.key,
    required this.task,
    required this.taskLists,
    required this.capabilities,
    required this.localTimeZone,
    required this.accountLabel,
    required this.onRefresh,
    required this.onSave,
    required this.onCreateSubtask,
    required this.onMoveToTop,
    required this.onDelete,
    required this.onCancel,
    this.hierarchy = const TaskHierarchySnapshot(parent: null, subtasks: []),
    this.onHierarchyTaskSelected,
    this.onSubtaskCompletionChanged,
    this.onChecklistSubtaskRenamed,
    this.onChecklistSubtaskDeleted,
    this.onDuplicate,
    this.onExport,
    this.onSaved,
    this.onTaskSwitchCancelled,
    this.onDirtyChanged,
    this.onDraftChanged,
    this.categorySuggestions = const [],
    this.initialDraft,
    this.editorTitle,
    this.saveLabel,
    this.accountIds = const [],
    this.selectedAccountId,
    this.accountLabelFor,
    this.accountSecondaryLabelFor,
    this.onAccountSelected,
    this.allowTaskListSelection,
    this.showAdvancedActions = true,
    this.showDeleteAction = true,
    this.confirmTaskSwitch = true,
    this.useNativeDatePicker = false,
    this.dialogBarrierColor,
    this.headerBarService,
    this.canSaveDraft,
    this.isCreate = false,
  });

  final TaskEntity task;
  final List<TaskListEntity> taskLists;
  final TaskCollectionCapabilities capabilities;
  final String localTimeZone;
  final String? accountLabel;
  final VoidCallback onRefresh;
  final Future<void> Function(
    TaskDetailsDraft draft,
    Map<String, Object?> patch,
  )
  onSave;
  final Future<void> Function(String title) onCreateSubtask;
  final VoidCallback onMoveToTop;
  final Future<void> Function() onDelete;
  final VoidCallback onCancel;
  final TaskHierarchySnapshot hierarchy;
  final Future<void> Function(TaskEntity task)? onHierarchyTaskSelected;
  final Future<void> Function(TaskSubtaskEntity subtask, bool completed)?
  onSubtaskCompletionChanged;
  final Future<void> Function(TaskSubtaskEntity subtask, String title)?
  onChecklistSubtaskRenamed;
  final Future<void> Function(TaskSubtaskEntity subtask)?
  onChecklistSubtaskDeleted;
  final Future<void> Function()? onDuplicate;
  final Future<void> Function()? onExport;
  final VoidCallback? onSaved;
  final ValueChanged<TaskEntity>? onTaskSwitchCancelled;
  final ValueChanged<bool>? onDirtyChanged;
  final ValueChanged<TaskDetailsDraft>? onDraftChanged;
  final List<String> categorySuggestions;
  final TaskDetailsDraft? initialDraft;
  final String? editorTitle;
  final String? saveLabel;
  final List<String> accountIds;
  final String? selectedAccountId;
  final String Function(String accountId)? accountLabelFor;
  final String? Function(String accountId)? accountSecondaryLabelFor;
  final ValueChanged<String>? onAccountSelected;
  final bool? allowTaskListSelection;
  final bool showAdvancedActions;
  final bool showDeleteAction;
  final bool confirmTaskSwitch;
  final bool useNativeDatePicker;
  final Color? dialogBarrierColor;
  final LinuxHeaderBarService? headerBarService;
  final bool Function(TaskDetailsDraft draft)? canSaveDraft;
  final bool isCreate;

  @override
  State<TaskDetailsEditor> createState() => _TaskDetailsEditorState();
}

class _TaskDetailsEditorState extends State<TaskDetailsEditor> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _shortcutFocusNode = FocusNode(debugLabel: 'Task editor shortcuts');
  final _invalidTimeFields = <_TaskTimeField>{};

  TaskDetailsDraft? _draft;
  TaskDetailsDraft? _cleanDraftBaseline;
  String? _loadedTaskKey;
  late TaskEntity _editingTask;
  var _saving = false;
  var _addingCategory = false;
  var _confirmingTaskSwitch = false;
  var _confirmingDelete = false;
  var _creatingSubtask = false;

  @override
  void initState() {
    super.initState();
    _editingTask = widget.task;
    _loadDraft(widget.task, force: true);
  }

  @override
  void didUpdateWidget(covariant TaskDetailsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _taskKey(widget.task);
    final sameKey = _loadedTaskKey == nextKey;
    final hasChanges = _hasEditorChanges(_draft);

    if (!sameKey) {
      if (hasChanges && widget.confirmTaskSwitch) {
        unawaited(_confirmTaskSelectionChange(widget.task));
      } else {
        _loadDraft(widget.task, force: true);
      }
      return;
    }

    if (!hasChanges && _taskChanged(_editingTask, widget.task)) {
      _loadDraft(widget.task, force: true);
    }
  }

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft =
        _draft ?? TaskDetailsDraft.fromTask(_editingTask, widget.localTimeZone);
    final l10n = context.l10n;
    final hasChanges = _hasEditorChanges(draft);
    final scheduledAllDay = _isScheduledAllDay(draft);
    final scheduleIssue = draft.scheduleIssue;
    final canSave =
        _canWrite &&
        draft.title.trim().isNotEmpty &&
        hasChanges &&
        !_saving &&
        scheduleIssue == TaskScheduleIssue.none &&
        draft.hasValidTaskUrl &&
        _timeFieldsAreValid(draft, scheduledAllDay) &&
        (widget.canSaveDraft?.call(draft) ?? true);
    final currentList = _listTitle(draft.taskListId);
    final listValue = [
      currentList,
      widget.accountLabel,
    ].where((value) => value != null && value.isNotEmpty).join(' · ');

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (canSave) {
            unawaited(_save());
          }
        },
      },
      child: Focus(
        autofocus: true,
        focusNode: _shortcutFocusNode,
        onKeyEvent: _handleEditorKeyEvent,
        child: Column(
          children: [
            _TaskDetailsHeader(
              title: widget.editorTitle ?? l10n.editTask,
              cancelLabel: l10n.cancel,
              saveLabel: widget.saveLabel ?? l10n.save,
              saving: _saving,
              canSave: canSave,
              onCancel: _cancel,
              onSave: _save,
            ),
            Expanded(
              child: BusyMaxEditorScrollBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BusyMaxGroupedList(
                      filled: true,
                      children: [
                        YaruListTile.square(
                          title: TextField(
                            controller: _titleController,
                            enabled: _canWrite,
                            decoration: busyMaxGroupedTextFieldDecoration(
                              context,
                              labelText: l10n.title,
                            ),
                            onChanged: (value) =>
                                _updateDraft(draft.copyWith(title: value)),
                          ),
                        ),
                      ],
                    ),
                    if (_hasAccountSelector)
                      BusyMaxGroupedList(
                        filled: true,
                        children: [_accountRow()],
                      ),
                    BusyMaxGroupedList(
                      filled: true,
                      children: [_listRow(draft, listValue)],
                    ),
                    if (widget.capabilities.supportsDueDate)
                      BusyMaxGroupedList(
                        title: l10n.dueGroup,
                        filled: true,
                        children: [
                          if (_supportsScheduledTimeMode)
                            IgnorePointer(
                              ignoring: !_canWrite,
                              child: BusyMaxTimeModeRow(
                                allDay: scheduledAllDay,
                                onChanged: (value) =>
                                    _setScheduledAllDay(draft, value),
                              ),
                            ),
                          DesktopDateValueRow(
                            label: l10n.dueDate,
                            date: draft.dueDate,
                            enabled: _canWrite,
                            onChanged: (value) =>
                                _updateDraft(draft.copyWith(dueDate: value)),
                            useNativePicker: widget.useNativeDatePicker,
                            onClear: () => unawaited(
                              _clearScheduledDate(draft, due: true),
                            ),
                          ),
                          if (widget.capabilities.supportsDueTime &&
                              !scheduledAllDay)
                            DesktopTimeValueRow(
                              label: l10n.dueTime,
                              time: draft.microsoftDueTime,
                              enabled: _canWrite,
                              onChanged: (value) => _updateDraft(
                                draft.copyWith(microsoftDueTime: value),
                              ),
                              timeZone: draft.microsoftDueTimeZone,
                              onTimeZoneChanged: (value) => _updateDraft(
                                draft.copyWith(microsoftDueTimeZone: value),
                              ),
                              onValidityChanged: (valid) =>
                                  _setTimeFieldValidity(
                                    _TaskTimeField.due,
                                    valid,
                                  ),
                              useNativePicker: widget.useNativeDatePicker,
                            ),
                        ],
                      ),
                    if (widget.capabilities.supportsStartDateTime)
                      BusyMaxGroupedList(
                        title: l10n.startGroup,
                        filled: true,
                        children: _startRows(draft, scheduledAllDay),
                      ),
                    if (scheduleIssue != TaskScheduleIssue.none)
                      _taskScheduleError(scheduleIssue),
                    if (_supportsIcalFields)
                      IcalTaskFieldsEditor(
                        draft: draft,
                        capabilities: widget.capabilities,
                        enabled: _canWrite,
                        useNativeDatePicker: widget.useNativeDatePicker,
                        dialogBarrierColor: widget.dialogBarrierColor,
                        headerBarService: widget.headerBarService,
                        onChanged: _updateDraft,
                      ),
                    if (widget.capabilities.supportsReminderDateTime &&
                        !widget.capabilities.supportsMultipleReminders)
                      BusyMaxGroupedList(
                        title: l10n.reminderGroup,
                        filled: true,
                        children: _reminderRows(draft),
                      ),
                    if (widget.capabilities.supportsRecurrence &&
                        !widget.capabilities.supportsAdvancedRecurrence)
                      BusyMaxGroupedList(
                        filled: true,
                        children: [_repeatRow(draft)],
                      ),
                    if ((widget.capabilities.supportsImportance &&
                            !widget.capabilities.supportsIcalPriority) ||
                        widget.capabilities.supportsCategories)
                      BusyMaxGroupedList(
                        title: l10n.organizationSection,
                        filled: true,
                        children: [
                          if (widget.capabilities.supportsImportance &&
                              !widget.capabilities.supportsIcalPriority)
                            _importanceRow(draft),
                          if (widget.capabilities.supportsCategories)
                            IgnorePointer(
                              ignoring: !_canWrite,
                              child: _categoriesRow(draft),
                            ),
                        ],
                      ),
                    BusyMaxGroupedList(
                      filled: true,
                      children: [
                        YaruListTile.square(
                          title: TextField(
                            controller: _notesController,
                            enabled: _canWrite,
                            minLines: 3,
                            maxLines: 5,
                            decoration: busyMaxGroupedTextFieldDecoration(
                              context,
                              labelText: l10n.notes,
                              alignLabelWithHint: true,
                            ),
                            onChanged: (value) =>
                                _updateDraft(draft.copyWith(notes: value)),
                          ),
                        ),
                      ],
                    ),
                    if (widget.showAdvancedActions &&
                        widget.capabilities.supportsTaskHierarchy)
                      _subtasksSection(),
                    if (widget.showAdvancedActions &&
                        (widget.capabilities.supportsTaskReparenting ||
                            widget.capabilities.supportsDuplicate ||
                            widget.capabilities.supportsNativeExport))
                      BusyMaxGroupedList(
                        title: l10n.advancedSection,
                        filled: true,
                        children: [
                          if (widget.capabilities.supportsTaskReparenting)
                            BusyMaxActionRow(
                              title: l10n.moveToTop,
                              leading: const Icon(Icons.vertical_align_top),
                              enabled: widget.capabilities.canUpdateTasks,
                              onTap: widget.capabilities.canUpdateTasks
                                  ? widget.onMoveToTop
                                  : null,
                            ),
                          if (widget.capabilities.supportsDuplicate)
                            BusyMaxActionRow(
                              title: l10n.duplicateTask,
                              leading: const Icon(Icons.copy_outlined),
                              enabled:
                                  widget.capabilities.canCreateTasks &&
                                  widget.onDuplicate != null,
                              onTap:
                                  widget.capabilities.canCreateTasks &&
                                      widget.onDuplicate != null
                                  ? () => unawaited(widget.onDuplicate!())
                                  : null,
                            ),
                          if (widget.capabilities.supportsNativeExport)
                            BusyMaxActionRow(
                              title: l10n.export,
                              leading: const Icon(Icons.file_download_outlined),
                              enabled: widget.onExport != null,
                              onTap: widget.onExport == null
                                  ? null
                                  : () => unawaited(widget.onExport!()),
                            ),
                        ],
                      ),
                    if (widget.showDeleteAction &&
                        widget.capabilities.canDeleteTasks) ...[
                      const SizedBox(height: BusyMaxSpacing.md),
                      BusyMaxGroupedList(
                        filled: true,
                        children: [
                          BusyMaxActionRow(
                            title: l10n.deleteTask,
                            titleWidget: Center(
                              child: Text(
                                l10n.deleteTask,
                                style: _taskEditorProminentActionStyle(
                                  context,
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            destructive: true,
                            onTap: _deleteTask,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: BusyMaxSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        !widget.showDeleteAction ||
        !widget.capabilities.canDeleteTasks ||
        _isEditableTextFocused()) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
        unawaited(_deleteTask());
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isEditableTextFocused() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool get _hasAccountSelector {
    return widget.selectedAccountId != null &&
        widget.accountIds.isNotEmpty &&
        widget.accountLabelFor != null &&
        widget.onAccountSelected != null;
  }

  bool get _canWrite => widget.isCreate
      ? widget.capabilities.canCreateTasks
      : widget.capabilities.canUpdateTasks;

  bool get _supportsIcalFields =>
      widget.capabilities.supportsIcalPriority ||
      widget.capabilities.supportsPercentComplete ||
      widget.capabilities.supportsTaskStatus ||
      widget.capabilities.supportsCompletedDateTime ||
      widget.capabilities.supportsLocation ||
      widget.capabilities.supportsUrl ||
      widget.capabilities.supportsClassification ||
      widget.capabilities.supportsMultipleReminders ||
      widget.capabilities.supportsAdvancedRecurrence ||
      widget.capabilities.supportsPinning ||
      widget.capabilities.supportsSubtaskVisibility;

  Widget _accountRow() {
    final l10n = context.l10n;
    final labelFor = widget.accountLabelFor!;
    final secondaryLabelFor = widget.accountSecondaryLabelFor;
    return BusyMaxComboRow<String>(
      title: l10n.account,
      leading: const Icon(YaruIcons.user),
      subtitle: secondaryLabelFor?.call(widget.selectedAccountId!),
      values: widget.accountIds,
      selected: widget.selectedAccountId!,
      labelFor: labelFor,
      onSelected: widget.onAccountSelected!,
    );
  }

  Widget _listRow(TaskDetailsDraft draft, String listValue) {
    final l10n = context.l10n;
    if (widget.taskLists.isEmpty) {
      return BusyMaxActionRow(
        title: l10n.list,
        leading: const Icon(YaruIcons.task_list),
        subtitle: listValue.isEmpty ? null : listValue,
        enabled: false,
      );
    }
    final canSelectList =
        widget.allowTaskListSelection ??
        widget.capabilities.supportsCrossListMove;
    if (!canSelectList) {
      return BusyMaxActionRow(
        title: l10n.list,
        leading: const Icon(YaruIcons.task_list),
        subtitle: listValue.isEmpty ? null : listValue,
        enabled: false,
        tooltip: widget.capabilities.supportsCrossListMove
            ? null
            : l10n.microsoftMoveUnsupported,
      );
    }
    return BusyMaxComboRow<String>(
      title: l10n.list,
      leading: const Icon(YaruIcons.task_list),
      subtitle: widget.accountLabel,
      values: [for (final list in widget.taskLists) list.id],
      selected: draft.taskListId,
      enabled: widget.isCreate || _canWrite,
      labelFor: (value) => _listTitle(value) ?? l10n.noneValue,
      onSelected: (value) => _updateDraft(draft.copyWith(taskListId: value)),
    );
  }

  List<Widget> _startRows(TaskDetailsDraft draft, bool scheduledAllDay) {
    final l10n = context.l10n;
    return [
      DesktopDateValueRow(
        label: l10n.startDate,
        date: draft.microsoftStartDate,
        enabled: _canWrite,
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftStartDate: value)),
        useNativePicker: widget.useNativeDatePicker,
        onClear: () => unawaited(_clearScheduledDate(draft, due: false)),
      ),
      if (!scheduledAllDay)
        DesktopTimeValueRow(
          label: l10n.startTime,
          time: draft.microsoftStartTime,
          enabled: _canWrite,
          onChanged: (value) =>
              _updateDraft(draft.copyWith(microsoftStartTime: value)),
          timeZone: draft.microsoftStartTimeZone,
          onTimeZoneChanged: (value) =>
              _updateDraft(draft.copyWith(microsoftStartTimeZone: value)),
          onValidityChanged: (valid) =>
              _setTimeFieldValidity(_TaskTimeField.start, valid),
          useNativePicker: widget.useNativeDatePicker,
        ),
    ];
  }

  Future<void> _clearScheduledDate(
    TaskDetailsDraft draft, {
    required bool due,
  }) async {
    final relatedIndexes = <int>[];
    for (var index = 0; index < draft.alarms.length; index += 1) {
      final alarm = draft.alarms[index];
      if (alarm.relativeOffset != null && alarm.isRelatedToDue == due) {
        relatedIndexes.add(index);
      }
    }

    var alarms = draft.alarms;
    if (relatedIndexes.isNotEmpty) {
      final reference = draft.reminderReferenceUtc(
        due: due,
        localTimeZone: widget.localTimeZone,
      );
      final choice = await showBusyMaxModalDialog<_RelatedReminderChoice>(
        context,
        barrierColor: widget.dialogBarrierColor,
        headerBarService: widget.headerBarService,
        barrierDismissible: false,
        builder: (dialogContext) => BusyMaxDialogShell(
          title: dialogContext.l10n.relatedRemindersTitle,
          actions: [
            BusyMaxPushButton.standard(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.l10n.cancel),
            ),
            BusyMaxPushButton.destructive(
              context: dialogContext,
              onPressed: () =>
                  Navigator.pop(dialogContext, _RelatedReminderChoice.discard),
              child: Text(dialogContext.l10n.discardRelatedReminders),
            ),
            BusyMaxPushButton.suggested(
              onPressed: reference == null
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      _RelatedReminderChoice.keepAbsolute,
                    ),
              child: Text(dialogContext.l10n.keepRelatedReminders),
            ),
          ],
          children: [
            Text(
              dialogContext.l10n.relatedRemindersDescription(
                relatedIndexes.length,
              ),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      final related = relatedIndexes.toSet();
      alarms = switch (choice) {
        _RelatedReminderChoice.discard => [
          for (var index = 0; index < draft.alarms.length; index += 1)
            if (!related.contains(index)) draft.alarms[index],
        ],
        _RelatedReminderChoice.keepAbsolute => [
          for (var index = 0; index < draft.alarms.length; index += 1)
            if (related.contains(index))
              draft.alarms[index].withAbsoluteTrigger(
                reference!.add(draft.alarms[index].relativeOffset!),
              )
            else
              draft.alarms[index],
        ],
      };
    }

    final noOtherDate = due
        ? draft.microsoftStartDate == null
        : draft.dueDate == null;
    _updateDraft(
      due
          ? draft.copyWith(
              dueDate: null,
              microsoftDueTime: widget.capabilities.supportsDueTime
                  ? null
                  : draft.microsoftDueTime,
              recurrenceJson: noOtherDate ? null : draft.recurrenceJson,
              alarms: alarms,
            )
          : draft.copyWith(
              microsoftStartDate: null,
              microsoftStartTime: null,
              recurrenceJson: noOtherDate ? null : draft.recurrenceJson,
              alarms: alarms,
            ),
    );
  }

  Widget _taskScheduleError(TaskScheduleIssue issue) {
    final message = switch (issue) {
      TaskScheduleIssue.dueBeforeStart => context.l10n.taskDueBeforeStart,
      TaskScheduleIssue.mixedTimeModes =>
        context.l10n.taskStartDueTimeModeMismatch,
      TaskScheduleIssue.none => '',
    };
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      key: const ValueKey('task-schedule-error'),
      padding: const EdgeInsets.fromLTRB(
        BusyMaxSpacing.lg,
        BusyMaxSpacing.xs,
        BusyMaxSpacing.lg,
        BusyMaxSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: color),
          const SizedBox(width: BusyMaxSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  bool get _supportsScheduledTimeMode {
    return widget.capabilities.supportsDueTime ||
        widget.capabilities.supportsStartDateTime;
  }

  bool _isScheduledAllDay(TaskDetailsDraft draft) {
    final hasDueTime =
        widget.capabilities.supportsDueTime && draft.microsoftDueTime != null;
    final hasStartTime =
        widget.capabilities.supportsStartDateTime &&
        draft.microsoftStartTime != null;
    return !hasDueTime && !hasStartTime;
  }

  void _setScheduledAllDay(TaskDetailsDraft draft, bool allDay) {
    if (allDay) {
      _invalidTimeFields
        ..remove(_TaskTimeField.due)
        ..remove(_TaskTimeField.start);
      _updateDraft(
        draft.copyWith(
          microsoftDueTime: widget.capabilities.supportsDueTime
              ? null
              : draft.microsoftDueTime,
          microsoftStartTime: widget.capabilities.supportsStartDateTime
              ? null
              : draft.microsoftStartTime,
        ),
      );
      return;
    }
    final hasDueDate = draft.dueDate != null && draft.dueDate!.isNotEmpty;
    final hasStartDate =
        draft.microsoftStartDate != null &&
        draft.microsoftStartDate!.isNotEmpty;
    final shouldDefaultDueTime =
        widget.capabilities.supportsDueTime && (hasDueDate || !hasStartDate);
    _updateDraft(
      draft.copyWith(
        dueDate: shouldDefaultDueTime
            ? draft.dueDate ?? encodeGoogleDateOnly(DateTime.now())
            : draft.dueDate,
        microsoftDueTime: shouldDefaultDueTime
            ? draft.microsoftDueTime ?? '09:00'
            : draft.microsoftDueTime,
        microsoftStartTime:
            widget.capabilities.supportsStartDateTime && hasStartDate
            ? draft.microsoftStartTime ?? '09:00'
            : draft.microsoftStartTime,
      ),
    );
  }

  Widget _repeatRow(TaskDetailsDraft draft) {
    final l10n = context.l10n;
    final type = _recurrenceType(draft.recurrenceJson);
    final options = _repeatOptions(context);
    return BusyMaxComboRow<String>(
      title: l10n.repeat,
      leading: const Icon(YaruIcons.repeat),
      values: options.keys.toList(),
      selected: type,
      enabled: _canWrite,
      labelFor: (value) => options[value] ?? l10n.repeatNone,
      onSelected: (value) => _updateDraft(
        draft.copyWith(
          recurrenceJson: _recurrenceJsonFor(
            value,
            draft,
            dav: _editingTask.davCollectionId != null,
          ),
        ),
      ),
    );
  }

  Widget _importanceRow(TaskDetailsDraft draft) {
    final l10n = context.l10n;
    final labels = {
      'low': l10n.importanceLow,
      'normal': l10n.importanceNormal,
      'high': l10n.importanceHigh,
    };
    return BusyMaxComboRow<String>(
      title: l10n.importance,
      leading: const Icon(YaruIcons.task_important),
      values: labels.keys.toList(),
      selected: draft.importance,
      enabled: _canWrite,
      labelFor: (value) => labels[value] ?? l10n.importanceNormal,
      onSelected: (value) => _updateDraft(draft.copyWith(importance: value)),
    );
  }

  Widget _categoriesRow(TaskDetailsDraft draft) {
    final l10n = context.l10n;
    return BusyMaxCategoryEditorRow(
      title: l10n.categories,
      addLabel: l10n.addCategory,
      categories: draft.categories,
      suggestions: widget.categorySuggestions,
      adding: _addingCategory,
      inputKey: const Key('task-category-input'),
      onAddPressed: () {
        setState(() {
          _addingCategory = true;
        });
      },
      onSubmitted: (value) => _addCategory(draft, value),
      onCancelAdding: () {
        setState(() {
          _addingCategory = false;
        });
      },
      onDeleted: (category) => _removeCategory(draft, category),
    );
  }

  void _addCategory(TaskDetailsDraft draft, String value) {
    final currentDraft = _draft ?? draft;
    final category = value.trim();
    if (category.isEmpty ||
        currentDraft.categories.any(
          (existing) => existing.toLowerCase() == category.toLowerCase(),
        )) {
      return;
    }
    setState(() {
      _addingCategory = false;
    });
    _updateDraft(
      currentDraft.copyWith(categories: [...currentDraft.categories, category]),
    );
  }

  void _removeCategory(TaskDetailsDraft draft, String category) {
    final currentDraft = _draft ?? draft;
    _updateDraft(
      currentDraft.copyWith(
        categories: [
          for (final value in currentDraft.categories)
            if (value != category) value,
        ],
      ),
    );
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null ||
        _saving ||
        !_canWrite ||
        draft.scheduleIssue != TaskScheduleIssue.none ||
        !draft.hasValidTaskUrl ||
        !_timeFieldsAreValid(draft, _isScheduledAllDay(draft))) {
      return;
    }
    final patch = draft.toPatch(
      _editingTask,
      widget.capabilities,
      localTimeZone: widget.localTimeZone,
    );
    setState(() {
      _saving = true;
    });
    try {
      await widget.onSave(draft, patch);
      if (!mounted) {
        return;
      }
      _cleanDraftBaseline = draft;
      widget.onDirtyChanged?.call(false);
      widget.onSaved?.call();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    final draft = _draft;
    final hasChanges = _hasEditorChanges(draft);
    if (hasChanges) {
      final discard = await showBusyMaxConfirm(
        context,
        title: context.l10n.discardChanges,
        message: context.l10n.discardChangesConfirmation,
        confirmLabel: context.l10n.discardChangesAction,
        destructive: true,
        barrierColor: widget.dialogBarrierColor,
        headerBarService: widget.headerBarService,
      );
      if (!discard || !mounted) {
        return;
      }
    }
    _loadDraft(_editingTask, force: true);
    widget.onCancel();
  }

  Future<void> _confirmTaskSelectionChange(TaskEntity nextTask) async {
    if (_confirmingTaskSwitch) {
      return;
    }
    _confirmingTaskSwitch = true;
    final previousTask = _editingTask;
    final discard = await showBusyMaxConfirm(
      context,
      title: context.l10n.discardChanges,
      message: context.l10n.discardChangesConfirmation,
      confirmLabel: context.l10n.discardChangesAction,
      destructive: true,
      barrierColor: widget.dialogBarrierColor,
      headerBarService: widget.headerBarService,
    );
    if (!mounted) {
      return;
    }
    _confirmingTaskSwitch = false;
    if (discard) {
      _loadDraft(nextTask, force: true);
    } else {
      widget.onTaskSwitchCancelled?.call(previousTask);
    }
  }

  Widget _subtasksSection() {
    final l10n = context.l10n;
    final hierarchy = widget.hierarchy;
    return BusyMaxGroupedList(
      title: l10n.subtasks,
      filled: true,
      children: [
        if (hierarchy.parent case final parent?)
          BusyMaxActionRow(
            key: ValueKey('task-parent-${parent.id}'),
            title: parent.title,
            subtitle: l10n.parent,
            leading: const Icon(Icons.account_tree_outlined),
            trailing: Icon(
              BusyMaxGlyphs.chevronForwardFor(Directionality.of(context)),
            ),
            enabled: widget.onHierarchyTaskSelected != null,
            onTap: widget.onHierarchyTaskSelected == null
                ? null
                : () => unawaited(widget.onHierarchyTaskSelected!(parent)),
          ),
        for (final subtask in hierarchy.subtasks) _subtaskRow(subtask),
        BusyMaxActionRow(
          key: const ValueKey('create-subtask-action'),
          title: l10n.createSubtask,
          leading: Icon(
            BusyMaxGlyphs.subdirectoryFor(Directionality.of(context)),
          ),
          enabled: widget.capabilities.canCreateTasks && !_creatingSubtask,
          onTap: widget.capabilities.canCreateTasks && !_creatingSubtask
              ? _createSubtask
              : null,
        ),
      ],
    );
  }

  Widget _subtaskRow(TaskSubtaskEntity subtask) {
    final task = subtask.task;
    final canToggle =
        widget.capabilities.canUpdateTasks &&
        widget.onSubtaskCompletionChanged != null;
    final title = Text(
      subtask.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        decoration: subtask.completed ? TextDecoration.lineThrough : null,
        color: subtask.completed
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
    return BusyMaxActionRow(
      key: ValueKey('subtask-${subtask.kind.name}-${subtask.id}'),
      title: subtask.title,
      titleWidget: title,
      leading: Icon(BusyMaxGlyphs.subdirectoryFor(Directionality.of(context))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          YaruCheckbox(
            value: subtask.completed,
            onChanged: !canToggle
                ? null
                : (value) => unawaited(
                    widget.onSubtaskCompletionChanged!(subtask, value ?? false),
                  ),
          ),
          if (task != null)
            Icon(BusyMaxGlyphs.chevronForwardFor(Directionality.of(context)))
          else if (widget.onChecklistSubtaskRenamed != null ||
              widget.onChecklistSubtaskDeleted != null)
            BusyMaxMenuButton<_ChecklistSubtaskAction>(
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onSelected: (action) =>
                  unawaited(_handleChecklistSubtaskAction(subtask, action)),
              entries: [
                if (widget.onChecklistSubtaskRenamed != null)
                  BusyMaxMenuEntry(
                    value: _ChecklistSubtaskAction.rename,
                    label: context.l10n.rename,
                    icon: Icons.edit_outlined,
                  ),
                if (widget.onChecklistSubtaskDeleted != null)
                  BusyMaxMenuEntry(
                    value: _ChecklistSubtaskAction.delete,
                    label: context.l10n.delete,
                    icon: YaruIcons.trash,
                    destructive: true,
                  ),
              ],
            ),
        ],
      ),
      enabled: task == null || widget.onHierarchyTaskSelected != null,
      onTap: task == null || widget.onHierarchyTaskSelected == null
          ? null
          : () => unawaited(widget.onHierarchyTaskSelected!(task)),
    );
  }

  Future<void> _handleChecklistSubtaskAction(
    TaskSubtaskEntity subtask,
    _ChecklistSubtaskAction action,
  ) async {
    switch (action) {
      case _ChecklistSubtaskAction.rename:
        final title = await showBusyMaxTextPrompt(
          context,
          title: context.l10n.rename,
          label: context.l10n.title,
          actionLabel: context.l10n.save,
          initialValue: subtask.title,
          barrierColor: widget.dialogBarrierColor,
          headerBarService: widget.headerBarService,
        );
        final normalized = title?.trim();
        if (normalized == null ||
            normalized.isEmpty ||
            normalized == subtask.title) {
          return;
        }
        await widget.onChecklistSubtaskRenamed?.call(subtask, normalized);
      case _ChecklistSubtaskAction.delete:
        final confirmed = await showBusyMaxConfirm(
          context,
          title: context.l10n.delete,
          message: context.l10n.deleteTaskConfirmation(subtask.title),
          confirmLabel: context.l10n.delete,
          destructive: true,
          barrierColor: widget.dialogBarrierColor,
          headerBarService: widget.headerBarService,
        );
        if (confirmed) {
          await widget.onChecklistSubtaskDeleted?.call(subtask);
        }
    }
  }

  Future<void> _createSubtask() async {
    if (!widget.capabilities.canCreateTasks || _creatingSubtask) return;
    final title = await showBusyMaxTextPrompt(
      context,
      title: context.l10n.newSubtask,
      label: context.l10n.title,
      actionLabel: context.l10n.create,
      barrierColor: widget.dialogBarrierColor,
      headerBarService: widget.headerBarService,
    );
    if (title == null || title.trim().isEmpty) {
      return;
    }
    setState(() => _creatingSubtask = true);
    try {
      await widget.onCreateSubtask(title.trim());
    } finally {
      if (mounted) setState(() => _creatingSubtask = false);
    }
  }

  Future<void> _deleteTask() async {
    if (_confirmingDelete || !widget.capabilities.canDeleteTasks) {
      return;
    }
    _confirmingDelete = true;
    try {
      final confirmed = await showBusyMaxConfirm(
        context,
        title: context.l10n.deleteTask,
        message: context.l10n.deleteTaskConfirmation(_editingTask.title),
        confirmLabel: context.l10n.delete,
        destructive: true,
        barrierColor: widget.dialogBarrierColor,
        headerBarService: widget.headerBarService,
      );
      if (confirmed) {
        await widget.onDelete();
      }
    } finally {
      _confirmingDelete = false;
    }
  }

  void _loadDraft(TaskEntity task, {required bool force}) {
    final taskKey = _taskKey(task);
    if (!force && _loadedTaskKey == taskKey) {
      return;
    }
    final draft =
        widget.initialDraft ??
        TaskDetailsDraft.fromTask(task, widget.localTimeZone);
    _editingTask = task;
    _loadedTaskKey = taskKey;
    _invalidTimeFields.clear();
    _draft = draft;
    _cleanDraftBaseline = draft;
    _titleController.text = draft.title;
    _notesController.text = draft.notes;
    widget.onDirtyChanged?.call(false);
  }

  void _updateDraft(TaskDetailsDraft draft) {
    setState(() {
      _draft = draft;
    });
    widget.onDraftChanged?.call(draft);
    widget.onDirtyChanged?.call(_hasEditorChanges(draft));
  }

  void _setTimeFieldValidity(_TaskTimeField field, bool valid) {
    final changed = valid
        ? _invalidTimeFields.remove(field)
        : _invalidTimeFields.add(field);
    if (changed) {
      setState(() {});
      widget.onDirtyChanged?.call(_hasEditorChanges(_draft));
    }
  }

  bool _hasEditorChanges(TaskDetailsDraft? draft) {
    if (draft == null) {
      return false;
    }
    return _hasDraftChanges(draft) ||
        !_timeFieldsAreValid(draft, _isScheduledAllDay(draft));
  }

  bool _timeFieldsAreValid(TaskDetailsDraft draft, bool scheduledAllDay) {
    if (!scheduledAllDay &&
        widget.capabilities.supportsDueTime &&
        _invalidTimeFields.contains(_TaskTimeField.due)) {
      return false;
    }
    if (!scheduledAllDay &&
        widget.capabilities.supportsStartDateTime &&
        _invalidTimeFields.contains(_TaskTimeField.start)) {
      return false;
    }
    if (draft.microsoftReminderEnabled &&
        _invalidTimeFields.contains(_TaskTimeField.reminder)) {
      return false;
    }
    return true;
  }

  bool _hasDraftChanges(TaskDetailsDraft? draft) {
    if (draft == null) {
      return false;
    }
    final baseline = _cleanDraftBaseline;
    if (baseline != null && baseline.taskId == draft.taskId) {
      return !draft.hasSameValues(baseline);
    }
    return draft.differsFrom(
      _editingTask,
      widget.capabilities,
      localTimeZone: widget.localTimeZone,
    );
  }

  String? _listTitle(String listId) {
    for (final list in widget.taskLists) {
      if (list.id == listId) {
        return list.title;
      }
    }
    return null;
  }

  List<Widget> _reminderRows(TaskDetailsDraft draft) {
    final l10n = context.l10n;
    if (!draft.microsoftReminderEnabled) {
      return [
        BusyMaxActionRow(
          title: l10n.addReminder,
          titleWidget: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
                const SizedBox(width: BusyMaxSpacing.xs),
                Text(
                  l10n.addReminder,
                  style: _taskEditorProminentActionStyle(context),
                ),
              ],
            ),
          ),
          enabled: _canWrite,
          onTap: _canWrite
              ? () => _updateDraft(
                  draft.copyWith(
                    microsoftReminderEnabled: true,
                    microsoftReminderDate:
                        draft.dueDate ?? encodeGoogleDateOnly(DateTime.now()),
                    microsoftReminderTime: '09:00',
                  ),
                )
              : null,
        ),
      ];
    }

    return [
      DesktopDateValueRow(
        label: l10n.reminderDate,
        date: draft.microsoftReminderDate,
        enabled: _canWrite,
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftReminderDate: value)),
        useNativePicker: widget.useNativeDatePicker,
        onClear: () =>
            _updateDraft(draft.copyWith(microsoftReminderDate: null)),
      ),
      DesktopTimeValueRow(
        label: l10n.reminderTime,
        time: draft.microsoftReminderTime,
        enabled: _canWrite,
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftReminderTime: value)),
        timeZone: draft.microsoftReminderTimeZone,
        onTimeZoneChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftReminderTimeZone: value)),
        onValidityChanged: (valid) =>
            _setTimeFieldValidity(_TaskTimeField.reminder, valid),
        useNativePicker: widget.useNativeDatePicker,
      ),
      BusyMaxActionRow(
        title: l10n.removeReminder,
        leading: const Icon(YaruIcons.window_close),
        enabled: _canWrite,
        onTap: _canWrite
            ? () {
                _invalidTimeFields.remove(_TaskTimeField.reminder);
                _updateDraft(
                  draft.copyWith(
                    microsoftReminderEnabled: false,
                    microsoftReminderDate: null,
                    microsoftReminderTime: null,
                  ),
                );
              }
            : null,
      ),
    ];
  }
}

enum _ChecklistSubtaskAction { rename, delete }

TextStyle? _taskEditorProminentActionStyle(
  BuildContext context, {
  Color? color,
  FontWeight fontWeight = FontWeight.w600,
}) {
  return Theme.of(
    context,
  ).textTheme.labelLarge?.copyWith(color: color, fontWeight: fontWeight);
}

enum _TaskTimeField { due, start, reminder }

enum _RelatedReminderChoice { discard, keepAbsolute }

class _TaskDetailsHeader extends StatelessWidget {
  const _TaskDetailsHeader({
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.saving,
    required this.canSave,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final bool saving;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return BusyMaxEditorHeader(
      title: title,
      cancelLabel: cancelLabel,
      saveLabel: saveLabel,
      onCancel: onCancel,
      onSave: canSave ? onSave : null,
      saving: saving,
    );
  }
}

String _taskKey(TaskEntity task) =>
    '${task.accountId}/${task.taskListId}/${task.id}';

bool _taskChanged(TaskEntity oldTask, TaskEntity newTask) {
  return oldTask.updatedLocalAtUtc != newTask.updatedLocalAtUtc ||
      oldTask.title != newTask.title ||
      oldTask.notes != newTask.notes ||
      oldTask.dueUtc != newTask.dueUtc ||
      oldTask.microsoftDueDateTime != newTask.microsoftDueDateTime ||
      oldTask.microsoftDueTimeZone != newTask.microsoftDueTimeZone ||
      oldTask.microsoftStartDateTime != newTask.microsoftStartDateTime ||
      oldTask.microsoftStartTimeZone != newTask.microsoftStartTimeZone ||
      oldTask.microsoftReminderDateTime != newTask.microsoftReminderDateTime ||
      oldTask.microsoftReminderTimeZone != newTask.microsoftReminderTimeZone ||
      oldTask.microsoftIsReminderOn != newTask.microsoftIsReminderOn ||
      oldTask.recurrenceJson != newTask.recurrenceJson ||
      oldTask.importance != newTask.importance ||
      oldTask.categoriesJson != newTask.categoriesJson ||
      oldTask.icalPriority != newTask.icalPriority ||
      oldTask.percentComplete != newTask.percentComplete ||
      oldTask.providerStatus != newTask.providerStatus ||
      oldTask.completedUtc != newTask.completedUtc ||
      oldTask.taskLocation != newTask.taskLocation ||
      oldTask.taskUrl != newTask.taskUrl ||
      oldTask.taskClassification != newTask.taskClassification ||
      oldTask.taskPinned != newTask.taskPinned ||
      oldTask.taskHideSubtasks != newTask.taskHideSubtasks ||
      oldTask.taskHideCompletedSubtasks != newTask.taskHideCompletedSubtasks ||
      oldTask.taskAlarmsJson != newTask.taskAlarmsJson;
}

Map<String, String> _repeatOptions(BuildContext context) {
  final l10n = context.l10n;
  return {
    'none': l10n.repeatNone,
    'daily': l10n.repeatDaily,
    'weekly': l10n.repeatWeekly,
    'absoluteMonthly': l10n.repeatMonthly,
    'absoluteYearly': l10n.repeatYearly,
  };
}

String _recurrenceType(String? recurrenceJson) {
  if (recurrenceJson == null || recurrenceJson.isEmpty) {
    return 'none';
  }
  try {
    final decoded = jsonDecode(recurrenceJson);
    if (decoded is Map) {
      final pattern = decoded['pattern'];
      if (pattern is Map) {
        return pattern['type']?.toString() ?? 'none';
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
    return 'none';
  }
  return 'none';
}

String? _recurrenceJsonFor(
  String type,
  TaskDetailsDraft draft, {
  required bool dav,
}) {
  if (type == 'none') {
    return null;
  }
  final now = DateTime.now();
  final recurrenceStart = DateTime.tryParse(draft.dueDate ?? '') ?? now;
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
      'daysOfWeek': [_weekdayName(now.weekday)],
      'firstDayOfWeek': 'monday',
    },
    'absoluteMonthly' => {
      'type': 'absoluteMonthly',
      'interval': 1,
      'dayOfMonth': now.day.clamp(1, 31),
    },
    'absoluteYearly' => {
      'type': 'absoluteYearly',
      'interval': 1,
      'dayOfMonth': now.day.clamp(1, 31),
      'month': now.month,
    },
    _ => {'type': 'daily', 'interval': 1},
  };
  return jsonEncode({
    'pattern': pattern,
    'range': {
      'type': 'noEnd',
      'startDate': draft.dueDate ?? encodeGoogleDateOnly(now),
    },
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

String _weekdayName(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    _ => 'sunday',
  };
}

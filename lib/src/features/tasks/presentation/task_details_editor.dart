import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import '../../../l10n/l10n.dart';
import '../../../task_providers/task_provider.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../data/tasks_repository.dart';
import 'desktop_date_time_fields.dart';
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
    this.canSaveDraft,
  });

  final TaskEntity task;
  final List<TaskListEntity> taskLists;
  final TaskProviderCapabilities capabilities;
  final String localTimeZone;
  final String? accountLabel;
  final VoidCallback onRefresh;
  final Future<void> Function(
    TaskDetailsDraft draft,
    Map<String, Object?> patch,
  )
  onSave;
  final ValueChanged<String> onCreateSubtask;
  final VoidCallback onMoveToTop;
  final Future<void> Function() onDelete;
  final VoidCallback onCancel;
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
  final bool Function(TaskDetailsDraft draft)? canSaveDraft;

  @override
  State<TaskDetailsEditor> createState() => _TaskDetailsEditorState();
}

class _TaskDetailsEditorState extends State<TaskDetailsEditor> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _categoryController = TextEditingController();

  TaskDetailsDraft? _draft;
  TaskDetailsDraft? _cleanDraftBaseline;
  String? _loadedTaskKey;
  late TaskEntity _editingTask;
  var _saving = false;
  var _addingCategory = false;
  var _confirmingTaskSwitch = false;

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
    final hasChanges = _hasDraftChanges(_draft);

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
    _titleController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft =
        _draft ?? TaskDetailsDraft.fromTask(_editingTask, widget.localTimeZone);
    final l10n = context.l10n;
    final hasChanges = _hasDraftChanges(draft);
    final canSave =
        draft.title.trim().isNotEmpty &&
        hasChanges &&
        !_saving &&
        (widget.canSaveDraft?.call(draft) ?? true);
    final currentList = _listTitle(draft.taskListId);
    final scheduledAllDay = _isScheduledAllDay(draft);
    final listValue = [
      currentList,
      widget.accountLabel,
    ].where((value) => value != null && value.isNotEmpty).join(' · ');

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
      child: Focus(
        autofocus: true,
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
            const SizedBox(height: BusyMaxSpacing.headerInset),
            Expanded(
              child: BusyMaxClamp(
                maxWidth: 640,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: BusyMaxSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BusyMaxGroupedList(
                      filled: true,
                      children: [
                        YaruListTile.square(
                          hoverColor: busyMaxEditorRowHoverColor(context),
                          title: TextField(
                            controller: _titleController,
                            decoration: _plainTaskFieldDecoration(
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
                    BusyMaxGroupedList(
                      title: l10n.dueGroup,
                      filled: true,
                      children: [
                        if (_supportsScheduledTimeMode)
                          BusyMaxTimeModeRow(
                            allDay: scheduledAllDay,
                            onChanged: (value) =>
                                _setScheduledAllDay(draft, value),
                          ),
                        DesktopDateValueRow(
                          label: l10n.dueDate,
                          date: draft.dueDate,
                          emptyLabel: l10n.noneValue,
                          onChanged: (value) =>
                              _updateDraft(draft.copyWith(dueDate: value)),
                          onClear: () => _updateDraft(
                            draft.copyWith(
                              dueDate: null,
                              microsoftDueTime:
                                  widget.capabilities.supportsDueTime
                                  ? null
                                  : draft.microsoftDueTime,
                            ),
                          ),
                        ),
                        if (widget.capabilities.supportsDueTime &&
                            !scheduledAllDay)
                          DesktopTimeValueRow(
                            label: l10n.dueTime,
                            time: draft.microsoftDueTime,
                            emptyLabel: l10n.noneValue,
                            onChanged: (value) => _updateDraft(
                              draft.copyWith(microsoftDueTime: value),
                            ),
                          ),
                      ],
                    ),
                    if (widget.capabilities.supportsStartDateTime)
                      BusyMaxGroupedList(
                        title: l10n.startGroup,
                        filled: true,
                        children: _startRows(draft, scheduledAllDay),
                      ),
                    if (widget.capabilities.supportsReminderDateTime)
                      BusyMaxGroupedList(
                        title: l10n.reminderGroup,
                        filled: true,
                        children: _reminderRows(draft),
                      ),
                    if (widget.capabilities.supportsRecurrence)
                      BusyMaxGroupedList(
                        title: l10n.repeat,
                        filled: true,
                        children: [_repeatRow(draft)],
                      ),
                    if (widget.capabilities.supportsImportance ||
                        widget.capabilities.supportsCategories)
                      BusyMaxGroupedList(
                        title: l10n.organizationSection,
                        filled: true,
                        children: [
                          if (widget.capabilities.supportsImportance)
                            _importanceRow(draft),
                          if (widget.capabilities.supportsCategories)
                            _categoriesRow(draft),
                        ],
                      ),
                    BusyMaxGroupedList(
                      filled: true,
                      children: [
                        YaruListTile.square(
                          hoverColor: busyMaxEditorRowHoverColor(context),
                          title: TextField(
                            controller: _notesController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: _plainTaskFieldDecoration(
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
                      BusyMaxGroupedList(
                        title: l10n.advancedSection,
                        filled: true,
                        children: [
                          BusyMaxActionRow(
                            title: l10n.createSubtask,
                            leading: const Icon(Icons.subdirectory_arrow_right),
                            onTap: _createSubtask,
                          ),
                          BusyMaxActionRow(
                            title: l10n.moveToTop,
                            leading: const Icon(Icons.vertical_align_top),
                            onTap: widget.onMoveToTop,
                          ),
                        ],
                      ),
                    if (widget.showDeleteAction) ...[
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

  bool get _hasAccountSelector {
    return widget.selectedAccountId != null &&
        widget.accountIds.isNotEmpty &&
        widget.accountLabelFor != null &&
        widget.onAccountSelected != null;
  }

  Widget _accountRow() {
    final l10n = context.l10n;
    final labelFor = widget.accountLabelFor!;
    final secondaryLabelFor = widget.accountSecondaryLabelFor;
    return BusyMaxComboRow<String>(
      title: l10n.account,
      leading: const Icon(YaruIcons.user),
      values: widget.accountIds,
      selected: widget.selectedAccountId!,
      labelFor: labelFor,
      menuItemBuilder: (context, value) => _TaskEditorAccountIdentity(
        label: labelFor(value),
        secondaryLabel: secondaryLabelFor?.call(value),
      ),
      selectedBuilder: (context, value) => _TaskEditorAccountIdentity(
        label: labelFor(value),
        secondaryLabel: secondaryLabelFor?.call(value),
      ),
      onSelected: widget.onAccountSelected!,
    );
  }

  Widget _listRow(TaskDetailsDraft draft, String listValue) {
    final l10n = context.l10n;
    if (widget.taskLists.isEmpty) {
      return BusyMaxActionRow(
        title: l10n.list,
        leading: const Icon(Icons.drive_file_move_outline),
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
        leading: const Icon(Icons.drive_file_move_outline),
        subtitle: listValue.isEmpty ? null : listValue,
        enabled: false,
        tooltip: widget.capabilities.supportsCrossListMove
            ? null
            : l10n.microsoftMoveUnsupported,
      );
    }
    return BusyMaxComboRow<String>(
      title: l10n.list,
      leading: const Icon(Icons.drive_file_move_outline),
      subtitle: widget.accountLabel,
      values: [for (final list in widget.taskLists) list.id],
      selected: draft.taskListId,
      labelFor: (value) => _listTitle(value) ?? l10n.noneValue,
      selectedBuilder: (context, value) => _taskEditorSelectedValue(
        context,
        _listTitle(value) ?? l10n.noneValue,
      ),
      onSelected: (value) => _updateDraft(draft.copyWith(taskListId: value)),
    );
  }

  List<Widget> _startRows(TaskDetailsDraft draft, bool scheduledAllDay) {
    final l10n = context.l10n;
    return [
      DesktopDateValueRow(
        label: l10n.startDate,
        date: draft.microsoftStartDate,
        emptyLabel: l10n.noneValue,
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftStartDate: value)),
        onClear: () => _updateDraft(
          draft.copyWith(microsoftStartDate: null, microsoftStartTime: null),
        ),
      ),
      if (!scheduledAllDay)
        DesktopTimeValueRow(
          label: l10n.startTime,
          time: draft.microsoftStartTime,
          emptyLabel: l10n.noneValue,
          onChanged: (value) =>
              _updateDraft(draft.copyWith(microsoftStartTime: value)),
        ),
    ];
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
      leading: const Icon(Icons.repeat),
      values: options.keys.toList(),
      selected: type,
      labelFor: (value) => options[value] ?? l10n.repeatNone,
      selectedBuilder: (context, value) =>
          _taskEditorSelectedValue(context, options[value] ?? l10n.repeatNone),
      onSelected: (value) => _updateDraft(
        draft.copyWith(recurrenceJson: _recurrenceJsonFor(value, draft)),
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
      leading: const Icon(Icons.priority_high_outlined),
      values: labels.keys.toList(),
      selected: draft.importance,
      labelFor: (value) => labels[value] ?? l10n.importanceNormal,
      selectedBuilder: (context, value) => _taskEditorSelectedValue(
        context,
        labels[value] ?? l10n.importanceNormal,
      ),
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
      controller: _categoryController,
      inputKey: const Key('task-category-input'),
      onAddPressed: () {
        setState(() {
          _addingCategory = true;
        });
      },
      onSubmitted: (value) => _addCategory(draft, value),
      onCancelAdding: () {
        _categoryController.clear();
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
    if (category.isEmpty || currentDraft.categories.contains(category)) {
      return;
    }
    _categoryController.clear();
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
    if (draft == null || _saving) {
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
    final hasChanges = _hasDraftChanges(draft);
    if (hasChanges) {
      final discard = await showBusyMaxConfirm(
        context,
        title: context.l10n.discardChanges,
        message: context.l10n.discardChangesConfirmation,
        confirmLabel: context.l10n.discard,
        destructive: true,
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
      confirmLabel: context.l10n.discard,
      destructive: true,
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

  Future<void> _createSubtask() async {
    final title = await showBusyMaxTextPrompt(
      context,
      title: context.l10n.newSubtask,
      label: context.l10n.title,
      actionLabel: context.l10n.create,
    );
    if (title == null || title.trim().isEmpty) {
      return;
    }
    widget.onCreateSubtask(title.trim());
  }

  Future<void> _deleteTask() async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.deleteTask,
      message: context.l10n.deleteTaskConfirmation(_editingTask.title),
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (confirmed) {
      await widget.onDelete();
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
    widget.onDirtyChanged?.call(_hasDraftChanges(draft));
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
          onTap: () => _updateDraft(
            draft.copyWith(
              microsoftReminderEnabled: true,
              microsoftReminderDate:
                  draft.dueDate ?? encodeGoogleDateOnly(DateTime.now()),
              microsoftReminderTime: '09:00',
            ),
          ),
        ),
      ];
    }

    return [
      DesktopDateValueRow(
        label: l10n.reminderDate,
        date: draft.microsoftReminderDate,
        emptyLabel: l10n.noneValue,
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftReminderDate: value)),
        onClear: () =>
            _updateDraft(draft.copyWith(microsoftReminderDate: null)),
      ),
      DesktopTimeValueRow(
        label: l10n.reminderTime,
        time: draft.microsoftReminderTime,
        emptyLabel: l10n.noneValue,
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftReminderTime: value)),
      ),
      BusyMaxActionRow(
        title: l10n.removeReminder,
        leading: const Icon(YaruIcons.window_close),
        onTap: () => _updateDraft(
          draft.copyWith(
            microsoftReminderEnabled: false,
            microsoftReminderDate: null,
            microsoftReminderTime: null,
          ),
        ),
      ),
    ];
  }
}

InputDecoration _plainTaskFieldDecoration(
  BuildContext context, {
  required String labelText,
  String? errorText,
  bool alignLabelWithHint = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final labelColor = errorText == null
      ? colorScheme.onSurfaceVariant
      : colorScheme.error;
  final labelStyle = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: labelColor);
  return InputDecoration(
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    labelText: labelText,
    labelStyle: labelStyle,
    floatingLabelStyle: labelStyle,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    alignLabelWithHint: alignLabelWithHint,
    errorText: errorText,
  );
}

Widget _taskEditorSelectedValue(BuildContext context, String value) {
  return Align(
    alignment: Alignment.centerRight,
    child: Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    ),
  );
}

class _TaskEditorAccountIdentity extends StatelessWidget {
  const _TaskEditorAccountIdentity({required this.label, this.secondaryLabel});

  final String label;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = secondaryLabel?.trim();
    final primaryStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: 1.05);
    final secondaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.05,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: primaryStyle,
          ),
          if (secondary != null && secondary.isNotEmpty)
            Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: secondaryStyle,
            ),
        ],
      ),
    );
  }
}

TextStyle? _taskEditorProminentActionStyle(
  BuildContext context, {
  Color? color,
  FontWeight fontWeight = FontWeight.w600,
}) {
  return Theme.of(
    context,
  ).textTheme.labelLarge?.copyWith(color: color, fontWeight: fontWeight);
}

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
      oldTask.microsoftStartDateTime != newTask.microsoftStartDateTime ||
      oldTask.microsoftReminderDateTime != newTask.microsoftReminderDateTime ||
      oldTask.recurrenceJson != newTask.recurrenceJson ||
      oldTask.importance != newTask.importance ||
      oldTask.categoriesJson != newTask.categoriesJson;
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
    }
  } on FormatException {
    return 'none';
  }
  return 'none';
}

String? _recurrenceJsonFor(String type, TaskDetailsDraft draft) {
  if (type == 'none') {
    return null;
  }
  final now = DateTime.now();
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

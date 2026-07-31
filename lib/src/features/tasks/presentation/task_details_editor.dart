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
    this.useNativeDatePicker = false,
    this.dialogBarrierColor,
    this.headerBarService,
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
  final bool useNativeDatePicker;
  final Color? dialogBarrierColor;
  final LinuxHeaderBarService? headerBarService;
  final bool Function(TaskDetailsDraft draft)? canSaveDraft;

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
    final canSave =
        draft.title.trim().isNotEmpty &&
        hasChanges &&
        !_saving &&
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
                          onChanged: (value) =>
                              _updateDraft(draft.copyWith(dueDate: value)),
                          useNativePicker: widget.useNativeDatePicker,
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
                            onChanged: (value) => _updateDraft(
                              draft.copyWith(microsoftDueTime: value),
                            ),
                            timeZone: draft.microsoftDueTimeZone,
                            onTimeZoneChanged: (value) => _updateDraft(
                              draft.copyWith(microsoftDueTimeZone: value),
                            ),
                            onValidityChanged: (valid) => _setTimeFieldValidity(
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
                    if (widget.capabilities.supportsReminderDateTime)
                      BusyMaxGroupedList(
                        title: l10n.reminderGroup,
                        filled: true,
                        children: _reminderRows(draft),
                      ),
                    if (widget.capabilities.supportsRecurrence)
                      BusyMaxGroupedList(
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
                          title: TextField(
                            controller: _notesController,
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
                      BusyMaxGroupedList(
                        title: l10n.advancedSection,
                        filled: true,
                        children: [
                          BusyMaxActionRow(
                            title: l10n.createSubtask,
                            leading: Icon(
                              BusyMaxGlyphs.subdirectoryFor(
                                Directionality.of(context),
                              ),
                            ),
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

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        !widget.showDeleteAction ||
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
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftStartDate: value)),
        useNativePicker: widget.useNativeDatePicker,
        onClear: () => _updateDraft(
          draft.copyWith(microsoftStartDate: null, microsoftStartTime: null),
        ),
      ),
      if (!scheduledAllDay)
        DesktopTimeValueRow(
          label: l10n.startTime,
          time: draft.microsoftStartTime,
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
      labelFor: (value) => options[value] ?? l10n.repeatNone,
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
      leading: const Icon(YaruIcons.task_important),
      values: labels.keys.toList(),
      selected: draft.importance,
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

  Future<void> _createSubtask() async {
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
    widget.onCreateSubtask(title.trim());
  }

  Future<void> _deleteTask() async {
    if (_confirmingDelete) {
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
        onChanged: (value) =>
            _updateDraft(draft.copyWith(microsoftReminderDate: value)),
        useNativePicker: widget.useNativeDatePicker,
        onClear: () =>
            _updateDraft(draft.copyWith(microsoftReminderDate: null)),
      ),
      DesktopTimeValueRow(
        label: l10n.reminderTime,
        time: draft.microsoftReminderTime,
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
        onTap: () {
          _invalidTimeFields.remove(_TaskTimeField.reminder);
          _updateDraft(
            draft.copyWith(
              microsoftReminderEnabled: false,
              microsoftReminderDate: null,
              microsoftReminderTime: null,
            ),
          );
        },
      ),
    ];
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

enum _TaskTimeField { due, start, reminder }

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

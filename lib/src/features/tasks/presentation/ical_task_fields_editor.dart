import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../dav/ical/ical_task_alarm.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../recurrence/domain/recurrence_rule.dart';
import '../../recurrence/presentation/recurrence_editor.dart';
import '../domain/task_capabilities.dart';
import 'desktop_date_time_fields.dart';
import 'task_details_draft.dart';

/// Native RFC 5545 VTODO fields exposed by Nextcloud Tasks.
class IcalTaskFieldsEditor extends StatefulWidget {
  const IcalTaskFieldsEditor({
    super.key,
    required this.draft,
    required this.capabilities,
    required this.enabled,
    required this.onChanged,
    this.useNativeDatePicker = false,
    this.dialogBarrierColor,
    this.headerBarService,
  });

  final TaskDetailsDraft draft;
  final TaskCollectionCapabilities capabilities;
  final bool enabled;
  final ValueChanged<TaskDetailsDraft> onChanged;
  final bool useNativeDatePicker;
  final Color? dialogBarrierColor;
  final LinuxHeaderBarService? headerBarService;

  @override
  State<IcalTaskFieldsEditor> createState() => _IcalTaskFieldsEditorState();
}

class _IcalTaskFieldsEditorState extends State<IcalTaskFieldsEditor> {
  late final TextEditingController _locationController;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.draft.location);
    _urlController = TextEditingController(text: widget.draft.taskUrl);
  }

  @override
  void didUpdateWidget(covariant IcalTaskFieldsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_locationController.text != widget.draft.location) {
      _locationController.value = TextEditingValue(
        text: widget.draft.location,
        selection: TextSelection.collapsed(
          offset: widget.draft.location.length,
        ),
      );
    }
    if (_urlController.text != widget.draft.taskUrl) {
      _urlController.value = TextEditingValue(
        text: widget.draft.taskUrl,
        selection: TextSelection.collapsed(offset: widget.draft.taskUrl.length),
      );
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = widget.capabilities;
    final result = <Widget>[];
    if (capabilities.supportsTaskStatus ||
        capabilities.supportsPercentComplete ||
        capabilities.supportsCompletedDateTime) {
      result.add(_statusGroup());
    }
    if (capabilities.supportsIcalPriority) {
      result.add(_priorityGroup());
    }
    if (capabilities.supportsLocation || capabilities.supportsUrl) {
      result.add(_placeAndLinkGroup());
    }
    if (capabilities.supportsClassification ||
        capabilities.supportsPinning ||
        capabilities.supportsSubtaskVisibility) {
      result.add(_sharingGroup());
    }
    if (capabilities.supportsMultipleReminders) {
      result.add(_remindersGroup());
    }
    if (capabilities.supportsAdvancedRecurrence &&
        (widget.draft.microsoftStartDate != null ||
            widget.draft.dueDate != null)) {
      result.add(_recurrenceGroup());
    }
    return Column(children: result);
  }

  Widget _statusGroup() {
    final l10n = context.l10n;
    final draft = widget.draft;
    final showCompletionDate =
        draft.taskStatus == 'COMPLETED' ||
        draft.percentComplete == 100 ||
        draft.completedDate != null;
    return BusyMaxGroupedList(
      title: l10n.statusSection,
      filled: true,
      children: [
        if (widget.capabilities.supportsTaskStatus)
          BusyMaxComboRow<String>(
            title: l10n.taskStatus,
            leading: const Icon(Icons.fact_check_outlined),
            values: const [
              '',
              'NEEDS-ACTION',
              'IN-PROCESS',
              'COMPLETED',
              'CANCELLED',
            ],
            selected: draft.taskStatus ?? '',
            enabled: widget.enabled,
            labelFor: (value) => switch (value) {
              'NEEDS-ACTION' => l10n.taskStatusNeedsAction,
              'IN-PROCESS' => l10n.taskStatusInProcess,
              'COMPLETED' => l10n.taskStatusCompleted,
              'CANCELLED' => l10n.taskStatusCancelled,
              _ => l10n.taskStatusNone,
            },
            onSelected: (value) => _setStatus(value.isEmpty ? null : value),
          ),
        if (widget.capabilities.supportsPercentComplete)
          _TaskValueSliderRow(
            key: const ValueKey('ical-task-progress'),
            title: l10n.completionPercent(draft.percentComplete),
            leading: const Icon(Icons.donut_large_outlined),
            value: draft.percentComplete,
            maximum: 100,
            divisions: 100,
            enabled: widget.enabled,
            onChanged: _setProgress,
          ),
        if (widget.capabilities.supportsCompletedDateTime &&
            showCompletionDate) ...[
          DesktopDateValueRow(
            label: l10n.completionDate,
            date: draft.completedDate,
            enabled: widget.enabled,
            onChanged: _setCompletionDate,
            onClear: () => _setCompletionDate(null),
            useNativePicker: widget.useNativeDatePicker,
          ),
          if (draft.completedDate != null)
            DesktopTimeValueRow(
              label: l10n.completed,
              time: draft.completedTime,
              enabled: widget.enabled,
              onChanged: (value) =>
                  widget.onChanged(draft.copyWith(completedTime: value)),
              useNativePicker: widget.useNativeDatePicker,
            ),
        ],
      ],
    );
  }

  Widget _priorityGroup() {
    final l10n = context.l10n;
    final priority = widget.draft.icalPriority;
    final label = switch (priority) {
      0 => l10n.priorityNone,
      >= 1 && <= 4 => l10n.priorityHighValue(priority),
      5 => l10n.priorityMediumValue(priority),
      _ => l10n.priorityLowValue(priority),
    };
    return BusyMaxGroupedList(
      title: l10n.priority,
      filled: true,
      children: [
        _TaskValueSliderRow(
          key: const ValueKey('ical-task-priority'),
          title: label,
          leading: const Icon(YaruIcons.task_important),
          value: priority,
          maximum: 9,
          divisions: 9,
          enabled: widget.enabled,
          // RFC 5545 orders priority in the opposite direction: 1 is highest.
          onChanged: (value) =>
              widget.onChanged(widget.draft.copyWith(icalPriority: value)),
        ),
      ],
    );
  }

  Widget _placeAndLinkGroup() {
    final l10n = context.l10n;
    return BusyMaxGroupedList(
      filled: true,
      children: [
        if (widget.capabilities.supportsLocation)
          YaruListTile.square(
            leading: const Icon(Icons.place_outlined),
            title: TextField(
              key: const ValueKey('ical-task-location'),
              controller: _locationController,
              enabled: widget.enabled,
              decoration: busyMaxGroupedTextFieldDecoration(
                context,
                labelText: l10n.location,
              ),
              onChanged: (value) =>
                  widget.onChanged(widget.draft.copyWith(location: value)),
            ),
          ),
        if (widget.capabilities.supportsUrl)
          YaruListTile.square(
            leading: const Icon(Icons.link),
            title: TextField(
              key: const ValueKey('ical-task-url'),
              controller: _urlController,
              enabled: widget.enabled,
              keyboardType: TextInputType.url,
              decoration: busyMaxGroupedTextFieldDecoration(
                context,
                labelText: l10n.taskUrl,
                errorText: widget.draft.hasValidTaskUrl
                    ? null
                    : l10n.invalidTaskUrl,
              ),
              onChanged: (value) =>
                  widget.onChanged(widget.draft.copyWith(taskUrl: value)),
            ),
          ),
      ],
    );
  }

  Widget _sharingGroup() {
    final l10n = context.l10n;
    return BusyMaxGroupedList(
      filled: true,
      children: [
        if (widget.capabilities.supportsClassification)
          BusyMaxComboRow<String>(
            title: l10n.classification,
            leading: const Icon(Icons.visibility_outlined),
            values: const ['PUBLIC', 'CONFIDENTIAL', 'PRIVATE'],
            selected: widget.draft.classification,
            enabled:
                widget.enabled && widget.capabilities.canUpdateClassification,
            labelFor: (value) => switch (value) {
              'CONFIDENTIAL' => l10n.classificationConfidential,
              'PRIVATE' => l10n.classificationPrivate,
              _ => l10n.classificationPublic,
            },
            onSelected: (value) =>
                widget.onChanged(widget.draft.copyWith(classification: value)),
          ),
        if (widget.capabilities.supportsPinning)
          BusyMaxSwitchRow(
            title: l10n.pinTask,
            leading: const Icon(Icons.push_pin_outlined),
            value: widget.draft.pinned,
            enabled: widget.enabled,
            onChanged: (value) =>
                widget.onChanged(widget.draft.copyWith(pinned: value)),
          ),
        if (widget.capabilities.supportsSubtaskVisibility)
          BusyMaxSwitchRow(
            key: const ValueKey('ical-task-hide-subtasks'),
            title: l10n.hideSubtasks,
            leading: const Icon(Icons.account_tree_outlined),
            value: widget.draft.hideSubtasks,
            enabled: widget.enabled,
            onChanged: (value) =>
                widget.onChanged(widget.draft.copyWith(hideSubtasks: value)),
          ),
        if (widget.capabilities.supportsSubtaskVisibility)
          BusyMaxSwitchRow(
            key: const ValueKey('ical-task-hide-completed-subtasks'),
            title: l10n.hideClosedSubtasks,
            leading: const Icon(Icons.rule_outlined),
            value: widget.draft.hideCompletedSubtasks,
            enabled: widget.enabled,
            onChanged: (value) => widget.onChanged(
              widget.draft.copyWith(hideCompletedSubtasks: value),
            ),
          ),
      ],
    );
  }

  Widget _remindersGroup() {
    final l10n = context.l10n;
    final alarms = widget.draft.alarms;
    return BusyMaxGroupedList(
      title: l10n.reminders,
      filled: true,
      children: [
        if (alarms.isEmpty)
          BusyMaxActionRow(
            title: l10n.noReminders,
            leading: const Icon(Icons.notifications_none),
            enabled: false,
          ),
        for (var index = 0; index < alarms.length; index += 1)
          BusyMaxActionRow(
            key: ValueKey('ical-task-alarm-$index'),
            title: _alarmLabel(alarms[index]),
            subtitle: _alarmTypeLabel(alarms[index]),
            leading: const Icon(Icons.notifications_outlined),
            enabled: widget.enabled,
            onTap: _canEditReminder(alarms[index])
                ? () => _editReminder(index)
                : null,
            tooltip: _canEditReminder(alarms[index])
                ? l10n.editReminder
                : l10n.unsupportedReminder,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canEditReminder(alarms[index]))
                  YaruIconButton(
                    tooltip: l10n.editReminder,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: widget.enabled
                        ? () => _editReminder(index)
                        : null,
                  ),
                YaruIconButton(
                  tooltip: l10n.removeReminder,
                  icon: const Icon(Icons.close),
                  onPressed: widget.enabled
                      ? () => _removeReminder(index)
                      : null,
                ),
              ],
            ),
          ),
        BusyMaxActionRow(
          title: l10n.addReminder,
          leading: const Icon(Icons.add_alert_outlined),
          enabled: widget.enabled,
          onTap: widget.enabled ? _addReminder : null,
        ),
      ],
    );
  }

  Widget _recurrenceGroup() {
    final l10n = context.l10n;
    final recurrence = RecurrenceRule.fromJson(
      widget.draft.recurrenceJson,
      baseDate: _recurrenceBaseDate,
    );
    final canEdit = widget.enabled && recurrence.isSupported;
    return BusyMaxGroupedList(
      filled: true,
      children: [
        BusyMaxActionRow(
          key: const ValueKey('ical-task-recurrence'),
          title: l10n.repeat,
          subtitle: recurrence.isSupported
              ? _recurrenceSummary(recurrence)
              : l10n.unsupportedRecurrencePreserved,
          leading: const Icon(YaruIcons.repeat),
          enabled: canEdit,
          onTap: canEdit ? _editRecurrence : null,
          trailing: Icon(
            recurrence.isSupported ? Icons.chevron_right : Icons.lock_outline,
          ),
        ),
      ],
    );
  }

  void _setStatus(String? status) {
    final draft = widget.draft;
    final now = DateTime.now();
    final next = switch (status) {
      'COMPLETED' => draft.copyWith(
        taskStatus: status,
        percentComplete: 100,
        completedDate: draft.completedDate ?? _dateString(now),
        completedTime: draft.completedTime ?? _timeString(now),
      ),
      'IN-PROCESS' => draft.copyWith(
        taskStatus: status,
        percentComplete: draft.percentComplete == 100
            ? 99
            : draft.percentComplete == 0
            ? 1
            : draft.percentComplete,
        completedDate: null,
        completedTime: null,
      ),
      'NEEDS-ACTION' || null => draft.copyWith(
        taskStatus: status,
        percentComplete: draft.percentComplete == 100
            ? 99
            : draft.percentComplete,
        completedDate: null,
        completedTime: null,
      ),
      'CANCELLED' => draft.copyWith(taskStatus: status),
      _ => draft,
    };
    widget.onChanged(next);
  }

  void _setProgress(int percent) {
    final draft = widget.draft;
    final now = DateTime.now();
    widget.onChanged(switch (percent) {
      100 => draft.copyWith(
        percentComplete: 100,
        taskStatus: 'COMPLETED',
        completedDate: draft.completedDate ?? _dateString(now),
        completedTime: draft.completedTime ?? _timeString(now),
      ),
      0 => draft.copyWith(
        percentComplete: 0,
        taskStatus: 'NEEDS-ACTION',
        completedDate: null,
        completedTime: null,
      ),
      _ => draft.copyWith(
        percentComplete: percent,
        taskStatus: 'IN-PROCESS',
        completedDate: null,
        completedTime: null,
      ),
    });
  }

  void _setCompletionDate(String? value) {
    final draft = widget.draft;
    if (value == null) {
      widget.onChanged(
        draft.copyWith(
          completedDate: null,
          completedTime: null,
          percentComplete: draft.percentComplete == 100
              ? 99
              : draft.percentComplete,
          taskStatus: draft.percentComplete == 100
              ? 'IN-PROCESS'
              : draft.taskStatus,
        ),
      );
      return;
    }
    widget.onChanged(
      draft.copyWith(
        completedDate: value,
        completedTime: draft.completedTime ?? _timeString(DateTime.now()),
        percentComplete: 100,
        taskStatus: 'COMPLETED',
      ),
    );
  }

  Future<void> _addReminder() async {
    final alarm = await _showReminderDialog(context, initial: null);
    if (alarm == null || !mounted) return;
    widget.onChanged(
      widget.draft.copyWith(alarms: [...widget.draft.alarms, alarm]),
    );
  }

  Future<void> _editReminder(int index) async {
    final current = widget.draft.alarms[index];
    if (!_canEditReminder(current)) return;
    final alarm = await _showReminderDialog(context, initial: current);
    if (alarm == null || !mounted) return;
    final alarms = [...widget.draft.alarms];
    alarms[index] = alarm;
    widget.onChanged(widget.draft.copyWith(alarms: alarms));
  }

  void _removeReminder(int index) {
    widget.onChanged(
      widget.draft.copyWith(
        alarms: [
          for (var i = 0; i < widget.draft.alarms.length; i += 1)
            if (i != index) widget.draft.alarms[i],
        ],
      ),
    );
  }

  bool _canEditReminder(IcalTaskAlarm alarm) => alarm.canEditTriggerFor(
    allDay:
        widget.draft.microsoftDueTime == null &&
        widget.draft.microsoftStartTime == null,
  );

  Future<IcalTaskAlarm?> _showReminderDialog(
    BuildContext context, {
    required IcalTaskAlarm? initial,
  }) {
    return showBusyMaxModalEditorDialog<IcalTaskAlarm>(
      context,
      barrierColor: widget.dialogBarrierColor,
      headerBarService: widget.headerBarService,
      maxWidth: 520,
      maxHeight: 680,
      builder: (context) => _TaskReminderDialog(
        initial: initial,
        hasStart: widget.draft.microsoftStartDate != null,
        hasDue: widget.draft.dueDate != null,
        allDay:
            widget.draft.microsoftDueTime == null &&
            widget.draft.microsoftStartTime == null,
        useNativeDatePicker: widget.useNativeDatePicker,
      ),
    );
  }

  Future<void> _editRecurrence() async {
    final initial = RecurrenceRule.fromJson(
      widget.draft.recurrenceJson,
      baseDate: _recurrenceBaseDate,
    );
    if (!initial.isSupported) return;
    final baseDate = _recurrenceBaseDate ?? DateTime.now();
    final allDay =
        widget.draft.microsoftDueTime == null &&
        widget.draft.microsoftStartTime == null;
    final result = await showRecurrenceEditorDialog(
      context,
      initial: initial,
      allDay: allDay,
      floating:
          !allDay &&
          (widget.draft.microsoftStartTimeZone?.trim().isEmpty ?? true),
      baseDate: baseDate,
      minimumDate: baseDate,
      timeZone: widget.draft.microsoftStartTimeZone,
      useNativeDatePicker: widget.useNativeDatePicker,
      barrierColor: widget.dialogBarrierColor,
      headerBarService: widget.headerBarService,
    );
    if (result == null || !mounted) return;
    widget.onChanged(
      widget.draft.copyWith(recurrenceJson: result.toJsonString()),
    );
  }

  String _alarmLabel(IcalTaskAlarm alarm) {
    final absolute = alarm.absoluteUtc;
    if (absolute != null) {
      final local = absolute.toLocal();
      return context.l10n.dateTimeDisplay(
        MaterialLocalizations.of(context).formatMediumDate(local),
        TimeOfDay.fromDateTime(local).format(context),
      );
    }
    final offset = alarm.relativeOffset;
    if (offset != null) {
      final absoluteSeconds = offset.inSeconds.abs();
      if (absoluteSeconds == 0) {
        return alarm.isRelatedToDue
            ? context.l10n.reminderAtTaskDue
            : context.l10n.reminderAtTaskStart;
      }
      final amount = absoluteSeconds % (7 * Duration.secondsPerDay) == 0
          ? absoluteSeconds ~/ (7 * Duration.secondsPerDay)
          : absoluteSeconds % Duration.secondsPerDay == 0
          ? absoluteSeconds ~/ Duration.secondsPerDay
          : absoluteSeconds % Duration.secondsPerHour == 0
          ? absoluteSeconds ~/ Duration.secondsPerHour
          : absoluteSeconds % Duration.secondsPerMinute == 0
          ? absoluteSeconds ~/ Duration.secondsPerMinute
          : absoluteSeconds;
      final unit = absoluteSeconds % (7 * Duration.secondsPerDay) == 0
          ? context.l10n.reminderUnitWeeks
          : absoluteSeconds % Duration.secondsPerDay == 0
          ? context.l10n.reminderUnitDays
          : absoluteSeconds % Duration.secondsPerHour == 0
          ? context.l10n.reminderUnitHours
          : absoluteSeconds % Duration.secondsPerMinute == 0
          ? context.l10n.reminderUnitMinutes
          : context.l10n.reminderUnitSeconds;
      final relation = alarm.isRelatedToDue
          ? (offset.isNegative
                ? context.l10n.beforeTaskDue
                : context.l10n.afterTaskDue)
          : (offset.isNegative
                ? context.l10n.beforeTaskStarts
                : context.l10n.afterTaskStarts);
      return '$amount $unit · $relation';
    }
    return alarm.triggerRaw;
  }

  String? _alarmTypeLabel(IcalTaskAlarm alarm) {
    if (alarm.action.isEmpty || alarm.action == 'DISPLAY') return null;
    return alarm.action;
  }

  String _recurrenceSummary(RecurrenceRule recurrence) => recurrenceRuleSummary(
    context,
    recurrence,
    timeZone: widget.draft.microsoftStartTimeZone,
  );

  DateTime? get _recurrenceBaseDate => DateTime.tryParse(
    widget.draft.microsoftStartDate ?? widget.draft.dueDate ?? '',
  );
}

class _TaskValueSliderRow extends StatelessWidget {
  const _TaskValueSliderRow({
    super.key,
    required this.title,
    required this.leading,
    required this.value,
    required this.maximum,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final Widget leading;
  final int value;
  final int maximum;
  final int divisions;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return YaruListTile.square(
      leading: leading,
      title: Text(title),
      subtitle: Slider(
        value: value.toDouble(),
        min: 0,
        max: maximum.toDouble(),
        divisions: divisions,
        label: '$value',
        onChanged: enabled
            ? (value) => onChanged(value.round().clamp(0, maximum))
            : null,
      ),
    );
  }
}

enum _ReminderMode { absolute, beforeStart, beforeDue, allDayStart, allDayDue }

enum _ReminderUnit { seconds, minutes, hours, days, weeks }

class _TaskReminderDialog extends StatefulWidget {
  const _TaskReminderDialog({
    required this.initial,
    required this.hasStart,
    required this.hasDue,
    required this.allDay,
    required this.useNativeDatePicker,
  });

  final IcalTaskAlarm? initial;
  final bool hasStart;
  final bool hasDue;
  final bool allDay;
  final bool useNativeDatePicker;

  @override
  State<_TaskReminderDialog> createState() => _TaskReminderDialogState();
}

class _TaskReminderDialogState extends State<_TaskReminderDialog> {
  late _ReminderMode _mode;
  late _ReminderUnit _unit;
  late DateTime _absoluteLocal;
  late TimeOfDay _allDayTime;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final offset = initial?.relativeOffset;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _absoluteLocal =
        initial?.absoluteUtc?.toLocal() ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
    if (offset != null) {
      if (widget.allDay) {
        final fields = IcalAllDayAlarmOffset.fromDuration(offset);
        _mode = initial!.isRelatedToDue
            ? _ReminderMode.allDayDue
            : _ReminderMode.allDayStart;
        _unit = fields.unit == IcalAllDayAlarmUnit.weeks
            ? _ReminderUnit.weeks
            : _ReminderUnit.days;
        _amountController = TextEditingController(text: '${fields.amount}');
        _allDayTime = TimeOfDay(hour: fields.hour, minute: fields.minute);
      } else {
        _mode = initial!.isRelatedToDue
            ? _ReminderMode.beforeDue
            : _ReminderMode.beforeStart;
        final seconds = offset.inSeconds.abs();
        if (seconds != 0 && seconds % (7 * Duration.secondsPerDay) == 0) {
          _unit = _ReminderUnit.weeks;
          _amountController = TextEditingController(
            text: '${seconds ~/ (7 * Duration.secondsPerDay)}',
          );
        } else if (seconds != 0 && seconds % Duration.secondsPerDay == 0) {
          _unit = _ReminderUnit.days;
          _amountController = TextEditingController(
            text: '${seconds ~/ Duration.secondsPerDay}',
          );
        } else if (seconds != 0 && seconds % Duration.secondsPerHour == 0) {
          _unit = _ReminderUnit.hours;
          _amountController = TextEditingController(
            text: '${seconds ~/ Duration.secondsPerHour}',
          );
        } else if (seconds == 0 || seconds % Duration.secondsPerMinute == 0) {
          _unit = _ReminderUnit.minutes;
          _amountController = TextEditingController(
            text: '${seconds ~/ Duration.secondsPerMinute}',
          );
        } else {
          _unit = _ReminderUnit.seconds;
          _amountController = TextEditingController(text: '$seconds');
        }
        _allDayTime = const TimeOfDay(hour: 9, minute: 0);
      }
    } else {
      _mode = _ReminderMode.absolute;
      _unit = widget.allDay ? _ReminderUnit.days : _ReminderUnit.minutes;
      _amountController = TextEditingController(
        text: widget.allDay ? '0' : '10',
      );
      _allDayTime = const TimeOfDay(hour: 9, minute: 0);
    }
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modes = <_ReminderMode>[
      _ReminderMode.absolute,
      if (widget.hasStart)
        if (widget.allDay)
          _ReminderMode.allDayStart
        else
          _ReminderMode.beforeStart,
      if (widget.hasDue)
        if (widget.allDay) _ReminderMode.allDayDue else _ReminderMode.beforeDue,
    ];
    if (!modes.contains(_mode)) modes.add(_mode);
    return BusyMaxModalEditorScaffold(
      title: widget.initial == null ? l10n.addReminder : l10n.editReminder,
      cancelLabel: l10n.cancel,
      saveLabel: l10n.save,
      onCancel: () => Navigator.pop(context),
      onSave: _canSave ? _save : null,
      contentMaxWidth: 480,
      children: [
        BusyMaxGroupedList(
          filled: true,
          children: [
            BusyMaxComboRow<_ReminderMode>(
              title: l10n.reminder,
              values: modes,
              selected: _mode,
              labelFor: (mode) => _modeLabel(mode, l10n),
              onSelected: (value) => setState(() => _mode = value),
            ),
          ],
        ),
        if (_mode == _ReminderMode.absolute)
          BusyMaxGroupedList(
            filled: true,
            children: [
              DesktopDateValueRow(
                label: l10n.reminderDate,
                date: _dateString(_absoluteLocal),
                useNativePicker: widget.useNativeDatePicker,
                onChanged: _setAbsoluteDate,
              ),
              DesktopTimeValueRow(
                label: l10n.reminderTime,
                time: _timeString(_absoluteLocal),
                allowEmpty: false,
                useNativePicker: widget.useNativeDatePicker,
                onChanged: _setAbsoluteTime,
              ),
            ],
          )
        else
          BusyMaxGroupedList(
            filled: true,
            children: [
              YaruListTile.square(
                title: TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: busyMaxGroupedTextFieldDecoration(
                    context,
                    labelText: l10n.reminderAmount,
                  ),
                ),
              ),
              BusyMaxComboRow<_ReminderUnit>(
                title: l10n.reminderUnit,
                values: _availableUnits,
                selected: _unit,
                labelFor: (unit) => _unitLabel(unit, l10n),
                onSelected: (value) => setState(() => _unit = value),
              ),
              if (_isAllDayRelative)
                DesktopTimeValueRow(
                  label: l10n.reminderTimeOfDay,
                  time: _clockString(_allDayTime.hour, _allDayTime.minute),
                  allowEmpty: false,
                  useNativePicker: widget.useNativeDatePicker,
                  onChanged: _setAllDayTime,
                ),
            ],
          ),
      ],
    );
  }

  void _setAbsoluteDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return;
    setState(() {
      _absoluteLocal = DateTime(
        date.year,
        date.month,
        date.day,
        _absoluteLocal.hour,
        _absoluteLocal.minute,
      );
    });
  }

  void _setAbsoluteTime(String? value) {
    final time = _parseClock(value);
    if (time == null) return;
    setState(() {
      _absoluteLocal = DateTime(
        _absoluteLocal.year,
        _absoluteLocal.month,
        _absoluteLocal.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _setAllDayTime(String? value) {
    final time = _parseClock(value);
    if (time == null) return;
    setState(() => _allDayTime = time);
  }

  void _save() {
    final initial = widget.initial;
    if (_mode == _ReminderMode.absolute) {
      Navigator.pop(
        context,
        initial?.withAbsoluteTrigger(_absoluteLocal.toUtc()) ??
            IcalTaskAlarm.displayAbsolute(_absoluteLocal.toUtc()),
      );
      return;
    }
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount < 0 || amount > 3600) return;
    final relatedToDue =
        _mode == _ReminderMode.beforeDue || _mode == _ReminderMode.allDayDue;
    final offset = _isAllDayRelative
        ? IcalAllDayAlarmOffset(
            amount: amount,
            unit: _unit == _ReminderUnit.weeks
                ? IcalAllDayAlarmUnit.weeks
                : IcalAllDayAlarmUnit.days,
            hour: _allDayTime.hour,
            minute: _allDayTime.minute,
          ).toDuration()
        : Duration(seconds: -_timedSeconds(amount));
    Navigator.pop(
      context,
      initial?.withRelativeTrigger(offset, relatedToDue: relatedToDue) ??
          IcalTaskAlarm.displayRelative(offset, relatedToDue: relatedToDue),
    );
  }

  List<_ReminderUnit> get _availableUnits {
    if (widget.allDay) {
      return const [_ReminderUnit.days, _ReminderUnit.weeks];
    }
    final result = <_ReminderUnit>[];
    if (_unit == _ReminderUnit.seconds) result.add(_ReminderUnit.seconds);
    result.addAll(const [_ReminderUnit.minutes, _ReminderUnit.hours]);
    result.addAll(const [_ReminderUnit.days, _ReminderUnit.weeks]);
    return result;
  }

  bool get _isAllDayRelative =>
      _mode == _ReminderMode.allDayStart || _mode == _ReminderMode.allDayDue;

  bool get _canSave {
    if (_mode == _ReminderMode.absolute) return true;
    final amount = int.tryParse(_amountController.text);
    return amount != null && amount >= 0 && amount <= 3600;
  }

  int _timedSeconds(int amount) =>
      amount *
      switch (_unit) {
        _ReminderUnit.seconds => 1,
        _ReminderUnit.minutes => Duration.secondsPerMinute,
        _ReminderUnit.hours => Duration.secondsPerHour,
        _ReminderUnit.days => Duration.secondsPerDay,
        _ReminderUnit.weeks => 7 * Duration.secondsPerDay,
      };

  String _modeLabel(_ReminderMode mode, AppLocalizations l10n) =>
      switch (mode) {
        _ReminderMode.absolute => l10n.absoluteReminder,
        _ReminderMode.beforeStart => l10n.beforeTaskStarts,
        _ReminderMode.beforeDue => l10n.beforeTaskDue,
        _ReminderMode.allDayStart => l10n.relativeToTaskStart,
        _ReminderMode.allDayDue => l10n.relativeToTaskDue,
      };

  String _unitLabel(_ReminderUnit unit, AppLocalizations l10n) =>
      switch (unit) {
        _ReminderUnit.seconds => l10n.reminderUnitSeconds,
        _ReminderUnit.minutes => l10n.reminderUnitMinutes,
        _ReminderUnit.hours => l10n.reminderUnitHours,
        _ReminderUnit.days => l10n.reminderUnitDays,
        _ReminderUnit.weeks => l10n.reminderUnitWeeks,
      };
}

String _dateString(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _timeString(DateTime value) => _clockString(value.hour, value.minute);

String _clockString(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:'
    '${minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseClock(String? value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value ?? '');
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

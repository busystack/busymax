import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../dav/ical/ical_task_alarm.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../providers/busy_provider.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_recurrence_dialog.dart';
import 'windows_task_create_fields.dart';
import 'windows_time_zone_dialog.dart';

Future<bool> showWindowsTaskEditorDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final accounts = await ref
      .read(accountsRepositoryProvider)
      .watchAccounts()
      .first;
  final accountsById = {for (final account in accounts) account.id: account};
  final capabilities = <String, TaskCollectionCapabilities>{};
  final lists = <TaskListEntity>[];
  for (final account in accounts.where((account) => account.isTaskCapable)) {
    final accountLists = await ref
        .read(taskListsRepositoryForAccountProvider(account.id))
        .listTaskLists();
    for (final list in accountLists) {
      final value = account.provider == BusyProvider.nextcloud
          ? await ref.read(
                  davTaskCollectionCapabilitiesProvider((
                    accountId: account.id,
                    taskListId: list.id,
                  )).future,
                ) ??
                noTaskCollectionCapabilities
          : adapterDefaultTaskCapabilities(account.provider);
      if (value.canCreateTasks) {
        lists.add(list);
        capabilities[list.id] = value;
      }
    }
  }
  if (!context.mounted) return false;
  if (lists.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(AppLocalizations.of(context).newTask),
        content: Text(AppLocalizations.of(context).noTaskListsSynced),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      ),
    );
    return false;
  }

  final title = TextEditingController();
  final notes = TextEditingController();
  final location = TextEditingController();
  final taskUrl = TextEditingController();
  final categories = TextEditingController();
  var selectedList = lists.first;
  var selectedTimeZone = ref.read(localTimeZoneProvider);
  DateTime? due;
  DateTime? start;
  var scheduledAllDay = true;
  DateTime? reminder;
  var alarms = <IcalTaskAlarm>[];
  var recurrence = const RecurrenceRule.none();
  var importance = 'normal';
  var status = '';
  var priority = 0;
  var progress = 0;
  var classification = 'PUBLIC';
  var pinned = false;
  var hideSubtasks = false;
  var hideCompletedSubtasks = false;
  var saving = false;
  var saved = false;
  var allowPop = false;
  String? error;
  final initialListId = selectedList.id;
  final initialTimeZone = selectedTimeZone;
  bool hasPendingEdits() =>
      selectedList.id != initialListId ||
      selectedTimeZone != initialTimeZone ||
      title.text.isNotEmpty ||
      notes.text.isNotEmpty ||
      location.text.isNotEmpty ||
      taskUrl.text.isNotEmpty ||
      categories.text.isNotEmpty ||
      due != null ||
      start != null ||
      !scheduledAllDay ||
      reminder != null ||
      alarms.isNotEmpty ||
      recurrence.repeats ||
      importance != 'normal' ||
      status.isNotEmpty ||
      priority != 0 ||
      progress != 0 ||
      classification != 'PUBLIC' ||
      pinned ||
      hideSubtasks ||
      hideCompletedSubtasks;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final capability =
            capabilities[selectedList.id] ?? noTaskCollectionCapabilities;
        final provider =
            accountsById[selectedList.accountId]?.provider ??
            BusyProvider.google;
        final validUrl =
            taskUrl.text.trim().isEmpty ||
            (Uri.tryParse(taskUrl.text.trim())?.hasScheme ?? false);
        final validSchedule =
            due == null || start == null || !due!.isBefore(start!);
        void closeDialog() {
          setState(() => allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          });
        }

        return PopScope<void>(
          canPop: allowPop || (!saving && !hasPendingEdits()),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || saving || allowPop) return;
            if (await _confirmDiscardNewTaskChanges(context) &&
                context.mounted) {
              closeDialog();
            }
          },
          child: ContentDialog(
            title: Text(l10n.newTask),
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
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.taskLists,
                    child: ComboBox<TaskListEntity>(
                      isExpanded: true,
                      value: selectedList,
                      items: [
                        for (final list in lists)
                          ComboBoxItem(value: list, child: Text(list.title)),
                      ],
                      onChanged: saving
                          ? null
                          : (list) {
                              if (list != null) {
                                setState(() {
                                  selectedList = list;
                                  recurrence = const RecurrenceRule.none();
                                  reminder = null;
                                  alarms = [];
                                  scheduledAllDay = true;
                                });
                              }
                            },
                    ),
                  ),
                  if (capability.supportsDueDate) ...[
                    const SizedBox(height: 12),
                    _DateTimeField(
                      label: l10n.dueDate,
                      value: due,
                      showTime: capability.supportsDueTime && !scheduledAllDay,
                      enabled: !saving,
                      onChanged: (value) => setState(() => due = value),
                    ),
                  ],
                  if (capability.supportsStartDateTime) ...[
                    const SizedBox(height: 12),
                    _DateTimeField(
                      label: l10n.startDateTime,
                      value: start,
                      showTime: !scheduledAllDay,
                      enabled: !saving,
                      onChanged: (value) => setState(() => start = value),
                    ),
                  ],
                  if ((due != null || start != null) &&
                      (capability.supportsDueTime ||
                          capability.supportsStartDateTime)) ...[
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: scheduledAllDay,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => scheduledAllDay = value),
                      content: Text(l10n.allDay),
                    ),
                  ],
                  if (capability.supportsDueTime ||
                      capability.supportsStartDateTime ||
                      capability.supportsReminderDateTime) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.selectTimeZone,
                      child: Button(
                        onPressed: saving
                            ? null
                            : () async {
                                final value = await showWindowsTimeZoneDialog(
                                  context,
                                  selectedTimeZone: selectedTimeZone,
                                );
                                if (value != null) {
                                  setState(() => selectedTimeZone = value);
                                }
                              },
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(selectedTimeZone),
                        ),
                      ),
                    ),
                  ],
                  if (capability.supportsReminderDateTime &&
                      !capability.supportsMultipleReminders) ...[
                    const SizedBox(height: 12),
                    ToggleSwitch(
                      checked: reminder != null,
                      onChanged: saving
                          ? null
                          : (enabled) => setState(
                              () => reminder = enabled
                                  ? (due ?? start ?? DateTime.now()).subtract(
                                      const Duration(minutes: 15),
                                    )
                                  : null,
                            ),
                      content: Text(l10n.reminder),
                    ),
                    if (reminder != null) ...[
                      const SizedBox(height: 8),
                      _DateTimeField(
                        label: l10n.reminderTime,
                        value: reminder,
                        showTime: true,
                        enabled: !saving,
                        onChanged: (value) => setState(() => reminder = value),
                      ),
                    ],
                  ],
                  if (capability.supportsMultipleReminders) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.reminder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0; index < alarms.length; index += 1)
                            ListTile(
                              title: Text(
                                _newTaskAlarmLabel(context, alarms[index]),
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final value =
                                          await _showTaskReminderDialog(
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
                                onPressed: saving
                                    ? null
                                    : () => setState(
                                        () => alarms.removeAt(index),
                                      ),
                              ),
                            ),
                          Button(
                            onPressed: saving
                                ? null
                                : () async {
                                    final value = await _showTaskReminderDialog(
                                      context,
                                      initial: (due ?? start ?? DateTime.now())
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
                                  },
                            child: Text(l10n.addReminder),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (capability.supportsRecurrence &&
                      (due != null || start != null)) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.repeat,
                      child: capability.supportsAdvancedRecurrence
                          ? Button(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final value =
                                          await showWindowsRecurrenceDialog(
                                            context,
                                            initial: recurrence,
                                            baseDate: start ?? due!,
                                            allDay: scheduledAllDay,
                                            timeZone: selectedTimeZone,
                                            providerLabel: provider.displayName,
                                            limits:
                                                RecurrenceRuleLimits.rfc5545,
                                          );
                                      if (value != null) {
                                        setState(() => recurrence = value);
                                      }
                                    },
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  _recurrenceLabel(l10n, recurrence.frequency),
                                ),
                              ),
                            )
                          : ComboBox<RecurrenceFrequency>(
                              isExpanded: true,
                              value: recurrence.frequency,
                              items: [
                                for (final frequency
                                    in RecurrenceFrequency.values)
                                  ComboBoxItem(
                                    value: frequency,
                                    child: Text(
                                      _recurrenceLabel(l10n, frequency),
                                    ),
                                  ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (frequency) {
                                      if (frequency != null) {
                                        setState(
                                          () => recurrence =
                                              _simpleRecurrenceRule(
                                                frequency,
                                                start ?? due!,
                                              ),
                                        );
                                      }
                                    },
                            ),
                    ),
                  ],
                  if (capability.supportsImportance &&
                      !capability.supportsIcalPriority) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.importance,
                      value: importance,
                      values: {
                        'low': l10n.importanceLow,
                        'normal': l10n.importanceNormal,
                        'high': l10n.importanceHigh,
                      },
                      enabled: !saving,
                      onChanged: (value) => setState(() => importance = value),
                    ),
                  ],
                  if (capability.supportsCategories) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.categories,
                      child: TextBox(controller: categories),
                    ),
                  ],
                  if (capability.supportsTaskStatus) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.taskStatus,
                      value: status,
                      values: {
                        '': l10n.taskStatusNone,
                        'NEEDS-ACTION': l10n.taskStatusNeedsAction,
                        'IN-PROCESS': l10n.taskStatusInProcess,
                        'COMPLETED': l10n.taskStatusCompleted,
                        'CANCELLED': l10n.taskStatusCancelled,
                      },
                      enabled: !saving,
                      onChanged: (value) => setState(() => status = value),
                    ),
                  ],
                  if (capability.supportsPercentComplete) ...[
                    const SizedBox(height: 12),
                    Text(l10n.completionPercent(progress)),
                    Slider(
                      value: progress.toDouble(),
                      max: 100,
                      divisions: 100,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => progress = value.round()),
                    ),
                  ],
                  if (capability.supportsIcalPriority) ...[
                    const SizedBox(height: 12),
                    Text(_priorityLabel(l10n, priority)),
                    Slider(
                      value: priority.toDouble(),
                      max: 9,
                      divisions: 9,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => priority = value.round()),
                    ),
                  ],
                  if (capability.supportsLocation) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.location,
                      child: TextBox(controller: location),
                    ),
                  ],
                  if (capability.supportsUrl) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.taskUrl,
                      child: TextBox(
                        controller: taskUrl,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (!validUrl)
                      InfoBar(
                        title: Text(l10n.invalidTaskUrl),
                        severity: InfoBarSeverity.warning,
                      ),
                    if (!validSchedule) ...[
                      const SizedBox(height: 8),
                      InfoBar(
                        title: Text(l10n.taskDueBeforeStart),
                        severity: InfoBarSeverity.warning,
                      ),
                    ],
                  ],
                  if (capability.supportsClassification) ...[
                    const SizedBox(height: 12),
                    _StringCombo(
                      label: l10n.classification,
                      value: classification,
                      values: {
                        'PUBLIC': l10n.classificationPublic,
                        'CONFIDENTIAL': l10n.classificationConfidential,
                        'PRIVATE': l10n.classificationPrivate,
                      },
                      enabled: !saving,
                      onChanged: (value) =>
                          setState(() => classification = value),
                    ),
                  ],
                  if (capability.supportsPinning) ...[
                    const SizedBox(height: 12),
                    ToggleSwitch(
                      checked: pinned,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => pinned = value),
                      content: Text(l10n.pinTask),
                    ),
                  ],
                  if (capability.supportsSubtaskVisibility) ...[
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: hideSubtasks,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => hideSubtasks = value),
                      content: Text(l10n.hideSubtasks),
                    ),
                    const SizedBox(height: 8),
                    ToggleSwitch(
                      checked: hideCompletedSubtasks,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setState(() => hideCompletedSubtasks = value),
                      content: Text(l10n.hideClosedSubtasks),
                    ),
                  ],
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.notes,
                    child: TextBox(controller: notes, maxLines: 4),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    InfoBar(
                      title: Text(error!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: saving
                    ? null
                    : () async {
                        if (hasPendingEdits() &&
                            !await _confirmDiscardNewTaskChanges(context)) {
                          return;
                        }
                        closeDialog();
                      },
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed:
                    saving ||
                        title.text.trim().isEmpty ||
                        !validUrl ||
                        !validSchedule
                    ? null
                    : () async {
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final fields = buildWindowsTaskCreateFields(
                            capability: capability,
                            provider: provider,
                            due: due,
                            start: start,
                            reminder: reminder,
                            alarms: alarms,
                            scheduledAllDay: scheduledAllDay,
                            timeZone: selectedTimeZone,
                            recurrence: recurrence,
                            importance: importance,
                            status: status,
                            priority: priority,
                            progress: progress,
                            location: location.text,
                            taskUrl: taskUrl.text,
                            classification: classification,
                            pinned: pinned,
                            hideSubtasks: hideSubtasks,
                            hideCompletedSubtasks: hideCompletedSubtasks,
                          );
                          await ref
                              .read(
                                tasksRepositoryForAccountProvider(
                                  selectedList.accountId,
                                ),
                              )
                              .createTask(
                                selectedList.id,
                                TaskCreateInput(
                                  title: title.text.trim(),
                                  notes: notes.text.trim(),
                                  dueUtc: due?.toUtc(),
                                  categories: _categories(categories.text),
                                  fields: fields,
                                ),
                              );
                          saved = true;
                          closeDialog();
                        } on Object catch (_) {
                          setState(() {
                            saving = false;
                            error = l10n.operationFailed;
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(),
                      )
                    : Text(l10n.create),
              ),
            ],
          ),
        );
      },
    ),
  );
  title.dispose();
  notes.dispose();
  location.dispose();
  taskUrl.dispose();
  categories.dispose();
  return saved;
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.showTime,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final bool showTime;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

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
        if (showTime && value != null)
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

String _newTaskAlarmLabel(BuildContext context, IcalTaskAlarm alarm) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = alarm.absoluteUtc!.toLocal();
  return l10n.dateTimeDisplay(
    DateFormat.yMMMd(locale).format(local),
    DateFormat.jm(locale).format(local),
  );
}

Future<DateTime?> _showTaskReminderDialog(
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

Future<bool> _confirmDiscardNewTaskChanges(BuildContext context) async {
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

RecurrenceRule _simpleRecurrenceRule(
  RecurrenceFrequency frequency,
  DateTime baseDate,
) {
  if (frequency == RecurrenceFrequency.none) {
    return const RecurrenceRule.none();
  }
  return RecurrenceRule(
    frequency: frequency,
    interval: 1,
    byDay: frequency == RecurrenceFrequency.weekly
        ? [rfcWeekdays[baseDate.weekday - 1]]
        : const [],
    byMonth: frequency == RecurrenceFrequency.yearly
        ? [baseDate.month]
        : const [],
    byMonthDay:
        frequency == RecurrenceFrequency.monthly ||
            frequency == RecurrenceFrequency.yearly
        ? [baseDate.day]
        : const [],
    bySetPosition: null,
    count: null,
    untilRaw: null,
    recurrenceDates: const [],
    exceptionDates: const [],
    rawRules: const [],
    isSupported: true,
  );
}

String _recurrenceLabel(AppLocalizations l10n, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => l10n.repeatNone,
      RecurrenceFrequency.daily => l10n.repeatDaily,
      RecurrenceFrequency.weekly => l10n.repeatWeekly,
      RecurrenceFrequency.monthly => l10n.repeatMonthly,
      RecurrenceFrequency.yearly => l10n.repeatYearly,
    };

String _priorityLabel(AppLocalizations l10n, int priority) => priority == 0
    ? l10n.priorityNone
    : priority <= 4
    ? l10n.priorityHighValue(priority)
    : priority == 5
    ? l10n.priorityMediumValue(priority)
    : l10n.priorityLowValue(priority);

List<String> _categories(String value) => [
  for (final category in value.split(','))
    if (category.trim().isNotEmpty) category.trim(),
];

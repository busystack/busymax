import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_colors.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/accounts/domain/account_collection_creation_capabilities.dart';
import '../../features/calendar/data/calendar_collection_creation_service.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_filters.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';

class WindowsScheduleSourcePane extends ConsumerStatefulWidget {
  const WindowsScheduleSourcePane({
    required this.selectedDate,
    required this.accounts,
    required this.calendarSources,
    required this.taskLists,
    required this.visibleCalendarSourceIds,
    required this.visibleTaskListKeys,
    required this.onDateSelected,
    required this.onCalendarVisibilityChanged,
    required this.onTaskListVisibilityChanged,
    required this.onSourcesChanged,
    super.key,
  });

  final DateTime selectedDate;
  final List<AccountEntity> accounts;
  final List<CalendarSourceEntity> calendarSources;
  final List<TaskListEntity> taskLists;
  final Set<String> visibleCalendarSourceIds;
  final Set<ScheduleTaskListKey> visibleTaskListKeys;
  final ValueChanged<DateTime> onDateSelected;
  final void Function(CalendarSourceEntity source, bool visible)
  onCalendarVisibilityChanged;
  final void Function(TaskListEntity list, bool visible)
  onTaskListVisibilityChanged;
  final VoidCallback onSourcesChanged;

  @override
  ConsumerState<WindowsScheduleSourcePane> createState() =>
      _WindowsScheduleSourcePaneState();
}

class _WindowsScheduleSourcePaneState
    extends ConsumerState<WindowsScheduleSourcePane> {
  late DateTime _displayedMonth = DateTime(
    widget.selectedDate.year,
    widget.selectedDate.month,
  );

  @override
  void didUpdateWidget(covariant WindowsScheduleSourcePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _displayedMonth = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ColoredBox(
      color: FluentTheme.of(context).cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _MiniMonth(
              displayedMonth: _displayedMonth,
              selectedDate: widget.selectedDate,
              locale: locale,
              onPrevious: () => setState(() {
                _displayedMonth = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month - 1,
                );
              }),
              onNext: () => setState(() {
                _displayedMonth = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month + 1,
                );
              }),
              onSelected: widget.onDateSelected,
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final account in widget.accounts) ...[
                  _AccountHeader(
                    account: account,
                    capabilities: AccountCollectionCreationCapabilities.resolve(
                      account: account,
                      networkAvailability:
                          ref.watch(networkAvailabilityProvider).valueOrNull ??
                          ref
                              .read(networkConnectivityMonitorProvider)
                              .availability,
                    ),
                    onCreateCalendar: () => unawaited(_createCalendar(account)),
                    onCreateTaskList: () => unawaited(_createTaskList(account)),
                  ),
                  for (final source in widget.calendarSources.where(
                    (source) =>
                        source.accountId == account.id &&
                        !source.hidden &&
                        !source.isDeleted,
                  ))
                    _VisibilityRow(
                      icon: BusyMaxGlyph.calendar,
                      title: source.summary,
                      checked: widget.visibleCalendarSourceIds.contains(
                        source.id,
                      ),
                      onChanged: (value) =>
                          widget.onCalendarVisibilityChanged(source, value),
                      menuItems: _calendarMenuItems(context, source),
                    ),
                  for (final list in widget.taskLists.where(
                    (list) =>
                        list.accountId == account.id && !list.pendingDelete,
                  ))
                    _VisibilityRow(
                      icon: BusyMaxGlyph.task,
                      title: list.title,
                      checked: widget.visibleTaskListKeys.contains(
                        ScheduleTaskListKey(
                          accountId: list.accountId,
                          taskListId: list.id,
                        ),
                      ),
                      onChanged: (value) =>
                          widget.onTaskListVisibilityChanged(list, value),
                      menuItems: _taskListMenuItems(context, account, list),
                    ),
                ],
                if (widget.calendarSources.isEmpty && widget.taskLists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.scheduleNoSources),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<MenuFlyoutItem> _calendarMenuItems(
    BuildContext context,
    CalendarSourceEntity source,
  ) {
    final l10n = AppLocalizations.of(context);
    return [
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.reminder)),
        text: Text(
          '${l10n.eventReminders} — '
          '${source.remindersEnabled ? l10n.onState : l10n.off}',
        ),
        onPressed: () => unawaited(_toggleCalendarReminders(source)),
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.settings)),
        text: Text(l10n.calendarColor),
        onPressed: source.capabilities.canChangeCalendarColor
            ? () => unawaited(_changeCalendarColor(source))
            : null,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.edit)),
        text: Text(l10n.rename),
        onPressed: source.capabilities.canRenameCalendar
            ? () => unawaited(_renameCalendar(source))
            : null,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.delete)),
        text: Text(
          source.capabilities.removalMode == CalendarRemovalMode.removeFromList
              ? l10n.removeFromMyCalendars
              : l10n.delete,
        ),
        onPressed: source.capabilities.canRemoveCalendar
            ? () => unawaited(_deleteCalendar(source))
            : null,
      ),
    ];
  }

  List<MenuFlyoutItem> _taskListMenuItems(
    BuildContext context,
    AccountEntity account,
    TaskListEntity list,
  ) {
    final l10n = AppLocalizations.of(context);
    final davCapabilities = list.davCollectionId == null
        ? null
        : ref
              .watch(
                davTaskCollectionCapabilitiesProvider((
                  accountId: list.accountId,
                  taskListId: list.id,
                )),
              )
              .valueOrNull;
    final canRename = account.provider == BusyProvider.microsoft
        ? list.canRenameOrDeleteForMicrosoft
        : list.davCollectionId != null
        ? davCapabilities?.supportsListRename ?? false
        : true;
    final canDelete = account.provider == BusyProvider.microsoft
        ? list.canRenameOrDeleteForMicrosoft
        : list.davCollectionId != null
        ? davCapabilities?.supportsListDelete ?? false
        : true;
    return [
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.reminder)),
        text: Text(
          '${l10n.taskReminders} — '
          '${list.remindersEnabled ? l10n.onState : l10n.off}',
        ),
        onPressed: () => unawaited(_toggleTaskListReminders(list)),
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.edit)),
        text: Text(l10n.rename),
        onPressed: canRename ? () => unawaited(_renameTaskList(list)) : null,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.delete)),
        text: Text(list.isShared == true ? l10n.unshare : l10n.deleteList),
        onPressed: canDelete ? () => unawaited(_deleteTaskList(list)) : null,
      ),
    ];
  }

  Future<void> _createCalendar(AccountEntity account) async {
    final title = await _textPrompt(
      title: AppLocalizations.of(context).newCalendar,
      actionLabel: AppLocalizations.of(context).create,
    );
    if (title == null || !mounted) return;
    await _runMutation(() async {
      final result = await ref
          .read(calendarCollectionCreationServiceProvider)
          .createCalendar(accountId: account.id, title: title);
      if (result.outcome ==
              CalendarCollectionCreationOutcome.createdRefreshPending &&
          mounted) {
        await _showMessage(
          AppLocalizations.of(context).calendarCreatedRefreshPending,
        );
      }
    });
  }

  Future<void> _createTaskList(AccountEntity account) async {
    final title = await _textPrompt(
      title: AppLocalizations.of(context).newTaskList,
      actionLabel: AppLocalizations.of(context).create,
    );
    if (title == null || !mounted) return;
    await _runMutation(
      () => ref
          .read(taskListsRepositoryForAccountProvider(account.id))
          .createTaskList(title),
    );
  }

  Future<void> _toggleCalendarReminders(CalendarSourceEntity source) =>
      _runMutation(
        () => ref
            .read(calendarRepositoryProvider)
            .setSourceRemindersEnabled(source.id, !source.remindersEnabled),
      );

  Future<void> _toggleTaskListReminders(TaskListEntity list) => _runMutation(
    () => ref
        .read(taskListsRepositoryForAccountProvider(list.accountId))
        .setRemindersEnabled(list.id, !list.remindersEnabled),
  );

  Future<void> _changeCalendarColor(CalendarSourceEntity source) async {
    final choices = calendarColorChoices(source.provider);
    final choice = await showDialog<CalendarColorChoice>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(AppLocalizations.of(context).calendarColor),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        content: ListView(
          shrinkWrap: true,
          children: [
            for (var index = 0; index < choices.length; index += 1)
              ListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _colorFromHex(choices[index].backgroundColor),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context).calendarColorOption(index + 1),
                ),
                trailing: _isCurrentCalendarColor(source, choices[index])
                    ? Icon(windowsBusyMaxGlyph(BusyMaxGlyph.check))
                    : null,
                onPressed: () => Navigator.pop(dialogContext, choices[index]),
              ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _runCalendarMutation(
      source.accountId,
      () => ref
          .read(calendarRepositoryProvider)
          .setSourceColor(source.id, choice),
    );
  }

  Future<void> _renameCalendar(CalendarSourceEntity source) async {
    final title = await _textPrompt(
      title: source.capabilities.renameMode == CalendarRenameMode.personal
          ? AppLocalizations.of(context).setCustomCalendarName
          : AppLocalizations.of(context).rename,
      actionLabel: AppLocalizations.of(context).rename,
      initialValue: source.summary,
    );
    if (title == null || title == source.summary || !mounted) return;
    await _runCalendarMutation(
      source.accountId,
      () => ref
          .read(calendarRepositoryProvider)
          .renameLocalSource(source.id, title),
    );
  }

  Future<void> _deleteCalendar(CalendarSourceEntity source) async {
    final l10n = AppLocalizations.of(context);
    final removeFromList =
        source.capabilities.removalMode == CalendarRemovalMode.removeFromList;
    final confirmed = await _confirm(
      title: removeFromList ? l10n.removeFromMyCalendars : l10n.delete,
      message: removeFromList
          ? l10n.removeCalendarConfirmation(source.summary)
          : l10n.deleteCalendarConfirmation(source.summary),
      actionLabel: removeFromList ? l10n.removeAction : l10n.delete,
    );
    if (!confirmed || !mounted) return;
    await _runCalendarMutation(
      source.accountId,
      () => ref.read(calendarRepositoryProvider).deleteLocalSource(source.id),
    );
  }

  Future<void> _renameTaskList(TaskListEntity list) async {
    final l10n = AppLocalizations.of(context);
    final title = await _textPrompt(
      title: l10n.renameList,
      actionLabel: l10n.rename,
      initialValue: list.title,
    );
    if (title == null || title == list.title || !mounted) return;
    await _runMutation(
      () => ref
          .read(taskListsRepositoryForAccountProvider(list.accountId))
          .renameTaskList(list.id, title),
    );
  }

  Future<void> _deleteTaskList(TaskListEntity list) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: list.isShared == true ? l10n.unshare : l10n.deleteList,
      message: list.isShared == true
          ? l10n.unshareTaskListConfirmation(list.title)
          : l10n.deleteTaskListConfirmation(list.title),
      actionLabel: list.isShared == true ? l10n.unshare : l10n.delete,
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => ref
          .read(taskListsRepositoryForAccountProvider(list.accountId))
          .deleteTaskList(list.id),
    );
  }

  Future<void> _runCalendarMutation(
    String accountId,
    Future<void> Function() operation,
  ) => _runMutation(() async {
    await operation();
    ref
        .read(pendingCalendarMutationSyncRequesterForAccountProvider(accountId))
        .request();
  });

  Future<void> _runMutation(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) widget.onSourcesChanged();
    } on Object {
      if (mounted) {
        await _showMessage(AppLocalizations.of(context).operationFailed);
      }
    }
  }

  Future<String?> _textPrompt({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ContentDialog(
        title: Text(title),
        content: InfoLabel(
          label: AppLocalizations.of(context).title,
          child: TextBox(controller: controller, autofocus: true),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ContentDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(actionLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showMessage(String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    ),
  );
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.account,
    required this.capabilities,
    required this.onCreateCalendar,
    required this.onCreateTaskList,
  });

  final AccountEntity account;
  final AccountCollectionCreationCapabilities capabilities;
  final VoidCallback onCreateCalendar;
  final VoidCallback onCreateTaskList;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            account.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption,
          ),
        ),
        if (capabilities.hasActions)
          DropDownButton(
            title: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add), size: 16),
            items: [
              if (capabilities.supportsCalendarCreation)
                MenuFlyoutItem(
                  leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar)),
                  text: Text(AppLocalizations.of(context).newCalendar),
                  onPressed: capabilities.calendarActionEnabled
                      ? onCreateCalendar
                      : null,
                ),
              if (capabilities.supportsTaskListCreation)
                MenuFlyoutItem(
                  leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.task)),
                  text: Text(AppLocalizations.of(context).newTaskList),
                  onPressed: capabilities.taskListActionEnabled
                      ? onCreateTaskList
                      : null,
                ),
            ],
          ),
      ],
    ),
  );
}

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({
    required this.icon,
    required this.title,
    required this.checked,
    required this.onChanged,
    required this.menuItems,
  });

  final BusyMaxGlyph icon;
  final String title;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final List<MenuFlyoutItem> menuItems;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      checked: checked,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 3, 8, 3),
        child: Row(
          children: [
            Checkbox(
              checked: checked,
              onChanged: (value) => onChanged(value ?? false),
            ),
            const SizedBox(width: 8),
            Icon(windowsBusyMaxGlyph(icon), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            DropDownButton(
              title: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more), size: 16),
              items: menuItems,
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorFromHex(String source) {
  final hex = source.trim().replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return Color(parsed == null ? 0xFF0078D4 : 0xFF000000 | parsed);
}

bool _isCurrentCalendarColor(
  CalendarSourceEntity source,
  CalendarColorChoice choice,
) => switch (source.provider) {
  BusyProvider.google =>
    source.backgroundColor?.toLowerCase() ==
        choice.backgroundColor.toLowerCase(),
  BusyProvider.microsoft => source.colorId == choice.providerValue,
  _ => false,
};

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.displayedMonth,
    required this.selectedDate,
    required this.locale,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final String locale;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(displayedMonth.year, displayedMonth.month);
    final gridStart = DateTime(
      first.year,
      first.month,
      first.day - (first.weekday - DateTime.monday),
    );
    final days = [
      for (var offset = 0; offset < 42; offset += 1)
        DateTime(gridStart.year, gridStart.month, gridStart.day + offset),
    ];
    final weekdayBase = DateTime(2026, 1, 5);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM(locale).format(displayedMonth),
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
            ),
            IconButton(
              icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.previous)),
              onPressed: onPrevious,
            ),
            IconButton(
              icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.next)),
              onPressed: onNext,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var index = 0; index < 7; index += 1)
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat.E(
                      locale,
                    ).format(weekdayBase.add(Duration(days: index))),
                    maxLines: 1,
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        for (var week = 0; week < 6; week += 1)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday += 1)
                Expanded(
                  child: _MiniDayButton(
                    day: days[week * 7 + weekday],
                    inMonth:
                        days[week * 7 + weekday].month == displayedMonth.month,
                    selected: _sameDay(days[week * 7 + weekday], selectedDate),
                    onSelected: onSelected,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MiniDayButton extends StatelessWidget {
  const _MiniDayButton({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.onSelected,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 26,
      child: Center(child: Text('${day.day}')),
    );
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Opacity(
        opacity: inMonth || selected ? 1 : 0.55,
        child: selected
            ? FilledButton(onPressed: () => onSelected(day), child: child)
            : Button(onPressed: () => onSelected(day), child: child),
      ),
    );
  }
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

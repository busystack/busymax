import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../l10n/l10n.dart';
import '../platform/linux_header_bar_service.dart';
import 'busymax_design.dart';
import 'busymax_dialog_identity.dart';
import 'busymax_dialogs.dart';
import 'busymax_shortcuts.dart';

Future<void> showBusyMaxKeyboardShortcutsDialog(
  BuildContext context, {
  LinuxHeaderBarService? headerBarService,
}) async {
  await showBusyMaxModalDialog<void>(
    context,
    headerBarService: headerBarService,
    builder: (context) => const BusyMaxKeyboardShortcutsDialog(),
  );
}

class BusyMaxKeyboardShortcutsDialog extends StatelessWidget {
  const BusyMaxKeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return BusyMaxInformationalDialog(
      closeLabel: l10n.close,
      maxWidth: 460,
      maxHeight: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BusyMaxDialogIdentity(
            visual: Icon(
              YaruIcons.keyboard_shortcuts,
              size: BusyMaxDialogIdentity.visualExtent,
              color: colorScheme.primary,
            ),
            title: l10n.keyboardShortcuts,
          ),
          const SizedBox(height: BusyMaxSpacing.lg),
          BusyMaxGroupedList(
            title: l10n.shortcutGroupGeneral,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.keyboardShortcuts,
                subtitle: l10n.shortcutKeyboardShortcutsDescription,
                leading: const Icon(YaruIcons.keyboard_shortcuts),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.keyboardShortcuts,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.settings,
                leading: const Icon(Icons.settings_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.settings,
                ),
              ),
              BusyMaxActionRow(
                title: MaterialLocalizations.of(context).searchFieldLabel,
                leading: const Icon(Icons.search),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.search,
                ),
              ),
            ],
          ),
          BusyMaxGroupedList(
            title: l10n.shortcutGroupNavigation,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.toggleSidebar,
                leading: const Icon(Icons.vertical_split_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.sidebar,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutNextPeriod,
                subtitle: l10n.shortcutNextPeriodDescription,
                leading: const Icon(Icons.arrow_forward),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.nextPeriod,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutPreviousPeriod,
                subtitle: l10n.shortcutPreviousPeriodDescription,
                leading: const Icon(Icons.arrow_back),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.previousPeriod,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutJumpToToday,
                leading: const Icon(Icons.today_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.today,
                ),
              ),
            ],
          ),
          BusyMaxGroupedList(
            title: l10n.shortcutGroupCreateAndEdit,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.newEvent,
                leading: const Icon(Icons.event_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.newEvent,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.newTask,
                leading: const Icon(Icons.task_alt_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.newTask,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutSaveItem,
                leading: const Icon(Icons.save_outlined),
                trailing: const _KeyboardShortcutBadge('Ctrl+S'),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutDeleteItem,
                leading: const Icon(Icons.delete_outline),
                trailing: const _KeyboardShortcutBadge('Backspace / Delete'),
              ),
            ],
          ),
          BusyMaxGroupedList(
            title: l10n.shortcutGroupTaskEditing,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.shortcutCancelEditing,
                subtitle: l10n.shortcutCancelEditingDescription,
                leading: const Icon(Icons.close),
                trailing: const _KeyboardShortcutBadge('Esc'),
              ),
            ],
          ),
          BusyMaxGroupedList(
            title: l10n.shortcutGroupView,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.shortcutDayView,
                leading: const Icon(Icons.calendar_view_day_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.dayView,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutWeekView,
                leading: const Icon(Icons.view_week_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.weekView,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutMonthView,
                leading: const Icon(Icons.calendar_view_month),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.monthView,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutYearView,
                leading: const Icon(Icons.calendar_today_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.yearView,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.shortcutAgendaView,
                leading: const Icon(Icons.view_agenda_outlined),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.agendaView,
                ),
              ),
            ],
          ),
          BusyMaxGroupedList(
            title: l10n.shortcutGroupCompactAgenda,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.compactAgendaRefresh,
                subtitle: l10n.shortcutRefreshCompactAgendaDescription,
                leading: const Icon(Icons.refresh),
                trailing: const _KeyboardShortcutBadge(
                  BusyMaxShortcutLabels.refreshCompactAgenda,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.compactAgendaHide,
                subtitle: l10n.shortcutHideCompactAgendaDescription,
                leading: const Icon(Icons.visibility_off_outlined),
                trailing: const _KeyboardShortcutBadge('Esc'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyboardShortcutBadge extends StatelessWidget {
  const _KeyboardShortcutBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Flexible(
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BusyMaxSpacing.sm,
              vertical: BusyMaxSpacing.xxs,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ),
    );
  }
}

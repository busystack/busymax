import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../platform/linux_header_bar_service.dart';
import 'busymax_design.dart';
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(BusyMaxSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: BusyMaxSpacing.md),
                  Text(
                    l10n.keyboardShortcuts,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: BusyMaxSpacing.lg),
                  BusyMaxGroupedList(
                    title: l10n.shortcutGroupGeneral,
                    filled: true,
                    children: [
                      BusyMaxActionRow(
                        title: l10n.keyboardShortcuts,
                        subtitle: l10n.shortcutKeyboardShortcutsDescription,
                        leading: const Icon(Icons.keyboard_alt_outlined),
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
                        title: MaterialLocalizations.of(
                          context,
                        ).searchFieldLabel,
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
                        title: l10n.shortcutNextPeriod,
                        subtitle: l10n.shortcutNextPeriodDescription,
                        leading: const Icon(Icons.arrow_forward),
                        trailing: const _KeyboardShortcutBadge('Shift+Right'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutPreviousPeriod,
                        subtitle: l10n.shortcutPreviousPeriodDescription,
                        leading: const Icon(Icons.arrow_back),
                        trailing: const _KeyboardShortcutBadge('Shift+Left'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutJumpToToday,
                        leading: const Icon(Icons.today_outlined),
                        trailing: const _KeyboardShortcutBadge('Shift+T'),
                      ),
                    ],
                  ),
                  BusyMaxGroupedList(
                    title: l10n.shortcutGroupCreateAndEdit,
                    filled: true,
                    children: [
                      BusyMaxActionRow(
                        title: l10n.create,
                        leading: const Icon(Icons.add),
                        trailing: const _KeyboardShortcutBadge(
                          BusyMaxShortcutLabels.create,
                        ),
                      ),
                      BusyMaxActionRow(
                        title: l10n.newEvent,
                        leading: const Icon(Icons.event_outlined),
                        trailing: const _KeyboardShortcutBadge('E'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.newTask,
                        leading: const Icon(Icons.task_alt_outlined),
                        trailing: const _KeyboardShortcutBadge('T'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutSaveItem,
                        leading: const Icon(Icons.save_outlined),
                        trailing: const _KeyboardShortcutBadge('Ctrl+S'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutDeleteItem,
                        leading: const Icon(Icons.delete_outline),
                        trailing: const _KeyboardShortcutBadge(
                          'Backspace / Delete',
                        ),
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
                        trailing: const _KeyboardShortcutBadge('1 / D'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutWeekView,
                        leading: const Icon(Icons.view_week_outlined),
                        trailing: const _KeyboardShortcutBadge('2 / W'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutMonthView,
                        leading: const Icon(Icons.calendar_view_month),
                        trailing: const _KeyboardShortcutBadge('3 / M'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutYearView,
                        leading: const Icon(Icons.calendar_today_outlined),
                        trailing: const _KeyboardShortcutBadge('4 / Y'),
                      ),
                      BusyMaxActionRow(
                        title: l10n.shortcutAgendaView,
                        leading: const Icon(Icons.view_agenda_outlined),
                        trailing: const _KeyboardShortcutBadge('0 / A'),
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
                        trailing: const _KeyboardShortcutBadge('Ctrl+R'),
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
            ),
            PositionedDirectional(
              top: BusyMaxSpacing.sm,
              end: BusyMaxSpacing.sm,
              child: BusyMaxDialogCloseButton(
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
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
    return DecoratedBox(
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
    );
  }
}

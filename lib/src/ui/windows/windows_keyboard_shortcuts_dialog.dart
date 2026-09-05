import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/busymax_shortcuts.dart';

Future<void> showWindowsKeyboardShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return ContentDialog(
        title: Text(l10n.keyboardShortcuts),
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
        content: ListView(
          shrinkWrap: true,
          children: [
            _ShortcutGroup(
              title: l10n.shortcutGroupGeneral,
              entries: [
                (
                  l10n.keyboardShortcuts,
                  BusyMaxShortcutLabels.keyboardShortcuts,
                ),
                (l10n.settings, BusyMaxShortcutLabels.settings),
                (l10n.windowsSearch, BusyMaxShortcutLabels.search),
                (l10n.showSidebar, BusyMaxShortcutLabels.sidebar),
              ],
            ),
            _ShortcutGroup(
              title: l10n.shortcutGroupNavigation,
              entries: [
                (
                  l10n.shortcutPreviousPeriod,
                  BusyMaxShortcutLabels.previousPeriod,
                ),
                (l10n.shortcutNextPeriod, BusyMaxShortcutLabels.nextPeriod),
                (l10n.shortcutJumpToToday, BusyMaxShortcutLabels.today),
              ],
            ),
            _ShortcutGroup(
              title: l10n.shortcutGroupView,
              entries: [
                (l10n.viewDay, BusyMaxShortcutLabels.dayView),
                (l10n.viewWeek, BusyMaxShortcutLabels.weekView),
                (l10n.viewMonth, BusyMaxShortcutLabels.monthView),
                (l10n.viewYear, BusyMaxShortcutLabels.yearView),
                (l10n.viewAgenda, BusyMaxShortcutLabels.agendaView),
              ],
            ),
            _ShortcutGroup(
              title: l10n.shortcutGroupCreateAndEdit,
              entries: [
                (l10n.newEvent, BusyMaxShortcutLabels.newEvent),
                (l10n.newTask, BusyMaxShortcutLabels.newTask),
                (l10n.shortcutCancelEditing, BusyMaxShortcutLabels.dismiss),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      );
    },
  );
}

class _ShortcutGroup extends StatelessWidget {
  const _ShortcutGroup({required this.title, required this.entries});

  final String title;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: FluentTheme.of(context).typography.subtitle),
        const SizedBox(height: 8),
        for (final (label, shortcut) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: FluentTheme.of(
                        context,
                      ).resources.controlStrokeColorDefault,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(shortcut),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

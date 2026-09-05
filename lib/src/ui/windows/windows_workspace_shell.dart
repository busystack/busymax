import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/busymax_shortcuts.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_keyboard_shortcuts_dialog.dart';

enum WindowsWorkspaceDestination { schedule, tasks, settings }

class WindowsWorkspaceShell extends StatelessWidget {
  const WindowsWorkspaceShell({
    required this.destination,
    required this.child,
    super.key,
  });

  final WindowsWorkspaceDestination destination;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = destination.index;
    return CallbackShortcuts(
      bindings: {
        BusyMaxShortcutActivators.settings: () => context.go('/settings'),
        BusyMaxShortcutActivators.keyboardShortcuts: () =>
            showWindowsKeyboardShortcutsDialog(context),
      },
      child: Focus(
        autofocus: true,
        child: NavigationView(
          pane: NavigationPane(
            selected: selected,
            displayMode: PaneDisplayMode.compact,
            size: const NavigationPaneSize(compactWidth: 48, openWidth: 240),
            header: const Padding(
              padding: EdgeInsetsDirectional.only(start: 12),
              child: Text('BusyMax'),
            ),
            onChanged: (index) {
              context.go(switch (index) {
                0 => '/schedule',
                1 => '/tasks',
                _ => '/settings',
              });
            },
            items: [
              PaneItem(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar)),
                title: Text(l10n.calendar),
                body: selected == 0 ? child : const SizedBox.shrink(),
              ),
              PaneItem(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.task)),
                title: Text(l10n.tasks),
                body: selected == 1 ? child : const SizedBox.shrink(),
              ),
            ],
            footerItems: [
              PaneItem(
                icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.settings)),
                title: Text(l10n.settings),
                body: selected == 2 ? child : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

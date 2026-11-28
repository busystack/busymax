import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:yaru/yaru.dart';

import '../../app/busymax_design.dart';
import '../../l10n/l10n.dart';
import '../../schedule/schedule_item.dart';
import 'journal_desktop_files.dart';
import 'journal_pane.dart';
import 'linux_journal_controls.dart';

Future<void> showLinuxJournalDialog(
  BuildContext context,
  JournalPaneAction action, {
  JournalScheduleItem? item,
  String? sourceId,
  String? accountId,
  DateTime? initialDate,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => BusyMaxSurfaceScope(
    role: BusyMaxSurfaceRole.dialog,
    child: Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: BusyMaxSizes.detailsWidth,
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            BusyMaxDialogTitleBar(
              title: Text(journalPaneTitle(context.l10n, action)),
            ),
            Expanded(
              child: JournalPane(
                action: action,
                item: item,
                sourceId: sourceId,
                accountId: accountId,
                initialDate: initialDate,
                controls: const LinuxJournalControls(),
                files: journalDesktopFiles,
                onClose: () => Navigator.of(context).pop(),
                detailActions: (actions) => Wrap(
                  spacing: BusyMaxSpacing.xs,
                  runSpacing: BusyMaxSpacing.xs,
                  children: [
                    for (final action in actions)
                      BusyMaxPopoverIconButton(
                        icon: switch (action.icon) {
                          JournalDetailAction.share => YaruIcons.share,
                          JournalDetailAction.edit => YaruIcons.pen,
                          JournalDetailAction.delete => YaruIcons.trash,
                          JournalDetailAction.close => YaruIcons.window_close,
                        },
                        tooltip: action.label,
                        destructive: action.icon == JournalDetailAction.delete,
                        onPressed: action.run,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:yaru/yaru.dart';

import '../../app/busymax_design.dart';
import '../../features/schedule/presentation/schedule_anchored_popover.dart';
import '../../l10n/l10n.dart';
import '../../schedule/schedule_item.dart';
import 'journal_desktop_files.dart';
import 'journal_pane.dart';
import 'linux_journal_controls.dart';

Future<void> showLinuxJournalDetails(
  BuildContext context, {
  required BuildContext anchorContext,
  required JournalScheduleItem item,
  Offset? anchorPoint,
}) async {
  final selection = await showScheduleAnchoredPopover<({bool? future})>(
    context: context,
    anchorContext: anchorContext,
    anchorPoint: anchorPoint,
    semanticLabel: item.title,
    builder: (context, arrowSide, arrowAlignment) => Material(
      color: Colors.transparent,
      child: BusyMaxContentPopoverSurface(
        arrowSide: arrowSide,
        arrowAlignment: arrowAlignment,
        child: JournalPane(
          action: JournalPaneAction.open,
          item: item,
          controls: const LinuxJournalControls(),
          files: journalDesktopFiles,
          detailActions: _detailActions,
          onClose: () => Navigator.of(context).pop(),
          onEditRequested: (future) {
            if (ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pop((future: future));
            }
          },
        ),
      ),
    ),
  );
  if (selection == null || !context.mounted) return;
  await showLinuxJournalDialog(
    context,
    JournalPaneAction.open,
    item: item,
    initialOccurrenceScope: selection.future,
  );
}

Future<void> showLinuxJournalDialog(
  BuildContext context,
  JournalPaneAction action, {
  JournalScheduleItem? item,
  String? sourceId,
  String? accountId,
  DateTime? initialDate,
  bool? initialOccurrenceScope,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    final editing =
        action == JournalPaneAction.create || action == JournalPaneAction.open;
    final pane = JournalPane(
      action: action,
      item: item,
      sourceId: sourceId,
      accountId: accountId,
      initialDate: initialDate,
      editOnOpen: editing,
      initialOccurrenceScope: initialOccurrenceScope,
      controls: const LinuxJournalControls(),
      files: journalDesktopFiles,
      onClose: () => Navigator.of(context).pop(),
      detailActions: _detailActions,
    );
    if (editing) {
      return BusyMaxModalEditorSurface(
        maxWidth: BusyMaxSizes.detailsWidth,
        insetPadding: const EdgeInsets.all(BusyMaxSpacing.md),
        child: SizedBox(
          width: BusyMaxSizes.detailsWidth,
          height: MediaQuery.sizeOf(context).height * .85,
          child: pane,
        ),
      );
    }
    return BusyMaxSurfaceScope(
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
              Expanded(child: pane),
            ],
          ),
        ),
      ),
    );
  },
);

Widget _detailActions(
  List<({String label, JournalDetailAction icon, VoidCallback? run})> actions,
) => Wrap(
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
);

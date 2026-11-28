import '../../journal/presentation/journal_desktop_files.dart';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../schedule/schedule_item.dart';
import '../../app/busymax_window_close.dart';
import '../../journal/presentation/journal_pane.dart';
import 'windows_time_picker.dart';

final windowsJournalNavigation = BusyMaxWindowCloseCoordinator();

Future<void> showWindowsJournalDialog(
  BuildContext context,
  JournalPaneAction action, {
  JournalScheduleItem? item,
  String? sourceId,
  String? accountId,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => ContentDialog(
    constraints: const BoxConstraints(maxWidth: 680),
    title: Text(journalPaneTitle(AppLocalizations.of(context), action)),
    content: SizedBox(
      height: MediaQuery.sizeOf(context).height * .66,
      child: JournalPane(
        action: action,
        item: item,
        sourceId: sourceId,
        accountId: accountId,
        controls: const _WindowsJournalControls(),
        navigationCoordinator: windowsJournalNavigation,
        files: journalDesktopFiles,
        onClose: () => Navigator.of(context).pop(),
        detailActions: (actions) => Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final action in actions)
              windowsScheduleDetailButton(action.label, switch (action.icon) {
                JournalDetailAction.share => FluentIcons.share,
                JournalDetailAction.edit => FluentIcons.edit,
                JournalDetailAction.delete => FluentIcons.delete,
                JournalDetailAction.close => FluentIcons.chrome_close,
              }, action.run),
          ],
        ),
      ),
    ),
  ),
);

Widget windowsScheduleDetailButton(
  String label,
  IconData glyph,
  VoidCallback? onPressed,
) => Tooltip(
  message: label,
  child: Semantics(
    label: label,
    child: SizedBox.square(
      dimension: 32,
      child: IconButton(
        icon: Icon(glyph, size: 16),
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        onPressed: onPressed,
      ),
    ),
  ),
);

final class _WindowsJournalControls implements JournalControls {
  const _WindowsJournalControls();

  @override
  Widget input(
    String label, {
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: InfoLabel(
      label: label,
      child: TextBox(
        controller: controller,
        onChanged: onChanged,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 12,
      ),
    ),
  );

  @override
  Widget choose(
    String label,
    String selected,
    List<JournalChoice> choices,
    ValueChanged<String> change,
  ) => InfoLabel(
    label: label,
    child: ComboBox<String>(
      value: selected,
      items: [
        for (final choice in choices)
          ComboBoxItem<String>(value: choice.id, child: Text(choice.label)),
      ],
      onChanged: (value) {
        if (value != null) change(value);
      },
    ),
  );

  @override
  Widget button(String label, VoidCallback? action, {bool primary = false}) =>
      primary
      ? FilledButton(onPressed: action, child: Text(label))
      : Button(onPressed: action, child: Text(label));

  @override
  Widget pickDate(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  ) => InfoLabel(
    label: label,
    child: DatePicker(
      selected: current ?? DateTime.now(),
      startDate: DateTime(1),
      endDate: DateTime(9999, 12, 31),
      onChanged: change,
    ),
  );

  @override
  Widget pickTime(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  ) {
    final basis = current ?? DateTime.now();
    return InfoLabel(
      label: label,
      child: WindowsTimePicker(
        selected: basis,
        onChanged: (time) => change(
          DateTime(
            basis.year,
            basis.month,
            basis.day,
            time.hour,
            time.minute,
            basis.second,
          ),
        ),
      ),
    );
  }
}

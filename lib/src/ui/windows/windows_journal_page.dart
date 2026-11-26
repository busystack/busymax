import '../../journal/presentation/journal_desktop_files.dart';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../journal/presentation/journal_workspace.dart';
import 'windows_time_picker.dart';

class WindowsJournalPage extends StatelessWidget {
  const WindowsJournalPage({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldPage(
    header: PageHeader(title: Text(AppLocalizations.of(context).journals)),
    content: const JournalWorkspace(
      controls: _WindowsJournalControls(),
      files: journalDesktopFiles,
    ),
  );
}

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

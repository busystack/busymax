import '../../journal/presentation/journal_desktop_files.dart';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../journal/presentation/journal_workspace.dart';

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
}

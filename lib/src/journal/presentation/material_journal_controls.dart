import '../../ui/common/flutter_material.dart';
import 'journal_pane.dart';
import 'journal_material_pickers.dart';

final class MaterialJournalControls implements JournalControls {
  const MaterialJournalControls();

  @override
  Widget input(
    String label, {
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 12,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget choose(
    String label,
    String selected,
    List<JournalChoice> choices,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 232,
    child: DropdownButtonFormField<String>(
      key: ValueKey((label, selected)),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final choice in choices)
          DropdownMenuItem<String>(
            value: choice.id,
            child: Text(choice.label, overflow: TextOverflow.ellipsis),
          ),
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
      : OutlinedButton(onPressed: action, child: Text(label));

  @override
  Widget pickDate(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  ) => journalDatePicker(this, label, current, change);

  @override
  Widget pickTime(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  ) => journalTimePicker(this, label, current, change);
}

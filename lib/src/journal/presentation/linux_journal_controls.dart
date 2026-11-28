import '../../app/busymax_design.dart';
import '../../ui/common/flutter_material.dart';
import 'journal_pane.dart';
import 'journal_material_pickers.dart';

final class LinuxJournalControls implements JournalControls {
  const LinuxJournalControls();

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
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget choose(
    String label,
    String selected,
    List<JournalChoice> choices,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 320,
    child: BusyMaxComboRow<String>(
      title: label,
      values: choices.map((choice) => choice.id).toList(),
      selected: selected,
      labelFor: (id) => choices.firstWhere((choice) => choice.id == id).label,
      onSelected: change,
      wrapSelectedValue: true,
    ),
  );

  @override
  Widget button(String label, VoidCallback? action, {bool primary = false}) =>
      primary
      ? BusyMaxPushButton.suggested(onPressed: action, child: Text(label))
      : BusyMaxPushButton.standard(onPressed: action, child: Text(label));

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

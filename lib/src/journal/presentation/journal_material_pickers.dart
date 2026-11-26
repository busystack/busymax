import '../../ui/common/flutter_material.dart';
import 'journal_controls.dart';

Widget journalDatePicker(
  JournalControls controls,
  String label,
  DateTime? current,
  ValueChanged<DateTime> change,
) => Builder(
  builder: (context) => controls.button(label, () async {
    final first = DateTime(1), last = DateTime(9999, 12, 31);
    final selected = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: current ?? DateTime.now(),
    );
    if (selected != null && context.mounted) change(selected);
  }),
);

Widget journalTimePicker(
  JournalControls controls,
  String label,
  DateTime? current,
  ValueChanged<DateTime> change,
) => Builder(
  builder: (context) => controls.button(label, () async {
    final basis = current ?? DateTime.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(basis),
    );
    if (selected != null && context.mounted) {
      change(
        DateTime(
          basis.year,
          basis.month,
          basis.day,
          selected.hour,
          selected.minute,
          basis.second,
        ),
      );
    }
  }),
);

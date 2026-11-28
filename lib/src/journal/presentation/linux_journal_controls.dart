import '../../app/busymax_design.dart';
import '../../features/tasks/presentation/desktop_date_time_fields.dart';
import '../../ui/common/flutter_material.dart';

import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import 'journal_controls.dart';

final class LinuxJournalControls
    implements JournalControls, JournalEditorLayout {
  const LinuxJournalControls();

  @override
  Widget input(
    String label, {
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    int lines = 1,
  }) => YaruListTile.square(
    title: Builder(
      builder: (context) => TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 12,
        decoration: busyMaxGroupedTextFieldDecoration(
          context,
          labelText: label,
        ),
      ),
    ),
  );

  @override
  Widget choose(
    String label,
    String selected,
    List<JournalChoice> choices,
    ValueChanged<String> change,
  ) => BusyMaxComboRow<String>(
    title: label,
    values: choices.map((choice) => choice.id).toList(),
    selected: selected,
    labelFor: (id) => choices.firstWhere((choice) => choice.id == id).label,
    onSelected: change,
    wrapSelectedValue: true,
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
  ) => DesktopDateValueRow(
    label: label,
    date: current == null ? null : DateFormat('yyyy-MM-dd').format(current),
    onChanged: (value) => change(DateTime.parse(value)),
  );

  @override
  Widget pickTime(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  ) => timeField(label, current, change);

  @override
  Widget timeField(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change, {
    String? timeZone,
    ValueChanged<String>? onTimeZoneChanged,
    ValueChanged<bool>? onValidityChanged,
  }) => DesktopTimeValueRow(
    label: label,
    time: DateFormat('HH:mm').format(current ?? DateTime.now()),
    allowEmpty: false,
    useNativePicker: true,
    timeZone: timeZone,
    onTimeZoneChanged: onTimeZoneChanged,
    onValidityChanged: onValidityChanged,
    onChanged: (value) {
      if (value == null) return;
      final base = current ?? DateTime.now();
      final clock = value.split(':');
      change(
        DateTime.utc(
          base.year,
          base.month,
          base.day,
          int.parse(clock[0]),
          int.parse(clock[1]),
          base.second,
        ),
      );
    },
  );

  @override
  Widget editor({
    required String title,
    required String closeLabel,
    required String saveLabel,
    required VoidCallback close,
    required VoidCallback? save,
    required bool locked,
    required List<Widget> children,
  }) => BusyMaxModalEditorScaffold(
    title: title,
    cancelLabel: closeLabel,
    saveLabel: saveLabel,
    onCancel: close,
    onSave: save,
    cancelEnabled: !locked,
    children: children,
  );

  @override
  Widget group(List<Widget> children) =>
      BusyMaxGroupedList(filled: true, children: children);

  @override
  Widget timeMode(bool allDay, ValueChanged<bool> change) =>
      BusyMaxTimeModeRow(allDay: allDay, onChanged: change);

  @override
  Widget details(String label, VoidCallback action) => BusyMaxActionRow(
    title: label,
    leading: const Icon(YaruIcons.document),
    onTap: action,
  );
}

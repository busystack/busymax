import 'package:flutter/material.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';

import '../../../app/busymax_design.dart';
import '../../../features/calendar/data/calendar_repository.dart';

class SourcePicker extends StatelessWidget {
  const SourcePicker({
    super.key,
    required this.sources,
    required this.selectedSourceId,
    required this.onSelected,
    this.labelText,
    this.decoration,
  });

  final List<CalendarSourceEntity> sources;
  final String? selectedSourceId;
  final ValueChanged<CalendarSourceEntity> onSelected;
  final String? labelText;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final selected = sources.any((source) => source.id == selectedSourceId)
        ? selectedSourceId
        : sources.isEmpty
        ? null
        : sources.first.id;
    if (selected == null) {
      return const SizedBox.shrink();
    }
    final label = labelText;
    final inputDecoration =
        decoration ??
        (label == null
            ? busyMaxDropdownDecoration()
            : busyMaxDropdownDecoration().copyWith(
                labelText: label,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ));
    return MenuButtonBuilder<String>(
      selected: selected,
      values: [for (final source in sources) source.id],
      menuPosition: PopupMenuPosition.under,
      decoration: inputDecoration,
      style: busyMaxDropdownButtonStyle(context),
      menuStyle: busyMaxDropdownMenuStyle(context),
      itemStyle: busyMaxDropdownMenuItemStyle(context),
      itemBuilder: (context, value, _) {
        final source = sources.firstWhere((source) => source.id == value);
        return Text(source.summary, overflow: TextOverflow.ellipsis);
      },
      onSelected: (value) {
        final match = sources.firstWhere((source) => source.id == value);
        onSelected(match);
      },
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          sources.firstWhere((source) => source.id == selected).summary,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

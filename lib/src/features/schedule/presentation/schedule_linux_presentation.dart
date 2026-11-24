import '../../../schedule/schedule_item.dart';
import 'schedule_item_selection.dart';
import 'schedule_more_popover.dart';

import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../ui/common/schedule/schedule_presentation.dart';

/// Linux retains its existing controls while sharing schedule composition.
class LinuxSchedulePresentation extends SchedulePresentation {
  const LinuxSchedulePresentation();
  @override
  bool get touch => false;
  @override
  Future<void> showMore(
    BuildContext context,
    DateTime day,
    List<ScheduleItem> items,
    ScheduleItemSelectionCallback onSelected,
    void Function(TaskScheduleItem, bool) onCompletion,
  ) async {
    final selection = await showScheduleMorePopover(
      context: context,
      anchorContext: context,
      day: day,
      items: items,
      onTaskCompletionChanged: onCompletion,
    );
    if (selection != null && context.mounted) {
      onSelected(context, selection.item, selection.anchorPoint);
    }
  }

  @override
  IconData get calendarIcon => YaruIcons.calendar;
  @override
  IconData get taskIcon => YaruIcons.task_list;
  @override
  IconData get createIcon => YaruIcons.plus;
  @override
  IconData previousIcon(TextDirection direction) =>
      BusyMaxGlyphs.startFor(direction);
  @override
  IconData nextIcon(TextDirection direction) => BusyMaxGlyphs.endFor(direction);
  @override
  IconData subdirectoryIcon(TextDirection direction) =>
      BusyMaxGlyphs.subdirectoryFor(direction);
  @override
  Widget checkbox(
    BuildContext context,
    bool value,
    ValueChanged<bool?>? onChanged,
  ) => BusyMaxYaruFocusBorder(
    builder: (context, focusNode) => YaruCheckbox(
      value: value,
      focusNode: focusNode,
      hasFocusBorder: false,
      onChanged: onChanged,
    ),
  );
  @override
  Widget groupedSurface(BuildContext context, Widget child) =>
      BusyMaxGroupedSurface(child: child);
  @override
  Widget groupedList(
    BuildContext context,
    String? title,
    List<Widget> children,
  ) => BusyMaxGroupedList(title: title, filled: true, children: children);
  @override
  Widget actionRow(BuildContext context, ScheduleActionRow row) =>
      BusyMaxActionRow(
        title: row.title,
        titleWidget: row.titleWidget,
        subtitle: row.subtitle,
        subtitleWidget: row.subtitleWidget,
        leading: row.leading,
        trailing: row.trailing,
        onTap: row.onTap,
        onActivated: row.onActivated,
      );
  @override
  Widget headerButton(BuildContext context, ScheduleHeaderIconButton button) =>
      BusyMaxHeaderIconButton(
        icon: button.icon,
        onPressed: button.onPressed,
        tooltip: button.tooltip,
        iconSize: button.iconSize,
        foregroundColor: button.foregroundColor,
        backgroundColor: button.backgroundColor,
        overlayColor: button.overlayColor,
        fixedSize: button.fixedSize,
        shape: button.shape,
      );
  @override
  Widget createButton(BuildContext context, ScheduleCreateButton button) =>
      YaruIconButton(
        icon: button.icon,
        onPressed: button.onPressed,
        tooltip: button.tooltip,
      );
  @override
  ButtonStyle headerIconStyle(
    BuildContext context, {
    Color? foregroundColor,
    WidgetStateProperty<Color?>? backgroundColor,
    WidgetStateProperty<Color?>? overlayColor,
  }) => busyMaxHeaderIconButtonStyle(
    context,
    foregroundColor: foregroundColor,
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
  );
  @override
  ButtonStyle headerTextStyle(
    BuildContext context, {
    Color? foregroundColor,
    WidgetStateProperty<Color?>? backgroundColor,
    WidgetStateProperty<Color?>? overlayColor,
  }) => busyMaxHeaderTextButtonStyle(
    context,
    foregroundColor: foregroundColor,
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
  );
}

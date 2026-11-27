import 'package:busymax/src/ui/common/flutter_material.dart';

import '../../../schedule/schedule_item.dart';

import '../../../app/busymax_surface_colors.dart';
import '../../../features/schedule/presentation/schedule_item_selection.dart';

export '../../../app/common/busymax_design_values.dart' show BusyMaxMotion;

// Presentation roles shared by the planner, month overview and mini-calendars.
// Platform renderers supply controls; date grouping and interaction stay here.
abstract final class ScheduleSpacing {
  static const xxs = 2.0,
      xs = 4.0,
      headerInset = 6.0,
      sm = 8.0,
      md = 12.0,
      lg = 20.0,
      xl = 30.0;
}

abstract final class ScheduleRadius {
  static const sm = 8.0;
}

abstract final class ScheduleSizes {
  static const iconSm = 16.0;
}

abstract final class ScheduleCalendarHeaderLayout {
  static const monthControlFlex = 3, yearControlFlex = 2;
}

class SchedulePresentationScope extends StatelessWidget {
  const SchedulePresentationScope({
    super.key,
    this.presentation,
    required this.child,
  });
  final SchedulePresentation? presentation;
  final Widget child;
  @override
  Widget build(BuildContext context) => presentation == null
      ? child
      : _SchedulePresentationScope(presentation: presentation!, child: child);
}

class _SchedulePresentationScope extends InheritedWidget {
  const _SchedulePresentationScope({
    required this.presentation,
    required super.child,
  });
  final SchedulePresentation presentation;
  @override
  bool updateShouldNotify(_SchedulePresentationScope oldWidget) =>
      presentation != oldWidget.presentation;
}

/// Native control renderer. Linux supplies its existing Yaru implementations.
class SchedulePresentation {
  const SchedulePresentation();
  static SchedulePresentation of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SchedulePresentationScope>()
          ?.presentation ??
      const SchedulePresentation();
  Future<void> showMore(
    BuildContext context,
    DateTime day,
    List<ScheduleItem> items,
    ScheduleItemSelectionCallback onSelected,
    void Function(TaskScheduleItem, bool) onCompletion,
  ) async {
    final selected = await showModalBottomSheet<ScheduleItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                MaterialLocalizations.of(context).formatFullDate(day),
              ),
            ),
            for (final item in items)
              ListTile(
                title: Text(item.title),
                onTap: () => Navigator.pop(context, item),
                trailing: item is TaskScheduleItem
                    ? Checkbox(
                        value: item.completed,
                        onChanged: item.capabilities.canEdit
                            ? (value) => onCompletion(item, value ?? false)
                            : null,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) {
      onSelected(context, selected);
    }
  }

  bool get touch => true;
  IconData get calendarIcon => Icons.calendar_today_outlined;
  IconData get taskIcon => Icons.checklist_outlined;
  IconData get createIcon => Icons.add;
  IconData previousIcon(TextDirection direction) => Icons.chevron_left;
  IconData nextIcon(TextDirection direction) => Icons.chevron_right;
  IconData subdirectoryIcon(TextDirection direction) =>
      direction == TextDirection.rtl
      ? Icons.subdirectory_arrow_left
      : Icons.subdirectory_arrow_right;
  Widget checkbox(
    BuildContext context,
    bool value,
    ValueChanged<bool?>? onChanged,
  ) => Checkbox(
    value: value,
    onChanged: onChanged,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  Widget groupedSurface(BuildContext context, Widget child) => Material(
    color: Color.alphaBlend(
      BusyMaxSurfaceColors.of(context).groupedSurface,
      BusyMaxSurfaceColors.of(context).window,
    ),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  Widget groupedList(
    BuildContext context,
    String? title,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
        ],
        groupedSurface(
          context,
          Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i != 0)
                  Divider(
                    height: 1,
                    color: BusyMaxSurfaceColors.of(context).cardShade,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
  Widget actionRow(BuildContext context, ScheduleActionRow row) => ListTile(
    title: row.titleWidget ?? Text(row.title),
    subtitle:
        row.subtitleWidget ??
        (row.subtitle == null ? null : Text(row.subtitle!)),
    leading: row.leading,
    trailing: row.trailing,
    onTap:
        row.onTap ??
        (row.onActivated == null ? null : () => row.onActivated!(context)),
  );
  Widget headerButton(BuildContext context, ScheduleHeaderIconButton button) =>
      IconButton(
        tooltip: button.tooltip,
        icon: button.icon,
        iconSize: button.iconSize,
        onPressed: button.onPressed,
        style:
            IconButton.styleFrom(
              foregroundColor: button.foregroundColor,
              padding: EdgeInsets.zero,
              fixedSize: button.fixedSize,
              minimumSize: button.fixedSize,
              maximumSize: button.fixedSize,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: button.shape,
            ).copyWith(
              backgroundColor: button.backgroundColor,
              overlayColor: button.overlayColor,
            ),
      );
  Widget createButton(BuildContext context, ScheduleCreateButton button) =>
      IconButton(
        tooltip: button.tooltip,
        icon: button.icon,
        onPressed: button.onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
  ButtonStyle headerIconStyle(
    BuildContext context, {
    Color? foregroundColor,
    WidgetStateProperty<Color?>? backgroundColor,
    WidgetStateProperty<Color?>? overlayColor,
  }) => ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    foregroundColor: WidgetStatePropertyAll(foregroundColor),
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
  );
  ButtonStyle headerTextStyle(
    BuildContext context, {
    Color? foregroundColor,
    WidgetStateProperty<Color?>? backgroundColor,
    WidgetStateProperty<Color?>? overlayColor,
  }) => headerIconStyle(
    context,
    foregroundColor: foregroundColor,
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
  );
}

class ScheduleCheckbox extends StatelessWidget {
  const ScheduleCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool?>? onChanged;
  @override
  Widget build(BuildContext context) =>
      SchedulePresentation.of(context).checkbox(context, value, onChanged);
}

class ScheduleGroupedSurface extends StatelessWidget {
  const ScheduleGroupedSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SchedulePresentation.of(context).groupedSurface(context, child);
}

class ScheduleGroupedList extends StatelessWidget {
  const ScheduleGroupedList({
    super.key,
    this.title,
    required this.children,
    this.filled = true,
  });
  final String? title;
  final List<Widget> children;
  final bool filled;
  @override
  Widget build(BuildContext context) =>
      SchedulePresentation.of(context).groupedList(context, title, children);
}

class ScheduleActionRow extends StatelessWidget {
  const ScheduleActionRow({
    super.key,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
    this.onActivated,
  });
  final String title;
  final String? subtitle;
  final Widget? titleWidget, subtitleWidget, leading, trailing;
  final VoidCallback? onTap;
  final ScheduleItemTapCallback? onActivated;
  @override
  Widget build(BuildContext context) =>
      SchedulePresentation.of(context).actionRow(context, this);
}

class ScheduleHeaderIconButton extends StatelessWidget {
  const ScheduleHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconSize = 16,
    this.foregroundColor,
    this.backgroundColor,
    this.overlayColor,
    this.fixedSize,
    this.shape,
  });
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double iconSize;
  final Color? foregroundColor;
  final WidgetStateProperty<Color?>? backgroundColor, overlayColor;
  final Size? fixedSize;
  final OutlinedBorder? shape;
  @override
  Widget build(BuildContext context) =>
      SchedulePresentation.of(context).headerButton(context, this);
}

class ScheduleCreateButton extends StatelessWidget {
  const ScheduleCreateButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  @override
  Widget build(BuildContext context) =>
      SchedulePresentation.of(context).createButton(context, this);
}

Color schedulePanelBorder(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant;
Color scheduleGridColor(BuildContext context) => Theme.of(context)
    .colorScheme
    .onSurface
    .withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? .06 : .10,
    );
ButtonStyle scheduleHeaderIconButtonStyle(
  BuildContext context, {
  Color? foregroundColor,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? overlayColor,
}) => SchedulePresentation.of(context).headerIconStyle(
  context,
  foregroundColor: foregroundColor,
  backgroundColor: backgroundColor,
  overlayColor: overlayColor,
);
ButtonStyle scheduleHeaderTextButtonStyle(
  BuildContext context, {
  Color? foregroundColor,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? overlayColor,
}) => SchedulePresentation.of(context).headerTextStyle(
  context,
  foregroundColor: foregroundColor,
  backgroundColor: backgroundColor,
  overlayColor: overlayColor,
);
WidgetStateProperty<Color?> scheduleSubtleButtonBackground(
  BuildContext context,
) => WidgetStateProperty.resolveWith(
  (states) => states.contains(WidgetState.pressed)
      ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .12)
      : states.contains(WidgetState.hovered)
      ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .08)
      : null,
);

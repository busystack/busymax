import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/semantics.dart';

import '../../../features/schedule/presentation/schedule_item_selection.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_event_rescheduling.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'schedule_event_block.dart';
import 'schedule_interactions.dart';

/// Native accessibility for the planner's coordinate-based input. The upstream
/// day background supplies pointer callbacks without accessible date/time
/// targets. Keep its visual/input implementation, and describe our own visible
/// slots and first-party chip anchors to assistive technology instead.
class SchedulePlannerAccessibility extends StatefulWidget {
  const SchedulePlannerAccessibility({
    super.key,
    required this.coordinates,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
    required this.onEmptySlot,
    this.onRangeCreated,
    required this.child,
  });

  final SchedulePlannerCoordinates coordinates;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem, bool) onTaskCompletionChanged;
  final ValueChanged<DateTime> onEmptySlot;
  final ValueChanged<ScheduleInterval>? onRangeCreated;
  final Widget child;

  @override
  State<SchedulePlannerAccessibility> createState() =>
      _SchedulePlannerAccessibilityState();
}

class _SchedulePlannerAccessibilityState
    extends State<SchedulePlannerAccessibility> {
  final _anchors = <BuildContext, ScheduleItem>{};
  var _targets = <_ItemTarget>[];
  var _slots = <_SlotTarget>[];
  var _scheduled = false;
  ScheduleItemAnchorCallback? _parentAnchor;

  void _register(ScheduleItem item, BuildContext anchor) {
    _parentAnchor?.call(item, anchor);
    _anchors[anchor] = item;
    _refreshAfterLayout();
  }

  void _refreshAfterLayout() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final coordinates = widget.coordinates;
      final planner = coordinates.planner;
      if (box == null || !box.hasSize || planner == null) return;
      final bounds = Offset.zero & box.size;
      _anchors.removeWhere((anchor, _) => !anchor.mounted);
      final targets = <_ItemTarget>[];
      for (final entry in _anchors.entries) {
        final anchorBox = entry.key.findRenderObject();
        if (anchorBox is! RenderBox ||
            !anchorBox.hasSize ||
            !anchorBox.attached) {
          continue;
        }
        final rect =
            (box.globalToLocal(anchorBox.localToGlobal(Offset.zero)) &
                    anchorBox.size)
                .intersect(bounds);
        if (rect.isEmpty) continue;
        targets.add((
          rect: _accessibleRect(
            rect,
            bounds,
            entry.value is TaskScheduleItem ? 96 : 48,
          ),
          anchor: entry.key,
          item: entry.value,
          label: [
            entry.value.title,
            entry.value is TaskScheduleItem
                ? context.l10n.calendarTasks
                : context.l10n.calendarEvents,
            scheduleTimeRange(context, entry.value),
            ScheduleProjection.sourceLabelForScheduleItem(entry.value),
            if (entry.value case TaskScheduleItem(parentTitle: final title?))
              '${context.l10n.parent}: $title',
          ].join(' · '),
        ));
      }
      final slots = <_SlotTarget>[];
      if (planner.mainHorizontalController.hasClients &&
          planner.mainVerticalController.hasClients) {
        final offset = planner.mainHorizontalController.offset;
        final first = planner.dayWidthCalculator.indexForOffset(offset);
        final last = planner.dayWidthCalculator.indexForOffset(
          offset + box.size.width - coordinates.gutterWidth - .01,
        );
        for (var index = first; index <= last; index++) {
          final day = planner.getDayFromIndex(index);
          for (var hour = 0; hour < 24; hour++) {
            final time = DateTime(day.year, day.month, day.day, hour);
            for (final rect in coordinates.rectangles(
              ScheduleInterval(time, time.add(const Duration(hours: 1))),
              false,
            )) {
              slots.add((
                rect: _accessibleRect(rect.intersect(bounds), bounds, 48),
                time: time,
              ));
            }
          }
        }
      }
      // Chip anchors are reported after layout; scrolling can change their
      // positions without rebuilding them. Only request another frame when
      // the accessible projection actually changes.
      bool sameTargets() =>
          targets.length == _targets.length &&
          List.generate(targets.length, (i) {
            final a = targets[i], b = _targets[i];
            return a.rect == b.rect &&
                a.label == b.label &&
                a.anchor == b.anchor &&
                a.item == b.item;
          }).every((v) => v);
      if (sameTargets() && _sameSlots(slots, _slots)) return;
      setState(() {
        _targets = targets;
        _slots = slots;
      });
    });
  }

  void _scroll(Axis axis, double direction) {
    final planner = widget.coordinates.planner;
    if (planner == null) return;
    final controller = axis == Axis.vertical
        ? planner.mainVerticalController
        : planner.mainHorizontalController;
    if (!controller.hasClients) return;
    final distance = axis == Axis.vertical
        ? controller.position.viewportDimension * .8
        : planner.dayWidth;
    controller.jumpTo(
      (controller.offset + direction * distance).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
    _refreshAfterLayout();
  }

  @override
  Widget build(BuildContext context) {
    _parentAnchor = context
        .dependOnInheritedWidgetOfExactType<ScheduleItemAnchorScope>()
        ?.onAnchorAvailable;
    _refreshAfterLayout();
    final localizations = MaterialLocalizations.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _refreshAfterLayout();
        return false;
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: context.l10n.calendar,
        onScrollUp: () => _scroll(Axis.vertical, -1),
        onScrollDown: () => _scroll(Axis.vertical, 1),
        onScrollLeft: () => _scroll(Axis.horizontal, -1),
        onScrollRight: () => _scroll(Axis.horizontal, 1),
        child: Stack(
          children: [
            ScheduleItemAnchorScope(
              onAnchorAvailable: _register,
              child: ExcludeSemantics(child: widget.child),
            ),
            Positioned.fill(
              child: Stack(
                children: [
                  for (final slot in _slots)
                    Positioned.fromRect(
                      rect: slot.rect,
                      child: Semantics(
                        key: ValueKey(('planner-slot', slot.time)),
                        container: true,
                        button: true,
                        label:
                            '${context.l10n.create} · '
                            '${localizations.formatFullDate(slot.time)} · '
                            '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(slot.time))}',
                        onTap: () => widget.onEmptySlot(slot.time),
                        customSemanticsActions: {
                          if (widget.onRangeCreated != null)
                            CustomSemanticsAction(
                              label: context.l10n.newEvent,
                            ): () => widget.onRangeCreated!(
                              ScheduleInterval(
                                slot.time,
                                slot.time.add(const Duration(hours: 1)),
                              ),
                            ),
                        },
                      ),
                    ),
                  for (final target in _targets)
                    Positioned.fromRect(
                      rect: target.rect,
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              key: ValueKey(('planner-preview', target.anchor)),
                              container: true,
                              button: true,
                              label: target.label,
                              onTap: () => widget.onItemSelected(
                                target.anchor,
                                target.item,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          if (target.item case final TaskScheduleItem task)
                            SizedBox(
                              width: target.rect.width.clamp(0, 48),
                              height: target.rect.height,
                              child: Semantics(
                                key: ValueKey((
                                  'planner-completion',
                                  target.anchor,
                                )),
                                container: true,
                                label:
                                    '${context.l10n.completed}: ${task.title}',
                                checked: task.completed,
                                enabled: task.capabilities.canEdit,
                                onTap: task.capabilities.canEdit
                                    ? () => widget.onTaskCompletionChanged(
                                        task,
                                        !task.completed,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _ItemTarget = ({
  Rect rect,
  BuildContext anchor,
  ScheduleItem item,
  String label,
});
typedef _SlotTarget = ({Rect rect, DateTime time});

bool _sameSlots(List<_SlotTarget> a, List<_SlotTarget> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

// Dense calendar chips and partially visible slots retain touch-sized assistive
// targets. This changes their semantic hit areas, not the calendar geometry.
Rect _accessibleRect(Rect rect, Rect bounds, double minWidth) {
  final width = rect.width.clamp(minWidth, bounds.width);
  final height = rect.height.clamp(48.0, bounds.height);
  return Rect.fromLTWH(
    (rect.center.dx - width / 2).clamp(bounds.left, bounds.right - width),
    (rect.center.dy - height / 2).clamp(bounds.top, bounds.bottom - height),
    width,
    height,
  );
}

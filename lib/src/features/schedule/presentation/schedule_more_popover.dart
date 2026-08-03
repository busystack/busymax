import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../schedule/schedule_item.dart';
import 'schedule_anchored_popover.dart';
import 'schedule_item_chip.dart';

class ScheduleMorePopoverSelection {
  const ScheduleMorePopoverSelection({
    required this.item,
    required this.anchorPoint,
  });

  final ScheduleItem item;
  final Offset? anchorPoint;
}

Future<ScheduleMorePopoverSelection?> showScheduleMorePopover({
  required BuildContext context,
  required BuildContext anchorContext,
  required DateTime day,
  required List<ScheduleItem> items,
  required void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged,
}) async {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dayLabel = DateFormat.yMMMMEEEEd(locale).format(day);
  final fallbackAnchorPoint = scheduleGlobalRectFor(anchorContext)?.center;
  return showScheduleAnchoredPopover<ScheduleMorePopoverSelection>(
    context: context,
    anchorContext: anchorContext,
    semanticLabel: dayLabel,
    preferredMinimumHeight: 200,
    builder: (context, arrowSide, arrowAlignment) {
      return BusyMaxPopoverSurface(
        color: BusyMaxSurfaceColors.of(context).popover,
        arrowSide: arrowSide,
        arrowAlignment: arrowAlignment,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(BusyMaxSpacing.lg),
              child: Text(
                dayLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(BusyMaxSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: BusyMaxSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ScheduleItemChip(
                    item: item,
                    height: 34,
                    compact: false,
                    onTap: (itemAnchorContext, [globalPosition]) {
                      Navigator.of(context).pop(
                        ScheduleMorePopoverSelection(
                          item: item,
                          anchorPoint:
                              globalPosition ??
                              scheduleGlobalRectFor(
                                itemAnchorContext,
                              )?.center ??
                              fallbackAnchorPoint,
                        ),
                      );
                    },
                    onTaskCompletionChanged: item is TaskScheduleItem
                        ? (completed) =>
                              onTaskCompletionChanged(item, completed)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

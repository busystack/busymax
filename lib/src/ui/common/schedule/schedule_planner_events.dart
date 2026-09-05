import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';

/// Keep the package's conflict/column layout, with enough visual space for two
/// boundary hit regions and a clickable body even for a five-minute event.
class SchedulePlannerEventArranger extends icv.SideEventArranger {
  const SchedulePlannerEventArranger() : super(paddingLeft: 4, paddingRight: 4);
  @override
  List<icv.OrganizedEvent> arrange({
    required List<icv.Event> events,
    required double height,
    required double width,
    required double heightPerMinute,
  }) => [
    for (final event in super.arrange(
      events: events,
      height: height,
      width: width,
      heightPerMinute: heightPerMinute,
    ))
      icv.OrganizedEvent(
        startDuration: event.startDuration,
        endDuration: event.endDuration,
        top: event.top,
        bottom: math.min(event.bottom, height - event.top - 22),
        left: event.left,
        right: event.right,
        event: event.event,
      ),
  ];
}

/// Display-only planner adapters. Never use their adapted ends for editing.
class SchedulePlannerEvents {
  const SchedulePlannerEvents._();

  static List<icv.Event> fromItems(
    List<ScheduleItem> items, {
    required Brightness brightness,
    required String Function(int) groupLabel,
  }) {
    final grouped = <String, List<({icv.Event event, ScheduleItem item})>>{};
    final ungrouped = <icv.Event>[];
    for (final item in items) {
      final event = fromItem(item, brightness);
      if (event == null) {
        continue;
      }
      if (event.isFullDay) {
        ungrouped.add(event);
        continue;
      }
      grouped
          .putIfAbsent(
            _slotKey(event),
            () => <({icv.Event event, ScheduleItem item})>[],
          )
          .add((event: event, item: item));
    }

    return [
      ...ungrouped,
      for (final entries in grouped.values)
        if (entries.length == 1)
          entries.single.event
        else
          entries.first.event.copyWith(
            title: entries.first.item.title,
            description: groupLabel(entries.length),
            data: ScheduleSlotGroup([for (final entry in entries) entry.item]),
            eventType: ScheduleSlotGroup,
          ),
    ];
  }

  static icv.Event? fromItem(ScheduleItem item, Brightness brightness) {
    final start = item.start;
    if (start == null) {
      return null;
    }
    final color = ScheduleProjection.colorForItem(item, brightness);
    if (item.allDay) {
      final startDay = _day(start);
      final endDay = item.end == null ? null : _day(item.end!);
      final inclusiveEnd = endDay == null
          ? null
          : DateTime(endDay.year, endDay.month, endDay.day - 1);
      final displayEnd = _endOfDay(
        inclusiveEnd != null && !inclusiveEnd.isBefore(startDay)
            ? inclusiveEnd
            : startDay,
      );
      return icv.Event(
        startTime: startDay,
        endTime: displayEnd,
        isFullDay: true,
        title: item.title,
        description: ScheduleProjection.sourceLabelForScheduleItem(item),
        color: color,
        textColor: _foregroundFor(color),
        data: item,
        eventType: item.kind,
      );
    }

    final end = item.end != null && item.end!.isAfter(start)
        ? item.end!
        : start.add(const Duration(minutes: 30));
    return icv.Event(
      startTime: start,
      endTime: end,
      title: item.title,
      description: ScheduleProjection.sourceLabelForScheduleItem(item),
      color: color,
      textColor: _foregroundFor(color),
      data: item,
      eventType: item.kind,
    );
  }
}

class ScheduleSlotGroup {
  const ScheduleSlotGroup(this.items);

  final List<ScheduleItem> items;
}

ScheduleItem? schedulePlannerItem(icv.Event event) {
  return event.data is ScheduleItem ? event.data! as ScheduleItem : null;
}

ScheduleSlotGroup? schedulePlannerGroup(icv.Event event) {
  return event.data is ScheduleSlotGroup
      ? event.data! as ScheduleSlotGroup
      : null;
}

String _slotKey(icv.Event event) {
  final end = event.endTime?.microsecondsSinceEpoch ?? -1;
  return [
    event.columnIndex,
    event.isFullDay,
    event.startTime.microsecondsSinceEpoch,
    end,
  ].join('|');
}

Color _foregroundFor(Color color) {
  return color.computeLuminance() > 0.54
      ? const Color(0xff000000)
      : const Color(0xffffffff);
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
DateTime _endOfDay(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day + 1,
).subtract(const Duration(milliseconds: 1));

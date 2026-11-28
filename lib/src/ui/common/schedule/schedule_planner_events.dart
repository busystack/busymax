import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';

/// Keep the package's conflict/column layout, with enough visual space for two
/// boundary hit regions and a clickable body even for a five-minute event.
class SchedulePlannerEventArranger extends icv.SideEventArranger {
  const SchedulePlannerEventArranger() : super(paddingLeft: 4, paddingRight: 4);

  static const _minimumTileHeight = 22.0;

  @override
  List<icv.OrganizedEvent> arrange({
    required List<icv.Event> events,
    required double height,
    required double width,
    required double heightPerMinute,
  }) {
    if (!events.any((event) => event.eventType == ScheduleItemKind.journal)) {
      return [
        for (final tile in super.arrange(
          events: events,
          height: height,
          width: width,
          heightPerMinute: heightPerMinute,
        ))
          icv.OrganizedEvent(
            startDuration: tile.startDuration,
            endDuration: tile.endDuration,
            top: tile.top,
            bottom: math.min(
              tile.bottom,
              height - tile.top - _minimumTileHeight,
            ),
            left: tile.left,
            right: tile.right,
            event: tile.event,
          ),
      ];
    }

    // Reserve only the drawn pixels for a journal marker. Feed disposable
    // layout intervals to the column arranger and return the original events.
    final layoutDay = DateTime.utc(2000);
    DateTime layoutTime(double pixel) => layoutDay.add(
      Duration(
        microseconds: (pixel / heightPerMinute * Duration.microsecondsPerMinute)
            .round(),
      ),
    );
    final tiles =
        <({icv.Event item, double top, double end, icv.Event proxy})>[];
    for (final event in events) {
      final journal = event.eventType == ScheduleItemKind.journal;
      final start = event.startTime;
      final top =
          (start.hour * 60 + start.minute + (journal ? start.second / 60 : 0)) *
          heightPerMinute;
      final end = event.endTime!;
      final visualEnd = math.max(
        top + _minimumTileHeight,
        journal ? top : (end.hour * 60 + end.minute) * heightPerMinute,
      );
      tiles.add((
        item: event,
        top: top,
        end: visualEnd,
        proxy: event.copyWith(
          startTime: layoutTime(top),
          endTime: layoutTime(visualEnd),
        ),
      ));
    }
    final ordered = tiles.toList()..sort((a, b) => a.top.compareTo(b.top));
    final availableWidth = math.max(1.0, width - paddingLeft - paddingRight);
    final bounds = <icv.Event, (double, double)>{};
    // Use the same lane width for the whole connected group. A long event and
    // two nearby markers can form a chain even when the end tiles don't touch.
    for (var first = 0; first < ordered.length;) {
      var end = ordered[first].end;
      var next = first + 1;
      while (next < ordered.length && ordered[next].top < end) {
        end = math.max(end, ordered[next++].end);
      }
      final arranged = super.arrange(
        events: [for (var i = first; i < next; i++) ordered[i].proxy],
        width: availableWidth + paddingLeft + paddingRight,
        height: height,
        heightPerMinute: heightPerMinute,
      );
      final lanes = {
        for (final tile in arranged)
          tile.event:
              ((tile.left - paddingLeft) /
                      (availableWidth -
                          tile.left -
                          tile.right +
                          paddingLeft +
                          paddingRight))
                  .round(),
      };
      final count = lanes.values.reduce(math.max) + 1;
      for (final entry in lanes.entries) {
        bounds[entry.key] = (
          paddingLeft + entry.value * availableWidth / count,
          paddingRight + (count - entry.value - 1) * availableWidth / count,
        );
      }
      first = next;
    }
    return [
      for (final tile in tiles)
        icv.OrganizedEvent(
          startDuration: tile.item.startTime,
          endDuration: tile.item.eventType == ScheduleItemKind.journal
              ? tile.item.startTime
              : tile.item.endTime!,
          top: tile.top,
          bottom: math.max(0.0, height - tile.end),
          left: bounds[tile.proxy]!.$1,
          right: bounds[tile.proxy]!.$2,
          event: tile.item,
        ),
    ];
  }
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
            eventType: entries.first.item is JournalScheduleItem
                ? ScheduleItemKind.journal
                : ScheduleSlotGroup,
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

    // The planner package requires a positive adapter interval. The arranger
    // resolves the journal's visual marker size independently of this value.
    final end = item is JournalScheduleItem
        ? start.add(const Duration(microseconds: 1))
        : item.end != null && item.end!.isAfter(start)
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

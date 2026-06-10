import 'package:flutter/material.dart';

import '../task_providers/task_provider.dart';
import 'schedule_item.dart';
import 'schedule_range.dart';
import 'schedule_scope.dart';
import 'schedule_sorting.dart';

class ScheduleProjection {
  const ScheduleProjection._();

  static List<ScheduleItem> filterByScope(
    List<ScheduleItem> items,
    ScheduleScope scope,
  ) {
    final filtered = switch (scope) {
      ScheduleScope.events =>
        items
            .where((item) => item.kind == ScheduleItemKind.calendarEvent)
            .toList(),
      ScheduleScope.tasks =>
        items.where((item) => item.kind == ScheduleItemKind.task).toList(),
      ScheduleScope.all ||
      ScheduleScope.today ||
      ScheduleScope.upcoming => List<ScheduleItem>.of(items),
    };
    filtered.sort(compareScheduleItems);
    return filtered;
  }

  static List<ScheduleItem> itemsForDay(
    List<ScheduleItem> items,
    DateTime day,
  ) {
    final range = ScheduleRange.day(day);
    final matches = items.where((item) => intersects(item, range)).toList();
    matches.sort(compareScheduleItems);
    return matches;
  }

  static Map<DateTime, List<ScheduleItem>> groupByDay(
    List<ScheduleItem> items,
  ) {
    final groups = <DateTime, List<ScheduleItem>>{};
    for (final item in items) {
      final start = item.start;
      if (start == null) {
        continue;
      }
      final key = day(start);
      groups.putIfAbsent(key, () => <ScheduleItem>[]).add(item);
    }
    for (final entry in groups.entries) {
      entry.value.sort(compareScheduleItems);
    }
    return groups;
  }

  static List<ScheduleItem> noDateTasks(List<ScheduleItem> items) {
    final result = items
        .where(
          (item) => item.kind == ScheduleItemKind.task && item.start == null,
        )
        .toList();
    result.sort(compareScheduleItems);
    return result;
  }

  static bool intersects(ScheduleItem item, ScheduleRange range) {
    final start = item.start;
    if (start == null) {
      return true;
    }
    final end = item.end ?? start.add(const Duration(minutes: 1));
    return end.isAfter(range.start) && start.isBefore(range.end);
  }

  static String sourceLabelForScheduleItem(ScheduleItem item) {
    if (item is CalendarScheduleItem) {
      return _cleanLabel(item.sourceName) ?? 'Calendar';
    }
    if (item is TaskScheduleItem) {
      final listName = _cleanLabel(item.sourceName) ?? 'Tasks';
      return switch (item.provider) {
        TaskProvider.google => _dedupeProvider('Google Tasks', listName),
        TaskProvider.microsoft => _dedupeProvider('Microsoft To Do', listName),
      };
    }
    return 'BusyMax';
  }

  static Color colorForItem(ScheduleItem item, Brightness brightness) {
    if (item is CalendarScheduleItem) {
      return _colorFromHex(item.colorHex) ??
          deterministicSourceColor(item.sourceId, brightness);
    }
    if (item is TaskScheduleItem && item.completed) {
      return brightness == Brightness.dark
          ? const Color(0xff8b949e)
          : const Color(0xff6e7781);
    }
    return brightness == Brightness.dark
        ? const Color(0xff8db3d9)
        : const Color(0xff4d7fa8);
  }

  static Color deterministicSourceColor(String seed, Brightness brightness) {
    const lightPalette = <Color>[
      Color(0xff326b88),
      Color(0xff7b5f1c),
      Color(0xff5e7f3f),
      Color(0xff8f4e5b),
      Color(0xff546f9f),
      Color(0xff7d6d8f),
      Color(0xff3f7d72),
      Color(0xff8a633e),
    ];
    const darkPalette = <Color>[
      Color(0xff81b9d7),
      Color(0xffd4b35f),
      Color(0xffa3c57a),
      Color(0xffd8999f),
      Color(0xffa8b9e1),
      Color(0xffc5afd5),
      Color(0xff87c7bc),
      Color(0xffd3a87b),
    ];
    final palette = brightness == Brightness.dark ? darkPalette : lightPalette;
    return palette[seed.hashCode.abs() % palette.length];
  }

  static DateTime day(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

String? _cleanLabel(String? label) {
  final value = label?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  final lower = value.toLowerCase();
  if (lower.startsWith('google-') ||
      lower.startsWith('microsoft-') ||
      lower.startsWith('local-') ||
      lower.contains('@generated')) {
    return null;
  }
  return value;
}

String _dedupeProvider(String provider, String listName) {
  final lowerProvider = provider.toLowerCase();
  final lowerList = listName.toLowerCase();
  if (lowerList == lowerProvider ||
      lowerList == 'google' ||
      lowerList == 'microsoft') {
    return provider;
  }
  return '$provider · $listName';
}

Color? _colorFromHex(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) {
    return null;
  }
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xff000000 | parsed);
}

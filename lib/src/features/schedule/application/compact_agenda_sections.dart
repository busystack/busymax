import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_sorting.dart';

enum CompactAgendaSectionKind { overdue, day }

class CompactAgendaSection {
  const CompactAgendaSection({
    required this.kind,
    required this.items,
    this.day,
    this.hasMore = false,
  });

  final CompactAgendaSectionKind kind;
  final DateTime? day;
  final List<ScheduleItem> items;
  final bool hasMore;
}

List<CompactAgendaSection> buildCompactAgendaSections({
  required DateTime today,
  required List<ScheduleItem> items,
}) {
  final overdueTasks = items.whereType<TaskScheduleItem>().where((item) {
    final start = item.start;
    return start != null &&
        !item.completed &&
        ScheduleProjection.day(start).isBefore(today);
  }).toList()..sort(compareScheduleItems);

  final sections = <CompactAgendaSection>[];
  if (overdueTasks.isNotEmpty) {
    sections.add(
      CompactAgendaSection(
        kind: CompactAgendaSectionKind.overdue,
        items: overdueTasks.take(8).toList(),
        hasMore: overdueTasks.length > 8,
      ),
    );
  }

  final grouped = <DateTime, List<ScheduleItem>>{};
  final end = today.add(const Duration(days: 7));
  for (final item in items) {
    if (item is TaskScheduleItem && item.completed) {
      continue;
    }
    final start = item.start;
    if (start == null) {
      continue;
    }
    final day = ScheduleProjection.day(start);
    if (day.isBefore(today) || !day.isBefore(end)) {
      continue;
    }
    grouped.putIfAbsent(day, () => <ScheduleItem>[]).add(item);
  }

  final days = grouped.keys.toList()..sort();
  for (final day in days) {
    final dayItems = grouped[day]!..sort(compareScheduleItems);
    sections.add(
      CompactAgendaSection(
        kind: CompactAgendaSectionKind.day,
        day: day,
        items: dayItems,
      ),
    );
  }

  return sections;
}

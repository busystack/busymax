import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_sorting.dart';

const compactAgendaInitialOverdueLimit = 8;
const compactAgendaOverduePageSize = 8;
const compactAgendaInitialNoDateLimit = 8;
const compactAgendaNoDatePageSize = 8;

enum CompactAgendaSectionKind { overdue, day, noDate }

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
  DateTime? end,
  int overdueLimit = compactAgendaInitialOverdueLimit,
  int noDateLimit = compactAgendaInitialNoDateLimit,
  bool hasMoreOverdueTasks = false,
  bool hasMoreNoDateTasks = false,
}) {
  final rangeEnd = end == null ? null : ScheduleProjection.day(end);
  final visibleOverdueLimit = overdueLimit < 1
      ? compactAgendaInitialOverdueLimit
      : overdueLimit;
  final visibleNoDateLimit = noDateLimit < 1
      ? compactAgendaInitialNoDateLimit
      : noDateLimit;
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
        items: overdueTasks.take(visibleOverdueLimit).toList(),
        hasMore:
            hasMoreOverdueTasks || overdueTasks.length > visibleOverdueLimit,
      ),
    );
  }

  final grouped = <DateTime, List<ScheduleItem>>{};
  final noDateTasks = <TaskScheduleItem>[];
  for (final item in items) {
    if (item is TaskScheduleItem && item.completed) {
      continue;
    }
    final start = item.start;
    if (start == null) {
      if (item is TaskScheduleItem) {
        noDateTasks.add(item);
      }
      continue;
    }
    final day = ScheduleProjection.day(start);
    if (day.isBefore(today) || (rangeEnd != null && !day.isBefore(rangeEnd))) {
      continue;
    }
    grouped.putIfAbsent(day, () => <ScheduleItem>[]).add(item);
  }

  final days = grouped.keys.toList()..sort();
  if (noDateTasks.isNotEmpty) {
    noDateTasks.sort(compareScheduleItems);
    sections.add(
      CompactAgendaSection(
        kind: CompactAgendaSectionKind.noDate,
        items: noDateTasks.take(visibleNoDateLimit).toList(),
        hasMore: hasMoreNoDateTasks || noDateTasks.length > visibleNoDateLimit,
      ),
    );
  }

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

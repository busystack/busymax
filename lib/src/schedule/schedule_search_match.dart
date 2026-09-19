import '../providers/busy_provider.dart';
import '../calendar_providers/calendar_description.dart';
import 'schedule_filters.dart';
import 'schedule_item.dart';
import 'schedule_range.dart';

List<String> _terms(String query) => query
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((term) => term.isNotEmpty)
    .toList();

/// Only identity fields are searchable; response and other provider metadata
/// deliberately do not become part of a person's identity.
Iterable<List<String>> scheduleEventPeople(CalendarScheduleItem item) sync* {
  for (final person in [
    if (item.organizer != null) item.organizer!,
    ...item.attendees,
  ]) {
    final identity = <String>[];
    for (final key in const [
      'displayName',
      'name',
      'email',
      'address',
      'cn',
      'uri',
    ]) {
      final value = person[key];
      if (value is String && value.trim().isNotEmpty) identity.add(value);
    }
    final nested = person['emailAddress'];
    if (nested is Map) {
      for (final key in const ['name', 'address']) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) identity.add(value);
      }
    }
    if (identity.isNotEmpty) yield identity;
  }
}

bool _matchesPerson(List<String> identity, List<String> terms) {
  final fields = identity.map((field) => field.toLowerCase()).toList();
  return terms.every((term) => fields.any((field) => field.contains(term)));
}

String? scheduleItemLocation(ScheduleItem item) => switch (item) {
  CalendarScheduleItem() => item.location,
  TaskScheduleItem() => item.location,
};

String _plainDescription(ScheduleItem item) => switch (item) {
  CalendarScheduleItem() => htmlCalendarDescriptionToPlainText(
    item.description ?? item.descriptionHtml ?? '',
  ),
  TaskScheduleItem() => htmlCalendarDescriptionToPlainText(item.notes ?? ''),
};

Iterable<String> _contextFields(ScheduleItem item) sync* {
  yield scheduleItemLocation(item) ?? '';
  if (item is CalendarScheduleItem) {
    for (final identity in scheduleEventPeople(item)) {
      yield* identity;
    }
  }
  yield _plainDescription(item);
  yield* item.categories;
  if (item is TaskScheduleItem) {
    yield item.parentTitle ?? '';
    yield* item.checklistItems.map((entry) => entry.title);
  }
}

bool matchesScheduleQuery(ScheduleItem item, String query) {
  final fields = [
    item.title,
    item.sourceName ?? '',
    item.provider.displayName,
    item.accountDisplayName ?? '',
    item.accountEmail ?? '',
    ..._contextFields(item),
  ].map((value) => value.toLowerCase()).toList();
  return _terms(
    query,
  ).every((term) => fields.any((field) => field.contains(term)));
}

bool matchesTaskCompletion(
  TaskScheduleItem item,
  ScheduleTaskCompletion completion,
) => switch (completion) {
  ScheduleTaskCompletion.open => !item.completed,
  ScheduleTaskCompletion.all => true,
  ScheduleTaskCompletion.completed => item.completed,
};

bool matchesScheduleFilters(
  ScheduleItem item,
  ScheduleFilters filters, {
  required ScheduleRange range,
}) {
  if (filters.accountIds.isNotEmpty &&
      !filters.accountIds.contains(item.accountId)) {
    return false;
  }
  if (item is CalendarScheduleItem) {
    if (!filters.includeCalendarEvents ||
        (filters.sourceFilterActive &&
            !filters.sourceIds.contains(item.sourceId))) {
      return false;
    }
    if (!filters.ignoreDateRange) {
      final start = item.start;
      if (start == null ||
          !start.isBefore(range.end) ||
          !(item.end ?? start.add(const Duration(minutes: 1))).isAfter(
            range.start,
          )) {
        return false;
      }
    }
    final personTerms = _terms(filters.person);
    if (personTerms.isNotEmpty &&
        !scheduleEventPeople(
          item,
        ).any((identity) => _matchesPerson(identity, personTerms))) {
      return false;
    }
  }
  if (item is TaskScheduleItem) {
    if (!filters.includeTasks ||
        (filters.taskListFilterActive &&
            !filters.taskListKeys.contains(
              ScheduleTaskListKey(
                accountId: item.accountId,
                taskListId: item.sourceId,
              ),
            ))) {
      return false;
    }
    if (!matchesTaskCompletion(item, filters.taskCompletion)) return false;
    // Person applies to events. A Tasks-only scope ignores the hidden control.
    if (filters.includeCalendarEvents && filters.person.trim().isNotEmpty) {
      return false;
    }
    if (filters.useTaskDueDate &&
        !filters.ignoreDateRange &&
        (item.due == null || !range.contains(item.due!))) {
      return false;
    }
    final now = filters.referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filters.taskDueState) {
      case ScheduleTaskDueState.any:
        break;
      case ScheduleTaskDueState.overdue:
        if (item.completed || item.due == null || !item.due!.isBefore(today)) {
          return false;
        }
      case ScheduleTaskDueState.noDueDate:
        if (item.due != null) return false;
    }
  }
  final location = (scheduleItemLocation(item) ?? '').toLowerCase();
  return location.contains(filters.location.trim().toLowerCase()) &&
      matchesScheduleQuery(item, filters.query);
}

/// A single bounded context snippet shared by the three presentations.
String? scheduleMatchContext(
  ScheduleItem item,
  String query, {
  String location = '',
  String person = '',
}) {
  final terms = _terms(query);
  if (location.trim().isNotEmpty &&
      scheduleItemLocation(item)?.isNotEmpty == true) {
    return _snippet(scheduleItemLocation(item)!, _terms(location));
  }
  if (person.trim().isNotEmpty && item is CalendarScheduleItem) {
    final personTerms = _terms(person);
    for (final identity in scheduleEventPeople(item)) {
      if (_matchesPerson(identity, personTerms)) {
        return _snippet(identity.join(' · '), personTerms);
      }
    }
  }
  if (terms.isEmpty || terms.every(item.title.toLowerCase().contains)) {
    return null;
  }
  for (final field in _contextFields(item)) {
    if (terms.any(field.toLowerCase().contains)) return _snippet(field, terms);
  }
  return null;
}

String _snippet(String field, List<String> terms) {
  final text = field.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 140) return text;
  final matches =
      terms.map(text.toLowerCase().indexOf).where((i) => i >= 0).toList()
        ..sort();
  final start = matches.isEmpty
      ? 0
      : (matches.first - 35).clamp(0, text.length - 140).toInt();
  return '${start > 0 ? '…' : ''}${text.substring(start, start + 140)}…';
}

String scheduleSearchSourceLabel(ScheduleItem item) {
  final account = item.accountEmail?.trim().isNotEmpty == true
      ? item.accountEmail
      : item.accountDisplayName;
  return [
    item.sourceName ?? item.provider.displayName,
    account ?? item.accountId,
  ].join(' · ');
}

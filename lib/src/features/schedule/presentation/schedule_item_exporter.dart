import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../../schedule/schedule_item.dart';

Future<File?> exportScheduleItemWithSaveDialog(ScheduleItem item) async {
  final location = await getSaveLocation(
    suggestedName: scheduleExportFileName(item),
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'iCalendar',
        extensions: ['ics'],
        mimeTypes: ['text/calendar'],
      ),
    ],
  );
  if (location == null) {
    return null;
  }
  final file = File(_ensureIcsExtension(location.path));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    scheduleItemToICalendar(item, nowUtc: DateTime.now().toUtc()),
  );
  return file;
}

String scheduleExportFileName(ScheduleItem item) {
  final prefix = item is CalendarScheduleItem ? 'event' : 'task';
  final title = _sanitizeFilePart(item.title);
  final date = item.start == null ? 'no-date' : _formatDate(item.start!);
  return 'busymax-$prefix-$date-$title.ics';
}

String scheduleItemToICalendar(ScheduleItem item, {required DateTime nowUtc}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BusyMax//BusyMax//EN',
    'CALSCALE:GREGORIAN',
  ];
  if (item is CalendarScheduleItem) {
    lines.addAll(_eventLines(item, nowUtc));
  } else if (item is TaskScheduleItem) {
    lines.addAll(_taskLines(item, nowUtc));
  }
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

List<String> _eventLines(CalendarScheduleItem item, DateTime nowUtc) {
  final start = item.start;
  final end = item.end;
  final lines = <String>[
    'BEGIN:VEVENT',
    'UID:${_icsText(item.id)}@busymax',
    'DTSTAMP:${_formatDateTimeUtc(nowUtc)}',
    'SUMMARY:${_icsText(item.title)}',
  ];
  if (start != null) {
    lines.add(_dateLine('DTSTART', start, item.allDay));
  }
  if (start != null || end != null) {
    lines.add(
      _dateLine('DTEND', _eventEnd(start, end, item.allDay), item.allDay),
    );
  }
  final location = item.location?.trim();
  if (location != null && location.isNotEmpty) {
    lines.add('LOCATION:${_icsText(location)}');
  }
  final description = item.description?.trim();
  if (description != null && description.isNotEmpty) {
    lines.add('DESCRIPTION:${_icsText(description)}');
  }
  lines.add('END:VEVENT');
  return lines;
}

List<String> _taskLines(TaskScheduleItem item, DateTime nowUtc) {
  final lines = <String>[
    'BEGIN:VTODO',
    'UID:${_icsText(item.id)}@busymax',
    'DTSTAMP:${_formatDateTimeUtc(nowUtc)}',
    'SUMMARY:${_icsText(item.title)}',
    'STATUS:${item.completed ? 'COMPLETED' : 'NEEDS-ACTION'}',
  ];
  final due = item.start;
  if (due != null) {
    lines.add(_dateLine('DUE', due, item.allDay));
  }
  final notes = item.notes?.trim();
  if (notes != null && notes.isNotEmpty) {
    lines.add('DESCRIPTION:${_icsText(notes)}');
  }
  lines.add('END:VTODO');
  return lines;
}

String _ensureIcsExtension(String path) {
  return path.toLowerCase().endsWith('.ics') ? path : '$path.ics';
}

DateTime _eventEnd(DateTime? start, DateTime? end, bool allDay) {
  if (end != null) {
    if (!allDay || start == null || end.isAfter(start)) {
      return end;
    }
  }
  final fallback = start ?? DateTime.now();
  return fallback.add(
    allDay ? const Duration(days: 1) : const Duration(hours: 1),
  );
}

String _dateLine(String key, DateTime value, bool allDay) {
  if (allDay) {
    return '$key;VALUE=DATE:${_formatDate(value)}';
  }
  return '$key:${_formatDateTimeUtc(value.toUtc())}';
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatDateTimeUtc(DateTime value) {
  final utc = value.toUtc();
  return '${_formatDate(utc)}T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';
}

String _icsText(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', '')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
}

String _sanitizeFilePart(String value) {
  final sanitized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return sanitized.isEmpty ? 'untitled' : sanitized;
}

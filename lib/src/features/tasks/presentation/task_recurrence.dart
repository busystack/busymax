import 'dart:convert';

import '../../../core/time/provider_date_time.dart';

String? encodeSimpleTaskRecurrence(
  String type, {
  required DateTime? due,
  required DateTime? start,
  required bool dav,
}) {
  if (type == 'none') return null;
  final recurrenceStart = start ?? due ?? DateTime.now();
  if (dav) {
    final frequency = switch (type) {
      'daily' => 'DAILY',
      'weekly' => 'WEEKLY',
      'absoluteMonthly' => 'MONTHLY',
      'absoluteYearly' => 'YEARLY',
      _ => 'DAILY',
    };
    final parts = <String>['FREQ=$frequency', 'INTERVAL=1'];
    if (type == 'weekly') {
      parts.add('BYDAY=${_weekdayCode(recurrenceStart.weekday)}');
    } else if (type == 'absoluteMonthly') {
      parts.add('BYMONTHDAY=${recurrenceStart.day}');
    } else if (type == 'absoluteYearly') {
      parts
        ..add('BYMONTH=${recurrenceStart.month}')
        ..add('BYMONTHDAY=${recurrenceStart.day}');
    }
    return jsonEncode({
      'rules': [parts.join(';')],
      'dates': const <String>[],
      'excludedDates': const <String>[],
    });
  }
  final pattern = switch (type) {
    'daily' => {'type': 'daily', 'interval': 1},
    'weekly' => {
      'type': 'weekly',
      'interval': 1,
      'daysOfWeek': [_weekdayName(recurrenceStart.weekday)],
      'firstDayOfWeek': 'monday',
    },
    'absoluteMonthly' => {
      'type': 'absoluteMonthly',
      'interval': 1,
      'dayOfMonth': recurrenceStart.day,
    },
    'absoluteYearly' => {
      'type': 'absoluteYearly',
      'interval': 1,
      'dayOfMonth': recurrenceStart.day,
      'month': recurrenceStart.month,
    },
    _ => {'type': 'daily', 'interval': 1},
  };
  return jsonEncode({
    'pattern': pattern,
    'range': {
      'type': 'noEnd',
      'startDate': providerWallTimeIso8601String(
        recurrenceStart,
      ).substring(0, 10),
    },
  });
}

String _weekdayCode(int weekday) => switch (weekday) {
  DateTime.monday => 'MO',
  DateTime.tuesday => 'TU',
  DateTime.wednesday => 'WE',
  DateTime.thursday => 'TH',
  DateTime.friday => 'FR',
  DateTime.saturday => 'SA',
  _ => 'SU',
};

String _weekdayName(int weekday) => switch (weekday) {
  DateTime.monday => 'monday',
  DateTime.tuesday => 'tuesday',
  DateTime.wednesday => 'wednesday',
  DateTime.thursday => 'thursday',
  DateTime.friday => 'friday',
  DateTime.saturday => 'saturday',
  _ => 'sunday',
};

import 'dart:math' as math;

import 'package:busymax/src/providers/busy_provider.dart';

class CalendarColorChoice {
  const CalendarColorChoice({
    required this.providerValue,
    required this.backgroundColor,
  });

  final String providerValue;
  final String backgroundColor;
}

const googleCalendarColorChoices = <CalendarColorChoice>[
  CalendarColorChoice(providerValue: '#3584e4', backgroundColor: '#3584e4'),
  CalendarColorChoice(providerValue: '#1c71d8', backgroundColor: '#1c71d8'),
  CalendarColorChoice(providerValue: '#33d17a', backgroundColor: '#33d17a'),
  CalendarColorChoice(providerValue: '#26a269', backgroundColor: '#26a269'),
  CalendarColorChoice(providerValue: '#2ec1c9', backgroundColor: '#2ec1c9'),
  CalendarColorChoice(providerValue: '#f6d32d', backgroundColor: '#f6d32d'),
  CalendarColorChoice(providerValue: '#ff7800', backgroundColor: '#ff7800'),
  CalendarColorChoice(providerValue: '#e01b24', backgroundColor: '#e01b24'),
  CalendarColorChoice(providerValue: '#c061cb', backgroundColor: '#c061cb'),
  CalendarColorChoice(providerValue: '#9141ac', backgroundColor: '#9141ac'),
  CalendarColorChoice(providerValue: '#986a44', backgroundColor: '#986a44'),
  CalendarColorChoice(providerValue: '#77767b', backgroundColor: '#77767b'),
];

const microsoftCalendarColorChoices = <CalendarColorChoice>[
  CalendarColorChoice(providerValue: 'lightBlue', backgroundColor: '#0078D4'),
  CalendarColorChoice(providerValue: 'lightGreen', backgroundColor: '#107C10'),
  CalendarColorChoice(providerValue: 'lightOrange', backgroundColor: '#D83B01'),
  CalendarColorChoice(providerValue: 'lightGray', backgroundColor: '#7A7574'),
  CalendarColorChoice(providerValue: 'lightYellow', backgroundColor: '#F2C811'),
  CalendarColorChoice(providerValue: 'lightTeal', backgroundColor: '#008575'),
  CalendarColorChoice(providerValue: 'lightPink', backgroundColor: '#E3008C'),
  CalendarColorChoice(providerValue: 'lightBrown', backgroundColor: '#8E562E'),
  CalendarColorChoice(providerValue: 'lightRed', backgroundColor: '#D13438'),
];

List<CalendarColorChoice> calendarColorChoices(BusyProvider provider) {
  return switch (provider) {
    BusyProvider.google => googleCalendarColorChoices,
    BusyProvider.microsoft => microsoftCalendarColorChoices,
    BusyProvider.appleICloud || BusyProvider.nextcloud => const [],
  };
}

String calendarColorForegroundHex(String backgroundColor) {
  final normalized = backgroundColor.replaceFirst('#', '');
  if (normalized.length != 6) {
    throw FormatException('Expected a six-digit RGB calendar color.');
  }
  final value = int.parse(normalized, radix: 16);
  final red = _linearColorChannel((value >> 16) & 0xff);
  final green = _linearColorChannel((value >> 8) & 0xff);
  final blue = _linearColorChannel(value & 0xff);
  final luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  return luminance > 0.179 ? '#000000' : '#ffffff';
}

String? calendarSourceBackgroundColorHex({
  required BusyProvider provider,
  String? backgroundColor,
  String? colorId,
}) {
  final explicitColor = _nonEmpty(backgroundColor);
  if (explicitColor != null) {
    return explicitColor;
  }
  if (provider == BusyProvider.microsoft) {
    return microsoftCalendarColorHex(colorId);
  }
  return null;
}

String? microsoftCalendarColorHex(String? value) {
  final normalized = value?.trim();
  for (final choice in microsoftCalendarColorChoices) {
    if (choice.providerValue == normalized) {
      return choice.backgroundColor;
    }
  }
  return null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

double _linearColorChannel(int value) {
  final channel = value / 255;
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

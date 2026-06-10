import '../task_providers/task_provider.dart';

String? calendarSourceBackgroundColorHex({
  required BusyProvider provider,
  String? backgroundColor,
  String? colorId,
}) {
  final explicitColor = _nonEmpty(backgroundColor);
  if (explicitColor != null) {
    return explicitColor;
  }
  if (provider == TaskProvider.microsoft) {
    return microsoftCalendarColorHex(colorId);
  }
  return null;
}

String? microsoftCalendarColorHex(String? value) {
  return switch (value?.trim()) {
    'lightBlue' => '#0078D4',
    'lightGreen' => '#107C10',
    'lightOrange' => '#D83B01',
    'lightGray' => '#7A7574',
    'lightYellow' => '#F2C811',
    'lightTeal' => '#008575',
    'lightPink' => '#E3008C',
    'lightBrown' => '#8E562E',
    'lightRed' => '#D13438',
    _ => null,
  };
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

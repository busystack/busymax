import 'dart:math' as math;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';

import 'l10n.dart';
import 'time_format.dart';

export 'time_format.dart';

/// Place above the navigator so routes and overlays observe the same snapshot.
class BusyMaxTimeFormatScope extends InheritedWidget {
  const BusyMaxTimeFormatScope({
    required this.formatter,
    required super.child,
    super.key,
  });

  final BusyMaxTimeFormatter formatter;

  static BusyMaxTimeFormatter of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BusyMaxTimeFormatScope>()
          ?.formatter ??
      BusyMaxTimeFormatter(
        locale: Localizations.localeOf(context).toLanguageTag(),
        use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  bool updateShouldNotify(BusyMaxTimeFormatScope oldWidget) =>
      oldWidget.formatter != formatter;
}

String formatClockTime(BuildContext context, TimeOfDay time) =>
    BusyMaxTimeFormatScope.of(context).formatClock(
      // Calendar layout uses hour 24 for its bottom boundary.
      time.hour == 24 && time.minute == 0 ? 0 : time.hour,
      time.minute,
    );

String formatClockDateTime(
  BuildContext context,
  DateTime value,
  String dateLabel,
) => BusyMaxTimeFormatScope.of(
  context,
).compose(dateLabel, value, context.l10n.dateTimeDisplay);

String formatScheduleBoundary(BuildContext context, int minutes) =>
    BusyMaxTimeFormatScope.of(
      context,
    ).scheduleBoundary(minutes, endOfDayLabel: context.l10n.timeEndOfDay);

/// Measure actual localized labels at the active text scale; shared by ruler
/// layout and all gutter-dependent hit/resize positions.
double clockRulerWidth(BuildContext context, TextStyle style) {
  final formatter = BusyMaxTimeFormatScope.of(context);
  var width = 64.0;
  for (var hour = 0; hour < 24; hour++) {
    final painter = TextPainter(
      text: TextSpan(text: formatter.formatClock(hour, 59), style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    width = math.max(width, painter.width + 20);
    painter.dispose();
  }
  return width;
}

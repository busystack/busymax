import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;
import 'package:flutter/material.dart' show TimeOfDay;

/// Upstream HoursPainter returns false from shouldRepaint. A clock/locale
/// change can change text without changing the canvas size, so repaint it.
class BusyMaxClockHoursPainter extends icv.HoursPainter {
  BusyMaxClockHoursPainter({
    required super.heightPerMinute,
    super.textDirection,
    super.hourColor,
    super.halfHourColor,
    super.quarterHourColor,
    super.currentHourIndicatorColor,
    super.quarterHourMinHeightPerMinute,
    super.textPainterBuilder,
    this.currentLabelSeparation = 10,
  });

  final double currentLabelSeparation;

  @override
  bool isHideByCurrentTime(TimeOfDay currentTime, double y) =>
      showCurrentHour &&
      ((currentTime.hour * 60 + currentTime.minute) * heightPerMinute - y)
              .abs() <=
          currentLabelSeparation;

  @override
  bool shouldRepaint(covariant icv.HoursPainter oldDelegate) => true;
}

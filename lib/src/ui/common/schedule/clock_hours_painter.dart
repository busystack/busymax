import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

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
  });

  @override
  bool shouldRepaint(covariant icv.HoursPainter oldDelegate) => true;
}

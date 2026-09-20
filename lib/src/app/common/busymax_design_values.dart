import 'package:flutter/widgets.dart';

abstract final class BusyMaxSpacing {
  static const double xSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double xLarge = 24;
  static const double xxLarge = 32;
}

abstract final class BusyMaxDimensions {
  static const double minimumWindowWidth = 900;
  static const double minimumWindowHeight = 600;
  static const double initialWindowWidth = 1280;
  static const double initialWindowHeight = 800;
  static const double navigationCompactWidth = 48;
  static const double navigationOpenWidth = 240;
  static const double sourcePaneWidth = 264;
  static const double editorWidth = 440;
  static const double contentMaximumWidth = 1120;
}

abstract final class BusyMaxBreakpoints {
  static const double compact = 720;
  static const double sourcePane = 980;
  static const double wide = 1280;

  static bool showsSourcePane(double width) => width >= sourcePane;
}

abstract final class BusyMaxMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 167);
  static const Duration slow = Duration(milliseconds: 250);

  static const Duration dialogInsets = Duration(milliseconds: 160);
  static const Curve dialogInsetsCurve = Curves.easeOutCubic;

  /// Behavioral delay; unlike presentation durations this is never disabled.
  static const Duration tooltipWait = Duration(milliseconds: 500);

  static const Duration sidebar = Duration(milliseconds: 200);
  static const Duration search = Duration(milliseconds: 160);
  static const Duration calendarPeriod = Duration(milliseconds: 200);
  static const Duration crossfade = Duration(milliseconds: 140);
  static const Duration accountDisclosure = Duration(milliseconds: 160);
  static const Duration taskCompletion = Duration(milliseconds: 120);
  static const Duration taskListMutation = Duration(milliseconds: 180);
  static const Duration taskEditorOpen = Duration(milliseconds: 180);
  static const Duration taskEditorClose = Duration(milliseconds: 140);
  static const Curve presentationCurve = Curves.easeOutCubic;
}

enum BusyMaxSemanticColorRole {
  accent,
  canvas,
  surface,
  foreground,
  secondaryForeground,
  border,
  success,
  warning,
  error,
  information,
}

enum BusyMaxInteractionState {
  normal,
  hovered,
  pressed,
  focused,
  selected,
  disabled,
}

@immutable
final class BusyMaxPaneState {
  const BusyMaxPaneState({
    required this.availableWidth,
    required this.sourcePaneRequested,
  });

  final double availableWidth;
  final bool sourcePaneRequested;

  bool get showsSourcePane =>
      sourcePaneRequested && BusyMaxBreakpoints.showsSourcePane(availableWidth);
}

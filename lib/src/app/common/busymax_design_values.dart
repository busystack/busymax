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

import 'package:flutter/material.dart';

import '../../../schedule/schedule_item.dart';

typedef ScheduleItemSelectionCallback =
    void Function(
      BuildContext context,
      ScheduleItem item, [
      Offset? globalPosition,
    ]);

typedef ScheduleItemTapCallback =
    void Function(BuildContext context, [Offset? globalPosition]);

typedef ScheduleItemAnchorCallback =
    void Function(ScheduleItem item, BuildContext context);

/// Lets planner chips report their mounted anchors through grouped/all-day
/// layouts without threading the callback through each layout delegate.
class ScheduleItemAnchorScope extends InheritedWidget {
  const ScheduleItemAnchorScope({
    super.key,
    required this.onAnchorAvailable,
    required super.child,
  });

  final ScheduleItemAnchorCallback onAnchorAvailable;

  static void register(BuildContext context, ScheduleItem item) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ScheduleItemAnchorScope>();
    if (scope == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) scope.onAnchorAvailable(item, context);
    });
  }

  @override
  bool updateShouldNotify(ScheduleItemAnchorScope oldWidget) =>
      onAnchorAvailable != oldWidget.onAnchorAvailable;
}

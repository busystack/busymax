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

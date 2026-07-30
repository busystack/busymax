import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../schedule/schedule_view_mode.dart';

abstract final class BusyMaxShortcutActivators {
  static const keyboardShortcuts = SingleActivator(
    LogicalKeyboardKey.slash,
    control: true,
  );
  static const settings = SingleActivator(
    LogicalKeyboardKey.comma,
    control: true,
  );
  static const search = SingleActivator(LogicalKeyboardKey.keyF, control: true);
  static const create = SingleActivator(LogicalKeyboardKey.keyN, control: true);
  static const dismiss = SingleActivator(LogicalKeyboardKey.escape);
}

abstract final class BusyMaxShortcutLabels {
  static const keyboardShortcuts = 'Ctrl+/';
  static const settings = 'Ctrl+,';
  static const search = 'Ctrl+F';
  static const create = 'Ctrl+N';
  static const previousPeriod = 'Shift+Left';
  static const nextPeriod = 'Shift+Right';
  static const today = 'Shift+T';
  static const newEvent = 'E';
  static const newTask = 'T';
  static const dayView = '1 / D';
  static const weekView = '2 / W';
  static const monthView = '3 / M';
  static const yearView = '4 / Y';
  static const agendaView = '0 / A';
  static const refreshCompactAgenda = 'Ctrl+R';
  static const dismiss = 'Esc';

  static String forViewMode(ScheduleViewMode mode) {
    return switch (mode) {
      ScheduleViewMode.day => dayView,
      ScheduleViewMode.week => weekView,
      ScheduleViewMode.month => monthView,
      ScheduleViewMode.year => yearView,
      ScheduleViewMode.agenda => agendaView,
    };
  }
}

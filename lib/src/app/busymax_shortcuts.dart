import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../schedule/schedule_view_mode.dart';

abstract final class BusyMaxShortcutActivators {
  static const keyboardShortcuts = SingleActivator(
    LogicalKeyboardKey.keyK,
    control: true,
    alt: true,
  );
  static const settings = SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
    alt: true,
  );
  static const search = SingleActivator(LogicalKeyboardKey.keyF, control: true);
  static const sidebar = SingleActivator(LogicalKeyboardKey.f9);
  static const dismiss = SingleActivator(LogicalKeyboardKey.escape);
}

abstract final class BusyMaxShortcutLabels {
  static const keyboardShortcuts = 'Ctrl+Alt+K';
  static const settings = 'Ctrl+Alt+S';
  static const search = 'Ctrl+F';
  static const sidebar = 'F9';
  static const previousPeriod = 'Shift+Left';
  static const nextPeriod = 'Shift+Right';
  static const today = 'Shift+T';
  static const newEvent = 'E';
  static const newTask = 'T';
  static const dayView = '1';
  static const weekView = '2';
  static const monthView = '3';
  static const yearView = '4';
  static const agendaView = '5';
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

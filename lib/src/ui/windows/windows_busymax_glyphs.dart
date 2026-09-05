import 'package:fluent_ui/fluent_ui.dart' show IconData;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../common/busymax_glyph.dart';

IconData windowsBusyMaxGlyph(BusyMaxGlyph glyph) => switch (glyph) {
  BusyMaxGlyph.calendar => FluentIcons.calendar_24_regular,
  BusyMaxGlyph.task => FluentIcons.clipboard_task_24_regular,
  BusyMaxGlyph.add => FluentIcons.add_24_regular,
  BusyMaxGlyph.edit => FluentIcons.edit_24_regular,
  BusyMaxGlyph.delete => FluentIcons.delete_24_regular,
  BusyMaxGlyph.refresh ||
  BusyMaxGlyph.sync => FluentIcons.arrow_sync_24_regular,
  BusyMaxGlyph.settings => FluentIcons.settings_24_regular,
  BusyMaxGlyph.account => FluentIcons.person_24_regular,
  BusyMaxGlyph.warning => FluentIcons.warning_24_regular,
  BusyMaxGlyph.error => FluentIcons.error_circle_24_regular,
  BusyMaxGlyph.information => FluentIcons.info_24_regular,
  BusyMaxGlyph.search => FluentIcons.search_24_regular,
  BusyMaxGlyph.previous => FluentIcons.arrow_left_24_regular,
  BusyMaxGlyph.next => FluentIcons.arrow_right_24_regular,
  BusyMaxGlyph.today => FluentIcons.calendar_today_24_regular,
  BusyMaxGlyph.month => FluentIcons.calendar_month_24_regular,
  BusyMaxGlyph.agenda => FluentIcons.calendar_agenda_24_regular,
  BusyMaxGlyph.recurrence => FluentIcons.arrow_repeat_all_24_regular,
  BusyMaxGlyph.reminder => FluentIcons.clock_alarm_24_regular,
  BusyMaxGlyph.close => FluentIcons.dismiss_24_regular,
  BusyMaxGlyph.more => FluentIcons.more_horizontal_24_regular,
  BusyMaxGlyph.check => FluentIcons.checkmark_24_regular,
  BusyMaxGlyph.signOut => FluentIcons.sign_out_24_regular,
  BusyMaxGlyph.diagnostics => FluentIcons.clipboard_error_24_regular,
  BusyMaxGlyph.feedback => FluentIcons.comment_24_regular,
  BusyMaxGlyph.privacy => FluentIcons.shield_24_regular,
};

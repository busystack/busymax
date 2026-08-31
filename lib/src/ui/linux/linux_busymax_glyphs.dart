import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:yaru/yaru.dart';

import '../common/busymax_glyph.dart';

IconData linuxBusyMaxGlyph(BusyMaxGlyph glyph) => switch (glyph) {
  BusyMaxGlyph.calendar => YaruIcons.calendar,
  BusyMaxGlyph.task => Icons.task_alt_outlined,
  BusyMaxGlyph.add => YaruIcons.plus,
  BusyMaxGlyph.edit => Icons.edit_outlined,
  BusyMaxGlyph.delete => YaruIcons.trash,
  BusyMaxGlyph.refresh || BusyMaxGlyph.sync => YaruIcons.refresh,
  BusyMaxGlyph.settings => YaruIcons.settings,
  BusyMaxGlyph.account => YaruIcons.user,
  BusyMaxGlyph.warning => YaruIcons.warning,
  BusyMaxGlyph.error => YaruIcons.error,
  BusyMaxGlyph.information => Icons.info_outline,
  BusyMaxGlyph.search => YaruIcons.search,
  BusyMaxGlyph.previous => YaruIcons.arrow_left,
  BusyMaxGlyph.next => YaruIcons.arrow_right,
  BusyMaxGlyph.today => Icons.calendar_today_outlined,
  BusyMaxGlyph.month => Icons.calendar_view_month,
  BusyMaxGlyph.agenda => Icons.view_agenda_outlined,
  BusyMaxGlyph.recurrence => Icons.repeat,
  BusyMaxGlyph.reminder => YaruIcons.bell,
  BusyMaxGlyph.close => YaruIcons.window_close,
  BusyMaxGlyph.more => YaruIcons.view_more,
  BusyMaxGlyph.check => YaruIcons.ok,
  BusyMaxGlyph.signOut => YaruIcons.log_out,
  BusyMaxGlyph.diagnostics => YaruIcons.monitor,
  BusyMaxGlyph.feedback => Icons.feedback_outlined,
  BusyMaxGlyph.privacy => YaruIcons.shield,
};

String? linuxNativeMenuGlyph(BusyMaxGlyph glyph) => switch (glyph) {
  BusyMaxGlyph.calendar || BusyMaxGlyph.today => 'x-office-calendar-symbolic',
  BusyMaxGlyph.task || BusyMaxGlyph.check => 'checkbox-checked-symbolic',
  BusyMaxGlyph.add => 'list-add-symbolic',
  BusyMaxGlyph.edit => 'document-edit-symbolic',
  BusyMaxGlyph.delete => 'user-trash-symbolic',
  BusyMaxGlyph.refresh || BusyMaxGlyph.sync => 'view-refresh-symbolic',
  BusyMaxGlyph.settings => 'preferences-system-symbolic',
  BusyMaxGlyph.account => 'avatar-default-symbolic',
  BusyMaxGlyph.warning => 'dialog-warning-symbolic',
  BusyMaxGlyph.error => 'dialog-error-symbolic',
  BusyMaxGlyph.information => 'help-about-symbolic',
  BusyMaxGlyph.search => 'system-search-symbolic',
  BusyMaxGlyph.reminder => 'preferences-system-notifications-symbolic',
  BusyMaxGlyph.privacy => 'security-high-symbolic',
  _ => null,
};

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
  static const dismiss = 'Esc';
}

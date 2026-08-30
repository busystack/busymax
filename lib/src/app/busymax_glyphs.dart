import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:yaru/yaru.dart';

/// Direction-aware glyphs used by BusyMax navigation and hierarchy controls.
///
/// Yaru's directional glyphs do not opt in to Flutter's automatic mirroring,
/// so callers select the matching physical glyph explicitly.
abstract final class BusyMaxGlyphs {
  const BusyMaxGlyphs._();

  /// Maps Flutter menu glyphs to equivalent freedesktop themed icons.
  ///
  /// GTK menu models consume themed-icon names rather than Flutter font
  /// glyphs, so the native bridge uses this catalog to retain menu artwork.
  static String? nativeMenuIconName(IconData? icon) {
    if (icon == null) {
      return null;
    }
    if (icon == YaruIcons.refresh || icon == Icons.refresh) {
      return 'view-refresh-symbolic';
    }
    if (icon == YaruIcons.trash || icon == Icons.delete_outline) {
      return 'user-trash-symbolic';
    }
    if (icon == Icons.open_in_browser_outlined) {
      return 'external-link-symbolic';
    }
    if (icon == Icons.edit_outlined) {
      return 'document-edit-symbolic';
    }
    if (icon == Icons.palette_outlined) {
      return 'color-select-symbolic';
    }
    if (icon == Icons.notifications_outlined) {
      return 'preferences-system-notifications-symbolic';
    }
    if (icon == Icons.notifications_off_outlined) {
      return 'notifications-disabled-symbolic';
    }
    if (icon == Icons.calendar_view_day_outlined ||
        icon == YaruIcons.calendar_day) {
      return 'calendar-app-symbolic';
    }
    if (icon == Icons.view_week_outlined) {
      return 'calendar-week-symbolic';
    }
    if (icon == Icons.calendar_view_month) {
      return 'calendar-month-symbolic';
    }
    if (icon == Icons.calendar_today_outlined || icon == Icons.event_outlined) {
      return 'x-office-calendar-symbolic';
    }
    if (icon == Icons.view_agenda_outlined) {
      return 'calendar-agenda-symbolic';
    }
    if (icon == YaruIcons.settings || icon == Icons.settings_outlined) {
      return 'preferences-system-symbolic';
    }
    if (icon == Icons.keyboard_alt_outlined ||
        icon == YaruIcons.keyboard_shortcuts) {
      return 'input-keyboard-symbolic';
    }
    if (icon == YaruIcons.warning) {
      return 'dialog-warning-symbolic';
    }
    if (icon == Icons.info_outline) {
      return 'help-about-symbolic';
    }
    if (icon == Icons.task_alt_outlined) {
      return 'checkbox-checked-symbolic';
    }
    if (icon == YaruIcons.user) {
      return 'avatar-default-symbolic';
    }
    if (icon == YaruIcons.desktop) {
      return 'video-display-symbolic';
    }
    if (icon == YaruIcons.bell) {
      return 'preferences-system-notifications-symbolic';
    }
    if (icon == YaruIcons.shield_warning) {
      return 'security-high-symbolic';
    }
    if (icon == YaruIcons.monitor) {
      return 'diagnostics-symbolic';
    }
    return null;
  }

  static IconData backFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? YaruIcons.arrow_right
        : YaruIcons.arrow_left;
  }

  static IconData previousFor(TextDirection direction) => backFor(direction);

  static IconData nextFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? YaruIcons.arrow_left
        : YaruIcons.arrow_right;
  }

  static IconData forwardFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? YaruIcons.go_previous
        : YaruIcons.go_next;
  }

  static IconData collapsedFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? YaruIcons.pan_start
        : YaruIcons.pan_end;
  }

  static IconData startFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? YaruIcons.pan_end
        : YaruIcons.pan_start;
  }

  static IconData endFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? YaruIcons.pan_start
        : YaruIcons.pan_end;
  }

  static IconData chevronForwardFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
  }

  static IconData subdirectoryFor(TextDirection direction) {
    return direction == TextDirection.rtl
        ? Icons.subdirectory_arrow_left
        : Icons.subdirectory_arrow_right;
  }
}

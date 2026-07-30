import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:yaru/yaru.dart';

/// Direction-aware glyphs used by BusyMax navigation and hierarchy controls.
///
/// Yaru's directional glyphs do not opt in to Flutter's automatic mirroring,
/// so callers select the matching physical glyph explicitly.
abstract final class BusyMaxGlyphs {
  const BusyMaxGlyphs._();

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

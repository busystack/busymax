import 'dart:io';

import 'package:busymax/src/app/busymax_glyphs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  test('navigation glyphs resolve for both reading directions', () {
    expect(BusyMaxGlyphs.backFor(TextDirection.ltr), YaruIcons.arrow_left);
    expect(BusyMaxGlyphs.backFor(TextDirection.rtl), YaruIcons.arrow_right);
    expect(BusyMaxGlyphs.previousFor(TextDirection.ltr), YaruIcons.arrow_left);
    expect(BusyMaxGlyphs.previousFor(TextDirection.rtl), YaruIcons.arrow_right);
    expect(BusyMaxGlyphs.nextFor(TextDirection.ltr), YaruIcons.arrow_right);
    expect(BusyMaxGlyphs.nextFor(TextDirection.rtl), YaruIcons.arrow_left);
    expect(BusyMaxGlyphs.forwardFor(TextDirection.ltr), YaruIcons.go_next);
    expect(BusyMaxGlyphs.forwardFor(TextDirection.rtl), YaruIcons.go_previous);
    expect(BusyMaxGlyphs.collapsedFor(TextDirection.ltr), YaruIcons.pan_end);
    expect(BusyMaxGlyphs.collapsedFor(TextDirection.rtl), YaruIcons.pan_start);
  });

  test('hierarchy glyphs resolve for both reading directions', () {
    expect(
      BusyMaxGlyphs.chevronForwardFor(TextDirection.ltr),
      Icons.chevron_right,
    );
    expect(
      BusyMaxGlyphs.chevronForwardFor(TextDirection.rtl),
      Icons.chevron_left,
    );
    expect(
      BusyMaxGlyphs.subdirectoryFor(TextDirection.ltr),
      Icons.subdirectory_arrow_right,
    );
    expect(
      BusyMaxGlyphs.subdirectoryFor(TextDirection.rtl),
      Icons.subdirectory_arrow_left,
    );
  });

  test('calendar option glyphs resolve for native GTK menus', () {
    expect(
      BusyMaxGlyphs.nativeMenuIconName(Icons.palette_outlined),
      'color-select-symbolic',
    );
    expect(
      BusyMaxGlyphs.nativeMenuIconName(Icons.notifications_outlined),
      'preferences-system-notifications-symbolic',
    );
    expect(
      BusyMaxGlyphs.nativeMenuIconName(Icons.notifications_off_outlined),
      'notifications-disabled-symbolic',
    );
  });

  test('Arabic and Persian glyph coverage is packaged in the snap', () {
    expect(
      File('snap/snapcraft.yaml').readAsStringSync(),
      contains('fonts-noto-core'),
    );
  });
}

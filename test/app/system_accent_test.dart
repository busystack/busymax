import 'package:busymax/src/app/system_accent.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/theme.dart';

void main() {
  test('reads RGB portal accent color values', () {
    final value = DBusStruct([
      const DBusDouble(0.7843137383460999),
      const DBusDouble(0.5333333611488342),
      const DBusDouble(0),
    ]);

    expect(colorFromPortalAccentValue(value), const Color(0xffc88800));
    expect(
      colorFromPortalAccentValue(DBusVariant(value)),
      const Color(0xffc88800),
    );
  });

  test('maps Ubuntu accent names when RGB portal value is unavailable', () {
    expect(ubuntuAccentNameColor('yellow'), const Color(0xffc88800));
    expect(
      colorFromUbuntuAccentNameValue(const DBusString('purple')),
      const Color(0xff7764d8),
    );
    expect(ubuntuAccentNameColor('orange'), YaruColors.orange);
    expect(colorFromUbuntuAccentNameValue(const DBusString('unknown')), isNull);
  });
}

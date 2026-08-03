import 'dart:async';

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

  test('falls back to the Ubuntu setting when the RGB read fails', () async {
    var readGnome = false;

    final color = await readPreferredLinuxAccentColor(
      readFreedesktop: () => Future<Color?>.error(
        StateError('freedesktop accent key is unavailable'),
      ),
      readGnome: () async {
        readGnome = true;
        return YaruVariant.orange.color;
      },
    );

    expect(color, YaruVariant.orange.color);
    expect(readGnome, isTrue);
  });

  test('does not read the named fallback after an exact RGB result', () async {
    var readGnome = false;
    const exactRgb = Color(0xFF336699);

    final color = await readPreferredLinuxAccentColor(
      readFreedesktop: () async => exactRgb,
      readGnome: () async {
        readGnome = true;
        return YaruVariant.blue.color;
      },
    );

    expect(color, exactRgb);
    expect(readGnome, isFalse);
  });

  test('an exact RGB signal remains authoritative over named signals', () {
    final resolver = LinuxAccentChangeResolver();
    final exactRgb = DBusStruct([
      const DBusDouble(0.2),
      const DBusDouble(0.4),
      const DBusDouble(0.6),
    ]);

    expect(
      resolver.resolve(
        'org.gnome.desktop.interface',
        const DBusString('orange'),
      ),
      YaruVariant.orange.color,
    );
    expect(
      resolver.resolve('org.freedesktop.appearance', exactRgb),
      const Color(0xFF336699),
    );
    expect(
      resolver.resolve('org.gnome.desktop.interface', const DBusString('blue')),
      isNull,
    );
  });

  test('subscribes before reading the initial accent snapshot', () async {
    var subscribed = false;
    final snapshot = Completer<Color?>();
    final changes = StreamController<LinuxAccentSettingChange>(
      onListen: () => subscribed = true,
    );
    final colors = watchPreferredLinuxAccentColors(
      readFreedesktop: () => snapshot.future,
      readGnome: () async => YaruVariant.orange.color,
      changes: changes.stream,
    ).toList();

    await Future<void>.delayed(Duration.zero);
    expect(subscribed, isTrue);
    changes.add((
      namespace: 'org.freedesktop.appearance',
      value: DBusStruct([
        const DBusDouble(0.2),
        const DBusDouble(0.4),
        const DBusDouble(0.6),
      ]),
    ));
    snapshot.complete(null);
    await changes.close();

    expect(await colors, [YaruVariant.orange.color, const Color(0xFF336699)]);
  });

  test(
    'an initial exact accent cannot be downgraded by a named signal',
    () async {
      const exactRgb = Color(0xFF336699);
      final snapshot = Completer<Color?>();
      final changes = StreamController<LinuxAccentSettingChange>();
      final colors = watchPreferredLinuxAccentColors(
        readFreedesktop: () => snapshot.future,
        readGnome: () async => YaruVariant.orange.color,
        changes: changes.stream,
      ).toList();

      await Future<void>.delayed(Duration.zero);
      changes.add((
        namespace: 'org.gnome.desktop.interface',
        value: const DBusString('blue'),
      ));
      snapshot.complete(exactRgb);
      await changes.close();

      expect(await colors, [exactRgb]);
    },
  );
}

import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/theme.dart';

final linuxPortalAppearanceProvider = Provider<LinuxPortalAppearance>(
  (ref) => const LinuxPortalAppearance(),
);

final ubuntuSystemAccentColorProvider = StreamProvider<Color>((ref) async* {
  if (!Platform.isLinux) {
    return;
  }

  final appearance = ref.watch(linuxPortalAppearanceProvider);
  final initial = await appearance.readAccentColor();
  if (initial != null) {
    yield initial;
  }
  yield* appearance.accentColorChanges().distinct();
});

class LinuxPortalAppearance {
  const LinuxPortalAppearance();

  static const _portalDestination = 'org.freedesktop.portal.Desktop';
  static const _portalPath = '/org/freedesktop/portal/desktop';
  static const _settingsInterface = 'org.freedesktop.portal.Settings';
  static const _freedesktopAppearance = 'org.freedesktop.appearance';
  static const _gnomeInterface = 'org.gnome.desktop.interface';
  static const _accentColor = 'accent-color';

  Future<Color?> readAccentColor() async {
    final client = DBusClient.session();
    try {
      final object = _portalObject(client);
      return await _readFreedesktopAccent(object) ??
          await _readGnomeAccentName(object);
    } on Object {
      return null;
    } finally {
      await client.close();
    }
  }

  Stream<Color> accentColorChanges() async* {
    final client = DBusClient.session();
    try {
      final object = _portalObject(client);
      final signals = DBusRemoteObjectSignalStream(
        object: object,
        interface: _settingsInterface,
        name: 'SettingChanged',
        signature: DBusSignature('ssv'),
      );
      await for (final signal in signals) {
        final namespace = signal.values[0].asString();
        final key = signal.values[1].asString();
        if (key != _accentColor) {
          continue;
        }
        final value = signal.values[2].asVariant();
        final color = namespace == _freedesktopAppearance
            ? colorFromPortalAccentValue(value)
            : namespace == _gnomeInterface
            ? colorFromUbuntuAccentNameValue(value)
            : null;
        if (color != null) {
          yield color;
        }
      }
    } on Object {
      return;
    } finally {
      await client.close();
    }
  }

  DBusRemoteObject _portalObject(DBusClient client) {
    return DBusRemoteObject(
      client,
      name: _portalDestination,
      path: DBusObjectPath(_portalPath),
    );
  }

  Future<Color?> _readFreedesktopAccent(DBusRemoteObject object) async {
    final value = await _readSetting(
      object,
      _freedesktopAppearance,
      _accentColor,
    );
    return value == null ? null : colorFromPortalAccentValue(value);
  }

  Future<Color?> _readGnomeAccentName(DBusRemoteObject object) async {
    final value = await _readSetting(object, _gnomeInterface, _accentColor);
    return value == null ? null : colorFromUbuntuAccentNameValue(value);
  }

  Future<DBusValue?> _readSetting(
    DBusRemoteObject object,
    String namespace,
    String key,
  ) async {
    final response = await object.callMethod(_settingsInterface, 'Read', [
      DBusString(namespace),
      DBusString(key),
    ], replySignature: DBusSignature('v'));
    return response.returnValues.single.asVariant();
  }
}

Color? colorFromPortalAccentValue(DBusValue value) {
  final resolved = value.signature == DBusSignature('v')
      ? value.asVariant()
      : value;
  if (resolved.signature != DBusSignature('(ddd)')) {
    return null;
  }
  final channels = resolved.asStruct();
  if (channels.length != 3) {
    return null;
  }
  final red = _colorChannel(channels[0].asDouble());
  final green = _colorChannel(channels[1].asDouble());
  final blue = _colorChannel(channels[2].asDouble());
  return Color.fromARGB(255, red, green, blue);
}

Color? colorFromUbuntuAccentNameValue(DBusValue value) {
  final resolved = value.signature == DBusSignature('v')
      ? value.asVariant()
      : value;
  if (resolved.signature != DBusSignature('s')) {
    return null;
  }
  return ubuntuAccentNameColor(resolved.asString());
}

Color? ubuntuAccentNameColor(String name) {
  return switch (name) {
    'blue' => YaruVariant.blue.color,
    'teal' => YaruVariant.adwaitaTeal.color,
    'green' => YaruVariant.adwaitaGreen.color,
    'yellow' => YaruVariant.adwaitaYellow.color,
    'orange' => YaruVariant.orange.color,
    'red' => YaruVariant.red.color,
    'pink' => YaruVariant.magenta.color,
    'purple' => YaruVariant.purple.color,
    'slate' => YaruVariant.adwaitaSlate.color,
    'brown' => YaruVariant.wartyBrown.color,
    'magenta' => YaruVariant.magenta.color,
    'olive' => YaruVariant.olive.color,
    'prussiangreen' => YaruVariant.prussianGreen.color,
    'sage' => YaruVariant.sage.color,
    'wartybrown' => YaruVariant.wartyBrown.color,
    _ => null,
  };
}

int _colorChannel(double value) {
  return (value.clamp(0, 1) * 255).round();
}

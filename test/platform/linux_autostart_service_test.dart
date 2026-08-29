import 'dart:io';

import 'package:busymax/src/platform/linux_autostart_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enables and disables XDG launch at login', () async {
    final configHome = await Directory.systemTemp.createTemp(
      'busymax-autostart-',
    );
    addTearDown(() => configHome.delete(recursive: true));
    final service = LinuxAutostartService(
      environment: {'XDG_CONFIG_HOME': configHome.path},
      executable: '/opt/BusyMax/busymax',
      isLinux: true,
    );

    await service.setEnabled(true);

    final file = File('${configHome.path}/autostart/$busyMaxAutostartFileName');
    expect(await service.isEnabled(), isTrue);
    expect(await file.exists(), isTrue);
    final entry = await file.readAsString();
    expect(entry, contains('Exec="/opt/BusyMax/busymax" --start-minimized'));
    expect(entry, contains('X-BusyMax-Autostart=true'));

    await service.setEnabled(false);

    expect(await service.isEnabled(), isFalse);
    expect(await file.exists(), isFalse);
  });

  test('writes the Snap command in the Snap user configuration', () async {
    final configHome = await Directory.systemTemp.createTemp(
      'busymax-snap-autostart-',
    );
    addTearDown(() => configHome.delete(recursive: true));
    final service = LinuxAutostartService(
      environment: {
        'XDG_CONFIG_HOME': configHome.path,
        'SNAP': '/snap/busymax/current',
      },
      executable: '/snap/busymax/current/busymax',
      isLinux: true,
    );

    await service.setEnabled(true);

    final entry = await File(
      '${configHome.path}/autostart/$busyMaxAutostartFileName',
    ).readAsString();
    expect(entry, contains('Exec=busymax --start-minimized'));
  });

  test('rejects a relative XDG configuration directory', () async {
    final service = LinuxAutostartService(
      environment: const {'XDG_CONFIG_HOME': 'relative/config'},
      executable: '/usr/bin/busymax',
      isLinux: true,
    );

    await expectLater(
      service.setEnabled(true),
      throwsA(isA<FileSystemException>()),
    );
  });
}

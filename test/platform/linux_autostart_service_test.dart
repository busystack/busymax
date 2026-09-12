import 'dart:io';

import 'package:busymax/src/platform/linux_autostart_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entryCase in <({String contents, bool enabled})>[
    (contents: 'Hidden=true', enabled: false),
    (contents: 'Hidden=false', enabled: true),
    (contents: '# Hidden=true\nHidden = false', enabled: true),
    (contents: 'X-GNOME-Autostart-enabled=false', enabled: false),
    (contents: 'OnlyShowIn=KDE;', enabled: false),
    (contents: 'OnlyShowIn=GNOME;', enabled: true),
    (contents: 'NotShowIn=GNOME;', enabled: false),
    (contents: 'TryExec=/missing/busymax-executable', enabled: false),
    (
      contents: 'Hidden=false\n[Desktop Action Other]\nHidden=true',
      enabled: true,
    ),
  ]) {
    test('interprets autostart entry: ${entryCase.contents}', () async {
      final configHome = await Directory.systemTemp.createTemp(
        'busymax-autostart-test-',
      );
      addTearDown(() => configHome.delete(recursive: true));
      final service = LinuxAutostartService(
        environment: {
          'XDG_CONFIG_HOME': configHome.path,
          'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME',
          'PATH': '/bin:/usr/bin',
        },
        executable: '/opt/BusyMax/busymax',
        isLinux: true,
      );
      await service.setEnabled(true);
      final file = File(
        '${configHome.path}/autostart/$busyMaxAutostartFileName',
      );
      await file.writeAsString(
        '[Desktop Entry]\nType=Application\nExec=busymax\n${entryCase.contents}\n',
      );
      expect(await service.isEnabled(), entryCase.enabled);
      expect(
        await service.state(),
        entryCase.enabled
            ? DesktopAutostartState.enabled
            : DesktopAutostartState.disabled,
      );
      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
    });
  }

  test('resolves a TryExec command from a Unix search path', () async {
    final configHome = await Directory.systemTemp.createTemp(
      'busymax-autostart-try-exec-',
    );
    addTearDown(() => configHome.delete(recursive: true));
    final service = LinuxAutostartService(
      environment: {
        'XDG_CONFIG_HOME': configHome.path,
        'PATH': '/bin:/usr/bin',
      },
      isLinux: true,
    );
    await service.setEnabled(true);
    final file = File('${configHome.path}/autostart/$busyMaxAutostartFileName');
    await file.writeAsString(
      '[Desktop Entry]\nType=Application\nExec=busymax\nTryExec=sh\n',
    );

    expect(await service.isEnabled(), isTrue);
  }, skip: !Platform.isLinux);

  test('concurrent enables use independent temporary files', () async {
    final configHome = await Directory.systemTemp.createTemp(
      'busymax-autostart-concurrent-',
    );
    addTearDown(() => configHome.delete(recursive: true));
    final service = LinuxAutostartService(
      environment: {'XDG_CONFIG_HOME': configHome.path},
      isLinux: true,
    );
    await Future.wait(List.generate(8, (_) => service.setEnabled(true)));
    expect(await service.isEnabled(), isTrue);
    final entries = await Directory(
      '${configHome.path}/autostart',
    ).list().toList();
    expect(entries.map((entry) => entry.path), [
      '${configHome.path}/autostart/$busyMaxAutostartFileName',
    ]);
  });

  test(
    'state read failures propagate and unsupported platforms are unavailable',
    () async {
      final service = LinuxAutostartService(
        environment: {'XDG_CONFIG_HOME': 'relative'},
        isLinux: true,
      );
      await expectLater(service.state(), throwsA(isA<FileSystemException>()));
      expect(
        await LinuxAutostartService(isLinux: false).state(),
        DesktopAutostartState.unavailable,
      );
    },
  );

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

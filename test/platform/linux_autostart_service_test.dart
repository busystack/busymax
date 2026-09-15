import 'dart:io';

import 'package:busymax/src/platform/linux_autostart_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('effective Linux startup state', () {
    late Directory root;
    late String configHome;
    late String systemConfig;
    late String fallbackConfig;
    late Map<String, String> environment;
    late LinuxAutostartService service;
    const activeEntry = '[Desktop Entry]\nType=Application\nExec=busymax\n';

    Future<File> writeEntry(String directory, String contents) async {
      final file = File(
        path.join(directory, 'autostart', busyMaxAutostartFileName),
      );
      await file.parent.create(recursive: true);
      return file.writeAsString(contents);
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'busymax-effective-startup-',
      );
      configHome = path.join(root.path, 'user');
      systemConfig = path.join(root.path, 'system');
      fallbackConfig = path.join(root.path, 'fallback');
      environment = {
        'XDG_CONFIG_HOME': configHome,
        'XDG_CONFIG_DIRS': '$systemConfig:$fallbackConfig',
        'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME',
      };
      service = LinuxAutostartService(
        environment: environment,
        executable: '/opt/BusyMax/busymax',
        isLinux: true,
        processId: 123,
      );
    });
    tearDown(() => root.delete(recursive: true));

    test(
      'reads an inherited entry and disables it with a user override',
      () async {
        final inherited = await writeEntry(systemConfig, activeEntry);
        expect(await service.state(), DesktopAutostartState.enabled);

        await service.setEnabled(false);

        expect(await service.state(), DesktopAutostartState.disabled);
        final override = File(
          path.join(configHome, 'autostart', busyMaxAutostartFileName),
        );
        expect(await override.readAsString(), contains('Hidden=true'));
        expect(await inherited.readAsString(), activeEntry);
        await service.setEnabled(false);
        expect(await service.isEnabled(), isFalse);

        await service.setEnabled(true);
        expect(await service.isEnabled(), isTrue);
        expect(await override.readAsString(), isNot(contains('Hidden=true')));
        expect(await inherited.readAsString(), activeEntry);
      },
    );

    test('disabling a user entry does not expose an inherited entry', () async {
      await writeEntry(systemConfig, activeEntry);
      await service.setEnabled(true);
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
    });

    test(
      'hidden user and system entries mask lower priority entries',
      () async {
        await writeEntry(fallbackConfig, activeEntry);
        expect(await service.isEnabled(), isTrue);
        await writeEntry(systemConfig, '[Desktop Entry]\nHidden=true\n');
        expect(await service.isEnabled(), isFalse);
        await service.setEnabled(true);
        expect(await service.isEnabled(), isTrue);
        await writeEntry(configHome, '[Desktop Entry]\nHidden=true\n');
        await writeEntry(systemConfig, activeEntry);
        expect(await service.isEnabled(), isFalse);
      },
    );

    test(
      'desktop restrictions do not fall back to a lower priority entry',
      () async {
        await writeEntry(systemConfig, '${activeEntry}OnlyShowIn=KDE;\n');
        await writeEntry(fallbackConfig, activeEntry);
        expect(await service.isEnabled(), isFalse);
      },
    );

    test(
      'ignores relative XDG directories and keeps absolute directory order',
      () async {
        environment['XDG_CONFIG_DIRS'] =
            'relative::$systemConfig:$fallbackConfig';
        await writeEntry(systemConfig, '[Desktop Entry]\nHidden=true\n');
        await writeEntry(fallbackConfig, activeEntry);
        expect(await service.isEnabled(), isFalse);
      },
    );

    test(
      'an unreadable effective entry is an error, not an Off result',
      () async {
        await Directory(
          path.join(systemConfig, 'autostart', busyMaxAutostartFileName),
        ).create(recursive: true);
        await expectLater(service.state(), throwsA(isA<FileSystemException>()));
      },
    );

    test(
      'atomic override replaces a user symlink without modifying its target',
      () async {
        final inherited = await writeEntry(systemConfig, activeEntry);
        final userDirectory = Directory(path.join(configHome, 'autostart'));
        await userDirectory.create(recursive: true);
        final link = Link(
          path.join(userDirectory.path, busyMaxAutostartFileName),
        );
        await link.create(inherited.path);
        await service.setEnabled(false);
        expect(await service.isEnabled(), isFalse);
        expect(await inherited.readAsString(), activeEntry);
        expect(await link.exists(), isFalse);
      },
      skip: !Platform.isLinux,
    );

    test('Snap uses only its own autostart entry', () async {
      environment['SNAP'] = '/snap/busymax/current';
      await writeEntry(systemConfig, activeEntry);
      expect(await service.isEnabled(), isFalse);
      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
      await service.setEnabled(false);
      expect(await service.isEnabled(), isFalse);
      expect(
        await File(
          path.join(configHome, 'autostart', busyMaxAutostartFileName),
        ).exists(),
        isFalse,
      );
    });

    test(
      'Snap reports the GNOME startup launch as externally managed',
      () async {
        environment.addAll({
          'SNAP': '/snap/busymax/current',
          'GIO_LAUNCHED_DESKTOP_FILE':
              '/home/example/.config/autostart/busymax_busymax.desktop',
          'GIO_LAUNCHED_DESKTOP_FILE_PID': '123',
        });
        expect(await service.state(), DesktopAutostartState.enabledExternally);
        expect(await service.isEnabled(), isTrue);
        expect((await service.state()).canChange, isFalse);
        for (final enabled in [true, false]) {
          await expectLater(service.setEnabled(enabled), throwsStateError);
        }
        expect(await Directory(configHome).exists(), isFalse);
        // The external entry still controls startup even if a Snap entry exists.
        await writeEntry(configHome, activeEntry);
        expect(await service.state(), DesktopAutostartState.enabledExternally);
      },
    );

    test('Snap ignores inherited GIO metadata from another process', () async {
      environment.addAll({
        'SNAP': '/snap/busymax/current',
        'GIO_LAUNCHED_DESKTOP_FILE':
            '/home/example/.config/autostart/ide.desktop',
        'GIO_LAUNCHED_DESKTOP_FILE_PID': '456',
      });
      expect(await service.state(), DesktopAutostartState.disabled);
      environment.remove('GIO_LAUNCHED_DESKTOP_FILE_PID');
      expect(await service.state(), DesktopAutostartState.disabled);
    });

    test(
      'Snap menu launches and its own startup entry remain changeable',
      () async {
        environment.addAll({
          'SNAP': '/snap/busymax/current',
          'GIO_LAUNCHED_DESKTOP_FILE_PID': '123',
        });
        for (final launchedFile in [
          '/var/lib/snapd/desktop/applications/busymax_busymax.desktop',
          'relative/autostart/busymax.desktop',
          '/home/example/.config/autostart/busymax.desktop.disabled',
          path.join(configHome, 'autostart', busyMaxAutostartFileName),
        ]) {
          environment['GIO_LAUNCHED_DESKTOP_FILE'] = launchedFile;
          expect(await service.state(), DesktopAutostartState.disabled);
          await service.setEnabled(true);
          expect(await service.state(), DesktopAutostartState.enabled);
          await service.setEnabled(false);
        }
      },
    );
  });

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
        path.join(configHome.path, 'autostart', busyMaxAutostartFileName),
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
    final file = File(
      path.join(configHome.path, 'autostart', busyMaxAutostartFileName),
    );
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
    final autostartDirectory = path.join(configHome.path, 'autostart');
    final entries = await Directory(autostartDirectory).list().toList();
    expect(entries.map((entry) => entry.path), [
      path.join(autostartDirectory, busyMaxAutostartFileName),
    ]);
  });

  test('a failed mutation does not prevent a later retry', () async {
    final root = await Directory.systemTemp.createTemp(
      'busymax-autostart-retry-',
    );
    addTearDown(() => root.delete(recursive: true));
    final configHomePath = path.join(root.path, 'config');
    final blockingFile = File(configHomePath);
    await blockingFile.writeAsString('not a directory');
    final service = LinuxAutostartService(
      environment: {'XDG_CONFIG_HOME': configHomePath},
      isLinux: true,
    );

    await expectLater(
      service.setEnabled(true),
      throwsA(isA<FileSystemException>()),
    );
    await blockingFile.delete();
    await Directory(configHomePath).create();

    await service.setEnabled(true);

    expect(await service.isEnabled(), isTrue);
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

    final file = File(
      path.join(configHome.path, 'autostart', busyMaxAutostartFileName),
    );
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
      path.join(configHome.path, 'autostart', busyMaxAutostartFileName),
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

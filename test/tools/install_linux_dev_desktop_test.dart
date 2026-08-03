import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('install_linux_dev_desktop.sh', () {
    test(
      'installs an idempotent Wayland desktop registration',
      () async {
        final dataHome = await Directory.systemTemp.createTemp(
          'busymax-dev-desktop-test-',
        );
        addTearDown(() => dataHome.delete(recursive: true));

        final environment = <String, String>{
          ...Platform.environment,
          'XDG_DATA_HOME': dataHome.path,
        };
        final executable = File(
          'build/linux/x64/debug/bundle/busymax',
        ).absolute.path;

        for (var attempt = 0; attempt < 2; attempt++) {
          final result = await Process.run('bash', <String>[
            'tools/install_linux_dev_desktop.sh',
            '--executable',
            executable,
          ], environment: environment);
          expect(result.exitCode, 0, reason: _processFailure(result));
        }

        final desktop = File(
          '${dataHome.path}/applications/io.busystack.busymax.desktop',
        );
        final icon = File(
          '${dataHome.path}/icons/hicolor/scalable/apps/'
          'io.busystack.busymax.svg',
        );
        expect(desktop.existsSync(), isTrue);
        expect(icon.existsSync(), isTrue);

        final desktopContents = desktop.readAsStringSync();
        expect(desktopContents, contains('Exec="$executable"'));
        expect(desktopContents, contains('Icon=${icon.absolute.path}'));
        expect(
          desktopContents,
          contains('StartupWMClass=io.busystack.busymax'),
        );
        expect(desktopContents, contains('X-BusyMax-Development=true'));
        expect(
          icon.readAsBytesSync(),
          File('assets/branding/busymax-logo.svg').readAsBytesSync(),
        );

        final uninstall = await Process.run('bash', <String>[
          'tools/install_linux_dev_desktop.sh',
          '--uninstall',
        ], environment: environment);
        expect(uninstall.exitCode, 0, reason: _processFailure(uninstall));
        expect(desktop.existsSync(), isFalse);
        expect(icon.existsSync(), isFalse);
      },
      skip: !Platform.isLinux,
    );

    test(
      'does not overwrite a desktop entry it does not own',
      () async {
        final dataHome = await Directory.systemTemp.createTemp(
          'busymax-dev-desktop-unowned-test-',
        );
        addTearDown(() => dataHome.delete(recursive: true));
        final desktop = File(
          '${dataHome.path}/applications/io.busystack.busymax.desktop',
        )..createSync(recursive: true);
        desktop.writeAsStringSync('[Desktop Entry]\nName=Keep me\n');

        final result = await Process.run(
          'bash',
          <String>['tools/install_linux_dev_desktop.sh'],
          environment: <String, String>{
            ...Platform.environment,
            'XDG_DATA_HOME': dataHome.path,
          },
        );

        expect(result.exitCode, isNot(0));
        expect(desktop.readAsStringSync(), '[Desktop Entry]\nName=Keep me\n');
        expect(result.stderr, contains('not owned by this helper'));
      },
      skip: !Platform.isLinux,
    );
  });
}

String _processFailure(ProcessResult result) {
  return 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}';
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('build_install_snap_local.sh', () {
    test('installs without removing the existing snap or its data', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      final result = await fixture.run(
        arguments: <String>['--root', fixture.validRoot.path],
      );

      expect(
        result.exitCode,
        0,
        reason: _processFailure(result, fixture.commandLogContents),
      );
      expect(fixture.commandLogContents, isNot(contains('snap remove')));
      expect(fixture.commandLogContents, isNot(contains('--purge')));
      expect(
        fixture.commandLogContents,
        contains('sudo\tsnap install --dangerous'),
      );
    });

    test('accepts and can reuse an owned temporary staging root', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      final result = await fixture.run(
        arguments: <String>['--root', fixture.validRoot.path],
      );

      expect(
        result.exitCode,
        0,
        reason: _processFailure(result, fixture.commandLogContents),
      );
      expect(
        File('${fixture.validRoot.path}/busymax_test').readAsStringSync(),
        'test binary\n',
      );
      expect(
        File(
          '${fixture.validRoot.path}/.busymax-local-snap-root',
        ).readAsStringSync(),
        'busymax-local-snap-root-v1\n'
        'project=${fixture.project.resolveSymbolicLinksSync()}\n',
      );

      final secondResult = await fixture.run(
        arguments: <String>['--root', fixture.validRoot.path],
      );
      expect(
        secondResult.exitCode,
        0,
        reason: _processFailure(secondResult, fixture.commandLogContents),
      );
      expect(
        fixture.commandLogContents,
        contains('rm\t-rf -- ${fixture.validRoot.path}'),
      );
    });

    test('rejects an existing unowned staging directory before rm', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);
      fixture.validRoot.createSync(recursive: true);
      final sentinel = File('${fixture.validRoot.path}/keep-me')
        ..writeAsStringSync('private data');

      await _expectUnsafeRootRejected(
        fixture,
        arguments: <String>['--root', fixture.validRoot.path],
      );
      expect(sentinel.readAsStringSync(), 'private data');
    });

    test(
      'rejects a staging directory with a foreign ownership marker',
      () async {
        final fixture = await _LocalSnapFixture.create();
        addTearDown(fixture.dispose);
        fixture.validRoot.createSync(recursive: true);
        final sentinel = File('${fixture.validRoot.path}/keep-me')
          ..writeAsStringSync('private data');
        File(
          '${fixture.validRoot.path}/.busymax-local-snap-root',
        ).writeAsStringSync(
          'busymax-local-snap-root-v1\nproject=/another/project\n',
        );

        await _expectUnsafeRootRejected(
          fixture,
          arguments: <String>['--root', fixture.validRoot.path],
        );
        expect(sentinel.readAsStringSync(), 'private data');
      },
    );

    test('rejects a root filesystem --root before invoking rm', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        arguments: const <String>['--root', '/'],
      );
    });

    test('rejects SNAP_ROOT equal to the home directory', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        environment: <String, String>{'SNAP_ROOT': fixture.home.path},
      );
    });

    test('rejects --root equal to the repository', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        arguments: <String>['--root', fixture.project.path],
      );
    });

    test('rejects a root that contains the repository', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        arguments: <String>['--root', fixture.root.path],
      );
    });

    test('rejects relative aliases of the repository', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        arguments: const <String>['--root', 'tools/..'],
      );
    });

    test('rejects symlinks that resolve to the repository', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);
      final alias = Link('${fixture.safeStaging.path}/repository-alias');
      await alias.create(fixture.project.path);

      await _expectUnsafeRootRejected(
        fixture,
        arguments: <String>['--root', alias.path],
      );
    });

    test('rejects an explicitly empty --root', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        arguments: const <String>['--root', ''],
      );
    });

    test('rejects an explicitly empty SNAP_ROOT', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);

      await _expectUnsafeRootRejected(
        fixture,
        environment: const <String, String>{'SNAP_ROOT': ''},
      );
    });

    test('rejects binary-name path traversal before invoking rm', () async {
      final fixture = await _LocalSnapFixture.create();
      addTearDown(fixture.dispose);
      _writeFile(
        '${fixture.project.path}/build/linux/x64/release/victim',
        'built binary\n',
      );
      final victim = File('${fixture.safeStaging.path}/victim')
        ..writeAsStringSync('do not delete');

      final result = await fixture.run(
        arguments: <String>[
          '--root',
          fixture.validRoot.path,
          '--binary-name',
          '../victim',
        ],
      );
      final output = '${result.stdout}\n${result.stderr}'.toLowerCase();

      expect(result.exitCode, isNot(0));
      expect(output, contains('error:'));
      expect(output, contains('binary'));
      expect(
        fixture.commandLogContents.split('\n'),
        isNot(contains(startsWith('rm\t'))),
      );
      expect(fixture.commandLogContents, isNot(contains('sudo\tsnap install')));
      expect(victim.readAsStringSync(), 'do not delete');
    });
  });
}

Future<void> _expectUnsafeRootRejected(
  _LocalSnapFixture fixture, {
  List<String> arguments = const <String>[],
  Map<String, String> environment = const <String, String>{},
}) async {
  final result = await fixture.run(
    arguments: arguments,
    environment: environment,
  );
  final output = '${result.stdout}\n${result.stderr}'.toLowerCase();

  expect(
    result.exitCode,
    isNot(0),
    reason: 'unsafe root unexpectedly succeeded:\n$output',
  );
  expect(output, contains('error:'));
  expect(output, contains('root'));
  expect(
    fixture.commandLogContents.split('\n'),
    isNot(contains(startsWith('rm\t'))),
    reason:
        'root validation must happen before rm:\n'
        '${fixture.commandLogContents}',
  );
  expect(fixture.commandLogContents, isNot(contains('sudo\tsnap install')));
}

String _processFailure(ProcessResult result, String commandLog) {
  return 'exit code: ${result.exitCode}\n'
      'stdout:\n${result.stdout}\n'
      'stderr:\n${result.stderr}\n'
      'commands:\n$commandLog';
}

final class _LocalSnapFixture {
  _LocalSnapFixture._({
    required this.root,
    required this.project,
    required this.home,
    required this.safeStaging,
    required this.validRoot,
    required this.scaffold,
    required this.output,
    required this.fakeBin,
    required this.commandLog,
  });

  final Directory root;
  final Directory project;
  final Directory home;
  final Directory safeStaging;
  final Directory validRoot;
  final Directory scaffold;
  final File output;
  final Directory fakeBin;
  final File commandLog;

  String get commandLogContents =>
      commandLog.existsSync() ? commandLog.readAsStringSync() : '';

  static Future<_LocalSnapFixture> create() async {
    final root = await Directory.systemTemp.createTemp(
      'busymax_snap_helper_test.',
    );
    final project = Directory('${root.path}/project')..createSync();
    final home = Directory('${root.path}/home')..createSync();
    final safeStaging = Directory('${root.path}/safe-staging')..createSync();
    final validRoot = Directory('${safeStaging.path}/snap-root');
    final scaffold = Directory('${root.path}/scaffold')..createSync();
    final output = File('${root.path}/output/busymax_test.snap');
    final fakeBin = Directory('${root.path}/fake-bin')..createSync();
    final commandLog = File('${root.path}/commands.log');

    _writeFile(
      '${project.path}/tools/build_install_snap_local.sh',
      File('tools/build_install_snap_local.sh').readAsStringSync(),
    );
    _writeFile(
      '${project.path}/pubspec.yaml',
      'name: busymax_test\nversion: 1.2.3+4\n',
    );
    _writeFile(
      '${project.path}/linux/CMakeLists.txt',
      'set(BINARY_NAME "busymax_test")\n'
          'set(APPLICATION_ID "com.example.busymax_test")\n',
    );
    _writeFile(
      '${project.path}/snap/snapcraft.yaml',
      'name: busymax_test\n'
          'version: 1.2.3\n'
          'apps:\n'
          '  busymax_test:\n'
          '    command: busymax_test\n',
    );
    _writeFile(
      '${project.path}/build/linux/x64/release/bundle/busymax_test',
      'test binary\n',
    );
    _writeFile(
      '${scaffold.path}/meta/snap.yaml',
      'name: busymax_test\n'
          'version: 0.0.1\n'
          'apps:\n'
          '  busymax_test:\n'
          '    command: busymax_test\n',
    );

    await _writeExecutable('${fakeBin.path}/flutter', r'''#!/usr/bin/env bash
set -euo pipefail
printf 'flutter\t%s\n' "$*" >> "$COMMAND_LOG"
''');
    await _writeExecutable('${fakeBin.path}/rm', r'''#!/usr/bin/env bash
set -euo pipefail
printf 'rm\t%s\n' "$*" >> "$COMMAND_LOG"
for argument in "$@"; do
  [[ "$argument" == -* ]] && continue
  canonical="$(realpath -m -- "$argument")"
  case "$canonical" in
    "$ALLOWED_RM_PREFIX"|"$ALLOWED_RM_PREFIX"/*) ;;
    *)
      echo "blocked unsafe rm target: $argument" >&2
      exit 97
      ;;
  esac
done
exec /bin/rm "$@"
''');
    await _writeExecutable('${fakeBin.path}/snap', r'''#!/usr/bin/env bash
set -euo pipefail
printf 'snap\t%s\n' "$*" >> "$COMMAND_LOG"
if [[ "${1:-}" == "pack" ]]; then
  if [[ -e "${2:-}/.busymax-local-snap-root" ]]; then
    echo 'ownership marker must not be included in the snap payload' >&2
    exit 96
  fi
  for argument in "$@"; do
    case "$argument" in
      --filename=*)
        output="${argument#--filename=}"
        mkdir -p "$(dirname "$output")"
        : > "$output"
        ;;
    esac
  done
elif [[ "${1:-}" == "info" ]]; then
  echo 'installed: 1.2.3'
fi
''');
    await _writeExecutable('${fakeBin.path}/sudo', r'''#!/usr/bin/env bash
set -euo pipefail
printf 'sudo\t%s\n' "$*" >> "$COMMAND_LOG"
''');
    await _writeExecutable('${fakeBin.path}/unsquashfs', r'''#!/usr/bin/env bash
set -euo pipefail
printf 'unsquashfs\t%s\n' "$*" >> "$COMMAND_LOG"
if [[ " $* " == *' -ll '* ]]; then
  echo 'squashfs-root/busymax_test'
else
  echo 'version: 1.2.3'
fi
''');

    return _LocalSnapFixture._(
      root: root,
      project: project,
      home: home,
      safeStaging: safeStaging,
      validRoot: validRoot,
      scaffold: scaffold,
      output: output,
      fakeBin: fakeBin,
      commandLog: commandLog,
    );
  }

  Future<ProcessResult> run({
    List<String> arguments = const <String>[],
    Map<String, String> environment = const <String, String>{},
  }) {
    return Process.run(
      'bash',
      <String>[
        '${project.path}/tools/build_install_snap_local.sh',
        '--skip-tests',
        '--no-run',
        '--scaffold',
        scaffold.path,
        '--output',
        output.path,
        ...arguments,
      ],
      workingDirectory: project.path,
      environment: <String, String>{
        ...Platform.environment,
        'PATH': '${fakeBin.path}:${Platform.environment['PATH']}',
        'HOME': home.path,
        'COMMAND_LOG': commandLog.path,
        'ALLOWED_RM_PREFIX': safeStaging.resolveSymbolicLinksSync(),
        ...environment,
      },
    );
  }

  Future<void> dispose() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}

void _writeFile(String path, String contents) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

Future<void> _writeExecutable(String path, String contents) async {
  _writeFile(path, contents);
  final result = await Process.run('chmod', <String>['755', path]);
  if (result.exitCode != 0) {
    throw StateError('chmod failed for $path: ${result.stderr}');
  }
}

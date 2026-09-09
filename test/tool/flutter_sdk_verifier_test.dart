import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a Flutter wrapper with its nested bundled Dart', () async {
    final fixture = await _ToolchainFixture.create();
    addTearDown(fixture.dispose);

    final result = await fixture.verify();

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final report = jsonDecode(result.stdout.toString());
    expect(report, isA<Map<String, Object?>>());
    expect(report['flutterVersion'], '3.44.4');
    expect(report['dartVersion'], '3.12.2');
    expect(
      File(report['dartExecutable']! as String).parent.path,
      fixture.bundledDart.parent.path,
    );
  });

  test('ignores an unrelated Dart earlier on PATH', () async {
    final fixture = await _ToolchainFixture.create();
    addTearDown(fixture.dispose);
    final unrelated = Directory('${fixture.root.path}/unrelated/bin')
      ..createSync(recursive: true);
    await _writeExecutable(
      File('${unrelated.path}/${_commandName('dart')}'),
      dartVersion: '9.9.9',
    );

    final result = await fixture.verify(
      environment: {
        ...Platform.environment,
        'PATH':
            '${unrelated.path}${Platform.isWindows ? ';' : ':'}'
            '${Platform.environment['PATH'] ?? ''}',
      },
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      (jsonDecode(result.stdout.toString())
          as Map<String, Object?>)['dartVersion'],
      '3.12.2',
    );
  });

  test('rejects a sibling Dart outside the selected Flutter SDK', () async {
    final fixture = await _ToolchainFixture.create();
    addTearDown(fixture.dispose);
    final siblingDart = File(
      '${fixture.root.path}/bin/${_commandName('dart')}',
    );
    await _writeExecutable(siblingDart, dartVersion: '3.12.2');

    final result = await fixture.verify(dart: siblingDart);

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr.toString(),
      contains('bundled executable from the selected Flutter SDK'),
    );
  });
}

final class _ToolchainFixture {
  const _ToolchainFixture({
    required this.root,
    required this.flutter,
    required this.bundledDart,
  });

  final Directory root;
  final File flutter;
  final File bundledDart;

  static Future<_ToolchainFixture> create() async {
    final root = await Directory.systemTemp.createTemp('busymax-flutter-sdk-');
    final flutter = File('${root.path}/bin/${_commandName('flutter')}');
    final bundledDart = File(
      '${root.path}/bin/cache/dart-sdk/bin/${_commandName('dart')}',
    );
    await _writeExecutable(flutter, flutterVersion: '3.44.4');
    await _writeExecutable(bundledDart, dartVersion: '3.12.2');
    return _ToolchainFixture(
      root: root,
      flutter: flutter,
      bundledDart: bundledDart,
    );
  }

  Future<ProcessResult> verify({
    File? dart,
    Map<String, String>? environment,
  }) => Process.run(
    _hostDartExecutable(),
    [
      'tool/verify_flutter_sdk.dart',
      '--flutter',
      flutter.path,
      '--dart',
      (dart ?? bundledDart).path,
      '--expected-flutter',
      '3.44.4',
      '--expected-dart',
      '3.12.2',
    ],
    environment: environment,
    runInShell: Platform.isWindows,
  );

  Future<void> dispose() => root.delete(recursive: true);
}

String _hostDartExecutable() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}/dart-sdk/bin/'
      '${Platform.isWindows ? 'dart.exe' : 'dart'}',
    );
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  throw StateError(
    'Could not locate the Flutter test runner\'s bundled Dart SDK from '
    '${Platform.resolvedExecutable}.',
  );
}

String _commandName(String command) =>
    Platform.isWindows ? '$command.cmd' : command;

Future<void> _writeExecutable(
  File file, {
  String? flutterVersion,
  String? dartVersion,
}) async {
  await file.parent.create(recursive: true);
  if (Platform.isWindows) {
    final output = flutterVersion != null
        ? '{"frameworkVersion":"$flutterVersion",'
              '"dartSdkVersion":"3.12.2"}'
        : 'Dart SDK version: $dartVersion (stable) on "windows_x64"';
    await file.writeAsString('@echo off\r\necho $output\r\n');
    return;
  }
  final output = flutterVersion != null
      ? '{"frameworkVersion":"$flutterVersion",'
            '"dartSdkVersion":"3.12.2"}'
      : 'Dart SDK version: $dartVersion (stable) on "linux_x64"';
  await file.writeAsString('#!/bin/sh\nprintf \'%s\\n\' \'$output\'\n');
  final chmod = await Process.run('chmod', ['+x', file.path]);
  if (chmod.exitCode != 0) {
    throw ProcessException('chmod', ['+x', file.path]);
  }
}

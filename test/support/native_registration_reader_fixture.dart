import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/core/auth/registration_file_reader.dart';

Future<RegistrationFileReader> buildNativeRegistrationReader() async {
  final directory = await Directory.systemTemp.createTemp(
    'busymax-reader-test-',
  );
  // Windows keeps a loaded DLL mapped until the test process exits. Its
  // build directory contains compiled test code only, never credentials.
  if (!Platform.isWindows) addTearDown(() => directory.delete(recursive: true));
  for (final arguments in [
    ['-S', 'native/registration_reader', '-B', directory.path],
    ['--build', directory.path, '--config', 'Release'],
  ]) {
    final result = await Process.run('cmake', arguments);
    if (result.exitCode != 0) {
      throw StateError(
        'Native reader build failed: ${result.stdout} ${result.stderr}',
      );
    }
  }
  return RegistrationFileReader(
    libraryPath: Platform.isWindows
        ? p.join(directory.path, 'Release', 'busymax_registration_reader.dll')
        : p.join(directory.path, 'libbusymax_registration_reader.so'),
  );
}

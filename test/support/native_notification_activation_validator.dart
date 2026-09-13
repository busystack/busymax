import 'dart:io';

/// Compiles the production C++ notification validator used by the Windows
/// runner. The JSON contract is portable; named-pipe tests run on Windows.
class NativeNotificationActivationValidator {
  NativeNotificationActivationValidator._(this._directory, this._executable);

  final Directory _directory;
  final String _executable;

  static Future<NativeNotificationActivationValidator> build() async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-native-activation-',
    );
    try {
      await _run('cmake', ['-S', 'windows/runner/tests', '-B', directory.path]);
      await _run('cmake', [
        '--build',
        directory.path,
        '--config',
        'Release',
        '--target',
        'busymax_notification_activation_test',
      ]);
      final name =
          'busymax_notification_activation_test${Platform.isWindows ? '.exe' : ''}';
      final candidates = [
        '${directory.path}/Release/$name',
        '${directory.path}/$name',
      ];
      final executable = candidates.firstWhere(
        (path) => File(path).existsSync(),
      );
      // Run the native positive/negative contract tests as well as checking
      // actual service-generated activations in the caller's forwarding path.
      await _run(executable, []);
      return NativeNotificationActivationValidator._(directory, executable);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<bool> accepts(String activation) async {
    final result = await Process.run(_executable, ['--validate', activation]);
    if (result.exitCode == 0) return true;
    if (result.exitCode == 1) return false;
    throw StateError('Native activation validator failed: ${result.stderr}');
  }

  Future<void> dispose() => _directory.delete(recursive: true);

  static Future<void> _run(String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      throw StateError(
        'Native activation test command failed ($executable):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
  }
}

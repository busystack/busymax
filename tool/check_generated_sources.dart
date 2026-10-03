import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Compares regeneration with the reviewed working tree, including uncommitted
/// schema/localization edits. A fresh checkout must still pass the CI git check.
Future<void> main(List<String> args) async {
  if (args.length != 2 || !{'snapshot', 'verify'}.contains(args[0])) {
    stderr.writeln(
      'Usage: dart run tool/check_generated_sources.dart snapshot|verify snapshot.json',
    );
    exitCode = 64;
    return;
  }
  final paths = [
    for (final file in Directory('lib/l10n/generated').listSync())
      if (file is File) file.path,
    'lib/src/db/app_database.g.dart',
  ]..sort();
  final hashes = {
    for (final path in paths)
      path: sha256.convert(File(path).readAsBytesSync()).toString(),
  };
  final snapshot = File(args[1]);
  if (args[0] == 'snapshot') {
    snapshot.writeAsStringSync(jsonEncode(hashes));
    return;
  }
  final expected = jsonDecode(snapshot.readAsStringSync()) as Map;
  if (jsonEncode(expected) != jsonEncode(hashes)) {
    stderr.writeln(
      'Generated sources differ from the reviewed snapshot. Regenerate and review them.',
    );
    exitCode = 1;
  } else {
    stdout.writeln('Generated sources are reproducible.');
  }
}

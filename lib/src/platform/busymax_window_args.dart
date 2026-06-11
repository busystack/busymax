import 'dart:convert';

enum BusyMaxWindowKind { main, compactAgenda }

class BusyMaxWindowArgs {
  const BusyMaxWindowArgs({required this.kind, required this.version});

  final BusyMaxWindowKind kind;
  final int version;

  static const currentVersion = 1;

  static const main = BusyMaxWindowArgs(
    kind: BusyMaxWindowKind.main,
    version: currentVersion,
  );

  static const compactAgenda = BusyMaxWindowArgs(
    kind: BusyMaxWindowKind.compactAgenda,
    version: currentVersion,
  );

  String encode() {
    return jsonEncode({
      'app': 'BusyMax',
      'version': version,
      'kind': kind.name,
    });
  }

  static BusyMaxWindowArgs parse(String raw) {
    if (raw.trim().isEmpty) {
      return main;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return main;
      }
      if (decoded['app'] != 'BusyMax') {
        return main;
      }
      final kind = decoded['kind']?.toString();
      if (kind == BusyMaxWindowKind.compactAgenda.name) {
        return compactAgenda;
      }
      return main;
    } on Object {
      return main;
    }
  }
}

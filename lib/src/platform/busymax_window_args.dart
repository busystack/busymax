import 'dart:convert';

enum BusyMaxWindowKind { main, compactAgenda }

class BusyMaxWindowArgs {
  const BusyMaxWindowArgs({
    required this.kind,
    required this.version,
    this.requestedPositionX,
    this.requestedPositionY,
  });

  final BusyMaxWindowKind kind;
  final int version;
  final double? requestedPositionX;
  final double? requestedPositionY;

  static const currentVersion = 1;

  static const main = BusyMaxWindowArgs(
    kind: BusyMaxWindowKind.main,
    version: currentVersion,
  );

  static const compactAgenda = BusyMaxWindowArgs(
    kind: BusyMaxWindowKind.compactAgenda,
    version: currentVersion,
  );

  static BusyMaxWindowArgs compactAgendaAt({
    required double x,
    required double y,
  }) {
    return BusyMaxWindowArgs(
      kind: BusyMaxWindowKind.compactAgenda,
      version: currentVersion,
      requestedPositionX: x,
      requestedPositionY: y,
    );
  }

  String encode() {
    return jsonEncode({
      'app': 'BusyMax',
      'version': version,
      'kind': kind.name,
      if (requestedPositionX != null && requestedPositionY != null)
        'position': {'x': requestedPositionX, 'y': requestedPositionY},
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
        final position = decoded['position'];
        final x = position is Map ? position['x'] : null;
        final y = position is Map ? position['y'] : null;
        final parsedX = x is num ? x.toDouble() : null;
        final parsedY = y is num ? y.toDouble() : null;
        if (parsedX != null &&
            parsedY != null &&
            parsedX.isFinite &&
            parsedY.isFinite) {
          return compactAgendaAt(x: parsedX, y: parsedY);
        }
        return compactAgenda;
      }
      return main;
    } on Object {
      return main;
    }
  }
}

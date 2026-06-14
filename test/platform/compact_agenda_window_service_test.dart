import 'package:busymax/src/platform/compact_agenda_window_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compact agenda placement', () {
    test('top-right fallback keeps the full window frame on-screen', () {
      final position = compactAgendaTopRightWorkAreaPositionForTest(
        const Rect.fromLTWH(0, 0, 1920, 1080),
      );

      expect(position.dx, 1430);
      expect(position.dy, 6);
    });

    test('top-right fallback clamps to the workarea minimum', () {
      final position = compactAgendaTopRightWorkAreaPositionForTest(
        const Rect.fromLTWH(0, 0, 320, 240),
      );

      expect(position.dx, 6);
      expect(position.dy, 6);
    });
  });
}

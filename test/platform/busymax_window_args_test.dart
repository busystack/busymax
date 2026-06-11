import 'package:busymax/src/platform/busymax_window_args.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty string parses as main window', () {
    expect(BusyMaxWindowArgs.parse('').kind, BusyMaxWindowKind.main);
  });

  test('malformed JSON parses as main window', () {
    expect(BusyMaxWindowArgs.parse('{bad').kind, BusyMaxWindowKind.main);
  });

  test('compact agenda JSON parses as compact agenda window', () {
    final args = BusyMaxWindowArgs.parse(
      BusyMaxWindowArgs.compactAgenda.encode(),
    );

    expect(args.kind, BusyMaxWindowKind.compactAgenda);
    expect(args.version, BusyMaxWindowArgs.currentVersion);
  });

  test('unknown app parses as main window', () {
    final args = BusyMaxWindowArgs.parse(
      '{"app":"Other","version":1,"kind":"compactAgenda"}',
    );

    expect(args.kind, BusyMaxWindowKind.main);
  });

  test('unknown kind parses as main window', () {
    final args = BusyMaxWindowArgs.parse(
      '{"app":"BusyMax","version":1,"kind":"unknown"}',
    );

    expect(args.kind, BusyMaxWindowKind.main);
  });
}

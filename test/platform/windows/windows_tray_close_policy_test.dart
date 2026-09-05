import 'package:busymax/src/ui/windows/windows_desktop_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('close can hide only when background mode and a usable tray exist', () {
    expect(
      shouldWindowsHideOnClose(
        runInBackgroundWhenClosed: true,
        trayAvailable: true,
      ),
      isTrue,
    );
    expect(
      shouldWindowsHideOnClose(
        runInBackgroundWhenClosed: true,
        trayAvailable: false,
      ),
      isFalse,
    );
    expect(
      shouldWindowsHideOnClose(
        runInBackgroundWhenClosed: false,
        trayAvailable: true,
      ),
      isFalse,
    );
  });
}

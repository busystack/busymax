import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/widgets.dart';

/// Startup state can be changed by desktop settings while BusyMax is inactive.
class LaunchAtLoginRefreshObserver extends WidgetsBindingObserver {
  LaunchAtLoginRefreshObserver(this.refresh) {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) refresh();
    });
  }

  final VoidCallback refresh;
  bool _disposed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.focused) refresh();
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}

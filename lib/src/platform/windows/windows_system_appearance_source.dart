import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:system_theme/system_theme.dart';

import '../common/desktop_services.dart';

final class WindowsSystemAppearanceSource implements SystemAppearanceSource {
  WindowsSystemAppearanceSource() {
    _subscription = SystemTheme.onChange.listen((_) => _changes.add(null));
  }

  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<Object?> _subscription;

  @override
  Color get accentColor => SystemTheme.accentColor.accent;

  @override
  Brightness get brightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  bool get highContrast => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .highContrast;

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}

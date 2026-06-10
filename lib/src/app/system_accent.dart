import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

import 'system_accent_change_events.dart';

typedef SystemAccentLoader = Future<Color> Function();
typedef SystemAccentChangeEvents = Stream<Object?> Function();

final systemAccentLoaderProvider = Provider<SystemAccentLoader>((ref) {
  return () async {
    await SystemTheme.accentColor.load();
    return SystemTheme.accentColor.accent;
  };
});

final systemAccentChangeEventsProvider = Provider<SystemAccentChangeEvents>((
  ref,
) {
  return systemAccentChangeEvents;
});

final systemAccentReloadDelayProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 100);
});

final ubuntuSystemAccentColorProvider = StreamProvider<Color>((ref) async* {
  final changeEvents = ref.watch(systemAccentChangeEventsProvider);
  final loadAccent = ref.watch(systemAccentLoaderProvider);
  final reloadDelay = ref.watch(systemAccentReloadDelayProvider);

  await for (final _ in changeEvents()) {
    if (reloadDelay > Duration.zero) {
      await Future<void>.delayed(reloadDelay);
    }
    try {
      yield await loadAccent();
    } on Object {
      // Keep the current theme if the platform accent cannot be reloaded.
    }
  }
});

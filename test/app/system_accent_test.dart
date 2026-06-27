import 'dart:async';

import 'package:busymax/src/app/system_accent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Ubuntu accent provider reloads when a change event is received',
    () async {
      final changes = StreamController<Object?>();
      final emitted = <Color>[];
      final colors = [const Color(0xFF2E7D32), const Color(0xFF8A1D61)];
      var loadCount = 0;

      final container = ProviderContainer(
        overrides: [
          systemAccentChangeEventsProvider.overrideWithValue(
            () => changes.stream,
          ),
          systemAccentLoaderProvider.overrideWithValue(() async {
            return colors[loadCount++];
          }),
          systemAccentReloadDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await changes.close();
      });

      final subscription = container.listen<AsyncValue<Color>>(
        ubuntuSystemAccentColorProvider,
        (_, next) => next.whenData(emitted.add),
      );
      addTearDown(subscription.close);

      changes.add(Object());
      await _waitForEmitted(emitted, 1);

      changes.add(Object());
      await _waitForEmitted(emitted, 2);

      expect(emitted, colors);
    },
  );
}

Future<void> _waitForEmitted(List<Color> emitted, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (emitted.length < count && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (emitted.length < count) {
    fail('Expected $count accent values, got ${emitted.length}.');
  }
}

import 'dart:async';

import 'package:busymax/src/platform/linux_header_bar_configuration_synchronizer.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'coalesces equal requests and applies only the latest frame value',
    () async {
      final callbacks = <VoidCallback>[];
      final applied = <BusyMaxHeaderBarConfiguration>[];
      final synchronizer = BusyMaxHeaderBarConfigurationSynchronizer.forTesting(
        apply: (configuration) async => applied.add(configuration),
        scheduleAfterFrame: callbacks.add,
      );
      addTearDown(synchronizer.dispose);
      final first = _configuration(dark: false);
      final latest = _configuration(dark: true);

      synchronizer
        ..schedule(first)
        ..schedule(first)
        ..schedule(latest);

      expect(callbacks, hasLength(2));
      for (final callback in callbacks) {
        callback();
      }
      await synchronizer.settled;

      expect(applied, [latest]);
    },
  );

  test('serializes an in-flight update before the newest value', () async {
    final callbacks = <VoidCallback>[];
    final firstRelease = Completer<void>();
    final applied = <BusyMaxHeaderBarConfiguration>[];
    final synchronizer = BusyMaxHeaderBarConfigurationSynchronizer.forTesting(
      apply: (configuration) async {
        applied.add(configuration);
        if (applied.length == 1) {
          await firstRelease.future;
        }
      },
      scheduleAfterFrame: callbacks.add,
    );
    addTearDown(synchronizer.dispose);
    final first = _configuration(dark: false);
    final latest = _configuration(dark: true);

    synchronizer.schedule(first);
    callbacks.removeAt(0)();
    await Future<void>.delayed(Duration.zero);

    synchronizer.schedule(latest);
    callbacks.removeAt(0)();
    firstRelease.complete();
    await synchronizer.settled;

    expect(applied, [first, latest]);
  });

  test(
    'recovers after a failed native apply and permits an equal retry',
    () async {
      final callbacks = <VoidCallback>[];
      final applied = <BusyMaxHeaderBarConfiguration>[];
      final errors = <Object>[];
      var shouldFail = true;
      final synchronizer = BusyMaxHeaderBarConfigurationSynchronizer.forTesting(
        apply: (configuration) async {
          applied.add(configuration);
          if (shouldFail) {
            shouldFail = false;
            throw StateError('native header unavailable');
          }
        },
        scheduleAfterFrame: callbacks.add,
        reportError: (error, _) => errors.add(error),
      );
      addTearDown(synchronizer.dispose);
      final configuration = _configuration(dark: false);

      synchronizer.schedule(configuration);
      callbacks.removeAt(0)();
      await synchronizer.settled;

      synchronizer.schedule(configuration);
      callbacks.removeAt(0)();
      await synchronizer.settled;

      expect(applied, [configuration, configuration]);
      expect(errors, [isA<StateError>()]);
    },
  );
}

BusyMaxHeaderBarConfiguration _configuration({required bool dark}) {
  return BusyMaxHeaderBarConfiguration(
    labels: const BusyMaxHeaderBarLabels(
      today: 'Today',
      day: 'Day',
      week: 'Week',
      month: 'Month',
      year: 'Year',
      agenda: 'Agenda',
      search: 'Search',
      create: 'Create',
      createEvent: 'Event',
      createTask: 'Task',
      refresh: 'Refresh',
      menu: 'Menu',
      previous: 'Previous',
      next: 'Next',
      sidebar: 'Sidebar',
      back: 'Back',
      settings: 'Settings',
      keyboardShortcuts: 'Keyboard shortcuts',
      aboutBusyMax: 'About BusyMax',
    ),
    sidebarWidth: 300,
    theme: BusyMaxHeaderBarTheme(
      preferDark: dark,
      windowBackgroundColor: dark ? Colors.black : Colors.white,
      backgroundColor: dark ? Colors.black : Colors.white,
      sidebarBackgroundColor: dark ? Colors.black : Colors.white,
      foregroundColor: dark ? Colors.white : Colors.black,
      sidebarBorderColor: Colors.grey,
      modalBarrierColor: Colors.black54,
    ),
  );
}

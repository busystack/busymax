import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

/// Host barriers for the maintained live lifecycle probe. They never edit work
/// rows, cancel jobs or change production dispatch/constraints/backoff behavior.
class RetainedAndroidWork {
  RetainedAndroidWork._(this.directory);
  final Directory directory;
  final watch = Stopwatch()..start();
  static Future<RetainedAndroidWork> create() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/retained-startup-qa');
    await directory.create(recursive: true);
    return RetainedAndroidWork._(directory);
  }

  Future<void> record(String name, Map<String, Object?> values) async {
    await File('${directory.path}/$name.json').writeAsString(
      jsonEncode({
        'pid': pid,
        'isolate': developer.Service.getIsolateId(Isolate.current),
        'utc': DateTime.now().toUtc().toIso8601String(),
        'elapsedMicros': watch.elapsedMicroseconds,
        ...values,
      }),
      flush: true,
    );
  }

  Future<void> prepare(WidgetTester tester, AppDatabase database) async {
    await database.customStatement(
      'CREATE TABLE qa_foreground_writes(owner INTEGER PRIMARY KEY, value INTEGER NOT NULL)',
    );
    await database.customStatement(
      'INSERT INTO qa_foreground_writes VALUES(0,0),(1,0)',
    );
    await Workmanager().initialize(busyMaxWorkmanagerDispatcher);
    for (final sync in [true, false]) {
      await Workmanager().registerPeriodicTask(
        sync
            ? busyMaxPeriodicSyncUniqueName
            : busyMaxNotificationRefillUniqueName,
        sync ? busyMaxPeriodicSyncTaskName : busyMaxNotificationRefillTaskName,
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(seconds: 3),
        flexInterval: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: sync ? NetworkType.connected : NetworkType.notRequired,
          requiresBatteryNotLow: true,
          requiresStorageNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 10),
        tag: sync ? 'busymax-sync' : 'busymax-notification-refill',
      );
    }
    await record('prepared', {});
    await forceStopBarrier(tester);
  }

  Future<void> forceStopBarrier(WidgetTester tester) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Host did not perform the required real process termination.');
  }

  Future<void> observe(WidgetTester tester, AppDatabase database) async {
    await record('foreground-ready', {});
    final outcome = File('${directory.path}/workers-finished.json');
    // Two original live workers each reconcile during initialization and after
    // their task. Measured passes take 25 seconds under the foreground writer;
    // retain a bounded budget for all four passes plus real DAV synchronization.
    final deadline = DateTime.now().add(const Duration(seconds: 120));
    var writes = 0;
    while (!await outcome.exists()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Original retained workers did not finish.');
      }
      await database.transaction(() async {
        await database.customStatement(
          'UPDATE qa_foreground_writes SET value=value+1 WHERE owner=?',
          [writes % 2],
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      writes++;
      if (writes == 1) await record('foreground-writing', {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final results = jsonDecode(await outcome.readAsString()) as Map;
    expect(results['allRetainedWorkersFinished'], isTrue);
    expect(results['notificationRefillSucceeded'], isTrue);
    expect(results['workerInitializationFailed'], isFalse);
    expect((results['workerResults'] as Map).values, everyElement('SUCCESS'));
    await record('retained-verified', {
      'foregroundTransactions': writes,
      'recordedWorkerOutcomes': results,
    });
  }
}

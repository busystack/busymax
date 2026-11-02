// Run only with the isolated busymaxNextcloudQa application ID and test signer.
import 'dart:io';
import 'dart:ui';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void authorizationLeaseFixtureDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, input) async {
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/${input!['fixture']}',
    );
    final platform = BusyMaxAndroidPlatform();
    final lease = await platform.acquireAccountGate(
      input['account'] as String,
      shared: true,
    );
    try {
      await File('${directory.path}/acquired')
          .writeAsString('shared', flush: true);
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (!await File('${directory.path}/release').exists()) {
        if (DateTime.now().isAfter(deadline)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return true;
    } finally {
      await platform.releaseAccountGate(lease);
      await File('${directory.path}/released')
          .writeAsString('released', flush: true);
    }
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('foreground and WorkManager engines share readers and exclude authorization writers', () async {
    expect(Platform.isAndroid, true);
    const enabled = bool.fromEnvironment('BUSYMAX_AUTHORIZATION_LEASE_QA');
    expect(
      enabled,
      true,
      reason: 'Requires an explicitly isolated QA package.',
    );
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'io.busystack.busymax.nextcloudqa',
      reason:
          'This fixture must never register work in the normal application.',
    );
    final name =
        'authorization-lease-qa-${DateTime.now().microsecondsSinceEpoch}';
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/$name',
    );
    await directory.create();
    final platform = BusyMaxAndroidPlatform();
    final account = 'authorization:$name';
    String? foreground, writer, last;
    Future<void>? writerWork;
    var writerAcquired = false;
    try {
      foreground = await platform.acquireAccountGate(account, shared: true);
      await Workmanager().initialize(authorizationLeaseFixtureDispatcher);
      await Workmanager().registerOneOffTask(
        name,
        'authorization-lease-fixture',
        inputData: {'fixture': name, 'account': account},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!await File('${directory.path}/acquired').exists()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Background engine did not acquire its shared native lease.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      writerWork = () async {
        writer = await platform.acquireAccountGate(account);
        writerAcquired = true;
      }();
      await platform.releaseAccountGate(foreground);
      foreground = null;
      final other = await platform.acquireAccountGate(
        '$account-other',
        shared: true,
      );
      await platform.releaseAccountGate(other);
      expect(
        writerAcquired,
        false,
        reason: 'Background reader still owns authorization.',
      );
      await File('${directory.path}/release')
          .writeAsString('release', flush: true);
      await writerWork.timeout(const Duration(seconds: 10));
      expect(writerAcquired, true);
      final releaseDeadline = DateTime.now().add(const Duration(seconds: 3));
      while (!await File('${directory.path}/released').exists()) {
        if (DateTime.now().isAfter(releaseDeadline)) {
          fail('Background release receipt missing.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await platform.releaseAccountGate(writer!);
      writer = null;
      last = await platform.acquireAccountGate(account, shared: true);
    } finally {
      await File('${directory.path}/release')
          .writeAsString('release', flush: true);
      if (foreground != null) await platform.releaseAccountGate(foreground);
      try {
        await writerWork;
      } on Object {
        /* Preserve the original test failure while cleaning up. */
      }
      if (writer != null) await platform.releaseAccountGate(writer!);
      if (last != null) await platform.releaseAccountGate(last);
      await Workmanager().cancelByUniqueName(name);
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

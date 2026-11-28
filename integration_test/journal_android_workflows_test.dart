import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/journal_workflow.dart';

void main() {
  const provider = String.fromEnvironment('BUSYMAX_JOURNAL_PROVIDER');
  const encoded = String.fromEnvironment('BUSYMAX_JOURNAL_NATIVE_FIXTURE');
  const stage = String.fromEnvironment('BUSYMAX_JOURNAL_RESTART_STAGE');
  const run = String.fromEnvironment('BUSYMAX_JOURNAL_RESTART_RUN');
  if (!const {'caldav', 'nextcloud'}.contains(provider) || encoded.isEmpty) {
    throw StateError(
      'Configure the Android journal provider and private fixture.',
    );
  }
  final restart = stage.isEmpty
      ? null
      : JournalRestartStage.values.byName(stage);
  if (restart != null && !RegExp(r'^[0-9a-f]{12}$').hasMatch(run)) {
    throw StateError('Configure a unique Android journal restart run ID.');
  }
  runJournalWorkflow(
    platform: 'Android',
    provider: provider,
    isNative: () => Platform.isAndroid,
    fixture: () async => (jsonDecode(utf8.decode(base64Decode(encoded))) as Map)
        .cast<String, Object?>(),
    restart: restart,
    checkConflictChoices: true,
    checkMove: true,
    persistentProfile: restart == null
        ? null
        : () async => Directory(
            '${(await getApplicationSupportDirectory()).path}/journal-qa-$run',
          ),
    app: () => const AndroidBusyMaxApp(),
    runtimeOverrides: (database) => [
      androidNotificationServiceProvider.overrideWith((ref) {
        final service = AndroidNotificationService(
          database: database,
          settings: AppSettings.defaults,
        );
        ref.onDispose(service.dispose);
        return service;
      }),
    ],
    openSchedule: (_, _) async {},
    input: (label) => label == 'Search'
        ? journalScheduleSearchInput()
        : journalMaterialInput(label),
    button: (label, primary) =>
        find.widgetWithText(primary ? FilledButton : OutlinedButton, label),
  );
}

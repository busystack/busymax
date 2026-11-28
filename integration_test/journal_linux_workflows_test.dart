import 'dart:io';

import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/journal_workflow.dart';

void main() {
  final stage = Platform.environment['BUSYMAX_JOURNAL_RESTART_STAGE'];
  final profile = Platform.environment['BUSYMAX_JOURNAL_RESTART_PROFILE'];
  if ((stage == null) != (profile == null)) {
    throw StateError('Configure both the journal restart stage and profile.');
  }
  for (final provider in ['caldav', 'nextcloud']) {
    runJournalWorkflow(
      platform: 'Linux',
      provider: provider,
      isNative: () => Platform.isLinux,
      fixture: () => desktopJournalFixture(provider),
      restart: stage == null ? null : JournalRestartStage.values.byName(stage),
      persistentProfile: profile == null
          ? null
          : () async => Directory(profile),
      checkConflictChoices:
          Platform.environment['BUSYMAX_LINUX_JOURNAL_CONFLICTS'] == '1',
      slowCollectionRemoval:
          provider == 'nextcloud' &&
          Platform.environment['BUSYMAX_LINUX_JOURNAL_SLOW_DELETE'] == '1',
      checkMove: Platform.environment['BUSYMAX_LINUX_JOURNAL_MOVE'] == '1',
      app: () => const LinuxBusyMaxApp(),
      openJournals: (_, container) async =>
          container.read(appRouterProvider).go('/journals'),
      input: journalMaterialInput,
      button: (label, primary) =>
          find.widgetWithText(primary ? ElevatedButton : FilledButton, label),
      enabledRefresh: () => find.byWidgetPredicate(
        (widget) =>
            widget is FilledButton &&
            widget.onPressed != null &&
            widget.child is Text &&
            (widget.child as Text).data == 'Refresh',
      ),
    );
  }
}

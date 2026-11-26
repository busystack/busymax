import 'dart:io';

import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/journal_workflow.dart';

void main() {
  for (final provider in ['caldav', 'nextcloud']) {
    runJournalWorkflow(
      platform: 'Linux',
      provider: provider,
      isNative: () => Platform.isLinux,
      fixture: () => desktopJournalFixture(provider),
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

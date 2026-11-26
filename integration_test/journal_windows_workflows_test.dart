import 'dart:io';

import 'package:busymax/src/app/windows/windows_busymax_app.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/journal_workflow.dart';

void main() {
  for (final provider in ['caldav', 'nextcloud']) {
    runJournalWorkflow(
      platform: 'Windows',
      provider: provider,
      isNative: () => Platform.isWindows,
      fixture: () => desktopJournalFixture(provider),
      app: () => const WindowsBusyMaxApp(),
      openJournals: (_, _) async => windowsAppRouter.go('/journals'),
      input: (label) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is InfoLabel && widget.label.toPlainText() == label,
        ),
        matching: find.byType(TextBox),
      ),
      button: (label, primary) =>
          find.widgetWithText(primary ? FilledButton : Button, label),
      enabledRefresh: () => find.byWidgetPredicate(
        (widget) =>
            widget is Button &&
            widget.onPressed != null &&
            widget.child is Text &&
            (widget.child as Text).data == 'Refresh',
      ),
    );
  }
}

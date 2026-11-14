import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_dav_attachments_section.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/attachments/dav_attachment_providers.dart';
import 'package:busymax/src/ui/windows/windows_dav_attachments_section.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Official file-selector platform seam; no dependency implementation is changed.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import '../features/schedule/presentation/caldav_attachment_consumption_test.dart'
    show attachmentDatabase;
import '../test_localized_app.dart';

void main() {
  testWidgets(
    'Android DAV attachments use explicit native document save with exact MIME and bytes',
    (tester) async {
      final db = (await tester.runAsync(() => attachmentDatabase('VTODO')))!;
      addTearDown(db.close);
      final task = (await tester.runAsync(
        () => db.select(db.tasks).getSingle(),
      ))!;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final target = (
        accountId: 'account',
        taskListId: task.taskListId,
        taskId: task.id,
      );
      final calls = <Map>[];
      const channel = MethodChannel('io.busystack.busymax/android');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'createDocument');
        calls.add(call.arguments as Map);
        return 'content://qa/attachment';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedTestApp(
            child: Scaffold(
              body: AndroidDavAttachmentsSection.task(target: target),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => container.read(davTaskAttachmentsProvider(target).future),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('http.bin'), findsOneWidget);
      expect(find.text('https.bin'), findsOneWidget);
      await tester.tap(find.text('Save inline.bin'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single['suggestedName'], 'inline.bin');
      expect(calls.single['mimeType'], 'application/octet-stream');
      expect(calls.single['bytes'], [0, 1, 2, 3]);
      expect(
        await tester.runAsync(() => db.select(db.pendingOps).get()),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Windows DAV controls expose references and use an explicit save chooser',
    (tester) async {
      final db = (await tester.runAsync(() => attachmentDatabase('VTODO')))!;
      addTearDown(db.close);
      final task = (await tester.runAsync(
        () => db.select(db.tasks).getSingle(),
      ))!;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final target = (
        accountId: 'account',
        taskListId: task.taskListId,
        taskId: task.id,
      );
      final previous = FileSelectorPlatform.instance;
      final selector = _CancelSelector();
      FileSelectorPlatform.instance = selector;
      addTearDown(() => FileSelectorPlatform.instance = previous);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: fluent.FluentApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WindowsDavAttachmentsSection.task(target: target),
          ),
        ),
      );
      await tester.runAsync(
        () => container.read(davTaskAttachmentsProvider(target).future),
      );
      await tester.pumpAndSettle();
      expect(selector.calls, 0);
      expect(find.text('http.bin'), findsOneWidget);
      expect(find.text('https.bin'), findsOneWidget);
      await tester.tap(find.text('Save inline.bin'));
      await tester.pumpAndSettle();
      expect(selector.calls, 1);
      expect(selector.name, 'inline.bin');
      expect(
        await tester.runAsync(() => db.select(db.pendingOps).get()),
        isEmpty,
      );
    },
  );
}

class _CancelSelector extends FileSelectorPlatform {
  int calls = 0;
  String? name;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    calls++;
    name = options.suggestedName;
    return null;
  }
}

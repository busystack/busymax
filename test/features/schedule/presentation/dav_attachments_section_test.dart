import 'dart:async';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/schedule/presentation/dav_attachments_section.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
// Official plugin test interfaces are not re-exported by their public widgets.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../test_localized_app.dart';
import 'caldav_attachment_consumption_test.dart' show attachmentDatabase;

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DavTaskAttachmentTarget target;
  late UrlLauncherPlatform originalLauncher;
  late _Launcher launcher;
  late int davRequests;
  setUp(() async {
    db = await attachmentDatabase('VTODO');
    final task = await db.select(db.tasks).getSingle();
    target = (
      accountId: 'account',
      taskListId: task.taskListId,
      taskId: task.id,
    );
    davRequests = 0;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        davAccountHttpClientProvider('account').overrideWithValue(
          MockClient((_) async {
            davRequests++;
            throw StateError(
              'Attachment access must not use authenticated DAV I/O.',
            );
          }),
        ),
      ],
    );
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
  });
  tearDown(() async {
    UrlLauncherPlatform.instance = originalLauncher;
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedTestApp(
          child: Scaffold(body: DavAttachmentsSection.task(target: target)),
        ),
      ),
    );
    await tester.runAsync(
      () => container.read(davTaskAttachmentsProvider(target).future),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'HTTP/HTTPS gestures use the existing external handler without credentials',
    (tester) async {
      final before = await tester.runAsync(() => _snapshot(db));
      await pump(tester);
      expect(launcher.urls, isEmpty);
      expect(davRequests, 0);
      await tester.tap(find.text('http.bin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('https.bin'));
      await tester.pumpAndSettle();
      expect(launcher.urls, [
        'http://files.example.test/http.bin',
        'https://files.example.test/https.bin',
      ]);
      expect(davRequests, 0);
      expect(await tester.runAsync(() => _snapshot(db)), before);
    },
  );

  testWidgets(
    'inline save consumes cached bytes without network, queue or validator changes',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busymax-inline-widget-'),
      ))!;
      addTearDown(
        () => tester.runAsync(() => directory.delete(recursive: true)),
      );
      final original = FileSelectorPlatform.instance;
      final selector = _Selector('${directory.path}/saved.bin');
      FileSelectorPlatform.instance = selector;
      addTearDown(() => FileSelectorPlatform.instance = original);
      final before = await tester.runAsync(() => _snapshot(db));
      await pump(tester);
      expect(selector.calls, 0);
      await tester.tap(find.text('Save inline.bin'));
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (true) {
        await tester.pump();
        if (await tester.runAsync(() => File(selector.path).exists()) == true) {
          break;
        }
        expect(
          DateTime.now().isBefore(deadline),
          isTrue,
          reason:
              'Explicit attachment save must finish within the fixed bound.',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => File(selector.path).readAsBytes()), [
        0,
        1,
        2,
        3,
      ]);
      expect(await tester.runAsync(() => _snapshot(db)), before);
      expect(davRequests, 0);
      expect(launcher.urls, isEmpty);
    },
  );

  testWidgets(
    'metadata-only remote commit updates references while the interface is open',
    (tester) async {
      await pump(tester);
      final updated = Completer<void>();
      final sub = container.listen(davTaskAttachmentsProvider(target), (
        _,
        next,
      ) {
        if (next.asData?.value.any(
                  (x) => x.uri?.endsWith('/new.bin') == true,
                ) ==
                true &&
            !updated.isCompleted) {
          updated.complete();
        }
      });
      addTearDown(sub.close);
      await tester.runAsync(() async {
        final object = await db.select(db.davObjects).getSingle();
        await _commit(
          db,
          object.rawIcsBody.replaceFirst('/http.bin', '/new.bin'),
        );
      });
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!updated.isCompleted) {
        await tester.pump();
        expect(
          DateTime.now().isBefore(deadline),
          isTrue,
          reason:
              'The metadata commit must reach the open attachment controls.',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('http.bin'), findsNothing);
      expect(find.text('new.bin'), findsOneWidget);
      expect(find.text('https.bin'), findsOneWidget);
      expect(launcher.urls, isEmpty);
      expect(davRequests, 0);
      expect(await db.select(db.pendingOps).get(), isEmpty);
    },
  );

  testWidgets(
    'malformed binary is visible but disabled; unsafe schemes never launch',
    (tester) async {
      await tester.runAsync(() async {
        final object = await db.select(db.davObjects).getSingle();
        await _commit(
          db,
          object.rawIcsBody
              .replaceFirst('AAECAw==', 'AB==')
              .replaceFirst(
                'END:VTODO',
                'ATTACH:javascript:alert(1)\r\n'
                    'ATTACH:https://user:secret@files.example.test/private\r\n'
                    'ATTACH:data:text/plain;base64,AA==\r\nEND:VTODO',
              ),
        );
      });
      await pump(tester);
      expect(find.text('Save inline.bin'), findsNothing);
      expect(
        find.text('This attachment is invalid or exceeds the size limit.'),
        findsOneWidget,
      );
      expect(find.text('http.bin'), findsOneWidget);
      expect(find.text('https.bin'), findsOneWidget);
      expect(find.text('private'), findsNothing);
      expect(launcher.urls, isEmpty);
      expect(davRequests, 0);
    },
  );

  test('task identity is scoped to its account and list', () async {
    final result = await container.read(
      davTaskAttachmentsProvider((
        accountId: 'account',
        taskListId: 'other-list',
        taskId: target.taskId,
      )).future,
    );
    expect(result, isEmpty);
    expect(davRequests, 0);
  });

  test('pending unrelated edit is not replayed, mutated, or discarded by attachment reads', () async {
    final object = await db.select(db.davObjects).getSingle();
    await db
        .update(db.davCollections)
        .write(
          const DavCollectionsCompanion(
            currentUserPrivilegesJson: Value('["{DAV:}read","{DAV:}write"]'),
            readOnly: Value(false),
          ),
        );
    await DavPendingOperationQueue(database: db).enqueueUpdate(
      accountId: 'account',
      collectionId: 'collection',
      objectId: object.id,
      patch: DavMutationPatch(
        scope: DavMutationScope.recurrenceMaster,
        target: const IcalComponentKey(componentType: 'VTODO', uid: 'attached'),
        operations: [
          DavPatchOperation.setText('SUMMARY', 'Pending offline title'),
        ],
      ),
    );
    final before = await _snapshot(db);
    final attachments = await container.read(
      davTaskAttachmentsProvider(target).future,
    );
    expect(attachments.first.decode(), [0, 1, 2, 3]);
    expect(await _snapshot(db), before);
    expect(davRequests, 0);
  });
}

Future<Object> _snapshot(AppDatabase db) async => {
  'objects': [for (final x in await db.select(db.davObjects).get()) x.toJson()],
  'pending': [for (final x in await db.select(db.pendingOps).get()) x.toJson()],
};

Future<void> _commit(AppDatabase db, String raw) async {
  final object = DavPreparedObject.parse(
    hrefKey: '/calendar/attached.ics',
    requestUri: Uri.parse('https://dav.example.test/calendar/attached.ics'),
    etag: '"two"',
    contentType: 'text/calendar',
    rawIcsBody: raw,
  );
  await DavObjectRepository(database: db).commit(
    DavCollectionCommit(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.caldav,
      objects: [object],
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: {object.hrefKey},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'two',
      baselineGeneration: 2,
      completedAtUtc: DateTime.utc(2026, 11, 10, 1),
      projectionRangeStartUtc: DateTime.utc(2026),
      projectionRangeEndUtc: DateTime.utc(2027),
    ),
  );
}

class _Launcher extends UrlLauncherPlatform {
  final urls = <String>[];
  @override
  Null get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    expect(options.mode, PreferredLaunchMode.externalApplication);
    expect(options.webViewConfiguration.headers, isEmpty);
    urls.add(url);
    return true;
  }
}

class _Selector extends FileSelectorPlatform {
  _Selector(this.path);
  final String path;
  int calls = 0;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    calls++;
    return FileSaveLocation(path);
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_event_attachments_dialog.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/attachment_upload_session.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/linux_event_attachments_dialog.dart';
import 'package:busymax/src/features/schedule/presentation/attachment_upload_coordinator.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/event_attachment_link.dart';
import 'package:busymax/src/ui/windows/windows_event_attachments_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// The file_selector package does not re-export its platform test seam.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test_localized_app.dart';

const _event = CalendarScheduleItem(
  id: 'local-event',
  accountId: 'microsoft:a',
  provider: BusyProvider.microsoft,
  sourceId: 'local-calendar',
  providerCalendarId: 'remote-calendar',
  providerEventId: 'remote-event',
  title: 'Planning',
  allDay: false,
);

class _AttachmentTestFileSelector extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    Uint8List.fromList(const [1, 2, 3]),
    path: '/test/agenda.txt',
    mimeType: 'text/plain',
  );
}

void main() {
  test(
    'R3 missing retry header backs off repeated direct 429s without creating uncertainty',
    () async {
      var now = DateTime.utc(2026, 10, 1);
      var submissions = 0;
      final coordinator = AttachmentUploadCoordinator(now: () => now);
      addTearDown(coordinator.dispose);
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      Future<void> upload() => coordinator.upload(
        key: key,
        name: 'a.txt',
        size: 1,
        contentType: 'text/plain',
        bytes: const [1],
        list: () async => const [],
        submit: (_) async {
          submissions++;
          if (submissions <= 2) {
            throw const MicrosoftCalendarApiError(
              statusCode: 429,
              code: 'TooManyRequests',
              message: 'Throttled',
            );
          }
          return 'confirmed';
        },
      );
      await expectLater(upload(), throwsA(isA<MicrosoftCalendarApiError>()));
      final first = coordinator.retryAfter(key)!;
      expect(first, greaterThanOrEqualTo(const Duration(seconds: 2)));
      expect(first, lessThan(const Duration(seconds: 3)));
      await expectLater(
        upload(),
        throwsA(isA<AttachmentUploadRateLimitedException>()),
      );
      expect(submissions, 1);
      now = now.add(first + const Duration(milliseconds: 1));
      await expectLater(upload(), throwsA(isA<MicrosoftCalendarApiError>()));
      final second = coordinator.retryAfter(key)!;
      expect(second, greaterThanOrEqualTo(const Duration(seconds: 4)));
      expect(second, lessThan(const Duration(seconds: 5)));
      expect(coordinator.needsReconciliation(key), isFalse);
      now = now.add(second + const Duration(milliseconds: 1));
      await upload();
      expect(submissions, 3);
      expect(coordinator.canSubmit(key), isTrue);
    },
  );

  test(
    'R3 throttled chunk does not discard an existing upload session',
    () async {
      final coordinator = AttachmentUploadCoordinator();
      addTearDown(coordinator.dispose);
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      await expectLater(
        coordinator.upload(
          key: key,
          name: 'large.bin',
          size: 1,
          contentType: 'application/octet-stream',
          bytes: const [1],
          list: () async => const [],
          submit: (onSession) async {
            onSession(
              MicrosoftAttachmentUploadSession(
                url: Uri.parse('https://graph.microsoft.com/session'),
                expiresAt: DateTime.utc(2099),
                nextOffset: 0,
              ),
            );
            throw const MicrosoftCalendarApiError(
              statusCode: 429,
              code: 'TooManyRequests',
              message: 'Throttled',
            );
          },
        ),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      expect(coordinator.hasResumableSession(key), isTrue);
      expect(coordinator.needsReconciliation(key), isTrue);
      expect(coordinator.retryAfter(key), equals(null));
    },
  );
  test(
    'R3 fresh direct event 429 is a rejected attempt, not an unresolved upload',
    () async {
      var now = DateTime.utc(2026, 10, 1);
      var posts = 0;
      final heldRefresh = Completer<http.Response>();
      final refreshStarted = Completer<void>();
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            if (posts == 2) {
              refreshStarted.complete();
              return heldRefresh.future;
            }
            return http.Response(jsonEncode({'value': <Object>[]}), 200);
          }
          posts++;
          if (posts == 2) {
            return http.Response(
              jsonEncode({
                'id': 'confirmed-a',
                'name': 'notes.txt',
                'size': 1,
                '@odata.type': '#microsoft.graph.fileAttachment',
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({
              'error': {'code': 'TooManyRequests', 'message': 'Throttled'},
            }),
            429,
            headers: {'retry-after': '30'},
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator(now: () => now);
      addTearDown(coordinator.dispose);
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      Future<void> upload() => coordinator.uploadEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
        name: 'notes.txt',
        contentType: 'text/plain',
        bytes: [1],
      );
      await expectLater(
        upload(),
        throwsA(
          isA<MicrosoftCalendarApiError>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
      expect(posts, 1);
      expect(coordinator.status(key), AttachmentUploadStatus.ready);
      expect(coordinator.needsReconciliation(key), isFalse);
      expect(coordinator.retryAfter(key), const Duration(seconds: 30));
      expect(coordinator.canSubmit(key), isFalse);
      expect(
        await client.listEventAttachments(
          calendarId: 'calendar',
          eventId: 'event',
        ),
        isEmpty,
      );
      await expectLater(
        upload(),
        throwsA(isA<AttachmentUploadRateLimitedException>()),
      );
      expect(posts, 1);
      now = now.add(const Duration(seconds: 31));
      await upload();
      await refreshStarted.future;
      expect(posts, 2);
      expect(coordinator.status(key), AttachmentUploadStatus.committed);
      expect(coordinator.canSubmit(key), isTrue);
      heldRefresh.complete(
        http.Response(jsonEncode({'value': <Object>[]}), 200),
      );
    },
  );

  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets(
      '$platform R3 direct upload throttling keeps Close usable and gates explicit retry',
      (tester) async {
        final previousSelector = FileSelectorPlatform.instance;
        FileSelectorPlatform.instance = _AttachmentTestFileSelector();
        addTearDown(() => FileSelectorPlatform.instance = previousSelector);
        const android = MethodChannel('io.busystack.busymax/android');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(android, (call) async {
          if (call.method != 'openDocument') return null;
          return {
            'uri': 'content://busymax.test/agenda',
            'name': 'agenda.txt',
            'mimeType': 'text/plain',
            'bytes': Uint8List.fromList(const [1, 2, 3]),
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(android, null));
        var now = DateTime.utc(2026, 10, 1);
        var posts = 0;
        final client = MicrosoftCalendarApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(jsonEncode({'value': <Object>[]}), 200);
            }
            posts++;
            if (posts == 1) {
              return http.Response(
                jsonEncode({
                  'error': {'code': 'TooManyRequests', 'message': 'Throttled'},
                }),
                429,
                headers: {'retry-after': '30'},
              );
            }
            return http.Response(
              jsonEncode({
                'id': 'attachment-a',
                'name': 'agenda.txt',
                'size': 3,
                '@odata.type': '#microsoft.graph.fileAttachment',
              }),
              201,
            );
          }),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          responseTimeZone: 'UTC',
        );
        final coordinator = AttachmentUploadCoordinator(now: () => now);
        final key = AttachmentUploadCoordinator.eventKey(
          'microsoft:a',
          'remote-calendar',
          'remote-event',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentUploadCoordinatorProvider.overrideWith(
                (ref) => coordinator,
              ),
              microsoftCalendarApiClientForAccountProvider(
                'microsoft:a',
              ).overrideWithValue(client),
            ],
            child: platform == 'Windows'
                ? fluent.FluentApp(
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Builder(
                      builder: (context) => fluent.Button(
                        onPressed: () =>
                            showWindowsEventAttachmentsDialog(context, _event),
                        child: const fluent.Text('Open attachments'),
                      ),
                    ),
                  )
                : localizedTestApp(
                    child: Scaffold(
                      body: Builder(
                        builder: (context) => TextButton(
                          onPressed: () => platform == 'Android'
                              ? showAndroidEventAttachmentsDialog(
                                  context,
                                  _event,
                                )
                              : showLinuxEventAttachmentsDialog(
                                  context,
                                  _event,
                                ),
                          child: const Text('Open attachments'),
                        ),
                      ),
                    ),
                  ),
          ),
        );
        await tester.tap(find.text('Open attachments'));
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        await tester.tap(find.byKey(const Key('event-attachment-add')));
        for (var i = 0; i < 20 && posts == 0; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(posts, 1);
        expect(coordinator.needsReconciliation(key), isFalse);
        expect(coordinator.canSubmit(key), isFalse);
        expect(
          find.text(
            'Attachment upload is temporarily rate-limited. Try again when the wait ends.',
          ),
          findsOneWidget,
        );
        final add = tester.widget(
          find.byKey(const Key('event-attachment-add')),
        );
        expect(switch (add) {
          fluent.Button button => button.onPressed,
          TextButton button => button.onPressed,
          FilledButton button => button.onPressed,
          _ => null,
        }, equals(null));
        await tester.tap(find.text('Close'));
        await tester.pump();
        await tester.tap(find.text('Open attachments'));
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        expect(posts, 1);
        now = now.add(const Duration(seconds: 31));
        await tester.pump(const Duration(seconds: 31));
        expect(coordinator.canSubmit(key), isTrue);
        await tester.tap(find.byKey(const Key('event-attachment-add')));
        for (var i = 0; i < 20 && posts < 2; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(posts, 2);
        if (platform == 'Windows') {
          await tester.pump(const Duration(milliseconds: 200));
        }
      },
    );
  }

  test('confirmed direct upload returns before its list refresh', () async {
    final heldRefresh = Completer<List<AttachmentUploadRemoteItem>>();
    final refreshStarted = Completer<void>();
    var lists = 0;
    var submissions = 0;
    final coordinator = AttachmentUploadCoordinator();
    final key = AttachmentUploadCoordinator.eventKey(
      'account',
      'calendar',
      'event',
    );
    var completed = false;
    final upload = coordinator
        .upload(
          key: key,
          name: 'agenda.txt',
          size: 1,
          contentType: 'text/plain',
          bytes: const [1],
          list: () {
            lists++;
            if (lists == 1) return Future.value(const []);
            refreshStarted.complete();
            return heldRefresh.future;
          },
          submit: (_) async {
            submissions++;
            return 'attachment-a';
          },
        )
        .then((_) => completed = true);
    await refreshStarted.future;
    for (var i = 0; i < 4; i++) {
      await Future<void>.value();
    }
    try {
      expect(coordinator.status(key), AttachmentUploadStatus.committed);
      expect(completed, isTrue);
      expect(submissions, 1);
      expect(lists, 2);
    } finally {
      heldRefresh.complete(const []);
      await upload;
    }
  });

  test(
    'a delayed confirmed refresh is harmless after coordinator disposal',
    () async {
      final heldRefresh = Completer<List<AttachmentUploadRemoteItem>>();
      final refreshStarted = Completer<void>();
      var lists = 0;
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      await coordinator.upload(
        key: key,
        name: 'agenda.txt',
        size: 1,
        contentType: 'text/plain',
        bytes: const [1],
        list: () {
          if (lists++ == 0) return Future.value(const []);
          refreshStarted.complete();
          return heldRefresh.future;
        },
        submit: (_) async => 'attachment-a',
      );
      await refreshStarted.future;
      coordinator.dispose();
      heldRefresh.complete(const []);
      for (var i = 0; i < 4; i++) {
        await Future<void>.value();
      }
      expect(lists, 2);
    },
  );

  for (final platform in ['Linux', 'Windows', 'Android']) {
    for (final refreshFails in [false, true]) {
      testWidgets(
        '$platform confirmed upload releases Add and Close before ${refreshFails ? 'failed' : 'successful'} list refresh',
        (tester) async {
          final previousSelector = FileSelectorPlatform.instance;
          FileSelectorPlatform.instance = _AttachmentTestFileSelector();
          addTearDown(() => FileSelectorPlatform.instance = previousSelector);
          const android = MethodChannel('io.busystack.busymax/android');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(android, (call) async {
            if (call.method != 'openDocument') return null;
            return {
              'uri': 'content://busymax.test/agenda',
              'name': 'agenda.txt',
              'mimeType': 'text/plain',
              'bytes': Uint8List.fromList(const [1, 2, 3]),
            };
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(android, null);
          });

          final heldRefresh = Completer<http.Response>();
          var uploads = 0;
          var listRequests = 0;
          var held = false;
          final client = MicrosoftCalendarApiClient(
            httpClient: MockClient((request) async {
              if (request.method == 'GET' &&
                  request.url.path.endsWith('/attachments')) {
                listRequests++;
                if (uploads == 1 && !held) {
                  held = true;
                  return heldRefresh.future;
                }
                return http.Response(jsonEncode({'value': []}), 200);
              }
              if (request.method == 'POST' &&
                  request.url.path.endsWith('/attachments')) {
                uploads++;
                return http.Response(
                  jsonEncode({
                    'id': 'attachment-a',
                    'name': 'agenda.txt',
                    'size': 3,
                    '@odata.type': '#microsoft.graph.fileAttachment',
                  }),
                  201,
                );
              }
              return http.Response('{}', 404);
            }),
            baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
            responseTimeZone: 'UTC',
          );
          final coordinator = AttachmentUploadCoordinator();
          final key = AttachmentUploadCoordinator.eventKey(
            'microsoft:a',
            'remote-calendar',
            'remote-event',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                attachmentUploadCoordinatorProvider.overrideWith(
                  (ref) => coordinator,
                ),
                microsoftCalendarApiClientForAccountProvider(
                  'microsoft:a',
                ).overrideWithValue(client),
              ],
              child: platform == 'Windows'
                  ? fluent.FluentApp(
                      localizationsDelegates: const [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: Builder(
                        builder: (context) => fluent.Button(
                          onPressed: () => showWindowsEventAttachmentsDialog(
                            context,
                            _event,
                          ),
                          child: const fluent.Text('Open attachments'),
                        ),
                      ),
                    )
                  : localizedTestApp(
                      child: Scaffold(
                        body: Builder(
                          builder: (context) => TextButton(
                            onPressed: () => platform == 'Android'
                                ? showAndroidEventAttachmentsDialog(
                                    context,
                                    _event,
                                  )
                                : showLinuxEventAttachmentsDialog(
                                    context,
                                    _event,
                                  ),
                            child: const Text('Open attachments'),
                          ),
                        ),
                      ),
                    ),
            ),
          );
          await tester.tap(find.text('Open attachments'));
          for (var i = 0; i < 4; i++) {
            await tester.pump();
          }
          await tester.tap(find.byKey(const Key('event-attachment-add')));
          for (var i = 0; i < 30 && !held; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(held, isTrue, reason: 'uploads=$uploads lists=$listRequests');
          expect(coordinator.status(key), AttachmentUploadStatus.committed);
          for (var i = 0; i < 3; i++) {
            await tester.pump();
          }
          final add = tester.widget(
            find.byKey(const Key('event-attachment-add')),
          );
          final close = platform == 'Windows'
              ? tester.widget<fluent.Button>(
                  find.widgetWithText(fluent.Button, 'Close'),
                )
              : platform == 'Android'
              ? tester.widget<TextButton>(
                  find.widgetWithText(TextButton, 'Close'),
                )
              : tester.widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Close'),
                );
          expect(switch (add) {
            fluent.Button button => button.onPressed,
            TextButton button => button.onPressed,
            FilledButton button => button.onPressed,
            _ => null,
          }, isNot(equals(null)));
          expect(switch (close) {
            fluent.Button button => button.onPressed,
            TextButton button => button.onPressed,
            ElevatedButton button => button.onPressed,
            _ => null,
          }, isNot(equals(null)));
          expect(uploads, 1);
          await tester.tap(find.text('Close'));
          await tester.pump();
          await tester.tap(find.text('Open attachments'));
          await tester.pump();
          expect(uploads, 1);
          if (refreshFails) {
            heldRefresh.completeError(http.ClientException('list failed'));
          } else {
            heldRefresh.complete(http.Response(jsonEncode({'value': []}), 200));
          }
          for (var i = 0; i < 4; i++) {
            await tester.pump();
          }
          expect(coordinator.status(key), AttachmentUploadStatus.committed);
          expect(coordinator.canSubmit(key), isTrue);
          expect(uploads, 1);
          expect(listRequests, greaterThanOrEqualTo(2));
          expect(tester.takeException(), equals(null));
          if (platform == 'Windows') {
            await tester.pump(const Duration(milliseconds: 200));
          }
        },
      );
    }
  }

  test(
    'another matching attachment never proves a lost upload succeeded',
    () async {
      var committed = false;
      var visible = false;
      var posts = 0;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/attachments')) {
            return http.Response(
              jsonEncode({
                'value': visible
                    ? [
                        {
                          'id': 'new-attachment',
                          'name': 'notes.txt',
                          'size': 4,
                          '@odata.type': '#microsoft.graph.fileAttachment',
                        },
                      ]
                    : [],
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/attachments')) {
            posts++;
            committed = true;
            throw http.ClientException('response lost');
          }
          return http.Response('{}', 404);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      Future<void> upload() => coordinator.uploadEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
        name: 'notes.txt',
        contentType: 'text/plain',
        bytes: [1, 2, 3, 4],
      );
      await expectLater(
        upload(),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      expect(committed, isTrue);
      expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
      await expectLater(
        upload(),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      expect(posts, 1);
      visible = true;
      expect(
        await coordinator.reconcileEvent(
          client: client,
          accountId: 'account',
          calendarId: 'calendar',
          eventId: 'event',
        ),
        AttachmentUploadStatus.unresolved,
      );
      expect(coordinator.canSubmit(key), isFalse);
      expect(coordinator.canResolveManually(key), isTrue);
      coordinator.resolveUncertainManually(key, exists: false);
      expect(coordinator.canSubmit(key), isTrue);
    },
  );

  test('lost final event upload-session response remains unresolved', () async {
    var visible = false;
    var sessions = 0;
    var chunks = 0;
    final bytes = List<int>.filled(3 * 1024 * 1024, 65);
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/attachments')) {
          return http.Response(
            jsonEncode({
              'value': visible
                  ? [
                      {
                        'id': 'session-attachment',
                        'name': 'large.bin',
                        'size': bytes.length,
                        '@odata.type': '#microsoft.graph.fileAttachment',
                      },
                    ]
                  : [],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/createUploadSession')) {
          sessions++;
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://outlook.office.com/upload/session',
              'expirationDateTime': '2099-01-01T00:00:00Z',
              'nextExpectedRanges': ['0-'],
            }),
            201,
          );
        }
        if (request.method == 'PUT') {
          chunks++;
          if (chunks == 2) throw http.ClientException('final response lost');
          return http.Response(
            jsonEncode({
              'nextExpectedRanges': ['2097152-'],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    final coordinator = AttachmentUploadCoordinator();
    Future<void> upload() => coordinator.uploadEvent(
      client: client,
      accountId: 'account',
      calendarId: 'calendar',
      eventId: 'event',
      name: 'large.bin',
      contentType: 'application/octet-stream',
      bytes: bytes,
    );
    await expectLater(
      upload(),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    await expectLater(
      upload(),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    expect(sessions, 1);
    expect(chunks, 2);
    visible = true;
    await expectLater(
      coordinator.reconcileEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
      ),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    expect(
      coordinator.status(
        AttachmentUploadCoordinator.eventKey('account', 'calendar', 'event'),
      ),
      AttachmentUploadStatus.unresolved,
    );
  });

  test('lost nonfinal chunk resumes the same event session', () async {
    var sessions = 0;
    var statusReads = 0;
    final ranges = <String>[];
    final bytes = List<int>.filled(4 * 1024 * 1024, 65);
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/attachments')) {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/createUploadSession')) {
          sessions++;
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://outlook.office.com/upload/session',
              'expirationDateTime': '2099-01-01T00:00:00Z',
              'nextExpectedRanges': ['0-'],
            }),
            201,
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/upload/session')) {
          statusReads++;
          return http.Response(
            jsonEncode({
              'nextExpectedRanges': ['2097152-'],
            }),
            200,
          );
        }
        if (request.method == 'PUT') {
          final range =
              request.headers['content-range'] ??
              request.headers['Content-Range']!;
          ranges.add(range);
          if (range.startsWith('bytes 0-')) {
            throw http.ClientException('first chunk response lost');
          }
          return http.Response(
            '',
            201,
            headers: {
              'Location':
                  'https://outlook.office.com/events/event/attachments/confirmed-id',
            },
          );
        }
        return http.Response('{}', 404);
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    final coordinator = AttachmentUploadCoordinator();
    final key = AttachmentUploadCoordinator.eventKey(
      'account',
      'calendar',
      'event',
    );
    await expectLater(
      coordinator.uploadEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
        name: 'large.bin',
        contentType: 'application/octet-stream',
        bytes: bytes,
      ),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
    expect(
      await coordinator.reconcileEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
      ),
      AttachmentUploadStatus.committed,
    );
    expect(sessions, 1);
    expect(statusReads, greaterThanOrEqualTo(1));
    expect(ranges, [
      'bytes 0-2097151/${bytes.length}',
      'bytes 2097152-4194303/${bytes.length}',
    ]);
  });

  test('incomplete event session can be cancelled before safe retry', () async {
    var sessions = 0;
    var cancellations = 0;
    var denyCancellation = true;
    final bytes = List<int>.filled(4 * 1024 * 1024, 65);
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/attachments')) {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        if (request.method == 'POST') {
          sessions++;
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://outlook.office.com/upload/session',
              'expirationDateTime': '2099-01-01T00:00:00Z',
              'nextExpectedRanges': ['0-'],
            }),
            201,
          );
        }
        if (request.method == 'PUT') {
          throw http.ClientException('nonfinal response lost');
        }
        if (request.method == 'DELETE') {
          cancellations++;
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response('', denyCancellation ? 503 : 204);
        }
        return http.Response('{}', 404);
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    final coordinator = AttachmentUploadCoordinator();
    final key = AttachmentUploadCoordinator.eventKey(
      'account',
      'calendar',
      'event',
    );
    Future<void> upload() => coordinator.uploadEvent(
      client: client,
      accountId: 'account',
      calendarId: 'calendar',
      eventId: 'event',
      name: 'large.bin',
      contentType: 'application/octet-stream',
      bytes: bytes,
    );
    await expectLater(
      upload(),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    expect(coordinator.hasResumableSession(key), isTrue);
    await expectLater(
      coordinator.cancelEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
      ),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    expect(coordinator.canSubmit(key), isFalse);
    denyCancellation = false;
    await coordinator.cancelEvent(
      client: client,
      accountId: 'account',
      calendarId: 'calendar',
      eventId: 'event',
    );
    expect(cancellations, 2);
    expect(coordinator.canSubmit(key), isTrue);
    await expectLater(
      upload(),
      throwsA(isA<AttachmentUploadUnresolvedException>()),
    );
    expect(sessions, 2);
  });

  test(
    'malformed or expired session status never silently unlocks retry',
    () async {
      var reads = 0;
      var puts = 0;
      var sessions = 0;
      final bytes = List<int>.filled(4 * 1024 * 1024, 65);
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/attachments')) {
            return http.Response(jsonEncode({'value': []}), 200);
          }
          if (request.method == 'POST') {
            sessions++;
            return http.Response(
              jsonEncode({
                'uploadUrl': 'https://outlook.office.com/upload/session',
                'expirationDateTime': '2099-01-01T00:00:00Z',
                'nextExpectedRanges': ['0-'],
              }),
              201,
            );
          }
          if (request.method == 'PUT') {
            puts++;
            throw http.ClientException('chunk response lost');
          }
          if (request.method == 'GET') {
            reads++;
            return reads == 1
                ? http.Response(jsonEncode({'nextExpectedRanges': 'bad'}), 200)
                : http.Response(
                    jsonEncode({
                      'nextExpectedRanges': ['2097152-'],
                      'expirationDateTime': '2000-01-01T00:00:00Z',
                    }),
                    200,
                  );
          }
          return http.Response('{}', 404);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      await expectLater(
        coordinator.uploadEvent(
          client: client,
          accountId: 'account',
          calendarId: 'calendar',
          eventId: 'event',
          name: 'large.bin',
          contentType: 'application/octet-stream',
          bytes: bytes,
        ),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          coordinator.reconcileEvent(
            client: client,
            accountId: 'account',
            calendarId: 'calendar',
            eventId: 'event',
          ),
          throwsA(isA<AttachmentUploadUnresolvedException>()),
        );
        expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
        expect(coordinator.canSubmit(key), isFalse);
      }
      expect(sessions, 1);
      expect(puts, 1);
      expect(reads, 2);
      expect(coordinator.canResolveManually(key), isTrue);
    },
  );

  test(
    'confirmed event attachment denial restores Add without committing',
    () async {
      var posts = 0;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'value': []}), 200);
          }
          posts++;
          return http.Response(
            jsonEncode({
              'error': {'code': 'AccessDenied'},
            }),
            403,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      await expectLater(
        coordinator.uploadEvent(
          client: client,
          accountId: 'account',
          calendarId: 'calendar',
          eventId: 'event',
          name: 'notes.txt',
          contentType: 'text/plain',
          bytes: [1],
        ),
        throwsA(isA<Object>()),
      );
      expect(posts, 1);
      expect(coordinator.status(key), AttachmentUploadStatus.ready);
      expect(coordinator.canSubmit(key), isTrue);
    },
  );

  test(
    'confirmed upload with failed refresh permits a distinct upload',
    () async {
      var posts = 0;
      var gets = 0;
      var visible = false;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            gets++;
            if (!visible && gets.isEven) {
              throw http.ClientException('attachment list unavailable');
            }
            return http.Response(
              jsonEncode({
                'value': visible
                    ? [
                        {
                          'id': 'committed-id',
                          'name': 'notes.txt',
                          'size': 4,
                          '@odata.type': '#microsoft.graph.fileAttachment',
                        },
                      ]
                    : [],
              }),
              200,
            );
          }
          posts++;
          return http.Response(
            jsonEncode({
              'id': 'committed-id',
              'name': 'notes.txt',
              'size': 4,
              '@odata.type': '#microsoft.graph.fileAttachment',
            }),
            201,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      Future<void> upload() => coordinator.uploadEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
        name: 'notes.txt',
        contentType: 'text/plain',
        bytes: [1, 2, 3, 4],
      );
      await upload();
      expect(coordinator.status(key), AttachmentUploadStatus.committed);
      expect(coordinator.needsReconciliation(key), isTrue);
      expect(coordinator.canSubmit(key), isTrue);
      await upload();
      expect(posts, 2);
      visible = true;
      expect(
        await coordinator.reconcileEvent(
          client: client,
          accountId: 'account',
          calendarId: 'calendar',
          eventId: 'event',
        ),
        AttachmentUploadStatus.committed,
      );
      expect(coordinator.needsReconciliation(key), isFalse);
      expect(coordinator.canSubmit(key), isTrue);
    },
  );

  test(
    'late confirmed refresh cannot unlock or relabel a newer attempt',
    () async {
      final firstRefresh = Completer<List<AttachmentUploadRemoteItem>>();
      var submissions = 0;
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      final uploadA = coordinator.upload(
        key: key,
        name: 'a.txt',
        size: 1,
        contentType: 'text/plain',
        bytes: const [1],
        list: () =>
            submissions == 0 ? Future.value(const []) : firstRefresh.future,
        submit: (_) async {
          submissions++;
          return 'attachment-a';
        },
      );
      for (var i = 0; i < 10 && coordinator.confirmedId(key) == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(coordinator.confirmedId(key), 'attachment-a');
      expect(coordinator.canSubmit(key), isTrue);
      await expectLater(
        coordinator.upload(
          key: key,
          name: 'b.txt',
          size: 1,
          contentType: 'text/plain',
          bytes: const [2],
          list: () async => const [],
          submit: (_) async {
            submissions++;
            throw http.ClientException('response lost');
          },
        ),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
      expect(coordinator.confirmedId(key), equals(null));
      coordinator.attachmentRemoved(key, 'attachment-a');
      expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
      firstRefresh.complete(const []);
      await uploadA;
      for (var i = 0; i < 4; i++) {
        await Future<void>.value();
      }
      expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
      expect(coordinator.canSubmit(key), isFalse);
      expect(submissions, 2);
    },
  );

  testWidgets('Linux Add remains enabled after confirmed refresh failure', (
    tester,
  ) async {
    var posts = 0;
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          if (posts > 0) throw http.ClientException('list unavailable');
          return http.Response(jsonEncode({'value': []}), 200);
        }
        posts++;
        return http.Response(
          jsonEncode({
            'id': 'attachment-a',
            'name': 'a.txt',
            'size': 1,
            '@odata.type': '#microsoft.graph.fileAttachment',
          }),
          201,
        );
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    final coordinator = AttachmentUploadCoordinator();
    await coordinator.uploadEvent(
      client: client,
      accountId: 'microsoft:a',
      calendarId: 'remote-calendar',
      eventId: 'remote-event',
      name: 'a.txt',
      contentType: 'text/plain',
      bytes: const [1],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentUploadCoordinatorProvider.overrideWith(
            (ref) => coordinator,
          ),
          microsoftCalendarApiClientForAccountProvider(
            'microsoft:a',
          ).overrideWithValue(client),
        ],
        child: localizedTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showLinuxEventAttachmentsDialog(context, _event),
                child: const Text('Open attachments'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open attachments'));
    await tester.pumpAndSettle();
    final add = tester.widget<FilledButton>(
      find.byKey(const Key('event-attachment-add')),
    );
    expect(add.onPressed, isNot(equals(null)));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open attachments'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('event-attachment-add')))
          .onPressed,
      isNot(equals(null)),
    );
    expect(posts, 1);
  });

  test(
    'successful empty refresh clears confirmed presentation state',
    () async {
      var posts = 0;
      var failRefresh = true;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            if (posts > 0 && failRefresh) {
              failRefresh = false;
              throw http.ClientException('list unavailable');
            }
            return http.Response(jsonEncode({'value': []}), 200);
          }
          posts++;
          return http.Response(
            jsonEncode({
              'id': 'attachment-a',
              'name': 'a.txt',
              'size': 1,
              '@odata.type': '#microsoft.graph.fileAttachment',
            }),
            201,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      await coordinator.uploadEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
        name: 'a.txt',
        contentType: 'text/plain',
        bytes: const [1],
      );
      expect(coordinator.confirmedId(key), 'attachment-a');
      expect(
        await coordinator.reconcileEvent(
          client: client,
          accountId: 'account',
          calendarId: 'calendar',
          eventId: 'event',
        ),
        AttachmentUploadStatus.committed,
      );
      expect(coordinator.confirmedId(key), equals(null));
      expect(coordinator.canSubmit(key), isTrue);
      expect(posts, 1);
    },
  );

  test(
    'malformed success response cannot authorize a duplicate upload',
    () async {
      var posts = 0;
      var visible = false;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'value': visible
                    ? [
                        {
                          'id': 'committed-id',
                          'name': 'notes.txt',
                          'size': 4,
                          '@odata.type': '#microsoft.graph.fileAttachment',
                        },
                      ]
                    : [],
              }),
              200,
            );
          }
          posts++;
          return http.Response('not-json', 201);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final coordinator = AttachmentUploadCoordinator();
      final key = AttachmentUploadCoordinator.eventKey(
        'account',
        'calendar',
        'event',
      );
      Future<void> upload() => coordinator.uploadEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
        name: 'notes.txt',
        contentType: 'text/plain',
        bytes: [1, 2, 3, 4],
      );
      await expectLater(
        upload(),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      expect(coordinator.status(key), AttachmentUploadStatus.unresolved);
      await expectLater(
        upload(),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      );
      expect(posts, 1);
      visible = true;
      expect(
        await coordinator.reconcileEvent(
          client: client,
          accountId: 'account',
          calendarId: 'calendar',
          eventId: 'event',
        ),
        AttachmentUploadStatus.unresolved,
      );
    },
  );
  for (final platform in ['Linux', 'Windows', 'Android']) {
    testWidgets(
      '$platform exposes review before retrying an uncertain event upload',
      (tester) async {
        var posts = 0;
        final client = MicrosoftCalendarApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response(jsonEncode({'value': []}), 200);
            }
            posts++;
            throw http.ClientException('direct response lost');
          }),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          responseTimeZone: 'UTC',
        );
        final coordinator = AttachmentUploadCoordinator();
        final key = AttachmentUploadCoordinator.eventKey(
          'microsoft:a',
          'remote-calendar',
          'remote-event',
        );
        await expectLater(
          coordinator.uploadEvent(
            client: client,
            accountId: 'microsoft:a',
            calendarId: 'remote-calendar',
            eventId: 'remote-event',
            name: 'notes.txt',
            contentType: 'text/plain',
            bytes: [1],
          ),
          throwsA(isA<AttachmentUploadUnresolvedException>()),
        );
        expect(
          await coordinator.reconcileEvent(
            client: client,
            accountId: 'microsoft:a',
            calendarId: 'remote-calendar',
            eventId: 'remote-event',
          ),
          AttachmentUploadStatus.unresolved,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentUploadCoordinatorProvider.overrideWith(
                (ref) => coordinator,
              ),
              microsoftCalendarApiClientForAccountProvider(
                'microsoft:a',
              ).overrideWithValue(client),
            ],
            child: platform == 'Windows'
                ? fluent.FluentApp(
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Builder(
                      builder: (context) => fluent.Button(
                        onPressed: () =>
                            showWindowsEventAttachmentsDialog(context, _event),
                        child: const fluent.Text('Open attachments'),
                      ),
                    ),
                  )
                : localizedTestApp(
                    child: Scaffold(
                      body: Builder(
                        builder: (context) => TextButton(
                          onPressed: () => platform == 'Android'
                              ? showAndroidEventAttachmentsDialog(
                                  context,
                                  _event,
                                )
                              : showLinuxEventAttachmentsDialog(
                                  context,
                                  _event,
                                ),
                          child: const Text('Open attachments'),
                        ),
                      ),
                    ),
                  ),
          ),
        );
        await tester.tap(find.text('Open attachments'));
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byKey(const Key('event-attachment-add')), findsOneWidget);
        expect(coordinator.canSubmit(key), isFalse);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(coordinator.canSubmit(key), isFalse);
        await tester.tap(find.text('Retry').last);
        await tester.pumpAndSettle();
        expect(coordinator.canSubmit(key), isTrue);
        expect(posts, 1);
      },
    );
    testWidgets('$platform queues a Nextcloud URI reference from details', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = CalendarRepository(database: database);
      const accountId = 'nextcloud:a';
      const collectionId = 'dav-collection';
      const href = '/remote.php/dav/calendars/a/work/';
      const body =
          'BEGIN:VCALENDAR\r\n'
          'VERSION:2.0\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:attachment@example.test\r\n'
          'DTSTART:20260608T090000Z\r\n'
          'DTEND:20260608T100000Z\r\n'
          'SUMMARY:Planning\r\n'
          'ATTACH:https://files.example/old.pdf\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: accountId,
              provider: 'nextcloud',
              authority: 'https://cloud.example.test',
              providerAccountId: 'a',
              credentialKind: 'nextcloud_app_password',
              authState: const Value('signed_in'),
              createdAtUtc: '2026-06-08T00:00:00.000Z',
              updatedAtUtc: '2026-06-08T00:00:00.000Z',
            ),
          );
      await database
          .into(database.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: collectionId,
              accountId: accountId,
              hrefKey: href,
              requestUri: 'https://cloud.example.test$href',
              displayName: 'Work',
              supportedComponentMask: const Value(1),
              currentUserPrivilegesJson: const Value(
                '["{DAV:}read","{DAV:}write"]',
              ),
              readOnly: const Value(false),
              eventProjectionEnabled: const Value(true),
              createdAtUtc: '2026-06-08T00:00:00.000Z',
              updatedAtUtc: '2026-06-08T00:00:00.000Z',
            ),
          );
      await database
          .into(database.calendarSources)
          .insert(
            CalendarSourcesCompanion.insert(
              id: 'dav-calendar-dav-collection',
              accountId: accountId,
              provider: 'nextcloud',
              providerCalendarId: href,
              davCollectionId: const Value(collectionId),
              summary: 'Work',
              createdAtLocal: 0,
              updatedAtLocal: 0,
            ),
          );
      final prepared = DavPreparedObject.parse(
        hrefKey: '${href}attachment.ics',
        requestUri: Uri.parse(
          'https://cloud.example.test${href}attachment.ics',
        ),
        etag: '"v1"',
        contentType: 'text/calendar',
        rawIcsBody: body,
      );
      await DavObjectRepository(database: database).commit(
        DavCollectionCommit(
          accountId: accountId,
          collectionId: collectionId,
          provider: BusyProvider.nextcloud,
          objects: [prepared],
          deletedHrefKeys: const {},
          completeMembership: true,
          membershipHrefKeys: {prepared.hrefKey},
          finalCursorKind: 'dav_sync_token',
          finalCursorValue: 'sync-1',
          baselineGeneration: 1,
          completedAtUtc: DateTime.utc(2026, 6, 8),
          projectionRangeStartUtc: DateTime.utc(2026, 6),
          projectionRangeEndUtc: DateTime.utc(2026, 7),
        ),
      );
      final event = await database.select(database.calendarEvents).getSingle();
      final item = CalendarScheduleItem(
        id: event.id,
        accountId: accountId,
        provider: BusyProvider.nextcloud,
        sourceId: event.calendarSourceId,
        providerCalendarId: event.providerCalendarId,
        providerEventId: event.providerEventId,
        title: event.title,
        allDay: event.allDay,
        attachmentLinks: const [
          EventAttachmentLink(
            url: 'https://files.example/old.pdf',
            name: 'old.pdf',
          ),
        ],
        attachmentsLoaded: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarRepositoryProvider.overrideWithValue(repository)],
          child: platform == 'Windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Builder(
                    builder: (context) => fluent.Button(
                      onPressed: () =>
                          showWindowsEventAttachmentsDialog(context, item),
                      child: const fluent.Text('Open attachments'),
                    ),
                  ),
                )
              : localizedTestApp(
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => platform == 'Android'
                            ? showAndroidEventAttachmentsDialog(context, item)
                            : showLinuxEventAttachmentsDialog(context, item),
                        child: const Text('Open attachments'),
                      ),
                    ),
                  ),
                ),
        ),
      );
      await tester.tap(find.text('Open attachments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-attachment-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).last,
        'https://files.example/new.pdf',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('new.pdf'), findsOneWidget);
      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'dav.update');
      expect(
        (await database.select(database.calendarEvents).getSingle())
            .attachmentsJson,
        contains('new.pdf'),
      );
      await tester.tap(
        find.byKey(const Key('event-attachment-remove-reference')).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('old.pdf'), findsNothing);
      final queued = await database.select(database.pendingOps).get();
      expect(queued, hasLength(1));
      expect(
        (await database.select(database.calendarEvents).getSingle())
            .attachmentsJson,
        isNot(contains('old.pdf')),
      );
    });

    testWidgets('$platform changes a Google reference and cached event', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = CalendarRepository(database: database);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'google:a',
              provider: 'google',
              authority: 'https://accounts.google.com',
              providerAccountId: 'a',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              grantedScopes: const Value(''),
              createdAtUtc: '2026-06-08T00:00:00.000Z',
              updatedAtUtc: '2026-06-08T00:00:00.000Z',
            ),
          );
      await repository.upsertSource(
        accountId: 'google:a',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'google-calendar',
          summary: 'Google Calendar',
        ),
      );
      final attachments = <Map<String, Object?>>[];
      var patchCount = 0;
      final requests = <String>[];
      Map<String, Object?> event() => {
        'id': 'google-event',
        'etag': '"v${patchCount + 1}"',
        'summary': 'Planning',
        'start': {'dateTime': '2026-06-08T09:00:00Z'},
        'end': {'dateTime': '2026-06-08T10:00:00Z'},
        'attachments': attachments,
      };
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url}');
          if (request.method == 'PATCH') {
            patchCount++;
            expect(request.url.queryParameters['supportsAttachments'], 'true');
            attachments
              ..clear()
              ..addAll([
                for (final item
                    in jsonDecode(request.body)['attachments'] as List)
                  Map<String, Object?>.from(item as Map),
              ]);
          }
          return http.Response(jsonEncode(event()), 200);
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      const item = CalendarScheduleItem(
        id: 'google-local',
        accountId: 'google:a',
        provider: BusyProvider.google,
        sourceId: 'google-calendar',
        providerCalendarId: 'google-calendar',
        providerEventId: 'google-event',
        title: 'Planning',
        allDay: false,
        attachmentsLoaded: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarRepositoryProvider.overrideWithValue(repository),
            googleCalendarApiClientForAccountProvider(
              'google:a',
            ).overrideWithValue(client),
          ],
          child: platform == 'Windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Builder(
                    builder: (context) => fluent.Button(
                      onPressed: () =>
                          showWindowsEventAttachmentsDialog(context, item),
                      child: const fluent.Text('Open attachments'),
                    ),
                  ),
                )
              : localizedTestApp(
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => platform == 'Android'
                            ? showAndroidEventAttachmentsDialog(context, item)
                            : showLinuxEventAttachmentsDialog(context, item),
                        child: const Text('Open attachments'),
                      ),
                    ),
                  ),
                ),
        ),
      );
      await tester.tap(find.text('Open attachments'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-attachment-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).last,
        'https://drive.google.com/file/d/Agenda.pdf',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(
        patchCount,
        1,
        reason:
            'Requests: $requests. Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).whereType<String>().join(' | ')}',
      );
      expect(find.text('Agenda.pdf'), findsOneWidget);
      var rows = await database.select(database.calendarEvents).get();
      expect(rows.single.attachmentsJson, contains('Agenda.pdf'));

      await tester.tap(
        find.byKey(const Key('event-attachment-remove-reference')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(patchCount, 2);
      expect(attachments, isEmpty);
      rows = await database.select(database.calendarEvents).get();
      expect(rows.single.attachmentsJson, '[]');
    });

    testWidgets('$platform shows Google attachment references without Graph', (
      tester,
    ) async {
      var graphRequests = 0;
      const googleEvent = CalendarScheduleItem(
        id: 'google-local',
        accountId: 'google:a',
        provider: BusyProvider.google,
        sourceId: 'google-calendar',
        providerCalendarId: 'google-calendar',
        providerEventId: 'google-event',
        title: 'Planning',
        allDay: false,
        attachmentLinks: [
          EventAttachmentLink(
            url: 'https://drive.google.com/file/d/agenda/view',
            name: 'Agenda.pdf',
          ),
        ],
        attachmentsLoaded: true,
        capabilities: ScheduleItemCapabilities.readOnly,
      );
      final graph = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          graphRequests++;
          return http.Response('{"value":[]}', 200);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            microsoftCalendarApiClientForAccountProvider(
              'google:a',
            ).overrideWithValue(graph),
          ],
          child: platform == 'Windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Builder(
                    builder: (context) => fluent.Button(
                      onPressed: () => showWindowsEventAttachmentsDialog(
                        context,
                        googleEvent,
                      ),
                      child: const fluent.Text('Open attachments'),
                    ),
                  ),
                )
              : localizedTestApp(
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => platform == 'Android'
                            ? showAndroidEventAttachmentsDialog(
                                context,
                                googleEvent,
                              )
                            : showLinuxEventAttachmentsDialog(
                                context,
                                googleEvent,
                              ),
                        child: const Text('Open attachments'),
                      ),
                    ),
                  ),
                ),
        ),
      );
      await tester.tap(find.text('Open attachments'));
      await tester.pumpAndSettle();
      expect(graphRequests, 0);
      expect(find.text('Agenda.pdf'), findsOneWidget);
    });

    testWidgets('$platform event attachment dialog loads only when opened', (
      tester,
    ) async {
      var requests = 0;
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests++;
          expect(
            request.url.path,
            '/v1.0/me/calendars/remote-calendar/events/remote-event/attachments',
          );
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 'file',
                  'name': 'Agenda.pdf',
                  'size': 4,
                  '@odata.type': '#microsoft.graph.fileAttachment',
                },
              ],
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      final launcher = Builder(
        builder: (context) => platform == 'Windows'
            ? fluent.Button(
                onPressed: () =>
                    showWindowsEventAttachmentsDialog(context, _event),
                child: const fluent.Text('Open attachments'),
              )
            : TextButton(
                onPressed: () => platform == 'Android'
                    ? showAndroidEventAttachmentsDialog(context, _event)
                    : showLinuxEventAttachmentsDialog(context, _event),
                child: const Text('Open attachments'),
              ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            microsoftCalendarApiClientForAccountProvider(
              'microsoft:a',
            ).overrideWithValue(client),
          ],
          child: platform == 'Windows'
              ? fluent.FluentApp(
                  localizationsDelegates: const [AppLocalizations.delegate],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: launcher,
                )
              : localizedTestApp(child: Scaffold(body: launcher)),
        ),
      );
      expect(requests, 0);
      await tester.tap(find.text('Open attachments'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Agenda.pdf'), findsOneWidget);
      expect(find.text('4 B'), findsOneWidget);
    });

    testWidgets(
      '$platform removes a Microsoft attachment only after confirmation',
      (tester) async {
        var deletes = 0;
        var posts = 0;
        var failRefresh = false;
        final client = MicrosoftCalendarApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'DELETE') {
              deletes++;
              expect(
                request.url.path,
                '/v1.0/me/calendars/remote-calendar/events/remote-event/attachments/file',
              );
              return http.Response('', 204);
            }
            if (request.method == 'POST') {
              posts++;
              failRefresh = true;
              return http.Response(
                jsonEncode({
                  'id': 'file',
                  'name': 'Agenda.pdf',
                  'size': 4,
                  '@odata.type': '#microsoft.graph.fileAttachment',
                }),
                201,
              );
            }
            if (failRefresh) {
              failRefresh = false;
              throw http.ClientException('list refresh unavailable');
            }
            return http.Response(
              jsonEncode({
                'value': deletes == 0
                    ? [
                        {
                          'id': 'file',
                          'name': 'Agenda.pdf',
                          'size': 4,
                          '@odata.type': '#microsoft.graph.fileAttachment',
                        },
                      ]
                    : <Object>[],
              }),
              200,
            );
          }),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          responseTimeZone: 'UTC',
        );
        final coordinator = AttachmentUploadCoordinator();
        final uploadKey = AttachmentUploadCoordinator.eventKey(
          'microsoft:a',
          'remote-calendar',
          'remote-event',
        );
        await coordinator.uploadEvent(
          client: client,
          accountId: 'microsoft:a',
          calendarId: 'remote-calendar',
          eventId: 'remote-event',
          name: 'Agenda.pdf',
          contentType: 'application/pdf',
          bytes: const [1, 2, 3, 4],
        );
        expect(coordinator.confirmedId(uploadKey), 'file');
        expect(coordinator.canSubmit(uploadKey), isTrue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              attachmentUploadCoordinatorProvider.overrideWith(
                (ref) => coordinator,
              ),
              microsoftCalendarApiClientForAccountProvider(
                'microsoft:a',
              ).overrideWithValue(client),
            ],
            child: platform == 'Windows'
                ? fluent.FluentApp(
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: fluent.Button(
                      onPressed: () => showWindowsEventAttachmentsDialog(
                        tester.element(find.byType(fluent.Button).first),
                        _event,
                      ),
                      child: const fluent.Text('Open attachments'),
                    ),
                  )
                : localizedTestApp(
                    child: Scaffold(
                      body: Builder(
                        builder: (context) => TextButton(
                          onPressed: () => platform == 'Android'
                              ? showAndroidEventAttachmentsDialog(
                                  context,
                                  _event,
                                )
                              : showLinuxEventAttachmentsDialog(
                                  context,
                                  _event,
                                ),
                          child: const Text('Open attachments'),
                        ),
                      ),
                    ),
                  ),
          ),
        );
        await tester.tap(find.text('Open attachments'));
        await tester.pumpAndSettle();
        if (platform == 'Android') {
          await tester.tap(find.byTooltip('Delete').last);
        } else {
          await tester.tap(find.text('Delete').last);
        }
        await tester.pumpAndSettle();
        expect(deletes, 0);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(deletes, 0);
        if (platform == 'Android') {
          await tester.tap(find.byTooltip('Delete').last);
        } else {
          await tester.tap(find.text('Delete').last);
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(deletes, 1);
        expect(posts, 1);
        expect(coordinator.confirmedId(uploadKey), equals(null));
        expect(coordinator.canSubmit(uploadKey), isTrue);
      },
    );
  }
}

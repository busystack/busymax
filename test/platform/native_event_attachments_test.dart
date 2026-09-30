import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/android/presentation/android_event_attachments_dialog.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/schedule/presentation/linux_event_attachments_dialog.dart';
import 'package:busymax/src/features/schedule/presentation/attachment_upload_coordinator.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/event_attachment_link.dart';
import 'package:busymax/src/ui/windows/windows_event_attachments_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  test(
    'lost event upload response blocks a second upload until ID reconciliation',
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
        AttachmentUploadStatus.committed,
      );
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
            }),
            200,
          );
        }
        if (request.method == 'PUT') {
          chunks++;
          if (chunks == 2) throw http.ClientException('final response lost');
          return http.Response('', 200);
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
    expect(
      await coordinator.reconcileEvent(
        client: client,
        accountId: 'account',
        calendarId: 'calendar',
        eventId: 'event',
      ),
      AttachmentUploadStatus.committed,
    );
  });

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

  test('confirmed upload with failed refresh cannot be repeated', () async {
    var posts = 0;
    var visible = false;
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          if (posts > 0 && !visible) {
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
    expect(coordinator.canSubmit(key), isFalse);
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
      AttachmentUploadStatus.committed,
    );
    expect(coordinator.needsReconciliation(key), isFalse);
    expect(coordinator.canSubmit(key), isTrue);
  });

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
        AttachmentUploadStatus.committed,
      );
    },
  );
  for (final platform in ['Linux', 'Windows', 'Android']) {
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
      },
    );
  }
}

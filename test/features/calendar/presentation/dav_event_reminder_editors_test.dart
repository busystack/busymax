import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_event_editor_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../test_localized_app.dart';

void main() {
  for (final windows in [false, true]) {
    for (final provider in [BusyProvider.caldav, BusyProvider.nextcloud]) {
      for (final action in ['edit', 'add', 'delete']) {
        testWidgets(
          '${windows ? 'Windows' : 'Linux'} $provider $action retains DAV alarm identities',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1400, 1800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final db = AppDatabase.memoryForTests();
            addTearDown(db.close);
            final objects = DavObjectRepository(database: db);
            final repository = CalendarRepository(
              database: db,
              localTimeZone: 'UTC',
            );
            final now = DateTime.now().toUtc();
            await db
                .into(db.accounts)
                .insert(
                  AccountsCompanion.insert(
                    id: 'account',
                    provider: provider.storageValue,
                    authority: 'https://cloud.example.test',
                    providerAccountId: 'user',
                    credentialKind: provider == BusyProvider.caldav
                        ? 'caldav_password'
                        : 'nextcloud_app_password',
                    authState: const Value('signed_in'),
                    createdAtUtc: now.toIso8601String(),
                    updatedAtUtc: now.toIso8601String(),
                  ),
                );
            await db
                .into(db.davCollections)
                .insert(
                  DavCollectionsCompanion.insert(
                    id: 'collection',
                    accountId: 'account',
                    hrefKey: '/calendar/',
                    requestUri: 'https://cloud.example.test/calendar/',
                    displayName: 'Work',
                    supportedComponentMask: const Value(1),
                    currentUserPrivilegesJson: const Value(
                      '["{DAV:}read","{DAV:}write"]',
                    ),
                    readOnly: const Value(false),
                    eventProjectionEnabled: const Value(true),
                    createdAtUtc: now.toIso8601String(),
                    updatedAtUtc: now.toIso8601String(),
                  ),
                );
            await db
                .into(db.calendarSources)
                .insert(
                  CalendarSourcesCompanion.insert(
                    id: 'dav-calendar-collection',
                    accountId: 'account',
                    provider: provider.storageValue,
                    providerCalendarId: '/calendar/',
                    davCollectionId: const Value('collection'),
                    summary: 'Work',
                    createdAtLocal: 0,
                    updatedAtLocal: 0,
                  ),
                );
            final raw = _raw.replaceFirst(
              'SUMMARY:Reminders',
              provider == BusyProvider.caldav
                  ? 'SUMMARY:Reminders\r\nATTENDEE;CN=Guest;PARTSTAT=ACCEPTED:mailto:guest@example.test'
                  : 'SUMMARY:Reminders',
            );
            final prepared = DavPreparedObject.parse(
              hrefKey: '/calendar/event.ics',
              requestUri: Uri.parse(
                'https://cloud.example.test/calendar/event.ics',
              ),
              etag: '"one"',
              contentType: 'text/calendar',
              rawIcsBody: raw,
            );
            await objects.commit(
              DavCollectionCommit(
                accountId: 'account',
                collectionId: 'collection',
                provider: provider,
                objects: [prepared],
                deletedHrefKeys: const {},
                completeMembership: true,
                membershipHrefKeys: {prepared.hrefKey},
                finalCursorKind: 'dav_sync_token',
                finalCursorValue: 'one',
                baselineGeneration: 1,
                completedAtUtc: now,
                projectionRangeStartUtc: DateTime.utc(2026),
                projectionRangeEndUtc: DateTime.utc(2028),
              ),
            );
            final eventId = (await db.select(db.calendarEvents).getSingle()).id;
            final detail = (await tester.runAsync(
              () => repository.loadEventDetail(eventId),
            ))!;
            final sources = (await tester.runAsync(
              () => repository.watchSourcesForAccounts(['account']).first,
            ))!;
            var syncs = 0, puts = 0, reads = 0;
            var syncCompleted = false;
            Object? syncFailure;
            var serverBody = raw;
            final transport = DavHttpTransport(
              client: MockClient((request) async {
                if (request.method == 'PUT') {
                  expectSync(request.headers['if-match'], '"one"');
                  serverBody = request.body;
                  puts++;
                  return http.Response('', 204);
                }
                expectSync(request.method, 'GET');
                reads++;
                return http.Response(
                  serverBody,
                  200,
                  headers: {'etag': '"two"', 'content-type': 'text/calendar'},
                );
              }),
              profile: davProviderProfile(
                provider,
                nextcloudServer: Uri.parse('https://cloud.example.test'),
                caldavServer: Uri.parse('https://cloud.example.test'),
              ),
              accountAuthority: Uri.parse('https://cloud.example.test'),
            );
            final requester = PendingMutationSyncRequester(
              debounce: Duration.zero,
              onSyncFailure: (error) async {
                syncFailure = error;
                syncCompleted = true;
              },
              sync: () async {
                syncs++;
                final summary = await DavPendingOperationsReplayer(
                  database: db,
                  accountId: 'account',
                  objectRepository: objects,
                  serviceFactory:
                      ({required account, required collection}) async =>
                          DavConditionalMutationService(
                            remoteClient: DavMutationHttpClient(
                              transport: transport,
                              accountId: 'account',
                              collectionId: 'collection',
                              credential: DavBasicCredential(
                                username: 'user',
                                password: 'synthetic',
                              ),
                            ),
                          ),
                ).replayDueOperations();
                expectSync(summary.appliedCount, 1);
                syncCompleted = true;
              },
            );
            addTearDown(requester.dispose);
            bool? saved;
            if (windows) {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    databaseProvider.overrideWithValue(db),
                    calendarRepositoryProvider.overrideWithValue(
                      _EditorRepository(db, sources),
                    ),
                    accountsRepositoryProvider.overrideWithValue(
                      _EditorAccounts(db, provider),
                    ),
                    localTimeZoneProvider.overrideWithValue('UTC'),
                    pendingCalendarMutationSyncRequesterForAccountProvider(
                      'account',
                    ).overrideWithValue(requester),
                  ],
                  child: fluent.FluentApp(
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Consumer(
                      builder: (context, ref, _) => fluent.Button(
                        child: const Text('Open'),
                        onPressed: () async {
                          saved = await showWindowsEventEditorDialog(
                            context,
                            ref,
                            eventId: eventId,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
              await tester.tap(find.text('Open'));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pumpAndSettle();
              if (provider == BusyProvider.caldav) {
                expect(
                  find.textContaining('guest@example.test'),
                  findsOneWidget,
                );
                expect(find.text('Add guest'), findsNothing);
                // Read-only attendee rows render role/response text, no role picker.
                expect(find.byType(fluent.ComboBox<bool>), findsNothing);
              }
              final combos = tester
                  .widgetList<fluent.ComboBox<int>>(
                    find.byType(fluent.ComboBox<int>),
                  )
                  .where((w) => w.value == 30)
                  .toList();
              expect(
                combos,
                hasLength(2),
              ); // Equal-minute alarms have distinct identities.
              switch (action) {
                case 'edit':
                  combos.first.onChanged!(45);
                case 'add':
                  await tester.ensureVisible(find.text('Add Reminder'));
                  await tester.tap(find.text('Add Reminder'));
                case 'delete':
                  final row = find
                      .ancestor(
                        of: find.byWidget(combos.first),
                        matching: find.byType(Row),
                      )
                      .first;
                  tester
                      .widget<fluent.IconButton>(
                        find.descendant(
                          of: row,
                          matching: find.byType(fluent.IconButton),
                        ),
                      )
                      .onPressed!();
              }
              await tester.pump();
              await tester.tap(find.text('Save').last);
              await tester.pump();
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 150)),
              );
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pumpAndSettle();
              expect(saved, isTrue);
              for (var i = 0; i < 30 && !syncCompleted; i++) {
                await tester.pump(const Duration(milliseconds: 20));
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)),
                );
              }
              expect(syncFailure, isNull);
              expect(syncCompleted, isTrue);
              // The editor's immediate sync request drives a PUT and authoritative GET.
              expect(syncs, 1);
              expect(puts, 1);
              expect(reads, greaterThanOrEqualTo(1));
              expect(await db.select(db.pendingOps).get(), isEmpty);
            } else {
              await tester.pumpWidget(
                localizedTestApp(
                  child: Scaffold(
                    body: EventEditor(
                      initialDraft: EventEditorDraft.fromEventDetail(detail),
                      sources: sources,
                      onCancel: () {},
                      onSave: (draft) async {
                        await repository.updateLocalEvent(draft);
                        saved = true;
                      },
                    ),
                  ),
                ),
              );
              final rows = tester
                  .widgetList<BusyMaxComboRow<int>>(
                    find.byType(BusyMaxComboRow<int>),
                  )
                  .where((w) => w.title == 'Reminder')
                  .toList();
              expect(rows.map((r) => r.selected), [0, 30, 30]);
              switch (action) {
                case 'edit':
                  rows[1].onSelected(45);
                case 'add':
                  await tester.ensureVisible(find.text('Add Reminder'));
                  await tester.tap(find.text('Add Reminder'));
                case 'delete':
                  await tester.ensureVisible(
                    find.byTooltip('Remove reminder').at(1),
                  );
                  await tester.tap(find.byTooltip('Remove reminder').at(1));
              }
              await tester.pump();
              await tester.tap(
                find
                    .ancestor(
                      of: find.text('Save'),
                      matching: find.byWidgetPredicate(
                        (w) => w is ButtonStyleButton,
                      ),
                    )
                    .first,
              );
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)),
              );
              await tester.pumpAndSettle();
              expect(saved, isTrue);
              final op = await db.select(db.pendingOps).getSingle();
              serverBody = DavMutationPatch.fromJsonString(
                op.mutationPatchJson!,
              ).applyTo(op.baselineRawIcs!, nowUtc: now);
            }
            expect(tester.takeException(), isNull);
            expect(serverBody, contains(_zeroAlarm));
            expect(serverBody, contains(_duplicateAlarm));
            expect(serverBody, contains(_audioAlarm));
            expect(serverBody, contains(_endAlarm));
            if (action == 'delete') {
              expect(serverBody, isNot(contains('X-KEEP:edited')));
            } else {
              expect(
                serverBody,
                contains('DESCRIPTION:Custom description\r\nX-KEEP:edited'),
              );
              if (action == 'edit') {
                expect(serverBody, contains('TRIGGER:-PT45M'));
              }
            }
            if (action == 'add') {
              expect('BEGIN:VALARM'.allMatches(serverBody), hasLength(6));
            }
            final updated = (await tester.runAsync(
              () => repository.loadEventDetail(eventId),
            ))!;
            expect(updated.reminders.toString(), contains('X-KEEP'));
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
        );
      }
    }
  }
}

const _zeroAlarm =
    'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT0M\r\nDESCRIPTION:At start\r\nX-KEEP:zero\r\nEND:VALARM\r\n';
const _editedAlarm =
    'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nDESCRIPTION:Custom description\r\nX-KEEP:edited\r\nEND:VALARM\r\n';
const _duplicateAlarm =
    'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nDESCRIPTION:Same time, different alarm\r\nX-KEEP:duplicate\r\nEND:VALARM\r\n';
const _audioAlarm =
    'BEGIN:VALARM\r\nACTION:AUDIO\r\nTRIGGER:-PT5M\r\nX-KEEP:audio\r\nEND:VALARM\r\n';
const _endAlarm =
    'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER;RELATED=END:-PT0M\r\nDESCRIPTION:End\r\nX-KEEP:end\r\nEND:VALARM\r\n';
const _raw =
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:reminders\r\nDTSTART:20261110T090000Z\r\nDTEND:20261110T100000Z\r\nSUMMARY:Reminders\r\n$_zeroAlarm$_editedAlarm$_duplicateAlarm$_audioAlarm${_endAlarm}END:VEVENT\r\nEND:VCALENDAR\r\n';

class _EditorRepository extends CalendarRepository {
  _EditorRepository(AppDatabase db, this.sources)
    : super(database: db, localTimeZone: 'UTC');
  final List<CalendarSourceEntity> sources;
  @override
  Stream<List<CalendarSourceEntity>> watchSourcesForAccounts(
    List<String> ids,
  ) => Stream.value(sources);
}

class _EditorAccounts extends AccountsRepository {
  _EditorAccounts(AppDatabase db, this.provider) : super(database: db);
  final BusyProvider provider;
  @override
  Stream<List<AccountEntity>> watchAccounts() => Stream.value([
    AccountEntity(
      id: 'account',
      provider: provider,
      authority: 'https://cloud.example.test',
      providerAccountId: 'user',
      authState: accountAuthStateSignedIn,
    ),
  ]);
}

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = CalendarRepository(database: database);
    await _seed(database);
  });

  tearDown(() async => database.close());

  test('rejects create, edit, delete, move, and RSVP for WebCal', () async {
    final createDraft = EventEditorDraft.newEvent(
      accountId: 'webcal-account-sub',
      sourceId: 'webcal-calendar-sub',
      providerCalendarId: 'sub',
      start: DateTime(2026, 8, 30, 9),
      end: DateTime(2026, 8, 30, 10),
    ).copyWith(title: 'Not allowed');
    await expectLater(
      repository.createLocalEvent(createDraft),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );

    final webCalDetail = (await repository.loadEventDetail('webcal-event'))!;
    await expectLater(
      repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(webCalDetail).copyWith(title: 'Edit'),
      ),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );
    await expectLater(
      repository.deleteLocalEvent('webcal-event'),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );
    await expectLater(
      repository.respondToLocalEvent(
        'webcal-event',
        CalendarInvitationResponse.accept,
      ),
      throwsA(isA<UnsupportedError>()),
    );

    final cloudDetail = (await repository.loadEventDetail('google-event'))!;
    await expectLater(
      repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(cloudDetail).copyWith(
          accountId: 'webcal-account-sub',
          sourceId: 'webcal-calendar-sub',
          providerCalendarId: 'sub',
        ),
      ),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );
    await expectLater(
      repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(webCalDetail).copyWith(
          accountId: 'google-account',
          sourceId: 'google-calendar',
          providerCalendarId: 'primary',
        ),
      ),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );

    expect(await database.select(database.pendingOps).get(), isEmpty);
  });
}

Future<void> _seed(AppDatabase database) async {
  for (final account in [
    (
      id: 'webcal-account-sub',
      provider: 'webcal',
      authority: 'https://calendar.example.test',
      providerId: 'fingerprint',
      credential: 'webcal_subscription',
      tasks: false,
    ),
    (
      id: 'google-account',
      provider: 'google',
      authority: 'https://accounts.google.com',
      providerId: 'me@example.test',
      credential: 'oauth',
      tasks: true,
    ),
  ]) {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: account.id,
            provider: account.provider,
            authority: account.authority,
            providerAccountId: account.providerId,
            credentialKind: account.credential,
            authState: const Value('signed_in'),
            calendarsEnabled: const Value(true),
            tasksEnabled: Value(account.tasks),
            grantedScopes: const Value(''),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
  }
  for (final source in [
    (
      id: 'webcal-calendar-sub',
      accountId: 'webcal-account-sub',
      provider: 'webcal',
      calendarId: 'sub',
      readOnly: true,
    ),
    (
      id: 'google-calendar',
      accountId: 'google-account',
      provider: 'google',
      calendarId: 'primary',
      readOnly: false,
    ),
  ]) {
    await database
        .into(database.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: source.id,
            accountId: source.accountId,
            provider: source.provider,
            providerCalendarId: source.calendarId,
            summary: source.id,
            readOnly: Value(source.readOnly),
            accessRole: Value(source.readOnly ? 'reader' : 'owner'),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
  }
  for (final event in [
    (
      id: 'webcal-event',
      accountId: 'webcal-account-sub',
      sourceId: 'webcal-calendar-sub',
      provider: 'webcal',
      calendarId: 'sub',
    ),
    (
      id: 'google-event',
      accountId: 'google-account',
      sourceId: 'google-calendar',
      provider: 'google',
      calendarId: 'primary',
    ),
  ]) {
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: event.id,
            accountId: event.accountId,
            calendarSourceId: event.sourceId,
            provider: event.provider,
            providerCalendarId: event.calendarId,
            providerEventId: event.id,
            title: event.id,
            startDateTime: const Value('2026-08-30T09:00:00'),
            startTimeZone: const Value('UTC'),
            endDateTime: const Value('2026-08-30T10:00:00'),
            endTimeZone: const Value('UTC'),
            organizerJson: Value(
              event.provider == 'google' ? '{"self":true}' : null,
            ),
            rawJson: const Value('{}'),
            baselineRawJson: const Value('{}'),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
  }
}

const _now = '2026-08-29T00:00:00.000Z';

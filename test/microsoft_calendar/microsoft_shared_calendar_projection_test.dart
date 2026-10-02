import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restricted delegated private item hides cached details and cannot queue deletion',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'microsoft:a',
              provider: BusyProvider.microsoft.storageValue,
              authority: 'https://login.microsoftonline.com/common',
              providerAccountId: 'a',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              grantedScopes: const Value(''),
              createdAtUtc: '2026-07-01T00:00:00.000Z',
              updatedAtUtc: '2026-07-01T00:00:00.000Z',
            ),
          );
      final calendarId = const MicrosoftSharedPrimaryCalendarAddress(
        owner: 'owner@example.com',
        graphCalendarId: 'owner-calendar',
      ).sourceCalendarId;
      final repository = CalendarRepository(database: database);
      await repository.upsertSource(
        accountId: 'microsoft:a',
        source: CalendarSourceDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: calendarId,
          summary: 'Owner calendar',
          readOnly: false,
          rawJson: const {'canViewPrivateItems': false},
        ),
      );
      await repository.upsertEvent(
        accountId: 'microsoft:a',
        event: CalendarEventDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: calendarId,
          providerEventId: 'private-event',
          title: 'Sensitive title',
          description: 'Sensitive description',
          location: 'Sensitive location',
          startDateTime: '2026-07-15T09:00:00',
          endDateTime: '2026-07-15T10:00:00',
          startTimeZone: 'UTC',
          endTimeZone: 'UTC',
          visibility: 'private',
          webLink: 'https://outlook.example/private',
          attachmentsJson: const [
            {'fileUrl': 'https://files.example/private', 'title': 'Secret'},
          ],
          rawJson: const {'hasAttachments': true},
        ),
      );
      final items = await ScheduleRepository(
        database,
      ).listItems(range: ScheduleRange.day(DateTime(2026, 7, 15)));
      final item = items.single as CalendarScheduleItem;
      expect(item.title, isNot(contains('Sensitive')));
      expect(item.description, isNull);
      expect(item.location, isNull);
      expect(item.eventLinkUrl, isNull);
      expect(item.attachmentLinks, isEmpty);
      expect(item.capabilities.canEdit, isFalse);
      expect(item.capabilities.canDelete, isFalse);
      await expectLater(
        repository.deleteLocalEvent(item.id),
        throwsA(isA<CalendarMutationNotAllowed>()),
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );
}

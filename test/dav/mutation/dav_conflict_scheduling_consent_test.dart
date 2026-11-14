import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dav_conflict_fixture.dart';
import '../../support/persistence_test_directory.dart';

void main() {
  for (final component in ['VEVENT', 'VTODO']) {
    for (final attendees in [true, false]) {
      test(
        '$component conflict duplication attendees=$attendees survives restart and requires authorization',
        () async {
          final directory = await createPersistenceTestDirectory(
            'busymax-conflict-consent-',
          );
          AppDatabase open() =>
              AppDatabase(NativeDatabase(File('${directory.path}/db.sqlite')));
          var db = open();
          addTearDown(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
          await seedSchedulingConflict(
            db,
            component: component,
            attendees: attendees,
          );
          Future<DavConflictEntity> conflict() async =>
              (await DavConflictRepository(
                database: db,
              ).watchUnresolved().first).single;
          final originalOps = await db.select(db.pendingOps).get();
          final original = await conflict();
          expect(original.canDuplicate, isTrue);
          expect(original.duplicationRequiresSchedulingConsent, attendees);
          if (attendees) {
            await expectLater(
              DavConflictResolutionService(database: db)
                  .resolve(original.id, DavConflictResolution.duplicateLocal),
              throwsA(
                isA<DavException>().having(
                  (e) => e.code,
                  'code',
                  'IcalSchedulingConsentRequired',
                ),
              ),
            );
            expect(await db.select(db.pendingOps).get(), originalOps);
            expect((await conflict()).canKeepServer, isTrue);
            expect((await conflict()).canReapplyLocal, isTrue);
          }
          // Cancellation does not call resolve. All state must still survive reopening.
          await db.close();
          db = open();
          expect((await conflict()).id, original.id);
          expect(await db.select(db.pendingOps).get(), originalOps);
          await DavConflictResolutionService(database: db).resolve(
            original.id,
            DavConflictResolution.duplicateLocal,
            allowScheduling: attendees,
          );
          expect(
            await DavConflictRepository(database: db).watchUnresolved().first,
            isEmpty,
          );
          final queued = await db.select(db.pendingOps).getSingle();
          expect(queued.operationType, 'dav.create');
          expect(
            (jsonDecode(queued.requestJson) as Map)['schedulingConsent'] ==
                true,
            attendees,
          );
          final data = jsonDecode(queued.requestJson) as Map;
          final raw = data['rawIcs'] as String;
          final uid = data['uid'] as String;
          expect(uid, isNot('event@example.test'));
          expect(raw, contains('X-KEEP:opaque'));
          expect(raw, contains('RRULE:FREQ=DAILY;COUNT=3'));
          expect(raw, contains('RECURRENCE-ID:20260912T090000Z'));
          expect(raw, contains('SUMMARY:Exception'));
          expect(
            raw.contains('ATTENDEE:mailto:guest@example.invalid'),
            attendees,
          );
          expect(
            raw.contains('ORGANIZER:mailto:owner@example.invalid'),
            attendees,
          );
          expect('UID:$uid'.allMatches(raw), hasLength(2));
          await db.close();
          db = open();
          expect(await db.select(db.pendingOps).getSingle(), queued);
          expect(
            (jsonDecode(
              (await db.select(db.pendingOps).getSingle()).requestJson,
            ) as Map)['rawIcs'],
            raw,
          );
          expect(
            await DavConflictRepository(database: db).watchUnresolved().first,
            isEmpty,
          );
        },
      );
    }
  }
}

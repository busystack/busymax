import 'package:busymax/src/dav/storage/dav_collection_creation_notices.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DavCollectionCreationNotices notices;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notices = DavCollectionCreationNotices(
      db,
      nowUtc: () => DateTime.utc(2026, 11, 3),
    );
    for (final id in ['owner', 'other']) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              provider: 'caldav',
              authority: 'https://example.test/',
              providerAccountId: id,
              credentialKind: 'caldav_password',
              createdAtUtc: 'now',
              updatedAtUtc: 'now',
            ),
          );
    }
    for (final state in ['prepared', 'dispatched', 'committed', 'rejected']) {
      await db
          .into(db.davCollectionCreations)
          .insert(
            DavCollectionCreationsCompanion.insert(
              id: state,
              accountId: 'owner',
              authority: 'https://example.test/',
              homeUri: 'https://example.test/home/',
              targetUri: 'https://example.test/home/$state/',
              displayName: const ['prepared', 'dispatched'].contains(state)
                  ? state
                  : 'Same title',
              componentsJson: '["VEVENT"]',
              state: Value(state),
              lastErrorKind: const Value('authorization'),
              lastErrorCode: const Value('DavPermissionDenied'),
              lastErrorStatus: const Value(403),
              createdAtUtc: 'now',
            ),
          );
    }
  });
  tearDown(() => db.close());

  test(
    'only the owning account can acknowledge an existing rejected operation',
    () async {
      for (final id in ['prepared', 'dispatched', 'committed', 'missing']) {
        expect(await notices.acknowledge('owner', id), isFalse);
      }
      expect(await notices.acknowledge('other', 'rejected'), isFalse);
      expect(
        await db.select(db.davCollectionCreationAcknowledgments).get(),
        isEmpty,
      );
      expect((await notices.load('owner')).map((n) => n.operation.id).toSet(), {
        'prepared',
        'dispatched',
        'rejected',
      });
    },
  );

  test('acknowledgment is idempotent presentation metadata and preserves the journal', () async {
    final before = (await db.select(db.davCollectionCreations).get())
        .map((r) => r.toJson())
        .toList();
    expect(await notices.acknowledge('owner', 'rejected'), isTrue);
    final original =
        (await db.select(db.davCollectionCreationAcknowledgments).getSingle())
            .toJson();
    final later = DavCollectionCreationNotices(
      db,
      nowUtc: () => DateTime.utc(2027),
    );
    expect(await later.acknowledge('owner', 'rejected'), isTrue);
    expect(
      (await db.select(db.davCollectionCreationAcknowledgments).getSingle())
          .toJson(),
      original,
    );
    expect(
      (await db.select(db.davCollectionCreations).get())
          .map((r) => r.toJson())
          .toList(),
      before,
    );
    expect((await notices.load('owner')).map((n) => n.operation.id).toSet(), {
      'prepared',
      'dispatched',
    });
    expect(await notices.load('other'), isEmpty);
    final originalFailure = await (db.select(
      db.davCollectionCreations,
    )..where((r) => r.id.equals('rejected'))).getSingle();
    await db
        .into(db.davCollectionCreations)
        .insert(
          originalFailure
              .toCompanion(true)
              .copyWith(
                id: const Value('new-rejection'),
                targetUri: const Value(
                  'https://example.test/home/new-rejection/',
                ),
              ),
        );
    expect(
      (await notices.load('owner'))
          .any((n) => n.operation.id == 'new-rejection'),
      isTrue,
    );
    await (db.delete(db.accounts)..where((r) => r.id.equals('owner'))).go();
    expect(
      await db.select(db.davCollectionCreationAcknowledgments).get(),
      isEmpty,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'a failed acknowledgment write leaves the warning and diagnostics intact',
    () async {
      await db.customStatement(
        "CREATE TRIGGER reject_ack BEFORE INSERT ON dav_collection_creation_acknowledgments BEGIN SELECT RAISE(ABORT, 'test write failure'); END",
      );
      await expectLater(
        notices.acknowledge('owner', 'rejected'),
        throwsA(anything),
      );
      expect(
        await db.select(db.davCollectionCreationAcknowledgments).get(),
        isEmpty,
      );
      final rejected = (await notices.load('owner'))
          .singleWhere((n) => n.operation.id == 'rejected');
      expect(rejected.error.statusCode, 403);
      expect(rejected.operation.state, 'rejected');
    },
  );

  test('pending outcomes remain visible even with inconsistent acknowledgment metadata', () async {
    await db
        .into(db.davCollectionCreationAcknowledgments)
        .insert(
          DavCollectionCreationAcknowledgmentsCompanion.insert(
            operationId: 'dispatched',
            acknowledgedAtUtc: 'now',
          ),
        );
    expect(
      (await notices.load('owner'))
          .any((n) => n.operation.id == 'dispatched' && n.pending),
      isTrue,
    );
    expect(await notices.acknowledge('owner', 'dispatched'), isFalse);
  });
}

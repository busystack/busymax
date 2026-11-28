import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' show Value;

Future<DavCollection> seedLocalJournalCollection(
  AppDatabase db, {
  String accountId = 'qa',
  String collectionId = 'source',
  String displayName = 'Fixture journal',
}) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: accountId,
          provider: 'caldav',
          authority: 'https://example.invalid/',
          providerAccountId: accountId,
          credentialKind: 'caldav_password',
          authState: const Value('signed_in'),
          createdAtUtc: 'now',
          updatedAtUtc: 'now',
        ),
      );
  await db
      .into(db.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: collectionId,
          accountId: accountId,
          hrefKey: '/dav/journals/',
          requestUri: 'https://example.invalid/dav/journals/',
          displayName: displayName,
          journalProjectionEnabled: const Value(true),
          journalInventoryComplete: const Value(true),
          currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
          supportedComponentMask: const Value(8),
          createdAtUtc: 'now',
          updatedAtUtc: 'now',
        ),
      );
  return (db.select(
    db.davCollections,
  )..where((row) => row.id.equals(collectionId))).getSingle();
}

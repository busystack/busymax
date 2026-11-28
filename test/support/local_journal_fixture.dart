import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart' show Value;

Future<DavCollection> seedLocalJournalCollection(AppDatabase db) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'qa',
          provider: 'caldav',
          authority: 'https://example.invalid/',
          providerAccountId: 'qa',
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
          id: 'source',
          accountId: 'qa',
          hrefKey: '/dav/journals/',
          requestUri: 'https://example.invalid/dav/journals/',
          displayName: 'Fixture journal',
          journalProjectionEnabled: const Value(true),
          journalInventoryComplete: const Value(true),
          currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
          supportedComponentMask: const Value(8),
          createdAtUtc: 'now',
          updatedAtUtc: 'now',
        ),
      );
  return db.select(db.davCollections).getSingle();
}

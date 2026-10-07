import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/storage/dav_settings_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dav_task_inventory_fixture.dart';

void main() {
  late AppDatabase database;
  late DavTaskInventoryFixture inventory;
  late ProviderContainer container;
  late DavSettingsRepository repository;
  late TaskList list;
  late DavCollection collection;

  setUp(() async {
    database = AppDatabase.memoryForTests();
    inventory = DavTaskInventoryFixture(database);
    await inventory.seedAccount();
    await inventory.commit(writable: true);
    list = await database.select(database.taskLists).getSingle();
    collection = await database.select(database.davCollections).getSingle();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    repository = container.read(davSettingsRepositoryProvider);
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  _CapabilityProbe probe() {
    final result = _CapabilityProbe(container, list.accountId, list.id);
    addTearDown(result.close);
    return result;
  }

  Future<void> updateCollection(DavCollectionsCompanion changes) =>
      (database.update(
        database.davCollections,
      )..where((row) => row.id.equals(collection.id))).write(changes);

  test(
    'watched lookup and provider follow mapping removal, rebinding, and task-list deletion',
    () async {
      await database
          .into(database.davCollections)
          .insert(
            collection
                .toCompanion(false)
                .copyWith(
                  id: const Value('read-only'),
                  hrefKey: const Value('/other-tasks/'),
                  currentUserPrivilegesJson: const Value('["{DAV:}read"]'),
                ),
          );
      await inventory.seedAccount(id: 'nextcloud:other');
      await inventory.commit(writable: true, account: 'nextcloud:other');
      final other = await (database.select(
        database.davCollections,
      )..where((row) => row.accountId.equals('nextcloud:other'))).getSingle();
      final entities = StreamIterator(
        repository.watchCollectionByTaskListId(list.accountId, list.id),
      );
      addTearDown(entities.cancel);
      final values = probe();
      Future<void> check(String? id, bool? canCreate) async {
        expect(
          await entities.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        expect(entities.current?.id, id);
        expect((await values.next())?.canCreateTasks, canCreate);
        expect(
          (await repository.collectionByTaskListId(
            list.accountId,
            list.id,
          ))?.id,
          id,
        );
        expect(
          (await container.read(
            davTaskCollectionCapabilitiesProvider((
              accountId: list.accountId,
              taskListId: list.id,
            )).future,
          ))?.canCreateTasks,
          canCreate,
        );
      }

      Future<void> bind(String? id) async {
        await (database.update(database.taskLists)..where(
              (row) =>
                  row.accountId.equals(list.accountId) & row.id.equals(list.id),
            ))
            .write(TaskListsCompanion(davCollectionId: Value(id)));
      }

      await check(collection.id, true);
      await bind(null);
      await check(null, null);
      await bind('read-only');
      await check('read-only', false);
      await bind(other.id);
      await check(
        null,
        null,
      ); // A valid foreign key must not leak another account's collection.
      await bind(collection.id);
      await check(collection.id, true);
      await (database.delete(database.taskLists)..where(
            (row) =>
                row.accountId.equals(list.accountId) & row.id.equals(list.id),
          ))
          .go();
      await check(null, null);
      await database.into(database.taskLists).insert(list.toCompanion(false));
      await check(collection.id, true);
      expect(
        await repository
            .watchCollectionByTaskListId('nextcloud:other', list.id)
            .first,
        isNull,
      );
      expect(
        await repository
            .watchCollectionByTaskListId(list.accountId, 'missing')
            .first,
        isNull,
      );
    },
  );

  test(
    'collection deletion and restoration update the existing provider subscription',
    () async {
      final values = probe();
      expect((await values.next())!.canCreateTasks, isTrue);
      await updateCollection(
        const DavCollectionsCompanion(deleted: Value(true)),
      );
      expect(await values.next(), isNull);
      await updateCollection(
        const DavCollectionsCompanion(deleted: Value(false)),
      );
      expect((await values.next())!.canCreateTasks, isTrue);
      await inventory.commit(writable: true, missing: true);
      expect(await values.next(), isNull);
      await inventory.commit(writable: false);
      expect((await values.next())!.canCreateTasks, isFalse);
      expect(
        (await database.select(database.davCollections).getSingle()).id,
        collection.id,
      );

      await (database.delete(
        database.davCollections,
      )..where((row) => row.id.equals(collection.id))).go();
      expect(await values.next(), isNull);
      expect(
        (await database.select(database.taskLists).getSingle()).davCollectionId,
        isNull,
      );
      await database
          .into(database.davCollections)
          .insert(collection.toCompanion(false));
      expect(
        await values.next(),
        isNull,
      ); // Physical restoration does not invent a missing mapping.
      await (database.update(database.taskLists)..where(
            (row) =>
                row.accountId.equals(list.accountId) & row.id.equals(list.id),
          ))
          .write(TaskListsCompanion(davCollectionId: Value(collection.id)));
      expect((await values.next())!.canCreateTasks, isTrue);
    },
  );

  test(
    'provider observes component, projection, resource-type and member-privilege changes',
    () async {
      final values = probe();
      expect((await values.next())!.canCreateTasks, isTrue);
      for (final changes in [
        const DavCollectionsCompanion(
          supportedComponentMask: Value(davComponentEvent),
        ),
        const DavCollectionsCompanion(taskProjectionEnabled: Value(false)),
        DavCollectionsCompanion(
          resourceTypesJson: Value(
            jsonEncode(['{http://calendarserver.org/ns/}subscribed']),
          ),
        ),
        const DavCollectionsCompanion(
          currentUserPrivilegesJson: Value(
            '["{DAV:}read","{DAV:}write-content"]',
          ),
        ),
      ]) {
        await updateCollection(changes);
        expect((await values.next())!.canCreateTasks, isFalse);
        await database
            .into(database.davCollections)
            .insertOnConflictUpdate(collection.toCompanion(false));
        expect((await values.next())!.canCreateTasks, isTrue);
      }
    },
  );

  test(
    'provider uses current metadata, owner and joined service principal for task capabilities',
    () async {
      final values = probe();
      final initial = (await values.next())!;
      expect(initial.canUpdateClassification, isTrue);
      expect(initial.supportsListDelete, isFalse);
      await updateCollection(
        const DavCollectionsCompanion(
          safeDisplayMetadataJson: Value(
            '{"shared":true,"parentPrivileges":["{DAV:}unbind"]}',
          ),
        ),
      );
      final shared = (await values.next())!;
      expect(shared.canUpdateClassification, isFalse);
      expect(shared.supportsListDelete, isTrue);
      await updateCollection(
        const DavCollectionsCompanion(safeDisplayMetadataJson: Value('{}')),
      );
      expect((await values.next())!.canUpdateClassification, isTrue);
      await updateCollection(
        const DavCollectionsCompanion(
          ownerHref: Value('https://cloud.example.test/principals/other/'),
        ),
      );
      expect((await values.next())!.canUpdateClassification, isFalse);
      await (database.update(
        database.davAccountServices,
      )..where((row) => row.accountId.equals(list.accountId))).write(
        const DavAccountServicesCompanion(
          principalHref: Value('https://cloud.example.test/principals/other/'),
        ),
      );
      expect((await values.next())!.canUpdateClassification, isTrue);
    },
  );
}

class _CapabilityProbe {
  _CapabilityProbe(
    ProviderContainer container,
    String accountId,
    String taskListId,
  ) {
    _values = StreamIterator(_events.stream);
    _subscription = container.listen(
      davTaskCollectionCapabilitiesProvider((
        accountId: accountId,
        taskListId: taskListId,
      )),
      (_, next) {
        if (next is AsyncData<TaskCollectionCapabilities?>) {
          _events.add(next.value);
        }
        if (next.hasError) _events.addError(next.error!, next.stackTrace!);
      },
      fireImmediately: true,
    );
  }
  final _events = StreamController<TaskCollectionCapabilities?>();
  late final StreamIterator<TaskCollectionCapabilities?> _values;
  late final ProviderSubscription<AsyncValue<TaskCollectionCapabilities?>>
  _subscription;

  Future<TaskCollectionCapabilities?> next() async {
    expect(
      await _values.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    return _values.current;
  }

  Future<void> close() async {
    _subscription.close();
    await _values.cancel();
    await _events.close();
  }
}

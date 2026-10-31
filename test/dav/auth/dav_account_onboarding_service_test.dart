import 'dart:io';

import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';

import '../../helpers/nextcloud_tls_fixture.dart';

import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/contacts_fixture.dart';
import '../../support/dav_contacts_fixture.dart' as carddav;

import 'package:busymax/src/contacts/busymax_contacts_controller.dart';

void main() {
  late AppDatabase database;
  late InMemorySecretStore secrets;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
  });

  tearDown(() => database.close());

  test('linked Nextcloud contact retry reuses valid authorization and Reconnect renews the parent before rebinding', () async {
    final persistence = AuthorizationPersistence(
      database: database,
      secrets: secrets,
    );
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      authorizationPersistence: persistence,
      nextcloudLoginFlow: _successfulLoginFlow(
        server: carddav.server.toString(),
        rotatePasswords: true,
      ),
      idFactory: () => 'contacts-parent',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    final id = (await service.connectNextcloud(
      enteredServer: carddav.server.toString(),
    )).accountId;
    var reconnects = 0;
    final fixture = ContactsFixture(
      database,
      realDav: true,
      readAuthorizationGeneration: persistence.generation,
      readLinkedDavCredential: (id) async {
        final secret =
            (await persistence.readCurrentCredential(id))!
                as NextcloudSecretRecord;
        return BusyMaxLinkedDavCredential(
          server: secret.canonicalServer,
          username: secret.loginName,
          password: secret.appPassword,
        );
      },
      reconnectLinkedDavAccount: (id, cancellation) async {
        reconnects++;
        final token = DavCancellationToken();
        if (cancellation.isCancelled) token.cancel();
        unawaited(cancellation.signal.then((_) => token.cancel()));
        await service.reconnectNextcloud(
          accountId: id,
          enteredServer: carddav.server.toString(),
          cancellationToken: token,
        );
        cancellation.committed();
      },
    );
    addTearDown(fixture.controller.close);
    final dav = carddav.DavFixture();
    fixture.respondDav = dav.respond;
    await fixture.controller.enableLinkedNextcloudContacts(id);
    final contactId = BusyMaxContactsController.linkedContactAccountId(id);
    await fixture.controller.synchronizeAccount(contactId);
    final otherServer = carddav.server.replace(host: 'other.example.test');
    await fixture.accounts.upsertSignedInAccount(
      id: 'other',
      provider: BusyProvider.nextcloud,
      authority: otherServer.toString(),
      providerAccountId: 'alex',
      grantedScopes: '',
    );
    final otherCredential = NextcloudSecretRecord(
      canonicalServer: otherServer,
      loginName: 'alex',
      appPassword: 'other-password',
    );
    await secrets.saveCredential('other', otherCredential);
    await fixture.controller.enableLinkedNextcloudContacts('other');
    await fixture.controller.synchronizeAccount('contacts:other');
    await service.reconnectNextcloud(
      accountId: id,
      enteredServer: carddav.server.toString(),
    );
    final replaced =
        await persistence.readCurrentCredential(id) as NextcloudSecretRecord;
    fixture.requests.clear();
    await fixture.controller.synchronizeAccount(contactId);
    expect(fixture.requests, isNotEmpty);
    expect(
      fixture.requests.every(
        (request) =>
            request.headers['authorization'] ==
            'Basic ${base64Encode(utf8.encode('${replaced.loginName}:${replaced.appPassword}'))}',
      ),
      isTrue,
    );
    final targetRequestCount = fixture.requests.length;
    await fixture.controller.synchronizeAccount('contacts:other');
    final otherRequests = fixture.requests.skip(targetRequestCount).toList();
    expect(otherRequests, isNotEmpty);
    expect(
      otherRequests.every(
        (request) =>
            request.url.host == otherServer.host &&
            request.headers['authorization'] ==
                'Basic ${base64Encode(utf8.encode('alex:other-password'))}',
      ),
      isTrue,
    );
    final source = (await fixture.controller.sourceSettings())
        .firstWhere((setting) => setting.source.accountId == contactId)
        .source;
    await fixture.store.setSourceEnabled(source.key, enabled: false);
    final original = (await secrets.readCredential(id))!.toJson();
    await fixture.controller.synchronizeAccount(contactId);
    expect(reconnects, 0);
    expect((await secrets.readCredential(id))!.toJson(), original);
    await fixture.controller.reconnectContactsAccount(contactId);
    await fixture.controller.synchronizeAccount(contactId);
    expect(reconnects, 1);
    expect((await secrets.readCredential(id))!.toJson(), isNot(original));
    expect(await fixture.store.sourceEnabled(source.key), isFalse);
    expect(
      (await database.select(database.accounts).get()).map((a) => a.id),
      unorderedEquals([id, 'other']),
    );
    expect(
      (await secrets.readCredential('other'))!.toJson(),
      otherCredential.toJson(),
    );
    expect(
      (await fixture.store.read((tx) => tx.account(contactId)))!.enabled,
      isTrue,
    );
    expect(
      dav.requests.where(
        (r) => ['PUT', 'DELETE', 'PROPPATCH', 'MKCOL'].contains(r.method),
      ),
      isEmpty,
    );
  });

  test('queued cancelled reconnect releases its caller before the account gate and cannot recreate a removed account', () async {
    final coordinator = AccountSyncCoordinator();
    addTearDown(coordinator.dispose);
    final discovered = Completer<void>();
    var reconnecting = false;
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      syncCoordinator: coordinator,
      nextcloudLoginFlow: _successfulLoginFlow(rotatePasswords: true),
      idFactory: () => 'queued',
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async {
            if (reconnecting && !discovered.isCompleted) discovered.complete();
            return _discovery(accountId, provider, accountAuthority);
          },
    );
    final id = (await service.connectNextcloud(
      enteredServer: 'cloud.example.test',
    )).accountId;
    final entered = Completer<void>(), release = Completer<void>();
    final blocker = coordinator.run(id, () async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    reconnecting = true;
    final token = DavCancellationToken();
    final reconnect = service.reconnectNextcloud(
      accountId: id,
      enteredServer: 'cloud.example.test',
      cancellationToken: token,
    );
    final cancelled = expectLater(
      reconnect,
      throwsA(
        isA<DavException>().having(
          (e) => e.kind,
          'kind',
          DavErrorKind.cancelled,
        ),
      ),
    );
    await discovered.future;
    final removed = service.removeAccount(id);
    await cancelled;
    expect(release.isCompleted, isFalse);
    release.complete();
    await blocker;
    await removed;
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(await secrets.readCredential(id), isNull);
    expect(await database.select(database.authorizationCommits).get(), isEmpty);
    final next = await service.connectNextcloud(
      enteredServer: 'cloud.example.test',
    );
    expect(next.accountId, id);
    expect((await database.select(database.accounts).getSingle()).id, id);
  });

  test('DAV credential journaling does not call native OAuth hooks and Add cannot replace an existing account', () async {
    Never unexpected() =>
        throw StateError('DAV must not mutate native OAuth bindings');
    final persistence = AuthorizationPersistence(
      database: database,
      secrets: secrets,
      readNativeBinding: (_) async => unexpected(),
      restoreNativeBinding: (_, _) async => unexpected(),
      onCredentialWritten: (_, _) async => unexpected(),
      onRemovalCommitted: (_, _) async => unexpected(),
    );
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      authorizationPersistence: persistence,
      nextcloudLoginFlow: _successfulLoginFlow(rotatePasswords: true),
      idFactory: () => 'dav-only',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    final id = (await service.connectNextcloud(
      enteredServer: 'cloud.example.test',
    )).accountId;
    final saved = (await secrets.readCredential(id))!.toJson();
    await expectLater(
      service.connectNextcloud(enteredServer: 'cloud.example.test'),
      throwsA(
        isA<DavException>().having(
          (e) => e.code,
          'code',
          'DavAccountAlreadyConnected',
        ),
      ),
    );
    expect((await secrets.readCredential(id))!.toJson(), saved);
    await service.reconnectNextcloud(
      accountId: id,
      enteredServer: 'cloud.example.test',
    );
    expect((await secrets.readCredential(id))!.toJson(), isNot(saved));
    await service.removeAccount(id);
    expect(await secrets.readCredential(id), isNull);
    expect(await database.select(database.accounts).get(), isEmpty);
  });

  for (final state in ['permission_changed', 'unsupported_server_profile']) {
    test(
      '$state can revalidate without replacing identity, selections or queued work',
      () async {
        var reject = false;
        final service = DavAccountOnboardingService(
          database: database,
          secretStore: secrets,
          nextcloudLoginFlow: _successfulLoginFlow(),
          idFactory: () => 'recover',
          discover:
              ({
                required accountId,
                required provider,
                required accountAuthority,
                required credential,
                cancellationToken,
              }) async {
                if (reject) {
                  throw const DavException(
                    kind: DavErrorKind.authorization,
                    code: 'DavPermissionDenied',
                    safeMessage: 'Permissions still need repair.',
                  );
                }
                return _discovery(
                  accountId,
                  provider,
                  accountAuthority,
                  collections: [_mixedCollection(accountAuthority)],
                );
              },
        );
        final id = (await service.connectNextcloud(
          enteredServer: 'cloud.example.test',
        )).accountId;
        await _insertNextcloudLocalState(database, id);
        final collection = await database
            .select(database.davCollections)
            .getSingle();
        await (database.update(
          database.davCollections,
        )..where((r) => r.id.equals(collection.id))).write(
          const DavCollectionsCompanion(
            eventsSelected: Value(false),
            tasksSelected: Value(true),
          ),
        );
        await (database.update(database.accounts)
              ..where((r) => r.id.equals(id)))
            .write(AccountsCompanion(authState: Value(state)));
        final beforeSecret = (await secrets.readCredential(id))!.toJson();
        final beforePending = await database
            .select(database.pendingOps)
            .getSingle();
        reject = true;
        await expectLater(
          service.revalidateAccount(id),
          throwsA(isA<DavException>()),
        );
        expect(
          (await database.select(database.accounts).getSingle()).authState,
          state,
        );
        expect((await secrets.readCredential(id))!.toJson(), beforeSecret);
        expect(
          await database.select(database.pendingOps).getSingle(),
          beforePending,
        );
        reject = false;
        final result = await service.revalidateAccount(id);
        expect(result.accountId, id);
        final recovered = await database.select(database.accounts).getSingle();
        expect(recovered.authState, 'signed_in');
        expect(recovered.providerAccountId, 'alex');
        final selected = await database
            .select(database.davCollections)
            .getSingle();
        expect(selected.id, collection.id);
        expect(selected.eventsSelected, isFalse);
        expect(selected.tasksSelected, isTrue);
        expect(
          (await database.select(database.taskLists).get()).any(
            (r) => r.id == 'cached-list',
          ),
          isTrue,
        );
        expect(
          await database.select(database.pendingOps).getSingle(),
          beforePending,
        );
        expect((await secrets.readCredential(id))!.toJson(), beforeSecret);
      },
    );
  }

  test('same Nextcloud username on different servers remains isolated during reconnect and removal', () async {
    DavAccountOnboardingService service(String server, String id) =>
        DavAccountOnboardingService(
          database: database,
          secretStore: secrets,
          nextcloudLoginFlow: _successfulLoginFlow(server: server),
          idFactory: () => id,
          discover: ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async => _discovery(accountId, provider, accountAuthority),
        );
    final firstService = service('https://cloud.example.test', 'one');
    final secondService = service('https://other.example.test', 'two');
    final first = await firstService.connectNextcloud(
      enteredServer: 'cloud.example.test',
    );
    final second = await secondService.connectNextcloud(
      enteredServer: 'other.example.test',
    );
    expect(first.accountId, isNot(second.accountId));
    final secondBefore = (await secrets.readCredential(second.accountId))!
        .toJson();
    await firstService.reconnectNextcloud(
      accountId: first.accountId,
      enteredServer: 'cloud.example.test',
    );
    expect(await database.select(database.accounts).get(), hasLength(2));
    await firstService.removeAccount(first.accountId);
    expect(
      (await database.select(database.accounts).getSingle()).id,
      second.accountId,
    );
    expect(
      (await secrets.readCredential(second.accountId))!.toJson(),
      secondBefore,
    );
    expect(await secrets.readActiveAccountId(), isNull);
  });
  for (final failLocal in [false, true]) {
    test(
      'Nextcloud coordinated removal drains contacts and isolates other accounts; local failure=$failLocal',
      () async {
        final gate = _ObservedAuthorizationGate();
        final coordinator = AccountSyncCoordinator();
        addTearDown(coordinator.dispose);
        final persistence = AuthorizationPersistence(
          database: database,
          secrets: secrets,
          gate: gate,
        );
        final fixture = ContactsFixture(
          database,
          realDav: true,
          // The production reader, including the shared authorization lock.
          readLinkedDavCredential: (id) async {
            final credential = await persistence.readCurrentCredential(id);
            return credential is NextcloudSecretRecord
                ? BusyMaxLinkedDavCredential(
                    server: credential.canonicalServer,
                    username: credential.loginName,
                    password: credential.appPassword,
                  )
                : null;
          },
          readAuthorizationGeneration: persistence.generation,
        );
        addTearDown(fixture.controller.close);
        final remote = carddav.DavFixture();
        fixture.respondDav = remote.respond;
        var revoked = 0;
        var restored = false;
        var restoredWithAccountGate = false;
        final restoring = Completer<void>(),
            releaseRestoration = Completer<void>();
        addTearDown(() {
          if (!releaseRestoration.isCompleted) releaseRestoration.complete();
        });
        final service = DavAccountOnboardingService(
          database: database,
          secretStore: secrets,
          authorizationPersistence: persistence,
          accountGate: gate,
          syncCoordinator: coordinator,
          nextcloudLoginFlow: _successfulLoginFlow(
            server: carddav.server.toString(),
            rotatePasswords: true,
          ),
          idFactory: () => 'parent',
          discover: ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async => _discovery(accountId, provider, accountAuthority),
          onAccountRemovalStarting:
              fixture.controller.beginLinkedAccountRemoval,
          onAccountRemoving: fixture.controller.prepareLinkedAccountRemoval,
          persistLinkedAccountRemoval:
              fixture.controller.persistLinkedAccountRemoval,
          onAccountRemovalFailed: (id) async {
            // Fail deterministically instead of hanging the test on recursive
            // entry into the production non-reentrant credential reader.
            if (gate.held.contains('authorization:$id')) {
              throw StateError('Contacts restoration owns authorization lock');
            }
            restoredWithAccountGate = gate.held.contains(id);
            restoring.complete();
            await releaseRestoration.future;
            await fixture.controller.restoreLinkedAccountAfterFailedRemoval(id);
            restored = true;
          },
          onAccountRemoved: fixture.controller.linkedAccountRemovalCommitted,
          onAccountRemovalFinished:
              fixture.controller.finishLinkedAccountRemoval,
          nextcloudCredentialRevoker:
              ({required accountId, required credential}) async {
                revoked++;
              },
        );
        final parent = (await service.connectNextcloud(
          enteredServer: carddav.server.toString(),
        )).accountId;
        await fixture.accounts.upsertSignedInAccount(
          id: 'unrelated',
          provider: BusyProvider.nextcloud,
          authority: 'https://other.example.test',
          providerAccountId: 'alex',
          grantedScopes: '',
        );
        await secrets.saveCredential(
          'unrelated',
          NextcloudSecretRecord(
            canonicalServer: Uri.parse('https://other.example.test'),
            loginName: 'alex',
            appPassword: 'other-synthetic',
          ),
        );
        await fixture.controller.enableLinkedNextcloudContacts(parent);
        final id = 'contacts:$parent';
        await fixture.controller.synchronizeAccount(id);
        await fixture.controller.addCardDavContactsOnly(
          id: 'independent',
          label: 'Independent QA',
          server: carddav.server,
          username: 'independent',
          password: 'synthetic',
        );
        expect(
          await fixture.store.read((tx) => tx.count(accountId: id)),
          greaterThan(0),
        );
        final independentSources = await fixture.store.read(
          (tx) => tx.sources(accountId: 'independent'),
        );
        await fixture.store.setSourceEnabled(
          independentSources.first.key,
          enabled: false,
        );
        if (failLocal) {
          await database.customStatement(
            "CREATE TRIGGER reject_parent_removal BEFORE DELETE ON accounts WHEN OLD.id = '$parent' BEGIN SELECT RAISE(ABORT, 'fixture rollback'); END",
          );
          final removal = service.removeAccount(parent);
          final rejected = expectLater(removal, throwsA(isA<Exception>()));
          await Future.any<void>([
            restoring.future,
            removal.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          ]);
          expect(restoring.isCompleted, isTrue);
          final previous = (await persistence.readCurrentCredential(parent))!
              .toJson();
          final discovered = Completer<void>();
          final replacementService = DavAccountOnboardingService(
            database: database,
            secretStore: secrets,
            authorizationPersistence: persistence,
            syncCoordinator: coordinator,
            nextcloudLoginFlow: _successfulLoginFlow(
              server: carddav.server.toString(),
              appPassword: 'concurrent-password',
            ),
            discover:
                ({
                  required accountId,
                  required provider,
                  required accountAuthority,
                  required credential,
                  cancellationToken,
                }) async {
                  discovered.complete();
                  return _discovery(accountId, provider, accountAuthority);
                },
          );
          final replacing = replacementService.reconnectNextcloud(
            accountId: parent,
            enteredServer: carddav.server.toString(),
          );
          await discovered.future;
          // Recovery can read authorization, while replacement still waits
          // on the production account coordinator until restoration finishes.
          expect(
            (await persistence.readCurrentCredential(parent))!.toJson(),
            previous,
          );
          releaseRestoration.complete();
          await rejected;
          await replacing;
          expect(
            (await persistence.readCurrentCredential(
              parent,
            ) as NextcloudSecretRecord).appPassword,
            'concurrent-password',
          );
          expect(restored, isTrue);
          expect(restoredWithAccountGate, isTrue);
          expect(revoked, 0);
          expect(
            (await fixture.store.read((tx) => tx.account(id)))!.enabled,
            isTrue,
          );
          expect(
            await secrets.readCredential(parent),
            isA<NextcloudSecretRecord>(),
          );
          await fixture.controller.synchronizeAccount(id);
          await database.customStatement('DROP TRIGGER reject_parent_removal');
          final beforeReconnect = (await secrets.readCredential(parent))!
              .toJson();
          await service.reconnectNextcloud(
            accountId: parent,
            enteredServer: carddav.server.toString(),
          );
          expect(
            (await secrets.readCredential(parent))!.toJson(),
            isNot(beforeReconnect),
          );
        }
        final entered = Completer<void>(), release = Completer<void>();
        var block = true;
        fixture.respondDav = (request) async {
          if (block && request.method == 'REPORT') {
            block = false;
            entered.complete();
            await release.future;
          }
          return remote.respond(request);
        };
        final lateSync = fixture.controller.synchronizeAccount(id);
        final observed = lateSync.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        await entered.future;
        final removal = service.removeAccount(parent);
        release.complete();
        await removal;
        await observed;
        expect(await fixture.store.read((tx) => tx.account(id)), isNull);
        expect(await fixture.store.read((tx) => tx.count(accountId: id)), 0);
        expect(await fixture.store.linkedContactAccounts(parent), isEmpty);
        expect(
          (await fixture.store.selection()).accountIds,
          isNot(contains(id)),
        );
        expect(await fixture.accounts.accountById('unrelated'), isNotNull);
        expect(
          await secrets.readCredential('unrelated'),
          isA<NextcloudSecretRecord>(),
        );
        expect(
          await fixture.store.read((tx) => tx.account('independent')),
          isNotNull,
        );
        expect(
          await fixture.store.sourceEnabled(independentSources.first.key),
          isFalse,
        );
        expect(revoked, 1);
      },
    );
  }

  for (final phase in ['discovery', 'save', 'readback', 'commit']) {
    test(
      'cancel during $phase restores the previous credential and leaves no commit',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        final gated = _GatedSecrets(entered, release);
        _CommitGate? commitGate;
        if (phase == 'commit') {
          await database.close();
          commitGate = _CommitGate(entered, release);
          database = AppDatabase(
            NativeDatabase.memory().interceptWith(commitGate),
          );
        }
        final token = DavCancellationToken();
        var block = false;
        final service = DavAccountOnboardingService(
          database: database,
          secretStore: gated,
          nextcloudLoginFlow: _successfulLoginFlow(rotatePasswords: true),
          idFactory: () => 'cancelled',
          discover:
              ({
                required accountId,
                required provider,
                required accountAuthority,
                required credential,
                cancellationToken,
              }) async {
                if (block && phase == 'discovery') {
                  entered.complete();
                  await release.future;
                }
                return _discovery(accountId, provider, accountAuthority);
              },
        );
        final initial = await service.connectNextcloud(
          enteredServer: 'cloud.example.test',
        );
        final previous = await gated.readCredential(initial.accountId);
        block = true;
        gated.phase = phase;
        gated.wrote = false;
        if (commitGate != null) commitGate.enabled = true;
        // The same flow fixture can be reused after the first operation.
        final operation = service.reconnectNextcloud(
          accountId: initial.accountId,
          enteredServer: 'cloud.example.test',
          cancellationToken: token,
        );
        final failure = expectLater(
          operation,
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.cancelled,
            ),
          ),
        );
        await entered.future;
        token.cancel();
        release.complete();
        await failure;
        expect(
          (await gated.readCredential(
            initial.accountId,
          ) as NextcloudSecretRecord).appPassword,
          (previous as NextcloudSecretRecord).appPassword,
        );
        expect(await database.select(database.accounts).get(), hasLength(1));
      },
    );
  }

  test('cancellation after the SQLite commit returns success and preserves the accepted credential', () async {
    await database.close();
    final token = DavCancellationToken();
    final gate = _CommitGate(Completer<void>(), Completer<void>())
      ..afterCommit = token.cancel;
    database = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(),
      idFactory: () => 'committed',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    gate.enabled = true;
    final result = await service.connectNextcloud(
      enteredServer: 'cloud.example.test',
      cancellationToken: token,
    );
    expect(token.isCancelled, isTrue);
    expect(
      (await database.select(database.accounts).getSingle()).id,
      result.accountId,
    );
    expect(
      await secrets.readCredential(result.accountId),
      isA<NextcloudSecretRecord>(),
    );
    expect(await database.select(database.authorizationCommits).get(), isEmpty);
  });

  test('cancelled new credential persistence leaves no account and permits the next attempt', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final gated = _GatedSecrets(entered, release)..phase = 'save';
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: gated,
      nextcloudLoginFlow: _successfulLoginFlow(),
      idFactory: () => 'new',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    final token = DavCancellationToken();
    final operation = service.connectNextcloud(
      enteredServer: 'cloud.example.test',
      cancellationToken: token,
    );
    final cancelled = expectLater(
      operation,
      throwsA(
        isA<DavException>().having(
          (e) => e.kind,
          'kind',
          DavErrorKind.cancelled,
        ),
      ),
    );
    await entered.future;
    token.cancel();
    release.complete();
    await cancelled;
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(await gated.readCredential('nextcloud:new'), isNull);
    expect(await database.select(database.authorizationCommits).get(), isEmpty);
    final connected = await service.connectNextcloud(
      enteredServer: 'cloud.example.test',
    );
    expect(
      (await database.select(database.accounts).getSingle()).id,
      connected.accountId,
    );
  });

  test(
    'Apple discovery completes before trimmed opaque secret is stored',
    () async {
      var discoveryCalled = false;
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _unusedLoginFlow(),
        idFactory: () => 'apple-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async {
              discoveryCalled = true;
              expect(await secrets.readCredential(accountId), isNull);
              expect(provider, BusyProvider.appleICloud);
              expect(accountAuthority, Uri.parse('https://caldav.icloud.com'));
              expect(credential.username, 'Person@Example.test');
              expect(credential.password, 'abcd-efgh-ijkl-mnop');
              return _discovery(accountId, provider, accountAuthority);
            },
      );

      final result = await service.connectAppleICloud(
        email: '  Person@Example.test  ',
        appSpecificPassword: '  abcd-efgh-ijkl-mnop  ',
      );

      expect(discoveryCalled, isTrue);
      expect(result.accountId, 'apple_icloud:apple-id');
      final stored = await secrets.readCredential(result.accountId);
      expect(stored, isA<AppleICloudSecretRecord>());
      final apple = stored! as AppleICloudSecretRecord;
      expect(apple.username, 'Person@Example.test');
      expect(apple.appSpecificPassword, 'abcd-efgh-ijkl-mnop');
      expect(apple.toString(), isNot(contains(apple.appSpecificPassword)));
      final account = await database.select(database.accounts).getSingle();
      expect(account.provider, 'apple_icloud');
      expect(account.providerAccountId, 'person@example.test');
      expect(account.tasksEnabled, isFalse);
      expect(account.authState, 'signed_in');
      expect(
        await database.select(database.davAccountServices).get(),
        hasLength(1),
      );
    },
  );

  test('failed discovery leaves no account or credential', () async {
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _unusedLoginFlow(),
      idFactory: () => 'failed-id',
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async => throw const DavException(
            kind: DavErrorKind.authentication,
            code: 'DavAuthRejected',
            safeMessage: 'Credential rejected.',
          ),
    );

    await expectLater(
      service.connectAppleICloud(
        email: 'person@example.test',
        appSpecificPassword: 'bad-password',
      ),
      throwsA(isA<DavException>()),
    );
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(await secrets.readCredential('apple_icloud:failed-id'), isNull);
  });

  test(
    'Nextcloud stores returned canonical server, login name, and app password',
    () async {
      var requests = 0;
      final flow = NextcloudLoginFlowV2(
        client: MockClient((request) async {
          requests += 1;
          if (requests == 1) {
            return http.Response(
              jsonEncode({
                'poll': {
                  'token': 'temporary-token',
                  'endpoint':
                      'https://entered.example.test/cloud/login/v2/poll',
                },
                'login':
                    'https://entered.example.test/cloud/login/v2/flow/browser',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'server': 'https://entered.example.test/cloud/',
              'loginName': 'canonical-user',
              'appPassword': 'generated-app-password',
            }),
            200,
          );
        }),
        browserLauncher: (_) async => true,
        delay: (_) async {},
      );
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: flow,
        idFactory: () => 'nextcloud-id',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) async {
              expect(provider, BusyProvider.nextcloud);
              expect(
                accountAuthority,
                Uri.parse('https://entered.example.test/cloud'),
              );
              expect(credential.username, 'canonical-user');
              expect(credential.password, 'generated-app-password');
              expect(await secrets.readCredential(accountId), isNull);
              return _discovery(accountId, provider, accountAuthority);
            },
      );

      final result = await service.connectNextcloud(
        enteredServer: 'entered.example.test/cloud',
      );

      final account = await database.select(database.accounts).getSingle();
      expect(account.authority, 'https://entered.example.test/cloud');
      expect(account.providerAccountId, 'canonical-user');
      expect(account.tasksEnabled, isTrue);
      final credential = await secrets.readCredential(
        result.accountId,
      ) as NextcloudSecretRecord;
      expect(
        credential.canonicalServer,
        Uri.parse('https://entered.example.test/cloud'),
      );
      expect(credential.loginName, 'canonical-user');
      expect(credential.appPassword, 'generated-app-password');
      expect(credential.toString(), isNot(contains('generated-app-password')));
    },
  );

  test('Nextcloud reconnect replaces only the verified credential and preserves local state', () async {
    final initialService = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'old-password'),
      idFactory: () => 'nextcloud-id',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    final connected = await initialService.connectNextcloud(
      enteredServer: 'cloud.example.test',
    );
    await _insertNextcloudLocalState(database, connected.accountId);
    await _markPendingAuthenticationBlocked(database);

    var verifiedBeforeReplacement = false;
    final reconnectService = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'new-password'),
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async {
            final stored = await secrets.readCredential(
              accountId,
            ) as NextcloudSecretRecord;
            expect(stored.appPassword, 'old-password');
            expect(credential.password, 'new-password');
            verifiedBeforeReplacement = true;
            return _discovery(accountId, provider, accountAuthority);
          },
    );

    final reconnected = await reconnectService.reconnectNextcloud(
      accountId: connected.accountId,
      enteredServer: 'cloud.example.test',
    );

    expect(verifiedBeforeReplacement, isTrue);
    expect(reconnected.accountId, connected.accountId);
    final stored = await secrets.readCredential(
      connected.accountId,
    ) as NextcloudSecretRecord;
    expect(stored.appPassword, 'new-password');
    expect(await database.select(database.accounts).get(), hasLength(1));
    expect(await database.select(database.taskLists).get(), hasLength(1));
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'pending');
    expect(pending.retryClassification, 'credential_replaced');
    expect(pending.attemptCount, 0);
    expect(pending.nextAttemptAtUtc, isNull);
    expect(pending.lastErrorCode, isNull);
    expect(
      (await database.select(database.accounts).getSingle()).authState,
      'signed_in',
    );
  });

  test('Nextcloud reconnect rejects a different identity without touching local state', () async {
    final initialService = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'old-password'),
      idFactory: () => 'nextcloud-id',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    final connected = await initialService.connectNextcloud(
      enteredServer: 'cloud.example.test',
    );
    await _insertNextcloudLocalState(database, connected.accountId);
    await _markPendingAuthenticationBlocked(database);
    var discoveryCalled = false;
    final reconnectService = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(
        loginName: 'different-user',
        appPassword: 'untrusted-password',
      ),
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async {
            discoveryCalled = true;
            return _discovery(accountId, provider, accountAuthority);
          },
    );

    await expectLater(
      reconnectService.reconnectNextcloud(
        accountId: connected.accountId,
        enteredServer: 'cloud.example.test',
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavNextcloudReconnectIdentityMismatch',
        ),
      ),
    );

    expect(discoveryCalled, isFalse);
    final stored = await secrets.readCredential(
      connected.accountId,
    ) as NextcloudSecretRecord;
    expect(stored.appPassword, 'old-password');
    expect(await database.select(database.accounts).get(), hasLength(1));
    expect(await database.select(database.taskLists).get(), hasLength(1));
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'auth_blocked');
    expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  test('failed Nextcloud reconnect discovery preserves the old credential and local state', () async {
    final initialService = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'old-password'),
      idFactory: () => 'nextcloud-id',
      discover: ({
        required accountId,
        required provider,
        required accountAuthority,
        required credential,
        cancellationToken,
      }) async => _discovery(accountId, provider, accountAuthority),
    );
    final connected = await initialService.connectNextcloud(
      enteredServer: 'cloud.example.test',
    );
    await _insertNextcloudLocalState(database, connected.accountId);
    await _markPendingAuthenticationBlocked(database);
    final reconnectService = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _successfulLoginFlow(appPassword: 'new-password'),
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async => throw const DavException(
            kind: DavErrorKind.authentication,
            code: 'DavAuthRejected',
            safeMessage: 'Credential rejected.',
          ),
    );

    await expectLater(
      reconnectService.reconnectNextcloud(
        accountId: connected.accountId,
        enteredServer: 'cloud.example.test',
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavAuthRejected',
        ),
      ),
    );

    final stored = await secrets.readCredential(
      connected.accountId,
    ) as NextcloudSecretRecord;
    expect(stored.appPassword, 'old-password');
    expect(await database.select(database.accounts).get(), hasLength(1));
    expect(await database.select(database.taskLists).get(), hasLength(1));
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'auth_blocked');
    expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  test('Apple replacement validates before replacing the old secret', () async {
    var discoveryCount = 0;
    late String accountId;
    final service = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      nextcloudLoginFlow: _unusedLoginFlow(),
      idFactory: () => 'apple-id',
      discover:
          ({
            required String accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) async {
            discoveryCount += 1;
            if (discoveryCount == 2) {
              final stillOld = await secrets.readCredential(accountId);
              expect(
                (stillOld! as AppleICloudSecretRecord).appSpecificPassword,
                'old-password',
              );
              expect(credential.password, 'new-password-with-hyphens');
            }
            return _discovery(accountId, provider, accountAuthority);
          },
    );
    accountId = (await service.connectAppleICloud(
      email: 'person@example.test',
      appSpecificPassword: 'old-password',
    )).accountId;
    await database
        .into(database.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            id: 'apple-auth-blocked',
            accountId: accountId,
            provider: const Value('apple_icloud'),
            entityType: 'event',
            operation: 'dav_update',
            operationType: const Value('dav.update'),
            requestJson: '{}',
            state: const Value('auth_blocked'),
            retryClassification: const Value('authentication'),
            attemptCount: const Value(1),
            nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
            lastErrorCode: const Value('DavCredentialsRevoked'),
            createdAtUtc: '2026-08-08T12:00:00.000Z',
            updatedAtUtc: '2026-08-08T12:00:00.000Z',
          ),
        );

    await service.replaceAppleAppSpecificPassword(
      accountId: accountId,
      appSpecificPassword: '  new-password-with-hyphens  ',
    );

    final replacement =
        await secrets.readCredential(accountId) as AppleICloudSecretRecord;
    expect(replacement.appSpecificPassword, 'new-password-with-hyphens');
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'pending');
    expect(pending.nextAttemptAtUtc, isNull);
  });

  test(
    'Apple local removal deletes the credential, cache, and pending work',
    () async {
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _unusedLoginFlow(),
        idFactory: () => 'apple-remove-id',
        discover: ({
          required accountId,
          required provider,
          required accountAuthority,
          required credential,
          cancellationToken,
        }) async => _discovery(accountId, provider, accountAuthority),
      );
      final connected = await service.connectAppleICloud(
        email: 'person@example.test',
        appSpecificPassword: 'app-specific-password',
      );
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'apple-pending-removal',
              accountId: connected.accountId,
              provider: const Value('apple_icloud'),
              entityType: 'event',
              operation: 'dav_create',
              operationType: const Value('dav.create'),
              requestJson: '{}',
              createdAtUtc: '2026-08-08T12:00:00.000Z',
              updatedAtUtc: '2026-08-08T12:00:00.000Z',
            ),
          );

      final result = await service.removeAccount(connected.accountId);

      expect(result.remoteRevocationAttempted, isFalse);
      expect(await secrets.readCredential(connected.accountId), isNull);
      expect(await secrets.readActiveAccountId(), isNull);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await database.select(database.davAccountServices).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'remote revocation failure never prevents complete local removal',
    () async {
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _successfulLoginFlow(),
        idFactory: () => 'nextcloud-id',
        discover: ({
          required accountId,
          required provider,
          required accountAuthority,
          required credential,
          cancellationToken,
        }) async => _discovery(accountId, provider, accountAuthority),
        nextcloudCredentialRevoker:
            ({required accountId, required credential}) async {
              throw const DavException(
                kind: DavErrorKind.network,
                code: 'RevocationOffline',
                safeMessage: 'Offline.',
              );
            },
      );
      final connected = await service.connectNextcloud(
        enteredServer: 'cloud.example.test',
      );
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'pending',
              accountId: connected.accountId,
              provider: const Value('nextcloud'),
              entityType: 'event',
              operation: 'dav_create',
              operationType: const Value('dav.create'),
              requestJson: '{}',
              createdAtUtc: '2026-08-08T12:00:00.000Z',
              updatedAtUtc: '2026-08-08T12:00:00.000Z',
            ),
          );

      final result = await service.removeAccount(connected.accountId);

      expect(result.remoteRevocationAttempted, isTrue);
      expect(result.remoteRevocationSucceeded, isFalse);
      expect(result.remoteFailureCode, 'RevocationOffline');
      expect(await secrets.readCredential(connected.accountId), isNull);
      expect(await secrets.readActiveAccountId(), isNull);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await database.select(database.davAccountServices).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );
  group('private certificate authorization lifecycle', () {
    late NextcloudTlsFixture tls;
    final server = Uri.parse('https://localhost/nextcloud');
    setUpAll(() async {
      tls = await NextcloudTlsFixture.create();
    });
    tearDownAll(() => tls.dispose());
    NextcloudTrustPolicy pin(String id, String name) =>
        NextcloudTrustPolicy.approve(
          owner: id,
          installation: server,
          mode: NextcloudTrustMode.pinnedLeaf,
          certificates: NextcloudCertificate.import(
            File(tls.path('$name.pem')).readAsBytesSync(),
          ),
          generation: name,
        );

    for (final failure in ['discovery', 'database', 'secure-storage']) {
      test(
        '$failure preserves the previous policy, generation and cached data',
        () async {
          final store = _TrustFaultSecrets();
          final persistence = AuthorizationPersistence(
            database: database,
            secrets: store,
          );
          var rejectDiscovery = false;
          final service = DavAccountOnboardingService(
            database: database,
            secretStore: store,
            authorizationPersistence: persistence,
            nextcloudLoginFlow: _successfulLoginFlow(server: server.toString()),
            discover:
                ({
                  required accountId,
                  required provider,
                  required accountAuthority,
                  required credential,
                  cancellationToken,
                }) async {
                  if (rejectDiscovery) {
                    throw const DavException(
                      kind: DavErrorKind.protocol,
                      code: 'SyntheticDiscoveryFailure',
                      safeMessage: 'Synthetic discovery failure',
                    );
                  }
                  return _discovery(accountId, provider, accountAuthority);
                },
          );
          final id = (await service.connectNextcloud(
            enteredServer: server.toString(),
          )).accountId;
          await service.replaceNextcloudTrust(
            accountId: id,
            expectedGeneration: await persistence.generation(id),
            policy: pin(id, 'self'),
          );
          await _insertNextcloudLocalState(database, id);
          final previous = await store.readCredential(id);
          final generation = await persistence.generation(id);
          if (failure == 'discovery') {
            rejectDiscovery = true;
          }
          if (failure == 'secure-storage') {
            store.failId = id;
          }
          if (failure == 'database') {
            await database.customStatement(
              "CREATE TEMP TRIGGER reject_trust BEFORE UPDATE ON accounts BEGIN SELECT RAISE(ABORT, 'synthetic commit failure'); END",
            );
          }
          await expectLater(
            service.replaceNextcloudTrust(
              accountId: id,
              expectedGeneration: generation,
              policy: pin(id, 'self-renewed'),
            ),
            throwsA(anything),
          );
          expect(
            (await store.readCredential(id))!.toJson(),
            previous!.toJson(),
          );
          expect(await persistence.generation(id), generation);
          expect(await database.select(database.taskLists).get(), hasLength(1));
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(1),
          );
          await persistence.recover();
          expect((await store.readCredential(id))!.toJson(), previous.toJson());
        },
      );
    }
    test('accepted replacement increments generation; stale approvals after reconnect/removal have no effect', () async {
      final persistence = AuthorizationPersistence(
        database: database,
        secrets: secrets,
      );
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        authorizationPersistence: persistence,
        nextcloudLoginFlow: _successfulLoginFlow(
          server: server.toString(),
          rotatePasswords: true,
        ),
        discover: ({
          required accountId,
          required provider,
          required accountAuthority,
          required credential,
          cancellationToken,
        }) async => _discovery(accountId, provider, accountAuthority),
      );
      final id = (await service.connectNextcloud(
        enteredServer: server.toString(),
      )).accountId;
      final generation = await persistence.generation(id);
      await service.replaceNextcloudTrust(
        accountId: id,
        expectedGeneration: generation,
        policy: pin(id, 'self'),
      );
      expect(await persistence.generation(id), generation + 1);
      await service.reconnectNextcloud(
        accountId: id,
        enteredServer: server.toString(),
      );
      await expectLater(
        service.replaceNextcloudTrust(
          accountId: id,
          expectedGeneration: generation + 1,
          policy: pin(id, 'self-renewed'),
        ),
        throwsA(isA<DavException>()),
      );
      final accepted =
          await secrets.readCredential(id) as NextcloudSecretRecord;
      expect(accepted.trustPolicy!.generation, 'self');
      await service.removeAccount(id);
      await expectLater(
        service.replaceNextcloudTrust(
          accountId: id,
          expectedGeneration: await persistence.generation(id),
          policy: pin(id, 'self-renewed'),
        ),
        throwsA(isA<DavException>()),
      );
      expect(await secrets.readCredential(id), isNull);
    });
    test('removal captures private trust before deletion and preserves local-first semantics', () async {
      final persistence = AuthorizationPersistence(
        database: database,
        secrets: secrets,
      );
      var checked = false;
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        authorizationPersistence: persistence,
        nextcloudLoginFlow: _successfulLoginFlow(server: server.toString()),
        discover: ({
          required accountId,
          required provider,
          required accountAuthority,
          required credential,
          cancellationToken,
        }) async => _discovery(accountId, provider, accountAuthority),
        nextcloudCredentialRevoker:
            ({required accountId, required credential}) async {
              expect(await secrets.readCredential(accountId), isNull);
              expect(credential.trustPolicy!.generation, 'self');
              credential.trustPolicy!.requireScope(accountId, server);
              checked = true;
              throw const DavException(
                kind: DavErrorKind.tls,
                code: 'SyntheticPinMismatch',
                safeMessage: 'Synthetic TLS failure',
              );
            },
      );
      final id = (await service.connectNextcloud(
        enteredServer: server.toString(),
      )).accountId;
      await service.replaceNextcloudTrust(
        accountId: id,
        expectedGeneration: await persistence.generation(id),
        policy: pin(id, 'self'),
      );
      final result = await service.removeAccount(id);
      expect(checked, isTrue);
      expect(result.remoteRevocationSucceeded, isFalse);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await secrets.readCredential(id), isNull);
    });
  });
}

NextcloudLoginFlowV2 _unusedLoginFlow() => NextcloudLoginFlowV2(
  client: MockClient((_) async => http.Response('', 500)),
  browserLauncher: (_) async => false,
);

NextcloudLoginFlowV2 _successfulLoginFlow({
  String server = 'https://cloud.example.test/',
  String loginName = 'alex',
  String appPassword = 'app-password',
  bool rotatePasswords = false,
}) {
  var call = 0;
  return NextcloudLoginFlowV2(
    client: MockClient((request) async {
      call += 1;
      return call.isOdd
          ? http.Response(
              jsonEncode({
                'poll': {
                  'token': 'token',
                  'endpoint': request.url
                      .resolve('../../login/v2/poll')
                      .toString(),
                },
                'login': request.url
                    .resolve('../../login/v2/flow/browser')
                    .toString(),
              }),
              200,
            )
          : http.Response(
              jsonEncode({
                'server': server,
                'loginName': loginName,
                'appPassword': rotatePasswords
                    ? '$appPassword-$call'
                    : appPassword,
              }),
              200,
            );
    }),
    browserLauncher: (_) async => true,
    delay: (_) async {},
  );
}

/// Observes production gate calls without changing their behavior. The shared
/// AccountSyncCoordinator and AuthorizationPersistence retain serialization.
final class _ObservedAuthorizationGate implements CrossEngineAccountGate {
  final _gate = const InProcessAccountGate();
  final held = <String>{};

  @override
  Future<T> run<T>(String id, Future<T> Function() work) =>
      _gate.run(id, () async {
        held.add(id);
        try {
          return await work();
        } finally {
          held.remove(id);
        }
      });
}

class _GatedSecrets extends InMemorySecretStore {
  _GatedSecrets(this.entered, this.release);
  final Completer<void> entered, release;
  String? phase;
  bool wrote = false;
  @override
  Future<void> saveCredential(String id, SecretRecord record) async {
    await super.saveCredential(id, record);
    wrote = true;
    if (phase == 'save' && id.startsWith('nextcloud:')) {
      phase = null;
      entered.complete();
      await release.future;
    }
  }

  @override
  Future<SecretRecord?> readCredential(String id) async {
    final value = await super.readCredential(id);
    if (phase == 'readback' && wrote && id.startsWith('nextcloud:')) {
      phase = null;
      entered.complete();
      await release.future;
    }
    return value;
  }
}

Future<void> _insertNextcloudLocalState(
  AppDatabase database,
  String accountId,
) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: accountId,
          id: 'cached-list',
          title: 'Cached list',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
  await database
      .into(database.pendingOps)
      .insert(
        PendingOpsCompanion.insert(
          id: 'pending-reconnect',
          accountId: accountId,
          provider: const Value('nextcloud'),
          entityType: 'task',
          operation: 'dav_update',
          operationType: const Value('dav.update'),
          requestJson: '{}',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}

Future<void> _markPendingAuthenticationBlocked(AppDatabase database) async {
  await database
      .update(database.pendingOps)
      .write(
        const PendingOpsCompanion(
          state: Value('auth_blocked'),
          retryClassification: Value('authentication'),
          attemptCount: Value(1),
          nextAttemptAtUtc: Value('9999-12-31T23:59:59.999Z'),
          lastErrorCode: Value('DavCredentialsRevoked'),
          lastErrorMessage: Value('The DAV credential was rejected.'),
        ),
      );
}

DavDiscoveryResult _discovery(
  String accountId,
  BusyProvider provider,
  Uri authority, {
  List<DavCollectionDiscovery> collections = const [],
}) => DavDiscoveryResult(
  accountId: accountId,
  provider: provider,
  service: DavServiceDiscovery(
    canonicalServiceUri: authority,
    canonicalOrigin: authority.replace(path: ''),
    principalHref: authority.resolve('/principals/user/'),
    calendarHomeHref: authority.resolve('/calendars/user/'),
    calendarUserAddresses: const [],
    scheduleInboxHref: null,
    scheduleOutboxHref: null,
    capabilities: const AccountServiceCapabilities(
      hasPrincipal: true,
      hasCalendarHome: true,
    ),
    discoveredAtUtc: DateTime.utc(2026, 8, 8, 12),
    lastValidatedAtUtc: DateTime.utc(2026, 8, 8, 12),
    providerProfileVersion: 1,
  ),
  collections: collections,
);

DavCollectionDiscovery _mixedCollection(Uri authority) =>
    DavCollectionDiscovery(
      hrefKey: '/calendars/user/mixed/',
      requestUri: authority.resolve('/calendars/user/mixed/'),
      displayName: 'Mixed QA',
      description: null,
      resourceTypes: const {
        '{DAV:}collection',
        '{urn:ietf:params:xml:ns:caldav}calendar',
      },
      supportedComponentMask: 3,
      supportedCalendarData: const [],
      supportedReports: const {},
      currentUserPrivileges: const {
        '{DAV:}read',
        '{DAV:}write',
        '{DAV:}write-properties',
      },
      ownerHref: null,
      safeDisplayMetadata: const {},
      color: null,
      sortOrder: null,
      calendarTimeZone: null,
      calendarTimeZoneId: null,
      scheduleTransparency: null,
      maximumResourceSize: null,
      maximumInstances: null,
      syncToken: null,
      ctag: null,
      capabilities: const CollectionCapabilities(
        canRead: true,
        canWriteContent: true,
        canWriteProperties: true,
        canAddMembers: true,
        canDeleteMembers: true,
        supportsEvents: true,
        supportsTasks: true,
      ),
      kind: DavCollectionKind.mixedCalendar,
      eventProjectionEnabled: true,
      taskProjectionEnabled: true,
    );

class _CommitGate extends QueryInterceptor {
  _CommitGate(this.entered, this.release);
  final Completer<void> entered, release;
  bool enabled = false;
  void Function()? afterCommit;
  QueryExecutor? accountTransaction;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await super.runInsert(executor, statement, args);
    if (enabled && statement.startsWith('INSERT INTO "accounts"')) {
      accountTransaction ??= executor;
    }
    if (enabled &&
        afterCommit == null &&
        statement.startsWith('INSERT INTO "accounts"')) {
      enabled = false;
      entered.complete();
      await release.future;
    }
    return result;
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await super.runUpdate(executor, statement, args);
    if (enabled && statement.startsWith('UPDATE "accounts"')) {
      accountTransaction ??= executor;
    }
    if (enabled &&
        afterCommit == null &&
        statement.startsWith('UPDATE "accounts"')) {
      enabled = false;
      entered.complete();
      await release.future;
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await super.commitTransaction(inner);
    if (enabled &&
        afterCommit != null &&
        identical(accountTransaction, inner)) {
      enabled = false;
      afterCommit!();
    }
  }
}

class _TrustFaultSecrets extends InMemorySecretStore {
  String? failId;
  @override
  Future<void> saveCredential(String accountId, SecretRecord credential) async {
    if (accountId == failId) {
      failId = null;
      throw const SecretStoreException(
        'SyntheticWriteFailure',
        'Synthetic secure storage failure.',
      );
    }
    await super.saveCredential(accountId, credential);
  }
}

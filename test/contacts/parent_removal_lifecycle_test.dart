import '../support/persistence_test_directory.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show QueryInterceptor, QueryExecutor, TransactionExecutor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:busymax/src/db/app_database.dart';

import 'package:busystack_contacts/google.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busymax/src/contacts/busymax_contacts_store.dart';
import 'package:busymax/src/core/auth/account_token_broker.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/microsoft_graph_scopes.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../core/auth/authorization_transition_test.dart'
    show Harness, FailureStore, tenant, fixtureIdToken;

/// Pauses actual serialization, without replacing persistence or its queue.
class RemovalGate implements CrossEngineAccountGate {
  bool capture = false;
  final readFinished = Completer<void>(), releaseRead = Completer<void>();
  final removalEntered = Completer<void>(), releaseRemoval = Completer<void>();
  int calls = 0;
  @override
  Future<T> run<T>(String id, Future<T> Function() operation) async {
    if (!capture) return operation();
    final call = ++calls;
    if (call == 1) {
      final result = await operation();
      readFinished.complete();
      await releaseRead.future;
      return result;
    }
    if (call == 2) {
      removalEntered.complete();
      await releaseRemoval.future;
    }
    return operation();
  }
}

/// Faults only the real preparation SQL/COMMIT, never parent deletion or secrets.
class PreparationFault extends QueryInterceptor {
  String? contactId;
  String? phase;
  bool persistent = false;
  final failure = StateError('original-preparation-failure');
  final recoveryFailure = StateError('unresolved-detach-journal');
  QueryExecutor? disableTransaction;
  int hits = 0;

  void fail() {
    hits++;
    if (!persistent) phase = null;
    throw hits == 1 ? failure : recoveryFailure;
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final data = args
        .whereType<String>()
        .where((s) => s.startsWith('{'))
        .map((s) => jsonDecode(s) as Map)
        .firstOrNull;
    if (data != null &&
        data['id'] == contactId &&
        data['enabled'] == false &&
        statement.startsWith('INSERT INTO bm_contact_accounts')) {
      if (phase == 'disable-write') {
        fail();
      }
      if (phase == 'disable-commit') disableTransaction = executor;
    }
    if (phase == 'detach-journal' &&
        data?['account'] == contactId &&
        data?['state'] == 'unknown' &&
        statement.startsWith('INSERT INTO bm_contact_mutations')) {
      fail();
    }
    await super.runCustom(executor, statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (identical(inner, disableTransaction)) {
      disableTransaction = null;
      fail();
    }
    await super.commitTransaction(inner);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (phase == 'account-read' &&
        statement == 'SELECT data FROM bm_contact_accounts WHERE id = ?' &&
        args.singleOrNull == contactId) {
      fail();
    }
    return super.runSelect(executor, statement, args);
  }
}

class LifecycleFixture {
  LifecycleFixture(
    this.provider, {
    RemovalGate? gate,
    AppDatabase? database,
    FailureStore? secrets,
  }) : h = Harness(gate: gate, database: database, secretStore: secrets) {
    store = BusyMaxContactsStore(h.db);
    controller = BusyMaxContactsController(
      store: store,
      accounts: h.accounts,
      authorization: DesktopAccountTokenBroker(
        google: h.google,
        microsoft: h.microsoft,
      ),
      readAuthorizationGeneration: h.persistence.generation,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            provider == BusyProvider.google
                ? {
                    'connections': [],
                    'contactGroups': [],
                    'nextSyncToken': 'complete',
                  }
                : {'value': []},
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      readDavSecret: (_) async => null,
      writeDavSecret: (_, value) async {},
      deleteDavSecret: (_) async {},
      readLinkedDavCredential: (_) async => null,
      launchBrowser: (_) async => true,
    );
    repository = AuthRepository(
      oAuth: h.google,
      microsoftOAuth: h.microsoft,
      database: h.db,
      authorizationPersistence: h.persistence,
      onAccountRemovalStarting: controller.beginLinkedAccountRemoval,
      onAccountRemoving: (id) async {
        await controller.prepareLinkedAccountRemoval(id);
        await afterPrepare?.call();
      },
      persistLinkedAccountRemoval: controller.persistLinkedAccountRemoval,
      onAccountRemovalFailed: (id) async {
        await beforeRecovery?.call();
        await controller.restoreLinkedAccountAfterFailedRemoval(id);
      },
      onAccountRemoved: controller.linkedAccountRemovalCommitted,
      onAccountRemovalFinished: controller.finishLinkedAccountRemoval,
    );
    h.beforeRequest = (request) async {
      if (request.method != 'POST' ||
          !request.body.contains('authorization_code')) {
        return null;
      }
      return http.Response(
        jsonEncode({
          'access_token': 'candidate',
          'refresh_token': 'candidate-refresh',
          'expires_in': 3600,
          'scope': h.flow.lastScope,
          if (provider == BusyProvider.microsoft)
            'id_token': fixtureIdToken(
              Uri.splitQueryString(request.body)['client_id']!,
            ),
        }),
        200,
      );
    };
  }
  final BusyProvider provider;
  final Harness h;
  late final BusyMaxContactsStore store;
  late final BusyMaxContactsController controller;
  late final AuthRepository repository;
  final requests = <http.Request>[];
  Future<void> Function()? afterPrepare, beforeRecovery;
  String get id =>
      provider == BusyProvider.google ? 'opaque' : 'microsoft:ms-user';
  String get contactId => 'contacts:$id';
  Future<void> seed({bool granted = true, bool? enabled}) async {
    if (provider == BusyProvider.google) {
      await h.seed();
    } else {
      await h.seedMicrosoft(shared: false);
    }
    final credential =
        await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
    final scope = provider == BusyProvider.google
        ? googleContactsReadScope
        : 'Contacts.Read';
    if (granted) {
      await h.secrets.saveCredential(
        id,
        credential.withTokens(
          credential.tokenSet.copyWith(
            scopes: {...credential.tokenSet.scopes, scope},
          ),
        ),
      );
      await h.accounts.upsertSignedInAccount(
        id: id,
        provider: provider,
        providerAccountId: credential.subject,
        tenantId: provider == BusyProvider.microsoft ? tenant : null,
        grantedScopes: {...credential.tokenSet.scopes, scope}.join(' '),
      );
    }
    if (granted) {
      await controller.authorization.contactsAuthorizationHeader(provider, id);
    }
    await controller.start();
    if (enabled != null) {
      await controller.enableLinkedContacts(id);
      await controller.synchronizeAccount(contactId);
      if (!enabled) await controller.disableContactsAccount(contactId);
    }
  }

  Future<void> close() async {
    await controller.close().timeout(const Duration(seconds: 3));
    h.staging.dispose();
    await h.db.close();
  }

  Future<void> seedUncertainMutations({bool queued = false}) async {
    final source = (await store.read((tx) => tx.sources(accountId: contactId)))
        .first;
    await store.write((tx) async {
      for (final state in [
        ContactMutationState.executing,
        ContactMutationState.unknown,
        if (queued) ContactMutationState.queued,
      ]) {
        await tx.putMutation(
          ContactMutation(
            id: state.name,
            accountId: contactId,
            sourceKey: source.key,
            kind: ContactMutationKind.update,
            state: state,
            createdAt: DateTime.utc(2026, 10, 11),
            payload: const {'fixture': 'unresolved-work'},
          ),
        );
      }
    });
  }
}

void main() {
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final revoked in [false, true]) {
      test(
        '$provider contacts retain the authorization classification; revoked=$revoked',
        () async {
          final f = LifecycleFixture(provider);
          addTearDown(f.close);
          await f.seed(enabled: true);
          final saved =
              await f.h.secrets.readCredential(f.id) as BoundOAuthSecretRecord;
          await f.h.secrets.saveCredential(
            f.id,
            saved.withTokens(
              saved.tokenSet.copyWith(expiresAtUtc: DateTime.utc(2000)),
            ),
          );
          f.h.beforeRequest = (_) async {
            if (revoked) return http.Response('{"error":"invalid_grant"}', 400);
            throw http.ClientException('synthetic offline');
          };
          final classification = revoked ? 'expiredGrant' : 'network';
          await expectLater(
            f.controller.synchronizeAccount(f.contactId),
            throwsA(
              isA<ContactsException>().having(
                (e) => e.code,
                'safe classification',
                'oauth:$classification',
              ),
            ),
          );
          expect(
            (await f.store.read((tx) => tx.account(f.contactId)))!.errorCode,
            'oauth:$classification',
          );
          expect(
            (await f.h.secrets.readCredential(
              f.id,
            ) as BoundOAuthSecretRecord).subject,
            saved.subject,
          );
        },
      );
    }
  }

  test(
    'revoked Google authorization never restores contacts after local rollback',
    () async {
      final f = LifecycleFixture(BusyProvider.google);
      addTearDown(f.close);
      await f.seed(enabled: true);
      await f.h.db.customStatement(
        "CREATE TRIGGER reject_removal BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT, 'failure after remote revocation'); END",
      );
      final requests = f.requests.length;
      await expectLater(
        f.repository.removeAccount(accountId: f.id, revokeAuthorization: true),
        throwsA(isA<AccountRemovalPersistenceException>()),
      );
      expect(
        (await f.store.read((tx) => tx.account(f.contactId)))!.enabled,
        isFalse,
      );
      expect(f.requests.length, requests);
      await expectLater(
        f.controller.directory.discover(f.contactId),
        throwsA(isA<ContactsException>()),
      );
    },
  );
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      '$provider broad credentials and queued writes remain read-only after actual removal rollback',
      () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(enabled: true);
        final credential =
            await f.h.secrets.readCredential(f.id) as BoundOAuthSecretRecord;
        final grant = provider == BusyProvider.google
            ? googleContactsWriteScope
            : 'Contacts.ReadWrite';
        final scopes = {...credential.tokenSet.scopes, grant};
        await f.h.secrets.saveCredential(
          f.id,
          credential.withTokens(credential.tokenSet.copyWith(scopes: scopes)),
        );
        await f.h.accounts.upsertSignedInAccount(
          id: f.id,
          provider: provider,
          providerAccountId: credential.subject,
          tenantId: provider == BusyProvider.microsoft ? tenant : null,
          grantedScopes: scopes.join(' '),
        );
        await f.controller.enableLinkedContacts(f.id);
        await f.controller.synchronizeAccount(f.contactId);
        await f.seedUncertainMutations(queued: true);
        await f.h.db.customStatement(
          "CREATE TRIGGER reject_removal BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT, 'rollback'); END",
        );
        await expectLater(
          f.repository.removeAccount(accountId: f.id),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'reason',
              contains('rollback'),
            ),
          ),
        );
        await f.controller.synchronizeAccount(f.contactId);
        final account = (await f.store.read((tx) => tx.account(f.contactId)))!;
        expect(account.enabled, isTrue);
        expect(account.grantedScopes, contains(grant));
        for (final source in await f.store.read(
          (tx) => tx.sources(accountId: f.contactId),
        )) {
          expect(source.capabilities.create, isFalse);
          expect(source.capabilities.update, isFalse);
          expect(source.capabilities.delete, isFalse);
          expect(source.capabilities.photoWrite, isFalse);
          expect(source.canRename, isFalse);
          expect(source.canRemove, isFalse);
        }
        final journal = await f.store.read(
          (tx) => tx.mutations(accountId: f.contactId),
        );
        expect(
          journal.singleWhere((m) => m.id == 'queued').state,
          ContactMutationState.queued,
        );
        expect(
          journal.singleWhere((m) => m.id == 'executing').state,
          ContactMutationState.unknown,
        );
        expect(
          journal.singleWhere((m) => m.id == 'unknown').state,
          ContactMutationState.unknown,
        );
        expect(f.requests.every((request) => request.method == 'GET'), isTrue);
      },
    );
    for (final phase in ['disable-commit', 'detach-journal']) {
      test(
        '$provider preparation $phase failure repairs partial detachment',
        () async {
          final fault = PreparationFault();
          final f = LifecycleFixture(
            provider,
            database: AppDatabase(NativeDatabase.memory().interceptWith(fault)),
          );
          addTearDown(f.close);
          await f.seed(enabled: true);
          if (phase == 'detach-journal') await f.seedUncertainMutations();
          final before = (await f.store.read((tx) => tx.account(f.contactId)))!
              .toJson();
          final credential = (await f.h.secrets.readCredential(f.id))!.toJson();
          final requests = f.requests.length;
          fault
            ..contactId = f.contactId
            ..phase = phase;
          await expectLater(
            f.repository.removeAccount(accountId: f.id),
            throwsA(same(fault.failure)),
          );
          expect(fault.hits, 1);
          expect(
            (await f.store.read((tx) => tx.account(f.contactId)))!.toJson(),
            before,
          );
          expect(
            (await f.h.secrets.readCredential(f.id))!.toJson(),
            credential,
          );
          expect(await f.h.accounts.accountById(f.id), isNotNull);
          await f.controller.synchronizeAccount(f.contactId);
          expect(f.requests.length, greaterThan(requests));
          expect(f.h.flow.clients, isEmpty);
          if (phase == 'detach-journal') {
            final mutations = await f.store.read(
              (tx) => tx.mutations(accountId: f.contactId),
            );
            expect(mutations, hasLength(2));
            expect(
              mutations.map((m) => m.state),
              everyElement(ContactMutationState.unknown),
            );
            expect(
              mutations.singleWhere((m) => m.id == 'executing').errorCode,
              'disconnected-after-dispatch',
            );
            expect(f.requests.every((r) => r.method == 'GET'), isTrue);
          }
        },
      );
    }
    test(
      '$provider preparation unresolved detach journal retains work and original error',
      () async {
        final fault = PreparationFault();
        final f = LifecycleFixture(
          provider,
          database: AppDatabase(NativeDatabase.memory().interceptWith(fault)),
        );
        addTearDown(f.close);
        await f.seed(enabled: true);
        await f.seedUncertainMutations(queued: true);
        final requests = f.requests.length;
        fault
          ..contactId = f.contactId
          ..phase = 'detach-journal'
          ..persistent = true;
        await expectLater(
          f.repository.removeAccount(accountId: f.id),
          throwsA(same(fault.failure)),
        );
        expect(fault.hits, 2);
        expect(
          (await f.store.read((tx) => tx.account(f.contactId)))!.errorCode,
          'contacts-removal-recovery-required',
        );
        await expectLater(
          f.controller.synchronizeAccount(f.contactId),
          throwsA(
            isA<ContactsException>().having(
              (e) => e.code,
              'actionable recovery',
              'contacts-removal-recovery-required',
            ),
          ),
        );
        expect(f.requests.length, requests);
        final mutations = await f.store.read(
          (tx) => tx.mutations(accountId: f.contactId),
        );
        expect(
          {for (final m in mutations) m.id: m.state},
          {
            'executing': ContactMutationState.executing,
            'unknown': ContactMutationState.unknown,
            'queued': ContactMutationState.queued,
          },
        );
        expect(await f.h.accounts.accountById(f.id), isNotNull);
        expect(await f.h.secrets.readCredential(f.id), isNotNull);
        fault.phase = null;
        await f.controller.close().timeout(const Duration(seconds: 3));
        final restartedStore = BusyMaxContactsStore(f.h.db);
        expect(
          (await restartedStore.read((tx) => tx.account(f.contactId)))!
              .errorCode,
          'contacts-removal-recovery-required',
        );
        expect(
          await restartedStore.read(
            (tx) => tx.mutations(accountId: f.contactId),
          ),
          hasLength(3),
        );
        await restartedStore.close();
      },
    );
    for (final enabled in [false, null]) {
      test(
        '$provider preparation read failure leaves disabled/absent contacts enabled=$enabled',
        () async {
          final fault = PreparationFault();
          final f = LifecycleFixture(
            provider,
            database: AppDatabase(NativeDatabase.memory().interceptWith(fault)),
          );
          addTearDown(f.close);
          await f.seed(enabled: enabled);
          final before = await f.store.read((tx) => tx.account(f.contactId));
          final credential = (await f.h.secrets.readCredential(f.id))!.toJson();
          final requests = f.requests.length;
          fault
            ..contactId = f.contactId
            ..phase = 'account-read';
          await expectLater(
            f.repository.removeAccount(accountId: f.id),
            throwsA(same(fault.failure)),
          );
          expect(
            (await f.store.read((tx) => tx.account(f.contactId)))?.toJson(),
            before?.toJson(),
          );
          expect(
            (await f.h.secrets.readCredential(f.id))!.toJson(),
            credential,
          );
          expect(f.requests.length, requests);
          expect(f.h.flow.clients, isEmpty);
          expect(await f.h.accounts.accountById(f.id), isNotNull);
        },
      );
    }
    for (final newer in ['disable', 'remove', 'replacement']) {
      test('$provider preparation recovery respects newer $newer', () async {
        final fault = PreparationFault();
        final f = LifecycleFixture(
          provider,
          database: AppDatabase(NativeDatabase.memory().interceptWith(fault)),
        );
        addTearDown(f.close);
        await f.seed(enabled: true);
        final waiting = Completer<void>(), resume = Completer<void>();
        f.beforeRecovery = () async {
          waiting.complete();
          await resume.future;
        };
        fault
          ..contactId = f.contactId
          ..phase = 'disable-write';
        final removed = f.repository.removeAccount(accountId: f.id);
        final observed = expectLater(removed, throwsA(same(fault.failure)));
        await waiting.future;
        final requests = f.requests.length;
        if (newer == 'disable') {
          await f.controller.disableContactsAccount(f.contactId);
        } else if (newer == 'remove') {
          await f.controller.removeContactsAccount(f.contactId);
        } else {
          await f.store.write((tx) async {
            final current = (await tx.account(f.contactId))!;
            await tx.putAccount(
              ContactAccount(
                id: current.id,
                provider: current.provider,
                displayName: 'replacement',
                subject: 'new-subject',
                grantedScopes: current.grantedScopes,
                enabled: false,
                generation: current.generation + 1,
                errorCode: 'newer-state',
              ),
            );
          });
        }
        final newerState = (await f.store.read((tx) => tx.account(f.contactId)))
            ?.toJson();
        resume.complete();
        await observed;
        expect(
          (await f.store.read((tx) => tx.account(f.contactId)))?.toJson(),
          newerState,
        );
        expect(f.requests.length, requests);
        expect(await f.h.accounts.accountById(f.id), isNotNull);
      });
    }
    for (final phase in ['before-write', 'after-write']) {
      test('$provider preparation disable failure $phase restores running binding', () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(enabled: true);
        final parent = (await (f.h.db.select(
          f.h.db.accounts,
        )..where((row) => row.id.equals(f.id))).getSingle()).toJson();
        final credential = (await f.h.secrets.readCredential(f.id))!.toJson();
        final before = (await f.store.read((tx) => tx.account(f.contactId)))!;
        final generation = await f.h.persistence.generation(f.id);
        final requests = f.requests.length;
        expect(requests, greaterThan(0));
        await f.h.db.customStatement(
          'CREATE TRIGGER reject_contact_disable '
          '${phase == 'before-write' ? 'BEFORE' : 'AFTER'} UPDATE ON bm_contact_accounts '
          "WHEN NEW.id = '${f.contactId}' AND json_extract(NEW.data, '\$.enabled') = 0 "
          "BEGIN SELECT RAISE(ABORT, 'preparation-disable-failure'); END",
        );
        await expectLater(
          f.repository.removeAccount(accountId: f.id),
          throwsA(
            predicate<Object>(
              (error) =>
                  error.toString().contains('preparation-disable-failure'),
            ),
          ),
        );
        expect(
          (await (f.h.db.select(
            f.h.db.accounts,
          )..where((row) => row.id.equals(f.id))).getSingle()).toJson(),
          parent,
        );
        expect((await f.h.secrets.readCredential(f.id))!.toJson(), credential);
        expect(await f.h.persistence.generation(f.id), generation);
        final after = (await f.store.read((tx) => tx.account(f.contactId)))!;
        expect(after.toJson(), before.toJson());
        await f.h.db.customStatement('DROP TRIGGER reject_contact_disable');
        await f.controller.synchronizeAccount(f.contactId);
        expect(f.requests.length, greaterThan(requests));
        expect(f.h.flow.clients, isEmpty);
        await f.controller.close().timeout(const Duration(seconds: 3));
        expect(await f.h.accounts.accountById(f.id), isNotNull);
      });
    }
    test(
      '$provider fresh consent positive commits parent grants and contacts together',
      () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(granted: false);
        await f.controller.enableLinkedContacts(f.id);
        await f.controller.synchronizeAccount(f.contactId);
        final contacts = (await f.store.read((tx) => tx.account(f.contactId)))!;
        final credential =
            await f.h.secrets.readCredential(f.id) as BoundOAuthSecretRecord;
        expect(contacts.enabled, isTrue);
        expect(
          contacts.grantedScopes.map(microsoftGraphScopeName),
          containsAll(credential.tokenSet.scopes.map(microsoftGraphScopeName)),
        );
        expect(
          (await f.h.accounts.accountById(f.id))!.grantedScopes.split(' '),
          containsAll(credential.tokenSet.scopes),
        );
        expect(f.requests, isNotEmpty);
      },
    );
    for (final granted in [true, false]) {
      test(
        '$provider ${granted ? 'already granted' : 'fresh consent'} enrollment queued behind removal drains',
        () async {
          final gate = RemovalGate();
          final f = LifecycleFixture(provider, gate: gate);
          addTearDown(f.close);
          await f.seed(granted: granted);
          gate.capture = true;
          final enrollment = f.controller.enableLinkedContacts(f.id);
          final enrollmentResult = expectLater(
            enrollment,
            throwsA(isA<Object>()),
          );
          await gate.readFinished.future;
          final removal = f.repository.removeAccount(accountId: f.id);
          // Let the empty recovery-journal query enqueue removal while the actual
          // credential reader still owns the boundary. No provider work is guessed.
          await f.h.persistence.recover();
          await Future<void>.delayed(Duration.zero);
          gate.releaseRead.complete();
          await gate.removalEntered.future;
          await Future<void>.delayed(Duration.zero);
          gate.releaseRemoval.complete();
          await removal.timeout(const Duration(seconds: 3));
          await enrollmentResult;
          expect(await f.h.accounts.accountById(f.id), isNull);
          expect(await f.h.secrets.readCredential(f.id), isNull);
          expect(await f.store.read((tx) => tx.account(f.contactId)), isNull);
          await f.controller.close().timeout(const Duration(seconds: 3));
          await f.h.persistence.recover();
          expect(await f.h.secrets.readCredential(f.id), isNull);
        },
      );
    }
    test(
      '$provider fresh consent queues staged commit behind the removal boundary',
      () async {
        final gate = RemovalGate();
        final f = LifecycleFixture(provider, gate: gate);
        addTearDown(f.close);
        await f.seed(granted: false);
        final ready = Completer<void>(), consent = Completer<void>();
        final response = f.h.beforeRequest;
        f.h.beforeRequest = (request) async {
          if (request.method == 'GET') {
            ready.complete();
            await consent.future;
            return null;
          }
          return response?.call(request);
        };
        var staged = 0;
        f.h.secrets.beforeSave = (id, record) async {
          if (id == f.id &&
              record is BoundOAuthSecretRecord &&
              record.generation > 1) {
            staged++;
          }
        };
        final enrolled = f.controller.enableLinkedContacts(f.id);
        final observed = expectLater(enrolled, throwsA(isA<Object>()));
        await ready.future;
        gate.capture = true;
        gate.calls = 1;
        final removed = f.repository.removeAccount(accountId: f.id);
        await gate.removalEntered.future;
        await expectLater(
          f.controller.enableLinkedContacts(f.id),
          throwsA(isA<ContactsException>()),
        );
        consent.complete();
        await Future<void>.delayed(Duration.zero);
        gate.releaseRemoval.complete();
        await removed.timeout(const Duration(seconds: 3));
        await observed;
        expect(staged, lessThanOrEqualTo(1));
        expect(await f.h.db.select(f.h.db.authorizationCommits).get(), isEmpty);
        expect(await f.h.secrets.readCredential(f.id), isNull);
        expect(await f.store.read((tx) => tx.account(f.contactId)), isNull);
      },
    );
    test(
      '$provider cancellation after secure staging rolls back before parent removal',
      () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(granted: false);
        final staged = Completer<void>(), release = Completer<void>();
        f.h.secrets.afterSave = (id, record) async {
          if (id == f.id &&
              record is BoundOAuthSecretRecord &&
              record.generation > 1) {
            staged.complete();
            await release.future;
          }
        };
        final enrolled = f.controller.enableLinkedContacts(f.id);
        final observed = expectLater(enrolled, throwsA(isA<Object>()));
        await staged.future;
        final removed = f.repository.removeAccount(accountId: f.id);
        final disabled = f.controller.disableContactsAccount(f.contactId);
        release.complete();
        await observed;
        await disabled;
        await removed.timeout(const Duration(seconds: 3));
        expect(await f.h.secrets.readCredential(f.id), isNull);
        expect(await f.store.read((tx) => tx.account(f.contactId)), isNull);
        expect(await f.h.db.select(f.h.db.authorizationCommits).get(), isEmpty);
      },
    );
    test(
      '$provider incomplete credential rollback does not grant contacts recovery authority',
      () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(enabled: true);
        final credential =
            await f.h.secrets.readCredential(f.id) as BoundOAuthSecretRecord;
        final candidate = provider == BusyProvider.google
            ? GoogleDesktopCredential(
                registration:
                    credential.registration as GoogleDesktopRegistration,
                tokenSet: credential.tokenSet,
                subject: credential.subject,
                generation: 2,
                transitionEligible: credential.transitionEligible,
              )
            : MicrosoftDesktopCredential(
                registration:
                    credential.registration as MicrosoftPublicRegistration,
                tokenSet: credential.tokenSet,
                subject: credential.subject,
                tenantId: tenant,
                generation: 2,
                transitionEligible: false,
              );
        f.afterPrepare = () async {
          f.h.secrets.beforeSave = (id, record) async {
            if (id == f.id &&
                record is BoundOAuthSecretRecord &&
                record.generation == 1) {
              throw StateError('credential rollback unavailable');
            }
          };
          await expectLater(
            f.h.persistence.commit(
              accountId: f.id,
              expectedGeneration: 1,
              candidate: candidate,
              requireExisting: true,
              persistAccount: () async {
                throw StateError('account metadata failure');
              },
            ),
            throwsA(isA<Object>()),
          );
        };
        final requests = f.requests.length;
        await expectLater(
          f.repository.removeAccount(accountId: f.id),
          throwsA(isA<Object>()),
        );
        expect(
          (await f.store.read((tx) => tx.account(f.contactId)))!.enabled,
          isFalse,
        );
        expect(f.requests.length, requests);
        expect(
          await f.h.db.select(f.h.db.authorizationCommits).get(),
          hasLength(1),
        );
        f.h.secrets.beforeSave = null;
        await f.h.persistence.recover();
        expect(
          (await f.h.secrets.readCredential(f.id))!.toJson(),
          credential.toJson(),
        );
        expect(
          (await f.store.read((tx) => tx.account(f.contactId)))!.enabled,
          isFalse,
        );
      },
    );
    test(
      '$provider post-commit credential cleanup failure never restores removed contacts',
      () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(enabled: true);
        var deletions = 0;
        f.h.secrets.beforeDelete = (id) async {
          if (id == f.id && ++deletions == 2) {
            f.h.secrets.beforeDelete = null;
            throw StateError('cleanup failed after durable deletion');
          }
        };
        await expectLater(
          f.repository.removeAccount(accountId: f.id),
          throwsA(isA<Object>()),
        );
        expect(await f.h.accounts.accountById(f.id), isNull);
        expect(await f.store.read((tx) => tx.account(f.contactId)), isNull);
        await f.controller.restoreLinkedAccountAfterFailedRemoval(f.id);
        await f.h.persistence.recover();
        expect(await f.h.secrets.readCredential(f.id), isNull);
      },
    );
    for (final newer in [
      'disable',
      'remove',
      'contacts-replacement',
      'authorization-replacement',
    ]) {
      test('$provider older recovery cannot overwrite newer $newer', () async {
        final f = LifecycleFixture(provider);
        addTearDown(f.close);
        await f.seed(enabled: true);
        final waiting = Completer<void>(), resume = Completer<void>();
        if (newer == 'authorization-replacement') {
          f.afterPrepare = () async {
            waiting.complete();
            await resume.future;
          };
        } else {
          f.beforeRecovery = () async {
            waiting.complete();
            await resume.future;
          };
          f.h.secrets.beforeDelete = (id) async {
            if (id == f.id) {
              f.h.secrets.beforeDelete = null;
              throw StateError('reversible failure');
            }
          };
        }
        final removed = f.repository.removeAccount(accountId: f.id);
        final observed = expectLater(removed, throwsA(isA<Object>()));
        await waiting.future;
        final requests = f.requests.length;
        if (newer == 'disable') {
          await f.controller.disableContactsAccount(f.contactId);
        } else if (newer == 'remove') {
          await f.controller.removeContactsAccount(f.contactId);
        } else if (newer == 'contacts-replacement') {
          await f.store.write((tx) async {
            final current = (await tx.account(f.contactId))!;
            await tx.putAccount(
              current.copy(
                generation: current.generation + 1,
                enabled: false,
                errorCode: 'newer-state',
              ),
            );
          });
        } else {
          final old =
              await f.h.secrets.readCredential(f.id) as BoundOAuthSecretRecord;
          final candidate = provider == BusyProvider.google
              ? GoogleDesktopCredential(
                  registration: old.registration as GoogleDesktopRegistration,
                  tokenSet: old.tokenSet,
                  subject: old.subject,
                  generation: old.generation + 1,
                  transitionEligible: old.transitionEligible,
                )
              : MicrosoftDesktopCredential(
                  registration: old.registration as MicrosoftPublicRegistration,
                  tokenSet: old.tokenSet,
                  subject: old.subject,
                  tenantId: tenant,
                  generation: old.generation + 1,
                  transitionEligible: old.transitionEligible,
                );
          await f.h.persistence.commit(
            accountId: f.id,
            expectedGeneration: old.generation,
            candidate: candidate,
            requireExisting: true,
            persistAccount: () async {},
          );
        }
        resume.complete();
        await observed;
        final current = await f.store.read((tx) => tx.account(f.contactId));
        expect(current?.enabled, newer == 'remove' ? isNull : isFalse);
        expect(f.requests.length, requests);
        if (current != null) {
          await expectLater(
            f.controller.directory.discover(f.contactId),
            throwsA(isA<ContactsException>()),
          );
        }
        if (newer == 'authorization-replacement') {
          expect(await f.h.persistence.generation(f.id), 2);
        }
      });
    }
    for (final enabled in [true, false, null]) {
      test(
        '$provider successful removal enabled=$enabled never restores and leaves another account usable',
        () async {
          final f = LifecycleFixture(provider);
          addTearDown(f.close);
          await f.seed(enabled: enabled);
          final credential =
              await f.h.secrets.readCredential(f.id) as BoundOAuthSecretRecord;
          final other = provider == BusyProvider.google
              ? GoogleDesktopCredential(
                  registration:
                      credential.registration as GoogleDesktopRegistration,
                  tokenSet: credential.tokenSet,
                  subject: 'other',
                  generation: 1,
                  transitionEligible: false,
                )
              : MicrosoftDesktopCredential(
                  registration:
                      credential.registration as MicrosoftPublicRegistration,
                  tokenSet: credential.tokenSet,
                  subject: 'other',
                  tenantId: tenant,
                  generation: 1,
                  transitionEligible: false,
                );
          await f.h.persistence.commit(
            accountId: 'unrelated',
            expectedGeneration: 0,
            candidate: other,
            persistAccount: () => f.h.accounts.upsertSignedInAccount(
              id: 'unrelated',
              provider: provider,
              providerAccountId: 'other',
              tenantId: provider == BusyProvider.microsoft ? tenant : null,
              grantedScopes: credential.tokenSet.scopes.join(' '),
            ),
          );
          await f.controller.enableLinkedContacts('unrelated');
          await f.controller.synchronizeAccount('contacts:unrelated');
          final removed = f.repository.removeAccount(accountId: f.id);
          expect(
            identical(removed, f.repository.removeAccount(accountId: f.id)),
            isTrue,
          );
          await removed;
          await f.controller.restoreLinkedAccountAfterFailedRemoval(f.id);
          await f.h.persistence.recover();
          expect(await f.h.accounts.accountById(f.id), isNull);
          expect(await f.h.secrets.readCredential(f.id), isNull);
          expect(await f.store.read((tx) => tx.account(f.contactId)), isNull);
          await f.controller.synchronizeAccount('contacts:unrelated');
          expect(
            (await f.store.read((tx) => tx.account('contacts:unrelated')))!
                .enabled,
            isTrue,
          );
        },
      );
    }
    for (final enabled in [true, false, null]) {
      test(
        '$provider failed removal preserves settings and provider binding after disk restart enabled=$enabled',
        () async {
          final profile = await createPersistenceTestDirectory(
            'busymax-removal-restart-',
          );
          addTearDown(() => profile.delete(recursive: true));
          final secrets = FailureStore();
          LifecycleFixture open() => LifecycleFixture(
            provider,
            database: AppDatabase(
              NativeDatabase(File('${profile.path}/app.db')),
            ),
            secrets: secrets,
          );
          var f = open();
          await f.seed(enabled: enabled);
          f.h.secrets.beforeDelete = (id) async {
            if (id == f.id) {
              f.h.secrets.beforeDelete = null;
              throw StateError('reversible storage failure');
            }
          };
          await expectLater(
            f.repository.removeAccount(accountId: f.id),
            throwsA(isA<Object>()),
          );
          await f.close();
          f = open();
          addTearDown(f.close);
          await f.h.persistence.recover();
          await f.controller.start();
          final current = await f.store.read((tx) => tx.account(f.contactId));
          expect(current?.enabled, enabled);
          if (enabled == true) {
            await f.controller.synchronizeAccount(f.contactId);
            expect(f.requests, isNotEmpty);
          } else {
            await Future<void>.delayed(Duration.zero);
            expect(f.requests, isEmpty);
            if (current != null) {
              await expectLater(
                f.controller.directory.discover(f.contactId),
                throwsA(isA<ContactsException>()),
              );
            }
          }
          expect(await f.h.secrets.readCredential(f.id), isNotNull);
        },
      );
    }
    for (final enabled in [true, false, null]) {
      for (final failure in ['secret', 'database']) {
        test(
          '$provider reversible $failure removal preserves contacts enabled=$enabled',
          () async {
            final f = LifecycleFixture(provider);
            addTearDown(f.close);
            await f.seed(enabled: enabled);
            final before = await f.store.read((tx) => tx.account(f.contactId));
            final credential = (await f.h.secrets.readCredential(f.id))!
                .toJson();
            if (failure == 'secret') {
              f.h.secrets.beforeDelete = (id) async {
                if (id == f.id) {
                  f.h.secrets.beforeDelete = null;
                  throw StateError('reversible secret deletion failure');
                }
              };
            } else {
              await f.h.db.customStatement(
                "CREATE TRIGGER reject_removal BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT, 'reversible deletion failure'); END",
              );
            }
            final requests = f.requests.length;
            await expectLater(
              f.repository.removeAccount(accountId: f.id),
              throwsA(isA<Object>()),
            );
            final after = await f.store.read((tx) => tx.account(f.contactId));
            expect(after?.enabled, before?.enabled);
            expect(after?.subject, before?.subject);
            expect(after?.grantedScopes, before?.grantedScopes);
            expect(
              (await f.h.secrets.readCredential(f.id))!.toJson(),
              credential,
            );
            if (enabled == true) {
              await f.controller.synchronizeAccount(f.contactId);
              expect(f.requests.length, greaterThan(requests));
            } else {
              expect(f.requests.length, requests);
              if (after != null) {
                await expectLater(
                  f.controller.directory.discover(f.contactId),
                  throwsA(isA<ContactsException>()),
                );
              }
            }
            await f.controller.close();
            final restartedStore = BusyMaxContactsStore(f.h.db);
            expect(
              (await restartedStore.read((tx) => tx.account(f.contactId)))
                  ?.enabled,
              enabled,
            );
            await restartedStore.close();
          },
        );
      }
    }
  }
}

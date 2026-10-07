import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AccountsRepository accounts;
  late AuthSessionController controller;
  final syncs = <({String accountId, bool initial})>[];

  setUp(() async {
    database = AppDatabase.memoryForTests();
    accounts = AccountsRepository(database: database);
    controller = AuthSessionController(
      repository: AuthRepository(
        oAuth: _UnexpectedOAuthGateway(),
        database: database,
      ),
      isConfigured: true,
      onSignedIn: (accountId, initial) async {
        syncs.add((accountId: accountId, initial: initial));
      },
    );
    await controller.load();
    syncs.clear();
  });
  tearDown(() async {
    if (controller.mounted) controller.dispose();
    await database.close();
  });

  Future<void> persist(String id, BusyProvider provider) =>
      accounts.upsertSignedInAccount(
        id: id,
        provider: provider,
        authority: switch (provider) {
          BusyProvider.microsoft => 'https://login.microsoftonline.com/common',
          BusyProvider.appleICloud => 'https://caldav.icloud.com',
          BusyProvider.google => 'https://accounts.google.com',
          _ => 'https://fixture.example.test',
        },
        providerAccountId: id,
        grantedScopes: '',
      );

  test(
    'session-only reconciliation selects the persisted first connection without sync',
    () async {
      expect(controller.state.isSignedIn, isFalse);
      await persist('apple:first', BusyProvider.appleICloud);
      await controller.reconcileConnectedAccount('apple:first');
      expect(controller.state.isSignedIn, isTrue);
      expect(controller.state.accountId, 'apple:first');
      expect(syncs, isEmpty);
    },
  );

  test(
    'session-only reconciliation preserves a valid session ahead of repository ordering',
    () async {
      await persist('microsoft:existing', BusyProvider.microsoft);
      await controller.load();
      final original = controller.state;
      syncs.clear();
      await persist('google:new', BusyProvider.google);
      await controller.reconcileConnectedAccount('google:new');
      expect(controller.state, same(original));
      expect(controller.state.accountId, 'microsoft:existing');
      expect(syncs, isEmpty);
    },
  );

  test(
    'missing, subscription and reconnect-required rows cannot manufacture a session',
    () async {
      final original = controller.state;
      await controller.reconcileConnectedAccount('missing');
      await persist('webcal:only', BusyProvider.webCal);
      await controller.reconcileConnectedAccount('webcal:only');
      await persist('google:invalid', BusyProvider.google);
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals('google:invalid'))).write(
        const AccountsCompanion(
          authState: Value(accountAuthStateReauthRequired),
        ),
      );
      await controller.reconcileConnectedAccount('google:invalid');
      expect(controller.state, same(original));
      expect(syncs, isEmpty);
    },
  );

  test(
    'reconciliation repairs an invalid current account using the committed reconnection',
    () async {
      await persist('microsoft:old', BusyProvider.microsoft);
      await controller.load();
      syncs.clear();
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals('microsoft:old'))).write(
        const AccountsCompanion(
          authState: Value(accountAuthStateReauthRequired),
        ),
      );
      await persist('nextcloud:connected', BusyProvider.nextcloud);
      await controller.reconcileConnectedAccount('nextcloud:connected');
      expect(controller.state.accountId, 'nextcloud:connected');
      expect(syncs, isEmpty);
    },
  );

  test('session-only reconciliation remains inert after disposal', () async {
    controller.dispose();
    await controller.reconcileConnectedAccount('missing');
    expect(syncs, isEmpty);
  });
  test(
    'a disposed reconciliation in flight does not publish or sync',
    () async {
      await persist('google:connected', BusyProvider.google);
      final reconciliation = controller.reconcileConnectedAccount(
        'google:connected',
      );
      controller.dispose();
      await reconciliation;
      expect(syncs, isEmpty);
    },
  );
  test('a newer cancellation wins over a reconciliation in flight', () async {
    await persist('google:connected', BusyProvider.google);
    final reconciliation = controller.reconcileConnectedAccount(
      'google:connected',
    );
    await controller.cancelSignIn(cancellation: AuthorizationCancellation());
    await reconciliation;
    expect(controller.state.isSignedIn, isFalse);
    expect(syncs, isEmpty);
  });
  test(
    'reconnecting the current account preserves its valid session without sync',
    () async {
      await persist('apple:current', BusyProvider.appleICloud);
      await controller.load();
      final original = controller.state;
      syncs.clear();
      await persist('apple:current', BusyProvider.appleICloud);
      await controller.reconcileConnectedAccount('apple:current');
      expect(controller.state, same(original));
      expect(syncs, isEmpty);
    },
  );

  test(
    'read failure preserves the previous session and reports the failure',
    () async {
      await persist('google:existing', BusyProvider.google);
      await controller.load();
      final original = controller.state;
      syncs.clear();
      await database.close();
      await expectLater(
        controller.reconcileConnectedAccount('new'),
        throwsStateError,
      );
      expect(controller.state, same(original));
      expect(syncs, isEmpty);
    },
  );
}

class _UnexpectedOAuthGateway implements OAuthGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Reconciliation must not authorize or synchronize.');
}

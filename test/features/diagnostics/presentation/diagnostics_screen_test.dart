import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/diagnostics/presentation/diagnostics_screen.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets(
    'retry for reconnect-required account stays blocked and reports reconnect',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedAccount(database, needsReconnect: true);
      await _seedBlockedOperation(database, id: 'retry-op');
      var syncCalls = 0;
      final service = PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => syncCalls += 1,
        syncCalendar: () async => syncCalls += 1,
      );

      await _pumpDiagnostics(tester, database, service);
      final before = await database.pendingOpsDao.getOp('retry-op');

      _selectMenuAction(tester, 'Retry');
      await tester.pumpAndSettle();

      final after = await database.pendingOpsDao.getOp('retry-op');
      expect(after?.state, before?.state);
      expect(after?.nextAttemptAtUtc, before?.nextAttemptAtUtc);
      expect(syncCalls, 0);
      expect(
        find.text('This account needs to be reconnected.'),
        findsOneWidget,
      );
      expect(find.text('Retry completed.'), findsNothing);
      await _disposeDiagnostics(tester);
    },
  );

  testWidgets('discard failure uses a controlled sync message', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedAccount(database);
    await _seedBlockedOperation(database, id: 'discard-op');
    final service = _ThrowingPendingOpResolutionService(database);

    await _pumpDiagnostics(tester, database, service);

    _selectMenuAction(tester, 'Discard');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard').last);
    await tester.pumpAndSettle();

    expect(find.text('This account needs to be reconnected.'), findsOneWidget);
    expect(find.textContaining('KnownUnsentRequestException'), findsNothing);
    expect(find.textContaining('OAuthRefreshException'), findsNothing);
    expect(find.textContaining('provider-secret'), findsNothing);
    expect(await database.pendingOpsDao.getOp('discard-op'), isNotNull);
    await _disposeDiagnostics(tester);
  });
}

Future<void> _disposeDiagnostics(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
}

Future<void> _pumpDiagnostics(
  WidgetTester tester,
  AppDatabase database,
  PendingOpResolutionService service,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
        pendingOpResolutionServiceForAccountProvider.overrideWith(
          (ref, accountId) => service,
        ),
      ],
      child: localizedTestApp(
        child: const Scaffold(
          body: SingleChildScrollView(
            child: DiagnosticsPanel(scrollable: false),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _selectMenuAction(WidgetTester tester, String label) {
  final menu =
      tester.widget(
            find.byWidgetPredicate((widget) => widget is BusyMaxMenuButton),
          )
          as dynamic;
  final entry = (menu.entries as List<dynamic>).singleWhere(
    (candidate) => candidate.label == label,
  );
  menu.onSelected(entry.value);
}

Future<void> _seedAccount(
  AppDatabase database, {
  bool needsReconnect = false,
}) async {
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'provider-account',
          credentialKind: 'oauth',
          authState: Value(
            needsReconnect
                ? accountAuthStateReauthRequired
                : accountAuthStateSignedIn,
          ),
          createdAtUtc: '2026-09-21T00:00:00.000Z',
          updatedAtUtc: '2026-09-21T00:00:00.000Z',
        ),
      );
}

Future<void> _seedBlockedOperation(AppDatabase database, {required String id}) {
  return database.pendingOpsDao.enqueue(
    PendingOpsCompanion.insert(
      id: id,
      accountId: 'account',
      provider: const Value('google'),
      entityType: 'task',
      operation: 'patch_task',
      taskListId: const Value('list'),
      taskId: const Value('task'),
      requestJson: '{}',
      state: const Value('failed'),
      retryClassification: const Value('permanent'),
      nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
      lastErrorCode: const Value('provider_rejected'),
      createdAtUtc: '2026-09-21T00:00:00.000Z',
      updatedAtUtc: '2026-09-21T00:00:00.000Z',
    ),
  );
}

final class _ThrowingPendingOpResolutionService
    extends PendingOpResolutionService {
  _ThrowingPendingOpResolutionService(AppDatabase database)
    : super(
        database: database,
        accountId: 'account',
        syncTasks: _noSync,
        syncCalendar: _noSync,
      );

  @override
  Future<void> discard(String opId) async {
    throw const KnownUnsentRequestException(
      kind: RequestPreDispatchFailureKind.authentication,
      cause: OAuthRefreshException(
        'OAuthRefreshFailed',
        'provider-secret',
        statusCode: 400,
        oauthError: 'invalid_grant',
        oauthErrorDescription: 'provider-secret',
      ),
    );
  }

  static Future<void> _noSync() async {}
}

import 'dart:async';

import 'package:drift/drift.dart';

import '../../app/app_settings.dart';
import '../../core/http/request_dispatch_exception.dart';
import '../../db/app_database.dart';
import '../sync/sync_failure_notification_policy.dart';
import 'desktop_notification_service.dart';
import 'notification_reconciler.dart';

String operationalNotificationId(String kind, String? accountId) =>
    accountId == null ? kind : '$kind|$accountId';

class OperationalNotificationTransport {
  const OperationalNotificationTransport({
    required this.deliver,
    required this.cancel,
    this.synchronize,
    this.readSettings,
  });
  final Future<ReminderDeliveryResult> Function(
    String kind,
    String? accountId,
    String revision,
    int count,
  )
  deliver;
  final Future<bool> Function(String id) cancel;
  final Future<void> Function(Future<void> Function() operation)? synchronize;
  final Future<AppSettings> Function()? readSettings;
}

/// Reconciles durable unresolved issues instead of depending on one transient
/// sync callback. DAV and the Google/Microsoft replay paths share this scan.
class OperationalNotificationCoordinator
    implements OperationalNotificationReporter {
  OperationalNotificationCoordinator({
    required AppDatabase database,
    required AppSettings Function() settings,
    required OperationalNotificationTransport Function() transport,
    DateTime Function()? now,
  }) : _database = database,
       _settings = settings,
       _transport = transport,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final AppSettings Function() _settings;
  final OperationalNotificationTransport Function() _transport;
  final DateTime Function() _now;
  StreamSubscription<Set<TableUpdate>>? _subscription;
  Timer? _timer;
  bool _checking = false;
  bool _again = false;
  bool _stopped = false;
  bool _withdraw = false;

  void start() {
    if (_stopped || _timer != null) return;
    _subscription = _database
        .tableUpdates(
          TableUpdateQuery.allOf([
            TableUpdateQuery.onTable(_database.pendingOps),
            TableUpdateQuery.onTable(_database.accounts),
            TableUpdateQuery.onTable(_database.authorizationGenerations),
          ]),
        )
        .listen((_) => unawaited(reconcile()));
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(reconcile()),
    );
    unawaited(reconcile());
  }

  void stop() {
    _stopped = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
  }

  void settingsChanged({bool withdraw = true, bool releaseDeferred = false}) {
    if (_stopped) return;
    _withdraw = _withdraw || withdraw;
    if (releaseDeferred) {
      unawaited(
        _database
            .update(_database.notificationIssues)
            .write(const NotificationIssuesCompanion(retryAtUtc: Value(null)))
            .then((_) => reconcile()),
      );
    } else {
      unawaited(reconcile());
    }
  }

  @override
  Future<void> notifySyncFailure(Object error, {String? accountId}) async {
    if (_stopped) return;
    final disposition = syncFailureNotificationDisposition(error);
    if (disposition == SyncFailureNotificationDisposition.suppressed) return;
    accountId ??= switch (error) {
      AuthorizationScopedFailure(:final accountId) => accountId,
      AuthorizationScopedOAuthException(:final accountId) => accountId,
      _ => null,
    };
    var revision = disposition.name;
    if (accountId != null) {
      final generation = await _authorizationGeneration(accountId);
      if (_stopped) return;
      final failedGeneration = failureAuthorizationGeneration(error, accountId);
      if (failedGeneration != null && failedGeneration != generation) return;
      // Explicit reconnection replaces this durable generation. Recovery must
      // invalidate the old issue even when the next network sync cannot run.
      // Normal token refresh does not change the authorization generation.
      revision = '${disposition.name}:$generation';
    }
    final id = operationalNotificationId('sync-failure', accountId);
    await _recordIssue(id, accountId, 'sync-failure', revision);
    await reconcile();
  }

  Future<void> clearAccountSyncFailure(String accountId) async {
    if (_stopped) return;
    final id = operationalNotificationId('sync-failure', accountId);
    // Keep a cleanup record until native withdrawal succeeds.
    await (_database.update(
      _database.notificationIssues,
    )..where((row) => row.id.equals(id))).write(
      const NotificationIssuesCompanion(
        revision: Value('resolved'),
        submittedRevision: Value(null),
      ),
    );
    await reconcile();
  }

  @override
  Future<void> notifyConflict(String summary) => reconcile();

  Future<void> reconcile() async {
    if (_stopped) return;
    if (_checking) {
      _again = true;
      return;
    }
    _checking = true;
    try {
      do {
        _again = false;
        final synchronize = _transport().synchronize;
        if (synchronize == null) {
          await _evaluate();
        } else {
          await synchronize(_evaluate);
        }
      } while (_again && !_stopped);
    } on Object {
      // A disposed runtime may close its database while a native operation or
      // query is completing. It must not launch another query or leak an error.
      if (!_stopped) rethrow;
    } finally {
      _checking = false;
    }
  }

  Future<void> _evaluate() async {
    if (_stopped) return;
    final accounts = {
      for (final account in await _database.select(_database.accounts).get())
        account.id,
    };
    if (_stopped) return;
    final conflicts =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.state.equals('conflict') |
                  row.conflictState.equals('unresolved') |
                  row.lastErrorCode.equals('conflict'),
            ))
            .get();
    if (_stopped) return;
    final byAccount = <String, List<String>>{};
    for (final op in conflicts) {
      if (accounts.contains(op.accountId)) {
        (byAccount[op.accountId] ??= []).add(op.id);
      }
    }
    for (final entry in byAccount.entries) {
      if (_stopped) return;
      entry.value.sort();
      await _recordIssue(
        operationalNotificationId('conflict', entry.key),
        entry.key,
        'conflict',
        entry.value.join('\n'),
      );
    }
    final withdraw = _withdraw;
    if (_stopped) return;
    _withdraw = false;
    for (final issue
        in await _database.select(_database.notificationIssues).get()) {
      if (_stopped) return;
      final resolved =
          await (_database.select(
                _database.notificationIssues,
              )..where((row) => _sameIssue(row, issue) & _resolvedIssue(issue)))
              .getSingleOrNull() !=
          null;
      if (_stopped) return;
      final settings = await _currentSettings();
      final enabled = issue.kind == 'conflict'
          ? settings.notifyConflicts
          : settings.notifySyncFailures;
      final private =
          settings.notificationDetailLevel == NotificationDetailLevel.private;
      if (resolved ||
          !enabled ||
          private && !issue.submittedPrivate ||
          withdraw ||
          issue.cleanupPending) {
        final removed = await _transport().cancel(issue.id);
        if (_stopped) return;
        final updated =
            await (_database.update(_database.notificationIssues)..where(
                  (row) =>
                      _sameIssue(row, issue) &
                      (resolved ? _resolvedIssue(issue) : const Constant(true)),
                ))
                .write(
                  NotificationIssuesCompanion(cleanupPending: Value(!removed)),
                );
        if (updated == 0) {
          _again = true;
          continue;
        }
        if (resolved && removed) {
          final deleted =
              await (_database.delete(_database.notificationIssues)..where(
                    (row) =>
                        _sameIssue(row, issue, cleanupPending: false) &
                        _resolvedIssue(issue),
                  ))
                  .go();
          if (deleted == 0) _again = true;
          continue;
        }
        if (resolved || !enabled || !removed) continue;
      }
      if (issue.submittedRevision == issue.revision ||
          (issue.retryAtUtc != null &&
              issue.retryAtUtc! > _now().millisecondsSinceEpoch)) {
        continue;
      }
      final transport = _transport();
      final result = await transport.deliver(
        issue.kind,
        issue.accountId,
        issue.revision,
        byAccount[issue.accountId]?.length ?? 1,
      );
      if (_stopped) {
        if (result.status == ReminderDeliveryStatus.delivered) {
          await transport.cancel(issue.id);
        }
        return;
      }
      final current = await (_database.select(
        _database.notificationIssues,
      )..where((row) => row.id.equals(issue.id))).getSingleOrNull();
      if (_stopped) {
        if (result.status == ReminderDeliveryStatus.delivered) {
          await transport.cancel(issue.id);
        }
        return;
      }
      var authorizationChanged = false;
      if (issue.kind == 'sync-failure' && issue.accountId != null) {
        final generation = await _authorizationGeneration(issue.accountId!);
        if (_stopped) {
          if (result.status == ReminderDeliveryStatus.delivered) {
            await transport.cancel(issue.id);
          }
          return;
        }
        authorizationChanged =
            generation != _syncIssueGeneration(issue.revision);
      }
      final currentSettings = await _currentSettings();
      if (current?.revision != issue.revision ||
          authorizationChanged ||
          currentSettings.notificationDetailLevel !=
              settings.notificationDetailLevel ||
          (issue.kind == 'conflict'
              ? !currentSettings.notifyConflicts
              : !currentSettings.notifySyncFailures)) {
        final removed = await transport.cancel(issue.id);
        if (_stopped) return;
        if (!removed) {
          await (_database.update(_database.notificationIssues)..where(
                (row) =>
                    row.id.equals(issue.id) &
                    row.revision.equals(issue.revision),
              ))
              .write(
                const NotificationIssuesCompanion(cleanupPending: Value(true)),
              );
        }
      }
      if (current?.revision != issue.revision || authorizationChanged) {
        _again = true;
        continue;
      }
      await (_database.update(_database.notificationIssues)..where(
            (row) =>
                row.id.equals(issue.id) & row.revision.equals(issue.revision),
          ))
          .write(
            result.status == ReminderDeliveryStatus.delivered
                ? NotificationIssuesCompanion(
                    submittedRevision: Value(issue.revision),
                    submittedPrivate: Value(private),
                    retryAtUtc: const Value(null),
                  )
                : NotificationIssuesCompanion(
                    retryAtUtc: Value(
                      result.retryAtUtc?.millisecondsSinceEpoch,
                    ),
                  ),
          );
    }
  }

  Future<AppSettings> _currentSettings() async =>
      await _transport().readSettings?.call() ?? _settings();

  Future<void> _recordIssue(
    String id,
    String? accountId,
    String kind,
    String revision,
  ) async {
    // One atomic UPSERT, including lifecycle reset. Separate runtimes may
    // report while cancellation is awaiting native work; a read/then-write
    // transaction here would race another writer's revision or lock upgrade.
    await _database.customInsert(
      'INSERT INTO notification_issues (id, account_id, kind, revision) '
      'VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
      'revision = excluded.revision, '
      'submitted_revision = CASE WHEN revision <> excluded.revision '
      'THEN NULL ELSE submitted_revision END, '
      'retry_at_utc = CASE WHEN revision <> excluded.revision '
      'THEN NULL ELSE retry_at_utc END, '
      'cleanup_pending = CASE WHEN revision <> excluded.revision '
      'THEN cleanup_pending OR submitted_revision IS NOT NULL OR native_id IS NOT NULL '
      'ELSE cleanup_pending END',
      variables: [
        Variable(id),
        Variable<String>(accountId),
        Variable(kind),
        Variable(revision),
      ],
      updates: {_database.notificationIssues},
    );
  }

  Future<int> _authorizationGeneration(String accountId) async =>
      (await (_database.select(
            _database.authorizationGenerations,
          )..where((row) => row.accountId.equals(accountId))).getSingleOrNull())
          ?.generation ??
      0;

  // Resolution is a predicate over authoritative SQLite state, not a scan's
  // cached account/generation snapshot. Use it both to decide cancellation and
  // in the cleanup writes themselves: authorization/recovery can commit while
  // native cancellation awaits, under a different cross-engine gate.
  Expression<bool> _resolvedIssue(NotificationIssue issue) {
    if (issue.revision == 'resolved') return const Constant(true);
    final accountId = issue.accountId;
    if (accountId == null) return const Constant(false);
    final missingAccount = notExistsQuery(
      _database.select(_database.accounts)
        ..where((row) => row.id.equals(accountId)),
    );
    if (issue.kind == 'sync-failure') {
      final generation = _syncIssueGeneration(issue.revision);
      if (generation == null) return const Constant(true);
      final matchingGeneration =
          _database.select(_database.authorizationGenerations)..where(
            (row) =>
                row.accountId.equals(accountId) &
                (generation == 0
                    ? row.generation.isNotValue(0)
                    : row.generation.equals(generation)),
          );
      // An absent generation is the established generation-zero state.
      return missingAccount |
          (generation == 0
              ? existsQuery(matchingGeneration)
              : notExistsQuery(matchingGeneration));
    }
    if (issue.kind == 'conflict') {
      return missingAccount |
          notExistsQuery(
            _database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  (row.state.equals('conflict') |
                      row.conflictState.equals('unresolved') |
                      row.lastErrorCode.equals('conflict')),
            ),
          );
    }
    return missingAccount;
  }

  // A native cancellation may await another engine. It may only consume the
  // revision AND lifecycle that caused it, never a recovered/new failure.
  Expression<bool> _sameIssue(
    $NotificationIssuesTable row,
    NotificationIssue issue, {
    bool? cleanupPending,
  }) =>
      row.id.equals(issue.id) &
      row.revision.equals(issue.revision) &
      (issue.submittedRevision == null
          ? row.submittedRevision.isNull()
          : row.submittedRevision.equals(issue.submittedRevision!)) &
      row.submittedPrivate.equals(issue.submittedPrivate) &
      row.cleanupPending.equals(cleanupPending ?? issue.cleanupPending) &
      (issue.retryAtUtc == null
          ? row.retryAtUtc.isNull()
          : row.retryAtUtc.equals(issue.retryAtUtc!));

  int? _syncIssueGeneration(String revision) =>
      int.tryParse(revision.substring(revision.lastIndexOf(':') + 1));
}

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../google_calendar/google_calendar_errors.dart';
import '../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../microsoft_todo/api/microsoft_todo_api_error.dart';
import '../tasks/domain/task_remote_error.dart';
import '../../core/http/request_dispatch_exception.dart';
import '../../core/auth/oauth_models.dart';

enum SyncTrigger { manual, foreground, background, localMutation }

enum SyncDomain { tasks, calendar }

const _triggerZone = #busymaxSyncTrigger;
SyncTrigger get currentSyncTrigger =>
    Zone.current[_triggerZone] as SyncTrigger? ?? SyncTrigger.manual;
Future<T> withSyncTrigger<T>(
  SyncTrigger trigger,
  Future<T> Function() operation,
) => runZoned(operation, zoneValues: {_triggerZone: trigger});

final class DomainCooldownException implements Exception {
  const DomainCooldownException(this.domain, this.notBeforeUtc);
  final SyncDomain domain;
  final DateTime notBeforeUtc;
  @override
  String toString() =>
      'Synchronization is deferred until the provider cooldown ends.';
}

/// Must be called INSIDE the account and cross-engine synchronization gates.
final class DomainSyncPolicy {
  DomainSyncPolicy(this.database, {DateTime Function()? nowUtc})
    : nowUtc = nowUtc ?? (() => DateTime.now().toUtc());
  final AppDatabase database;
  final DateTime Function() nowUtc;
  // See docs/synchronization_budget.md for request-count evidence and policy.
  static const tasksPassiveInterval = Duration(hours: 1);
  static const calendarPassiveInterval = Duration(minutes: 15);
  static const foregroundStaleness = Duration(minutes: 15);

  Future<void> checkCooldown(String id, SyncDomain domain) async {
    final row =
        await (database.select(database.domainSyncSchedules)..where(
              (r) => r.accountId.equals(id) & r.domain.equals(domain.name),
            ))
            .getSingleOrNull();
    final until = _date(row?.cooldownUntilUtc);
    if (until != null && until.isAfter(nowUtc())) {
      throw DomainCooldownException(domain, until);
    }
  }

  /// Called by durable replay before returning control to its engine. Preserve
  /// pull checkpoints and the latest longer cooldown, including another writer.
  Future<bool> recordFailureCooldown(
    String id,
    SyncDomain domain,
    Object error,
  ) async {
    final retry = retryTiming(error);
    if (retry == null) return false;
    // Atomic max preserves a longer cooldown even across separate database
    // connections. All stored dates here are normalized UTC ISO timestamps.
    await database.customUpdate(
      'INSERT INTO domain_sync_schedules (account_id, domain, cooldown_until_utc) VALUES (?, ?, ?) '
      'ON CONFLICT(account_id, domain) DO UPDATE SET cooldown_until_utc = '
      'CASE WHEN domain_sync_schedules.cooldown_until_utc > excluded.cooldown_until_utc '
      'THEN domain_sync_schedules.cooldown_until_utc ELSE excluded.cooldown_until_utc END',
      variables: [
        Variable(id),
        Variable(domain.name),
        Variable(nowUtc().add(retry).toIso8601String()),
      ],
      updates: {database.domainSyncSchedules},
    );
    return true;
  }

  Future<void> _dispatch(
    String id,
    SyncDomain domain,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
    } on Object catch (error) {
      await recordFailureCooldown(id, domain, error);
      rethrow;
    }
  }

  Future<void> run(
    String id,
    SyncDomain domain, {
    required Future<void> Function() pull,
    required Future<void> Function() deferred,
    Future<void> Function()? maintainCached,
    bool full = false,
  }) async {
    final account = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (account == null ||
        (domain == SyncDomain.tasks
            ? !account.tasksEnabled
            : !account.calendarsEnabled)) {
      return;
    }
    final query = database.select(database.domainSyncSchedules)
      ..where((r) => r.accountId.equals(id) & r.domain.equals(domain.name));
    final row = await query.getSingleOrNull();
    final now = nowUtc();
    final cooldown = _date(row?.cooldownUntilUtc);
    if (cooldown != null && cooldown.isAfter(now)) {
      await maintainCached?.call();
      throw DomainCooldownException(domain, cooldown);
    }
    final last = _date(row?.lastSuccessfulPullUtc);
    final next = _date(row?.nextPassivePullUtc);
    final clockMovedBack = last != null && last.isAfter(now);
    final trigger = currentSyncTrigger;
    if (trigger == SyncTrigger.localMutation && !full) {
      await _dispatch(id, domain, deferred);
      return;
    }
    final due =
        full ||
        clockMovedBack ||
        last == null ||
        trigger == SyncTrigger.manual ||
        trigger == SyncTrigger.localMutation ||
        (trigger == SyncTrigger.foreground
            ? now.difference(last) >= foregroundStaleness
            : next == null || !next.isAfter(now));
    if (!due) {
      await _dispatch(id, domain, deferred);
      return;
    }
    try {
      await pull();
      // A stale success must not erase a cooldown established during the pull.
      await checkCooldown(id, domain);
      final completed = nowUtc();
      final interval = domain == SyncDomain.tasks
          ? tasksPassiveInterval
          : calendarPassiveInterval;
      // Sample once on success; an overdue wake never moves eligibility forward.
      final digest = sha256
          .convert(
            utf8.encode('$id:${domain.name}:${completed.toIso8601String()}'),
          )
          .bytes;
      final jitter = Duration(
        seconds: (digest[0] * 256 + digest[1]) % (interval.inSeconds ~/ 10 + 1),
      );
      await database.customUpdate(
        'INSERT INTO domain_sync_schedules (account_id, domain, last_successful_pull_utc, next_passive_pull_utc) VALUES (?, ?, ?, ?) '
        'ON CONFLICT(account_id, domain) DO UPDATE SET last_successful_pull_utc = excluded.last_successful_pull_utc, '
        'next_passive_pull_utc = excluded.next_passive_pull_utc, cooldown_until_utc = NULL '
        'WHERE domain_sync_schedules.cooldown_until_utc IS NULL OR domain_sync_schedules.cooldown_until_utc <= ?',
        variables: [
          Variable(id),
          Variable(domain.name),
          Variable(completed.toIso8601String()),
          Variable(completed.add(interval + jitter).toIso8601String()),
          Variable(completed.toIso8601String()),
        ],
        updates: {database.domainSyncSchedules},
      );
      await checkCooldown(id, domain);
    } on Object catch (error) {
      await recordFailureCooldown(id, domain, error);
      rethrow;
    }
  }
}

DateTime? _date(String? value) => DateTime.tryParse(value ?? '')?.toUtc();
Duration? retryTiming(Object failure) {
  final error = resolveEffectiveSyncFailure(failure);
  if (error is OAuthRefreshException &&
      (error.statusCode == 429 || error.statusCode >= 500)) {
    return error.retryAfter ?? const Duration(minutes: 1);
  }
  if (error is TaskRemoteError && error.retryable) {
    return error.retryAfter ?? const Duration(minutes: 1);
  }
  if (error is GoogleCalendarApiError &&
      (error.isRateLimited || error.statusCode >= 500)) {
    return error.retryAfter ?? const Duration(minutes: 1);
  }
  if (error is MicrosoftCalendarApiError &&
      (error.isRateLimited || error.statusCode >= 500)) {
    return error.retryAfter ?? const Duration(minutes: 1);
  }
  if (error is MicrosoftTodoApiError &&
      (error.statusCode == 429 || error.statusCode >= 500)) {
    return error.retryAfter ?? const Duration(minutes: 1);
  }
  return null;
}

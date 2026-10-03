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
      await (maintainCached ?? deferred)();
      throw DomainCooldownException(domain, cooldown);
    }
    final last = _date(row?.lastSuccessfulPullUtc);
    final next = _date(row?.nextPassivePullUtc);
    final clockMovedBack = last != null && last.isAfter(now);
    final trigger = currentSyncTrigger;
    if (trigger == SyncTrigger.localMutation && !full) {
      await deferred();
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
      await deferred();
      return;
    }
    try {
      await pull();
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
      await database
          .into(database.domainSyncSchedules)
          .insertOnConflictUpdate(
            DomainSyncSchedulesCompanion.insert(
              accountId: id,
              domain: domain.name,
              lastSuccessfulPullUtc: Value(completed.toIso8601String()),
              nextPassivePullUtc: Value(
                completed.add(interval + jitter).toIso8601String(),
              ),
              cooldownUntilUtc: const Value(null),
            ),
          );
    } on Object catch (error) {
      final retry = retryTiming(error);
      if (retry != null) {
        final until = nowUtc().add(retry);
        final existing = _date(row?.cooldownUntilUtc);
        final effective = existing != null && existing.isAfter(until)
            ? existing
            : until;
        await database
            .into(database.domainSyncSchedules)
            .insertOnConflictUpdate(
              DomainSyncSchedulesCompanion.insert(
                accountId: id,
                domain: domain.name,
                lastSuccessfulPullUtc: Value(row?.lastSuccessfulPullUtc),
                nextPassivePullUtc: Value(row?.nextPassivePullUtc),
                cooldownUntilUtc: Value(effective.toIso8601String()),
              ),
            );
      }
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

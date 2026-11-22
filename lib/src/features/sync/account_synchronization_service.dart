import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/auth/authorization_persistence.dart';
import '../../core/http/request_dispatch_exception.dart';
import '../../dav/dav_errors.dart';
import '../../dav/mutation/dav_collection_creation_failure.dart';
import '../../dav/sync/dav_account_sync_engine.dart';
import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../../webcal/webcal_subscription_service.dart';
import '../accounts/data/accounts_repository.dart';
import 'account_sync_activity.dart';
import 'account_sync_operations.dart';
import 'calendar_sync_engine.dart';
import 'domain_sync_schedule.dart';
import 'sync_auth_error.dart';
import 'sync_engine.dart';
import 'sync_request.dart';

/// Coordinates account refreshes while provider engines own transport and replay.
final class AccountSynchronizationService {
  AccountSynchronizationService({
    required this.accounts,
    required this.database,
    required this.requireNetwork,
    required this.coordinator,
    required this.gate,
    required this.activity,
    required this.authorization,
    required this.webCalService,
    required this.davEngine,
    required this.tasksEngine,
    required this.calendarEngine,
    required this.loadDavCreationNotices,
    required this.discoverFederation,
    required this.onManualFailure,
    required this.clearAccountFailure,
  });

  final AccountsRepository accounts;
  final AppDatabase database;
  final Future<void> Function() requireNetwork;
  final AccountSyncCoordinator coordinator;
  final CrossEngineAccountGate gate;
  final AccountSyncActivity activity;
  final AuthorizationPersistence authorization;
  final WebCalSubscriptionService Function() webCalService;
  final DavAccountSyncEngine Function(String) davEngine;
  final SyncEngine Function(String, BusyProvider) tasksEngine;
  final CalendarSyncEngine Function(String, BusyProvider) calendarEngine;
  final Future<List<DavCollectionCreationFailure>> Function(
    String,
    Map<String, DavException>,
  )
  loadDavCreationNotices;
  final Future<void> Function(String, bool) discoverFederation;
  final Future<void> Function(String, Object) onManualFailure;
  final Future<void> Function(String) clearAccountFailure;

  late final ScopedAccountSyncOperations operations =
      RequestAccountSyncOperations(_execute);

  Future<Set<SyncScope>> _davProjections(String accountId, String id) async {
    final calendars =
        await (database.select(database.calendarSources)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.davCollectionId.equals(id) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final tasks =
        await (database.select(database.taskLists)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.davCollectionId.equals(id) &
                  row.serverMissing.equals(false),
            ))
            .get();
    return {
      for (final source in calendars) calendarSyncScope(accountId, source.id),
      for (final list in tasks) taskListSyncScope(accountId, list.id),
    };
  }

  Future<SyncOutcome> _executeForAccount(
    SyncRequest request,
    AccountEntity account,
  ) async {
    final scope = request.scope;
    final id = account.id;
    if (account.provider == BusyProvider.webCal) {
      return _syncWebCal(request, account);
    }
    if (account.provider.isDav) return _syncDav(request, account);
    switch (scope.kind) {
      case SyncScopeKind.calendarSource:
      case SyncScopeKind.calendar:
        return _syncRestDomain(account, SyncDomain.calendar, request);
      case SyncScopeKind.tasks:
      case SyncScopeKind.taskList:
        return _syncRestDomain(account, SyncDomain.tasks, request);
      case SyncScopeKind.account:
        final children = [
          for (final domain in SyncDomain.values)
            await _syncRestDomain(account, domain, (
              origin: request.origin,
              strategy: request.strategy,
              scope: _domainScope(id, domain),
            )),
        ];
        final failures = {
          for (final child in children)
            if (child.error case final error?)
              (child.request.scope.kind == SyncScopeKind.tasks
                      ? 'tasks'
                      : 'calendar'):
                  error,
        };
        final successful = {
          for (final child in children)
            if (child.disposition == SyncDisposition.completed)
              child.request.scope.kind == SyncScopeKind.tasks
                  ? 'tasks'
                  : 'calendar',
        };
        return SyncOutcome(
          request,
          summarizeSyncOutcomes(children),
          affected: children.expand((child) => child.affected),
          completedResources: children.expand(
            (child) => child.completedResources,
          ),
          children: children,
          error: failures.isEmpty
              ? null
              : PartialAccountSyncException(failures, successful),
        );
      case SyncScopeKind.all:
      case SyncScopeKind.subscription:
      case SyncScopeKind.davCollection:
        return SyncOutcome(request, SyncDisposition.missing);
    }
  }

  Future<SyncOutcome> _syncWebCal(
    SyncRequest request,
    AccountEntity account,
  ) async {
    final scope = request.scope;
    final id = account.id;
    final resource = scope.resourceId;
    final affected = <SyncScope>{};
    if (!account.calendarsEnabled ||
        scope.kind == SyncScopeKind.tasks ||
        scope.kind == SyncScopeKind.taskList ||
        request.origin == SyncTrigger.localMutation) {
      return SyncOutcome(request, SyncDisposition.disabled);
    }
    final service = webCalService();
    final subscription = await service.subscriptionForAccount(id);
    if (subscription == null ||
        scope.kind == SyncScopeKind.subscription &&
            resource != subscription.id ||
        scope.kind == SyncScopeKind.calendarSource &&
            resource != subscription.calendarSourceId) {
      return SyncOutcome(request, SyncDisposition.missing);
    }
    final source = calendarSyncScope(id, subscription.calendarSourceId);
    final subscriptionScope = (
      kind: SyncScopeKind.subscription,
      accountId: id,
      resourceId: subscription.id,
    );
    try {
      final outcome = await service.checkSubscription(
        subscription.id,
        accountId: id,
        manual: request.origin == SyncTrigger.manual,
        trackCheck: (check) {
          affected.add(source);
          return activity.run(
            id,
            'webcal',
            () => activity.resource([source], () async {
              final result = await check();
              if (result == SyncDisposition.failed) {
                throw const WebCalSubscriptionException(
                  'WebCalSecretUnavailable',
                );
              }
              return result;
            }),
          );
        },
      );
      return SyncOutcome(
        request,
        outcome,
        affected: affected,
        completedResources: outcome == SyncDisposition.completed
            ? [source, subscriptionScope]
            : const [],
      );
    } on Object catch (error) {
      return SyncOutcome(
        request,
        SyncDisposition.failed,
        affected: affected,
        error: error,
      );
    }
  }

  Future<SyncOutcome> _syncDav(
    SyncRequest request,
    AccountEntity account,
  ) async {
    final scope = request.scope;
    final id = account.id;
    final resource = scope.resourceId;
    final full = request.strategy == SyncStrategy.fullRecovery;
    final affected = <SyncScope>{};
    final completedResources = <SyncScope>{};
    final domain = switch (scope.kind) {
      SyncScopeKind.calendar => SyncDomain.calendar,
      SyncScopeKind.tasks => SyncDomain.tasks,
      _ => null,
    };
    final accountWide = scope.kind == SyncScopeKind.account;
    if (domain == SyncDomain.calendar && !account.calendarsEnabled ||
        domain == SyncDomain.tasks && !account.tasksEnabled) {
      return SyncOutcome(request, SyncDisposition.disabled);
    }
    String? collection;
    if (resource != null) {
      final task = scope.kind == SyncScopeKind.taskList;
      final physical = scope.kind == SyncScopeKind.davCollection;
      if (!physical &&
          (task ? !account.tasksEnabled : !account.calendarsEnabled)) {
        return SyncOutcome(request, SyncDisposition.disabled);
      }
      if (physical) {
        collection = resource;
      } else if (task) {
        final list =
            await (database.select(database.taskLists)..where(
                  (row) => row.accountId.equals(id) & row.id.equals(resource),
                ))
                .getSingleOrNull();
        if (list?.pendingDelete == true) {
          return SyncOutcome(request, SyncDisposition.disabled);
        }
        collection = list?.davCollectionId;
      } else {
        final source =
            await (database.select(database.calendarSources)..where(
                  (row) =>
                      row.accountId.equals(id) &
                      row.id.equals(resource) &
                      row.isDeleted.equals(false),
                ))
                .getSingleOrNull();
        collection = source?.davCollectionId;
      }
      if (collection == null) {
        return SyncOutcome(request, SyncDisposition.missing);
      }
      final row =
          await (database.select(database.davCollections)..where(
                (row) => row.accountId.equals(id) & row.id.equals(collection!),
              ))
              .getSingleOrNull();
      if (row == null || row.deleted || row.serverMissing) {
        return SyncOutcome(request, SyncDisposition.missing);
      }
      final eventsEnabled =
          account.calendarsEnabled &&
          row.eventProjectionEnabled &&
          row.eventsSelected;
      final tasksEnabled =
          account.tasksEnabled &&
          row.taskProjectionEnabled &&
          row.tasksSelected;
      final selected = physical
          ? eventsEnabled || tasksEnabled
          : task
          ? tasksEnabled
          : eventsEnabled;
      if (!selected) return SyncOutcome(request, SyncDisposition.disabled);
    }
    if (!account.tasksEnabled && !account.calendarsEnabled) {
      return SyncOutcome(request, SyncDisposition.disabled);
    }
    final dispatchOnly = request.origin == SyncTrigger.localMutation;
    final physicalId = collection;
    final engine = davEngine(id);
    var completed = false;
    try {
      final result = await activity.run(
        id,
        domain?.name ?? 'dav',
        () async {
          Future<DavAccountSyncResult> pull() => engine.synchronize(
            full: full,
            collectionId: physicalId,
            projection: physicalId == null ? null : scope.kind,
            domain: domain,
            dispatchOnly: dispatchOnly,
            trackCollection: (collectionId, work) async {
              final projections = await _davProjections(id, collectionId);
              projections.add(davCollectionSyncScope(id, collectionId));
              affected.addAll(projections);
              // A failed readback supersedes an earlier successful pull.
              completedResources.removeAll(projections);
              await activity.resource(projections, work);
              completedResources.addAll(projections);
            },
          );
          Future<DavAccountSyncResult> synchronize() async {
            if (physicalId == null) return pull();
            final projections = await _davProjections(id, physicalId);
            return activity.resource(projections, pull, resolveFailure: false);
          }

          final result = dispatchOnly || !account.tasksEnabled
              ? await synchronize()
              : await coordinator.trackTaskImport(
                  id,
                  synchronize,
                  coversAccount: accountWide,
                  coversPriorImport: (result) =>
                      result.disposition == SyncDisposition.completed,
                );
          completed =
              physicalId == null &&
              result.disposition == SyncDisposition.completed;
          return result;
        },
        clearFailureOnSuccess: () => completed,
        rememberFailure: (_) => physicalId == null,
      );
      for (final collectionId in result.affectedCollectionIds) {
        affected.addAll(await _davProjections(id, collectionId));
      }
      if (accountWide && !dispatchOnly) {
        activity.setCollectionCreationFailures(
          id,
          await loadDavCreationNotices(id, result.collectionCreationFailures),
        );
        if (account.provider == BusyProvider.nextcloud) {
          unawaited(
            Future<void>.sync(() => discoverFederation(id, full))
                .catchError((Object _, StackTrace _) {}),
          );
        }
      }
      return SyncOutcome(
        request,
        result.disposition,
        affected: affected,
        completedResources: completedResources,
        children: [
          if (accountWide && result.disposition == SyncDisposition.completed)
            for (final domain in SyncDomain.values)
              if (_domainEnabled(account, domain))
                SyncOutcome((
                  scope: _domainScope(id, domain),
                  origin: request.origin,
                  strategy: request.strategy,
                ), SyncDisposition.completed),
        ],
      );
    } on DavException catch (error) {
      return SyncOutcome(
        request,
        error.kind == DavErrorKind.cancelled
            ? SyncDisposition.cancelled
            : SyncDisposition.failed,
        affected: affected,
        completedResources: completedResources,
        error: error.kind == DavErrorKind.cancelled ? null : error,
      );
    } on Object catch (error) {
      return SyncOutcome(
        request,
        affected.isEmpty ? SyncDisposition.failed : SyncDisposition.partial,
        affected: affected,
        completedResources: completedResources,
        error: error,
      );
    }
  }

  Future<SyncOutcome> _syncRestDomain(
    AccountEntity account,
    SyncDomain domain,
    SyncRequest domainRequest,
  ) async {
    final id = account.id;
    final resource = domainRequest.scope.resourceId;
    final full = domainRequest.strategy == SyncStrategy.fullRecovery;
    final task = domain == SyncDomain.tasks;
    final domainAffected = <SyncScope>{};
    final completedResources = <SyncScope>{};
    final kind = task ? taskListSyncScope : calendarSyncScope;
    if (task ? !account.tasksEnabled : !account.calendarsEnabled) {
      return SyncOutcome(domainRequest, SyncDisposition.disabled);
    }
    final policy = DomainSyncPolicy(database);
    var result = SyncDisposition.deferred;
    var pulled = false;
    SyncDeferral? deferral;
    try {
      await activity.run(
        id,
        domain.name,
        () async {
          final tasks = task ? tasksEngine(id, account.provider) : null;
          final calendars = task ? null : calendarEngine(id, account.provider);
          final scheduled = await policy.run(
            id,
            domain,
            full: full,
            completeDomain: resource == null,
            deferred: resource == null
                ? (tasks?.dispatchPendingWrites ??
                      calendars!.dispatchPendingWrites)
                : () async {},
            maintainCached:
                tasks?.maintainCachedReminders ??
                calendars!.maintainCachedReminders,
            pull: () async {
              try {
                if (resource != null) {
                  void touched(String value) =>
                      domainAffected.add(kind(id, value));
                  Future<void> trackWrite(
                    Set<String> ids,
                    Future<void> Function() write,
                  ) => activity.resource(
                    ids.map((value) => kind(id, value)),
                    write,
                    resolveFailure: false,
                  );
                  if (tasks != null) {
                    result = await coordinator.trackTaskImport(
                      id,
                      () async {
                        final disposition = await tasks.refreshList(
                          resource,
                          onAffected: touched,
                          trackWrite: trackWrite,
                        );
                        if (disposition == SyncDisposition.deferred) {
                          throw const ScopedSyncDeferred();
                        }
                        return disposition;
                      },
                      coversAccount: false,
                      changedOnFailure: () => tasks.remoteImportWroteData,
                    );
                  } else {
                    result = await calendars!.refreshSource(
                      resource,
                      full: full,
                      onAffected: touched,
                      trackWrite: trackWrite,
                    );
                  }
                } else if (tasks != null) {
                  await coordinator.trackTaskImport(
                    id,
                    full ? tasks.fullSync : tasks.incrementalSync,
                    changedOnFailure: () => tasks.remoteImportWroteData,
                  );
                  result = SyncDisposition.completed;
                } else {
                  await (full
                      ? calendars!.fullSync()
                      : calendars!.incrementalSync());
                  result = SyncDisposition.completed;
                }
              } finally {
                domainAffected.addAll(
                  (tasks?.affectedCollectionIds ??
                          calendars!.affectedCollectionIds)
                      .map((value) => kind(id, value)),
                );
                completedResources.addAll(
                  (tasks?.completedCollectionIds ??
                          calendars!.completedCollectionIds)
                      .map((value) => kind(id, value)),
                );
              }
            },
          );
          if (scheduled == DomainSyncDisposition.deferred) {
            deferral = SyncDeferral.scheduled;
          }
          if (scheduled == DomainSyncDisposition.skipped) {
            result = SyncDisposition.disabled;
          }
          pulled =
              scheduled == DomainSyncDisposition.pulled &&
              resource == null &&
              result == SyncDisposition.completed;
          if (pulled) {
            final pending =
                await (database.select(database.pendingOps)
                      ..where(
                        (row) =>
                            row.accountId.equals(id) &
                            row.entityType.isIn(
                              task
                                  ? const [
                                      'task',
                                      'task_list',
                                      'task_checklist_item',
                                    ]
                                  : const ['calendar', 'event'],
                            ),
                      )
                      ..limit(1))
                    .get();
            if (pending.isNotEmpty) {
              result = SyncDisposition.deferred;
              deferral = SyncDeferral.pendingWrites;
            }
          }
        },
        clearFailureOnSuccess: () => pulled,
        rememberFailure: (error) =>
            resource == null && error is! DomainCooldownException,
      );
      return SyncOutcome(
        domainRequest,
        result,
        affected: domainAffected,
        completedResources: completedResources,
        deferral: deferral,
      );
    } on ScopedSyncDeferred {
      return SyncOutcome(
        domainRequest,
        SyncDisposition.deferred,
        affected: domainAffected,
        completedResources: completedResources,
      );
    } on DomainCooldownException catch (error) {
      return SyncOutcome(
        domainRequest,
        SyncDisposition.deferred,
        affected: domainAffected,
        completedResources: completedResources,
        error: error,
      );
    } on Object catch (error) {
      return SyncOutcome(
        domainRequest,
        SyncDisposition.failed,
        affected: domainAffected,
        completedResources: completedResources,
        error: error,
      );
    }
  }

  Future<SyncOutcome> _execute(SyncRequest request) =>
      activity.request(request, (start) async {
        final id = request.scope.accountId;
        if (request.scope.kind == SyncScopeKind.all) {
          return start(() async {
            final eligible = await accounts.listSyncEligibleAccounts();
            final children = await Future.wait([
              for (final account in eligible)
                operations.execute((
                  scope: accountSyncScope(account.id),
                  origin: request.origin,
                  strategy: request.strategy,
                )),
            ]);
            return SyncOutcome(
              request,
              summarizeSyncOutcomes(children),
              affected: children.expand((child) => child.affected),
              completedResources: children.expand(
                (child) => child.completedResources,
              ),
              children: children,
              error: children.map((child) => child.error).nonNulls.firstOrNull,
            );
          });
        }
        if (id == null) return SyncOutcome(request, SyncDisposition.missing);
        final generation = await authorization.generation(id);
        return gate.run(
          id,
          () => coordinator.run(
            id,
            () => start(() async {
              if (generation != await authorization.generation(id)) {
                return SyncOutcome(request, SyncDisposition.cancelled);
              }
              final account = await accounts.accountById(id);
              if (account == null) {
                return SyncOutcome(request, SyncDisposition.missing);
              }
              if (!account.isSyncEligible) {
                return SyncOutcome(
                  request,
                  SyncDisposition.disabled,
                  error: request.origin == SyncTrigger.manual
                      ? AccountNotSyncEligibleException(
                          needsReconnect: account.needsReconnect,
                        )
                      : null,
                );
              }
              SyncOutcome result;
              try {
                await requireNetwork();
                result = await withSyncTrigger(
                  request.origin,
                  () => _executeForAccount(request, account),
                );
              } on Object catch (error) {
                result = SyncOutcome(
                  request,
                  SyncDisposition.failed,
                  error: error,
                );
              }
              if (result.error case final error?) {
                final scoped = AuthorizationScopedFailure(
                  accountId: id,
                  generation: generation,
                  cause: error,
                );
                if (request.origin == SyncTrigger.manual) {
                  await onManualFailure(id, scoped);
                }
                return SyncOutcome(
                  request,
                  result.disposition,
                  affected: result.affected,
                  completedResources: result.completedResources,
                  children: result.children,
                  error: scoped,
                );
              }
              if (request.scope.kind == SyncScopeKind.account &&
                  result.disposition == SyncDisposition.completed &&
                  generation == await authorization.generation(id)) {
                final now = DateTime.now().toUtc().toIso8601String();
                await database
                    .into(database.domainSyncSchedules)
                    .insertOnConflictUpdate(
                      DomainSyncSchedulesCompanion.insert(
                        accountId: id,
                        domain: accountRefreshHistoryKey,
                        lastSuccessfulPullUtc: Value(now),
                      ),
                    );
                await clearAccountFailure(id);
              }
              return result;
            }),
          ),
        );
      });
}

SyncScope _domainScope(String id, SyncDomain domain) => (
  kind: domain == SyncDomain.tasks
      ? SyncScopeKind.tasks
      : SyncScopeKind.calendar,
  accountId: id,
  resourceId: null,
);

bool _domainEnabled(AccountEntity account, SyncDomain domain) =>
    domain == SyncDomain.tasks
    ? account.tasksEnabled
    : account.calendarsEnabled;

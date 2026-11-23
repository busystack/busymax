import 'package:flutter/foundation.dart';

import '../../dav/mutation/dav_collection_creation_failure.dart';
import 'sync_request.dart';
import 'domain_sync_schedule.dart';

/// Current-process outcomes are separate from durable successful pull times.
/// A deferred pull never manufactures a new successful synchronization date.
class AccountSyncActivity extends ChangeNotifier {
  final _running = <(String, String), int>{};
  final _failures = <(String, String), Object>{};
  final _collectionCreationFailures =
      <String, Map<String, DavCollectionCreationFailure>>{};
  final _queued = <SyncScope, int>{};
  final _executing = <SyncScope, int>{};
  final _outcomes = <SyncScope, SyncOutcome>{};
  final _resourceFailures = <SyncScope, Object>{};

  Set<SyncScope> _external = const {};

  Set<SyncScope> get localExecutingScopes => Set.unmodifiable(_executing.keys);

  void setExternalExecuting(Iterable<SyncScope> values) {
    final next = values.toSet();
    if (setEquals(next, _external)) return;
    _external = next;
    _notify();
  }

  bool get anyRunning =>
      _queued.isNotEmpty ||
      _executing.isNotEmpty ||
      _running.isNotEmpty ||
      _external.isNotEmpty;

  bool accountRunning(String id) =>
      _queued.keys.any((key) => key.accountId == id) ||
      _executing.keys.any((key) => key.accountId == id) ||
      _running.keys.any((key) => key.$1 == id) ||
      _external.any((scope) => scope.accountId == id);

  bool queued(SyncScope scope) => _queued.containsKey(scope);
  bool executing(SyncScope scope) =>
      _executing.containsKey(scope) || _external.contains(scope);
  bool busy(SyncScope scope) => queued(scope) || executing(scope);
  SyncOutcome? outcome(SyncScope scope) => _outcomes[scope];
  Object? resourceFailure(SyncScope scope) => _resourceFailures[scope];
  bool accountHasFailure(String id) =>
      _resourceFailures.keys.any((scope) => scope.accountId == id) ||
      _failures.keys.any((key) => key.$1 == id) ||
      _outcomes.entries.any(
        (entry) => entry.key.accountId == id && entry.value.hasFailure,
      );

  bool accountNeedsAttention(String id) =>
      accountHasFailure(id) ||
      _outcomes.entries.any(
        (entry) => entry.key.accountId == id && entry.value.needsAttention,
      );

  void _adjust(Map<SyncScope, int> state, SyncScope key, int delta) {
    final count = (state[key] ?? 0) + delta;
    if (count == 0) {
      state.remove(key);
    } else {
      state[key] = count;
    }
    _notify();
  }

  Future<SyncOutcome> request(
    SyncRequest request,
    Future<SyncOutcome> Function(
      Future<SyncOutcome> Function(Future<SyncOutcome> Function()) start,
    )
    queue,
  ) async {
    final scope = request.scope;
    _adjust(_queued, scope, 1);
    var started = false;
    try {
      final outcome = await queue((work) async {
        started = true;
        _adjust(_executing, scope, 1);
        _adjust(_queued, scope, -1);
        try {
          final result = await work();
          // Settle while this request still owns the account gate.
          _recordOutcome(request, result);
          return result;
        } on Object catch (error) {
          _recordOutcome(
            request,
            SyncOutcome(request, SyncDisposition.failed, error: error),
          );
          rethrow;
        } finally {
          _adjust(_executing, scope, -1);
        }
      });
      if (!started) _recordOutcome(request, outcome);
      return outcome;
    } on Object catch (error) {
      final outcome = SyncOutcome(
        request,
        SyncDisposition.failed,
        error: error,
      );
      if (!started) _recordOutcome(request, outcome);
      return outcome;
    } finally {
      if (!started) _adjust(_queued, scope, -1);
      _notify();
    }
  }

  void _recordOutcome(SyncRequest request, SyncOutcome outcome) {
    final scope = request.scope;
    if (scope.accountId case final id?) {
      for (final resource in outcome.completedResources) {
        if (resource.accountId == id && resource.resourceId != null) {
          _clearOutcome(resource);
        }
      }
      if (scope.kind == SyncScopeKind.account) {
        for (final child in outcome.children) {
          final covered = child.request.scope;
          if (covered.accountId == id &&
              _domainFor(covered) != null &&
              child.disposition != SyncDisposition.disabled) {
            _recordDomainOutcome(id, covered, child);
          }
        }
      } else if (_domainFor(scope) != null) {
        _recordDomainOutcome(id, scope, outcome);
        _pruneResolvedOutcome(accountSyncScope(id));
        _pruneResolvedOutcome(allSyncScope);
        return;
      }
    }
    if (outcome.disposition == SyncDisposition.completed) {
      _clearOutcome(scope);
    } else {
      // A recovered child can clear an old error even if queued writes keep
      // the aggregate actionable.
      if (outcome.children.isNotEmpty) _pruneResolvedOutcome(scope);
      if (outcome.needsAttention) _retainOutcome(scope, outcome);
    }
    if (scope.kind == SyncScopeKind.account) {
      _pruneResolvedOutcome(allSyncScope);
    }
  }

  void _clearOutcome(SyncScope scope) {
    _outcomes.remove(scope);
    _resourceFailures.remove(scope);
  }

  SyncDomain? _domainFor(SyncScope scope) => switch (scope.kind) {
    SyncScopeKind.calendar => SyncDomain.calendar,
    SyncScopeKind.tasks => SyncDomain.tasks,
    _ => null,
  };

  void _recordDomainOutcome(String id, SyncScope scope, SyncOutcome outcome) {
    if (outcome.disposition == SyncDisposition.completed) {
      _clearOutcome(scope);
      _failures.remove((id, _domainFor(scope)!.name));
    } else if (outcome.deferral == SyncDeferral.pendingWrites) {
      // A verified pull clears the earlier pull failure. The unresolved
      // writes retain their own status and durable replay information.
      _clearOutcome(scope);
      _outcomes[scope] = outcome;
    } else if (outcome.needsAttention) {
      _retainOutcome(scope, outcome);
    }
  }

  void _retainOutcome(SyncScope scope, SyncOutcome outcome) {
    final previous = _outcomes[scope];
    if (previous == null ||
        !(previous.hasFailure || previous.error != null) ||
        outcome.hasFailure ||
        outcome.error != null) {
      _outcomes[scope] = outcome;
    }
  }

  void _pruneResolvedOutcome(SyncScope scope) {
    final previous = _outcomes[scope];
    if (previous == null || previous.children.isEmpty) return;
    final remaining = [
      for (final child in previous.children)
        if (_outcomes[child.request.scope] case final retained?) retained,
    ];
    if (remaining.isEmpty) {
      _clearOutcome(scope);
    } else if (previous.children.any(
      (child) =>
          !identical(_outcomes[child.request.scope], child) &&
          child.needsAttention,
    )) {
      _outcomes[scope] = SyncOutcome(
        previous.request,
        SyncDisposition.partial,
        children: remaining,
        error: remaining.map((child) => child.error).nonNulls.firstOrNull,
      );
    }
  }

  Future<T> resource<T>(
    Iterable<SyncScope> scopes,
    Future<T> Function() work, {
    bool resolveFailure = true,
  }) async {
    final keys = scopes.toSet();
    for (final key in keys) {
      _adjust(_executing, key, 1);
    }
    try {
      final result = await work();
      if (resolveFailure) {
        for (final key in keys) {
          _resourceFailures.remove(key);
        }
      }
      return result;
    } on Object catch (error) {
      if (resolveFailure) {
        for (final key in keys) {
          _resourceFailures[key] = error;
        }
      }
      rethrow;
    } finally {
      for (final key in keys) {
        _adjust(_executing, key, -1);
      }
    }
  }

  bool _disposed = false;

  bool isRunning(String id, String domain) => (_running[(id, domain)] ?? 0) > 0;
  Object? failure(String id, String domain) => _failures[(id, domain)];

  Map<String, DavCollectionCreationFailure> collectionCreationFailures(
    String id,
  ) => _collectionCreationFailures[id] ?? const {};

  void setCollectionCreationFailures(
    String id,
    Iterable<DavCollectionCreationFailure> failures,
  ) {
    final values = {
      for (final failure in failures) failure.operation.id: failure,
    };
    if (values.isEmpty) {
      _collectionCreationFailures.remove(id);
    } else {
      _collectionCreationFailures[id] = Map.unmodifiable(values);
    }
    _notify();
  }

  Future<T> run<T>(
    String id,
    String domain,
    Future<T> Function() work, {
    bool Function()? clearFailureOnSuccess,
    bool Function(Object)? rememberFailure,
  }) async {
    final key = (id, domain);
    _running.update(key, (count) => count + 1, ifAbsent: () => 1);
    _notify();
    try {
      final result = await work();
      // Dispatching queued writes alone does not confirm that a failed pull
      // recovered. The caller knows whether a fresh pull actually completed.
      if (clearFailureOnSuccess?.call() ?? true) {
        _failures.remove(key);
      }
      return result;
    } on Object catch (error) {
      if (rememberFailure?.call(error) ?? true) _failures[key] = error;
      rethrow;
    } finally {
      final count = (_running[key] ?? 1) - 1;
      if (count == 0) {
        _running.remove(key);
      } else {
        _running[key] = count;
      }
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

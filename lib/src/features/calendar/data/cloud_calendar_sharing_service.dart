import 'dart:math';

import '../../../core/http/request_dispatch_exception.dart';
import '../../../google_calendar/google_calendar_api_client.dart';
import '../../../google_calendar/google_calendar_models.dart';
import '../../../google_calendar/google_calendar_errors.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../../microsoft_calendar/microsoft_calendar_models.dart';
import '../../../microsoft_calendar/microsoft_shared_calendar_address.dart';
import '../../../providers/busy_provider.dart';
import 'calendar_repository.dart';

/// A permission row retains the provider object required for a later mutation.
/// Roles are deliberately not translated into an allegedly universal model.
final class CloudCalendarShareGrant {
  const CloudCalendarShareGrant({
    required this.id,
    required this.recipient,
    required this.role,
    required this.allowedRoles,
    required this.canChange,
    required this.canRevoke,
    this.googleRule,
    this.microsoftPermission,
  });

  final String id;
  final String recipient;
  final String role;
  final List<String> allowedRoles;
  final bool canChange;
  final bool canRevoke;
  final GoogleAclRule? googleRule;
  final MicrosoftCalendarPermission? microsoftPermission;
}

final class CloudCalendarShareSnapshot {
  const CloudCalendarShareSnapshot(
    this.grants, {
    this.refreshError,
    this.outcomeUnknown = false,
  });

  final List<CloudCalendarShareGrant> grants;

  /// A committed mutation must not be reported as failed just because the
  /// follow-up read failed. The returned grants contain the acknowledged row.
  final Object? refreshError;
  final bool outcomeUnknown;
}

/// A rejected sharing write may be retried explicitly after this delay.
/// It is separate from an uncertain write that requires reconciliation.
final class CloudCalendarSharingCooldownException implements Exception {
  const CloudCalendarSharingCooldownException(this.retryAfter);

  final Duration retryAfter;

  @override
  String toString() => 'Calendar sharing is rate-limited. Try again later.';
}

typedef _ShareScope = ({
  BusyProvider provider,
  String accountId,
  String calendarId,
});

enum _ShareMutationKind { add, change, revoke }

final class _PendingShareMutation {
  _PendingShareMutation({
    required this.kind,
    required this.recipient,
    required this.role,
    required this.grantId,
    required this.baselineIds,
    required this.visibleGrants,
  });

  final _ShareMutationKind kind;
  final String recipient;
  final String? role;
  final String? grantId;
  final Set<String> baselineIds;
  List<CloudCalendarShareGrant> visibleGrants;
  bool dispatching = true;
}

final class _ShareCooldown {
  const _ShareCooldown({required this.until, required this.attempts});

  final DateTime until;
  final int attempts;
}

final class CloudCalendarSharingService {
  // A reopened native view gets a new service object. Keep uncertain intent
  // scoped to the provider account and calendar until an authoritative read
  // resolves it; never infer failure from a missing or failed list response.
  static final Map<_ShareScope, _PendingShareMutation> _pending = {};
  static final Map<_ShareScope, _ShareCooldown> _cooldowns = {};
  CloudCalendarSharingService({
    required this.source,
    this.google,
    this.microsoft,
    DateTime Function()? now,
  }) {
    _now = now ?? DateTime.now;
    if (!canManageSource(source)) {
      throw StateError('Calendar sharing management is unavailable.');
    }
    if (source.provider == BusyProvider.google && google == null ||
        source.provider == BusyProvider.microsoft && microsoft == null) {
      throw StateError('Calendar sharing client is unavailable.');
    }
  }

  final CalendarSourceEntity source;
  final GoogleCalendarApiClient? google;
  final MicrosoftCalendarApiClient? microsoft;
  late final DateTime Function() _now;
  List<CloudCalendarShareGrant> _grants = const [];
  bool _loaded = false;

  _ShareScope get _scope => (
    provider: source.provider,
    accountId: source.accountId,
    calendarId: source.providerCalendarId,
  );

  bool get hasUnresolvedOutcome => _pending.containsKey(_scope);

  Duration? get retryAfter {
    final cooldown = _cooldowns[_scope];
    if (cooldown == null) return null;
    final remaining = cooldown.until.difference(_now());
    return remaining > Duration.zero ? remaining : null;
  }

  bool get isRateLimited => retryAfter != null;

  static bool canManageSource(CalendarSourceEntity source) =>
      !source.isDeleted &&
      !source.pendingCreate &&
      switch (source.provider) {
        BusyProvider.google => source.accessRole == 'owner',
        BusyProvider.microsoft =>
          source.primaryCalendar &&
              MicrosoftSharedPrimaryCalendarAddress.parse(
                    source.providerCalendarId,
                  ) ==
                  null,
        _ => false,
      };

  List<String> get newGrantRoles => source.provider == BusyProvider.google
      ? const [
          'freeBusyReader',
          'reader',
          'writerWithoutPrivateAccess',
          'writer',
        ]
      : const ['freeBusyRead', 'limitedRead', 'read', 'write'];

  Future<CloudCalendarShareSnapshot> load() async {
    final pending = _pending[_scope];
    if (pending != null && pending.dispatching) {
      _grants = pending.visibleGrants;
      _loaded = true;
      return CloudCalendarShareSnapshot(_grants, outcomeUnknown: true);
    }
    try {
      final grants = await _fetchGrants();
      _grants = List.unmodifiable(grants);
      _loaded = true;
      if (pending != null) {
        pending.visibleGrants = _grants;
        if (_confirmsIntent(pending, _grants) &&
            identical(_pending[_scope], pending)) {
          _pending.remove(_scope);
        }
      }
      return CloudCalendarShareSnapshot(
        _grants,
        outcomeUnknown: _pending.containsKey(_scope),
      );
    } on Object catch (error) {
      if (pending == null) rethrow;
      _grants = pending.visibleGrants;
      _loaded = true;
      return CloudCalendarShareSnapshot(
        _grants,
        refreshError: error,
        outcomeUnknown: true,
      );
    }
  }

  Future<List<CloudCalendarShareGrant>> _fetchGrants() async =>
      source.provider == BusyProvider.google
      ? [
          for (final rule in await google!.listAclRules(
            source.providerCalendarId,
          ))
            _googleGrant(rule),
        ]
      : [
          for (final permission
              in await microsoft!.listPrimaryCalendarPermissions())
            _microsoftGrant(permission),
        ];

  Future<CloudCalendarShareSnapshot> add({
    required String recipient,
    required String role,
  }) async {
    if (!newGrantRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported sharing role.');
    }
    final target = recipient.trim();
    if (_grants.any(
      (grant) => grant.recipient.toLowerCase() == target.toLowerCase(),
    )) {
      throw StateError('This recipient already has a calendar grant.');
    }
    final pending = _begin(
      kind: _ShareMutationKind.add,
      recipient: target,
      role: role,
    );
    late final CloudCalendarShareGrant grant;
    try {
      grant = source.provider == BusyProvider.google
          ? _googleGrant(
              await google!.addAclUser(
                source.providerCalendarId,
                email: target,
                role: role,
              ),
            )
          : _microsoftGrant(
              await microsoft!.addPrimaryCalendarPermission(
                email: target,
                role: role,
              ),
            );
    } on Object catch (error) {
      if (_isKnownUncommittedFailure(error)) {
        _finishKnownFailure(pending, error);
        rethrow;
      }
      pending.dispatching = false;
      return load();
    }
    _finishAcknowledged(pending);
    _grants = List.unmodifiable([
      ..._grants.where((e) => e.id != grant.id),
      grant,
    ]);
    return _refreshAfterAcknowledgedMutation();
  }

  Future<CloudCalendarShareSnapshot> change(
    CloudCalendarShareGrant grant,
    String role,
  ) async {
    if (!grant.canChange || !grant.allowedRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'This role cannot be changed.');
    }
    final pending = _begin(
      kind: _ShareMutationKind.change,
      recipient: grant.recipient,
      role: role,
      grantId: grant.id,
    );
    late final CloudCalendarShareGrant updated;
    try {
      updated = source.provider == BusyProvider.google
          ? _googleGrant(
              await google!.changeAclRole(
                source.providerCalendarId,
                grant.googleRule!,
                role,
              ),
            )
          : _microsoftGrant(
              await microsoft!.changePrimaryCalendarPermission(
                grant.microsoftPermission!,
                role,
              ),
            );
    } on Object catch (error) {
      if (_isKnownUncommittedFailure(error)) {
        _finishKnownFailure(pending, error);
        rethrow;
      }
      pending.dispatching = false;
      return load();
    }
    _finishAcknowledged(pending);
    _grants = List.unmodifiable([
      for (final current in _grants) current.id == grant.id ? updated : current,
    ]);
    return _refreshAfterAcknowledgedMutation();
  }

  Future<CloudCalendarShareSnapshot> revoke(
    CloudCalendarShareGrant grant,
  ) async {
    if (!grant.canRevoke) {
      throw ArgumentError.value(grant.id, 'grant', 'Grant cannot be revoked.');
    }
    final pending = _begin(
      kind: _ShareMutationKind.revoke,
      recipient: grant.recipient,
      grantId: grant.id,
    );
    try {
      if (source.provider == BusyProvider.google) {
        await google!.revokeAclUser(
          source.providerCalendarId,
          grant.googleRule!,
        );
      } else {
        await microsoft!.revokePrimaryCalendarPermission(
          grant.microsoftPermission!,
        );
      }
    } on Object catch (error) {
      if (_isKnownUncommittedFailure(error)) {
        _finishKnownFailure(pending, error);
        rethrow;
      }
      pending.dispatching = false;
      return load();
    }
    _finishAcknowledged(pending);
    _grants = List.unmodifiable(_grants.where((e) => e.id != grant.id));
    return _refreshAfterAcknowledgedMutation();
  }

  Future<CloudCalendarShareSnapshot> _refreshAfterAcknowledgedMutation() async {
    try {
      return await load();
    } on Object catch (error) {
      return CloudCalendarShareSnapshot(_grants, refreshError: error);
    }
  }

  _PendingShareMutation _begin({
    required _ShareMutationKind kind,
    required String recipient,
    String? role,
    String? grantId,
  }) {
    if (!_loaded || _pending.containsKey(_scope)) {
      throw StateError(
        'Refresh and resolve this calendar sharing change before another mutation.',
      );
    }
    final remaining = retryAfter;
    if (remaining != null) {
      throw CloudCalendarSharingCooldownException(remaining);
    }
    if (grantId != null && !_grants.any((grant) => grant.id == grantId)) {
      throw StateError('This calendar grant is no longer in the loaded list.');
    }
    final pending = _PendingShareMutation(
      kind: kind,
      recipient: recipient,
      role: role,
      grantId: grantId,
      baselineIds: {for (final grant in _grants) grant.id},
      visibleGrants: _grants,
    );
    _pending[_scope] = pending;
    return pending;
  }

  bool _confirmsIntent(
    _PendingShareMutation pending,
    List<CloudCalendarShareGrant> grants,
  ) => switch (pending.kind) {
    _ShareMutationKind.add =>
      grants
                  .where(
                    (grant) =>
                        !pending.baselineIds.contains(grant.id) &&
                        grant.recipient.toLowerCase() ==
                            pending.recipient.toLowerCase() &&
                        grant.role == pending.role,
                  )
                  .length ==
              1 &&
          grants
                  .where(
                    (grant) =>
                        grant.recipient.toLowerCase() ==
                        pending.recipient.toLowerCase(),
                  )
                  .length ==
              1,
    _ShareMutationKind.change =>
      grants
              .where(
                (grant) =>
                    grant.id == pending.grantId && grant.role == pending.role,
              )
              .length ==
          1,
    _ShareMutationKind.revoke => !grants.any(
      (grant) => grant.id == pending.grantId,
    ),
  };

  bool _isKnownUncommittedFailure(Object error) => switch (error) {
    RequestNotDispatchedException _ => true,
    ArgumentError _ => true,
    GoogleCalendarApiError e when e.isRateLimited => true,
    MicrosoftCalendarApiError e when e.isRateLimited => true,
    GoogleCalendarApiError e
        when e.statusCode >= 400 &&
            e.statusCode < 500 &&
            !const {408, 409, 429}.contains(e.statusCode) =>
      true,
    MicrosoftCalendarApiError e
        when e.statusCode >= 400 &&
            e.statusCode < 500 &&
            !const {408, 409, 429}.contains(e.statusCode) =>
      true,
    _ => false,
  };

  void _finishKnownFailure(_PendingShareMutation pending, Object error) {
    if (!identical(_pending[_scope], pending)) return;
    _pending.remove(_scope);
    final serverDelay = switch (error) {
      GoogleCalendarApiError e when e.isRateLimited => e.retryAfter,
      MicrosoftCalendarApiError e when e.isRateLimited => e.retryAfter,
      _ => null,
    };
    if (error is GoogleCalendarApiError && error.isRateLimited ||
        error is MicrosoftCalendarApiError && error.isRateLimited) {
      final attempt = (_cooldowns[_scope]?.attempts ?? 0) + 1;
      // Explicit Retry-After is authoritative. Otherwise bound exponential
      // backoff with positive jitter, without silently resending a write.
      final baseMs = min(300000, 2000 * (1 << min(attempt - 1, 7)));
      final jitterMs = (baseMs * Random().nextDouble() / 4).round();
      final delay = serverDelay ?? Duration(milliseconds: baseMs + jitterMs);
      _cooldowns[_scope] = _ShareCooldown(
        until: _now().add(delay),
        attempts: attempt,
      );
    } else {
      _cooldowns.remove(_scope);
    }
  }

  void _finishAcknowledged(_PendingShareMutation pending) {
    if (!identical(_pending[_scope], pending)) return;
    _pending.remove(_scope);
    _cooldowns.remove(_scope);
  }

  CloudCalendarShareGrant _googleGrant(GoogleAclRule rule) {
    final mutable = rule.scopeType == 'user' && rule.role != 'owner';
    return CloudCalendarShareGrant(
      id: rule.id,
      recipient: rule.scopeValue ?? rule.scopeType,
      role: rule.role,
      allowedRoles: mutable ? newGrantRoles : const [],
      canChange: mutable,
      canRevoke: mutable,
      googleRule: rule,
    );
  }

  CloudCalendarShareGrant _microsoftGrant(
    MicrosoftCalendarPermission permission,
  ) {
    final mutable =
        permission.role != 'owner' &&
        permission.allowedRoles.any((role) => role != 'custom');
    return CloudCalendarShareGrant(
      id: permission.id,
      recipient: permission.address ?? permission.name ?? permission.id,
      role: permission.role,
      allowedRoles: [
        for (final role in permission.allowedRoles)
          if (role != 'custom') role,
      ],
      canChange: mutable,
      canRevoke: permission.role != 'owner' && permission.isRemovable,
      microsoftPermission: permission,
    );
  }
}

import '../../../google_calendar/google_calendar_api_client.dart';
import '../../../google_calendar/google_calendar_models.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
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
  const CloudCalendarShareSnapshot(this.grants, {this.refreshError});

  final List<CloudCalendarShareGrant> grants;

  /// A committed mutation must not be reported as failed just because the
  /// follow-up read failed. The returned grants contain the acknowledged row.
  final Object? refreshError;
}

final class CloudCalendarSharingService {
  CloudCalendarSharingService({
    required this.source,
    this.google,
    this.microsoft,
  }) {
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
  List<CloudCalendarShareGrant> _grants = const [];

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
    final grants = source.provider == BusyProvider.google
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
    _grants = List.unmodifiable(grants);
    return CloudCalendarShareSnapshot(_grants);
  }

  Future<CloudCalendarShareSnapshot> add({
    required String recipient,
    required String role,
  }) async {
    if (!newGrantRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported sharing role.');
    }
    final grant = source.provider == BusyProvider.google
        ? _googleGrant(
            await google!.addAclUser(
              source.providerCalendarId,
              email: recipient.trim(),
              role: role,
            ),
          )
        : _microsoftGrant(
            await microsoft!.addPrimaryCalendarPermission(
              email: recipient.trim(),
              role: role,
            ),
          );
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
    final updated = source.provider == BusyProvider.google
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
    if (source.provider == BusyProvider.google) {
      await google!.revokeAclUser(source.providerCalendarId, grant.googleRule!);
    } else {
      await microsoft!.revokePrimaryCalendarPermission(
        grant.microsoftPermission!,
      );
    }
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

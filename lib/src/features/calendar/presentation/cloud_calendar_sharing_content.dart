import '../application/cloud_calendar_sharing_session.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../providers/busy_provider.dart';
import '../data/calendar_repository.dart';
import '../data/cloud_calendar_sharing_service.dart';
import 'cloud_calendar_sharing_labels.dart';

/// Ubuntu-native permission management. Android and Windows provide their own
/// platform presentations over the same provider-specific service.
class CloudCalendarSharingContent extends ConsumerStatefulWidget {
  const CloudCalendarSharingContent({
    super.key,
    required this.sources,
    this.serviceFactory,
  });

  final List<CalendarSourceEntity> sources;
  final CloudCalendarSharingService Function(CalendarSourceEntity)?
  serviceFactory;

  @override
  ConsumerState<CloudCalendarSharingContent> createState() =>
      _CloudCalendarSharingContentState();
}

class _CloudCalendarSharingContentState
    extends ConsumerState<CloudCalendarSharingContent> {
  final _recipient = TextEditingController();
  late final _session = CloudCalendarSharingSession(_createService);
  String? _newRole;

  void _sessionChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
    if (widget.sources.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_select(widget.sources.first));
      });
    }
  }

  @override
  void didUpdateWidget(covariant CloudCalendarSharingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sources.length != widget.sources.length ||
        oldWidget.sources.any(
          (source) => !widget.sources.any((current) => current.id == source.id),
        )) {
      final selectedId = _session.source?.id;
      final next = widget.sources.where((source) => source.id == selectedId);
      unawaited(_select(next.firstOrNull ?? widget.sources.firstOrNull));
    }
  }

  @override
  void dispose() {
    _session.dispose();
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _select(CalendarSourceEntity? source) => _session.select(source);

  CloudCalendarSharingService _createService(CalendarSourceEntity source) {
    final service =
        widget.serviceFactory?.call(source) ??
        CloudCalendarSharingService(
          source: source,
          google: source.provider == BusyProvider.google
              ? ref.read(
                  googleCalendarApiClientForAccountProvider(source.accountId),
                )
              : null,
          microsoft: source.provider == BusyProvider.microsoft
              ? ref.read(
                  microsoftCalendarApiClientForAccountProvider(
                    source.accountId,
                  ),
                )
              : null,
        );
    _newRole = service.newGrantRoles.first;
    return service;
  }

  Future<CloudCalendarShareSnapshot?> _mutate(
    Future<CloudCalendarShareSnapshot> Function(CloudCalendarSharingService)
    action,
  ) async {
    final result = await _session.mutate(action);
    if (!mounted || result == null) return null;
    final warning = result.outcomeUnknown
        ? context.l10n.nextcloudOutcomeUnknown
        : result.refreshError != null
        ? context.l10n.sharingRefreshFailed
        : null;
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning)));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final service = _session.service;
    final grants = _session.snapshot?.grants;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sources.length > 1)
          BusyMaxMenuButton<String>(
            key: const Key('calendar-sharing-source'),
            tooltip:
                service?.source.summary ?? context.l10n.manageCalendarSharing,
            entries: [
              for (final source in widget.sources)
                BusyMaxMenuEntry(
                  value: source.id,
                  label: source.summary,
                  role: BusyMaxMenuEntryRole.radio,
                  selected: source.id == service?.source.id,
                ),
            ],
            onSelected: (id) => unawaited(
              _select(widget.sources.firstWhere((source) => source.id == id)),
            ),
            enabled: !_session.busy,
          ),
        if (_session.busy) const YaruCircularProgressIndicator(),
        if (_session.error != null) ...[
          SelectableText('${context.l10n.operationFailed}: ${_session.error}'),
          if (service != null)
            BusyMaxPushButton.standard(
              onPressed: _session.busy
                  ? null
                  : () => unawaited(_select(service.source)),
              child: Text(context.l10n.retry),
            ),
        ],
        if (service?.isRateLimited == true)
          Text(context.l10n.sharingRateLimited),
        if (_session.snapshot?.outcomeUnknown == true) ...[
          Text(context.l10n.nextcloudOutcomeUnknown),
          if (service != null)
            BusyMaxPushButton.standard(
              onPressed: _session.busy
                  ? null
                  : () => unawaited(_select(service.source)),
              child: Text(context.l10n.retry),
            ),
        ] else if (_session.snapshot?.refreshError != null) ...[
          Text(context.l10n.sharingRefreshFailed),
          if (service != null)
            BusyMaxPushButton.standard(
              onPressed: _session.busy
                  ? null
                  : () => unawaited(_select(service.source)),
              child: Text(context.l10n.retry),
            ),
        ],
        if (grants != null) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 290),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final grant in grants)
                  YaruListTile.square(
                    key: Key('calendar-sharing-grant-${grant.id}'),
                    title: Text(grant.recipient),
                    subtitle: Text(
                      calendarSharingRoleLabel(context.l10n, grant.role),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (grant.canChange)
                          BusyMaxMenuButton<String>(
                            tooltip: context.l10n.shareRole,
                            icon: const Icon(Icons.edit_outlined),
                            enabled:
                                !_session.busy &&
                                service?.isRateLimited != true &&
                                _session.snapshot?.refreshError == null &&
                                _session.snapshot?.outcomeUnknown != true,
                            entries: [
                              for (final role in grant.allowedRoles)
                                BusyMaxMenuEntry(
                                  value: role,
                                  label: calendarSharingRoleLabel(
                                    context.l10n,
                                    role,
                                  ),
                                ),
                            ],
                            onSelected: (role) => unawaited(
                              _mutate((service) => service.change(grant, role)),
                            ),
                          ),
                        if (grant.canRevoke)
                          BusyMaxPushButton.standard(
                            onPressed:
                                _session.busy ||
                                    service?.isRateLimited == true ||
                                    _session.snapshot?.refreshError != null ||
                                    _session.snapshot?.outcomeUnknown == true
                                ? null
                                : () => unawaited(_confirmRevoke(grant)),
                            child: const Icon(Icons.person_remove_outlined),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BusyMaxGroupedList(
            filled: true,
            children: [
              YaruListTile.square(
                title: TextField(
                  key: const Key('calendar-sharing-recipient'),
                  controller: _recipient,
                  enabled:
                      !_session.busy &&
                      _session.snapshot?.outcomeUnknown != true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: busyMaxGroupedTextFieldDecoration(
                    context,
                    labelText: context.l10n.shareRecipientEmail,
                  ),
                ),
              ),
            ],
          ),
          if (service != null)
            BusyMaxMenuButton<String>(
              key: ValueKey('calendar-sharing-new-role-${service.source.id}'),
              tooltip: _newRole == null
                  ? context.l10n.shareRole
                  : calendarSharingRoleLabel(context.l10n, _newRole!),
              enabled:
                  !_session.busy && _session.snapshot?.outcomeUnknown != true,
              entries: [
                for (final role in service.newGrantRoles)
                  BusyMaxMenuEntry(
                    value: role,
                    label: calendarSharingRoleLabel(context.l10n, role),
                    role: BusyMaxMenuEntryRole.radio,
                    selected: role == _newRole,
                  ),
              ],
              onSelected: (role) => setState(() => _newRole = role),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: BusyMaxPushButton.standard(
              key: const Key('calendar-sharing-add'),
              onPressed:
                  _session.busy ||
                      service?.isRateLimited == true ||
                      _newRole == null ||
                      _session.snapshot?.refreshError != null ||
                      _session.snapshot?.outcomeUnknown == true
                  ? null
                  : () => unawaited(_add()),
              child: Text(context.l10n.addCalendarShare),
            ),
          ),
        ],
        if (service == null && widget.sources.isEmpty)
          Text(context.l10n.sharingPermissionUnavailable),
      ],
    );
  }

  Future<void> _add() async {
    final role = _newRole;
    if (role == null) return;
    final result = await _mutate(
      (service) => service.add(recipient: _recipient.text, role: role),
    );
    if (mounted && result != null && !result.outcomeUnknown) _recipient.clear();
  }

  Future<void> _confirmRevoke(CloudCalendarShareGrant grant) async {
    final serviceBeforeConfirmation = _session.service;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.nextcloudRevokeShare,
      message: grant.recipient,
      confirmLabel: context.l10n.nextcloudRevokeShare,
      destructive: true,
    );
    if (confirmed &&
        mounted &&
        identical(serviceBeforeConfirmation, _session.service)) {
      await _mutate((service) => service.revoke(grant));
    }
  }
}

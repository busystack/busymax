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
  CloudCalendarSharingService? _service;
  CloudCalendarShareSnapshot? _snapshot;
  Object? _error;
  bool _busy = false;
  String? _newRole;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
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
      final selected = _service?.source.id;
      final next = widget.sources.where((source) => source.id == selected);
      if (next.isNotEmpty) {
        unawaited(_select(next.first));
      } else if (widget.sources.isNotEmpty) {
        unawaited(_select(widget.sources.first));
      } else {
        _generation++;
        _service = null;
        _snapshot = null;
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _select(CalendarSourceEntity source) async {
    final generation = ++_generation;
    setState(() {
      _service = null;
      _snapshot = null;
      _error = null;
      _busy = true;
    });
    try {
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
      if (!mounted || generation != _generation) return;
      setState(() {
        _service = service;
        _newRole = service.newGrantRoles.first;
      });
      final snapshot = await service.load();
      if (!mounted || generation != _generation) return;
      setState(() => _snapshot = snapshot);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _mutate(
    Future<CloudCalendarShareSnapshot> Function(CloudCalendarSharingService)
    action,
  ) async {
    final service = _service;
    if (service == null ||
        _busy ||
        _snapshot == null ||
        _snapshot!.refreshError != null ||
        _snapshot!.outcomeUnknown ||
        service.hasUnresolvedOutcome) {
      return;
    }
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await action(service);
      if (!mounted || generation != _generation) return;
      setState(() => _snapshot = snapshot);
      if (snapshot.outcomeUnknown) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.nextcloudOutcomeUnknown)),
        );
      } else if (snapshot.refreshError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.sharingRefreshFailed)),
        );
      }
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final grants = _snapshot?.grants;
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
            enabled: !_busy,
          ),
        if (_busy) const YaruCircularProgressIndicator(),
        if (_error != null) ...[
          SelectableText('${context.l10n.operationFailed}: $_error'),
          if (service != null)
            BusyMaxPushButton.standard(
              onPressed: _busy
                  ? null
                  : () => unawaited(_select(service.source)),
              child: Text(context.l10n.retry),
            ),
        ],
        if (_snapshot?.outcomeUnknown == true) ...[
          Text(context.l10n.nextcloudOutcomeUnknown),
          if (service != null)
            BusyMaxPushButton.standard(
              onPressed: _busy
                  ? null
                  : () => unawaited(_select(service.source)),
              child: Text(context.l10n.retry),
            ),
        ] else if (_snapshot?.refreshError != null) ...[
          Text(context.l10n.sharingRefreshFailed),
          if (service != null)
            BusyMaxPushButton.standard(
              onPressed: _busy
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
                                !_busy &&
                                _snapshot?.refreshError == null &&
                                _snapshot?.outcomeUnknown != true,
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
                                _busy ||
                                    _snapshot?.refreshError != null ||
                                    _snapshot?.outcomeUnknown == true
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
                  enabled: !_busy && _snapshot?.outcomeUnknown != true,
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
              enabled: !_busy && _snapshot?.outcomeUnknown != true,
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
                  _busy ||
                      _newRole == null ||
                      _snapshot?.refreshError != null ||
                      _snapshot?.outcomeUnknown == true
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
    await _mutate(
      (service) => service.add(recipient: _recipient.text, role: role),
    );
    if (_error == null && mounted) _recipient.clear();
  }

  Future<void> _confirmRevoke(CloudCalendarShareGrant grant) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.nextcloudRevokeShare,
      message: grant.recipient,
      confirmLabel: context.l10n.nextcloudRevokeShare,
      destructive: true,
    );
    if (confirmed && mounted) await _mutate((service) => service.revoke(grant));
  }
}

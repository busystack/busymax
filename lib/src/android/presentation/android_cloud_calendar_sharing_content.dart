import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/data/cloud_calendar_sharing_service.dart';
import '../../features/calendar/presentation/cloud_calendar_sharing_labels.dart';

/// Provider-specific permission management, hosted by the Linux and Android
/// native dialog shells. It never edits local sharing state on API failure.
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
  Timer? _cooldownTimer;
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
      final selected = _service?.source;
      final replacement = widget.sources.where(
        (source) => source.id == selected?.id,
      );
      final next = replacement.isNotEmpty
          ? replacement.first
          : widget.sources.isEmpty
          ? null
          : widget.sources.first;
      if (next == null) {
        _generation++;
        _service = null;
        _snapshot = null;
      } else {
        unawaited(_select(next));
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _cooldownTimer?.cancel();
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _select(CalendarSourceEntity source) async {
    final generation = ++_generation;
    _cooldownTimer?.cancel();
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
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _scheduleCooldown();
      }
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
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _scheduleCooldown();
      }
    }
  }

  void _scheduleCooldown() {
    _cooldownTimer?.cancel();
    final service = _service;
    final delay = service?.retryAfter;
    if (service == null || delay == null) return;
    final generation = _generation;
    _cooldownTimer = Timer(delay + const Duration(milliseconds: 1), () {
      if (!mounted ||
          generation != _generation ||
          !identical(_service, service)) {
        return;
      }
      setState(() {});
      _scheduleCooldown();
    });
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
          DropdownButtonFormField<String>(
            key: const Key('calendar-sharing-source'),
            initialValue: service?.source.id,
            items: [
              for (final source in widget.sources)
                DropdownMenuItem(value: source.id, child: Text(source.summary)),
            ],
            onChanged: _busy
                ? null
                : (id) {
                    if (id == null) return;
                    unawaited(
                      _select(widget.sources.firstWhere((e) => e.id == id)),
                    );
                  },
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) ...[
          SelectableText('${context.l10n.operationFailed}: $_error'),
          TextButton(
            onPressed: service == null || _busy
                ? null
                : () => unawaited(_select(service.source)),
            child: Text(context.l10n.retry),
          ),
        ],
        if (service?.isRateLimited == true)
          Text(context.l10n.sharingRateLimited),
        if (_snapshot?.outcomeUnknown == true) ...[
          Text(context.l10n.nextcloudOutcomeUnknown),
          TextButton(
            onPressed: _busy || service == null
                ? null
                : () => unawaited(_select(service.source)),
            child: Text(context.l10n.retry),
          ),
        ] else if (_snapshot?.refreshError != null) ...[
          Text(context.l10n.sharingRefreshFailed),
          TextButton(
            onPressed: _busy || service == null
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
                  ListTile(
                    key: Key('calendar-sharing-grant-${grant.id}'),
                    title: Text(grant.recipient),
                    subtitle: Text(
                      calendarSharingRoleLabel(context.l10n, grant.role),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        if (grant.canChange)
                          PopupMenuButton<String>(
                            enabled:
                                !_busy &&
                                service?.isRateLimited != true &&
                                _snapshot?.refreshError == null &&
                                _snapshot?.outcomeUnknown != true,
                            tooltip: context.l10n.shareRole,
                            onSelected: (role) => unawaited(
                              _mutate((s) => s.change(grant, role)),
                            ),
                            itemBuilder: (_) => [
                              for (final role in grant.allowedRoles)
                                PopupMenuItem(
                                  value: role,
                                  child: Text(
                                    calendarSharingRoleLabel(
                                      context.l10n,
                                      role,
                                    ),
                                  ),
                                ),
                            ],
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        if (grant.canRevoke)
                          IconButton(
                            tooltip: context.l10n.nextcloudRevokeShare,
                            onPressed:
                                _busy ||
                                    service?.isRateLimited == true ||
                                    _snapshot?.refreshError != null ||
                                    _snapshot?.outcomeUnknown == true
                                ? null
                                : () => unawaited(_confirmRevoke(grant)),
                            icon: const Icon(Icons.person_remove_outlined),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('calendar-sharing-recipient'),
            controller: _recipient,
            enabled: !_busy && _snapshot?.outcomeUnknown != true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.l10n.shareRecipientEmail,
            ),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('calendar-sharing-new-role-${service!.source.id}'),
            initialValue: _newRole,
            decoration: InputDecoration(labelText: context.l10n.shareRole),
            items: [
              for (final role in service.newGrantRoles)
                DropdownMenuItem(
                  value: role,
                  child: Text(calendarSharingRoleLabel(context.l10n, role)),
                ),
            ],
            onChanged: _busy || _snapshot?.outcomeUnknown == true
                ? null
                : (role) => setState(() => _newRole = role),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('calendar-sharing-add'),
              onPressed:
                  _busy ||
                      service.isRateLimited ||
                      _newRole == null ||
                      _snapshot?.refreshError != null ||
                      _snapshot?.outcomeUnknown == true
                  ? null
                  : () => unawaited(_add()),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(context.l10n.addCalendarShare),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.nextcloudRevokeShare),
        content: Text(grant.recipient),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.nextcloudRevokeShare),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate((service) => service.revoke(grant));
    }
  }
}

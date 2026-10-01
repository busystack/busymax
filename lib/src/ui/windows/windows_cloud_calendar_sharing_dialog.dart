import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/data/cloud_calendar_sharing_service.dart';
import '../../features/calendar/presentation/cloud_calendar_sharing_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/busy_provider.dart';

Future<void> showWindowsCloudCalendarSharingDialog(
  BuildContext context, {
  required List<CalendarSourceEntity> sources,
  CloudCalendarSharingService Function(CalendarSourceEntity)? serviceFactory,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => ContentDialog(
    title: Text(AppLocalizations.of(dialogContext).manageCalendarSharing),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: _WindowsCloudCalendarSharingContent(
          sources: sources,
          serviceFactory: serviceFactory,
        ),
      ),
    ),
    actions: [
      Button(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(AppLocalizations.of(dialogContext).close),
      ),
    ],
  ),
);

class _WindowsCloudCalendarSharingContent extends ConsumerStatefulWidget {
  const _WindowsCloudCalendarSharingContent({
    required this.sources,
    this.serviceFactory,
  });
  final List<CalendarSourceEntity> sources;
  final CloudCalendarSharingService Function(CalendarSourceEntity)?
  serviceFactory;

  @override
  ConsumerState<_WindowsCloudCalendarSharingContent> createState() =>
      _WindowsCloudCalendarSharingContentState();
}

class _WindowsCloudCalendarSharingContentState
    extends ConsumerState<_WindowsCloudCalendarSharingContent> {
  final _recipient = TextEditingController();
  CloudCalendarSharingService? _service;
  CloudCalendarShareSnapshot? _snapshot;
  Object? _error;
  bool _busy = false;
  Timer? _cooldownTimer;
  String? _role;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sources.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load(widget.sources.first));
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _cooldownTimer?.cancel();
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _load(CalendarSourceEntity source) async {
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
        _role = service.newGrantRoles.first;
      });
      final result = await service.load();
      if (!mounted || generation != _generation) return;
      setState(() => _snapshot = result);
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
      final result = await action(service);
      if (!mounted || generation != _generation) return;
      setState(() => _snapshot = result);
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
    final l10n = AppLocalizations.of(context);
    final service = _service;
    final grants = _snapshot?.grants;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sources.length > 1)
          ComboBox<String>(
            key: const Key('windows-sharing-source'),
            value: service?.source.id,
            isExpanded: true,
            items: [
              for (final source in widget.sources)
                ComboBoxItem(value: source.id, child: Text(source.summary)),
            ],
            onChanged: _busy
                ? null
                : (id) {
                    if (id == null) return;
                    unawaited(
                      _load(widget.sources.firstWhere((e) => e.id == id)),
                    );
                  },
          ),
        if (_busy) const ProgressBar(),
        if (_error != null) ...[
          InfoBar(
            title: Text(l10n.operationFailed),
            content: SelectableText('$_error'),
            severity: InfoBarSeverity.error,
          ),
          Button(
            onPressed: service == null || _busy
                ? null
                : () => unawaited(_load(service.source)),
            child: Text(l10n.retry),
          ),
        ],
        if (service?.isRateLimited == true)
          InfoBar(
            title: Text(l10n.sharingRateLimited),
            severity: InfoBarSeverity.warning,
          ),
        if (_snapshot?.outcomeUnknown == true)
          Column(
            children: [
              InfoBar(
                title: Text(l10n.nextcloudOutcomeUnknown),
                severity: InfoBarSeverity.warning,
              ),
              Button(
                onPressed: _busy || service == null
                    ? null
                    : () => unawaited(_load(service.source)),
                child: Text(l10n.retry),
              ),
            ],
          )
        else if (_snapshot?.refreshError != null)
          Column(
            children: [
              InfoBar(
                title: Text(l10n.sharingRefreshFailed),
                severity: InfoBarSeverity.warning,
              ),
              Button(
                onPressed: _busy || service == null
                    ? null
                    : () => unawaited(_load(service.source)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        if (grants != null) ...[
          SizedBox(
            height: 230,
            child: ListView(
              children: [
                for (final grant in grants)
                  Padding(
                    key: Key('windows-sharing-grant-${grant.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grant.recipient),
                        Text(calendarSharingRoleLabel(l10n, grant.role)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (grant.canChange)
                              DropDownButton(
                                title: Text(l10n.shareRole),
                                items: [
                                  for (final role in grant.allowedRoles)
                                    MenuFlyoutItem(
                                      text: Text(
                                        calendarSharingRoleLabel(l10n, role),
                                      ),
                                      onPressed:
                                          _busy ||
                                              service?.isRateLimited == true ||
                                              _snapshot?.refreshError != null ||
                                              _snapshot?.outcomeUnknown == true
                                          ? null
                                          : () => unawaited(
                                              _mutate(
                                                (s) => s.change(grant, role),
                                              ),
                                            ),
                                    ),
                                ],
                              ),
                            if (grant.canRevoke)
                              Button(
                                onPressed:
                                    _busy ||
                                        service?.isRateLimited == true ||
                                        _snapshot?.refreshError != null ||
                                        _snapshot?.outcomeUnknown == true
                                    ? null
                                    : () => unawaited(_confirmRevoke(grant)),
                                child: Text(l10n.nextcloudRevokeShare),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          InfoLabel(
            label: l10n.shareRecipientEmail,
            child: TextBox(
              key: const Key('windows-sharing-recipient'),
              controller: _recipient,
              enabled: !_busy && _snapshot?.outcomeUnknown != true,
            ),
          ),
          const SizedBox(height: 8),
          InfoLabel(
            label: l10n.shareRole,
            child: ComboBox<String>(
              key: const Key('windows-sharing-new-role'),
              value: _role,
              isExpanded: true,
              items: [
                for (final role in service!.newGrantRoles)
                  ComboBoxItem(
                    value: role,
                    child: Text(calendarSharingRoleLabel(l10n, role)),
                  ),
              ],
              onChanged: _busy || _snapshot?.outcomeUnknown == true
                  ? null
                  : (value) => setState(() => _role = value),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Button(
              key: const Key('windows-sharing-add'),
              onPressed:
                  _busy ||
                      service.isRateLimited ||
                      _role == null ||
                      _snapshot?.refreshError != null ||
                      _snapshot?.outcomeUnknown == true
                  ? null
                  : () => unawaited(_add()),
              child: Text(l10n.addCalendarShare),
            ),
          ),
        ],
        if (service == null && widget.sources.isEmpty)
          Text(l10n.sharingPermissionUnavailable),
      ],
    );
  }

  Future<void> _add() async {
    final role = _role;
    if (role == null) return;
    await _mutate(
      (service) => service.add(recipient: _recipient.text, role: role),
    );
    if (_error == null && mounted) _recipient.clear();
  }

  Future<void> _confirmRevoke(CloudCalendarShareGrant grant) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(l10n.nextcloudRevokeShare),
        content: Text(grant.recipient),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.nextcloudRevokeShare),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate((service) => service.revoke(grant));
    }
  }
}

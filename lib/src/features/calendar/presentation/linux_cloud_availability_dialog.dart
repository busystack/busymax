import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../calendar_providers/cloud_calendar_client.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/time_format_scope.dart';
import 'event_editor_draft.dart';

Future<void> showLinuxCloudAvailabilityDialog(
  BuildContext context, {
  required EventEditorDraft draft,
}) => showBusyMaxModalDialog<void>(
  context,
  barrierDismissible: false,
  builder: (_) => _LinuxCloudAvailabilityDialog(draft: draft),
);

class _LinuxCloudAvailabilityDialog extends ConsumerStatefulWidget {
  const _LinuxCloudAvailabilityDialog({required this.draft});

  final EventEditorDraft draft;

  @override
  ConsumerState<_LinuxCloudAvailabilityDialog> createState() =>
      _LinuxCloudAvailabilityDialogState();
}

class _LinuxCloudAvailabilityDialogState
    extends ConsumerState<_LinuxCloudAvailabilityDialog> {
  bool _loading = true;
  int _generation = 0;
  Object? _error;
  List<FreeBusyCalendarResultDto> _results = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(
        calendarRemoteApiClientForAccountProvider(widget.draft.accountId),
      );
      final interval = widget.draft.cloudAvailabilityInterval;
      if (client is! DetailedFreeBusyClient || interval == null) {
        throw StateError('Availability is unavailable.');
      }
      final recipients = widget.draft.attendees
          .where((attendee) => !attendee.self && !attendee.organizer)
          .map((attendee) => attendee.email.trim())
          .where((email) => email.isNotEmpty)
          .toSet()
          .toList();
      final fetched = await (client as DetailedFreeBusyClient).freeBusyDetails(
        calendarIds: recipients,
        rangeStart: interval.start.toUtc(),
        rangeEnd: interval.end.toUtc(),
      );
      if (mounted && generation == _generation) _results = fetched;
    } on Object catch (error) {
      if (mounted && generation == _generation) _error = error;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    String interval(BusySlotDto slot) =>
        '${formatClockDateTime(context, slot.start.toLocal(), date.format(slot.start.toLocal()))} – '
        '${formatClockDateTime(context, slot.end.toLocal(), date.format(slot.end.toLocal()))}';
    return BusyMaxDialogShell(
      key: const ValueKey('linux-cloud-availability-dialog'),
      title: l10n.nextcloudGuestAvailability,
      maxWidth: 600,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: _loading ? null : _load,
          child: Text(l10n.refresh),
        ),
        BusyMaxPushButton.suggested(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
      children: [
        if (_loading) const Center(child: YaruCircularProgressIndicator()),
        if (_error != null) Text(redactForLog(_error)),
        if (!_loading && _error == null)
          for (final result in _results)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(result.calendarId),
                  Text(
                    !result.succeeded
                        ? l10n.nextcloudAvailabilityUnknown
                        : result.busySlots.isEmpty
                        ? l10n.nextcloudAvailabilityFree
                        : result.busySlots.map(interval).join('\n'),
                  ),
                  if (result.errors.isNotEmpty) Text(result.errors.join(' · ')),
                ],
              ),
            ),
      ],
    );
  }
}

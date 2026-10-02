import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_sync_dto.dart';
import '../../calendar_providers/cloud_calendar_client.dart';
import '../../core/logging/redacting_logger.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../l10n/time_format_scope.dart';

Future<void> showWindowsCloudAvailabilityDialog(
  BuildContext context, {
  required EventEditorDraft draft,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WindowsCloudAvailabilityDialog(draft: draft),
);

class _WindowsCloudAvailabilityDialog extends ConsumerStatefulWidget {
  const _WindowsCloudAvailabilityDialog({required this.draft});

  final EventEditorDraft draft;

  @override
  ConsumerState<_WindowsCloudAvailabilityDialog> createState() =>
      _WindowsCloudAvailabilityDialogState();
}

class _WindowsCloudAvailabilityDialogState
    extends ConsumerState<_WindowsCloudAvailabilityDialog> {
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
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    String interval(BusySlotDto slot) =>
        '${formatClockDateTime(context, slot.start.toLocal(), date.format(slot.start.toLocal()))} – '
        '${formatClockDateTime(context, slot.end.toLocal(), date.format(slot.end.toLocal()))}';
    return ContentDialog(
      key: const ValueKey('windows-cloud-availability-dialog'),
      title: Text(l10n.nextcloudGuestAvailability),
      content: SizedBox(
        width: 560,
        height: 400,
        child: _loading
            ? const Center(child: ProgressRing())
            : _error != null
            ? Text(redactForLog(_error))
            : ListView(
                children: [
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
                          if (result.errors.isNotEmpty)
                            Text(result.errors.join(' · ')),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        Button(onPressed: _loading ? null : _load, child: Text(l10n.refresh)),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

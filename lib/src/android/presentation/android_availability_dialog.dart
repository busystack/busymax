import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_sync_dto.dart';
import '../../calendar_providers/cloud_calendar_client.dart';
import '../../core/logging/redacting_logger.dart';
import '../../dav/nextcloud/nextcloud_scheduling_service.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../l10n/l10n.dart';
import '../../l10n/time_format_scope.dart';
import '../../providers/busy_provider.dart';

Future<void> showAndroidGuestAvailabilityDialog(
  BuildContext context, {
  required String accountId,
  required BusyProvider provider,
  required EventEditorDraft draft,
  String? collectionId,
}) => showDialog<void>(
  context: context,
  builder: (_) => AndroidGuestAvailabilityDialog(
    accountId: accountId,
    provider: provider,
    collectionId: collectionId,
    draft: draft,
  ),
);

class AndroidGuestAvailabilityDialog extends ConsumerStatefulWidget {
  const AndroidGuestAvailabilityDialog({
    super.key,
    required this.accountId,
    required this.provider,
    required this.draft,
    this.collectionId,
  });

  final String accountId;
  final BusyProvider provider;
  final String? collectionId;
  final EventEditorDraft draft;

  @override
  ConsumerState<AndroidGuestAvailabilityDialog> createState() =>
      _AndroidGuestAvailabilityDialogState();
}

class _AndroidGuestAvailabilityDialogState
    extends ConsumerState<AndroidGuestAvailabilityDialog> {
  bool _loading = true;
  Object? _error;
  List<NextcloudFreeBusyResult> _nextcloud = const [];
  Map<String, FreeBusyCalendarResultDto> _cloud = const {};
  int _loadGeneration = 0;

  List<String> get _recipients => widget.draft.attendees
      .where((attendee) => !attendee.self && !attendee.organizer)
      .map((attendee) => attendee.email.trim())
      .where((email) => email.isNotEmpty)
      .toSet()
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AndroidGuestAvailabilityDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.provider != widget.provider ||
        oldWidget.collectionId != widget.collectionId ||
        oldWidget.draft != widget.draft) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!_loading && mounted) setState(() => _loading = true);
    _error = null;
    _nextcloud = const [];
    _cloud = const {};
    try {
      if (widget.provider == BusyProvider.nextcloud) {
        final collectionId = widget.collectionId;
        if (collectionId == null) throw StateError('Missing collection');
        final results = await ref
            .read(nextcloudSchedulingServiceProvider(widget.accountId))
            .freeBusyForDraft(
              collectionId: collectionId,
              draft: widget.draft,
              fallbackTimeZone: ref.read(localTimeZoneProvider),
            );
        if (generation != _loadGeneration || !mounted) return;
        _nextcloud = results;
      } else if (widget.provider == BusyProvider.google ||
          widget.provider == BusyProvider.microsoft) {
        final client = ref.read(
          calendarRemoteApiClientForAccountProvider(widget.accountId),
        );
        final interval = widget.draft.cloudAvailabilityInterval;
        if (client == null || interval == null) {
          throw StateError('Availability is unavailable');
        }
        if (client is DetailedFreeBusyClient) {
          final results = await (client as DetailedFreeBusyClient)
              .freeBusyDetails(
                calendarIds: _recipients,
                rangeStart: interval.start.toUtc(),
                rangeEnd: interval.end.toUtc(),
              );
          final byCalendar = {
            for (final result in results)
              result.calendarId.toLowerCase(): result,
          };
          if (generation != _loadGeneration || !mounted) return;
          _cloud = {
            for (final recipient in _recipients)
              recipient:
                  byCalendar[recipient.toLowerCase()] ??
                  FreeBusyCalendarResultDto(
                    calendarId: recipient,
                    status: FreeBusyEvaluationStatus.missing,
                  ),
          };
        } else {
          _cloud = {
            for (final recipient in _recipients)
              recipient: FreeBusyCalendarResultDto(
                calendarId: recipient,
                status: FreeBusyEvaluationStatus.missing,
              ),
          };
        }
      } else {
        throw StateError('Availability is unsupported');
      }
    } on Object catch (error) {
      if (generation == _loadGeneration) _error = error;
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    String interval(DateTime start, DateTime end) =>
        '${formatClockDateTime(context, start.toLocal(), date.format(start.toLocal()))} – '
        '${formatClockDateTime(context, end.toLocal(), date.format(end.toLocal()))}';
    return AlertDialog(
      key: const ValueKey('android-guest-availability-dialog'),
      title: Text(context.l10n.nextcloudGuestAvailability),
      content: SizedBox(
        width: 520,
        height: (MediaQuery.sizeOf(context).height * .55).clamp(180, 520),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? SingleChildScrollView(child: Text(redactForLog(_error)))
            : ListView(
                children: [
                  for (final result in _nextcloud)
                    _AvailabilityEntry(
                      recipient: result.recipient.replaceFirst(
                        RegExp(r'^mailto:', caseSensitive: false),
                        '',
                      ),
                      free:
                          result.availability !=
                              NextcloudAvailability.unknown &&
                          result.intervals.isEmpty,
                      unknown:
                          result.availability == NextcloudAvailability.unknown,
                      intervals: [
                        for (final value in result.intervals)
                          interval(value.startUtc, value.endUtc),
                      ],
                    ),
                  for (final entry in _cloud.entries)
                    _AvailabilityEntry(
                      recipient: entry.key,
                      free:
                          entry.value.succeeded &&
                          entry.value.busySlots.isEmpty,
                      unknown: !entry.value.succeeded,
                      intervals: [
                        for (final value in entry.value.busySlots)
                          interval(value.start, value.end),
                      ],
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _load,
          child: Text(context.l10n.refresh),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

class _AvailabilityEntry extends StatelessWidget {
  const _AvailabilityEntry({
    required this.recipient,
    required this.free,
    required this.unknown,
    required this.intervals,
  });

  final String recipient;
  final bool free;
  final bool unknown;
  final List<String> intervals;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          recipient,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          unknown
              ? context.l10n.nextcloudAvailabilityUnknown
              : free
              ? context.l10n.nextcloudAvailabilityFree
              : context.l10n.nextcloudAvailabilityBusy,
        ),
        for (final value in intervals) SelectableText(value),
      ],
    ),
  );
}

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../ical/ical_import_service.dart';
import '../../../ical/ical_ingestion.dart';
import '../../../l10n/l10n.dart';
import '../../../providers/busy_provider.dart';
import '../data/calendar_repository.dart';

Future<void> showIcsImportFlow(
  BuildContext context,
  WidgetRef ref, {
  String? filePath,
}) async {
  const typeGroup = XTypeGroup(
    label: 'iCalendar',
    extensions: ['ics'],
    mimeTypes: ['text/calendar'],
  );
  final file = filePath == null
      ? await openFile(acceptedTypeGroups: const [typeGroup])
      : XFile(filePath);
  if (file == null || !context.mounted) return;
  try {
    final length = await file.length();
    if (length > icalIngestionDecodedBodyLimit) {
      throw const IcalIngestionException(
        'IcalBodyTooLarge',
        'The calendar data exceeds the 16 MiB limit.',
      );
    }
    final service = ref.read(icalImportServiceProvider);
    final preview = service.parsePreview(await file.readAsBytes());
    final destinations = await service.writableDestinations();
    final accountLabels = {
      for (final account
          in await ref.read(accountsRepositoryProvider).watchAccounts().first)
        account.id: account.selectorLabel,
    };
    if (!context.mounted) return;
    final destination = await showBusyMaxModalDialog<CalendarSourceEntity>(
      context,
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
      barrierDismissible: false,
      builder: (dialogContext) => _IcalImportPreviewDialog(
        preview: preview,
        destinations: destinations,
        accountLabels: accountLabels,
      ),
    );
    if (destination == null || !context.mounted) return;
    final report = await service.importPreview(
      preview: preview,
      destination: destination,
    );
    if (!context.mounted) return;
    await showBusyMaxModalDialog<void>(
      context,
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
      builder: (dialogContext) => _IcalImportReportDialog(report: report),
    );
  } on Object catch (error) {
    if (!context.mounted) return;
    final code = switch (error) {
      IcalIngestionException(:final code) => code,
      _ => 'IcalImportFailed',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.importIcsFailed(code))));
  }
}

class _IcalImportPreviewDialog extends StatefulWidget {
  const _IcalImportPreviewDialog({
    required this.preview,
    required this.destinations,
    required this.accountLabels,
  });

  final IcalImportPreview preview;
  final List<CalendarSourceEntity> destinations;
  final Map<String, String> accountLabels;

  @override
  State<_IcalImportPreviewDialog> createState() =>
      _IcalImportPreviewDialogState();
}

class _IcalImportPreviewDialogState extends State<_IcalImportPreviewDialog> {
  CalendarSourceEntity? _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.destinations.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final omitted = widget.preview.fieldsThatWillBeOmitted.toList()..sort();
    return BusyMaxDialogShell(
      title: l10n.importIcsPreview,
      maxWidth: BusyMaxSizes.compactDetailsWidth,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          key: const ValueKey('confirm-ics-import'),
          onPressed: _destination == null
              ? null
              : () => Navigator.of(context).pop(_destination),
          child: Text(l10n.importIcsConfirm),
        ),
      ],
      children: [
        Text(l10n.importEventsFound(widget.preview.eventCount)),
        if (widget.preview.invalidEventCount > 0)
          Text(l10n.importInvalidEvents(widget.preview.invalidEventCount)),
        if (omitted.isNotEmpty)
          Text(l10n.importFieldsOmitted(omitted.join(', '))),
        const SizedBox(height: BusyMaxSpacing.md),
        if (widget.destinations.isEmpty)
          Text(l10n.noWritableCalendars)
        else
          BusyMaxComboRow<CalendarSourceEntity>(
            key: const ValueKey('ics-import-destination'),
            title: l10n.importDestinationCalendar,
            values: widget.destinations,
            selected: _destination!,
            labelFor: (source) =>
                '${widget.accountLabels[source.accountId] ?? source.provider.displayName} · ${source.summary}',
            onSelected: (value) => setState(() => _destination = value),
          ),
      ],
    );
  }
}

class _IcalImportReportDialog extends StatelessWidget {
  const _IcalImportReportDialog({required this.report});

  final IcalImportReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final omitted = report.fieldsIntentionallyOmitted.toList()..sort();
    final unsupported = report.unsupportedRecurrenceSets
        .map((item) => '${item.uid}: ${item.reason}')
        .toList(growable: false);
    return BusyMaxDialogShell(
      title: l10n.importIcsComplete,
      actions: [
        BusyMaxPushButton.suggested(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
      children: [
        Text(
          [
            l10n.importQueued(report.queued),
            l10n.importDuplicatesSkipped(report.duplicatesSkipped),
            l10n.importUnsupportedSets(report.unsupportedRecurrenceSets.length),
            ...unsupported,
            l10n.importInvalidEvents(report.invalidEvents),
            if (omitted.isNotEmpty)
              l10n.importFieldsOmitted(omitted.join(', ')),
          ].join('\n'),
        ),
      ],
    );
  }
}

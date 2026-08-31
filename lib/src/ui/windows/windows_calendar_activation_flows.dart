import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../ical/ical_import_service.dart';
import '../../ical/ical_ingestion.dart';

Future<void> showWindowsIcsImportFlow(
  BuildContext context,
  WidgetRef ref, {
  String? filePath,
}) async {
  const typeGroup = XTypeGroup(
    label: 'iCalendar',
    extensions: ['ics'],
    mimeTypes: ['text/calendar'],
  );
  final selected = filePath == null
      ? await openFile(acceptedTypeGroups: const [typeGroup])
      : XFile(filePath);
  if (selected == null || !context.mounted) return;
  try {
    if (await selected.length() > icalIngestionDecodedBodyLimit) {
      throw const IcalIngestionException(
        'IcalBodyTooLarge',
        'The calendar data exceeds the 16 MiB limit.',
      );
    }
    final service = ref.read(icalImportServiceProvider);
    final preview = service.parsePreview(await selected.readAsBytes());
    final destinations = await service.writableDestinations();
    if (!context.mounted) return;
    final destination = await showDialog<CalendarSourceEntity>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WindowsIcsPreviewDialog(
        preview: preview,
        destinations: destinations,
      ),
    );
    if (destination == null || !context.mounted) return;
    final report = await service.importPreview(
      preview: preview,
      destination: destination,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _WindowsIcsReportDialog(report: report),
    );
  } on Object catch (error) {
    if (!context.mounted) return;
    final code = switch (error) {
      IcalIngestionException(:final code) => code,
      FileSystemException(:final osError) =>
        osError?.errorCode.toString() ?? 'FileError',
      _ => 'IcalImportFailed',
    };
    await showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(AppLocalizations.of(context).importIcsPreview),
        content: InfoBar(
          title: Text(AppLocalizations.of(context).importIcsFailed(code)),
          severity: InfoBarSeverity.error,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      ),
    );
  }
}

class _WindowsIcsPreviewDialog extends StatefulWidget {
  const _WindowsIcsPreviewDialog({
    required this.preview,
    required this.destinations,
  });

  final IcalImportPreview preview;
  final List<CalendarSourceEntity> destinations;

  @override
  State<_WindowsIcsPreviewDialog> createState() =>
      _WindowsIcsPreviewDialogState();
}

class _WindowsIcsPreviewDialogState extends State<_WindowsIcsPreviewDialog> {
  CalendarSourceEntity? _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.destinations.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final omitted = widget.preview.fieldsThatWillBeOmitted.toList()..sort();
    return ContentDialog(
      title: Text(l10n.importIcsPreview),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.importEventsFound(widget.preview.eventCount)),
          if (widget.preview.invalidEventCount > 0)
            Text(l10n.importInvalidEvents(widget.preview.invalidEventCount)),
          if (omitted.isNotEmpty)
            Text(l10n.importFieldsOmitted(omitted.join(', '))),
          const SizedBox(height: 16),
          if (widget.destinations.isEmpty)
            InfoBar(
              title: Text(l10n.noWritableCalendars),
              severity: InfoBarSeverity.warning,
            )
          else
            InfoLabel(
              label: l10n.importDestinationCalendar,
              child: ComboBox<CalendarSourceEntity>(
                isExpanded: true,
                value: _destination,
                items: [
                  for (final source in widget.destinations)
                    ComboBoxItem(value: source, child: Text(source.summary)),
                ],
                onChanged: (value) => setState(() => _destination = value),
              ),
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _destination == null
              ? null
              : () => Navigator.pop(context, _destination),
          child: Text(l10n.importIcsConfirm),
        ),
      ],
    );
  }
}

class _WindowsIcsReportDialog extends StatelessWidget {
  const _WindowsIcsReportDialog({required this.report});

  final IcalImportReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final omitted = report.fieldsIntentionallyOmitted.toList()..sort();
    return ContentDialog(
      title: Text(l10n.importIcsComplete),
      content: Text(
        [
          l10n.importQueued(report.queued),
          l10n.importDuplicatesSkipped(report.duplicatesSkipped),
          l10n.importUnsupportedSets(report.unsupportedRecurrenceSets.length),
          l10n.importInvalidEvents(report.invalidEvents),
          if (omitted.isNotEmpty) l10n.importFieldsOmitted(omitted.join(', ')),
        ].join('\n'),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

Future<void> showWindowsWebCalSubscriptionFlow(
  BuildContext context,
  WidgetRef ref, {
  String? initialUrl,
}) async {
  final url = TextEditingController(text: initialUrl);
  final name = TextEditingController();
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        return ContentDialog(
          title: Text(l10n.addCalendarSubscription),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.calendarSubscriptionsDescription),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.subscriptionUrl,
                child: TextBox(controller: url, enabled: !busy),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.subscriptionName,
                child: TextBox(controller: name, enabled: !busy),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                InfoBar(title: Text(error!), severity: InfoBarSeverity.error),
              ],
            ],
          ),
          actions: [
            Button(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: busy || url.text.trim().isEmpty
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(webCalSubscriptionServiceProvider)
                            .addSubscription(
                              subscriptionUrl: url.text.trim(),
                              localName: name.text.trim().isEmpty
                                  ? null
                                  : name.text.trim(),
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on Object catch (_) {
                        setState(() {
                          busy = false;
                          error = l10n.subscriptionOperationFailed(
                            l10n.operationFailed,
                          );
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: ProgressRing())
                  : Text(l10n.addSubscriptionAction),
            ),
          ],
        );
      },
    ),
  );
  url.dispose();
  name.dispose();
}

import '../../l10n/generated/app_localizations.dart';
import '../ical/ical_import_service.dart';

String localizedIcalImportReport(
  AppLocalizations l10n,
  IcalImportReport report,
) {
  final omitted = report.fieldsIntentionallyOmitted.toList()..sort();
  return [
    l10n.importQueued(report.queued),
    if (report.followUpPending) l10n.nextcloudImportFollowUp,
    l10n.importDuplicatesSkipped(report.duplicatesSkipped),
    l10n.importUnsupportedSets(report.unsupportedRecurrenceSets.length),
    for (final item in report.unsupportedRecurrenceSets)
      '${item.uid}: ${item.reason}',
    l10n.importInvalidEvents(report.invalidEvents),
    if (omitted.isNotEmpty) l10n.importFieldsOmitted(omitted.join(', ')),
  ].join('\n');
}

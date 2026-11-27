import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../dav/ical/dav_native_export.dart';

/// The document tree adapter writes calendar files. Recovery bundles are
/// separately available from the affected entries in the journal workspace.
Future<String?> exportAndroidDavCollection(
  DavCollectionExport snapshot,
  AppLocalizations l10n,
) async {
  final path = snapshot.resources.isEmpty
      ? null
      : await BusyMaxAndroidPlatform.instance.exportDocumentTree(
          folderName:
              'BusyMax-export-${DateTime.now().toUtc().millisecondsSinceEpoch}',
          resources: [
            for (final (index, resource) in snapshot.resources.indexed)
              AndroidExportResource(
                name: 'resource-${index + 1}.ics',
                bytes: Uint8List.fromList(utf8.encode(resource.rawIcs)),
              ),
          ],
        );
  if (path == null && snapshot.excludedJournalCount == 0) return null;
  return [
    if (path != null) l10n.exportedFile(path),
    if (snapshot.excludedJournalCount > 0) l10n.journalCollectionExportRecovery,
  ].join('\n');
}

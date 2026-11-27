import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../../dav/ical/dav_native_export.dart';
import '../../../dav/ical/dav_native_import.dart';

Future<String?> exportDavCollectionWithDirectoryDialog(
  DavCollectionExport snapshot, {
  Future<String?> Function() chooseDirectory = getDirectoryPath,
}) async {
  if (snapshot.resources.isEmpty && snapshot.pendingJournalRecoveries.isEmpty) {
    return null;
  }
  final destination = await chooseDirectory();
  if (destination == null) return null;
  final directory = await _writeCalendarFiles(destination, snapshot.resources);
  for (final (index, recovery) in snapshot.pendingJournalRecoveries.indexed) {
    await File(
      '${directory.path}${Platform.pathSeparator}journal-recovery-${index + 1}.json',
    ).writeAsString(
      const JsonEncoder.withIndent('  ').convert(recovery.toJson()),
      flush: true,
    );
  }
  return directory.path;
}

/// Use a new directory and neutral filenames. Never overwrite user files or
/// turn untrusted UIDs, titles or DAV hrefs into filesystem paths.
Future<String?> exportNativeCollectionWithDirectoryDialog(
  List<NativeImportResource> resources,
) async {
  final destination = await getDirectoryPath();
  if (destination == null) return null;
  return (await _writeCalendarFiles(destination, resources)).path;
}

Future<Directory> _writeCalendarFiles(
  String destination,
  List<NativeImportResource> resources,
) async {
  final directory = await Directory(destination).createTemp('busymax-export-');
  for (var index = 0; index < resources.length; index++) {
    await File(
      '${directory.path}${Platform.pathSeparator}resource-${index + 1}.ics',
    ).writeAsString(resources[index].rawIcs, flush: true);
  }
  return directory;
}

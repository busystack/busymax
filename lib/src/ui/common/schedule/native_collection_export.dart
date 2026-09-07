import 'dart:io';

import 'package:file_selector/file_selector.dart';
import '../../../dav/nextcloud/nextcloud_native_import.dart';

/// Use a new directory and neutral filenames. Never overwrite user files or
/// turn untrusted UIDs, titles or DAV hrefs into filesystem paths.
Future<String?> exportNativeCollectionWithDirectoryDialog(
  List<NativeImportResource> resources,
) async {
  final destination = await getDirectoryPath();
  if (destination == null) return null;
  final directory = await Directory(destination).createTemp('busymax-export-');
  for (var index = 0; index < resources.length; index++) {
    await File(
      '${directory.path}${Platform.pathSeparator}resource-${index + 1}.ics',
    ).writeAsString(resources[index].rawIcs, flush: true);
  }
  return directory.path;
}

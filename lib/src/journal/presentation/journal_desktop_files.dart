import 'package:file_selector/file_selector.dart';

import '../../dav/ical/ical_attachments.dart';
import '../../features/attachments/presentation/dav_attachment_desktop_save.dart';
import '../../features/schedule/presentation/schedule_item_exporter.dart';
import '../../ui/common/schedule/native_collection_export.dart';
import 'journal_workspace.dart';

const journalDesktopFiles = JournalFileActions(
  read: _readJournalFile,
  export: _exportJournalFile,
  pickAttachment: _pickJournalAttachment,
  saveAttachment: saveDavInlineAttachmentToDesktop,
  exportCollection: exportNativeCollectionWithDirectoryDialog,
);

Future<JournalAttachmentFile?> _pickJournalAttachment() async {
  final file = await openFile();
  if (file == null) return null;
  if (await file.length() > maximumIcalAttachmentBytes) {
    throw const FormatException('Attachment exceeds the file size limit.');
  }
  return (name: file.name, bytes: await file.readAsBytes());
}

Future<List<int>?> _readJournalFile() async {
  const calendar = XTypeGroup(
    label: 'iCalendar',
    extensions: ['ics'],
    mimeTypes: ['text/calendar'],
  );
  final file = await openFile(acceptedTypeGroups: const [calendar]);
  if (file == null) return null;
  if (await file.length() > 16 * 1024 * 1024) {
    throw const FormatException('Calendar file exceeds the import limit.');
  }
  return file.readAsBytes();
}

Future<void> _exportJournalFile(String raw) async {
  await exportICalendarWithSaveDialog(
    suggestedName: 'busymax-journal.ics',
    calendarData: raw,
  );
}

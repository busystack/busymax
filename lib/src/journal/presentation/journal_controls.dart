import 'package:flutter/widgets.dart';

import '../../dav/ical/dav_native_import.dart';
import '../../dav/ical/ical_attachments.dart';

typedef JournalChoice = ({String id, String label});
typedef JournalAttachmentFile = ({String name, List<int> bytes});

final class JournalFileActions {
  const JournalFileActions({
    required this.read,
    required this.export,
    required this.pickAttachment,
    required this.saveAttachment,
    this.exportCollection,
    this.exportDraft,
  });

  final Future<List<int>?> Function() read;
  final Future<void> Function(String raw) export;
  final Future<void> Function(String json)? exportDraft;
  final Future<String?> Function(List<NativeImportResource>)? exportCollection;
  final Future<JournalAttachmentFile?> Function() pickAttachment;
  final Future<String?> Function(IcalAttachment) saveAttachment;
}

abstract interface class JournalControls {
  Widget input(
    String label, {
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    int lines = 1,
  });
  Widget choose(
    String label,
    String selected,
    List<JournalChoice> choices,
    ValueChanged<String> change,
  );
  Widget button(String label, VoidCallback? action, {bool primary = false});
  Widget pickDate(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  );
  Widget pickTime(
    String label,
    DateTime? current,
    ValueChanged<DateTime> change,
  );
}

/// Host hooks for the desktop editor chrome and native grouped fields.
abstract interface class JournalEditorLayout {
  Widget editor({
    required String title,
    required String closeLabel,
    required String saveLabel,
    required VoidCallback close,
    required VoidCallback? save,
    required bool locked,
    required List<Widget> children,
  });
  Widget group(List<Widget> children);
  Widget timeMode(bool allDay, ValueChanged<bool> change);
  Widget timeField(
    String label,
    DateTime? value,
    ValueChanged<DateTime> change, {
    String? timeZone,
    ValueChanged<String>? onTimeZoneChanged,
    ValueChanged<bool>? onValidityChanged,
  });
  Widget details(String label, VoidCallback action);
}

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
  });

  final Future<List<int>?> Function() read;
  final Future<void> Function(String raw) export;
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

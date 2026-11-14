import 'package:fluent_ui/fluent_ui.dart';

import '../../features/attachments/dav_attachment_providers.dart';
import '../../features/attachments/presentation/dav_attachments_section.dart';
import '../../features/attachments/presentation/dav_attachment_desktop_save.dart';

class WindowsDavAttachmentsSection extends StatelessWidget {
  const WindowsDavAttachmentsSection.event({
    super.key,
    required String eventId,
    this.showHeading = true,
  }) : eventId = eventId,
       task = null;
  const WindowsDavAttachmentsSection.task({
    super.key,
    required DavTaskAttachmentTarget target,
  }) : eventId = null,
       task = target,
       showHeading = true;
  final String? eventId;
  final DavTaskAttachmentTarget? task;
  final bool showHeading;
  @override
  Widget build(BuildContext context) {
    Widget button(String label, VoidCallback? pressed) =>
        Button(onPressed: pressed, child: Text(label));
    return task == null
        ? CalDavAttachmentsSection.event(
            eventId: eventId!,
            showHeading: showHeading,
            saveInline: saveDavInlineAttachmentToDesktop,
            buttonBuilder: button,
          )
        : CalDavAttachmentsSection.task(
            target: task!,
            saveInline: saveDavInlineAttachmentToDesktop,
            buttonBuilder: button,
          );
  }
}

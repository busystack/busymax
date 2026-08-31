import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../providers/busy_provider.dart';

enum WindowsGuestUpdateAction { save, delete }

Future<CalendarGuestUpdatePolicy?> showWindowsGuestUpdateDialog(
  BuildContext context, {
  required BusyProvider provider,
  required WindowsGuestUpdateAction action,
}) {
  final l10n = AppLocalizations.of(context);
  final saving = action == WindowsGuestUpdateAction.save;
  if (provider == BusyProvider.microsoft) {
    return showDialog<CalendarGuestUpdatePolicy>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ContentDialog(
        title: Text(
          saving
              ? l10n.microsoftNotifyGuestsSaveTitle
              : l10n.microsoftNotifyGuestsDeleteTitle,
        ),
        content: Text(
          saving
              ? l10n.microsoftNotifyGuestsSaveMessage
              : l10n.microsoftNotifyGuestsDeleteMessage,
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, CalendarGuestUpdatePolicy.send),
            child: Text(saving ? l10n.save : l10n.delete),
          ),
        ],
      ),
    );
  }
  if (provider != BusyProvider.google) {
    return Future.value(CalendarGuestUpdatePolicy.send);
  }
  return showDialog<CalendarGuestUpdatePolicy>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ContentDialog(
      title: Text(l10n.notifyGuestsTitle),
      content: Text(
        saving ? l10n.notifyGuestsSaveMessage : l10n.notifyGuestsDeleteMessage,
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
        Button(
          onPressed: () =>
              Navigator.pop(dialogContext, CalendarGuestUpdatePolicy.doNotSend),
          child: Text(l10n.doNotSend),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, CalendarGuestUpdatePolicy.send),
          child: Text(saving ? l10n.sendUpdates : l10n.sendCancellation),
        ),
      ],
    ),
  );
}

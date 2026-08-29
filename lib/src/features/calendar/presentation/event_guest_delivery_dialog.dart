import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../calendar_providers/calendar_mutation.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../providers/busy_provider.dart';

enum CalendarGuestDeliveryAction { save, delete }

Future<CalendarGuestUpdatePolicy?> showCalendarGuestDeliveryDialog(
  BuildContext context, {
  required BusyProvider provider,
  required CalendarGuestDeliveryAction action,
  LinuxHeaderBarService? headerBarService,
}) async {
  if (provider == BusyProvider.microsoft) {
    final saving = action == CalendarGuestDeliveryAction.save;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: saving
          ? context.l10n.microsoftNotifyGuestsSaveTitle
          : context.l10n.microsoftNotifyGuestsDeleteTitle,
      message: saving
          ? context.l10n.microsoftNotifyGuestsSaveMessage
          : context.l10n.microsoftNotifyGuestsDeleteMessage,
      confirmLabel: saving ? context.l10n.save : context.l10n.delete,
      destructive: !saving,
      headerBarService: headerBarService,
    );
    return confirmed ? CalendarGuestUpdatePolicy.send : null;
  }
  if (provider != BusyProvider.google) {
    return CalendarGuestUpdatePolicy.send;
  }
  return showBusyMaxModalDialog<CalendarGuestUpdatePolicy>(
    context,
    headerBarService: headerBarService,
    barrierDismissible: false,
    builder: (dialogContext) => _GoogleGuestDeliveryDialog(action: action),
  );
}

class _GoogleGuestDeliveryDialog extends StatefulWidget {
  const _GoogleGuestDeliveryDialog({required this.action});

  final CalendarGuestDeliveryAction action;

  @override
  State<_GoogleGuestDeliveryDialog> createState() =>
      _GoogleGuestDeliveryDialogState();
}

class _GoogleGuestDeliveryDialogState
    extends State<_GoogleGuestDeliveryDialog> {
  var _policy = CalendarGuestUpdatePolicy.send;

  @override
  Widget build(BuildContext context) {
    final saving = widget.action == CalendarGuestDeliveryAction.save;
    return BusyMaxDialogShell(
      title: context.l10n.notifyGuestsTitle,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        if (saving)
          BusyMaxPushButton.suggested(
            onPressed: () => Navigator.of(context).pop(_policy),
            child: Text(context.l10n.save),
          )
        else
          BusyMaxPushButton.destructive(
            context: context,
            onPressed: () => Navigator.of(context).pop(_policy),
            child: Text(context.l10n.delete),
          ),
      ],
      children: [
        Text(
          saving
              ? context.l10n.notifyGuestsSaveMessage
              : context.l10n.notifyGuestsDeleteMessage,
        ),
        BusyMaxGroupedList(
          filled: true,
          children: [
            _choiceRow(
              CalendarGuestUpdatePolicy.send,
              saving ? context.l10n.sendUpdates : context.l10n.sendCancellation,
            ),
            _choiceRow(
              CalendarGuestUpdatePolicy.doNotSend,
              context.l10n.doNotSend,
            ),
          ],
        ),
      ],
    );
  }

  Widget _choiceRow(CalendarGuestUpdatePolicy policy, String title) {
    return BusyMaxActionRow(
      title: title,
      leading: Icon(
        _policy == policy
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
      ),
      onTap: () => setState(() => _policy = policy),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';

@immutable
class AccountRemovalOptions {
  const AccountRemovalOptions({required this.revokeGoogleAuthorization});

  final bool revokeGoogleAuthorization;
}

Future<AccountRemovalOptions?> showBusyMaxAccountRemovalDialog(
  BuildContext context, {
  required String accountLabel,
  required bool canRevokeGoogleAuthorization,
}) {
  return showBusyMaxModalDialog<AccountRemovalOptions>(
    context,
    barrierDismissible: false,
    builder: (dialogContext) => _AccountRemovalDialog(
      accountLabel: accountLabel,
      canRevokeGoogleAuthorization: canRevokeGoogleAuthorization,
    ),
  );
}

class _AccountRemovalDialog extends StatefulWidget {
  const _AccountRemovalDialog({
    required this.accountLabel,
    required this.canRevokeGoogleAuthorization,
  });

  final String accountLabel;
  final bool canRevokeGoogleAuthorization;

  @override
  State<_AccountRemovalDialog> createState() => _AccountRemovalDialogState();
}

class _AccountRemovalDialogState extends State<_AccountRemovalDialog> {
  var _revokeGoogleAuthorization = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BusyMaxDialogShell(
      title: l10n.removeAccountTitle(widget.accountLabel),
      maxWidth: 500,
      actions: [
        BusyMaxPushButton.standard(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        BusyMaxPushButton.destructive(
          key: const Key('confirm-account-removal'),
          context: context,
          onPressed: () => Navigator.of(context).pop(
            AccountRemovalOptions(
              revokeGoogleAuthorization: _revokeGoogleAuthorization,
            ),
          ),
          child: Text(l10n.removeAccountAction),
        ),
      ],
      children: [
        Text(l10n.removeAccountConfirmation),
        if (widget.canRevokeGoogleAuthorization) ...[
          const SizedBox(height: BusyMaxSpacing.lg),
          BusyMaxYaruFocusBorder(
            borderStrokeAlign: BorderSide.strokeAlignInside,
            builder: (context, rowFocusNode) => YaruCheckboxListTile(
              key: const Key('revoke-google-authorization'),
              value: _revokeGoogleAuthorization,
              onChanged: _onRevokeGoogleAuthorizationChanged,
              focusNode: rowFocusNode,
              control: BusyMaxYaruFocusBorder(
                builder: (context, controlFocusNode) => YaruCheckbox(
                  value: _revokeGoogleAuthorization,
                  onChanged: _onRevokeGoogleAuthorizationChanged,
                  focusNode: controlFocusNode,
                  hasFocusBorder: false,
                ),
              ),
              title: Text(l10n.revokeGoogleAccess),
              subtitle: Text(l10n.revokeGoogleAccessDescription),
              shape: const RoundedRectangleBorder(),
              hasFocusBorder: false,
            ),
          ),
        ],
      ],
    );
  }

  void _onRevokeGoogleAuthorizationChanged(bool? value) {
    setState(() => _revokeGoogleAuthorization = value ?? false);
  }
}

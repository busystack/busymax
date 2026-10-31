import 'package:flutter/material.dart';

import '../common/nextcloud_certificate_review.dart';
import '../../l10n/l10n.dart';
import '../../app/busymax_design.dart';
import '../../app/busymax_dialogs.dart';

Future<CertificateReviewAction?> showLinuxNextcloudCertificate(
  BuildContext context,
  NextcloudCertificateReviewData data,
) {
  final l10n = context.l10n;
  Widget action(CertificateReviewAction action, String label) =>
      BusyMaxPushButton.standard(
        autofocus: action == CertificateReviewAction.reject,
        onPressed: () => Navigator.of(context).pop(action),
        child: Text(label),
      );
  final actions = <Widget>[
    action(CertificateReviewAction.reject, l10n.certificateReject),
    if (!data.error) ...[
      action(CertificateReviewAction.importCa, l10n.certificateImportCa),
      if (data.management) ...[
        action(CertificateReviewAction.revalidate, l10n.revalidateAccount),
        action(CertificateReviewAction.replacePin, l10n.certificateReplacePin),
        action(CertificateReviewAction.standard, l10n.certificateUseStandard),
      ],
      if (data.canApprove)
        action(CertificateReviewAction.approve, l10n.certificateApprove),
    ],
  ];
  return showBusyMaxModalDialog<CertificateReviewAction>(
    context,
    barrierDismissible: false,
    builder: (context) => BusyMaxDialogShell(
      title: l10n.privateServerCertificates,
      maxWidth: 640,
      actions: actions,
      children: [NextcloudCertificateReviewContent(data: data)],
    ),
  );
}

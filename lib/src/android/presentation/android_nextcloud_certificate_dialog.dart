import 'package:flutter/material.dart';

import '../../ui/common/nextcloud_certificate_review.dart';
import '../../l10n/l10n.dart';

Future<CertificateReviewAction?> showAndroidNextcloudCertificate(
  BuildContext context,
  NextcloudCertificateReviewData data,
) {
  final l10n = context.l10n;
  Widget action(CertificateReviewAction action, String label) => TextButton(
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
  return showDialog<CertificateReviewAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(l10n.privateServerCertificates),
      content: NextcloudCertificateReviewContent(data: data),
      actions: actions,
    ),
  );
}

Future<bool> showAndroidNextcloudCanonicalServer(
  BuildContext context,
  Uri entered,
  Uri canonical,
) async {
  final l10n = context.l10n;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l10n.nextcloudProvider),
          content: Text(
            l10n.nextcloudCanonicalServerReview(
              entered.toString(),
              canonical.toString(),
            ),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.connectAccountAction),
            ),
          ],
        ),
      ) ??
      false;
}

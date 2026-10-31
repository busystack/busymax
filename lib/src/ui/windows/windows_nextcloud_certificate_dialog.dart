import 'package:fluent_ui/fluent_ui.dart';

import '../common/nextcloud_certificate_review.dart';
import '../../l10n/l10n.dart';

Future<CertificateReviewAction?> showWindowsNextcloudCertificate(
  BuildContext context,
  NextcloudCertificateReviewData data,
) {
  final l10n = context.l10n;
  Widget action(CertificateReviewAction action, String label) => Button(
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
    builder: (context) => ContentDialog(
      title: Text(l10n.privateServerCertificates),
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
      content: NextcloudCertificateReviewContent(data: data),
      actions: [Wrap(spacing: 8, runSpacing: 8, children: actions)],
    ),
  );
}

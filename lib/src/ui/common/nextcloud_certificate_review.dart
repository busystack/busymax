import 'dart:io';

import '../../dav/dav_errors.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_bootstrap.dart';
import '../../core/secrets/secret_store.dart';
import '../../dav/trust/nextcloud_certificate.dart';
import '../../dav/trust/nextcloud_http_client_factory.dart';
import '../../dav/trust/nextcloud_trust_policy.dart';
import '../../l10n/l10n.dart';

enum CertificateReviewAction {
  reject,
  approve,
  importCa,
  replacePin,
  standard,
  revalidate,
}

typedef CertificateReviewPresenter = Future<CertificateReviewAction?> Function(
  NextcloudCertificateReviewData data,
);

final class NextcloudCertificateReviewData {
  const NextcloudCertificateReviewData({
    required this.endpoint,
    this.certificates = const [],
    this.previous,
    this.mode,
    this.management = false,
    this.canApprove = false,
    this.failure,
    this.error = false,
    this.networkFailure = false,
  });
  final Uri endpoint;
  final List<NextcloudCertificate> certificates;
  final NextcloudTrustPolicy? previous;
  final NextcloudTrustMode? mode;
  final bool management;
  final bool canApprove;
  final NextcloudCertificateFailure? failure;
  final bool error;
  final bool networkFailure;
}

/// Native presenters supply controls and dialog chrome; this content uses
/// plain, bounded text and selectable fingerprints on all three platforms.
class NextcloudCertificateReviewContent extends StatelessWidget {
  const NextcloudCertificateReviewContent({super.key, required this.data});
  final NextcloudCertificateReviewData data;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String mode(NextcloudTrustMode? value) => switch (value) {
      null => l10n.certificateStandard,
      NextcloudTrustMode.privateCa => l10n.certificatePrivateCa,
      NextcloudTrustMode.pinnedLeaf => l10n.certificatePinnedLeaf,
      NextcloudTrustMode.invalidConfiguration => l10n.certificateInvalid,
    };
    Widget certificate(NextcloudCertificate cert) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SelectableText(
        l10n.certificateDetails(
          cert.subject,
          cert.issuer,
          cert.notBefore.toIso8601String(),
          cert.notAfter.toIso8601String(),
          cert.fingerprint,
        ),
        textDirection: TextDirection.ltr,
      ),
    );
    return SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              '${data.endpoint.host}:${data.endpoint.port}${data.endpoint.path}',
              textDirection: TextDirection.ltr,
            ),
            Text(mode(data.mode)),
            if (data.error)
              Text(
                data.networkFailure
                    ? l10n.nextcloudServerUnavailable
                    : l10n.certificateInvalid,
              ),
            if (data.failure != null)
              Text(certificateFailureMessage(context, data.failure!)),
            if (!data.management) Text(l10n.certificateFirstUseWarning),
            for (final cert in data.certificates) certificate(cert),
            if (data.previous != null) ...[
              Text(l10n.certificatePrevious),
              Text(mode(data.previous!.mode)),
              for (final cert in data.previous!.certificates) certificate(cert),
            ],
            Text(l10n.certificateRenewalHelp),
            const SizedBox(height: 12),
            Text(l10n.certificateBrowserBoundary),
          ],
        ),
      ),
    );
  }
}

String certificateFailureMessage(
  BuildContext context,
  NextcloudCertificateFailure failure,
) => context.l10n.certificateFailure(failure.name);

Future<NextcloudTrustPolicy?> _importCa(
  Uri endpoint,
  String owner,
  CertificateReviewPresenter present, {
  NextcloudTrustPolicy? previous,
}) async {
  try {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'X.509', extensions: ['pem', 'crt', 'cer', 'der']),
      ],
    );
    if (file == null) return null;
    if (await file.length() > NextcloudCertificate.maximumBytes) {
      throw const FormatException('Certificate import is too large.');
    }
    final certs = await NextcloudCertificate.importStream(file.openRead());
    for (final cert in certs) {
      cert.validateCa();
    }
    final choice = await present(
      NextcloudCertificateReviewData(
        endpoint: endpoint,
        certificates: certs,
        previous: previous,
        mode: NextcloudTrustMode.privateCa,
        canApprove: true,
      ),
    );
    if (choice != CertificateReviewAction.approve) return null;
    return NextcloudTrustPolicy.approve(
      owner: owner,
      installation: endpoint,
      mode: NextcloudTrustMode.privateCa,
      certificates: certs,
      generation: const Uuid().v4(),
    );
  } on FormatException {
    throw NextcloudCertificateException(
      NextcloudCertificateFailure.invalidPolicy,
      endpoint: endpoint,
      previous: previous,
    );
  }
}

Future<NextcloudTrustPolicy?> reviewNextcloudCertificate(
  NextcloudCertificateException challenge,
  String owner,
  CertificateReviewPresenter present,
) async {
  final certificate = challenge.observed;
  var eligible = false;
  try {
    certificate?.validateServer(challenge.endpoint.host, selfSigned: true);
    eligible = certificate != null;
  } on Object {
    /* A pin cannot override eligibility. CA import stays available. */
  }
  final choice = await present(
    NextcloudCertificateReviewData(
      endpoint: challenge.endpoint,
      certificates: certificate == null ? const [] : [certificate],
      previous: challenge.previous,
      mode: NextcloudTrustMode.pinnedLeaf,
      canApprove: eligible,
      failure: challenge.failure,
    ),
  );
  if (choice == CertificateReviewAction.importCa) {
    return _importCa(
      challenge.endpoint,
      owner,
      present,
      previous: challenge.previous,
    );
  }
  if (choice != CertificateReviewAction.approve || !eligible) return null;
  return NextcloudTrustPolicy.approve(
    owner: owner,
    installation: challenge.endpoint,
    mode: NextcloudTrustMode.pinnedLeaf,
    certificates: [certificate!],
    generation: const Uuid().v4(),
  );
}

Future<void> manageNextcloudCertificates(
  WidgetRef ref,
  String accountId,
  CertificateReviewPresenter present, {
  bool contactsOnly = false,
}) async {
  Uri? endpoint;
  NextcloudTrustPolicy? activePolicy;
  try {
    final contacts = ref.read(busyMaxContactsControllerProvider);
    final snapshot = contactsOnly
        ? null
        : await ref
              .read(authorizationPersistenceProvider)
              .readCurrentSnapshot(accountId);
    final secret = snapshot?.$1;
    if (!contactsOnly && secret is! NextcloudSecretRecord) return;
    final contactSnapshot = contactsOnly
        ? await contacts.privateTrustSnapshot(accountId)
        : null;
    final previous = contactsOnly
        ? contactSnapshot!.$2
        : (secret as NextcloudSecretRecord).trustPolicy;
    activePolicy = previous;
    endpoint = contactsOnly
        ? contactSnapshot!.$1
        : (secret as NextcloudSecretRecord).canonicalServer;
    final generation = contactsOnly ? contactSnapshot!.$3 : snapshot!.$2;
    final owner = contactsOnly ? 'contacts:$accountId' : accountId;
    final action = await present(
      NextcloudCertificateReviewData(
        endpoint: endpoint,
        previous: previous,
        mode: previous?.mode,
        management: true,
      ),
    );
    NextcloudTrustPolicy? replacement;
    if (action == CertificateReviewAction.importCa) {
      replacement = await _importCa(
        endpoint,
        owner,
        present,
        previous: previous,
      );
      if (replacement == null) return;
    } else if (action == CertificateReviewAction.replacePin) {
      final observed = await ref
          .read(nextcloudHttpClientFactoryProvider)
          .observe(endpoint);
      replacement = await reviewNextcloudCertificate(
        NextcloudCertificateException(
          NextcloudCertificateFailure.approvalRequired,
          endpoint: endpoint,
          observed: observed,
          previous: previous,
        ),
        owner,
        present,
      );
      if (replacement == null) return;
    } else if (action == CertificateReviewAction.revalidate) {
      replacement = previous;
    } else if (action == CertificateReviewAction.standard) {
      if (await present(
            NextcloudCertificateReviewData(
              endpoint: endpoint,
              previous: previous,
              canApprove: true,
            ),
          ) !=
          CertificateReviewAction.approve) {
        return;
      }
    } else {
      return;
    }
    if (contactsOnly) {
      await contacts.replacePrivateTrust(accountId, generation, replacement);
    } else {
      await ref
          .read(davAccountOnboardingServiceProvider)
          .replaceNextcloudTrust(
            accountId: accountId,
            expectedGeneration: generation,
            policy: replacement,
          );
    }
  } on Object catch (error) {
    if (error is DavException && error.kind == DavErrorKind.cancelled) return;
    if (endpoint != null) {
      final certificate = error is NextcloudCertificateException
          ? error.observed
          : null;
      await present(
        NextcloudCertificateReviewData(
          endpoint: endpoint,
          error: true,
          networkFailure:
              error is SocketException ||
              error is DavException &&
                  (error.kind == DavErrorKind.network ||
                      error.kind == DavErrorKind.timeout),
          failure: error is NextcloudCertificateException
              ? error.failure
              : null,
          certificates: certificate == null ? const [] : [certificate],
          previous: activePolicy,
        ),
      );
    }
  }
}

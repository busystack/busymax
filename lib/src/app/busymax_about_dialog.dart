import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../features/feedback/data/feedback_api_client.dart';
import '../features/feedback/presentation/feedback_dialog.dart';
import '../l10n/l10n.dart';
import '../platform/linux_header_bar_service.dart';
import 'busymax_design.dart';

const _busyMaxWebsiteUri = 'https://github.com/busystack/busymax';
const _busyMaxIssuesUri = 'https://github.com/busystack/busymax/issues';

Future<void> showBusyMaxAboutDialog(
  BuildContext context, {
  required FeedbackSubmissionService feedbackSubmissionService,
  LinuxHeaderBarService? headerBarService,
}) async {
  final service = headerBarService;
  if (service != null) {
    unawaited(service.setModalBarrierVisible(true));
  }
  _BusyMaxAboutAction? action;
  try {
    action = await showDialog<_BusyMaxAboutAction>(
      context: context,
      builder: (dialogContext) => BusyMaxAboutDialog(
        onSendFeedback: () =>
            Navigator.of(dialogContext).pop(_BusyMaxAboutAction.sendFeedback),
      ),
    );
  } finally {
    if (service != null) {
      unawaited(service.setModalBarrierVisible(false));
    }
  }
  if (action == _BusyMaxAboutAction.sendFeedback && context.mounted) {
    await showBusyMaxFeedbackDialog(
      context,
      submissionService: feedbackSubmissionService,
      headerBarService: headerBarService,
    );
  }
}

class BusyMaxAboutDialog extends StatelessWidget {
  const BusyMaxAboutDialog({super.key, this.onSendFeedback});

  final VoidCallback? onSendFeedback;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(BusyMaxSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: const _BusyMaxLogo(size: 72),
                  ),
                  const SizedBox(height: BusyMaxSpacing.md),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                  const SizedBox(height: BusyMaxSpacing.xs),
                  Text(
                    l10n.aboutBusyMaxDescription,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: BusyMaxSpacing.sm),
                  Align(
                    alignment: Alignment.center,
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final info = snapshot.data;
                        final version = info == null
                            ? ''
                            : 'v${info.version}+${info.buildNumber}';
                        return _VersionTag(version: version);
                      },
                    ),
                  ),
                  const SizedBox(height: BusyMaxSpacing.lg),
                  BusyMaxGroupedList(
                    filled: true,
                    children: [
                      BusyMaxActionRow(
                        title: l10n.website,
                        leading: const Icon(Icons.language),
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: BusyMaxSizes.iconSm,
                        ),
                        onTap: () => unawaited(
                          _openExternalUri(Uri.parse(_busyMaxWebsiteUri)),
                        ),
                      ),
                      BusyMaxActionRow(
                        title: l10n.sendFeedback,
                        leading: const Icon(Icons.feedback_outlined),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: BusyMaxSizes.iconSm,
                        ),
                        onTap: onSendFeedback,
                      ),
                      BusyMaxActionRow(
                        title: l10n.reportAnIssue,
                        leading: const Icon(YaruIcons.warning),
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: BusyMaxSizes.iconSm,
                        ),
                        onTap: () => unawaited(
                          _openExternalUri(Uri.parse(_busyMaxIssuesUri)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: BusyMaxSpacing.sm,
              end: BusyMaxSpacing.sm,
              child: BusyMaxDialogCloseButton(
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BusyMaxAboutAction { sendFeedback }

class _BusyMaxLogo extends StatelessWidget {
  const _BusyMaxLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/busymax-logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox.square(dimension: size),
    );
  }
}

class _VersionTag extends StatelessWidget {
  const _VersionTag({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    if (version.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BusyMaxSpacing.sm,
          vertical: BusyMaxSpacing.xs,
        ),
        child: Text(version, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

Future<void> _openExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

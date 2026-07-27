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
import 'busymax_dialog_identity.dart';
import 'busymax_dialogs.dart';

const _busyMaxWebsiteUri = 'https://github.com/busystack/busymax';
const _busyMaxIssuesUri = 'https://github.com/busystack/busymax/issues';

Future<void> showBusyMaxAboutDialog(
  BuildContext context, {
  required FeedbackSubmissionService feedbackSubmissionService,
  LinuxHeaderBarService? headerBarService,
}) async {
  final action = await showBusyMaxModalDialog<_BusyMaxAboutAction>(
    context,
    headerBarService: headerBarService,
    builder: (dialogContext) => BusyMaxAboutDialog(
      onSendFeedback: () =>
          Navigator.of(dialogContext).pop(_BusyMaxAboutAction.sendFeedback),
    ),
  );
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
    final theme = Theme.of(context);
    return BusyMaxInformationalDialog(
      closeLabel: l10n.close,
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BusyMaxDialogIdentity(
            visual: const _BusyMaxLogo(),
            title: l10n.appTitle,
          ),
          const SizedBox(height: BusyMaxSpacing.xs),
          Text(
            l10n.aboutBusyMaxDescription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: BusyMaxSpacing.sm),
          Align(
            alignment: Alignment.center,
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final version = info == null ? '' : _formatVersion(info);
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
                onTap: () =>
                    unawaited(_openExternalUri(Uri.parse(_busyMaxWebsiteUri))),
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
                onTap: () =>
                    unawaited(_openExternalUri(Uri.parse(_busyMaxIssuesUri))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BusyMaxAboutAction { sendFeedback }

class _BusyMaxLogo extends StatelessWidget {
  const _BusyMaxLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/busymax-logo.png',
      width: BusyMaxDialogIdentity.visualExtent,
      height: BusyMaxDialogIdentity.visualExtent,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          const SizedBox.square(dimension: BusyMaxDialogIdentity.visualExtent),
    );
  }
}

String _formatVersion(PackageInfo info) {
  final version = info.version.trim();
  final buildNumber = info.buildNumber.trim();
  if (version.isEmpty && buildNumber.isEmpty) {
    return '';
  }
  final versionWithBuild = switch ((version, buildNumber)) {
    ('', final build) => build,
    (final release, '') => release,
    (final release, final build) => '$release+$build',
  };
  return versionWithBuild.startsWith('v')
      ? versionWithBuild
      : 'v$versionWithBuild';
}

class _VersionTag extends StatelessWidget {
  const _VersionTag({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    if (version.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return YaruTranslucentContainer(
      opacity: 1,
      border: const Border(),
      borderRadius: const BorderRadius.all(Radius.circular(kYaruButtonRadius)),
      color: colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BusyMaxSpacing.sm,
          vertical: BusyMaxSpacing.xs,
        ),
        child: Text(
          version,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

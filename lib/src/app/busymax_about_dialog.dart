import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../l10n/l10n.dart';
import '../platform/linux_header_bar_service.dart';
import 'busymax_design.dart';
import 'busymax_dialog_identity.dart';
import 'busymax_dialogs.dart';
import 'busymax_surface_colors.dart';

const _busyMaxWebsiteUrl = 'https://busystack.org';
const _busyMaxRepositoryUrl = 'https://github.com/busystack/busymax/';
const _apacheLicenseUrl = 'https://www.apache.org/licenses/LICENSE-2.0';

Future<void> showBusyMaxAboutDialog(
  BuildContext context, {
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalDialog<void>(
    context,
    headerBarService: headerBarService,
    builder: (dialogContext) => const BusyMaxAboutDialog(),
  );
}

class BusyMaxAboutDialog extends StatelessWidget {
  const BusyMaxAboutDialog({super.key});

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
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null ? '' : _formatVersion(info);
              return _VersionTag(version: version);
            },
          ),
          const SizedBox(height: BusyMaxSpacing.md),
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.license,
                subtitle: l10n.apacheLicenseName,
                leading: const Icon(YaruIcons.information),
                trailing: const Icon(YaruIcons.external_link),
                onTap: () =>
                    unawaited(_openExternalUri(Uri.parse(_apacheLicenseUrl))),
              ),
              BusyMaxActionRow(
                title: l10n.website,
                subtitle: _busyMaxWebsiteUrl,
                leading: const Icon(YaruIcons.home),
                trailing: const Icon(YaruIcons.external_link),
                onTap: () =>
                    unawaited(_openExternalUri(Uri.parse(_busyMaxWebsiteUrl))),
              ),
              BusyMaxActionRow(
                title: l10n.sourceCode,
                subtitle: _busyMaxRepositoryUrl,
                leading: const Icon(YaruIcons.code),
                trailing: const Icon(YaruIcons.external_link),
                onTap: () => unawaited(
                  _openExternalUri(Uri.parse(_busyMaxRepositoryUrl)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    final colors = BusyMaxSurfaceColors.of(context);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.control,
          borderRadius: BorderRadius.circular(BusyMaxRadius.pill),
          border: Border.all(color: colors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BusyMaxSpacing.md,
            vertical: BusyMaxSpacing.xs,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              version,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

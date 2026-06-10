import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../l10n/l10n.dart';
import '../platform/linux_header_bar_service.dart';
import 'busymax_design.dart';

const _busyMaxWebsiteUri = 'https://github.com/busystack/busymax';
const _busyMaxIssuesUri = 'https://github.com/busystack/busymax/issues';

Future<void> showBusyMaxAboutDialog(
  BuildContext context, {
  LinuxHeaderBarService? headerBarService,
}) async {
  final service = headerBarService;
  if (service != null) {
    unawaited(service.setModalBarrierVisible(true));
  }
  try {
    await showDialog<void>(
      context: context,
      builder: (context) => const BusyMaxAboutDialog(),
    );
  } finally {
    if (service != null) {
      unawaited(service.setModalBarrierVisible(false));
    }
  }
}

class BusyMaxAboutDialog extends StatelessWidget {
  const BusyMaxAboutDialog({super.key});

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

class _BusyMaxLogo extends StatefulWidget {
  const _BusyMaxLogo({required this.size});

  final double size;

  @override
  State<_BusyMaxLogo> createState() => _BusyMaxLogoState();
}

class _BusyMaxLogoState extends State<_BusyMaxLogo> {
  late final Future<Uint8List?> _logoBytes = _loadLogoBytes();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _logoBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            filterQuality: FilterQuality.high,
          );
        }
        return SizedBox.square(dimension: widget.size);
      },
    );
  }

  Future<Uint8List?> _loadLogoBytes() async {
    const assetPath = 'assets/branding/busymax-logo.png';
    try {
      final data = await rootBundle.load(assetPath);
      return Uint8List.view(
        data.buffer,
        data.offsetInBytes,
        data.lengthInBytes,
      );
    } on Object {
      return _loadLogoFileBytes(assetPath);
    }
  }

  Future<Uint8List?> _loadLogoFileBytes(String assetPath) async {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      p.join(executableDir, 'data', 'flutter_assets', assetPath),
      assetPath,
    ];
    for (final candidate in candidates) {
      try {
        final file = File(candidate);
        if (await file.exists()) {
          return file.readAsBytes();
        }
      } on Object {
        // Try the next known location.
      }
    }
    return null;
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

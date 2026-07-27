import 'package:flutter/material.dart';

import 'busymax_design.dart';

/// Native Yaru chrome shared by BusyMax's informational dialogs.
///
/// The title bar deliberately lives outside the scroll viewport. This keeps
/// its window control fixed, fully opaque, and at Yaru's native metric while
/// the dialog content remains usable in compact windows and at large text
/// scales.
class BusyMaxInformationalDialog extends StatelessWidget {
  const BusyMaxInformationalDialog({
    required this.closeLabel,
    required this.maxWidth,
    required this.child,
    this.maxHeight,
    super.key,
  });

  final String closeLabel;
  final double maxWidth;
  final double? maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dialogSurface = busyMaxDialogSurfaceColor(context);
    return BusyMaxSurfaceScope(
      role: BusyMaxSurfaceRole.dialog,
      child: Builder(
        builder: (context) {
          return Dialog(
            backgroundColor: dialogSurface,
            surfaceTintColor: dialogSurface,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight ?? double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BusyMaxDialogTitleBar(closeSemanticLabel: closeLabel),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BusyMaxSpacing.lg),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shared application identity treatment for informational dialogs.
///
/// The 128-pixel visual follows libadwaita's large application-icon metric.
/// Dialogs provide their own visual while this widget keeps its geometry and
/// title hierarchy consistent.
class BusyMaxDialogIdentity extends StatelessWidget {
  const BusyMaxDialogIdentity({
    required this.visual,
    required this.title,
    super.key,
  });

  static const visualExtent = 128.0;
  static const titleWeight = FontWeight.bold;

  final Widget visual;
  final String title;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: titleWeight) ??
        const TextStyle(fontWeight: titleWeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.md),
            child: SizedBox.square(dimension: visualExtent, child: visual),
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        Text(title, textAlign: TextAlign.center, style: titleStyle),
      ],
    );
  }
}

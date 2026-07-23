import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../platform/linux_header_bar_service.dart';
import '../platform/linux_header_bar_provider.dart';
import '../platform/native_dialog_service.dart';
import 'busymax_design.dart';
import 'busymax_shortcuts.dart';

const _modalShortcuts = <ShortcutActivator, Intent>{
  BusyMaxShortcutActivators.keyboardShortcuts:
      DoNothingAndStopPropagationIntent(),
  BusyMaxShortcutActivators.settings: DoNothingAndStopPropagationIntent(),
};

/// Prevents application-level navigation shortcuts from escaping a modal
/// surface while preserving shortcuts owned by that surface's descendants.
///
/// Use this for modal UI that is not presented by [showBusyMaxModalDialog],
/// such as anchored popovers and in-page editor overlays.
class BusyMaxModalShortcutBoundary extends StatelessWidget {
  const BusyMaxModalShortcutBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(shortcuts: _modalShortcuts, child: child);
  }
}

final _modalDepths = Map<LinuxHeaderBarService, int>.identity();

Future<T?> showBusyMaxModalDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  LinuxHeaderBarService? headerBarService,
  Color? barrierColor,
  bool barrierDismissible = true,
}) async {
  final effectiveHeaderBarService =
      headerBarService ?? _headerBarServiceFrom(context);
  return _coordinateBusyMaxModal<T>(
    context,
    headerBarService: effectiveHeaderBarService,
    showSurface: () => _showBusyMaxFlutterDialog<T>(
      context,
      builder: builder,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
    ),
  );
}

Future<T?> _coordinateBusyMaxModal<T>(
  BuildContext context, {
  required LinuxHeaderBarService? headerBarService,
  required Future<T?> Function() showSurface,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  await acquireBusyMaxModalBarrier(headerBarService);
  if (!context.mounted) {
    await releaseBusyMaxModalBarrier(headerBarService);
    return null;
  }

  try {
    return await showSurface();
  } finally {
    await releaseBusyMaxModalBarrier(headerBarService);
    if (previousFocus?.context != null && previousFocus!.canRequestFocus) {
      previousFocus.requestFocus();
    }
  }
}

Future<T?> _showBusyMaxFlutterDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: barrierColor ?? busyMaxModalBarrierColor(context),
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (dialogContext) =>
        BusyMaxModalShortcutBoundary(child: builder(dialogContext)),
  );
}

Future<T?> showBusyMaxModalEditorDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  LinuxHeaderBarService? headerBarService,
  double maxWidth = BusyMaxSizes.compactDetailsWidth,
  double? maxHeight = 760,
}) async {
  return showBusyMaxModalDialog<T>(
    context,
    headerBarService: headerBarService,
    barrierDismissible: false,
    builder: (dialogContext) {
      final reduceMotion = MediaQuery.disableAnimationsOf(dialogContext);
      return Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(BusyMaxSpacing.lg),
        insetAnimationDuration: reduceMotion
            ? Duration.zero
            : BusyMaxMotion.dialogInsets,
        insetAnimationCurve: BusyMaxMotion.dialogInsetsCurve,
        child: BusyMaxModalEditorSurface(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          child: builder(dialogContext),
        ),
      );
    },
  );
}

Future<String?> showBusyMaxTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String actionLabel,
  String? initialValue,
  String? message,
  Color? barrierColor,
  LinuxHeaderBarService? headerBarService,
}) async {
  return showBusyMaxModalDialog<String>(
    context,
    headerBarService: headerBarService,
    barrierColor: barrierColor,
    barrierDismissible: false,
    builder: (dialogContext) => BusyMaxPromptDialog(
      title: title,
      label: label,
      actionLabel: actionLabel,
      initialValue: initialValue,
      message: message,
    ),
  );
}

Future<bool> showBusyMaxConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  Color? barrierColor,
  LinuxHeaderBarService? headerBarService,
  NativeDialogService nativeDialogService = const NativeDialogService(),
}) async {
  final nativeResult = await nativeDialogService.confirm(
    title: title,
    message: message,
    cancelLabel: context.l10n.cancel,
    confirmLabel: confirmLabel,
    destructive: destructive,
  );
  if (nativeResult.available) {
    // GTK owns parent modality for its transient dialog. Adding BusyMax's
    // Flutter/header-bar barrier here would dim only part of the native window
    // and duplicate the platform's input blocking.
    return nativeResult.confirmed;
  }
  if (!context.mounted) {
    return false;
  }

  final confirmed = await showBusyMaxModalDialog<bool>(
    context,
    headerBarService: headerBarService,
    barrierColor: barrierColor,
    builder: (dialogContext) => BusyMaxConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return confirmed == true;
}

/// Acquires a reference-counted native header-bar modal barrier.
///
/// Every call must be paired with [releaseBusyMaxModalBarrier]. In-page modal
/// surfaces should use this pair; route dialogs acquire it automatically.
Future<void> acquireBusyMaxModalBarrier(LinuxHeaderBarService? service) async {
  if (service == null) {
    return;
  }
  final depth = _modalDepths[service] ?? 0;
  _modalDepths[service] = depth + 1;
  if (depth == 0) {
    await service.setModalBarrierVisible(true);
  }
}

/// Releases a barrier acquired by [acquireBusyMaxModalBarrier].
Future<void> releaseBusyMaxModalBarrier(LinuxHeaderBarService? service) async {
  if (service == null) {
    return;
  }
  final depth = _modalDepths[service] ?? 0;
  if (depth <= 1) {
    _modalDepths.remove(service);
    await service.setModalBarrierVisible(false);
    return;
  }
  _modalDepths[service] = depth - 1;
}

LinuxHeaderBarService? _headerBarServiceFrom(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(linuxHeaderBarServiceProvider);
  } on StateError {
    // Standalone widget hosts (including lightweight tests) do not
    // necessarily install Riverpod. Explicit injection remains available.
    return null;
  }
}

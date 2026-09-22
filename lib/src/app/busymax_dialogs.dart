import 'package:flutter/material.dart';

import 'busymax_design.dart';
import 'busymax_shortcuts.dart';
import 'busymax_window_close.dart';

const _modalShortcuts = <ShortcutActivator, Intent>{
  BusyMaxShortcutActivators.keyboardShortcuts:
      DoNothingAndStopPropagationIntent(),
  BusyMaxShortcutActivators.settings: DoNothingAndStopPropagationIntent(),
  BusyMaxShortcutActivators.back: DoNothingAndStopPropagationIntent(),
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

Future<T?> showBusyMaxModalDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final result = await _showBusyMaxFlutterDialog<T>(
    context,
    builder: builder,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
  );
  if (previousFocus?.context?.mounted == true &&
      previousFocus!.canRequestFocus) {
    previousFocus.requestFocus();
  }
  return result;
}

Future<T?> _showBusyMaxFlutterDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final closeCoordinator = BusyMaxWindowCloseScope.maybeOf(context);
  final route = _BusyMaxDialogRoute<T>(
    context: context,
    builder: builder,
    themes: themes,
    closeCoordinator: closeCoordinator,
    fixedBarrierColor: barrierColor,
    initialBarrierColor: barrierColor ?? busyMaxModalBarrierColor(context),
    barrierDismissible: barrierDismissible,
  );
  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}

class _BusyMaxDialogRoute<T> extends DialogRoute<T> {
  _BusyMaxDialogRoute({
    required super.context,
    required WidgetBuilder builder,
    required CapturedThemes themes,
    required BusyMaxWindowCloseCoordinator? closeCoordinator,
    required Color? fixedBarrierColor,
    required Color initialBarrierColor,
    required super.barrierDismissible,
  }) : _fixedBarrierColor = fixedBarrierColor,
       _initialBarrierColor = initialBarrierColor,
       super(
         builder: (dialogContext) {
           final dialog = BusyMaxWindowCloseGuard(
             onCloseRequested: () => false,
             child: BusyMaxModalShortcutBoundary(child: builder(dialogContext)),
           );
           return closeCoordinator == null
               ? dialog
               : BusyMaxWindowCloseScope(
                   coordinator: closeCoordinator,
                   child: dialog,
                 );
         },
         themes: themes,
         barrierColor: initialBarrierColor,
         traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
       );

  final Color? _fixedBarrierColor;
  final Color _initialBarrierColor;

  /// Unlike [DialogRoute]'s constructor value, this getter is reevaluated
  /// when the Navigator's inherited theme changes.
  @override
  Color? get barrierColor {
    final fixedColor = _fixedBarrierColor;
    if (fixedColor != null) {
      return fixedColor;
    }
    final navigatorContext = navigator?.context;
    return navigatorContext == null
        ? _initialBarrierColor
        : busyMaxModalBarrierColor(navigatorContext);
  }
}

Future<T?> showBusyMaxModalEditorDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  double maxWidth = BusyMaxSizes.compactDetailsWidth,
  double? maxHeight = 760,
}) async {
  return showBusyMaxModalDialog<T>(
    context,
    barrierColor: barrierColor,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BusyMaxModalEditorSurface(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        insetPadding: const EdgeInsets.all(BusyMaxSpacing.lg),
        child: builder(dialogContext),
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
}) {
  return showBusyMaxModalDialog<String>(
    context,
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
}) async {
  final confirmed = await showBusyMaxModalDialog<bool>(
    context,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/linux_header_bar_service.dart';
import '../platform/linux_header_bar_provider.dart';
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

final _modalStates =
    Map<LinuxHeaderBarService, _BusyMaxModalBarrierState>.identity();
final _modalBarrierUpdateTails =
    Map<LinuxHeaderBarService, Future<void>>.identity();

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
    shadesHeader: barrierColor == null || barrierColor.a > 0,
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
  required bool shadesHeader,
  required Future<T?> Function() showSurface,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  await acquireBusyMaxModalBarrier(
    headerBarService,
    shadesHeader: shadesHeader,
  );
  if (!context.mounted) {
    await releaseBusyMaxModalBarrier(
      headerBarService,
      shadesHeader: shadesHeader,
    );
    return null;
  }

  try {
    return await showSurface();
  } finally {
    await releaseBusyMaxModalBarrier(
      headerBarService,
      shadesHeader: shadesHeader,
    );
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
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    _BusyMaxDialogRoute<T>(
      context: context,
      builder: builder,
      themes: themes,
      fixedBarrierColor: barrierColor,
      initialBarrierColor: barrierColor ?? busyMaxModalBarrierColor(context),
      barrierDismissible: barrierDismissible,
    ),
  );
}

class _BusyMaxDialogRoute<T> extends DialogRoute<T> {
  _BusyMaxDialogRoute({
    required super.context,
    required WidgetBuilder builder,
    required CapturedThemes themes,
    required Color? fixedBarrierColor,
    required Color initialBarrierColor,
    required super.barrierDismissible,
  }) : _fixedBarrierColor = fixedBarrierColor,
       _initialBarrierColor = initialBarrierColor,
       super(
         builder: (dialogContext) =>
             BusyMaxModalShortcutBoundary(child: builder(dialogContext)),
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
  LinuxHeaderBarService? headerBarService,
  double maxWidth = BusyMaxSizes.compactDetailsWidth,
  double? maxHeight = 760,
}) async {
  return showBusyMaxModalDialog<T>(
    context,
    headerBarService: headerBarService,
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
  LinuxHeaderBarService? headerBarService,
}) {
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
}) async {
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
/// Set [shadesHeader] to false when the matching Flutter barrier is fully
/// transparent but still blocks interaction.
Future<void> acquireBusyMaxModalBarrier(
  LinuxHeaderBarService? service, {
  bool shadesHeader = true,
}) async {
  if (service == null) {
    return;
  }
  final state = _modalStates.putIfAbsent(
    service,
    _BusyMaxModalBarrierState.new,
  );
  final previousVisible = state.modalDepth > 0;
  final previousShadeDepth = state.shadeDepth;
  state.modalDepth += 1;
  if (shadesHeader) {
    state.shadeDepth += 1;
  }
  final visible = state.modalDepth > 0;
  final stateChanged =
      visible != previousVisible || state.shadeDepth != previousShadeDepth;
  final stateUpdate = stateChanged
      ? _enqueueBusyMaxModalBarrierUpdate(
          service,
          visible: visible,
          shadeDepth: state.shadeDepth,
        )
      : _modalBarrierUpdateTails[service];
  if (stateUpdate == null) {
    return;
  }

  try {
    // A nested transparent route shares the in-flight native state without
    // adding a shade. A visibly shaded route increments only shadeDepth.
    await stateUpdate;
  } on Object catch (error, stackTrace) {
    state.modalDepth -= 1;
    if (shadesHeader) {
      state.shadeDepth -= 1;
    }
    if (state.modalDepth == 0) {
      _modalStates.remove(service);
    }
    try {
      // The platform may have applied the state before its response failed.
      // Restore the preceding native state while preserving the cause.
      await _enqueueBusyMaxModalBarrierUpdate(
        service,
        visible: state.modalDepth > 0,
        shadeDepth: state.shadeDepth,
      );
    } on Object {
      // Best-effort rollback cannot replace the causative exception.
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

/// Releases a barrier acquired by [acquireBusyMaxModalBarrier].
///
/// [shadesHeader] must match the value used by the corresponding acquire.
Future<void> releaseBusyMaxModalBarrier(
  LinuxHeaderBarService? service, {
  bool shadesHeader = true,
}) async {
  if (service == null) {
    return;
  }
  final state = _modalStates[service];
  if (state == null || state.modalDepth == 0) {
    return;
  }
  final previousVisible = state.modalDepth > 0;
  final previousShadeDepth = state.shadeDepth;
  state.modalDepth -= 1;
  if (shadesHeader && state.shadeDepth > 0) {
    state.shadeDepth -= 1;
  }
  final visible = state.modalDepth > 0;
  if (!visible) {
    _modalStates.remove(service);
  }
  if (visible == previousVisible && state.shadeDepth == previousShadeDepth) {
    final pending = _modalBarrierUpdateTails[service];
    if (pending != null) {
      await pending;
    }
    return;
  }
  await _enqueueBusyMaxModalBarrierUpdate(
    service,
    visible: visible,
    shadeDepth: state.shadeDepth,
  );
}

Future<void> _enqueueBusyMaxModalBarrierUpdate(
  LinuxHeaderBarService service, {
  required bool visible,
  required int shadeDepth,
}) {
  final previous = _modalBarrierUpdateTails[service] ?? Future<void>.value();
  final ready = previous.then<void>(
    (_) {},
    // A failed update belongs to the caller that requested it. It must not
    // poison the per-service queue and prevent a rollback or later retry.
    onError: (Object _, StackTrace _) {},
  );
  late final Future<void> update;
  update = ready
      .then(
        (_) => service.setModalBarrierState(
          visible: visible,
          shadeDepth: shadeDepth,
        ),
      )
      .whenComplete(() {
        if (identical(_modalBarrierUpdateTails[service], update)) {
          _modalBarrierUpdateTails.remove(service);
        }
      });
  _modalBarrierUpdateTails[service] = update;
  return update;
}

final class _BusyMaxModalBarrierState {
  int modalDepth = 0;
  int shadeDepth = 0;
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

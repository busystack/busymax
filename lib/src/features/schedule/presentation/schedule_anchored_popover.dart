import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';

typedef ScheduleAnchoredPopoverBuilder =
    Widget Function(
      BuildContext context,
      BusyMaxPopoverArrowSide arrowSide,
      double arrowAlignment,
    );

/// Coordinates anchored popovers with schedule-owned native header actions.
class ScheduleAnchoredPopoverController {
  _SchedulePopoverRegistration? _active;

  bool get isOpen => _active != null;

  Future<void> dismiss() {
    return _active?.dismiss() ?? Future<void>.value();
  }

  void _attach(_SchedulePopoverRegistration registration) {
    _active = registration;
  }

  void _detach(Object token) {
    if (_active?.token == token) {
      _active = null;
    }
  }
}

class ScheduleAnchoredPopoverScope extends InheritedWidget {
  const ScheduleAnchoredPopoverScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ScheduleAnchoredPopoverController controller;

  static ScheduleAnchoredPopoverController? maybeControllerOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<ScheduleAnchoredPopoverScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(ScheduleAnchoredPopoverScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

class _SchedulePopoverRegistration {
  const _SchedulePopoverRegistration({
    required this.token,
    required this.dismiss,
  });

  final Object token;
  final Future<void> Function() dismiss;
}

/// Presents a keyboard-modal desktop popover anchored to a widget or pointer.
///
/// The route owns focus while it is visible, restores the previous focus on
/// dismissal, and constrains its child to the real space above or below the
/// anchor. Callers remain responsible only for their popover content.
Future<T?> showScheduleAnchoredPopover<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required ScheduleAnchoredPopoverBuilder builder,
  required String semanticLabel,
  Offset? anchorPoint,
  double preferredWidth = 420,
  double minimumWidth = 280,
  double preferredMinimumHeight = 240,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final anchorRect = anchorPoint == null
      ? scheduleGlobalRectFor(anchorContext)
      : Rect.fromCenter(center: anchorPoint, width: 1, height: 1);
  final disableAnimations =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final controller =
      ScheduleAnchoredPopoverScope.maybeControllerOf(anchorContext) ??
      ScheduleAnchoredPopoverScope.maybeControllerOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = RawDialogRoute<T>(
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 120),
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.stop,
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ScheduleAnchoredPopoverRoute(
        anchorRect: anchorRect,
        preferredWidth: preferredWidth,
        minimumWidth: minimumWidth,
        preferredMinimumHeight: preferredMinimumHeight,
        semanticLabel: semanticLabel,
        builder: builder,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (disableAnimations) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  final routeResult = navigator.push<T>(route);
  final token = Object();
  final finished = Completer<void>();
  controller?._attach(
    _SchedulePopoverRegistration(
      token: token,
      dismiss: () async {
        if (route.isCurrent) {
          navigator.pop();
        }
        await finished.future;
      },
    ),
  );
  try {
    return await routeResult;
  } finally {
    if (previousFocus?.context?.mounted ?? false) {
      previousFocus!.requestFocus();
    }
    controller?._detach(token);
    if (!finished.isCompleted) {
      finished.complete();
    }
  }
}

Rect? scheduleGlobalRectFor(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

class _ScheduleAnchoredPopoverRoute extends StatelessWidget {
  const _ScheduleAnchoredPopoverRoute({
    required this.anchorRect,
    required this.preferredWidth,
    required this.minimumWidth,
    required this.preferredMinimumHeight,
    required this.builder,
    required this.semanticLabel,
  });

  final Rect? anchorRect;
  final double preferredWidth;
  final double minimumWidth;
  final double preferredMinimumHeight;
  final ScheduleAnchoredPopoverBuilder builder;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _SchedulePopoverLayout.resolve(
              anchor: anchorRect,
              viewport: constraints.biggest,
              textDirection: Directionality.of(context),
              preferredWidth: preferredWidth,
              minimumWidth: minimumWidth,
              preferredMinimumHeight: preferredMinimumHeight,
            );
            return BusyMaxModalShortcutBoundary(
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Actions(
                  actions: {
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (_) {
                        Navigator.of(context).pop();
                        return null;
                      },
                    ),
                  },
                  child: FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: Focus(
                      autofocus: true,
                      child: Semantics(
                        scopesRoute: true,
                        namesRoute: true,
                        label: semanticLabel,
                        explicitChildNodes: true,
                        child: BlockSemantics(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomSingleChildLayout(
                                  delegate: _SchedulePopoverPositionDelegate(
                                    layout,
                                  ),
                                  child: builder(
                                    context,
                                    layout.arrowSide,
                                    layout.arrowAlignment,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SchedulePopoverLayout {
  const _SchedulePopoverLayout({
    required this.anchor,
    required this.left,
    required this.width,
    required this.maximumHeight,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  factory _SchedulePopoverLayout.resolve({
    required Rect? anchor,
    required Size viewport,
    required TextDirection textDirection,
    required double preferredWidth,
    required double minimumWidth,
    required double preferredMinimumHeight,
  }) {
    const margin = BusyMaxSpacing.md;
    const gap = BusyMaxSpacing.xs;
    final availableWidth = math.max(0.0, viewport.width - margin * 2);
    final width = availableWidth < minimumWidth
        ? availableWidth
        : math.min(preferredWidth, availableWidth);
    final maximumLeft = math.max(margin, viewport.width - width - margin);
    if (anchor == null) {
      return _SchedulePopoverLayout(
        anchor: null,
        left: ((viewport.width - width) / 2)
            .clamp(margin, maximumLeft)
            .toDouble(),
        width: width,
        maximumHeight: math.max(0, viewport.height - margin * 2),
        arrowSide: BusyMaxPopoverArrowSide.top,
        arrowAlignment: 0.5,
      );
    }

    final preferredLeft = textDirection == TextDirection.rtl
        ? anchor.right - width
        : anchor.left;
    final left = preferredLeft.clamp(margin, maximumLeft).toDouble();
    final spaceAbove = math.max(0.0, anchor.top - gap - margin);
    final spaceBelow = math.max(
      0.0,
      viewport.height - anchor.bottom - gap - margin,
    );
    final showBelow =
        spaceBelow >= math.min(preferredMinimumHeight, spaceAbove) ||
        spaceBelow >= spaceAbove;
    final arrowAlignment = width <= 0
        ? 0.5
        : ((anchor.center.dx - left) / width).clamp(0.08, 0.92).toDouble();
    return _SchedulePopoverLayout(
      anchor: anchor,
      left: left,
      width: width,
      maximumHeight: showBelow ? spaceBelow : spaceAbove,
      arrowSide: showBelow
          ? BusyMaxPopoverArrowSide.top
          : BusyMaxPopoverArrowSide.bottom,
      arrowAlignment: arrowAlignment,
    );
  }

  final Rect? anchor;
  final double left;
  final double width;
  final double maximumHeight;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;
}

class _SchedulePopoverPositionDelegate extends SingleChildLayoutDelegate {
  const _SchedulePopoverPositionDelegate(this.layout);

  final _SchedulePopoverLayout layout;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: layout.width,
      maxWidth: layout.width,
      maxHeight: layout.maximumHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const margin = BusyMaxSpacing.md;
    const gap = BusyMaxSpacing.xs;
    final maximumTop = math.max(
      margin,
      size.height - childSize.height - margin,
    );
    final anchor = layout.anchor;
    if (anchor == null) {
      return Offset(
        layout.left,
        ((size.height - childSize.height) / 2)
            .clamp(margin, maximumTop)
            .toDouble(),
      );
    }
    final preferredTop = switch (layout.arrowSide) {
      BusyMaxPopoverArrowSide.top => anchor.bottom + gap,
      BusyMaxPopoverArrowSide.bottom => anchor.top - childSize.height - gap,
    };
    return Offset(
      layout.left,
      preferredTop.clamp(margin, maximumTop).toDouble(),
    );
  }

  @override
  bool shouldRelayout(covariant _SchedulePopoverPositionDelegate oldDelegate) {
    return layout.anchor != oldDelegate.layout.anchor ||
        layout.left != oldDelegate.layout.left ||
        layout.width != oldDelegate.layout.width ||
        layout.maximumHeight != oldDelegate.layout.maximumHeight ||
        layout.arrowSide != oldDelegate.layout.arrowSide ||
        layout.arrowAlignment != oldDelegate.layout.arrowAlignment;
  }
}

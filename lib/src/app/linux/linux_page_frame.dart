import 'package:flutter/material.dart';

import '../busymax_design.dart';
import '../busymax_surface_colors.dart';
import 'linux_window_host.dart';

/// The canonical Linux page composition.
///
/// The sidebar header and body are a single full-height child of one clipped
/// allocation, so their visible edge is physically identical at every frame.
class LinuxPageFrame extends StatefulWidget {
  const LinuxPageFrame({
    super.key,
    required this.header,
    required this.body,
    this.sidebarHeader,
    this.sidebarBody,
    this.sidebarAvailable = false,
    this.sidebarExpanded = false,
    this.sidebarTransitionGeneration = 0,
  });

  final Widget header;
  final Widget body;
  final Widget? sidebarHeader;
  final Widget? sidebarBody;
  final bool sidebarAvailable;
  final bool sidebarExpanded;
  final int sidebarTransitionGeneration;

  @override
  State<LinuxPageFrame> createState() => _LinuxPageFrameState();
}

class _LinuxPageFrameState extends State<LinuxPageFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: _targetVisible ? 1 : 0,
  );
  late int _generation;
  bool _disableAnimations = false;

  bool get _hasSidebar =>
      widget.sidebarHeader != null && widget.sidebarBody != null;
  bool get _targetVisible =>
      _hasSidebar && widget.sidebarAvailable && widget.sidebarExpanded;

  @override
  void initState() {
    super.initState();
    _generation = widget.sidebarTransitionGeneration;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled && _controller.isAnimating) {
        _controller.value = _targetVisible ? 1 : 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant LinuxPageFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetVisible ? 1.0 : 0.0;
    if (widget.sidebarTransitionGeneration == _generation) {
      final oldTarget =
          oldWidget.sidebarHeader != null &&
          oldWidget.sidebarBody != null &&
          oldWidget.sidebarAvailable &&
          oldWidget.sidebarExpanded;
      if (oldTarget != _targetVisible) {
        _controller
          ..stop()
          ..value = target;
      }
      return;
    }
    _generation = widget.sidebarTransitionGeneration;
    if (_disableAnimations) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    if (distance == 0) {
      _controller
        ..stop()
        ..value = target;
      return;
    }
    _controller.animateTo(
      target,
      duration: BusyMaxMotion.sidebar * distance,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final metrics = LinuxWindowMetricsScope.of(context);
    final textDirection = Directionality.of(context);
    final sidebarAtLeft = textDirection == TextDirection.ltr;
    final sidebarControlInset = sidebarAtLeft
        ? metrics.leftControlInset
        : metrics.rightControlInset;
    final oppositeControlInset = sidebarAtLeft
        ? metrics.rightControlInset
        : metrics.leftControlInset;
    final sidebar = _hasSidebar
        ? SizedBox(
            width: BusyMaxSizes.sidebarWidth,
            child: ColoredBox(
              color: colors.sidebar,
              child: Column(
                children: [
                  SizedBox(
                    height: BusyMaxLinuxWindowMetrics.headerHeight,
                    child: Padding(
                      padding: sidebarAtLeft
                          ? EdgeInsets.only(left: sidebarControlInset)
                          : EdgeInsets.only(right: sidebarControlInset),
                      child: widget.sidebarHeader!,
                    ),
                  ),
                  Expanded(child: widget.sidebarBody!),
                ],
              ),
            ),
          )
        : null;
    final main = _LinuxFrameMain(
      header: ColoredBox(color: colors.window, child: widget.header),
      body: widget.body,
    );
    return AnimatedBuilder(
      animation: _controller,
      child: main,
      builder: (context, mainChild) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final rawWidth = BusyMaxSizes.sidebarWidth * _controller.value;
        final presentedWidth =
            (rawWidth * devicePixelRatio).round() / devicePixelRatio;
        final widthFactor = presentedWidth / BusyMaxSizes.sidebarWidth;
        final sidebarSideOverlap = (sidebarControlInset - presentedWidth)
            .clamp(0.0, double.infinity)
            .toDouble();
        final mainPadding = sidebarAtLeft
            ? EdgeInsets.only(
                left: sidebarSideOverlap,
                right: oppositeControlInset,
              )
            : EdgeInsets.only(
                left: oppositeControlInset,
                right: sidebarSideOverlap,
              );
        final sidebarInteractive = _targetVisible && _controller.value == 1;
        return Row(
          children: [
            if (sidebar != null)
              DecoratedBox(
                key: const ValueKey('linux-sidebar-viewport'),
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    end: BorderSide(
                      color: colors.sidebarBorder.withValues(
                        alpha: _controller.value == 0 ? 0 : 1,
                      ),
                    ),
                  ),
                ),
                child: IgnorePointer(
                  ignoring: !sidebarInteractive,
                  child: ExcludeFocus(
                    excluding: !sidebarInteractive,
                    child: ExcludeSemantics(
                      excluding: !sidebarInteractive,
                      child: TickerMode(
                        enabled: sidebarInteractive || _controller.value > 0,
                        child: ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: widthFactor,
                            child: sidebar,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: BusyMaxLinuxWindowMetrics.headerHeight,
                    child: Padding(
                      padding: mainPadding,
                      child: (mainChild! as _LinuxFrameMain).header,
                    ),
                  ),
                  Expanded(child: (mainChild as _LinuxFrameMain).body),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinuxFrameMain extends StatelessWidget {
  const _LinuxFrameMain({required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class BusyMaxLinuxBrandHeader extends StatelessWidget {
  const BusyMaxLinuxBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LinuxTitlebarGestureRegion(
      child: Center(
        child: Text(
          'BusyMax',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: busyMaxHeaderTitleStyle(context),
        ),
      ),
    );
  }
}

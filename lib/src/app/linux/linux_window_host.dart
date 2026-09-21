import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../l10n/l10n.dart';
import '../../platform/gtk_window_preferences_service.dart';
import '../busymax_design.dart';
import '../busymax_surface_colors.dart';

/// Shared dimensions for Flutter-owned Linux chrome.
abstract final class BusyMaxLinuxWindowMetrics {
  static const double headerHeight = BusyMaxSizes.toolbarHeight;
  static const double controlSize = kYaruWindowControlSize;
  static const double controlSpacing = 14;
  static const double controlHorizontalPadding = 10;

  static double clusterWidth(int controls) => controls == 0
      ? 0
      : controlHorizontalPadding * 2 +
            controlSize * controls +
            controlSpacing * (controls - 1);
}

class LinuxWindowMetricsScope extends InheritedWidget {
  const LinuxWindowMetricsScope({
    super.key,
    required this.leftControlInset,
    required this.rightControlInset,
    required this.preferences,
    required super.child,
  });

  final double leftControlInset;
  final double rightControlInset;
  final GtkWindowPreferences preferences;

  static final LinuxWindowMetricsScope _fallback = LinuxWindowMetricsScope(
    leftControlInset: 0,
    rightControlInset: 0,
    preferences: GtkWindowPreferences.defaults(),
    child: const SizedBox.shrink(),
  );

  static LinuxWindowMetricsScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LinuxWindowMetricsScope>() ??
      _fallback;

  @override
  bool updateShouldNotify(LinuxWindowMetricsScope oldWidget) =>
      leftControlInset != oldWidget.leftControlInset ||
      rightControlInset != oldWidget.rightControlInset ||
      preferences != oldWidget.preferences;
}

/// Owns the stable, window-level system controls above the route navigator.
///
/// The overlay contains only the configured control clusters. Application
/// header content remains inside page routes and is therefore covered by
/// ordinary dialog barriers.
class LinuxWindowHost extends ConsumerWidget {
  const LinuxWindowHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(gtkWindowPreferencesProvider).valueOrNull ??
        GtkWindowPreferences.defaults();
    final window = YaruWindow.of(context);
    return StreamBuilder<YaruWindowState>(
      stream: window.states(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const YaruWindowState();
        final leftControls = _meaningfulControls(
          preferences.decorationLayout.left,
          state,
        );
        final rightControls = _meaningfulControls(
          preferences.decorationLayout.right,
          state,
        );
        final leftInset = BusyMaxLinuxWindowMetrics.clusterWidth(
          leftControls.length,
        );
        final rightInset = BusyMaxLinuxWindowMetrics.clusterWidth(
          rightControls.length,
        );
        return LinuxWindowMetricsScope(
          leftControlInset: leftInset,
          rightControlInset: rightInset,
          preferences: preferences,
          child: _LinuxWindowOverlay(
            leftControls: leftControls,
            rightControls: rightControls,
            state: state,
            child: child,
          ),
        );
      },
    );
  }
}

List<GtkWindowControlType> _meaningfulControls(
  List<GtkWindowControlType> controls,
  YaruWindowState state,
) => controls
    .where((control) {
      return switch (control) {
        GtkWindowControlType.menu => true,
        GtkWindowControlType.minimize => state.isMinimizable != false,
        GtkWindowControlType.maximize =>
          state.isMaximizable != false ||
              state.isRestorable == true ||
              state.isMaximized == true,
        GtkWindowControlType.close => state.isClosable != false,
      };
    })
    .toList(growable: false);

class _LinuxWindowOverlay extends StatefulWidget {
  const _LinuxWindowOverlay({
    required this.leftControls,
    required this.rightControls,
    required this.state,
    required this.child,
  });

  final List<GtkWindowControlType> leftControls;
  final List<GtkWindowControlType> rightControls;
  final YaruWindowState state;
  final Widget child;

  @override
  State<_LinuxWindowOverlay> createState() => _LinuxWindowOverlayState();
}

class _LinuxWindowOverlayState extends State<_LinuxWindowOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: _buildOverlay);

  @override
  void didUpdateWidget(covariant _LinuxWindowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (widget.leftControls.isNotEmpty)
          Positioned(
            key: const ValueKey('linux-window-controls-left'),
            left: 0,
            top: 0,
            height: BusyMaxLinuxWindowMetrics.headerHeight,
            child: _LinuxWindowControlCluster(
              controls: widget.leftControls,
              state: widget.state,
            ),
          ),
        if (widget.rightControls.isNotEmpty)
          Positioned(
            key: const ValueKey('linux-window-controls-right'),
            right: 0,
            top: 0,
            height: BusyMaxLinuxWindowMetrics.headerHeight,
            child: _LinuxWindowControlCluster(
              controls: widget.rightControls,
              state: widget.state,
            ),
          ),
      ],
    );
  }
}

class _LinuxWindowControlCluster extends StatelessWidget {
  const _LinuxWindowControlCluster({
    required this.controls,
    required this.state,
  });

  final List<GtkWindowControlType> controls;
  final YaruWindowState state;

  @override
  Widget build(BuildContext context) {
    final foreground = BusyMaxSurfaceColors.of(context).foreground;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedOpacity(
        opacity: state.isActive == false ? .5 : 1,
        duration: BusyMaxMotion.fast,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BusyMaxLinuxWindowMetrics.controlHorizontalPadding,
          ),
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < controls.length; index++) ...[
                if (index > 0)
                  const SizedBox(
                    width: BusyMaxLinuxWindowMetrics.controlSpacing,
                  ),
                _buildControl(context, controls[index], foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControl(
    BuildContext context,
    GtkWindowControlType control,
    Color foreground,
  ) {
    final window = YaruWindow.of(context);
    final material = MaterialLocalizations.of(context);
    final iconColor = WidgetStatePropertyAll(foreground);
    return switch (control) {
      GtkWindowControlType.menu => SizedBox.square(
        dimension: BusyMaxLinuxWindowMetrics.controlSize,
        child: Tooltip(
          message: material.showMenuTooltip,
          child: InkResponse(
            onTap: window.showMenu,
            radius: BusyMaxLinuxWindowMetrics.controlSize / 2,
            child: const Icon(Icons.menu, size: 16),
          ),
        ),
      ),
      GtkWindowControlType.minimize => Tooltip(
        message: context.l10n.windowMinimize,
        child: YaruWindowControl(
          iconColor: iconColor,
          semanticLabel: context.l10n.windowMinimize,
          type: YaruWindowControlType.minimize,
          onTap: state.isMinimizable == false ? null : window.minimize,
        ),
      ),
      GtkWindowControlType.maximize => Tooltip(
        message: state.isMaximized == true
            ? context.l10n.windowRestore
            : context.l10n.windowMaximize,
        child: YaruWindowControl(
          iconColor: iconColor,
          semanticLabel: state.isMaximized == true
              ? context.l10n.windowRestore
              : context.l10n.windowMaximize,
          type: state.isMaximized == true
              ? YaruWindowControlType.restore
              : YaruWindowControlType.maximize,
          onTap: state.isMaximized == true
              ? window.restore
              : state.isMaximizable == false
              ? null
              : window.maximize,
        ),
      ),
      GtkWindowControlType.close => Tooltip(
        message: material.closeButtonTooltip,
        child: YaruWindowControl(
          iconColor: iconColor,
          semanticLabel: material.closeButtonLabel,
          type: YaruWindowControlType.close,
          onTap: state.isClosable == false ? null : window.close,
        ),
      ),
    };
  }
}

/// Adds native titlebar gestures only to a page-selected empty header region.
class LinuxTitlebarGestureRegion extends StatelessWidget {
  const LinuxTitlebarGestureRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final preferences = LinuxWindowMetricsScope.of(context).preferences;
    final window = YaruWindow.of(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            event.buttons == kMiddleMouseButton) {
          unawaited(
            _performTitlebarAction(context, preferences.middleClick, window),
          );
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => unawaited(window.drag()),
        onDoubleTap: () => unawaited(
          _performTitlebarAction(context, preferences.doubleClick, window),
        ),
        onSecondaryTap: () => unawaited(
          _performTitlebarAction(context, preferences.rightClick, window),
        ),
        child: child,
      ),
    );
  }
}

Future<void> _performTitlebarAction(
  BuildContext context,
  GtkTitlebarAction action,
  YaruWindowInstance window,
) async {
  switch (action) {
    case GtkTitlebarAction.none:
      return;
    case GtkTitlebarAction.minimize:
      await window.minimize();
    case GtkTitlebarAction.toggleMaximize:
      final state = await window.state();
      if (!context.mounted) return;
      if (state.isMaximized == true || state.isFullscreen == true) {
        await window.restore();
      } else if (state.isMaximizable != false) {
        await window.maximize();
      }
    case GtkTitlebarAction.menu:
      await window.showMenu();
    case GtkTitlebarAction.lower:
      await const GtkWindowPreferencesService().lowerWindow();
  }
}

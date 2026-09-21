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

  static double decorationWidth(GtkWindowDecorationElement decoration) =>
      switch (decoration) {
        GtkWindowDecorationElement.fallbackApplicationMenu => 0,
        GtkWindowDecorationElement.windowIcon ||
        GtkWindowDecorationElement.minimize ||
        GtkWindowDecorationElement.maximize ||
        GtkWindowDecorationElement.close => controlSize,
      };

  static double clusterWidth(List<GtkWindowDecorationElement> decorations) =>
      decorations.isEmpty
      ? 0
      : controlHorizontalPadding * 2 +
            decorations.fold(0, (width, item) {
              return width + decorationWidth(item);
            }) +
            controlSpacing * (decorations.length - 1);
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
class LinuxWindowHost extends ConsumerStatefulWidget {
  const LinuxWindowHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LinuxWindowHost> createState() => _LinuxWindowHostState();
}

class _LinuxWindowHostState extends ConsumerState<LinuxWindowHost> {
  YaruWindowInstance? _window;
  Stream<YaruWindowState>? _windowStates;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final window = YaruWindow.of(context);
    if (identical(window, _window)) return;
    _window = window;
    _windowStates = window.states();
  }

  @override
  Widget build(BuildContext context) {
    final preferences =
        ref.watch(gtkWindowPreferencesProvider).valueOrNull ??
        GtkWindowPreferences.defaults();
    return StreamBuilder<YaruWindowState>(
      stream: _windowStates,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const YaruWindowState();
        final leftDecorations = _meaningfulDecorations(
          preferences.decorationLayout.left,
          state,
        );
        final rightDecorations = _meaningfulDecorations(
          preferences.decorationLayout.right,
          state,
        );
        final leftInset = BusyMaxLinuxWindowMetrics.clusterWidth(
          leftDecorations,
        );
        final rightInset = BusyMaxLinuxWindowMetrics.clusterWidth(
          rightDecorations,
        );
        return LinuxWindowMetricsScope(
          leftControlInset: leftInset,
          rightControlInset: rightInset,
          preferences: preferences,
          child: _LinuxWindowOverlay(
            leftDecorations: leftDecorations,
            rightDecorations: rightDecorations,
            state: state,
            child: widget.child,
          ),
        );
      },
    );
  }
}

List<GtkWindowDecorationElement> _meaningfulDecorations(
  List<GtkWindowDecorationElement> decorations,
  YaruWindowState state,
) => decorations
    .where((decoration) {
      return switch (decoration) {
        // BusyMax does not register GTK's fallback application-menu model.
        GtkWindowDecorationElement.fallbackApplicationMenu => false,
        GtkWindowDecorationElement.windowIcon => true,
        GtkWindowDecorationElement.minimize => state.isMinimizable != false,
        GtkWindowDecorationElement.maximize =>
          state.isMaximizable != false ||
              state.isRestorable == true ||
              state.isMaximized == true ||
              state.isFullscreen == true,
        GtkWindowDecorationElement.close => state.isClosable != false,
      };
    })
    .toList(growable: false);

class _LinuxWindowOverlay extends StatefulWidget {
  const _LinuxWindowOverlay({
    required this.leftDecorations,
    required this.rightDecorations,
    required this.state,
    required this.child,
  });

  final List<GtkWindowDecorationElement> leftDecorations;
  final List<GtkWindowDecorationElement> rightDecorations;
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
        if (widget.leftDecorations.isNotEmpty)
          Positioned(
            key: const ValueKey('linux-window-controls-left'),
            left: 0,
            top: 0,
            height: BusyMaxLinuxWindowMetrics.headerHeight,
            child: _LinuxWindowControlCluster(
              decorations: widget.leftDecorations,
              state: widget.state,
            ),
          ),
        if (widget.rightDecorations.isNotEmpty)
          Positioned(
            key: const ValueKey('linux-window-controls-right'),
            right: 0,
            top: 0,
            height: BusyMaxLinuxWindowMetrics.headerHeight,
            child: _LinuxWindowControlCluster(
              decorations: widget.rightDecorations,
              state: widget.state,
            ),
          ),
      ],
    );
  }
}

class _LinuxWindowControlCluster extends StatelessWidget {
  const _LinuxWindowControlCluster({
    required this.decorations,
    required this.state,
  });

  final List<GtkWindowDecorationElement> decorations;
  final YaruWindowState state;

  @override
  Widget build(BuildContext context) {
    final foreground = BusyMaxSurfaceColors.of(context).foreground;
    return Material(
      type: MaterialType.transparency,
      child: _LinuxWindowActivationOpacity(
        opacity: state.isActive == false ? .5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BusyMaxLinuxWindowMetrics.controlHorizontalPadding,
          ),
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < decorations.length; index++) ...[
                if (index > 0)
                  const SizedBox(
                    width: BusyMaxLinuxWindowMetrics.controlSpacing,
                  ),
                _buildDecoration(context, decorations[index], foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecoration(
    BuildContext context,
    GtkWindowDecorationElement decoration,
    Color foreground,
  ) {
    final window = YaruWindow.of(context);
    final material = MaterialLocalizations.of(context);
    final iconColor = WidgetStatePropertyAll(foreground);
    final restorePresentation =
        state.isMaximized == true || state.isFullscreen == true;
    return switch (decoration) {
      GtkWindowDecorationElement.fallbackApplicationMenu =>
        const SizedBox.shrink(),
      GtkWindowDecorationElement.windowIcon => SizedBox.square(
        dimension: BusyMaxLinuxWindowMetrics.controlSize,
        child: Center(
          child: Image.asset(
            'assets/branding/busymax-logo.png',
            width: BusyMaxSizes.iconSm,
            height: BusyMaxSizes.iconSm,
            excludeFromSemantics: true,
          ),
        ),
      ),
      GtkWindowDecorationElement.minimize => Tooltip(
        message: context.l10n.windowMinimize,
        child: YaruWindowControl(
          iconColor: iconColor,
          semanticLabel: context.l10n.windowMinimize,
          type: YaruWindowControlType.minimize,
          onTap: state.isMinimizable == false ? null : window.minimize,
        ),
      ),
      GtkWindowDecorationElement.maximize => Tooltip(
        message: restorePresentation
            ? context.l10n.windowRestore
            : context.l10n.windowMaximize,
        child: YaruWindowControl(
          iconColor: iconColor,
          semanticLabel: restorePresentation
              ? context.l10n.windowRestore
              : context.l10n.windowMaximize,
          type: restorePresentation
              ? YaruWindowControlType.restore
              : YaruWindowControlType.maximize,
          onTap: restorePresentation
              ? window.restore
              : state.isMaximizable == false
              ? null
              : window.maximize,
        ),
      ),
      GtkWindowDecorationElement.close => Tooltip(
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

class _LinuxWindowActivationOpacity extends StatelessWidget {
  const _LinuxWindowActivationOpacity({
    required this.opacity,
    required this.child,
  });

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const key = ValueKey('linux-window-controls-opacity');
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(key: key, opacity: opacity, child: child);
    }
    return AnimatedOpacity(
      key: key,
      opacity: opacity,
      duration: BusyMaxMotion.fast,
      child: child,
    );
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
        excludeFromSemantics: true,
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

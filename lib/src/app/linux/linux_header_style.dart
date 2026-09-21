import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../busymax_design.dart';
import '../busymax_surface_colors.dart';
import 'linux_window_host.dart';

abstract final class BusyMaxLinuxHeaderStyle {
  static const double controlRadius = 6;
  static const double activeForegroundOpacity = 1;
  static const double inactiveForegroundOpacity = .50;
  static const double disabledActiveForegroundOpacity = .38;
  static const double disabledInactiveForegroundOpacity = .19;
  static const double hoverBackgroundStrength = .07;
  static const double pressedBackgroundStrength = .16;
  static const double selectedBackgroundStrength = .10;
  static const double selectedHoverBackgroundStrength = .13;
  static const double selectedPressedBackgroundStrength = .19;
}

/// Physical window-control obstructions inside the current main header.
///
/// These remain physical in RTL because GTK's decoration layout is physical.
/// Application-header layouts consume them at their corresponding edge while
/// retaining the complete header as the title-centering coordinate system.
class LinuxPageHeaderInsetsScope extends InheritedWidget {
  const LinuxPageHeaderInsetsScope({
    super.key,
    required this.leftObstruction,
    required this.rightObstruction,
    required super.child,
  });

  final double leftObstruction;
  final double rightObstruction;

  static const _fallback = LinuxPageHeaderInsetsScope(
    leftObstruction: 0,
    rightObstruction: 0,
    child: SizedBox.shrink(),
  );

  static LinuxPageHeaderInsetsScope of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LinuxPageHeaderInsetsScope>() ??
      _fallback;

  @override
  bool updateShouldNotify(LinuxPageHeaderInsetsScope oldWidget) =>
      leftObstruction != oldWidget.leftObstruction ||
      rightObstruction != oldWidget.rightObstruction;
}

Color busyMaxLinuxHeaderForeground(
  BuildContext context, {
  bool disabled = false,
}) {
  final active = LinuxWindowMetricsScope.of(context).windowActive;
  final opacity = switch ((active, disabled)) {
    (true, false) => BusyMaxLinuxHeaderStyle.activeForegroundOpacity,
    (false, false) => BusyMaxLinuxHeaderStyle.inactiveForegroundOpacity,
    (true, true) => BusyMaxLinuxHeaderStyle.disabledActiveForegroundOpacity,
    (false, true) => BusyMaxLinuxHeaderStyle.disabledInactiveForegroundOpacity,
  };
  final foreground = BusyMaxSurfaceColors.of(context).foreground;
  return foreground.withValues(alpha: foreground.a * opacity);
}

TextStyle busyMaxLinuxHeaderTitleStyle(BuildContext context) =>
    _busyMaxLinuxHeaderTextStyle(context, busyMaxHeaderTitleStyle(context));

TextStyle busyMaxLinuxHeaderBrandStyle(BuildContext context) =>
    _busyMaxLinuxHeaderTextStyle(context, busyMaxHeaderBrandStyle(context));

TextStyle _busyMaxLinuxHeaderTextStyle(BuildContext context, TextStyle style) {
  final baseColor = style.color ?? BusyMaxSurfaceColors.of(context).foreground;
  final opacity = LinuxWindowMetricsScope.of(context).windowActive
      ? BusyMaxLinuxHeaderStyle.activeForegroundOpacity
      : BusyMaxLinuxHeaderStyle.inactiveForegroundOpacity;
  return style.copyWith(
    color: baseColor.withValues(alpha: baseColor.a * opacity),
  );
}

WidgetStateProperty<Color?> busyMaxLinuxHeaderControlBackground(
  BuildContext context,
) {
  final foreground = busyMaxLinuxHeaderForeground(context);
  Color layer(double strength) =>
      foreground.withValues(alpha: foreground.a * strength);
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    final selected = states.contains(WidgetState.selected);
    final pressed = states.contains(WidgetState.pressed);
    final hovered = states.contains(WidgetState.hovered);
    if (selected && pressed) {
      return layer(BusyMaxLinuxHeaderStyle.selectedPressedBackgroundStrength);
    }
    if (selected && hovered) {
      return layer(BusyMaxLinuxHeaderStyle.selectedHoverBackgroundStrength);
    }
    if (pressed) {
      return layer(BusyMaxLinuxHeaderStyle.pressedBackgroundStrength);
    }
    if (selected) {
      return layer(BusyMaxLinuxHeaderStyle.selectedBackgroundStrength);
    }
    if (hovered) {
      return layer(BusyMaxLinuxHeaderStyle.hoverBackgroundStrength);
    }
    return Colors.transparent;
  });
}

class BusyMaxLinuxHeaderIconButton extends StatelessWidget {
  const BusyMaxLinuxHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.focusNode,
    this.selected = false,
    this.selectedIcon,
  });

  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool selected;
  final Widget? selectedIcon;

  @override
  Widget build(BuildContext context) {
    return BusyMaxHeaderIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      focusNode: focusNode,
      isSelected: selected,
      selectedIcon: selectedIcon,
      foregroundColor: busyMaxLinuxHeaderForeground(context),
      disabledForegroundColor: busyMaxLinuxHeaderForeground(
        context,
        disabled: true,
      ),
      backgroundColor: busyMaxLinuxHeaderControlBackground(context),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          BusyMaxLinuxHeaderStyle.controlRadius,
        ),
      ),
      focusBorderRadius: BusyMaxLinuxHeaderStyle.controlRadius,
    );
  }
}

class BusyMaxLinuxHeaderMenuButton<T> extends StatelessWidget {
  const BusyMaxLinuxHeaderMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = const Icon(YaruIcons.view_more),
    this.controller,
    this.enabled = true,
    this.highlightWhenOpen = true,
  });

  final String tooltip;
  final Widget icon;
  final List<BusyMaxMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final BusyMaxMenuController? controller;
  final bool enabled;
  final bool highlightWhenOpen;

  @override
  Widget build(BuildContext context) {
    return BusyMaxMenuButton<T>(
      tooltip: tooltip,
      icon: icon,
      entries: entries,
      onSelected: onSelected,
      controller: controller,
      enabled: enabled,
      highlightWhenOpen: highlightWhenOpen,
      triggerBuilder: (context, trigger) => trigger.anchor(
        child: BusyMaxLinuxHeaderIconButton(
          icon: icon,
          tooltip: tooltip,
          focusNode: trigger.focusNode,
          selected: highlightWhenOpen && trigger.isOpen,
          onPressed: trigger.onPressed,
        ),
      ),
    );
  }
}

class BusyMaxLinuxHeaderControlGroup extends StatelessWidget {
  const BusyMaxLinuxHeaderControlGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: BusyMaxSpacing.headerInset),
          children[index],
        ],
      ],
    );
  }
}

enum _BusyMaxLinuxHeaderSlot { leading, title, trailing }

/// GTK-style application header geometry with an absolute center title.
class BusyMaxLinuxHeaderLayout extends StatelessWidget {
  const BusyMaxLinuxHeaderLayout({
    super.key,
    required this.leading,
    required this.title,
    required this.trailing,
    this.maxContentWidth,
  });

  final Widget leading;
  final Widget title;
  final Widget trailing;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final insets = LinuxPageHeaderInsetsScope.of(context);
    final direction = Directionality.of(context);
    return SizedBox(
      height: BusyMaxSizes.toolbarHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const LinuxTitlebarGestureRegion(child: SizedBox.expand()),
          CustomMultiChildLayout(
            delegate: _BusyMaxLinuxHeaderLayoutDelegate(
              direction: direction,
              leftObstruction: insets.leftObstruction,
              rightObstruction: insets.rightObstruction,
              maxContentWidth: maxContentWidth,
            ),
            children: [
              LayoutId(id: _BusyMaxLinuxHeaderSlot.leading, child: leading),
              LayoutId(id: _BusyMaxLinuxHeaderSlot.title, child: title),
              LayoutId(id: _BusyMaxLinuxHeaderSlot.trailing, child: trailing),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusyMaxLinuxHeaderLayoutDelegate extends MultiChildLayoutDelegate {
  _BusyMaxLinuxHeaderLayoutDelegate({
    required this.direction,
    required this.leftObstruction,
    required this.rightObstruction,
    required this.maxContentWidth,
  });

  final TextDirection direction;
  final double leftObstruction;
  final double rightObstruction;
  final double? maxContentWidth;

  @override
  void performLayout(Size size) {
    final centeredInset = maxContentWidth == null
        ? 0.0
        : math.max(0.0, (size.width - maxContentWidth!) / 2);
    final leftInset = math.max(
      leftObstruction + BusyMaxSpacing.headerInset,
      centeredInset,
    );
    final rightInset = math.max(
      rightObstruction + BusyMaxSpacing.headerInset,
      centeredInset,
    );
    final sideConstraints = BoxConstraints.loose(size);
    final leadingSize = layoutChild(
      _BusyMaxLinuxHeaderSlot.leading,
      sideConstraints,
    );
    final trailingSize = layoutChild(
      _BusyMaxLinuxHeaderSlot.trailing,
      sideConstraints,
    );

    late final Offset leadingOffset;
    late final Offset trailingOffset;
    late final double leftOccupiedEdge;
    late final double rightOccupiedEdge;
    if (direction == TextDirection.ltr) {
      leadingOffset = Offset(leftInset, (size.height - leadingSize.height) / 2);
      trailingOffset = Offset(
        size.width - rightInset - trailingSize.width,
        (size.height - trailingSize.height) / 2,
      );
      leftOccupiedEdge = leadingOffset.dx + leadingSize.width;
      rightOccupiedEdge = trailingOffset.dx;
    } else {
      leadingOffset = Offset(
        size.width - rightInset - leadingSize.width,
        (size.height - leadingSize.height) / 2,
      );
      trailingOffset = Offset(
        leftInset,
        (size.height - trailingSize.height) / 2,
      );
      leftOccupiedEdge = trailingOffset.dx + trailingSize.width;
      rightOccupiedEdge = leadingOffset.dx;
    }
    positionChild(_BusyMaxLinuxHeaderSlot.leading, leadingOffset);
    positionChild(_BusyMaxLinuxHeaderSlot.trailing, trailingOffset);

    final centerX = size.width / 2;
    final safeHalfWidth = math.max(
      0,
      math.min(centerX - leftOccupiedEdge, rightOccupiedEdge - centerX),
    );
    final titleSize = layoutChild(
      _BusyMaxLinuxHeaderSlot.title,
      BoxConstraints.loose(Size(safeHalfWidth * 2, size.height)),
    );
    positionChild(
      _BusyMaxLinuxHeaderSlot.title,
      Offset(
        centerX - titleSize.width / 2,
        (size.height - titleSize.height) / 2,
      ),
    );
  }

  @override
  bool shouldRelayout(_BusyMaxLinuxHeaderLayoutDelegate oldDelegate) =>
      direction != oldDelegate.direction ||
      leftObstruction != oldDelegate.leftObstruction ||
      rightObstruction != oldDelegate.rightObstruction ||
      maxContentWidth != oldDelegate.maxContentWidth;
}

class BusyMaxLinuxHeaderTitle extends StatelessWidget {
  const BusyMaxLinuxHeaderTitle(this.text, {super.key, this.brand = false});

  final String text;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: brand
            ? busyMaxLinuxHeaderBrandStyle(context)
            : busyMaxLinuxHeaderTitleStyle(context),
      ),
    );
  }
}

ButtonStyle busyMaxLinuxHeaderTextButtonStyle(
  BuildContext context, {
  required bool suggested,
}) {
  final geometry = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(BusyMaxSizes.headerIconButton, BusyMaxSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.normal,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          BusyMaxLinuxHeaderStyle.controlRadius,
        ),
      ),
    ),
    animationDuration: BusyMaxMotion.fast,
    splashFactory: NoSplash.splashFactory,
  );
  if (suggested) return geometry;
  return geometry.copyWith(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? busyMaxLinuxHeaderForeground(context, disabled: true)
          : busyMaxLinuxHeaderForeground(context),
    ),
    backgroundColor: busyMaxLinuxHeaderControlBackground(context),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

class BusyMaxLinuxHeaderTextButton extends StatelessWidget {
  const BusyMaxLinuxHeaderTextButton.standard({
    super.key,
    required this.label,
    required this.onPressed,
  }) : suggested = false;

  const BusyMaxLinuxHeaderTextButton.suggested({
    super.key,
    required this.label,
    required this.onPressed,
  }) : suggested = true;

  final String label;
  final VoidCallback? onPressed;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final style = busyMaxLinuxHeaderTextButtonStyle(
      context,
      suggested: suggested,
    );
    return suggested
        ? BusyMaxPushButton.suggested(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          )
        : BusyMaxPushButton.standard(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          );
  }
}

abstract final class BusyMaxLinuxHeaderGlyphs {
  static const sidebar = YaruIcons.sidebar;
  static const today = YaruIcons.calendar;
  static const search = YaruIcons.search;
  static const refresh = YaruIcons.refresh;
  static const menu = YaruIcons.view_more;
  static const close = YaruIcons.window_close;

  static IconData previousFor(TextDirection direction) =>
      direction == TextDirection.ltr
      ? YaruIcons.go_previous
      : YaruIcons.go_next;

  static IconData nextFor(TextDirection direction) =>
      direction == TextDirection.ltr
      ? YaruIcons.go_next
      : YaruIcons.go_previous;
}

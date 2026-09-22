import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../busymax_design.dart';
import '../busymax_native_search_entry_theme.dart';
import '../busymax_surface_colors.dart';
import '../../platform/gtk_header_icon_service.dart';
import 'linux_window_host.dart';

abstract final class BusyMaxLinuxHeaderStyle {
  static const double symbolicIconSize = 16;
  static const double searchEntryHeight = 32;
  static const double searchEntryRadius = 9;
  static const double searchEntryBorderWidth = 1;
  static const double searchEntryInnerFocusWidth = 1;
  static const double searchEntryHorizontalPadding = 8;
  static const double searchEntryIconGap = 6;
  static const Duration searchChangedDelay = Duration(milliseconds: 150);
  static const Duration searchEntryFocusDuration = Duration(milliseconds: 200);
  static const double compoundButtonHorizontalPadding = 9;
  static const double compoundButtonVerticalPadding = 4;
  static const double viewIconGap = 6;
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
    this.semanticLabel,
  });

  final BusyMaxLinuxHeaderIcon icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool selected;
  final BusyMaxLinuxHeaderIcon? selectedIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = BusyMaxHeaderIconButton(
      icon: BusyMaxGtkHeaderIcon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      focusNode: focusNode,
      isSelected: selected,
      selectedIcon: selectedIcon == null
          ? null
          : BusyMaxGtkHeaderIcon(selectedIcon!),
      iconSize: BusyMaxLinuxHeaderStyle.symbolicIconSize,
      fixedSize: const Size.square(BusyMaxSizes.headerIconButton),
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
    return semanticLabel == null
        ? button
        : Semantics(
            label: semanticLabel,
            button: true,
            enabled: onPressed != null,
            child: button,
          );
  }
}

class BusyMaxLinuxHeaderMenuButton<T> extends StatelessWidget {
  const BusyMaxLinuxHeaderMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = BusyMaxLinuxHeaderIcon.mainMenu,
    this.controller,
    this.enabled = true,
    this.highlightWhenOpen = true,
  });

  final String tooltip;
  final BusyMaxLinuxHeaderIcon icon;
  final List<BusyMaxMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final BusyMaxMenuController? controller;
  final bool enabled;
  final bool highlightWhenOpen;

  @override
  Widget build(BuildContext context) {
    return BusyMaxMenuButton<T>(
      tooltip: tooltip,
      icon: BusyMaxGtkHeaderIcon(icon),
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

class BusyMaxLinuxViewMenuButton<T> extends StatelessWidget {
  const BusyMaxLinuxViewMenuButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.entries,
    required this.onSelected,
    this.controller,
    this.enabled = true,
  });

  final String tooltip;
  final BusyMaxLinuxHeaderIcon icon;
  final List<BusyMaxMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final BusyMaxMenuController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BusyMaxMenuButton<T>(
      tooltip: tooltip,
      icon: BusyMaxGtkHeaderIcon(icon),
      entries: entries,
      onSelected: onSelected,
      controller: controller,
      enabled: enabled,
      triggerBuilder: (context, trigger) => trigger.anchor(
        child: _BusyMaxLinuxViewMenuTrigger(
          tooltip: tooltip,
          icon: icon,
          focusNode: trigger.focusNode,
          selected: trigger.isOpen,
          onPressed: trigger.onPressed,
        ),
      ),
    );
  }
}

class _BusyMaxLinuxViewMenuTrigger extends StatelessWidget {
  const _BusyMaxLinuxViewMenuTrigger({
    required this.tooltip,
    required this.icon,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final BusyMaxLinuxHeaderIcon icon;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = busyMaxLinuxHeaderForeground(context);
    final disabledForeground = busyMaxLinuxHeaderForeground(
      context,
      disabled: true,
    );
    final baseBackground = busyMaxLinuxHeaderControlBackground(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, BusyMaxSizes.headerIconButton),
      ),
      maximumSize: const WidgetStatePropertyAll(
        Size(double.infinity, BusyMaxSizes.headerIconButton),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: BusyMaxLinuxHeaderStyle.compoundButtonHorizontalPadding,
          vertical: BusyMaxLinuxHeaderStyle.compoundButtonVerticalPadding,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? disabledForeground
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => baseBackground.resolve({
          ...states,
          if (selected) WidgetState.selected,
        }),
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
    final button = SizedBox(
      height: BusyMaxSizes.headerIconButton,
      child: TextButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style: style,
        child: Builder(
          builder: (context) => IconTheme(
            data: IconThemeData(
              color: DefaultTextStyle.of(context).style.color,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BusyMaxGtkHeaderIcon(icon),
                const SizedBox(width: BusyMaxLinuxHeaderStyle.viewIconGap),
                const BusyMaxGtkHeaderIcon(
                  BusyMaxLinuxHeaderIcon.viewMenuArrow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final focused = YaruTheme.maybeOf(context)?.focusBorders == true
        ? YaruFocusBorder.primary(
            borderRadius: BorderRadius.circular(
              BusyMaxLinuxHeaderStyle.controlRadius,
            ),
            child: button,
          )
        : button;
    return Tooltip(message: tooltip, child: focused);
  }
}

class BusyMaxGtkHeaderIcon extends StatelessWidget {
  const BusyMaxGtkHeaderIcon(this.icon, {super.key, this.direction});

  final BusyMaxLinuxHeaderIcon icon;
  final TextDirection? direction;

  @override
  Widget build(BuildContext context) {
    final effectiveDirection = direction ?? Directionality.of(context);
    final asset = GtkHeaderIconScope.of(
      context,
    ).catalog.assetFor(icon, effectiveDirection);
    final color = IconTheme.of(context).color;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: BusyMaxLinuxHeaderStyle.symbolicIconSize,
        child: asset == null
            ? CustomPaint(
                size: const Size.square(
                  BusyMaxLinuxHeaderStyle.symbolicIconSize,
                ),
                painter: _BusyMaxGtkHeaderFallbackPainter(
                  icon: icon,
                  color: color ?? const Color(0xFF000000),
                ),
              )
            : Image.memory(
                asset.bytes,
                width: BusyMaxLinuxHeaderStyle.symbolicIconSize,
                height: BusyMaxLinuxHeaderStyle.symbolicIconSize,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
      ),
    );
  }
}

class _BusyMaxGtkHeaderFallbackPainter extends CustomPainter {
  const _BusyMaxGtkHeaderFallbackPainter({
    required this.icon,
    required this.color,
  });

  final BusyMaxLinuxHeaderIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (icon == BusyMaxLinuxHeaderIcon.filter) {
      final path = Path()
        ..moveTo(2, 3)
        ..lineTo(14, 3)
        ..lineTo(9.25, 8.25)
        ..lineTo(9.25, 12.25)
        ..lineTo(6.75, 13.5)
        ..lineTo(6.75, 8.25)
        ..close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
      return;
    }
    paint.style = PaintingStyle.stroke;
    canvas
      ..drawRect(const Rect.fromLTWH(2.5, 2.5, 11, 11), paint)
      ..drawLine(const Offset(4.5, 4.5), const Offset(11.5, 11.5), paint)
      ..drawLine(const Offset(11.5, 4.5), const Offset(4.5, 11.5), paint);
  }

  @override
  bool shouldRepaint(_BusyMaxGtkHeaderFallbackPainter oldDelegate) =>
      icon != oldDelegate.icon || color != oldDelegate.color;
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

enum BusyMaxLinuxHeaderCenterAllocation { centered, fillBetweenControls }

/// GTK-style application header geometry with an explicit center allocation.
class BusyMaxLinuxHeaderLayout extends StatelessWidget {
  const BusyMaxLinuxHeaderLayout({
    super.key,
    required this.leading,
    required this.title,
    required this.trailing,
    this.maxContentWidth,
    this.centerAllocation = BusyMaxLinuxHeaderCenterAllocation.centered,
  });

  final Widget leading;
  final Widget title;
  final Widget trailing;
  final double? maxContentWidth;
  final BusyMaxLinuxHeaderCenterAllocation centerAllocation;

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
              centerAllocation: centerAllocation,
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
    required this.centerAllocation,
  });

  final TextDirection direction;
  final double leftObstruction;
  final double rightObstruction;
  final double? maxContentWidth;
  final BusyMaxLinuxHeaderCenterAllocation centerAllocation;

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

    final safeLeftEdge = leftOccupiedEdge + BusyMaxSpacing.headerInset;
    final safeRightEdge = rightOccupiedEdge - BusyMaxSpacing.headerInset;
    switch (centerAllocation) {
      case BusyMaxLinuxHeaderCenterAllocation.centered:
        final centerX = size.width / 2;
        final safeHalfWidth = math.max(
          0,
          math.min(centerX - safeLeftEdge, safeRightEdge - centerX),
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
      case BusyMaxLinuxHeaderCenterAllocation.fillBetweenControls:
        final availableWidth = math.max(0.0, safeRightEdge - safeLeftEdge);
        final titleSize = layoutChild(
          _BusyMaxLinuxHeaderSlot.title,
          BoxConstraints(
            minWidth: availableWidth,
            maxWidth: availableWidth,
            minHeight: 0,
            maxHeight: size.height,
          ),
        );
        positionChild(
          _BusyMaxLinuxHeaderSlot.title,
          Offset(safeLeftEdge, (size.height - titleSize.height) / 2),
        );
    }
  }

  @override
  bool shouldRelayout(_BusyMaxLinuxHeaderLayoutDelegate oldDelegate) =>
      direction != oldDelegate.direction ||
      leftObstruction != oldDelegate.leftObstruction ||
      rightObstruction != oldDelegate.rightObstruction ||
      maxContentWidth != oldDelegate.maxContentWidth ||
      centerAllocation != oldDelegate.centerAllocation;
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

/// The bounded center-slot presentation corresponding to the former native
/// `GtkSearchEntry` title-stack child.
class BusyMaxLinuxHeaderSearchField extends StatefulWidget {
  const BusyMaxLinuxHeaderSearchField({
    super.key,
    required this.controller,
    required this.focusRequest,
    required this.semanticLabel,
    required this.onChanged,
    required this.onClear,
    this.autofocus = true,
  });

  /// Mirrors GtkEntry:max-width-chars as a natural-width hint. It is not a
  /// hard maximum when the header title child expands.
  static const int naturalWidthChars = 48;
  static const shellKey = ValueKey<String>('busymax-linux-search-shell');
  static const innerFocusKey = ValueKey<String>(
    'busymax-linux-search-inner-focus',
  );
  static const primaryIconKey = ValueKey<String>(
    'busymax-linux-search-primary-icon',
  );
  static const secondaryIconKey = ValueKey<String>(
    'busymax-linux-search-secondary-icon',
  );
  static const clearKey = ValueKey<String>('busymax-linux-search-clear');

  final TextEditingController controller;
  final int focusRequest;
  final String semanticLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool autofocus;

  @override
  State<BusyMaxLinuxHeaderSearchField> createState() =>
      _BusyMaxLinuxHeaderSearchFieldState();
}

class _BusyMaxLinuxHeaderSearchFieldState
    extends State<BusyMaxLinuxHeaderSearchField> {
  final _focusNode = FocusNode(debugLabel: 'BusyMax Linux header Search');
  late bool _isEmpty;
  Timer? _searchChangedTimer;
  String? _pendingSearchValue;
  var _clearHovered = false;
  var _clearPressed = false;

  @override
  void initState() {
    super.initState();
    _isEmpty = widget.controller.text.isEmpty;
    widget.controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
    if (widget.autofocus) {
      _focusAndSelectAll();
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxLinuxHeaderSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _cancelPendingSearchChanged();
      oldWidget.controller.removeListener(_handleControllerChanged);
      _isEmpty = widget.controller.text.isEmpty;
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.focusRequest != widget.focusRequest) {
      _focusAndSelectAll();
    }
  }

  @override
  void dispose() {
    _cancelPendingSearchChanged();
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final pending = _pendingSearchValue;
    if (pending != null && widget.controller.text != pending) {
      _cancelPendingSearchChanged();
    }
    final isEmpty = widget.controller.text.isEmpty;
    if (_isEmpty != isEmpty && mounted) {
      setState(() => _isEmpty = isEmpty);
    }
  }

  void _cancelPendingSearchChanged() {
    _searchChangedTimer?.cancel();
    _searchChangedTimer = null;
    _pendingSearchValue = null;
  }

  void _handleTextChanged(String value) {
    _cancelPendingSearchChanged();
    if (value.isEmpty) {
      widget.onChanged('');
      return;
    }

    _pendingSearchValue = value;
    _searchChangedTimer = Timer(BusyMaxLinuxHeaderStyle.searchChangedDelay, () {
      if (!mounted) return;
      final pending = _pendingSearchValue;
      _pendingSearchValue = null;
      _searchChangedTimer = null;
      if (pending != null && widget.controller.text == pending) {
        widget.onChanged(pending);
      }
    });
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _focusAndSelectAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    });
  }

  void _clear() {
    _cancelPendingSearchChanged();
    widget.onClear();
    if (widget.controller.text.isNotEmpty) {
      widget.controller.clear();
    }
    _focusNode.requestFocus();
  }

  void _setClearHovered(bool hovered) {
    if (_clearHovered != hovered) {
      setState(() => _clearHovered = hovered);
    }
  }

  void _setClearPressed(bool pressed) {
    if (_clearPressed != pressed) {
      setState(() => _clearPressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowActive = LinuxWindowMetricsScope.of(context).windowActive;
    final focused = _focusNode.hasFocus;
    final searchTheme = BusyMaxNativeSearchEntryTheme.of(context);
    final searchStyle = searchTheme.stateFor(
      windowActive: windowActive,
      focused: focused,
    );
    final direction = Directionality.of(context);
    final textStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: searchStyle.foreground, fontWeight: FontWeight.normal);
    final widthProbe = TextPainter(
      text: TextSpan(
        text: List.filled(
          BusyMaxLinuxHeaderSearchField.naturalWidthChars,
          '0',
        ).join(),
        style: textStyle,
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final naturalWidth =
        widthProbe.width +
        BusyMaxLinuxHeaderStyle.searchEntryHorizontalPadding * 2 +
        searchStyle.borderLeft +
        searchStyle.borderRight;
    widthProbe.dispose();
    final primaryIconForeground = direction == TextDirection.rtl
        ? searchStyle.primaryIconForegroundRtl
        : searchStyle.primaryIconForeground;
    final secondaryIconForeground = direction == TextDirection.rtl
        ? searchStyle.secondaryIconForegroundRtl
        : searchStyle.secondaryIconForeground;
    final clearColor = !windowActive
        ? secondaryIconForeground
        : _clearPressed
        ? theme.colorScheme.primary
        : _clearHovered
        ? searchStyle.foreground
        : secondaryIconForeground;
    final focusDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : BusyMaxLinuxHeaderStyle.searchEntryFocusDuration;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    double snapToPhysicalPixel(double value) =>
        (value * devicePixelRatio).roundToDouble() / devicePixelRatio;
    final innerFocusWidth = searchStyle.hasInnerFocus
        ? snapToPhysicalPixel(searchStyle.innerFocusWidth)
        : 0.0;
    final innerFocusColor = searchStyle.hasInnerFocus
        ? searchStyle.innerFocusColor
        : searchStyle.innerFocusColor.withValues(alpha: 0);
    final innerFocusInsets = EdgeInsets.fromLTRB(
      snapToPhysicalPixel(searchStyle.borderLeft),
      snapToPhysicalPixel(searchStyle.borderTop),
      snapToPhysicalPixel(searchStyle.borderRight),
      snapToPhysicalPixel(searchStyle.borderBottom),
    );
    final innerFocusRadius = snapToPhysicalPixel(
      math.max(
        0.0,
        searchStyle.radius -
            math.max(
              math.max(innerFocusInsets.left, innerFocusInsets.right),
              math.max(innerFocusInsets.top, innerFocusInsets.bottom),
            ),
      ),
    );

    return FocusScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : naturalWidth;
          return SizedBox(
            width: width,
            height: BusyMaxLinuxHeaderStyle.searchEntryHeight,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                key: BusyMaxLinuxHeaderSearchField.shellKey,
                duration: focusDuration,
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: searchStyle.background,
                  borderRadius: BorderRadius.circular(searchStyle.radius),
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(searchStyle.radius),
                  border: Border(
                    top: BorderSide(
                      color: searchStyle.borderColor,
                      width: searchStyle.borderTop,
                    ),
                    right: BorderSide(
                      color: searchStyle.borderColor,
                      width: searchStyle.borderRight,
                    ),
                    bottom: BorderSide(
                      color: searchStyle.borderColor,
                      width: searchStyle.borderBottom,
                    ),
                    left: BorderSide(
                      color: searchStyle.borderColor,
                      width: searchStyle.borderLeft,
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focusNode.requestFocus,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: BusyMaxLinuxHeaderStyle
                              .searchEntryHorizontalPadding,
                          end: BusyMaxLinuxHeaderStyle
                              .searchEntryHorizontalPadding,
                        ),
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              key: BusyMaxLinuxHeaderSearchField.primaryIconKey,
                              child: IconTheme(
                                data: IconThemeData(
                                  color: primaryIconForeground,
                                ),
                                child: const BusyMaxGtkHeaderIcon(
                                  BusyMaxLinuxHeaderIcon.searchEntryFind,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: BusyMaxLinuxHeaderStyle.searchEntryIconGap,
                            ),
                            Expanded(
                              child: Semantics(
                                label: widget.semanticLabel,
                                textField: true,
                                child: TextField(
                                  controller: widget.controller,
                                  focusNode: _focusNode,
                                  autofocus: false,
                                  maxLines: 1,
                                  style: textStyle,
                                  cursorColor: windowActive
                                      ? theme.colorScheme.primary
                                      : searchStyle.foreground,
                                  cursorWidth: 1,
                                  decoration: const InputDecoration(
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    filled: false,
                                  ),
                                  onChanged: _handleTextChanged,
                                ),
                              ),
                            ),
                            if (!_isEmpty) ...[
                              const SizedBox(
                                width:
                                    BusyMaxLinuxHeaderStyle.searchEntryIconGap,
                              ),
                              Semantics(
                                container: true,
                                button: true,
                                label: MaterialLocalizations.of(
                                  context,
                                ).clearButtonTooltip,
                                onTap: _clear,
                                child: ExcludeSemantics(
                                  key: BusyMaxLinuxHeaderSearchField
                                      .secondaryIconKey,
                                  child: MouseRegion(
                                    key: BusyMaxLinuxHeaderSearchField.clearKey,
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => _setClearHovered(true),
                                    onExit: (_) {
                                      _setClearHovered(false);
                                      _setClearPressed(false);
                                    },
                                    child: Listener(
                                      behavior: HitTestBehavior.opaque,
                                      onPointerDown: (_) =>
                                          _setClearPressed(true),
                                      onPointerUp: (_) =>
                                          _setClearPressed(false),
                                      onPointerCancel: (_) =>
                                          _setClearPressed(false),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        excludeFromSemantics: true,
                                        onTap: _clear,
                                        child: IconTheme(
                                          data: IconThemeData(
                                            color: clearColor,
                                          ),
                                          child: const BusyMaxGtkHeaderIcon(
                                            BusyMaxLinuxHeaderIcon.searchClear,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: AnimatedContainer(
                        key: BusyMaxLinuxHeaderSearchField.innerFocusKey,
                        duration: focusDuration,
                        curve: Curves.easeOut,
                        margin: innerFocusInsets,
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(innerFocusRadius),
                          border: Border.all(
                            color: innerFocusColor,
                            width: innerFocusWidth,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

import 'package:flutter/material.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';
import 'package:yaru/yaru.dart';

import '../l10n/l10n.dart';
import 'busymax_surface_colors.dart';

abstract final class BusyMaxSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double headerInset = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double tooltipHorizontal = sm;
  static const double tooltipVertical = 5;
  static const double lg = kYaruPagePadding;
  static const double xl = kYaruPagePadding * 1.5;
  static const double xxl = kYaruPagePadding * 2;
}

abstract final class BusyMaxRadius {
  static const double sm = kYaruButtonRadius;
  static const double md = kYaruContainerRadius;
  static const double lg = kYaruContainerRadius;
  static const double headerButton = kYaruButtonRadius;
  static const double window = kYaruContainerRadius;
}

abstract final class BusyMaxSizes {
  static const double sidebarWidth = 300;
  static const double detailsWidth = 700;
  static const double compactDetailsWidth = 700;
  static const double toolbarHeight = kYaruTitleBarHeight;
  static const double pushButtonWidth = 136;
  static const double pushButtonHeight = 36;
  static const Size pushButtonSize = Size(pushButtonWidth, pushButtonHeight);
  static const double sidebarRowHeight = 36;
  static const double taskRowMinHeight = 48;
  static const double iconSm = 16;
  static const double iconMd = kYaruIconSize;
  static const double iconLg = 22;
  static const double headerIconButton = kYaruTitleBarItemHeight;
  static const double headerIcon = kYaruIconSize;
  static const double sidebarActionButton = headerIconButton;
  static const double sidebarActionIcon = headerIcon;
  static const double miniCalendarWeekButton = headerIconButton;
  static const double aboutCloseButton =
      headerIconButton - BusyMaxSpacing.sm - BusyMaxSpacing.xxs;
  static const double popoverActionButton = headerIconButton;
  static const double popoverArrowWidth = 18;
  static const double popoverArrowHeight = 10;
}

abstract final class BusyMaxElevation {
  static const double surface = 1;
  static const double popover = 6;
  static const double window = 12;
}

abstract final class BusyMaxShadow {
  static const double floatingBlur = 24;
  static const Offset floatingOffset = Offset(0, 8);
  static const double windowMargin = 14;

  static Color floatingColor(BuildContext context) {
    return BusyMaxSurfaceColors.of(context).shade;
  }

  static List<BoxShadow> floatingShadows(Color color) {
    return [
      BoxShadow(color: color, blurRadius: floatingBlur, offset: floatingOffset),
    ];
  }

  static List<BoxShadow> floatingShadowsFor(BuildContext context) {
    return floatingShadows(floatingColor(context));
  }
}

enum BusyMaxPopoverArrowSide { top, bottom }

class BusyMaxPopoverSurface extends StatelessWidget {
  const BusyMaxPopoverSurface({
    super.key,
    required this.child,
    required this.color,
    this.arrowSide = BusyMaxPopoverArrowSide.top,
    this.arrowAlignment = 0.5,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final arrowHeight = BusyMaxSizes.popoverArrowHeight;
    return PhysicalShape(
      clipper: _BusyMaxPopoverClipper(
        side: arrowSide,
        alignment: arrowAlignment.clamp(0.0, 1.0).toDouble(),
      ),
      color: color,
      elevation: BusyMaxElevation.popover,
      shadowColor: BusyMaxShadow.floatingColor(context),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          top: arrowSide == BusyMaxPopoverArrowSide.top ? arrowHeight : 0,
          bottom: arrowSide == BusyMaxPopoverArrowSide.bottom ? arrowHeight : 0,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _BusyMaxPopoverClipper extends CustomClipper<Path> {
  const _BusyMaxPopoverClipper({required this.side, required this.alignment});

  final BusyMaxPopoverArrowSide side;
  final double alignment;

  @override
  Path getClip(Size size) {
    final arrowWidth = BusyMaxSizes.popoverArrowWidth;
    final arrowHeight = BusyMaxSizes.popoverArrowHeight;
    final radius = Radius.circular(BusyMaxRadius.md);
    final bodyTop = side == BusyMaxPopoverArrowSide.top ? arrowHeight : 0.0;
    final bodyBottom = side == BusyMaxPopoverArrowSide.bottom
        ? size.height - arrowHeight
        : size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, bodyTop, size.width, bodyBottom),
      radius,
    );
    final minArrowCenter = BusyMaxRadius.md + arrowWidth / 2;
    final maxArrowCenter = size.width - minArrowCenter;
    final arrowCenter = (size.width * alignment)
        .clamp(minArrowCenter, maxArrowCenter)
        .toDouble();

    final path = Path()..addRRect(body);
    if (side == BusyMaxPopoverArrowSide.top) {
      path
        ..moveTo(arrowCenter - arrowWidth / 2, bodyTop)
        ..lineTo(arrowCenter, 0)
        ..lineTo(arrowCenter + arrowWidth / 2, bodyTop)
        ..close();
    } else {
      path
        ..moveTo(arrowCenter - arrowWidth / 2, bodyBottom)
        ..lineTo(arrowCenter, size.height)
        ..lineTo(arrowCenter + arrowWidth / 2, bodyBottom)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _BusyMaxPopoverClipper oldClipper) {
    return oldClipper.side != side || oldClipper.alignment != alignment;
  }
}

class BusyMaxCircularAction extends StatelessWidget {
  const BusyMaxCircularAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.hoverColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color hoverColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          hoverColor: hoverColor,
          focusColor: hoverColor,
          highlightColor: hoverColor,
          splashColor: Colors.transparent,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: BusyMaxSizes.popoverActionButton,
            child: Icon(
              icon,
              size: BusyMaxSizes.iconSm,
              color: foregroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

RoundedRectangleBorder busyMaxHeaderButtonShape() {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
  );
}

ButtonStyle busyMaxHeaderIconButtonStyle({
  Color? foregroundColor,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? overlayColor,
}) {
  return ButtonStyle(
    fixedSize: const WidgetStatePropertyAll(
      Size.square(BusyMaxSizes.headerIconButton),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size.square(BusyMaxSizes.headerIconButton),
    ),
    maximumSize: const WidgetStatePropertyAll(
      Size.square(BusyMaxSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: foregroundColor == null
        ? null
        : WidgetStatePropertyAll(foregroundColor),
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: WidgetStatePropertyAll(busyMaxHeaderButtonShape()),
  );
}

ButtonStyle busyMaxHeaderTextButtonStyle({
  Color? foregroundColor,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? overlayColor,
}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(BusyMaxSizes.headerIconButton, BusyMaxSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: foregroundColor == null
        ? null
        : WidgetStatePropertyAll(foregroundColor),
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: WidgetStatePropertyAll(busyMaxHeaderButtonShape()),
  );
}

WidgetStateProperty<Color?> busyMaxSubtleButtonBackground(
  BuildContext context,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.10);
    }
    return null;
  });
}

WidgetStateProperty<Color?> busyMaxHeaderButtonBackground(
  BuildContext context,
) {
  final surfaceColors = BusyMaxSurfaceColors.of(context);
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return surfaceColors.disabledControl;
    }
    if (states.contains(WidgetState.pressed)) {
      return surfaceColors.controlActive;
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return surfaceColors.controlHover;
    }
    return surfaceColors.control;
  });
}

ButtonStyle busyMaxDropdownButtonStyle(BuildContext context) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(BusyMaxSizes.headerIconButton, BusyMaxSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyMaxSpacing.lg),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: WidgetStatePropertyAll(
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: WidgetStatePropertyAll(busyMaxHeaderButtonShape()),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    animationDuration: Duration.zero,
  );
}

InputDecoration busyMaxDropdownDecoration() {
  return const InputDecoration(
    filled: false,
    isCollapsed: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
  );
}

MenuStyle busyMaxDropdownMenuStyle(BuildContext context, {double? minWidth}) {
  final popupTheme = Theme.of(context).popupMenuTheme;
  final colorScheme = Theme.of(context).colorScheme;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(
      popupTheme.color ?? colorScheme.surfaceContainerHigh,
    ),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: WidgetStatePropertyAll(BusyMaxShadow.floatingColor(context)),
    elevation: const WidgetStatePropertyAll(BusyMaxElevation.popover),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
      ),
    ),
    side: const WidgetStatePropertyAll(BorderSide.none),
    visualDensity: VisualDensity.standard,
    minimumSize: WidgetStatePropertyAll(Size(minWidth ?? 0, 0)),
  );
}

ButtonStyle busyMaxDropdownMenuItemStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
    maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 36)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
      }
      return colorScheme.onSurface;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.onSurfaceVariant.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
      }
      return Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    side: const WidgetStatePropertyAll(BorderSide.none),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
      ),
    ),
    animationDuration: Duration.zero,
  );
}

ButtonStyle busyMaxPushButtonStyle(ButtonStyle? style) {
  return const ButtonStyle(
    fixedSize: WidgetStatePropertyAll(
      Size.fromHeight(BusyMaxSizes.pushButtonHeight),
    ),
    minimumSize: WidgetStatePropertyAll(BusyMaxSizes.pushButtonSize),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ).merge(style);
}

ButtonStyle busyMaxHeaderPushButtonStyle(ButtonStyle? style) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(BusyMaxSizes.headerIconButton, BusyMaxSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyMaxSpacing.xl),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: WidgetStatePropertyAll(busyMaxHeaderButtonShape()),
  ).merge(style);
}

abstract final class BusyMaxPushButton {
  static PushButton elevated({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return PushButton.elevated(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: busyMaxPushButtonStyle(style),
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  static PushButton filled({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return PushButton.filled(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: busyMaxPushButtonStyle(style),
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  static PushButton outlined({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return PushButton.outlined(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: busyMaxPushButtonStyle(style),
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }
}

abstract final class BusyMaxHeaderPushButton {
  static PushButton filled({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return PushButton.filled(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: busyMaxHeaderPushButtonStyle(style),
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  static PushButton outlined({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return PushButton.outlined(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: busyMaxHeaderPushButtonStyle(style),
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }
}

Color busyMaxSelectedBackground(BuildContext context) {
  return Theme.of(context).colorScheme.primaryContainer;
}

Color busyMaxHoverBackground(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(alpha: 0.06),
    colorScheme.surface,
  );
}

Color busyMaxEditorRowHoverColor(BuildContext context) {
  final surfaceColors = BusyMaxSurfaceColors.of(context);
  return surfaceColors.foreground.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.045 : 0.055,
  );
}

Color busyMaxModalBarrierColor(BuildContext context) {
  return Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32);
}

Color busyMaxPanelBorder(BuildContext context) {
  return Theme.of(context).colorScheme.outlineVariant;
}

TextStyle? busyMaxSectionHeaderStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.titleSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
}

class BusyMaxClamp extends StatelessWidget {
  const BusyMaxClamp({
    super.key,
    required this.child,
    this.maxWidth = 680,
    this.scrollable = true,
    this.center = true,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.all(BusyMaxSpacing.lg),
    this.controller,
  });

  final Widget child;
  final double maxWidth;
  final bool scrollable;
  final bool center;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final clamped = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: margin,
      padding: padding,
      child: child,
    );

    final body = center
        ? Align(alignment: Alignment.topCenter, child: clamped)
        : clamped;

    return scrollable
        ? SingleChildScrollView(controller: controller, child: body)
        : body;
  }
}

class BusyMaxGroupedList extends StatelessWidget {
  const BusyMaxGroupedList({
    super.key,
    this.title,
    this.description,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: BusyMaxSpacing.xs),
    this.filled = false,
  });

  final String? title;
  final String? description;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        top: title == null && (description == null || description!.isEmpty)
            ? BusyMaxSpacing.md
            : BusyMaxSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: padding,
              child: Text(title!, style: busyMaxSectionHeaderStyle(context)),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: BusyMaxSpacing.xs),
              Padding(
                padding: padding,
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: BusyMaxSpacing.sm),
          ],
          _BusyMaxGroupedListSurface(filled: filled, children: children),
        ],
      ),
    );
  }
}

class BusyMaxSurface extends StatelessWidget {
  const BusyMaxSurface({
    super.key,
    required this.child,
    this.filled = true,
    this.color,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final bool filled;
  final Color? color;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(BusyMaxRadius.md);
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Material(
      color: filled ? color ?? surfaceColors.card : Colors.transparent,
      elevation: filled ? BusyMaxElevation.surface : 0,
      shadowColor: BusyMaxShadow.floatingColor(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class _BusyMaxGroupedListSurface extends StatelessWidget {
  const _BusyMaxGroupedListSurface({
    required this.filled,
    required this.children,
  });

  final bool filled;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1)
            Divider(height: 1, thickness: 1, color: surfaceColors.subtleBorder),
        ],
      ],
    );
    if (!filled) {
      return list;
    }
    final borderRadius = BorderRadius.circular(BusyMaxRadius.md);
    return Material(
      color: surfaceColors.control,
      elevation: BusyMaxElevation.surface,
      shadowColor: BusyMaxShadow.floatingColor(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

class BusyMaxActionRow extends StatelessWidget {
  const BusyMaxActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.tooltip,
    this.destructive = false,
    this.autofocus = false,
    this.hoverColor,
  });

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final String? tooltip;
  final bool destructive;
  final bool autofocus;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = destructive ? TextStyle(color: colorScheme.error) : null;
    final row = YaruListTile.square(
      leading: leading,
      title:
          titleWidget ??
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
      subtitle:
          subtitleWidget ??
          (subtitle == null || subtitle!.isEmpty
              ? null
              : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)),
      trailing: trailing,
      enabled: enabled,
      autofocus: autofocus,
      hoverColor: hoverColor ?? busyMaxEditorRowHoverColor(context),
      onTap: enabled ? onTap : null,
    );

    if (enabled || tooltip == null) {
      return row;
    }

    return Tooltip(
      message: tooltip!,
      child: Opacity(opacity: 0.6, child: IgnorePointer(child: row)),
    );
  }
}

class BusyMaxCategoryEditorRow extends StatelessWidget {
  const BusyMaxCategoryEditorRow({
    super.key,
    required this.title,
    required this.addLabel,
    required this.categories,
    required this.suggestions,
    required this.adding,
    required this.controller,
    required this.onAddPressed,
    required this.onSubmitted,
    required this.onCancelAdding,
    required this.onDeleted,
    this.inputKey,
  });

  final String title;
  final String addLabel;
  final List<String> categories;
  final List<String> suggestions;
  final bool adding;
  final TextEditingController controller;
  final VoidCallback onAddPressed;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancelAdding;
  final ValueChanged<String> onDeleted;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = [
      for (final suggestion in suggestions)
        if (suggestion.trim().isNotEmpty && !categories.contains(suggestion))
          suggestion,
    ];
    return BusyMaxActionRow(
      title: title,
      leading: const Icon(Icons.sell_outlined),
      subtitleWidget: Padding(
        padding: const EdgeInsets.only(top: BusyMaxSpacing.xs),
        child: Wrap(
          spacing: BusyMaxSpacing.xs,
          runSpacing: BusyMaxSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final category in categories)
              _BusyMaxCategoryChip(
                label: category,
                onDeleted: () => onDeleted(category),
              ),
            if (adding) ...[
              _BusyMaxCategoryInputChip(
                controller: controller,
                hintText: addLabel,
                inputKey: inputKey,
                onSubmitted: onSubmitted,
                onCancel: onCancelAdding,
              ),
              for (final suggestion in visibleSuggestions)
                _BusyMaxCategorySuggestionChip(
                  label: suggestion,
                  onPressed: () => onSubmitted(suggestion),
                ),
            ] else
              _BusyMaxAddCategoryChip(label: addLabel, onPressed: onAddPressed),
          ],
        ),
      ),
    );
  }
}

class _BusyMaxCategoryChip extends StatelessWidget {
  const _BusyMaxCategoryChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColors.control,
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: BusyMaxSpacing.md,
          end: BusyMaxSpacing.xs,
          top: BusyMaxSpacing.xs,
          bottom: BusyMaxSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: BusyMaxSpacing.xs),
            Tooltip(
              message:
                  '${MaterialLocalizations.of(context).deleteButtonTooltip} $label',
              child: InkResponse(
                onTap: onDeleted,
                radius: BusyMaxSizes.iconMd,
                child: Icon(
                  YaruIcons.window_close,
                  size: BusyMaxSizes.iconSm,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusyMaxAddCategoryChip extends StatelessWidget {
  const _BusyMaxAddCategoryChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
        hoverColor: busyMaxEditorRowHoverColor(context),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BusyMaxSpacing.md,
            vertical: BusyMaxSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                YaruIcons.plus,
                size: BusyMaxSizes.iconSm,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: BusyMaxSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusyMaxCategorySuggestionChip extends StatelessWidget {
  const _BusyMaxCategorySuggestionChip({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(
        YaruIcons.plus,
        size: BusyMaxSizes.iconSm,
        color: colorScheme.onSurfaceVariant,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
      backgroundColor: Colors.transparent,
      onPressed: onPressed,
    );
  }
}

class _BusyMaxCategoryInputChip extends StatelessWidget {
  const _BusyMaxCategoryInputChip({
    required this.controller,
    required this.hintText,
    this.inputKey,
    required this.onSubmitted,
    required this.onCancel,
  });

  final TextEditingController controller;
  final String hintText;
  final Key? inputKey;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColors.control,
        borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: BusyMaxSpacing.md,
          end: BusyMaxSpacing.xs,
        ),
        child: SizedBox(
          width: 180,
          height: 30,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: inputKey,
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration.collapsed(hintText: hintText),
                  textInputAction: TextInputAction.done,
                  onSubmitted: onSubmitted,
                ),
              ),
              InkResponse(
                onTap: () => onSubmitted(controller.text),
                radius: BusyMaxSizes.iconMd,
                child: Icon(
                  YaruIcons.checkmark,
                  size: BusyMaxSizes.iconSm,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.xs),
              InkResponse(
                onTap: onCancel,
                radius: BusyMaxSizes.iconMd,
                child: Icon(
                  YaruIcons.window_close,
                  size: BusyMaxSizes.iconSm,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusyMaxCalendarValueRow extends StatelessWidget {
  const BusyMaxCalendarValueRow({
    super.key,
    required this.label,
    required this.value,
    this.leading,
    this.trailingIcons = const [],
    this.onTap,
    this.enabled = true,
    this.tooltip,
  });

  final String label;
  final String value;
  final Widget? leading;
  final List<Widget> trailingIcons;
  final VoidCallback? onTap;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final row = YaruListTile.square(
      leading: leading,
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailingIcons.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final icon in trailingIcons) ...[
                  icon,
                  if (icon != trailingIcons.last)
                    const SizedBox(width: BusyMaxSpacing.sm),
                ],
              ],
            ),
      enabled: enabled,
      hoverColor: busyMaxEditorRowHoverColor(context),
      onTap: enabled ? onTap : null,
    );

    if (enabled || tooltip == null) {
      return row;
    }

    return Tooltip(
      message: tooltip!,
      child: Opacity(opacity: 0.6, child: IgnorePointer(child: row)),
    );
  }
}

class BusyMaxCalendarNotesCard extends StatelessWidget {
  const BusyMaxCalendarNotesCard({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.minLines = 3,
    this.maxLines = 8,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BusyMaxSpacing.lg,
        vertical: BusyMaxSpacing.md,
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class BusyMaxComboRow<T> extends StatelessWidget {
  const BusyMaxComboRow({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.tooltip,
    this.width = 220,
    this.trailingAction,
    this.menuItemBuilder,
    this.selectedBuilder,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;
  final String? tooltip;
  final double width;
  final Widget? trailingAction;
  final Widget Function(BuildContext context, T value)? menuItemBuilder;
  final Widget Function(BuildContext context, T value)? selectedBuilder;

  @override
  Widget build(BuildContext context) {
    final row = YaruListTile.square(
      leading: leading,
      titleText: title,
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            child: MenuButtonBuilder<T>(
              selected: selected,
              values: values,
              menuPosition: PopupMenuPosition.under,
              decoration: busyMaxDropdownDecoration(),
              style: busyMaxDropdownButtonStyle(context),
              menuStyle: busyMaxDropdownMenuStyle(context, minWidth: width),
              itemStyle: busyMaxDropdownMenuItemStyle(context),
              itemBuilder: (context, value, _) =>
                  menuItemBuilder?.call(context, value) ??
                  Text(labelFor(value)),
              onSelected: enabled ? onSelected : null,
              child:
                  selectedBuilder?.call(context, selected) ??
                  Text(labelFor(selected), overflow: TextOverflow.ellipsis),
            ),
          ),
          if (trailingAction != null) ...[
            const SizedBox(width: BusyMaxSpacing.xs),
            trailingAction!,
          ],
        ],
      ),
      enabled: enabled,
      hoverColor: busyMaxEditorRowHoverColor(context),
    );

    if (enabled || tooltip == null) {
      return row;
    }

    return Tooltip(
      message: tooltip!,
      child: Opacity(opacity: 0.6, child: IgnorePointer(child: row)),
    );
  }
}

class BusyMaxSwitchRow extends StatelessWidget {
  const BusyMaxSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: YaruSwitchListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        secondary: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
      ),
    );
  }
}

class BusyMaxMenuEntry<T> {
  const BusyMaxMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.checked = false,
    this.tooltip,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool checked;
  final String? tooltip;
  final bool destructive;
}

class BusyMaxMenuButton<T> extends StatefulWidget {
  const BusyMaxMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = const Icon(YaruIcons.view_more),
    this.minMenuWidth = 180,
  });

  final String tooltip;
  final Widget icon;
  final List<BusyMaxMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final double minMenuWidth;

  @override
  State<BusyMaxMenuButton<T>> createState() => _BusyMaxMenuButtonState<T>();
}

class _BusyMaxMenuButtonState<T> extends State<BusyMaxMenuButton<T>> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _controller,
      crossAxisUnconstrained: false,
      style: busyMaxDropdownMenuStyle(context, minWidth: widget.minMenuWidth),
      builder: (context, controller, child) {
        return YaruIconButton(
          tooltip: widget.tooltip,
          iconSize: BusyMaxSizes.headerIcon,
          icon: IconTheme.merge(
            data: IconThemeData(
              color: colorScheme.onSurfaceVariant,
              size: BusyMaxSizes.headerIcon,
            ),
            child: widget.icon,
          ),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
              return;
            }
            controller.open(
              position: const Offset(0, BusyMaxSizes.headerIconButton),
            );
          },
          style: busyMaxHeaderIconButtonStyle(
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: busyMaxSubtleButtonBackground(context),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        );
      },
      menuChildren: [
        for (final entry in widget.entries)
          _BusyMaxMenuEntryButton<T>(
            entry: entry,
            onSelected: (value) {
              widget.onSelected(value);
              _controller.close();
            },
          ),
      ],
    );
  }
}

class _BusyMaxMenuEntryButton<T> extends StatelessWidget {
  const _BusyMaxMenuEntryButton({
    required this.entry,
    required this.onSelected,
  });

  final BusyMaxMenuEntry<T> entry;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = entry.destructive ? colorScheme.error : null;
    final iconData = entry.checked ? YaruIcons.checkmark : entry.icon;
    final icon = iconData == null
        ? const SizedBox.square(dimension: BusyMaxSizes.iconSm)
        : Icon(iconData, size: BusyMaxSizes.iconSm, color: foreground);
    final row = MenuItemButton(
      leadingIcon: icon,
      onPressed: entry.enabled ? () => onSelected(entry.value) : null,
      style: busyMaxDropdownMenuItemStyle(context).copyWith(
        foregroundColor: foreground == null
            ? null
            : WidgetStatePropertyAll(foreground),
      ),
      child: Text(
        entry.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: foreground == null ? null : TextStyle(color: foreground),
      ),
    );

    if (entry.enabled || entry.tooltip == null) {
      return row;
    }

    return Tooltip(
      message: entry.tooltip!,
      child: Opacity(opacity: 0.55, child: row),
    );
  }
}

class BusyMaxEmptyState extends StatelessWidget {
  const BusyMaxEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BusyMaxSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: YaruInfoBox(
            yaruInfoType: YaruInfoType.information,
            color: colorScheme.onSurfaceVariant,
            icon: Icon(icon),
            title: Text(title),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null && message!.isNotEmpty)
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (actions.isNotEmpty) ...[
                  if (message != null && message!.isNotEmpty)
                    const SizedBox(height: BusyMaxSpacing.lg),
                  Wrap(
                    spacing: BusyMaxSpacing.sm,
                    runSpacing: BusyMaxSpacing.sm,
                    children: actions,
                  ),
                ],
                if ((message == null || message!.isEmpty) && actions.isEmpty)
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BusyMaxToolbar extends StatelessWidget {
  const BusyMaxToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleWidget = subtitle == null || subtitle!.isEmpty
        ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );

    return YaruTitleBar(
      title: titleWidget,
      centerTitle: false,
      isClosable: false,
      isMaximizable: false,
      isMinimizable: false,
      actions: actions.isEmpty
          ? null
          : [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: BusyMaxSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions) ...[
                      action,
                      if (action != actions.last)
                        const SizedBox(width: BusyMaxSpacing.sm),
                    ],
                  ],
                ),
              ),
            ],
    );
  }
}

class BusyMaxToolbarButton extends StatelessWidget {
  const BusyMaxToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return YaruIconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      );
    }

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: BusyMaxSizes.iconMd),
        const SizedBox(width: BusyMaxSpacing.sm),
        Text(label),
      ],
    );
    final button = primary
        ? BusyMaxPushButton.filled(onPressed: onPressed, child: child)
        : BusyMaxPushButton.outlined(onPressed: onPressed, child: child);
    return Tooltip(message: tooltip, child: button);
  }
}

class BusyMaxEditorHeader extends StatelessWidget {
  const BusyMaxEditorHeader({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    this.saving = false,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        0,
      ),
      child: Row(
        children: [
          BusyMaxHeaderPushButton.outlined(
            onPressed: onCancel,
            child: Text(cancelLabel, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          BusyMaxHeaderPushButton.filled(
            onPressed: onSave,
            child: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(saveLabel, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class BusyMaxTimeModeRow extends StatelessWidget {
  const BusyMaxTimeModeRow({
    super.key,
    required this.allDay,
    required this.onChanged,
  });

  final bool allDay;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(BusyMaxSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: _BusyMaxTimeModeButton(
              label: l10n.allDay,
              selected: allDay,
              onPressed: () => onChanged(true),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.xs),
          Expanded(
            child: _BusyMaxTimeModeButton(
              label: l10n.timeSlot,
              selected: !allDay,
              onPressed: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyMaxTimeModeButton extends StatelessWidget {
  const _BusyMaxTimeModeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final borderRadius = BorderRadius.circular(BusyMaxRadius.headerButton);
    return Material(
      color: selected ? surfaceColors.controlHover : Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: selected ? null : onPressed,
        child: SizedBox(
          height: BusyMaxSizes.pushButtonHeight,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BusyMaxModalEditorScaffold extends StatelessWidget {
  const BusyMaxModalEditorScaffold({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    required this.children,
    this.saving = false,
    this.contentMaxWidth = 640,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;
  final double contentMaxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BusyMaxEditorHeader(
          title: title,
          cancelLabel: cancelLabel,
          saveLabel: saveLabel,
          onCancel: onCancel,
          onSave: onSave,
          saving: saving,
        ),
        const SizedBox(height: BusyMaxSpacing.headerInset),
        Flexible(
          child: SingleChildScrollView(
            child: BusyMaxClamp(
              maxWidth: contentMaxWidth,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: BusyMaxSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BusyMaxDialogCloseButton extends StatelessWidget {
  const BusyMaxDialogCloseButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: surfaceColors.control,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          hoverColor: surfaceColors.controlHover,
          focusColor: surfaceColors.controlHover,
          highlightColor: surfaceColors.controlActive,
          splashColor: Colors.transparent,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: BusyMaxSizes.aboutCloseButton,
            child: Icon(
              Icons.close,
              size: BusyMaxSizes.iconSm,
              color: surfaceColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class BusyMaxModalEditorSurface extends StatelessWidget {
  const BusyMaxModalEditorSurface({
    super.key,
    required this.child,
    this.minWidth = 0,
    this.maxWidth = BusyMaxSizes.compactDetailsWidth,
    this.maxHeight,
  });

  final Widget child;
  final double minWidth;
  final double maxWidth;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final effectiveMaxWidth = maxWidth.isFinite
        ? maxWidth.clamp(0.0, double.infinity).toDouble()
        : maxWidth;
    final effectiveMinWidth = minWidth
        .clamp(
          0.0,
          effectiveMaxWidth.isFinite ? effectiveMaxWidth : double.infinity,
        )
        .toDouble();
    final effectiveMaxHeight = maxHeight == null
        ? double.infinity
        : maxHeight!.clamp(0.0, double.infinity).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: effectiveMinWidth,
        maxWidth: effectiveMaxWidth,
        maxHeight: effectiveMaxHeight,
      ),
      child: Material(
        color: surfaceColors.dialog,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BusyMaxRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class BusyMaxTooltipOnlyDisabled extends StatelessWidget {
  const BusyMaxTooltipOnlyDisabled({
    super.key,
    required this.enabled,
    required this.tooltip,
    required this.child,
  });

  final bool enabled;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return child;
    }
    return Tooltip(
      message: tooltip,
      child: Opacity(opacity: 0.6, child: IgnorePointer(child: child)),
    );
  }
}

class BusyMaxInlineBadge extends StatelessWidget {
  const BusyMaxInlineBadge({super.key, required this.label, this.tooltip});

  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badge = YaruInfoBadge(
      yaruInfoType: YaruInfoType.information,
      color: colorScheme.outline,
      padding: const EdgeInsets.symmetric(
        horizontal: BusyMaxSpacing.sm,
        vertical: BusyMaxSpacing.xxs,
      ),
      borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip!, child: badge);
  }
}

class BusyMaxDialogShell extends StatelessWidget {
  const BusyMaxDialogShell({
    super.key,
    required this.title,
    required this.children,
    this.maxWidth = 520,
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;
  final double maxWidth;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BusyMaxRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BusyMaxRadius.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              YaruDialogTitleBar(title: Text(title), centerTitle: true),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(BusyMaxSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(BusyMaxSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final action in actions) ...[
                        action,
                        if (action != actions.last)
                          const SizedBox(width: BusyMaxSpacing.sm),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusyMaxPromptDialog extends StatefulWidget {
  const BusyMaxPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.actionLabel,
    this.initialValue,
    this.message,
  });

  final String title;
  final String label;
  final String actionLabel;
  final String? initialValue;
  final String? message;

  @override
  State<BusyMaxPromptDialog> createState() => _BusyMaxPromptDialogState();
}

class _BusyMaxPromptDialogState extends State<BusyMaxPromptDialog> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return BusyMaxDialogShell(
      title: widget.title,
      maxWidth: 420,
      actions: [
        BusyMaxPushButton.outlined(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.filled(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(widget.actionLabel),
        ),
      ],
      children: [
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          Text(widget.message!),
          const SizedBox(height: BusyMaxSpacing.lg),
        ],
        ValidatedFormField(
          initialValue: widget.initialValue,
          autofocus: true,
          labelText: widget.label,
          onChanged: (value) => _value = value,
          onEditingComplete: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

class BusyMaxConfirmDialog extends StatelessWidget {
  const BusyMaxConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BusyMaxDialogShell(
      title: title,
      maxWidth: 460,
      actions: [
        BusyMaxPushButton.outlined(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.filled(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      children: [Text(message)],
    );
  }
}

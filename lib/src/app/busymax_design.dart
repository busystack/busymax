import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const double window = kYaruWindowRadius;
}

abstract final class BusyMaxSizes {
  static const double sidebarWidth = 300;
  static const double detailsWidth = 700;
  static const double compactDetailsWidth = 700;
  static const double toolbarHeight = kYaruTitleBarHeight;
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
  static const double popoverArrowWidth = 18;
  static const double popoverArrowHeight = 10;
}

abstract final class BusyMaxElevation {
  static const double card = 2;
  static const double popover = 6;
  static const double tooltip = 10;
  static const double window = 12;
}

abstract final class BusyMaxStroke {
  static const double outline = 1;
}

abstract final class BusyMaxAlpha {
  static const double modalBarrier = 0.32;
}

abstract final class BusyMaxMotion {
  static const Duration dialogInsets = Duration(milliseconds: 160);
  static const Curve dialogInsetsCurve = Curves.easeOutCubic;
}

abstract final class BusyMaxShadow {
  static const double floatingBlur = 24;
  static const Offset floatingOffset = Offset(0, 8);
  static const double windowMargin = 32;

  static Color _scaleAlpha(Color color, double scale) {
    return color.withValues(
      alpha: (color.a * scale).clamp(0.0, 1.0).toDouble(),
    );
  }

  static Color floatingColor(BuildContext context) {
    return BusyMaxSurfaceColors.of(context).shade;
  }

  /// Flutter's physical-elevation renderer applies its own ambient and spot
  /// opacity. It therefore needs the theme's unattenuated semantic shadow,
  /// unlike [BoxShadow], which consumes the GTK shade alpha directly.
  static Color physicalColor(BuildContext context) {
    return Theme.of(context).colorScheme.shadow;
  }

  static List<BoxShadow> floatingShadows(Color color) {
    return [
      BoxShadow(color: color, blurRadius: floatingBlur, offset: floatingOffset),
    ];
  }

  static List<BoxShadow> tooltipShadows(Color color) {
    return [
      BoxShadow(
        color: _scaleAlpha(color, 1.45),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: _scaleAlpha(color, 0.9),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> floatingShadowsFor(BuildContext context) {
    return floatingShadows(floatingColor(context));
  }

  static List<BoxShadow> tooltipShadowsFor(BuildContext context) {
    return tooltipShadows(floatingColor(context));
  }

  static List<BoxShadow> windowShadows(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: color.a * 0.75),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: color.withValues(alpha: color.a * 0.45),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: color.withValues(alpha: color.a * 0.25),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> windowShadowsFor(BuildContext context) {
    return windowShadows(floatingColor(context));
  }

  static List<BoxShadow> edgeShadows(Color color, {required bool below}) {
    return [
      BoxShadow(
        color: color,
        blurRadius: floatingBlur / 2,
        offset: Offset(
          0,
          below ? floatingOffset.dy / 2 : -floatingOffset.dy / 2,
        ),
      ),
    ];
  }

  static List<BoxShadow> edgeShadowsFor(
    BuildContext context, {
    required bool below,
  }) {
    return edgeShadows(floatingColor(context), below: below);
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
    final alignment = arrowAlignment.clamp(0.0, 1.0).toDouble();
    final clipper = _BusyMaxPopoverClipper(
      side: arrowSide,
      alignment: alignment,
    );
    return PhysicalShape(
      clipper: clipper,
      color: color,
      elevation: BusyMaxElevation.tooltip,
      shadowColor: BusyMaxShadow.physicalColor(context),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        foregroundPainter: _BusyMaxPopoverOutlinePainter(
          clipper: clipper,
          color: BusyMaxSurfaceColors.of(context).floatingBorder,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: arrowSide == BusyMaxPopoverArrowSide.top ? arrowHeight : 0,
            bottom: arrowSide == BusyMaxPopoverArrowSide.bottom
                ? arrowHeight
                : 0,
          ),
          child: Padding(padding: padding, child: child),
        ),
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

    final bodyPath = Path()..addRRect(body);
    final arrowPath = Path();
    if (side == BusyMaxPopoverArrowSide.top) {
      arrowPath
        ..moveTo(arrowCenter - arrowWidth / 2, bodyTop)
        ..lineTo(arrowCenter, 0)
        ..lineTo(arrowCenter + arrowWidth / 2, bodyTop)
        ..close();
    } else {
      arrowPath
        ..moveTo(arrowCenter - arrowWidth / 2, bodyBottom)
        ..lineTo(arrowCenter, size.height)
        ..lineTo(arrowCenter + arrowWidth / 2, bodyBottom)
        ..close();
    }
    return Path.combine(PathOperation.union, bodyPath, arrowPath);
  }

  @override
  bool shouldReclip(covariant _BusyMaxPopoverClipper oldClipper) {
    return oldClipper.side != side || oldClipper.alignment != alignment;
  }
}

class _BusyMaxPopoverOutlinePainter extends CustomPainter {
  const _BusyMaxPopoverOutlinePainter({
    required this.clipper,
    required this.color,
  });

  final _BusyMaxPopoverClipper clipper;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.getClip(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        // PhysicalShape clips its child to the same path. Drawing a double
        // width leaves one semantic outline pixel inside that clip.
        ..strokeWidth = BusyMaxStroke.outline * 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BusyMaxPopoverOutlinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.clipper.side != clipper.side ||
        oldDelegate.clipper.alignment != clipper.alignment;
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

MenuStyle busyMaxDropdownMenuStyle(BuildContext context, {double? minWidth}) {
  final base = Theme.of(context).menuTheme.style ?? const MenuStyle();
  return base.copyWith(
    minimumSize: minWidth == null
        ? null
        : WidgetStatePropertyAll(Size(minWidth, 0)),
  );
}

ButtonStyle busyMaxDropdownMenuItemStyle(BuildContext context) {
  return Theme.of(context).menuButtonTheme.style ?? const ButtonStyle();
}

/// BusyMax's cross-platform fallback for a native desktop search entry.
///
/// Linux header bars use `GtkSearchEntry`. Flutter-owned layouts delegate
/// geometry, icons, and interaction states to Yaru instead of restyling a raw
/// [TextField].
class BusyMaxSearchField extends StatefulWidget {
  const BusyMaxSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.autofocus = false,
    this.focusRequest = 0,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.clearButtonSemanticLabel,
  });

  final TextEditingController? controller;
  final String? hintText;
  final bool autofocus;

  /// Increment this value to focus the Yaru-owned text entry again.
  final int focusRequest;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String?>? onSubmitted;
  final VoidCallback? onClear;
  final String? clearButtonSemanticLabel;

  @override
  State<BusyMaxSearchField> createState() => _BusyMaxSearchFieldState();
}

class _BusyMaxSearchFieldState extends State<BusyMaxSearchField> {
  final _focusScopeNode = FocusScopeNode(
    debugLabel: 'BusyMaxSearchField scope',
  );
  final _yaruKeyboardFocusNode = FocusNode(
    debugLabel: 'BusyMaxSearchField keyboard listener',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      _requestTextFocus();
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequest != widget.focusRequest) {
      _requestTextFocus();
    }
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    _yaruKeyboardFocusNode.dispose();
    super.dispose();
  }

  void _requestTextFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Yaru's public focus node belongs to its keyboard listener. Keep that
      // wrapper out of traversal and focus the first Yaru-owned control,
      // which is the actual text entry.
      for (final node in _focusScopeNode.traversalDescendants) {
        if (node.canRequestFocus) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _focusScopeNode,
      child: YaruSearchField(
        controller: widget.controller,
        focusNode: _yaruKeyboardFocusNode,
        hintText: widget.hintText,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onClear: widget.onClear,
        clearIconSemanticLabel:
            widget.clearButtonSemanticLabel ??
            MaterialLocalizations.of(context).clearButtonTooltip,
      ),
    );
  }
}

abstract final class BusyMaxPushButton {
  /// A neutral desktop action. Yaru renders this with its standard filled
  /// control surface and native interaction geometry.
  static PushButton standard({
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
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  /// A suggested action. Yaru reserves the accent-filled elevated role for
  /// the single preferred action in a group.
  static PushButton suggested({
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
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  /// A destructive desktop action.
  ///
  /// Keep destructive emphasis on the final action in a confirmation dialog;
  /// ordinary destructive rows should continue to use semantic error
  /// foregrounds without becoming accent-filled buttons.
  static PushButton destructive({
    required BuildContext context,
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
    final colorScheme = Theme.of(context).colorScheme;
    return PushButton.elevated(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
      ).merge(style),
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }
}

Color busyMaxSelectedBackground(BuildContext context) {
  return BusyMaxSurfaceColors.of(context).controlActive;
}

Color busyMaxHoverBackground(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(alpha: 0.06),
    colorScheme.surface,
  );
}

Color busyMaxRowHoverColor(BuildContext context) {
  return Theme.of(context).hoverColor;
}

Color busyMaxEditorRowHoverColor(BuildContext context) {
  return busyMaxRowHoverColor(context);
}

Color busyMaxModalBarrierColor(BuildContext context) {
  return Theme.of(
    context,
  ).colorScheme.scrim.withValues(alpha: BusyMaxAlpha.modalBarrier);
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

Widget _busyMaxGroupedRowSubtitle(
  BuildContext context,
  Widget child, {
  bool enabled = true,
}) {
  final colors = BusyMaxSurfaceColors.of(context);
  return DefaultTextStyle.merge(
    style: TextStyle(
      color: enabled ? colors.mutedForeground : colors.disabledForeground,
    ),
    child: child,
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
    this.side = BorderSide.none,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final bool filled;
  final Color? color;
  final BorderSide side;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(BusyMaxRadius.md);
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Material(
      color: filled ? color ?? surfaceColors.card : Colors.transparent,
      elevation: filled ? BusyMaxElevation.card : 0,
      shadowColor: BusyMaxShadow.physicalColor(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: borderRadius, side: side),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class BusyMaxGroupedSurface extends StatelessWidget {
  const BusyMaxGroupedSurface({
    super.key,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    return BusyMaxSurface(
      color: surfaceColors.groupedSurface,
      side: highContrast
          ? BorderSide(color: Theme.of(context).colorScheme.outline)
          : BorderSide.none,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class BusyMaxSidebarSurface extends StatelessWidget {
  const BusyMaxSidebarSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Material(
      color: surfaceColors.sidebar,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(
              color: surfaceColors.sidebarBorder,
              width: BusyMaxStroke.outline,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A GTK-style navigation list for a persistent desktop sidebar.
///
/// The list delegates row interaction, focus handling, and selection geometry
/// to Yaru's master-detail controls while mapping their visual states to
/// BusyMax's semantic surface roles.
class BusyMaxSidebarNavigation extends StatelessWidget {
  const BusyMaxSidebarNavigation({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BusyMaxSurfaceColors.of(context);
    final masterDetailTheme = YaruMasterDetailTheme.of(context);

    return Theme(
      data: theme.copyWith(
        listTileTheme: theme.listTileTheme.copyWith(
          selectedColor: colors.foreground,
          selectedTileColor: Color.alphaBlend(colors.control, colors.sidebar),
          tileColor: Colors.transparent,
          iconColor: colors.mutedForeground,
          textColor: colors.foreground,
          titleTextStyle: theme.textTheme.bodyMedium,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: BusyMaxSpacing.sm,
          ),
          horizontalTitleGap: BusyMaxSpacing.sm,
          minVerticalPadding: 0,
          minLeadingWidth: BusyMaxSizes.iconSm,
          minTileHeight: BusyMaxSizes.sidebarRowHeight,
          visualDensity: VisualDensity.standard,
          titleAlignment: ListTileTitleAlignment.center,
        ),
      ),
      child: ListView.separated(
        padding:
            masterDetailTheme.listPadding ??
            const EdgeInsets.symmetric(vertical: BusyMaxSpacing.sm),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (context, index) => SizedBox(
          height: masterDetailTheme.tileSpacing ?? BusyMaxSpacing.xxs,
        ),
      ),
    );
  }
}

/// A selectable row for [BusyMaxSidebarNavigation].
class BusyMaxSidebarNavigationTile extends StatelessWidget {
  const BusyMaxSidebarNavigationTile({
    super.key,
    required this.selected,
    required this.leading,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final Widget leading;
  final Widget title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YaruMasterTile(
      selected: selected,
      leading: IconTheme.merge(
        data: const IconThemeData(size: BusyMaxSizes.iconSm),
        child: leading,
      ),
      title: title,
      onTap: onTap,
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
            Divider(height: 1, thickness: 1, color: surfaceColors.divider),
        ],
      ],
    );
    if (!filled) {
      return list;
    }
    return BusyMaxGroupedSurface(child: list);
  }
}

typedef BusyMaxRowActivationCallback =
    void Function(BuildContext context, Offset? globalPosition);

class BusyMaxActionRow extends StatefulWidget {
  const BusyMaxActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
    this.onActivated,
    this.enabled = true,
    this.tooltip,
    this.destructive = false,
    this.autofocus = false,
    this.hoverColor,
  }) : assert(onTap == null || onActivated == null);

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BusyMaxRowActivationCallback? onActivated;
  final bool enabled;
  final String? tooltip;
  final bool destructive;
  final bool autofocus;
  final Color? hoverColor;

  @override
  State<BusyMaxActionRow> createState() => _BusyMaxActionRowState();
}

class _BusyMaxActionRowState extends State<BusyMaxActionRow> {
  int? _primaryPointer;
  Offset? _pointerDownPosition;

  @override
  void didUpdateWidget(covariant BusyMaxActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.onActivated == null) {
      _clearPointer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = widget.destructive
        ? TextStyle(color: colorScheme.error)
        : null;
    final subtitle =
        widget.subtitleWidget ??
        (widget.subtitle == null || widget.subtitle!.isEmpty
            ? null
            : Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ));
    final interactive =
        widget.enabled && (widget.onTap != null || widget.onActivated != null);
    final row = YaruListTile.square(
      leading: widget.leading,
      title:
          widget.titleWidget ??
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
      subtitle: subtitle == null
          ? null
          : _busyMaxGroupedRowSubtitle(
              context,
              subtitle,
              enabled: widget.enabled,
            ),
      trailing: widget.trailing,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      hoverColor: widget.hoverColor ?? busyMaxRowHoverColor(context),
      onTap: interactive ? _activate : null,
    );

    final trackedRow = widget.onActivated == null
        ? row
        : Listener(
            onPointerDown: widget.enabled ? _handlePointerDown : null,
            onPointerUp: widget.enabled ? _handlePointerUp : null,
            onPointerCancel: widget.enabled ? _handlePointerCancel : null,
            child: row,
          );

    if (widget.enabled || widget.tooltip == null) {
      return trackedRow;
    }

    return Tooltip(
      message: widget.tooltip!,
      child: Opacity(opacity: 0.6, child: IgnorePointer(child: trackedRow)),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) {
      return;
    }
    _primaryPointer = event.pointer;
    _pointerDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_primaryPointer != event.pointer) {
      return;
    }
    final pointer = event.pointer;
    scheduleMicrotask(() {
      if (mounted && _primaryPointer == pointer) {
        _clearPointer();
      }
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_primaryPointer == event.pointer) {
      _clearPointer();
    }
  }

  void _activate() {
    final onActivated = widget.onActivated;
    if (onActivated == null) {
      widget.onTap?.call();
      return;
    }
    final globalPosition = _pointerDownPosition;
    _clearPointer();
    onActivated(context, globalPosition);
  }

  void _clearPointer() {
    _primaryPointer = null;
    _pointerDownPosition = null;
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
  final VoidCallback onAddPressed;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancelAdding;
  final ValueChanged<String> onDeleted;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = _visibleCategorySuggestions(
      suggestions: suggestions,
      selectedCategories: categories,
    );
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
              _BusyMaxCategoryInput(
                hintText: addLabel,
                suggestions: visibleSuggestions,
                inputKey: inputKey,
                onSubmitted: onSubmitted,
                onCancel: onCancelAdding,
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
    return InputChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      deleteIcon: const Icon(YaruIcons.window_close),
      deleteButtonTooltipMessage:
          '${MaterialLocalizations.of(context).deleteButtonTooltip} $label',
      onDeleted: onDeleted,
    );
  }
}

class _BusyMaxAddCategoryChip extends StatelessWidget {
  const _BusyMaxAddCategoryChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _BusyMaxCategoryInput extends StatefulWidget {
  const _BusyMaxCategoryInput({
    required this.hintText,
    required this.suggestions,
    this.inputKey,
    required this.onSubmitted,
    required this.onCancel,
  });

  final String hintText;
  final List<String> suggestions;
  final Key? inputKey;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  @override
  State<_BusyMaxCategoryInput> createState() => _BusyMaxCategoryInputState();
}

class _BusyMaxCategoryInputState extends State<_BusyMaxCategoryInput> {
  FocusNode? _requestedFocusNode;

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    return SizedBox(
      width: 260,
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: YaruAutocomplete<String>(
          displayStringForOption: (option) => option,
          optionsMaxHeight: 240,
          optionsBuilder: (value) =>
              _matchingCategorySuggestions(widget.suggestions, value),
          onSelected: widget.onSubmitted,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _requestInitialFocus(focusNode);

            void submitTypedCategory() {
              final category = _canonicalCategory(
                controller.text,
                widget.suggestions,
              );
              if (category != null) {
                widget.onSubmitted(category);
              }
            }

            return TextField(
              key: widget.inputKey,
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hintText,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    YaruIconButton(
                      tooltip: materialL10n.okButtonLabel,
                      icon: const Icon(YaruIcons.checkmark),
                      onPressed: submitTypedCategory,
                    ),
                    YaruIconButton(
                      tooltip: materialL10n.cancelButtonLabel,
                      icon: const Icon(YaruIcons.window_close),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final options = _matchingCategorySuggestions(
                  widget.suggestions,
                  TextEditingValue(text: value),
                );
                if (options.isEmpty) {
                  submitTypedCategory();
                } else {
                  onFieldSubmitted();
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _requestInitialFocus(FocusNode focusNode) {
    if (identical(_requestedFocusNode, focusNode)) {
      return;
    }
    _requestedFocusNode = focusNode;
    // This field is inserted into an already-focused editor, so TextField's
    // autofocus alone does not reliably move focus from the Add chip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_requestedFocusNode, focusNode)) {
        focusNode.requestFocus();
      }
    });
  }
}

List<String> _visibleCategorySuggestions({
  required List<String> suggestions,
  required List<String> selectedCategories,
}) {
  final selected = {
    for (final category in selectedCategories) _normalizedCategory(category),
  };
  final seen = <String>{};
  return [
    for (final suggestion in suggestions)
      if (suggestion.trim() case final trimmed
          when trimmed.isNotEmpty &&
              !selected.contains(_normalizedCategory(trimmed)) &&
              seen.add(_normalizedCategory(trimmed)))
        trimmed,
  ];
}

Iterable<String> _matchingCategorySuggestions(
  List<String> suggestions,
  TextEditingValue value,
) {
  final query = _normalizedCategory(value.text);
  if (query.isEmpty) {
    return const [];
  }
  final matching = [
    for (final suggestion in suggestions)
      if (_normalizedCategory(suggestion).contains(query)) suggestion,
  ];
  matching.sort((left, right) {
    final leftNormalized = _normalizedCategory(left);
    final rightNormalized = _normalizedCategory(right);
    final leftExact = leftNormalized == query;
    final rightExact = rightNormalized == query;
    if (leftExact != rightExact) {
      return leftExact ? -1 : 1;
    }
    final leftStarts = leftNormalized.startsWith(query);
    final rightStarts = rightNormalized.startsWith(query);
    if (leftStarts != rightStarts) {
      return leftStarts ? -1 : 1;
    }
    return leftNormalized.compareTo(rightNormalized);
  });
  return matching.take(8);
}

String? _canonicalCategory(String value, List<String> suggestions) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final normalized = _normalizedCategory(trimmed);
  for (final suggestion in suggestions) {
    if (_normalizedCategory(suggestion) == normalized) {
      return suggestion;
    }
  }
  return trimmed;
}

String _normalizedCategory(String value) => value.trim().toLowerCase();

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
      subtitle: _busyMaxGroupedRowSubtitle(
        context,
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        enabled: enabled,
      ),
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
    this.errorText,
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
  final String? errorText;
  final Widget? leading;
  final bool enabled;
  final String? tooltip;
  final double width;
  final Widget? trailingAction;
  final Widget Function(BuildContext context, T value)? menuItemBuilder;
  final Widget Function(BuildContext context, T value)? selectedBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasError = errorText?.isNotEmpty ?? false;
        final subtitleWidget = hasError
            ? Semantics(
                liveRegion: true,
                child: Text(
                  errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              )
            : subtitle == null
            ? null
            : Text(subtitle!);
        final styledSubtitle = subtitleWidget == null
            ? null
            : _busyMaxGroupedRowSubtitle(
                context,
                subtitleWidget,
                enabled: enabled,
              );
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final actionAllowance = trailingAction == null
            ? 0.0
            : BusyMaxSizes.headerIconButton + BusyMaxSpacing.xs;
        final stackControl =
            !constraints.hasBoundedWidth ||
            constraints.maxWidth < 560 ||
            textScale > 1.2;
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : width + BusyMaxSpacing.md * 2 + actionAllowance;
        final maximumInlineSelectorWidth = (availableWidth * 0.46)
            .clamp(120.0, double.infinity)
            .toDouble();
        final selectorWidth = stackControl
            ? (availableWidth - BusyMaxSpacing.md * 2 - actionAllowance)
                  .clamp(120.0, double.infinity)
                  .toDouble()
            : constraints.hasBoundedWidth
            ? width.clamp(120.0, maximumInlineSelectorWidth).toDouble()
            : width.clamp(120.0, double.infinity).toDouble();
        final selector = SizedBox(
          width: selectorWidth,
          child: BusyMaxMenuButton<T>(
            tooltip: tooltip ?? title,
            entries: [
              for (final value in values)
                BusyMaxMenuEntry<T>(
                  value: value,
                  label: labelFor(value),
                  child: menuItemBuilder?.call(context, value),
                ),
            ],
            onSelected: onSelected,
            minMenuWidth: selectorWidth,
            menuPosition: null,
            enabled: enabled,
            triggerBuilder: (context, onPressed, focusNode) {
              return OutlinedButton(
                focusNode: focusNode,
                onPressed: onPressed,
                child: Row(
                  children: [
                    Expanded(
                      child:
                          selectedBuilder?.call(context, selected) ??
                          Text(
                            labelFor(selected),
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                    const SizedBox(width: BusyMaxSpacing.sm),
                    const Icon(YaruIcons.pan_down),
                  ],
                ),
              );
            },
          ),
        );
        final trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            selector,
            if (trailingAction != null) ...[
              const SizedBox(width: BusyMaxSpacing.xs),
              trailingAction!,
            ],
          ],
        );
        final row = stackControl
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YaruListTile.square(
                    leading: leading,
                    titleText: title,
                    subtitle: styledSubtitle,
                    enabled: enabled,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BusyMaxSpacing.md,
                      0,
                      BusyMaxSpacing.md,
                      BusyMaxSpacing.md,
                    ),
                    child: trailing,
                  ),
                ],
              )
            : YaruListTile.square(
                leading: leading,
                titleText: title,
                subtitle: styledSubtitle,
                trailing: trailing,
                enabled: enabled,
              );
        // YaruListTile deliberately expands its title inside a Row, so it
        // requires a finite horizontal constraint. If dialog content is
        // measured unbounded, use the compact stacked form and only reserve
        // the selector's requested width plus the tile padding.
        final boundedRow = constraints.hasBoundedWidth
            ? row
            : SizedBox(width: availableWidth, child: row);
        final validatedRow = hasError
            ? Semantics(
                container: true,
                validationResult: ui.SemanticsValidationResult.invalid,
                child: boundedRow,
              )
            : boundedRow;

        if (enabled) {
          return validatedRow;
        }

        final disabledRow = Semantics(
          container: true,
          button: true,
          enabled: false,
          label: subtitle == null || subtitle!.isEmpty
              ? title
              : '$title, $subtitle',
          value: labelFor(selected),
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.6,
              child: ExcludeFocus(child: IgnorePointer(child: validatedRow)),
            ),
          ),
        );
        return tooltip == null
            ? disabledRow
            : Tooltip(
                message: tooltip!,
                excludeFromSemantics: true,
                child: disabledRow,
              );
      },
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
    return YaruSwitchListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      secondary: leading,
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : _busyMaxGroupedRowSubtitle(
              context,
              Text(subtitle!),
              enabled: enabled,
            ),
      shape: const RoundedRectangleBorder(),
      hoverColor: busyMaxRowHoverColor(context),
    );
  }
}

class BusyMaxMenuEntry<T> {
  const BusyMaxMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.child,
    this.enabled = true,
    this.checked = false,
    this.tooltip,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Widget? child;
  final bool enabled;
  final bool checked;
  final String? tooltip;
  final bool destructive;
}

typedef BusyMaxMenuTriggerBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      FocusNode focusNode,
    );

/// Controls keyboard-driven opening of a [BusyMaxMenuButton].
///
/// Pointer activation remains owned by the button so a mouse click does not
/// paint a keyboard focus ring. Commands and shortcuts use
/// [openForKeyboard], which transfers focus to the first enabled menu item.
class BusyMaxMenuController {
  Object? _owner;
  bool Function()? _openForKeyboard;
  VoidCallback? _close;
  bool Function()? _isOpen;

  bool get isAttached => _owner != null;

  bool get isOpen => _isOpen?.call() ?? false;

  /// Opens the attached menu in keyboard modality.
  ///
  /// Returns false when the menu is not attached, is disabled, or is already
  /// open.
  bool openForKeyboard() {
    final open = _openForKeyboard;
    if (open == null) {
      return false;
    }
    return open();
  }

  void close() => _close?.call();

  void _attach({
    required Object owner,
    required bool Function() openForKeyboard,
    required VoidCallback close,
    required bool Function() isOpen,
  }) {
    // Flutter can mount a replacement responsive subtree before disposing its
    // predecessor. Point commands at the newest attachment; the owner check
    // in [_detach] prevents the retiring state from detaching its successor.
    _owner = owner;
    _openForKeyboard = openForKeyboard;
    _close = close;
    _isOpen = isOpen;
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) {
      return;
    }
    _owner = null;
    _openForKeyboard = null;
    _close = null;
    _isOpen = null;
  }
}

class BusyMaxMenuButton<T> extends StatefulWidget {
  const BusyMaxMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = const Icon(YaruIcons.view_more),
    this.minMenuWidth = 180,
    this.menuPosition = const Offset(0, BusyMaxSizes.headerIconButton),
    this.triggerBuilder,
    this.controller,
    this.enabled = true,
  });

  final String tooltip;
  final Widget icon;
  final List<BusyMaxMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final double minMenuWidth;
  final Offset? menuPosition;
  final BusyMaxMenuTriggerBuilder? triggerBuilder;
  final BusyMaxMenuController? controller;
  final bool enabled;

  @override
  State<BusyMaxMenuButton<T>> createState() => _BusyMaxMenuButtonState<T>();
}

class _BusyMaxMenuButtonState<T> extends State<BusyMaxMenuButton<T>> {
  final _menuController = MenuController();
  late final FocusNode _triggerFocusNode;
  final List<FocusNode> _entryFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _triggerFocusNode = FocusNode(
      debugLabel: 'BusyMax menu trigger',
      onKeyEvent: _handleTriggerKeyEvent,
    );
    _synchronizeEntryFocusNodes();
    _attachExternalController();
  }

  @override
  void didUpdateWidget(covariant BusyMaxMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      _attachExternalController();
    }
    _synchronizeEntryFocusNodes();
    if (oldWidget.enabled && !widget.enabled && _menuController.isOpen) {
      _menuController.close();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _triggerFocusNode.dispose();
    for (final focusNode in _entryFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reservesLeadingSpace = widget.entries.any(
      (entry) => entry.checked || entry.icon != null,
    );
    return MenuAnchor(
      controller: _menuController,
      childFocusNode: _triggerFocusNode,
      crossAxisUnconstrained: false,
      style: busyMaxDropdownMenuStyle(context, minWidth: widget.minMenuWidth),
      builder: (context, controller, child) {
        final triggerBuilder = widget.triggerBuilder;
        if (triggerBuilder != null) {
          return triggerBuilder(
            context,
            widget.enabled ? () => _toggleMenu(controller) : null,
            _triggerFocusNode,
          );
        }
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
          focusNode: _triggerFocusNode,
          onPressed: widget.enabled ? () => _toggleMenu(controller) : null,
          style: busyMaxHeaderIconButtonStyle(
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: busyMaxSubtleButtonBackground(context),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        );
      },
      menuChildren: [
        for (var index = 0; index < widget.entries.length; index += 1)
          _BusyMaxMenuEntryButton<T>(
            entry: widget.entries[index],
            focusNode: _entryFocusNodes[index],
            reserveLeadingSpace: reservesLeadingSpace,
            onSelected: (value) {
              widget.onSelected(value);
              _menuController.close();
            },
          ),
      ],
    );
  }

  KeyEventResult _handleTriggerKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowDown) {
      if (_menuController.isOpen) {
        if (key == LogicalKeyboardKey.arrowDown) {
          _focusFirstEnabledEntry();
        } else {
          _menuController.close();
        }
      } else {
        _openForKeyboard();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _menuController.isOpen) {
      _menuController.close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
      return;
    }
    _openMenu(controller);
  }

  void _openMenu(MenuController controller) {
    final position = widget.menuPosition;
    if (position == null) {
      controller.open();
    } else {
      controller.open(position: position);
    }
  }

  bool _openForKeyboard() {
    if (!widget.enabled || _menuController.isOpen) {
      return false;
    }
    _triggerFocusNode.requestFocus();
    _openMenu(_menuController);
    _focusFirstEnabledEntry();
    return true;
  }

  void _focusFirstEnabledEntry() {
    final index = widget.entries.indexWhere((entry) => entry.enabled);
    if (index < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menuController.isOpen) {
        _entryFocusNodes[index].requestFocus();
      }
    });
  }

  void _attachExternalController() {
    widget.controller?._attach(
      owner: this,
      openForKeyboard: _openForKeyboard,
      close: _menuController.close,
      isOpen: () => _menuController.isOpen,
    );
  }

  void _synchronizeEntryFocusNodes() {
    while (_entryFocusNodes.length < widget.entries.length) {
      _entryFocusNodes.add(
        FocusNode(debugLabel: 'BusyMax menu entry ${_entryFocusNodes.length}'),
      );
    }
    while (_entryFocusNodes.length > widget.entries.length) {
      _entryFocusNodes.removeLast().dispose();
    }
  }
}

class _BusyMaxMenuEntryButton<T> extends StatelessWidget {
  const _BusyMaxMenuEntryButton({
    required this.entry,
    required this.focusNode,
    required this.reserveLeadingSpace,
    required this.onSelected,
  });

  final BusyMaxMenuEntry<T> entry;
  final FocusNode focusNode;
  final bool reserveLeadingSpace;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = entry.destructive ? colorScheme.error : null;
    final iconData = entry.checked ? YaruIcons.checkmark : entry.icon;
    final icon = iconData == null
        ? reserveLeadingSpace
              ? const SizedBox.square(dimension: BusyMaxSizes.iconSm)
              : null
        : Icon(iconData, size: BusyMaxSizes.iconSm, color: foreground);
    final row = MenuItemButton(
      focusNode: focusNode,
      leadingIcon: icon,
      onPressed: entry.enabled ? () => onSelected(entry.value) : null,
      style: busyMaxDropdownMenuItemStyle(context).copyWith(
        foregroundColor: foreground == null
            ? null
            : WidgetStatePropertyAll(foreground),
      ),
      child:
          entry.child ??
          Text(
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
    this.suggested = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool suggested;
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
    final button = suggested
        ? BusyMaxPushButton.suggested(onPressed: onPressed, child: child)
        : BusyMaxPushButton.standard(onPressed: onPressed, child: child);
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
    this.cancelEnabled = true,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;
  final bool cancelEnabled;

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
          BusyMaxPushButton.standard(
            onPressed: cancelEnabled ? onCancel : null,
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
          BusyMaxPushButton.suggested(
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
    final selector = ToggleButtons(
      isSelected: [allDay, !allDay],
      onPressed: (index) {
        final value = index == 0;
        if (value != allDay) {
          onChanged(value);
        }
      },
      children: [
        for (final label in [l10n.allDay, l10n.timeSlot])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
            child: Text(label),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stackSelector =
            !constraints.hasBoundedWidth ||
            constraints.maxWidth < 480 ||
            textScale > 1.2;
        final label = YaruListTile.square(
          title: Text(l10n.timeMode),
          subtitle: _busyMaxGroupedRowSubtitle(
            context,
            Text(l10n.timeModeDescription),
          ),
          trailing: stackSelector ? null : selector,
        );
        if (!stackSelector) {
          return label;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label,
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: BusyMaxSpacing.md,
                end: BusyMaxSpacing.md,
                bottom: BusyMaxSpacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: selector,
              ),
            ),
          ],
        );
      },
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
    this.cancelEnabled = true,
    this.contentMaxWidth = 640,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;
  final bool cancelEnabled;
  final double contentMaxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BusyMaxEditorHeader(
            title: title,
            cancelLabel: cancelLabel,
            saveLabel: saveLabel,
            onCancel: onCancel,
            onSave: onSave,
            saving: saving,
            cancelEnabled: cancelEnabled,
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
        elevation: BusyMaxElevation.window,
        shadowColor: BusyMaxShadow.physicalColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BusyMaxRadius.lg),
          side: BorderSide(
            color: surfaceColors.floatingBorder,
            width: BusyMaxStroke.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
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
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Dialog(
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
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: BusyMaxSpacing.sm,
                      overflowSpacing: BusyMaxSpacing.sm,
                      children: actions,
                    ),
                  ),
              ],
            ),
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
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
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
    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: YaruDialogTitleBar(title: Text(title), centerTitle: true),
      content: Text(message),
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        if (destructive)
          BusyMaxPushButton.destructive(
            context: context,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          )
        else
          BusyMaxPushButton.suggested(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    );
  }
}

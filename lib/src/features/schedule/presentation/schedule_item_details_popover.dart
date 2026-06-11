import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../calendar_providers/calendar_description.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'schedule_event_block.dart';

enum ScheduleItemDetailsAction { export, edit }

Future<ScheduleItemDetailsAction?> showScheduleItemDetailsPopover({
  required BuildContext context,
  required BuildContext anchorContext,
  required ScheduleItem item,
  Offset? anchorPoint,
}) {
  final anchorRect = anchorPoint == null
      ? _globalRectFor(anchorContext)
      : _globalRectForPoint(anchorPoint);
  return showGeneralDialog<ScheduleItemDetailsAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _ScheduleItemDetailsPopover(anchorRect: anchorRect, item: item);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
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
}

class _ScheduleItemDetailsPopover extends StatelessWidget {
  const _ScheduleItemDetailsPopover({
    required this.anchorRect,
    required this.item,
  });

  final Rect? anchorRect;
  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor = ScheduleProjection.colorForItem(
      item,
      colorScheme.brightness,
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _popoverLayout(
              anchorRect,
              constraints.biggest,
              textDirection: Directionality.of(context),
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _PopoverPositionDelegate(layout),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: layout.width,
                        maxWidth: layout.width,
                      ),
                      child: _ScheduleItemDetailsPopoverCard(
                        item: item,
                        itemColor: itemColor,
                        surfaceColors: surfaceColors,
                        arrowSide: layout.arrowSide,
                        arrowAlignment: layout.arrowAlignment,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScheduleItemDetailsPopoverCard extends StatelessWidget {
  const _ScheduleItemDetailsPopoverCard({
    required this.item,
    required this.itemColor,
    required this.surfaceColors,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  final ScheduleItem item;
  final Color itemColor;
  final BusyMaxSurfaceColors surfaceColors;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: BusyMaxPopoverSurface(
          color: surfaceColors.popover,
          arrowSide: arrowSide,
          arrowAlignment: arrowAlignment,
          child: Padding(
            padding: const EdgeInsets.all(BusyMaxSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: BusyMaxSizes.iconSm,
                      height: BusyMaxSizes.iconSm,
                      margin: const EdgeInsets.only(top: BusyMaxSpacing.xs),
                      decoration: BoxDecoration(
                        color: itemColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: BusyMaxSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: BusyMaxSpacing.xxs),
                          Text(
                            _kindLabel(context, item),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: BusyMaxSpacing.sm),
                    _PopoverActions(item: item, surfaceColors: surfaceColors),
                  ],
                ),
                const SizedBox(height: BusyMaxSpacing.lg),
                _ScheduleItemDetails(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverActions extends StatelessWidget {
  const _PopoverActions({required this.item, required this.surfaceColors});

  final ScheduleItem item;
  final BusyMaxSurfaceColors surfaceColors;

  @override
  Widget build(BuildContext context) {
    final foreground = surfaceColors.mutedForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BusyMaxCircularAction(
          icon: Icons.download_outlined,
          tooltip: context.l10n.export,
          backgroundColor: surfaceColors.control,
          foregroundColor: foreground,
          hoverColor: surfaceColors.controlHover,
          onPressed: () =>
              Navigator.of(context).pop(ScheduleItemDetailsAction.export),
        ),
        const SizedBox(width: BusyMaxSpacing.xs),
        BusyMaxCircularAction(
          icon: Icons.edit_outlined,
          tooltip: _editLabel(context, item),
          backgroundColor: surfaceColors.control,
          foregroundColor: foreground,
          hoverColor: surfaceColors.controlHover,
          onPressed: () =>
              Navigator.of(context).pop(ScheduleItemDetailsAction.edit),
        ),
        const SizedBox(width: BusyMaxSpacing.xs),
        BusyMaxCircularAction(
          icon: Icons.close,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          backgroundColor: surfaceColors.control,
          foregroundColor: foreground,
          hoverColor: surfaceColors.controlHover,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

Rect? _globalRectFor(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

Rect _globalRectForPoint(Offset point) {
  return Rect.fromCenter(center: point, width: 1, height: 1);
}

_PopoverLayout _popoverLayout(
  Rect? anchor,
  Size viewport, {
  required TextDirection textDirection,
}) {
  const margin = BusyMaxSpacing.md;
  const gap = BusyMaxSpacing.xs;
  const preferredWidth = 420.0;
  const minWidth = 280.0;
  const estimatedHeight = 310.0;

  final availableWidth = math.max(0.0, viewport.width - margin * 2);
  final width = availableWidth < minWidth
      ? availableWidth
      : math.min(preferredWidth, availableWidth);
  final maxLeft = math.max(margin, viewport.width - width - margin);

  if (anchor == null) {
    return _PopoverLayout(
      anchor: null,
      left: ((viewport.width - width) / 2).clamp(margin, maxLeft).toDouble(),
      width: width,
      arrowSide: BusyMaxPopoverArrowSide.top,
      arrowAlignment: 0.5,
    );
  }

  final preferredLeft = textDirection == TextDirection.rtl
      ? anchor.right - width
      : anchor.left;
  final left = preferredLeft.clamp(margin, maxLeft).toDouble();
  final below = anchor.bottom + gap;
  final showBelow = below + estimatedHeight <= viewport.height - margin;
  final arrowAlignment = ((anchor.center.dx - left) / width)
      .clamp(0.08, 0.92)
      .toDouble();

  return _PopoverLayout(
    anchor: anchor,
    left: left,
    width: width,
    arrowSide: showBelow
        ? BusyMaxPopoverArrowSide.top
        : BusyMaxPopoverArrowSide.bottom,
    arrowAlignment: arrowAlignment,
  );
}

class _PopoverLayout {
  const _PopoverLayout({
    required this.anchor,
    required this.left,
    required this.width,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  final Rect? anchor;
  final double left;
  final double width;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;
}

class _PopoverPositionDelegate extends SingleChildLayoutDelegate {
  const _PopoverPositionDelegate(this.layout);

  final _PopoverLayout layout;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    const margin = BusyMaxSpacing.md;
    return BoxConstraints(
      minWidth: layout.width,
      maxWidth: layout.width,
      maxHeight: math.max(0, constraints.maxHeight - margin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const margin = BusyMaxSpacing.md;
    const gap = BusyMaxSpacing.xs;
    final maxTop = math.max(margin, size.height - childSize.height - margin);
    final anchor = layout.anchor;

    if (anchor == null) {
      final centered = (size.height - childSize.height) / 2;
      return Offset(layout.left, centered.clamp(margin, maxTop).toDouble());
    }

    final preferredTop = switch (layout.arrowSide) {
      BusyMaxPopoverArrowSide.top => anchor.bottom + gap,
      BusyMaxPopoverArrowSide.bottom => anchor.top - childSize.height - gap,
    };
    return Offset(layout.left, preferredTop.clamp(margin, maxTop).toDouble());
  }

  @override
  bool shouldRelayout(covariant _PopoverPositionDelegate oldDelegate) {
    final old = oldDelegate.layout;
    return layout.anchor != old.anchor ||
        layout.left != old.left ||
        layout.width != old.width ||
        layout.arrowSide != old.arrowSide ||
        layout.arrowAlignment != old.arrowAlignment;
  }
}

class _ScheduleItemDetails extends StatelessWidget {
  const _ScheduleItemDetails({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[
      _ScheduleDetailRow(
        icon: Icons.schedule,
        text: _dateTimeLabel(context, item),
      ),
      _ScheduleDetailRow(
        icon: item is TaskScheduleItem
            ? YaruIcons.task_list
            : YaruIcons.calendar,
        text: ScheduleProjection.sourceLabelForScheduleItem(item),
      ),
      if (_accountLabel(item) case final account? when account.isNotEmpty)
        _ScheduleDetailRow(icon: Icons.person_outline, text: account),
      if (item is CalendarScheduleItem)
        ..._eventDetails(context, item as CalendarScheduleItem),
      if (item is TaskScheduleItem)
        ..._taskDetails(context, item as TaskScheduleItem),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final detail in details) ...[
          detail,
          if (detail != details.last) const SizedBox(height: BusyMaxSpacing.sm),
        ],
      ],
    );
  }
}

class _ScheduleDetailRow extends StatelessWidget {
  const _ScheduleDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: BusyMaxSizes.iconSm,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: BusyMaxSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleDetailRichRow extends StatelessWidget {
  const _ScheduleDetailRichRow({
    required this.icon,
    required this.html,
    required this.fallbackText,
  });

  final IconData icon;
  final String html;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final document = htmlCalendarDescriptionDocument(html);
    final text = document.text.isEmpty ? fallbackText.trim() : document.text;
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: BusyMaxSizes.iconSm,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: BusyMaxSpacing.sm),
        Expanded(
          child: Text.rich(
            _descriptionTextSpan(text, document.ranges, baseStyle),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

List<Widget> _eventDetails(BuildContext context, CalendarScheduleItem item) {
  final location = item.location?.trim();
  final description = item.description?.trim();
  return [
    if (location != null && location.isNotEmpty)
      _ScheduleDetailRow(icon: Icons.place_outlined, text: location),
    if (item.categories.isNotEmpty)
      _ScheduleDetailRow(
        icon: Icons.sell_outlined,
        text: '${context.l10n.categories}: ${item.categories.join(', ')}',
      ),
    if (item.descriptionHtml != null &&
        isHtmlContentType(item.descriptionContentType))
      _ScheduleDetailRichRow(
        icon: Icons.notes,
        html: item.descriptionHtml!,
        fallbackText: description ?? '',
      )
    else if (description != null && description.isNotEmpty)
      _ScheduleDetailRow(icon: Icons.notes, text: description),
  ];
}

List<Widget> _taskDetails(BuildContext context, TaskScheduleItem item) {
  final notes = item.notes?.trim();
  return [
    _ScheduleDetailRow(
      icon: item.completed ? YaruIcons.checkmark : Icons.radio_button_unchecked,
      text: item.completed ? context.l10n.completed : context.l10n.openStatus,
    ),
    if (item.categories.isNotEmpty)
      _ScheduleDetailRow(
        icon: Icons.sell_outlined,
        text: '${context.l10n.categories}: ${item.categories.join(', ')}',
      ),
    if (notes != null && notes.isNotEmpty)
      _ScheduleDetailRow(icon: Icons.notes, text: notes),
  ];
}

String _kindLabel(BuildContext context, ScheduleItem item) {
  return item is CalendarScheduleItem
      ? context.l10n.createEventAtTime
      : context.l10n.createTaskAtDate;
}

String _editLabel(BuildContext context, ScheduleItem item) {
  return item is CalendarScheduleItem
      ? context.l10n.editEvent
      : context.l10n.editTask;
}

TextSpan _descriptionTextSpan(
  String text,
  List<CalendarDescriptionStyleRange> ranges,
  TextStyle? baseStyle,
) {
  final children = <TextSpan>[];
  final boundaries = <int>{0, text.length};
  for (final range in ranges) {
    if (range.start >= 0 &&
        range.end <= text.length &&
        range.start < range.end) {
      boundaries
        ..add(range.start)
        ..add(range.end);
    }
  }
  final sorted = boundaries.toList()..sort();
  for (var index = 0; index < sorted.length - 1; index += 1) {
    final start = sorted[index];
    final end = sorted[index + 1];
    final styles = <CalendarDescriptionInlineStyle>{};
    for (final range in ranges) {
      if (range.start <= start && range.end >= end) {
        styles.addAll(range.styles);
      }
    }
    children.add(
      TextSpan(
        text: text.substring(start, end),
        style: baseStyle?.copyWith(
          fontWeight: styles.contains(CalendarDescriptionInlineStyle.bold)
              ? FontWeight.w700
              : null,
          fontStyle: styles.contains(CalendarDescriptionInlineStyle.italic)
              ? FontStyle.italic
              : null,
          decoration: styles.contains(CalendarDescriptionInlineStyle.underline)
              ? TextDecoration.underline
              : null,
        ),
      ),
    );
  }
  return TextSpan(style: baseStyle, children: children);
}

String _dateTimeLabel(BuildContext context, ScheduleItem item) {
  if (item.start == null) {
    return context.l10n.noDate;
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dateFormat = DateFormat.yMMMd(locale);
  final day = dateFormat.format(item.start!);
  if (item.allDay) {
    return '$day · ${context.l10n.allDay}';
  }
  return '$day · ${scheduleTimeRange(context, item)}';
}

String? _accountLabel(ScheduleItem item) {
  final name = item.accountDisplayName?.trim();
  final email = item.accountEmail?.trim();
  if (name != null && name.isNotEmpty && email != null && email.isNotEmpty) {
    if (name.toLowerCase() == email.toLowerCase()) {
      return email;
    }
    return '$name · $email';
  }
  if (name != null && name.isNotEmpty) {
    return name;
  }
  if (email != null && email.isNotEmpty) {
    return email;
  }
  return null;
}

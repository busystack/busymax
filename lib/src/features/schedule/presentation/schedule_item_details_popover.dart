import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../calendar_providers/calendar_description.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import 'schedule_anchored_popover.dart';
import 'schedule_event_block.dart';

enum ScheduleItemDetailsAction { export, edit, delete }

Future<ScheduleItemDetailsAction?> showScheduleItemDetailsPopover({
  required BuildContext context,
  required BuildContext anchorContext,
  required ScheduleItem item,
  Offset? anchorPoint,
}) {
  return showScheduleAnchoredPopover<ScheduleItemDetailsAction>(
    context: context,
    anchorContext: anchorContext,
    anchorPoint: anchorPoint,
    semanticLabel: item.title,
    builder: (context, arrowSide, arrowAlignment) {
      return _ScheduleItemDetailsPopoverCard(
        item: item,
        arrowSide: arrowSide,
        arrowAlignment: arrowAlignment,
      );
    },
  );
}

class _ScheduleItemDetailsPopoverCard extends StatelessWidget {
  const _ScheduleItemDetailsPopoverCard({
    required this.item,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  final ScheduleItem item;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final itemColor = ScheduleProjection.colorForItem(
      item,
      colorScheme.brightness,
    );
    return Material(
      color: Colors.transparent,
      child: BusyMaxPopoverSurface(
        color: surfaceColors.popover,
        arrowSide: arrowSide,
        arrowAlignment: arrowAlignment,
        child: SingleChildScrollView(
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
                  _PopoverActions(item: item),
                ],
              ),
              const SizedBox(height: BusyMaxSpacing.lg),
              _ScheduleItemDetails(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopoverActions extends StatelessWidget {
  const _PopoverActions({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      YaruIconButton(
        icon: const Icon(Icons.download_outlined, size: BusyMaxSizes.iconSm),
        tooltip: context.l10n.export,
        onPressed: () =>
            Navigator.of(context).pop(ScheduleItemDetailsAction.export),
      ),
      if (item.capabilities.canEdit)
        YaruIconButton(
          icon: const Icon(Icons.edit_outlined, size: BusyMaxSizes.iconSm),
          tooltip: _editLabel(context, item),
          onPressed: () =>
              Navigator.of(context).pop(ScheduleItemDetailsAction.edit),
        ),
      if (item.capabilities.canDelete)
        YaruIconButton(
          icon: Icon(
            Icons.delete_outline,
            size: BusyMaxSizes.iconSm,
            color: Theme.of(context).colorScheme.error,
          ),
          tooltip: context.l10n.delete,
          onPressed: () =>
              Navigator.of(context).pop(ScheduleItemDetailsAction.delete),
        ),
      YaruIconButton(
        icon: const Icon(Icons.close, size: BusyMaxSizes.iconSm),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index += 1) ...[
          if (index > 0) const SizedBox(width: BusyMaxSpacing.xs),
          actions[index],
        ],
      ],
    );
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
    if (item.reminderMinutesBeforeStart.isNotEmpty)
      _ScheduleDetailRow(
        icon: Icons.notifications_outlined,
        text:
            '${context.l10n.reminder}: '
            '${item.reminderMinutesBeforeStart.map((minutes) => _reminderBeforeLabel(context, minutes)).join(', ')}',
      ),
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
    if (item.reminder != null)
      _ScheduleDetailRow(
        icon: Icons.notifications_outlined,
        text:
            '${context.l10n.reminder}: '
            '${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_jm().format(item.reminder!)}',
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

String _reminderBeforeLabel(BuildContext context, int minutes) {
  return switch (minutes) {
    0 => context.l10n.reminderAtStart,
    < 60 => context.l10n.reminderMinutesBefore(minutes),
    < 1440 when minutes % 60 == 0 => context.l10n.reminderHoursBefore(
      minutes ~/ 60,
    ),
    >= 1440 when minutes % 1440 == 0 => context.l10n.reminderDaysBefore(
      minutes ~/ 1440,
    ),
    _ => context.l10n.reminderMinutesBefore(minutes),
  };
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

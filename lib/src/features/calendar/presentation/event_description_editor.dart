import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../calendar_providers/calendar_description.dart';
import '../../../l10n/l10n.dart';
import '../../../task_providers/task_provider.dart';

class EventDescriptionValue {
  const EventDescriptionValue({
    required this.text,
    this.contentType,
    this.html,
  });

  final String text;
  final String? contentType;
  final String? html;
}

class EventDescriptionEditor extends StatefulWidget {
  const EventDescriptionEditor({
    super.key,
    required this.provider,
    required this.text,
    required this.contentType,
    required this.html,
    required this.onChanged,
  });

  final BusyProvider provider;
  final String? text;
  final String? contentType;
  final String? html;
  final ValueChanged<EventDescriptionValue> onChanged;

  @override
  State<EventDescriptionEditor> createState() => _EventDescriptionEditorState();
}

class _EventDescriptionEditorState extends State<EventDescriptionEditor> {
  late final _RichDescriptionController _controller;
  var _notifying = false;

  bool get _supportsRichText => widget.provider == TaskProvider.microsoft;

  @override
  void initState() {
    super.initState();
    final document = _supportsRichText && isHtmlContentType(widget.contentType)
        ? htmlCalendarDescriptionDocument(widget.html ?? '')
        : CalendarDescriptionDocument(
            text: widget.text ?? '',
            ranges: const [],
          );
    _controller = _RichDescriptionController(document);
    _controller.addListener(_emitChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_emitChanged)
      ..dispose();
    super.dispose();
  }

  void _emitChanged() {
    if (_notifying) {
      return;
    }
    _notifying = true;
    try {
      final text = _controller.text;
      if (_supportsRichText) {
        final html = calendarDescriptionToHtml(text, _controller.ranges);
        widget.onChanged(
          EventDescriptionValue(text: text, contentType: 'html', html: html),
        );
        return;
      }
      widget.onChanged(EventDescriptionValue(text: text));
    } finally {
      _notifying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_supportsRichText)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BusyMaxSpacing.sm,
              BusyMaxSpacing.xs,
              BusyMaxSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                _FormatButton(
                  label: context.l10n.formatBoldShortLabel,
                  tooltip: context.l10n.formatBoldTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.bold,
                  ),
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.bold),
                ),
                const SizedBox(width: BusyMaxSpacing.xs),
                _FormatButton(
                  label: context.l10n.formatItalicShortLabel,
                  tooltip: context.l10n.formatItalicTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.italic,
                  ),
                  italic: true,
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.italic),
                ),
                const SizedBox(width: BusyMaxSpacing.xs),
                _FormatButton(
                  label: context.l10n.formatUnderlineShortLabel,
                  tooltip: context.l10n.formatUnderlineTooltip,
                  active: _controller.selectionHasStyle(
                    CalendarDescriptionInlineStyle.underline,
                  ),
                  underline: true,
                  onPressed: () =>
                      _toggleStyle(CalendarDescriptionInlineStyle.underline),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 8,
          decoration: _descriptionDecoration(context),
          cursorColor: Theme.of(context).colorScheme.primary,
          selectionControls: materialTextSelectionControls,
          style: Theme.of(context).textTheme.bodyMedium,
          onTap: () => setState(() {}),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  void _toggleStyle(CalendarDescriptionInlineStyle style) {
    setState(() {
      _controller.toggleStyle(style);
    });
    _emitChanged();
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.italic = false,
    this.underline = false,
  });

  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;
  final bool italic;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: BusyMaxSizes.pushButtonHeight,
        child: YaruIconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: busyMaxHeaderIconButtonStyle(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (active || states.contains(WidgetState.hovered)) {
                return surfaceColors.controlHover;
              }
              return Colors.transparent;
            }),
          ),
          icon: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: italic ? FontStyle.italic : null,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _descriptionDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: context.l10n.description,
    alignLabelWithHint: true,
    floatingLabelStyle: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
    labelStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    filled: true,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: BusyMaxSpacing.sm,
      vertical: BusyMaxSpacing.sm,
    ),
  );
}

class _RichDescriptionController extends TextEditingController {
  _RichDescriptionController(CalendarDescriptionDocument document)
    : _ranges = List<CalendarDescriptionStyleRange>.of(document.ranges),
      _previousText = document.text,
      super(text: document.text);

  List<CalendarDescriptionStyleRange> _ranges;
  String _previousText;
  final _updatingRanges = false;

  List<CalendarDescriptionStyleRange> get ranges => List.unmodifiable(_ranges);

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    super.value = newValue;
    if (_updatingRanges || oldText == newValue.text) {
      _previousText = newValue.text;
      return;
    }
    _ranges = _adjustRanges(_ranges, _previousText, newValue.text);
    _previousText = newValue.text;
  }

  bool selectionHasStyle(CalendarDescriptionInlineStyle style) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return false;
    }
    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;
    return _ranges.any(
      (range) =>
          range.start <= start &&
          range.end >= end &&
          range.styles.contains(style),
    );
  }

  void toggleStyle(CalendarDescriptionInlineStyle style) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }
    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;
    final remove = selectionHasStyle(style);
    if (remove) {
      _ranges = [
        for (final range in _ranges) ..._removeStyle(range, start, end, style),
      ];
    } else {
      _ranges = _mergeControllerRanges([
        ..._ranges,
        CalendarDescriptionStyleRange(start: start, end: end, styles: {style}),
      ]);
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }
    final children = <TextSpan>[];
    final boundaries = <int>{0, text.length};
    for (final range in _ranges) {
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
      for (final range in _ranges) {
        if (range.start <= start && range.end >= end) {
          styles.addAll(range.styles);
        }
      }
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: _styleFor(style, styles),
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

TextStyle? _styleFor(
  TextStyle? base,
  Set<CalendarDescriptionInlineStyle> styles,
) {
  return base?.copyWith(
    fontWeight: styles.contains(CalendarDescriptionInlineStyle.bold)
        ? FontWeight.w700
        : null,
    fontStyle: styles.contains(CalendarDescriptionInlineStyle.italic)
        ? FontStyle.italic
        : null,
    decoration: styles.contains(CalendarDescriptionInlineStyle.underline)
        ? TextDecoration.underline
        : null,
  );
}

List<CalendarDescriptionStyleRange> _adjustRanges(
  List<CalendarDescriptionStyleRange> ranges,
  String oldText,
  String newText,
) {
  var prefix = 0;
  final maxPrefix = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  while (prefix < maxPrefix &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix += 1;
  }
  var oldSuffix = oldText.length;
  var newSuffix = newText.length;
  while (oldSuffix > prefix &&
      newSuffix > prefix &&
      oldText.codeUnitAt(oldSuffix - 1) == newText.codeUnitAt(newSuffix - 1)) {
    oldSuffix -= 1;
    newSuffix -= 1;
  }
  final removed = oldSuffix - prefix;
  final inserted = newSuffix - prefix;
  final delta = inserted - removed;
  return [
    for (final range in ranges)
      if (_adjustRange(range, prefix, oldSuffix, delta, newText.length)
          case final adjusted?)
        adjusted,
  ];
}

CalendarDescriptionStyleRange? _adjustRange(
  CalendarDescriptionStyleRange range,
  int changeStart,
  int oldChangeEnd,
  int delta,
  int newLength,
) {
  var start = range.start;
  var end = range.end;
  if (end <= changeStart) {
    return range;
  }
  if (start >= oldChangeEnd) {
    start += delta;
    end += delta;
  } else {
    end += delta;
    if (start > changeStart) {
      start = changeStart;
    }
  }
  start = start.clamp(0, newLength);
  end = end.clamp(0, newLength);
  if (start >= end) {
    return null;
  }
  return range.copyWith(start: start, end: end);
}

List<CalendarDescriptionStyleRange> _removeStyle(
  CalendarDescriptionStyleRange range,
  int start,
  int end,
  CalendarDescriptionInlineStyle style,
) {
  if (!range.styles.contains(style) ||
      range.end <= start ||
      range.start >= end) {
    return [range];
  }
  final remaining = Set<CalendarDescriptionInlineStyle>.of(range.styles)
    ..remove(style);
  final result = <CalendarDescriptionStyleRange>[];
  if (range.start < start) {
    result.add(range.copyWith(end: start));
  }
  if (remaining.isNotEmpty) {
    result.add(
      CalendarDescriptionStyleRange(
        start: range.start < start ? start : range.start,
        end: range.end > end ? end : range.end,
        styles: remaining,
      ),
    );
  }
  if (range.end > end) {
    result.add(range.copyWith(start: end));
  }
  return result;
}

List<CalendarDescriptionStyleRange> _mergeControllerRanges(
  List<CalendarDescriptionStyleRange> ranges,
) {
  final sorted =
      [
        for (final range in ranges)
          if (range.start < range.end) range,
      ]..sort((a, b) {
        final start = a.start.compareTo(b.start);
        return start == 0 ? a.end.compareTo(b.end) : start;
      });
  final merged = <CalendarDescriptionStyleRange>[];
  for (final range in sorted) {
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null &&
        previous.end == range.start &&
        previous.styles.length == range.styles.length &&
        previous.styles.containsAll(range.styles)) {
      merged[merged.length - 1] = previous.copyWith(end: range.end);
    } else {
      merged.add(range);
    }
  }
  return merged;
}

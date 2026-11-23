import 'package:flutter/material.dart';

import '../../../calendar_providers/calendar_description.dart';

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

/// Owns the editable text and emits content changes without treating selection
/// and IME composition changes as event mutations.
final class EventDescriptionBinding {
  EventDescriptionBinding({
    required this.richText,
    required String? text,
    required String? contentType,
    required String? html,
    required ValueChanged<EventDescriptionValue> onChanged,
  }) : _onChanged = onChanged,
       controller = RichDescriptionController(
         richText && isHtmlContentType(contentType)
             ? htmlCalendarDescriptionDocument(html ?? '')
             : CalendarDescriptionDocument(text: text ?? '', ranges: const []),
       ) {
    _lastText = controller.text;
    _lastHtml = _html;
    controller.addListener(_emitChanged);
  }

  final bool richText;
  final RichDescriptionController controller;
  final ValueChanged<EventDescriptionValue> _onChanged;
  late String _lastText;
  String? _lastHtml;
  bool _notifying = false;

  String? get _html => richText
      ? calendarDescriptionToHtml(controller.text, controller.ranges)
      : null;

  void _emitChanged() {
    if (_notifying) return;
    final text = controller.text;
    final html = _html;
    if (text == _lastText && html == _lastHtml) return;
    _lastText = text;
    _lastHtml = html;
    _notifying = true;
    try {
      _onChanged(
        EventDescriptionValue(
          text: text,
          contentType: richText ? 'html' : null,
          html: html,
        ),
      );
    } finally {
      _notifying = false;
    }
  }

  void dispose() => controller.dispose();
}

class RichDescriptionController extends TextEditingController {
  RichDescriptionController(CalendarDescriptionDocument document)
    : _ranges = List<CalendarDescriptionStyleRange>.of(document.ranges),
      _previousText = document.text,
      super(text: document.text);

  List<CalendarDescriptionStyleRange> _ranges;
  String _previousText;

  List<CalendarDescriptionStyleRange> get ranges => List.unmodifiable(_ranges);

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    if (oldText != newValue.text) {
      _ranges = _adjustRanges(_ranges, _previousText, newValue.text);
    }
    _previousText = newValue.text;
    super.value = newValue;
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

enum CalendarDescriptionInlineStyle { bold, italic, underline }

class CalendarDescriptionStyleRange {
  const CalendarDescriptionStyleRange({
    required this.start,
    required this.end,
    required this.styles,
  });

  final int start;
  final int end;
  final Set<CalendarDescriptionInlineStyle> styles;

  CalendarDescriptionStyleRange copyWith({
    int? start,
    int? end,
    Set<CalendarDescriptionInlineStyle>? styles,
  }) {
    return CalendarDescriptionStyleRange(
      start: start ?? this.start,
      end: end ?? this.end,
      styles: styles ?? this.styles,
    );
  }
}

class CalendarDescriptionDocument {
  const CalendarDescriptionDocument({required this.text, required this.ranges});

  final String text;
  final List<CalendarDescriptionStyleRange> ranges;
}

CalendarDescriptionDocument calendarDescriptionDocumentFromBody({
  String? content,
  String? contentType,
}) {
  if (_isHtmlContentType(contentType)) {
    return htmlCalendarDescriptionDocument(content ?? '');
  }
  return CalendarDescriptionDocument(text: content ?? '', ranges: const []);
}

CalendarDescriptionDocument htmlCalendarDescriptionDocument(String html) {
  final withoutHidden = html
      .replaceAll(RegExp(r'<head\b[^>]*>.*?</head>', dotAll: true), '')
      .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true), '')
      .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true), '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final buffer = StringBuffer();
  final ranges = <CalendarDescriptionStyleRange>[];
  var bold = 0;
  var italic = 0;
  var underline = 0;

  void appendNewline() {
    final text = buffer.toString();
    if (text.endsWith('\n\n')) {
      return;
    }
    if (text.endsWith('\n')) {
      buffer.write('\n');
      return;
    }
    if (text.isNotEmpty) {
      buffer.write('\n');
    }
  }

  void appendText(String value) {
    final decoded = decodeHtmlEntities(value);
    if (decoded.isEmpty) {
      return;
    }
    final start = buffer.length;
    buffer.write(decoded);
    final styles = <CalendarDescriptionInlineStyle>{
      if (bold > 0) CalendarDescriptionInlineStyle.bold,
      if (italic > 0) CalendarDescriptionInlineStyle.italic,
      if (underline > 0) CalendarDescriptionInlineStyle.underline,
    };
    if (styles.isNotEmpty && buffer.length > start) {
      ranges.add(
        CalendarDescriptionStyleRange(
          start: start,
          end: buffer.length,
          styles: styles,
        ),
      );
    }
  }

  final tokenPattern = RegExp(r'<[^>]+>|[^<]+', multiLine: true, dotAll: true);
  for (final match in tokenPattern.allMatches(withoutHidden)) {
    final token = match.group(0) ?? '';
    if (token.startsWith('<')) {
      final tag = _tagName(token);
      final closing = RegExp(r'^</').hasMatch(token);
      final selfClosing = token.endsWith('/>');
      switch (tag) {
        case 'br':
          appendNewline();
        case 'p':
        case 'div':
        case 'tr':
          appendNewline();
        case 'li':
          appendNewline();
          if (!closing) {
            appendText('• ');
          }
        case 'b':
        case 'strong':
          if (closing) {
            bold = bold > 0 ? bold - 1 : 0;
          } else if (!selfClosing) {
            bold += 1;
          }
        case 'i':
        case 'em':
          if (closing) {
            italic = italic > 0 ? italic - 1 : 0;
          } else if (!selfClosing) {
            italic += 1;
          }
        case 'u':
          if (closing) {
            underline = underline > 0 ? underline - 1 : 0;
          } else if (!selfClosing) {
            underline += 1;
          }
      }
      continue;
    }
    appendText(token);
  }

  return _trimDocument(
    CalendarDescriptionDocument(
      text: buffer
          .toString()
          .replaceAll(RegExp(r'[ \t\f\r]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n'),
      ranges: _mergeRanges(ranges),
    ),
  );
}

String htmlCalendarDescriptionToPlainText(String html) {
  return htmlCalendarDescriptionDocument(html).text;
}

String calendarDescriptionToHtml(
  String text,
  List<CalendarDescriptionStyleRange> ranges,
) {
  if (text.isEmpty) {
    return '';
  }
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
  final buffer = StringBuffer();
  for (var index = 0; index < sorted.length - 1; index += 1) {
    final start = sorted[index];
    final end = sorted[index + 1];
    final segment = text.substring(start, end);
    if (segment.isEmpty) {
      continue;
    }
    final styles = <CalendarDescriptionInlineStyle>{};
    for (final range in ranges) {
      if (range.start <= start && range.end >= end) {
        styles.addAll(range.styles);
      }
    }
    var escaped = escapeHtml(segment).replaceAll('\n', '<br>');
    if (styles.contains(CalendarDescriptionInlineStyle.underline)) {
      escaped = '<u>$escaped</u>';
    }
    if (styles.contains(CalendarDescriptionInlineStyle.italic)) {
      escaped = '<em>$escaped</em>';
    }
    if (styles.contains(CalendarDescriptionInlineStyle.bold)) {
      escaped = '<strong>$escaped</strong>';
    }
    buffer.write(escaped);
  }
  return '<div>${buffer.toString()}</div>';
}

String escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String decodeHtmlEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#160;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final codePoint = int.tryParse(match.group(1)!, radix: 16);
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      })
      .replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
        final codePoint = int.tryParse(match.group(1)!);
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      });
}

bool isHtmlContentType(String? value) => _isHtmlContentType(value);

bool _isHtmlContentType(String? value) => value?.toLowerCase() == 'html';

String _tagName(String token) {
  final match = RegExp(r'^</?\s*([a-zA-Z0-9]+)').firstMatch(token);
  return match?.group(1)?.toLowerCase() ?? '';
}

CalendarDescriptionDocument _trimDocument(
  CalendarDescriptionDocument document,
) {
  final text = document.text;
  final leading = text.length - text.trimLeft().length;
  final trailing = text.trimRight().length;
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const CalendarDescriptionDocument(text: '', ranges: []);
  }
  return CalendarDescriptionDocument(
    text: trimmed,
    ranges: [
      for (final range in document.ranges)
        if (range.end > leading && range.start < trailing)
          range.copyWith(
            start: (range.start - leading).clamp(0, trimmed.length),
            end: (range.end - leading).clamp(0, trimmed.length),
          ),
    ],
  );
}

List<CalendarDescriptionStyleRange> _mergeRanges(
  List<CalendarDescriptionStyleRange> ranges,
) {
  if (ranges.isEmpty) {
    return const [];
  }
  final merged = <CalendarDescriptionStyleRange>[];
  for (final range in ranges) {
    if (range.start >= range.end) {
      continue;
    }
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

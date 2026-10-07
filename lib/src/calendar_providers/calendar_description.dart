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

  final tokenPattern = RegExp(
    r'</?[a-zA-Z][^>]*>|[^<]+|<',
    multiLine: true,
    dotAll: true,
  );
  for (final match in tokenPattern.allMatches(withoutHidden)) {
    final token = match.group(0) ?? '';
    if (token.startsWith('<') && token.length > 1) {
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

/// The exact provider-owned subtree and the separately editable remainder.
/// If the subtree is ambiguous, callers must refuse the body mutation.
final class MicrosoftMeetingBodyParts {
  const MicrosoftMeetingBodyParts({
    required this.editableHtml,
    required this.meetingHtml,
    this.documentPrefix = '',
    this.documentSuffix = '',
  });

  final String editableHtml;
  final String meetingHtml;
  final String documentPrefix;
  final String documentSuffix;
}

final class MicrosoftMeetingBodyEditUnsafe implements Exception {
  const MicrosoftMeetingBodyEditUnsafe();

  @override
  String toString() =>
      'The online meeting information could not be safely separated from the description.';
}

MicrosoftMeetingBodyParts splitMicrosoftMeetingBodyHtml({
  required String originalHtml,
  required String? meetingUrl,
}) {
  if (meetingUrl == null || meetingUrl.isEmpty || originalHtml.isEmpty) {
    return MicrosoftMeetingBodyParts(
      editableHtml: originalHtml,
      meetingHtml: '',
    );
  }
  final offset = _meetingLinkOffset(originalHtml, meetingUrl);
  if (offset == null) {
    throw const FormatException(
      'The online meeting block could not be identified.',
    );
  }
  final blocks = _balancedHtmlBlocks(originalHtml);
  if (blocks == null) {
    throw const FormatException('The online meeting HTML is not balanced.');
  }
  final containing = blocks
      .where(
        (block) =>
            block.start <= offset &&
            block.end >= offset &&
            const {'div', 'p', 'section', 'table'}.contains(block.tag),
      )
      .toList();
  final marked = containing
      .where(
        (block) => RegExp(
          r'(?:teams|meeting|online)',
          caseSensitive: false,
        ).hasMatch(originalHtml.substring(block.start, block.openEnd)),
      )
      .toList();
  final _HtmlBlock block;
  if (marked.isNotEmpty) {
    marked.sort((a, b) => a.start.compareTo(b.start));
    block = marked.first;
  } else if (containing.length == 1) {
    block = containing.single;
  } else {
    // Nested unmarked containers may mix provider details and authored text.
    throw const FormatException('The online meeting block is ambiguous.');
  }
  final meetingHtml = originalHtml.substring(block.start, block.end);
  final bodies = blocks
      .where(
        (candidate) =>
            candidate.tag == 'body' &&
            candidate.openEnd <= block.start &&
            candidate.closeStart >= block.end,
      )
      .toList();
  final body = bodies.length == 1 ? bodies.single : null;
  if (bodies.length > 1) {
    throw const FormatException('The online meeting document is ambiguous.');
  }
  final contentStart = body?.openEnd ?? 0;
  final contentEnd = body?.closeStart ?? originalHtml.length;
  return MicrosoftMeetingBodyParts(
    editableHtml: originalHtml
        .substring(contentStart, contentEnd)
        .replaceRange(block.start - contentStart, block.end - contentStart, ''),
    meetingHtml: meetingHtml,
    documentPrefix: body == null ? '' : originalHtml.substring(0, contentStart),
    documentSuffix: body == null ? '' : originalHtml.substring(contentEnd),
  );
}

/// Carries the exact online-meeting subtree through a user-body edit. Never
/// append an arbitrary suffix: it may contain stale user-authored content.
String preserveMicrosoftMeetingBodyHtml({
  required String editedHtml,
  required String originalHtml,
  required String? meetingUrl,
}) {
  final parts = splitMicrosoftMeetingBodyHtml(
    originalHtml: originalHtml,
    meetingUrl: meetingUrl,
  );
  if (parts.meetingHtml.isNotEmpty &&
      (editedHtml.contains(meetingUrl!) ||
          editedHtml.contains(escapeHtml(meetingUrl)))) {
    throw const FormatException(
      'The edited body still contains the online meeting block.',
    );
  }
  return '${parts.documentPrefix}$editedHtml${parts.meetingHtml}'
      '${parts.documentSuffix}';
}

final class _HtmlBlock {
  _HtmlBlock(this.tag, this.start, this.openEnd);
  final String tag;
  final int start;
  final int openEnd;
  int end = -1;
  int closeStart = -1;
}

List<_HtmlBlock>? _balancedHtmlBlocks(String html) {
  final blocks = <_HtmlBlock>[];
  final stack = <_HtmlBlock>[];
  final pattern = RegExp(
    r'<(/?)([A-Za-z][A-Za-z0-9:-]*)\b[^>]*>',
    dotAll: true,
  );
  const voidTags = {'br', 'hr', 'img', 'meta', 'link', 'input', 'wbr'};
  for (final match in pattern.allMatches(html)) {
    final tag = match.group(2)!.toLowerCase();
    if (match.group(1) == '/') {
      if (stack.isEmpty || stack.last.tag != tag) return null;
      final block = stack.removeLast();
      block.closeStart = match.start;
      block.end = match.end;
    } else if (!voidTags.contains(tag) && !match.group(0)!.endsWith('/>')) {
      final block = _HtmlBlock(tag, match.start, match.end);
      blocks.add(block);
      stack.add(block);
    }
  }
  return stack.isEmpty ? blocks : null;
}

int? _meetingLinkOffset(String html, String meetingUrl) {
  final direct = html.indexOf(meetingUrl);
  if (direct >= 0) return direct;
  final escaped = html.indexOf(escapeHtml(meetingUrl));
  if (escaped >= 0) return escaped;
  final anchor = RegExp(r'<a\b[^>]*>', caseSensitive: false, dotAll: true);
  final href = RegExp(
    r'''\bhref\s*=\s*(["'])(.*?)\1''',
    caseSensitive: false,
    dotAll: true,
  );
  for (final match in anchor.allMatches(html)) {
    final encoded = href.firstMatch(match.group(0)!)?.group(2);
    if (encoded == null) continue;
    final decoded = decodeHtmlEntities(encoded);
    if (decoded == meetingUrl) return match.start;
    try {
      if (Uri.decodeComponent(decoded) == meetingUrl) return match.start;
    } on FormatException {
      // A malformed href is not evidence of the provider-owned block.
    }
  }
  return null;
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
  // Decode once: &amp;lt; represents the literal text &lt;, not a new tag.
  return value.replaceAllMapped(
    RegExp(r'&(?:#([xX][0-9a-fA-F]+|[0-9]+)|(nbsp|amp|lt|gt|quot|apos));'),
    (match) {
      final numeric = match.group(1);
      if (numeric != null) {
        final hex = numeric.startsWith(RegExp('[xX]'));
        final codePoint = int.tryParse(
          hex ? numeric.substring(1) : numeric,
          radix: hex ? 16 : 10,
        );
        // Invalid numeric references (including overflow, NUL and surrogates)
        // have a visible replacement instead of throwing during projection.
        if (codePoint == null ||
            codePoint <= 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
          return '\uFFFD';
        }
        return codePoint == 160 ? ' ' : String.fromCharCode(codePoint);
      }
      return switch (match.group(2)) {
        'nbsp' => ' ',
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        _ => match.group(0)!,
      };
    },
  );
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

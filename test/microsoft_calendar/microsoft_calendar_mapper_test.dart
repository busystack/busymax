import 'package:busymax/src/calendar_providers/calendar_description.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Microsoft calendar source uses explicit hex color when available', () {
    final source = microsoftCalendarSourceFromJson({
      'id': 'cal-1',
      'name': 'Calendar',
      'canEdit': true,
      'hexColor': '#123456',
      'color': 'lightBlue',
    });

    expect(source.backgroundColor, '#123456');
    expect(source.colorId, 'lightBlue');
  });

  test(
    'Microsoft calendar source maps named colors when hex color is empty',
    () {
      final source = microsoftCalendarSourceFromJson({
        'id': 'cal-1',
        'name': 'Calendar',
        'canEdit': true,
        'hexColor': '',
        'color': 'lightTeal',
      });

      expect(source.backgroundColor, '#008575');
      expect(source.colorId, 'lightTeal');
    },
  );

  test('Exchange wrapper HTML becomes empty user-facing description', () {
    const html = '''
<html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="Generator" content="Microsoft Exchange Server">
<!-- converted from text -->
<style><!-- .EmailQuote { margin-left: 1pt; padding-left: 4pt; border-left: #800000 2px solid; } --></style></head>
<body>
<font size="2"><span style="font-size:11pt;"><div class="PlainText">&nbsp;</div></span></font>
</body>
</html>''';

    final event = microsoftCalendarEventFromJson('cal-1', {
      'id': 'event-1',
      'subject': 'Planning',
      'isAllDay': false,
      'body': {'contentType': 'html', 'content': html},
      'start': {'dateTime': '2026-06-10T09:00:00', 'timeZone': 'UTC'},
      'end': {'dateTime': '2026-06-10T10:00:00', 'timeZone': 'UTC'},
    });

    expect(event.description, isEmpty);
    expect(event.rawJson['body'], {'contentType': 'html', 'content': html});
  });

  test('formatted Microsoft HTML is converted to plain text with ranges', () {
    final document = htmlCalendarDescriptionDocument(
      '<div>Hello <strong>bold</strong> and <em>italic</em></div>',
    );

    expect(document.text, 'Hello bold and italic');
    expect(
      document.ranges.any(
        (range) =>
            document.text.substring(range.start, range.end) == 'bold' &&
            range.styles.contains(CalendarDescriptionInlineStyle.bold),
      ),
      isTrue,
    );
    expect(
      document.ranges.any(
        (range) =>
            document.text.substring(range.start, range.end) == 'italic' &&
            range.styles.contains(CalendarDescriptionInlineStyle.italic),
      ),
      isTrue,
    );
  });

  test('Microsoft event mutation preserves HTML body content type', () {
    final body = microsoftEventMutationToJson(
      const CalendarEventMutation(
        title: 'Planning',
        description: 'Hello bold',
        descriptionContentType: 'html',
        descriptionHtml: '<div>Hello <strong>bold</strong></div>',
      ),
    );

    expect(body['body'], {
      'contentType': 'html',
      'content': '<div>Hello <strong>bold</strong></div>',
    });
  });
}

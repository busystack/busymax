import 'package:busymax/src/calendar_providers/calendar_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'numeric entities preserve valid Unicode and replace invalid scalars',
    () {
      expect(
        htmlCalendarDescriptionToPlainText(
          '<p>&#x1F4C5; &#128197; &#x110000; &#1114112; &#xD800; &#0; '
          '&#xFFFFFFFFFFFFFFFFFFFFFFFFFFFF; &#9999999999999999999999999;</p>',
        ),
        '📅 📅 � � � � � �',
      );
    },
  );

  test(
    'decoding entities once preserves literal entity text and malformed input',
    () {
      expect(
        htmlCalendarDescriptionToPlainText(
          '<p>&amp;lt; &#xnope; 2 < 3 & 4</p>',
        ),
        '&lt; &#xnope; 2 < 3 & 4',
      );
    },
  );

  test(
    'meeting footer preservation replaces user text but retains provider link',
    () {
      const original =
          '<p>Old agenda</p><div><a href="https://teams.microsoft.com/l/meetup-join/example">Join Microsoft Teams meeting</a></div>';
      final edited = preserveMicrosoftMeetingBodyHtml(
        editedHtml: '<div>New agenda</div>',
        originalHtml: original,
        meetingUrl: 'https://teams.microsoft.com/l/meetup-join/example',
      );
      expect(edited, contains('New agenda'));
      expect(edited, isNot(contains('Old agenda')));
      expect(edited, contains('Join Microsoft Teams meeting'));
      expect(
        edited,
        contains('https://teams.microsoft.com/l/meetup-join/example'),
      );
    },
  );
}

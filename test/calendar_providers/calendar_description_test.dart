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

  test(
    'nested meeting block is preserved without stale trailing user text',
    () {
      const block =
          '<div class="teams-meeting"><div class="join">'
          '<a href="https://teams.microsoft.com/l/meetup-join/example">Join</a>'
          '</div><div>Meeting ID: 123</div></div>';
      const original = '<p>Old before</p>$block<p>Old after</p>';
      final edited = preserveMicrosoftMeetingBodyHtml(
        editedHtml: '<p>New before</p><p>New after</p>',
        originalHtml: original,
        meetingUrl: 'https://teams.microsoft.com/l/meetup-join/example',
      );
      expect(edited, contains(block));
      expect(edited, contains('New before'));
      expect(edited, contains('New after'));
      expect(edited, isNot(contains('Old before')));
      expect(edited, isNot(contains('Old after')));
      expect('Meeting ID: 123'.allMatches(edited), hasLength(1));
    },
  );

  test('unmatched meeting link rejects unsafe body replacement', () {
    expect(
      () => preserveMicrosoftMeetingBodyHtml(
        editedHtml: '<p>New agenda</p>',
        originalHtml: '<p>Old agenda</p><div>Meeting ID: 123</div>',
        meetingUrl: 'https://teams.microsoft.com/l/meetup-join/example',
      ),
      throwsFormatException,
    );
  });

  test('document shell and meeting subtree survive repeated edits once', () {
    const meetingUrl = 'https://teams.microsoft.com/l/meetup-join/example';
    const meeting =
        '<div class="teams-meeting"><div class="join">'
        '<a href="https://teams.microsoft.com/l/meetup-join/example">Join</a>'
        '</div><p>Meeting ID: 123</p></div>';
    const original =
        '<html><head><meta charset="utf-8"></head><body>'
        '<p>Old before</p>$meeting<p>Old after</p></body></html>';
    final first = preserveMicrosoftMeetingBodyHtml(
      editedHtml: '<p>First</p>',
      originalHtml: original,
      meetingUrl: meetingUrl,
    );
    expect(
      first,
      startsWith('<html><head><meta charset="utf-8"></head><body>'),
    );
    expect(first, endsWith('</body></html>'));
    expect(meeting.allMatches(first), hasLength(1));
    expect(first, isNot(contains('Old before')));
    expect(first, isNot(contains('Old after')));
    final parts = splitMicrosoftMeetingBodyHtml(
      originalHtml: first,
      meetingUrl: meetingUrl,
    );
    expect(parts.editableHtml, '<p>First</p>');
    final second = preserveMicrosoftMeetingBodyHtml(
      editedHtml: '<p>Second</p>',
      originalHtml: first,
      meetingUrl: meetingUrl,
    );
    expect(meeting.allMatches(second), hasLength(1));
    expect(second, isNot(contains('First')));
    expect(second, contains('Second'));
  });

  test('encoded meeting URL identifies the complete provider fragment', () {
    const meetingUrl = 'https://teams.microsoft.com/l/meetup-join/a?x=1&y=2';
    const original =
        '<p>Old</p><div class="online-meeting"><a href="https://teams.microsoft.com/l/meetup-join/a?x=1&amp;y=2">Join</a><p>Dial-in</p></div>';
    final edited = preserveMicrosoftMeetingBodyHtml(
      editedHtml: '<p>New</p>',
      originalHtml: original,
      meetingUrl: meetingUrl,
    );
    expect(edited, contains('Dial-in'));
    expect(edited, isNot(contains('Old')));
    expect('Join'.allMatches(edited), hasLength(1));
  });
}

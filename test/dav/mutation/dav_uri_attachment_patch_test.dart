import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_projection_mutations.dart';
import 'package:flutter_test/flutter_test.dart';

const _resource =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'BEGIN:VTIMEZONE\r\n'
    'TZID:America/Vancouver\r\n'
    'X-TZ-UNKNOWN:keep\r\n'
    'END:VTIMEZONE\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:series@example.com\r\n'
    'DTSTART;TZID=America/Vancouver:20260608T090000\r\n'
    'DTEND;TZID=America/Vancouver:20260608T100000\r\n'
    'SUMMARY:Meeting\r\n'
    'X-CUSTOM;X-PARAM="a,b":untouched\r\n'
    'ATTACH;VALUE=BINARY;ENCODING=BASE64:YWJj\r\n'
    'X-GROUP.ATTACH;FMTTYPE=application/pdf:https://files.example/old.pdf\r\n'
    'BEGIN:VALARM\r\n'
    'ACTION:DISPLAY\r\n'
    'TRIGGER:-PT15M\r\n'
    'END:VALARM\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:series@example.com\r\n'
    'RECURRENCE-ID;TZID=America/Vancouver:20260609T090000\r\n'
    'DTSTART;TZID=America/Vancouver:20260609T110000\r\n'
    'DTEND;TZID=America/Vancouver:20260609T120000\r\n'
    'SUMMARY:Moved meeting\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR\r\n';

void main() {
  const target = IcalComponentKey(
    componentType: 'VEVENT',
    uid: 'series@example.com',
  );

  test('URI addition preserves binary, grouped and unrelated DAV content', () {
    final patch = buildDavUriAttachmentPatch(
      baselineRawIcs: _resource,
      target: target,
      addUrl: 'https://files.example/new.pdf',
    )!;
    final candidate = patch.applyTo(
      _resource,
      nowUtc: DateTime.utc(2026, 6, 8),
    );
    expect(candidate, contains('ATTACH;VALUE=BINARY;ENCODING=BASE64:YWJj'));
    expect(
      candidate,
      contains(
        'X-GROUP.ATTACH;FMTTYPE=application/pdf:https://files.example/old.pdf',
      ),
    );
    expect(candidate, contains('X-CUSTOM;X-PARAM="a,b":untouched'));
    expect(candidate, contains('X-TZ-UNKNOWN:keep'));
    expect(candidate, contains('RECURRENCE-ID;TZID=America/Vancouver'));
    expect(
      candidate,
      contains('ATTACH;VALUE=URI:https://files.example/new.pdf'),
    );
  });

  test('URI removal leaves binary attachment and other resources intact', () {
    final patch = buildDavUriAttachmentPatch(
      baselineRawIcs: _resource,
      target: target,
      removeUrl: 'https://files.example/old.pdf',
    )!;
    final candidate = patch.applyTo(
      _resource,
      nowUtc: DateTime.utc(2026, 6, 8),
    );
    expect(candidate, isNot(contains('https://files.example/old.pdf')));
    expect(candidate, contains('ATTACH;VALUE=BINARY;ENCODING=BASE64:YWJj'));
    expect(candidate, contains('BEGIN:VALARM'));
    expect(candidate, contains('X-TZ-UNKNOWN:keep'));
  });

  test('URI mutation does not rewrite unchanged or unsupported references', () {
    expect(
      buildDavUriAttachmentPatch(
        baselineRawIcs: _resource,
        target: target,
        addUrl: 'https://files.example/old.pdf',
      ),
      isNull,
    );
    expect(
      buildDavUriAttachmentPatch(
        baselineRawIcs: _resource,
        target: target,
        removeUrl: 'https://files.example/missing.pdf',
      ),
      isNull,
    );
    expect(
      () => buildDavUriAttachmentPatch(
        baselineRawIcs: _resource,
        target: target,
        addUrl: 'http://files.example/insecure.pdf',
      ),
      throwsFormatException,
    );
  });
}

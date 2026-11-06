import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DAV writes supply one complete definition for repeated IANA references',
    () {
      const raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\n'
          'BEGIN:VEVENT\r\nUID:dst\r\nDTSTAMP:20261102T000000Z\r\n'
          'DTSTART;TZID=America/Vancouver:20270314T090000\r\n'
          'DTEND;TZID=America/Vancouver:20270314T100000\r\n'
          'RRULE:FREQ=YEARLY\r\nX-OPAQUE;X-PARAM=exact:unchanged\r\n'
          'END:VEVENT\r\nEND:VCALENDAR\r\n';
      final completed = completeIcalTimeZones(raw);
      final zones = IcalDocument.parse(completed).root
          .componentsNamed('VTIMEZONE');
      expect(zones, hasLength(1));
      final zone = zones.single;
      expect(zone.firstProperty('TZID')!.rawValue, 'America/Vancouver');
      expect(zone.componentsNamed('DAYLIGHT'), isNotEmpty);
      expect(zone.componentsNamed('STANDARD'), isNotEmpty);
      expect(completed, contains('RRULE:FREQ=YEARLY'));
      expect(completed, contains('X-OPAQUE;X-PARAM=exact:unchanged'));
      expect(completeIcalTimeZones(completed), completed);
    },
  );

  test(
    'embedded custom definitions and UTC/floating/date values stay byte exact',
    () {
      for (final start in [
        'DTSTART:20270314T090000Z',
        'DTSTART:20270314T090000',
        'DTSTART;VALUE=DATE:20270314',
      ]) {
        final raw =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n'
            'UID:plain\r\n$start\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
        expect(completeIcalTimeZones(raw), raw);
      }
      const custom =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'
          'BEGIN:VTIMEZONE\r\nTZID:Custom/Unregistered\r\n'
          'X-ORIGINAL:keep\r\nBEGIN:STANDARD\r\nDTSTART:19700101T000000\r\n'
          'TZOFFSETFROM:+0330\r\nTZOFFSETTO:+0330\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\n'
          'BEGIN:VTODO\r\nUID:custom\r\nDTSTART;TZID=Custom/Unregistered:20270314T090000\r\n'
          'END:VTODO\r\nEND:VCALENDAR\r\n';
      expect(completeIcalTimeZones(custom), custom);
    },
  );
}

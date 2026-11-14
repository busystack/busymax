import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax/src/dav/ical/ical_attachments.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:flutter_test/flutter_test.dart';

const target = IcalComponentKey(componentType: 'VEVENT', uid: 'attached');

void main() {
  test(
    'multiple binary attachments retain exact bytes, MIME and parameters',
    () {
      final bytes = Uint8List.fromList(List.generate(256, (i) => i));
      final value = base64.encode(bytes);
      final folded = '${value.substring(0, 40)}\r\n ${value.substring(40)}';
      final source = _calendar('''
ATTACH;FMTTYPE=application/octet-stream;VALUE=BINARY;ENCODING=BASE64;X-META="one^nTwo";FILENAME="café.bin":$folded
ATTACH;FMTTYPE=text/plain;VALUE=BINARY;ENCODING=BASE64:AAECAw==
ATTACH:http://files.example.test/a.txt
ATTACH:https://files.example.test/b.txt
''');
      final attachments = readIcalAttachments(source, target);
      expect(attachments, hasLength(4));
      expect(attachments.first.decode(), orderedEquals(bytes));
      expect(attachments[1].decode(), [0, 1, 2, 3]);
      expect(attachments[1].mimeType, 'text/plain');
      expect(attachments.first.suggestedName, 'café.bin');
      expect(attachments.first.parameterValue('X-META'), 'one\nTwo');
      expect(attachments.first.originalPhysicalLines, hasLength(2));
      expect(attachments[2].uri, 'http://files.example.test/a.txt');
      expect(attachments[3].uri, 'https://files.example.test/b.txt');
      expect(IcalDocument.parse(source).serialize(), source);
    },
  );

  test('absent FMTTYPE safely uses octet-stream and empty binary is valid', () {
    final item = readIcalAttachments(
      _calendar('ATTACH;VALUE=BINARY;ENCODING=BASE64:\n'),
      target,
    ).single;
    expect(item.mimeType, 'application/octet-stream');
    expect(item.canSave, isTrue);
    expect(item.decode(), isEmpty);
  });

  for (final value in [
    'A',
    'AA',
    'AAA',
    'AAAA=',
    'A===',
    '====',
    'AA==AAAA',
    'AB==',
    'AAB=',
    '_w==',
    '-w==',
    '%2Fw==',
    'AA A',
    'AA\tA',
    '你好',
    'AAAA\u0000',
  ]) {
    test('rejects malformed/noncanonical binary ${jsonEncode(value)}', () {
      final item = readIcalAttachments(
        _calendar('ATTACH;VALUE=BINARY;ENCODING=BASE64:$value\n'),
        target,
      ).single;
      expect(item.canSave, isFalse);
      expect(item.decode, throwsFormatException);
    });
  }

  for (final parameters in [
    'VALUE=BINARY',
    'VALUE=BINARY;ENCODING=QUOTED-PRINTABLE',
    'VALUE=BINARY;ENCODING=BASE64;ENCODING=BASE64',
    'VALUE=BINARY;VALUE=BINARY;ENCODING=BASE64',
    'VALUE=BINARY;ENCODING=BASE64;FMTTYPE="text/plain^nInjected"',
    'VALUE=BINARY;ENCODING=BASE64;FMTTYPE=text/plain;FMTTYPE=image/png',
  ]) {
    test('invalid binary metadata cannot be saved: $parameters', () {
      final item = readIcalAttachments(
        _calendar('ATTACH;$parameters:AA==\n'),
        target,
      ).single;
      expect(item.canSave, isFalse);
      expect(item.decode, throwsFormatException);
    });
  }

  test('bad attachment does not hide other valid attachments', () {
    final result = readIcalAttachments(
      _calendar('''
ATTACH;VALUE=BINARY;ENCODING=BASE64:not base64
ATTACH;VALUE=BINARY;ENCODING=BASE64:AA==
'''),
      target,
    );
    expect(result.first.canSave, isFalse);
    expect(result.last.decode(), [0]);
  });

  test(
    'inline and HTTP alarm attachments are accessible without alarm execution',
    () {
      final result = readIcalAttachments(
        _calendar('''
BEGIN:VALARM
ACTION:AUDIO
TRIGGER:-PT15M
ATTACH;FMTTYPE=audio/basic;VALUE=BINARY;ENCODING=BASE64:AAM=
END:VALARM
BEGIN:VALARM
ACTION:AUDIO
TRIGGER:-PT5M
ATTACH:https://files.example.test/alarm.au
END:VALARM
'''),
        target,
      );
      expect(result, hasLength(2));
      expect(result.every((item) => item.fromAlarm), isTrue);
      expect(result.first.mimeType, 'audio/basic');
      expect(result.first.decode(), [0, 3]);
      expect(result.last.uri, 'https://files.example.test/alarm.au');
    },
  );

  test('document/count limits reject safely without a partial inventory', () {
    expect(
      () => readIcalAttachments('A' * (maximumIcalAttachmentBytes + 1), target),
      throwsFormatException,
    );
    const attach = 'ATTACH:https://files.example.test/a\n';
    expect(
      readIcalAttachments(_calendar(attach * maximumIcalAttachments), target),
      hasLength(maximumIcalAttachments),
    );
    expect(
      () => readIcalAttachments(
        _calendar(attach * (maximumIcalAttachments + 1)),
        target,
      ),
      throwsFormatException,
    );
  });

  test(
    'detached attachments are selected by identity, with master fallback',
    () {
      final source = _calendar(
        'ATTACH:https://files.example.test/master\n',
        extra: '''
BEGIN:VEVENT
UID:attached
RECURRENCE-ID:20261111T090000
DTSTART:20261111T110000
ATTACH;VALUE=BINARY;ENCODING=BASE64:AQ==
END:VEVENT
BEGIN:VEVENT
UID:attached
RECURRENCE-ID:20261112T090000
DTSTART:20261112T110000
END:VEVENT
''',
      );
      final detached = readIcalAttachments(
        source,
        const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'attached',
          recurrenceIdKey: '20261111T090000',
        ),
      );
      expect(detached.single.decode(), [1]);
      final inherited = readIcalAttachments(
        source,
        const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'attached',
          recurrenceIdKey: '20261112T090000',
        ),
      );
      expect(inherited.single.uri, 'https://files.example.test/master');
      expect(IcalDocument.parse(source).serialize(), source);
    },
  );

  for (final zone in ['', ';TZID=America/Vancouver']) {
    test('THISANDFUTURE uses original occurrence identity ($zone)', () {
      final source = _calendar(
        'ATTACH:https://files.example.test/master\n',
        zone: zone,
        extra:
            '''
BEGIN:VEVENT
UID:attached
RECURRENCE-ID$zone;RANGE=THISANDFUTURE:20261111T090000
DTSTART$zone:20261111T110000
ATTACH:https://files.example.test/future
END:VEVENT
''',
      );
      final prefix = zone.isEmpty ? 'FLOATING:' : 'TZID=America/Vancouver:';
      expect(
        readIcalAttachments(
          source,
          target,
          occurrenceKey: '${prefix}20261110T090000',
        ).single.uri,
        'https://files.example.test/master',
      );
      expect(
        readIcalAttachments(
          source,
          target,
          occurrenceKey: '${prefix}20261112T090000',
        ).single.uri,
        'https://files.example.test/future',
      );
    });
  }

  test(
    'unknown or ambiguous component identities never select another object',
    () {
      final source = _calendar('ATTACH:https://files.example.test/a\n');
      expect(
        () => readIcalAttachments(
          source,
          const IcalComponentKey(componentType: 'VEVENT', uid: 'other'),
        ),
        throwsA(isA<Exception>()),
      );
      final duplicate = source.replaceFirst(
        'END:VCALENDAR',
        '''
BEGIN:VEVENT
UID:attached
DTSTART:20261110T090000
ATTACH:https://files.example.test/other
END:VEVENT
END:VCALENDAR'''
            .replaceAll('\n', '\r\n'),
      );
      expect(
        () => readIcalAttachments(duplicate, target),
        throwsA(isA<Exception>()),
      );
    },
  );
}

String _calendar(String properties, {String extra = '', String zone = ''}) =>
    'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Attachment test//EN\n'
            'BEGIN:VEVENT\nUID:attached\nDTSTAMP:20261110T000000Z\n'
            'DTSTART$zone:20261110T090000\nDTEND$zone:20261110T100000\n'
            '$properties'
            'END:VEVENT\n$extra'
            'END:VCALENDAR\n'
        .replaceAll('\r\n', '\n')
        .replaceAll('\n', '\r\n');

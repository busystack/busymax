import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = DavXmlParser();

  test('matches namespaces, not prefixes, and retains unknown properties', () {
    final result = parser.parseMultistatus(
      _xml('''
      <x:multistatus xmlns:x="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
          xmlns:z="urn:vendor:test">
        <x:response>
          <x:href>/dav/calendars/alex/work/</x:href>
          <x:propstat>
            <x:prop>
              <x:displayname>Work</x:displayname>
              <c:calendar-description>Calendar</c:calendar-description>
              <z:future-property z:flag="yes">opaque</z:future-property>
            </x:prop>
            <x:status>HTTP/1.1 200 OK</x:status>
          </x:propstat>
          <x:propstat>
            <x:prop><c:max-instances/></x:prop>
            <x:status>HTTP/1.1 404 Not Found</x:status>
          </x:propstat>
        </x:response>
        <x:sync-token>opaque-token</x:sync-token>
      </x:multistatus>
    '''),
    );

    expect(result.syncToken, 'opaque-token');
    expect(result.responses, hasLength(1));
    final response = result.responses.single;
    expect(response.propstats, hasLength(2));
    expect(
      response.successfulProperty(davNamespace, 'displayname')?.text,
      'Work',
    );
    final unknown = response.successfulProperty(
      'urn:vendor:test',
      'future-property',
    );
    expect(unknown?.element.attributes.single.name.local, 'flag');
    expect(unknown?.element.attributes.single.value, 'yes');
    expect(response.propstats.last.statusCode, 404);
    expect(
      response.isMissing,
      isFalse,
      reason: 'A 404 for one optional property does not remove the resource.',
    );
  });

  test('resource status 404 is a deletion and conditions are retained', () {
    final result = parser.parseMultistatus(
      _xml('''
      <d:multistatus xmlns:d="DAV:">
        <d:response>
          <d:href>/removed.ics</d:href>
          <d:status>HTTP/1.1 404 Not Found</d:status>
          <d:error><d:valid-sync-token/></d:error>
        </d:response>
      </d:multistatus>
    '''),
    );

    expect(result.responses.single.isMissing, isTrue);
    expect(result.hasCondition(davNamespace, 'valid-sync-token'), isTrue);
  });

  test('rejects DTDs, external entities, and malformed status lines', () {
    expect(
      () => parser.parseMultistatus(
        _xml(
          '<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]>'
          '<d:multistatus xmlns:d="DAV:"/>',
        ),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavXmlDtdForbidden',
        ),
      ),
    );
    expect(
      () => parser.parseMultistatus(
        _xml('''
        <d:multistatus xmlns:d="DAV:"><d:response>
          <d:href>/a</d:href><d:status>200 OK</d:status>
        </d:response></d:multistatus>
      '''),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.kind,
          'kind',
          DavErrorKind.malformedStatus,
        ),
      ),
    );
  });

  test('enforces byte, depth, element, text, and UTF-8 limits', () {
    void expectCode(DavXmlParser limited, Uint8List source, String code) {
      expect(
        () => limited.parseMultistatus(source),
        throwsA(
          isA<DavException>().having((error) => error.code, 'code', code),
        ),
      );
    }

    expectCode(
      const DavXmlParser(limits: DavXmlLimits(maximumBytes: 4)),
      _xml('<d:multistatus xmlns:d="DAV:"/>'),
      'DavXmlResponseTooLarge',
    );
    expectCode(
      const DavXmlParser(limits: DavXmlLimits(maximumDepth: 2)),
      _xml('<d:multistatus xmlns:d="DAV:"><d:a><d:b/></d:a></d:multistatus>'),
      'DavXmlDepthLimitExceeded',
    );
    expectCode(
      const DavXmlParser(limits: DavXmlLimits(maximumElements: 1)),
      _xml('<d:multistatus xmlns:d="DAV:"><d:a/></d:multistatus>'),
      'DavXmlElementLimitExceeded',
    );
    expectCode(
      const DavXmlParser(limits: DavXmlLimits(maximumTextBytes: 3)),
      _xml(
        '<d:multistatus xmlns:d="DAV:"><d:response>text</d:response></d:multistatus>',
      ),
      'DavXmlTextLimitExceeded',
    );
    expectCode(parser, Uint8List.fromList([0xC3, 0x28]), 'DavXmlInvalidUtf8');
  });
}

Uint8List _xml(String source) => Uint8List.fromList(utf8.encode(source));

import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/android/android_local_network_access.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xml/xml.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const provider = String.fromEnvironment('BUSYMAX_JOURNAL_PROVIDER');
  const fixture = String.fromEnvironment('BUSYMAX_JOURNAL_NATIVE_FIXTURE');
  if (!const {'caldav', 'nextcloud'}.contains(provider) || fixture.isEmpty) {
    throw StateError('Configure the private routed LAN journal fixture.');
  }

  testWidgets('Android API 37 routed journal HTTPS on $provider', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    await tester.runAsync(() async {
      final profile = jsonDecode(utf8.decode(base64Decode(fixture))) as Map;
      final origin = Uri.parse(profile['authority'] as String);
      expect(origin.scheme, 'https');
      expect(InternetAddress(origin.host).isLoopback, isFalse);
      final platform = BusyMaxAndroidPlatform.instance;
      expect(await platform.requiresLocalNetworkAccess(origin.host), isTrue);
      expect(await platform.hasLocalNetworkAccess(), isFalse);
      await expectLater(
        requireAndroidDavServerAccess(origin),
        throwsA(isA<AndroidDavLocalNetworkPermissionException>()),
      );
      debugPrint('JOURNAL_LAN_PERMISSION $provider awaiting-system-grant');
      expect(await platform.requestLocalNetworkAccess(), isTrue);
      await requireAndroidDavServerAccess(origin);

      final client = IOClient(
        HttpClient(
          context: SecurityContext(withTrustedRoots: true)
            ..setTrustedCertificatesBytes(utf8.encode(profile['ca'] as String)),
        )..connectionTimeout = const Duration(seconds: 15),
      );
      final authorization = base64Encode(
        utf8.encode('${profile['username']}:${profile['password']}'),
      );
      Future<http.Response> request(
        String method,
        Uri target, {
        String? body,
        Map<String, String> headers = const {},
      }) async {
        expect(target.origin, origin.origin);
        final request = http.Request(method, target)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Basic $authorization',
            ...headers,
          });
        if (body != null) request.body = body;
        return http.Response.fromStream(await client.send(request));
      }

      Future<Uri> discover(Uri target, String name) async {
        final response = await request(
          'PROPFIND',
          target,
          body:
              '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
              '<d:prop><$name/></d:prop></d:propfind>',
          headers: {'Depth': '0', 'Content-Type': 'application/xml'},
        );
        expect(response.statusCode, 207);
        final href = XmlDocument.parse(response.body)
            .findAllElements(
              name.split(':').last,
              namespaceUri: name.startsWith('d:')
                  ? 'DAV:'
                  : 'urn:ietf:params:xml:ns:caldav',
            )
            .single
            .findAllElements('href', namespaceUri: 'DAV:')
            .single
            .innerText;
        return target.resolve(href);
      }

      try {
        final principal = await discover(
          origin.resolve(provider == 'caldav' ? 'dav/' : 'remote.php/dav/'),
          'd:current-user-principal',
        );
        final home = await discover(principal, 'c:calendar-home-set');
        final slug = 'journal-lan-${DateTime.now().microsecondsSinceEpoch}';
        final collection = home.resolve('$slug/');
        expect(
          (await request(
            'MKCALENDAR',
            collection,
            body:
                '<c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
                '<d:set><d:prop><d:displayname>$slug</d:displayname>'
                '<c:supported-calendar-component-set><c:comp name="VJOURNAL"/>'
                '</c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>',
            headers: {'Content-Type': 'application/xml'},
          )).statusCode,
          201,
        );
        final member = collection.resolve('lan.ics');
        final body =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//API 37 LAN QA//EN\r\n'
            'BEGIN:VJOURNAL\r\nUID:$slug\r\nDTSTAMP:20261126T000000Z\r\n'
            'SUMMARY:Android LAN journal\r\nEND:VJOURNAL\r\nEND:VCALENDAR\r\n';
        try {
          expect(
            (await request(
              'PUT',
              member,
              body: body,
              headers: {
                'Content-Type': 'text/calendar; charset=utf-8',
                'If-None-Match': '*',
              },
            )).statusCode,
            201,
          );
          final saved = await request('GET', member);
          expect(saved.statusCode, 200);
          expect(saved.headers['etag'], isNotEmpty);
          expect(saved.body, contains('SUMMARY:Android LAN journal'));
        } finally {
          expect((await request('DELETE', collection)).statusCode, 204);
        }
        debugPrint(
          'JOURNAL_LAN_CASE $provider native-grant-and-dav-smoke PASS',
        );
      } finally {
        client.close();
      }
    });
  });
}

import 'dart:convert';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'nextcloud_admin_fixture.dart';

class SchedulingFixture extends NextcloudAdminFixture {
  String requestStatus = '2.0;Success', messageEtag = '"message-1"';
  bool duplicate = false, acknowledged = false;
  String busyData = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//QA//EN
BEGIN:VFREEBUSY
UID:availability
DTSTART:20260906T090000Z
DTEND:20260906T120000Z
FREEBUSY;FBTYPE=BUSY:20260906T100000Z/20260906T110000Z
END:VFREEBUSY
END:VCALENDAR
''';
  Future<void> seedScheduling() async {
    await seed();
    await seedPolicy();
  }

  Future<void> seedPolicy({
    List<String> privileges = const [
      '{urn:ietf:params:xml:ns:caldav}schedule-send',
    ],
  }) async {
    final home = Uri.parse(
      '${NextcloudAdminFixture.origin}${NextcloudAdminFixture.home}',
    );
    await (database.update(
      database.davAccountServices,
    )..where((r) => r.accountId.equals('account'))).write(
      DavAccountServicesCompanion(
        capabilitiesJson: Value(
          jsonEncode({
            'serverFeatures': ['calendar-auto-schedule'],
            'principalContexts': [
              DavPrincipalContext(
                principalHref: Uri.parse(
                  '${NextcloudAdminFixture.origin}/remote.php/dav/principals/users/alex/',
                ),
                calendarHomeHref: home,
                calendarUserAddresses: [Uri.parse('mailto:alex@example.test')],
                scheduleOutboxHref: home.resolve('outbox/'),
                scheduleInboxHref: home.resolve('inbox/'),
                outboxPrivileges: privileges.toSet(),
              ).toJson(),
            ],
          }),
        ),
      ),
    );
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/outbox/')) {
      requests.add(request);
      final entry =
          '<c:response><c:recipient><d:href>mailto:guest@example.test</d:href></c:recipient>'
          '<c:request-status>$requestStatus</c:request-status><c:calendar-data>${XmlText(busyData).toXmlString()}</c:calendar-data></c:response>';
      return http.Response(
        '<c:schedule-response xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">$entry${duplicate ? entry : ''}</c:schedule-response>',
        200,
      );
    }
    if (request.method == 'PROPFIND' && request.url.path.endsWith('/inbox/')) {
      requests.add(request);
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nMETHOD:REQUEST\r\nBEGIN:VEVENT\r\nUID:same-uid\r\nSUMMARY:Invitation\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
      final message = acknowledged
          ? ''
          : '<d:response><d:href>${NextcloudAdminFixture.home}inbox/server-message.ics</d:href><d:propstat><d:prop>'
                '<d:getetag>${XmlText(messageEtag).toXmlString()}</d:getetag><c:calendar-data>${XmlText(raw).toXmlString()}</c:calendar-data>'
                '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
      return http.Response(
        '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$message</d:multistatus>',
        207,
      );
    }
    if (request.method == 'DELETE' &&
        request.url.path.endsWith('/inbox/server-message.ics')) {
      requests.add(request);
      acknowledged = true;
      return http.Response('', 204);
    }
    return super.respond(request);
  }
}

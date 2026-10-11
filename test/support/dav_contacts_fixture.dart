import 'package:busystack_dav/carddav.dart';
import 'package:http/http.dart' as http;

final server = Uri.parse('https://cloud.example.test/nextcloud/');
String multistatus(String content) =>
    '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">$content</d:multistatus>';
String response(String href, String props) =>
    '<d:response><d:href>${davText(href)}</d:href><d:propstat><d:prop>$props</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
const rawCard =
    'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:uid-one\r\nFN:Zoë 李\r\nN:李;Zoë;;;\r\n'
    'EMAIL;TYPE=HOME:one@example.test\r\nEMAIL;TYPE=WORK:two@example.test\r\nNOTE:Original\r\nX-FUTURE;X-PARAM=opaque:keep\r\nEND:VCARD\r\n';

final class DavFixture {
  final requests = <http.Request>[];
  String card = rawCard, etag = '"one"';
  bool sync = true,
      rejectSync = false,
      conflict = false,
      failConfirmation = false,
      unknownCreate = false;
  int gets = 0, puts = 0;
  bool offline = false;
  Future<http.Response> respond(http.Request request) async {
    if (offline) throw http.ClientException('fixture offline');
    requests.add(request);
    final path = request.url.path;
    http.Response xml(String text) => http.Response(
      multistatus(text),
      207,
      headers: {'content-type': 'application/xml; charset=utf-8'},
    );
    if (request.method == 'OPTIONS') {
      return http.Response(
        '',
        200,
        headers: {
          'allow': 'GET, PUT, DELETE, REPORT, MKCOL, PROPPATCH',
          'dav': '1, 3, extended-mkcol',
        },
      );
    }
    if (request.method == 'MKCOL') return http.Response('', 201);
    if (request.method == 'PROPPATCH') {
      return xml(response(path, '<d:displayname>Renamed</d:displayname>'));
    }
    if (request.method == 'DELETE') return http.Response('', 204);
    if (request.method == 'PUT') {
      puts++;
      if (conflict) return http.Response('', 412);
      card = request.body;
      etag = '"new"';
      if (unknownCreate) {
        throw const FormatException('Response interrupted after remote write');
      }
      return http.Response('', 201);
    }
    if (request.method == 'GET') {
      gets++;
      if (failConfirmation) return http.Response('', 503);
      return http.Response(
        card,
        200,
        headers: {'etag': etag, 'content-type': 'text/vcard; charset=utf-8'},
      );
    }
    if (request.method == 'REPORT') {
      if (request.body.contains('sync-collection')) {
        if (rejectSync) return http.Response('', 405);
        return xml(
          '${response('/nextcloud/books/u/book/one.vcf', '<d:getetag>${davText(etag)}</d:getetag>')}<d:sync-token>cursor-one</d:sync-token>',
        );
      }
      return xml(
        response(
          '/nextcloud/books/u/book/one.vcf',
          '<d:getetag>${davText(etag)}</d:getetag><c:address-data>${davText(card)}</c:address-data>',
        ),
      );
    }
    if (path == '/.well-known/carddav') {
      return http.Response('', 301, headers: {'location': '/nextcloud/dav/'});
    }
    if (path == '/nextcloud/dav/') {
      return xml(
        response(
          path,
          '<d:current-user-principal><d:href>/nextcloud/principals/u/</d:href></d:current-user-principal>',
        ),
      );
    }
    if (path == '/nextcloud/principals/u/') {
      return xml(
        response(
          path,
          '<c:addressbook-home-set><d:href>/nextcloud/books/u/</d:href></c:addressbook-home-set>',
        ),
      );
    }
    if (path == '/nextcloud/books/u/') {
      return xml(
        response(
              path,
              '<d:current-user-privilege-set><d:privilege><d:bind/></d:privilege><d:privilege><d:unbind/></d:privilege></d:current-user-privilege-set>',
            ) +
            response(
              '${path}book/',
              '<d:displayname>Personal</d:displayname><d:resourcetype><d:collection/><c:addressbook/></d:resourcetype><d:current-user-privilege-set><d:privilege><d:read/></d:privilege><d:privilege><d:write/></d:privilege></d:current-user-privilege-set>${sync ? '<d:supported-report-set><d:supported-report><d:report><d:sync-collection/></d:report></d:supported-report></d:supported-report-set>' : ''}<c:supported-address-data><c:address-data-type content-type="text/vcard" version="3.0"/><c:address-data-type content-type="text/vcard" version="4.0"/></c:supported-address-data>',
            ) +
            response(
              '${path}readonly/',
              '<d:displayname>Read only</d:displayname><d:resourcetype><d:collection/><c:addressbook/></d:resourcetype>'
                  '<d:current-user-privilege-set><d:privilege><d:read/></d:privilege></d:current-user-privilege-set>',
            ),
      );
    }
    return xml(
      response(
            path,
            '<d:resourcetype><d:collection/><c:addressbook/></d:resourcetype>',
          ) +
          response('${path}one.vcf', '<d:getetag>${davText(etag)}</d:getetag>'),
    );
  }
}

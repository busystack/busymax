import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sync-collection uses RFC 6578 Depth: 0', () async {
    final authority = Uri.parse('https://cloud.example.test/nextcloud');
    final client = MockClient((request) async {
      // Model a strict RFC 6578 server: sync-level controls member depth and
      // an HTTP Depth value other than zero is rejected.
      if (request.headers['depth'] != '0') {
        return http.Response('', 400);
      }
      expect(request.method, 'REPORT');
      expect(request.body, contains('<d:sync-level>1</d:sync-level>'));
      return http.Response(
        '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"><d:sync-token>next-token</d:sync-token></d:multistatus>''',
        207,
        headers: const {'content-type': 'application/xml'},
      );
    });
    addTearDown(client.close);
    final profile = davProviderProfile(
      BusyProvider.nextcloud,
      nextcloudServer: authority,
    );
    final remote = DavCollectionHttpClient(
      transport: DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: authority,
        delay: (_) async {},
      ),
      profile: profile,
      accountAuthority: authority,
      accountId: 'account',
      collectionId: 'collection',
      collectionUri: Uri.parse(
        'https://cloud.example.test/nextcloud/remote.php/dav/calendars/alex/work/',
      ),
      credential: DavBasicCredential(username: 'alex', password: 'secret'),
    );

    final page = await remote.syncCollectionPage(
      syncToken: '',
      correlationId: 'strict-depth',
    );

    expect(page.nextSyncToken, 'next-token');
  });
}

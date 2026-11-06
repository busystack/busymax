import 'dart:convert';
import 'dart:io';

import 'package:busystack_dav/carddav.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/nextcloud_live_trust.dart';

/// Uses only the explicitly configured disposable live account. The contact is
/// a temporary fixture; BusyMax's existing contacts product remains read-only.
void main() {
  test(
    'real Nextcloud contacts resource and streaming clients share scoped trust',
    () async {
      String requiredValue(String name) {
        final value = Platform.environment['BUSYMAX_NEXTCLOUD_LIVE_$name'];
        if (value == null || value.isEmpty) {
          throw StateError('Missing disposable live contacts fixture.');
        }
        return value;
      }

      final authority = Uri.parse(requiredValue('URL'));
      final credential = DavBasicCredential(
        username: requiredValue('USERNAME'),
        password: requiredValue('PASSWORD'),
      );
      const profile = DavProviderProfile.nextcloud();
      final clients = [
        for (final identity in [
          'linked-contacts-live',
          'standalone-contacts-live',
        ])
          nextcloudLiveClient(
            authority: authority,
            prefix: 'BUSYMAX_NEXTCLOUD_LIVE',
            identity: identity,
          ),
      ];
      addTearDown(() {
        for (final client in clients) {
          client.close();
        }
      });
      final contacts = [
        for (var i = 0; i < clients.length; i++)
          CardDavClient(
            DavResourceClient(
              accountId: 'contacts-live-$i',
              authority: authority,
              profile: profile,
              credentialProvider: () async => credential,
              transport: DavHttpTransport(
                client: clients[i],
                profile: profile,
                accountAuthority: authority,
              ),
              streaming: DavTransferClient(
                client: clients[i],
                authority: authority,
                profile: profile,
              ),
            ),
          ),
      ];
      final discovered = await contacts.first.discover();
      expect(discovered.collections, isNotEmpty);
      final book = discovered.collections.first.uri;
      final id = 'busymax-private-qa-${DateTime.now().microsecondsSinceEpoch}';
      final uri = book.resolve('$id.vcf');
      final card =
          'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:$id\r\n'
          'FN:BusyMax disposable TLS fixture\r\nEND:VCARD\r\n';
      final created = await contacts.first.put(uri, card, create: true);
      try {
        for (final contact in contacts) {
          final resource = await contact.get(uri);
          expect(resource.data, contains('UID:$id'));
          final batch = await contact.multiget(book, [uri]);
          expect(batch.single.data, contains('UID:$id'));
          final cancellation = DavCancellationToken();
          final bytes = await contact.resources.streaming!
              .download(uri, credential: credential, cancellation: cancellation)
              .expand((chunk) => chunk)
              .toList();
          expect(utf8.decode(bytes), contains('UID:$id'));
        }
      } finally {
        await contacts.first.delete(uri, etag: created.etag);
      }
    },
    skip: Platform.environment['BUSYMAX_NEXTCLOUD_LIVE'] == '1'
        ? false
        : 'Needs the disposable Nextcloud live HTTPS fixture.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

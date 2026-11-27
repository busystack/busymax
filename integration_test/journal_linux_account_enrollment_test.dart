import 'dart:convert';
import 'dart:io';

import 'package:busymax/main_linux.dart' as linux;
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import 'support/journal_workflow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Linux production CalDAV enrollment discovers a journal source',
    (tester) async {
      expect(Platform.isLinux, isTrue);
      expect(Platform.environment['GDK_BACKEND'], 'x11');
      final dataHome = Directory(Platform.environment['XDG_DATA_HOME']!);
      final configHome = Directory(Platform.environment['XDG_CONFIG_HOME']!);
      expect(dataHome.existsSync(), isTrue);
      expect(configHome.existsSync(), isTrue);
      expect(configHome.parent.path, dataHome.parent.path);
      final support = (await tester.runAsync(getApplicationSupportDirectory))!;
      expect(support.path, startsWith('${dataHome.path}/'));
      expect(File('${support.path}/busymax.sqlite').existsSync(), isFalse);
      final profile = (await tester.runAsync(
        () => desktopJournalFixture('caldav'),
      ))!;
      final authority = Uri.parse(profile['authority'] as String);
      final username = profile['username'] as String;
      final password = profile['password'] as String;
      final peer = IOClient(
        HttpClient(
          context: SecurityContext(withTrustedRoots: true)
            ..setTrustedCertificatesBytes(utf8.encode(profile['ca'] as String)),
        ),
      );
      final authorization = base64Encode(utf8.encode('$username:$password'));
      Future<http.Response> request(
        String method,
        Uri uri, [
        String? body,
      ]) async {
        expect(uri.origin, authority.origin);
        final request = http.Request(method, uri)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Basic $authorization',
            'Content-Type': 'application/xml; charset=utf-8',
            'Depth': '0',
          });
        if (body != null) request.body = body;
        return http.Response.fromStream(await peer.send(request));
      }

      Uri? collectionUri;
      try {
        final title = 'Enrollment journal ${const Uuid().v4()}';
        collectionUri = await tester.runAsync(() async {
          Future<Uri> discover(
            Uri endpoint,
            String name,
            String namespace,
          ) async {
            final response = await request(
              'PROPFIND',
              endpoint,
              '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
                  '<d:prop><${namespace == 'DAV:' ? 'd' : 'c'}:$name/></d:prop></d:propfind>',
            );
            expect(response.statusCode, 207);
            final property = XmlDocument.parse(response.body)
                .findAllElements(name, namespaceUri: namespace)
                .single;
            return endpoint.resolve(
              property
                  .findElements('href', namespaceUri: 'DAV:')
                  .single
                  .innerText,
            );
          }

          final principal = await discover(
            authority.resolve('dav/'),
            'current-user-principal',
            'DAV:',
          );
          final home = await discover(
            principal,
            'calendar-home-set',
            'urn:ietf:params:xml:ns:caldav',
          );
          expect(home.path, endsWith('/'));
          final uri = home.resolve('enrollment-${const Uuid().v4()}/');
          expect(
            (await request(
              'MKCALENDAR',
              uri,
              '<c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
                  '<d:set><d:prop><d:displayname>$title</d:displayname>'
                  '<c:supported-calendar-component-set><c:comp name="VJOURNAL"/>'
                  '</c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>',
            )).statusCode,
            201,
          );
          return uri;
        });

        // Start the production entry point with the real file database, native
        // keyring, connectivity observer, TLS review and synchronization.
        await tester.runAsync(() => linux.main([]));
        await waitJournalWidget(tester, find.byType(LinuxBusyMaxApp));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LinuxBusyMaxApp)),
          listen: false,
        );
        final database = container.read(databaseProvider);
        final persistence = container.read(authorizationPersistenceProvider);
        expect(
          await tester.runAsync(() => database.select(database.accounts).get()),
          isEmpty,
        );
        container.read(appRouterProvider).go('/settings?page=accounts');

        Future<void> tap(Finder finder) async {
          await waitJournalWidget(tester, finder);
          await tester.ensureVisible(finder);
          await tester.pump(const Duration(milliseconds: 300));
          final hit = finder.hitTestable();
          await waitJournalWidget(tester, hit);
          await tester.tap(hit);
          await tester.pump(const Duration(milliseconds: 300));
        }

        Future<void> submit({required bool reconnect}) async {
          final server = find.byKey(const Key('caldav-server-field'));
          final user = find.byKey(const Key('caldav-username-field'));
          final secret = find.byKey(const Key('caldav-password-field'));
          await waitJournalWidget(tester, secret);
          if (reconnect) {
            for (final field in [server, user]) {
              final input = find.descendant(
                of: field,
                matching: find.byType(EditableText),
              );
              expect(tester.widget<EditableText>(input).readOnly, isTrue);
            }
            expect(inputValue(tester, user), username);
          } else {
            await tester.enterText(server, authority.toString());
            await tester.enterText(user, username);
          }
          await tester.enterText(secret, password);
          await tap(find.text('Connect').last);
        }

        tester.testTextInput.register();
        addTearDown(tester.testTextInput.unregister);
        await tap(find.byKey(const ValueKey('add-account-caldav')));
        await submit(reconnect: false);
        await tap(find.text('Import private CA'));
        await tester.runAsync(() async {
          final profilePath =
              Platform.environment['BUSYMAX_JOURNAL_LIVE_FIXTURE']!;
          final fixture =
              jsonDecode(await File(profilePath).readAsString()) as Map;
          final ca = (fixture['caldav'] as Map)['caFile'] as String;
          await _pickFixtureCa(ca);
        });
        await tap(find.text('Approve this certificate policy'));
        final discovered = await _awaitResult(tester, () async {
          final accounts = await database.select(database.accounts).get();
          if (accounts.isEmpty) return null;
          final account = accounts.single;
          final collections = await database
              .select(database.davCollections)
              .get();
          final collection = collections
              .where((row) => row.displayName == title)
              .firstOrNull;
          if (collection == null) return null;
          final credential = await persistence.readCurrentCredential(
            account.id,
          );
          if (credential == null) return null;
          expect(credential, isA<CalDavSecretRecord>());
          return (account: account, collection: collection);
        });
        final account = discovered.account;
        final collection = discovered.collection;
        expect(account.provider, 'caldav');
        expect(account.providerAccountId, username);
        expect(collection.supportedComponentMask, davComponentJournal);
        expect(Uri.parse(collection.requestUri), collectionUri);
        expect(collection.accountId, account.id);

        final router = container.read(appRouterProvider);
        router.go('/settings?page=accounts&accountDetail=${account.id}');
        final source = find.byKey(
          ValueKey('dav-collection-expander-${collection.id}'),
        );
        await tap(find.descendant(of: source, matching: find.text(title)));
        final toggle = find.byKey(
          ValueKey('dav-journals-toggle-${collection.id}'),
        );
        await waitJournalWidget(tester, toggle);
        if (!tester.widget<BusyMaxSwitchRow>(toggle).value) {
          await tap(
            find.descendant(of: toggle, matching: find.text('Journals')),
          );
          await waitJournalWidget(
            tester,
            find.byWidgetPredicate(
              (widget) =>
                  widget is BusyMaxSwitchRow &&
                  widget.key ==
                      ValueKey('dav-journals-toggle-${collection.id}') &&
                  widget.value,
            ),
          );
        }
        expect(tester.widget<BusyMaxSwitchRow>(toggle).value, isTrue);

        final before = await tester.runAsync(
          () => persistence.generation(account.id),
        );
        await tap(
          find.descendant(
            of: find.byKey(ValueKey('account-advanced-${account.id}')),
            matching: find.text('Advanced'),
          ),
        );
        await tap(find.byKey(ValueKey('reconnect-account-${account.id}')));
        await submit(reconnect: true);
        await _awaitResult(tester, () async {
          final generation = await persistence.generation(account.id);
          final credential = await persistence.readCurrentCredential(
            account.id,
          );
          return generation != before && credential is CalDavSecretRecord
              ? generation
              : null;
        });
        expect(
          (await tester.runAsync(
            () => database.select(database.accounts).get(),
          ))!.single.id,
          account.id,
        );
        router.go('/journals');
        await waitJournalWidget(tester, find.text(title));
        debugPrint(
          'JOURNAL_WORKFLOW_CASE caldav account-connect-and-discover PASS',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        final remote = collectionUri;
        if (remote != null) {
          await tester.runAsync(() async {
            expect((await request('DELETE', remote)).statusCode, 204);
          });
        }
        peer.close();
      }
    },
    skip:
        Platform.environment['BUSYMAX_JOURNAL_LINUX_NATIVE_ENROLLMENT'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _pickFixtureCa(String path) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  String? window;
  while (DateTime.now().isBefore(deadline)) {
    final result = await Process.run('xdotool', [
      'search',
      '--onlyvisible',
      '--name',
      r'^Open File$',
    ]);
    if (result.exitCode == 0) {
      window = (result.stdout as String).trim();
      expect(window, matches(RegExp(r'^\d+$')));
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (window == null)
    throw TestFailure('The native CA file chooser did not open.');
  for (final arguments in [
    ['windowfocus', '--sync', window],
    ['key', '--clearmodifiers', 'ctrl+l'],
    ['type', '--clearmodifiers', path],
    ['key', '--clearmodifiers', 'Return'],
  ]) {
    final result = await Process.run('xdotool', arguments);
    expect(
      result.exitCode,
      0,
      reason: 'Native CA file chooser: ${arguments.first}',
    );
  }
}

Future<T> _awaitResult<T extends Object>(
  WidgetTester tester,
  Future<T?> Function() getResult,
) async {
  for (var attempt = 0; attempt < 240; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final result = await tester.runAsync(getResult);
    if (result != null) return result;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  throw TestFailure('Linux journal enrollment did not converge.');
}

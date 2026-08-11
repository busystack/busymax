import 'dart:convert';

import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('normalizes HTTPS while preserving an installation path', () {
    expect(
      normalizeNextcloudLoginServer(' cloud.example.test/nextcloud/ '),
      Uri.parse('https://cloud.example.test/nextcloud'),
    );
    expect(
      normalizeNextcloudLoginServer(
        'http://CLOUD.example.test:8443/nextcloud/',
      ),
      Uri.parse('https://cloud.example.test:8443/nextcloud'),
    );
    expect(
      () => normalizeNextcloudLoginServer('https://user@cloud.test/path'),
      throwsFormatException,
    );
  });

  test('normalizes standard DAV endpoints to the installation root', () {
    expect(
      normalizeNextcloudLoginServer(
        'https://cloud.example.test/remote.php/dav',
      ),
      Uri.parse('https://cloud.example.test'),
    );
    expect(
      normalizeNextcloudLoginServer(
        'https://cloud.example.test/nextcloud/remote.php/dav/calendars/alex',
      ),
      Uri.parse('https://cloud.example.test/nextcloud'),
    );
    expect(
      normalizeNextcloudLoginServer(
        'https://cloud.example.test/nextcloud/remote.php/webdav/',
      ),
      Uri.parse('https://cloud.example.test/nextcloud'),
    );
  });

  test(
    'success treats 404 as pending and uses canonical returned identity',
    () async {
      final requests = <http.Request>[];
      var polls = 0;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/index.php/login/v2')) {
          return http.Response(
            jsonEncode({
              'poll': {
                'token': 'short-lived-token',
                'endpoint':
                    'https://cloud.example.test/nextcloud/login/v2/poll',
              },
              'login':
                  'https://cloud.example.test/nextcloud/login/v2/flow/browser',
            }),
            200,
          );
        }
        polls += 1;
        if (polls < 3) return http.Response('', 404);
        return http.Response(
          jsonEncode({
            'server': 'https://CANONICAL.example.test/nextcloud/',
            'loginName': ' server-login ',
            'appPassword': ' app-secret ',
          }),
          200,
        );
      });
      Uri? opened;
      final flow = NextcloudLoginFlowV2(
        client: client,
        browserLauncher: (uri) async {
          opened = uri;
          return true;
        },
        delay: (_) async {},
      );

      final result = await flow.start(
        'https://cloud.example.test/nextcloud/remote.php/dav',
      );

      expect(requests.first.url.path, '/nextcloud/index.php/login/v2');
      expect(opened?.path, '/nextcloud/login/v2/flow/browser');
      expect(polls, 3);
      expect(requests.last.body, 'token=short-lived-token');
      expect(requests.last.url.query, isEmpty);
      expect(
        result.canonicalServer,
        Uri.parse('https://canonical.example.test/nextcloud'),
      );
      expect(result.loginName, 'server-login');
      expect(result.appPassword, 'app-secret');
      expect(result.toString(), isNot(contains('app-secret')));
      expect(result.toString(), isNot(contains('server-login')));
      expect(result.toString(), isNot(contains('canonical.example.test')));
      expect(
        requests.every(
          (request) => !request.url.toString().contains('short-lived-token'),
        ),
        isTrue,
      );
    },
  );

  test('cancel stops pending polling with a typed cancellation', () async {
    late NextcloudLoginFlowV2 flow;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/index.php/login/v2')) {
        return http.Response(
          jsonEncode({
            'poll': {
              'token': 'token',
              'endpoint': 'https://cloud.example.test/login/v2/poll',
            },
            'login': 'https://cloud.example.test/login/v2/flow/browser',
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    flow = NextcloudLoginFlowV2(
      client: client,
      browserLauncher: (_) async {
        flow.cancel();
        return true;
      },
      delay: (_) async {},
    );

    await expectLater(
      flow.start('cloud.example.test'),
      throwsA(
        isA<DavException>().having(
          (error) => error.kind,
          'kind',
          DavErrorKind.cancelled,
        ),
      ),
    );
  });

  test('pending polling expires without becoming an auth rejection', () async {
    var clock = DateTime.utc(2026, 8, 8, 12);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/index.php/login/v2')) {
        return http.Response(
          jsonEncode({
            'poll': {
              'token': 'token',
              'endpoint': 'https://cloud.example.test/login/v2/poll',
            },
            'login': 'https://cloud.example.test/login/v2/flow/browser',
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    final flow = NextcloudLoginFlowV2(
      client: client,
      browserLauncher: (_) async => true,
      nowUtc: () => clock,
      operationTimeout: const Duration(seconds: 2),
      pollInterval: const Duration(seconds: 1),
      delay: (duration) async => clock = clock.add(duration),
    );

    await expectLater(
      flow.start('cloud.example.test'),
      throwsA(
        isA<DavException>()
            .having((error) => error.kind, 'kind', DavErrorKind.timeout)
            .having((error) => error.code, 'code', 'NextcloudLoginFlowExpired'),
      ),
    );
  });

  test('rejects cross-origin login and poll endpoints', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'poll': {
            'token': 'token',
            'endpoint': 'https://attacker.example/login/v2/poll',
          },
          'login': 'https://cloud.example.test/login/v2/flow/browser',
        }),
        200,
      ),
    );
    final flow = NextcloudLoginFlowV2(
      client: client,
      browserLauncher: (_) async => true,
    );

    await expectLater(
      flow.start('cloud.example.test'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'NextcloudLoginEndpointRejected',
        ),
      ),
    );
  });

  test('rejects cross-origin HTTP redirects before following them', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls += 1;
      return http.Response(
        '',
        302,
        headers: {'location': 'https://evil.test/'},
      );
    });
    final flow = NextcloudLoginFlowV2(
      client: client,
      browserLauncher: (_) async => true,
    );

    await expectLater(
      flow.start('cloud.example.test'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'NextcloudLoginRedirectRejected',
        ),
      ),
    );
    expect(calls, 1);
  });

  test('browser launch failure and malformed success are terminal', () async {
    final startBody = jsonEncode({
      'poll': {
        'token': 'token',
        'endpoint': 'https://cloud.example.test/login/v2/poll',
      },
      'login': 'https://cloud.example.test/login/v2/flow/browser',
    });
    final launchFailure = NextcloudLoginFlowV2(
      client: MockClient((_) async => http.Response(startBody, 200)),
      browserLauncher: (_) async => false,
    );
    await expectLater(
      launchFailure.start('cloud.example.test'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'NextcloudLoginBrowserLaunchFailed',
        ),
      ),
    );

    var calls = 0;
    final malformed = NextcloudLoginFlowV2(
      client: MockClient((_) async {
        calls += 1;
        return calls == 1
            ? http.Response(startBody, 200)
            : http.Response('{bad json', 200);
      }),
      browserLauncher: (_) async => true,
      delay: (_) async {},
    );
    await expectLater(
      malformed.start('cloud.example.test'),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'NextcloudLoginMalformedResponse',
        ),
      ),
    );
  });
}

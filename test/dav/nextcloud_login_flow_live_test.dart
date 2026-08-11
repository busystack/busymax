import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/nextcloud_app_password_revoker.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const _enabledVariable = 'BUSYMAX_NEXTCLOUD_LOGIN_LIVE';

void main() {
  final enabled = Platform.environment[_enabledVariable] == '1';

  test(
    'real browser Login Flow returns and revokes a canonical app password',
    () async {
      final server = Uri.parse(
        _requiredEnvironment('BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL'),
      );
      final username = _requiredEnvironment(
        'BUSYMAX_NEXTCLOUD_LOGIN_LIVE_USERNAME',
      );
      final bootstrapAppPassword = _requiredEnvironment(
        'BUSYMAX_NEXTCLOUD_LOGIN_LIVE_APP_PASSWORD',
      );
      final certificatePath = _requiredEnvironment(
        'BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT',
      );
      expect(server.scheme, 'https');

      final securityContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(certificatePath);
      final flowHttpClient = HttpClient(context: securityContext);
      final flowClient = IOClient(flowHttpClient);
      addTearDown(() {
        flowClient.close();
        flowHttpClient.close(force: true);
      });
      final browser = await _HeadlessLoginFlowBrowser.start(
        username: username,
        appPassword: bootstrapAppPassword,
      );
      addTearDown(browser.close);

      final flow = NextcloudLoginFlowV2(
        client: flowClient,
        browserLauncher: browser.authorize,
        pollInterval: const Duration(milliseconds: 100),
        operationTimeout: const Duration(minutes: 2),
      );
      final result = await flow.start(server.toString());
      expect(result.canonicalServer, server);
      expect(result.loginName, username);
      expect(result.appPassword, bootstrapAppPassword);
      expect(result.toString(), isNot(contains(username)));
      expect(result.toString(), isNot(contains(bootstrapAppPassword)));

      final profile = davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: result.canonicalServer,
      );
      final davHttpClient = HttpClient(context: securityContext);
      final davClient = IOClient(davHttpClient);
      addTearDown(() {
        davClient.close();
        davHttpClient.close(force: true);
      });
      final transport = DavHttpTransport(
        client: davClient,
        profile: profile,
        accountAuthority: result.canonicalServer,
      );
      final credential = DavBasicCredential(
        username: result.loginName,
        password: result.appPassword,
      );
      final discovery = DavDiscoveryService(
        transport: transport,
        profile: profile,
        accountAuthority: result.canonicalServer,
        accountId: 'nextcloud-login-live',
        credential: credential,
      );
      final discovered = await discovery.discover(
        correlationId: 'nextcloud-login-live-discovery',
      );
      expect(discovered.service.calendarHomeHref.path, isNotEmpty);

      await NextcloudAppPasswordRevoker(transport: transport).revoke(
        accountId: 'nextcloud-login-live',
        credential: NextcloudSecretRecord(
          canonicalServer: result.canonicalServer,
          loginName: result.loginName,
          appPassword: result.appPassword,
        ),
        correlationId: 'nextcloud-login-live-revoke',
      );
      await expectLater(
        discovery.discover(
          correlationId: 'nextcloud-login-live-revoked-discovery',
        ),
        throwsA(
          isA<DavException>().having(
            (error) => error.kind,
            'kind',
            DavErrorKind.authentication,
          ),
        ),
      );
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 and its URL, username, temporary app '
              'password, and TLS certificate variables to run this test.',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'real Login Flow start can be cancelled while browser authorization opens',
    () async {
      final server = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL');
      final certificatePath = _requiredEnvironment(
        'BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT',
      );
      final securityContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(certificatePath);
      final ioClient = HttpClient(context: securityContext);
      final client = IOClient(ioClient);
      addTearDown(() {
        client.close();
        ioClient.close(force: true);
      });
      late final NextcloudLoginFlowV2 flow;
      flow = NextcloudLoginFlowV2(
        client: client,
        browserLauncher: (_) async {
          flow.cancel();
          return true;
        },
      );

      await expectLater(
        flow.start(server),
        throwsA(
          isA<DavException>().having(
            (error) => error.kind,
            'kind',
            DavErrorKind.cancelled,
          ),
        ),
      );
    },
    skip: enabled ? false : 'Live Nextcloud Login Flow is not enabled.',
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'real pending polling remains 404 until the operation expires',
    () async {
      final server = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LOGIN_LIVE_URL');
      final certificatePath = _requiredEnvironment(
        'BUSYMAX_NEXTCLOUD_LOGIN_LIVE_TLS_CERT',
      );
      final securityContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(certificatePath);
      final ioClient = HttpClient(context: securityContext);
      final client = IOClient(ioClient);
      addTearDown(() {
        client.close();
        ioClient.close(force: true);
      });
      var clock = DateTime.utc(2026, 8, 8, 12);
      var pendingDelays = 0;
      final flow = NextcloudLoginFlowV2(
        client: client,
        browserLauncher: (_) async => true,
        nowUtc: () => clock,
        operationTimeout: const Duration(seconds: 2),
        pollInterval: const Duration(seconds: 1),
        delay: (duration) async {
          pendingDelays += 1;
          clock = clock.add(duration);
        },
      );

      await expectLater(
        flow.start(server),
        throwsA(
          isA<DavException>()
              .having((error) => error.kind, 'kind', DavErrorKind.timeout)
              .having(
                (error) => error.code,
                'code',
                'NextcloudLoginFlowExpired',
              ),
        ),
      );
      expect(pendingDelays, 2);
    },
    skip: enabled ? false : 'Live Nextcloud Login Flow is not enabled.',
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

final class _HeadlessLoginFlowBrowser {
  _HeadlessLoginFlowBrowser({
    required this.username,
    required this.appPassword,
    required this.process,
    required this.profileDirectory,
    required _ChromeDevTools devTools,
  }) : _devTools = devTools;

  static Future<_HeadlessLoginFlowBrowser> start({
    required String username,
    required String appPassword,
  }) async {
    final debugReservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final debugPort = debugReservation.port;
    await debugReservation.close();
    final profileDirectory = await Directory.systemTemp.createTemp(
      'busymax-nextcloud-login-browser-',
    );
    final executable =
        Platform.environment['BUSYMAX_NEXTCLOUD_LOGIN_LIVE_BROWSER'] ??
        'google-chrome';
    final process = await Process.start(executable, [
      '--headless=new',
      '--disable-gpu',
      '--disable-background-networking',
      '--disable-component-update',
      '--disable-breakpad',
      '--disable-crash-reporter',
      '--disable-default-apps',
      '--disable-sync',
      '--ignore-certificate-errors',
      '--no-first-run',
      '--no-default-browser-check',
      '--remote-debugging-address=127.0.0.1',
      '--remote-debugging-port=$debugPort',
      '--user-data-dir=${profileDirectory.path}',
      'about:blank',
    ]);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    try {
      final webSocketUri = await _waitForDevTools(debugPort);
      final devTools = await _ChromeDevTools.connect(webSocketUri);
      return _HeadlessLoginFlowBrowser(
        username: username,
        appPassword: appPassword,
        process: process,
        profileDirectory: profileDirectory,
        devTools: devTools,
      );
    } on Object {
      process.kill();
      await process.exitCode;
      await _deleteDirectoryWithRetries(profileDirectory);
      rethrow;
    }
  }

  final String username;
  final String appPassword;
  final Process process;
  final Directory profileDirectory;
  final _ChromeDevTools _devTools;

  Future<bool> authorize(Uri loginUri) async {
    final target = await _devTools.call(
      'Target.createTarget',
      parameters: const {'url': 'about:blank'},
    );
    final attached = await _devTools.call(
      'Target.attachToTarget',
      parameters: {'targetId': target['targetId'], 'flatten': true},
    );
    final sessionId = attached['sessionId']! as String;
    await _devTools.call('Page.enable', sessionId: sessionId);
    await _devTools.call(
      'Page.navigate',
      parameters: {'url': loginUri.toString()},
      sessionId: sessionId,
    );

    await _waitForBrowserCondition(() async {
      final value = await _devTools.evaluate('''(() => {
          const candidate = [...document.querySelectorAll('button, a')]
            .find((element) => element.textContent.includes('Alternative log in using app password'));
          if (!candidate) return false;
          candidate.click();
          return true;
        })()''', sessionId: sessionId);
      return value == true;
    });

    await _waitForBrowserCondition(() async {
      final value = await _devTools.evaluate('''(() => {
          const user = document.querySelector('input[name="user"]');
          const password = document.querySelector('input[name="password"]');
          const form = user?.closest('form');
          if (!user || !password || !form) return false;
          const setValue = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
          setValue.call(user, ${jsonEncode(username)});
          setValue.call(password, ${jsonEncode(appPassword)});
          user.dispatchEvent(new Event('input', { bubbles: true }));
          password.dispatchEvent(new Event('input', { bubbles: true }));
          form.requestSubmit();
          return true;
        })()''', sessionId: sessionId);
      return value == true;
    });
    return true;
  }

  Future<void> close() async {
    await _devTools.close();
    process.kill();
    await process.exitCode;
    await _deleteDirectoryWithRetries(profileDirectory);
  }
}

final class _ChromeDevTools {
  _ChromeDevTools._(this._socket) {
    _socket.listen(
      _receive,
      onError: _failAll,
      onDone: () => _failAll(StateError('Chrome DevTools disconnected.')),
    );
  }

  static Future<_ChromeDevTools> connect(Uri uri) async =>
      _ChromeDevTools._(await WebSocket.connect(uri.toString()));

  final WebSocket _socket;
  final Map<int, Completer<Map<String, Object?>>> _pending = {};
  var _nextId = 1;

  Future<Map<String, Object?>> call(
    String method, {
    Map<String, Object?> parameters = const {},
    String? sessionId,
  }) {
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _socket.add(
      jsonEncode({
        'id': id,
        'method': method,
        'params': parameters,
        if (sessionId != null) 'sessionId': sessionId,
      }),
    );
    return completer.future.timeout(const Duration(seconds: 15));
  }

  Future<Object?> evaluate(
    String expression, {
    required String sessionId,
  }) async {
    final result = await call(
      'Runtime.evaluate',
      parameters: {
        'expression': expression,
        'returnByValue': true,
        'awaitPromise': true,
      },
      sessionId: sessionId,
    );
    final remote = (result['result']! as Map).cast<String, Object?>();
    return remote['value'];
  }

  void _receive(Object? rawMessage) {
    if (rawMessage is! String) return;
    final decoded = jsonDecode(rawMessage);
    if (decoded is! Map) return;
    final message = decoded.cast<String, Object?>();
    final id = message['id'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (message['error'] case final Map error) {
      completer.completeError(
        StateError('Chrome DevTools command failed: ${error['code']}.'),
      );
      return;
    }
    completer.complete(
      ((message['result'] as Map?) ?? const {}).cast<String, Object?>(),
    );
  }

  void _failAll(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  Future<void> close() => _socket.close();
}

Future<Uri> _waitForDevTools(int port) async {
  final client = http.Client();
  try {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      try {
        final response = await client
            .get(Uri.parse('http://127.0.0.1:$port/json/version'))
            .timeout(const Duration(seconds: 1));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, Object?>;
          return Uri.parse(json['webSocketDebuggerUrl']! as String);
        }
      } on Object {
        // Chrome is still starting.
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } finally {
    client.close();
  }
  throw StateError('Headless Chrome did not expose DevTools in time.');
}

Future<void> _waitForBrowserCondition(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('The Nextcloud browser authorization UI did not load.');
}

Future<void> _deleteDirectoryWithRetries(Directory directory) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (!await directory.exists()) return;
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 49) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('$name is required when $_enabledVariable=1.');
  }
  return value;
}

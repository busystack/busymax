import 'dart:async';
import 'dart:io';

import 'package:busymax/src/webcal/webcal_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binds validators only to the exact matching redirect hop', () async {
    final first = _FakeResponse(302, headers: {'location': '/final.ics'});
    final second = _FakeResponse(
      200,
      chunks: const [
        <int>[1, 2, 3],
      ],
    );
    final client = _FakeHttpClient([first, second]);
    final transport = IoWebCalHttpTransport(clientFactory: () => client);
    final start = Uri.parse('https://calendar.example.test/start');
    final target = Uri.parse('https://calendar.example.test/final.ics');

    final result = await transport.get(
      start,
      validators: const WebCalHttpValidators(
        etag: '"etag"',
        lastModified: 'Sat, 29 Aug 2026 20:00:00 GMT',
      ),
      validatorTarget: target,
    );

    expect(
      result.finalUri.toString(),
      'https://calendar.example.test/final.ics',
    );
    expect(result.body, [1, 2, 3]);
    expect(client.requests, hasLength(2));
    final firstHeaders = client.requests.first.recordedHeaders;
    expect(firstHeaders['accept'], 'text/calendar');
    expect(firstHeaders, isNot(contains('if-none-match')));
    expect(firstHeaders, isNot(contains('if-modified-since')));
    expect(firstHeaders, isNot(contains('authorization')));
    expect(firstHeaders, isNot(contains('cookie')));
    expect(firstHeaders, isNot(contains('referer')));
    expect(firstHeaders, isNot(contains('origin')));
    final redirectedHeaders = client.requests.last.recordedHeaders;
    expect(redirectedHeaders['if-none-match'], '"etag"');
    expect(
      redirectedHeaders['if-modified-since'],
      'Sat, 29 Aug 2026 20:00:00 GMT',
    );
  });

  test(
    'rejects redirect downgrade, user information, fragments, and loops',
    () async {
      for (final target in [
        'http://calendar.example.test/feed',
        'https://user:secret@calendar.example.test/feed',
        'https://calendar.example.test/feed#fragment',
      ]) {
        final client = _FakeHttpClient([
          _FakeResponse(302, headers: {'location': target}),
        ]);
        await expectLater(
          IoWebCalHttpTransport(
            clientFactory: () => client,
          ).get(Uri.parse('https://calendar.example.test/start')),
          throwsA(
            isA<WebCalHttpException>().having(
              (error) => error.code,
              'code',
              'WebCalRedirectTargetNotAllowed',
            ),
          ),
        );
        expect(client.requests, hasLength(1));
      }

      final loop = _FakeHttpClient([
        _FakeResponse(302, headers: {'location': '/start'}),
      ]);
      await expectLater(
        IoWebCalHttpTransport(
          clientFactory: () => loop,
        ).get(Uri.parse('https://calendar.example.test/start')),
        throwsA(
          isA<WebCalHttpException>().having(
            (error) => error.code,
            'code',
            'WebCalRedirectLoop',
          ),
        ),
      );
    },
  );

  test('enforces decoded body and redirect limits', () async {
    final oversized = _FakeHttpClient([
      _FakeResponse(
        200,
        chunks: const [
          <int>[1, 2, 3, 4, 5],
        ],
      ),
    ]);
    await expectLater(
      IoWebCalHttpTransport(
        clientFactory: () => oversized,
        limits: const WebCalHttpLimits(maximumDecodedBodyBytes: 4),
      ).get(Uri.parse('https://calendar.example.test/start')),
      throwsA(
        isA<WebCalHttpException>().having(
          (error) => error.code,
          'code',
          'WebCalBodyTooLarge',
        ),
      ),
    );

    final redirects = _FakeHttpClient([
      _FakeResponse(302, headers: {'location': '/two'}),
      _FakeResponse(302, headers: {'location': '/three'}),
    ]);
    await expectLater(
      IoWebCalHttpTransport(
        clientFactory: () => redirects,
        limits: const WebCalHttpLimits(maximumRedirects: 1),
      ).get(Uri.parse('https://calendar.example.test/one')),
      throwsA(
        isA<WebCalHttpException>().having(
          (error) => error.code,
          'code',
          'WebCalRedirectLimitExceeded',
        ),
      ),
    );
  });

  test('enforces stream inactivity and total deadlines', () async {
    final idleController = StreamController<List<int>>();
    addTearDown(idleController.close);
    final idle = _FakeHttpClient([
      _FakeResponse(200, stream: idleController.stream),
    ]);
    await expectLater(
      IoWebCalHttpTransport(
        clientFactory: () => idle,
        limits: const WebCalHttpLimits(
          streamInactivityTimeout: Duration(milliseconds: 5),
          totalDeadline: Duration(seconds: 1),
        ),
      ).get(Uri.parse('https://calendar.example.test/start')),
      throwsA(
        isA<WebCalHttpException>().having(
          (error) => error.code,
          'code',
          'WebCalStreamInactivityTimeout',
        ),
      ),
    );

    final total = _FakeHttpClient(const [], neverConnect: true);
    await expectLater(
      IoWebCalHttpTransport(
        clientFactory: () => total,
        limits: const WebCalHttpLimits(
          totalDeadline: Duration(milliseconds: 5),
        ),
      ).get(Uri.parse('https://calendar.example.test/start')),
      throwsA(
        isA<WebCalHttpException>().having(
          (error) => error.code,
          'code',
          'WebCalTotalTimeout',
        ),
      ),
    );
  });

  test('marks a response conditional only when validators were sent', () async {
    final target = Uri.parse('https://calendar.example.test/feed');
    final conditional = _FakeHttpClient([_FakeResponse(304)]);
    final response =
        await IoWebCalHttpTransport(clientFactory: () => conditional).get(
          target,
          validators: const WebCalHttpValidators(etag: '"one"'),
          validatorTarget: target,
        );
    expect(response.conditionalRequestSent, isTrue);

    final unbound = _FakeHttpClient([_FakeResponse(304)]);
    final unboundResponse =
        await IoWebCalHttpTransport(clientFactory: () => unbound).get(
          target,
          validators: const WebCalHttpValidators(etag: '"one"'),
          validatorTarget: Uri.parse('https://other.example.test/feed'),
        );
    expect(unboundResponse.conditionalRequestSent, isFalse);
  });

  test('does not wait for stalled redirect or 304 response bodies', () async {
    final redirectBody = StreamController<List<int>>();
    final notModifiedBody = StreamController<List<int>>();
    final redirectClient = _FakeHttpClient([
      _FakeResponse(
        302,
        headers: {'location': '/final.ics'},
        stream: redirectBody.stream,
      ),
      _FakeResponse(
        200,
        chunks: const [
          <int>[1],
        ],
      ),
    ]);

    final redirected =
        await IoWebCalHttpTransport(clientFactory: () => redirectClient)
            .get(Uri.parse('https://calendar.example.test/start'))
            .timeout(const Duration(milliseconds: 100));
    expect(redirected.body, [1]);
    expect(redirectBody.hasListener, isFalse);

    final notModifiedClient = _FakeHttpClient([
      _FakeResponse(304, stream: notModifiedBody.stream),
    ]);
    final target = Uri.parse('https://calendar.example.test/feed');
    final notModified =
        await IoWebCalHttpTransport(clientFactory: () => notModifiedClient)
            .get(
              target,
              validators: const WebCalHttpValidators(etag: '"one"'),
              validatorTarget: target,
            )
            .timeout(const Duration(milliseconds: 100));
    expect(notModified.statusCode, 304);
    expect(notModifiedBody.hasListener, isFalse);
  });

  test('body waits never exceed the remaining total deadline', () async {
    final controller = StreamController<List<int>>();
    scheduleMicrotask(() => controller.add([1]));
    final client = _FakeHttpClient([
      _FakeResponse(200, stream: controller.stream),
    ]);

    await expectLater(
      IoWebCalHttpTransport(
        clientFactory: () => client,
        limits: const WebCalHttpLimits(
          streamInactivityTimeout: Duration(seconds: 1),
          totalDeadline: Duration(milliseconds: 20),
        ),
      ).get(Uri.parse('https://calendar.example.test/start')),
      throwsA(
        isA<WebCalHttpException>().having(
          (error) => error.code,
          'code',
          'WebCalTotalTimeout',
        ),
      ),
    );
  });
}

final class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.responses, {this.neverConnect = false});

  final List<_FakeResponse> responses;
  final bool neverConnect;
  final requests = <_FakeRequest>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (neverConnect) return Completer<HttpClientRequest>().future;
    final request = _FakeRequest(url, responses[requests.length]);
    requests.add(request);
    return Future.value(request);
  }

  @override
  set connectionTimeout(Duration? value) {}

  @override
  set autoUncompress(bool value) {}

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri, this.response);

  @override
  final Uri uri;
  final _FakeResponse response;
  final _FakeHeaders _headers = _FakeHeaders();

  @override
  HttpHeaders get headers => _headers;

  Map<String, String> get recordedHeaders => _headers.values;

  @override
  set followRedirects(bool value) {}

  @override
  set maxRedirects(int value) {}

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeResponse(
    this.statusCode, {
    Map<String, String> headers = const {},
    List<List<int>> chunks = const [],
    Stream<List<int>>? stream,
  }) : _headers = _FakeHeaders(headers),
       _stream = stream ?? Stream<List<int>>.fromIterable(chunks);

  @override
  final int statusCode;
  final _FakeHeaders _headers;
  final Stream<List<int>> _stream;

  @override
  HttpHeaders get headers => _headers;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeHeaders implements HttpHeaders {
  _FakeHeaders([Map<String, String> initial = const {}])
    : values = {
        for (final entry in initial.entries)
          entry.key.toLowerCase(): entry.value,
      };

  final Map<String, String> values;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = value.toString();
  }

  @override
  void removeAll(String name) => values.remove(name.toLowerCase());

  @override
  String? value(String name) => values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

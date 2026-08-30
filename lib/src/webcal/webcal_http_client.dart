import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../ical/ical_ingestion.dart';

final class WebCalHttpException implements Exception {
  const WebCalHttpException(this.code, {this.httpStatus});

  final String code;
  final int? httpStatus;

  @override
  String toString() =>
      'WebCalHttpException($code${httpStatus == null ? '' : ', status: $httpStatus'})';
}

final class WebCalHttpValidators {
  const WebCalHttpValidators({this.etag, this.lastModified});

  final String? etag;
  final String? lastModified;

  bool get isEmpty => etag == null && lastModified == null;
}

final class WebCalHttpResponse {
  const WebCalHttpResponse({
    required this.statusCode,
    required this.finalUri,
    required this.body,
    required this.etag,
    required this.lastModified,
    required this.contentType,
    required this.conditionalRequestSent,
  });

  final int statusCode;
  final Uri finalUri;
  final Uint8List? body;
  final String? etag;
  final String? lastModified;
  final String? contentType;
  final bool conditionalRequestSent;
}

abstract interface class WebCalHttpTransport {
  Future<WebCalHttpResponse> get(
    Uri uri, {
    WebCalHttpValidators validators = const WebCalHttpValidators(),
    Uri? validatorTarget,
  });
}

final class WebCalHttpLimits {
  const WebCalHttpLimits({
    this.connectTimeout = const Duration(seconds: 15),
    this.streamInactivityTimeout = const Duration(seconds: 30),
    this.totalDeadline = const Duration(minutes: 2),
    this.maximumDecodedBodyBytes = icalIngestionDecodedBodyLimit,
    this.maximumRedirects = 5,
  });

  final Duration connectTimeout;
  final Duration streamInactivityTimeout;
  final Duration totalDeadline;
  final int maximumDecodedBodyBytes;
  final int maximumRedirects;
}

final class IoWebCalHttpTransport implements WebCalHttpTransport {
  IoWebCalHttpTransport({
    HttpClient Function()? clientFactory,
    this.limits = const WebCalHttpLimits(),
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final WebCalHttpLimits limits;

  @override
  Future<WebCalHttpResponse> get(
    Uri uri, {
    WebCalHttpValidators validators = const WebCalHttpValidators(),
    Uri? validatorTarget,
  }) async {
    final deadline = DateTime.now().add(limits.totalDeadline);
    final visited = <String>{};
    var current = uri;
    var redirects = 0;
    while (true) {
      _requireHttpsTarget(current);
      if (!visited.add(current.toString())) {
        throw const WebCalHttpException('WebCalRedirectLoop');
      }
      if (redirects > limits.maximumRedirects) {
        throw const WebCalHttpException('WebCalRedirectLimitExceeded');
      }
      final response = await _singleGet(
        current,
        validators: validatorTarget == current
            ? validators
            : const WebCalHttpValidators(),
        deadline: deadline,
      );
      if (!_redirectStatuses.contains(response.statusCode)) return response;
      final location = response.redirectLocation;
      if (location == null) {
        throw WebCalHttpException(
          'WebCalRedirectMissingLocation',
          httpStatus: response.statusCode,
        );
      }
      final next = current.resolveUri(location);
      _requireHttpsTarget(next);
      current = next;
      redirects += 1;
    }
  }

  Future<_SingleResponse> _singleGet(
    Uri target, {
    required WebCalHttpValidators validators,
    required DateTime deadline,
  }) async {
    final client = _clientFactory()
      ..connectionTimeout = limits.connectTimeout
      ..autoUncompress = true;
    try {
      final remaining = _remaining(deadline);
      final request = await client
          .getUrl(target)
          .timeout(
            remaining,
            onTimeout: () =>
                throw const WebCalHttpException('WebCalTotalTimeout'),
          );
      request
        ..followRedirects = false
        ..maxRedirects = 0;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'text/calendar')
        ..removeAll(HttpHeaders.authorizationHeader)
        ..removeAll(HttpHeaders.cookieHeader)
        ..removeAll(HttpHeaders.refererHeader)
        ..removeAll('Origin');
      if (validators.etag != null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, validators.etag!);
      }
      if (validators.lastModified != null) {
        request.headers.set(
          HttpHeaders.ifModifiedSinceHeader,
          validators.lastModified!,
        );
      }
      final response = await request.close().timeout(
        _remaining(deadline),
        onTimeout: () => throw const WebCalHttpException('WebCalTotalTimeout'),
      );
      final redirectLocation = switch (response.headers.value(
        HttpHeaders.locationHeader,
      )) {
        final value? => Uri.tryParse(value),
        null => null,
      };
      Uint8List? body;
      if (response.statusCode != HttpStatus.notModified &&
          !_redirectStatuses.contains(response.statusCode)) {
        body = await _readLimitedBody(
          response,
          deadline: deadline,
          inactivityTimeout: limits.streamInactivityTimeout,
          maximumBytes: limits.maximumDecodedBodyBytes,
        );
      }
      return _SingleResponse(
        statusCode: response.statusCode,
        finalUri: target,
        body: body,
        etag: response.headers.value(HttpHeaders.etagHeader),
        lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
        contentType: response.headers.value(HttpHeaders.contentTypeHeader),
        conditionalRequestSent: !validators.isEmpty,
        redirectLocation: redirectLocation,
      );
    } on WebCalHttpException {
      rethrow;
    } on TimeoutException {
      throw const WebCalHttpException('WebCalNetworkTimeout');
    } on SocketException {
      throw const WebCalHttpException('WebCalNetworkFailure');
    } on HttpException {
      throw const WebCalHttpException('WebCalNetworkFailure');
    } finally {
      client.close(force: true);
    }
  }
}

const _redirectStatuses = <int>{301, 302, 303, 307, 308};

void _requireHttpsTarget(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const WebCalHttpException('WebCalRedirectTargetNotAllowed');
  }
}

Future<Uint8List> _readLimitedBody(
  HttpClientResponse response, {
  required DateTime deadline,
  required Duration inactivityTimeout,
  required int maximumBytes,
}) async {
  final builder = BytesBuilder(copy: false);
  final iterator = StreamIterator<List<int>>(response);
  try {
    while (true) {
      final remaining = _remaining(deadline);
      final limitedByDeadline = remaining <= inactivityTimeout;
      final wait = limitedByDeadline ? remaining : inactivityTimeout;
      final hasNext = await iterator.moveNext().timeout(
        wait,
        onTimeout: () => throw WebCalHttpException(
          limitedByDeadline
              ? 'WebCalTotalTimeout'
              : 'WebCalStreamInactivityTimeout',
        ),
      );
      if (!hasNext) break;
      final chunk = iterator.current;
      if (builder.length + chunk.length > maximumBytes) {
        throw const WebCalHttpException('WebCalBodyTooLarge');
      }
      builder.add(chunk);
    }
  } finally {
    await iterator.cancel();
  }
  return builder.takeBytes();
}

Duration _remaining(DateTime deadline) {
  final value = deadline.difference(DateTime.now());
  if (value <= Duration.zero) {
    throw const WebCalHttpException('WebCalTotalTimeout');
  }
  return value;
}

final class _SingleResponse extends WebCalHttpResponse {
  const _SingleResponse({
    required super.statusCode,
    required super.finalUri,
    required super.body,
    required super.etag,
    required super.lastModified,
    required super.contentType,
    required super.conditionalRequestSent,
    required this.redirectLocation,
  });

  final Uri? redirectLocation;
}

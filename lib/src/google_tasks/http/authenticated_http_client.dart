import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../core/logging/redacting_logger.dart';
import '../oauth/oauth_models.dart';
import '../oauth/oauth_service.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({
    required http.Client inner,
    required OAuthService oAuthService,
    DateTime Function()? nowUtc,
  }) : _inner = inner,
       _oAuthService = oAuthService,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final http.Client _inner;
  final OAuthService _oAuthService;
  final DateTime Function() _nowUtc;
  final _logger = RedactingLogger(Logger('AuthenticatedHttpClient'));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    var tokenSet = await _validTokenSet();
    var response = await _sendBuffered(request, bodyBytes, tokenSet);

    if (response.statusCode == 401) {
      _logger.warning('${request.method} ${request.url.path} returned 401');
      await response.stream.drain<void>();
      tokenSet = await _oAuthService.refreshActiveToken();
      response = await _sendBuffered(request, bodyBytes, tokenSet);
    }

    return response;
  }

  Future<OAuthTokenSet> _validTokenSet() async {
    final tokenSet = await _oAuthService.readActiveTokenSet();
    if (tokenSet == null) {
      throw const OAuthException(
        'OAuthMissingToken',
        'No active OAuth token is available.',
      );
    }

    if (tokenSet.expiresWithin(const Duration(seconds: 60), _nowUtc())) {
      return _oAuthService.refreshActiveToken();
    }

    return tokenSet;
  }

  Future<http.StreamedResponse> _sendBuffered(
    http.BaseRequest original,
    List<int> bodyBytes,
    OAuthTokenSet tokenSet,
  ) {
    final request = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..headers[authorizationHeaderName] = 'Bearer ${tokenSet.accessToken}'
      ..bodyBytes = bodyBytes;

    _logger.fine('${request.method} ${request.url.path}');
    return _inner.send(request);
  }
}

const authorizationHeaderName = 'Authorization';

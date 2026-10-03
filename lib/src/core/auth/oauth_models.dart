import 'dart:convert';

/// Decoding failures never include a provider response body in exception text.
Map<String, Object?> decodeOAuthProviderObject(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } on Object {
    /* safely classified below */
  }
  throw const OAuthException(
    'OAuthTemporaryResponse',
    'The provider returned an invalid authorization response. Try again.',
  );
}

/// OAuth token record shared by the Google and Microsoft adapters.
class OAuthTokenSet {
  const OAuthTokenSet({
    required this.accessToken,
    required this.expiresAtUtc,
    required this.tokenType,
    required this.scopes,
    this.refreshToken,
    this.idToken,
  });

  factory OAuthTokenSet.fromTokenEndpointJson(
    Map<String, Object?> json, {
    required DateTime issuedAtUtc,
    String? existingRefreshToken,
    String? existingIdToken,
    Set<String>? existingScopes,
    String? fallbackScopeText,
  }) {
    final accessToken = json['access_token'];
    final expiresIn = json['expires_in'];
    final expiresInSeconds = expiresIn is int
        ? expiresIn
        : expiresIn is String
        ? int.tryParse(expiresIn)
        : null;
    if (accessToken is! String ||
        accessToken.trim().isEmpty ||
        expiresInSeconds == null ||
        expiresInSeconds <= 0 ||
        (json['refresh_token'] != null && json['refresh_token'] is! String) ||
        (json['id_token'] != null && json['id_token'] is! String) ||
        (json['scope'] != null && json['scope'] is! String)) {
      throw const OAuthException(
        'OAuthTemporaryResponse',
        'The provider returned an incomplete authorization response. Try again.',
      );
    }
    final responseScopes = _scopesFromText(json['scope']?.toString());
    final fallbackScopes = _scopesFromText(fallbackScopeText);
    final scopes = responseScopes.isNotEmpty
        ? responseScopes
        : existingScopes?.isNotEmpty == true
        ? Set<String>.of(existingScopes!)
        : fallbackScopes;

    return OAuthTokenSet(
      accessToken: accessToken,
      refreshToken: json['refresh_token']?.toString().isNotEmpty == true
          ? json['refresh_token']!.toString()
          : existingRefreshToken,
      idToken: json['id_token']?.toString().isNotEmpty == true
          ? json['id_token']!.toString()
          : existingIdToken,
      expiresAtUtc: issuedAtUtc.add(Duration(seconds: expiresInSeconds)),
      tokenType: json['token_type']?.toString().isNotEmpty == true
          ? json['token_type']!.toString()
          : 'Bearer',
      scopes: scopes,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime expiresAtUtc;
  final String tokenType;
  final Set<String> scopes;

  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;

  bool expiresWithin(Duration duration, DateTime nowUtc) {
    return expiresAtUtc.isBefore(nowUtc.toUtc().add(duration));
  }

  OAuthTokenSet copyWith({
    String? accessToken,
    String? refreshToken,
    String? idToken,
    DateTime? expiresAtUtc,
    String? tokenType,
    Set<String>? scopes,
  }) {
    return OAuthTokenSet(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      idToken: idToken ?? this.idToken,
      expiresAtUtc: expiresAtUtc ?? this.expiresAtUtc,
      tokenType: tokenType ?? this.tokenType,
      scopes: scopes ?? this.scopes,
    );
  }
}

Set<String> _scopesFromText(String? scopeText) {
  return (scopeText ?? '')
      .split(RegExp(r'\s+'))
      .where((scope) => scope.isNotEmpty)
      .toSet();
}

class OAuthCallbackResult {
  const OAuthCallbackResult({required this.code, required this.scope});

  final String code;
  final String? scope;
}

enum OAuthFailureKind {
  configuration,
  wrongAccount,
  permission,
  storage,
  corruptRecord,
  expiredGrant,
  cancelled,
  timeout,
  throttled,
  temporary,
  stale,
  alreadyConnected,
}

class OAuthException implements Exception {
  const OAuthException(this.code, this.message);

  final String code;
  final String message;
  OAuthFailureKind get classification => switch (code) {
    'OAuthWrongAccount' => OAuthFailureKind.wrongAccount,
    'OAuthSignInCancelled' => OAuthFailureKind.cancelled,
    'OAuthStaleAuthorization' => OAuthFailureKind.stale,
    'OAuthAccountAlreadyConnected' => OAuthFailureKind.alreadyConnected,
    'OAuthMissingRequiredScope' ||
    'MicrosoftOAuthMissingRequiredScope' ||
    'OAuthMissingRefreshToken' ||
    'MicrosoftOAuthMissingRefreshToken' => OAuthFailureKind.permission,
    'OAuthCallbackTimeout' || 'OAuthRequestTimeout' => OAuthFailureKind.timeout,
    'OAuthSetupRequired' ||
    'OAuthRegistrationUnresolved' ||
    'OAuthConfigurationRejected' ||
    'OAuthConfigurationExpired' ||
    'OAuthWrongClientType' ||
    'OAuthConfigurationMalformed' ||
    'OAuthConfigurationTooLarge' ||
    'OAuthUnsupportedFileSource' ||
    'OAuthConfigurationUnreadable' => OAuthFailureKind.configuration,
    _ => OAuthFailureKind.temporary,
  };

  @override
  String toString() => '$code: $message';
}

class OAuthRefreshException extends OAuthException {
  const OAuthRefreshException(
    super.code,
    super.message, {
    required this.statusCode,
    this.oauthError,
    this.oauthErrorDescription,
    this.retryAfter,
  });

  final int statusCode;
  final Duration? retryAfter;
  @override
  OAuthFailureKind get classification {
    if (statusCode == 429) return OAuthFailureKind.throttled;
    if (statusCode != 400 && statusCode != 401) {
      return OAuthFailureKind.temporary;
    }
    return switch (oauthError) {
      'invalid_grant' => OAuthFailureKind.expiredGrant,
      'invalid_client' ||
      'unauthorized_client' ||
      'invalid_scope' => OAuthFailureKind.configuration,
      'access_denied' => OAuthFailureKind.permission,
      _ => OAuthFailureKind.temporary,
    };
  }

  /// The structured OAuth `error` value returned by the provider.
  final String? oauthError;

  /// The provider's redacted OAuth `error_description`, when present.
  final String? oauthErrorDescription;
}

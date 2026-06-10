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
    final expiresIn = json['expires_in'];
    final expiresInSeconds = expiresIn is int
        ? expiresIn
        : int.parse(expiresIn?.toString() ?? '0');
    final responseScopes = _scopesFromText(json['scope']?.toString());
    final fallbackScopes = _scopesFromText(fallbackScopeText);
    final scopes = responseScopes.isNotEmpty
        ? responseScopes
        : existingScopes?.isNotEmpty == true
        ? Set<String>.of(existingScopes!)
        : fallbackScopes;

    return OAuthTokenSet(
      accessToken: json['access_token']?.toString() ?? '',
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

class OAuthException implements Exception {
  const OAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class OAuthRefreshException extends OAuthException {
  const OAuthRefreshException(
    super.code,
    super.message, {
    required this.statusCode,
  });

  final int statusCode;
}

import 'dart:collection';
import '../auth/oauth_models.dart';

/// A request failure that is known to have happened before the HTTP client
/// forwarded the request to the network.
///
/// Creation replay may safely retain and retry an operation only when the
/// boundary that prevented dispatch supplies this explicit proof.
enum RequestPreDispatchFailureKind { authentication, connectivity }

abstract interface class RequestNotDispatchedException implements Exception {
  RequestPreDispatchFailureKind get kind;
  Object? get cause;
  String get code;
}

final class KnownUnsentRequestException
    implements RequestNotDispatchedException {
  const KnownUnsentRequestException({required this.kind, this.cause});

  @override
  final RequestPreDispatchFailureKind kind;
  @override
  final Object? cause;

  @override
  String get code => switch (kind) {
    RequestPreDispatchFailureKind.authentication =>
      'authentication_failed_before_dispatch',
    RequestPreDispatchFailureKind.connectivity =>
      'connectivity_failed_before_dispatch',
  };

  @override
  String toString() => 'KnownUnsentRequestException($code)';
}

final class AuthorizationScopedFailure implements Exception {
  const AuthorizationScopedFailure({
    required this.accountId,
    required this.generation,
    required this.cause,
  });
  final String accountId;
  final int generation;
  final Object cause;
  @override
  String toString() =>
      'Synchronization failed for the authorization used by this operation.';
}

/// Retains the typed, safe OAuth UI error while attaching the authorization
/// that was actually used by optional consent.
final class AuthorizationScopedOAuthException extends OAuthException {
  AuthorizationScopedOAuthException({
    required this.accountId,
    required this.generation,
    required this.cause,
  }) : super(cause.code, cause.message);
  final String accountId;
  final int generation;
  final OAuthException cause;
  @override
  OAuthFailureKind get classification => cause.classification;
}

int? failureAuthorizationGeneration(Object error, String id) {
  var current = error;
  for (var i = 0; i < 8; i++) {
    if (current is AuthorizationScopedFailure) {
      return current.accountId == id ? current.generation : null;
    }
    if (current is AuthorizationScopedOAuthException) {
      return current.accountId == id ? current.generation : null;
    }
    if (current is! RequestNotDispatchedException || current.cause == null) {
      return null;
    }
    current = current.cause!;
  }
  return null;
}

/// Resolves the substantive failure while preserving pre-dispatch wrappers.
///
/// Classification and user messaging can inspect the returned cause without
/// weakening the wrapper's replay-safety guarantee. Malformed cause graphs are
/// bounded and identity-checked so they cannot loop forever.
Object resolveEffectiveSyncFailure(Object error) {
  const maximumCauseDepth = 8;
  final visited = HashSet<Object>.identity();
  var current = error;

  for (var depth = 0; depth < maximumCauseDepth; depth += 1) {
    if (!visited.add(current)) {
      return current;
    }
    if (current is AuthorizationScopedFailure) {
      current = current.cause;
      continue;
    }
    if (current is AuthorizationScopedOAuthException) {
      current = current.cause;
      continue;
    }
    if (current is! RequestNotDispatchedException || current.cause == null) {
      return current;
    }
    current = current.cause!;
  }

  return current;
}

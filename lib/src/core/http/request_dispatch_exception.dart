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

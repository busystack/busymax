import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busystack_dav/busystack_dav.dart' as dav;
import 'package:http/http.dart' as http;

import '../../core/http/native_terminating_http_client.dart';
import '../../core/http/terminating_http_client.dart';
import '../../features/connectivity/network_connectivity_service.dart';
import 'nextcloud_certificate.dart';
import 'nextcloud_trust_policy.dart';

enum NextcloudCertificateFailure {
  approvalRequired,
  pinMismatch,
  expired,
  notYetValid,
  hostnameMismatch,
  invalidPolicy,
  ineligible,
  verificationFailed,
}

/// This proof is created only while establishing/validating a TLS socket,
/// before it is handed to HttpClient. It must never wrap a response failure.
final class NextcloudCertificateException extends dav.DavException
    implements dav.DavRequestNotDispatchedException {
  NextcloudCertificateException(
    this.failure, {
    this.observed,
    this.previous,
    required this.endpoint,
  }) : super(
         kind: dav.DavErrorKind.tls,
         code: 'NextcloudCertificate${failure.name}',
         safeMessage: 'Review the Nextcloud server certificate.',
       );
  final NextcloudCertificateFailure failure;
  final NextcloudCertificate? observed;
  final NextcloudTrustPolicy? previous;
  final Uri endpoint;
}

/// TLS ended before a validated socket was available, with no observed
/// certificate rejection. HTTP never received the socket or dispatched bytes.
final class _NextcloudConnectionNotDispatched extends dav.DavException
    implements dav.DavRequestNotDispatchedException {
  const _NextcloudConnectionNotDispatched()
    : super(
        kind: dav.DavErrorKind.network,
        code: 'DavNetworkFailure',
        safeMessage: 'The DAV server could not be reached.',
      );
}

/// Owns account/session clients; it never changes SecurityContext.defaultContext
/// or the application's global client. Every native attempt has the same
/// immutable policy, including connection-establishment cancellation attempts.
final class NextcloudHttpClientFactory {
  NextcloudHttpClientFactory({required this.requireNetwork, this.findProxy});
  final Future<void> Function() requireNetwork;
  final String Function(Uri)? findProxy;
  final Map<String, Set<http.Client>> _clients = {};

  /// A management-only observation, never a substitute for validation on the
  /// authenticated socket. No HTTP bytes or credentials are sent by this probe.
  Future<NextcloudCertificate> observe(Uri endpoint) async {
    await requireNetwork();
    NextcloudCertificate? observed;
    if (endpoint.scheme != 'https' || endpoint.userInfo.isNotEmpty) {
      throw const FormatException('Nextcloud requires HTTPS.');
    }
    final task = await SecureSocket.startConnect(
      endpoint.host,
      endpoint.port,
      context: SecurityContext(withTrustedRoots: false),
      onBadCertificate: (cert) {
        try {
          observed = NextcloudCertificate.der(cert.der);
        } on Object {
          // Malformed input is rejected without throwing from the TLS callback.
        }
        return false;
      },
    );
    try {
      final socket = await task.socket.timeout(const Duration(seconds: 15));
      socket.destroy();
    } on TlsException {
      if (observed == null) rethrow;
    } finally {
      task.cancel();
    }
    return observed ??
        (throw const FormatException('No server certificate received.'));
  }

  http.Client create({
    required String owner,
    required Uri authority,
    NextcloudTrustPolicy? policy,
    bool reuseConnections = false,
  }) {
    try {
      policy?.requireScope(owner, authority);
    } on Object {
      throw NextcloudCertificateException(
        NextcloudCertificateFailure.invalidPolicy,
        endpoint: authority,
      );
    }
    final clients = _clients.putIfAbsent(owner, () => {});
    final peers = <SecureSocket, NextcloudCertificate>{};
    NextcloudCertificate? proxyRejected;
    late final _ScopedClient scoped;
    scoped = _ScopedClient(
      authority: authority,
      validate: () {
        proxyRejected = null;
        if (policy == null) return;
        try {
          for (final certificate in policy.certificates) {
            if (policy.mode == NextcloudTrustMode.privateCa) {
              certificate.validateCa();
            } else {
              certificate.validateServer(authority.host, selfSigned: true);
            }
          }
          for (final peer in peers.values) {
            peer.validateServer(
              authority.host,
              selfSigned: policy.mode == NextcloudTrustMode.pinnedLeaf,
            );
          }
        } on Object catch (error) {
          throw _failure(error, authority, policy, null);
        }
      },
      tlsFailure: (error) => _failure(error, authority, policy, proxyRejected),
      inner: ConnectivityAwareHttpClient(
        requireNetwork: requireNetwork,
        inner: NativeTerminatingHttpClient(
          reuseConnections: reuseConnections,
          nativeClientFactory: () => _native(
            authority,
            policy,
            onPeer: (socket, peer) {
              peers[socket] = peer;
              // Closed connections must not retain an obsolete leaf after a
              // private CA renews it. Only live pooled sockets need checking.
              unawaited(
                socket.done.then<void>(
                  (_) {
                    peers.remove(socket);
                  },
                  onError: (Object _, StackTrace _) {
                    peers.remove(socket);
                  },
                ),
              );
            },
            onProxyRejected: (peer) => proxyRejected = peer,
          ),
        ),
      ),
      onClose: () => clients.remove(scoped),
    );
    clients.add(scoped);
    return scoped;
  }

  void invalidate(String owner) {
    for (final client in _clients.remove(owner)?.toList() ?? <http.Client>[]) {
      client.close();
    }
  }

  void close() {
    for (final owner in _clients.keys.toList()) {
      invalidate(owner);
    }
  }

  HttpClient _native(
    Uri authority,
    NextcloudTrustPolicy? policy, {
    required void Function(SecureSocket, NextcloudCertificate) onPeer,
    required void Function(NextcloudCertificate) onProxyRejected,
  }) {
    final context = SecurityContext(
      withTrustedRoots: policy?.mode != NextcloudTrustMode.pinnedLeaf,
    );
    try {
      for (final certificate
          in policy?.certificates ?? <NextcloudCertificate>[]) {
        if (policy!.mode == NextcloudTrustMode.privateCa) {
          certificate.validateCa();
        } else {
          certificate.validateServer(authority.host, selfSigned: true);
        }
        context.setTrustedCertificatesBytes(utf8.encode(certificate.pem));
      }
    } on Object catch (error) {
      if (policy?.mode == NextcloudTrustMode.privateCa) {
        throw NextcloudCertificateException(
          NextcloudCertificateFailure.invalidPolicy,
          endpoint: authority,
          previous: policy,
        );
      }
      throw _failure(error, authority, policy, policy?.certificates.first);
    }
    final client = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 15);
    if (findProxy != null) client.findProxy = findProxy;
    client.badCertificateCallback = (certificate, host, port) {
      try {
        onProxyRejected(NextcloudCertificate.der(certificate.der));
      } on Object {
        // Native verification still rejects malformed certificates.
      }
      return false;
    };
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null) {
        // Dart performs CONNECT and platform TLS validation after connecting to
        // the proxy. A pinned peer cannot be inspected before HTTP on this path.
        if (policy != null) {
          throw const dav.DavException(
            kind: dav.DavErrorKind.network,
            code: 'NextcloudPrivateTrustProxyUnsupported',
            safeMessage: 'Private-certificate connections require a direct connection. Configure a proxy bypass for this server.',
          );
        }
        return Socket.startConnect(proxyHost, proxyPort!);
      }
      if (policy?.mode == NextcloudTrustMode.privateCa) {
        try {
          for (final certificate in policy!.certificates) {
            certificate.validateCa();
          }
        } on Object {
          throw NextcloudCertificateException(
            NextcloudCertificateFailure.invalidPolicy,
            endpoint: authority,
            previous: policy,
          );
        }
      }
      NextcloudCertificate? observed;
      var malformed = false;
      final task = await SecureSocket.startConnect(
        uri.host,
        uri.port,
        context: context,
        onBadCertificate: (certificate) {
          try {
            observed = NextcloudCertificate.der(certificate.der);
          } on Object {
            malformed = true;
          }
          return false; // Review always happens after rejection, outside TLS.
        },
      );
      final socket = task.socket.then<Socket>(
        (socket) {
          try {
            // Public HTTPS uses native validation unchanged. Private-policy
            // eligibility limits must not restrict normally trusted services.
            if (policy == null) return socket;
            final peer = NextcloudCertificate.der(socket.peerCertificate!.der);
            if (policy.mode == NextcloudTrustMode.pinnedLeaf &&
                peer.fingerprint != policy.certificates.single.fingerprint) {
              throw NextcloudCertificateException(
                NextcloudCertificateFailure.pinMismatch,
                endpoint: authority,
                observed: peer,
                previous: policy,
              );
            }
            peer.validateServer(
              uri.host,
              selfSigned: policy.mode == NextcloudTrustMode.pinnedLeaf,
            );
            onPeer(socket, peer);
            return socket; // Only now can HttpClient construct/send HTTP bytes.
          } on Object catch (error) {
            socket.destroy();
            if (error is NextcloudCertificateException) rethrow;
            throw _failure(error, authority, policy, observed);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (error is TlsException) {
            if (malformed) {
              throw NextcloudCertificateException(
                NextcloudCertificateFailure.ineligible,
                endpoint: authority,
                previous: policy,
              );
            }
            if (observed == null) {
              throw const _NextcloudConnectionNotDispatched();
            }
            throw _failure(error, authority, policy, observed);
          }
          Error.throwWithStackTrace(error, stack);
        },
      );
      return ConnectionTask.fromSocket(socket, task.cancel);
    };
    return client;
  }

  NextcloudCertificateException _failure(
    Object error,
    Uri authority,
    NextcloudTrustPolicy? policy,
    NextcloudCertificate? observed,
  ) {
    var failure = policy == null
        ? NextcloudCertificateFailure.approvalRequired
        : NextcloudCertificateFailure.verificationFailed;
    if (observed != null) {
      if (policy?.mode == NextcloudTrustMode.pinnedLeaf &&
          observed.fingerprint != policy!.certificates.single.fingerprint) {
        failure = NextcloudCertificateFailure.pinMismatch;
      } else {
        try {
          observed.validateServer(
            authority.host,
            selfSigned:
                policy == null || policy.mode == NextcloudTrustMode.pinnedLeaf,
          );
        } on Object catch (eligibility) {
          failure = _eligibilityFailure(eligibility);
        }
      }
    } else if (error is FormatException) {
      failure = _eligibilityFailure(error);
    }
    return NextcloudCertificateException(
      failure,
      endpoint: authority,
      observed: observed,
      previous: policy,
    );
  }
}

NextcloudCertificateFailure _eligibilityFailure(Object error) {
  final message = error is FormatException ? error.message : '';
  return switch (message) {
    'certificate-expired' => NextcloudCertificateFailure.expired,
    'certificate-not-yet-valid' => NextcloudCertificateFailure.notYetValid,
    'certificate-hostname-mismatch' =>
      NextcloudCertificateFailure.hostnameMismatch,
    _ => NextcloudCertificateFailure.ineligible,
  };
}

final class _ScopedClient extends http.BaseClient
    implements TerminatingHttpClient {
  _ScopedClient({
    required this.authority,
    required this.inner,
    required this.onClose,
    required this.validate,
    required this.tlsFailure,
  });
  final Uri authority;
  final TerminatingHttpClient inner;
  final void Function() onClose;
  final void Function() validate;
  final NextcloudCertificateException Function(Object) tlsFailure;
  bool _closed = false;
  void _check(http.BaseRequest request) {
    final uri = request.url;
    if (_closed) throw http.ClientException('Nextcloud client is closed.');
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != authority.host.toLowerCase() ||
        uri.port != authority.port) {
      throw const dav.DavException(
        kind: dav.DavErrorKind.redirectRejected,
        code: 'NextcloudTrustDestinationRejected',
        safeMessage: 'Use the approved Nextcloud HTTPS installation.',
      );
    }
    request.followRedirects =
        false; // Existing login/DAV policies own redirects.
    validate();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _check(request);
    try {
      return await inner.send(request);
    } on HandshakeException catch (error) {
      throw tlsFailure(error);
    }
  }

  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) async {
    _check(request);
    try {
      return await inner.sendTerminating(
        request,
        terminate: terminate,
        connectionTimeout: connectionTimeout,
      );
    } on HandshakeException catch (error) {
      throw tlsFailure(error);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    inner.close();
    onClose();
  }
}

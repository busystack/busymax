import 'package:busymax/src/dav/dav_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every required public DAV error category', () {
    final cases = <(DavException, DavErrorCategory)>[
      (
        _error(DavErrorKind.authentication, 'DavAuthRejected'),
        DavErrorCategory.davAuthRejected,
      ),
      (
        _error(DavErrorKind.authentication, 'DavCredentialsRevoked'),
        DavErrorCategory.davCredentialsRevoked,
      ),
      (
        _error(DavErrorKind.tls, 'DavTlsFailure'),
        DavErrorCategory.davTlsFailure,
      ),
      (
        _error(DavErrorKind.protocol, 'DavDiscoveryFailed'),
        DavErrorCategory.davDiscoveryFailed,
      ),
      (
        _error(DavErrorKind.protocol, 'DavUnsupportedServer'),
        DavErrorCategory.davUnsupportedServer,
      ),
      (
        _error(DavErrorKind.authorization, 'DavPermissionDenied'),
        DavErrorCategory.davPermissionDenied,
      ),
      (
        _error(DavErrorKind.conflict, 'DavResourceConflict'),
        DavErrorCategory.davResourceConflict,
      ),
      (
        _error(DavErrorKind.uidConflict, 'DavUidConflict'),
        DavErrorCategory.davUidConflict,
      ),
      (
        _error(DavErrorKind.invalidCalendarData, 'DavMalformedResource'),
        DavErrorCategory.davMalformedResource,
      ),
      (
        _error(DavErrorKind.unsupportedComponent, 'DavUnsupportedComponent'),
        DavErrorCategory.davUnsupportedComponent,
      ),
      (
        _error(DavErrorKind.limitExceeded, 'DavQuotaOrSizeLimit'),
        DavErrorCategory.davQuotaOrSizeLimit,
      ),
      (
        _error(DavErrorKind.rateLimited, 'DavRateLimited'),
        DavErrorCategory.davRateLimited,
      ),
      (
        _error(DavErrorKind.network, 'DavNetworkFailure'),
        DavErrorCategory.davTransientNetwork,
      ),
      (
        _error(DavErrorKind.server, 'DavServerUnavailable'),
        DavErrorCategory.davServerUnavailable,
      ),
      (
        _error(DavErrorKind.invalidSyncToken, 'DavSyncTokenInvalid'),
        DavErrorCategory.davSyncTokenInvalid,
      ),
      (
        _error(DavErrorKind.notFound, 'DavCollectionRemoved'),
        DavErrorCategory.davCollectionRemoved,
      ),
      (
        _error(DavErrorKind.authorization, 'DavReadOnly'),
        DavErrorCategory.davReadOnly,
      ),
      (
        _error(DavErrorKind.protocol, 'DavProtocolViolation'),
        DavErrorCategory.davProtocolViolation,
      ),
    ];

    for (final entry in cases) {
      expect(entry.$1.category, entry.$2, reason: entry.$1.code);
    }
  });

  test('exposes retry, user-action, and cached-data disposition', () {
    final credentials = _error(
      DavErrorKind.authentication,
      'DavCredentialsRevoked',
    );
    expect(credentials.retryable, isFalse);
    expect(credentials.requiresUserAction, isTrue);
    expect(credentials.cachedDataUsable, isTrue);

    final unavailable = _error(DavErrorKind.server, 'DavServerUnavailable');
    expect(unavailable.retryable, isTrue);
    expect(unavailable.requiresUserAction, isFalse);
    expect(unavailable.cachedDataUsable, isTrue);

    final malformed = _error(
      DavErrorKind.invalidCalendarData,
      'DavMalformedResource',
    );
    expect(malformed.retryable, isFalse);
    expect(malformed.requiresUserAction, isFalse);
    expect(malformed.cachedDataUsable, isFalse);
  });

  test('parses bounded Retry-After delta seconds and HTTP dates', () {
    final now = DateTime.utc(2026, 8, 8, 12);

    expect(parseDavRetryAfter('90', nowUtc: now), const Duration(seconds: 90));
    expect(
      parseDavRetryAfter('Sat, 08 Aug 2026 12:00:30 GMT', nowUtc: now),
      const Duration(seconds: 30),
    );
    expect(parseDavRetryAfter('-1', nowUtc: now), isNull);
    expect(parseDavRetryAfter('not-a-date', nowUtc: now), isNull);
    expect(
      parseDavRetryAfter('999999', nowUtc: now),
      const Duration(hours: 24),
    );
  });
}

DavException _error(DavErrorKind kind, String code) =>
    DavException(kind: kind, code: code, safeMessage: 'Safe message.');

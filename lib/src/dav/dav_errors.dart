import 'dart:io';

enum DavErrorKind {
  cancelled,
  timeout,
  network,
  tls,
  authentication,
  authorization,
  redirectRejected,
  redirectLoop,
  responseTooLarge,
  malformedXml,
  malformedStatus,
  protocol,
  rateLimited,
  invalidSyncToken,
  preconditionFailed,
  uidConflict,
  invalidCalendarData,
  unsupportedComponent,
  maximumResourceSize,
  limitExceeded,
  notFound,
  conflict,
  server,
}

/// DAV failure categories used by retry policy and user-facing error handling.
enum DavErrorCategory {
  davAuthRejected,
  davCredentialsRevoked,
  davTlsFailure,
  davDiscoveryFailed,
  davUnsupportedServer,
  davPermissionDenied,
  davResourceConflict,
  davUidConflict,
  davMalformedResource,
  davUnsupportedComponent,
  davQuotaOrSizeLimit,
  davRateLimited,
  davTransientNetwork,
  davServerUnavailable,
  davSyncTokenInvalid,
  davCollectionRemoved,
  davReadOnly,
  davProtocolViolation,
  davOperationCancelled,
}

final class DavErrorDisposition {
  const DavErrorDisposition({
    required this.category,
    required this.retryable,
    required this.requiresUserAction,
    required this.cachedDataUsable,
  });

  final DavErrorCategory category;
  final bool retryable;
  final bool requiresUserAction;
  final bool cachedDataUsable;
}

/// A typed DAV failure whose diagnostic representation excludes request URLs,
/// response bodies, credentials, and user calendar content.
final class DavException implements Exception {
  const DavException({
    required this.kind,
    required this.code,
    required this.safeMessage,
    this.statusCode,
    this.correlationId,
    this.retryAfter,
    this.categoryOverride,
  });

  final DavErrorKind kind;
  final String code;
  final String safeMessage;
  final int? statusCode;
  final String? correlationId;
  final Duration? retryAfter;
  final DavErrorCategory? categoryOverride;

  DavErrorDisposition get disposition => classifyDavError(
    kind: kind,
    code: code,
    statusCode: statusCode,
    categoryOverride: categoryOverride,
  );

  DavErrorCategory get category => disposition.category;
  bool get retryable => disposition.retryable;
  bool get requiresUserAction => disposition.requiresUserAction;
  bool get cachedDataUsable => disposition.cachedDataUsable;

  @override
  String toString() =>
      'DavException(kind: ${kind.name}, code: $code, '
      'statusCode: $statusCode, correlationId: $correlationId)';
}

DavErrorDisposition classifyDavError({
  required DavErrorKind kind,
  required String code,
  int? statusCode,
  DavErrorCategory? categoryOverride,
}) {
  final category =
      categoryOverride ??
      _categoryFor(kind: kind, code: code, statusCode: statusCode);
  final retryable = switch (category) {
    DavErrorCategory.davRateLimited ||
    DavErrorCategory.davTransientNetwork ||
    DavErrorCategory.davServerUnavailable => true,
    DavErrorCategory.davDiscoveryFailed =>
      kind == DavErrorKind.timeout ||
          kind == DavErrorKind.network ||
          kind == DavErrorKind.server ||
          kind == DavErrorKind.rateLimited,
    _ => false,
  };
  final requiresUserAction = switch (category) {
    DavErrorCategory.davAuthRejected ||
    DavErrorCategory.davCredentialsRevoked ||
    DavErrorCategory.davTlsFailure ||
    DavErrorCategory.davUnsupportedServer ||
    DavErrorCategory.davPermissionDenied ||
    DavErrorCategory.davResourceConflict ||
    DavErrorCategory.davUidConflict ||
    DavErrorCategory.davReadOnly => true,
    DavErrorCategory.davDiscoveryFailed => !retryable,
    _ => false,
  };
  final cachedDataUsable = switch (category) {
    DavErrorCategory.davMalformedResource ||
    DavErrorCategory.davUnsupportedComponent ||
    DavErrorCategory.davCollectionRemoved => false,
    _ => true,
  };
  return DavErrorDisposition(
    category: category,
    retryable: retryable,
    requiresUserAction: requiresUserAction,
    cachedDataUsable: cachedDataUsable,
  );
}

DavErrorCategory _categoryFor({
  required DavErrorKind kind,
  required String code,
  required int? statusCode,
}) {
  final normalizedCode = code.toLowerCase();
  if (normalizedCode.contains('credentialsrevoked')) {
    return DavErrorCategory.davCredentialsRevoked;
  }
  if (normalizedCode.contains('authrejected')) {
    return DavErrorCategory.davAuthRejected;
  }
  if (normalizedCode.contains('unsupportedserver') ||
      normalizedCode.contains('unsupportedprofile')) {
    return DavErrorCategory.davUnsupportedServer;
  }
  if (normalizedCode.contains('discoveryfailed')) {
    return DavErrorCategory.davDiscoveryFailed;
  }
  if (normalizedCode.contains('permissiondenied')) {
    return DavErrorCategory.davPermissionDenied;
  }
  if (normalizedCode.contains('readonly')) {
    return DavErrorCategory.davReadOnly;
  }
  if (normalizedCode.contains('uidconflict')) {
    return DavErrorCategory.davUidConflict;
  }
  if (normalizedCode.contains('resourceconflict') ||
      normalizedCode.contains('resourcelocked') ||
      normalizedCode.startsWith('davconflict')) {
    return DavErrorCategory.davResourceConflict;
  }
  if (normalizedCode.contains('malformedresource')) {
    return DavErrorCategory.davMalformedResource;
  }
  if (normalizedCode.contains('unsupportedcomponent')) {
    return DavErrorCategory.davUnsupportedComponent;
  }
  if (normalizedCode.contains('quotaorsizelimit') ||
      normalizedCode.contains('maximumresourcesize')) {
    return DavErrorCategory.davQuotaOrSizeLimit;
  }
  if (normalizedCode.contains('ratelimited')) {
    return DavErrorCategory.davRateLimited;
  }
  if (normalizedCode.contains('tlsfailure')) {
    return DavErrorCategory.davTlsFailure;
  }
  if (normalizedCode.contains('networkfailure') ||
      normalizedCode.contains('timeout')) {
    return DavErrorCategory.davTransientNetwork;
  }
  if (normalizedCode.contains('serverunavailable')) {
    return DavErrorCategory.davServerUnavailable;
  }
  if (normalizedCode.contains('synctokeninvalid')) {
    return DavErrorCategory.davSyncTokenInvalid;
  }
  if (normalizedCode.contains('collectionremoved') ||
      normalizedCode.contains('collectionnotfound')) {
    return DavErrorCategory.davCollectionRemoved;
  }

  if (statusCode != null) {
    if (statusCode == HttpStatus.unauthorized) {
      return DavErrorCategory.davAuthRejected;
    }
    if (statusCode == HttpStatus.forbidden) {
      return DavErrorCategory.davPermissionDenied;
    }
    if (statusCode == HttpStatus.notFound || statusCode == HttpStatus.gone) {
      return DavErrorCategory.davCollectionRemoved;
    }
    if (statusCode == HttpStatus.conflict ||
        statusCode == HttpStatus.preconditionFailed ||
        statusCode == HttpStatus.locked) {
      return DavErrorCategory.davResourceConflict;
    }
    if (statusCode == HttpStatus.tooManyRequests) {
      return DavErrorCategory.davRateLimited;
    }
    if (statusCode == HttpStatus.insufficientStorage) {
      return DavErrorCategory.davQuotaOrSizeLimit;
    }
    if (statusCode >= 500) {
      return DavErrorCategory.davServerUnavailable;
    }
  }

  return switch (kind) {
    DavErrorKind.cancelled => DavErrorCategory.davOperationCancelled,
    DavErrorKind.timeout ||
    DavErrorKind.network => DavErrorCategory.davTransientNetwork,
    DavErrorKind.tls => DavErrorCategory.davTlsFailure,
    DavErrorKind.authentication => DavErrorCategory.davAuthRejected,
    DavErrorKind.authorization => DavErrorCategory.davPermissionDenied,
    DavErrorKind.rateLimited => DavErrorCategory.davRateLimited,
    DavErrorKind.invalidSyncToken => DavErrorCategory.davSyncTokenInvalid,
    DavErrorKind.preconditionFailed ||
    DavErrorKind.conflict => DavErrorCategory.davResourceConflict,
    DavErrorKind.uidConflict => DavErrorCategory.davUidConflict,
    DavErrorKind.invalidCalendarData => DavErrorCategory.davMalformedResource,
    DavErrorKind.unsupportedComponent =>
      DavErrorCategory.davUnsupportedComponent,
    DavErrorKind.maximumResourceSize ||
    DavErrorKind.limitExceeded ||
    DavErrorKind.responseTooLarge => DavErrorCategory.davQuotaOrSizeLimit,
    DavErrorKind.notFound => DavErrorCategory.davCollectionRemoved,
    DavErrorKind.server => DavErrorCategory.davServerUnavailable,
    DavErrorKind.redirectRejected ||
    DavErrorKind.redirectLoop ||
    DavErrorKind.malformedXml ||
    DavErrorKind.malformedStatus ||
    DavErrorKind.protocol => DavErrorCategory.davProtocolViolation,
  };
}

/// Parses a server retry hint without including the original header in an
/// exception or log message.
Duration? parseDavRetryAfter(
  String? value, {
  DateTime? nowUtc,
  Duration maximum = const Duration(hours: 24),
}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  Duration? result;
  final seconds = int.tryParse(trimmed);
  if (seconds != null) {
    if (seconds < 0) return null;
    result = Duration(seconds: seconds);
  } else {
    try {
      final deadline = HttpDate.parse(trimmed).toUtc();
      result = deadline.difference((nowUtc ?? DateTime.now().toUtc()).toUtc());
      if (result.isNegative) result = Duration.zero;
    } on Object {
      return null;
    }
  }
  return result > maximum ? maximum : result;
}

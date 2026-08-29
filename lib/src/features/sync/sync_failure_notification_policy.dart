import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/auth/oauth_models.dart';
import '../../dav/dav_errors.dart';
import '../../dav/sync/dav_account_sync_engine.dart';
import '../../google_calendar/google_calendar_errors.dart';
import '../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../microsoft_todo/api/microsoft_todo_api_error.dart';
import '../tasks/domain/task_remote_error.dart';
import '../connectivity/network_connectivity_service.dart';
import 'sync_auth_error.dart';

enum SyncFailureNotificationDisposition {
  suppressed,
  reconnectRequired,
  permissionChanged,
  unsupportedProvider,
  temporarilyUnavailable,
}

SyncFailureNotificationDisposition syncFailureNotificationDisposition(
  Object error,
) {
  if (error is DavAccountSyncException) {
    return _aggregateDavFailures(error.failures);
  }
  if (error is DavException) {
    return _davDisposition(error);
  }
  if (error is NetworkUnavailableException ||
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return SyncFailureNotificationDisposition.suppressed;
  }
  if (error is TaskRemoteError) {
    if (error.retryable) {
      return SyncFailureNotificationDisposition.suppressed;
    }
    return _httpDisposition(error.statusCode);
  }
  if (error is GoogleCalendarApiError) {
    return _httpDisposition(error.statusCode);
  }
  if (error is MicrosoftCalendarApiError) {
    return _httpDisposition(error.statusCode);
  }
  if (error is MicrosoftTodoApiError) {
    return _httpDisposition(error.statusCode);
  }
  if (error is OAuthRefreshException) {
    return _httpDisposition(
      error.statusCode,
      badRequestRequiresReconnect: true,
    );
  }
  if (isMissingOAuthTokenError(error)) {
    return SyncFailureNotificationDisposition.reconnectRequired;
  }
  if (error is OAuthException &&
      error.code.toLowerCase().contains('refreshfailed')) {
    return SyncFailureNotificationDisposition.reconnectRequired;
  }
  return SyncFailureNotificationDisposition.temporarilyUnavailable;
}

SyncFailureNotificationDisposition _aggregateDavFailures(
  List<DavException> failures,
) {
  var result = SyncFailureNotificationDisposition.suppressed;
  for (final failure in failures) {
    final current = _davDisposition(failure);
    if (_priority(current) > _priority(result)) {
      result = current;
    }
  }
  return failures.isEmpty
      ? SyncFailureNotificationDisposition.temporarilyUnavailable
      : result;
}

int _priority(SyncFailureNotificationDisposition disposition) {
  return switch (disposition) {
    SyncFailureNotificationDisposition.suppressed => 0,
    SyncFailureNotificationDisposition.temporarilyUnavailable => 1,
    SyncFailureNotificationDisposition.unsupportedProvider => 2,
    SyncFailureNotificationDisposition.permissionChanged => 3,
    SyncFailureNotificationDisposition.reconnectRequired => 4,
  };
}

SyncFailureNotificationDisposition _davDisposition(DavException error) {
  return switch (error.category) {
    DavErrorCategory.davOperationCancelled ||
    DavErrorCategory.davRateLimited ||
    DavErrorCategory.davTransientNetwork ||
    DavErrorCategory.davServerUnavailable =>
      SyncFailureNotificationDisposition.suppressed,
    DavErrorCategory.davAuthRejected ||
    DavErrorCategory.davCredentialsRevoked =>
      SyncFailureNotificationDisposition.reconnectRequired,
    DavErrorCategory.davPermissionDenied || DavErrorCategory.davReadOnly =>
      SyncFailureNotificationDisposition.permissionChanged,
    DavErrorCategory.davUnsupportedServer ||
    DavErrorCategory.davUnsupportedComponent ||
    DavErrorCategory.davProtocolViolation =>
      SyncFailureNotificationDisposition.unsupportedProvider,
    _ => SyncFailureNotificationDisposition.temporarilyUnavailable,
  };
}

SyncFailureNotificationDisposition _httpDisposition(
  int statusCode, {
  bool badRequestRequiresReconnect = false,
}) {
  if (statusCode == HttpStatus.unauthorized ||
      (badRequestRequiresReconnect && statusCode == HttpStatus.badRequest)) {
    return SyncFailureNotificationDisposition.reconnectRequired;
  }
  if (statusCode == HttpStatus.forbidden) {
    return SyncFailureNotificationDisposition.permissionChanged;
  }
  if (statusCode == HttpStatus.requestTimeout ||
      statusCode == 425 ||
      statusCode == HttpStatus.tooManyRequests ||
      statusCode >= HttpStatus.internalServerError) {
    return SyncFailureNotificationDisposition.suppressed;
  }
  return SyncFailureNotificationDisposition.temporarilyUnavailable;
}

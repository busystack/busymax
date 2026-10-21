import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../l10n/generated/app_localizations.dart';
import '../../../core/auth/oauth_models.dart';
import '../../../core/http/request_dispatch_exception.dart';
import '../../../core/secrets/secret_store.dart';
import '../../../dav/dav_errors.dart';
import '../../../dav/sync/dav_account_sync_engine.dart';
import '../../../features/connectivity/network_connectivity_service.dart';
import '../../../features/sync/sync_auth_error.dart';
import '../../../features/sync/sync_failure_notification_policy.dart';
import '../../../features/tasks/domain/task_remote_error.dart';
import '../../../google_calendar/google_calendar_errors.dart';
import '../../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../../microsoft_todo/api/microsoft_todo_api_error.dart';
import '../../../l10n/oauth_error_description.dart';

enum AccountSettingsRecovery {
  retry,
  reconnect,
  replaceRegistration,
  revalidate,
}

enum AccountSettingsFailure {
  network,
  authorization,
  registration,
  permissions,
  configuration,
  storage,
  temporary,
}

/// Presentation of typed outcomes and persisted DAV codes. Provider messages,
/// exception strings and correlation identifiers never become preference text.
class AccountSettingsFeedback {
  const AccountSettingsFeedback(this.kind, this.message, this.recovery);
  final AccountSettingsFailure kind;
  final String message;
  final AccountSettingsRecovery recovery;

  static AccountSettingsFeedback fromError(
    AppLocalizations l10n,
    Object error,
  ) {
    error = resolveEffectiveSyncFailure(error);
    if (error is DavAccountSyncException) {
      if (error.failures.isNotEmpty) {
        return fromError(l10n, error.failures.first);
      }
    }
    if (error is SecretStoreException ||
        error is DavException &&
            error.code == 'DavCredentialStoreUnavailable') {
      return AccountSettingsFeedback(
        AccountSettingsFailure.storage,
        l10n.oauthSecureStorageUnavailable,
        AccountSettingsRecovery.retry,
      );
    }
    if (error is OAuthException) {
      switch (error.classification) {
        case OAuthFailureKind.registrationUnavailable:
        case OAuthFailureKind.clientRejected:
        case OAuthFailureKind.configuration:
          return AccountSettingsFeedback(
            AccountSettingsFailure.registration,
            localizedOAuthFailure(
              l10n,
              error.classification,
              l10n.accountSyncProblem,
            ),
            AccountSettingsRecovery.replaceRegistration,
          );
        case OAuthFailureKind.network:
        case OAuthFailureKind.timeout:
          return _network(l10n);
        case OAuthFailureKind.permission:
          return AccountSettingsFeedback(
            AccountSettingsFailure.permissions,
            l10n.oauthPermissionRefused,
            AccountSettingsRecovery.reconnect,
          );
        case OAuthFailureKind.storage:
        case OAuthFailureKind.corruptRecord:
          return AccountSettingsFeedback(
            AccountSettingsFailure.storage,
            l10n.oauthSecureStorageUnavailable,
            AccountSettingsRecovery.retry,
          );
        default:
          if (isOAuthReconnectRequiredError(error)) {
            return AccountSettingsFeedback(
              AccountSettingsFailure.authorization,
              l10n.accountReconnectRequired,
              AccountSettingsRecovery.reconnect,
            );
          }
          return AccountSettingsFeedback(
            AccountSettingsFailure.temporary,
            localizedOAuthFailure(
              l10n,
              error.classification,
              l10n.accountSyncProblem,
            ),
            AccountSettingsRecovery.retry,
          );
      }
    }
    if (error is DavException) {
      switch (error.category) {
        case DavErrorCategory.davTransientNetwork:
        case DavErrorCategory.davTlsFailure:
          return _network(l10n);
        case DavErrorCategory.davAuthRejected:
        case DavErrorCategory.davCredentialsRevoked:
          return AccountSettingsFeedback(
            AccountSettingsFailure.authorization,
            l10n.accountReconnectRequired,
            AccountSettingsRecovery.reconnect,
          );
        case DavErrorCategory.davPermissionDenied:
        case DavErrorCategory.davReadOnly:
          return AccountSettingsFeedback(
            AccountSettingsFailure.permissions,
            l10n.davPermissionChanged,
            AccountSettingsRecovery.revalidate,
          );
        case DavErrorCategory.davUnsupportedServer:
        case DavErrorCategory.davUnsupportedComponent:
        case DavErrorCategory.davProtocolViolation:
          return AccountSettingsFeedback(
            AccountSettingsFailure.configuration,
            l10n.davUnsupportedServer,
            AccountSettingsRecovery.revalidate,
          );
        default:
          break;
      }
    }
    if (error is NetworkUnavailableException ||
        error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return _network(l10n);
    }
    final status = switch (error) {
      GoogleCalendarApiError(:final statusCode) => statusCode,
      MicrosoftCalendarApiError(:final statusCode) => statusCode,
      MicrosoftTodoApiError(:final statusCode) => statusCode,
      TaskRemoteError(:final statusCode) => statusCode,
      _ => null,
    };
    final throttled =
        status == 429 || error is GoogleCalendarApiError && error.isRateLimited;
    if (throttled ||
        status != null && (status >= 500 || status == 408 || status == 425)) {
      return AccountSettingsFeedback(
        AccountSettingsFailure.temporary,
        throttled
            ? l10n.oauthProviderThrottled
            : l10n.oauthProviderTemporaryFailure,
        AccountSettingsRecovery.retry,
      );
    }
    final disposition = syncFailureNotificationDisposition(error);
    if (disposition == SyncFailureNotificationDisposition.reconnectRequired) {
      return AccountSettingsFeedback(
        AccountSettingsFailure.authorization,
        l10n.accountReconnectRequired,
        AccountSettingsRecovery.reconnect,
      );
    }
    if (disposition == SyncFailureNotificationDisposition.permissionChanged) {
      return AccountSettingsFeedback(
        AccountSettingsFailure.permissions,
        l10n.davPermissionChanged,
        AccountSettingsRecovery.reconnect,
      );
    }
    return AccountSettingsFeedback(
      AccountSettingsFailure.temporary,
      l10n.accountSyncProblem,
      AccountSettingsRecovery.retry,
    );
  }

  static AccountSettingsFeedback fromDavCode(
    AppLocalizations l10n,
    String code,
  ) {
    // These are persisted app-owned codes, not free-form server descriptions.
    const kinds = {
      'DavNetworkFailure': DavErrorKind.network,
      'DavRequestTimeout': DavErrorKind.timeout,
      'DavTimeout': DavErrorKind.timeout,
      'DavTlsFailure': DavErrorKind.tls,
      'DavAuthRejected': DavErrorKind.authentication,
      'DavCredentialsRevoked': DavErrorKind.authentication,
      'DavPermissionDenied': DavErrorKind.authorization,
      'DavReadOnly': DavErrorKind.authorization,
      'DavUnsupportedServer': DavErrorKind.protocol,
      'DavUnsupportedProfile': DavErrorKind.protocol,
      'DavUnsupportedComponent': DavErrorKind.unsupportedComponent,
      'DavServerUnavailable': DavErrorKind.server,
      'DavCredentialStoreUnavailable': DavErrorKind.network,
    };
    final kind = kinds[code];
    return kind == null
        ? AccountSettingsFeedback(
            AccountSettingsFailure.temporary,
            l10n.accountSyncProblem,
            AccountSettingsRecovery.retry,
          )
        : fromError(
            l10n,
            DavException(kind: kind, code: code, safeMessage: ''),
          );
  }

  static AccountSettingsFeedback _network(AppLocalizations l10n) =>
      AccountSettingsFeedback(
        AccountSettingsFailure.network,
        l10n.accountServiceUnreachable,
        AccountSettingsRecovery.retry,
      );
}

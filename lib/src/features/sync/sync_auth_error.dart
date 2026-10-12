import '../../google_calendar/google_calendar_errors.dart';
import '../../microsoft_calendar/microsoft_calendar_errors.dart';
import '../../microsoft_todo/api/microsoft_todo_api_error.dart';
import '../tasks/domain/task_remote_error.dart';

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'account_sync_operations.dart';
import 'domain_sync_schedule.dart';
import '../../core/logging/redacting_logger.dart';
import '../../core/http/request_dispatch_exception.dart';

import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:flutter/services.dart';

import '../connectivity/network_connectivity_service.dart';

const accountReconnectRequiredSyncMessage =
    'This account needs to be reconnected.';
const accountReconnectRequiredActionLabel = 'Reconnect this account';
const syncTemporarilyUnavailableMessage =
    'Synchronization is temporarily unavailable.';

/// Raised when an application-facing sync or recovery entry point observes
/// that the account is no longer eligible at dispatch time.
class AccountNotSyncEligibleException implements Exception {
  const AccountNotSyncEligibleException({required this.needsReconnect});

  final bool needsReconnect;

  @override
  String toString() => 'The account is not eligible for synchronization.';
}

bool isMissingOAuthTokenError(Object error) {
  final effectiveError = resolveEffectiveSyncFailure(error);
  return (effectiveError is OAuthException &&
          (effectiveError.code == 'OAuthMissingToken' ||
              effectiveError.code == 'OAuthMissingRefreshToken' ||
              effectiveError.code == 'MicrosoftOAuthMissingToken' ||
              effectiveError.code == 'MicrosoftOAuthMissingRefreshToken')) ||
      (effectiveError is PlatformException &&
          effectiveError.code == 'android/auth-interaction-required');
}

bool isOAuthReconnectRequiredError(Object error) {
  final effective = resolveEffectiveSyncFailure(error);
  return effective is OAuthException && effective.requiresReconnect ||
      isMissingOAuthTokenError(effective);
}

String syncFailureMessage(
  Object error, {
  String networkUnavailableMessage = 'No network connection is available.',
}) {
  final effectiveError = resolveEffectiveSyncFailure(error);
  if (effectiveError is PartialAccountSyncException) {
    return effectiveError.toString();
  }
  if (effectiveError is DomainCooldownException) {
    return effectiveError.toString();
  }
  if (effectiveError is NetworkUnavailableException) {
    return networkUnavailableMessage;
  }
  if (effectiveError is AccountNotSyncEligibleException) {
    return effectiveError.needsReconnect
        ? accountReconnectRequiredSyncMessage
        : syncTemporarilyUnavailableMessage;
  }
  if (isOAuthReconnectRequiredError(effectiveError)) {
    return accountReconnectRequiredSyncMessage;
  }
  if (effectiveError is OAuthException ||
      effectiveError is RequestNotDispatchedException) {
    if (effectiveError is OAuthException &&
        effectiveError.classification == OAuthFailureKind.network) {
      return networkUnavailableMessage;
    }
    return effectiveError is OAuthException &&
            effectiveError.classification == OAuthFailureKind.permission
        ? 'Account permissions need to be updated to resume synchronization.'
        : syncTemporarilyUnavailableMessage;
  }
  final status = switch (effectiveError) {
    GoogleCalendarApiError(:final statusCode) => statusCode,
    MicrosoftCalendarApiError(:final statusCode) => statusCode,
    MicrosoftTodoApiError(:final statusCode) => statusCode,
    TaskRemoteError(:final statusCode) => statusCode,
    _ => null,
  };
  if (status != null) {
    if (status == 401) return accountReconnectRequiredSyncMessage;
    if (status == 403) {
      return 'Account permissions need to be updated to resume synchronization.';
    }
    return syncTemporarilyUnavailableMessage;
  }
  return redactForLog(effectiveError);
}

/// Diagnostics use typed outcomes and allowlisted codes, never provider bodies.
String syncFailureDiagnostic(Object failure) {
  var error = resolveEffectiveSyncFailure(failure);
  if (error is OAuthRegistrationUnavailableException) {
    return 'OAuth.registrationUnavailable${error.cause == null ? '' : ': ${syncFailureDiagnostic(error.cause!)}'}';
  }
  if (error is OAuthRefreshException) {
    const safeCodes = {
      'invalid_client',
      'unauthorized_client',
      'invalid_grant',
      'invalid_scope',
      'access_denied',
      'temporarily_unavailable',
      'server_error',
      'invalid_request',
    };
    final provider = safeCodes.contains(error.oauthError)
        ? error.oauthError
        : 'unrecognized';
    return 'OAuth.${error.classification.name}: HTTP ${error.statusCode}; $provider';
  }
  if (error is OAuthAuthorizationException) {
    final provider =
        const {
          'invalid_client',
          'unauthorized_client',
          'invalid_scope',
          'invalid_grant',
          'access_denied',
          'consent_required',
          'interaction_required',
          'login_required',
          'invalid_request',
        }.contains(error.providerError)
        ? error.providerError
        : 'unrecognized';
    return 'OAuth.${error.classification.name}; $provider${error.statusCode == null ? '' : '; HTTP ${error.statusCode}'}';
  }
  if (error is OAuthException) return 'OAuth.${error.classification.name}';
  if (error is NetworkUnavailableException ||
      error is SocketException ||
      error is http.ClientException) {
    return 'Network failure';
  }
  if (error is TimeoutException) return 'Network timeout';
  return redactForLog(error);
}

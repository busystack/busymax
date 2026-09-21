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

String syncFailureMessage(
  Object error, {
  String networkUnavailableMessage = 'No network connection is available.',
}) {
  final effectiveError = resolveEffectiveSyncFailure(error);
  if (effectiveError is NetworkUnavailableException) {
    return networkUnavailableMessage;
  }
  if (isMissingOAuthTokenError(effectiveError) ||
      (effectiveError is OAuthRefreshException &&
          effectiveError.oauthError == 'invalid_grant')) {
    return accountReconnectRequiredSyncMessage;
  }
  if (effectiveError is OAuthRefreshException ||
      effectiveError is RequestNotDispatchedException) {
    return syncTemporarilyUnavailableMessage;
  }
  return redactForLog(effectiveError);
}

import '../../core/logging/redacting_logger.dart';
import '../../google_tasks/oauth/oauth_models.dart';

const accountReconnectRequiredSyncMessage =
    'This account needs to be reconnected.';
const accountReconnectRequiredActionLabel = 'Reconnect this account';

bool isMissingOAuthTokenError(Object error) {
  return error is OAuthException &&
      (error.code == 'OAuthMissingToken' ||
          error.code == 'MicrosoftOAuthMissingToken');
}

String syncFailureMessage(Object error) {
  if (isMissingOAuthTokenError(error)) {
    return accountReconnectRequiredSyncMessage;
  }
  return redactForLog(error);
}

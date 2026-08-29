import '../../core/logging/redacting_logger.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import '../connectivity/network_connectivity_service.dart';

const accountReconnectRequiredSyncMessage =
    'This account needs to be reconnected.';
const accountReconnectRequiredActionLabel = 'Reconnect this account';

bool isMissingOAuthTokenError(Object error) {
  return error is OAuthException &&
      (error.code == 'OAuthMissingToken' ||
          error.code == 'MicrosoftOAuthMissingToken');
}

String syncFailureMessage(
  Object error, {
  String networkUnavailableMessage = 'No network connection is available.',
}) {
  if (error is NetworkUnavailableException) {
    return networkUnavailableMessage;
  }
  if (isMissingOAuthTokenError(error)) {
    return accountReconnectRequiredSyncMessage;
  }
  return redactForLog(error);
}

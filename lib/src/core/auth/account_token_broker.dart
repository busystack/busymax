import '../../google_tasks/oauth/oauth_service.dart';
import '../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../providers/busy_provider.dart';

/// Provider-neutral token access used by API clients.
abstract interface class AccountTokenBroker {
  Future<String> authorizationHeader(BusyProvider provider, String accountId);

  Future<void> recoverUnauthorized(BusyProvider provider, String accountId);
}

final class DesktopAccountTokenBroker implements AccountTokenBroker {
  const DesktopAccountTokenBroker({
    required this.google,
    required this.microsoft,
  });

  final OAuthService google;
  final MicrosoftOAuthService microsoft;

  @override
  Future<String> authorizationHeader(BusyProvider provider, String accountId) =>
      switch (provider) {
        BusyProvider.google => google.authorizationHeaderForAccount(accountId),
        BusyProvider.microsoft => microsoft.authorizationHeaderForAccount(
          accountId,
        ),
        _ => throw StateError(
          '$provider does not use OAuth API authorization.',
        ),
      };

  @override
  Future<void> recoverUnauthorized(
    BusyProvider provider,
    String accountId,
  ) async {
    switch (provider) {
      case BusyProvider.google:
        await google.refreshTokenForAccount(accountId);
      case BusyProvider.microsoft:
        await microsoft.refreshTokenForAccount(accountId);
      case BusyProvider.appleICloud:
      case BusyProvider.nextcloud:
      case BusyProvider.webCal:
        throw StateError('$provider does not use OAuth API authorization.');
    }
  }
}

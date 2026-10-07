import '../../google_tasks/oauth/oauth_service.dart';
import '../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../providers/busy_provider.dart';
import 'authorization_attempt.dart';

/// Provider-neutral token access used by API clients.
abstract interface class AccountTokenBroker {
  Future<String> authorizationHeader(BusyProvider provider, String accountId);

  Future<String> microsoftSharedCalendarAuthorizationHeader(String accountId);

  Future<String> microsoftCategoryAuthorizationHeader(String accountId);

  Future<void> recoverUnauthorized(BusyProvider provider, String accountId);
}

enum MicrosoftGraphAuthorizationKind { ordinary, sharedCalendar, category }

/// Claims-capable Graph authorization used by the shared request pipeline.
/// Kept separate so existing non-Graph token consumers retain their contract.
abstract interface class MicrosoftGraphAuthorizationBroker {
  Future<String> microsoftGraphAuthorizationHeader(
    String accountId,
    MicrosoftGraphAuthorizationKind kind, {
    String? claims,
  });
}

/// Optional contact permissions are deliberately separate from calendar/task
/// token access so ordinary account sign-in never requests them implicitly.
abstract interface class ContactsAuthorizationBroker {
  Future<void> authorizeContacts(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    AuthorizationCancellation? cancellation,
    Future<void> Function()? persistContacts,
  });

  Future<String> contactsAuthorizationHeader(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    String? claims,
  });
}

final class DesktopAccountTokenBroker
    implements
        AccountTokenBroker,
        ContactsAuthorizationBroker,
        MicrosoftGraphAuthorizationBroker {
  const DesktopAccountTokenBroker({
    required this.google,
    required this.microsoft,
  });

  final OAuthService google;
  final MicrosoftOAuthService microsoft;

  @override
  Future<void> authorizeContacts(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    AuthorizationCancellation? cancellation,
    Future<void> Function()? persistContacts,
  }) => switch (provider) {
    BusyProvider.google => google.authorizeGoogleContacts(
      accountId,
      writable: writable,
      cancellation: cancellation,
      persistContacts: persistContacts,
    ),
    BusyProvider.microsoft => microsoft.authorizeMicrosoftContacts(
      accountId,
      writable: writable,
      cancellation: cancellation,
      persistContacts: persistContacts,
    ),
    _ => throw StateError('$provider does not use OAuth contacts access.'),
  };

  @override
  Future<String> contactsAuthorizationHeader(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    String? claims,
  }) => switch (provider) {
    BusyProvider.google => google.googleContactsAuthorizationHeader(
      accountId,
      writable: writable,
    ),
    BusyProvider.microsoft => microsoft.microsoftContactsAuthorizationHeader(
      accountId,
      writable: writable,
      claims: claims,
    ),
    _ => throw StateError('$provider does not use OAuth contacts access.'),
  };

  @override
  Future<String> microsoftSharedCalendarAuthorizationHeader(String accountId) =>
      microsoft.sharedCalendarAuthorizationHeaderForAccount(accountId);

  @override
  Future<String> microsoftCategoryAuthorizationHeader(String accountId) =>
      microsoft.categoryAuthorizationHeaderForAccount(accountId);

  @override
  Future<String> microsoftGraphAuthorizationHeader(
    String accountId,
    MicrosoftGraphAuthorizationKind kind, {
    String? claims,
  }) => switch (kind) {
    MicrosoftGraphAuthorizationKind.ordinary =>
      microsoft.authorizationHeaderForAccount(accountId, claims: claims),
    MicrosoftGraphAuthorizationKind.sharedCalendar =>
      microsoft.sharedCalendarAuthorizationHeaderForAccount(
        accountId,
        claims: claims,
      ),
    MicrosoftGraphAuthorizationKind.category =>
      microsoft.categoryAuthorizationHeaderForAccount(
        accountId,
        claims: claims,
      ),
  };

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

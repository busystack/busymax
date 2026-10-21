import 'package:busymax/l10n/generated/app_localizations_en.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:busymax/src/google_calendar/google_calendar_errors.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/features/settings/presentation/account_settings_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  test(
    'typed DAV failures map to usable recovery without provider diagnostics',
    () {
      for (final (kind, code, recovery) in [
        (
          DavErrorKind.network,
          'DavNetworkFailure',
          AccountSettingsRecovery.retry,
        ),
        (
          DavErrorKind.timeout,
          'DavRequestTimeout',
          AccountSettingsRecovery.retry,
        ),
        (
          DavErrorKind.authentication,
          'DavCredentialsRevoked',
          AccountSettingsRecovery.reconnect,
        ),
        (
          DavErrorKind.authorization,
          'DavPermissionDenied',
          AccountSettingsRecovery.revalidate,
        ),
        (
          DavErrorKind.protocol,
          'DavUnsupportedServer',
          AccountSettingsRecovery.revalidate,
        ),
      ]) {
        final error = DavException(
          kind: kind,
          code: code,
          safeMessage: 'private provider body',
          correlationId: 'private-correlation',
        );
        for (final failure in [
          error,
          DavAccountSyncException([error]),
          AuthorizationScopedFailure(
            accountId: 'qa',
            generation: 2,
            cause: error,
          ),
        ]) {
          final feedback = AccountSettingsFeedback.fromError(l10n, failure);
          expect(feedback.recovery, recovery);
          expect(feedback.message, isNot(contains('private')));
          expect(feedback.message, isNot(contains('Dav')));
          if (kind == DavErrorKind.network || kind == DavErrorKind.timeout) {
            expect(feedback.message, l10n.accountServiceUnreachable);
            expect(
              feedback.message.toLowerCase(),
              isNot(contains('reconnect')),
            );
          }
        }
        expect(
          AccountSettingsFeedback.fromDavCode(l10n, code).recovery,
          recovery,
        );
      }
    },
  );
  test(
    'provider service failures and throttling offer retry without raw messages',
    () {
      for (final error in [
        const GoogleCalendarApiError(
          statusCode: 503,
          code: 'private',
          message: 'private',
        ),
        const MicrosoftCalendarApiError(
          statusCode: 502,
          code: 'private',
          message: 'private',
        ),
      ]) {
        final result = AccountSettingsFeedback.fromError(l10n, error);
        expect(result.message, l10n.oauthProviderTemporaryFailure);
        expect(result.recovery, AccountSettingsRecovery.retry);
      }
      expect(
        AccountSettingsFeedback.fromError(
          l10n,
          const GoogleCalendarApiError(
            statusCode: 403,
            code: 'private',
            message: 'private',
            reasons: ['rateLimitExceeded'],
          ),
        ).message,
        l10n.oauthProviderThrottled,
      );
    },
  );
  test('unknown failures and persisted codes never become UI strings', () {
    for (final feedback in [
      AccountSettingsFeedback.fromError(
        l10n,
        StateError('private/token/example'),
      ),
      AccountSettingsFeedback.fromDavCode(l10n, 'private/token/example'),
    ]) {
      expect(feedback.message, l10n.accountSyncProblem);
      expect(feedback.recovery, AccountSettingsRecovery.retry);
    }
  });
  test(
    'registration recovery differs from an expired grant or a network outage',
    () {
      expect(
        AccountSettingsFeedback.fromError(
          l10n,
          const OAuthException('OAuthRegistrationUnresolved', 'private'),
        ).recovery,
        AccountSettingsRecovery.replaceRegistration,
      );
      expect(
        AccountSettingsFeedback.fromError(
          l10n,
          const OAuthException('OAuthMissingToken', 'private'),
        ).recovery,
        AccountSettingsRecovery.reconnect,
      );
      expect(
        AccountSettingsFeedback.fromError(
          l10n,
          const OAuthException('OAuthTemporaryTransport', 'private'),
        ).recovery,
        AccountSettingsRecovery.retry,
      );
    },
  );
}

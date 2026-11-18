import 'package:busymax/src/features/auth/application/account_removal.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements AuthRepository {}

void main() {
  test(
    'Google revocation failure is a warning after guarded local removal',
    () async {
      final auth = _Auth();
      var guarded = false;
      when(
        () =>
            auth.removeAccount(accountId: 'account', revokeAuthorization: true),
      ).thenAnswer((_) async {
        expect(guarded, isTrue);
        return const AccountRemovalResult(
          authorizationRevocationStatus:
              AccountAuthorizationRevocationStatus.failed,
        );
      });
      final result = await removeBusyMaxAccount(
        accountId: 'account',
        provider: BusyProvider.google,
        revokeGoogleAuthorization: true,
        auth: () => auth,
        dav: () => throw StateError('unexpected DAV client'),
        guardOAuthRemoval: (remove) {
          guarded = true;
          return remove();
        },
      );
      expect(result, AccountRemovalOutcome.googleRevocationFailed);
    },
  );
}

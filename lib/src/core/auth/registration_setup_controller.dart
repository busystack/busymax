import 'package:flutter/foundation.dart';

import '../../providers/busy_provider.dart';
import 'oauth_models.dart';
import 'oauth_registration.dart';
import 'registration_staging.dart';

final class RegistrationSetupController extends ChangeNotifier {
  RegistrationSetupController(
    this.staging,
    this.provider, {
    this.platform = AuthenticationPlatform.desktop,
  });
  final RegistrationStaging staging;
  final BusyProvider provider;
  final AuthenticationPlatform platform;
  RegistrationHandle? handle;
  String? error;
  bool busy = false;
  bool _disposed = false;
  bool _accepted = false;
  MicrosoftAudience audience = MicrosoftAudience.personalAndOrganizations;
  String clientId = '';
  String tenantId = '';
  void clearSelection() {
    if (handle case final selected?) staging.discard(selected.id);
    handle = null;
  }

  Future<void> validate() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      handle = provider == BusyProvider.google
          ? await staging.selectGoogle()
          : staging.stageMicrosoft(
              clientId: clientId,
              audience: audience,
              tenantId: audience == MicrosoftAudience.tenant ? tenantId : null,
              platform: platform,
            );
      if (handle?.summary.origin == RegistrationOrigin.retiringShared) {
        staging.discard(handle!.id);
        handle = null;
        throw const OAuthException(
          'OAuthConfigurationRejected',
          'Choose a registration from your own project or tenant. This client is the retiring shared registration.',
        );
      }
    } on OAuthException catch (failure) {
      error = failure.message;
    } on Object {
      error = 'Registration setup could not complete. Try again.';
    } finally {
      busy = false;
      if (_disposed && handle != null) {
        staging.discard(handle!.id);
        handle = null;
      }
      if (!_disposed) notifyListeners();
    }
  }

  RegistrationHandle? accept() {
    _accepted = true;
    return handle;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_accepted) staging.cancel();
    super.dispose();
  }
}

/// Packaged onboarding help excludes retirement text. Account settings carry
/// the independently evaluated migration notice and targeted operation.
String registrationOnboardingGuide(String guide) => guide
    .replaceAll(
      RegExp(
        r'^## Existing(?:-account migration| shared accounts)\n[\s\S]*?(?=^## |(?![\s\S]))',
        multiLine: true,
      ),
      '',
    )
    .replaceAll(
      'The desktop client\'s retirement does **not** authorize deletion of the Cloud project still needed by Android. ',
      '',
    );

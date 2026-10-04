import 'package:flutter/foundation.dart';

import '../../providers/busy_provider.dart';
import 'oauth_models.dart';
import 'authorization_attempt.dart';
import 'oauth_registration.dart';
import 'registration_staging.dart';

final class RegistrationSetupController extends ChangeNotifier {
  RegistrationSetupController(
    this.staging,
    this.provider, {
    this.platform = AuthenticationPlatform.desktop,
  }) {
    staging.addListener(_stagingChanged);
  }
  final RegistrationStaging staging;
  final BusyProvider provider;
  final AuthenticationPlatform platform;
  RegistrationHandle? handle;
  String? error;
  String? errorCode;
  bool busy = false;
  bool expired = false;
  bool _disposed = false;
  bool _accepted = false;
  int _revision = 0;
  final _cancellation = AuthorizationCancellation();
  MicrosoftAudience audience = MicrosoftAudience.personalAndOrganizations;
  String clientId = '';
  String tenantId = '';
  bool _clientEdited = false;
  bool _tenantEdited = false;

  bool get invalidClientId => _clientEdited && !isUuid(clientId.trim());
  bool get invalidTenantId =>
      audience == MicrosoftAudience.tenant &&
      _tenantEdited &&
      !isUuid(tenantId.trim());
  bool get canConnect =>
      !_disposed &&
      !_accepted &&
      !busy &&
      !expired &&
      handle != null &&
      staging.isAvailable(handle!);

  void _stagingChanged() {
    if (_disposed || _accepted) return;
    if (handle case final selected?) {
      if (!staging.isAvailable(selected)) {
        handle = null;
        expired = true;
        error = null;
        errorCode = null;
        notifyListeners();
      }
    }
  }

  void clearSelection() {
    final selected = handle;
    handle = null;
    if (selected != null) staging.discard(selected.id);
  }

  void updateClientId(String value) {
    if (_disposed || _accepted || clientId == value) return;
    clientId = value;
    _clientEdited = true;
    _inputsChanged();
  }

  void updateTenantId(String value) {
    if (_disposed || _accepted || tenantId == value) return;
    tenantId = value;
    _tenantEdited = true;
    _inputsChanged();
  }

  void updateAudience(MicrosoftAudience value) {
    if (_disposed || _accepted || audience == value) return;
    audience = value;
    // A hidden tenant never remains part of the submitted form.
    tenantId = '';
    _tenantEdited = false;
    _inputsChanged();
  }

  void _inputsChanged() {
    _revision++;
    error = null;
    errorCode = null;
    expired = false;
    clearSelection();
    _validateMicrosoft();
    notifyListeners();
  }

  MicrosoftPublicRegistration _microsoftRegistration() =>
      MicrosoftPublicRegistration(
        clientId: clientId,
        audience: audience,
        tenantId: audience == MicrosoftAudience.tenant ? tenantId : null,
        platform: platform,
      );

  void _validateMicrosoft({bool showFailure = false}) {
    try {
      _microsoftRegistration();
      final selected = staging.stageMicrosoft(
        clientId: clientId,
        audience: audience,
        tenantId: audience == MicrosoftAudience.tenant ? tenantId : null,
        platform: platform,
      );
      if (selected.summary.origin == RegistrationOrigin.retiringShared) {
        staging.discard(selected.id);
        errorCode = 'OAuthRetiringRegistration';
        error = 'Choose a registration from your own project or tenant.';
      } else {
        handle = selected;
      }
    } on OAuthException catch (failure) {
      // Field errors are recomputed from the current input, not cached.
      if (showFailure) {
        error = failure.message;
        errorCode = failure.code;
      }
    }
  }

  Future<void> validate() async {
    if (busy || _disposed || _accepted) return;
    final revision = ++_revision;
    busy = true;
    error = null;
    errorCode = null;
    notifyListeners();
    RegistrationHandle? candidate;
    try {
      if (provider == BusyProvider.google) {
        candidate = await staging.selectGoogle(
          cancellation: _cancellation,
          preserve: handle,
        );
        if (_disposed || revision != _revision) {
          if (candidate != null) staging.discard(candidate.id);
          return;
        }
        // Picker cancellation preserves both the current selection and expiry.
        if (candidate == null) return;
        if (candidate.summary.origin == RegistrationOrigin.retiringShared) {
          staging.discard(candidate.id);
          throw const OAuthException(
            'OAuthRetiringRegistration',
            'Choose a registration from your own project or tenant.',
          );
        }
        clearSelection();
        handle = candidate;
        expired = false;
      } else {
        clearSelection();
        _clientEdited = true;
        _tenantEdited = true;
        _validateMicrosoft(showFailure: true);
        expired = false;
      }
    } on OAuthException catch (failure) {
      if (!_disposed &&
          revision == _revision &&
          failure.classification != OAuthFailureKind.cancelled) {
        error = failure.message;
        errorCode = failure.code;
      }
    } on Object {
      if (!_disposed && revision == _revision) {
        error = 'Registration setup could not complete. Try again.';
        errorCode = 'OAuthSetupFailed';
      }
    } finally {
      if (!_disposed && revision == _revision) {
        busy = false;
        notifyListeners();
      }
    }
  }

  RegistrationHandle? accept() {
    if (!canConnect) {
      _stagingChanged();
      return null;
    }
    if (provider == BusyProvider.microsoft) {
      // Recheck the same local rules without extending the staging lifetime.
      try {
        final registration = _microsoftRegistration();
        if (registration.clientId != handle!.summary.clientId ||
            registration.authorityTenant != handle!.summary.authority) {
          clearSelection();
          notifyListeners();
          return null;
        }
      } on OAuthException {
        clearSelection();
        _clientEdited = true;
        _tenantEdited = true;
        notifyListeners();
        return null;
      }
    }
    _accepted = true;
    return handle;
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    staging.removeListener(_stagingChanged);
    _cancellation.cancel();
    if (!_accepted) clearSelection();
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

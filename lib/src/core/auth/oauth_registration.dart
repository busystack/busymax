import '../../providers/busy_provider.dart';
import 'oauth_models.dart';
import 'authorization_attempt.dart';

enum AuthenticationPlatform { desktop, android }

enum RegistrationOrigin { userProvided, retiringShared, nativeGoogleAndroid }

enum AuthorizationIntent { newConnection, reconnect, replaceRegistration }

abstract interface class RegistrationBindingResolver {
  Future<void> establishExistingBinding(String id, BusyProvider provider);
}

/// Non-secret native alias snapshot used only for persistence rollback. It
/// conveys no ownership/provenance and is never a desktop token envelope.
final class NativeBindingSnapshot {
  const NativeBindingSnapshot({
    required this.provider,
    required this.nativeAccountId,
    this.username,
    this.authority,
    this.clientId,
    this.authorityTenant,
  });
  final BusyProvider provider;
  final String nativeAccountId;
  final String? username, authority, clientId, authorityTenant;
  Map<String, Object?> toJson() => {
    'provider': provider.storageValue,
    'nativeAccountId': nativeAccountId,
    'username': username,
    'authority': authority,
    'clientId': clientId,
    'authorityTenant': authorityTenant,
  };
  factory NativeBindingSnapshot.fromJson(Map<String, dynamic> value) =>
      NativeBindingSnapshot(
        provider: BusyProviderCodec.requireStorageValue(
          value['provider'] as String,
        ),
        nativeAccountId: value['nativeAccountId'] as String,
        username: value['username'] as String?,
        authority: value['authority'] as String?,
        clientId: value['clientId'] as String?,
        authorityTenant: value['authorityTenant'] as String?,
      );
}

enum MicrosoftAudience {
  personalAndOrganizations,
  organizations,
  personal,
  tenant,
}

/// Presentation contains no client secret, token, or imported file path.
final class RegistrationSummary {
  const RegistrationSummary({
    required this.provider,
    required this.platform,
    required this.origin,
    required this.clientId,
    this.projectId,
    this.authority,
    this.transitionEligible = false,
  });
  final BusyProvider provider;
  final AuthenticationPlatform platform;
  final RegistrationOrigin origin;
  final String clientId;
  final String? projectId;
  final String? authority;
  final bool transitionEligible;
  bool get showRetirementNotice =>
      transitionEligible &&
      origin == RegistrationOrigin.retiringShared &&
      !(provider == BusyProvider.google &&
          platform == AuthenticationPlatform.android);
}

sealed class OAuthRegistration {
  const OAuthRegistration();
  String get clientId;
  RegistrationSummary summary({bool transitionEligible = false});
}

final class GoogleDesktopRegistration extends OAuthRegistration {
  const GoogleDesktopRegistration({
    required this.clientId,
    this.clientSecret,
    required this.projectId,
    this.origin = RegistrationOrigin.userProvided,
  });
  @override
  final String clientId;
  final String? clientSecret;
  final String projectId;
  final RegistrationOrigin origin;
  @override
  RegistrationSummary summary({bool transitionEligible = false}) =>
      RegistrationSummary(
        provider: BusyProvider.google,
        platform: AuthenticationPlatform.desktop,
        origin: origin,
        clientId: clientId,
        projectId: projectId,
        transitionEligible: transitionEligible,
      );
  @override
  String toString() => 'GoogleDesktopRegistration([REDACTED])';
}

final class MicrosoftPublicRegistration extends OAuthRegistration {
  MicrosoftPublicRegistration({
    required String clientId,
    required this.audience,
    String? tenantId,
    this.platform = AuthenticationPlatform.desktop,
    this.origin = RegistrationOrigin.userProvided,
  }) : clientId = clientId.trim().toLowerCase(),
       tenantId = tenantId?.trim().toLowerCase() {
    if (!isUuid(this.clientId) ||
        (audience == MicrosoftAudience.tenant &&
            !isUuid(this.tenantId ?? '')) ||
        (audience != MicrosoftAudience.tenant && this.tenantId != null)) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Enter an Application/client ID and a supported account audience. A tenant-specific audience also requires a tenant ID.',
      );
    }
  }
  @override
  final String clientId;
  final MicrosoftAudience audience;
  final String? tenantId;
  final AuthenticationPlatform platform;
  final RegistrationOrigin origin;
  String get authorityTenant => switch (audience) {
    MicrosoftAudience.personalAndOrganizations => 'common',
    MicrosoftAudience.organizations => 'organizations',
    MicrosoftAudience.personal => 'consumers',
    MicrosoftAudience.tenant => tenantId!,
  };
  Uri endpoint(String operation) => Uri.https(
    'login.microsoftonline.com',
    '/$authorityTenant/oauth2/v2.0/$operation',
  );
  @override
  RegistrationSummary summary({bool transitionEligible = false}) =>
      RegistrationSummary(
        provider: BusyProvider.microsoft,
        platform: platform,
        origin: origin,
        clientId: clientId,
        authority: authorityTenant,
        transitionEligible: transitionEligible,
      );
}

bool isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

/// Opaque, single-use reference to configuration held by the auth layer.
final class RegistrationHandle {
  const RegistrationHandle(this.id, this.summary);
  final String id;
  final RegistrationSummary summary;
}

final class AuthorizationRequest {
  const AuthorizationRequest.newConnection(
    this.registration, {
    this.cancellation,
  }) : intent = AuthorizationIntent.newConnection,
       accountId = null;
  const AuthorizationRequest.reconnect(this.accountId, {this.cancellation})
    : intent = AuthorizationIntent.reconnect,
      registration = null;
  const AuthorizationRequest.replace(
    this.accountId,
    this.registration, {
    this.cancellation,
  }) : intent = AuthorizationIntent.replaceRegistration;
  final AuthorizationIntent intent;
  final String? accountId;
  final RegistrationHandle? registration;
  final AuthorizationCancellation? cancellation;
  AuthorizationRequest withCancellation(AuthorizationCancellation signal) =>
      switch (intent) {
        AuthorizationIntent.newConnection => AuthorizationRequest.newConnection(
          registration,
          cancellation: signal,
        ),
        AuthorizationIntent.reconnect => AuthorizationRequest.reconnect(
          accountId,
          cancellation: signal,
        ),
        AuthorizationIntent.replaceRegistration => AuthorizationRequest.replace(
          accountId,
          registration,
          cancellation: signal,
        ),
      };
}

typedef AuthorizationCommit =
    Future<void> Function(Future<void> Function() persistAccount);

enum AccountConnectionState {
  connected,
  connecting,
  reauthenticationRequired,
  temporarilyUnavailable,
  permissionChanged,
  unsupportedServerProfile,
  signedOut,
}

extension AccountConnectionStateStorage on AccountConnectionState {
  /// `signed_in` and `reauth_required` are retained as the durable spellings
  /// used by the pre-DAV schema. The typed model exposes the provider-neutral
  /// connection states required by every transport.
  String get storageValue => switch (this) {
    AccountConnectionState.connected => 'signed_in',
    AccountConnectionState.connecting => 'connecting',
    AccountConnectionState.reauthenticationRequired => 'reauth_required',
    AccountConnectionState.temporarilyUnavailable => 'temporarily_unavailable',
    AccountConnectionState.permissionChanged => 'permission_changed',
    AccountConnectionState.unsupportedServerProfile =>
      'unsupported_server_profile',
    AccountConnectionState.signedOut => 'signed_out',
  };
}

abstract final class AccountConnectionStateCodec {
  static AccountConnectionState parse(String value) => switch (value) {
    'signed_in' => AccountConnectionState.connected,
    'connecting' => AccountConnectionState.connecting,
    'reauth_required' => AccountConnectionState.reauthenticationRequired,
    'temporarily_unavailable' => AccountConnectionState.temporarilyUnavailable,
    'permission_changed' => AccountConnectionState.permissionChanged,
    'unsupported_server_profile' =>
      AccountConnectionState.unsupportedServerProfile,
    'signed_out' => AccountConnectionState.signedOut,
    _ => throw FormatException('Unsupported account connection state.'),
  };
}

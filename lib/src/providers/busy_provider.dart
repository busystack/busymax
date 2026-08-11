/// Stable account provider identities persisted by BusyMax.
enum BusyProvider { google, microsoft, appleICloud, nextcloud }

extension BusyProviderValue on BusyProvider {
  String get storageValue => switch (this) {
    BusyProvider.google => 'google',
    BusyProvider.microsoft => 'microsoft',
    BusyProvider.appleICloud => 'apple_icloud',
    BusyProvider.nextcloud => 'nextcloud',
  };

  String get displayName => switch (this) {
    BusyProvider.google => 'Google',
    BusyProvider.microsoft => 'Microsoft',
    BusyProvider.appleICloud => 'Apple iCloud',
    BusyProvider.nextcloud => 'Nextcloud',
  };
}

sealed class BusyProviderParseResult {
  const BusyProviderParseResult();

  BusyProvider? get provider;
}

final class SupportedBusyProvider extends BusyProviderParseResult {
  const SupportedBusyProvider(this.value);

  final BusyProvider value;

  @override
  BusyProvider get provider => value;
}

final class UnsupportedStoredProvider extends BusyProviderParseResult {
  const UnsupportedStoredProvider(this.storageValue);

  final String? storageValue;

  @override
  BusyProvider? get provider => null;
}

/// A typed corrupt-storage failure. Unknown values are never mapped to a
/// different provider because doing so could send data or credentials to the
/// wrong service.
final class UnsupportedStoredProviderException implements FormatException {
  const UnsupportedStoredProviderException(this.storageValue);

  final String? storageValue;

  @override
  String get message => 'Unsupported provider value in BusyMax storage.';

  @override
  int? get offset => null;

  @override
  String? get source => storageValue;

  @override
  String toString() =>
      'UnsupportedStoredProviderException(storageValue: $storageValue)';
}

abstract final class BusyProviderCodec {
  static BusyProviderParseResult parseStorageValue(String? value) {
    return switch (value) {
      'google' => const SupportedBusyProvider(BusyProvider.google),
      'microsoft' => const SupportedBusyProvider(BusyProvider.microsoft),
      'apple_icloud' => const SupportedBusyProvider(BusyProvider.appleICloud),
      'nextcloud' => const SupportedBusyProvider(BusyProvider.nextcloud),
      _ => UnsupportedStoredProvider(value),
    };
  }

  static BusyProvider requireStorageValue(String? value) {
    return switch (parseStorageValue(value)) {
      SupportedBusyProvider(:final value) => value,
      UnsupportedStoredProvider(:final storageValue) =>
        throw UnsupportedStoredProviderException(storageValue),
    };
  }
}

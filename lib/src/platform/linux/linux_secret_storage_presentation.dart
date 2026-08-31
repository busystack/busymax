import '../../core/secrets/secret_store.dart';

const linuxSecretStoragePresentation = SecretStoragePresentation(
  backendDomain: 'busymax.secure_storage.linux',
  runtimeBackend: 'linux-keyring',
  unavailableMessage:
      'Secure credential storage is temporarily unavailable. Unlock your '
      'system keyring and try again.',
);

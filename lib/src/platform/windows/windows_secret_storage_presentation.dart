import '../../core/secrets/secret_store.dart';

const windowsSecretStoragePresentation = SecretStoragePresentation(
  backendDomain: 'busymax.secure_storage.windows',
  runtimeBackend: 'windows-credential-storage',
  unavailableMessage:
      'Windows credential storage is temporarily unavailable. Check your '
      'Windows credentials and try again.',
);

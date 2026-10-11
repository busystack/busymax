import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../config/build_config.dart';
import '../../providers/busy_provider.dart';
import 'oauth_models.dart';
import 'oauth_registration.dart';
import 'registration_file_reader.dart';
import 'authorization_attempt.dart';

/// Configuration is owned here, never in widget state. No file is modified.
final class RegistrationStaging extends ChangeNotifier {
  RegistrationStaging(
    this.config, {
    this.lifetime = const Duration(minutes: 10),
    this.beforeConfigurationOpen,
    this.fileReader = const RegistrationFileReader(),
    this.filePicker,
    DateTime Function()? nowUtc,
  }) : nowUtc = nowUtc ?? (() => DateTime.now().toUtc());
  final BuildConfig config;
  final RegistrationFileReader fileReader;
  final Duration lifetime;
  final Future<XFile?> Function()? filePicker;
  final DateTime Function() nowUtc;
  final Future<void> Function()? beforeConfigurationOpen;
  static const maximumBytes = 64 * 1024;
  final Map<String, (OAuthRegistration, Timer, DateTime)> _entries = {};
  final Set<String> _knownRetiringClients = {};
  Completer<void>? _readCancellation;
  int _generation = 0;
  final AuthorizationAttemptOwner _selections = AuthorizationAttemptOwner();

  Future<RegistrationHandle?> selectGoogle({
    String? initialDirectory,
    AuthorizationCancellation? cancellation,
    RegistrationHandle? preserve,
  }) async {
    _cancelPendingImport();
    final attempt = _selections.begin(
      () => DateTime.now().toUtc(),
      cancellation,
    );
    final selectionGeneration = _generation;
    try {
      final selected = await attempt.wait(
        filePicker?.call() ??
            openFile(
              initialDirectory: initialDirectory,
              acceptedTypeGroups: const [
                XTypeGroup(
                  label: 'Google Desktop OAuth JSON',
                  extensions: ['json'],
                ),
              ],
            ),
      );
      attempt.check();
      if (selectionGeneration != _generation) throw _cancelled;
      return selected == null
          ? null
          : await importGoogle(
              selected,
              cancellation: cancellation,
              preserve: preserve,
            );
    } finally {
      _selections.finish(attempt);
    }
  }

  void rememberRetiringClient(String clientId) =>
      _knownRetiringClients.add(clientId.toLowerCase());

  RegistrationHandle stageBusyMax(BusyProvider provider) {
    if (provider == BusyProvider.google &&
        config.hasBusyMaxGoogleRegistration) {
      return stage(
        GoogleDesktopRegistration(
          clientId: config.busyMaxGoogleOAuthClientId.trim(),
          clientSecret: config.busyMaxGoogleOAuthClientSecret.trim(),
          projectId: config.busyMaxGoogleOAuthProjectId.trim(),
          origin: RegistrationOrigin.busyMaxManaged,
        ),
      );
    }
    if (provider == BusyProvider.microsoft &&
        config.hasBusyMaxMicrosoftRegistration) {
      return stage(
        MicrosoftPublicRegistration(
          clientId: config.busyMaxMicrosoftOAuthClientId,
          audience: MicrosoftAudience.personalAndOrganizations,
          origin: RegistrationOrigin.busyMaxManaged,
        ),
      );
    }
    throw const OAuthException(
      'OAuthSharedUnavailable',
      'BusyMax-managed authorization is unavailable in this build.',
    );
  }

  bool _isConfiguredActive(OAuthRegistration value) => switch (value) {
    GoogleDesktopRegistration() =>
      config.hasBusyMaxGoogleRegistration &&
          value.clientId == config.busyMaxGoogleOAuthClientId.trim(),
    MicrosoftPublicRegistration() =>
      value.platform == AuthenticationPlatform.desktop &&
          config.hasBusyMaxMicrosoftRegistration &&
          value.clientId ==
              config.busyMaxMicrosoftOAuthClientId.trim().toLowerCase(),
  };

  Future<RegistrationHandle> importGoogle(
    XFile selected, {
    AuthorizationCancellation? cancellation,
    RegistrationHandle? preserve,
  }) async {
    _cancelPendingImport();
    final generation = _generation;
    final attempt = AuthorizationAttempt(
      nowUtc: () => DateTime.now().toUtc(),
      cancellation: cancellation,
      lifetime: const Duration(seconds: 15),
    );
    final path = selected.path;
    if (!isSupportedRegistrationFilePath(path, windows: Platform.isWindows)) {
      attempt.dispose();
      throw const OAuthException(
        'OAuthUnsupportedFileSource',
        'Select a local Desktop OAuth JSON file.',
      );
    }
    final cancelled = Completer<void>();
    _readCancellation = cancelled;
    unawaited(cancelled.future.then((_) => attempt.cancel()));
    try {
      attempt.check();
      await attempt.wait(
        beforeConfigurationOpen?.call() ?? Future<void>.value(),
      );
      if (generation != _generation) throw _cancelled;
      final bytes = await fileReader.read(
        path,
        maximumBytes: maximumBytes,
        cancellation: Future.any([cancelled.future, attempt.cancellation]),
        timeout: attempt.deadline.difference(DateTime.now().toUtc()),
      );
      try {
        attempt.check();
        if (generation != _generation) throw _cancelled;
        return stage(
          parseGoogleDesktopConfiguration(bytes, config),
          preserve: preserve,
        );
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } finally {
      attempt.cancel();
      attempt.dispose();
      if (!cancelled.isCompleted) cancelled.complete();
      if (identical(_readCancellation, cancelled)) _readCancellation = null;
    }
  }

  RegistrationHandle stageMicrosoft({
    required String clientId,
    required MicrosoftAudience audience,
    String? tenantId,
    AuthenticationPlatform platform = AuthenticationPlatform.desktop,
  }) {
    final registration = MicrosoftPublicRegistration(
      clientId: clientId,
      audience: audience,
      tenantId: tenantId,
      platform: platform,
      origin:
          clientId.trim().toLowerCase() ==
                  config.microsoftOAuthClientId.trim().toLowerCase() &&
              !(platform == AuthenticationPlatform.desktop &&
                  config.hasBusyMaxMicrosoftRegistration &&
                  clientId.trim().toLowerCase() ==
                      config.busyMaxMicrosoftOAuthClientId.trim().toLowerCase())
          ? RegistrationOrigin.retiringShared
          : RegistrationOrigin.userProvided,
    );
    return stage(registration);
  }

  RegistrationHandle stage(
    OAuthRegistration value, {
    RegistrationHandle? preserve,
  }) {
    final known = value is GoogleDesktopRegistration
        ? config.googleOAuthClientId
        : config.microsoftOAuthClientId;
    if (value.summary().origin != RegistrationOrigin.busyMaxManaged &&
        (value.summary().origin == RegistrationOrigin.retiringShared ||
            !_isConfiguredActive(value)) &&
        (_knownRetiringClients.contains(value.clientId.toLowerCase()) ||
            (known.isNotEmpty &&
                value.clientId.toLowerCase() == known.trim().toLowerCase()))) {
      value = value.withOrigin(RegistrationOrigin.retiringShared);
    }
    for (final key in _entries.keys.toList()) {
      if (key != preserve?.id) discard(key);
    }
    final id = const Uuid().v4();
    _entries[id] = (
      value,
      Timer(lifetime, () => discard(id)),
      nowUtc().add(lifetime),
    );
    notifyListeners();
    return RegistrationHandle(id, value.summary());
  }

  OAuthRegistration consume(RegistrationHandle handle) {
    if (!isAvailable(handle)) discard(handle.id);
    final entry = _entries.remove(handle.id);
    if (entry == null) {
      throw const OAuthException(
        'OAuthConfigurationExpired',
        'Select your registration again. The previous selection expired or was consumed.',
      );
    }
    entry.$2.cancel();
    notifyListeners();
    return entry.$1;
  }

  bool isAvailable(RegistrationHandle handle) {
    final entry = _entries[handle.id];
    return entry != null && nowUtc().isBefore(entry.$3);
  }

  void discard(String id) {
    final entry = _entries.remove(id);
    if (entry != null) {
      entry.$2.cancel();
      notifyListeners();
    }
  }

  void _cancelPendingImport() {
    _generation++;
    _selections.current?.cancel();
    final read = _readCancellation;
    if (read != null && !read.isCompleted) read.complete();
  }

  void cancel() {
    _cancelPendingImport();
    for (final key in _entries.keys.toList()) {
      discard(key);
    }
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }

  static const _cancelled = OAuthException(
    'OAuthSignInCancelled',
    'Registration setup was cancelled.',
  );
}

/// A Windows drive prefix is a native path, not an imported URI scheme.
/// Remote UNC/device paths and URI-backed sources require a separate adapter.
bool isSupportedRegistrationFilePath(String path, {required bool windows}) =>
    !path.contains('\x00') &&
    (windows
        ? RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)
        : path.startsWith('/') && Uri.tryParse(path)?.hasScheme != true);

GoogleDesktopRegistration parseGoogleDesktopConfiguration(
  List<int> bytes,
  BuildConfig config,
) {
  if (bytes.length > RegistrationStaging.maximumBytes) {
    throw const OAuthException(
      'OAuthConfigurationTooLarge',
      'The OAuth JSON file exceeds 64 KiB.',
    );
  }
  Object? value;
  try {
    value = jsonDecode(utf8.decode(bytes));
  } on Object {
    throw const OAuthException(
      'OAuthConfigurationMalformed',
      'The selected file is not valid UTF-8 OAuth JSON.',
    );
  }
  if (value is! Map ||
      value['installed'] is! Map ||
      value.containsKey('web') ||
      value.containsKey('type')) {
    throw const OAuthException(
      'OAuthWrongClientType',
      'Download an installed Desktop OAuth client. Web clients, service accounts, and token files cannot be imported.',
    );
  }
  final installed = value['installed'] as Map;
  final clientId = installed['client_id'];
  final secret = installed['client_secret'];
  final project = installed['project_id'];
  if (clientId is! String ||
      !RegExp(r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$')
          .hasMatch(clientId) ||
      project is! String ||
      !RegExp(r'^[a-z][a-z0-9-]{4,62}[a-z0-9]$').hasMatch(project) ||
      (secret != null &&
          (secret is! String ||
              secret.trim().isEmpty ||
              secret.length > 4096))) {
    throw const OAuthException(
      'OAuthConfigurationRejected',
      'The Desktop OAuth JSON must contain a valid client ID, project ID, and optional string client secret.',
    );
  }
  // Endpoints, scopes and redirects in the download are deliberately ignored.
  return GoogleDesktopRegistration(
    clientId: clientId,
    clientSecret: secret as String?,
    projectId: project,
    origin:
        clientId == config.googleOAuthClientId.trim() &&
            !(config.hasBusyMaxGoogleRegistration &&
                clientId == config.busyMaxGoogleOAuthClientId.trim())
        ? RegistrationOrigin.retiringShared
        : RegistrationOrigin.userProvided,
  );
}

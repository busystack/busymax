import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';

import '../../config/build_config.dart';
import 'oauth_models.dart';
import 'oauth_registration.dart';

/// Configuration is owned here, never in widget state. No file is modified.
final class RegistrationStaging {
  RegistrationStaging(
    this.config, {
    this.lifetime = const Duration(minutes: 10),
  });
  final BuildConfig config;
  final Duration lifetime;
  static const maximumBytes = 64 * 1024;
  final Map<String, (OAuthRegistration, Timer)> _entries = {};
  final Set<String> _knownRetiringClients = {};
  StreamSubscription<List<int>>? _read;
  Completer<RegistrationHandle>? _reading;
  int _generation = 0;

  Future<RegistrationHandle?> selectGoogle({String? initialDirectory}) async {
    cancel();
    final selectionGeneration = _generation;
    final selected = await openFile(
      initialDirectory: initialDirectory,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Google Desktop OAuth JSON', extensions: ['json']),
      ],
    );
    if (selectionGeneration != _generation) throw _cancelled;
    return selected == null ? null : importGoogle(selected);
  }

  void rememberRetiringClient(String clientId) =>
      _knownRetiringClients.add(clientId.toLowerCase());

  Future<RegistrationHandle> importGoogle(XFile selected) async {
    cancel();
    final generation = _generation;
    final path = selected.path;
    if (!isSupportedRegistrationFilePath(path, windows: Platform.isWindows)) {
      throw const OAuthException(
        'OAuthUnsupportedFileSource',
        'Select a local Desktop OAuth JSON file.',
      );
    }
    final completion = Completer<RegistrationHandle>();
    final pending = completion.future;
    unawaited(pending.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    _reading = completion;
    StreamSubscription<List<int>>? subscription;
    final bytes = <int>[];
    final timer = Timer(const Duration(seconds: 15), () {
      if (generation != _generation) return;
      if (!completion.isCompleted) {
        completion.completeError(
          const OAuthException(
            'OAuthRequestTimeout',
            'Reading the registration timed out.',
          ),
        );
      }
      cancel();
    });
    try {
      final type = await Future.any([
        FileSystemEntity.type(path, followLinks: false),
        pending.then<FileSystemEntityType>((_) => throw _cancelled),
      ]);
      if (type != FileSystemEntityType.file) {
        throw const OAuthException(
          'OAuthUnsupportedFileSource',
          'Select a regular local JSON file.',
        );
      }
      if (generation != _generation) throw _cancelled;
      subscription = File(path).openRead().listen(
        (chunk) {
          if (bytes.length + chunk.length > maximumBytes) {
            if (!completion.isCompleted) {
              completion.completeError(
                const OAuthException(
                  'OAuthConfigurationTooLarge',
                  'The OAuth JSON file exceeds 64 KiB.',
                ),
              );
            }
            unawaited(subscription?.cancel());
            return;
          }
          bytes.addAll(chunk);
        },
        onError: (Object _) {
          if (!completion.isCompleted) {
            completion.completeError(
              const OAuthException(
                'OAuthConfigurationUnreadable',
                'The selected OAuth file could not be read.',
              ),
            );
          }
        },
        onDone: () {
          if (completion.isCompleted) return;
          try {
            if (generation != _generation) throw _cancelled;
            completion.complete(
              stage(parseGoogleDesktopConfiguration(bytes, config)),
            );
          } on Object catch (error) {
            completion.completeError(error);
          }
        },
        cancelOnError: true,
      );
      _read = subscription;
      return await pending;
    } finally {
      timer.cancel();
      await subscription?.cancel();
      if (identical(_read, subscription)) _read = null;
      if (identical(_reading, completion)) _reading = null;
      bytes.clear();
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
              config.microsoftOAuthClientId.trim().toLowerCase()
          ? RegistrationOrigin.retiringShared
          : RegistrationOrigin.userProvided,
    );
    return stage(registration);
  }

  RegistrationHandle stage(OAuthRegistration value) {
    final known = value is GoogleDesktopRegistration
        ? config.googleOAuthClientId
        : config.microsoftOAuthClientId;
    if (_knownRetiringClients.contains(value.clientId.toLowerCase()) ||
        (known.isNotEmpty &&
            value.clientId.toLowerCase() == known.trim().toLowerCase())) {
      value = switch (value) {
        GoogleDesktopRegistration() => GoogleDesktopRegistration(
          clientId: value.clientId,
          clientSecret: value.clientSecret,
          projectId: value.projectId,
          origin: RegistrationOrigin.retiringShared,
        ),
        MicrosoftPublicRegistration() => MicrosoftPublicRegistration(
          clientId: value.clientId,
          audience: value.audience,
          tenantId: value.tenantId,
          platform: value.platform,
          origin: RegistrationOrigin.retiringShared,
        ),
      };
    }
    for (final key in _entries.keys.toList()) {
      discard(key);
    }
    final id = const Uuid().v4();
    _entries[id] = (value, Timer(lifetime, () => discard(id)));
    return RegistrationHandle(id, value.summary());
  }

  OAuthRegistration consume(RegistrationHandle handle) {
    final entry = _entries.remove(handle.id);
    if (entry == null) {
      throw const OAuthException(
        'OAuthConfigurationExpired',
        'Select your registration again. The previous selection expired or was consumed.',
      );
    }
    entry.$2.cancel();
    return entry.$1;
  }

  void discard(String id) {
    _entries.remove(id)?.$2.cancel();
  }

  void cancel() {
    _generation++;
    if (_reading case final reading? when !reading.isCompleted) {
      reading.completeError(_cancelled);
    }
    unawaited(_read?.cancel());
    for (final key in _entries.keys.toList()) {
      discard(key);
    }
  }

  void dispose() => cancel();
  static const _cancelled = OAuthException(
    'OAuthSignInCancelled',
    'Registration setup was cancelled.',
  );
}

/// A Windows drive prefix is a native path, not an imported URI scheme.
/// Remote UNC/device paths and URI-backed sources require a separate adapter.
bool isSupportedRegistrationFilePath(String path, {required bool windows}) =>
    windows
    ? RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)
    : path.startsWith('/') && Uri.tryParse(path)?.hasScheme != true;

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
      !RegExp(
        r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
      ).hasMatch(clientId) ||
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
    origin: clientId == config.googleOAuthClientId.trim()
        ? RegistrationOrigin.retiringShared
        : RegistrationOrigin.userProvided,
  );
}

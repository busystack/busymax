import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@visibleForTesting
const nativeDialogChannelName = 'busymax/native_dialogs';

/// Result of asking the platform to present a native confirmation dialog.
///
/// [available] distinguishes a user cancellation from a platform that does
/// not implement the native dialog bridge.
@immutable
class NativeConfirmationResult {
  const NativeConfirmationResult({
    required this.available,
    this.confirmed = false,
  });

  const NativeConfirmationResult.unavailable()
    : available = false,
      confirmed = false;

  final bool available;
  final bool confirmed;
}

/// Presents confirmation UI owned by the host desktop toolkit.
///
/// Linux implements this with a transient `GtkMessageDialog`. Other hosts can
/// omit the channel; callers then use their themed Flutter fallback.
class NativeDialogService {
  const NativeDialogService({
    MethodChannel channel = const MethodChannel(nativeDialogChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<NativeConfirmationResult> confirm({
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required bool destructive,
  }) async {
    try {
      final confirmed = await _channel.invokeMethod<bool>('confirm', {
        'title': title,
        'message': message,
        'cancelLabel': cancelLabel,
        'confirmLabel': confirmLabel,
        'destructive': destructive,
      });
      if (confirmed == null) {
        return const NativeConfirmationResult.unavailable();
      }
      return NativeConfirmationResult(available: true, confirmed: confirmed);
    } on MissingPluginException {
      return const NativeConfirmationResult.unavailable();
    } on PlatformException {
      return const NativeConfirmationResult.unavailable();
    }
  }
}

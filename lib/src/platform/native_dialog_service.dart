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

@immutable
class NativeTimeZoneOption {
  const NativeTimeZoneOption({
    required this.id,
    required this.region,
    required this.name,
    required this.englishName,
    required this.title,
    required this.subtitle,
    required this.searchText,
  });

  final String id;
  final String region;
  final String name;
  final String englishName;
  final String title;
  final String subtitle;
  final String searchText;

  Map<String, String> toMessage() {
    return {
      'id': id,
      'region': region,
      'name': name,
      'englishName': englishName,
      'title': title,
      'subtitle': subtitle,
      'searchText': searchText,
    };
  }
}

@immutable
class NativeTimeZoneSelectionResult {
  const NativeTimeZoneSelectionResult({
    required this.available,
    this.selectedTimeZone,
  });

  const NativeTimeZoneSelectionResult.unavailable()
    : available = false,
      selectedTimeZone = null;

  final bool available;
  final String? selectedTimeZone;
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

  Future<NativeTimeZoneSelectionResult> selectTimeZone({
    required String title,
    required String searchPlaceholder,
    required String noResultsLabel,
    required String selectedTimeZone,
    required List<NativeTimeZoneOption> options,
  }) async {
    try {
      final selected = await _channel.invokeMethod<String>('selectTimeZone', {
        'title': title,
        'searchPlaceholder': searchPlaceholder,
        'noResultsLabel': noResultsLabel,
        'selectedTimeZone': selectedTimeZone,
        'options': options.map((option) => option.toMessage()).toList(),
      });
      return NativeTimeZoneSelectionResult(
        available: true,
        selectedTimeZone: selected,
      );
    } on MissingPluginException {
      return const NativeTimeZoneSelectionResult.unavailable();
    } on PlatformException {
      return const NativeTimeZoneSelectionResult.unavailable();
    }
  }
}

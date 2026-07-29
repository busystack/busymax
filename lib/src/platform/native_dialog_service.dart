import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'linux_header_bar_service.dart';

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

/// Semantic presentation values shared with Flutter's grouped-list component.
///
/// The Linux host keeps its native GTK input and Handy rows, while these
/// values prevent the native result groups from developing a separate visual
/// language from BusyMaxGroupedList.
@immutable
class NativeGroupedListStyle {
  const NativeGroupedListStyle({
    required this.surfaceColor,
    required this.dividerColor,
    required this.sectionHeaderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.hoverColor,
    required this.shadowColor,
    required this.outlineColor,
    required this.highContrast,
    required this.radius,
    required this.sectionTopSpacing,
    required this.sectionHorizontalPadding,
    required this.titleBottomSpacing,
  });

  final Color surfaceColor;
  final Color dividerColor;
  final Color sectionHeaderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color hoverColor;
  final Color shadowColor;
  final Color outlineColor;
  final bool highContrast;
  final int radius;
  final int sectionTopSpacing;
  final int sectionHorizontalPadding;
  final int titleBottomSpacing;

  Map<String, Object> toMessage() {
    return {
      'surfaceColor': busyMaxCssColor(surfaceColor),
      'dividerColor': busyMaxCssColor(dividerColor),
      'sectionHeaderColor': busyMaxCssColor(sectionHeaderColor),
      'primaryTextColor': busyMaxCssColor(primaryTextColor),
      'secondaryTextColor': busyMaxCssColor(secondaryTextColor),
      'hoverColor': busyMaxCssColor(hoverColor),
      'shadowColor': busyMaxCssColor(shadowColor),
      'outlineColor': busyMaxCssColor(outlineColor),
      'highContrast': highContrast,
      'radius': radius,
      'sectionTopSpacing': sectionTopSpacing,
      'sectionHorizontalPadding': sectionHorizontalPadding,
      'titleBottomSpacing': titleBottomSpacing,
    };
  }
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
    required NativeGroupedListStyle groupedListStyle,
  }) async {
    try {
      final selected = await _channel.invokeMethod<String>('selectTimeZone', {
        'title': title,
        'searchPlaceholder': searchPlaceholder,
        'noResultsLabel': noResultsLabel,
        'selectedTimeZone': selectedTimeZone,
        'options': options.map((option) => option.toMessage()).toList(),
        'groupedListStyle': groupedListStyle.toMessage(),
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

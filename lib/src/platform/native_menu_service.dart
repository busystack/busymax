import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@visibleForTesting
const nativeMenuChannelName = 'busymax/native_menus';

/// Identifies one native menu presentation.
///
/// The host compares this identity when dismissing a menu, so a retiring
/// widget can never close a newer caller's popover.
@immutable
final class NativeMenuSession {
  NativeMenuSession() : id = _nextId++;

  static int _nextId = 1;

  final int id;
}

/// One command exposed by a host-toolkit menu.
///
/// Entries intentionally contain presentation state only. The selected index
/// is mapped back to the caller's domain value after the native menu closes.
@immutable
final class NativeMenuEntry {
  const NativeMenuEntry({
    required this.label,
    this.enabled = true,
    this.selected = false,
  });

  final String label;
  final bool enabled;
  final bool selected;

  Map<String, Object> _toPlatformMap() {
    return <String, Object>{
      'label': label,
      'enabled': enabled,
      'selected': selected,
    };
  }
}

/// Result of asking the host toolkit to present a native menu.
///
/// [available] distinguishes a dismissed native menu from a host that does not
/// implement the bridge. When available, a null [selectedIndex] means that the
/// user dismissed the menu without choosing an entry.
@immutable
final class NativeMenuResult {
  const NativeMenuResult.available({this.selectedIndex}) : available = true;

  const NativeMenuResult.unavailable()
    : available = false,
      selectedIndex = null;

  final bool available;
  final int? selectedIndex;
}

/// Presents an anchored menu owned by the host desktop toolkit.
///
/// Hosts that do not implement the channel are reported as unavailable so the
/// caller can use its themed Flutter fallback.
class NativeMenuService {
  const NativeMenuService({
    MethodChannel channel = const MethodChannel(nativeMenuChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<NativeMenuResult> show({
    required NativeMenuSession session,
    required Rect anchor,
    required List<NativeMenuEntry> entries,
    bool focusFirst = false,
  }) async {
    try {
      final selectedIndex = await _channel.invokeMethod<int>('show', {
        'sessionId': session.id,
        'anchor': <String, double>{
          'x': anchor.left,
          'y': anchor.top,
          'width': anchor.width,
          'height': anchor.height,
        },
        'entries': [for (final entry in entries) entry._toPlatformMap()],
        'focusFirst': focusFirst,
      });
      return NativeMenuResult.available(selectedIndex: selectedIndex);
    } on MissingPluginException {
      return const NativeMenuResult.unavailable();
    } on PlatformException catch (error) {
      if (error.code == 'unavailable') {
        return const NativeMenuResult.unavailable();
      }
      rethrow;
    }
  }

  /// Dismisses [session] if it is still owned by the native host.
  ///
  /// Returns false when no menu was dismissed or the host does not implement
  /// the native menu bridge.
  Future<bool> dismiss(NativeMenuSession session) async {
    try {
      return await _channel.invokeMethod<bool>('dismiss', {
            'sessionId': session.id,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      if (error.code == 'unavailable') {
        return false;
      }
      rethrow;
    }
  }
}

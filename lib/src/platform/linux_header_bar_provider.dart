import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'linux_header_bar_service.dart';

/// Application-scoped owner of the native Linux header-bar bridge.
///
/// Keeping the provider beside the platform service lets shared presentation
/// infrastructure resolve the bridge without depending on the application's
/// composition root.
final linuxHeaderBarServiceProvider = Provider<LinuxHeaderBarService>((ref) {
  final service = LinuxHeaderBarService();
  ref.onDispose(service.dispose);
  return service;
});

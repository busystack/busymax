import 'dart:async';

import 'package:busymax/src/features/notifications/desktop_notification_backend.dart';

class RecordingNotificationBackend implements DesktopNotificationBackend {
  final requests = <BusyMaxNotificationRequest>[];
  final actions = <DesktopNotificationActionHandler?>[];
  final cancelledIds = <String>[];
  final cancellationAttempts = <String>[];
  final activeIds = <String>{};
  int cancellationFailuresRemaining = 0;
  Completer<void>? barrier;
  Object? error;
  int attempts = 0;

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    attempts++;
    if (error != null) throw error!;
    requests.add(request);
    actions.add(onAction);
    await barrier?.future;
    activeIds.add(request.stableId);
  }

  Future<void> invoke(int index, String action) async {
    await actions[index]?.call(action, requests[index].payload);
  }

  @override
  Future<void> cancel(String stableId) async {
    cancellationAttempts.add(stableId);
    if (cancellationFailuresRemaining > 0) {
      cancellationFailuresRemaining--;
      throw StateError('Temporary cancellation failure');
    }
    cancelledIds.add(stableId);
    activeIds.remove(stableId);
  }

  @override
  Future<void> close() async {}
}

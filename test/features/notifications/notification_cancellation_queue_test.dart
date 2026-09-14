import 'dart:async';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_cancellation_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recording_notification_backend.dart';

void main() {
  test(
    'pending cancellation keeps its original backend across service replacement',
    () async {
      final queue = NotificationCancellationQueue();
      final oldBackend = RecordingNotificationBackend()
        ..cancellationFailuresRemaining = 1;
      final oldService = DesktopNotificationService(
        backend: oldBackend,
        settings: AppSettings.defaults(),
        cancellationQueue: queue,
      );
      expect(await oldService.cancelReminder('old-delivery'), isFalse);
      final newBackend = RecordingNotificationBackend();
      final replacement = DesktopNotificationService(
        backend: newBackend,
        settings: AppSettings.defaults(),
        cancellationQueue: queue,
      );
      await replacement.retryReminderCancellations();
      expect(oldBackend.cancelledIds, ['old-delivery']);
      expect(newBackend.cancelledIds, isEmpty);
      await replacement.retryReminderCancellations();
      expect(oldBackend.cancellationAttempts, hasLength(2));
    },
  );

  test(
    'concurrent cancellation requests share one native attempt and complete',
    () async {
      final queue = NotificationCancellationQueue();
      final barrier = Completer<void>();
      var attempts = 0;
      Future<void> close() async {
        attempts++;
        await barrier.future;
      }

      final first = queue.cancel('delivery', close);
      final second = queue.cancel('delivery', close);
      expect(attempts, 1);
      barrier.complete();
      expect(await Future.wait([first, second]), [true, true]);
      await queue.retry();
      expect(attempts, 1);
    },
  );
}

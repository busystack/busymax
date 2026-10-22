abstract interface class NotificationReconciler {
  Future<void> reconcile();
}

abstract interface class OperationalNotificationReporter {
  Future<void> notifySyncFailure(Object error, {String? accountId});
  Future<void> notifyConflict(String summary);
}

final class CallbackOperationalNotificationReporter
    implements OperationalNotificationReporter {
  const CallbackOperationalNotificationReporter({
    required this.onSyncFailure,
    required this.onConflict,
  });

  final Future<void> Function(Object error, {String? accountId}) onSyncFailure;
  final Future<void> Function(String summary) onConflict;

  @override
  Future<void> notifySyncFailure(Object error, {String? accountId}) =>
      onSyncFailure(error, accountId: accountId);

  @override
  Future<void> notifyConflict(String summary) => onConflict(summary);
}

final class CallbackNotificationReconciler implements NotificationReconciler {
  const CallbackNotificationReconciler(this._callback);

  final Future<void> Function() _callback;

  @override
  Future<void> reconcile() => _callback();
}

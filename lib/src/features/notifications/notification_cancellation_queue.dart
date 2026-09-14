/// Owns failed native cancellations independently of scheduler and settings
/// lifetimes. Each entry retains the backend that created that delivery.
class NotificationCancellationQueue {
  final _pending = <String, Future<void> Function()>{};
  final _inFlight = <String, Future<bool>>{};

  Future<bool> cancel(String deliveryId, Future<void> Function() cancel) {
    _pending.putIfAbsent(deliveryId, () => cancel);
    return _attempt(deliveryId);
  }

  Future<void> retry() async {
    for (final deliveryId in _pending.keys.toList()) {
      await _attempt(deliveryId);
    }
  }

  Future<bool> _attempt(String deliveryId) => _inFlight.putIfAbsent(
    deliveryId,
    () => _perform(deliveryId).whenComplete(() {
      _inFlight.remove(deliveryId);
    }),
  );

  Future<bool> _perform(String deliveryId) async {
    final cancel = _pending[deliveryId];
    if (cancel == null) return true;
    try {
      await cancel();
      _pending.remove(deliveryId);
      return true;
    } on Object {
      // One unavailable notification must not block unrelated work.
      return false;
    }
  }
}

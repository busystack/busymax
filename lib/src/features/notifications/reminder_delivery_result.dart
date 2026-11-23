enum ReminderDeliveryStatus { delivered, deferred, disabled, failed }

final class ReminderDeliveryResult {
  const ReminderDeliveryResult._(this.status, {this.retryAtUtc});

  const ReminderDeliveryResult.delivered()
    : this._(ReminderDeliveryStatus.delivered);

  const ReminderDeliveryResult.disabled()
    : this._(ReminderDeliveryStatus.disabled);

  const ReminderDeliveryResult.deferred(DateTime retryAtUtc)
    : this._(ReminderDeliveryStatus.deferred, retryAtUtc: retryAtUtc);

  const ReminderDeliveryResult.failed(DateTime retryAtUtc)
    : this._(ReminderDeliveryStatus.failed, retryAtUtc: retryAtUtc);

  final ReminderDeliveryStatus status;
  final DateTime? retryAtUtc;
}

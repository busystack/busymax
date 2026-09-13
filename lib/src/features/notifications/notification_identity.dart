/// Each delivery has its own desktop ID, so cancelling an earlier delivery
/// cannot remove a newer notification for the same schedule.
String notificationDeliveryId(String scheduleId, String generation) =>
    generation == 'legacy' ? scheduleId : '$scheduleId|$generation';

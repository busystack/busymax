class TaskRemoteError implements Exception {
  const TaskRemoteError({
    required this.statusCode,
    this.code,
    required this.message,
    this.retryable = false,
    this.providerDetails,
  });

  final int statusCode;
  final String? code;
  final String message;
  final bool retryable;
  final Map<String, Object?>? providerDetails;

  @override
  String toString() => 'TaskRemoteError($code, HTTP $statusCode)';
}

enum TaskDueKind { date, floatingDateTime, utcDateTime, zonedDateTime }

class TaskDueValue {
  const TaskDueValue({
    required this.kind,
    required this.value,
    this.timeZoneId,
  });

  final TaskDueKind kind;
  final String value;
  final String? timeZoneId;
}

enum TaskCompletionState { needsAction, inProcess, completed, cancelled }

class TaskReminderValue {
  const TaskReminderValue({
    this.absolute,
    this.relativeOffset,
    this.extensionData = const {},
  });

  final TaskDueValue? absolute;
  final Duration? relativeOffset;
  final Map<String, Object?> extensionData;
}

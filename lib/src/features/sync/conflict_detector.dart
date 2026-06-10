import '../../google_tasks/api/google_tasks_json.dart';
import 'conflict_models.dart';

class ConflictDetector {
  const ConflictDetector();

  PendingMutationConflict detect({
    required String entityType,
    required String entityId,
    required Map<String, Object?> localPendingFields,
    required Map<String, Object?> lastServerJson,
    required Map<String, Object?> currentServerJson,
    required DateTime? baselineUpdatedUtc,
    required DateTime? currentUpdatedUtc,
  }) {
    if (baselineUpdatedUtc == null ||
        currentUpdatedUtc == null ||
        !currentUpdatedUtc.isAfter(baselineUpdatedUtc)) {
      return PendingMutationConflict(
        entityType: entityType,
        entityId: entityId,
        changedFields: const {},
      );
    }

    final overlapping = <String>{};
    for (final field in localPendingFields.keys) {
      final lastValue = _comparableValue(field, lastServerJson[field]);
      final currentValue = _comparableValue(field, currentServerJson[field]);
      if (lastValue != currentValue) {
        overlapping.add(field);
      }
    }

    return PendingMutationConflict(
      entityType: entityType,
      entityId: entityId,
      changedFields: overlapping,
    );
  }

  Object? _comparableValue(String field, Object? value) {
    if (field == 'due') {
      return normalizeGoogleDueDateValue(value);
    }
    return value;
  }
}

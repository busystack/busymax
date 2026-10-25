import 'package:collection/collection.dart';

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
    bool compareWithoutRevision = false,
  }) {
    if (!compareWithoutRevision &&
        (baselineUpdatedUtc == null ||
            currentUpdatedUtc == null ||
            !currentUpdatedUtc.isAfter(baselineUpdatedUtc))) {
      return PendingMutationConflict(
        entityType: entityType,
        entityId: entityId,
        changedFields: const {},
      );
    }

    final overlapping = <String>{};
    for (final field in localPendingFields.keys) {
      if (!fieldValuesEqual(
        field,
        lastServerJson[field],
        currentServerJson[field],
      )) {
        overlapping.add(field);
      }
    }

    return PendingMutationConflict(
      entityType: entityType,
      entityId: entityId,
      changedFields: overlapping,
    );
  }

  bool fieldValuesEqual(String field, Object? first, Object? second) {
    return const DeepCollectionEquality().equals(
      _comparableValue(field, first),
      _comparableValue(field, second),
    );
  }

  Object? _comparableValue(String field, Object? value) {
    if (field == 'due') {
      return normalizeGoogleDueDateValue(value);
    }
    return value;
  }
}

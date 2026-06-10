class PendingMutationConflict {
  const PendingMutationConflict({
    required this.entityType,
    required this.entityId,
    required this.changedFields,
  });

  final String entityType;
  final String entityId;
  final Set<String> changedFields;

  bool get hasConflict => changedFields.isNotEmpty;
}

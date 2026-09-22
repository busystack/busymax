import 'dart:convert';

const taskChecklistLocalIdentityAliasesKey = '_busymaxLocalIdentityAliases';

class TaskChecklistItemEntity {
  const TaskChecklistItemEntity({
    required this.id,
    required this.title,
    required this.completed,
    required this.rawJson,
    this.createdAtUtc,
    this.completedAtUtc,
  });

  factory TaskChecklistItemEntity.fromJson(Map<String, Object?> json) {
    return TaskChecklistItemEntity(
      id: json['id']?.toString() ?? '',
      title: json['displayName']?.toString() ?? '',
      completed: json['isChecked'] == true,
      createdAtUtc: _dateTimeOrNull(json['createdDateTime']),
      completedAtUtc: _dateTimeOrNull(json['checkedDateTime']),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String id;
  final String title;
  final bool completed;
  final DateTime? createdAtUtc;
  final DateTime? completedAtUtc;
  final Map<String, Object?> rawJson;

  Map<String, Object?> toJson() => Map<String, Object?>.from(rawJson);

  Set<String> get localIdentityAliases {
    final aliases = rawJson[taskChecklistLocalIdentityAliasesKey];
    return {
      if (aliases is List)
        for (final alias in aliases)
          if (alias != null && alias.toString().isNotEmpty) alias.toString(),
    };
  }

  bool matchesIdentity(String candidate) {
    if (id == candidate) return true;
    return localIdentityAliases.contains(candidate);
  }

  TaskChecklistItemEntity withLocalIdentityAlias(String? alias) {
    if (alias == null || alias.isEmpty || alias == id) return this;
    final aliases = <String>{...localIdentityAliases, alias};
    return TaskChecklistItemEntity.fromJson({
      ...rawJson,
      taskChecklistLocalIdentityAliasesKey: aliases.toList(growable: false),
    });
  }
}

List<TaskChecklistItemEntity> decodeTaskChecklistItems(String? source) {
  if (source == null || source.isEmpty) return const [];
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];
    return [
      for (final value in decoded)
        if (value is Map)
          TaskChecklistItemEntity.fromJson(value.cast<String, Object?>()),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeTaskChecklistItems(
  Iterable<TaskChecklistItemEntity> checklistItems,
) => jsonEncode([for (final item in checklistItems) item.toJson()]);

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}

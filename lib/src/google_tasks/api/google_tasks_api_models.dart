import 'google_tasks_json.dart';

class TaskListDto {
  const TaskListDto({
    required this.id,
    required this.title,
    required this.rawJson,
    this.kind,
    this.etag,
    this.updated,
    this.selfLink,
  });

  factory TaskListDto.fromJson(Map<String, Object?> json) {
    return TaskListDto(
      kind: json['kind']?.toString(),
      id: json['id']?.toString() ?? '',
      etag: json['etag']?.toString(),
      title: json['title']?.toString() ?? '',
      updated: _dateTimeOrNull(json['updated']),
      selfLink: json['selfLink']?.toString(),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? kind;
  final String id;
  final String? etag;
  final String title;
  final DateTime? updated;
  final String? selfLink;
  final Map<String, Object?> rawJson;
}

class TaskListsPageDto {
  const TaskListsPageDto({
    required this.items,
    required this.rawJson,
    this.kind,
    this.etag,
    this.nextPageToken,
  });

  factory TaskListsPageDto.fromJson(Map<String, Object?> json) {
    return TaskListsPageDto(
      kind: json['kind']?.toString(),
      etag: json['etag']?.toString(),
      nextPageToken: json['nextPageToken']?.toString(),
      items: jsonObjectList(json['items']).map(TaskListDto.fromJson).toList(),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? kind;
  final String? etag;
  final String? nextPageToken;
  final List<TaskListDto> items;
  final Map<String, Object?> rawJson;
}

class TaskDto {
  const TaskDto({
    required this.id,
    required this.title,
    required this.rawJson,
    this.kind,
    this.etag,
    this.updated,
    this.selfLink,
    this.parent,
    this.position,
    this.notes,
    this.status,
    this.due,
    this.completed,
    this.deleted,
    this.hidden,
    this.links = const [],
    this.webViewLink,
    this.assignmentInfo,
  });

  factory TaskDto.fromJson(Map<String, Object?> json) {
    final links = jsonObjectList(json['links']).map(TaskLinkDto.fromJson);
    final assignmentInfo = json['assignmentInfo'] is Map
        ? (json['assignmentInfo'] as Map).cast<String, Object?>()
        : null;

    return TaskDto(
      kind: json['kind']?.toString(),
      id: json['id']?.toString() ?? '',
      etag: json['etag']?.toString(),
      title: json['title']?.toString() ?? '',
      updated: _dateTimeOrNull(json['updated']),
      selfLink: json['selfLink']?.toString(),
      parent: json['parent']?.toString(),
      position: json['position']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      due: _dateTimeOrNull(json['due']),
      completed: _dateTimeOrNull(json['completed']),
      deleted: _boolOrNull(json['deleted']),
      hidden: _boolOrNull(json['hidden']),
      links: List.unmodifiable(links),
      webViewLink: json['webViewLink']?.toString(),
      assignmentInfo: assignmentInfo == null
          ? null
          : Map.unmodifiable(assignmentInfo),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? kind;
  final String id;
  final String? etag;
  final String title;
  final DateTime? updated;
  final String? selfLink;
  final String? parent;
  final String? position;
  final String? notes;
  final String? status;
  final DateTime? due;
  final DateTime? completed;
  final bool? deleted;
  final bool? hidden;
  final List<TaskLinkDto> links;
  final String? webViewLink;
  final Map<String, Object?>? assignmentInfo;
  final Map<String, Object?> rawJson;
}

class TaskLinkDto {
  const TaskLinkDto({
    required this.rawJson,
    this.type,
    this.description,
    this.link,
  });

  factory TaskLinkDto.fromJson(Map<String, Object?> json) {
    return TaskLinkDto(
      type: json['type']?.toString(),
      description: json['description']?.toString(),
      link: json['link']?.toString(),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? type;
  final String? description;
  final String? link;
  final Map<String, Object?> rawJson;
}

class TasksPageDto {
  const TasksPageDto({
    required this.items,
    required this.rawJson,
    this.kind,
    this.etag,
    this.nextPageToken,
  });

  factory TasksPageDto.fromJson(Map<String, Object?> json) {
    return TasksPageDto(
      kind: json['kind']?.toString(),
      etag: json['etag']?.toString(),
      nextPageToken: json['nextPageToken']?.toString(),
      items: jsonObjectList(json['items']).map(TaskDto.fromJson).toList(),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? kind;
  final String? etag;
  final String? nextPageToken;
  final List<TaskDto> items;
  final Map<String, Object?> rawJson;
}

abstract class GoogleTasksMutation {
  const GoogleTasksMutation(this.fields);

  final Map<String, Object?> fields;

  Map<String, Object?> toJson() => Map.unmodifiable(fields);
}

class TaskListPatch extends GoogleTasksMutation {
  const TaskListPatch(super.fields);

  factory TaskListPatch.title(String title) => TaskListPatch({'title': title});
}

class TaskListPut extends GoogleTasksMutation {
  const TaskListPut(super.fields);

  factory TaskListPut.title(String title) => TaskListPut({'title': title});
}

class TaskCreate extends GoogleTasksMutation {
  const TaskCreate.fields(super.fields);

  factory TaskCreate({
    String? title,
    String? notes,
    String? status,
    DateTime? due,
  }) {
    return TaskCreate.fields({
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (due != null) 'due': encodeGoogleDueDate(due),
    });
  }
}

class TaskPatch extends GoogleTasksMutation {
  const TaskPatch.fields(super.fields);

  factory TaskPatch({
    String? title,
    String? notes,
    String? status,
    DateTime? due,
    DateTime? completed,
    bool? deleted,
    bool clearDue = false,
    bool clearCompleted = false,
  }) {
    return TaskPatch.fields({
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (due != null) 'due': encodeGoogleDueDate(due),
      if (completed != null) 'completed': encodeGoogleDateTime(completed),
      if (deleted != null) 'deleted': deleted,
      if (clearDue) 'due': null,
      if (clearCompleted) 'completed': null,
    });
  }
}

class TaskPut extends GoogleTasksMutation {
  const TaskPut.fields(super.fields);

  factory TaskPut({
    required String title,
    String? notes,
    String? status,
    DateTime? due,
    DateTime? completed,
    bool? deleted,
  }) {
    return TaskPut.fields({
      'title': title,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (due != null) 'due': encodeGoogleDueDate(due),
      if (completed != null) 'completed': encodeGoogleDateTime(completed),
      if (deleted != null) 'deleted': deleted,
    });
  }
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value.toString()).toUtc();
}

bool? _boolOrNull(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return value.toString() == 'true';
}

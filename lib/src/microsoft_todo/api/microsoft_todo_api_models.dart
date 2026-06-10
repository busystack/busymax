import 'microsoft_todo_json.dart';

class MicrosoftDateTimeTimeZoneDto {
  const MicrosoftDateTimeTimeZoneDto({
    required this.dateTime,
    required this.timeZone,
  });

  factory MicrosoftDateTimeTimeZoneDto.fromJson(Map<String, Object?> json) {
    return MicrosoftDateTimeTimeZoneDto(
      dateTime: json['dateTime']?.toString() ?? '',
      timeZone: json['timeZone']?.toString() ?? '',
    );
  }

  final String dateTime;
  final String timeZone;

  Map<String, Object?> toJson() => {'dateTime': dateTime, 'timeZone': timeZone};
}

class MicrosoftItemBodyDto {
  const MicrosoftItemBodyDto({this.content, this.contentType});

  factory MicrosoftItemBodyDto.fromJson(Map<String, Object?> json) {
    return MicrosoftItemBodyDto(
      content: json['content']?.toString(),
      contentType: json['contentType']?.toString(),
    );
  }

  final String? content;
  final String? contentType;

  Map<String, Object?> toJson() => {
    if (content != null) 'content': content,
    if (contentType != null) 'contentType': contentType,
  };
}

class MicrosoftTodoUserDto {
  const MicrosoftTodoUserDto({
    required this.id,
    required this.rawJson,
    this.displayName,
    this.mail,
    this.userPrincipalName,
  });

  factory MicrosoftTodoUserDto.fromJson(Map<String, Object?> json) {
    return MicrosoftTodoUserDto(
      id: json['id']?.toString() ?? '',
      displayName: microsoftStringOrNull(json['displayName']),
      mail: microsoftStringOrNull(json['mail']),
      userPrincipalName: microsoftStringOrNull(json['userPrincipalName']),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String id;
  final String? displayName;
  final String? mail;
  final String? userPrincipalName;
  final Map<String, Object?> rawJson;
}

class MicrosoftTodoTaskListDto {
  const MicrosoftTodoTaskListDto({
    required this.id,
    required this.rawJson,
    this.displayName,
    this.isOwner,
    this.isShared,
    this.wellknownListName,
    this.removed = false,
    this.removedReason,
  });

  factory MicrosoftTodoTaskListDto.fromJson(Map<String, Object?> json) {
    final removed = microsoftJsonObjectOrNull(json['@removed']);
    return MicrosoftTodoTaskListDto(
      id: json['id']?.toString() ?? '',
      displayName: microsoftStringOrNull(json['displayName']),
      isOwner: microsoftBoolOrNull(json['isOwner']),
      isShared: microsoftBoolOrNull(json['isShared']),
      wellknownListName: microsoftStringOrNull(json['wellknownListName']),
      rawJson: Map.unmodifiable(json),
      removed: removed != null,
      removedReason: microsoftStringOrNull(removed?['reason']),
    );
  }

  final String id;
  final String? displayName;
  final bool? isOwner;
  final bool? isShared;
  final String? wellknownListName;
  final Map<String, Object?> rawJson;
  final bool removed;
  final String? removedReason;
}

class MicrosoftTodoTaskDto {
  const MicrosoftTodoTaskDto({
    required this.id,
    required this.categories,
    required this.rawJson,
    this.etag,
    this.title,
    this.body,
    this.completedDateTime,
    this.dueDateTime,
    this.reminderDateTime,
    this.startDateTime,
    this.isReminderOn,
    this.importance,
    this.status,
    this.recurrence,
    this.hasAttachments,
    this.createdDateTime,
    this.lastModifiedDateTime,
    this.bodyLastModifiedDateTime,
    this.removed = false,
    this.removedReason,
  });

  factory MicrosoftTodoTaskDto.fromJson(Map<String, Object?> json) {
    final removed = microsoftJsonObjectOrNull(json['@removed']);
    return MicrosoftTodoTaskDto(
      id: json['id']?.toString() ?? '',
      etag: microsoftStringOrNull(json['@odata.etag']),
      title: microsoftStringOrNull(json['title']),
      body: _body(json['body']),
      categories: [
        for (final category
            in json['categories'] is List
                ? json['categories']! as List
                : const <Object?>[])
          category.toString(),
      ],
      completedDateTime: _dateTimeTimeZone(json['completedDateTime']),
      dueDateTime: _dateTimeTimeZone(json['dueDateTime']),
      reminderDateTime: _dateTimeTimeZone(json['reminderDateTime']),
      startDateTime: _dateTimeTimeZone(json['startDateTime']),
      isReminderOn: microsoftBoolOrNull(json['isReminderOn']),
      importance: microsoftStringOrNull(json['importance']),
      status: microsoftStringOrNull(json['status']),
      recurrence: microsoftJsonObjectOrNull(json['recurrence']),
      hasAttachments: microsoftBoolOrNull(json['hasAttachments']),
      createdDateTime: microsoftStringOrNull(json['createdDateTime']),
      lastModifiedDateTime: microsoftStringOrNull(json['lastModifiedDateTime']),
      bodyLastModifiedDateTime: microsoftStringOrNull(
        json['bodyLastModifiedDateTime'],
      ),
      rawJson: Map.unmodifiable(json),
      removed: removed != null,
      removedReason: microsoftStringOrNull(removed?['reason']),
    );
  }

  final String id;
  final String? etag;
  final String? title;
  final MicrosoftItemBodyDto? body;
  final List<String> categories;
  final MicrosoftDateTimeTimeZoneDto? completedDateTime;
  final MicrosoftDateTimeTimeZoneDto? dueDateTime;
  final MicrosoftDateTimeTimeZoneDto? reminderDateTime;
  final MicrosoftDateTimeTimeZoneDto? startDateTime;
  final bool? isReminderOn;
  final String? importance;
  final String? status;
  final Map<String, Object?>? recurrence;
  final bool? hasAttachments;
  final String? createdDateTime;
  final String? lastModifiedDateTime;
  final String? bodyLastModifiedDateTime;
  final Map<String, Object?> rawJson;
  final bool removed;
  final String? removedReason;
}

class MicrosoftTodoTaskListsPageDto {
  const MicrosoftTodoTaskListsPageDto({
    required this.items,
    required this.rawJson,
    this.nextLink,
  });

  factory MicrosoftTodoTaskListsPageDto.fromJson(Map<String, Object?> json) {
    return MicrosoftTodoTaskListsPageDto(
      items: microsoftJsonObjectList(
        json['value'],
      ).map(MicrosoftTodoTaskListDto.fromJson).toList(),
      nextLink: microsoftStringOrNull(json['@odata.nextLink']),
      rawJson: Map.unmodifiable(json),
    );
  }

  final List<MicrosoftTodoTaskListDto> items;
  final String? nextLink;
  final Map<String, Object?> rawJson;
}

class MicrosoftTodoTaskListsDeltaPageDto extends MicrosoftTodoTaskListsPageDto {
  const MicrosoftTodoTaskListsDeltaPageDto({
    required super.items,
    required super.rawJson,
    super.nextLink,
    this.deltaLink,
  });

  factory MicrosoftTodoTaskListsDeltaPageDto.fromJson(
    Map<String, Object?> json,
  ) {
    return MicrosoftTodoTaskListsDeltaPageDto(
      items: microsoftJsonObjectList(
        json['value'],
      ).map(MicrosoftTodoTaskListDto.fromJson).toList(),
      nextLink: microsoftStringOrNull(json['@odata.nextLink']),
      deltaLink: microsoftStringOrNull(json['@odata.deltaLink']),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? deltaLink;
}

class MicrosoftTodoTasksPageDto {
  const MicrosoftTodoTasksPageDto({
    required this.items,
    required this.rawJson,
    this.nextLink,
  });

  factory MicrosoftTodoTasksPageDto.fromJson(Map<String, Object?> json) {
    return MicrosoftTodoTasksPageDto(
      items: microsoftJsonObjectList(
        json['value'],
      ).map(MicrosoftTodoTaskDto.fromJson).toList(),
      nextLink: microsoftStringOrNull(json['@odata.nextLink']),
      rawJson: Map.unmodifiable(json),
    );
  }

  final List<MicrosoftTodoTaskDto> items;
  final String? nextLink;
  final Map<String, Object?> rawJson;
}

class MicrosoftTodoTasksDeltaPageDto extends MicrosoftTodoTasksPageDto {
  const MicrosoftTodoTasksDeltaPageDto({
    required super.items,
    required super.rawJson,
    super.nextLink,
    this.deltaLink,
  });

  factory MicrosoftTodoTasksDeltaPageDto.fromJson(Map<String, Object?> json) {
    return MicrosoftTodoTasksDeltaPageDto(
      items: microsoftJsonObjectList(
        json['value'],
      ).map(MicrosoftTodoTaskDto.fromJson).toList(),
      nextLink: microsoftStringOrNull(json['@odata.nextLink']),
      deltaLink: microsoftStringOrNull(json['@odata.deltaLink']),
      rawJson: Map.unmodifiable(json),
    );
  }

  final String? deltaLink;
}

MicrosoftDateTimeTimeZoneDto? _dateTimeTimeZone(Object? value) {
  final json = microsoftJsonObjectOrNull(value);
  if (json == null) {
    return null;
  }
  return MicrosoftDateTimeTimeZoneDto.fromJson(json);
}

MicrosoftItemBodyDto? _body(Object? value) {
  final json = microsoftJsonObjectOrNull(value);
  if (json == null) {
    return null;
  }
  return MicrosoftItemBodyDto.fromJson(json);
}

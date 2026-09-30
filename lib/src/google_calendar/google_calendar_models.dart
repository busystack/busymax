class GoogleCalendarPage {
  const GoogleCalendarPage({
    required this.items,
    this.nextPageToken,
    this.nextSyncToken,
  });

  factory GoogleCalendarPage.fromJson(Map<String, Object?> json) {
    return GoogleCalendarPage(
      items: _mapItems(json),
      nextPageToken: json['nextPageToken']?.toString(),
      nextSyncToken: json['nextSyncToken']?.toString(),
    );
  }

  final List<Map<String, Object?>> items;
  final String? nextPageToken;
  final String? nextSyncToken;
}

class GoogleColorsDto {
  const GoogleColorsDto({required this.rawJson});

  factory GoogleColorsDto.fromJson(Map<String, Object?> json) {
    return GoogleColorsDto(rawJson: json);
  }

  final Map<String, Object?> rawJson;
}

final class GoogleEventLabel {
  const GoogleEventLabel({
    required this.id,
    required this.name,
    required this.backgroundColor,
  });

  factory GoogleEventLabel.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final color = json['backgroundColor'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        color is! String ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      throw const FormatException('Malformed Google event label.');
    }
    return GoogleEventLabel(id: id, name: name, backgroundColor: color);
  }

  final String id;
  final String name;
  final String backgroundColor;
}

final class GoogleAclRule {
  const GoogleAclRule({
    required this.id,
    required this.role,
    required this.scopeType,
    this.scopeValue,
  });

  factory GoogleAclRule.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final role = json['role'];
    final scope = json['scope'];
    if (id is! String ||
        id.isEmpty ||
        role is! String ||
        role.isEmpty ||
        scope is! Map ||
        scope['type'] is! String ||
        (scope['type'] as String).isEmpty) {
      throw const FormatException('Malformed Google calendar ACL rule.');
    }
    return GoogleAclRule(
      id: id,
      role: role,
      scopeType: scope['type'] as String,
      scopeValue: scope['value']?.toString(),
    );
  }

  final String id;
  final String role;
  final String scopeType;
  final String? scopeValue;
}

List<Map<String, Object?>> _mapItems(Map<String, Object?> json) {
  final items = json['items'];
  if (items is! List) {
    return const [];
  }
  return items
      .whereType<Map>()
      .map((item) => item.cast<String, Object?>())
      .toList();
}

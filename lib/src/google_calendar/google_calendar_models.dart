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

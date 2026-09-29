class MicrosoftGraphCollectionPage {
  const MicrosoftGraphCollectionPage({
    required this.items,
    this.nextLink,
    this.deltaLink,
  });

  factory MicrosoftGraphCollectionPage.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    if (value is! List || value.any((item) => item is! Map)) {
      throw const FormatException('Malformed Microsoft Graph collection.');
    }
    return MicrosoftGraphCollectionPage(
      items: value
          .cast<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList(),
      nextLink: json['@odata.nextLink']?.toString(),
      deltaLink: json['@odata.deltaLink']?.toString(),
    );
  }

  final List<Map<String, Object?>> items;
  final String? nextLink;
  final String? deltaLink;
}

class MicrosoftGraphCollectionPage {
  const MicrosoftGraphCollectionPage({
    required this.items,
    this.nextLink,
    this.deltaLink,
  });

  factory MicrosoftGraphCollectionPage.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    return MicrosoftGraphCollectionPage(
      items: value is List
          ? value
                .whereType<Map>()
                .map((item) => item.cast<String, Object?>())
                .toList()
          : const [],
      nextLink: json['@odata.nextLink']?.toString(),
      deltaLink: json['@odata.deltaLink']?.toString(),
    );
  }

  final List<Map<String, Object?>> items;
  final String? nextLink;
  final String? deltaLink;
}

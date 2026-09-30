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

/// Outlook's account-owned category catalog. Category names on events and
/// tasks remain authoritative even when this optional lookup is unavailable.
final class MicrosoftMasterCategory {
  const MicrosoftMasterCategory({
    required this.id,
    required this.displayName,
    required this.color,
  });

  factory MicrosoftMasterCategory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['displayName'];
    final color = json['color'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        color is! String ||
        color.isEmpty) {
      throw const FormatException('Malformed Outlook master category.');
    }
    return MicrosoftMasterCategory(id: id, displayName: name, color: color);
  }

  final String id;
  final String displayName;
  final String color;
}

/// Representative swatches for Graph's Outlook category-color constants.
/// Outlook clients may render a different shade of the same named color.
int? microsoftCategorySwatchArgb(String preset) {
  const swatches = <int>[
    0xffd13438, // Red
    0xffef6950, // Orange
    0xff8e562e, // Brown
    0xffe9b437, // Yellow
    0xff498205, // Green
    0xff00a2ae, // Teal
    0xff8c8e25, // Olive
    0xff0078d4, // Blue
    0xff8764b8, // Purple
    0xffc239b3, // Cranberry
    0xff69797e, // Steel
    0xff4f5d62, // Dark steel
    0xff8a8886, // Gray
    0xff605e5c, // Dark gray
    0xff323130, // Black
    0xffa4262c, // Dark red
    0xffca5010, // Dark orange
    0xff6b3b16, // Dark brown
    0xffa79a26, // Dark yellow
    0xff0b6a0b, // Dark green
    0xff038387, // Dark teal
    0xff6a6b18, // Dark olive
    0xff004578, // Dark blue
    0xff5c2e91, // Dark purple
    0xff931d7d, // Dark cranberry
  ];
  final match = RegExp(
    r'^preset(\d+)$',
    caseSensitive: false,
  ).firstMatch(preset);
  if (match == null) return null;
  final index = int.tryParse(match.group(1)!);
  return index == null || index >= swatches.length ? null : swatches[index];
}

final class MicrosoftCalendarPermission {
  const MicrosoftCalendarPermission({
    required this.id,
    required this.role,
    required this.allowedRoles,
    required this.isRemovable,
    this.name,
    this.address,
  });

  factory MicrosoftCalendarPermission.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final role = json['role'];
    final allowed = json['allowedRoles'];
    if (id is! String ||
        id.isEmpty ||
        role is! String ||
        role.isEmpty ||
        allowed is! List ||
        allowed.any((value) => value is! String) ||
        json['isRemovable'] is! bool) {
      throw const FormatException('Malformed Microsoft calendar permission.');
    }
    final email = json['emailAddress'];
    if (email != null && email is! Map) {
      throw const FormatException('Malformed permission recipient.');
    }
    return MicrosoftCalendarPermission(
      id: id,
      role: role,
      allowedRoles: List.unmodifiable(allowed.cast<String>()),
      isRemovable: json['isRemovable'] as bool,
      name: email is Map ? email['name']?.toString() : null,
      address: email is Map ? email['address']?.toString() : null,
    );
  }

  final String id;
  final String role;
  final List<String> allowedRoles;
  final bool isRemovable;
  final String? name;
  final String? address;
}

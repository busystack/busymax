import 'dart:convert';

/// A local source key that keeps an owner-mailbox calendar distinct from a
/// recipient-local share with the same Graph calendar ID.
final class MicrosoftSharedPrimaryCalendarAddress {
  const MicrosoftSharedPrimaryCalendarAddress({
    required this.owner,
    required this.graphCalendarId,
  });

  final String owner;
  final String graphCalendarId;

  static const _prefix = 'busymax-shared-primary:';

  String get sourceCalendarId =>
      '$_prefix${base64Url.encode(utf8.encode(owner))}:${base64Url.encode(utf8.encode(graphCalendarId))}';

  static MicrosoftSharedPrimaryCalendarAddress? parse(String value) {
    if (!value.startsWith(_prefix)) return null;
    final parts = value.substring(_prefix.length).split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid owner calendar key.');
    }
    try {
      final owner = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[0])),
      );
      final id = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      if (owner.isEmpty || id.isEmpty) {
        throw const FormatException('Invalid owner calendar key.');
      }
      return MicrosoftSharedPrimaryCalendarAddress(
        owner: owner,
        graphCalendarId: id,
      );
    } on FormatException {
      throw const FormatException('Invalid owner calendar key.');
    }
  }
}

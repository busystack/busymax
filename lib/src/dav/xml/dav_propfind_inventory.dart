import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../dav_errors.dart';
import 'dav_xml.dart';

/// Validate PROPFIND response structure before using first-property accessors.
/// Incremental RFC 6578 responses have a different grammar and do not use this.
DavMultistatus parseDavPropfindInventory(
  DavXmlParser parser,
  Uint8List bytes, {
  String? correlationId,
}) {
  Never incomplete() => throw DavException(
    kind: DavErrorKind.protocol,
    code: 'DavIncompleteInventory',
    safeMessage: 'The DAV inventory was incomplete. Cached data was retained.',
    correlationId: correlationId,
  );
  final root = parser
      .parseDocument(bytes, correlationId: correlationId)
      .rootElement;
  List<XmlElement> children(XmlElement element, String local) => element
      .childElements
      .where(
        (e) => e.name.namespaceUri == davNamespace && e.name.local == local,
      )
      .toList();
  if (root.name.namespaceUri != davNamespace ||
      root.name.local != 'multistatus') {
    incomplete();
  }
  for (final response in children(root, 'response')) {
    final hrefs = children(response, 'href');
    final stats = children(response, 'propstat');
    final statuses = children(response, 'status');
    if (hrefs.length != 1 ||
        hrefs.single.childElements.isNotEmpty ||
        hrefs.single.innerText.trim().isEmpty ||
        statuses.length > 1 ||
        (statuses.isNotEmpty && stats.isNotEmpty) ||
        (statuses.isEmpty && stats.isEmpty)) {
      incomplete();
    }
    // Preserve resource-level failures for the caller's status classification.
    // They never establish a complete inventory or an absent member.
    if (statuses.isNotEmpty) {
      if (statuses.single.childElements.isNotEmpty) incomplete();
      continue;
    }
    if (children(response, 'error').isNotEmpty) incomplete();
    final seen = <DavPropertyName>{};
    for (final stat in stats) {
      final props = children(stat, 'prop');
      final statuses = children(stat, 'status');
      if (props.length != 1 ||
          statuses.length != 1 ||
          statuses.single.childElements.isNotEmpty ||
          children(stat, 'error').isNotEmpty) {
        incomplete();
      }
      for (final property in props.single.childElements) {
        if (!seen.add(
          DavPropertyName(property.name.namespaceUri, property.name.local),
        )) {
          incomplete();
        }
      }
    }
  }
  final result = parser.parseMultistatus(bytes, correlationId: correlationId);
  if (result.responses.isEmpty || result.errorConditions.isNotEmpty) {
    incomplete();
  }
  return result;
}

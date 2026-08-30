Uri davCollectionUri(Uri uri) {
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  return uri.replace(path: path, query: null, fragment: null);
}

String nextcloudCollectionMemberName(
  String displayName, {
  required Uri homeUri,
  required Iterable<Uri> existingCollectionUris,
}) {
  var candidate = displayName
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^\w-]+'), '')
      .replaceAll(RegExp(r'--+'), '-')
      .replaceFirst(RegExp(r'^-+'), '')
      .replaceFirst(RegExp(r'-+$'), '');
  if (candidate.isEmpty) candidate = '-';
  final home = davCollectionUri(homeUri);
  final occupied = {
    for (final uri in existingCollectionUris) davCollectionUri(uri).toString(),
  };
  bool available(String value) =>
      !occupied.contains(davCollectionUri(home.resolve(value)).toString());
  if (available(candidate)) return candidate;
  if (!candidate.contains('-')) {
    candidate = '$candidate-1';
    if (available(candidate)) return candidate;
  }
  do {
    final lastDash = candidate.lastIndexOf('-');
    final first = candidate.substring(0, lastDash);
    final suffix = candidate.substring(lastDash + 1);
    final number = int.tryParse(suffix);
    candidate = number == null ? '$candidate-1' : '$first-${number + 1}';
  } while (!available(candidate));
  return candidate;
}

String escapeDavXmlText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

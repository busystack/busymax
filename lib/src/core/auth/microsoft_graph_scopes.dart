/// Compares the short and fully qualified spellings returned for Microsoft
/// Graph delegated scopes. Other resource URLs retain their distinct names.
String microsoftGraphScopeName(String scope) {
  final normalized = scope.trim().toLowerCase();
  const graphPrefix = 'https://graph.microsoft.com/';
  return normalized.startsWith(graphPrefix)
      ? normalized.substring(graphPrefix.length)
      : normalized;
}

bool hasMicrosoftGraphScope(Iterable<String> granted, String required) {
  final name = microsoftGraphScopeName(required);
  return granted.any((scope) => microsoftGraphScopeName(scope) == name);
}

bool hasMicrosoftGraphScopes(
  Iterable<String> granted,
  Iterable<String> required,
) {
  final names = granted.map(microsoftGraphScopeName).toSet();
  return required.every(
    (scope) => names.contains(microsoftGraphScopeName(scope)),
  );
}

/// Syntax checks only. Provider publishing, verification and consent remain
/// owner-controlled release prerequisites and cannot be inferred from these values.
bool validGoogleDesktopConfiguration({
  required String clientId,
  required String clientSecret,
  required String projectId,
}) =>
    RegExp(r'^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$')
        .hasMatch(clientId.trim()) &&
    RegExp(r'^[a-z][a-z0-9-]{4,62}[a-z0-9]$').hasMatch(projectId.trim()) &&
    clientSecret.trim().isNotEmpty;

bool validMicrosoftDesktopConfiguration({required String clientId}) =>
    _uuid.hasMatch(clientId.trim());

final _uuid = RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');

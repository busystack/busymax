/// Validated input for the existing contacts-only enrollment operations.
final class DavContactsEnrollment {
  const DavContactsEnrollment._(
    this.label,
    this.server,
    this.username,
    this.password,
  );

  static DavContactsEnrollment? parse({
    required String label,
    required String server,
    required String username,
    required String password,
    bool nextcloud = false,
  }) {
    final endpoint = Uri.tryParse(server.trim());
    final name = label.trim();
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        name.isEmpty ||
        (!nextcloud && (username.isEmpty || password.isEmpty))) {
      return null;
    }
    return DavContactsEnrollment._(name, endpoint, username, password);
  }

  final String label;
  final Uri server;
  final String username;
  final String password;
}

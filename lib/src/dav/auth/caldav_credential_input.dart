import '../../providers/account_authority.dart';

final class CalDavCredentialInput {
  const CalDavCredentialInput({
    required this.serverUrl,
    required this.username,
    required this.password,
  });
  final String serverUrl;
  final String username;
  final String password;

  bool get isValid =>
      isSafeServer(serverUrl) &&
      username.trim().isNotEmpty &&
      !username.contains(':') &&
      password.isNotEmpty &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch('$username$password');

  static bool isSafeServer(String value) {
    try {
      normalizeCalDavAuthority(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  @override
  String toString() => 'CalDavCredentialInput([REDACTED])';
}

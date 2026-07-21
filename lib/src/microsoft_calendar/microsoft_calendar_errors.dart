import 'dart:convert';

import 'package:http/http.dart' as http;

class MicrosoftCalendarApiError implements Exception {
  const MicrosoftCalendarApiError({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  factory MicrosoftCalendarApiError.fromResponse(http.Response response) {
    var code = 'MicrosoftCalendarApiError';
    var message =
        'Microsoft Graph calendar request failed '
        'with ${response.statusCode}.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          code = error['code']?.toString() ?? code;
          message = error['message']?.toString() ?? message;
        }
      }
    } on Object {
      // Keep the generic message when Graph returns non-JSON.
    }
    return MicrosoftCalendarApiError(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }

  final int statusCode;
  final String code;
  final String message;

  bool get isInvalidSyncState {
    final normalizedCode = code.toLowerCase();
    return statusCode == 410 ||
        normalizedCode == 'syncstatenotfound' ||
        normalizedCode == 'resyncrequired';
  }

  @override
  String toString() => '$code: $message';
}

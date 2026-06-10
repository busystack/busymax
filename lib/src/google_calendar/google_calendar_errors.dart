import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleCalendarApiError implements Exception {
  const GoogleCalendarApiError({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  factory GoogleCalendarApiError.fromResponse(http.Response response) {
    var code = 'GoogleCalendarApiError';
    var message = 'Google Calendar request failed with ${response.statusCode}.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          code = error['status']?.toString() ?? code;
          message = error['message']?.toString() ?? message;
        }
      }
    } on Object {
      // Keep the generic message when the response is not JSON.
    }
    return GoogleCalendarApiError(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }

  final int statusCode;
  final String code;
  final String message;

  bool get isInvalidSyncToken => statusCode == 410;

  @override
  String toString() => '$code: $message';
}

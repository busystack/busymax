import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/http/retry_after.dart';

class MicrosoftCalendarApiError implements Exception {
  const MicrosoftCalendarApiError({
    required this.statusCode,
    required this.code,
    required this.message,
    this.retryAfter,
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
      retryAfter: parseHttpRetryAfter(response.headers['retry-after']),
    );
  }

  final int statusCode;
  final String code;
  final String message;
  final Duration? retryAfter;

  bool get isRateLimited => statusCode == 429;

  bool get isInvalidSyncState {
    final normalizedCode = code.toLowerCase();
    return statusCode == 410 ||
        normalizedCode == 'syncstatenotfound' ||
        normalizedCode == 'resyncrequired';
  }

  @override
  String toString() => '$code: $message';
}

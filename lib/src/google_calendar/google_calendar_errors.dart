import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/http/retry_after.dart';

class GoogleCalendarApiError implements Exception {
  const GoogleCalendarApiError({
    required this.statusCode,
    required this.code,
    required this.message,
    this.reasons = const [],
    this.retryAfter,
  });

  factory GoogleCalendarApiError.fromResponse(http.Response response) {
    var code = 'GoogleCalendarApiError';
    var message = 'Google Calendar request failed with ${response.statusCode}.';
    final reasons = <String>[];
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          code = error['status']?.toString() ?? code;
          message = error['message']?.toString() ?? message;
          final entries = error['errors'];
          if (entries is List) {
            for (final entry in entries) {
              if (entry is Map && entry['reason'] is String) {
                reasons.add(entry['reason'] as String);
              }
            }
          }
        }
      }
    } on Object {
      // Keep the generic message when the response is not JSON.
    }
    return GoogleCalendarApiError(
      statusCode: response.statusCode,
      code: code,
      message: message,
      reasons: List.unmodifiable(reasons),
      retryAfter: parseHttpRetryAfter(response.headers['retry-after']),
    );
  }

  final int statusCode;
  final String code;
  final String message;
  final List<String> reasons;
  final Duration? retryAfter;

  bool get isRateLimited =>
      statusCode == 429 ||
      statusCode == 403 &&
          reasons.any(
            (reason) =>
                reason == 'rateLimitExceeded' ||
                reason == 'userRateLimitExceeded',
          );

  bool get isInvalidSyncToken => statusCode == 410;

  @override
  String toString() => '$code: $message';
}

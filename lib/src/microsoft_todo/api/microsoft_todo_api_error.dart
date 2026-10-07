import 'dart:convert';

import '../../core/logging/redacting_logger.dart';
import '../../core/http/retry_after.dart';

class MicrosoftTodoApiError implements Exception {
  const MicrosoftTodoApiError({
    required this.statusCode,
    required this.message,
    this.code,
    this.rawJson,
    this.retryAfter,
  });

  factory MicrosoftTodoApiError.fromResponse({
    required int statusCode,
    required String body,
    Map<String, String> headers = const {},
  }) {
    final retryAfter = parseHttpRetryAfter(headers['retry-after']);
    if (body.trim().isEmpty) {
      return MicrosoftTodoApiError(
        statusCode: statusCode,
        message: 'Microsoft Graph returned HTTP $statusCode.',
        retryAfter: retryAfter,
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final json = decoded.cast<String, Object?>();
        final error = json['error'];
        if (error is Map) {
          final errorJson = error.cast<String, Object?>();
          return MicrosoftTodoApiError(
            statusCode: statusCode,
            code: errorJson['code']?.toString(),
            message: redactForLog(errorJson['message']).trim().isEmpty
                ? 'Microsoft Graph returned HTTP $statusCode.'
                : redactForLog(errorJson['message']),
            rawJson: json,
            retryAfter: retryAfter,
          );
        }
        return MicrosoftTodoApiError(
          statusCode: statusCode,
          message: 'Microsoft Graph returned HTTP $statusCode.',
          rawJson: json,
          retryAfter: retryAfter,
        );
      }
    } on FormatException {
      return MicrosoftTodoApiError(
        statusCode: statusCode,
        message: redactForLog(body),
        retryAfter: retryAfter,
      );
    }

    return MicrosoftTodoApiError(
      statusCode: statusCode,
      message: redactForLog(body),
      retryAfter: retryAfter,
    );
  }

  final int statusCode;
  final String? code;
  final String message;
  final Map<String, Object?>? rawJson;
  final Duration? retryAfter;

  @override
  String toString() => 'MicrosoftTodoApiError($statusCode, $message)';
}

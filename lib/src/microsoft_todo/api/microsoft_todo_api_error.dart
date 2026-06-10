import 'dart:convert';

import '../../core/logging/redacting_logger.dart';

class MicrosoftTodoApiError implements Exception {
  const MicrosoftTodoApiError({
    required this.statusCode,
    required this.message,
    this.code,
    this.rawJson,
  });

  factory MicrosoftTodoApiError.fromResponse({
    required int statusCode,
    required String body,
  }) {
    if (body.trim().isEmpty) {
      return MicrosoftTodoApiError(
        statusCode: statusCode,
        message: 'Microsoft Graph returned HTTP $statusCode.',
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
          );
        }
        return MicrosoftTodoApiError(
          statusCode: statusCode,
          message: 'Microsoft Graph returned HTTP $statusCode.',
          rawJson: json,
        );
      }
    } on FormatException {
      return MicrosoftTodoApiError(
        statusCode: statusCode,
        message: redactForLog(body),
      );
    }

    return MicrosoftTodoApiError(
      statusCode: statusCode,
      message: redactForLog(body),
    );
  }

  final int statusCode;
  final String? code;
  final String message;
  final Map<String, Object?>? rawJson;

  @override
  String toString() => 'MicrosoftTodoApiError($statusCode, $message)';
}

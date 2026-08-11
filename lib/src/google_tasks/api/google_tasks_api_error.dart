import 'dart:convert';

import '../../features/tasks/domain/task_remote_error.dart';

class GoogleTasksApiError extends TaskRemoteError {
  const GoogleTasksApiError({
    required super.statusCode,
    required super.message,
    super.code,
    this.status,
    this.rawJson,
  }) : super(
         retryable: statusCode == 429 || statusCode >= 500,
         providerDetails: rawJson,
       );

  factory GoogleTasksApiError.fromResponse({
    required int statusCode,
    required String body,
  }) {
    if (body.isEmpty) {
      return GoogleTasksApiError(
        statusCode: statusCode,
        message: 'Google Tasks API returned HTTP $statusCode.',
      );
    }

    try {
      final decoded = jsonDecode(body) as Map<String, Object?>;
      final error = decoded['error'];
      if (error is Map) {
        final errorJson = error.cast<String, Object?>();
        return GoogleTasksApiError(
          statusCode: statusCode,
          code: errorJson['code']?.toString(),
          status: errorJson['status']?.toString(),
          message:
              errorJson['message']?.toString() ??
              'Google Tasks API returned HTTP $statusCode.',
          rawJson: decoded,
        );
      }
      return GoogleTasksApiError(
        statusCode: statusCode,
        message: 'Google Tasks API returned HTTP $statusCode.',
        rawJson: decoded,
      );
    } on Object {
      return GoogleTasksApiError(
        statusCode: statusCode,
        message: 'Google Tasks API returned HTTP $statusCode.',
      );
    }
  }

  final String? status;
  final Map<String, Object?>? rawJson;

  @override
  String toString() => 'GoogleTasksApiError($statusCode, $message)';
}

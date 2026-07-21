import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'feedback_submission.dart';

abstract interface class FeedbackSubmissionService {
  Future<FeedbackReceipt> submit(FeedbackSubmission submission);
}

class FeedbackReceipt {
  const FeedbackReceipt({required this.id});

  final String id;
}

class FeedbackApiClient implements FeedbackSubmissionService {
  FeedbackApiClient({
    required http.Client httpClient,
    required Uri endpoint,
    this.connectionTimeout = const Duration(seconds: 10),
    this.responseTimeout = const Duration(seconds: 20),
  }) : _httpClient = httpClient,
       _endpoint = endpoint;

  final http.Client _httpClient;
  final Uri _endpoint;
  final Duration connectionTimeout;
  final Duration responseTimeout;

  @override
  Future<FeedbackReceipt> submit(FeedbackSubmission submission) async {
    final request = http.Request('POST', _endpoint)
      ..headers.addAll(const {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
      })
      ..body = jsonEncode(submission.toJson());

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(connectionTimeout);
      final bodyBytes = await streamedResponse.stream.toBytes().timeout(
        responseTimeout,
      );

      return _handleResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        bodyBytes: bodyBytes,
      );
    } on TimeoutException {
      throw const FeedbackTimeoutFailure();
    } on IOException catch (error) {
      throw FeedbackConnectionFailure(error);
    } on http.ClientException catch (error) {
      throw FeedbackConnectionFailure(error);
    }
  }

  FeedbackReceipt _handleResponse({
    required int statusCode,
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) {
    if (statusCode == 201) {
      try {
        final decoded = jsonDecode(utf8.decode(bodyBytes));
        if (decoded is Map) {
          final id = decoded['id'];
          if (id is String && id.trim().isNotEmpty) {
            return FeedbackReceipt(id: id.trim());
          }
        }
      } on FormatException {
        // A successful response without a usable receipt is not accepted.
      }
      throw const FeedbackServerFailure(statusCode: 503);
    }

    if (statusCode == 400 || statusCode == 422) {
      throw FeedbackRejectedFailure(statusCode: statusCode);
    }
    if (statusCode == 429) {
      throw FeedbackRateLimitedFailure(
        retryAfter: _headerValue(headers, 'retry-after'),
      );
    }
    throw FeedbackServerFailure(statusCode: statusCode);
  }

  String? _headerValue(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) {
        return entry.value;
      }
    }
    return null;
  }
}

class FeedbackConnectionFailure implements Exception {
  const FeedbackConnectionFailure(this.cause);

  final Object cause;
}

class FeedbackTimeoutFailure implements Exception {
  const FeedbackTimeoutFailure();
}

class FeedbackRateLimitedFailure implements Exception {
  const FeedbackRateLimitedFailure({this.retryAfter});

  final String? retryAfter;
}

class FeedbackRejectedFailure implements Exception {
  const FeedbackRejectedFailure({required this.statusCode});

  final int statusCode;
}

class FeedbackServerFailure implements Exception {
  const FeedbackServerFailure({required this.statusCode});

  final int statusCode;
}

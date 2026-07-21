import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/features/feedback/data/feedback_api_client.dart';
import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts JSON to the configured endpoint and reads the receipt', () async {
    late http.Request recorded;
    final client = FeedbackApiClient(
      httpClient: MockClient((request) async {
        recorded = request;
        return http.Response(jsonEncode({'id': 'BM-2026-0001'}), 201);
      }),
      endpoint: Uri.parse('https://example.test/api/feedback'),
    );

    final receipt = await client.submit(_submission);

    expect(receipt.id, 'BM-2026-0001');
    expect(recorded.method, 'POST');
    expect(recorded.url, Uri.parse('https://example.test/api/feedback'));
    expect(recorded.headers['Content-Type'], 'application/json; charset=utf-8');
    expect(jsonDecode(recorded.body), _submission.toJson());
  });

  test('classifies rejected, rate-limited, and server responses', () async {
    Future<void> expectFailure(
      int statusCode,
      Matcher matcher, {
      Map<String, String> headers = const {},
    }) async {
      final client = FeedbackApiClient(
        httpClient: MockClient(
          (_) async => http.Response('{}', statusCode, headers: headers),
        ),
        endpoint: Uri.parse('https://example.test/api/feedback'),
      );
      await expectLater(client.submit(_submission), throwsA(matcher));
    }

    await expectFailure(422, isA<FeedbackRejectedFailure>());
    await expectFailure(
      429,
      isA<FeedbackRateLimitedFailure>().having(
        (failure) => failure.retryAfter,
        'retryAfter',
        '60',
      ),
      headers: const {'Retry-After': '60'},
    );
    await expectFailure(503, isA<FeedbackServerFailure>());
  });

  test('classifies a connection timeout', () async {
    final pending = Completer<http.Response>();
    final client = FeedbackApiClient(
      httpClient: MockClient((_) => pending.future),
      endpoint: Uri.parse('https://example.test/api/feedback'),
      connectionTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      client.submit(_submission),
      throwsA(isA<FeedbackTimeoutFailure>()),
    );
  });
}

const _submission = FeedbackSubmission(
  submissionId: 'bd142a44-e1f9-47b5-a923-57c9ce680f33',
  appVersion: '1.2.3',
  buildNumber: '45',
  category: FeedbackCategory.problem,
  subject: 'Calendar issue',
  message: 'The calendar view did not update.',
  replyEmail: null,
);

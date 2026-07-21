import 'dart:async';

import 'package:busymax/src/features/feedback/data/feedback_api_client.dart';
import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:busymax/src/features/feedback/presentation/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  testWidgets('shows required-field validation without sending', (
    tester,
  ) async {
    final service = _FakeFeedbackService((_) async {
      return const FeedbackReceipt(id: 'unexpected');
    });
    await _pumpDialog(tester, service);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Select a category.'), findsOneWidget);
    expect(
      find.text('Subject must be between 3 and 120 characters.'),
      findsOneWidget,
    );
    expect(
      find.text('Message must be between 10 and 5,000 characters.'),
      findsOneWidget,
    );
    expect(service.submissions, isEmpty);
  });

  testWidgets('rejects an invalid optional reply email', (tester) async {
    final service = _FakeFeedbackService((_) async {
      return const FeedbackReceipt(id: 'unexpected');
    });
    await _pumpDialog(tester, service);
    await _enterValidRequiredFields(tester);
    await tester.enterText(
      find.byKey(const Key('feedback-reply-email')),
      'not-an-email',
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(service.submissions, isEmpty);
  });

  testWidgets('shows loading state and prevents duplicate submission', (
    tester,
  ) async {
    final completion = Completer<FeedbackReceipt>();
    final service = _FakeFeedbackService((_) => completion.future);
    await _pumpDialog(tester, service);
    await _enterValidRequiredFields(tester);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    expect(service.submissions, hasLength(1));

    completion.complete(const FeedbackReceipt(id: 'BM-100'));
    await tester.pumpAndSettle();
  });

  testWidgets('disables Cancel while a submission is in progress', (
    tester,
  ) async {
    final completion = Completer<FeedbackReceipt>();
    final service = _FakeFeedbackService((_) => completion.future);
    var cancelCount = 0;
    await _pumpDialog(tester, service, onCancel: () => cancelCount += 1);
    await _enterValidRequiredFields(tester);

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(cancelCount, 0);
    expect(service.submissions, hasLength(1));

    completion.complete(const FeedbackReceipt(id: 'BM-101'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    expect(cancelCount, 1);
  });

  testWidgets('blocks Escape and barrier dismissal while submitting', (
    tester,
  ) async {
    final completion = Completer<FeedbackReceipt>();
    final service = _FakeFeedbackService((_) => completion.future);
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog(
                child: SizedBox(
                  width: 680,
                  height: 760,
                  child: BusyMaxFeedbackDialog(
                    submissionService: service,
                    onCancel: () => Navigator.of(dialogContext).pop(),
                    metadataLoader: () async => const FeedbackAppMetadata(
                      version: '1.2.3',
                      buildNumber: '45',
                    ),
                    submissionIdGenerator: () =>
                        'bd142a44-e1f9-47b5-a923-57c9ce680f33',
                    osVersionProvider: () => 'Test Linux',
                  ),
                ),
              ),
            ),
            child: const Text('Open feedback'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open feedback'));
    await tester.pumpAndSettle();
    await _enterValidRequiredFields(tester);
    await tester.tap(find.text('Submit'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('feedback-subject')), findsOneWidget);

    await tester.tapAt(const Offset(5, 300));
    await tester.pump();
    expect(find.byKey(const Key('feedback-subject')), findsOneWidget);
    expect(service.submissions, hasLength(1));

    completion.complete(const FeedbackReceipt(id: 'BM-102'));
    await tester.pumpAndSettle();
  });

  testWidgets('clears the form and shows the server reference on success', (
    tester,
  ) async {
    final service = _FakeFeedbackService((_) async {
      return const FeedbackReceipt(id: 'BM-2026-100');
    });
    await _pumpDialog(tester, service);
    await _enterValidRequiredFields(tester);

    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const Key('feedback-technical-details')),
    );
    expect(checkbox.value, isFalse);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback sent. Reference: BM-2026-100'), findsOneWidget);
    expect(_fieldText(tester, 'feedback-subject'), isEmpty);
    expect(_fieldText(tester, 'feedback-message'), isEmpty);
    expect(_fieldText(tester, 'feedback-reply-email'), isEmpty);
    expect(service.submissions.single.appVersion, '1.2.3');
    expect(service.submissions.single.buildNumber, '45');
    expect(service.submissions.single.technicalDetails, isNull);
  });

  testWidgets('keeps content and the submission UUID after server failure', (
    tester,
  ) async {
    var attempt = 0;
    final service = _FakeFeedbackService((_) async {
      attempt += 1;
      if (attempt == 1) {
        throw const FeedbackServerFailure(statusCode: 503);
      }
      return const FeedbackReceipt(id: 'BM-2026-101');
    });
    var generatedIds = 0;
    String generateId() {
      generatedIds += 1;
      return generatedIds == 1
          ? 'bd142a44-e1f9-47b5-a923-57c9ce680f33'
          : 'b3890182-a046-444c-b260-5db17fc13304';
    }

    await _pumpDialog(tester, service, submissionIdGenerator: generateId);
    await _enterValidRequiredFields(tester);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('BusyStack could not accept your feedback'),
      findsOneWidget,
    );
    expect(_fieldText(tester, 'feedback-subject'), 'Calendar issue');
    expect(
      _fieldText(tester, 'feedback-message'),
      'The calendar view did not update.',
    );

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(service.submissions, hasLength(2));
    expect(
      service.submissions[0].submissionId,
      service.submissions[1].submissionId,
    );
    expect(generatedIds, 2, reason: 'A new UUID is generated after success.');
  });

  testWidgets('rotates the submission UUID when a failed draft is edited', (
    tester,
  ) async {
    var attempt = 0;
    final service = _FakeFeedbackService((_) async {
      attempt += 1;
      if (attempt == 1) {
        throw const FeedbackConnectionFailure('response lost');
      }
      return const FeedbackReceipt(id: 'BM-2026-103');
    });
    const ids = [
      'bd142a44-e1f9-47b5-a923-57c9ce680f33',
      'b3890182-a046-444c-b260-5db17fc13304',
      '64579cb6-f420-4ad1-94b9-b3e187639c54',
    ];
    var generatedIds = 0;

    await _pumpDialog(
      tester,
      service,
      submissionIdGenerator: () => ids[generatedIds++],
    );
    await _enterValidRequiredFields(tester);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('feedback-subject')),
      'Updated calendar issue',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(service.submissions, hasLength(2));
    expect(
      service.submissions[1].submissionId,
      isNot(service.submissions[0].submissionId),
    );
    expect(service.submissions[1].subject, 'Updated calendar issue');
    expect(
      generatedIds,
      3,
      reason: 'UUIDs are generated initially, after the edit, and on success.',
    );
  });

  testWidgets('shows distinct connection, timeout, and rate-limit errors', (
    tester,
  ) async {
    final cases = <(Object, String)>[
      (
        const FeedbackConnectionFailure('offline'),
        'Could not connect to BusyStack. Check your connection and try again.',
      ),
      (
        const FeedbackTimeoutFailure(),
        'The request timed out. Your feedback has not been cleared; '
            'please try again.',
      ),
      (
        const FeedbackRateLimitedFailure(retryAfter: '60'),
        'Too many feedback submissions have been sent from this network. '
            'Please wait and try again.',
      ),
    ];

    for (final (failure, message) in cases) {
      final service = _FakeFeedbackService((_) async => throw failure);
      await _pumpDialog(tester, service);
      await _enterValidRequiredFields(tester);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(_fieldText(tester, 'feedback-subject'), 'Calendar issue');
    }
  });

  testWidgets('includes only consented OS version and locale', (tester) async {
    final service = _FakeFeedbackService((_) async {
      return const FeedbackReceipt(id: 'BM-2026-102');
    });
    await _pumpDialog(tester, service, osVersion: 'Test Linux 6.8');
    await _enterValidRequiredFields(tester);

    await tester.tap(find.text('Include technical details'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(service.submissions.single.technicalDetails?.toJson(), {
      'osVersion': 'Test Linux 6.8',
      'locale': 'en',
    });
  });
}

Future<void> _pumpDialog(
  WidgetTester tester,
  FeedbackSubmissionService service, {
  FeedbackSubmissionIdGenerator? submissionIdGenerator,
  String osVersion = 'Test Linux',
  VoidCallback? onCancel,
}) async {
  await tester.pumpWidget(
    localizedTestApp(
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 680,
            height: 760,
            child: BusyMaxFeedbackDialog(
              submissionService: service,
              onCancel: onCancel ?? () {},
              metadataLoader: () async => const FeedbackAppMetadata(
                version: '1.2.3',
                buildNumber: '45',
              ),
              submissionIdGenerator:
                  submissionIdGenerator ??
                  () => 'bd142a44-e1f9-47b5-a923-57c9ce680f33',
              osVersionProvider: () => osVersion,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterValidRequiredFields(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('feedback-category')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Problem or bug').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('feedback-subject')),
    'Calendar issue',
  );
  await tester.enterText(
    find.byKey(const Key('feedback-message')),
    'The calendar view did not update.',
  );
}

String _fieldText(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

class _FakeFeedbackService implements FeedbackSubmissionService {
  _FakeFeedbackService(this.handler);

  final Future<FeedbackReceipt> Function(FeedbackSubmission submission) handler;
  final submissions = <FeedbackSubmission>[];

  @override
  Future<FeedbackReceipt> submit(FeedbackSubmission submission) {
    submissions.add(submission);
    return handler(submission);
  }
}

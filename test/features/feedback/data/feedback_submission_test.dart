import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackValidation', () {
    test('requires a category', () {
      expect(FeedbackValidation.categoryIsValid(null), isFalse);
      expect(
        FeedbackValidation.categoryIsValid(FeedbackCategory.problem),
        isTrue,
      );
    });

    test('enforces trimmed subject boundaries', () {
      expect(FeedbackValidation.subjectIsValid('ab'), isFalse);
      expect(FeedbackValidation.subjectIsValid(' abc '), isTrue);
      expect(FeedbackValidation.subjectIsValid(_textOfLength(120)), isTrue);
      expect(FeedbackValidation.subjectIsValid(_textOfLength(121)), isFalse);
      expect(
        FeedbackValidation.subjectIsValid(_emojiTextOfLength(120)),
        isTrue,
      );
      expect(
        FeedbackValidation.subjectIsValid(_emojiTextOfLength(121)),
        isFalse,
      );
    });

    test('enforces trimmed message boundaries', () {
      expect(FeedbackValidation.messageIsValid(_textOfLength(9)), isFalse);
      expect(FeedbackValidation.messageIsValid(_textOfLength(10)), isTrue);
      expect(FeedbackValidation.messageIsValid(_textOfLength(5000)), isTrue);
      expect(FeedbackValidation.messageIsValid(_textOfLength(5001)), isFalse);
      expect(
        FeedbackValidation.messageIsValid(_emojiTextOfLength(5000)),
        isTrue,
      );
      expect(
        FeedbackValidation.messageIsValid(_emojiTextOfLength(5001)),
        isFalse,
      );
    });

    test('allows an empty reply email and rejects malformed email', () {
      expect(FeedbackValidation.replyEmailIsValid(''), isTrue);
      expect(
        FeedbackValidation.replyEmailIsValid('person@example.com'),
        isTrue,
      );
      expect(FeedbackValidation.replyEmailIsValid('not-an-email'), isFalse);
      expect(
        FeedbackValidation.replyEmailIsValid('person@example.com\r\nBcc:x'),
        isFalse,
      );
      for (final address in [
        'a,b@example.com',
        'a..b@example.com',
        'a@b..com',
        '.person@example.com',
        'person.@example.com',
        'person@-example.com',
        'person@example-.com',
        'person@example',
      ]) {
        expect(
          FeedbackValidation.replyEmailIsValid(address),
          isFalse,
          reason: address,
        );
      }
      expect(
        FeedbackValidation.replyEmailIsValid("person.o'neil+tag@example.co.uk"),
        isTrue,
      );
    });
  });

  test('serializes the required BusyMax request fields', () {
    const submission = FeedbackSubmission(
      submissionId: 'bd142a44-e1f9-47b5-a923-57c9ce680f33',
      appVersion: '1.2.3',
      buildNumber: '45',
      category: FeedbackCategory.privacySecurity,
      subject: '  Privacy question  ',
      message: '  Please explain this behavior.  ',
      replyEmail: '  person@example.com  ',
    );

    expect(submission.toJson(), {
      'submissionId': 'bd142a44-e1f9-47b5-a923-57c9ce680f33',
      'app': 'busymax',
      'appVersion': '1.2.3',
      'buildNumber': '45',
      'platform': 'linux',
      'category': 'privacy_security',
      'subject': 'Privacy question',
      'message': 'Please explain this behavior.',
      'replyEmail': 'person@example.com',
    });
  });

  test('serializes only explicitly approved technical details', () {
    const submission = FeedbackSubmission(
      submissionId: 'bd142a44-e1f9-47b5-a923-57c9ce680f33',
      appVersion: '1.2.3',
      buildNumber: '45',
      category: FeedbackCategory.problem,
      subject: 'Calendar issue',
      message: 'The calendar view did not update.',
      replyEmail: '   ',
      technicalDetails: FeedbackTechnicalDetails(
        osVersion: 'Linux 6.8.0',
        locale: 'en-CA',
      ),
    );

    final json = submission.toJson();
    expect(json['replyEmail'], isNull);
    expect(json['technicalDetails'], {
      'osVersion': 'Linux 6.8.0',
      'locale': 'en-CA',
    });
    expect(json.keys, isNot(contains('logs')));
    expect(json.keys, isNot(contains('hostname')));
    expect(json.keys, isNot(contains('username')));
  });
}

String _textOfLength(int length) => List.filled(length, 'a').join();

String _emojiTextOfLength(int length) => List.filled(length, '🙂').join();

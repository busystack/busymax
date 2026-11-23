import 'package:busymax/src/features/feedback/data/feedback_draft_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identical retries keep identity and editing starts a new attempt', () {
    var sequence = 0;
    final draft = FeedbackDraftSession(idGenerator: () => 'id-${++sequence}');
    draft.edited();
    expect(draft.beginAttempt(), 'id-1');
    expect(draft.beginAttempt(), 'id-1');
    draft.includeTechnicalDetails = true;
    draft.edited();
    draft.edited();
    expect(draft.beginAttempt(), 'id-2');
    draft.reset();
    expect(draft.includeTechnicalDetails, isFalse);
    expect(draft.beginAttempt(), 'id-3');
  });
}

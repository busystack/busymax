import 'package:uuid/uuid.dart';

final class FeedbackDraftSession {
  FeedbackDraftSession({String Function()? idGenerator})
    : _generateId = idGenerator ?? const Uuid().v4 {
    _submissionId = _generateId();
  }

  final String Function() _generateId;
  late String _submissionId;
  bool _attempted = false;
  bool submitting = false;
  bool includeTechnicalDetails = false;

  String beginAttempt() {
    _attempted = true;
    return _submissionId;
  }

  void edited() {
    if (_attempted) _newAttempt();
  }

  void reset() {
    includeTechnicalDetails = false;
    _newAttempt();
  }

  void _newAttempt() {
    _submissionId = _generateId();
    _attempted = false;
  }
}

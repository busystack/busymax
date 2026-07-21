enum FeedbackCategory {
  problem('problem'),
  feature('feature'),
  privacySecurity('privacy_security'),
  usability('usability'),
  other('other');

  const FeedbackCategory(this.apiValue);

  final String apiValue;
}

class FeedbackTechnicalDetails {
  const FeedbackTechnicalDetails({
    required this.osVersion,
    required this.locale,
  });

  final String osVersion;
  final String locale;

  Map<String, Object?> toJson() => {'osVersion': osVersion, 'locale': locale};
}

class FeedbackSubmission {
  const FeedbackSubmission({
    required this.submissionId,
    required this.appVersion,
    required this.buildNumber,
    required this.category,
    required this.subject,
    required this.message,
    required this.replyEmail,
    this.technicalDetails,
  });

  static const applicationId = 'busymax';
  static const platform = 'linux';

  final String submissionId;
  final String appVersion;
  final String buildNumber;
  final FeedbackCategory category;
  final String subject;
  final String message;
  final String? replyEmail;
  final FeedbackTechnicalDetails? technicalDetails;

  Map<String, Object?> toJson() => {
    'submissionId': submissionId,
    'app': applicationId,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'platform': platform,
    'category': category.apiValue,
    'subject': subject.trim(),
    'message': message.trim(),
    'replyEmail': _normalizedReplyEmail(replyEmail),
    if (technicalDetails case final details?)
      'technicalDetails': details.toJson(),
  };
}

abstract final class FeedbackValidation {
  static const minimumSubjectLength = 3;
  static const maximumSubjectLength = 120;
  static const minimumMessageLength = 10;
  static const maximumMessageLength = 5000;

  static final RegExp _emailLocalPartPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$",
  );
  static final RegExp _emailDomainLabelPattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
  );

  static bool categoryIsValid(FeedbackCategory? category) => category != null;

  static bool subjectIsValid(String subject) {
    final length = subject.trim().runes.length;
    return length >= minimumSubjectLength && length <= maximumSubjectLength;
  }

  static bool messageIsValid(String message) {
    final length = message.trim().runes.length;
    return length >= minimumMessageLength && length <= maximumMessageLength;
  }

  static bool replyEmailIsValid(String replyEmail) {
    final normalized = replyEmail.trim();
    if (normalized.isEmpty) {
      return true;
    }
    if (normalized.length > 254 ||
        normalized.codeUnits.any((unit) => unit < 33)) {
      return false;
    }

    final atIndex = normalized.indexOf('@');
    if (atIndex <= 0 || atIndex != normalized.lastIndexOf('@')) {
      return false;
    }

    final localPart = normalized.substring(0, atIndex);
    final domain = normalized.substring(atIndex + 1);
    if (localPart.length > 64 ||
        localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..') ||
        !_emailLocalPartPattern.hasMatch(localPart)) {
      return false;
    }

    final labels = domain.split('.');
    return labels.length >= 2 &&
        labels.every(_emailDomainLabelPattern.hasMatch);
  }
}

String? _normalizedReplyEmail(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

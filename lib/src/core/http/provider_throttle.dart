import 'dart:convert';

bool isGoogleQuotaResponse(int statusCode, String body) {
  if (statusCode == 429) return true;
  if (statusCode != 403) return false;
  try {
    final value = jsonDecode(body);
    if (value is! Map || value['error'] is! Map) return false;
    final error = value['error'] as Map;
    final reasons = error['errors'];
    return reasons is List &&
        reasons.any(
          (entry) =>
              entry is Map &&
              const {
                'rateLimitExceeded',
                'userRateLimitExceeded',
                'quotaExceeded',
                'dailyLimitExceeded',
              }.contains(entry['reason']),
        );
  } on Object {
    return false;
  }
}

import 'dart:io';

/// A server retry hint. Invalid or elapsed values are not usable cooldowns.
/// No upper bound is applied to an explicit server delay.
Duration? parseHttpRetryAfter(String? value, {DateTime? now}) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final seconds = int.tryParse(trimmed);
  if (seconds != null) {
    return seconds > 0 ? Duration(seconds: seconds) : null;
  }
  try {
    final until = HttpDate.parse(trimmed).toUtc();
    final duration = until.difference((now ?? DateTime.now()).toUtc());
    return duration > Duration.zero ? duration : null;
  } on Object {
    return null;
  }
}

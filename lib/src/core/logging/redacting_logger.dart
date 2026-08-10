import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

String redactForLog(Object? value) {
  var text = value?.toString() ?? '';
  text = text.replaceAllMapped(
    RegExp(r'\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    (match) => '${match.group(1)} [REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'\bAuthorization\s*[:=]\s*(?:(Bearer|Basic)\s+)?[^,\r\n}]+',
      caseSensitive: false,
    ),
    (match) =>
        'Authorization: ${match.group(1) == null ? '' : '${match.group(1)} '}'
        '[REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(r'\b(?:Set-)?Cookie\s*[:=]\s*[^\r\n]+', caseSensitive: false),
    (match) =>
        '${(match.group(0) ?? '').split(RegExp(r'[:=]')).first}: '
        '[REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(r'(https?://)[^/@\s]+@', caseSensitive: false),
    (match) => '${match.group(1)}[REDACTED]@',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'(^|[\s])((?:access|refresh|id)[_-]?token|code|code[_-]?verifier|client[_-]?secret|password|app[_-]?password|app[_-]?specific[_-]?password|poll[_-]?token)=([^&\s]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    (match) => '${match.group(1)}${match.group(2)}=[REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'([?&])((?:access|refresh|id)[_-]?token|token|code|code_verifier|client_secret|password|app[_-]?password|ticket|session|key)=([^&#\s]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)}=[REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'"(accessToken|refreshToken|idToken|token|clientSecret|client_secret|codeVerifier|appPassword|appSpecificPassword|password|pollToken|login|loginUrl|requestBody|responseBody|body|cookie)"\s*:\s*(?:"(?:\\.|[^"])*"|[^,}\s]+)',
      caseSensitive: false,
    ),
    (match) => '"${match.group(1)}":"[REDACTED]"',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'\b(access[_-]?token|refresh[_-]?token|id[_-]?token|client[_-]?secret|code[_-]?verifier|app[_-]?password|app[_-]?specific[_-]?password|password|poll[_-]?token|loginUrl|requestBody|responseBody|cookie)\s*([:=])\s*(?:"(?:\\.|[^"])*"|\x27[^\x27]*\x27|[^,}\s&#]+)',
      caseSensitive: false,
    ),
    (match) =>
        '${match.group(1)}${match.group(2)}'
        '${match.group(2) == '=' ? '' : ' '}[REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'\b(href|requestUri|objectUri|collectionUri)\s*([:=])\s*[^,}\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)} [REDACTED]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'\b(SUMMARY|DESCRIPTION|LOCATION|ATTENDEE|ORGANIZER|COMMENT|CONTACT|ATTACH|X-ALT-DESC)(?:;[^:\r\n]*)?:[^\r\n]*',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}:[REDACTED]',
  );
  return text;
}

void configureLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    final line =
        '[${record.level.name}] ${record.loggerName}: '
        '${redactForLog(record.message)}';
    if (kDebugMode) {
      debugPrint(line);
    } else {
      stderr.writeln(line);
    }
  });
}

class RedactingLogger {
  const RedactingLogger(this._logger);

  final Logger _logger;

  void fine(Object? message) => _logger.fine(redactForLog(message));
  void info(Object? message) => _logger.info(redactForLog(message));
  void warning(Object? message) => _logger.warning(redactForLog(message));
  void severe(Object? message) => _logger.severe(redactForLog(message));
}

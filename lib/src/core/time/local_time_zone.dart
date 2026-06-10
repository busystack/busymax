import 'dart:io';

String localIanaTimeZone() {
  try {
    final timezoneFile = File('/etc/timezone');
    if (timezoneFile.existsSync()) {
      final value = timezoneFile.readAsStringSync().trim();
      if (_looksLikeTimeZone(value)) {
        return value;
      }
    }

    final localtime = Link('/etc/localtime');
    if (localtime.existsSync()) {
      final target = localtime.targetSync();
      const prefix = '/usr/share/zoneinfo/';
      final index = target.indexOf(prefix);
      if (index >= 0) {
        final value = target.substring(index + prefix.length);
        if (_looksLikeTimeZone(value)) {
          return value;
        }
      }
    }
  } on Object {
    return 'UTC';
  }
  return 'UTC';
}

bool _looksLikeTimeZone(String value) {
  return value.isNotEmpty &&
      !value.contains('\n') &&
      !value.startsWith('/') &&
      value != 'posix' &&
      value != 'right';
}

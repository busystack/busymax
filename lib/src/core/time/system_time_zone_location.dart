import 'package:flutter/foundation.dart';

@immutable
class BusyMaxSystemTimeZoneLocation {
  const BusyMaxSystemTimeZoneLocation({
    required this.name,
    required this.englishName,
    required this.countryCode,
    required this.timeZoneId,
  });

  final String name;
  final String englishName;
  final String? countryCode;
  final String timeZoneId;

  bool matches(String normalizedQuery) {
    return name.toLowerCase().contains(normalizedQuery) ||
        englishName.toLowerCase().contains(normalizedQuery);
  }
}

/// A validated geographic point. Zero is a valid latitude and longitude.
final class GeographicPoint {
  const GeographicPoint._({required this.latitude, required this.longitude});
  factory GeographicPoint({
    required double latitude,
    required double longitude,
  }) {
    final point = tryParse(latitude: latitude, longitude: longitude);
    if (point == null) throw ArgumentError('Invalid geographic point');
    return point;
  }
  final double latitude;
  final double longitude;
  static GeographicPoint? tryParse({
    required Object? latitude,
    required Object? longitude,
  }) {
    double? number(Object? value) => value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value)
        : null;
    final lat = number(latitude);
    final lon = number(longitude);
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180)
      return null;
    return GeographicPoint._(latitude: lat, longitude: lon);
  }

  static GeographicPoint? fromJson(Object? value) => value is Map
      ? tryParse(latitude: value['latitude'], longitude: value['longitude'])
      : null;
  static GeographicPoint? fromIcal(String? value) {
    final parts = value?.split(';');
    return parts?.length == 2
        ? tryParse(latitude: parts![0], longitude: parts[1])
        : null;
  }

  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  String get icalValue => '$latitude;$longitude';
  String get directionsValue => '$latitude,$longitude';
  @override
  bool operator ==(Object other) =>
      other is GeographicPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;
  @override
  int get hashCode => Object.hash(latitude, longitude);
}

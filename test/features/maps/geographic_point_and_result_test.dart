import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeographicPoint', () {
    test('accepts zero and inclusive coordinate bounds', () {
      expect(
        GeographicPoint.tryParse(latitude: 0, longitude: 0),
        GeographicPoint(latitude: 0, longitude: 0),
      );
      expect(
        GeographicPoint.tryParse(latitude: '90', longitude: '-180'),
        GeographicPoint(latitude: 90, longitude: -180),
      );
      expect(
        GeographicPoint.tryParse(latitude: -90, longitude: 180),
        isNotNull,
      );
    });

    test('rejects out-of-bounds, malformed, and non-finite values', () {
      for (final values in [
        (91, 0),
        (-91, 0),
        (0, 181),
        (0, -181),
        (double.nan, 0),
        (0, double.infinity),
        ('north', 'west'),
      ]) {
        expect(
          GeographicPoint.tryParse(latitude: values.$1, longitude: values.$2),
          isNull,
        );
      }
    });

    test('serializes provider, iCalendar, and directions representations', () {
      final point = GeographicPoint(latitude: 49.2827, longitude: -123.1207);
      expect(point.toJson(), {'latitude': 49.2827, 'longitude': -123.1207});
      expect(point.icalValue, '49.2827;-123.1207');
      expect(GeographicPoint.fromIcal(point.icalValue), point);
      expect(point.directionsValue, '49.2827,-123.1207');
      expect(GeographicPoint.fromJson(point.toJson()), point);
      expect(GeographicPoint.fromIcal('49.2,-123.1'), isNull);
    });
  });

  group('LocationResult', () {
    final point = GeographicPoint(latitude: 0, longitude: 0);

    test('preserves formatted, named, type, and optional address data', () {
      final result = LocationResult(
        label: '1 Main Street, Example City',
        name: 'Example Hall',
        formattedAddress: '1 Main Street, Example City',
        point: point,
        resultType: 'amenity',
        address: const {
          'street': '1 Main Street',
          'city': 'Example City',
          'postalCode': 'A1A 1A1',
        },
      );

      expect(result.name, 'Example Hall');
      expect(result.formattedAddress, '1 Main Street, Example City');
      expect(result.approximate, isFalse);
      expect(result.microsoftLocation, {
        'displayName': result.label,
        'coordinates': {'latitude': 0.0, 'longitude': 0.0},
        'address': {
          'street': '1 Main Street',
          'city': 'Example City',
          'postalCode': 'A1A 1A1',
        },
      });
    });

    test('marks area-level result types as approximate', () {
      for (final type in ['city', 'street', 'postcode', 'state', 'country']) {
        expect(
          LocationResult(
            label: type,
            point: point,
            resultType: type,
          ).approximate,
          isTrue,
        );
      }
    });

    test('same label with a different point is a distinct replacement', () {
      final first = LocationResult(label: 'Hall', point: point);
      final second = LocationResult(
        label: 'Hall',
        point: GeographicPoint(latitude: 1, longitude: 2),
      );

      expect(first, isNot(second));
      expect(
        LocationChange.replace(first),
        isNot(LocationChange.replace(second)),
      );
    });
  });

  group('Google Maps directions URI', () {
    test('prefers coordinates and leaves origin and travel mode absent', () {
      final uri = googleMapsDirectionsUri(
        location: 'ignored',
        point: GeographicPoint(latitude: 0, longitude: -0.25),
      );
      expect(uri.queryParameters, {'api': '1', 'destination': '0.0,-0.25'});
      expect(uri.queryParameters, isNot(contains('origin')));
      expect(uri.queryParameters, isNot(contains('travelmode')));
    });

    test('encodes Unicode and reserved characters in text destinations', () {
      final uri = googleMapsDirectionsUri(location: 'Café & Hall / 東京');
      expect(uri.queryParameters['destination'], 'Café & Hall / 東京');
      expect(uri.toString(), contains('Caf%C3%A9+%26+Hall+%2F+'));
    });
  });
}

import 'package:busymax/src/features/maps/application/directions_launcher.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test(
    'launches coordinates in an external browser without Geoapify',
    () async {
      Uri? launched;
      LaunchMode? capturedMode;
      final result = await launchGoogleMapsDirections(
        location: 'fallback',
        point: GeographicPoint(latitude: 0, longitude: 0),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          launched = uri;
          capturedMode = mode;
          return true;
        },
      );

      expect(result, isTrue);
      expect(launched!.queryParameters['destination'], '0.0,0.0');
      expect(capturedMode, LaunchMode.externalApplication);
    },
  );

  test(
    'returns browser launch failure to the platform feedback layer',
    () async {
      final result = await launchGoogleMapsDirections(
        location: 'Café & Park',
        launcher: (_, {mode = LaunchMode.platformDefault}) async => false,
      );
      expect(result, isFalse);
    },
  );

  test('converts launcher exceptions into a feedback-safe failure', () async {
    expect(
      await launchGoogleMapsDirections(
        location: 'Fallback',
        launcher: (_, {mode = LaunchMode.platformDefault}) async =>
            throw StateError('platform unavailable'),
      ),
      isFalse,
    );
  });
}

import 'package:url_launcher/url_launcher.dart';

import '../domain/geographic_point.dart';
import '../domain/location_result.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

Future<bool> launchGoogleMapsDirections({
  required String location,
  GeographicPoint? point,
  ExternalUriLauncher launcher = launchUrl,
}) async {
  try {
    return await launcher(
      googleMapsDirectionsUri(location: location, point: point),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    return false;
  }
}

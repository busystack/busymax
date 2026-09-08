import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('embedded map implementation and dependencies remain removed', () {
    for (final path in [
      'lib/src/features/maps/application/location_search_controller.dart',
      'lib/src/features/maps/application/location_map_controller.dart',
      'lib/src/features/maps/data/geoapify_client.dart',
      'lib/src/features/maps/data/map_tile_service.dart',
      'lib/src/features/maps/presentation/linux_location_autocomplete.dart',
      'lib/src/features/maps/presentation/linux_location_map_dialog.dart',
      'lib/src/features/maps/presentation/map_canvas.dart',
      'lib/src/ui/windows/windows_location_autocomplete.dart',
      'lib/src/ui/windows/windows_location_map_dialog.dart',
      'lib/src/features/maps/application/directions_launcher.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    final dependencies = File('pubspec.yaml').readAsStringSync();
    expect(dependencies, isNot(contains('flutter_map:')));
    expect(dependencies, isNot(contains('latlong2:')));
  });
}

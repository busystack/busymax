import 'dart:convert';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/maps/application/location_destination_resolver.dart';
import 'package:busymax/src/features/maps/application/location_map_controller.dart';
import 'package:busymax/src/features/maps/data/geoapify_client.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  test(
    'native coordinates win without a network request, including zero',
    () async {
      var requests = 0;
      final controller = LocationMapController(
        client: _client((_) async {
          requests++;
          return _response(const []);
        }, apiKey: ''),
        resolver: LocationDestinationResolver(
          LocationResolutionRepository(database),
        ),
        location: '',
        locationChange: const LocationChange.unchanged(),
        nativePoint: GeographicPoint(latitude: 0, longitude: 0),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(requests, 0);
      expect(
        controller.destination?.point,
        GeographicPoint(latitude: 0, longitude: 0),
      );
      expect(controller.destination?.label, '0.0,0.0');
      expect(controller.status, LocationLookupStatus.unconfigured);
    },
  );

  test('an explicit clear blocks fallback to the old native point', () async {
    var requests = 0;
    final controller = LocationMapController(
      client: _client((_) async {
        requests++;
        return _response(const []);
      }),
      resolver: LocationDestinationResolver(
        LocationResolutionRepository(database),
      ),
      location: '',
      locationChange: const LocationChange.clear(),
      nativePoint: GeographicPoint(latitude: 49, longitude: -123),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(requests, 0);
    expect(controller.destination, isNull);
    expect(controller.status, LocationLookupStatus.empty);
  });

  test(
    'an explicit replacement wins even when the readable label is unchanged',
    () async {
      final replacement = LocationResult(
        label: 'Same hall',
        point: GeographicPoint(latitude: 1, longitude: 2),
      );
      final controller = LocationMapController(
        client: _client((_) async => _response(const [])),
        resolver: LocationDestinationResolver(
          LocationResolutionRepository(database),
        ),
        location: 'Same hall',
        locationChange: LocationChange.replace(replacement),
        nativePoint: GeographicPoint(latitude: 3, longitude: 4),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.destination, replacement);
    },
  );

  test(
    'ambiguous forward lookup requires a choice before showing a map',
    () async {
      final controller = LocationMapController(
        client: _client(
          (_) async => _response([
            {'formatted': 'First', 'lat': 1, 'lon': 2, 'result_type': 'street'},
            {
              'formatted': 'Second',
              'lat': 3,
              'lon': 4,
              'result_type': 'building',
            },
          ]),
        ),
        resolver: LocationDestinationResolver(
          LocationResolutionRepository(database),
        ),
        location: 'Hall',
        locationChange: const LocationChange.unchanged(),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.destination, isNull);
      expect(controller.choices.map((result) => result.label), [
        'First',
        'Second',
      ]);
      controller.choose(controller.choices.last);
      expect(controller.destination?.label, 'Second');
      expect(controller.chosenSelection, controller.destination);
      expect(controller.choices, isEmpty);
    },
  );

  test(
    'coalesces individual tile failures into one stable state change',
    () async {
      final controller = LocationMapController(
        client: _client((_) async => _response(const [])),
        resolver: LocationDestinationResolver(
          LocationResolutionRepository(database),
        ),
        location: '',
        locationChange: const LocationChange.unchanged(),
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.reportTileFailure();
      controller.reportTileFailure();
      expect(controller.tileFailure, isTrue);
      expect(notifications, 1);
    },
  );
}

GeoapifyClient _client(
  Future<http.StreamedResponse> Function(http.BaseRequest request) handler, {
  String apiKey = 'key',
}) => GeoapifyClient(
  client: _Transport(handler),
  apiKey: apiKey,
  canUseNetwork: () async => true,
);

http.StreamedResponse _response(List<Object?> results) => http.StreamedResponse(
  Stream.value(utf8.encode(jsonEncode({'results': results}))),
  200,
);

final class _Transport extends http.BaseClient {
  _Transport(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

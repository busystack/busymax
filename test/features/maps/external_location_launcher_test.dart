import 'package:busymax/src/features/maps/application/external_location_launcher.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('destination classification', () {
    test('recognizes only complete HTTP(S) values with a host', () {
      final uri = completeHttpLocationUri(
        '  https://intranet/room?a=1%202&b=%2B#floor-2  ',
      );
      expect(uri.toString(), 'https://intranet/room?a=1%202&b=%2B#floor-2');
      expect(completeHttpLocationUri('http://server/path'), isNotNull);
      expect(completeHttpLocationUri('See https://example.com'), isNull);
      expect(completeHttpLocationUri('file:///tmp/map'), isNull);
      expect(completeHttpLocationUri('javascript:alert(1)'), isNull);
      expect(completeHttpLocationUri('data:text/plain,map'), isNull);
      expect(completeHttpLocationUri('https:///missing-host'), isNull);
    });
  });

  group('URI construction', () {
    test('constructs opaque Linux text URI with percent encoding', () {
      final uri = linuxLocationUri(
        const ExternalLocationDestination.text(
          "Café + Hall & Annex #2, O'Brien% / 東京",
        ),
      );

      expect(uri.toString(), startsWith('maps:q='));
      expect(uri.toString(), isNot(startsWith('maps:?q=')));
      expect(uri.toString(), contains('%20'));
      expect(uri.toString(), isNot(contains('+Hall')));
      expect(
        Uri.decodeComponent(uri.toString().substring(7)),
        "Café + Hall & Annex #2, O'Brien% / 東京",
      );
    });

    test('constructs Linux geo URI including zero and negative values', () {
      final uri = linuxLocationUri(
        ExternalLocationDestination.coordinates(
          GeographicPoint(latitude: 0, longitude: -123.25),
        ),
      );
      expect(uri.toString(), 'geo:0.0,-123.25');
    });

    test('constructs encoded Google Maps search URL', () {
      final uri = googleMapsSearchUri("Café + Hall & Annex #2, O'Brien% / 東京");
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters, {
        'api': '1',
        'query': "Café + Hall & Annex #2, O'Brien% / 東京",
      });
      expect(uri.queryParameters, isNot(contains('destination')));
      expect(uri.queryParameters, isNot(contains('query_place_id')));
    });
  });

  group('launch decisions', () {
    test('Linux native success does not launch a browser', () async {
      final calls = <Uri>[];
      final result = await ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.linux,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          calls.add(uri);
          expect(mode, LaunchMode.externalApplication);
          return true;
        },
      ).open(const ExternalLocationDestination.text('Main Hall'));

      expect(result, ExternalLocationLaunchResult.opened);
      expect(calls.map((uri) => uri.scheme), ['maps']);
    });

    test('Linux native false performs exactly one browser fallback', () async {
      final calls = <Uri>[];
      final result =
          await ExternalLocationLauncher(
            platform: () => ExternalLocationPlatform.linux,
            launcher: (uri, {mode = LaunchMode.platformDefault}) async {
              calls.add(uri);
              return calls.length == 2;
            },
          ).open(
            ExternalLocationDestination.coordinates(
              GeographicPoint(latitude: 0, longitude: -1),
            ),
          );

      expect(result, ExternalLocationLaunchResult.opened);
      expect(calls.map((uri) => uri.scheme), ['geo', 'https']);
      expect(calls.last.queryParameters['query'], '0.0,-1.0');
    });

    test(
      'Linux native exception performs exactly one browser fallback',
      () async {
        final calls = <Uri>[];
        final result = await ExternalLocationLauncher(
          platform: () => ExternalLocationPlatform.linux,
          launcher: (uri, {mode = LaunchMode.platformDefault}) async {
            calls.add(uri);
            if (calls.length == 1) throw StateError('no native handler');
            return true;
          },
        ).open(const ExternalLocationDestination.text('Room 4'));

        expect(result, ExternalLocationLaunchResult.opened);
        expect(calls, hasLength(2));
        expect(calls.last.scheme, 'https');
      },
    );

    test('Windows uses one browser search launch', () async {
      final calls = <Uri>[];
      final result = await ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          calls.add(uri);
          return true;
        },
      ).open(const ExternalLocationDestination.text('Main Hall'));

      expect(result, ExternalLocationLaunchResult.opened);
      expect(calls, hasLength(1));
      expect(calls.single.scheme, 'https');
    });

    test('direct links retain query and fragment without map search', () async {
      final calls = <Uri>[];
      final link = completeHttpLocationUri(
        'https://intranet/path?q=a%2Bb&room=A%26B#section',
      )!;
      final result = await ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.linux,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          calls.add(uri);
          return true;
        },
      ).open(ExternalLocationDestination.link(link));

      expect(result, ExternalLocationLaunchResult.opened);
      expect(calls, [link]);
      expect(calls.single.path, '/path');
      expect(calls.single.query, 'q=a%2Bb&room=A%26B');
      expect(calls.single.fragment, 'section');
    });

    test(
      'unsupported supplied schemes are searched, never launched directly',
      () async {
        final calls = <Uri>[];
        await ExternalLocationLauncher(
          platform: () => ExternalLocationPlatform.windows,
          launcher: (uri, {mode = LaunchMode.platformDefault}) async {
            calls.add(uri);
            return true;
          },
        ).open(const ExternalLocationDestination.text('file:///private/map'));

        expect(calls, hasLength(1));
        expect(calls.single.scheme, 'https');
        expect(calls.single.queryParameters['query'], 'file:///private/map');
      },
    );

    test('launcher rejects a directly constructed unsafe link', () async {
      final calls = <Uri>[];
      final result = await ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          calls.add(uri);
          return true;
        },
      ).open(ExternalLocationDestination.link(Uri.parse('file:///tmp/map')));

      expect(result, ExternalLocationLaunchResult.noDestination);
      expect(calls, isEmpty);
    });

    test('no destination and total failure are controlled results', () async {
      var calls = 0;
      final launcher = ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (_, {mode = LaunchMode.platformDefault}) async {
          calls += 1;
          throw StateError('unavailable');
        },
      );

      expect(
        await launcher.open(null),
        ExternalLocationLaunchResult.noDestination,
      );
      expect(calls, 0);
      expect(
        await launcher.open(const ExternalLocationDestination.text('Hall')),
        ExternalLocationLaunchResult.failed,
      );
      expect(calls, 1);
    });

    test(
      'overlong browser search is rejected without truncation or launch',
      () async {
        var calls = 0;
        final text = List.filled(2100, 'a').join();
        final result = await ExternalLocationLauncher(
          platform: () => ExternalLocationPlatform.windows,
          launcher: (_, {mode = LaunchMode.platformDefault}) async {
            calls += 1;
            return true;
          },
        ).open(ExternalLocationDestination.text(text));

        expect(result, ExternalLocationLaunchResult.browserUrlTooLong);
        expect(calls, 0);
      },
    );
  });
}

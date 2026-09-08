import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/presentation/map_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders a shared interactive map with native retina tiles and attribution',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BusyMaxMapController();
      var failures = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 700,
            height: 500,
            child: BusyMaxMapCanvas(
              point: GeographicPoint(latitude: 0, longitude: 0),
              destinationLabel: 'Coordinate destination',
              apiKey: 'test-key',
              cache: const DisabledMapCachingProvider(),
              canUseNetwork: () async => false,
              controller: controller,
              onTileFailure: () => failures++,
              onOpenAttribution: (_) async {},
              brightness: Brightness.dark,
              markerColor: Colors.orange,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.byType(RichAttributionWidget), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Coordinate destination',
        ),
        findsWidgets,
      );
      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(layer.urlTemplate, contains('/dark-matter/'));
      expect(layer.urlTemplate, contains('{r}.png'));
      expect(layer.resolvedRetinaMode, RetinaMode.server);

      controller.zoomIn();
      controller.zoomOut();
      controller.recenter();
      await tester.pump();
      expect(failures, lessThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

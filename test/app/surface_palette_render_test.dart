import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final baseline in const [
    _SurfaceBaseline(
      brightness: Brightness.light,
      view: Color(0xFFFFFFFF),
      window: Color(0xFFFAFAFA),
      sidebar: Color(0xFFEBEBEB),
      card: Color(0xFFFFFFFF),
      popover: Color(0xFFFAFAFA),
      floatingBorder: Color.fromRGBO(0, 0, 0, 0.14),
    ),
    _SurfaceBaseline(
      brightness: Brightness.dark,
      view: Color(0xFF272727),
      window: Color(0xFF2C2C2C),
      sidebar: Color(0xFF393939),
      card: Color(0xFF3D3D3D),
      popover: Color(0xFF3E3E3E),
      floatingBorder: Color.fromRGBO(0, 0, 0, 0.14),
    ),
  ]) {
    testWidgets(
      'renders the reviewed ${baseline.brightness.name} surface palette',
      (tester) async {
        tester.view
          ..physicalSize = const Size(800, 600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final boundaryKey = GlobalKey();
        final viewProbe = GlobalKey();
        final sidebarProbe = GlobalKey();
        final dialogProbe = GlobalKey();
        final cardProbe = GlobalKey();
        final popoverProbe = GlobalKey();
        final popoverSurfaceKey = GlobalKey();
        final contentPopoverProbe = GlobalKey();
        final theme = BusyMaxYaruTheme.build(
          brightness: baseline.brightness,
          accentColor: const Color(0xFFE95464),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                final colors = BusyMaxSurfaceColors.of(context);
                return RepaintBoundary(
                  key: boundaryKey,
                  child: Scaffold(
                    backgroundColor: colors.view,
                    body: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: BusyMaxSidebarSurface(
                            child: SizedBox(
                              width: 120,
                              height: double.infinity,
                              child: Center(
                                child: SizedBox.square(
                                  key: sidebarProbe,
                                  dimension: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: SizedBox.square(
                              key: viewProbe,
                              dimension: 16,
                            ),
                          ),
                        ),
                        BusyMaxModalEditorSurface(
                          maxWidth: 320,
                          maxHeight: 260,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  key: dialogProbe,
                                  dimension: 16,
                                ),
                                const SizedBox(height: 24),
                                BusyMaxGroupedSurface(
                                  child: SizedBox(
                                    key: cardProbe,
                                    width: 180,
                                    height: 72,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: BusyMaxContentPopoverSurface(
                              padding: const EdgeInsets.all(20),
                              child: SizedBox.square(
                                key: contentPopoverProbe,
                                dimension: 16,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: BusyMaxPopoverSurface(
                              key: popoverSurfaceKey,
                              color: colors.popover,
                              padding: const EdgeInsets.all(20),
                              child: SizedBox.square(
                                key: popoverProbe,
                                dimension: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pixels = await _capturePixels(tester, boundaryKey);
        expect(_pixelAtProbe(tester, pixels, sidebarProbe), baseline.sidebar);
        expect(_pixelAtProbe(tester, pixels, viewProbe), baseline.view);
        expect(_pixelAtProbe(tester, pixels, dialogProbe), baseline.window);
        expect(_pixelAtProbe(tester, pixels, cardProbe), baseline.card);
        expect(_pixelAtProbe(tester, pixels, popoverProbe), baseline.popover);
        final popoverSize = tester.getSize(find.byKey(popoverSurfaceKey));
        final edge = _pixelAtLocal(
          tester,
          pixels,
          popoverSurfaceKey,
          Offset(0.5, popoverSize.height / 2),
        );
        final expectedEdge = Color.alphaBlend(
          baseline.floatingBorder,
          baseline.popover,
        );
        _expectColorNear(edge, expectedEdge, tolerance: 3);
        if (baseline.brightness == Brightness.dark) {
          expect(
            edge.computeLuminance(),
            lessThan(baseline.popover.computeLuminance()),
          );
        }
        expect(
          _pixelAtProbe(tester, pixels, contentPopoverProbe),
          baseline.popover,
        );
      },
    );
  }
}

class _SurfaceBaseline {
  const _SurfaceBaseline({
    required this.brightness,
    required this.view,
    required this.window,
    required this.sidebar,
    required this.card,
    required this.popover,
    required this.floatingBorder,
  });

  final Brightness brightness;
  final Color view;
  final Color window;
  final Color sidebar;
  final Color card;
  final Color popover;
  final Color floatingBorder;
}

Future<_CapturedPixels> _capturePixels(
  WidgetTester tester,
  GlobalKey boundaryKey,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.binding.runAsync<ui.Image>(
    () => boundary.toImage(pixelRatio: 1),
  ))!;
  try {
    final data = (await tester.binding.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    return _CapturedPixels(
      bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      boundary: boundary,
    );
  } finally {
    image.dispose();
  }
}

Color _pixelAtProbe(
  WidgetTester tester,
  _CapturedPixels pixels,
  GlobalKey probeKey,
) {
  final globalCenter = tester.getCenter(find.byKey(probeKey));
  final localCenter = pixels.boundary.globalToLocal(globalCenter);
  final x = localCenter.dx.round();
  final y = localCenter.dy.round();
  final offset = (y * pixels.width + x) * 4;
  return Color.fromARGB(
    pixels.bytes[offset + 3],
    pixels.bytes[offset],
    pixels.bytes[offset + 1],
    pixels.bytes[offset + 2],
  );
}

Color _pixelAtLocal(
  WidgetTester tester,
  _CapturedPixels pixels,
  GlobalKey probeKey,
  Offset localOffset,
) {
  final box = tester.renderObject<RenderBox>(find.byKey(probeKey));
  final globalPoint = box.localToGlobal(localOffset);
  final point = pixels.boundary.globalToLocal(globalPoint);
  final x = point.dx.floor();
  final y = point.dy.floor();
  final offset = (y * pixels.width + x) * 4;
  return Color.fromARGB(
    pixels.bytes[offset + 3],
    pixels.bytes[offset],
    pixels.bytes[offset + 1],
    pixels.bytes[offset + 2],
  );
}

void _expectColorNear(Color actual, Color expected, {required int tolerance}) {
  expect(
    (actual.r * 255 - expected.r * 255).abs(),
    lessThanOrEqualTo(tolerance),
  );
  expect(
    (actual.g * 255 - expected.g * 255).abs(),
    lessThanOrEqualTo(tolerance),
  );
  expect(
    (actual.b * 255 - expected.b * 255).abs(),
    lessThanOrEqualTo(tolerance),
  );
  expect(
    (actual.a * 255 - expected.a * 255).abs(),
    lessThanOrEqualTo(tolerance),
  );
}

class _CapturedPixels {
  const _CapturedPixels({
    required this.bytes,
    required this.width,
    required this.boundary,
  });

  final Uint8List bytes;
  final int width;
  final RenderRepaintBoundary boundary;
}

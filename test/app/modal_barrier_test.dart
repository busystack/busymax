import 'dart:io';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native dark startup fallback matches the Dart semantic shade', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();
    final match = RegExp(
      r'kDefaultModalBarrierColor\[\] = '
      r'"rgba\(0,0,0,([0-9.]+)\)"',
    ).firstMatch(source);

    expect(match, isNotNull);
    final nativeAlpha = double.parse(match!.group(1)!);
    final dartAlpha = busyMaxFallbackSurfaceColors(Brightness.dark).shade.a;
    expect(nativeAlpha, closeTo(dartAlpha, 0.0001));
    expect(source, contains('modal_barrier_color_for_depth('));
    expect(source, contains('std::pow(1.0 - barrier.alpha'));
    expect(
      source,
      contains(
        'g_autofree gchar* modal_barrier_color = '
        'modal_barrier_color_for_depth(',
      ),
    );
    expect(source, contains('self->header_bar_modal_barrier_color'));
    expect(source, contains('self->header_bar_modal_barrier_shade_depth'));
    expect(source, contains('kDefaultModalBarrierColor'));
  });

  test('native modal blocking and visual shade depth remain independent', () {
    final source = File('linux/runner/my_application.cc').readAsStringSync();

    expect(source, contains('set_header_bar_modal_barrier_state'));
    expect(source, contains('set_header_bar_modal_barrier_visible'));
    expect(
      source,
      contains(
        'set_header_bar_modal_barrier_state(self, visible, visible ? 1 : 0);',
      ),
    );
    expect(
      source,
      contains(
        'self->header_bar_modal_barrier_shade_depth = '
        'effective_shade_depth;',
      ),
    );
    final setterStart = source.indexOf(
      'static void set_header_bar_modal_barrier_state(',
    );
    final setterEnd = source.indexOf(
      'static void set_header_bar_modal_barrier_visible(',
      setterStart,
    );
    final setter = source.substring(setterStart, setterEnd);
    expect(
      setter,
      contains('gtk_widget_set_visible(self->titlebar_modal_barrier, visible)'),
    );
    expect(setter, contains('if (shade_changed) {'));
    expect(setter, contains('refresh_header_bar_css(self);'));
    expect(
      source,
      contains(
        'set_header_bar_modal_barrier_state(\n'
        '        self, fl_lookup_bool_arg(args, "visible", FALSE),',
      ),
    );
    expect(
      source,
      contains('1.0 - std::pow(1.0 - barrier.alpha, effective_depth)'),
    );
  });

  for (final (brightness, expectedAlpha) in [
    (Brightness.light, 0.07),
    (Brightness.dark, 0.25),
  ]) {
    testWidgets(
      '$brightness modal barrier follows the native semantic shade role',
      (tester) async {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFF3584E4),
        );
        late Color barrier;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                barrier = busyMaxModalBarrierColor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final shade = theme.extension<BusyMaxSurfaceColors>()!.shade;
        expect(barrier.a, closeTo(expectedAlpha, 0.0001));
        expect(barrier.r, shade.r);
        expect(barrier.g, shade.g);
        expect(barrier.b, shade.b);
      },
    );
  }

  testWidgets('high-contrast shade remains a translucent modal layer', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
      highContrast: true,
    );
    late Color barrier;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            barrier = busyMaxModalBarrierColor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(barrier, theme.extension<BusyMaxSurfaceColors>()!.shade);
    expect(barrier.a, 0.50);
    expect(barrier.a, lessThan(1));
  });

  testWidgets(
    'a GTK3 palette without semantic shade keeps restrained light dimming',
    (tester) async {
      const gtkColors = GtkThemeColors(
        brightness: Brightness.light,
        window: Color(0xFFFAFAFA),
        popover: Color(0xFFFAFAFA),
      );
      final theme = BusyMaxYaruTheme.build(
        brightness: Brightness.light,
        accentColor: const Color(0xFF3584E4),
        gtkThemeColors: gtkColors,
      );
      late Color barrier;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              barrier = busyMaxModalBarrierColor(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        theme.extension<BusyMaxSurfaceColors>()!.shade,
        busyMaxFallbackSurfaceColors(Brightness.light).shade,
      );
      expect(barrier.a, closeTo(0.07, 0.0001));
    },
  );
}

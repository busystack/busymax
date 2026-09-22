import 'dart:io';

import 'package:busymax/src/platform/gtk_animation_settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the initial GTK animation setting', () async {
    const channel = MethodChannel('busymax_test/gtk_animations');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getGtkAnimationsEnabled');
      return false;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    expect(
      await const GtkAnimationSettingsService(
        channel: channel,
      ).getAnimationsEnabled(),
      isFalse,
    );
  });

  test('animation stream follows GTK setting changes', () async {
    const events = EventChannel('busymax_test/gtk_animation_events');
    MockStreamHandlerEventSink? sink;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, eventSink) {
          sink = eventSink;
          eventSink.success(true);
        },
      ),
    );
    addTearDown(() => messenger.setMockStreamHandler(events, null));

    final values = const GtkAnimationSettingsService(
      events: events,
    ).watchAnimationsEnabled().take(2).toList();
    await pumpEventQueue();
    sink!.success(false);

    expect(await values, [isTrue, isFalse]);
  });

  test('provider exposes the preloaded value before native events', () async {
    final container = ProviderContainer(
      overrides: [initialGtkAnimationsEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);

    expect(await container.read(gtkAnimationsEnabledProvider.future), isFalse);
  });

  test('missing GTK integration falls back without disabling motion', () async {
    expect(
      await const GtkAnimationSettingsService(
        channel: MethodChannel('busymax_test/gtk_animations_missing'),
      ).getAnimationsEnabled(),
      isNull,
    );
  });

  test(
    'native GTK bridge observes and tears down animation preference state',
    () {
      final source = File('linux/runner/my_application.cc').readAsStringSync();
      final frame = File(
        'lib/src/app/linux/linux_page_frame.dart',
      ).readAsStringSync();

      expect(source, contains('"notify::gtk-enable-animations"'));
      expect(source, contains('send_gtk_animation_settings_event(self);'));
      expect(
        source,
        contains('disconnect_gtk_animation_settings_signal(self);'),
      );
      expect(
        source,
        contains(
          'g_clear_object(&self->gtk_animation_settings_event_channel);',
        ),
      );
      expect(source, isNot(contains('header_sidebar_brand_box')));
      expect(source, isNot(contains('gtk_widget_add_tick_callback(')));
      expect(frame, contains('MediaQuery.disableAnimationsOf(context)'));
      expect(frame, contains('_controller.value = _targetVisible ? 1 : 0'));
      expect(frame, contains('BusyMaxMotion.sidebar * distance'));
    },
  );
}

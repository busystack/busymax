import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const yaruWindowChannel = MethodChannel('yaru_window');
  const yaruEventsChannel = MethodChannel('yaru_window/events');
  late List<MethodCall> windowCalls;

  setUp(() {
    windowCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(yaruWindowChannel, (call) async {
      windowCalls.add(call);
      return call.method == 'state' ? <String, Object?>{} : null;
    });
    messenger.setMockMethodCallHandler(yaruEventsChannel, (_) async => null);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(yaruWindowChannel, null);
    messenger.setMockMethodCallHandler(yaruEventsChannel, null);
  });

  testWidgets(
    'configured physical clusters stay ordered in RTL above dialog barriers',
    (tester) async {
      const preferences = GtkWindowPreferences(
        decorationLayout: GtkDecorationLayout(
          left: [GtkWindowControlType.menu, GtkWindowControlType.minimize],
          right: [GtkWindowControlType.maximize, GtkWindowControlType.close],
        ),
        doubleClick: GtkTitlebarAction.toggleMaximize,
        middleClick: GtkTitlebarAction.none,
        rightClick: GtkTitlebarAction.menu,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gtkWindowPreferencesProvider.overrideWith(
              (ref) => Stream.value(preferences),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => LinuxWindowHost(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        const AlertDialog(content: Text('Application modal')),
                  ),
                  child: const Text('Open modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final left = find.byKey(const ValueKey('linux-window-controls-left'));
      final right = find.byKey(const ValueKey('linux-window-controls-right'));
      expect(left, findsOneWidget);
      expect(right, findsOneWidget);
      expect(
        find.descendant(of: left, matching: find.byType(YaruWindowControl)),
        findsOneWidget,
      );
      final rightControls = find.descendant(
        of: right,
        matching: find.byType(YaruWindowControl),
      );
      expect(rightControls, findsNWidgets(2));
      expect(
        tester.getCenter(rightControls.first).dx,
        lessThan(tester.getCenter(rightControls.last).dx),
      );

      await tester.tap(find.text('Open modal'));
      await tester.pumpAndSettle();
      expect(find.text('Application modal'), findsOneWidget);

      final close = find.descendant(
        of: right,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is YaruWindowControl &&
              widget.type == YaruWindowControlType.close,
        ),
      );
      await tester.tap(close);
      await tester.pump();

      expect(windowCalls.map((call) => call.method), contains('close'));
      expect(find.text('Application modal'), findsOneWidget);
    },
  );
}

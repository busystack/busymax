import 'package:busymax/src/features/schedule/presentation/schedule_create_menu.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  testWidgets('create chooser delegates selection to the native menu host', (
    tester,
  ) async {
    MethodCall? nativeCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (call) async {
          nativeCall = call;
          return 1;
        });
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(80),
                  child: Builder(
                    builder: (context) {
                      anchorContext = context;
                      return const SizedBox.square(dimension: 32);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final result = await showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
      anchorPoint: const Offset(96, 96),
    );

    expect(result, ScheduleCreateChoice.task);
    expect(nativeCall?.method, 'show');
    final arguments = nativeCall?.arguments as Map<Object?, Object?>;
    expect(arguments['sessionId'], isA<int>());
    expect(arguments['anchor'], {
      'x': 96.0,
      'y': 96.0,
      'width': 0.0,
      'height': 0.0,
    });
    expect(arguments['entries'], [
      {'label': 'Event', 'enabled': true, 'selected': false},
      {'label': 'Task', 'enabled': true, 'selected': false},
    ]);
    expect(arguments['focusFirst'], isFalse);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });

  testWidgets('unavailable native host uses an anchored popup-menu fallback', (
    tester,
  ) async {
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(80),
                  child: Builder(
                    builder: (context) {
                      anchorContext = context;
                      return const SizedBox.square(dimension: 32);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final result = showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
      anchorPoint: const Offset(96, 96),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    expect(await result, ScheduleCreateChoice.task);
  });

  testWidgets('popup-menu fallback disables unavailable creation kinds', (
    tester,
  ) async {
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Center(
                child: Builder(
                  builder: (context) {
                    anchorContext = context;
                    return const SizedBox.square(dimension: 32);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final result = showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
      canCreateEvent: false,
      canCreateTask: true,
    );
    await tester.pumpAndSettle();

    final eventItem = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Event'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    final taskItem = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Task'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    expect(eventItem.enabled, isFalse);
    expect(taskItem.enabled, isTrue);
    expect(Focus.of(tester.element(find.text('Task'))).hasFocus, isTrue);

    await tester.tap(find.text('Event'));
    await tester.pump();
    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    expect(await result, ScheduleCreateChoice.task);
  });

  testWidgets('Escape dismisses the fallback and restores anchor focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    late BuildContext hostContext;
    late BuildContext anchorContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return Builder(
                builder: (context) {
                  anchorContext = context;
                  return TextButton(
                    focusNode: focusNode,
                    onPressed: () {},
                    child: const Text('Anchor'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    final result = showScheduleCreateMenu(
      context: hostContext,
      anchorContext: anchorContext,
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
    expect(Focus.of(tester.element(find.text('Event'))).hasFocus, isTrue);
    expect(focusNode.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('native dismissal does not open the Flutter fallback', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (_) async => null);
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await showScheduleCreateMenu(context: hostContext);
    await tester.pump();

    expect(result, isNull);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });

  testWidgets('create chooser does not open without an available choice', (
    tester,
  ) async {
    var nativeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (_) async {
          nativeCalls += 1;
          return null;
        });
    late BuildContext hostContext;
    await tester.pumpWidget(
      localizedTestApp(
        child: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await showScheduleCreateMenu(
      context: hostContext,
      canCreateEvent: false,
      canCreateTask: false,
    );
    await tester.pump();

    expect(result, isNull);
    expect(nativeCalls, 0);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });

  test('single available creation kind is resolved for direct creation', () {
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: true,
        canCreateTask: false,
      ),
      ScheduleCreateChoice.event,
    );
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: false,
        canCreateTask: true,
      ),
      ScheduleCreateChoice.task,
    );
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: true,
        canCreateTask: true,
      ),
      isNull,
    );
    expect(
      singleAvailableScheduleCreateChoice(
        canCreateEvent: false,
        canCreateTask: false,
      ),
      isNull,
    );
  });
}

import 'package:busymax/src/features/schedule/presentation/schedule_create_menu.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create chooser synchronizes the native modal barrier', (
    tester,
  ) async {
    const channel = MethodChannel('busymax_test/create_chooser_barrier');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ? true : null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LinuxHeaderBarService(channel: channel, isLinux: true);
    addTearDown(service.dispose);
    await service.initialize();

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

    final result = showScheduleCreateMenu(
      context: hostContext,
      headerBarService: service,
    );
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    final barrierCallsWhileOpen = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCallsWhileOpen, hasLength(1));
    expect(barrierCallsWhileOpen.single.arguments, isTrue);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();

    expect(await result, ScheduleCreateChoice.task);
    final barrierCalls = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCalls, hasLength(2));
    expect(barrierCalls.first.arguments, isTrue);
    expect(barrierCalls.last.arguments, isFalse);
  });

  testWidgets('create chooser disables unavailable creation kinds', (
    tester,
  ) async {
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

    final result = showScheduleCreateMenu(
      context: hostContext,
      canCreateEvent: false,
      canCreateTask: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Event'));
    await tester.pump();
    expect(find.text('Create'), findsOneWidget);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    expect(await result, ScheduleCreateChoice.task);
  });
}

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialogs.dart';
import 'package:busymax/src/platform/linux_header_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('modal coordinator synchronizes the native barrier', (
    tester,
  ) async {
    const channel = MethodChannel('busymax_test/modal_barrier');
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

    final result = showBusyMaxConfirm(
      hostContext,
      title: 'Remove item?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
      headerBarService: service,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
    expect(
      calls.where((call) => call.method == 'setModalBarrierVisible'),
      hasLength(1),
    );
    expect(calls.last.arguments, isTrue);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    final barrierCalls = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCalls, hasLength(2));
    expect(barrierCalls.first.arguments, isTrue);
    expect(barrierCalls.last.arguments, isFalse);
  });

  testWidgets('nested modals keep the native barrier active', (tester) async {
    const channel = MethodChannel('busymax_test/nested_modal_barrier');
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

    final first = showBusyMaxModalDialog<void>(
      hostContext,
      headerBarService: service,
      builder: (context) => const Dialog(child: Text('First dialog')),
    );
    await tester.pumpAndSettle();
    final second = showBusyMaxModalDialog<void>(
      hostContext,
      headerBarService: service,
      builder: (context) => const Dialog(child: Text('Second dialog')),
    );
    await tester.pumpAndSettle();

    expect(
      calls.where((call) => call.method == 'setModalBarrierVisible'),
      hasLength(1),
    );

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await second;
    expect(
      calls.where((call) => call.method == 'setModalBarrierVisible'),
      hasLength(1),
    );

    Navigator.of(hostContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await first;

    final barrierCalls = calls
        .where((call) => call.method == 'setModalBarrierVisible')
        .toList();
    expect(barrierCalls, hasLength(2));
    expect(barrierCalls.last.arguments, isFalse);
  });
}

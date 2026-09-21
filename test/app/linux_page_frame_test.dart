import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one viewport owns the full-height sidebar edge at every frame', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_FrameHarnessState>();
    await tester.pumpWidget(_testApp(_FrameHarness(key: harnessKey)));

    _expectSharedEdge(tester, expectedWidth: 0);
    harnessKey.currentState!.toggle();
    await tester.pump();
    for (final elapsed in const [
      Duration(milliseconds: 35),
      Duration(milliseconds: 45),
      Duration(milliseconds: 55),
    ]) {
      await tester.pump(elapsed);
      _expectSharedEdge(tester);
    }
    await tester.pumpAndSettle();
    _expectSharedEdge(tester, expectedWidth: BusyMaxSizes.sidebarWidth);

    harnessKey.currentState!.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    final closingWidth = _sidebarWidth(tester);
    harnessKey.currentState!.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(_sidebarWidth(tester), greaterThan(closingWidth));
    _expectSharedEdge(tester);
  });

  testWidgets('unrelated rebuild preserves partial progress and body state', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_FrameHarnessState>();
    await tester.pumpWidget(_testApp(_FrameHarness(key: harnessKey)));
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byType(LinuxPageFrame)),
      ),
      isFalse,
    );
    expect(_sidebarWidth(tester), 0);
    harnessKey.currentState!.toggle();
    await tester.pump(const Duration(milliseconds: 80));
    final before = _sidebarWidth(tester);
    final bodyState = tester.state(find.byType(_RetainedBody));

    harnessKey.currentState!.rebuild();
    await tester.pump();

    expect(_sidebarWidth(tester), closeTo(before, 0.01));
    expect(tester.state(find.byType(_RetainedBody)), same(bodyState));
    _expectSharedEdge(tester);
  });

  testWidgets(
    'breakpoint settlement is immediate and retained state survives',
    (tester) async {
      final harnessKey = GlobalKey<_FrameHarnessState>();
      await tester.pumpWidget(_testApp(_FrameHarness(key: harnessKey)));
      harnessKey.currentState!.toggle();
      await tester.pumpAndSettle();
      final sidebarState = tester.state(find.byType(_RetainedSidebar));

      harnessKey.currentState!.setAvailable(false);
      await tester.pump();
      _expectSharedEdge(tester, expectedWidth: 0);
      harnessKey.currentState!.setAvailable(true);
      await tester.pump();
      _expectSharedEdge(tester, expectedWidth: BusyMaxSizes.sidebarWidth);
      expect(tester.state(find.byType(_RetainedSidebar)), same(sidebarState));
    },
  );

  testWidgets('RTL and fractional device pixels share one snapped edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.reset);
    final harnessKey = GlobalKey<_FrameHarnessState>();
    await tester.pumpWidget(
      _testApp(_FrameHarness(key: harnessKey), direction: TextDirection.rtl),
    );
    harnessKey.currentState!.toggle();
    await tester.pump(const Duration(milliseconds: 73));

    final width = _sidebarWidth(tester);
    expect(width * 1.25, closeTo((width * 1.25).roundToDouble(), 0.0001));
    _expectSharedEdge(tester, rtl: true);
  });

  testWidgets(
    'animation setting settles a running reveal to its logical target',
    (tester) async {
      final harnessKey = GlobalKey<_FrameHarnessState>();
      await tester.pumpWidget(_testApp(_FrameHarness(key: harnessKey)));
      expect(
        MediaQuery.disableAnimationsOf(
          tester.element(find.byType(LinuxPageFrame)),
        ),
        isFalse,
      );
      expect(_sidebarWidth(tester), 0);
      harnessKey.currentState!.toggle();
      await tester.pump();
      expect(_sidebarWidth(tester), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_sidebarWidth(tester), inExclusiveRange(0, 300));

      harnessKey.currentState!.setDisableAnimations(true);
      await tester.pump();
      _expectSharedEdge(tester, expectedWidth: BusyMaxSizes.sidebarWidth);
    },
  );
}

Widget _testApp(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(1000, 700),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(textDirection: direction, child: child),
  ),
);

double _sidebarWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('linux-sidebar-viewport'))).width;

void _expectSharedEdge(
  WidgetTester tester, {
  double? expectedWidth,
  bool rtl = false,
}) {
  final viewport = tester.getRect(
    find.byKey(const ValueKey('linux-sidebar-viewport')),
  );
  final main = tester.getRect(find.byKey(const ValueKey('frame-main')));
  if (rtl) {
    expect(viewport.left, closeTo(main.right, 0.001));
  } else {
    expect(viewport.right, closeTo(main.left, 0.001));
  }
  if (expectedWidth != null) {
    expect(viewport.width, closeTo(expectedWidth, 0.001));
  }
  expect(
    tester.getSize(find.byKey(const ValueKey('full-sidebar-child'))).width,
    BusyMaxSizes.sidebarWidth,
  );
  expect(find.byType(ClipRect), findsOneWidget);
}

class _FrameHarness extends StatefulWidget {
  const _FrameHarness({super.key});

  @override
  State<_FrameHarness> createState() => _FrameHarnessState();
}

class _FrameHarnessState extends State<_FrameHarness> {
  var expanded = false;
  var available = true;
  var generation = 0;
  var rebuildCount = 0;
  var disableAnimations = false;

  void toggle() => setState(() {
    expanded = !expanded;
    generation += 1;
  });

  void setAvailable(bool value) => setState(() => available = value);
  void setDisableAnimations(bool value) =>
      setState(() => disableAnimations = value);
  void rebuild() => setState(() => rebuildCount += 1);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: LinuxPageFrame(
        header: Text('$rebuildCount'),
        body: const _RetainedBody(key: ValueKey('frame-main')),
        sidebarHeader: const SizedBox(height: 46),
        sidebarBody: const _RetainedSidebar(),
        sidebarAvailable: available,
        sidebarExpanded: expanded,
        sidebarTransitionGeneration: generation,
      ),
    );
  }
}

class _RetainedBody extends StatefulWidget {
  const _RetainedBody({super.key});

  @override
  State<_RetainedBody> createState() => _RetainedBodyState();
}

class _RetainedBodyState extends State<_RetainedBody> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _RetainedSidebar extends StatefulWidget {
  const _RetainedSidebar();

  @override
  State<_RetainedSidebar> createState() => _RetainedSidebarState();
}

class _RetainedSidebarState extends State<_RetainedSidebar> {
  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('full-sidebar-child'),
    width: BusyMaxSizes.sidebarWidth,
  );
}

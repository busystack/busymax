import 'package:busymax/src/app/common/busymax_motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sidebar reveal is clipped, reversible, and interaction-safe', (
    tester,
  ) async {
    var taps = 0;
    var visible = true;
    var generation = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: BusyMaxHorizontalReveal(
                key: const ValueKey('reveal'),
                visible: visible,
                width: 200,
                transitionGeneration: generation,
                child: SizedBox(
                  width: 200,
                  height: 80,
                  child: TextButton(
                    onPressed: () => taps += 1,
                    child: const Text('Sidebar action'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('reveal'))).width, 200);

    update(() {
      visible = false;
      generation = 1;
    });
    await tester.pump();
    await tester.tap(find.text('Sidebar action'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 80));
    final collapsingProgress = _revealProgress(tester);
    expect(collapsingProgress, inExclusiveRange(0, 1));

    update(() {
      visible = true;
      generation = 2;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final reversedProgress = _revealProgress(tester);
    expect(reversedProgress, greaterThan(collapsingProgress));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('reveal'))).width, 200);
  });

  testWidgets('enabling reduced motion settles an active reveal immediately', (
    tester,
  ) async {
    var visible = true;
    var generation = 0;
    var disabled = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disabled),
              child: Align(
                alignment: Alignment.topLeft,
                child: BusyMaxHorizontalReveal(
                  key: const ValueKey('reveal'),
                  visible: visible,
                  width: 200,
                  transitionGeneration: generation,
                  child: const SizedBox(width: 200, height: 40),
                ),
              ),
            );
          },
        ),
      ),
    );
    update(() {
      visible = false;
      generation = 1;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_revealProgress(tester), greaterThan(0));

    update(() => disabled = true);
    await tester.pump();
    expect(_revealProgress(tester), 0);
  });

  testWidgets('same-frame sidebar reversal cancels the obsolete direction', (
    tester,
  ) async {
    var visible = true;
    var generation = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BusyMaxHorizontalReveal(
              key: const ValueKey('reveal'),
              visible: visible,
              width: 200,
              transitionGeneration: generation,
              child: const SizedBox(width: 200, height: 40),
            );
          },
        ),
      ),
    );

    update(() {
      visible = false;
      generation = 1;
    });
    await tester.pump();
    update(() {
      visible = true;
      generation = 2;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(_revealProgress(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('unchanged-generation rebuild preserves reveal progress', (
    tester,
  ) async {
    var visible = true;
    var generation = 0;
    var unrelated = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Column(
              children: [
                Text('data-$unrelated'),
                BusyMaxHorizontalReveal(
                  key: const ValueKey('reveal'),
                  visible: visible,
                  width: 200,
                  transitionGeneration: generation,
                  child: const SizedBox(width: 200, height: 40),
                ),
              ],
            );
          },
        ),
      ),
    );

    update(() {
      visible = false;
      generation = 1;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final beforeRebuild = _revealProgress(tester);
    expect(beforeRebuild, inExclusiveRange(0, 1));

    update(() => unrelated += 1);
    await tester.pump();
    expect(_revealProgress(tester), closeTo(beforeRebuild, .001));
    await tester.pump(const Duration(milliseconds: 20));
    expect(_revealProgress(tester), lessThan(beforeRebuild));
    await tester.pumpAndSettle();
    expect(_revealProgress(tester), 0);
  });

  testWidgets('first directional generation animates from a mounted host', (
    tester,
  ) async {
    var generation = 0;
    var direction = 0;
    var label = 'January';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 300,
              height: 200,
              child: BusyMaxDirectionalSwitcher(
                generation: generation,
                direction: direction,
                child: ColoredBox(
                  key: ValueKey(label),
                  color: Colors.blue,
                  child: Text(label),
                ),
              ),
            );
          },
        ),
      ),
    );

    update(() {
      generation = 1;
      direction = 1;
      label = 'February';
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final translations = tester
        .widgetList<FractionalTranslation>(find.byType(FractionalTranslation))
        .map((widget) => widget.translation.dx)
        .toList();
    expect(translations.any((value) => value.abs() > 0), isTrue);
    final opacity = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((widget) => widget.opacity);
    expect(opacity.any((value) => value > 0 && value < 1), isTrue);
  });

  testWidgets('retained crossfade keeps two live pages and hides outgoing UI', (
    tester,
  ) async {
    final counts = <String, int>{};
    Widget build(int index) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 200,
          child: BusyMaxRetainedCrossfade(
            index: index,
            children: [
              _TrackedPage(
                key: const ValueKey('page-a'),
                name: 'A',
                counts: counts,
              ),
              _TrackedPage(
                key: const ValueKey('page-b'),
                name: 'B',
                counts: counts,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(0));
    expect(counts, {'A': 1, 'B': 1});
    await tester.enterText(find.byKey(const ValueKey('field-A')), 'draft');

    await tester.pumpWidget(build(1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('draft'), findsOneWidget);
    final opacityBeforeReversal = _pageOpacity(tester, 'page-a');
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('field-A')),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    await tester.pumpWidget(build(0));
    await tester.pump();
    expect(
      _pageOpacity(tester, 'page-a'),
      closeTo(opacityBeforeReversal, .001),
    );
    await tester.pumpAndSettle();
    expect(find.text('draft'), findsOneWidget);
    expect(counts, {'A': 1, 'B': 1});
  });

  testWidgets('keyed crossfade retains three semantic destinations', (
    tester,
  ) async {
    final counts = <String, int>{};
    var destination = 'Week';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 300,
                height: 200,
                child: BusyMaxKeyedCrossfade(
                  transitionKey: destination,
                  child: _TrackedPage(
                    key: ValueKey('page-$destination'),
                    name: destination,
                    counts: counts,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-Week')),
      'retained planner state',
    );
    final weekState = tester.state(
      find.byKey(const ValueKey('page-Week'), skipOffstage: false),
    );

    update(() => destination = 'Month');
    await tester.pump();
    expect(counts, {'Week': 1, 'Month': 1});
    expect(
      tester.state(
        find.byKey(const ValueKey('page-Week'), skipOffstage: false),
      ),
      same(weekState),
    );
    await tester.pump(const Duration(milliseconds: 30));
    update(() => destination = 'Year');
    await tester.pump();
    expect(counts, {'Week': 1, 'Month': 1, 'Year': 1});
    expect(
      tester.state(
        find.byKey(const ValueKey('page-Week'), skipOffstage: false),
      ),
      same(weekState),
    );
    await tester.pump(const Duration(milliseconds: 30));
    update(() => destination = 'Week');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('field-Week'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.state(find.byKey(const ValueKey('page-Week'))),
      same(weekState),
    );
    expect(counts, {'Week': 1, 'Month': 1, 'Year': 1});
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('field-Week')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'retained planner state',
    );
  });
}

double _revealProgress(WidgetTester tester) => tester
    .widgetList<Align>(
      find.descendant(
        of: find.byKey(const ValueKey('reveal')),
        matching: find.byType(Align),
      ),
    )
    .singleWhere(
      (align) =>
          align.widthFactor != null &&
          align.alignment == AlignmentDirectional.centerStart,
    )
    .widthFactor!;

double _pageOpacity(WidgetTester tester, String key) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

class _TrackedPage extends StatefulWidget {
  const _TrackedPage({super.key, required this.name, required this.counts});

  final String name;
  final Map<String, int> counts;

  @override
  State<_TrackedPage> createState() => _TrackedPageState();
}

class _TrackedPageState extends State<_TrackedPage> {
  @override
  void initState() {
    super.initState();
    widget.counts.update(widget.name, (value) => value + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: ValueKey('field-${widget.name}'),
    decoration: InputDecoration(labelText: widget.name),
  );
}

import 'package:busymax/src/app/common/busymax_mutation_list.dart';
import 'package:busymax/src/schedule/task_list_mutation_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _account = 'account';
const _list = 'list';

void main() {
  TaskListMutationIntent intent({
    required TaskListMutationPresentation presentation,
    required String id,
    required int generation,
    bool? completed,
  }) => TaskListMutationIntent(
    presentation: presentation,
    accountId: _account,
    taskListId: _list,
    taskId: id,
    generation: generation,
    completed: completed,
  );

  testWidgets('identified removal retains an inert row through collapse', (
    tester,
  ) async {
    var taps = 0;
    var consumed = 0;
    final pending = intent(
      presentation: TaskListMutationPresentation.completion,
      id: 'b',
      generation: 1,
      completed: true,
    );

    await tester.pumpWidget(
      _harness(
        items: const [_Item('a'), _Item('b')],
        mutation: pending,
        onTap: () => taps += 1,
        onConsumed: (_) => consumed += 1,
      ),
    );
    await tester.pumpWidget(
      _harness(
        items: const [_Item('a')],
        mutation: pending,
        onTap: () => taps += 1,
        onConsumed: (_) => consumed += 1,
      ),
    );

    expect(find.text('b'), findsOneWidget);
    await tester.tap(find.text('b'), warnIfMissed: false);
    expect(taps, 0);
    expect(consumed, 0);
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('b'), findsOneWidget);
    expect(tester.getSize(find.text('b')).height, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('b'), findsNothing);
    expect(consumed, 1);
  });

  testWidgets('unrelated refresh reconciles without structural animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(items: const [_Item('a', completed: true), _Item('b')]),
    );
    await tester.pumpWidget(
      _harness(items: const [_Item('a', completed: true)]),
    );

    expect(find.text('b'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion completes a pending row lifecycle', (
    tester,
  ) async {
    final pending = intent(
      presentation: TaskListMutationPresentation.removal,
      id: 'b',
      generation: 2,
    );
    await tester.pumpWidget(
      _harness(items: const [_Item('a'), _Item('b')], disabled: true),
    );
    await tester.pumpWidget(
      _harness(items: const [_Item('a')], mutation: pending, disabled: true),
    );
    await tester.pump();

    expect(find.text('b'), findsNothing);
  });

  testWidgets('final row exits before the empty projection is shown', (
    tester,
  ) async {
    final pending = intent(
      presentation: TaskListMutationPresentation.removal,
      id: 'only',
      generation: 4,
    );
    await tester.pumpWidget(_harness(items: const [_Item('only')]));
    await tester.pumpWidget(_harness(items: const [], mutation: pending));

    expect(find.text('only'), findsOneWidget);
    expect(find.text('Empty projection'), findsNothing);
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('only'), findsOneWidget);
    expect(find.text('Empty projection'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('only'), findsNothing);
    expect(find.text('Empty projection'), findsOneWidget);
  });

  testWidgets('offscreen removal cannot suspend later reconciliation', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var consumed = 0;
    final before = List.generate(80, (index) => _Item('item-$index'));
    final pending = intent(
      presentation: TaskListMutationPresentation.removal,
      id: 'item-1',
      generation: 3,
    );

    await tester.pumpWidget(
      _harness(items: before, controller: controller, viewportHeight: 160),
    );
    await tester.pumpWidget(
      _harness(
        items: before.where((item) => item.id != 'item-1').toList(),
        mutation: pending,
        controller: controller,
        viewportHeight: 160,
        onConsumed: (_) => consumed += 1,
      ),
    );
    expect(find.text('item-1'), findsOneWidget);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('item-1'), findsNothing);

    final filtered = List.generate(30, (index) => _Item('filtered-$index'));
    await tester.pumpWidget(
      _harness(
        items: filtered,
        mutation: pending,
        controller: controller,
        viewportHeight: 160,
        onConsumed: (_) => consumed += 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    controller.jumpTo(0);
    await tester.pump();
    expect(find.text('filtered-0'), findsOneWidget);
    expect(find.text('item-1'), findsNothing);
    expect(consumed, 1);
  });

  testWidgets('a never-built removal settles and accepts later projections', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var consumed = 0;
    final before = List.generate(100, (index) => _Item('item-$index'));
    final pending = intent(
      presentation: TaskListMutationPresentation.removal,
      id: 'item-99',
      generation: 6,
    );

    await tester.pumpWidget(
      _harness(items: before, controller: controller, viewportHeight: 160),
    );
    expect(find.text('item-99'), findsNothing);

    await tester.pumpWidget(
      _harness(
        items: before.take(99).toList(),
        mutation: pending,
        controller: controller,
        viewportHeight: 160,
        onConsumed: (_) => consumed += 1,
      ),
    );
    expect(find.text('item-99'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(consumed, 1);

    final updated = <_Item>[
      const _Item('updated-first'),
      ...before.skip(1).take(98),
    ];
    await tester.pumpWidget(
      _harness(
        items: updated,
        mutation: pending,
        controller: controller,
        viewportHeight: 160,
        onConsumed: (_) => consumed += 1,
      ),
    );
    await tester.pump();
    expect(find.text('updated-first'), findsOneWidget);
    expect(consumed, 1);
  });

  testWidgets('reduced motion settles a never-built removal in the parent', (
    tester,
  ) async {
    var consumed = 0;
    final before = List.generate(100, (index) => _Item('item-$index'));
    final pending = intent(
      presentation: TaskListMutationPresentation.removal,
      id: 'item-99',
      generation: 7,
    );

    await tester.pumpWidget(
      _harness(items: before, disabled: true, viewportHeight: 160),
    );
    expect(find.text('item-99'), findsNothing);
    await tester.pumpWidget(
      _harness(
        items: before.take(99).toList(),
        mutation: pending,
        disabled: true,
        viewportHeight: 160,
        onConsumed: (_) => consumed += 1,
      ),
    );
    await tester.pump();
    expect(consumed, 1);

    await tester.pumpWidget(
      _harness(
        items: const [_Item('reconciled')],
        mutation: pending,
        disabled: true,
        viewportHeight: 160,
        onConsumed: (_) => consumed += 1,
      ),
    );
    expect(find.text('reconciled'), findsOneWidget);
    expect(consumed, 1);
  });

  testWidgets('empty projection keeps its footer available', (tester) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(
      _harness(
        items: const [],
        footer: TextButton(
          onPressed: () => loadMoreCalls += 1,
          child: const Text('Load more'),
        ),
      ),
    );

    expect(find.text('Empty projection'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    expect(loadMoreCalls, 1);
  });

  testWidgets('disposing the list completes its pending removal intent', (
    tester,
  ) async {
    var consumed = 0;
    final pending = intent(
      presentation: TaskListMutationPresentation.removal,
      id: 'b',
      generation: 5,
    );
    await tester.pumpWidget(_harness(items: const [_Item('a'), _Item('b')]));
    await tester.pumpWidget(
      _harness(
        items: const [_Item('a')],
        mutation: pending,
        onConsumed: (_) => consumed += 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(consumed, 1);
  });
}

Widget _harness({
  required List<_Item> items,
  TaskListMutationIntent? mutation,
  VoidCallback? onTap,
  ValueChanged<TaskListMutationIntent>? onConsumed,
  bool disabled = false,
  ScrollController? controller,
  double? viewportHeight,
  Widget? footer,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disabled),
    child: child!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: viewportHeight ?? double.infinity,
        child: BusyMaxMutationList<_Item>(
          items: items,
          mutation: mutation,
          identityOf: (item) => '$_account\u0000$_list\u0000${item.id}',
          mutationApplied: (item, value) =>
              value.completed == null || item.completed == value.completed,
          onMutationConsumed: onConsumed,
          controller: controller,
          emptyBuilder: (context) => const Text('Empty projection'),
          footer: footer,
          itemBuilder: (context, item, index) => SizedBox(
            height: 48,
            child: TextButton(onPressed: onTap, child: Text(item.id)),
          ),
        ),
      ),
    ),
  ),
);

class _Item {
  const _Item(this.id, {this.completed = false});

  final String id;
  final bool completed;
}

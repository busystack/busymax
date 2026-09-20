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
}

Widget _harness({
  required List<_Item> items,
  TaskListMutationIntent? mutation,
  VoidCallback? onTap,
  ValueChanged<TaskListMutationIntent>? onConsumed,
  bool disabled = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disabled),
    child: child!,
  ),
  home: Scaffold(
    body: BusyMaxMutationList<_Item>(
      items: items,
      mutation: mutation,
      identityOf: (item) => '$_account\u0000$_list\u0000${item.id}',
      mutationApplied: (item, value) =>
          value.completed == null || item.completed == value.completed,
      onMutationConsumed: onConsumed,
      itemBuilder: (context, item, index) => SizedBox(
        height: 48,
        child: TextButton(onPressed: onTap, child: Text(item.id)),
      ),
    ),
  ),
);

class _Item {
  const _Item(this.id, {this.completed = false});

  final String id;
  final bool completed;
}

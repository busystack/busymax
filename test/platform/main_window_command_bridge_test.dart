import 'package:busymax/src/features/schedule/application/compact_agenda_data.dart';
import 'package:busymax/src/features/schedule/application/compact_agenda_snapshot.dart';
import 'package:busymax/src/platform/main_window_command_bridge.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact agenda snapshot refreshes a cached query', (
    tester,
  ) async {
    const query = CompactAgendaQuery.initial;
    var current = _agendaData();
    var loadCount = 0;
    final container = ProviderContainer(
      overrides: [
        compactAgendaDataLoaderProvider.overrideWithValue((ref, query) async {
          loadCount += 1;
          return current;
        }),
      ],
    );
    final provider = compactAgendaDataForQueryProvider(query);
    // Keep the initial value cached so a plain read would reproduce the bug.
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    final initial = await container.read(provider.future);
    expect(initial.items, isEmpty);
    expect(loadCount, 1);

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    current = _agendaData(items: [_googleTask('New Google task')]);
    final encoded = await loadFreshCompactAgendaSnapshot(
      widgetRef,
      encodeCompactAgendaQuery(query),
    );
    final refreshed = decodeCompactAgendaData(encoded);

    expect(refreshed.items, hasLength(1));
    expect(refreshed.items.single.title, 'New Google task');
    expect(loadCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

CompactAgendaData _agendaData({List<ScheduleItem> items = const []}) {
  final today = DateTime(2026, 7, 21);
  return CompactAgendaData(
    today: today,
    range: ScheduleRange(
      start: today,
      end: today.add(const Duration(days: 30)),
    ),
    items: items,
    hasMoreOverdueTasks: false,
    hasMoreNoDateTasks: false,
    hasSignedInAccounts: true,
    hasSources: true,
    generatedAt: today.add(Duration(minutes: items.length)),
  );
}

TaskScheduleItem _googleTask(String title) {
  return TaskScheduleItem(
    id: 'new-google-task',
    accountId: 'google-account',
    provider: TaskProvider.google,
    sourceId: 'google-list',
    title: title,
    completed: false,
    allDay: true,
    start: DateTime(2026, 7, 21),
  );
}

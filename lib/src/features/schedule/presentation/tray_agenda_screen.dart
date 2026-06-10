import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_about_dialog.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../features/task_lists/data/task_lists_repository.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_commands.dart';
import '../../../schedule/schedule_filters.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_source_visibility.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../tasks/data/tasks_repository.dart';
import 'schedule_agenda_view.dart';

final _trayAgendaDataProvider = FutureProvider.autoDispose<_TrayAgendaData>((
  ref,
) async {
  final now = DateTime.now();
  final generatedAt = DateTime(now.year, now.month, now.day);
  final accounts = await ref
      .read(accountsRepositoryProvider)
      .listSignedInAccounts();
  if (accounts.isEmpty) {
    return _TrayAgendaData(
      range: ScheduleRange(
        start: generatedAt,
        end: generatedAt.add(const Duration(days: 7)),
      ),
      items: const [],
      hasSignedInAccounts: false,
      hasSources: false,
    );
  }

  final accountIds = accounts.map((account) => account.id).toList();
  final calendarSources = await ref
      .read(calendarRepositoryProvider)
      .listVisibleSources(accountIds);
  final taskLists = <TaskListEntity>[];
  for (final account in accounts) {
    taskLists.addAll(
      await ref
          .read(taskListsRepositoryForAccountProvider(account.id))
          .listTaskLists(),
    );
  }

  final visibility = ScheduleSourceVisibility.fromSources(
    calendarSources: calendarSources,
    taskLists: taskLists,
    settings: ref.read(appSettingsControllerProvider),
  );
  final hasSources = visibility.hasCalendarSources || visibility.hasTaskLists;
  final range = ScheduleRange(
    start: generatedAt,
    end: generatedAt.add(const Duration(days: 7)),
  );
  if (!hasSources) {
    return _TrayAgendaData(
      range: range,
      items: const [],
      hasSignedInAccounts: true,
      hasSources: false,
    );
  }

  final items = await ref
      .read(scheduleRepositoryProvider)
      .listItems(
        range: range,
        filters: ScheduleFilters(
          accountIds: accountIds.toSet(),
          sourceIds: visibility.visibleCalendarSourceIds,
          taskListIds: visibility.visibleTaskListIds,
          sourceFilterActive: true,
          taskListFilterActive: true,
          includeCalendarEvents: true,
          includeTasks: true,
          showCompletedTasks: false,
          showNoDateTasks: false,
        ),
      );

  return _TrayAgendaData(
    range: range,
    items: items,
    hasSignedInAccounts: true,
    hasSources: true,
  );
});

class TrayAgendaScreen extends ConsumerStatefulWidget {
  const TrayAgendaScreen({super.key});

  @override
  ConsumerState<TrayAgendaScreen> createState() => _TrayAgendaScreenState();
}

class _TrayAgendaScreenState extends ConsumerState<TrayAgendaScreen> {
  StreamSubscription<BusyMaxHeaderBarAction>? _headerBarActions;
  var _commandSequence = 0;

  @override
  void initState() {
    super.initState();
    _initializeHeaderBar();
  }

  @override
  void dispose() {
    unawaited(_headerBarActions?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_trayAgendaDataProvider);
    final colors = BusyMaxSurfaceColors.of(context);
    _updateHeaderBar(context);

    return Scaffold(
      backgroundColor: colors.view,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => BusyMaxEmptyState(
                icon: Icons.event_busy_outlined,
                title: context.l10n.trayAgendaError,
                message: error.toString(),
              ),
              data: (agenda) {
                if (!agenda.hasSignedInAccounts) {
                  return BusyMaxEmptyState(
                    icon: Icons.login,
                    title: context.l10n.trayAgendaSignInRequired,
                  );
                }
                if (!agenda.hasSources) {
                  return BusyMaxEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: context.l10n.trayAgendaNoSources,
                  );
                }
                if (agenda.items.isEmpty) {
                  return BusyMaxEmptyState(
                    icon: Icons.event_available,
                    title: context.l10n.noEventsOrTasks,
                  );
                }
                return ScheduleAgendaView(
                  range: agenda.range,
                  items: agenda.items,
                  onItemSelected: (_, item) => _openScheduleItem(item),
                  onTaskCompletionChanged: _setTaskCompleted,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeHeaderBar() async {
    final service = ref.read(linuxHeaderBarServiceProvider);
    _headerBarActions = service.actions.listen(_handleHeaderBarAction);
    await service.initialize();
    if (mounted) {
      _updateHeaderBar(context);
    }
  }

  void _updateHeaderBar(BuildContext context) {
    final title = context.l10n.viewAgenda;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final service = ref.read(linuxHeaderBarServiceProvider);
      unawaited(() async {
        await service.initialize();
        await service.setScheduleControlsVisible(false);
        await service.setBackVisible(true);
        await service.setOnboardingControls(
          visible: false,
          canGoBack: false,
          canContinue: false,
          backLabel: '',
          continueLabel: '',
        );
        await service.setTitleRange(title);
        await service.setCanRefresh(false);
        await service.setCanCreate(false);
        await service.setSearchActive(false);
        await service.setSidebarVisible(false);
      }());
    });
  }

  void _handleHeaderBarAction(BusyMaxHeaderBarAction action) {
    if (action == BusyMaxHeaderBarAction.back) {
      context.go('/schedule');
      return;
    }
    if (action == BusyMaxHeaderBarAction.settings) {
      context.go('/settings');
      return;
    }
    if (action == BusyMaxHeaderBarAction.aboutBusyMax) {
      unawaited(
        showBusyMaxAboutDialog(
          context,
          headerBarService: ref.read(linuxHeaderBarServiceProvider),
        ),
      );
    }
  }

  void _openScheduleItem(ScheduleItem item) {
    final date = item.start == null
        ? DateTime.now()
        : ScheduleProjection.day(item.start!);
    final kind = item is TaskScheduleItem
        ? ScheduleWorkspaceCommandKind.openTask
        : ScheduleWorkspaceCommandKind.openCalendarEvent;
    ref
        .read(scheduleWorkspaceCommandProvider.notifier)
        .state = ScheduleWorkspaceCommand(
      kind,
      ++_commandSequence,
      date: date,
      accountId: item.accountId,
      sourceId: item.sourceId,
      itemId: item.id,
    );
    context.go('/schedule');
  }

  Future<void> _setTaskCompleted(TaskScheduleItem item, bool completed) async {
    final fields = <String, Object?>{
      'status': completed ? 'completed' : 'needsAction',
      'completed': completed ? DateTime.now().toUtc().toIso8601String() : null,
    };
    await ref
        .read(tasksRepositoryForAccountProvider(item.accountId))
        .patchTask(item.sourceId, item.id, TaskPatchInput(fields));
    ref.invalidate(_trayAgendaDataProvider);
  }
}

class _TrayAgendaData {
  const _TrayAgendaData({
    required this.range,
    required this.items,
    required this.hasSignedInAccounts,
    required this.hasSources,
  });

  final ScheduleRange range;
  final List<ScheduleItem> items;
  final bool hasSignedInAccounts;
  final bool hasSources;
}

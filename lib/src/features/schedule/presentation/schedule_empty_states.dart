import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';

class ScheduleLoadingState extends StatelessWidget {
  const ScheduleLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.scheduleLoading;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: BusyMaxSpacing.lg),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleNoSourcesState extends StatelessWidget {
  const ScheduleNoSourcesState({
    super.key,
    required this.hasAccounts,
    required this.onOpenSettings,
    this.onRefresh,
  });

  final bool hasAccounts;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return BusyMaxEmptyState(
      icon: Icons.calendar_month_outlined,
      title: hasAccounts
          ? context.l10n.scheduleNoSources
          : context.l10n.scheduleSignInRequired,
      message: hasAccounts
          ? context.l10n.scheduleNoSourcesDescription
          : context.l10n.scheduleSignInDescription,
      actions: [
        BusyMaxPushButton.suggested(
          onPressed: onOpenSettings,
          child: Text(context.l10n.settings),
        ),
        if (onRefresh != null)
          BusyMaxPushButton.standard(
            onPressed: onRefresh,
            child: Text(context.l10n.trayAgendaRefresh),
          ),
      ],
    );
  }
}

class ScheduleUnavailableState extends StatelessWidget {
  const ScheduleUnavailableState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return BusyMaxEmptyState(
      icon: Icons.sync_problem_outlined,
      title: context.l10n.scheduleUnavailable,
      actions: [
        BusyMaxPushButton.suggested(
          onPressed: onRetry,
          child: Text(context.l10n.retry),
        ),
      ],
    );
  }
}

class ScheduleEmptyState extends StatelessWidget {
  const ScheduleEmptyState({
    super.key,
    required this.onNewEvent,
    required this.onNewTask,
  });

  final VoidCallback? onNewEvent;
  final VoidCallback? onNewTask;

  @override
  Widget build(BuildContext context) {
    return BusyMaxEmptyState(
      icon: Icons.event_available,
      title: context.l10n.noEventsOrTasks,
      actions: [
        if (onNewEvent != null)
          BusyMaxPushButton.standard(
            onPressed: onNewEvent,
            child: Text(context.l10n.newEvent),
          ),
        if (onNewTask != null)
          BusyMaxPushButton.standard(
            onPressed: onNewTask,
            child: Text(context.l10n.newTask),
          ),
      ],
    );
  }
}

class ScheduleSearchEmptyState extends StatelessWidget {
  const ScheduleSearchEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return BusyMaxEmptyState(
      icon: Icons.search_off_outlined,
      title: context.l10n.scheduleNoSearchResults,
      message: context.l10n.scheduleNoSearchResultsDescription,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

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
      icon: YaruIcons.calendar,
      title: hasAccounts
          ? context.l10n.scheduleNoSources
          : context.l10n.scheduleSignInRequired,
      message: hasAccounts
          ? context.l10n.scheduleNoSourcesDescription
          : context.l10n.scheduleSignInDescription,
      actions: [
        BusyMaxPushButton.suggested(
          onPressed: onOpenSettings,
          child: _ScheduleEmptyStateActionLabel(
            icon: YaruIcons.settings,
            label: context.l10n.settings,
          ),
        ),
        if (onRefresh != null)
          BusyMaxPushButton.standard(
            onPressed: onRefresh,
            child: _ScheduleEmptyStateActionLabel(
              icon: YaruIcons.refresh,
              label: context.l10n.refresh,
            ),
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
      icon: YaruIcons.sync_error,
      title: context.l10n.scheduleUnavailable,
      actions: [
        BusyMaxPushButton.suggested(
          onPressed: onRetry,
          child: _ScheduleEmptyStateActionLabel(
            icon: YaruIcons.refresh,
            label: context.l10n.retry,
          ),
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
      icon: YaruIcons.calendar_day,
      title: context.l10n.noEventsOrTasks,
      actions: [
        if (onNewEvent != null)
          BusyMaxPushButton.standard(
            onPressed: onNewEvent,
            child: _ScheduleEmptyStateActionLabel(
              icon: YaruIcons.calendar_new,
              label: context.l10n.newEvent,
            ),
          ),
        if (onNewTask != null)
          BusyMaxPushButton.standard(
            onPressed: onNewTask,
            child: _ScheduleEmptyStateActionLabel(
              icon: YaruIcons.task_list,
              label: context.l10n.newTask,
            ),
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
      icon: YaruIcons.search,
      title: context.l10n.scheduleNoSearchResults,
      message: context.l10n.scheduleNoSearchResultsDescription,
    );
  }
}

class _ScheduleEmptyStateActionLabel extends StatelessWidget {
  const _ScheduleEmptyStateActionLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: BusyMaxSizes.iconSm),
        const SizedBox(width: BusyMaxSpacing.sm),
        Text(label),
      ],
    );
  }
}

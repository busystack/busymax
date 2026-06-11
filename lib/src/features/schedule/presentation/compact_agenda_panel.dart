import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/main_window_command_client.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../application/compact_agenda_controller.dart';
import '../application/compact_agenda_data.dart';
import '../application/compact_agenda_sections.dart';
import 'compact_agenda_formatting.dart';

typedef CompactAgendaTaskCompletionCallback =
    Future<void> Function(TaskScheduleItem item, bool completed);

class CompactAgendaPanel extends ConsumerStatefulWidget {
  const CompactAgendaPanel({
    super.key,
    this.data,
    this.onOpenBusyMax,
    this.onNewTask,
    this.onRefresh,
    this.onHide,
    this.onOpenItem,
    this.onTaskCompletionChanged,
  });

  final AsyncValue<CompactAgendaData>? data;
  final Future<void> Function()? onOpenBusyMax;
  final Future<void> Function()? onNewTask;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onHide;
  final Future<void> Function(ScheduleItem item)? onOpenItem;
  final CompactAgendaTaskCompletionCallback? onTaskCompletionChanged;

  @override
  ConsumerState<CompactAgendaPanel> createState() => _CompactAgendaPanelState();
}

class _CompactAgendaPanelState extends ConsumerState<CompactAgendaPanel> {
  final _mutatingTaskKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final data = widget.data ?? ref.watch(compactAgendaDataProvider);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _HideIntent(),
        SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _RefreshIntent(),
      },
      child: Actions(
        actions: {
          _HideIntent: CallbackAction<_HideIntent>(
            onInvoke: (_) {
              unawaited(_hide());
              return null;
            },
          ),
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              unawaited(_refresh());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Padding(
            padding: const EdgeInsets.all(BusyMaxSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(BusyMaxRadius.window),
                border: Border.all(color: colors.border),
                boxShadow: BusyMaxShadow.floatingShadows(
                  BusyMaxShadow.floatingColor(context),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BusyMaxRadius.window),
                child: Column(
                  children: [
                    _CompactAgendaHeader(
                      data: data.valueOrNull,
                      onRefresh: _refresh,
                      onOpenBusyMax: _openBusyMax,
                      onHide: _hide,
                    ),
                    Expanded(child: _body(data)),
                    _CompactAgendaBottomBar(
                      onNewTask: _newTask,
                      onOpenBusyMax: _openBusyMax,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<CompactAgendaData> data) {
    return data.when(
      loading: () => const _CompactAgendaLoadingState(),
      error: (error, stackTrace) => _CompactAgendaMessageState(
        icon: Icons.event_busy_outlined,
        title: context.l10n.trayAgendaError,
        message: redactForLog(error),
        primaryLabel: context.l10n.compactAgendaRetry,
        onPrimary: _refresh,
        secondaryLabel: context.l10n.compactAgendaOpenBusyMax,
        onSecondary: _openBusyMax,
      ),
      data: (agenda) {
        if (!agenda.hasSignedInAccounts) {
          return _CompactAgendaMessageState(
            icon: Icons.login,
            title: context.l10n.trayAgendaSignInRequired,
            primaryLabel: context.l10n.compactAgendaOpenBusyMax,
            onPrimary: _openBusyMax,
          );
        }
        if (!agenda.hasSources) {
          return _CompactAgendaMessageState(
            icon: Icons.event_busy_outlined,
            title: context.l10n.trayAgendaNoSources,
            primaryLabel: context.l10n.compactAgendaOpenBusyMax,
            onPrimary: _openBusyMax,
          );
        }
        if (agenda.items.isEmpty) {
          return _CompactAgendaMessageState(
            icon: Icons.event_available,
            title: context.l10n.compactAgendaClear,
            message: context.l10n.noEventsOrTasks,
          );
        }
        return _sections(agenda);
      },
    );
  }

  Widget _sections(CompactAgendaData data) {
    final sections = buildCompactAgendaSections(
      today: data.today,
      items: data.items,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        BusyMaxSpacing.md,
        BusyMaxSpacing.sm,
        BusyMaxSpacing.md,
        BusyMaxSpacing.md,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _CompactAgendaSectionView(
          section: section,
          today: data.today,
          mutatingTaskKeys: _mutatingTaskKeys,
          onOpenItem: _openItem,
          onTaskCompletionChanged: _setTaskCompleted,
          onOpenBusyMax: _openBusyMax,
        );
      },
    );
  }

  Future<void> _openBusyMax() async {
    final callback = widget.onOpenBusyMax;
    if (callback != null) {
      await callback();
      return;
    }
    await const MainWindowCommandClient().openMain();
    await windowManager.hide();
  }

  Future<void> _newTask() async {
    final callback = widget.onNewTask;
    if (callback != null) {
      await callback();
      return;
    }
    await const MainWindowCommandClient().newTask();
    await windowManager.hide();
  }

  Future<void> _refresh() async {
    final callback = widget.onRefresh;
    if (callback != null) {
      await callback();
      return;
    }
    ref.invalidate(compactAgendaDataProvider);
  }

  Future<void> _hide() async {
    final callback = widget.onHide;
    if (callback != null) {
      await callback();
      return;
    }
    await windowManager.hide();
  }

  Future<void> _openItem(ScheduleItem item) async {
    final callback = widget.onOpenItem;
    if (callback != null) {
      await callback(item);
      return;
    }
    await const MainWindowCommandClient().openScheduleItem(item);
    await windowManager.hide();
  }

  Future<void> _setTaskCompleted(
    TaskScheduleItem item,
    bool completed,
  ) async {
    final key = compactAgendaTaskMutationKey(item);
    if (_mutatingTaskKeys.contains(key)) {
      return;
    }
    setState(() => _mutatingTaskKeys.add(key));
    try {
      final callback = widget.onTaskCompletionChanged;
      if (callback != null) {
        await callback(item, completed);
      } else {
        await ref
            .read(compactAgendaControllerProvider)
            .setTaskCompleted(item, completed);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(redactForLog(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _mutatingTaskKeys.remove(key));
      }
    }
  }
}

class _CompactAgendaHeader extends StatelessWidget {
  const _CompactAgendaHeader({
    required this.data,
    required this.onRefresh,
    required this.onOpenBusyMax,
    required this.onHide,
  });

  final CompactAgendaData? data;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenBusyMax;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final subtitle = compactAgendaTodaySubtitle(
      context,
      data?.today ?? DateTime.now(),
    );
    return DragToMoveArea(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
        decoration: BoxDecoration(
          color: colors.headerbarFlat,
          border: Border(bottom: BorderSide(color: colors.subtleBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.compactAgendaTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _CompactHeaderButton(
              tooltip: context.l10n.compactAgendaRefresh,
              icon: Icons.refresh,
              onPressed: () => unawaited(onRefresh()),
            ),
            _CompactHeaderButton(
              tooltip: context.l10n.compactAgendaOpenBusyMax,
              icon: Icons.open_in_full,
              onPressed: () => unawaited(onOpenBusyMax()),
            ),
            _CompactHeaderButton(
              tooltip: context.l10n.compactAgendaHide,
              icon: Icons.close,
              onPressed: () => unawaited(onHide()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeaderButton extends StatelessWidget {
  const _CompactHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return YaruIconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: BusyMaxSizes.iconMd,
      onPressed: onPressed,
      style: busyMaxHeaderIconButtonStyle(
        foregroundColor: BusyMaxSurfaceColors.of(context).foreground,
        backgroundColor: busyMaxSubtleButtonBackground(context),
      ),
    );
  }
}

class _CompactAgendaLoadingState extends StatelessWidget {
  const _CompactAgendaLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(BusyMaxSpacing.md),
            itemCount: 4,
            separatorBuilder: (_, _) =>
                const SizedBox(height: BusyMaxSpacing.sm),
            itemBuilder: (context, index) => const _SkeletonRow(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.all(BusyMaxSpacing.md),
      decoration: BoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FractionallySizedBox(
            widthFactor: 0.68,
            child: Container(height: 10, color: colors.controlHover),
          ),
          const SizedBox(height: BusyMaxSpacing.sm),
          FractionallySizedBox(
            widthFactor: 0.42,
            child: Container(height: 8, color: colors.controlHover),
          ),
        ],
      ),
    );
  }
}

class _CompactAgendaMessageState extends StatelessWidget {
  const _CompactAgendaMessageState({
    required this.icon,
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? primaryLabel;
  final Future<void> Function()? onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BusyMaxSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: colors.mutedForeground),
            const SizedBox(height: BusyMaxSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: BusyMaxSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.mutedForeground),
              ),
            ],
            if (primaryLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: BusyMaxSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: BusyMaxSpacing.sm,
                runSpacing: BusyMaxSpacing.sm,
                children: [
                  if (primaryLabel != null)
                    BusyMaxPushButton.filled(
                      onPressed: onPrimary == null
                          ? null
                          : () => unawaited(onPrimary!()),
                      child: Text(primaryLabel!),
                    ),
                  if (secondaryLabel != null)
                    BusyMaxPushButton.outlined(
                      onPressed: onSecondary == null
                          ? null
                          : () => unawaited(onSecondary!()),
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactAgendaSectionView extends StatelessWidget {
  const _CompactAgendaSectionView({
    required this.section,
    required this.today,
    required this.mutatingTaskKeys,
    required this.onOpenItem,
    required this.onTaskCompletionChanged,
    required this.onOpenBusyMax,
  });

  final CompactAgendaSection section;
  final DateTime today;
  final Set<String> mutatingTaskKeys;
  final Future<void> Function(ScheduleItem item) onOpenItem;
  final CompactAgendaTaskCompletionCallback onTaskCompletionChanged;
  final Future<void> Function() onOpenBusyMax;

  @override
  Widget build(BuildContext context) {
    final title = switch (section.kind) {
      CompactAgendaSectionKind.overdue => context.l10n.compactAgendaOverdue,
      CompactAgendaSectionKind.day => compactAgendaDayLabel(
        context,
        today: today,
        day: section.day ?? today,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: BusyMaxSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BusyMaxSpacing.xs,
              0,
              BusyMaxSpacing.xs,
              BusyMaxSpacing.xs,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: BusyMaxSurfaceColors.of(context).mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: BusyMaxSurfaceColors.of(context).view,
              borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
              border: Border.all(
                color: BusyMaxSurfaceColors.of(context).subtleBorder,
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < section.items.length; index += 1)
                  _CompactAgendaRow(
                    item: section.items[index],
                    today: today,
                    mutating:
                        section.items[index] is TaskScheduleItem &&
                        mutatingTaskKeys.contains(
                          compactAgendaTaskMutationKey(
                            section.items[index] as TaskScheduleItem,
                          ),
                        ),
                    showDivider: index < section.items.length - 1 ||
                        section.hasMore,
                    onOpenItem: onOpenItem,
                    onTaskCompletionChanged: onTaskCompletionChanged,
                  ),
                if (section.hasMore)
                  _MoreOverdueRow(onOpenBusyMax: onOpenBusyMax),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAgendaRow extends StatelessWidget {
  const _CompactAgendaRow({
    required this.item,
    required this.today,
    required this.mutating,
    required this.showDivider,
    required this.onOpenItem,
    required this.onTaskCompletionChanged,
  });

  final ScheduleItem item;
  final DateTime today;
  final bool mutating;
  final bool showDivider;
  final Future<void> Function(ScheduleItem item) onOpenItem;
  final CompactAgendaTaskCompletionCallback onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final color = ScheduleProjection.colorForItem(
      item,
      Theme.of(context).colorScheme.brightness,
    );
    final source = ScheduleProjection.sourceLabelForScheduleItem(item);
    final meta = compactAgendaItemMeta(context, item, today: today);
    final event = item is CalendarScheduleItem
        ? item as CalendarScheduleItem
        : null;
    return AnimatedOpacity(
      opacity: mutating ? 0.48 : 1,
      duration: const Duration(milliseconds: 120),
      child: InkWell(
        onTap: mutating ? null : () => unawaited(onOpenItem(item)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: BusyMaxSurfaceColors.of(context).subtleBorder,
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: BusyMaxSpacing.md,
            vertical: BusyMaxSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (task != null) ...[
                YaruCheckbox(
                  value: task.completed,
                  onChanged: mutating
                      ? null
                      : (value) => unawaited(
                          onTaskCompletionChanged(task, value ?? false),
                        ),
                ),
                const SizedBox(width: BusyMaxSpacing.sm),
              ] else ...[
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: BusyMaxSpacing.md),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: BusyMaxSpacing.xxs),
                    Text(
                      [if (meta.isNotEmpty) meta, source].join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BusyMaxSurfaceColors.of(context).mutedForeground,
                      ),
                    ),
                    if (event?.location?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: BusyMaxSpacing.xxs),
                      Text(
                        event!.location!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              BusyMaxSurfaceColors.of(context).mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreOverdueRow extends StatelessWidget {
  const _MoreOverdueRow({required this.onOpenBusyMax});

  final Future<void> Function() onOpenBusyMax;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => unawaited(onOpenBusyMax()),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BusyMaxSpacing.md,
          vertical: BusyMaxSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.open_in_full, size: BusyMaxSizes.iconSm),
            const SizedBox(width: BusyMaxSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.compactAgendaMoreOverdue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactAgendaBottomBar extends StatelessWidget {
  const _CompactAgendaBottomBar({
    required this.onNewTask,
    required this.onOpenBusyMax,
  });

  final Future<void> Function() onNewTask;
  final Future<void> Function() onOpenBusyMax;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    return Container(
      padding: const EdgeInsets.all(BusyMaxSpacing.md),
      decoration: BoxDecoration(
        color: colors.headerbarFlat,
        border: Border(top: BorderSide(color: colors.subtleBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: BusyMaxPushButton.filled(
              onPressed: () => unawaited(onNewTask()),
              child: Text(context.l10n.compactAgendaNewTask),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: BusyMaxPushButton.outlined(
              onPressed: () => unawaited(onOpenBusyMax()),
              child: Text(context.l10n.compactAgendaOpenBusyMax),
            ),
          ),
        ],
      ),
    );
  }
}

class _HideIntent extends Intent {
  const _HideIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

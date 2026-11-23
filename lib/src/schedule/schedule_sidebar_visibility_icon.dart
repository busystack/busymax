import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_bootstrap.dart';
import '../features/sync/sync_activity_icon.dart';
import '../features/sync/sync_request.dart';
import '../l10n/l10n.dart';
import '../l10n/sync_outcome_description.dart';
import '../providers/busy_provider.dart';
import 'schedule_source_visibility.dart';

typedef SidebarVisibilityButtonBuilder = Widget Function(
  BuildContext context,
  Widget icon,
  String tooltip,
  VoidCallback? onPressed,
);

class ScheduleSidebarVisibilityIcon extends ConsumerWidget {
  const ScheduleSidebarVisibilityIcon({
    super.key,
    required this.scope,
    required this.label,
    required this.actionLabel,
    required this.visible,
    required this.color,
    required this.icon,
    required this.warningIcon,
    required this.onPressed,
    required this.buttonBuilder,
    this.accountVisibility,
    this.animate = true,
    this.ringSize = 22,
  });

  final SyncScope scope;
  final String label;
  final String actionLabel;
  final bool visible;
  final Color color;
  final Widget icon;
  final IconData warningIcon;
  final VoidCallback? onPressed;
  final SidebarVisibilityButtonBuilder buttonBuilder;
  final ScheduleAccountVisibility? accountVisibility;
  final bool animate;
  final double ringSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activity = ref.watch(accountSyncActivityProvider);
    final accountId = scope.kind == SyncScopeKind.account
        ? scope.accountId
        : null;
    final busy =
        activity.busy(scope) ||
        accountId != null && activity.accountRunning(accountId);
    final queued = activity.queued(scope) && !activity.executing(scope);
    final outcome = activity.outcome(scope);
    final warning =
        !busy &&
        (outcome?.needsAttention == true ||
            activity.resourceFailure(scope) != null ||
            accountId != null && activity.accountNeedsAttention(accountId));
    final syncStatus = busy
        ? (queued ? l10n.syncQueued : l10n.traySyncing)
        : warning
        ? syncOutcomeDescription(l10n, outcome?.disposition)
        : null;
    final selectionStatus = switch (accountVisibility) {
      ScheduleAccountVisibility.partial => l10n.someAccountSourcesVisible,
      ScheduleAccountVisibility.noVisibleSources =>
        l10n.noAccountSourcesVisible,
      ScheduleAccountVisibility.hidden => l10n.accountHiddenInSchedule,
      _ => null,
    };
    final tooltip = [actionLabel, ?selectionStatus, ?syncStatus].join('\n');
    return Semantics(
      container: true,
      label: '$actionLabel, $label',
      hint: [?selectionStatus, ?syncStatus].join('\n'),
      button: true,
      enabled: onPressed != null,
      toggled: visible,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: buttonBuilder(
          context,
          SizedBox.square(
            dimension: ringSize + 4,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Opacity(opacity: visible ? 1 : 0.4, child: icon),
                if (busy)
                  _SidebarSyncRing(
                    animate: animate && !queued,
                    size: ringSize,
                    color: color,
                  ),
                if (accountVisibility == ScheduleAccountVisibility.partial ||
                    accountVisibility ==
                        ScheduleAccountVisibility.noVisibleSources)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width:
                          accountVisibility == ScheduleAccountVisibility.partial
                          ? 6
                          : 3,
                      height: 2,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                if (warning)
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Icon(warningIcon, size: 11, color: color),
                  ),
              ],
            ),
          ),
          tooltip,
          onPressed,
        ),
      ),
    );
  }
}

/// Only the arc rotates. Cached sliver children and rows retained during
/// disclosure can stay mounted after leaving the viewport.
class _SidebarSyncRing extends StatefulWidget {
  const _SidebarSyncRing({
    required this.animate,
    required this.size,
    required this.color,
  });

  final bool animate;
  final double size;
  final Color color;

  @override
  State<_SidebarSyncRing> createState() => _SidebarSyncRingState();
}

class _SidebarSyncRingState extends State<_SidebarSyncRing> {
  ScrollPosition? _position;
  bool _visible = false;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A window resize can change the viewport without scrolling it.
    MediaQuery.maybeSizeOf(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_scheduleCheck);
      _position = position;
      _position?.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final visible =
          viewport == null ||
          viewport.paintBounds.overlaps(
            MatrixUtils.transformRect(
              box.getTransformTo(viewport),
              box.paintBounds,
            ),
          );
      if (visible != _visible) setState(() => _visible = visible);
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) {
      _scheduleCheck();
      return SyncRotation(
        enabled: _visible && widget.animate,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _SyncArc(color: widget.color),
        ),
      );
    },
  );
}

class _SyncArc extends CustomPainter {
  const _SyncArc({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.25);
    canvas.drawOval(bounds, paint);
    paint.color = color;
    canvas.drawArc(bounds, -2.4, 2.5, false, paint);
  }

  @override
  bool shouldRepaint(_SyncArc oldDelegate) => oldDelegate.color != color;
}

String scheduleAccountVisibilityAction(
  BuildContext context,
  ScheduleAccountVisibility state,
) => state == ScheduleAccountVisibility.hidden
    ? context.l10n.showScheduleAccount
    : context.l10n.hideScheduleAccount;

String scheduleCollectionVisibilityAction(
  BuildContext context, {
  required bool calendar,
  required bool accountVisible,
  required bool visible,
}) {
  final l10n = context.l10n;
  if (!accountVisible) return l10n.showAccountToChangeVisibility;
  return calendar
      ? (visible ? l10n.hideScheduleCalendar : l10n.showScheduleCalendar)
      : (visible ? l10n.hideScheduleTaskList : l10n.showScheduleTaskList);
}

String scheduleAccountProviderLetter(BusyProvider provider) =>
    switch (provider) {
      BusyProvider.google => 'G',
      BusyProvider.microsoft => 'M',
      BusyProvider.nextcloud => 'N',
      BusyProvider.appleICloud => 'A',
      BusyProvider.webCal => 'W',
      BusyProvider.caldav => 'C',
    };

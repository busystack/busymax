import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../l10n/l10n.dart';
import '../../l10n/sync_outcome_description.dart';
import 'sync_request.dart';

/// Replaces the glyph in its existing slot for the duration of a request.
class SyncActivityIcon extends ConsumerWidget {
  const SyncActivityIcon({
    super.key,
    required this.scope,
    required this.child,
    required this.refresh,
    required this.warning,
    this.animate = true,
  });

  final SyncScope scope;
  final Widget child;
  final Widget refresh;
  final Widget warning;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(accountSyncActivityProvider);
    final account = scope.kind == SyncScopeKind.account
        ? scope.accountId
        : null;
    final busy =
        activity.busy(scope) ||
        account != null && activity.accountRunning(account);
    final outcome = activity.outcome(scope);
    final needsStatus =
        outcome != null ||
        activity.resourceFailure(scope) != null ||
        account != null && activity.accountNeedsAttention(account);
    if (!busy && !needsStatus) return child;
    final queued = activity.queued(scope) && !activity.executing(scope);
    return Semantics(
      label: busy
          ? (queued ? context.l10n.syncQueued : context.l10n.traySyncing)
          : syncOutcomeDescription(context.l10n, outcome?.disposition),
      child: busy
          ? SyncRotation(enabled: animate && !queued, child: refresh)
          : warning,
    );
  }
}

class SyncRotation extends StatelessWidget {
  const SyncRotation({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      enabled &&
          TickerMode.valuesOf(context).enabled &&
          !MediaQuery.disableAnimationsOf(context)
      ? _RotatingIcon(child: child)
      : child;
}

class _RotatingIcon extends StatefulWidget {
  const _RotatingIcon({required this.child});

  final Widget child;

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _controller, child: widget.child);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

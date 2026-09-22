import 'package:flutter/widgets.dart';

import '../../schedule/task_list_mutation_intent.dart';
import 'busymax_design_values.dart';

typedef BusyMaxMutationItemBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

/// Lazy list reconciliation for one identified, successful local mutation.
/// Unrelated data changes replace the projection without entrance effects.
class BusyMaxMutationList<T> extends StatefulWidget {
  const BusyMaxMutationList({
    super.key,
    required this.items,
    required this.identityOf,
    required this.itemBuilder,
    this.mutation,
    this.mutationApplied,
    this.padding,
    this.separatorBuilder,
    this.emptyBuilder,
    this.onMutationConsumed,
    this.footer,
    this.controller,
  });

  final List<T> items;
  final String Function(T item) identityOf;
  final BusyMaxMutationItemBuilder<T> itemBuilder;
  final TaskListMutationIntent? mutation;
  final bool Function(T item, TaskListMutationIntent mutation)? mutationApplied;
  final EdgeInsetsGeometry? padding;
  final IndexedWidgetBuilder? separatorBuilder;
  final WidgetBuilder? emptyBuilder;
  final ValueChanged<TaskListMutationIntent>? onMutationConsumed;
  final Widget? footer;
  final ScrollController? controller;

  @override
  State<BusyMaxMutationList<T>> createState() => _BusyMaxMutationListState<T>();
}

class _BusyMaxMutationListState<T> extends State<BusyMaxMutationList<T>>
    with SingleTickerProviderStateMixin {
  late List<T> _presented = List<T>.of(widget.items);
  late final AnimationController _mutationAnimation = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  )..addStatusListener(_handleAnimationStatus);
  int? _handledGeneration;
  String? _entering;
  String? _exiting;
  T? _outgoing;
  int? _outgoingIndex;
  TaskListMutationIntent? _activeStructuralMutation;
  int? _animationGeneration;
  final Set<int> _consumedGenerations = {};
  bool _disableAnimations = false;

  bool get _hasActiveMutation => _activeStructuralMutation != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _disableAnimations) return;
    _disableAnimations = disabled;
    if (disabled && _hasActiveMutation) {
      _settleActiveMutation(rebuild: false);
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxMutationList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mutation = widget.mutation;
    if (_hasActiveMutation) {
      final activeGeneration = _activeStructuralMutation!.generation;
      if (mutation == null || mutation.generation != activeGeneration) {
        _settleActiveMutation(rebuild: false);
      } else {
        _reconcileActiveProjection();
        return;
      }
    }
    if (mutation == null || mutation.generation == _handledGeneration) {
      _presented = List<T>.of(widget.items);
      return;
    }
    final target = mutation.taskKey;
    final currentIndex = widget.items.indexWhere(
      (item) => widget.identityOf(item) == target,
    );
    final previousIndex = _presented.indexWhere(
      (item) => widget.identityOf(item) == target,
    );
    if (mutation.presentation == TaskListMutationPresentation.insertion) {
      if (currentIndex < 0) {
        _presented = List<T>.of(widget.items);
        return;
      }
      _handledGeneration = mutation.generation;
      _entering = target;
      _activeStructuralMutation = mutation;
      _presented = List<T>.of(widget.items);
      _startMutationAnimation(mutation.generation);
      return;
    }
    if (currentIndex >= 0) {
      final item = widget.items[currentIndex];
      if (!(widget.mutationApplied?.call(item, mutation) ?? true)) {
        _presented = List<T>.of(widget.items);
        return;
      }
      _handledGeneration = mutation.generation;
      _presented = List<T>.of(widget.items);
      _notifyConsumed(mutation);
      return;
    }
    if (previousIndex < 0) {
      _presented = List<T>.of(widget.items);
      return;
    }
    final outgoing = _presented[previousIndex];
    _handledGeneration = mutation.generation;
    _exiting = target;
    _outgoing = outgoing;
    _outgoingIndex = previousIndex;
    _activeStructuralMutation = mutation;
    _presented = List<T>.of(widget.items)
      ..insert(previousIndex.clamp(0, widget.items.length), outgoing);
    _startMutationAnimation(mutation.generation);
  }

  void _reconcileActiveProjection() {
    final exiting = _exiting;
    if (exiting == null) {
      final entering = _entering;
      _presented = List<T>.of(widget.items);
      if (entering != null &&
          !_presented.any((item) => widget.identityOf(item) == entering)) {
        _settleActiveMutation(rebuild: false);
      }
      return;
    }
    final outgoing = _outgoing;
    if (outgoing == null) {
      _settleActiveMutation(rebuild: false);
      return;
    }
    _presented = List<T>.of(widget.items);
    if (_presented.any((item) => widget.identityOf(item) == exiting)) {
      _settleActiveMutation(rebuild: false);
      return;
    }
    _presented.insert(
      (_outgoingIndex ?? _presented.length).clamp(0, _presented.length),
      outgoing,
    );
  }

  void _startMutationAnimation(int generation) {
    _animationGeneration = generation;
    _mutationAnimation
      ..stop()
      ..value = 0;
    if (_disableAnimations || BusyMaxMotion.taskListMutation == Duration.zero) {
      _settleActiveMutation(rebuild: false);
      return;
    }
    _mutationAnimation.animateTo(
      1,
      duration: BusyMaxMotion.taskListMutation,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    final activeGeneration = _activeStructuralMutation?.generation;
    if (status == AnimationStatus.completed &&
        _hasActiveMutation &&
        _animationGeneration == activeGeneration &&
        mounted) {
      _settleActiveMutation(rebuild: true);
    }
  }

  void _settleActiveMutation({required bool rebuild}) {
    final mutation = _activeStructuralMutation;
    _mutationAnimation.stop();
    _entering = null;
    _exiting = null;
    _outgoing = null;
    _outgoingIndex = null;
    _activeStructuralMutation = null;
    _animationGeneration = null;
    _presented = List<T>.of(widget.items);
    _mutationAnimation.value = 1;
    if (mutation != null) _notifyConsumed(mutation);
    if (rebuild && mounted) setState(() {});
  }

  void _notifyConsumed(TaskListMutationIntent mutation) {
    if (!_consumedGenerations.add(mutation.generation)) return;
    final callback = widget.onMutationConsumed;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback(mutation));
  }

  @override
  void dispose() {
    final mutation = _activeStructuralMutation;
    if (mutation != null) {
      // The row lifecycle is already owned here rather than by a lazy child.
      // Finish the screen-scoped intent even if this whole list is replaced.
      _notifyConsumed(mutation);
    }
    _mutationAnimation.removeStatusListener(_handleAnimationStatus);
    _mutationAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_presented.isEmpty && widget.emptyBuilder != null) {
      final empty = widget.emptyBuilder!(context);
      if (widget.footer == null) return empty;
      return ListView(
        controller: widget.controller,
        padding: widget.padding,
        children: [empty, widget.footer!],
      );
    }
    final separated = widget.separatorBuilder != null;
    final logicalCount = _presented.length + (widget.footer == null ? 0 : 1);
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      itemCount: separated
          ? (logicalCount == 0 ? 0 : logicalCount * 2 - 1)
          : logicalCount,
      itemBuilder: (context, rawIndex) {
        if (separated && rawIndex.isOdd) {
          return widget.separatorBuilder!(context, rawIndex ~/ 2);
        }
        final index = separated ? rawIndex ~/ 2 : rawIndex;
        if (index == _presented.length) return widget.footer!;
        final item = _presented[index];
        final identity = widget.identityOf(item);
        return _MutationCell(
          key: ValueKey(('mutation-cell', identity)),
          entering: identity == _entering,
          exiting: identity == _exiting,
          animation: _mutationAnimation,
          child: widget.itemBuilder(context, item, index),
        );
      },
    );
  }
}

class _MutationCell extends StatelessWidget {
  const _MutationCell({
    super.key,
    required this.entering,
    required this.exiting,
    required this.animation,
    required this.child,
  });

  final bool entering;
  final bool exiting;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> progress = exiting
        ? ReverseAnimation(animation)
        : entering
        ? animation
        : const AlwaysStoppedAnimation(1);
    return IgnorePointer(
      ignoring: exiting,
      child: ExcludeFocus(
        excluding: exiting,
        child: ExcludeSemantics(
          excluding: exiting,
          child: ClipRect(
            child: SizeTransition(
              sizeFactor: progress,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: progress, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

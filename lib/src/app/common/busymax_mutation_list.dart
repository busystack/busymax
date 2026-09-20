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

  @override
  State<BusyMaxMutationList<T>> createState() => _BusyMaxMutationListState<T>();
}

class _BusyMaxMutationListState<T> extends State<BusyMaxMutationList<T>> {
  late List<T> _presented = List<T>.of(widget.items);
  int? _handledGeneration;
  String? _entering;
  String? _exiting;
  TaskListMutationIntent? _exitingMutation;

  @override
  void didUpdateWidget(covariant BusyMaxMutationList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mutation = widget.mutation;
    if (_exiting != null) return;
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
      _presented = List<T>.of(widget.items);
      _notifyConsumed(mutation);
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
    _exitingMutation = mutation;
    _presented = List<T>.of(widget.items)
      ..insert(previousIndex.clamp(0, widget.items.length), outgoing);
  }

  void _notifyConsumed(TaskListMutationIntent mutation) {
    final callback = widget.onMutationConsumed;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(mutation);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_presented.isEmpty && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }
    final separated = widget.separatorBuilder != null;
    final logicalCount = _presented.length + (widget.footer == null ? 0 : 1);
    return ListView.builder(
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
          onFinished: () {
            if (!mounted) return;
            setState(() {
              if (_entering == identity) _entering = null;
              if (_exiting == identity) {
                final mutation = _exitingMutation;
                _exiting = null;
                _exitingMutation = null;
                _presented = List<T>.of(widget.items);
                if (mutation != null) _notifyConsumed(mutation);
              }
            });
          },
          child: widget.itemBuilder(context, item, index),
        );
      },
    );
  }
}

class _MutationCell extends StatefulWidget {
  const _MutationCell({
    super.key,
    required this.entering,
    required this.exiting,
    required this.onFinished,
    required this.child,
  });

  final bool entering;
  final bool exiting;
  final VoidCallback onFinished;
  final Widget child;

  @override
  State<_MutationCell> createState() => _MutationCellState();
}

class _MutationCellState extends State<_MutationCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: widget.entering ? 0 : 1,
  );
  bool _disableAnimations = false;
  bool _finishScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled && (widget.entering || widget.exiting)) {
        _controller.value = widget.exiting ? 0 : 1;
        _finishAfterFrame();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _MutationCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entering != oldWidget.entering ||
        widget.exiting != oldWidget.exiting) {
      _run();
    }
  }

  Future<void> _run() async {
    if (!mounted || (!widget.entering && !widget.exiting)) return;
    final target = widget.exiting ? 0.0 : 1.0;
    if (_disableAnimations) {
      _controller.value = target;
      _finishAfterFrame();
      return;
    } else {
      await _controller.animateTo(
        target,
        duration: BusyMaxMotion.taskListMutation,
        curve: BusyMaxMotion.presentationCurve,
      );
    }
    if (mounted) widget.onFinished();
  }

  void _finishAfterFrame() {
    if (_finishScheduled) return;
    _finishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finishScheduled = false;
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: widget.exiting,
    child: ExcludeFocus(
      excluding: widget.exiting,
      child: ExcludeSemantics(
        excluding: widget.exiting,
        child: ClipRect(
          child: SizeTransition(
            sizeFactor: _controller,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: _controller, child: widget.child),
          ),
        ),
      ),
    ),
  );
}

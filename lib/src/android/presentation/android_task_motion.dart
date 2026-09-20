import 'package:flutter/material.dart';

import '../../app/common/busymax_design_values.dart';

class AndroidTaskCompletionIcon extends StatefulWidget {
  const AndroidTaskCompletionIcon({
    super.key,
    required this.completed,
    this.size,
    this.animate = false,
  });

  final bool completed;
  final double? size;
  final bool animate;

  @override
  State<AndroidTaskCompletionIcon> createState() =>
      _AndroidTaskCompletionIconState();
}

class _AndroidTaskCompletionIconState extends State<AndroidTaskCompletionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: widget.completed ? 1 : 0,
  );
  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled) _controller.value = widget.completed ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant AndroidTaskCompletionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completed == widget.completed) return;
    final target = widget.completed ? 1.0 : 0.0;
    if (_disableAnimations || !widget.animate) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    if (distance == 0) return;
    _controller.animateTo(
      target,
      duration: BusyMaxMotion.taskCompletion * distance,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size ?? IconTheme.of(context).size ?? 24,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final scheme = Theme.of(context).colorScheme;
        return Transform.scale(
          scale: .92 + .08 * (progress <= .5 ? 1 - progress : progress),
          child: Icon(
            progress >= .5 ? Icons.check_circle : Icons.radio_button_unchecked,
            size: widget.size,
            color: Color.lerp(
              scheme.onSurfaceVariant,
              scheme.primary,
              progress,
            ),
          ),
        );
      },
    ),
  );
}

class AndroidTaskTitle extends StatelessWidget {
  const AndroidTaskTitle({
    super.key,
    required this.title,
    required this.completed,
    this.maxLines = 2,
    this.animate = false,
  });

  final String title;
  final bool completed;
  final int maxLines;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedDefaultTextStyle(
      duration: MediaQuery.disableAnimationsOf(context) || !animate
          ? Duration.zero
          : BusyMaxMotion.taskCompletion,
      curve: BusyMaxMotion.presentationCurve,
      style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
        decoration: completed ? TextDecoration.lineThrough : null,
        color: completed
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
      ),
      child: Text(title, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
  }
}

import 'package:flutter/widgets.dart';

import 'busymax_design_values.dart';

/// A full-size child revealed by changing only its clipped horizontal slot.
///
/// [transitionGeneration] must change only for an explicit user interaction.
/// Responsive changes can therefore settle immediately without chasing the
/// window size. The child keeps its full layout width throughout the reveal.
class BusyMaxHorizontalReveal extends StatefulWidget {
  const BusyMaxHorizontalReveal({
    super.key,
    required this.visible,
    required this.width,
    required this.transitionGeneration,
    required this.child,
    this.duration = BusyMaxMotion.sidebar,
  });

  final bool visible;
  final double width;
  final int transitionGeneration;
  final Duration duration;
  final Widget child;

  @override
  State<BusyMaxHorizontalReveal> createState() =>
      _BusyMaxHorizontalRevealState();
}

class _BusyMaxHorizontalRevealState extends State<BusyMaxHorizontalReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: widget.visible ? 1 : 0,
  );
  late int _generation;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _generation = widget.transitionGeneration;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled && _controller.isAnimating) {
        _controller.value = widget.visible ? 1 : 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxHorizontalReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.visible ? 1.0 : 0.0;
    if (widget.transitionGeneration == _generation) {
      // Ordinary data/theme rebuilds must not terminate an in-flight reveal.
      // A visibility change without a semantic generation is a responsive
      // layout change and intentionally settles without animation.
      if (widget.visible != oldWidget.visible) {
        _controller
          ..stop()
          ..value = target;
      }
      return;
    }
    _generation = widget.transitionGeneration;
    if (_disableAnimations || widget.duration == Duration.zero) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    if (distance == 0) {
      // A same-frame reversal can target the current endpoint while an older
      // simulation is still headed away from it.
      _controller
        ..stop()
        ..value = target;
      return;
    }
    _controller.animateTo(
      target,
      duration: widget.duration * distance,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.visible;
    return AnimatedBuilder(
      animation: _controller,
      child: SizedBox(width: widget.width, child: widget.child),
      builder: (context, child) => IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: TickerMode(
              enabled: active || _controller.value > 0,
              child: ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: _controller.value,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BusyMaxVerticalReveal extends StatefulWidget {
  const BusyMaxVerticalReveal({
    super.key,
    required this.visible,
    required this.child,
    this.duration = BusyMaxMotion.search,
  });

  final bool visible;
  final Widget child;
  final Duration duration;

  @override
  State<BusyMaxVerticalReveal> createState() => _BusyMaxVerticalRevealState();
}

class _BusyMaxVerticalRevealState extends State<BusyMaxVerticalReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: widget.visible ? 1 : 0,
  );
  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled) _controller.value = widget.visible ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxVerticalReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    final target = widget.visible ? 1.0 : 0.0;
    if (_disableAnimations || widget.duration == Duration.zero) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    if (distance == 0) return;
    _controller.animateTo(
      target,
      duration: widget.duration * distance,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: ExcludeSemantics(
          excluding: !widget.visible,
          child: TickerMode(
            enabled: widget.visible || _controller.value > 0,
            child: ClipRect(
              child: SizeTransition(
                sizeFactor: _controller,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: _controller, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bounded directional period transition driven by an explicit generation.
class BusyMaxDirectionalSwitcher extends StatefulWidget {
  const BusyMaxDirectionalSwitcher({
    super.key,
    required this.generation,
    required this.direction,
    required this.child,
    this.duration = BusyMaxMotion.calendarPeriod,
  });

  final int generation;
  final int direction;
  final Widget child;
  final Duration duration;

  @override
  State<BusyMaxDirectionalSwitcher> createState() =>
      _BusyMaxDirectionalSwitcherState();
}

class _BusyMaxDirectionalSwitcherState extends State<BusyMaxDirectionalSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  );
  late int _generation;
  late final List<Widget> _slots = [widget.child, const SizedBox.shrink()];
  var _index = 0;
  var _direction = 0;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _generation = widget.generation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled) _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxDirectionalSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.generation == _generation || widget.direction == 0) {
      _slots[_index] = widget.child;
      return;
    }
    _generation = widget.generation;
    _direction = widget.direction.sign;
    _index = 1 - _index;
    _slots[_index] = widget.child;
    if (_disableAnimations || widget.duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller
      ..value = 0
      ..animateTo(
        1,
        duration: widget.duration,
        curve: BusyMaxMotion.presentationCurve,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final visualDirection =
        _direction * (textDirection == TextDirection.rtl ? -1 : 1);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            for (var slot = 0; slot < _slots.length; slot++)
              if (slot == _index || (_controller.value < 1 && slot != _index))
                IgnorePointer(
                  ignoring: slot != _index,
                  child: ExcludeFocus(
                    excluding: slot != _index,
                    child: ExcludeSemantics(
                      excluding: slot != _index,
                      child: FractionalTranslation(
                        translation: Offset(
                          slot == _index
                              ? visualDirection * .08 * (1 - _controller.value)
                              : -visualDirection * .08 * _controller.value,
                          0,
                        ),
                        child: Opacity(
                          opacity: slot == _index
                              ? .72 + .28 * _controller.value
                              : 1 - _controller.value,
                          child: _slots[slot],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Moves the existing live surface into its new period without replacing it.
class BusyMaxDirectionalEntrance extends StatefulWidget {
  const BusyMaxDirectionalEntrance({
    super.key,
    required this.generation,
    required this.direction,
    required this.child,
    this.duration = BusyMaxMotion.calendarPeriod,
  });

  final int generation;
  final int direction;
  final Widget child;
  final Duration duration;

  @override
  State<BusyMaxDirectionalEntrance> createState() =>
      _BusyMaxDirectionalEntranceState();
}

class _BusyMaxDirectionalEntranceState extends State<BusyMaxDirectionalEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  );
  late int _generation;
  int _direction = 0;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _generation = widget.generation;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled) _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxDirectionalEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.generation == _generation || widget.direction == 0) return;
    _generation = widget.generation;
    _direction = widget.direction.sign;
    if (_disableAnimations || widget.duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller
      ..value = 0
      ..animateTo(
        1,
        duration: widget.duration,
        curve: BusyMaxMotion.presentationCurve,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final visual = _direction * (rtl ? -1 : 1);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(visual * .08 * (1 - _controller.value), 0),
          child: Opacity(opacity: .72 + .28 * _controller.value, child: child),
        ),
      ),
    );
  }
}

/// Crossfades a fixed set of live pages without reconstructing destinations.
class BusyMaxRetainedCrossfade extends StatefulWidget {
  const BusyMaxRetainedCrossfade({
    super.key,
    required this.index,
    required this.children,
    this.duration = BusyMaxMotion.crossfade,
  }) : assert(children.length > 0),
       assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<BusyMaxRetainedCrossfade> createState() =>
      _BusyMaxRetainedCrossfadeState();
}

/// Retains the last normal and alternate presentations while switching.
/// Updates affect only the currently active side, so an inactive planner is
/// never given search results (and vice versa).
class BusyMaxBinaryPresentation extends StatefulWidget {
  const BusyMaxBinaryPresentation({
    super.key,
    required this.alternateActive,
    required this.child,
    this.duration = BusyMaxMotion.search,
  });

  final bool alternateActive;
  final Widget child;
  final Duration duration;

  @override
  State<BusyMaxBinaryPresentation> createState() =>
      _BusyMaxBinaryPresentationState();
}

class _BusyMaxBinaryPresentationState extends State<BusyMaxBinaryPresentation> {
  Widget _normal = const SizedBox.shrink();
  Widget _alternate = const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    if (widget.alternateActive) {
      _alternate = widget.child;
    } else {
      _normal = widget.child;
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxBinaryPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alternateActive) {
      _alternate = widget.child;
    } else {
      _normal = widget.child;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BusyMaxRetainedCrossfade(
      index: widget.alternateActive ? 1 : 0,
      duration: widget.duration,
      children: [_normal, _alternate],
    );
  }
}

/// A semantic destination host: data rebuilds update the active destination,
/// while every previously visited destination keeps its live element state.
/// Only a changed [transitionKey] starts a crossfade.
class BusyMaxKeyedCrossfade extends StatefulWidget {
  const BusyMaxKeyedCrossfade({
    super.key,
    required this.transitionKey,
    required this.child,
    this.duration = BusyMaxMotion.crossfade,
  });

  final Object transitionKey;
  final Widget child;
  final Duration duration;

  @override
  State<BusyMaxKeyedCrossfade> createState() => _BusyMaxKeyedCrossfadeState();
}

class _BusyMaxKeyedCrossfadeState extends State<BusyMaxKeyedCrossfade> {
  late final List<Object> _keys;
  late final List<GlobalKey> _destinationKeys;
  late final List<Widget> _destinations;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    final key = GlobalKey(
      debugLabel: 'busymax-destination-${widget.transitionKey}',
    );
    _keys = [widget.transitionKey];
    _destinationKeys = [key];
    _destinations = [KeyedSubtree(key: key, child: widget.child)];
  }

  @override
  void didUpdateWidget(covariant BusyMaxKeyedCrossfade oldWidget) {
    super.didUpdateWidget(oldWidget);
    final destination = _keys.indexOf(widget.transitionKey);
    if (destination < 0) {
      _keys.add(widget.transitionKey);
      final key = GlobalKey(
        debugLabel: 'busymax-destination-${widget.transitionKey}',
      );
      _destinationKeys.add(key);
      _destinations.add(KeyedSubtree(key: key, child: widget.child));
      _index = _keys.length - 1;
    } else {
      _index = destination;
      _destinations[destination] = KeyedSubtree(
        key: _destinationKeys[destination],
        child: widget.child,
      );
    }
  }

  @override
  Widget build(BuildContext context) => BusyMaxRetainedCrossfade(
    index: _index,
    duration: widget.duration,
    // Widgets are immutable. Do not let an older retained host observe later
    // in-place destination-list edits during element reconciliation.
    children: List<Widget>.of(_destinations, growable: false),
  );
}

class _BusyMaxRetainedCrossfadeState extends State<BusyMaxRetainedCrossfade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  );
  late int _current = widget.index;
  int? _outgoing;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled) {
        _controller.stop();
        _outgoing = null;
        _controller.value = 1;
      }
    }
  }

  @override
  void didUpdateWidget(covariant BusyMaxRetainedCrossfade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == _current) return;
    if (widget.index == _outgoing && _controller.isAnimating) {
      // A -> B -> A reverses from the presentation currently on screen.
      // Swapping the roles and complementing progress preserves both page
      // opacities instead of replaying a complete transition from an endpoint.
      final previousCurrent = _current;
      _current = widget.index;
      _outgoing = previousCurrent;
      _controller.value = 1 - _controller.value;
    } else {
      _outgoing = _current;
      _current = widget.index;
      _controller.value = 0;
    }
    if (_disableAnimations || widget.duration == Duration.zero) {
      _finish();
      return;
    }
    final distance = 1 - _controller.value;
    if (distance == 0) {
      _finish();
      return;
    }
    _controller.animateTo(
      1,
      duration: widget.duration * distance,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  void _finish() {
    if (!mounted) return;
    _outgoing = null;
    _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        fit: StackFit.loose,
        children: [
          for (var index = 0; index < widget.children.length; index++)
            _RetainedPage(
              key: ValueKey(('busymax-retained-page', index)),
              active: index == _current,
              outgoing: index == _outgoing,
              opacity: index == _current
                  ? _controller.value
                  : index == _outgoing
                  ? 1 - _controller.value
                  : 0,
              child: widget.children[index],
            ),
        ],
      ),
    );
  }
}

class _RetainedPage extends StatelessWidget {
  const _RetainedPage({
    super.key,
    required this.active,
    required this.outgoing,
    required this.opacity,
    required this.child,
  });

  final bool active;
  final bool outgoing;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !active && !outgoing,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeFocus(
          excluding: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: TickerMode(
              enabled: active,
              child: Opacity(opacity: opacity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

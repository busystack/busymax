import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../l10n/time_format_scope.dart';

/// Application-owned clock presentation. Pending values, date/time-zone identity
/// and live clock preferences belong to the calendar draft, not a library fork.
class WindowsTimePicker extends StatefulWidget {
  const WindowsTimePicker({
    required this.selected,
    this.onChanged,
    this.onCancel,
    this.header,
    this.endOfDay = false,
    super.key,
  });
  final DateTime? selected;
  final ValueChanged<DateTime>? onChanged;
  final VoidCallback? onCancel;
  final String? header;
  final bool endOfDay;
  @override
  State<WindowsTimePicker> createState() => WindowsTimePickerState();
}

class WindowsTimePickerState extends State<WindowsTimePicker> {
  final _flyout = FlyoutController();
  bool _open = false;

  Future<void> open() async {
    if (_open || widget.onChanged == null) return;
    _open = true;
    final initial = widget.selected ?? DateTime.now();
    try {
      final value = await _flyout.showFlyout<DateTime>(
        builder: (context) => FlyoutContent(
          child: _PendingClock(
            initial: initial,
            confirm: (value) => _flyout.close(value),
            cancel: () => _flyout.close<DateTime>(),
          ),
        ),
      );
      if (!mounted) return;
      if (value == null) {
        widget.onCancel?.call();
      } else if (value != widget.selected) {
        widget.onChanged?.call(value);
      }
    } finally {
      _open = false;
    }
  }

  @override
  void dispose() {
    _flyout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = BusyMaxTimeFormatScope.of(context);
    final selected = widget.selected;
    final locale = Localizations.localeOf(context).toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(widget.header!),
          ),
        FlyoutTarget(
          controller: _flyout,
          child: Button(
            onPressed: widget.onChanged == null ? null : open,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected == null
                      ? '–'
                      : _hour(selected.hour, locale, clock.use24Hour),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':'),
                ),
                Text(selected == null ? '–' : _minute(selected.minute, locale)),
                if (!clock.use24Hour)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      selected == null
                          ? '–'
                          : _period(selected.hour >= 12, locale),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.endOfDay) Text(formatScheduleBoundary(context, 1440)),
      ],
    );
  }
}

String _hour(int hour, String locale, bool use24) => (DateFormat(
  use24 ? "HH'|'" : "h'|'",
  locale,
)..useNativeDigits = true).format(DateTime(2000, 1, 1, hour)).split('|').first;
String _minute(int minute, String locale) => (DateFormat(
  'mm',
  locale,
)..useNativeDigits = true).format(DateTime(2000, 1, 1, 0, minute));
String _period(bool pm, String locale) =>
    DateFormat('a', locale).format(DateTime(2000, 1, 1, pm ? 12 : 0));

class _PendingClock extends StatefulWidget {
  const _PendingClock({
    required this.initial,
    required this.confirm,
    required this.cancel,
  });
  final DateTime initial;
  final ValueChanged<DateTime> confirm;
  final VoidCallback cancel;
  @override
  State<_PendingClock> createState() => _PendingClockState();
}

class _PendingClockState extends State<_PendingClock> {
  late DateTime _draft = widget.initial;
  @override
  Widget build(BuildContext context) {
    final use24 = BusyMaxTimeFormatScope.of(context).use24Hour;
    final locale = Localizations.localeOf(context).toString();
    final style = FluentTheme.of(context).typography.body;
    final measure = TextPainter(
      text: TextSpan(text: '00', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final row = math.max(40.0, measure.height + 20);
    measure.dispose();
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: row * 5,
            child: Row(
              children: [
                Expanded(
                  child: _ClockWheel(
                    key: ValueKey('hours-$use24'),
                    count: use24 ? 24 : 12,
                    initial: use24 ? _draft.hour : _draft.hour % 12,
                    row: row,
                    label: (i) => _hour(i, locale, use24),
                    changed: (i) => setState(
                      () => _draft = _draft.copyWith(
                        hour: use24 ? i : i + (_draft.hour >= 12 ? 12 : 0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _ClockWheel(
                    count: 60,
                    initial: _draft.minute,
                    row: row,
                    label: (i) => _minute(i, locale),
                    changed: (i) =>
                        setState(() => _draft = _draft.copyWith(minute: i)),
                  ),
                ),
                if (!use24)
                  Expanded(
                    child: _ClockWheel(
                      key: const ValueKey('period'),
                      count: 2,
                      initial: _draft.hour >= 12 ? 1 : 0,
                      row: row,
                      looping: false,
                      label: (i) => _period(i == 1, locale),
                      changed: (i) => setState(
                        () => _draft = _draft.copyWith(
                          hour: _draft.hour % 12 + i * 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('time-confirm'),
                  onPressed: () => widget.confirm(_draft),
                  child: Text(context.l10n.save),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Button(
                  key: const ValueKey('time-cancel'),
                  onPressed: widget.cancel,
                  child: Text(context.l10n.cancel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClockWheel extends StatefulWidget {
  const _ClockWheel({
    super.key,
    required this.count,
    required this.initial,
    required this.row,
    required this.label,
    required this.changed,
    this.looping = true,
  });
  final int count, initial;
  final double row;
  final String Function(int) label;
  final ValueChanged<int> changed;
  final bool looping;
  @override
  State<_ClockWheel> createState() => _ClockWheelState();
}

class _ClockWheelState extends State<_ClockWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.initial,
  );
  bool _focusVisible = false;

  void _step(int delta) {
    final next = widget.looping
        ? _controller.selectedItem + delta
        : (_controller.selectedItem + delta).clamp(0, widget.count - 1);
    _controller.jumpToItem(next);
    widget.changed(next % widget.count);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (var i = 0; i < widget.count; i++)
        widget.looping
            ? Center(child: Text(widget.label(i)))
            : Button(
                onPressed: () => _controller.animateToItem(
                  i,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                ),
                child: Center(child: Text(widget.label(i))),
              ),
    ];
    return FocusableActionDetector(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowUp): _ClockStepIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _ClockStepIntent(1),
      },
      actions: {
        _ClockStepIntent: CallbackAction<_ClockStepIntent>(
          onInvoke: (intent) {
            _step(intent.delta);
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
      child: FocusBorder(
        focused: _focusVisible,
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: widget.row,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: widget.changed,
          childDelegate: widget.looping
              ? ListWheelChildLoopingListDelegate(children: labels)
              : ListWheelChildListDelegate(children: labels),
        ),
      ),
    );
  }
}

class _ClockStepIntent extends Intent {
  const _ClockStepIntent(this.delta);
  final int delta;
}

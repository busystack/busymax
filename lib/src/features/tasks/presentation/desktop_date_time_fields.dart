import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:busymax/src/core/time/local_time_zone.dart';
import 'package:busymax/src/core/time/time_zone_catalog.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:busymax/src/features/schedule/presentation/mini_calendar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_anchored_popover.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/features/tasks/presentation/time_zone_selection_dialog.dart';
import 'package:yaru/yaru.dart';

@visibleForTesting
const nativeDateTimePickerChannelName = 'busymax/native_date_time_picker';

const _nativeDateTimePicker = NativeDateTimePicker();
const _dateTimePickerMaxWidth = 300.0;
const _dateTimePickerContentMaxHeight = 320.0;
const _dateTimePickerPopoverMinimumHeight = 300.0;
const _dateTimePickerPopoverPadding = EdgeInsets.all(BusyMaxSpacing.lg);
const _timePickerMaxWidth = 260.0;
const _timePickerMinimumWidth = 240.0;
const _timePickerPopoverMinimumHeight = 220.0;
const _timePickerPopoverPadding = EdgeInsets.all(BusyMaxSpacing.md);
const _timePickerInputControlSize = BusyMaxSizes.popoverActionButton;
const _timePickerInputColumnMinWidth = 36.0;
const _timePickerInputColumnMaxWidth = 38.0;

class NativeDateTimePicker {
  const NativeDateTimePicker();

  static const _channel = MethodChannel(nativeDateTimePickerChannelName);

  Future<NativeDatePickResult> pickDate({
    required String title,
    required String? initialDate,
    required String cancelLabel,
    required String okLabel,
  }) async {
    return _invoke('pickDate', {
      'title': title,
      'initialDate': initialDate,
      'cancelLabel': cancelLabel,
      'okLabel': okLabel,
    });
  }

  Future<NativeDatePickResult> pickTime({
    required String title,
    required String? initialTime,
    required String cancelLabel,
    required String okLabel,
  }) async {
    return _invoke('pickTime', {
      'title': title,
      'initialTime': initialTime,
      'cancelLabel': cancelLabel,
      'okLabel': okLabel,
    });
  }

  Future<NativeDatePickResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final value = await _channel.invokeMethod<String>(method, arguments);
      return NativeDatePickResult(available: true, date: value, time: value);
    } on MissingPluginException {
      return const NativeDatePickResult(available: false);
    }
  }
}

class NativeDatePickResult {
  const NativeDatePickResult({required this.available, this.date, this.time});

  final bool available;
  final String? date;
  final String? time;
}

class DesktopDateField extends StatefulWidget {
  const DesktopDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onChanged,
    this.enabled = true,
    this.onClear,
    this.useNativePicker = false,
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;
  final bool useNativePicker;

  @override
  State<DesktopDateField> createState() => _DesktopDateFieldState();
}

class DesktopDateValueRow extends StatelessWidget {
  const DesktopDateValueRow({
    super.key,
    required this.label,
    required this.date,
    required this.onChanged,
    this.enabled = true,
    this.onClear,
    this.useNativePicker = false,
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;
  final bool useNativePicker;

  @override
  Widget build(BuildContext context) {
    return DesktopDateField(
      label: label,
      date: date,
      onChanged: onChanged,
      enabled: enabled,
      onClear: onClear,
      useNativePicker: useNativePicker,
    );
  }
}

class _DesktopDateFieldState extends State<DesktopDateField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncVisibleValue();
  }

  @override
  void didUpdateWidget(covariant DesktopDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _syncVisibleValue();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canClear = widget.date?.isNotEmpty ?? false;
    return BusyMaxCalendarValueRow(
      label: widget.label,
      entry: Builder(
        builder: (fieldContext) => TextFormField(
          controller: _controller,
          readOnly: true,
          showCursor: false,
          enableInteractiveSelection: false,
          enabled: widget.enabled,
          decoration: busyMaxGroupedTextFieldDecoration(
            context,
            labelText: widget.label,
          ),
          onTap: widget.enabled
              ? () => _pickNativeDate(context, fieldContext)
              : null,
        ),
      ),
      trailingIcons: [
        if (canClear && widget.onClear != null)
          YaruIconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: widget.enabled ? widget.onClear : null,
            icon: const Icon(YaruIcons.window_close),
          ),
        Builder(
          builder: (buttonContext) => YaruIconButton(
            tooltip: widget.label,
            onPressed: widget.enabled
                ? () => _pickNativeDate(context, buttonContext)
                : null,
            icon: const Icon(YaruIcons.calendar),
          ),
        ),
      ],
      enabled: widget.enabled,
    );
  }

  void _syncVisibleValue() {
    final formatted = formatDesktopDate(context, widget.date);
    if (_controller.text == formatted) {
      return;
    }
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickNativeDate(
    BuildContext context,
    BuildContext anchorContext,
  ) async {
    if (!widget.enabled) {
      return;
    }
    if (!widget.useNativePicker) {
      final fallbackPicked = await showBusyMaxDateValueDialog(
        context,
        label: widget.label,
        initialDate: widget.date,
        anchorContext: anchorContext,
      );
      if (mounted && fallbackPicked != null) {
        _applyPickedDate(fallbackPicked);
      }
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    final picked = await _nativeDateTimePicker.pickDate(
      title: widget.label,
      initialDate: widget.date,
      cancelLabel: localizations.cancelButtonLabel,
      okLabel: localizations.okButtonLabel,
    );
    if (!context.mounted) {
      return;
    }
    if (picked.date != null) {
      _applyPickedDate(picked.date!);
      return;
    }
    if (picked.available) {
      return;
    }
    final fallbackPicked = await showBusyMaxDateValueDialog(
      context,
      label: widget.label,
      initialDate: widget.date,
      anchorContext: anchorContext,
    );
    if (mounted && fallbackPicked != null) {
      _applyPickedDate(fallbackPicked);
    }
  }

  void _applyPickedDate(String picked) {
    final formatted = formatDesktopDate(context, picked);
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged(picked);
  }
}

Future<String?> showBusyMaxDateValueDialog(
  BuildContext context, {
  required String label,
  required String? initialDate,
  BuildContext? anchorContext,
}) {
  return showScheduleAnchoredPopover<String>(
    context: context,
    anchorContext: anchorContext ?? context,
    semanticLabel: label,
    preferredWidth: _dateTimePickerMaxWidth,
    minimumWidth: 280,
    preferredMinimumHeight: _dateTimePickerPopoverMinimumHeight,
    builder: (context, arrowSide, arrowAlignment) => _DesktopDateValueDialog(
      label: label,
      initialDate: initialDate,
      arrowSide: arrowSide,
      arrowAlignment: arrowAlignment,
    ),
  );
}

Future<String?> showBusyMaxTimeValueDialog(
  BuildContext context, {
  required String label,
  required String? initialTime,
  required bool allowEmpty,
  String? initialTimeZone,
  ValueChanged<String?>? onTimeChanged,
  ValueChanged<String>? onTimeZoneChanged,
  BuildContext? anchorContext,
}) {
  return showScheduleAnchoredPopover<String>(
    context: context,
    anchorContext: anchorContext ?? context,
    semanticLabel: label,
    preferredWidth: _timePickerMaxWidth,
    minimumWidth: _timePickerMinimumWidth,
    preferredMinimumHeight: _timePickerPopoverMinimumHeight,
    builder: (context, arrowSide, arrowAlignment) => _DesktopTimeValueDialog(
      label: label,
      initialTime: initialTime,
      initialTimeZone: initialTimeZone,
      allowEmpty: allowEmpty,
      onTimeChanged: onTimeChanged,
      onTimeZoneChanged: onTimeZoneChanged,
      arrowSide: arrowSide,
      arrowAlignment: arrowAlignment,
    ),
  );
}

class _DesktopDateValueDialog extends StatefulWidget {
  const _DesktopDateValueDialog({
    required this.label,
    required this.initialDate,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  final String label;
  final String? initialDate;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;

  @override
  State<_DesktopDateValueDialog> createState() =>
      _DesktopDateValueDialogState();
}

class _DesktopDateValueDialogState extends State<_DesktopDateValueDialog> {
  static final _firstDate = DateTime(1900);
  static final _lastDate = DateTime(2100, 12, 31);
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = _supportedInitialDate(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = _calculateDateTimePickerPopupHeight(constraints);
        return BusyMaxContentPopoverSurface(
          arrowSide: widget.arrowSide,
          arrowAlignment: widget.arrowAlignment,
          padding: _dateTimePickerPopoverPadding,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: contentHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDateModeHeader(context),
                    MiniCalendar(
                      selectedDate: _selected,
                      firstWeekday: _firstWeekday(context),
                      items: const <ScheduleItem>[],
                      showHeader: false,
                      showDayHover: true,
                      weekNumbersInteractive: false,
                      onSelected: (date) => _setSelectedDate(
                        date,
                        submit:
                            date.year == _selected.year &&
                            date.month == _selected.month,
                      ),
                      onMonthSelected: null,
                      onYearSelected: null,
                      onWeekSelected: (week) =>
                          _setSelectedDate(week, submit: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _setSelectedDate(DateTime value, {bool submit = false}) {
    final preserveDay =
        value.day == 1 &&
        (value.year != _selected.year || value.month != _selected.month);
    final nextDay = preserveDay ? _selected.day : value.day;
    final clamped = _clampMonthAndDay(
      nextDay,
      DateTime(value.year, value.month),
    );
    final adjusted = _coerceSupportedRange(clamped);
    setState(() {
      _selected = adjusted;
    });
    if (submit) {
      _submit();
    }
  }

  void _submit() {
    Navigator.of(context).pop(encodeDateOnly(_selected));
  }

  Widget _buildDateModeHeader(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat.MMMM(locale).format(_selected);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDateModeStepper(
              context: context,
              label: monthLabel,
              previousTooltip: context.l10n.previousMonth,
              nextTooltip: context.l10n.nextMonth,
              onPrevious: () => _setSelectedDate(
                DateTime(_selected.year, _selected.month - 1),
              ),
              onNext: () => _setSelectedDate(
                DateTime(_selected.year, _selected.month + 1),
              ),
              onLabelPressed: null,
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: _buildDateModeStepper(
              context: context,
              label: '${_selected.year}',
              previousTooltip: context.l10n.previousYear,
              nextTooltip: context.l10n.nextYear,
              onPrevious: () => _setSelectedDate(
                DateTime(_selected.year - 1, _selected.month),
              ),
              onNext: () => _setSelectedDate(
                DateTime(_selected.year + 1, _selected.month),
              ),
              onLabelPressed: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateModeStepper({
    required BuildContext context,
    required String label,
    required String previousTooltip,
    required String nextTooltip,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    VoidCallback? onLabelPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _stepButton(
          context,
          colorScheme: colorScheme,
          tooltip: previousTooltip,
          icon: YaruIcons.pan_start,
          onPressed: onPrevious,
        ),
        const SizedBox(width: BusyMaxSpacing.xs),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _stepLabel(context, label, onLabelPressed),
          ),
        ),
        const SizedBox(width: BusyMaxSpacing.xs),
        _stepButton(
          context,
          colorScheme: colorScheme,
          tooltip: nextTooltip,
          icon: YaruIcons.pan_end,
          onPressed: onNext,
        ),
      ],
    );
  }

  Widget _stepButton(
    BuildContext context, {
    required ColorScheme colorScheme,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return BusyMaxHeaderIconButton(
      tooltip: tooltip,
      iconSize: BusyMaxSizes.headerIcon,
      icon: Icon(icon),
      onPressed: onPressed,
      foregroundColor: colorScheme.onSurfaceVariant,
      backgroundColor: WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  Widget _stepLabel(
    BuildContext context,
    String label,
    VoidCallback? onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle =
        (busyMaxSectionHeaderStyle(context) ??
                Theme.of(context).textTheme.titleSmall)
            ?.copyWith(color: colorScheme.onSurface);
    if (onPressed == null) {
      return Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: busyMaxHeaderTextButtonStyle(
        context,
        foregroundColor: colorScheme.onSurface,
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      ),
    );
  }

  DateTime _clampMonthAndDay(int day, DateTime month) {
    final maxDay = DateUtils.getDaysInMonth(month.year, month.month);
    return DateTime(month.year, month.month, day.clamp(1, maxDay));
  }

  DateTime _coerceSupportedRange(DateTime date) {
    if (date.isBefore(_firstDate)) {
      return _firstDate;
    }
    if (date.isAfter(_lastDate)) {
      return _lastDate;
    }
    return date;
  }

  int _firstWeekday(BuildContext context) {
    final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return index == 0 ? DateTime.sunday : index;
  }

  DateTime _supportedInitialDate(String? encodedDate) {
    final date = parseDateOnly(encodedDate) ?? _today();
    if (date.isBefore(_firstDate)) {
      return _firstDate;
    }
    if (date.isAfter(_lastDate)) {
      return _lastDate;
    }
    return date;
  }
}

double _calculateDateTimePickerPopupHeight(BoxConstraints constraints) {
  final availableHeight =
      constraints.maxHeight -
      (_dateTimePickerPopoverPadding.vertical +
          BusyMaxSizes.popoverArrowHeight);
  if (constraints.maxHeight <= 0 || constraints.maxHeight.isInfinite) {
    return _dateTimePickerContentMaxHeight;
  }
  return availableHeight.clamp(0, _dateTimePickerContentMaxHeight);
}

class DesktopTimeField extends StatefulWidget {
  const DesktopTimeField({
    super.key,
    required this.label,
    required this.time,
    required this.onChanged,
    this.enabled = true,
    this.allowEmpty = true,
    this.onValidityChanged,
    this.useNativePicker = false,
    this.timeZone,
    this.onTimeZoneChanged,
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool allowEmpty;
  final ValueChanged<bool>? onValidityChanged;
  final bool useNativePicker;
  final String? timeZone;
  final ValueChanged<String>? onTimeZoneChanged;

  @override
  State<DesktopTimeField> createState() => _DesktopTimeFieldState();
}

class DesktopTimeValueRow extends StatelessWidget {
  const DesktopTimeValueRow({
    super.key,
    required this.label,
    required this.time,
    required this.onChanged,
    this.enabled = true,
    this.allowEmpty = true,
    this.onValidityChanged,
    this.useNativePicker = false,
    this.timeZone,
    this.onTimeZoneChanged,
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool allowEmpty;
  final ValueChanged<bool>? onValidityChanged;
  final bool useNativePicker;
  final String? timeZone;
  final ValueChanged<String>? onTimeZoneChanged;

  @override
  Widget build(BuildContext context) {
    return DesktopTimeField(
      label: label,
      time: time,
      onChanged: onChanged,
      enabled: enabled,
      allowEmpty: allowEmpty,
      onValidityChanged: onValidityChanged,
      useNativePicker: useNativePicker,
      timeZone: timeZone,
      onTimeZoneChanged: onTimeZoneChanged,
    );
  }
}

class _DesktopTimeFieldState extends State<DesktopTimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _syncingText = false;
  var _inputValid = true;
  bool? _reportedValidity;
  var _hasPendingEmission = false;
  String? _pendingEmission;

  @override
  void initState() {
    super.initState();
    _inputValid = _storedTimeIsValid(widget.time, widget.allowEmpty);
    _controller = TextEditingController();
    _focusNode = FocusNode(debugLabel: widget.label)
      ..addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_focusNode.hasFocus) {
      _syncVisibleValue();
    }
    _reportValidityAfterBuild();
  }

  @override
  void didUpdateWidget(covariant DesktopTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final timeChanged = oldWidget.time != widget.time;
    final timeZoneChanged = oldWidget.timeZone != widget.timeZone;
    final policyChanged = oldWidget.allowEmpty != widget.allowEmpty;
    final availabilityChanged = oldWidget.enabled != widget.enabled;
    final validityCallbackAdded =
        oldWidget.onValidityChanged == null && widget.onValidityChanged != null;
    if (validityCallbackAdded) {
      _reportedValidity = null;
    }
    if (!timeChanged &&
        !timeZoneChanged &&
        !policyChanged &&
        !availabilityChanged &&
        !validityCallbackAdded) {
      return;
    }
    if (!timeChanged &&
        !timeZoneChanged &&
        !policyChanged &&
        !availabilityChanged) {
      _reportValidityAfterBuild();
      return;
    }
    if (timeZoneChanged &&
        !timeChanged &&
        !policyChanged &&
        !availabilityChanged) {
      if (!_focusNode.hasFocus && _inputValid) {
        _syncVisibleValue();
      }
      _reportValidityAfterBuild();
      return;
    }

    final acceptedLocalEmission =
        timeChanged &&
        !availabilityChanged &&
        _hasPendingEmission &&
        widget.time == _pendingEmission;
    _hasPendingEmission = false;
    _pendingEmission = null;

    if (!acceptedLocalEmission || availabilityChanged) {
      _inputValid = _storedTimeIsValid(widget.time, widget.allowEmpty);
      _syncVisibleValue();
      _reportValidityAfterBuild();
    } else if (!_focusNode.hasFocus) {
      _syncVisibleValue();
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BusyMaxCalendarValueRow(
      label: widget.label,
      entry: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.datetime,
        textInputAction: TextInputAction.done,
        decoration: busyMaxGroupedTextFieldDecoration(
          context,
          labelText: widget.label,
          errorText: _inputValid
              ? null
              : MaterialLocalizations.of(context).invalidTimeLabel,
        ),
        onChanged: _handleTextChanged,
        onFieldSubmitted: (_) => _normalizeOrRestore(),
      ),
      trailingIcons: [
        Builder(
          builder: (buttonContext) => YaruIconButton(
            tooltip: widget.label,
            onPressed: widget.enabled
                ? () => _pickNativeTime(context, buttonContext)
                : null,
            icon: const Icon(YaruIcons.clock),
          ),
        ),
      ],
      enabled: widget.enabled,
    );
  }

  Future<void> _pickNativeTime(
    BuildContext context,
    BuildContext anchorContext,
  ) async {
    if (!widget.enabled) {
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    if (widget.useNativePicker) {
      final picked = await _nativeDateTimePicker.pickTime(
        title: widget.label,
        initialTime: widget.time,
        cancelLabel: localizations.cancelButtonLabel,
        okLabel: localizations.okButtonLabel,
      );
      if (!context.mounted) {
        return;
      }
      if (picked.time != null) {
        _emitTime(picked.time!);
        _focusNode.requestFocus();
        return;
      }
      if (picked.available) {
        return;
      }
    }

    final picked = await showBusyMaxTimeValueDialog(
      context,
      label: widget.label,
      initialTime: widget.time,
      allowEmpty: widget.allowEmpty,
      initialTimeZone: widget.timeZone,
      onTimeChanged: _emitTime,
      onTimeZoneChanged: widget.onTimeZoneChanged,
      anchorContext: anchorContext,
    );
    if (!context.mounted) {
      return;
    }
    if (picked != null) {
      _emitTime(picked);
      _focusNode.requestFocus();
    }
  }

  void _handleTextChanged(String input) {
    if (_syncingText) {
      return;
    }
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      _setInputValidity(widget.allowEmpty);
      if (widget.allowEmpty) {
        _emitTime(null);
      }
      return;
    }
    final parsed = parseDesktopTimeInput(context, trimmed);
    if (parsed == null) {
      _setInputValidity(false);
      return;
    }
    _setInputValidity(true);
    _emitTime(encodeTimeOfDay(parsed));
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_inputValid) {
        _syncVisibleValue(includeTimeZone: false);
      }
      return;
    }
    if (_restoreRejectedPendingEmission()) {
      return;
    }
    _normalizeOrRestore();
  }

  void _normalizeOrRestore() {
    final input = _controller.text.trim();
    if (input.isEmpty && widget.allowEmpty) {
      _setInputValidity(true);
      _emitTime(null);
      _syncVisibleValue();
      return;
    }
    final parsed = parseDesktopTimeInput(context, input);
    if (parsed == null) {
      _setInputValidity(false);
      return;
    }
    _setInputValidity(true);
    _emitTime(encodeTimeOfDay(parsed));
    _syncVisibleValue(time: parsed);
  }

  void _syncVisibleValue({TimeOfDay? time, bool? includeTimeZone}) {
    final parsed = time ?? parseTimeOfDay(widget.time);
    final formatted = parsed == null
        ? ''
        : _formatVisibleTime(
            parsed,
            includeTimeZone: includeTimeZone ?? !_focusNode.hasFocus,
          );
    if (_controller.text == formatted) {
      return;
    }
    _syncingText = true;
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _syncingText = false;
  }

  String _formatVisibleTime(TimeOfDay time, {required bool includeTimeZone}) {
    final formatted = formatMaterialTime(context, time);
    if (!includeTimeZone) {
      return formatted;
    }
    final timeZone = widget.timeZone;
    if (timeZone == null || timeZone.isEmpty) {
      return formatted;
    }
    final code = BusyMaxTimeZoneCatalog.location(timeZone).code;
    return '$formatted ($code)';
  }

  void _emitTime(String? value) {
    if (value == widget.time ||
        _hasPendingEmission && value == _pendingEmission) {
      return;
    }
    _hasPendingEmission = true;
    _pendingEmission = value;
    widget.onChanged(value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_hasPendingEmission ||
          _focusNode.hasFocus ||
          widget.time == _pendingEmission) {
        return;
      }
      _restoreRejectedPendingEmission();
    });
  }

  bool _restoreRejectedPendingEmission() {
    if (!_hasPendingEmission || widget.time == _pendingEmission) {
      return false;
    }
    _hasPendingEmission = false;
    _pendingEmission = null;
    _inputValid = _storedTimeIsValid(widget.time, widget.allowEmpty);
    _syncVisibleValue();
    _reportValidity(_inputValid);
    setState(() {});
    return true;
  }

  void _setInputValidity(bool valid) {
    if (_inputValid != valid) {
      setState(() {
        _inputValid = valid;
      });
    }
    _reportValidity(valid);
  }

  void _reportValidityAfterBuild() {
    final validity = _inputValid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputValid == validity) {
        _reportValidity(validity);
      }
    });
  }

  void _reportValidity(bool valid) {
    if (_reportedValidity == valid) {
      return;
    }
    _reportedValidity = valid;
    widget.onValidityChanged?.call(valid);
  }
}

class _DesktopTimeValueDialog extends StatefulWidget {
  const _DesktopTimeValueDialog({
    required this.label,
    required this.initialTime,
    required this.initialTimeZone,
    required this.allowEmpty,
    required this.onTimeChanged,
    required this.onTimeZoneChanged,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  final String label;
  final String? initialTime;
  final String? initialTimeZone;
  final bool allowEmpty;
  final ValueChanged<String?>? onTimeChanged;
  final ValueChanged<String>? onTimeZoneChanged;
  final BusyMaxPopoverArrowSide arrowSide;
  final double arrowAlignment;

  @override
  State<_DesktopTimeValueDialog> createState() =>
      _DesktopTimeValueDialogState();
}

class _DesktopTimeValueDialogState extends State<_DesktopTimeValueDialog> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  bool _syncingText = false;
  bool _inputValid = true;
  late String _selectedTimeZone;

  @override
  void initState() {
    super.initState();
    _hourController = TextEditingController();
    _minuteController = TextEditingController();
    _inputValid =
        widget.allowEmpty || parseTimeOfDay(widget.initialTime) != null;
    _selectedTimeZone = widget.initialTimeZone ?? localIanaTimeZone();
    _syncVisibleValue();
  }

  @override
  void didUpdateWidget(covariant _DesktopTimeValueDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _syncVisibleValue();
    }
    if (oldWidget.initialTimeZone != widget.initialTimeZone &&
        widget.initialTimeZone != null) {
      _selectedTimeZone = widget.initialTimeZone!;
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final timeInputColumnWidth = _calculateTimeInputColumnWidth(
          constraints,
        );
        return BusyMaxContentPopoverSurface(
          arrowSide: widget.arrowSide,
          arrowAlignment: widget.arrowAlignment,
          padding: _timePickerPopoverPadding,
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: timeInputColumnWidth,
                        maxWidth: timeInputColumnWidth,
                      ),
                      child: _timeInputSection(
                        context: context,
                        buttonWidth: timeInputColumnWidth,
                        controller: _hourController,
                        label: 'Hour',
                        onIncrement: () => _changeHour(1),
                        onDecrement: () => _changeHour(-1),
                      ),
                    ),
                    const SizedBox(width: BusyMaxSpacing.xs),
                    SizedBox(
                      width: BusyMaxSpacing.sm,
                      child: Center(
                        child: Text(
                          ':',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: BusyMaxSpacing.xs),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: timeInputColumnWidth,
                        maxWidth: timeInputColumnWidth,
                      ),
                      child: _timeInputSection(
                        context: context,
                        buttonWidth: timeInputColumnWidth,
                        controller: _minuteController,
                        label: 'Minute',
                        onIncrement: () => _changeMinute(1),
                        onDecrement: () => _changeMinute(-1),
                      ),
                    ),
                  ],
                ),
                if (!_inputValid)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BusyMaxSpacing.md,
                      vertical: BusyMaxSpacing.sm,
                    ),
                    child: Text(
                      MaterialLocalizations.of(context).invalidTimeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: BusyMaxSpacing.md),
                BusyMaxPushButton.standard(
                  onPressed: _openTimezoneDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.public,
                        size: BusyMaxSizes.popoverActionIcon,
                      ),
                      const SizedBox(width: BusyMaxSpacing.xs),
                      Flexible(
                        child: Text(
                          _timezoneDisplayLabel(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateTimeInputColumnWidth(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
      return _timePickerInputColumnMaxWidth;
    }
    final dividerAndSpacing = BusyMaxSpacing.md + (BusyMaxSpacing.xs * 2);
    final availablePerColumn = (constraints.maxWidth - dividerAndSpacing) / 2;
    return availablePerColumn.clamp(
      _timePickerInputColumnMinWidth,
      _timePickerInputColumnMaxWidth,
    );
  }

  Future<void> _openTimezoneDialog() async {
    final selected = await showBusyMaxTimeZoneSelectionDialog(
      context,
      selectedTimeZone: _selectedTimeZone,
    );
    if (!mounted || selected == null || selected == _selectedTimeZone) {
      return;
    }
    setState(() => _selectedTimeZone = selected);
    widget.onTimeZoneChanged?.call(selected);
  }

  String _timezoneDisplayLabel(BuildContext context) {
    return BusyMaxTimeZoneCatalog.location(_selectedTimeZone).displayLabel;
  }

  Widget _timeInputSection({
    required BuildContext context,
    required double buttonWidth,
    required TextEditingController controller,
    required String label,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final controlFill = Color.alphaBlend(
      surfaceColors.control,
      surfaceColors.popover,
    );
    final borderColor = surfaceColors.border;
    final inputTextStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal, height: 1);

    return FocusTraversalOrder(
      order: const NumericFocusOrder(0),
      child: Container(
        decoration: BoxDecoration(
          color: controlFill,
          borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BusyMaxHeaderIconButton(
              onPressed: onIncrement,
              icon: const Icon(Icons.add),
              tooltip: label,
              iconSize: BusyMaxSizes.popoverActionIcon,
              fixedSize: Size(buttonWidth, _timePickerInputControlSize),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: busyMaxSubtleButtonBackground(context),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(BusyMaxRadius.sm),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            SizedBox(
              height: _timePickerInputControlSize,
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.number,
                expands: true,
                minLines: null,
                maxLines: null,
                maxLength: 2,
                style: inputTextStyle,
                decoration:
                    busyMaxGroupedTextFieldDecoration(
                      context,
                      labelText: '',
                    ).copyWith(
                      isDense: true,
                      filled: true,
                      fillColor: controlFill,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      labelText: '',
                    ),
                buildCounter:
                    (
                      BuildContext context, {
                      required int currentLength,
                      required int? maxLength,
                      required bool isFocused,
                    }) => const SizedBox.shrink(),
                onChanged: (_) => _handleTimeInputChanged(),
                onFieldSubmitted: (_) => _handleTimeInputChanged(),
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            BusyMaxHeaderIconButton(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove),
              tooltip: label,
              iconSize: BusyMaxSizes.popoverActionIcon,
              fixedSize: Size(buttonWidth, _timePickerInputControlSize),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: busyMaxSubtleButtonBackground(context),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(BusyMaxRadius.sm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTimeInputChanged() {
    if (_syncingText) {
      return;
    }
    final parsed = _currentSelection();
    final bothBlank =
        _hourController.text.trim().isEmpty &&
        _minuteController.text.trim().isEmpty;
    if (bothBlank) {
      _setInputValidity(widget.allowEmpty);
      if (widget.allowEmpty) {
        widget.onTimeChanged?.call(null);
      }
      return;
    }
    _setInputValidity(parsed != null);
    if (parsed != null) {
      widget.onTimeChanged?.call(encodeTimeOfDay(parsed));
    }
  }

  void _changeHour(int delta) {
    final next = _normalizeHour(_hourController.text, 0) + delta;
    final value = next % 24;
    _setComponent(_hourController, value < 0 ? value + 24 : value);
  }

  void _changeMinute(int delta) {
    final next = _normalizeMinute(_minuteController.text, 0) + delta;
    final value = next % 60;
    _setComponent(_minuteController, value < 0 ? value + 60 : value);
    _handleTimeInputChanged();
  }

  int _normalizeHour(String input, int fallback) {
    final parsed = int.tryParse(input.trim());
    if (parsed == null || parsed < 0 || parsed > 23) {
      return fallback;
    }
    return parsed;
  }

  int _normalizeMinute(String input, int fallback) {
    final parsed = int.tryParse(input.trim());
    if (parsed == null || parsed < 0 || parsed > 59) {
      return fallback;
    }
    return parsed;
  }

  void _setComponent(TextEditingController controller, int value) {
    _syncingText = true;
    _ensureTwoDigits(controller, value);
    _syncingText = false;
    _handleTimeInputChanged();
  }

  void _ensureTwoDigits(TextEditingController controller, int value) {
    final valueText = value.toString().padLeft(2, '0');
    if (controller.text == valueText) {
      return;
    }
    controller.value = TextEditingValue(
      text: valueText,
      selection: TextSelection.collapsed(offset: valueText.length),
    );
  }

  TimeOfDay? _currentSelection() {
    final hour = _normalizeHour(_hourController.text, -1);
    final minute = _normalizeMinute(_minuteController.text, -1);
    if (hour < 0 || minute < 0) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _syncVisibleValue() {
    final initial = parseTimeOfDay(widget.initialTime);
    _syncingText = true;
    if (initial == null) {
      _hourController.text = '';
      _minuteController.text = '';
    } else {
      _hourController.text = initial.hour.toString().padLeft(2, '0');
      _minuteController.text = initial.minute.toString().padLeft(2, '0');
    }
    _syncingText = false;
  }

  void _setInputValidity(bool valid) {
    if (_inputValid == valid) {
      return;
    }
    setState(() {
      _inputValid = valid;
    });
  }
}

String formatDesktopDateTime(BuildContext context, String? dateTime) {
  final parsed = parseGraphLocalDateTime(dateTime);
  if (parsed == null) {
    return '';
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.yMMMd(locale).format(parsed);
  final time = formatMaterialTime(context, TimeOfDay.fromDateTime(parsed));

  return context.l10n.dateTimeDisplay(date, time);
}

String formatMaterialTime(BuildContext context, TimeOfDay time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

String formatDesktopDate(BuildContext context, String? date) {
  final parsed = parseDateOnly(date);
  if (parsed == null) {
    return '';
  }
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(parsed);
}

@visibleForTesting
TimeOfDay? parseDesktopTimeInput(BuildContext context, String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (_providerTimePattern.hasMatch(trimmed)) {
    return parseTimeOfDay(trimmed);
  }

  final normalized = trimmed
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  final locale = Localizations.localeOf(context).toLanguageTag();
  for (final candidate in {trimmed, normalized}) {
    for (final format in [
      DateFormat.Hm(locale),
      DateFormat.jm(locale),
      DateFormat('H:mm', locale),
      DateFormat('h:mm a', locale),
    ]) {
      try {
        final parsed = format.parseStrict(candidate);
        return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      } on FormatException {
        // Try the other native locale representation.
      }
    }
  }
  return null;
}

DateTime? parseDateOnly(String? date) {
  if (date == null || date.length < 10) {
    return null;
  }
  return DateTime.tryParse('${date.substring(0, 10)}T00:00:00');
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime? parseGraphLocalDateTime(String? dateTime) {
  if (dateTime == null || dateTime.isEmpty) {
    return null;
  }
  final normalized = dateTime.length >= 16
      ? dateTime.substring(0, 16)
      : dateTime;
  return DateTime.tryParse(normalized);
}

TimeOfDay? parseTimeOfDay(String? time) {
  if (time == null) {
    return null;
  }
  final match = _providerTimePattern.firstMatch(time);
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

final _providerTimePattern = RegExp(r'^(\d{2}):(\d{2})$');

bool _storedTimeIsValid(String? time, bool allowEmpty) {
  return time == null ? allowEmpty : parseTimeOfDay(time) != null;
}

String encodeDateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String encodeGraphLocalDateTime(DateTime dateTime) {
  return '${encodeDateOnly(dateTime)}T'
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}:00';
}

String encodeTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

bool isSameDate(DateTime? first, DateTime? second) {
  return first != null &&
      second != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

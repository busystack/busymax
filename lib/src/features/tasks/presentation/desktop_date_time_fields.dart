import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_glyphs.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:busymax/src/core/time/local_time_zone.dart';
import 'package:busymax/src/core/time/time_zone_catalog.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:busymax/src/l10n/localized_formatters.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/features/schedule/presentation/mini_calendar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_anchored_popover.dart';
import 'package:busymax/src/features/tasks/presentation/time_zone_selection_dialog.dart';
import 'package:yaru/yaru.dart';

@visibleForTesting
const nativeDateTimePickerChannelName = 'busymax/native_date_time_picker';

const _nativeDateTimePicker = NativeDateTimePicker();
const _dateTimePickerMaxWidth = 340.0;
const _dateTimePickerContentMaxHeight = 320.0;
const _dateTimePickerMinimumFittedContentHeight = 180.0;
const _dateTimePickerPopoverMinimumHeight = 300.0;
const _dateTimePickerPopoverPadding = EdgeInsets.all(BusyMaxSpacing.lg);
const _timePickerMaxWidth = 260.0;
const _timePickerMinimumWidth = 240.0;
const _timePickerPopoverMinimumHeight = 220.0;
const _timePickerPopoverPadding = EdgeInsets.all(BusyMaxSpacing.md);
const _timePickerInputControlSize = BusyMaxSizes.popoverActionButton;
const _timePickerInputColumnWidth = BusyMaxSizes.popoverActionButton;
const _timePickerEditableCursorWidth = 2.0;
// RenderEditable reserves this gap plus cursorWidth after a single line.
const _timePickerEditableCursorGap = 1.0;
const _timePickerEditableLeadingInset =
    _timePickerEditableCursorWidth + _timePickerEditableCursorGap;

class NativeDateTimePicker {
  const NativeDateTimePicker();

  static const _channel = MethodChannel(nativeDateTimePickerChannelName);

  Future<NativeTimePickResult> pickTime({
    required String title,
    required String? initialTime,
    required String cancelLabel,
    required String okLabel,
    required BusyMaxTimeFormatter clock,
    required String hourLabel,
    required String minuteLabel,
    required String periodLabel,
    required String invalidTimeLabel,
  }) async {
    return _invoke('pickTime', {
      'title': title,
      'initialTime': initialTime,
      'cancelLabel': cancelLabel,
      'okLabel': okLabel,
      'use24Hour': clock.use24Hour,
      'hourLabel': hourLabel,
      'minuteLabel': minuteLabel,
      'periodLabel': periodLabel,
      'invalidTimeLabel': invalidTimeLabel,
      'amLabel': clock.periodLabel(false),
      'pmLabel': clock.periodLabel(true),
    });
  }

  Future<NativeTimePickResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final value = await _channel.invokeMethod<String>(method, arguments);
      return NativeTimePickResult(available: true, time: value);
    } on MissingPluginException {
      return const NativeTimePickResult(available: false);
    }
  }
}

class NativeTimePickResult {
  const NativeTimePickResult({required this.available, this.time});

  final bool available;
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
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;

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
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return DesktopDateField(
      label: label,
      date: date,
      onChanged: onChanged,
      enabled: enabled,
      onClear: onClear,
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
          onTap: widget.enabled ? () => _pickDate(context, fieldContext) : null,
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
                ? () => _pickDate(context, buttonContext)
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

  Future<void> _pickDate(
    BuildContext context,
    BuildContext anchorContext,
  ) async {
    if (!widget.enabled) {
      return;
    }
    final picked = await showBusyMaxDateValueDialog(
      context,
      label: widget.label,
      initialDate: widget.date,
      anchorContext: anchorContext,
    );
    if (mounted && picked != null) {
      _applyPickedDate(picked);
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
    minimumWidth: _dateTimePickerMaxWidth,
    preferredMinimumHeight: _dateTimePickerPopoverMinimumHeight,
    builder: (context, arrowSide, arrowAlignment) => _DesktopDateValueDialog(
      label: label,
      initialDate: initialDate,
      arrowSide: arrowSide,
      arrowAlignment: arrowAlignment,
    ),
  );
}

double _timePopoverWidth(BuildContext context) {
  final clock = BusyMaxTimeFormatScope.of(context);
  var width = MediaQuery.textScalerOf(context).scale(_timePickerMaxWidth);
  // Reserve both periods even when opened in 24-hour mode: an open popover
  // can change format without replacing its route or losing its current edit.
  var periodWidth = 0.0;
  for (final pm in [false, true]) {
    final painter = TextPainter(
      text: TextSpan(
        text: clock.periodLabel(pm),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    if (painter.width > periodWidth) periodWidth = painter.width;
    painter.dispose();
  }
  final requiredWidth =
      MediaQuery.textScalerOf(context).scale(2 * _timePickerInputColumnWidth) +
      periodWidth +
      100;
  return width > requiredWidth ? width : requiredWidth.ceilToDouble();
}

Future<String?> showBusyMaxTimeValueDialog(
  BuildContext context, {
  required String label,
  required String? initialTime,
  required bool allowEmpty,
  String? initialTimeZone,
  ValueChanged<String?>? onTimeChanged,
  ValueChanged<bool>? onValidityChanged,
  String? Function()? readTime,
  ValueChanged<String>? onTimeZoneChanged,
  BuildContext? anchorContext,
}) {
  return showScheduleAnchoredPopover<String>(
    context: context,
    anchorContext: anchorContext ?? context,
    semanticLabel: label,
    preferredWidth: _timePopoverWidth(context),
    minimumWidth: _timePickerMinimumWidth,
    preferredMinimumHeight: _timePickerPopoverMinimumHeight,
    builder: (context, arrowSide, arrowAlignment) => _DesktopTimeValueDialog(
      label: label,
      initialTime: initialTime,
      initialTimeZone: initialTimeZone,
      allowEmpty: allowEmpty,
      onTimeChanged: onTimeChanged,
      onValidityChanged: onValidityChanged,
      readTime: readTime,
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
  // Match the date-only domain accepted by the prior GTK path.
  static final _firstDate = DateTime(1);
  static final _lastDate = DateTime(9999, 12, 31);
  late DateTime _selected;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _selected = _supportedInitialDate(widget.initialDate);
    _displayedMonth = DateTime(_selected.year, _selected.month);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentHeight = _calculateDateTimePickerPopupHeight(constraints);
        Widget calendarGrid({bool shrinkToFitHeight = false}) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BusyMaxSpacing.headerInset,
              BusyMaxSpacing.headerInset,
              BusyMaxSpacing.headerInset,
              BusyMaxSpacing.md,
            ),
            child: MiniCalendarGrid(
              displayedMonth: _displayedMonth,
              selectedDate: _selected,
              firstWeekday: _firstWeekday(context),
              shrinkToFitHeight: shrinkToFitHeight,
              onDaySelected: (date) => _setSelectedDate(
                date,
                submit:
                    date.year == _displayedMonth.year &&
                    date.month == _displayedMonth.month,
              ),
            ),
          );
        }

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildDateModeHeader(context), calendarGrid()],
        );
        final Widget pickerContent;
        if (contentHeight >= _dateTimePickerContentMaxHeight) {
          pickerContent = content;
        } else if (contentHeight >= _dateTimePickerMinimumFittedContentHeight) {
          pickerContent = SizedBox(
            height: contentHeight,
            child: Column(
              children: [
                _buildDateModeHeader(context),
                Expanded(child: calendarGrid(shrinkToFitHeight: true)),
              ],
            ),
          );
        } else {
          pickerContent = ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: contentHeight),
              child: SingleChildScrollView(child: content),
            ),
          );
        }
        return BusyMaxContentPopoverSurface(
          arrowSide: widget.arrowSide,
          arrowAlignment: widget.arrowAlignment,
          padding: _dateTimePickerPopoverPadding,
          child: pickerContent,
        );
      },
    );
  }

  void _setSelectedDate(DateTime value, {bool submit = false}) {
    final adjusted = _coerceSupportedRange(value);
    setState(() {
      _selected = adjusted;
      _displayedMonth = DateTime(adjusted.year, adjusted.month);
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
    final monthLabel = localizedMonthHeading(locale, _displayedMonth);
    final colorScheme = Theme.of(context).colorScheme;
    final direction = Directionality.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.headerInset,
        BusyMaxSpacing.sm,
      ),
      child: Row(
        children: [
          _stepButton(
            context,
            colorScheme: colorScheme,
            tooltip: context.l10n.previousMonth,
            icon: BusyMaxGlyphs.startFor(direction),
            onPressed: () => _showMonth(
              DateTime(_displayedMonth.year, _displayedMonth.month - 1),
            ),
          ),
          Expanded(
            flex: BusyMaxCalendarHeaderLayout.monthControlFlex,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _stepLabel(context, monthLabel, null),
            ),
          ),
          _stepButton(
            context,
            colorScheme: colorScheme,
            tooltip: context.l10n.nextMonth,
            icon: BusyMaxGlyphs.endFor(direction),
            onPressed: () => _showMonth(
              DateTime(_displayedMonth.year, _displayedMonth.month + 1),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          _stepButton(
            context,
            colorScheme: colorScheme,
            tooltip: context.l10n.previousYear,
            icon: BusyMaxGlyphs.startFor(direction),
            onPressed: () => _showMonth(
              DateTime(_displayedMonth.year - 1, _displayedMonth.month),
            ),
          ),
          Expanded(
            flex: BusyMaxCalendarHeaderLayout.yearControlFlex,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _stepLabel(context, '${_displayedMonth.year}', null),
            ),
          ),
          _stepButton(
            context,
            colorScheme: colorScheme,
            tooltip: context.l10n.nextYear,
            icon: BusyMaxGlyphs.endFor(direction),
            onPressed: () => _showMonth(
              DateTime(_displayedMonth.year + 1, _displayedMonth.month),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonth(DateTime value) {
    final firstMonth = DateTime(_firstDate.year, _firstDate.month);
    final lastMonth = DateTime(_lastDate.year, _lastDate.month);
    final month = DateTime(value.year, value.month);
    final adjusted = month.isBefore(firstMonth)
        ? firstMonth
        : month.isAfter(lastMonth)
        ? lastMonth
        : month;
    setState(() => _displayedMonth = adjusted);
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
    return BusyMaxWeekPreferencesScope.firstWeekdayOf(context);
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
  String? _editingLocale;

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
    BusyMaxTimeFormatScope.of(context);
    if (!_focusNode.hasFocus && _inputValid) {
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
        clock: BusyMaxTimeFormatScope.of(context),
        hourLabel: localizations.timePickerHourLabel,
        minuteLabel: localizations.timePickerMinuteLabel,
        periodLabel: context.l10n.timePeriod,
        invalidTimeLabel: localizations.invalidTimeLabel,
        title: widget.label,
        initialTime: widget.time,
        cancelLabel: localizations.cancelButtonLabel,
        okLabel: localizations.okButtonLabel,
      );
      if (!context.mounted) {
        return;
      }
      if (picked.time != null) {
        if (parseTimeOfDay(picked.time) == null) {
          _setInputValidity(false);
          return;
        }
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
      onValidityChanged: _setInputValidity,
      readTime: () => widget.time,
      onTimeZoneChanged: widget.onTimeZoneChanged,
      anchorContext: anchorContext,
    );
    if (!context.mounted) {
      return;
    }
    _setInputValidity(_storedTimeIsValid(widget.time, widget.allowEmpty));
    _syncVisibleValue();
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
    final parsed = _parseInput(trimmed);
    if (parsed == null) {
      _setInputValidity(false);
      return;
    }
    _setInputValidity(true);
    _emitTime(encodeTimeOfDay(parsed));
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _editingLocale ??= BusyMaxTimeFormatScope.of(context).locale;
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
      _editingLocale = null;
      _setInputValidity(true);
      _emitTime(null);
      _syncVisibleValue();
      return;
    }
    final parsed = _parseInput(input);
    if (parsed == null) {
      _setInputValidity(false);
      return;
    }
    _setInputValidity(true);
    _emitTime(encodeTimeOfDay(parsed));
    _editingLocale = null;
    _syncVisibleValue(time: parsed);
  }

  TimeOfDay? _parseInput(String input) {
    final parsed = parseBusyMaxClockInput(
      input,
      _editingLocale ?? BusyMaxTimeFormatScope.of(context).locale,
    );
    return parsed == null
        ? null
        : TimeOfDay(hour: parsed.hour, minute: parsed.minute);
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
    if (!widget.enabled) return;
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
    required this.onValidityChanged,
    required this.readTime,
    required this.onTimeZoneChanged,
    required this.arrowSide,
    required this.arrowAlignment,
  });

  final String label;
  final String? initialTime;
  final String? initialTimeZone;
  final bool allowEmpty;
  final ValueChanged<String?>? onTimeChanged;
  final ValueChanged<bool>? onValidityChanged;
  final String? Function()? readTime;
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
  late final FocusNode _hourFocusNode;
  late final FocusNode _minuteFocusNode;
  bool _syncingText = false;
  bool _inputValid = true;
  late String _selectedTimeZone;
  TimeOfDay? _selection;
  BusyMaxTimeFormatter? _format;
  late BusyMaxTimeFormatter _desiredFormat;
  bool _isPm = false;
  String? _lastEmission;

  @override
  void initState() {
    super.initState();
    _hourController = TextEditingController();
    _minuteController = TextEditingController();
    _hourFocusNode = FocusNode(debugLabel: 'Time picker hour')
      ..addListener(_componentFocusChanged);
    _minuteFocusNode = FocusNode(debugLabel: 'Time picker minute')
      ..addListener(_componentFocusChanged);
    _inputValid =
        widget.allowEmpty || parseTimeOfDay(widget.initialTime) != null;
    _selectedTimeZone = widget.initialTimeZone ?? localIanaTimeZone();
    _selection = parseTimeOfDay(widget.initialTime);
    _lastEmission = widget.initialTime;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _desiredFormat = BusyMaxTimeFormatScope.of(context);
    if (_format == null || _inputValid) {
      _format = _desiredFormat;
      _syncVisibleValue();
    }
  }

  void _componentFocusChanged() {
    if (!_hourFocusNode.hasFocus && !_minuteFocusNode.hasFocus && _inputValid) {
      setState(() {
        _format = _desiredFormat;
        _syncVisibleValue();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DesktopTimeValueDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _selection = parseTimeOfDay(widget.initialTime);
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
    _hourFocusNode.dispose();
    _minuteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialLocalizations = MaterialLocalizations.of(context);
    final componentWidth = MediaQuery.textScalerOf(
      context,
    ).scale(_timePickerInputColumnWidth);
    return BusyMaxContentPopoverSurface(
      arrowSide: widget.arrowSide,
      arrowAlignment: widget.arrowAlignment,
      padding: _timePickerPopoverPadding,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: componentWidth,
                  child: _timeInputSection(
                    context: context,
                    buttonWidth: componentWidth,
                    controller: _hourController,
                    focusNode: _hourFocusNode,
                    label: materialLocalizations.timePickerHourLabel,
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
                SizedBox(
                  width: componentWidth,
                  child: _timeInputSection(
                    context: context,
                    buttonWidth: componentWidth,
                    controller: _minuteController,
                    focusNode: _minuteFocusNode,
                    label: materialLocalizations.timePickerMinuteLabel,
                    onIncrement: () => _changeMinute(1),
                    onDecrement: () => _changeMinute(-1),
                  ),
                ),
                if (!_format!.use24Hour) ...[
                  const SizedBox(width: BusyMaxSpacing.sm),
                  Flexible(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: BusyMaxMenuButton<bool>(
                        key: const ValueKey('time-period-selector'),
                        tooltip: context.l10n.timePeriod,
                        entries: [
                          for (final pm in [false, true])
                            BusyMaxMenuEntry(
                              value: pm,
                              label: _format!.periodLabel(pm),
                              role: BusyMaxMenuEntryRole.radio,
                              selected: pm == _isPm,
                            ),
                        ],
                        onSelected: (pm) {
                          if (pm == _isPm) return;
                          setState(() => _isPm = pm);
                          _handleTimeInputChanged();
                        },
                        triggerBuilder: (context, trigger) => trigger.anchor(
                          child: Semantics(
                            label: context.l10n.timePeriod,
                            expanded: trigger.isOpen,
                            child: BusyMaxPushButton.standard(
                              onPressed: trigger.onPressed,
                              focusNode: trigger.focusNode,
                              style: ButtonStyle(
                                textStyle: WidgetStatePropertyAll(
                                  Theme.of(context).textTheme.bodyMedium,
                                ),
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(0, _timePickerInputControlSize),
                                ),
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(
                                    horizontal: BusyMaxSpacing.sm,
                                  ),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _format!.periodLabel(_isPm),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: BusyMaxSpacing.xs),
                                  const Icon(
                                    YaruIcons.pan_down,
                                    size: BusyMaxSizes.iconSm,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
    required FocusNode focusNode,
    required String label,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final controlFill = Color.alphaBlend(
      surfaceColors.control,
      surfaceColors.popover,
    );
    final dividerColor = surfaceColors.divider;
    final inputTextStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.normal,
          height: 1,
        ) ??
        const TextStyle(fontWeight: FontWeight.normal, height: 1);

    return FocusTraversalOrder(
      order: NumericFocusOrder(identical(controller, _hourController) ? 0 : 1),
      child: Container(
        key: ValueKey(('time-input-section', label)),
        decoration: BoxDecoration(
          color: controlFill,
          borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
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
            Divider(height: 1, thickness: 1, color: dividerColor),
            SizedBox(
              key: ValueKey(('time-input', label)),
              height: _timePickerInputControlSize,
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: focusNode.requestFocus,
                  child: Center(
                    child: SizedBox(
                      width: buttonWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: _timePickerEditableLeadingInset,
                        ),
                        child: EditableText(
                          controller: controller,
                          focusNode: focusNode,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLines: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(
                                '[0-9\u0660-\u0669\u06f0-\u06f9\u0966-\u096f]',
                              ),
                            ),
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: inputTextStyle,
                          strutStyle: StrutStyle.fromTextStyle(
                            inputTextStyle,
                            forceStrutHeight: true,
                          ),
                          cursorWidth: _timePickerEditableCursorWidth,
                          cursorColor: Theme.of(context).colorScheme.primary,
                          backgroundCursorColor:
                              surfaceColors.disabledForeground,
                          selectionColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.28),
                          onChanged: (_) => _handleTimeInputChanged(),
                          onSubmitted: (_) => _handleTimeInputChanged(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: dividerColor),
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
        _selection = null;
        _emitSelection(null);
      }
      return;
    }
    _setInputValidity(parsed != null);
    if (parsed != null) {
      _selection = parsed;
      _emitSelection(encodeTimeOfDay(parsed));
    }
  }

  void _emitSelection(String? value) {
    if (value == _lastEmission) return;
    _lastEmission = value;
    widget.onTimeChanged?.call(value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.readTime == null || _lastEmission != value) return;
      final accepted = widget.readTime!();
      if (accepted == value) return;
      // Match the controlled outer field when its parent rejects a valid edit.
      _selection = parseTimeOfDay(accepted);
      _lastEmission = accepted;
      if (_inputValid) setState(_syncVisibleValue);
    });
  }

  void _changeHour(int delta) {
    final component = _normalizeHour(_hourController.text, -1);
    final currentHour = component < 0
        ? _selection?.hour ?? 0
        : _format!.use24Hour
        ? component
        : canonicalHour(component, isPm: _isPm);
    final next = (currentHour + delta) % 24;
    setState(() {
      _isPm = next >= 12;
      _ensureTwoDigits(
        _hourController,
        _format!.use24Hour ? next : twelveHourComponent(next),
      );
    });
    // An hour step must not complete or replace a partly edited minute.
    _handleTimeInputChanged();
  }

  void _changeMinute(int delta) {
    final next = _normalizeMinute(_minuteController.text, 0) + delta;
    final value = next % 60;
    _setComponent(_minuteController, value < 0 ? value + 60 : value);
  }

  int _normalizeHour(String input, int fallback) {
    final parsed = int.tryParse(normalizeTimeDigits(input.trim()));
    if (parsed == null ||
        parsed < (_format!.use24Hour ? 0 : 1) ||
        parsed > (_format!.use24Hour ? 23 : 12)) {
      return fallback;
    }
    return parsed;
  }

  int _normalizeMinute(String input, int fallback) {
    final parsed = int.tryParse(normalizeTimeDigits(input.trim()));
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
    final valueText = _format!.component(
      value,
      padded: !identical(controller, _hourController) || _format!.use24Hour,
    );
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
    return TimeOfDay(
      hour: _format!.use24Hour ? hour : canonicalHour(hour, isPm: _isPm),
      minute: minute,
    );
  }

  void _syncVisibleValue() {
    final initial = _selection;
    _syncingText = true;
    if (initial == null) {
      _hourController.text = '';
      _minuteController.text = '';
    } else {
      _isPm = initial.hour >= 12;
      _ensureTwoDigits(
        _hourController,
        _format!.use24Hour ? initial.hour : twelveHourComponent(initial.hour),
      );
      _ensureTwoDigits(_minuteController, initial.minute);
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
    widget.onValidityChanged?.call(valid);
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
  return formatClockTime(context, time);
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
  final parsed = parseBusyMaxClockInput(
    input,
    Localizations.localeOf(context).toLanguageTag(),
  );
  return parsed == null
      ? null
      : TimeOfDay(hour: parsed.hour, minute: parsed.minute);
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

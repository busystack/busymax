import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_dialogs.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:yaru/yaru.dart';

@visibleForTesting
const nativeDateTimePickerChannelName = 'busymax/native_date_time_picker';

const _nativeDateTimePicker = NativeDateTimePicker();

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

  Future<NativeDatePickResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      return NativeDatePickResult(
        available: true,
        date: await _channel.invokeMethod<String>(method, arguments),
      );
    } on MissingPluginException {
      return const NativeDatePickResult(available: false);
    }
  }
}

class NativeDatePickResult {
  const NativeDatePickResult({required this.available, this.date});

  final bool available;
  final String? date;
}

class DesktopDateField extends StatefulWidget {
  const DesktopDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onChanged,
    this.enabled = true,
    this.onClear,
    this.useNativePicker = true,
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
    this.useNativePicker = true,
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
      entry: TextFormField(
        controller: _controller,
        readOnly: true,
        showCursor: false,
        enableInteractiveSelection: false,
        enabled: widget.enabled,
        decoration: busyMaxGroupedTextFieldDecoration(
          context,
          labelText: widget.label,
        ),
        onTap: widget.enabled ? () => _pickNativeDate(context) : null,
      ),
      trailingIcons: [
        if (canClear && widget.onClear != null)
          YaruIconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: widget.enabled ? widget.onClear : null,
            icon: const Icon(YaruIcons.window_close),
          ),
        YaruIconButton(
          tooltip: widget.label,
          onPressed: widget.enabled ? () => _pickNativeDate(context) : null,
          icon: const Icon(YaruIcons.calendar),
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

  Future<void> _pickNativeDate(BuildContext context) async {
    if (!widget.enabled) {
      return;
    }
    if (!widget.useNativePicker) {
      final fallbackPicked = await showBusyMaxDateValueDialog(
        context,
        label: widget.label,
        initialDate: widget.date,
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
}) {
  return showBusyMaxModalDialog<String>(
    context,
    builder: (dialogContext) {
      return _DesktopDateValueDialog(label: label, initialDate: initialDate);
    },
  );
}

class _DesktopDateValueDialog extends StatefulWidget {
  const _DesktopDateValueDialog({
    required this.label,
    required this.initialDate,
  });

  final String label;
  final String? initialDate;

  @override
  State<_DesktopDateValueDialog> createState() =>
      _DesktopDateValueDialogState();
}

class _DesktopDateValueDialogState extends State<_DesktopDateValueDialog> {
  static final _firstDate = DateTime(1900);
  static final _lastDate = DateTime(2100, 12, 31);

  final _formKey = GlobalKey<FormState>();
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = _supportedInitialDate(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    return BusyMaxDialogShell(
      title: widget.label,
      maxWidth: 360,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          onPressed: _submit,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: InputDatePickerFormField(
            initialDate: _selected,
            firstDate: _firstDate,
            lastDate: _lastDate,
            fieldLabelText: widget.label,
            onDateSaved: (date) => _selected = date,
            onDateSubmitted: _finish,
          ),
        ),
      ],
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    form.save();
    _finish(_selected);
  }

  void _finish(DateTime selected) {
    Navigator.of(context).pop(encodeDateOnly(selected));
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

class DesktopTimeField extends StatefulWidget {
  const DesktopTimeField({
    super.key,
    required this.label,
    required this.time,
    required this.onChanged,
    this.enabled = true,
    this.allowEmpty = true,
    this.onValidityChanged,
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool allowEmpty;
  final ValueChanged<bool>? onValidityChanged;

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
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool allowEmpty;
  final ValueChanged<bool>? onValidityChanged;

  @override
  Widget build(BuildContext context) {
    return DesktopTimeField(
      label: label,
      time: time,
      onChanged: onChanged,
      enabled: enabled,
      allowEmpty: allowEmpty,
      onValidityChanged: onValidityChanged,
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
    final policyChanged = oldWidget.allowEmpty != widget.allowEmpty;
    final availabilityChanged = oldWidget.enabled != widget.enabled;
    final validityCallbackAdded =
        oldWidget.onValidityChanged == null && widget.onValidityChanged != null;
    if (validityCallbackAdded) {
      _reportedValidity = null;
    }
    if (!timeChanged &&
        !policyChanged &&
        !availabilityChanged &&
        !validityCallbackAdded) {
      return;
    }
    if (!timeChanged && !policyChanged && !availabilityChanged) {
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
      enabled: widget.enabled,
    );
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

  void _syncVisibleValue({TimeOfDay? time}) {
    final parsed = time ?? parseTimeOfDay(widget.time);
    final formatted = parsed == null ? '' : formatMaterialTime(context, parsed);
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

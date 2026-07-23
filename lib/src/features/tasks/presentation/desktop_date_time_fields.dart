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
    this.emptyLabel,
    this.useNativePicker = true,
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;
  final String? emptyLabel;
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
    this.emptyLabel,
    this.useNativePicker = true,
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;
  final String? emptyLabel;
  final bool useNativePicker;

  @override
  Widget build(BuildContext context) {
    final formatted = formatDesktopDate(context, date);
    final displayValue = formatted.isEmpty
        ? emptyLabel ?? context.l10n.noneValue
        : formatted;
    final canClear = date != null && date!.isNotEmpty && onClear != null;

    return BusyMaxCalendarValueRow(
      label: label,
      value: displayValue,
      leading: const Icon(YaruIcons.calendar),
      enabled: enabled,
      onTap: () => _pickNativeDate(context),
      trailingIcons: [
        if (canClear)
          YaruIconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            iconSize: BusyMaxSizes.iconMd,
            icon: const Icon(YaruIcons.window_close),
            onPressed: enabled ? onClear : null,
          ),
        const Icon(Icons.edit_outlined, size: BusyMaxSizes.iconMd),
        const Icon(YaruIcons.calendar, size: BusyMaxSizes.iconMd),
      ],
    );
  }

  Future<void> _pickNativeDate(BuildContext context) async {
    if (!enabled) {
      return;
    }
    if (!useNativePicker) {
      final fallbackPicked = await showBusyMaxDateValueDialog(
        context,
        label: label,
        initialDate: date,
      );
      if (context.mounted && fallbackPicked != null) {
        onChanged(fallbackPicked);
      }
      return;
    }
    final localizations = MaterialLocalizations.of(context);
    final picked = await _nativeDateTimePicker.pickDate(
      title: label,
      initialDate: date,
      cancelLabel: localizations.cancelButtonLabel,
      okLabel: localizations.okButtonLabel,
    );
    if (!context.mounted) {
      return;
    }
    if (picked.date != null) {
      onChanged(picked.date!);
      return;
    }
    if (picked.available) {
      return;
    }
    final fallbackPicked = await showBusyMaxDateValueDialog(
      context,
      label: label,
      initialDate: date,
    );
    if (context.mounted && fallbackPicked != null) {
      onChanged(fallbackPicked);
    }
  }
}

class _DesktopDateFieldState extends State<DesktopDateField> {
  late final YaruDateTimeEntryController _controller;
  var _syncingController = false;

  @override
  void initState() {
    super.initState();
    _controller = YaruDateTimeEntryController(
      dateTime: parseDateOnly(widget.date),
    );
  }

  @override
  void didUpdateWidget(covariant DesktopDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      final nextDate = parseDateOnly(widget.date);
      final currentDate = _controller.dateTime;
      if (!isSameDate(currentDate, nextDate)) {
        _syncingController = true;
        _controller.dateTime = nextDate;
        _syncingController = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateEntry = _withoutFloatingEntryLabel(
      context,
      YaruDateTimeEntry(
        controller: _controller,
        includeTime: false,
        firstDateTime: DateTime(1900),
        lastDateTime: DateTime(2100, 12, 31),
        acceptEmpty: true,
        clearIconSemanticLabel: widget.label,
        onChanged: (date) {
          if (_syncingController) {
            return;
          }
          if (date == null) {
            widget.onClear?.call();
            return;
          }
          widget.onChanged(encodeDateOnly(date));
        },
      ),
    );

    return YaruListTile.square(
      leading: const Icon(YaruIcons.calendar),
      titleText: widget.label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 190,
            child: widget.enabled
                ? dateEntry
                : Opacity(
                    opacity: 0.6,
                    child: ExcludeFocus(child: IgnorePointer(child: dateEntry)),
                  ),
          ),
          YaruIconButton(
            tooltip: widget.label,
            iconSize: 28,
            onPressed: widget.enabled ? () => _pickNativeDate(context) : null,
            icon: const Icon(YaruIcons.calendar),
          ),
        ],
      ),
      enabled: widget.enabled,
      onTap: widget.enabled ? () => _pickNativeDate(context) : null,
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
    final pickedDate = parseDateOnly(picked);
    if (!isSameDate(_controller.dateTime, pickedDate)) {
      _syncingController = true;
      _controller.dateTime = pickedDate;
      _syncingController = false;
    }
    widget.onChanged(picked);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isSameDate(_controller.dateTime, pickedDate)) {
        return;
      }
      _syncingController = true;
      _controller.dateTime = pickedDate;
      _syncingController = false;
    });
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
  late final YaruDateTimeEntryController _controller;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = parseDateOnly(widget.initialDate) ?? _today();
    _controller = YaruDateTimeEntryController(dateTime: _selected);
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
          onPressed: _selected == null ? null : _submit,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
      children: [
        _withoutFloatingEntryLabel(
          context,
          YaruDateTimeEntry(
            controller: _controller,
            includeTime: false,
            firstDateTime: DateTime(1900),
            lastDateTime: DateTime(2100, 12, 31),
            acceptEmpty: false,
            clearIconSemanticLabel: widget.label,
            onChanged: (date) {
              setState(() {
                _selected = date;
              });
            },
          ),
        ),
      ],
    );
  }

  void _submit() {
    final selected = _selected;
    if (selected == null) {
      return;
    }
    Navigator.of(context).pop(encodeDateOnly(selected));
  }
}

class DesktopTimeField extends StatefulWidget {
  const DesktopTimeField({
    super.key,
    required this.label,
    required this.time,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool enabled;

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
    this.emptyLabel,
    this.allowEmpty = true,
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? emptyLabel;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    final formatted = formatDesktopTime(context, time);
    final displayValue = formatted.isEmpty
        ? emptyLabel ?? context.l10n.noneValue
        : formatted;

    return BusyMaxCalendarValueRow(
      label: label,
      value: displayValue,
      leading: const Icon(Icons.schedule),
      enabled: enabled,
      onTap: () => _editTime(context),
      trailingIcons: const [
        Icon(Icons.edit_outlined, size: BusyMaxSizes.iconMd),
        Icon(Icons.schedule, size: BusyMaxSizes.iconMd),
      ],
    );
  }

  Future<void> _editTime(BuildContext context) async {
    if (!enabled) {
      return;
    }
    await showBusyMaxModalDialog<void>(
      context,
      builder: (dialogContext) {
        return _DesktopTimeValueDialog(
          label: label,
          time: time,
          onChanged: onChanged,
          allowEmpty: allowEmpty,
        );
      },
    );
  }
}

class _DesktopTimeValueDialog extends StatefulWidget {
  const _DesktopTimeValueDialog({
    required this.label,
    required this.time,
    required this.onChanged,
    required this.allowEmpty,
  });

  final String label;
  final String? time;
  final ValueChanged<String?> onChanged;
  final bool allowEmpty;

  @override
  State<_DesktopTimeValueDialog> createState() =>
      _DesktopTimeValueDialogState();
}

class _DesktopTimeValueDialogState extends State<_DesktopTimeValueDialog> {
  late final YaruTimeEntryController _controller;
  final _formKey = GlobalKey<FormState>();
  TimeOfDay? _selected;

  @override
  void initState() {
    super.initState();
    _selected = parseTimeOfDay(widget.time);
    _controller = YaruTimeEntryController(timeOfDay: _selected);
  }

  @override
  Widget build(BuildContext context) {
    final timeEntry = _BusyMaxTimeEntry(
      controller: _controller,
      label: widget.label,
      acceptEmpty: widget.allowEmpty,
      autofocus: true,
      onChanged: (time) {
        setState(() {
          _selected = time;
        });
      },
      onSubmitted: (_) => _submit(),
    );
    return BusyMaxDialogShell(
      title: widget.label,
      maxWidth: 360,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          onPressed: widget.allowEmpty || _selected != null ? _submit : null,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
      children: [Form(key: _formKey, child: timeEntry)],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false) ||
        (!widget.allowEmpty && _selected == null)) {
      return;
    }
    widget.onChanged(_selected == null ? null : encodeTimeOfDay(_selected!));
    Navigator.of(context).pop();
  }
}

class _DesktopTimeFieldState extends State<DesktopTimeField> {
  late final YaruTimeEntryController _controller;
  var _syncingController = false;

  @override
  void initState() {
    super.initState();
    _controller = YaruTimeEntryController(
      timeOfDay: parseTimeOfDay(widget.time),
    );
  }

  @override
  void didUpdateWidget(covariant DesktopTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.time != widget.time) {
      final nextTime = parseTimeOfDay(widget.time);
      if (_controller.timeOfDay != nextTime) {
        _syncingController = true;
        _controller.timeOfDay = nextTime;
        _syncingController = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeEntry = _BusyMaxTimeEntry(
      controller: _controller,
      label: widget.label,
      acceptEmpty: true,
      onChanged: (time) {
        if (_syncingController) {
          return;
        }
        widget.onChanged(time == null ? null : encodeTimeOfDay(time));
      },
    );
    return YaruListTile.square(
      leading: const Icon(Icons.schedule),
      titleText: widget.label,
      trailing: SizedBox(
        width: 168,
        child: widget.enabled
            ? timeEntry
            : Opacity(
                opacity: 0.6,
                child: ExcludeFocus(child: IgnorePointer(child: timeEntry)),
              ),
      ),
      enabled: widget.enabled,
    );
  }
}

class _BusyMaxTimeEntry extends StatelessWidget {
  const _BusyMaxTimeEntry({
    required this.controller,
    required this.label,
    required this.acceptEmpty,
    required this.onChanged,
    this.autofocus = false,
    this.onSubmitted,
  });

  final YaruTimeEntryController controller;
  final String label;
  final bool acceptEmpty;
  final bool autofocus;
  final ValueChanged<TimeOfDay?> onChanged;
  final ValueChanged<TimeOfDay?>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return _withoutFloatingEntryLabel(
      context,
      YaruTimeEntry(
        controller: controller,
        autofocus: autofocus,
        force24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context)
            ? true
            : null,
        acceptEmpty: acceptEmpty,
        clearIconSemanticLabel: label,
        errorFormatText: localizations.invalidTimeLabel,
        errorInvalidText: localizations.invalidTimeLabel,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
      ),
    );
  }
}

Widget _withoutFloatingEntryLabel(BuildContext context, Widget child) {
  // The date/time rows already provide the visible label through
  // YaruListTile.square, so field labels are hidden here to avoid duplicates.
  final theme = Theme.of(context);

  return Theme(
    data: theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
    ),
    child: child,
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

String formatDesktopTime(BuildContext context, String? time) {
  final parsed = parseTimeOfDay(time);
  if (parsed == null) {
    return '';
  }
  return formatMaterialTime(context, parsed);
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
  if (time == null || time.length < 5) {
    return null;
  }
  final hour = int.tryParse(time.substring(0, 2));
  final minute = int.tryParse(time.substring(3, 5));
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

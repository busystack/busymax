import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:yaru/yaru.dart';

@visibleForTesting
const nativeDateTimePickerChannelName = 'busymax/native_date_time_picker';

const _nativeDateTimePicker = NativeDateTimePicker();

class NativeDateTimePicker {
  const NativeDateTimePicker();

  static const _channel = MethodChannel(nativeDateTimePickerChannelName);

  Future<String?> pickDate({
    required String title,
    required String? initialDate,
    required String cancelLabel,
    required String okLabel,
  }) {
    return _invoke('pickDate', {
      'title': title,
      'initialDate': initialDate,
      'cancelLabel': cancelLabel,
      'okLabel': okLabel,
    });
  }

  Future<String?> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<String>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }
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
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;
  final String? emptyLabel;

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
  });

  final String label;
  final String? date;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final VoidCallback? onClear;
  final String? emptyLabel;

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
    final localizations = MaterialLocalizations.of(context);
    final picked = await _nativeDateTimePicker.pickDate(
      title: label,
      initialDate: date,
      cancelLabel: localizations.cancelButtonLabel,
      okLabel: localizations.okButtonLabel,
    );
    if (context.mounted && picked != null) {
      onChanged(picked);
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
    final dateEntry = _withoutInternalDateTimeEntryLabel(
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
                : Opacity(opacity: 0.6, child: IgnorePointer(child: dateEntry)),
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
    final localizations = MaterialLocalizations.of(context);
    final picked = await _nativeDateTimePicker.pickDate(
      title: widget.label,
      initialDate: widget.date,
      cancelLabel: localizations.cancelButtonLabel,
      okLabel: localizations.okButtonLabel,
    );
    if (context.mounted && picked != null) {
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
    await showDialog<void>(
      context: context,
      builder: (context) {
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
  final _focusNode = FocusNode();
  TimeOfDay? _selected;

  @override
  void initState() {
    super.initState();
    _selected = parseTimeOfDay(widget.time);
    _controller = YaruTimeEntryController(timeOfDay: _selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeEntry = YaruTimeEntry(
      controller: _controller,
      focusNode: _focusNode,
      force24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      acceptEmpty: widget.allowEmpty,
      clearIconSemanticLabel: widget.label,
      onChanged: _setSelectedTime,
    );
    return BusyMaxDialogShell(
      title: widget.label,
      maxWidth: 360,
      actions: [
        BusyMaxPushButton.outlined(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.filled(
          onPressed: widget.allowEmpty || _selected != null
              ? () {
                  widget.onChanged(
                    _selected == null ? null : encodeTimeOfDay(_selected!),
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
      children: [_withoutInternalDateTimeEntryLabel(context, timeEntry)],
    );
  }

  void _setSelectedTime(TimeOfDay? time) {
    setState(() {
      _selected = time;
    });
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
      final currentTime = _controller.timeOfDay;
      if (currentTime?.hour != nextTime?.hour ||
          currentTime?.minute != nextTime?.minute) {
        _syncingController = true;
        _controller.timeOfDay = nextTime;
        _syncingController = false;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeEntry = _withoutInternalDateTimeEntryLabel(
      context,
      YaruTimeEntry(
        controller: _controller,
        force24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        acceptEmpty: true,
        clearIconSemanticLabel: widget.label,
        onChanged: (time) {
          if (_syncingController) {
            return;
          }
          widget.onChanged(time == null ? null : encodeTimeOfDay(time));
        },
      ),
    );
    return YaruListTile.square(
      leading: const Icon(Icons.schedule),
      titleText: widget.label,
      trailing: SizedBox(
        width: 168,
        child: widget.enabled
            ? timeEntry
            : Opacity(opacity: 0.6, child: IgnorePointer(child: timeEntry)),
      ),
      enabled: widget.enabled,
    );
  }
}

Widget _withoutInternalDateTimeEntryLabel(BuildContext context, Widget child) {
  // YaruDateTimeEntry/YaruTimeEntry currently expose an internal label.
  // BusyMax provides the row label through YaruListTile.square, so the
  // internal field label is hidden here to avoid duplicate labels.
  final theme = Theme.of(context);
  const hiddenLabelStyle = TextStyle(
    color: Colors.transparent,
    fontSize: 0,
    height: 0,
  );

  return Theme(
    data: theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: hiddenLabelStyle,
        floatingLabelStyle: hiddenLabelStyle,
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
  if (hour == null || minute == null || hour > 23 || minute > 59) {
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

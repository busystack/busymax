import 'package:fluent_ui/fluent_ui.dart';

import '../../l10n/time_format_scope.dart';

/// Every Windows picker uses the application locale and resolved clock.
class WindowsTimePicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final clock = BusyMaxTimeFormatScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimePicker(
          selected: selected,
          hourFormat: clock.use24Hour ? HourFormat.HH : HourFormat.h,
          locale: Localizations.localeOf(context),
          header: header,
          onCancel: onCancel,
          onChanged: onChanged == null
              ? null
              : (value) {
                  // Confirmation without an edit must not dirty an editor draft.
                  if (value != selected) onChanged!(value);
                },
        ),
        if (endOfDay) Text(formatScheduleBoundary(context, 1440)),
      ],
    );
  }
}

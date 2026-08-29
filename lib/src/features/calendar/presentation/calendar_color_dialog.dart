import 'package:flutter/material.dart';

import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../providers/busy_provider.dart';

Future<CalendarColorChoice?> showCalendarColorDialog(
  BuildContext context, {
  required BusyProvider provider,
  required String? currentBackgroundColor,
  required String? currentColorId,
  required LinuxHeaderBarService headerBarService,
}) {
  return showBusyMaxModalDialog<CalendarColorChoice>(
    context,
    headerBarService: headerBarService,
    barrierDismissible: false,
    builder: (dialogContext) => _CalendarColorDialog(
      provider: provider,
      currentBackgroundColor: currentBackgroundColor,
      currentColorId: currentColorId,
    ),
  );
}

class _CalendarColorDialog extends StatefulWidget {
  const _CalendarColorDialog({
    required this.provider,
    required this.currentBackgroundColor,
    required this.currentColorId,
  });

  final BusyProvider provider;
  final String? currentBackgroundColor;
  final String? currentColorId;

  @override
  State<_CalendarColorDialog> createState() => _CalendarColorDialogState();
}

class _CalendarColorDialogState extends State<_CalendarColorDialog> {
  late final List<CalendarColorChoice> _choices;
  CalendarColorChoice? _selected;

  @override
  void initState() {
    super.initState();
    _choices = calendarColorChoices(widget.provider);
    _selected = switch (widget.provider) {
      BusyProvider.google => _findChoice(
        (choice) =>
            _sameHex(choice.backgroundColor, widget.currentBackgroundColor),
      ),
      BusyProvider.microsoft => _findChoice(
        (choice) => choice.providerValue == widget.currentColorId,
      ),
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud ||
      BusyProvider.webCal => null,
    };
  }

  CalendarColorChoice? _findChoice(
    bool Function(CalendarColorChoice choice) matches,
  ) {
    for (final choice in _choices) {
      if (matches(choice)) return choice;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BusyMaxDialogShell(
      title: context.l10n.calendarColor,
      maxWidth: 360,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(context.l10n.save),
        ),
      ],
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: BusyMaxSpacing.sm,
          runSpacing: BusyMaxSpacing.sm,
          children: [
            for (var index = 0; index < _choices.length; index += 1)
              _CalendarColorSwatch(
                choice: _choices[index],
                label: context.l10n.calendarColorOption(index + 1),
                selected: _selected == _choices[index],
                onSelected: () => setState(() => _selected = _choices[index]),
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarColorSwatch extends StatelessWidget {
  const _CalendarColorSwatch({
    required this.choice,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final CalendarColorChoice choice;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(choice.backgroundColor);
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onSelected,
          radius: 27,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: selected
                  ? Icon(Icons.check, color: checkColor, size: 20)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

Color _parseColor(String value) {
  final normalized = value.replaceFirst('#', '');
  return Color(int.parse('ff$normalized', radix: 16));
}

bool _sameHex(String first, String? second) {
  return second != null && first.toLowerCase() == second.toLowerCase();
}

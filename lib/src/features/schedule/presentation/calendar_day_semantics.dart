import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Gives every interactive calendar day one consistent desktop accessibility
/// contract, regardless of the visual calendar that renders it.
class BusyMaxCalendarDaySemantics extends StatelessWidget {
  const BusyMaxCalendarDaySemantics({
    super.key,
    required this.day,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final label = DateFormat.yMMMMEEEEd(locale).format(day);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: Tooltip(message: label, excludeFromSemantics: true, child: child),
    );
  }
}

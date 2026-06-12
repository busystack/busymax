import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/busymax_design.dart';
import '../../../schedule/schedule_item.dart';
import 'schedule_item_chip.dart';
import 'schedule_item_selection.dart';

Future<void> showScheduleMorePopover({
  required BuildContext context,
  required DateTime day,
  required List<ScheduleItem> items,
  required ScheduleItemSelectionCallback onItemSelected,
  required void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(BusyMaxSpacing.lg),
                child: Text(
                  DateFormat.yMMMMEEEEd(locale).format(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(BusyMaxSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: BusyMaxSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ScheduleItemChip(
                      item: item,
                      height: 34,
                      compact: false,
                      onTap: (context, [globalPosition]) {
                        Navigator.of(context).pop();
                        onItemSelected(context, item, globalPosition);
                      },
                      onTaskCompletionChanged: item is TaskScheduleItem
                          ? (completed) =>
                                onTaskCompletionChanged(item, completed)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

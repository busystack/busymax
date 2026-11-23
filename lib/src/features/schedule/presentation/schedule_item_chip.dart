import '../../../ui/common/schedule/schedule_item_chip.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/schedule_item_chip.dart'
    hide ScheduleItemChip;

class ScheduleItemChip extends shared.ScheduleItemChip {
  const ScheduleItemChip({
    super.key,
    required super.item,
    required super.height,
    super.width,
    super.compact = true,
    super.onTap,
    super.onTaskCompletionChanged,
  }) : super(presentation: const LinuxSchedulePresentation());
}

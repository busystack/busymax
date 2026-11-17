import '../../../ui/common/schedule/schedule_task_chip.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/schedule_task_chip.dart'
    hide ScheduleTaskChip;

class ScheduleTaskChip extends shared.ScheduleTaskChip {
  const ScheduleTaskChip({
    super.key,
    required super.item,
    required super.height,
    super.width,
    super.compact = false,
    super.onTap,
    super.onCompletionChanged,
  }) : super(presentation: const LinuxSchedulePresentation());
}

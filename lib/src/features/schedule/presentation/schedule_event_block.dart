import '../../../ui/common/schedule/schedule_event_block.dart' as shared;
import 'schedule_linux_presentation.dart';

export '../../../ui/common/schedule/schedule_event_block.dart'
    hide ScheduleEventBlock;

class ScheduleEventBlock extends shared.ScheduleEventBlock {
  const ScheduleEventBlock({
    super.key,
    required super.item,
    required super.height,
    super.width,
    super.compact = false,
    super.onTap,
  }) : super(presentation: const LinuxSchedulePresentation());
}

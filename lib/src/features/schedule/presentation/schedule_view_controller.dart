import '../../../schedule/schedule_scope.dart';
import '../../../schedule/schedule_view_mode.dart';

class ScheduleViewState {
  const ScheduleViewState({
    required this.selectedDate,
    required this.mode,
    required this.scope,
  });

  final DateTime selectedDate;
  final ScheduleViewMode mode;
  final ScheduleScope scope;

  ScheduleViewState copyWith({
    DateTime? selectedDate,
    ScheduleViewMode? mode,
    ScheduleScope? scope,
  }) {
    return ScheduleViewState(
      selectedDate: selectedDate ?? this.selectedDate,
      mode: mode ?? this.mode,
      scope: scope ?? this.scope,
    );
  }
}

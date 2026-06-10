import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ScheduleWorkspaceCommandKind {
  today,
  newEvent,
  newTask,
  openDate,
  openCalendarEvent,
  openTask,
}

class ScheduleWorkspaceCommand {
  const ScheduleWorkspaceCommand(
    this.kind,
    this.sequence, {
    this.date,
    this.accountId,
    this.sourceId,
    this.itemId,
  });

  final ScheduleWorkspaceCommandKind kind;
  final int sequence;
  final DateTime? date;
  final String? accountId;
  final String? sourceId;
  final String? itemId;
}

final scheduleWorkspaceCommandProvider =
    StateProvider<ScheduleWorkspaceCommand?>((ref) => null);

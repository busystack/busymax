import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schedule_item.dart';

enum ScheduleWorkspaceCommandKind {
  today,
  agenda,
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

  /// Full identity avoids opening a similarly named item in another account.
  bool matchesItem(ScheduleItem item) =>
      accountId == item.accountId &&
      sourceId == item.sourceId &&
      itemId == item.id &&
      switch (kind) {
        ScheduleWorkspaceCommandKind.openCalendarEvent =>
          item is CalendarScheduleItem,
        ScheduleWorkspaceCommandKind.openTask => item is TaskScheduleItem,
        _ => false,
      };
}

final scheduleWorkspaceCommandProvider =
    StateProvider<ScheduleWorkspaceCommand?>((ref) => null);

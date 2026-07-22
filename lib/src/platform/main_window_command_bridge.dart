import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_bootstrap.dart';
import '../app/app_router.dart';
import '../features/schedule/application/compact_agenda_data.dart';
import '../features/schedule/application/compact_agenda_snapshot.dart';
import '../features/sync/sync_auth_error.dart';
import '../schedule/schedule_commands.dart';
import 'main_window_command_client.dart';

Future<Map<String, Object?>> loadFreshCompactAgendaSnapshot(
  WidgetRef ref,
  Object? rawArgs,
) async {
  final query = decodeCompactAgendaQuery(rawArgs);
  final data = await ref.refresh(
    compactAgendaDataForQueryProvider(query).future,
  );
  return encodeCompactAgendaData(data);
}

class MainWindowCommandBridge extends ConsumerStatefulWidget {
  const MainWindowCommandBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainWindowCommandBridge> createState() =>
      _MainWindowCommandBridgeState();
}

class _MainWindowCommandBridgeState
    extends ConsumerState<MainWindowCommandBridge> {
  var _sequence = 0;

  @override
  void initState() {
    super.initState();
    unawaited(busyMaxMainWindowChannel.setMethodCallHandler(_handleMethodCall));
  }

  @override
  void dispose() {
    unawaited(busyMaxMainWindowChannel.setMethodCallHandler(null));
    super.dispose();
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'busymax.main.open':
        await ref.read(linuxWindowServiceProvider).showWindow();
        return true;
      case 'busymax.main.openScheduleItem':
        return _openScheduleItem(call.arguments);
      case 'busymax.main.newTask':
        return _newTask();
      case 'busymax.main.refreshAll':
        await ref.read(allAccountsSyncRunnerProvider)();
        return true;
      case 'busymax.main.compactAgendaSnapshot':
        return _compactAgendaSnapshot(call.arguments);
      case 'busymax.main.requestTaskSync':
        return _requestTaskSync(call.arguments);
      case 'busymax.main.requestCalendarSync':
        return _requestCalendarSync(call.arguments);
    }

    throw MissingPluginException('Not implemented: ${call.method}');
  }

  Future<bool> _openScheduleItem(Object? rawArgs) async {
    if (rawArgs is! Map) {
      return false;
    }
    final args = rawArgs.cast<Object?, Object?>();
    final kind = args['kind']?.toString();
    final accountId = args['accountId']?.toString();
    final sourceId = args['sourceId']?.toString();
    final itemId = args['itemId']?.toString();
    final rawDate = args['date']?.toString();
    final date = rawDate == null ? null : DateTime.tryParse(rawDate);

    if (kind == null ||
        accountId == null ||
        sourceId == null ||
        itemId == null) {
      return false;
    }

    final commandKind = switch (kind) {
      'task' => ScheduleWorkspaceCommandKind.openTask,
      'calendarEvent' => ScheduleWorkspaceCommandKind.openCalendarEvent,
      _ => null,
    };
    if (commandKind == null) {
      return false;
    }

    await ref.read(linuxWindowServiceProvider).showWindow();
    ref
        .read(scheduleWorkspaceCommandProvider.notifier)
        .state = ScheduleWorkspaceCommand(
      commandKind,
      ++_sequence,
      date: date,
      accountId: accountId,
      sourceId: sourceId,
      itemId: itemId,
    );
    ref.read(appRouterProvider).go('/schedule');
    return true;
  }

  Future<bool> _newTask() async {
    await ref.read(linuxWindowServiceProvider).showWindow();
    ref
        .read(scheduleWorkspaceCommandProvider.notifier)
        .state = ScheduleWorkspaceCommand(
      ScheduleWorkspaceCommandKind.newTask,
      ++_sequence,
    );
    ref.read(appRouterProvider).go('/schedule');
    return true;
  }

  Future<Map<String, Object?>> _compactAgendaSnapshot(Object? rawArgs) async {
    return loadFreshCompactAgendaSnapshot(ref, rawArgs);
  }

  Future<bool> _requestTaskSync(Object? rawArgs) async {
    if (rawArgs is! Map) {
      return false;
    }
    final accountId = rawArgs.cast<Object?, Object?>()['accountId']?.toString();
    if (accountId == null || accountId.isEmpty) {
      return false;
    }
    ref
        .read(pendingMutationSyncRequesterForAccountProvider(accountId))
        .request();
    unawaited(ref.read(notificationSchedulerProvider).checkNow());
    return true;
  }

  Future<bool> _requestCalendarSync(Object? rawArgs) async {
    if (rawArgs is! Map) {
      return false;
    }
    final accountId = rawArgs.cast<Object?, Object?>()['accountId']?.toString();
    if (accountId == null || accountId.isEmpty) {
      return false;
    }
    unawaited(_syncCalendarAccount(accountId));
    unawaited(ref.read(notificationSchedulerProvider).checkNow());
    return true;
  }

  Future<void> _syncCalendarAccount(String accountId) async {
    try {
      await ref
          .read(calendarSyncEngineForAccountFactoryProvider)(accountId)
          .incrementalSync();
    } on Object catch (error) {
      if (isMissingOAuthTokenError(error)) {
        try {
          await ref
              .read(authRepositoryProvider)
              .markReconnectRequired(accountId);
        } on Object {
          // Preserve the original sync failure handling below.
        }
      }
      // The local pending operation remains queued and a later refresh/sync can
      // retry it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

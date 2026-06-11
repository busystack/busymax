import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../schedule/schedule_item.dart';
import '../schedule/schedule_projection.dart';

const busyMaxMainWindowChannelName = 'io.busystack.busymax/main-window';

const busyMaxMainWindowChannel = WindowMethodChannel(
  busyMaxMainWindowChannelName,
  mode: ChannelMode.unidirectional,
);

class MainWindowCommandClient {
  const MainWindowCommandClient();

  Future<void> openMain() async {
    await busyMaxMainWindowChannel.invokeMethod<bool>('busymax.main.open');
  }

  Future<void> openScheduleItem(ScheduleItem item) async {
    final date = item.start == null
        ? ScheduleProjection.day(DateTime.now())
        : ScheduleProjection.day(item.start!);
    await busyMaxMainWindowChannel
        .invokeMethod<bool>('busymax.main.openScheduleItem', {
          'kind': item is TaskScheduleItem ? 'task' : 'calendarEvent',
          'accountId': item.accountId,
          'sourceId': item.sourceId,
          'itemId': item.id,
          'date': date.toIso8601String(),
        });
  }

  Future<void> newTask() async {
    await busyMaxMainWindowChannel.invokeMethod<bool>('busymax.main.newTask');
  }

  Future<void> refreshAll() async {
    await busyMaxMainWindowChannel.invokeMethod<bool>(
      'busymax.main.refreshAll',
    );
  }

  Future<void> requestTaskSync(String accountId) async {
    await busyMaxMainWindowChannel.invokeMethod<bool>(
      'busymax.main.requestTaskSync',
      {'accountId': accountId},
    );
  }

  Future<void> requestCalendarSync(String accountId) async {
    await busyMaxMainWindowChannel.invokeMethod<bool>(
      'busymax.main.requestCalendarSync',
      {'accountId': accountId},
    );
  }
}

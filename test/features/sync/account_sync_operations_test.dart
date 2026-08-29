import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'routes providers explicitly and never creates a WebCal task sync',
    () async {
      var provider = BusyProvider.webCal;
      final calls = <String>[];
      final operations = RoutingAccountSyncOperations(
        providerForAccount: (_) async => provider,
        syncDav: (_, {required full}) async => calls.add('dav:$full'),
        syncWebCal: (_, {required full}) async => calls.add('webcal:$full'),
        syncTasksRest: (_, {required full}) async => calls.add('tasks:$full'),
        syncCalendarRest: (_, {required full}) async =>
            calls.add('calendar:$full'),
      );

      await operations.syncAccount('account', full: false);
      await operations.syncCalendar('account', full: true);
      await operations.syncTasks('account', full: true);
      expect(calls, ['webcal:false', 'webcal:true']);

      calls.clear();
      provider = BusyProvider.nextcloud;
      await operations.syncAccount('account', full: false);
      expect(calls, ['dav:false']);

      calls.clear();
      provider = BusyProvider.google;
      await operations.syncAccount('account', full: true);
      expect(calls, ['tasks:true', 'calendar:true']);
    },
  );
}

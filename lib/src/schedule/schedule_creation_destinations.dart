import '../providers/busy_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_bootstrap.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import '../features/tasks/domain/task_capabilities.dart';

/// Creation eligibility used by defaults and every workspace creation entry.
/// A remembered destination never overrides collection permissions/deletion.
final scheduleTaskListCreateEligibleProvider = Provider.autoDispose
    .family<bool, TaskListEntity>((ref, list) {
      if (list.pendingDelete) {
        return false;
      }
      final account = ref
          .watch(accountsStreamProvider)
          .valueOrNull
          ?.where((account) => account.id == list.accountId)
          .firstOrNull;
      if (account == null || !account.isTaskCapable) {
        return false;
      }
      return account.provider.isDav
          ? ref
                    .watch(
                      davTaskCollectionCapabilitiesProvider((
                        accountId: list.accountId,
                        taskListId: list.id,
                      )),
                    )
                    .valueOrNull
                    ?.canCreateTasks ==
                true
          : adapterDefaultTaskCapabilities(account.provider).canCreateTasks;
    });

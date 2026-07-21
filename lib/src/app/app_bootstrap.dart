import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/build_config.dart';
import '../core/time/local_time_zone.dart';
import '../db/app_database.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/feedback/data/feedback_api_client.dart';
import '../features/notifications/desktop_notification_service.dart';
import '../features/notifications/notification_scheduler.dart';
import '../features/sync/all_accounts_sync_scheduler.dart';
import '../features/sync/calendar_sync_engine.dart';
import '../features/sync/pending_mutation_sync_requester.dart';
import '../features/sync/pending_op_resolution_service.dart';
import '../features/sync/sync_auth_error.dart';
import '../features/sync/sync_engine.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import '../features/tasks/data/tasks_repository.dart';
import '../google_tasks/api/google_tasks_api_client.dart';
import '../google_tasks/http/authenticated_http_client.dart';
import '../google_tasks/http/retrying_http_client.dart';
import '../google_tasks/oauth/oauth_loopback_flow.dart';
import '../google_tasks/oauth/oauth_service.dart';
import '../google_tasks/oauth/oauth_token_store.dart';
import '../google_tasks/oauth/portal_encrypted_oauth_token_store.dart';
import '../google_calendar/google_calendar_api_client.dart';
import '../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../microsoft_todo/api/microsoft_todo_api_client.dart';
import '../microsoft_todo/api/microsoft_todo_google_tasks_adapter.dart';
import '../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../platform/compact_agenda_window_service.dart';
import '../platform/linux_header_bar_service.dart';
import '../platform/linux_window_service.dart';
import '../task_providers/task_provider.dart';
import '../schedule/schedule_commands.dart';
import '../schedule/schedule_repository.dart';
import 'app_router.dart';
import 'app_settings.dart';

export '../app/app_settings.dart';

final buildConfigProvider = Provider<BuildConfig>(
  (ref) => BuildConfig.fromEnvironment(),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final baseHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final retryingHttpClientProvider = Provider<http.Client>((ref) {
  return RetryingHttpClient(inner: ref.watch(baseHttpClientProvider));
});

final feedbackSubmissionServiceProvider = Provider<FeedbackSubmissionService>((
  ref,
) {
  final config = ref.watch(buildConfigProvider);
  return FeedbackApiClient(
    httpClient: ref.watch(baseHttpClientProvider),
    endpoint: Uri.parse(config.feedbackEndpoint),
  );
});

final oAuthTokenStoreProvider = Provider<OAuthTokenStore>((ref) {
  if (Platform.isLinux && (Platform.environment['SNAP']?.isNotEmpty ?? false)) {
    // flutter_secure_storage_linux warms up direct libsecret first, so
    // SECRET_BACKEND=file cannot avoid a locked keyring inside strict snaps.
    return PortalEncryptedOAuthTokenStore();
  }
  return SecureOAuthTokenStore(ref.watch(secureStorageProvider));
});

final applicationOAuthServiceProvider = Provider<OAuthService>((ref) {
  return OAuthService(
    config: ref.watch(buildConfigProvider),
    httpClient: ref.watch(baseHttpClientProvider),
    tokenStore: ref.watch(oAuthTokenStoreProvider),
    loopbackFlow: OAuthLoopbackFlow(),
  );
});

final oAuthServiceProvider = applicationOAuthServiceProvider;

final microsoftOAuthServiceProvider = Provider<MicrosoftOAuthService>((ref) {
  return MicrosoftOAuthService(
    config: ref.watch(buildConfigProvider),
    httpClient: ref.watch(baseHttpClientProvider),
    tokenStore: ref.watch(oAuthTokenStoreProvider),
    loopbackFlow: OAuthLoopbackFlow(),
  );
});

final authenticatedHttpClientProvider = Provider<http.Client>((ref) {
  return AuthenticatedHttpClient(
    inner: ref.watch(retryingHttpClientProvider),
    oAuthService: ref.watch(applicationOAuthServiceProvider),
  );
});

final desktopNotificationBackendProvider = Provider<DesktopNotificationBackend>(
  (ref) {
    final backend = FreedesktopNotificationBackend();
    ref.onDispose(() {
      unawaited(backend.close());
    });
    return backend;
  },
);

final desktopNotificationServiceProvider = Provider<DesktopNotificationService>(
  (ref) {
    return DesktopNotificationService(
      backend: ref.watch(desktopNotificationBackendProvider),
      settings: ref.watch(appSettingsControllerProvider),
    );
  },
);

final linuxWindowServiceProvider = Provider<LinuxWindowService>(
  (ref) => const LinuxWindowService(),
);

final linuxHeaderBarServiceProvider = Provider<LinuxHeaderBarService>((ref) {
  final service = LinuxHeaderBarService();
  ref.onDispose(service.dispose);
  return service;
});

final compactAgendaWindowServiceProvider = Provider<CompactAgendaWindowService>(
  (ref) {
    return const CompactAgendaWindowService();
  },
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    oAuth: ref.watch(applicationOAuthServiceProvider),
    database: ref.watch(databaseProvider),
    accountsRepository: ref.watch(accountsRepositoryProvider),
    microsoftOAuth: ref.watch(microsoftOAuthServiceProvider),
  );
});

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(database: ref.watch(databaseProvider));
});

final accountsStreamProvider = StreamProvider<List<AccountEntity>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchAccounts();
});

final accountManagementStreamProvider = StreamProvider<List<AccountEntity>>((
  ref,
) {
  return ref.watch(accountsRepositoryProvider).watchVisibleAccounts();
});

final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

final selectedAccountProvider = Provider<AccountEntity?>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
  final selectedId = ref.watch(selectedAccountIdProvider);
  if (selectedId != null) {
    for (final account in accounts) {
      if (account.id == selectedId) {
        return account;
      }
    }
  }
  if (accounts.isNotEmpty) {
    return accounts.first;
  }
  return null;
});

final selectedAccountCapabilitiesProvider = Provider<TaskProviderCapabilities>((
  ref,
) {
  final account = ref.watch(selectedAccountProvider);
  return capabilitiesForProvider(account?.provider ?? TaskProvider.google);
});

final localTimeZoneProvider = Provider<String>((ref) => localIanaTimeZone());

final googleTasksApiClientForAccountProvider =
    Provider.family<GoogleTasksApiClient, String>((ref, accountId) {
      final config = ref.watch(buildConfigProvider);
      return GoogleTasksRestApiClient(
        httpClient: ref.watch(retryingHttpClientProvider),
        baseUri: Uri.parse(config.googleApiBaseUrl),
        authorizationHeaderProvider: () => ref
            .read(applicationOAuthServiceProvider)
            .authorizationHeaderForAccount(accountId),
        unauthorizedRefreshProvider: () => ref
            .read(applicationOAuthServiceProvider)
            .refreshTokenForAccount(accountId),
      );
    });

final googleCalendarApiClientForAccountProvider =
    Provider.family<GoogleCalendarApiClient, String>((ref, accountId) {
      final config = ref.watch(buildConfigProvider);
      return GoogleCalendarApiClient(
        httpClient: ref.watch(retryingHttpClientProvider),
        baseUri: Uri.parse(config.googleApiBaseUrl),
        authorizationHeaderProvider: () => ref
            .read(applicationOAuthServiceProvider)
            .authorizationHeaderForAccount(accountId),
        unauthorizedRefreshProvider: () => ref
            .read(applicationOAuthServiceProvider)
            .refreshTokenForAccount(accountId),
      );
    });

final microsoftTodoApiClientForAccountProvider =
    Provider.family<MicrosoftTodoApiClient, String>((ref, accountId) {
      final config = ref.watch(buildConfigProvider);
      return MicrosoftTodoRestApiClient(
        httpClient: ref.watch(retryingHttpClientProvider),
        baseUri: Uri.parse(config.microsoftGraphBaseUrl),
        authorizationHeaderProvider: () => ref
            .read(microsoftOAuthServiceProvider)
            .authorizationHeaderForAccount(accountId),
        unauthorizedRefreshProvider: () => ref
            .read(microsoftOAuthServiceProvider)
            .refreshTokenForAccount(accountId),
      );
    });

final microsoftCalendarApiClientForAccountProvider =
    Provider.family<MicrosoftCalendarApiClient, String>((ref, accountId) {
      final config = ref.watch(buildConfigProvider);
      return MicrosoftCalendarApiClient(
        httpClient: ref.watch(retryingHttpClientProvider),
        baseUri: Uri.parse(config.microsoftGraphBaseUrl),
        responseTimeZone: ref.watch(localTimeZoneProvider),
        authorizationHeaderProvider: () => ref
            .read(microsoftOAuthServiceProvider)
            .authorizationHeaderForAccount(accountId),
        unauthorizedRefreshProvider: () => ref
            .read(microsoftOAuthServiceProvider)
            .refreshTokenForAccount(accountId),
      );
    });

final microsoftAsGoogleTasksApiClientForAccountProvider =
    Provider.family<GoogleTasksApiClient, String>((ref, accountId) {
      return MicrosoftTodoGoogleTasksAdapter(
        client: ref.watch(microsoftTodoApiClientForAccountProvider(accountId)),
        defaultTimeZone: ref.watch(localTimeZoneProvider),
      );
    });

typedef SyncEngineForAccountFactory = SyncEngine Function(String accountId);

final syncEngineForAccountFactoryProvider =
    Provider<SyncEngineForAccountFactory>((ref) {
      return (accountId) {
        final apiClient = accountId.startsWith('microsoft:')
            ? ref.read(
                microsoftAsGoogleTasksApiClientForAccountProvider(accountId),
              )
            : ref.read(googleTasksApiClientForAccountProvider(accountId));

        return SyncEngine(
          database: ref.read(databaseProvider),
          apiClient: apiClient,
          accountId: accountId,
          fullRefreshOnly: accountId.startsWith('microsoft:'),
          onConflictBlocked: ref
              .read(desktopNotificationServiceProvider)
              .notifyConflict,
        );
      };
    });

typedef CalendarSyncEngineForAccountFactory =
    CalendarSyncEngine Function(String accountId);

final calendarSyncEngineForAccountFactoryProvider =
    Provider<CalendarSyncEngineForAccountFactory>((ref) {
      return (accountId) {
        final client = accountId.startsWith('microsoft:')
            ? ref.read(microsoftCalendarApiClientForAccountProvider(accountId))
            : ref.read(googleCalendarApiClientForAccountProvider(accountId));
        return CalendarSyncEngine(
          database: ref.read(databaseProvider),
          client: client,
          accountId: accountId,
          onConflictBlocked: ref
              .read(desktopNotificationServiceProvider)
              .notifyConflict,
          onNotificationScheduleChanged: () =>
              ref.read(notificationSchedulerProvider).checkNow(),
        );
      };
    });

typedef SignedInSyncRunner =
    Future<void> Function(String accountId, bool initial);

final signedInSyncRunnerProvider = Provider<SignedInSyncRunner>((ref) {
  return (accountId, initial) async {
    final syncEngine = ref.read(syncEngineForAccountFactoryProvider)(accountId);
    final calendarSyncEngine = ref.read(
      calendarSyncEngineForAccountFactoryProvider,
    )(accountId);
    try {
      if (initial) {
        await syncEngine.fullSync();
        await calendarSyncEngine.fullSync();
      } else {
        await syncEngine.incrementalSync();
        await calendarSyncEngine.incrementalSync();
      }
    } on Object catch (error) {
      await _markAccountReconnectRequiredIfMissingSyncToken(
        ref,
        accountId,
        error,
      );
      rethrow;
    }
  };
});

typedef AllAccountsSyncRunner = Future<void> Function();

final allAccountsSyncRunnerProvider = Provider<AllAccountsSyncRunner>((ref) {
  Future<void> syncAccount(String accountId) async {
    await ref
        .read(syncEngineForAccountFactoryProvider)(accountId)
        .incrementalSync();
    await ref
        .read(calendarSyncEngineForAccountFactoryProvider)(accountId)
        .incrementalSync();
  }

  return () {
    return runAllSignedInAccountSync(
      listSignedInAccounts: ref
          .read(accountsRepositoryProvider)
          .listSignedInAccounts,
      syncAccount: syncAccount,
      onSyncFailure: ref
          .read(desktopNotificationServiceProvider)
          .notifySyncFailure,
      onAccountSyncFailure: (accountId, error) =>
          _markAccountReconnectRequiredIfMissingSyncToken(
            ref,
            accountId,
            error,
          ),
    );
  };
});

final StateNotifierProvider<AuthSessionController, AuthSessionState>
authSessionControllerProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>((ref) {
      final config = ref.watch(buildConfigProvider);
      return AuthSessionController(
        repository: ref.watch(authRepositoryProvider),
        isConfigured: config.hasAnyProviderConfigured,
        onSignedIn: ref.read(signedInSyncRunnerProvider),
      );
    });

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    database: ref.watch(databaseProvider),
    localTimeZone: ref.watch(localTimeZoneProvider),
    onNotificationScheduleChanged: () =>
        ref.read(notificationSchedulerProvider).checkNow(),
  );
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(databaseProvider));
});

final Provider<String?> activeAccountProvider = Provider<String?>((ref) {
  final selectedAccount = ref.watch(selectedAccountProvider);
  if (selectedAccount != null) {
    return selectedAccount.id;
  }
  final session = ref.watch(authSessionControllerProvider);
  return session.isSignedIn ? session.accountId : null;
});

final googleTasksApiClientProvider = Provider<GoogleTasksApiClient?>((ref) {
  final accountId = ref.watch(activeAccountProvider);
  if (accountId == null) {
    return null;
  }
  final selectedAccount = ref.watch(selectedAccountProvider);
  final provider =
      selectedAccount?.provider ??
      (accountId.startsWith('microsoft:')
          ? TaskProvider.microsoft
          : TaskProvider.google);
  return switch (provider) {
    TaskProvider.microsoft => ref.watch(
      microsoftAsGoogleTasksApiClientForAccountProvider(accountId),
    ),
    TaskProvider.google => ref.watch(
      googleTasksApiClientForAccountProvider(accountId),
    ),
  };
});

final taskListsRepositoryProvider = Provider<TaskListsRepository?>((ref) {
  final accountId = ref.watch(activeAccountProvider);
  if (accountId == null) {
    return null;
  }
  return TaskListsRepository(
    database: ref.watch(databaseProvider),
    accountId: accountId,
    apiClient: ref.watch(googleTasksApiClientProvider),
    onMutationQueued: ref.watch(pendingMutationSyncRequesterProvider)?.request,
  );
});

final taskListsRepositoryForAccountProvider =
    Provider.family<TaskListsRepository, String>((ref, accountId) {
      return TaskListsRepository(
        database: ref.watch(databaseProvider),
        accountId: accountId,
      );
    });

final tasksRepositoryProvider = Provider<TasksRepository?>((ref) {
  final accountId = ref.watch(activeAccountProvider);
  if (accountId == null) {
    return null;
  }
  return TasksRepository(
    database: ref.watch(databaseProvider),
    accountId: accountId,
    apiClient: ref.watch(googleTasksApiClientProvider),
    onMutationQueued: ref.watch(pendingMutationSyncRequesterProvider)?.request,
    onNotificationScheduleChanged: () =>
        ref.read(notificationSchedulerProvider).checkNow(),
  );
});

final tasksRepositoryForAccountProvider =
    Provider.family<TasksRepository, String>((ref, accountId) {
      final apiClient = accountId.startsWith('microsoft:')
          ? ref.watch(
              microsoftAsGoogleTasksApiClientForAccountProvider(accountId),
            )
          : ref.watch(googleTasksApiClientForAccountProvider(accountId));
      return TasksRepository(
        database: ref.watch(databaseProvider),
        accountId: accountId,
        apiClient: apiClient,
        onMutationQueued: ref
            .watch(pendingMutationSyncRequesterForAccountProvider(accountId))
            .request,
        onNotificationScheduleChanged: () =>
            ref.read(notificationSchedulerProvider).checkNow(),
      );
    });

final Provider<SyncEngine?> syncEngineProvider = Provider<SyncEngine?>((ref) {
  final accountId = ref.watch(activeAccountProvider);
  final apiClient = ref.watch(googleTasksApiClientProvider);
  if (accountId == null || apiClient == null) {
    return null;
  }
  final provider =
      ref.watch(selectedAccountProvider)?.provider ??
      (accountId.startsWith('microsoft:')
          ? TaskProvider.microsoft
          : TaskProvider.google);
  return SyncEngine(
    database: ref.watch(databaseProvider),
    apiClient: apiClient,
    accountId: accountId,
    fullRefreshOnly: provider == TaskProvider.microsoft,
    onConflictBlocked: ref
        .watch(desktopNotificationServiceProvider)
        .notifyConflict,
  );
});

final pendingMutationSyncRequesterProvider =
    Provider<PendingMutationSyncRequester?>((ref) {
      final accountId = ref.watch(activeAccountProvider);
      final syncEngine = ref.watch(syncEngineProvider);
      if (accountId == null || syncEngine == null) {
        return null;
      }

      final requester = PendingMutationSyncRequester(
        sync: syncEngine.incrementalSync,
        onSyncFailure: ref
            .watch(desktopNotificationServiceProvider)
            .notifySyncFailure,
        onSyncError: (error) => _markAccountReconnectRequiredIfMissingSyncToken(
          ref,
          accountId,
          error,
        ),
      );
      ref.onDispose(requester.dispose);
      return requester;
    });

final pendingMutationSyncRequesterForAccountProvider =
    Provider.family<PendingMutationSyncRequester, String>((ref, accountId) {
      final syncEngine = ref.watch(syncEngineForAccountFactoryProvider)(
        accountId,
      );
      final requester = PendingMutationSyncRequester(
        sync: syncEngine.incrementalSync,
        onSyncFailure: ref
            .watch(desktopNotificationServiceProvider)
            .notifySyncFailure,
        onSyncError: (error) => _markAccountReconnectRequiredIfMissingSyncToken(
          ref,
          accountId,
          error,
        ),
      );
      ref.onDispose(requester.dispose);
      return requester;
    });

final pendingOpResolutionServiceProvider =
    Provider<PendingOpResolutionService?>((ref) {
      final accountId = ref.watch(activeAccountProvider);
      final apiClient = ref.watch(googleTasksApiClientProvider);
      final syncEngine = ref.watch(syncEngineProvider);
      if (accountId == null || apiClient == null || syncEngine == null) {
        return null;
      }
      return PendingOpResolutionService(
        database: ref.watch(databaseProvider),
        apiClient: apiClient,
        accountId: accountId,
        syncEngine: syncEngine,
      );
    });

final syncSchedulerProvider = Provider<AllAccountsSyncScheduler>((ref) {
  Future<void> syncAccount(String accountId) async {
    await ref
        .read(syncEngineForAccountFactoryProvider)(accountId)
        .incrementalSync();
    await ref
        .read(calendarSyncEngineForAccountFactoryProvider)(accountId)
        .incrementalSync();
  }

  final scheduler = AllAccountsSyncScheduler(
    listSignedInAccounts: ref
        .read(accountsRepositoryProvider)
        .listSignedInAccounts,
    syncAccount: syncAccount,
    onSyncFailure: ref
        .watch(desktopNotificationServiceProvider)
        .notifySyncFailure,
    onAccountSyncFailure: (accountId, error) =>
        _markAccountReconnectRequiredIfMissingSyncToken(ref, accountId, error),
  );
  scheduler.start();
  ref.onDispose(scheduler.stop);
  return scheduler;
});

Future<void> _markAccountReconnectRequiredIfMissingSyncToken(
  Ref ref,
  String accountId,
  Object error,
) async {
  if (!isMissingOAuthTokenError(error)) {
    return;
  }
  try {
    await ref.read(authRepositoryProvider).markReconnectRequired(accountId);
  } on Object {
    // Keep the original sync failure as the reported error.
  }
}

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  final scheduler = NotificationScheduler(
    database: ref.watch(databaseProvider),
    notifications: ref.watch(desktopNotificationServiceProvider),
    onNotificationActivated: (row) => _openNotificationSource(ref, row),
  );
  scheduler.start();
  ref.onDispose(scheduler.stop);
  return scheduler;
});

final _notificationOpenSequenceProvider = StateProvider<int>((ref) => 0);

Future<void> _openNotificationSource(
  Ref ref,
  NotificationScheduleData row,
) async {
  return switch (row.sourceType) {
    'event' => _openEventNotification(ref, row),
    'task' => _openTaskNotification(ref, row),
    _ => ref.read(linuxWindowServiceProvider).showWindow(),
  };
}

Future<void> _openEventNotification(
  Ref ref,
  NotificationScheduleData row,
) async {
  final database = ref.read(databaseProvider);
  final event =
      await (database.select(database.calendarEvents)..where(
            (table) =>
                table.accountId.equals(row.accountId) &
                table.id.equals(row.sourceId) &
                table.isDeleted.equals(false) &
                table.isCancelled.equals(false),
          ))
          .getSingleOrNull();
  if (event == null) {
    await ref.read(linuxWindowServiceProvider).showWindow();
    return;
  }

  await _openScheduleItemFromNotification(
    ref,
    kind: ScheduleWorkspaceCommandKind.openCalendarEvent,
    date: _calendarEventCommandDate(event),
    accountId: event.accountId,
    sourceId: event.calendarSourceId,
    itemId: event.id,
  );
}

Future<void> _openTaskNotification(
  Ref ref,
  NotificationScheduleData row,
) async {
  final database = ref.read(databaseProvider);
  final task =
      await (database.select(database.tasks)
            ..where(
              (table) =>
                  table.accountId.equals(row.accountId) &
                  table.id.equals(row.sourceId) &
                  table.pendingDelete.equals(false),
            )
            ..limit(1))
          .getSingleOrNull();
  if (task == null) {
    await ref.read(linuxWindowServiceProvider).showWindow();
    return;
  }

  await _openScheduleItemFromNotification(
    ref,
    kind: ScheduleWorkspaceCommandKind.openTask,
    date: _taskCommandDate(task),
    accountId: task.accountId,
    sourceId: task.taskListId,
    itemId: task.id,
  );
}

Future<void> _openScheduleItemFromNotification(
  Ref ref, {
  required ScheduleWorkspaceCommandKind kind,
  required DateTime? date,
  required String accountId,
  required String sourceId,
  required String itemId,
}) async {
  await ref.read(linuxWindowServiceProvider).showWindow();
  final sequenceController = ref.read(
    _notificationOpenSequenceProvider.notifier,
  );
  final sequence = sequenceController.state + 1;
  sequenceController.state = sequence;
  ref
      .read(scheduleWorkspaceCommandProvider.notifier)
      .state = ScheduleWorkspaceCommand(
    kind,
    sequence,
    date: date,
    accountId: accountId,
    sourceId: sourceId,
    itemId: itemId,
  );
  ref.read(appRouterProvider).go('/schedule');
}

DateTime? _calendarEventCommandDate(CalendarEvent event) {
  if (event.allDay) {
    return _parseLocalDate(event.startDate);
  }
  return _parseProviderDateTime(event.startDateTime, event.startTimeZone);
}

DateTime? _taskCommandDate(Task task) {
  return _parseProviderDateTime(
        task.microsoftDueDateTime,
        task.microsoftDueTimeZone,
      ) ??
      _parseProviderDateTime(
        task.microsoftReminderDateTime,
        task.microsoftReminderTimeZone,
      ) ??
      _parseProviderDateTime(task.dueUtc, 'UTC');
}

DateTime? _parseLocalDate(String? value) {
  if (value == null || value.length < 10) {
    return null;
  }
  return DateTime.tryParse('${value.substring(0, 10)}T00:00:00');
}

DateTime? _parseProviderDateTime(String? value, String? timeZone) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) {
    return null;
  }
  if (parsed.isUtc) {
    return parsed.toLocal();
  }

  final normalizedZone = timeZone?.trim().toLowerCase();
  if (normalizedZone == 'utc' ||
      normalizedZone == 'etc/utc' ||
      normalizedZone == 'gmt' ||
      normalizedZone == 'etc/gmt') {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return parsed;
}

final dueTodayNotificationProvider = Provider<void>((ref) {
  final settings = ref.watch(appSettingsControllerProvider);
  final accountId = ref.watch(activeAccountProvider);
  if (!settings.notifyDueToday || accountId == null) {
    return;
  }

  unawaited(_notifyDueTodayIfNeeded(ref, accountId, settings));
});

Future<void> _notifyDueTodayIfNeeded(
  Ref ref,
  String accountId,
  AppSettings settings,
) async {
  final now = DateTime.now();
  final today =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  if (settings.lastDueTodayNotificationDate == today) {
    return;
  }

  final database = ref.read(databaseProvider);
  final tasks =
      await (database.select(database.tasks)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.dueUtc.equals(today) &
                row.pendingDelete.equals(false),
          ))
          .get();
  final count = tasks.where((task) => task.status != 'completed').length;
  if (count <= 0) {
    return;
  }

  await ref.read(desktopNotificationServiceProvider).notifyDueToday(count);
  await ref
      .read(appSettingsControllerProvider.notifier)
      .markDueTodayNotified(today);
}

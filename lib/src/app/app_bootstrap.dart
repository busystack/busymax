import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/build_config.dart';
import '../core/time/local_time_zone.dart';
import '../db/app_database.dart';
import '../dav/auth/dav_account_onboarding_service.dart';
import '../dav/auth/nextcloud_app_password_revoker.dart';
import '../dav/auth/nextcloud_login_flow_v2.dart';
import '../dav/dav_provider_profile.dart';
import '../dav/discovery/dav_discovery_service.dart';
import '../dav/http/dav_http_transport.dart';
import '../dav/mutation/dav_conflict_repository.dart';
import '../dav/mutation/dav_pending_operations.dart';
import '../dav/mutation/dav_task_list_mutation_service.dart';
import '../dav/sync/dav_account_sync_engine.dart';
import '../dav/storage/dav_settings_repository.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/connectivity/network_connectivity_service.dart';
import '../features/feedback/data/feedback_api_client.dart';
import '../features/notifications/desktop_notification_service.dart';
import '../features/notifications/notification_scheduler.dart';
import '../features/sync/account_sync_operations.dart';
import '../features/sync/all_accounts_sync_scheduler.dart';
import '../features/sync/calendar_sync_engine.dart';
import '../features/sync/pending_mutation_sync_requester.dart';
import '../features/sync/pending_op_resolution_service.dart';
import '../features/sync/sync_engine.dart';
import '../features/sync/sync_failure_notification_policy.dart';
import '../features/task_lists/data/task_lists_repository.dart';
import '../features/tasks/data/tasks_repository.dart';
import '../features/tasks/domain/task_remote_client.dart';
import '../google_tasks/api/google_tasks_api_client.dart';
import '../google_tasks/http/authenticated_http_client.dart';
import '../google_tasks/http/retrying_http_client.dart';
import '../google_tasks/oauth/oauth_loopback_flow.dart';
import '../google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/core/secrets/portal_encrypted_secret_store.dart';
import '../google_calendar/google_calendar_api_client.dart';
import '../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../microsoft_todo/api/microsoft_todo_api_client.dart';
import '../microsoft_todo/api/microsoft_todo_task_remote_client.dart';
import '../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../platform/linux_window_service.dart';
import '../platform/linux_autostart_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import '../schedule/schedule_commands.dart';
import '../schedule/schedule_repository.dart';
import 'app_router.dart';
import 'app_settings.dart';

export '../app/app_settings.dart';
export '../platform/linux_header_bar_provider.dart';

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

final networkConnectivityMonitorProvider = Provider<NetworkConnectivityMonitor>(
  (ref) {
    final monitor = NetworkConnectivityMonitor();
    ref.onDispose(() => unawaited(monitor.dispose()));
    return monitor;
  },
);

final networkAvailabilityProvider = StreamProvider<NetworkAvailability>((ref) {
  return ref.watch(networkConnectivityMonitorProvider).watch();
});

final networkReconnectSyncCoordinatorProvider =
    Provider<NetworkReconnectSyncCoordinator>((ref) {
      final coordinator = NetworkReconnectSyncCoordinator(
        monitor: ref.watch(networkConnectivityMonitorProvider),
        synchronize: () => ref.read(syncSchedulerProvider).runNow(),
      );
      coordinator.start();
      ref.onDispose(() => unawaited(coordinator.dispose()));
      return coordinator;
    });

final baseHttpClientProvider = Provider<http.Client>((ref) {
  final client = ConnectivityAwareHttpClient(
    inner: http.Client(),
    requireNetwork: ref
        .watch(networkConnectivityMonitorProvider)
        .requireNetwork,
  );
  ref.onDispose(client.close);
  return client;
});

final nextcloudLoginFlowV2Provider = Provider<NextcloudLoginFlowV2>((ref) {
  return NextcloudLoginFlowV2(client: ref.watch(baseHttpClientProvider));
});

final davAccountOnboardingServiceProvider =
    Provider<DavAccountOnboardingService>((ref) {
      final client = ref.watch(baseHttpClientProvider);
      return DavAccountOnboardingService(
        database: ref.watch(databaseProvider),
        secretStore: ref.watch(secretStoreProvider),
        accountsRepository: ref.watch(accountsRepositoryProvider),
        nextcloudLoginFlow: ref.watch(nextcloudLoginFlowV2Provider),
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) {
              final profile = davProviderProfile(
                provider,
                nextcloudServer: provider == BusyProvider.nextcloud
                    ? accountAuthority
                    : null,
              );
              final transport = DavHttpTransport(
                client: client,
                profile: profile,
                accountAuthority: accountAuthority,
              );
              return DavDiscoveryService(
                transport: transport,
                profile: profile,
                accountAuthority: accountAuthority,
                accountId: accountId,
                credential: credential,
              ).discover(
                correlationId: const Uuid().v4(),
                cancellationToken: cancellationToken,
              );
            },
        nextcloudCredentialRevoker:
            ({required accountId, required credential}) {
              final profile = davProviderProfile(
                BusyProvider.nextcloud,
                nextcloudServer: credential.canonicalServer,
              );
              return NextcloudAppPasswordRevoker(
                transport: DavHttpTransport(
                  client: client,
                  profile: profile,
                  accountAuthority: credential.canonicalServer,
                ),
              ).revoke(
                accountId: accountId,
                credential: credential,
                correlationId: const Uuid().v4(),
              );
            },
      );
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

final secretStoreProvider = Provider<SecretStore>((ref) {
  if (Platform.isLinux && (Platform.environment['SNAP']?.isNotEmpty ?? false)) {
    // flutter_secure_storage_linux warms up direct libsecret first, so
    // SECRET_BACKEND=file cannot avoid a locked keyring inside strict snaps.
    return PortalEncryptedSecretStore();
  }
  return SecureSecretStore(ref.watch(secureStorageProvider));
});

final applicationOAuthServiceProvider = Provider<OAuthService>((ref) {
  return OAuthService(
    config: ref.watch(buildConfigProvider),
    httpClient: ref.watch(baseHttpClientProvider),
    tokenStore: ref.watch(secretStoreProvider),
    loopbackFlow: OAuthLoopbackFlow(),
  );
});

final oAuthServiceProvider = applicationOAuthServiceProvider;

final applicationOAuthGatewayProvider = Provider<OAuthGateway>(
  (ref) => ref.watch(applicationOAuthServiceProvider),
);

final microsoftOAuthServiceProvider = Provider<MicrosoftOAuthService>((ref) {
  return MicrosoftOAuthService(
    config: ref.watch(buildConfigProvider),
    httpClient: ref.watch(baseHttpClientProvider),
    tokenStore: ref.watch(secretStoreProvider),
    loopbackFlow: OAuthLoopbackFlow(),
  );
});

final applicationMicrosoftOAuthServiceProvider =
    Provider<MicrosoftOAuthService?>(
      (ref) => ref.watch(microsoftOAuthServiceProvider),
    );

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
    final settings = ref.watch(appSettingsControllerProvider);
    return DesktopNotificationService(
      backend: ref.watch(desktopNotificationBackendProvider),
      settings: settings,
      locale: settings.locale,
    );
  },
);

final linuxWindowServiceProvider = Provider<LinuxWindowService>(
  (ref) => const LinuxWindowService(),
);

final linuxAutostartServiceProvider = Provider<LinuxAutostartService>(
  (ref) => LinuxAutostartService(),
);

final launchAtLoginEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(linuxAutostartServiceProvider).isEnabled(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    oAuth: ref.watch(applicationOAuthGatewayProvider),
    database: ref.watch(databaseProvider),
    accountsRepository: ref.watch(accountsRepositoryProvider),
    microsoftOAuth: ref.watch(applicationMicrosoftOAuthServiceProvider),
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

final davSettingsRepositoryProvider = Provider<DavSettingsRepository>((ref) {
  return DavSettingsRepository(
    database: ref.watch(databaseProvider),
    onVisibilityChanged: (_) =>
        ref.read(notificationSchedulerProvider).checkNow(),
  );
});

final davCollectionsStreamProvider =
    StreamProvider<List<DavCollectionSettingsEntity>>((ref) {
      return ref.watch(davSettingsRepositoryProvider).watchCollections();
    });

final davConflictRepositoryProvider = Provider<DavConflictRepository>((ref) {
  return DavConflictRepository(database: ref.watch(databaseProvider));
});

final davConflictsStreamProvider = StreamProvider<List<DavConflictEntity>>((
  ref,
) {
  return ref.watch(davConflictRepositoryProvider).watchUnresolved();
});

final davConflictResolutionServiceProvider =
    Provider<DavConflictResolutionService>((ref) {
      final database = ref.watch(databaseProvider);
      return DavConflictResolutionService(
        database: database,
        pendingQueue: DavPendingOperationQueue(database: database),
      );
    });

final davTaskCollectionCapabilitiesProvider =
    FutureProvider.family<
      TaskCollectionCapabilities?,
      ({String accountId, String taskListId})
    >((ref, key) async {
      final collection = await ref
          .watch(davSettingsRepositoryProvider)
          .collectionByTaskListId(key.accountId, key.taskListId);
      return collection?.taskCapabilities;
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

final selectedAccountCapabilitiesProvider =
    Provider<TaskCollectionCapabilities>((ref) {
      final account = ref.watch(selectedAccountProvider);
      return account == null
          ? noTaskCollectionCapabilities
          : adapterDefaultTaskCapabilities(account.provider);
    });

final localTimeZoneProvider = Provider<String>((ref) => localIanaTimeZone());

final googleTasksApiClientForAccountProvider =
    Provider.family<TaskRemoteClient, String>((ref, accountId) {
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

final microsoftTodoTaskRemoteClientForAccountProvider =
    Provider.family<TaskRemoteClient, String>((ref, accountId) {
      return MicrosoftTodoTaskRemoteClient(
        client: ref.watch(microsoftTodoApiClientForAccountProvider(accountId)),
        defaultTimeZone: ref.watch(localTimeZoneProvider),
      );
    });

final taskRemoteApiClientForAccountProvider =
    Provider.family<TaskRemoteClient?, String>((ref, accountId) {
      final accounts = ref.watch(accountsStreamProvider).valueOrNull;
      AccountEntity? account;
      for (final candidate in accounts ?? const <AccountEntity>[]) {
        if (candidate.id == accountId) {
          account = candidate;
          break;
        }
      }
      if (account == null) {
        return null;
      }
      return switch (account.provider) {
        BusyProvider.microsoft => ref.watch(
          microsoftTodoTaskRemoteClientForAccountProvider(accountId),
        ),
        BusyProvider.google => ref.watch(
          googleTasksApiClientForAccountProvider(accountId),
        ),
        BusyProvider.appleICloud || BusyProvider.nextcloud => null,
      };
    });

typedef SyncEngineForAccountFactory =
    SyncEngine Function(String accountId, BusyProvider provider);

final syncEngineForAccountFactoryProvider =
    Provider<SyncEngineForAccountFactory>((ref) {
      return (accountId, provider) {
        final apiClient = switch (provider) {
          BusyProvider.microsoft => ref.read(
            microsoftTodoTaskRemoteClientForAccountProvider(accountId),
          ),
          BusyProvider.google => ref.read(
            googleTasksApiClientForAccountProvider(accountId),
          ),
          BusyProvider.appleICloud ||
          BusyProvider.nextcloud => throw StateError(
            'DAV task accounts must use DavSynchronizationEngine.',
          ),
        };

        return SyncEngine(
          database: ref.read(databaseProvider),
          apiClient: apiClient,
          accountId: accountId,
          fullRefreshOnly: provider == BusyProvider.microsoft,
          onConflictBlocked: ref
              .read(desktopNotificationServiceProvider)
              .notifyConflict,
        );
      };
    });

typedef CalendarSyncEngineForAccountFactory =
    CalendarSyncEngine Function(String accountId, BusyProvider provider);

final calendarSyncEngineForAccountFactoryProvider =
    Provider<CalendarSyncEngineForAccountFactory>((ref) {
      return (accountId, provider) {
        final client = switch (provider) {
          BusyProvider.microsoft => ref.read(
            microsoftCalendarApiClientForAccountProvider(accountId),
          ),
          BusyProvider.google => ref.read(
            googleCalendarApiClientForAccountProvider(accountId),
          ),
          BusyProvider.appleICloud ||
          BusyProvider.nextcloud => throw StateError(
            'DAV calendar accounts must use DavSynchronizationEngine.',
          ),
        };
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

typedef DavAccountSyncEngineFactory =
    DavAccountSyncEngine Function(String accountId);

final davAccountSyncEngineFactoryProvider =
    Provider<DavAccountSyncEngineFactory>((ref) {
      return (accountId) => DavAccountSyncEngine(
        database: ref.read(databaseProvider),
        secretStore: ref.read(secretStoreProvider),
        httpClient: ref.read(baseHttpClientProvider),
        accountId: accountId,
        rebuildNotifications: (accountId, affectedObjectIds) =>
            ref.read(notificationSchedulerProvider).checkNow(),
        reportPendingMutationFailure: (accountId, error) => ref
            .read(desktopNotificationServiceProvider)
            .notifySyncFailure(error),
      );
    });

final accountSyncOperationsProvider = Provider<AccountSyncOperations>((ref) {
  final accountsRepository = ref.watch(accountsRepositoryProvider);
  final connectivity = ref.watch(networkConnectivityMonitorProvider);

  Future<BusyProvider> providerForAccount(String accountId) async {
    final account = await accountsRepository.accountById(accountId);
    if (account == null) {
      throw StateError('Account $accountId is unavailable.');
    }
    return account.provider;
  }

  final routing = RoutingAccountSyncOperations(
    usesDav: (accountId) async {
      final provider = await providerForAccount(accountId);
      return provider == BusyProvider.appleICloud ||
          provider == BusyProvider.nextcloud;
    },
    syncDav: (accountId, {required full}) async {
      await ref
          .read(davAccountSyncEngineFactoryProvider)(accountId)
          .synchronize(full: full);
    },
    syncTasksRest: (accountId, {required full}) async {
      final provider = await providerForAccount(accountId);
      final engine = ref.read(syncEngineForAccountFactoryProvider)(
        accountId,
        provider,
      );
      if (full) {
        await engine.fullSync();
      } else {
        await engine.incrementalSync();
      }
    },
    syncCalendarRest: (accountId, {required full}) async {
      final provider = await providerForAccount(accountId);
      final engine = ref.read(calendarSyncEngineForAccountFactoryProvider)(
        accountId,
        provider,
      );
      if (full) {
        await engine.fullSync();
      } else {
        await engine.incrementalSync();
      }
    },
  );
  return ConnectivityAwareAccountSyncOperations(
    inner: routing,
    requireNetwork: connectivity.requireNetwork,
  );
});

typedef SignedInSyncRunner =
    Future<void> Function(String accountId, bool initial);

final signedInSyncRunnerProvider = Provider<SignedInSyncRunner>((ref) {
  return (accountId, initial) async {
    try {
      await ref
          .read(accountSyncOperationsProvider)
          .syncAccount(accountId, full: initial);
    } on Object catch (error) {
      await _markAccountReconnectRequiredForSyncError(ref, accountId, error);
      rethrow;
    }
  };
});

typedef AllAccountsSyncRunner = Future<void> Function();

final allAccountsSyncRunnerProvider = Provider<AllAccountsSyncRunner>((ref) {
  Future<void> syncAccount(String accountId) async {
    await ref
        .read(accountSyncOperationsProvider)
        .syncAccount(accountId, full: false);
  }

  return () async {
    await ref.read(networkConnectivityMonitorProvider).requireNetwork();
    await runAllSignedInAccountSync(
      listSignedInAccounts: ref
          .read(accountsRepositoryProvider)
          .listSyncEligibleAccounts,
      syncAccount: syncAccount,
      onSyncFailure: ref
          .read(desktopNotificationServiceProvider)
          .notifySyncFailure,
      onAccountSyncFailure: (accountId, error) =>
          _markAccountReconnectRequiredForSyncError(ref, accountId, error),
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

final googleTasksApiClientProvider = Provider<TaskRemoteClient?>((ref) {
  final accountId = ref.watch(activeAccountProvider);
  if (accountId == null) {
    return null;
  }
  return ref.watch(taskRemoteApiClientForAccountProvider(accountId));
});

final davTaskListMutationClientForAccountProvider =
    Provider.family<DavTaskListMutationClient, String>((ref, accountId) {
      return DavTaskListMutationService(
        database: ref.watch(databaseProvider),
        secretStore: ref.watch(secretStoreProvider),
        httpClient: ref.watch(baseHttpClientProvider),
        accountId: accountId,
        refreshAfterMutation: () => ref
            .read(accountSyncOperationsProvider)
            .syncAccount(accountId, full: true),
      );
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
    davMutationClient: ref.watch(
      davTaskListMutationClientForAccountProvider(accountId),
    ),
    onMutationQueued: ref.watch(pendingMutationSyncRequesterProvider)?.request,
  );
});

final taskListsRepositoryForAccountProvider =
    Provider.family<TaskListsRepository, String>((ref, accountId) {
      return TaskListsRepository(
        database: ref.watch(databaseProvider),
        accountId: accountId,
        apiClient: ref.watch(taskRemoteApiClientForAccountProvider(accountId)),
        davMutationClient: ref.watch(
          davTaskListMutationClientForAccountProvider(accountId),
        ),
        onMutationQueued: ref
            .watch(pendingMutationSyncRequesterForAccountProvider(accountId))
            .request,
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
      return TasksRepository(
        database: ref.watch(databaseProvider),
        accountId: accountId,
        apiClient: ref.watch(taskRemoteApiClientForAccountProvider(accountId)),
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
  final account = ref.watch(selectedAccountProvider);
  if (accountId == null || apiClient == null || account?.id != accountId) {
    return null;
  }
  return SyncEngine(
    database: ref.watch(databaseProvider),
    apiClient: apiClient,
    accountId: accountId,
    fullRefreshOnly: account!.provider == BusyProvider.microsoft,
    onConflictBlocked: ref
        .watch(desktopNotificationServiceProvider)
        .notifyConflict,
  );
});

final pendingMutationSyncRequesterProvider =
    Provider<PendingMutationSyncRequester?>((ref) {
      final accountId = ref.watch(activeAccountProvider);
      if (accountId == null) {
        return null;
      }

      final requester = PendingMutationSyncRequester(
        sync: () => ref
            .read(accountSyncOperationsProvider)
            .syncTasks(accountId, full: false),
        onSyncFailure: ref
            .watch(desktopNotificationServiceProvider)
            .notifySyncFailure,
        onSyncError: (error) =>
            _markAccountReconnectRequiredForSyncError(ref, accountId, error),
        canSync: ref.watch(networkConnectivityMonitorProvider).canUseNetwork,
      );
      ref.onDispose(requester.dispose);
      return requester;
    });

final pendingMutationSyncRequesterForAccountProvider =
    Provider.family<PendingMutationSyncRequester, String>((ref, accountId) {
      final requester = PendingMutationSyncRequester(
        sync: () => ref
            .read(accountSyncOperationsProvider)
            .syncTasks(accountId, full: false),
        onSyncFailure: ref
            .watch(desktopNotificationServiceProvider)
            .notifySyncFailure,
        onSyncError: (error) =>
            _markAccountReconnectRequiredForSyncError(ref, accountId, error),
        canSync: ref.watch(networkConnectivityMonitorProvider).canUseNetwork,
      );
      ref.onDispose(requester.dispose);
      return requester;
    });

final pendingCalendarMutationSyncRequesterForAccountProvider =
    Provider.family<PendingMutationSyncRequester, String>((ref, accountId) {
      final requester = PendingMutationSyncRequester(
        sync: () => ref
            .read(accountSyncOperationsProvider)
            .syncCalendar(accountId, full: false),
        onSyncFailure: ref
            .watch(desktopNotificationServiceProvider)
            .notifySyncFailure,
        onSyncError: (error) =>
            _markAccountReconnectRequiredForSyncError(ref, accountId, error),
        canSync: ref.watch(networkConnectivityMonitorProvider).canUseNetwork,
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
        .read(accountSyncOperationsProvider)
        .syncAccount(accountId, full: false);
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
        _markAccountReconnectRequiredForSyncError(ref, accountId, error),
    canSync: ref.watch(networkConnectivityMonitorProvider).canUseNetwork,
  );
  scheduler.start();
  ref.onDispose(scheduler.stop);
  return scheduler;
});

Future<void> _markAccountReconnectRequiredForSyncError(
  Ref ref,
  String accountId,
  Object error,
) async {
  if (syncFailureNotificationDisposition(error) !=
      SyncFailureNotificationDisposition.reconnectRequired) {
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

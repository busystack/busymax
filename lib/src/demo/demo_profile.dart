import 'dart:async';

import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app/app_bootstrap.dart';
import '../config/build_config.dart';
import '../db/app_database.dart';
import '../features/feedback/data/feedback_api_client.dart';
import '../features/feedback/data/feedback_submission.dart';
import '../features/notifications/desktop_notification_service.dart';
import '../features/notifications/notification_scheduler.dart';
import '../features/sync/account_sync_operations.dart';
import '../features/sync/all_accounts_sync_scheduler.dart';
import '../google_tasks/api/google_tasks_api_surface.dart';
import '../google_tasks/oauth/oauth_models.dart';
import '../google_tasks/oauth/oauth_service.dart';
import '../google_tasks/oauth/oauth_token_store.dart';
import 'demo_seed.dart';

AppSettings busyMaxDemoSettings(BusyMaxDemoTheme theme) {
  final themeModePreference = switch (theme) {
    BusyMaxDemoTheme.system => BusyMaxThemeModePreference.system,
    BusyMaxDemoTheme.light => BusyMaxThemeModePreference.light,
    BusyMaxDemoTheme.dark => BusyMaxThemeModePreference.dark,
  };
  return AppSettings.defaults().copyWith(
    themeModePreference: themeModePreference,
    notifySyncFailures: false,
    notifyConflicts: false,
    notifyDueToday: false,
    notifyEventReminders: false,
    notifyTaskReminders: false,
    runInBackgroundWhenClosed: false,
    showTrayIcon: false,
    startMinimizedToTray: false,
    quitExitsCompletely: true,
  );
}

class InMemoryLocalSettingsStore implements LocalSettingsStore {
  InMemoryLocalSettingsStore([Map<String, Object?> initial = const {}])
    : _value = Map<String, Object?>.from(initial);

  Map<String, Object?> _value;

  Map<String, Object?> get snapshot => Map.unmodifiable(_value);

  @override
  Future<Map<String, Object?>> load() async {
    return Map<String, Object?>.from(_value);
  }

  @override
  Future<void> save(Map<String, Object?> json) async {
    _value = Map<String, Object?>.from(json);
  }
}

class BusyMaxDemoProfile {
  BusyMaxDemoProfile._(this.database);

  static Future<BusyMaxDemoProfile> create({DateTime? now}) async {
    final database = AppDatabase.memoryForTests();
    try {
      await seedBusyMaxDemoData(database, now: now);
      return BusyMaxDemoProfile._(database);
    } on Object {
      await database.close();
      rethrow;
    }
  }

  final AppDatabase database;

  List<Override> get overrides {
    return [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(database.close);
        return database;
      }),
      baseHttpClientProvider.overrideWith((ref) {
        final client = _BlockedDemoHttpClient();
        ref.onDispose(client.close);
        return client;
      }),
      oAuthTokenStoreProvider.overrideWithValue(InMemoryOAuthTokenStore()),
      applicationOAuthGatewayProvider.overrideWithValue(
        DemoOAuthGateway(activeAccountId: busyMaxDemoAccountId),
      ),
      applicationMicrosoftOAuthServiceProvider.overrideWithValue(null),
      accountSyncOperationsProvider.overrideWithValue(
        const DisabledAccountSyncOperations(),
      ),
      taskRemoteApiClientForAccountProvider.overrideWith(
        (ref, accountId) => null,
      ),
      pendingOpResolutionServiceProvider.overrideWithValue(null),
      feedbackSubmissionServiceProvider.overrideWithValue(
        const DemoFeedbackSubmissionService(),
      ),
      desktopNotificationBackendProvider.overrideWithValue(
        const DemoDesktopNotificationBackend(),
      ),
      syncSchedulerProvider.overrideWith((ref) {
        final scheduler = AllAccountsSyncScheduler(
          listSignedInAccounts: () async => const [],
          syncAccount: (_) async {},
          onSyncFailure: (_) async {},
          interval: Duration.zero,
        );
        ref.onDispose(scheduler.stop);
        return scheduler;
      }),
      notificationSchedulerProvider.overrideWith((ref) {
        final scheduler = NotificationScheduler(
          database: ref.watch(databaseProvider),
          notifications: ref.watch(desktopNotificationServiceProvider),
        );
        ref.onDispose(scheduler.stop);
        return scheduler;
      }),
    ];
  }
}

class DemoOAuthGateway implements OAuthGateway {
  DemoOAuthGateway({String? activeAccountId})
    : _activeAccountId = activeAccountId;

  String? _activeAccountId;

  OAuthTokenSet get _tokenSet => OAuthTokenSet(
    accessToken: 'busymax-demo-access-token',
    refreshToken: 'busymax-demo-refresh-token',
    expiresAtUtc: DateTime.utc(2100),
    tokenType: 'Bearer',
    scopes: Set<String>.of(googleBusyMaxOAuthScopes),
  );

  @override
  Future<String?> get activeAccountId async => _activeAccountId;

  @override
  Future<void> cancelSignIn() async {}

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    if (accountId == null || accountId == _activeAccountId) {
      _activeAccountId = null;
    }
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async {
    return const GoogleUserInfo(
      subject: 'demo-user',
      name: 'Alex Morgan',
      email: 'alex@example.com',
      rawJson: {
        'sub': 'demo-user',
        'name': 'Alex Morgan',
        'email': 'alex@example.com',
      },
    );
  }

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    return _activeAccountId == null ? null : _tokenSet;
  }

  @override
  Future<OAuthTokenSet> refreshActiveToken() async => _tokenSet;

  @override
  Future<void> revokeAndSignOutAccount(String accountId) {
    return clearLocalSession(accountId: accountId);
  }

  @override
  Future<void> revokeAuthorization(String accountId) async {}

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
    _activeAccountId = busyMaxDemoAccountId;
    return OAuthSignInResult(
      accountId: busyMaxDemoAccountId,
      tokenSet: _tokenSet,
    );
  }
}

class DemoFeedbackSubmissionService implements FeedbackSubmissionService {
  const DemoFeedbackSubmissionService();

  @override
  Future<FeedbackReceipt> submit(FeedbackSubmission submission) async {
    return FeedbackReceipt(id: 'demo-${submission.submissionId}');
  }
}

class DemoDesktopNotificationBackend implements DesktopNotificationBackend {
  const DemoDesktopNotificationBackend();

  @override
  Future<void> close() async {}

  @override
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
    List<NotificationAction> actions = const [],
    DesktopNotificationActionHandler? onAction,
  }) async {}
}

class _BlockedDemoHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('Network access is disabled in BusyMax demo mode.');
  }
}

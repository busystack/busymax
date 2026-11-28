import 'android_sync_activity.dart';
import '../features/sync/domain_sync_schedule.dart';
import '../features/notifications/notification_schedule_service.dart';
import '../features/notifications/daily_summary_policy.dart';

import 'dart:async';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:drift/drift.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../app/app_bootstrap.dart';
import '../app/busymax_surface_colors.dart';
import '../l10n/app_locale.dart';
import '../l10n/locale_resolution.dart';
import '../l10n/l10n.dart';
import '../l10n/time_format_scope.dart';
import '../l10n/week_preferences_scope.dart';
import '../platform/android/android_first_weekday_source.dart';
import 'android_notifications.dart';
import 'presentation/android_schedule_screen.dart';
import 'presentation/android_settings_screen.dart';
import 'presentation/android_diagnostics_screen.dart';
import 'android_workspace_navigation.dart';

class AndroidBusyMaxApp extends ConsumerStatefulWidget {
  const AndroidBusyMaxApp({super.key});

  @override
  ConsumerState<AndroidBusyMaxApp> createState() => _AndroidBusyMaxAppState();
}

class _AndroidBusyMaxAppState extends ConsumerState<AndroidBusyMaxApp> {
  late final BusyMaxSystemFirstWeekdayController _firstWeekdayController;

  @override
  void initState() {
    super.initState();
    _firstWeekdayController = BusyMaxSystemFirstWeekdayController(
      AndroidFirstWeekdaySource(),
    )..addListener(_platformChanged);
  }

  void _platformChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _firstWeekdayController
      ..removeListener(_platformChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp(
      restorationScopeId: 'busymax_android',
      navigatorObservers: [androidWorkspaceRouteObserver],
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (_) => 'BusyMax',
      locale: settings.locale,
      supportedLocales: busyMaxSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        flutterMaterialLocalizationsDelegate,
        GlobalWidgetsLocalizations.delegate,
        flutterCupertinoLocalizationsDelegate,
      ],
      localeListResolutionCallback: (requested, supported) =>
          resolveBusyMaxLocales(requested, supported),
      themeMode: settings.themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      builder: (context, child) => BusyMaxTimeFormatScope(
        formatter: BusyMaxTimeFormatter(
          locale: Localizations.localeOf(context).toLanguageTag(),
          use24Hour: resolveBusyMax24HourClock(
            settings.timeFormatPreference,
            systemUses24Hour: ref.watch(androidSystemUses24HourProvider),
          ),
        ),
        child: BusyMaxWeekPreferencesScope(
          preference: settings.firstDayOfWeekPreference,
          systemWeekday: _firstWeekdayController.value,
          platformLocaleTag: WidgetsBinding.instance.platformDispatcher.locale
              .toLanguageTag(),
          child: BusyMaxWeekPreferencesStartupGate(
            preference: settings.firstDayOfWeekPreference,
            systemValueInitialized: _firstWeekdayController.isInitialized,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      home: const AndroidHomeShell(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final surfaces = busyMaxFallbackSurfaceColors(brightness);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff6d28d9),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: surfaces.window,
        onSurface: surfaces.foreground,
        onSurfaceVariant: surfaces.mutedForeground,
        outlineVariant: surfaces.divider,
        surfaceContainer: surfaces.card,
        surfaceContainerLowest: surfaces.view,
        surfaceContainerLow: surfaces.sidebar,
        surfaceContainerHigh: surfaces.dialog,
        surfaceContainerHighest: surfaces.popover,
      ),
      extensions: [surfaces],
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: surfaces.window,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaces.headerbarFlat,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: surfaces.card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaces.sidebar,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaces.dialog,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

class AndroidHomeShell extends ConsumerStatefulWidget {
  const AndroidHomeShell({super.key});

  @override
  ConsumerState<AndroidHomeShell> createState() => _AndroidHomeShellState();
}

class _AndroidHomeShellState extends ConsumerState<AndroidHomeShell>
    with WidgetsBindingObserver {
  StreamSubscription<AndroidPlatformEvent>? _platformEvents;
  StreamSubscription<AndroidReminderActivation>? _reminderActivations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformEvents = BusyMaxAndroidPlatform.instance.events.listen(
      (event) => unawaited(_handlePlatformEvent(event)),
    );
    _reminderActivations = ref
        .read(androidNotificationServiceProvider)
        .activations
        .listen((activation) => unawaited(_openReminder(activation)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeInitialActivations());
    });
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_platformEvents?.cancel());
    unawaited(_reminderActivations?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _invalidateExternalDatabaseState();
      if (ref.read(accountSyncActivityProvider.notifier)
          case final AndroidSyncActivity activity) {
        unawaited(activity.reconcilePlatformActivity());
      }
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    await ref.read(appSettingsControllerProvider.notifier).reload();
    if (!mounted) {
      return;
    }
    await ref.read(androidNotificationServiceProvider).refreshReadiness();
    if (!mounted) {
      return;
    }
    try {
      await withSyncTrigger(
        SyncTrigger.foreground,
        ref.read(allAccountsSyncRunnerProvider),
      );
    } on Object {
      // SyncRuns and account state expose the individual failure.
    }
    if (!mounted) {
      return;
    }
    await ref.read(notificationReconcilerProvider).reconcile();
  }

  Future<void> _consumeInitialActivations() async {
    final document = await BusyMaxAndroidPlatform.instance
        .takeInitialActivation();
    if (document != null) {
      await _openDocumentActivation(document);
    }
    if (!mounted) {
      return;
    }
    final reminder = ref
        .read(androidNotificationServiceProvider)
        .takeInitialActivation();
    if (reminder != null) {
      await _openReminder(reminder);
    }
  }

  Future<void> _handlePlatformEvent(AndroidPlatformEvent event) async {
    if (event.type == 'syncActivity') {
      if ((ref.read(accountSyncActivityProvider.notifier), event.data['scopes'])
          case (
            final AndroidSyncActivity activity,
            final List<Object?> scopes,
          )) {
        activity.updateFromPlatform(scopes);
      }
      return;
    }
    if (event.type == 'systemSettingsChanged') {
      final zone = await BusyMaxAndroidPlatform.instance.currentTimeZoneId();
      final uses24Hour = await BusyMaxAndroidPlatform.instance
          .uses24HourFormat();
      ref.read(androidLocalTimeZoneStateProvider.notifier).state = zone;
      ref.read(androidSystemUses24HourProvider.notifier).state = uses24Hour;
      await ref
          .read(androidNotificationServiceProvider)
          .initialize(timeZoneId: zone);
      final notifications = ref.read(androidNotificationServiceProvider);
      await notifications.synchronize(() async {
        await notifications.reconcile();
        final database = ref.read(databaseProvider);
        final schedules = NotificationScheduleService(
          database: database,
          preserveLifecycle: true,
        );
        for (final account in await database.select(database.accounts).get()) {
          await schedules.rebuildUpcomingNotifications(account.id);
        }
      });
      await ref.read(notificationReconcilerProvider).reconcile();
      return;
    }
    if (event.type == 'dataChanged') {
      _invalidateExternalDatabaseState();
      await ref.read(appSettingsControllerProvider.notifier).reload();
      await ref.read(notificationReconcilerProvider).reconcile();
      return;
    }
    if (event.type == 'document') {
      await _openDocumentActivation(AndroidActivation.fromMap(event.data));
    }
  }

  void _invalidateExternalDatabaseState() {
    // Drift streams do not receive writes from an independent worker engine.
    final database = ref.read(databaseProvider);
    database.notifyUpdates({
      TableUpdate.onTable(database.davCollections),
      TableUpdate.onTable(database.davJournalEntries),
      TableUpdate.onTable(database.davObjects),
      TableUpdate.onTable(database.domainSyncSchedules),
      TableUpdate.onTable(database.pendingOps),
      TableUpdate.onTable(database.davCollectionCreations),
      TableUpdate.onTable(database.davCollectionCreationAcknowledgments),
      TableUpdate.onTable(database.webCalSubscriptions),
      TableUpdate.onTable(database.calendarSources),
    });
    ref.invalidate(accountsStreamProvider);
    ref.invalidate(accountManagementStreamProvider);
    ref.invalidate(calendarSourcesStreamProvider);
    ref.invalidate(scheduleTaskListsProvider);
    ref.invalidate(scheduleDataRevisionProvider);
    ref.invalidate(davConflictsStreamProvider);
    ref.invalidate(webCalSubscriptionsProvider);
  }

  Future<void> _openDocumentActivation(AndroidActivation activation) async {
    final uri = activation.uri;
    if (!mounted || activation.kind != 'document' || uri == null) {
      return;
    }
    try {
      final document = await BusyMaxAndroidPlatform.instance.readDocumentUri(
        uri,
      );
      if (!mounted) {
        return;
      }
      await showAndroidIcsImport(context, ref, document: document);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importIcsFailed('$error'))),
        );
      }
    }
  }

  Future<void> _openReminder(AndroidReminderActivation activation) async {
    if (activation.sourceType == 'summary') {
      final date = parseNotificationDate(activation.itemId);
      if (date == null || !mounted) {
        return;
      }
      ref.read(androidWorkspaceRequestProvider.notifier).state =
          AndroidWorkspaceRequest(date: date, summary: true);
      return;
    }
    if (activation.sourceType == 'sync-failure' ||
        activation.sourceType == 'conflict') {
      final database = ref.read(databaseProvider);
      final account = activation.accountId == 'all'
          ? null
          : await (database.select(database.accounts)
                  ..where((row) => row.id.equals(activation.accountId)))
                .getSingleOrNull();
      if (!mounted) {
        return;
      }
      if (activation.accountId != 'all' && account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.notificationItemUnavailable)),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              activation.sourceType == 'conflict' &&
                  (account?.provider == 'google' ||
                      account?.provider == 'microsoft')
              ? AndroidDiagnosticsScreen(accountId: account!.id)
              : AndroidSettingsScreen(
                  notificationAccountId: activation.accountId == 'all'
                      ? null
                      : activation.accountId,
                  notificationConflicts: activation.sourceType == 'conflict',
                ),
        ),
      );
      return;
    }
    final database = ref.read(databaseProvider);
    final row =
        await (database.select(database.notificationSchedule)..where(
              (schedule) =>
                  schedule.id.equals(activation.scheduleId) &
                  schedule.generation.equals(activation.generation) &
                  schedule.accountId.equals(activation.accountId) &
                  schedule.sourceType.equals(activation.sourceType),
            ))
            .getSingleOrNull();
    final schedules = NotificationScheduleService(database: database);
    final task = activation.sourceType == 'task';
    final taskListId = task && row != null
        ? await schedules.taskListForOpenReminder(row)
        : null;
    final valid =
        row != null &&
        (task
            ? taskListId != null
            : await schedules.validateAndReconcileReminder(row, forOpen: true));
    if (!mounted) {
      return;
    }
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notificationItemUnavailable)),
      );
      return;
    }
    ref
        .read(androidWorkspaceRequestProvider.notifier)
        .state = AndroidWorkspaceRequest(
      date: DateTime.now(),
      itemId: row.sourceId,
      accountId: activation.accountId,
      taskListId: taskListId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const SafeArea(child: AndroidScheduleScreen()),
    );
  }
}

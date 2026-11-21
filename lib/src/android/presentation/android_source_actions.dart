part of 'android_settings_screen.dart';

Future<void> createAndroidAccountCollection(
  BuildContext context,
  WidgetRef ref,
  AccountEntity account, {
  required bool calendar,
}) => _AndroidSourceActions(
  context,
  ref,
)._createAccountCollection(account, calendar: calendar);

Future<void> showAndroidCalendarSourceActions(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source, {
  List<Widget> Function(BuildContext)? extraActions,
}) => _AndroidSourceActions(
  context,
  ref,
  extraActions,
)._editCalendarSource(source);

Future<void> showAndroidTaskListActions(
  BuildContext context,
  WidgetRef ref,
  TaskListEntity list,
  List<AccountEntity> accounts, {
  List<Widget> Function(BuildContext)? extraActions,
}) => _AndroidSourceActions(
  context,
  ref,
  extraActions,
)._editTaskList(list, accounts);

Future<void> showAndroidDavCollectionSelection(
  BuildContext context,
  WidgetRef ref,
  String id,
) => _AndroidSourceActions(context, ref)._selectCalDavCollection(id);

class _AndroidSourceActions {
  _AndroidSourceActions(this.context, this.ref, [this.extraActions]);
  final List<Widget> Function(BuildContext)? extraActions;
  final BuildContext context;
  final WidgetRef ref;
  bool get mounted => context.mounted;
  Future<void> _createAccountCollection(
    AccountEntity account, {
    required bool calendar,
  }) async {
    final l10n = context.l10n;
    final modes = accountCollectionCreationModes(account.provider);
    if (!account.isSignedIn ||
        (calendar
            ? !account.calendarsEnabled ||
                  modes.calendarMode ==
                      CalendarCollectionCreationMode.unavailable
            : !account.tasksEnabled ||
                  modes.taskListMode == TaskListCreationMode.unavailable)) {
      return;
    }
    final title = await _textPrompt(
      title: calendar ? l10n.newCalendar : l10n.newTaskList,
      label: l10n.title,
    );
    if (title == null || !mounted) {
      return;
    }
    try {
      if (calendar) {
        final result = await ref
            .read(calendarCollectionCreationServiceProvider)
            .createCalendar(accountId: account.id, title: title);
        if (result.refreshPending && mounted) {
          _message(l10n.davRefreshPending);
        }
      } else {
        await ref
            .read(taskListsRepositoryForAccountProvider(account.id))
            .createTaskList(title);
      }
    } on Object catch (error) {
      if (localizedCollectionRefreshPending(l10n, error) case final warning?) {
        if (mounted) _message(warning);
        return;
      }
      if (mounted) {
        _message(
          calendar
              ? l10n.calendarCreateFailed(
                  syncFailureMessage(
                    error,
                    networkUnavailableMessage: l10n.networkOfflineTryAgain,
                  ),
                )
              : l10n.taskListCreateFailed(
                  syncFailureMessage(
                    error,
                    networkUnavailableMessage: l10n.networkOfflineTryAgain,
                  ),
                ),
        );
      }
    }
  }

  Future<void> _selectCalDavCollection(String id) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final collection = ref
            .watch(davCollectionsStreamProvider)
            .valueOrNull
            ?.where((c) => c.id == id)
            .firstOrNull;
        return AlertDialog(
          title: Text(collection?.name ?? context.l10n.collectionSettings),
          content: collection == null
              ? Text(context.l10n.collectionsUnavailable)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ref
                            .watch(accountsStreamProvider)
                            .valueOrNull
                            ?.any(
                              (account) =>
                                  account.id == collection.accountId &&
                                  account.provider == BusyProvider.nextcloud,
                            ) ==
                        true)
                      ListTile(
                        title: Text(context.l10n.nextcloudCollectionSettings),
                        leading: const Icon(Icons.settings_outlined),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Navigator.of(this.context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => AndroidNextcloudCollectionScreen(
                                accountId: collection.accountId,
                                collectionId: collection.id,
                              ),
                            ),
                          );
                        },
                      ),
                    if (!collection.capabilities.permissionsKnown)
                      Text(context.l10n.davPermissionsUnknown),
                    if (collection.readOnly)
                      Text(context.l10n.readOnlySharedCollection),
                    if (collection.supportsEvents)
                      SwitchListTile(
                        title: Text(context.l10n.calendarContent),
                        value: collection.eventsSelected,
                        onChanged: (value) => ref
                            .read(davSettingsRepositoryProvider)
                            .setEventsSelected(id, value),
                      ),
                    if (collection.supportsTasks)
                      SwitchListTile(
                        title: Text(context.l10n.taskContent),
                        value: collection.tasksSelected,
                        onChanged: (value) => ref
                            .read(davSettingsRepositoryProvider)
                            .setTasksSelected(id, value),
                      ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    ),
  );

  void _openRefreshRecovery(String accountId) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              AndroidSettingsScreen(notificationAccountId: accountId),
        ),
      ),
    );
  }

  Future<void> _subscriptionAction(
    WebCalSubscriptionEntity subscription,
    String action,
  ) async {
    final l10n = context.l10n;
    try {
      final service = ref.read(webCalSubscriptionServiceProvider);
      if (action == 'refresh') {
        await refreshFromMaterial(
          context,
          ref,
          calendarSyncScope(
            subscription.accountId,
            subscription.calendarSourceId,
          ),
        );
      } else if (action == 'color') {
        final color = await _textPrompt(
          title: l10n.subscriptionColor,
          label: l10n.subscriptionColor,
          helper: l10n.subscriptionColorHelp,
          initialValue: subscription.color,
        );
        if (color != null) {
          await service.changeSubscriptionColor(subscription.id, color);
        }
      } else if (action == 'frequency') {
        if (!context.mounted) {
          return;
        }
        final mode = await showModalBottomSheet<WebCalRefreshMode>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in WebCalRefreshMode.values)
                  ListTile(
                    title: Text(switch (mode) {
                      WebCalRefreshMode.automatic => l10n.subscriptionAutomatic,
                      WebCalRefreshMode.hourly => l10n.subscriptionHourly,
                      WebCalRefreshMode.sixHours => l10n.subscriptionSixHours,
                      WebCalRefreshMode.daily => l10n.subscriptionDaily,
                    }),
                    selected: mode == subscription.refreshMode,
                    trailing: mode == subscription.refreshMode
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, mode),
                  ),
              ],
            ),
          ),
        );
        if (mode != null) {
          await service.changeRefreshMode(subscription.id, mode);
        }
      } else if (action == 'rename') {
        final name = await _textPrompt(
          title: l10n.rename,
          label: l10n.subscriptionName,
          initialValue: subscription.name,
        );
        if (name != null) {
          await service.renameSubscription(subscription.id, name);
        }
      } else if (action == 'remove') {
        final confirmed = await _confirm(
          l10n.unsubscribeCalendarTitle(subscription.name),
          l10n.unsubscribeCalendarConfirmation,
          l10n.unsubscribe,
        );
        if (confirmed) {
          await ref
              .read(crossEngineAccountGateProvider)
              .run(
                subscription.accountId,
                () => service.unsubscribe(subscription.id),
              );
        }
      }
    } on Object catch (error) {
      _message(l10n.subscriptionOperationFailed('$error'));
    }
  }

  Future<bool> _networkReady(String accountId) async {
    final account = await ref
        .read(accountsRepositoryProvider)
        .accountById(accountId);
    if (!context.mounted || account?.isSyncEligible != true) {
      if (context.mounted) {
        _message(context.l10n.reconnectAccount);
      }
      return false;
    }
    return !account!.provider.isDav ||
        await ensureAndroidLocalNetworkAccess(context, account.authority);
  }

  Future<void> _showSubscription(WebCalSubscriptionEntity subscription) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?extraActions?.call(context),
              ListTile(
                title: Text(subscription.name),
                subtitle: Text(subscription.safeOrigin),
              ),
              for (final action in [
                'refresh',
                'rename',
                'color',
                'frequency',
                'remove',
              ])
                ListTile(
                  title: Text(switch (action) {
                    'refresh' => context.l10n.refreshCalendar,
                    'rename' => context.l10n.rename,
                    'color' => context.l10n.subscriptionColor,
                    'frequency' => context.l10n.subscriptionRefreshMode,
                    _ => context.l10n.unsubscribe,
                  }),
                  onTap: () => Navigator.pop(context, action),
                ),
            ],
          ),
        ),
      ),
    );
    if (action != null && context.mounted) {
      await _subscriptionAction(subscription, action);
    }
  }

  Future<void> _editCalendarSource(CalendarSourceEntity source) async {
    if (source.provider == BusyProvider.webCal) {
      final subscriptions = await ref.read(webCalSubscriptionsProvider.future);
      final subscription = subscriptions
          .where((s) => s.calendarSourceId == source.id)
          .firstOrNull;
      if (!context.mounted || subscription == null) {
        return;
      }
      await _showSubscription(subscription);
      return;
    }
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?extraActions?.call(context),
              ListTile(
                title: Text(source.summary),
                subtitle:
                    source.provider == BusyProvider.caldav &&
                        source.davEffectivePermissions['permissionsKnown'] ==
                            false
                    ? Text(context.l10n.davPermissionsUnknown)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(context.l10n.refreshCalendar),
                onTap: () => Navigator.pop(context, 'refresh'),
              ),
              if ([
                BusyProvider.google,
                BusyProvider.microsoft,
                BusyProvider.nextcloud,
              ].contains(source.provider))
                ListTile(
                  leading: const Icon(Icons.open_in_browser_outlined),
                  title: Text(context.l10n.openInProvider),
                  onTap: () => Navigator.pop(context, 'open'),
                ),
              if (source.davCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.toggle_on_outlined),
                  title: Text(context.l10n.collectionSettings),
                  onTap: () => Navigator.pop(context, 'enablement'),
                ),
              if (source.provider == BusyProvider.google)
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(context.l10n.showInGoogleCalendarList),
                  onTap: () => Navigator.pop(context, 'visibility'),
                ),
              if (source.provider == BusyProvider.nextcloud &&
                  source.davCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(context.l10n.nextcloudCollectionSettings),
                  onTap: () => Navigator.pop(context, 'metadata'),
                ),
              if (source.capabilities.canRenameCalendar)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(context.l10n.rename),
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
              if (source.capabilities.canChangeCalendarColor)
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(context.l10n.calendarColor),
                  onTap: () => Navigator.pop(context, 'color'),
                ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(context.l10n.reminders),
                onTap: () => Navigator.pop(context, 'reminders'),
              ),
              if (source.provider == BusyProvider.nextcloud &&
                  source.davCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: Text(context.l10n.nextcloudSchedulingInbox),
                  onTap: () => Navigator.pop(context, 'scheduling'),
                ),
              if (source.provider == BusyProvider.nextcloud &&
                  source.davCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(context.l10n.nextcloudSharing),
                  onTap: () => Navigator.pop(context, 'sharing'),
                ),
              if (source.capabilities.canExportCalendar)
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(context.l10n.export),
                  onTap: () => Navigator.pop(context, 'export'),
                ),
              if (source.capabilities.canRemoveCalendar)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(
                    source.capabilities.removalMode ==
                            CalendarRemovalMode.removeFromList
                        ? context.l10n.removeFromMyCalendars
                        : context.l10n.delete,
                  ),
                  textColor:
                      source.capabilities.removalMode ==
                          CalendarRemovalMode.delete
                      ? Theme.of(context).colorScheme.error
                      : null,
                  iconColor:
                      source.capabilities.removalMode ==
                          CalendarRemovalMode.delete
                      ? Theme.of(context).colorScheme.error
                      : null,
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null) {
      return;
    }
    try {
      if (action == 'refresh') {
        if (!await _networkReady(source.accountId)) {
          return;
        }
        if (context.mounted) {
          await refreshFromMaterial(
            context,
            ref,
            calendarSyncScope(source.accountId, source.id),
            openRecovery: () => _openRefreshRecovery(source.accountId),
          );
        }
      } else if (action == 'open') {
        final account = await ref
            .read(accountsRepositoryProvider)
            .accountById(source.accountId);
        final uri = account == null
            ? null
            : scheduleCalendarProviderWebUri(account, source);
        if (uri != null) {
          await openScheduleWebLink(uri.toString());
        }
      } else if (action == 'enablement') {
        if (!context.mounted) {
          return;
        }
        await _selectCalDavCollection(source.davCollectionId!);
      } else if (action == 'visibility') {
        if (!context.mounted) {
          return;
        }
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: AndroidCalendarProviderVisibility(source: source),
          ),
        );
      } else if (action == 'metadata') {
        if (!await _networkReady(source.accountId)) {
          return;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidNextcloudCollectionScreen(
              accountId: source.accountId,
              collectionId: source.davCollectionId!,
            ),
          ),
        );
      } else if (action == 'rename') {
        final name = await _textPrompt(
          title: l10n.calendar,
          label: l10n.setCustomCalendarName,
          initialValue: source.summary,
        );
        if (mounted && name != null && name != source.summary) {
          await ref
              .read(calendarRepositoryProvider)
              .renameLocalSource(source.id, name);
          _requestQueuedCalendarSync(source);
        }
      } else if (action == 'reminders') {
        final reminders = await _booleanPrompt(
          l10n.reminders,
          source.remindersEnabled,
        );
        if (reminders == null) {
          return;
        }
        await ref
            .read(calendarRepositoryProvider)
            .setSourceRemindersEnabled(source.id, reminders);
      } else if (action == 'color') {
        final choice = await _selectCalendarColor(source);
        if (choice == null) {
          return;
        }
        await ref
            .read(calendarRepositoryProvider)
            .setSourceColor(source.id, choice);
        _requestQueuedCalendarSync(source);
      } else if (action == 'export') {
        await _exportCollection(source.accountId, source.davCollectionId!);
      } else if (action == 'sharing') {
        if (!context.mounted || source.provider != BusyProvider.nextcloud) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidNextcloudSharingScreen(
              accountId: source.accountId,
              collectionId: source.davCollectionId!,
              title: source.summary,
            ),
          ),
        );
      } else if (action == 'scheduling') {
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidNextcloudSchedulingScreen(
              accountId: source.accountId,
              collectionId: source.davCollectionId!,
            ),
          ),
        );
      } else if (action == 'delete') {
        final remove =
            source.capabilities.removalMode ==
            CalendarRemovalMode.removeFromList;
        final openedMicrosoftOwner =
            remove && source.provider == BusyProvider.microsoft;
        final confirmed = await _confirm(
          remove ? l10n.removeFromMyCalendars : l10n.delete,
          remove
              ? openedMicrosoftOwner
                    ? l10n.removeOpenedSharedCalendarConfirmation(
                        source.summary,
                      )
                    : l10n.removeCalendarConfirmation(source.summary)
              : source.isMixedDavCollection
              ? l10n.nextcloudRemoveMixed
              : l10n.deleteCalendarConfirmation(source.summary),
          remove ? l10n.removeAction : l10n.delete,
        );
        if (!confirmed || !mounted) {
          return;
        }
        await ref.read(calendarRepositoryProvider).deleteLocalSource(source.id);
        if (!openedMicrosoftOwner) {
          _requestQueuedCalendarSync(source);
        }
      }
    } on Object catch (error) {
      if (localizedCollectionRefreshPending(l10n, error) case final warning?) {
        if (mounted) _message(warning);
        return;
      }
      if (error is DavException &&
          error.code == 'DavCollectionCreationPending') {
        _message(l10n.davCollectionCreationPending);
        return;
      }

      _message(
        l10n.calendarUpdateFailed(
          localizedSyncFailureMessage(
            l10n,
            error,
            networkUnavailableMessage: l10n.networkOfflineTryAgain,
          ),
        ),
      );
    }
  }

  Future<void> _editTaskList(
    TaskListEntity list,
    List<AccountEntity> accounts,
  ) async {
    final l10n = context.l10n;
    final account = accounts
        .where((item) => item.id == list.accountId)
        .firstOrNull;
    final davCapabilities = list.davCollectionId == null
        ? null
        : await ref.read(
            davTaskCollectionCapabilitiesProvider((
              accountId: list.accountId,
              taskListId: list.id,
            )).future,
          );
    if (!context.mounted) {
      return;
    }
    final capabilities = list.davCollectionId != null
        ? davCapabilities ?? noTaskCollectionCapabilities
        : account == null
        ? noTaskCollectionCapabilities
        : adapterDefaultTaskCapabilities(account.provider);
    final canRename = canRenameScheduleTaskList(
      account?.provider,
      list,
      davCapabilities,
    );
    final canDelete = canDeleteScheduleTaskList(
      account?.provider,
      list,
      davCapabilities,
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...?extraActions?.call(context),
              ListTile(title: Text(list.title)),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(context.l10n.refreshList),
                onTap: () => Navigator.pop(context, 'refresh'),
              ),
              if (account != null &&
                  scheduleTaskProviderWebUri(account) != null)
                ListTile(
                  leading: const Icon(Icons.open_in_browser_outlined),
                  title: Text(context.l10n.openInProvider),
                  onTap: () => Navigator.pop(context, 'open'),
                ),
              if (account?.provider == BusyProvider.nextcloud &&
                  list.davCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(context.l10n.nextcloudCollectionSettings),
                  onTap: () => Navigator.pop(context, 'metadata'),
                ),
              if (list.davCollectionId != null)
                ListTile(
                  leading: const Icon(Icons.toggle_on_outlined),
                  title: Text(context.l10n.collectionSettings),
                  onTap: () => Navigator.pop(context, 'enablement'),
                ),
              if (capabilities.supportsClearCompleted)
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(context.l10n.clearCompleted),
                  onTap: () => Navigator.pop(context, 'clearCompleted'),
                ),
              if (canRename)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(context.l10n.rename),
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(context.l10n.reminders),
                onTap: () => Navigator.pop(context, 'reminders'),
              ),
              if (account?.provider == BusyProvider.nextcloud &&
                  list.davCollectionId != null &&
                  capabilities.supportsSharing)
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(context.l10n.nextcloudSharing),
                  onTap: () => Navigator.pop(context, 'sharing'),
                ),
              if (list.davCollectionId != null &&
                  capabilities.supportsNativeExport)
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(context.l10n.export),
                  onTap: () => Navigator.pop(context, 'export'),
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(context.l10n.deleteList),
                  textColor: Theme.of(context).colorScheme.error,
                  iconColor: Theme.of(context).colorScheme.error,
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null) {
      return;
    }
    try {
      if (action == 'metadata') {
        if (!await _networkReady(list.accountId) || !context.mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidNextcloudCollectionScreen(
              accountId: list.accountId,
              collectionId: list.davCollectionId!,
            ),
          ),
        );
      } else if (action == 'refresh') {
        if (!await _networkReady(list.accountId)) {
          return;
        }
        if (context.mounted) {
          await refreshFromMaterial(
            context,
            ref,
            taskListSyncScope(list.accountId, list.id),
            openRecovery: () => _openRefreshRecovery(list.accountId),
          );
        }
      } else if (action == 'open' && account != null) {
        await openScheduleWebLink(
          scheduleTaskProviderWebUri(account)!.toString(),
        );
      } else if (action == 'enablement') {
        if (!context.mounted) {
          return;
        }
        await _selectCalDavCollection(list.davCollectionId!);
      } else if (action == 'clearCompleted') {
        final repository = ref.read(
          tasksRepositoryForAccountProvider(list.accountId),
        );
        final count = await repository.countClearCompleted(list.id);
        if (!context.mounted || account == null) {
          return;
        }
        final confirmed = await _confirm(
          l10n.clearCompleted,
          account.provider == BusyProvider.google
              ? l10n.clearCompletedGoogleConfirmation(
                  list.title,
                  account.displayLabel,
                  count,
                )
              : l10n.clearCompletedNextcloudConfirmation(
                  list.title,
                  account.displayLabel,
                  count,
                ),
          l10n.clearCompleted,
        );
        if (confirmed && context.mounted) {
          await repository.clearCompleted(list.id);
        }
      } else if (action == 'rename') {
        final name = await _textPrompt(
          title: l10n.taskLists,
          label: l10n.list,
          initialValue: list.title,
        );
        if (mounted && name != null && name != list.title) {
          await ref
              .read(taskListsRepositoryForAccountProvider(list.accountId))
              .renameTaskList(list.id, name);
        }
      } else if (action == 'reminders') {
        final reminders = await _booleanPrompt(
          l10n.reminders,
          list.remindersEnabled,
        );
        if (reminders == null) {
          return;
        }
        await ref
            .read(taskListsRepositoryForAccountProvider(list.accountId))
            .setRemindersEnabled(list.id, reminders);
      } else if (action == 'export') {
        await _exportCollection(list.accountId, list.davCollectionId!);
      } else if (action == 'sharing') {
        if (!context.mounted ||
            account?.provider != BusyProvider.nextcloud ||
            !capabilities.supportsSharing) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidNextcloudSharingScreen(
              accountId: list.accountId,
              collectionId: list.davCollectionId!,
              title: list.title,
            ),
          ),
        );
      } else if (action == 'delete') {
        final confirmed = await _confirm(
          l10n.deleteList,
          list.isMixedDavCollection
              ? l10n.nextcloudRemoveMixed
              : l10n.deleteTaskListConfirmation(list.title),
          l10n.delete,
        );
        if (!confirmed) {
          return;
        }
        await ref
            .read(taskListsRepositoryForAccountProvider(list.accountId))
            .deleteTaskList(list.id);
      }
    } on Object catch (error) {
      if (localizedCollectionRefreshPending(l10n, error) case final warning?) {
        if (mounted) _message(warning);
        return;
      }
      if (error is DavException &&
          error.code == 'DavCollectionCreationPending') {
        _message(l10n.davCollectionCreationPending);
        return;
      }

      _message(
        l10n.taskListRenameFailed(
          syncFailureMessage(
            error,
            networkUnavailableMessage: l10n.networkOfflineTryAgain,
          ),
        ),
      );
    }
  }

  Future<CalendarColorChoice?> _selectCalendarColor(
    CalendarSourceEntity source,
  ) {
    final choices = calendarColorChoices(source.provider);
    return showModalBottomSheet<CalendarColorChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(context.l10n.calendarColor)),
            for (var index = 0; index < choices.length; index++)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorFromHex(
                    choices[index].backgroundColor,
                  ),
                ),
                title: Text(context.l10n.calendarColorOption(index + 1)),
                trailing:
                    choices[index].backgroundColor.toLowerCase() ==
                        source.backgroundColor?.toLowerCase()
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, choices[index]),
              ),
          ],
        ),
      ),
    );
  }

  void _requestQueuedCalendarSync(CalendarSourceEntity source) {
    if (source.provider != BusyProvider.google &&
        source.provider != BusyProvider.microsoft) {
      return;
    }
    ref
        .read(
          pendingCalendarMutationSyncRequesterForAccountProvider(
            source.accountId,
          ),
        )
        .request();
  }

  Future<void> _exportCollection(String accountId, String collectionId) async {
    final l10n = context.l10n;
    final resources = await ref
        .read(nextcloudNativeExportServiceProvider)
        .collection(accountId, collectionId);
    final folder = await BusyMaxAndroidPlatform.instance.exportDocumentTree(
      folderName:
          'BusyMax-export-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      resources: [
        for (var index = 0; index < resources.length; index++)
          AndroidExportResource(
            name: 'resource-${index + 1}.ics',
            bytes: Uint8List.fromList(utf8.encode(resources[index].rawIcs)),
          ),
      ],
    );
    if (folder != null) {
      _message(l10n.exportedFile(folder));
    }
  }

  Future<String?> _textPrompt({
    required String title,
    required String label,
    String? initialValue,
    String? helper,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _AndroidTextPromptDialog(
        title: title,
        label: label,
        initialValue: initialValue,
        helper: helper,
      ),
    );
  }

  Future<bool?> _booleanPrompt(String title, bool value) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: RadioGroup<bool>(
        groupValue: value,
        onChanged: (selected) => Navigator.pop(dialogContext, selected),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<bool>(value: true, title: Text(context.l10n.onState)),
            RadioListTile<bool>(value: false, title: Text(context.l10n.off)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.cancel),
        ),
      ],
    ),
  );

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class AndroidCalendarProviderVisibility extends ConsumerStatefulWidget {
  const AndroidCalendarProviderVisibility({
    super.key,
    required this.source,
    this.showSourceName = true,
  });
  final CalendarSourceEntity source;
  final bool showSourceName;
  @override
  ConsumerState<AndroidCalendarProviderVisibility> createState() =>
      _AndroidCalendarProviderVisibilityState();
}

class _AndroidCalendarProviderVisibilityState
    extends ConsumerState<AndroidCalendarProviderVisibility> {
  bool _busy = false;
  Future<void> _resolve(String id, String requestJson, bool discard) async {
    if (_busy) {
      return;
    }
    if (discard) {
      final request = jsonDecode(requestJson) as Map;
      final fields = [
        if (request.containsKey('summary')) context.l10n.title,
        if (request.containsKey('colorId') ||
            request.containsKey('backgroundColor'))
          context.l10n.calendarColor,
        if (request.containsKey('hidden'))
          context.l10n.showInGoogleCalendarList,
      ];
      final confirmed = await _AndroidSourceActions(context, ref)._confirm(
        context.l10n.discardPendingOperation,
        context.l10n.discardCalendarSettingsConfirmation(
          widget.source.summary,
          fields.map((f) => '• $f').join('\n'),
        ),
        context.l10n.discard,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final service = ref.read(
        pendingOpResolutionServiceForAccountProvider(widget.source.accountId),
      );
      if (discard) {
        await service.discard(id);
      } else {
        await service.retryNow(id);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources =
        ref.watch(calendarSourcesStreamProvider).valueOrNull ??
        const <CalendarSourceEntity>[];
    final source =
        sources.where((s) => s.id == widget.source.id).firstOrNull ??
        widget.source;
    final operation = ref.watch(calendarVisibilityOperationProvider(source.id));
    final pending = operation.valueOrNull;
    final failed =
        pending != null &&
        (pending.lastErrorCode != null ||
            !['pending', 'in_progress'].contains(pending.state));
    var hidden = source.hidden;
    if (failed) {
      final request = jsonDecode(pending.requestJson) as Map;
      final previous = request[calendarPatchPreviousValuesKey];
      final baseline = jsonDecode(pending.baselineRawJson ?? '{}') as Map;
      hidden = previous is Map && previous['hidden'] is bool
          ? previous['hidden'] as bool
          : baseline['hidden'] == true;
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: Text(context.l10n.showInGoogleCalendarList),
            subtitle: widget.showSourceName ? Text(source.summary) : null,
            value: !hidden,
            onChanged:
                !source.capabilities.canChangeProviderVisibility ||
                    failed ||
                    _busy ||
                    operation.isLoading ||
                    operation.hasError
                ? null
                : (visible) async {
                    setState(() => _busy = true);
                    try {
                      await ref
                          .read(calendarRepositoryProvider)
                          .setSourceProviderHidden(source.id, !visible);
                      ref
                          .read(
                            pendingCalendarMutationSyncRequesterForAccountProvider(
                              source.accountId,
                            ),
                          )
                          .request();
                    } on Object catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$error')));
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _busy = false);
                      }
                    }
                  },
          ),
          if (operation.isLoading || _busy) const LinearProgressIndicator(),
          if (operation.hasError)
            TextButton(
              onPressed: () => ref.invalidate(
                calendarVisibilityOperationProvider(source.id),
              ),
              child: Text(context.l10n.retry),
            ),
          if (pending != null)
            Text(
              failed
                  ? context.l10n.calendarRemoteFailed
                  : context.l10n.calendarRemotePending,
            ),
          if (failed)
            Wrap(
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _resolve(pending.id, pending.requestJson, false),
                  child: Text(context.l10n.retry),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _resolve(pending.id, pending.requestJson, true),
                  child: Text(context.l10n.discard),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

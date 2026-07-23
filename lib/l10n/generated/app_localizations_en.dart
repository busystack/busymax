// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Connect Google and Microsoft accounts to sync calendars and tasks.';

  @override
  String get googlePermissionsConsentNotice =>
      'On the Google permission screen, select both Calendar and Tasks permissions.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google Calendar and Google Tasks permissions are required. Please try again and select both checkboxes.';

  @override
  String get finishSetup => 'Finish setup';

  @override
  String get continueSetup => 'Continue';

  @override
  String get onboardingSetupTitle => 'Set Up BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Connect accounts';

  @override
  String get onboardingAccountsStepDescription =>
      'Add all Google and Microsoft accounts you want to use. BusyMax syncs calendars, events, task lists, and tasks from each account.';

  @override
  String get onboardingPreferencesStepTitle => 'Choose system settings';

  @override
  String get onboardingPreferencesStepDescription =>
      'Set desktop behavior, reminders, notification detail, and appearance before opening your schedule.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithMicrosoft => 'Sign in with Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'This provider is not configured.';

  @override
  String get waitingForGoogleSignIn => 'Waiting for Google sign-in...';

  @override
  String get waitingForMicrosoftSignIn => 'Waiting for Microsoft sign-in...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsoft sign-in is not configured. Set MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get exit => 'Exit';

  @override
  String get options => 'Options';

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get export => 'Export';

  @override
  String get save => 'Save';

  @override
  String get settings => 'Settings';

  @override
  String get all => 'All';

  @override
  String get calendarEvents => 'Events';

  @override
  String get calendarTasks => 'Tasks';

  @override
  String get calendar => 'Calendar';

  @override
  String get calendars => 'Calendars';

  @override
  String get newEvent => 'New event';

  @override
  String get refreshCalendar => 'Refresh calendar';

  @override
  String get openInProvider => 'Open in provider';

  @override
  String get hideFromSchedule => 'Hide from schedule';

  @override
  String get showInSchedule => 'Show in schedule';

  @override
  String get noCalendarsSynced => 'No calendars synced yet.';

  @override
  String get allDay => 'All day';

  @override
  String moreItems(int count) {
    return '+$count more';
  }

  @override
  String get noEventsOrTasks => 'No events or tasks';

  @override
  String get scheduleLoading => 'Loading schedule...';

  @override
  String get scheduleUnavailable => 'Schedule unavailable';

  @override
  String get scheduleNoSources => 'No visible calendars or task lists';

  @override
  String get scheduleNoSourcesDescription =>
      'Choose what to show in Settings, then refresh.';

  @override
  String get scheduleSignInRequired => 'Connect an account';

  @override
  String get scheduleSignInDescription =>
      'Sign in to sync calendars and tasks.';

  @override
  String get scheduleNoSearchResults => 'No matching events or tasks';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Try a different search or clear the current filters.';

  @override
  String get trayAgendaLoading => 'Loading agenda...';

  @override
  String get trayAgendaSignInRequired => 'Sign in to show agenda.';

  @override
  String get trayAgendaNoSources => 'No visible calendars or task lists.';

  @override
  String get trayAgendaOpenBusyMax => 'Open app';

  @override
  String get trayAgendaRefresh => 'Refresh';

  @override
  String get trayAgendaError => 'Agenda unavailable';

  @override
  String get compactAgendaTitle => 'Agenda';

  @override
  String get compactAgendaSubtitle => 'Upcoming';

  @override
  String get compactAgendaOverdue => 'Overdue';

  @override
  String get compactAgendaClear => 'Clear for now';

  @override
  String get compactAgendaOpenBusyMax => 'Open BusyMax';

  @override
  String get compactAgendaHide => 'Hide';

  @override
  String get compactAgendaNewTask => 'New task';

  @override
  String get compactAgendaRetry => 'Retry';

  @override
  String get compactAgendaRefresh => 'Refresh';

  @override
  String get compactAgendaAllDay => 'All day';

  @override
  String get compactAgendaDueToday => 'Due today';

  @override
  String get compactAgendaDueTomorrow => 'Due tomorrow';

  @override
  String compactAgendaDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get compactAgendaMoreOverdue => 'Load more overdue tasks';

  @override
  String get agendaLoadMoreOverdue => 'Load more overdue tasks';

  @override
  String get agendaLoadMoreNoDate => 'Load more no-date tasks';

  @override
  String get viewDay => 'Day';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewMonth => 'Month';

  @override
  String get viewYear => 'Year';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get scheduleSettings => 'Schedule';

  @override
  String get scheduleDisplaySettings => 'Schedule display';

  @override
  String get scheduleDisplayHoursDescription =>
      'Day and Week views open within these hours. Early and late items expand the range when needed.';

  @override
  String get scheduleDayStartsAt => 'Day starts at';

  @override
  String get scheduleDayEndsAt => 'Day ends at';

  @override
  String get sourceCalendar => 'Calendar';

  @override
  String get sourceTaskList => 'Task list';

  @override
  String get createChoiceTitle => 'Create';

  @override
  String get createEventAtTime => 'Event';

  @override
  String get createTaskAtDate => 'Task';

  @override
  String get editEvent => 'Edit event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get location => 'Location';

  @override
  String get timeSlot => 'Time slot';

  @override
  String get timeMode => 'Time';

  @override
  String get timeModeDescription => 'Use dates only or set specific times.';

  @override
  String get startDateTime => 'Start date/time';

  @override
  String get endDateTime => 'End date/time';

  @override
  String get doesNotRepeat => 'Does not repeat';

  @override
  String get defaultReminder => 'Default reminder';

  @override
  String get guests => 'Guests';

  @override
  String get noGuests => 'No guests';

  @override
  String get description => 'Description';

  @override
  String get availabilityShowAs => 'Availability / Show as';

  @override
  String get busy => 'Busy';

  @override
  String get visibility => 'Visibility';

  @override
  String get defaultVisibility => 'Default visibility';

  @override
  String get conference => 'Conference';

  @override
  String get noConference => 'No conference';

  @override
  String get providerCalendar => 'Provider calendar';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => 'Bold';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'Italic';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'Underline';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes before',
      one: '1 minute before',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'At start';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Free';

  @override
  String get availabilityTentative => 'Tentative';

  @override
  String get availabilityOutOfOffice => 'Out of office';

  @override
  String get availabilityWorkingElsewhere => 'Working elsewhere';

  @override
  String get visibilityDefault => 'Default';

  @override
  String get visibilityPublic => 'Public';

  @override
  String get visibilityPrivate => 'Private';

  @override
  String get visibilityConfidential => 'Confidential';

  @override
  String get sensitivityNormal => 'Normal';

  @override
  String get sensitivityPersonal => 'Personal';

  @override
  String get tasks => 'Tasks';

  @override
  String get allTasks => 'All tasks';

  @override
  String tasksInList(String title) {
    return 'Tasks in $title';
  }

  @override
  String get taskLists => 'Task lists';

  @override
  String get navigation => 'Navigation';

  @override
  String get mainMenu => 'Main Menu';

  @override
  String get keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get shortcutGroupGeneral => 'General';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Show this shortcuts reference';

  @override
  String get shortcutGroupNavigation => 'Navigation';

  @override
  String get shortcutNextPeriod => 'Next period';

  @override
  String get shortcutNextPeriodDescription =>
      'Next week in week view, next month in month view, and so on';

  @override
  String get shortcutPreviousPeriod => 'Previous period';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Previous week in week view, previous month in month view, and so on';

  @override
  String get shortcutJumpToToday => 'Jump to today';

  @override
  String get shortcutGroupView => 'View';

  @override
  String get shortcutDayView => 'Day view';

  @override
  String get shortcutWeekView => 'Week view';

  @override
  String get shortcutMonthView => 'Month view';

  @override
  String get shortcutYearView => 'Year view';

  @override
  String get shortcutAgendaView => 'Agenda view';

  @override
  String get shortcutGroupCreateAndEdit => 'Create and Edit';

  @override
  String get shortcutSaveItem => 'Save event or task';

  @override
  String get shortcutDeleteItem => 'Delete event or task';

  @override
  String get shortcutGroupTaskEditing => 'Task editing';

  @override
  String get shortcutCancelEditing => 'Cancel editing';

  @override
  String get shortcutCancelEditingDescription =>
      'Close task editing or task details';

  @override
  String get shortcutGroupCompactAgenda => 'Compact agenda';

  @override
  String get shortcutRefreshCompactAgendaDescription =>
      'Refresh the compact agenda window';

  @override
  String get shortcutHideCompactAgendaDescription =>
      'Hide the compact agenda window';

  @override
  String get aboutBusyMax => 'About BusyMax';

  @override
  String get aboutBusyMaxDescription => 'ToDo and Calendar';

  @override
  String get website => 'Website';

  @override
  String get reportAnIssue => 'Report an issue';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get feedbackSubmit => 'Submit';

  @override
  String get feedbackCategory => 'Category';

  @override
  String get feedbackSelectCategory => 'Select a category';

  @override
  String get feedbackCategoryProblem => 'Problem or bug';

  @override
  String get feedbackCategoryFeature => 'Feature request';

  @override
  String get feedbackCategoryPrivacySecurity => 'Privacy or security concern';

  @override
  String get feedbackCategoryUsability => 'Usability concern';

  @override
  String get feedbackCategoryOther => 'Other';

  @override
  String get feedbackSubject => 'Subject';

  @override
  String get feedbackDetailedMessage => 'Detailed message';

  @override
  String get feedbackReplyEmail => 'Reply email (optional)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Include technical details';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Adds only your Linux operating-system version and application locale. No logs, account data, file names, or other diagnostics are included.';

  @override
  String get feedbackCategoryRequired => 'Select a category.';

  @override
  String get feedbackSubjectLengthError =>
      'Subject must be between 3 and 120 characters.';

  @override
  String get feedbackMessageLengthError =>
      'Message must be between 10 and 5,000 characters.';

  @override
  String get feedbackInvalidEmail => 'Enter a valid email address.';

  @override
  String get feedbackConnectionError =>
      'Could not connect to BusyStack. Check your connection and try again.';

  @override
  String get feedbackTimeoutError =>
      'The request timed out. Your feedback has not been cleared; please try again.';

  @override
  String get feedbackRateLimitedError =>
      'Too many feedback submissions have been sent from this network. Please wait and try again.';

  @override
  String get feedbackRejectedError =>
      'The server rejected the submission. Review the fields and try again.';

  @override
  String get feedbackServerError =>
      'BusyStack could not accept your feedback right now. Your feedback has not been cleared; please try again.';

  @override
  String feedbackSuccess(String id) {
    return 'Feedback sent. Reference: $id';
  }

  @override
  String get toggleSidebar => 'Toggle Sidebar';

  @override
  String get accounts => 'Accounts';

  @override
  String get currentAccount => 'Current account';

  @override
  String get switchAccount => 'Switch account';

  @override
  String get addGoogleAccount => 'Add Google account';

  @override
  String get addMicrosoftAccount => 'Add Microsoft account';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Signed in';

  @override
  String get signOutThisAccount => 'Sign out this account';

  @override
  String get revokeThisAccount => 'Revoke this account';

  @override
  String get disconnectThisAccount => 'Disconnect this account';

  @override
  String get deleteLocalDataForThisAccount =>
      'Delete local data for this account';

  @override
  String get newList => 'New list';

  @override
  String get signInToViewTaskLists => 'Sign in to view task lists.';

  @override
  String get noTaskListsSynced => 'No task lists synced yet.';

  @override
  String get listActions => 'List actions';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get renameList => 'Rename list';

  @override
  String get deleteList => 'Delete list';

  @override
  String get builtInMicrosoftList => 'Built-in';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Built-in Microsoft To Do lists cannot be renamed or deleted.';

  @override
  String deleteListConfirmation(String title) {
    return 'Delete \"$title\" from Google Tasks?';
  }

  @override
  String get deleteEvent => 'Delete Event';

  @override
  String get title => 'Title';

  @override
  String get create => 'Create';

  @override
  String get newTask => 'New task';

  @override
  String get clearCompleted => 'Clear completed';

  @override
  String get refreshList => 'Refresh list';

  @override
  String get refreshAll => 'Refresh all';

  @override
  String get listRefreshed => 'List refreshed.';

  @override
  String get allTasksRefreshed => 'All accounts refreshed.';

  @override
  String exportedFile(String path) {
    return 'Exported to $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get selectOrCreateTaskList => 'Select or create a task list to begin.';

  @override
  String get signInToViewTasks => 'Sign in to view tasks.';

  @override
  String get noTasks => 'No tasks.';

  @override
  String get noTasksYet => 'No tasks yet';

  @override
  String get noTasksYetMessage =>
      'Create a task or refresh your accounts to get started.';

  @override
  String get noTasksInList => 'No tasks in this list.';

  @override
  String get overdue => 'Overdue';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get noDate => 'No date';

  @override
  String get completed => 'Completed';

  @override
  String duePrefix(String date) {
    return 'Due $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get searchTasks => 'Search tasks';

  @override
  String get advancedFilters => 'Advanced filters';

  @override
  String get showCompleted => 'Show completed';

  @override
  String get showHidden => 'Show hidden';

  @override
  String get showAssigned => 'Show assigned';

  @override
  String get taskDetails => 'Task details';

  @override
  String get editTask => 'Edit Task';

  @override
  String get noTaskSelected => 'No task selected.';

  @override
  String get noTaskSelectedHelper => 'Select a task to view and edit details.';

  @override
  String get taskUnavailable => 'Task unavailable.';

  @override
  String get signInToEditTasks => 'Sign in to edit tasks.';

  @override
  String get refreshTask => 'Refresh task';

  @override
  String get primarySection => 'Primary';

  @override
  String get statusSection => 'Status';

  @override
  String get openStatus => 'Open';

  @override
  String get doneStatus => 'Done';

  @override
  String get notes => 'Notes';

  @override
  String get dueDate => 'Due date';

  @override
  String get clearDueDate => 'Clear due date';

  @override
  String get dueTime => 'Due time';

  @override
  String get startDate => 'Start date';

  @override
  String get startTime => 'Start time';

  @override
  String get endDate => 'End Date';

  @override
  String get endTime => 'End Time';

  @override
  String get reminderDate => 'Reminder date';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get reminder => 'Reminder';

  @override
  String get addReminder => 'Add Reminder';

  @override
  String get addGuest => 'Add Guest';

  @override
  String get addGuestEmail => 'Add guest email';

  @override
  String get removeReminder => 'Remove reminder';

  @override
  String get off => 'Off';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatNone => 'None';

  @override
  String get noneValue => 'None';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get repeatYearly => 'Yearly';

  @override
  String get importance => 'Importance';

  @override
  String get importanceLow => 'Low';

  @override
  String get importanceNormal => 'Normal';

  @override
  String get importanceHigh => 'High';

  @override
  String get categories => 'Categories';

  @override
  String get scheduleSection => 'Schedule';

  @override
  String get dueGroup => 'Due';

  @override
  String get startGroup => 'Start';

  @override
  String get reminderGroup => 'Reminder';

  @override
  String get organizationSection => 'Organization';

  @override
  String get actionsSection => 'Actions';

  @override
  String get advancedSection => 'Advanced';

  @override
  String get addCategory => 'Add category';

  @override
  String get list => 'List';

  @override
  String get microsoftMoveUnsupported =>
      'Moving between lists is not supported for Microsoft To Do accounts in this version.';

  @override
  String get createSubtask => 'Create subtask';

  @override
  String get moveToTop => 'Move to top';

  @override
  String get deleteTask => 'Delete Task';

  @override
  String get newSubtask => 'New subtask';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Delete \"$title\" from Google Tasks?';
  }

  @override
  String get metadata => 'Metadata';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Updated';

  @override
  String get parent => 'Parent';

  @override
  String get position => 'Position';

  @override
  String get webLink => 'Web link';

  @override
  String get assignment => 'Assignment';

  @override
  String get localState => 'Local state';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get synced => 'Synced';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get revokeGoogleAuthorization => 'Revoke Google authorization';

  @override
  String get deleteLocalData => 'Delete local data';

  @override
  String get deleteLocalDataConfirmation =>
      'This removes the local account, synced tasks, and pending offline changes from this device.';

  @override
  String get sync => 'Sync';

  @override
  String get manualFullSync => 'Manual full sync';

  @override
  String get runInBackgroundWhenClosed =>
      'Continue running when the window is closed';

  @override
  String get showTrayIcon => 'Show tray icon';

  @override
  String get startMinimizedToTray => 'Start minimized to the tray';

  @override
  String get requiresTrayIcon => 'Requires the tray icon.';

  @override
  String get syncComplete => 'Sync complete.';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get notifySyncFailures => 'Notifications on sync failure';

  @override
  String get notifyConflicts => 'Notifications on conflicts';

  @override
  String get notifyDueToday => 'Due-today notifications';

  @override
  String get eventReminders => 'Event reminders';

  @override
  String get taskReminders => 'Task reminders';

  @override
  String get notificationDetailLevel => 'Notification detail level';

  @override
  String get notificationDetailPrivate => 'Private';

  @override
  String get notificationDetailNormal => 'Normal';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietHoursDescription => 'Pause notifications during this period.';

  @override
  String get quietHoursStart => 'Quiet hours start';

  @override
  String get quietHoursEnd => 'Quiet hours end';

  @override
  String get notifications => 'Notifications';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeFamily => 'Theme family';

  @override
  String get themeFamilyYaru => 'Native Ubuntu (Yaru)';

  @override
  String get localization => 'Localization';

  @override
  String get currentLocale => 'Current locale';

  @override
  String get privacy => 'Privacy';

  @override
  String get redactTaskContentInDiagnostics =>
      'Redact task content in diagnostics';

  @override
  String get developerDiagnostics => 'Developer diagnostics';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get apiInspectorDisabled => 'Show API inspector';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery revision: $revision';
  }

  @override
  String get implementedMethods => 'Implemented methods';

  @override
  String get supportsTasksScopes => 'Supports tasks and tasks.readonly scopes';

  @override
  String get requiresTasksScope => 'Requires tasks scope';

  @override
  String get blockedPendingOperations => 'Blocked pending operations';

  @override
  String get signInToInspectPendingOperations =>
      'Sign in to inspect pending operations.';

  @override
  String get noBlockedPendingOperations => 'No blocked pending operations.';

  @override
  String get operationActions => 'Operation actions';

  @override
  String pendingOpListId(String id) {
    return 'list=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'task=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'attempts=$count';
  }

  @override
  String get retry => 'Retry';

  @override
  String get discard => 'Discard';

  @override
  String get discardChanges => 'Discard changes?';

  @override
  String get discardChangesConfirmation =>
      'This discards unsaved edits to this task.';

  @override
  String get retryCompleted => 'Retry completed.';

  @override
  String get discardPendingOperation => 'Discard pending operation?';

  @override
  String get discardPendingOperationConfirmation =>
      'This removes the blocked local operation. The next sync will refresh from Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Pending operation discarded.';

  @override
  String get syncFailureNotificationTitle => 'BusyMax sync failed';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Background sync failed. $message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax sync conflict';

  @override
  String conflictNotificationBody(String summary) {
    return 'A pending local change was blocked. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Tasks due today';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks are due today.',
      one: 'One task is due today.',
    );
    return '$_temp0';
  }

  @override
  String get notificationDetailsHidden =>
      'Details are hidden by privacy settings.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get openMonthView => 'Open month view';

  @override
  String get previousYear => 'Previous year';

  @override
  String get nextYear => 'Next year';

  @override
  String get openYearView => 'Open year view';

  @override
  String weekNumberTooltip(int number) {
    return 'Week $number';
  }

  @override
  String get resizeAllDayPanel => 'Resize the all-day panel';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'This calendar is read-only.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Delete \"$title\"?';
  }
}

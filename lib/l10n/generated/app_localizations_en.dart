// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

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
      'Connect Google, Microsoft, Apple iCloud Calendar, or Nextcloud accounts.';

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
      'Add every account you want to use. BusyMax syncs supported calendars, events, task lists, and tasks from each account.';

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
  String get newCalendar => 'New calendar';

  @override
  String get calendarColor => 'Calendar color';

  @override
  String calendarColorOption(int number) {
    return 'Color $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'This provider does not support calendar management in BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'The primary calendar cannot be deleted.';

  @override
  String calendarCreateFailed(String error) {
    return 'Could not create the calendar: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'The calendar was created, but BusyMax could not refresh the account. It will appear after the next sync.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Could not update the calendar: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Could not delete the calendar: $error';
  }

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
  String get refresh => 'Refresh';

  @override
  String get trayOpenBusyMax => 'Open BusyMax';

  @override
  String get trayShowBusyMax => 'Show BusyMax';

  @override
  String get trayNewEvent => 'New event…';

  @override
  String get trayNewTask => 'New task…';

  @override
  String get trayToday => 'Today';

  @override
  String get trayAllDay => 'All day';

  @override
  String get trayNow => 'Now';

  @override
  String get trayCalendarEvent => 'Calendar event';

  @override
  String get trayUntitledEvent => 'Untitled event';

  @override
  String get trayNothingElseToday => 'Nothing else today';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks due today',
      one: '1 task due today',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Open today’s agenda';

  @override
  String get traySyncNow => 'Sync now';

  @override
  String get traySyncing => 'Syncing…';

  @override
  String get trayNotConnected => 'Not connected';

  @override
  String get trayNotYetSynced => 'Not yet synced';

  @override
  String get trayLastSyncedJustNow => 'Last synced just now';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $count minutes ago',
      one: 'Last synced 1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $count hours ago',
      one: 'Last synced 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $count days ago',
      one: 'Last synced 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Settings';

  @override
  String get trayQuitBusyMax => 'Quit BusyMax';

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
  String get attendeeRequired => 'Required';

  @override
  String get attendeeOptional => 'Optional';

  @override
  String get meetingSection => 'Meeting';

  @override
  String get addGoogleMeet => 'Add Google Meet';

  @override
  String get addTeamsMeeting => 'Add Microsoft Teams meeting';

  @override
  String get onlineMeetingAdded => 'Online meeting added';

  @override
  String get requestResponses => 'Request responses';

  @override
  String get requestResponsesDescription =>
      'Ask guests to respond to the invitation.';

  @override
  String get hideGuestList => 'Hide guest list';

  @override
  String get hideGuestListDescription =>
      'Guests cannot see who else was invited.';

  @override
  String get allowNewTimeProposals => 'Allow new time proposals';

  @override
  String get allowNewTimeProposalsDescription =>
      'Guests can suggest a different meeting time.';

  @override
  String get notifyGuestsTitle => 'Notify guests?';

  @override
  String get notifyGuestsSaveMessage =>
      'This meeting has guests. Send invitations or event updates when it is saved?';

  @override
  String get notifyGuestsDeleteMessage =>
      'This meeting has guests. Send a cancellation when it is deleted?';

  @override
  String get sendUpdates => 'Send updates';

  @override
  String get sendCancellation => 'Send cancellation';

  @override
  String get doNotSend => 'Don’t send';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Save meeting?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft will send invitations or event updates to guests.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Delete meeting?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft will send a cancellation to guests.';

  @override
  String get organizer => 'Organizer';

  @override
  String get yourResponse => 'Your response';

  @override
  String get guestResponses => 'Guest responses';

  @override
  String get respond => 'Respond';

  @override
  String get acceptInvitation => 'Accept';

  @override
  String get tentativeInvitation => 'Tentative';

  @override
  String get declineInvitation => 'Decline';

  @override
  String get joinMeeting => 'Join meeting';

  @override
  String get responseAccepted => 'Accepted';

  @override
  String get responseTentative => 'Tentative';

  @override
  String get responseDeclined => 'Declined';

  @override
  String get responseNeedsAction => 'Awaiting response';

  @override
  String get responseNotResponded => 'Not responded';

  @override
  String get responseOrganizer => 'Organizer';

  @override
  String invitationResponseFailed(String error) {
    return 'Could not send your response: $error';
  }

  @override
  String get joinMeetingFailed => 'Could not open the meeting link.';

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
  String get aboutBusyMax => 'About BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Calendar and tasks';

  @override
  String get license => 'License';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Website';

  @override
  String get sourceCode => 'Source code';

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
  String get showSidebar => 'Show sidebar panel';

  @override
  String get hideSidebar => 'Hide sidebar panel';

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
  String get removeAccount => 'Remove account…';

  @override
  String get removingAccount => 'Removing account…';

  @override
  String get removeAccountDescription =>
      'Stop syncing and remove this account’s data from this device.';

  @override
  String removeAccountTitle(String account) {
    return 'Remove $account from BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Provider copies of calendars, events, task lists, and tasks are not deleted.';

  @override
  String get revokeGoogleAccess =>
      'Also revoke BusyMax’s access to this Google Account';

  @override
  String get revokeGoogleAccessDescription =>
      'You will need to grant access again before reconnecting.';

  @override
  String get removeAccountAction => 'Remove account';

  @override
  String get removeAccountFailed =>
      'Could not finish removing the account. Try again.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'The account was removed from this device, but BusyMax could not revoke Google access. You can revoke it from your Google Account.';

  @override
  String get newTaskList => 'New task list';

  @override
  String taskListCreateFailed(String error) {
    return 'Could not create the task list: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Could not rename the task list: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Could not delete the task list: $error';
  }

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
  String get unshare => 'Unshare';

  @override
  String get readOnlyTaskListCannotRename =>
      'This task list is read-only and cannot be renamed.';

  @override
  String get taskListCannotDelete =>
      'This task list cannot be deleted with your current permissions.';

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
  String deleteTaskListConfirmation(String title) {
    return 'Delete \"$title\" and all of its tasks?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Unshare \"$title\" from this account?';
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
  String get taskStatus => 'Status';

  @override
  String get taskStatusNone => 'No status';

  @override
  String get taskStatusNeedsAction => 'Needs action';

  @override
  String get taskStatusInProcess => 'In progress';

  @override
  String get taskStatusCompleted => 'Completed';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String completionPercent(int percent) {
    return '$percent% completed';
  }

  @override
  String get completionDate => 'Completion date';

  @override
  String get priority => 'Priority';

  @override
  String get priorityNone => 'No priority';

  @override
  String priorityHighValue(int priority) {
    return 'Priority $priority · High';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Priority $priority · Medium';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Priority $priority · Low';
  }

  @override
  String get taskUrl => 'URL';

  @override
  String get invalidTaskUrl => 'Enter an absolute URL, including its scheme.';

  @override
  String get classification => 'Classification';

  @override
  String get classificationPublic => 'When shared, show the full task';

  @override
  String get classificationConfidential => 'When shared, show only busy';

  @override
  String get classificationPrivate => 'When shared, hide this task';

  @override
  String get pinTask => 'Pin task';

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
  String get reminders => 'Reminders';

  @override
  String get noReminders => 'No reminders';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get beforeTaskStarts => 'Before the task starts';

  @override
  String get beforeTaskDue => 'Before the task is due';

  @override
  String get afterTaskStarts => 'After the task starts';

  @override
  String get afterTaskDue => 'After the task is due';

  @override
  String get relativeToTaskStart => 'Relative to the task start date';

  @override
  String get relativeToTaskDue => 'Relative to the task due date';

  @override
  String get reminderTimeOfDay => 'Time of day';

  @override
  String get absoluteReminder => 'At a date and time';

  @override
  String get reminderAmount => 'Amount';

  @override
  String get reminderUnit => 'Unit';

  @override
  String get reminderUnitSeconds => 'Seconds';

  @override
  String get reminderUnitMinutes => 'Minutes';

  @override
  String get reminderUnitHours => 'Hours';

  @override
  String get reminderUnitDays => 'Days';

  @override
  String get reminderUnitWeeks => 'Weeks';

  @override
  String get reminderAtTaskStart => 'At the task start';

  @override
  String get reminderAtTaskDue => 'At the task due time';

  @override
  String get unsupportedReminder =>
      'This reminder type is preserved but its time cannot be edited.';

  @override
  String get relatedRemindersTitle => 'Keep related reminders?';

  @override
  String relatedRemindersDescription(int count) {
    return 'This date has $count related reminders. Keep them at their current date and time?';
  }

  @override
  String get discardRelatedReminders => 'Discard reminders';

  @override
  String get keepRelatedReminders => 'Keep reminders';

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
  String get repeatEvery => 'Interval';

  @override
  String get repeatOn => 'Repeat on';

  @override
  String get repeatEnd => 'End repeat';

  @override
  String get repeatNever => 'Never';

  @override
  String get repeatUntil => 'On date';

  @override
  String get repeatAfter => 'After a number of occurrences';

  @override
  String get repeatCount => 'Occurrences';

  @override
  String get repeatDayOfMonth => 'Days of month';

  @override
  String get repeatMonths => 'Months';

  @override
  String get repeatOrdinal => 'Weekday position';

  @override
  String get repeatSpecificDays => 'Specific days';

  @override
  String get repeatFirst => 'First';

  @override
  String get repeatSecond => 'Second';

  @override
  String get repeatThird => 'Third';

  @override
  String get repeatFourth => 'Fourth';

  @override
  String get repeatFifth => 'Fifth';

  @override
  String get repeatSecondToLast => 'Second to last';

  @override
  String get repeatLast => 'Last';

  @override
  String get repeatAnyDay => 'Day';

  @override
  String get repeatWeekday => 'Weekday';

  @override
  String get repeatWeekendDay => 'Weekend day';

  @override
  String repeatEveryDays(int count) {
    return 'Every $count days';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'Every $count months';
  }

  @override
  String repeatEveryYears(int count) {
    return 'Every $count years';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'on $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'on day $days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'on the first $days',
      'second': 'on the second $days',
      'third': 'on the third $days',
      'fourth': 'on the fourth $days',
      'fifth': 'on the fifth $days',
      'secondToLast': 'on the second to last $days',
      'last': 'on the last $days',
      'other': 'on $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'in $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count times';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'until $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'This recurrence rule uses options that this editor does not change.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'This recurrence cannot be used with $provider.';
  }

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
  String get subtasks => 'Subtasks';

  @override
  String get duplicateTask => 'Duplicate task';

  @override
  String get taskDuplicated => 'Task duplicated.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Could not duplicate the task: $error';
  }

  @override
  String get hideSubtasks => 'Hide subtasks';

  @override
  String get hideClosedSubtasks => 'Hide closed subtasks';

  @override
  String get moveToTop => 'Move to top';

  @override
  String get deleteTask => 'Delete Task';

  @override
  String get newSubtask => 'New subtask';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Delete \"$title\"?';
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
  String get launchAtLogin => 'Launch at login';

  @override
  String get launchAtLoginDescription =>
      'Start BusyMax in the background so reminders work after you sign in.';

  @override
  String get launchAtLoginFailed =>
      'Could not update the launch-at-login setting.';

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
  String get onState => 'On';

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
  String get discardChangesAction => 'Discard';

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
  String get eventReminderNotificationTitle => 'Event reminder';

  @override
  String get taskReminderNotificationTitle => 'Task reminder';

  @override
  String get eventReminderNotificationBody => 'Event starts soon.';

  @override
  String get taskReminderNotificationBody => 'Task is due soon.';

  @override
  String get notificationOpenAction => 'Open';

  @override
  String get notificationSnoozeAction => 'Snooze 10 minutes';

  @override
  String get notificationDismissAction => 'Dismiss';

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
  String get selectTimeZone => 'Select Timezone';

  @override
  String get searchLocations => 'Search locations';

  @override
  String get noLocationsFound => 'No locations found';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get providerConnectionDescription =>
      'Connect calendars and tasks from one of these providers.';

  @override
  String get appleICloudProvider => 'Apple iCloud Calendar';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud Tasks';

  @override
  String get addAppleICloudAccount => 'Add Apple iCloud Calendar account';

  @override
  String get addNextcloudAccount => 'Add Nextcloud account';

  @override
  String get waitingForAppleICloud => 'Connecting to Apple iCloud…';

  @override
  String get waitingForNextcloud => 'Waiting for Nextcloud authorization…';

  @override
  String get connectAppleICloudTitle => 'Connect Apple iCloud Calendar';

  @override
  String get appleAccountEmail => 'Apple Account email';

  @override
  String get appleAppSpecificPassword => 'App-specific password';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Create an app-specific password after enabling two-factor authentication for your Apple Account.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Resetting your Apple Account password revokes app-specific passwords.';

  @override
  String get connectNextcloudTitle => 'Connect Nextcloud';

  @override
  String get nextcloudServerUrl => 'Nextcloud server or CalDAV address';

  @override
  String get nextcloudServerUrlHelp =>
      'Enter your Nextcloud server URL, or paste the primary CalDAV address copied from Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax will open your browser. Approve access there, then return to BusyMax.';

  @override
  String get connectAccountAction => 'Connect';

  @override
  String get cancelAccountConnection => 'Cancel connection';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'The account was removed locally, but its Nextcloud app password could not be revoked.';

  @override
  String get davCachedOfflineNotice =>
      'Calendar and task data is cached locally for offline use.';

  @override
  String get davReauthenticationRequired =>
      'Reconnect this account to resume synchronization.';

  @override
  String get davTemporarilyUnavailable =>
      'This account is temporarily unavailable.';

  @override
  String get davPermissionChanged =>
      'Server permissions changed. Pending edits are paused.';

  @override
  String get davUnsupportedServer =>
      'This server or provider profile is not supported.';

  @override
  String get collectionSettings => 'Calendars and task lists';

  @override
  String get calendarContent => 'Calendar events';

  @override
  String get taskContent => 'Tasks';

  @override
  String get readOnlySharedCollection => 'Read-only';

  @override
  String get pendingLocally => 'Pending locally';

  @override
  String get conflictBlocked => 'Blocked by conflict';

  @override
  String get authenticationBlocked => 'Blocked until reconnect';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get keepServerVersion => 'Keep server version';

  @override
  String get reapplyLocalChange => 'Review and reapply local change';

  @override
  String get duplicateLocalItem => 'Duplicate as new item';

  @override
  String get davConnectionState => 'Connection state';

  @override
  String get davConnected => 'Connected';

  @override
  String get davConnecting => 'Connecting…';

  @override
  String get davSignedOut => 'Signed out';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Last successful sync: $time';
  }

  @override
  String get davNeverSynced => 'Not synchronized yet';

  @override
  String get refreshCollections => 'Refresh calendars and task lists';

  @override
  String nextcloudServerHost(String host) {
    return 'Server: $host';
  }

  @override
  String get collectionSupportsEvents => 'Event calendar';

  @override
  String get collectionSupportsTasks => 'Task list';

  @override
  String get collectionSupportsEventsAndTasks => 'Events and tasks';

  @override
  String get writableCollection => 'Writable';

  @override
  String get sharedCollection => 'Shared';

  @override
  String collectionLastSynced(String time) {
    return 'Last synchronized: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Sync issue: $code';
  }

  @override
  String get syncConflicts => 'Synchronization conflicts';

  @override
  String remoteChangedAt(String time) {
    return 'Server changed: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Local edit: $summary';
  }

  @override
  String get conflictResolutionFailed => 'The conflict could not be resolved.';

  @override
  String get recurringEventScope => 'Recurring event scope';

  @override
  String get entireSeries => 'Entire series';

  @override
  String get singleOccurrence => 'This event';

  @override
  String get thisAndFollowingEvents => 'This and following events';

  @override
  String get thisAndFutureUnavailable => 'Not supported by this provider.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'This and following events cannot be moved safely. Choose this event or the entire series.';

  @override
  String get entireSeriesMoveUnavailable =>
      'The recurrence rule is not available locally. Move this event instead.';

  @override
  String get copyEventAndDeleteOriginal => 'Copy event and delete original?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax cannot move this event directly from $source to $destination. It will create the copy first and delete the original only after the copy succeeds. Event IDs will change; attendee response statuses may reset and invitations or cancellations may be sent; conference links, attachments, reminders, provider-specific fields, and recurrence exceptions may not carry over.';
  }

  @override
  String get copyAndDelete => 'Copy and delete';

  @override
  String get chooseRecurringEventScope =>
      'Choose whether this change applies to the entire series, only this occurrence, or this and following events.';

  @override
  String get taskDueBeforeStart => 'Due must not be before start.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Set times for both start and due, or make the task all day.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get setCustomCalendarName => 'Set custom name';

  @override
  String get setAction => 'Set';

  @override
  String get removeFromMyCalendars => 'Remove from my calendars';

  @override
  String get removeAction => 'Remove';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Remove \"$title\" from your Google Calendar list? The shared calendar and its events will not be deleted.';
  }

  @override
  String get calendarCannotRemove =>
      'This calendar cannot be deleted or removed from this account.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Wait for this calendar’s pending changes to finish syncing before deleting or removing it.';

  @override
  String get calendarSubscriptions => 'Calendar subscriptions';

  @override
  String get calendarSubscriptionsDescription =>
      'Add read-only calendars that refresh from a secure WebCal URL.';

  @override
  String get addCalendarSubscription => 'Add calendar subscription';

  @override
  String get subscriptionName => 'Local name';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get subscriptionUrlHelp =>
      'Enter an HTTPS or webcal URL. BusyMax keeps the complete URL in secure storage.';

  @override
  String get subscriptionUrlInvalid =>
      'Enter a valid HTTPS or webcal URL without user information or a fragment.';

  @override
  String get subscriptionColor => 'Local color';

  @override
  String get subscriptionColorHelp => 'Use a six-digit color such as #3584E4.';

  @override
  String get subscriptionColorInvalid => 'Enter a six-digit hexadecimal color.';

  @override
  String get subscriptionRefreshMode => 'Refresh frequency';

  @override
  String get subscriptionAutomatic => 'Automatic';

  @override
  String get subscriptionHourly => 'Hourly';

  @override
  String get subscriptionSixHours => 'Every six hours';

  @override
  String get subscriptionDaily => 'Daily';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Source: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Enter a valid URL to preview its safe origin.';

  @override
  String get subscriptionReadOnly => 'Read-only subscription';

  @override
  String get subscriptionNeverRefreshed => 'Not refreshed yet';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Last successful refresh: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Next refresh: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Up to date';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Refresh issue: $code';
  }

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get unsubscribe => 'Unsubscribe';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Unsubscribe from “$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'This removes the local subscription and its cached events. The published calendar is not changed.';

  @override
  String get addSubscriptionAction => 'Add subscription';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Calendar subscription failed: $error';
  }

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get calendarImport => 'Calendar import';

  @override
  String get calendarImportDescription =>
      'Select a file, review its events, then choose the writable calendar that should receive them.';

  @override
  String get importIcsFile => 'Import .ics file';

  @override
  String get importIcsPreview => 'Import calendar events';

  @override
  String importEventsFound(int count) {
    return 'Importable event sets: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Invalid events: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Intentionally omitted: $fields';
  }

  @override
  String get noWritableCalendars =>
      'No writable destination calendar is available.';

  @override
  String get importDestinationCalendar => 'Destination calendar';

  @override
  String get importIcsConfirm => 'Import events';

  @override
  String get importIcsComplete => 'Import complete';

  @override
  String importQueued(int count) {
    return 'Imported or queued: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Duplicates skipped: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Unsupported recurrence sets: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Could not import the calendar file: $error';
  }

  @override
  String get networkOffline => 'Offline';

  @override
  String get networkOfflineDescription =>
      'Changes will sync when the connection is restored.';

  @override
  String get networkOfflineTryAgain =>
      'You’re offline. Connect to the internet and try again.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'on days $days';
  }
}

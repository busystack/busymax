// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'Monday',
      'TU': 'Tuesday',
      'WE': 'Wednesday',
      'TH': 'Thursday',
      'FR': 'Friday',
      'SA': 'Saturday',
      'SU': 'Sunday',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return 'on days $first and $second';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency on days $firstDay and $secondDay of $month';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency on day $day of $firstMonth and $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency on days $firstDay and $secondDay of $firstMonth and $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency on days $days of $firstMonth and $secondMonth';
  }

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
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Color $numberString';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString more';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tasks due today',
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $countString minutes ago',
      one: 'Last synced 1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $countString hours ago',
      one: 'Last synced 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $countString days ago',
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
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutesString minutes before',
      one: '1 minute before',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'At start';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString hours before',
      one: '1 hour before',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString days before',
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
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$percentString% completed';
  }

  @override
  String get completionDate => 'Completion date';

  @override
  String get priority => 'Priority';

  @override
  String get priorityNone => 'No priority';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priority $priorityString · High';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priority $priorityString · Medium';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priority $priorityString · Low';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'This date has $countString related reminders. Keep them at their current date and time?';
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
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'Monday',
      'TU': 'Tuesday',
      'WE': 'Wednesday',
      'TH': 'Thursday',
      'FR': 'Friday',
      'SA': 'Saturday',
      'SU': 'Sunday',
      'day': 'day',
      'weekday': 'weekday',
      'weekend': 'weekend day',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Every $countString days';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Every $countString weeks';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Every $countString months';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Every $countString years';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString times',
      one: '$countString time',
    );
    return '$_temp0';
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
  String get forceFullResync => 'Force full resync';

  @override
  String get forceFullResyncDescription =>
      'Completely reload data from every connected account. Use this only to troubleshoot synchronization problems.';

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
  String get settingsSystem => 'System';

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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'attempts=$countString';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString tasks are due today.',
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
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Week $numberString';
  }

  @override
  String get resizeAllDayPanel => 'Resize the all-day panel';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString items',
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Importable event sets: $countString';
  }

  @override
  String importInvalidEvents(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Invalid events: $countString';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Imported or queued: $countString';
  }

  @override
  String importDuplicatesSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Duplicates skipped: $countString';
  }

  @override
  String importUnsupportedSets(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Unsupported recurrence sets: $countString';
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

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first and $second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first and $second';
  }

  @override
  String repeatMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first and $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first and $second';
  }

  @override
  String repeatYearlyMonthListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyOnMonthDaySummary(
    String frequency,
    String month,
    String day,
  ) {
    return '$frequency on $month $day';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency on days $days of $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency on day $day of $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency on days $days of $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'on the first $days of $month',
      'second': 'on the second $days of $month',
      'third': 'on the third $days of $month',
      'fourth': 'on the fourth $days of $month',
      'fifth': 'on the fifth $days of $month',
      'secondToLast': 'on the second to last $days of $month',
      'last': 'on the last $days of $month',
      'other': 'on $days of $month',
    });
    return '$frequency $_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'on the first $days of $months',
      'second': 'on the second $days of $months',
      'third': 'on the third $days of $months',
      'fourth': 'on the fourth $days of $months',
      'fifth': 'on the fifth $days of $months',
      'secondToLast': 'on the second to last $days of $months',
      'last': 'on the last $days of $months',
      'other': 'on $days of $months',
    });
    return '$frequency $_temp0';
  }
}

/// The translations for Portuguese, as used in Portugal (`pt_PT`).
class AppLocalizationsPtPt extends AppLocalizationsPt {
  AppLocalizationsPtPt() : super('pt_PT');

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'à segunda-feira',
      'TU': 'à terça-feira',
      'WE': 'à quarta-feira',
      'TH': 'à quinta-feira',
      'FR': 'à sexta-feira',
      'SA': 'ao sábado',
      'SU': 'ao domingo',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return 'nos dias $first e $second';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency nos dias $firstDay e $secondDay de $month';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency no dia $day de $firstMonth e $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency nos dias $firstDay e $secondDay de $firstMonth e $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency nos dias $days de $firstMonth e $secondMonth';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Ligue as contas Google, Microsoft, Calendário Apple iCloud ou Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'No ecrã de autorizações da Google, selecione as autorizações do Calendário e das Tarefas.';

  @override
  String get googlePermissionsRequiredRetry =>
      'As autorizações do Calendário Google e do Google Tasks são necessárias. Tente novamente e selecione ambas as caixas.';

  @override
  String get finishSetup => 'Concluir configuração';

  @override
  String get continueSetup => 'Continuar';

  @override
  String get onboardingSetupTitle => 'Configurar o BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Ligar contas';

  @override
  String get onboardingAccountsStepDescription =>
      'Adicione todas as contas que pretende utilizar. O BusyMax sincroniza calendários, eventos, listas de tarefas e tarefas suportados de cada conta.';

  @override
  String get onboardingPreferencesStepTitle => 'Escolher definições do sistema';

  @override
  String get onboardingPreferencesStepDescription =>
      'Configure o comportamento da aplicação no ambiente de trabalho, os lembretes, o nível de detalhe das notificações e o aspeto antes de abrir a agenda.';

  @override
  String get signInWithGoogle => 'Iniciar sessão com a Google';

  @override
  String get signInWithMicrosoft => 'Iniciar sessão com a Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Este fornecedor não está configurado.';

  @override
  String get waitingForGoogleSignIn =>
      'A aguardar o início de sessão da Google...';

  @override
  String get waitingForMicrosoftSignIn =>
      'A aguardar o início de sessão da Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'O início de sessão da Microsoft não está configurado. Defina MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Fechar';

  @override
  String get exit => 'Sair';

  @override
  String get options => 'Opções';

  @override
  String get hide => 'Ocultar';

  @override
  String get show => 'Mostrar';

  @override
  String get export => 'Exportar';

  @override
  String get save => 'Guardar';

  @override
  String get settings => 'Definições';

  @override
  String get all => 'Tudo';

  @override
  String get calendarEvents => 'Eventos';

  @override
  String get calendarTasks => 'Tarefas';

  @override
  String get calendar => 'Calendário';

  @override
  String get calendars => 'Calendários';

  @override
  String get newCalendar => 'Novo calendário';

  @override
  String get calendarColor => 'Cor do calendário';

  @override
  String calendarColorOption(int number) {
    return 'Cor $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Este fornecedor não suporta a gestão de calendários no BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'O calendário principal não pode ser eliminado.';

  @override
  String calendarCreateFailed(String error) {
    return 'Não foi possível criar o calendário: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'O calendário foi criado, mas o BusyMax não conseguiu atualizar a conta. Será apresentado após a próxima sincronização.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Não foi possível atualizar o calendário: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Não foi possível eliminar o calendário: $error';
  }

  @override
  String get newEvent => 'Novo evento';

  @override
  String get refreshCalendar => 'Atualizar calendário';

  @override
  String get openInProvider => 'Abrir no serviço';

  @override
  String get hideFromSchedule => 'Ocultar da agenda';

  @override
  String get showInSchedule => 'Mostrar na agenda';

  @override
  String get noCalendarsSynced => 'Ainda não há calendários sincronizados.';

  @override
  String get allDay => 'Todo o dia';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString mais';
  }

  @override
  String get noEventsOrTasks => 'Sem eventos ou tarefas';

  @override
  String get scheduleLoading => 'A carregar agenda...';

  @override
  String get scheduleUnavailable => 'Agenda indisponível';

  @override
  String get scheduleNoSources =>
      'Sem calendários ou listas de tarefas visíveis';

  @override
  String get scheduleNoSourcesDescription =>
      'Escolha o que pretende mostrar nas Definições e atualize a agenda.';

  @override
  String get scheduleSignInRequired => 'Ligar uma conta';

  @override
  String get scheduleSignInDescription =>
      'Inicie sessão para sincronizar calendários e tarefas.';

  @override
  String get scheduleNoSearchResults =>
      'Nenhum evento ou tarefa correspondente';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Experimente outra pesquisa ou limpe os filtros atuais.';

  @override
  String get refresh => 'Atualizar';

  @override
  String get trayOpenBusyMax => 'Abrir o BusyMax';

  @override
  String get trayShowBusyMax => 'Mostrar o BusyMax';

  @override
  String get trayNewEvent => 'Novo evento…';

  @override
  String get trayNewTask => 'Nova tarefa…';

  @override
  String get trayToday => 'Hoje';

  @override
  String get trayAllDay => 'Todo o dia';

  @override
  String get trayNow => 'Agora';

  @override
  String get trayCalendarEvent => 'Evento do calendário';

  @override
  String get trayUntitledEvent => 'Evento sem título';

  @override
  String get trayNothingElseToday => 'Nada mais hoje';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas terminam hoje',
      one: '1 tarefa termina hoje',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Abrir a agenda de hoje';

  @override
  String get traySyncNow => 'Sincronizar agora';

  @override
  String get traySyncing => 'A sincronizar…';

  @override
  String get trayNotConnected => 'Não ligado';

  @override
  String get trayNotYetSynced => 'Ainda não sincronizado';

  @override
  String get trayLastSyncedJustNow => 'Sincronizado agora mesmo';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado há $count minutos',
      one: 'Sincronizado há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado há $count horas',
      one: 'Sincronizado há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado há $count dias',
      one: 'Sincronizado há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Definições';

  @override
  String get trayQuitBusyMax => 'Sair do BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Carregar mais tarefas em atraso';

  @override
  String get agendaLoadMoreNoDate => 'Carregar mais tarefas sem data';

  @override
  String get viewDay => 'Dia';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewMonth => 'Mês';

  @override
  String get viewYear => 'Ano';

  @override
  String get viewAgenda => 'Vista de agenda';

  @override
  String get scheduleSettings => 'Agenda';

  @override
  String get scheduleDisplaySettings => 'Apresentação da agenda';

  @override
  String get scheduleDisplayHoursDescription =>
      'As vistas de dia e semana mostram inicialmente este intervalo horário. Os itens anteriores ou posteriores alargam-no quando necessário.';

  @override
  String get scheduleDayStartsAt => 'O dia começa às';

  @override
  String get scheduleDayEndsAt => 'O dia termina às';

  @override
  String get sourceCalendar => 'Calendário';

  @override
  String get sourceTaskList => 'Lista de tarefas';

  @override
  String get createChoiceTitle => 'Criar';

  @override
  String get createEventAtTime => 'Evento';

  @override
  String get createTaskAtDate => 'Tarefa';

  @override
  String get editEvent => 'Editar evento';

  @override
  String get eventTitle => 'Título do evento';

  @override
  String get location => 'Local';

  @override
  String get timeSlot => 'Intervalo de tempo';

  @override
  String get startDateTime => 'Data e hora de início';

  @override
  String get endDateTime => 'Data e hora de fim';

  @override
  String get doesNotRepeat => 'Não se repete';

  @override
  String get defaultReminder => 'Lembrete predefinido';

  @override
  String get guests => 'Convidados';

  @override
  String get noGuests => 'Sem convidados';

  @override
  String get attendeeRequired => 'Obrigatório';

  @override
  String get attendeeOptional => 'Opcional';

  @override
  String get meetingSection => 'Reunião';

  @override
  String get addGoogleMeet => 'Adicionar o Google Meet';

  @override
  String get addTeamsMeeting => 'Adicionar reunião do Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Reunião online adicionada';

  @override
  String get requestResponses => 'Pedir respostas';

  @override
  String get requestResponsesDescription =>
      'Peça aos convidados que respondam ao convite.';

  @override
  String get hideGuestList => 'Ocultar lista de convidados';

  @override
  String get hideGuestListDescription =>
      'Os convidados não podem ver quem mais foi convidado.';

  @override
  String get allowNewTimeProposals => 'Permitir novas propostas de horário';

  @override
  String get allowNewTimeProposalsDescription =>
      'Os convidados podem sugerir uma hora diferente para a reunião.';

  @override
  String get notifyGuestsTitle => 'Notificar convidados?';

  @override
  String get notifyGuestsSaveMessage =>
      'Esta reunião tem convidados. Enviar convites ou atualizações do evento ao guardá-la?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Esta reunião tem convidados. Enviar um cancelamento ao eliminá-la?';

  @override
  String get sendUpdates => 'Enviar atualizações';

  @override
  String get sendCancellation => 'Enviar cancelamento';

  @override
  String get doNotSend => 'Não enviar';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Guardar reunião?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'A Microsoft enviará convites ou atualizações do evento aos convidados.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Eliminar reunião?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'A Microsoft enviará um cancelamento aos convidados.';

  @override
  String get organizer => 'Organizador';

  @override
  String get yourResponse => 'A sua resposta';

  @override
  String get guestResponses => 'Respostas dos convidados';

  @override
  String get respond => 'Responder';

  @override
  String get acceptInvitation => 'Aceitar';

  @override
  String get tentativeInvitation => 'Provisório';

  @override
  String get declineInvitation => 'Recusar';

  @override
  String get joinMeeting => 'Participar na reunião';

  @override
  String get responseAccepted => 'Aceite';

  @override
  String get responseTentative => 'Provisório';

  @override
  String get responseDeclined => 'Recusado';

  @override
  String get responseNeedsAction => 'A aguardar resposta';

  @override
  String get responseNotResponded => 'Sem resposta';

  @override
  String get responseOrganizer => 'Organizador';

  @override
  String invitationResponseFailed(String error) {
    return 'Não foi possível enviar a sua resposta: $error';
  }

  @override
  String get joinMeetingFailed =>
      'Não foi possível abrir a ligação da reunião.';

  @override
  String get description => 'Descrição';

  @override
  String get availabilityShowAs => 'Disponibilidade / Mostrar como';

  @override
  String get busy => 'Ocupado';

  @override
  String get visibility => 'Visibilidade';

  @override
  String get defaultVisibility => 'Visibilidade predefinida';

  @override
  String get conference => 'Conferência';

  @override
  String get noConference => 'Sem conferência';

  @override
  String get providerCalendar => 'Calendário do fornecedor';

  @override
  String get formatBoldShortLabel => 'N';

  @override
  String get formatBoldTooltip => 'Negrito';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'Itálico';

  @override
  String get formatUnderlineShortLabel => 'S';

  @override
  String get formatUnderlineTooltip => 'Sublinhado';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutesString minutos antes',
      one: '1 minuto antes',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'À hora de início';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString horas antes',
      one: '1 hora antes',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString dias antes',
      one: '1 dia antes',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Livre';

  @override
  String get availabilityTentative => 'Provisório';

  @override
  String get availabilityOutOfOffice => 'Fora do escritório';

  @override
  String get availabilityWorkingElsewhere => 'A trabalhar noutro local';

  @override
  String get visibilityDefault => 'Predefinida';

  @override
  String get visibilityPublic => 'Pública';

  @override
  String get visibilityPrivate => 'Privada';

  @override
  String get visibilityConfidential => 'Confidencial';

  @override
  String get sensitivityNormal => 'Normal';

  @override
  String get sensitivityPersonal => 'Pessoal';

  @override
  String get tasks => 'Tarefas';

  @override
  String get allTasks => 'Todas as tarefas';

  @override
  String tasksInList(String title) {
    return 'Tarefas em $title';
  }

  @override
  String get taskLists => 'Listas de tarefas';

  @override
  String get navigation => 'Navegação';

  @override
  String get mainMenu => 'Menu principal';

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get shortcutGroupGeneral => 'Geral';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Mostrar esta referência de atalhos';

  @override
  String get shortcutGroupNavigation => 'Navegação';

  @override
  String get shortcutNextPeriod => 'Período seguinte';

  @override
  String get shortcutNextPeriodDescription =>
      'Semana seguinte na vista semanal, mês seguinte na vista mensal e assim por diante';

  @override
  String get shortcutPreviousPeriod => 'Período anterior';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Semana anterior na vista semanal, mês anterior na vista mensal e assim por diante';

  @override
  String get shortcutJumpToToday => 'Ir para hoje';

  @override
  String get shortcutGroupView => 'Vista';

  @override
  String get shortcutDayView => 'Vista diária';

  @override
  String get shortcutWeekView => 'Vista semanal';

  @override
  String get shortcutMonthView => 'Vista mensal';

  @override
  String get shortcutYearView => 'Vista anual';

  @override
  String get shortcutAgendaView => 'Vista de agenda';

  @override
  String get shortcutGroupCreateAndEdit => 'Criar e editar';

  @override
  String get shortcutSaveItem => 'Guardar evento ou tarefa';

  @override
  String get shortcutDeleteItem => 'Eliminar evento ou tarefa';

  @override
  String get shortcutGroupTaskEditing => 'Edição de tarefas';

  @override
  String get shortcutCancelEditing => 'Cancelar edição';

  @override
  String get shortcutCancelEditingDescription =>
      'Fechar a edição ou os detalhes da tarefa';

  @override
  String get aboutBusyMax => 'Acerca do BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Calendário e tarefas';

  @override
  String get license => 'Licença';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Site';

  @override
  String get sourceCode => 'Código-fonte';

  @override
  String get reportAnIssue => 'Comunicar um problema';

  @override
  String get sendFeedback => 'Enviar comentários';

  @override
  String get feedbackSubmit => 'Enviar';

  @override
  String get feedbackCategory => 'Categoria';

  @override
  String get feedbackSelectCategory => 'Selecione uma categoria';

  @override
  String get feedbackCategoryProblem => 'Problema ou erro';

  @override
  String get feedbackCategoryFeature => 'Pedido de funcionalidade';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Questão de privacidade ou segurança';

  @override
  String get feedbackCategoryUsability => 'Problema de utilização';

  @override
  String get feedbackCategoryOther => 'Outro';

  @override
  String get feedbackSubject => 'Assunto';

  @override
  String get feedbackDetailedMessage => 'Mensagem detalhada';

  @override
  String get feedbackReplyEmail =>
      'Endereço de e-mail para resposta (opcional)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Incluir detalhes técnicos';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Adiciona apenas a versão do sistema operativo Linux e a configuração regional da aplicação. Não são incluídos registos, dados de contas, nomes de ficheiros nem outros diagnósticos.';

  @override
  String get feedbackCategoryRequired => 'Selecione uma categoria.';

  @override
  String get feedbackSubjectLengthError =>
      'O assunto deve ter entre 3 e 120 carateres.';

  @override
  String get feedbackMessageLengthError =>
      'A mensagem deve ter entre 10 e 5 000 carateres.';

  @override
  String get feedbackInvalidEmail => 'Introduza um endereço de e-mail válido.';

  @override
  String get feedbackConnectionError =>
      'Não foi possível ligar ao BusyStack. Verifique a ligação e tente novamente.';

  @override
  String get feedbackTimeoutError =>
      'O pedido excedeu o tempo limite. Os seus comentários não foram apagados; tente novamente.';

  @override
  String get feedbackRateLimitedError =>
      'Foram enviados demasiados comentários a partir desta rede. Aguarde e tente novamente.';

  @override
  String get feedbackRejectedError =>
      'O servidor rejeitou o envio. Reveja os campos e tente novamente.';

  @override
  String get feedbackServerError =>
      'O BusyStack não pode aceitar os seus comentários neste momento. Os seus comentários não foram apagados; tente novamente.';

  @override
  String feedbackSuccess(String id) {
    return 'Comentários enviados. Referência: $id';
  }

  @override
  String get toggleSidebar => 'Mostrar ou ocultar a barra lateral';

  @override
  String get showSidebar => 'Mostrar painel lateral';

  @override
  String get hideSidebar => 'Ocultar painel lateral';

  @override
  String get accounts => 'Contas';

  @override
  String get currentAccount => 'Conta atual';

  @override
  String get switchAccount => 'Mudar de conta';

  @override
  String get addGoogleAccount => 'Adicionar conta Google';

  @override
  String get addMicrosoftAccount => 'Adicionar conta Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Sessão iniciada';

  @override
  String get removeAccount => 'Remover conta…';

  @override
  String get removingAccount => 'A remover conta…';

  @override
  String get removeAccountDescription =>
      'Parar a sincronização e remover os dados desta conta deste dispositivo.';

  @override
  String removeAccountTitle(String account) {
    return 'Remover $account do BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'Esta ação elimina deste dispositivo as tarefas, calendários, eventos, lembretes e alterações offline pendentes colocados em cache. As alterações não sincronizadas serão perdidas. As cópias dos calendários, eventos, listas de tarefas e tarefas no fornecedor não são eliminadas.';

  @override
  String get revokeGoogleAccess =>
      'Revogar também o acesso do BusyMax a esta conta Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Terá de conceder acesso novamente antes de voltar a ligar a conta.';

  @override
  String get removeAccountAction => 'Remover conta';

  @override
  String get removeAccountFailed =>
      'Não foi possível concluir a remoção da conta. Tente novamente.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'A conta foi removida deste dispositivo, mas não foi possível revogar o acesso do BusyMax à sua conta Google. Pode revogar esse acesso na sua conta Google.';

  @override
  String get newTaskList => 'Nova lista de tarefas';

  @override
  String taskListCreateFailed(String error) {
    return 'Não foi possível criar a lista de tarefas: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Não foi possível mudar o nome da lista de tarefas: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Não foi possível eliminar a lista de tarefas: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Inicie sessão para ver as listas de tarefas.';

  @override
  String get noTaskListsSynced =>
      'Ainda não há listas de tarefas sincronizadas.';

  @override
  String get listActions => 'Ações da lista';

  @override
  String get rename => 'Mudar o nome';

  @override
  String get delete => 'Eliminar';

  @override
  String get renameList => 'Mudar o nome da lista';

  @override
  String get deleteList => 'Eliminar lista';

  @override
  String get unshare => 'Cancelar partilha';

  @override
  String get readOnlyTaskListCannotRename =>
      'Esta lista de tarefas é só de leitura e não pode ter o nome alterado.';

  @override
  String get taskListCannotDelete =>
      'Esta lista de tarefas não pode ser eliminada com as permissões atuais.';

  @override
  String get builtInMicrosoftList => 'Incorporada';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'As listas incorporadas do Microsoft To Do não podem ser renomeadas nem eliminadas.';

  @override
  String deleteListConfirmation(String title) {
    return 'Eliminar “$title” do Google Tasks?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Eliminar “$title” e todas as suas tarefas?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Cancelar a partilha de “$title” desta conta?';
  }

  @override
  String get deleteEvent => 'Eliminar evento';

  @override
  String get title => 'Título';

  @override
  String get create => 'Criar';

  @override
  String get newTask => 'Nova tarefa';

  @override
  String get clearCompleted => 'Limpar tarefas concluídas';

  @override
  String get refreshList => 'Atualizar lista';

  @override
  String get refreshAll => 'Atualizar tudo';

  @override
  String get listRefreshed => 'Lista atualizada.';

  @override
  String get allTasksRefreshed => 'Todas as contas foram atualizadas.';

  @override
  String exportedFile(String path) {
    return 'Exportado para $path';
  }

  @override
  String exportFailed(String error) {
    return 'Falha ao exportar: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Falha ao atualizar: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Selecione ou crie uma lista de tarefas para começar.';

  @override
  String get signInToViewTasks => 'Inicie sessão para ver as tarefas.';

  @override
  String get noTasks => 'Sem tarefas.';

  @override
  String get noTasksYet => 'Ainda não há tarefas';

  @override
  String get noTasksYetMessage =>
      'Crie uma tarefa ou atualize as suas contas para começar.';

  @override
  String get noTasksInList => 'Não há tarefas nesta lista.';

  @override
  String get overdue => 'Em atraso';

  @override
  String get today => 'Hoje';

  @override
  String get tomorrow => 'Amanhã';

  @override
  String get upcoming => 'Próximas';

  @override
  String get noDate => 'Sem data';

  @override
  String get completed => 'Concluídas';

  @override
  String duePrefix(String date) {
    return 'Prazo: $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date, $time';
  }

  @override
  String get taskDetails => 'Detalhes da tarefa';

  @override
  String get editTask => 'Editar tarefa';

  @override
  String get noTaskSelected => 'Nenhuma tarefa selecionada.';

  @override
  String get noTaskSelectedHelper =>
      'Selecione uma tarefa para ver e editar os detalhes.';

  @override
  String get taskUnavailable => 'Tarefa indisponível.';

  @override
  String get signInToEditTasks => 'Inicie sessão para editar tarefas.';

  @override
  String get refreshTask => 'Atualizar tarefa';

  @override
  String get primarySection => 'Principal';

  @override
  String get statusSection => 'Estado';

  @override
  String get openStatus => 'Aberta';

  @override
  String get doneStatus => 'Concluída';

  @override
  String get taskStatus => 'Estado';

  @override
  String get taskStatusNone => 'Sem estado';

  @override
  String get taskStatusNeedsAction => 'Requer ação';

  @override
  String get taskStatusInProcess => 'Em curso';

  @override
  String get taskStatusCompleted => 'Concluída';

  @override
  String get taskStatusCancelled => 'Cancelada';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$percentString% concluída';
  }

  @override
  String get completionDate => 'Data de conclusão';

  @override
  String get priority => 'Prioridade';

  @override
  String get priorityNone => 'Sem prioridade';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Prioridade $priorityString · Alta';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Prioridade $priorityString · Média';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Prioridade $priorityString · Baixa';
  }

  @override
  String get taskUrl => 'URL da tarefa';

  @override
  String get invalidTaskUrl =>
      'Introduza um URL absoluto, incluindo o esquema.';

  @override
  String get classification => 'Classificação';

  @override
  String get classificationPublic =>
      'Quando partilhada, mostrar a tarefa completa';

  @override
  String get classificationConfidential =>
      'Quando partilhada, mostrar apenas ocupado';

  @override
  String get classificationPrivate => 'Quando partilhada, ocultar esta tarefa';

  @override
  String get pinTask => 'Afixar tarefa';

  @override
  String get notes => 'Notas';

  @override
  String get dueDate => 'Data limite';

  @override
  String get clearDueDate => 'Limpar data limite';

  @override
  String get dueTime => 'Hora limite';

  @override
  String get startDate => 'Data de início';

  @override
  String get startTime => 'Hora de início';

  @override
  String get endDate => 'Data de fim';

  @override
  String get endTime => 'Hora de fim';

  @override
  String get reminderDate => 'Data do lembrete';

  @override
  String get reminderTime => 'Hora do lembrete';

  @override
  String get reminder => 'Lembrete';

  @override
  String get addReminder => 'Adicionar lembrete';

  @override
  String get reminders => 'Lembretes';

  @override
  String get noReminders => 'Sem lembretes';

  @override
  String get editReminder => 'Editar lembrete';

  @override
  String get beforeTaskStarts => 'Antes do início da tarefa';

  @override
  String get beforeTaskDue => 'Antes do prazo da tarefa';

  @override
  String get afterTaskStarts => 'Depois do início da tarefa';

  @override
  String get afterTaskDue => 'Depois do prazo da tarefa';

  @override
  String get relativeToTaskStart => 'Relativo à data de início da tarefa';

  @override
  String get relativeToTaskDue => 'Relativo à data limite da tarefa';

  @override
  String get reminderTimeOfDay => 'Hora do dia';

  @override
  String get absoluteReminder => 'Numa data e hora';

  @override
  String get reminderAmount => 'Quantidade';

  @override
  String get reminderUnit => 'Unidade';

  @override
  String get reminderUnitSeconds => 'Segundos';

  @override
  String get reminderUnitMinutes => 'Minutos';

  @override
  String get reminderUnitHours => 'Horas';

  @override
  String get reminderUnitDays => 'Dias';

  @override
  String get reminderUnitWeeks => 'Semanas';

  @override
  String get reminderAtTaskStart => 'No início da tarefa';

  @override
  String get reminderAtTaskDue => 'No prazo da tarefa';

  @override
  String get unsupportedReminder =>
      'Este tipo de lembrete é preservado, mas a hora não pode ser editada.';

  @override
  String get relatedRemindersTitle => 'Manter lembretes relacionados?';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Esta data tem $countString lembretes relacionados. Mantê-los na data e hora atuais?';
  }

  @override
  String get discardRelatedReminders => 'Eliminar lembretes';

  @override
  String get keepRelatedReminders => 'Manter lembretes';

  @override
  String get addGuest => 'Adicionar convidado';

  @override
  String get addGuestEmail => 'Adicionar e-mail do convidado';

  @override
  String get removeReminder => 'Remover lembrete';

  @override
  String get off => 'Desativado';

  @override
  String get repeat => 'Repetição';

  @override
  String get repeatNone => 'Não repetir';

  @override
  String get noneValue => 'Nenhum';

  @override
  String get repeatDaily => 'Diariamente';

  @override
  String get repeatWeekly => 'Semanalmente';

  @override
  String get repeatMonthly => 'Mensalmente';

  @override
  String get repeatYearly => 'Anualmente';

  @override
  String get repeatEvery => 'Intervalo';

  @override
  String get repeatOn => 'Repetir em';

  @override
  String get repeatEnd => 'Terminar repetição';

  @override
  String get repeatNever => 'Nunca';

  @override
  String get repeatUntil => 'Numa data';

  @override
  String get repeatAfter => 'Depois de um número de ocorrências';

  @override
  String get repeatCount => 'Ocorrências';

  @override
  String get repeatDayOfMonth => 'Dias do mês';

  @override
  String get repeatMonths => 'Meses';

  @override
  String get repeatOrdinal => 'Posição do dia da semana';

  @override
  String get repeatSpecificDays => 'Dias específicos';

  @override
  String get repeatFirst => 'Primeiro';

  @override
  String get repeatSecond => 'Segundo';

  @override
  String get repeatThird => 'Terceiro';

  @override
  String get repeatFourth => 'Quarto';

  @override
  String get repeatFifth => 'Quinto';

  @override
  String get repeatSecondToLast => 'Penúltimo';

  @override
  String get repeatLast => 'Último';

  @override
  String get repeatAnyDay => 'Dia';

  @override
  String get repeatWeekday => 'Dia útil';

  @override
  String get repeatWeekendDay => 'Dia do fim de semana';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'segunda-feira',
      'TU': 'terça-feira',
      'WE': 'quarta-feira',
      'TH': 'quinta-feira',
      'FR': 'sexta-feira',
      'SA': 'sábado',
      'SU': 'domingo',
      'day': 'dia',
      'weekday': 'dia útil',
      'weekend': 'dia do fim de semana',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'A cada $countString dias';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'A cada $countString semanas';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'A cada $countString meses';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'A cada $countString anos';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'no dia $days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'na primeira ocorrência de $days',
      'second': 'na segunda ocorrência de $days',
      'third': 'na terceira ocorrência de $days',
      'fourth': 'na quarta ocorrência de $days',
      'fifth': 'na quinta ocorrência de $days',
      'secondToLast': 'na penúltima ocorrência de $days',
      'last': 'na última ocorrência de $days',
      'other': 'em $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'em $months';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString vezes',
      one: '$countString vez',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'até $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Esta regra de recorrência utiliza opções que este editor não altera.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Esta recorrência não pode ser usada com $provider.';
  }

  @override
  String get importance => 'Importância';

  @override
  String get importanceLow => 'Baixa';

  @override
  String get importanceNormal => 'Média';

  @override
  String get importanceHigh => 'Alta';

  @override
  String get categories => 'Categorias';

  @override
  String get scheduleSection => 'Agenda';

  @override
  String get dueGroup => 'Prazo';

  @override
  String get startGroup => 'Início';

  @override
  String get reminderGroup => 'Lembrete';

  @override
  String get organizationSection => 'Organização';

  @override
  String get actionsSection => 'Ações';

  @override
  String get advancedSection => 'Avançado';

  @override
  String get addCategory => 'Adicionar categoria';

  @override
  String get list => 'Lista';

  @override
  String get microsoftMoveUnsupported =>
      'Nesta versão, não é possível mover tarefas entre listas em contas Microsoft To Do.';

  @override
  String get createSubtask => 'Criar subtarefa';

  @override
  String get subtasks => 'Subtarefas';

  @override
  String get duplicateTask => 'Duplicar tarefa';

  @override
  String get taskDuplicated => 'Tarefa duplicada.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Não foi possível duplicar a tarefa: $error';
  }

  @override
  String get hideSubtasks => 'Ocultar subtarefas';

  @override
  String get hideClosedSubtasks => 'Ocultar subtarefas concluídas';

  @override
  String get moveToTop => 'Mover para o início';

  @override
  String get deleteTask => 'Eliminar tarefa';

  @override
  String get newSubtask => 'Nova subtarefa';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Eliminar «$title»?';
  }

  @override
  String get metadata => 'Metadados';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Atualizado';

  @override
  String get parent => 'Tarefa principal';

  @override
  String get position => 'Posição';

  @override
  String get webLink => 'Ligação Web';

  @override
  String get assignment => 'Atribuição';

  @override
  String get localState => 'Estado local';

  @override
  String get pendingSync => 'Sincronização pendente';

  @override
  String get synced => 'Sincronizado';

  @override
  String get account => 'Conta';

  @override
  String get sync => 'Sincronização';

  @override
  String get forceFullResync => 'Forçar nova sincronização completa';

  @override
  String get forceFullResyncDescription =>
      'Recarrega completamente os dados de todas as contas ligadas. Utilize esta opção apenas para resolver problemas de sincronização.';

  @override
  String get runInBackgroundWhenClosed =>
      'Continuar em execução quando a janela for fechada';

  @override
  String get showTrayIcon => 'Mostrar ícone na área de notificação';

  @override
  String get startMinimizedToTray =>
      'Iniciar minimizado na área de notificação';

  @override
  String get launchAtLogin => 'Iniciar ao entrar';

  @override
  String get launchAtLoginDescription =>
      'Inicie o BusyMax em segundo plano para que os lembretes funcionem após entrar.';

  @override
  String get launchAtLoginFailed =>
      'Não foi possível atualizar o início de sessão.';

  @override
  String get requiresTrayIcon => 'Requer o ícone da área de notificação.';

  @override
  String get syncComplete => 'Sincronização concluída.';

  @override
  String syncFailed(String error) {
    return 'Falha na sincronização: $error';
  }

  @override
  String get notifySyncFailures => 'Notificações de falhas de sincronização';

  @override
  String get notifyConflicts => 'Notificações de conflitos';

  @override
  String get notifyDueToday => 'Notificações de tarefas com prazo para hoje';

  @override
  String get eventReminders => 'Lembretes de eventos';

  @override
  String get onState => 'Ativado';

  @override
  String get taskReminders => 'Lembretes de tarefas';

  @override
  String get notificationDetailLevel => 'Nível de detalhe das notificações';

  @override
  String get notificationDetailPrivate => 'Privado';

  @override
  String get notificationDetailNormal => 'Predefinido';

  @override
  String get quietHours => 'Período de silêncio';

  @override
  String get quietHoursDescription =>
      'Pausar as notificações durante este período.';

  @override
  String get quietHoursStart => 'Início do período de silêncio';

  @override
  String get quietHoursEnd => 'Fim do período de silêncio';

  @override
  String get notifications => 'Notificações';

  @override
  String get appearance => 'Aspeto';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get settingsSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeFamily => 'Família de temas';

  @override
  String get themeFamilyYaru => 'Tema nativo do Ubuntu (Yaru)';

  @override
  String get localization => 'Localização';

  @override
  String get currentLocale => 'Configuração regional atual';

  @override
  String get privacy => 'Privacidade';

  @override
  String get redactTaskContentInDiagnostics =>
      'Ocultar o conteúdo das tarefas nos diagnósticos';

  @override
  String get developerDiagnostics => 'Diagnósticos de programador';

  @override
  String get diagnostics => 'Diagnósticos';

  @override
  String get apiInspectorDisabled => 'Mostrar inspetor da API';

  @override
  String get googleTasksApi => 'API do Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Revisão de descoberta: $revision';
  }

  @override
  String get implementedMethods => 'Métodos implementados';

  @override
  String get supportsTasksScopes =>
      'Suporta os âmbitos de autorização tasks e tasks.readonly';

  @override
  String get requiresTasksScope => 'Requer o âmbito de autorização tasks';

  @override
  String get blockedPendingOperations => 'Operações pendentes bloqueadas';

  @override
  String get signInToInspectPendingOperations =>
      'Inicie sessão para inspecionar as operações pendentes.';

  @override
  String get noBlockedPendingOperations =>
      'Não há operações pendentes bloqueadas.';

  @override
  String get operationActions => 'Ações da operação';

  @override
  String pendingOpListId(String id) {
    return 'lista=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'tarefa=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'tentativas=$countString';
  }

  @override
  String get retry => 'Tentar novamente';

  @override
  String get discard => 'Descartar';

  @override
  String get discardChangesAction => 'Descartar';

  @override
  String get discardChanges => 'Descartar alterações?';

  @override
  String get discardChangesConfirmation =>
      'Esta ação descarta as alterações não guardadas nesta tarefa.';

  @override
  String get retryCompleted => 'Nova tentativa concluída.';

  @override
  String get discardPendingOperation => 'Descartar operação pendente?';

  @override
  String get discardPendingOperationConfirmation =>
      'Esta ação remove a operação local bloqueada. Na próxima sincronização, os dados serão novamente carregados do Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Operação pendente descartada.';

  @override
  String get syncFailureNotificationTitle =>
      'Falha na sincronização do BusyMax';

  @override
  String syncFailureNotificationBody(String message) {
    return 'A sincronização em segundo plano falhou. $message';
  }

  @override
  String get conflictNotificationTitle =>
      'Conflito de sincronização do BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Uma alteração local pendente foi bloqueada. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Tarefas com prazo para hoje';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $countString tarefas com prazo para hoje.',
      one: 'Há uma tarefa com prazo para hoje.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Lembrete de evento';

  @override
  String get taskReminderNotificationTitle => 'Lembrete de tarefa';

  @override
  String get eventReminderNotificationBody => 'O evento começa em breve.';

  @override
  String get taskReminderNotificationBody => 'O prazo da tarefa aproxima-se.';

  @override
  String get notificationOpenAction => 'Abrir';

  @override
  String get notificationSnoozeAction => 'Adiar 10 minutos';

  @override
  String get notificationDismissAction => 'Fechar';

  @override
  String get notificationDetailsHidden =>
      'Os detalhes estão ocultos pelas definições de privacidade.';

  @override
  String get previousMonth => 'Mês anterior';

  @override
  String get nextMonth => 'Mês seguinte';

  @override
  String get openMonthView => 'Abrir vista mensal';

  @override
  String get previousYear => 'Ano anterior';

  @override
  String get nextYear => 'Ano seguinte';

  @override
  String get openYearView => 'Abrir vista anual';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Semana $numberString';
  }

  @override
  String get resizeAllDayPanel => 'Redimensionar o painel de dia inteiro';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Este calendário é só de leitura.';

  @override
  String get selectTimeZone => 'Selecionar fuso horário';

  @override
  String get searchLocations => 'Pesquisar locais';

  @override
  String get noLocationsFound => 'Não foram encontrados locais';

  @override
  String get requiredField => 'Este campo é obrigatório.';

  @override
  String get providerConnectionDescription =>
      'Ligue calendários e tarefas a um destes fornecedores.';

  @override
  String get appleICloudProvider => 'Calendário Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Tarefas do Nextcloud';

  @override
  String get addAppleICloudAccount =>
      'Adicionar conta do Calendário Apple iCloud';

  @override
  String get addNextcloudAccount => 'Adicionar conta Nextcloud';

  @override
  String get waitingForAppleICloud => 'A ligar ao Apple iCloud…';

  @override
  String get waitingForNextcloud => 'A aguardar autorização do Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Ligar o Calendário Apple iCloud';

  @override
  String get appleAccountEmail => 'E-mail da conta Apple';

  @override
  String get appleAppSpecificPassword =>
      'Palavra-passe específica da aplicação';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Crie uma palavra-passe específica da aplicação depois de ativar a autenticação de dois fatores na sua conta Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'A reposição da palavra-passe da conta Apple revoga as palavras-passe específicas de aplicações.';

  @override
  String get connectNextcloudTitle => 'Ligar ao Nextcloud';

  @override
  String get nextcloudServerUrl => 'Servidor Nextcloud ou endereço CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Introduza o URL do servidor Nextcloud ou cole o endereço CalDAV principal copiado do Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'O BusyMax abrirá o navegador. Aprove o acesso aí e volte ao BusyMax.';

  @override
  String get connectAccountAction => 'Ligar';

  @override
  String get cancelAccountConnection => 'Cancelar ligação';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'A conta foi removida localmente, mas não foi possível revogar a palavra-passe da aplicação Nextcloud.';

  @override
  String get davCachedOfflineNotice =>
      'Os dados de calendários e tarefas são colocados em cache localmente para utilização offline.';

  @override
  String get davReauthenticationRequired =>
      'Volte a ligar esta conta para retomar a sincronização.';

  @override
  String get davTemporarilyUnavailable =>
      'Esta conta está temporariamente indisponível.';

  @override
  String get davPermissionChanged =>
      'As permissões do servidor foram alteradas. As edições pendentes estão em pausa.';

  @override
  String get davUnsupportedServer =>
      'Este servidor ou perfil do fornecedor não é suportado.';

  @override
  String get collectionSettings => 'Calendários e listas de tarefas';

  @override
  String get calendarContent => 'Eventos do calendário';

  @override
  String get taskContent => 'Tarefas';

  @override
  String get readOnlySharedCollection => 'Só de leitura';

  @override
  String get pendingLocally => 'Pendente localmente';

  @override
  String get conflictBlocked => 'Bloqueado por conflito';

  @override
  String get authenticationBlocked => 'Bloqueado até voltar a ligar';

  @override
  String get operationFailed => 'Operação falhou';

  @override
  String get keepServerVersion => 'Manter versão do servidor';

  @override
  String get reapplyLocalChange => 'Rever e reaplicar alteração local';

  @override
  String get duplicateLocalItem => 'Duplicar como novo item';

  @override
  String get davConnectionState => 'Estado da ligação';

  @override
  String get davConnected => 'Ligado';

  @override
  String get davConnecting => 'A ligar…';

  @override
  String get davSignedOut => 'Sessão terminada';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Última sincronização bem-sucedida: $time';
  }

  @override
  String get davNeverSynced => 'Ainda não sincronizado';

  @override
  String get refreshCollections => 'Atualizar calendários e listas de tarefas';

  @override
  String nextcloudServerHost(String host) {
    return 'Servidor: $host';
  }

  @override
  String get collectionSupportsEvents => 'Calendário de eventos';

  @override
  String get collectionSupportsTasks => 'Lista de tarefas';

  @override
  String get collectionSupportsEventsAndTasks => 'Eventos e tarefas';

  @override
  String get writableCollection => 'Editável';

  @override
  String get sharedCollection => 'Partilhado';

  @override
  String collectionLastSynced(String time) {
    return 'Última sincronização: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Problema de sincronização: $code';
  }

  @override
  String get syncConflicts => 'Conflitos de sincronização';

  @override
  String remoteChangedAt(String time) {
    return 'Alteração no servidor: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Edição local: $summary';
  }

  @override
  String get conflictResolutionFailed =>
      'Não foi possível resolver o conflito.';

  @override
  String get recurringEventScope => 'Âmbito do evento recorrente';

  @override
  String get entireSeries => 'Série inteira';

  @override
  String get singleOccurrence => 'Este evento';

  @override
  String get thisAndFollowingEvents => 'Este evento e os seguintes';

  @override
  String get thisAndFutureUnavailable => 'Não suportado por este fornecedor.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Este evento e os seguintes não podem ser movidos com segurança. Escolha este evento ou a série inteira.';

  @override
  String get entireSeriesMoveUnavailable =>
      'A regra de recorrência não está disponível localmente. Mova apenas este evento.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Copiar o evento e eliminar o original?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'O BusyMax não pode mover este evento diretamente de $source para $destination. Criará primeiro a cópia e eliminará o original apenas depois de a cópia ser criada com êxito. Os IDs do evento mudarão; os estados das respostas dos participantes poderão ser repostos e poderão ser enviados convites ou cancelamentos; as ligações de reuniões, os anexos, os lembretes, os campos específicos do fornecedor e as exceções de recorrência poderão não ser transferidos.';
  }

  @override
  String get copyAndDelete => 'Copiar e eliminar';

  @override
  String get chooseRecurringEventScope =>
      'Escolha se esta alteração se aplica à série inteira, apenas a este evento ou a este e aos eventos seguintes.';

  @override
  String get taskDueBeforeStart => 'O prazo não pode ser anterior ao início.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Defina horários para o início e o prazo, ou torne a tarefa de dia inteiro.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Eliminar «$title»?';
  }

  @override
  String get setCustomCalendarName => 'Definir nome personalizado';

  @override
  String get setAction => 'Definir';

  @override
  String get removeFromMyCalendars => 'Remover dos meus calendários';

  @override
  String get removeAction => 'Remover';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Remover \"$title\" da sua lista do Google Calendar? O calendário partilhado e os respetivos eventos não serão eliminados.';
  }

  @override
  String get calendarCannotRemove =>
      'Não é possível eliminar nem remover este calendário desta conta.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Aguarde que as alterações pendentes deste calendário terminem de sincronizar antes de o eliminar ou remover.';

  @override
  String get calendarSubscriptions => 'Subscrições de calendários';

  @override
  String get calendarSubscriptionsDescription =>
      'Adicione calendários só de leitura que sejam atualizados a partir de um URL WebCal seguro.';

  @override
  String get addCalendarSubscription => 'Adicionar subscrição de calendário';

  @override
  String get subscriptionName => 'Nome local';

  @override
  String get subscriptionUrl => 'URL da subscrição';

  @override
  String get subscriptionUrlHelp =>
      'Introduza um URL HTTPS ou webcal. O BusyMax mantém o URL completo num armazenamento seguro.';

  @override
  String get subscriptionUrlInvalid =>
      'Introduza um URL HTTPS ou webcal válido sem informações de utilizador ou fragmento.';

  @override
  String get subscriptionColor => 'Cor local';

  @override
  String get subscriptionColorHelp =>
      'Utilize uma cor de seis dígitos, como #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Introduza uma cor hexadecimal de seis dígitos.';

  @override
  String get subscriptionRefreshMode => 'Frequência de atualização';

  @override
  String get subscriptionAutomatic => 'Automática';

  @override
  String get subscriptionHourly => 'De hora a hora';

  @override
  String get subscriptionSixHours => 'A cada seis horas';

  @override
  String get subscriptionDaily => 'Diária';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Origem: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Introduza um URL válido para pré-visualizar a origem segura.';

  @override
  String get subscriptionReadOnly => 'Subscrição só de leitura';

  @override
  String get subscriptionNeverRefreshed => 'Ainda não atualizada';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Última atualização bem-sucedida: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Próxima atualização: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Atualizada';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Problema de atualização: $code';
  }

  @override
  String get refreshNow => 'Atualizar agora';

  @override
  String get unsubscribe => 'Cancelar subscrição';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Cancelar subscrição de “$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Isto remove a subscrição local e os eventos colocados em cache. O calendário publicado não é alterado.';

  @override
  String get addSubscriptionAction => 'Adicionar subscrição';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Falha na subscrição do calendário: $error';
  }

  @override
  String get subscriptions => 'Subscrições';

  @override
  String get calendarImport => 'Importação de calendário';

  @override
  String get calendarImportDescription =>
      'Selecione um ficheiro, reveja os eventos e escolha o calendário editável que os deve receber.';

  @override
  String get importIcsFile => 'Importar ficheiro .ics';

  @override
  String get importIcsPreview => 'Importar eventos do calendário';

  @override
  String importEventsFound(int count) {
    return 'Conjuntos de eventos importáveis: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Eventos inválidos: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Omitidos intencionalmente: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Não está disponível nenhum calendário de destino editável.';

  @override
  String get importDestinationCalendar => 'Calendário de destino';

  @override
  String get importIcsConfirm => 'Importar eventos';

  @override
  String get importIcsComplete => 'Importação concluída';

  @override
  String importQueued(int count) {
    return 'Importados ou em fila: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Duplicados ignorados: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Conjuntos de recorrência não suportados: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Não foi possível importar o ficheiro de calendário: $error';
  }

  @override
  String get networkOffline => 'Sem ligação';

  @override
  String get networkOfflineDescription =>
      'As alterações serão sincronizadas quando a ligação for restabelecida.';

  @override
  String get networkOfflineTryAgain =>
      'Está offline. Ligue-se à Internet e tente novamente.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'nos dias $days';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first e $second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first e $second';
  }

  @override
  String repeatMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first e $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first e $second';
  }

  @override
  String repeatYearlyMonthListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyOnMonthDaySummary(
    String frequency,
    String month,
    String day,
  ) {
    return '$frequency no dia $day de $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency nos dias $days de $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency no dia $day de $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency nos dias $days de $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'na primeira ocorrência de $days de $month',
      'second': 'na segunda ocorrência de $days de $month',
      'third': 'na terceira ocorrência de $days de $month',
      'fourth': 'na quarta ocorrência de $days de $month',
      'fifth': 'na quinta ocorrência de $days de $month',
      'secondToLast': 'na penúltima ocorrência de $days de $month',
      'last': 'na última ocorrência de $days de $month',
      'other': 'em $days de $month',
    });
    return '$frequency $_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'na primeira ocorrência de $days de $months',
      'second': 'na segunda ocorrência de $days de $months',
      'third': 'na terceira ocorrência de $days de $months',
      'fourth': 'na quarta ocorrência de $days de $months',
      'fifth': 'na quinta ocorrência de $days de $months',
      'secondToLast': 'na penúltima ocorrência de $days de $months',
      'last': 'na última ocorrência de $days de $months',
      'other': 'em $days de $months',
    });
    return '$frequency $_temp0';
  }
}

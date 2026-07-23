import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BusyMax'**
  String get appTitle;

  /// No description provided for @connectGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect Google and Microsoft accounts to sync calendars and tasks.'**
  String get connectGoogleAccount;

  /// No description provided for @googlePermissionsConsentNotice.
  ///
  /// In en, this message translates to:
  /// **'On the Google permission screen, select both Calendar and Tasks permissions.'**
  String get googlePermissionsConsentNotice;

  /// No description provided for @googlePermissionsRequiredRetry.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar and Google Tasks permissions are required. Please try again and select both checkboxes.'**
  String get googlePermissionsRequiredRetry;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get finishSetup;

  /// No description provided for @continueSetup.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueSetup;

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up BusyMax'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingAccountsStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect accounts'**
  String get onboardingAccountsStepTitle;

  /// No description provided for @onboardingAccountsStepDescription.
  ///
  /// In en, this message translates to:
  /// **'Add all Google and Microsoft accounts you want to use. BusyMax syncs calendars, events, task lists, and tasks from each account.'**
  String get onboardingAccountsStepDescription;

  /// No description provided for @onboardingPreferencesStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose system settings'**
  String get onboardingPreferencesStepTitle;

  /// No description provided for @onboardingPreferencesStepDescription.
  ///
  /// In en, this message translates to:
  /// **'Set desktop behavior, reminders, notification detail, and appearance before opening your schedule.'**
  String get onboardingPreferencesStepDescription;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithMicrosoft.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Microsoft'**
  String get signInWithMicrosoft;

  /// No description provided for @googleTasksProvider.
  ///
  /// In en, this message translates to:
  /// **'Google Tasks'**
  String get googleTasksProvider;

  /// No description provided for @microsoftTodoProvider.
  ///
  /// In en, this message translates to:
  /// **'Microsoft To Do'**
  String get microsoftTodoProvider;

  /// No description provided for @providerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This provider is not configured.'**
  String get providerNotConfigured;

  /// No description provided for @waitingForGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Google sign-in...'**
  String get waitingForGoogleSignIn;

  /// No description provided for @waitingForMicrosoftSignIn.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Microsoft sign-in...'**
  String get waitingForMicrosoftSignIn;

  /// No description provided for @microsoftSignInNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Microsoft sign-in is not configured. Set MICROSOFT_OAUTH_CLIENT_ID.'**
  String get microsoftSignInNotConfigured;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @calendarEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get calendarEvents;

  /// No description provided for @calendarTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get calendarTasks;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @calendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get calendars;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @refreshCalendar.
  ///
  /// In en, this message translates to:
  /// **'Refresh calendar'**
  String get refreshCalendar;

  /// No description provided for @openInProvider.
  ///
  /// In en, this message translates to:
  /// **'Open in provider'**
  String get openInProvider;

  /// No description provided for @hideFromSchedule.
  ///
  /// In en, this message translates to:
  /// **'Hide from schedule'**
  String get hideFromSchedule;

  /// No description provided for @showInSchedule.
  ///
  /// In en, this message translates to:
  /// **'Show in schedule'**
  String get showInSchedule;

  /// No description provided for @noCalendarsSynced.
  ///
  /// In en, this message translates to:
  /// **'No calendars synced yet.'**
  String get noCalendarsSynced;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreItems(int count);

  /// No description provided for @noEventsOrTasks.
  ///
  /// In en, this message translates to:
  /// **'No events or tasks'**
  String get noEventsOrTasks;

  /// No description provided for @scheduleLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading schedule...'**
  String get scheduleLoading;

  /// No description provided for @scheduleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Schedule unavailable'**
  String get scheduleUnavailable;

  /// No description provided for @scheduleNoSources.
  ///
  /// In en, this message translates to:
  /// **'No visible calendars or task lists'**
  String get scheduleNoSources;

  /// No description provided for @scheduleNoSourcesDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose what to show in Settings, then refresh.'**
  String get scheduleNoSourcesDescription;

  /// No description provided for @scheduleSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect an account'**
  String get scheduleSignInRequired;

  /// No description provided for @scheduleSignInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync calendars and tasks.'**
  String get scheduleSignInDescription;

  /// No description provided for @scheduleNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching events or tasks'**
  String get scheduleNoSearchResults;

  /// No description provided for @scheduleNoSearchResultsDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or clear the current filters.'**
  String get scheduleNoSearchResultsDescription;

  /// No description provided for @trayAgendaLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading agenda...'**
  String get trayAgendaLoading;

  /// No description provided for @trayAgendaSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to show agenda.'**
  String get trayAgendaSignInRequired;

  /// No description provided for @trayAgendaNoSources.
  ///
  /// In en, this message translates to:
  /// **'No visible calendars or task lists.'**
  String get trayAgendaNoSources;

  /// No description provided for @trayAgendaOpenBusyMax.
  ///
  /// In en, this message translates to:
  /// **'Open app'**
  String get trayAgendaOpenBusyMax;

  /// No description provided for @trayAgendaRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get trayAgendaRefresh;

  /// No description provided for @trayAgendaError.
  ///
  /// In en, this message translates to:
  /// **'Agenda unavailable'**
  String get trayAgendaError;

  /// No description provided for @compactAgendaTitle.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get compactAgendaTitle;

  /// No description provided for @compactAgendaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get compactAgendaSubtitle;

  /// No description provided for @compactAgendaOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get compactAgendaOverdue;

  /// No description provided for @compactAgendaClear.
  ///
  /// In en, this message translates to:
  /// **'Clear for now'**
  String get compactAgendaClear;

  /// No description provided for @compactAgendaOpenBusyMax.
  ///
  /// In en, this message translates to:
  /// **'Open BusyMax'**
  String get compactAgendaOpenBusyMax;

  /// No description provided for @compactAgendaHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get compactAgendaHide;

  /// No description provided for @compactAgendaNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get compactAgendaNewTask;

  /// No description provided for @compactAgendaRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get compactAgendaRetry;

  /// No description provided for @compactAgendaRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get compactAgendaRefresh;

  /// No description provided for @compactAgendaAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get compactAgendaAllDay;

  /// No description provided for @compactAgendaDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get compactAgendaDueToday;

  /// No description provided for @compactAgendaDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get compactAgendaDueTomorrow;

  /// No description provided for @compactAgendaDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String compactAgendaDueOn(String date);

  /// No description provided for @compactAgendaMoreOverdue.
  ///
  /// In en, this message translates to:
  /// **'Load more overdue tasks'**
  String get compactAgendaMoreOverdue;

  /// No description provided for @agendaLoadMoreOverdue.
  ///
  /// In en, this message translates to:
  /// **'Load more overdue tasks'**
  String get agendaLoadMoreOverdue;

  /// No description provided for @agendaLoadMoreNoDate.
  ///
  /// In en, this message translates to:
  /// **'Load more no-date tasks'**
  String get agendaLoadMoreNoDate;

  /// No description provided for @viewDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get viewDay;

  /// No description provided for @viewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get viewWeek;

  /// No description provided for @viewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get viewMonth;

  /// No description provided for @viewYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get viewYear;

  /// No description provided for @viewAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get viewAgenda;

  /// No description provided for @scheduleSettings.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleSettings;

  /// No description provided for @scheduleDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'Schedule display'**
  String get scheduleDisplaySettings;

  /// No description provided for @scheduleDisplayHoursDescription.
  ///
  /// In en, this message translates to:
  /// **'Day and Week views open within these hours. Early and late items expand the range when needed.'**
  String get scheduleDisplayHoursDescription;

  /// No description provided for @scheduleDayStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Day starts at'**
  String get scheduleDayStartsAt;

  /// No description provided for @scheduleDayEndsAt.
  ///
  /// In en, this message translates to:
  /// **'Day ends at'**
  String get scheduleDayEndsAt;

  /// No description provided for @sourceCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get sourceCalendar;

  /// No description provided for @sourceTaskList.
  ///
  /// In en, this message translates to:
  /// **'Task list'**
  String get sourceTaskList;

  /// No description provided for @createChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createChoiceTitle;

  /// No description provided for @createEventAtTime.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get createEventAtTime;

  /// No description provided for @createTaskAtDate.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get createTaskAtDate;

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEvent;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventTitle;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @timeSlot.
  ///
  /// In en, this message translates to:
  /// **'Time slot'**
  String get timeSlot;

  /// No description provided for @timeMode.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeMode;

  /// No description provided for @timeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use dates only or set specific times.'**
  String get timeModeDescription;

  /// No description provided for @startDateTime.
  ///
  /// In en, this message translates to:
  /// **'Start date/time'**
  String get startDateTime;

  /// No description provided for @endDateTime.
  ///
  /// In en, this message translates to:
  /// **'End date/time'**
  String get endDateTime;

  /// No description provided for @doesNotRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get doesNotRepeat;

  /// No description provided for @defaultReminder.
  ///
  /// In en, this message translates to:
  /// **'Default reminder'**
  String get defaultReminder;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get guests;

  /// No description provided for @noGuests.
  ///
  /// In en, this message translates to:
  /// **'No guests'**
  String get noGuests;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @availabilityShowAs.
  ///
  /// In en, this message translates to:
  /// **'Availability / Show as'**
  String get availabilityShowAs;

  /// No description provided for @busy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get busy;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @defaultVisibility.
  ///
  /// In en, this message translates to:
  /// **'Default visibility'**
  String get defaultVisibility;

  /// No description provided for @conference.
  ///
  /// In en, this message translates to:
  /// **'Conference'**
  String get conference;

  /// No description provided for @noConference.
  ///
  /// In en, this message translates to:
  /// **'No conference'**
  String get noConference;

  /// No description provided for @providerCalendar.
  ///
  /// In en, this message translates to:
  /// **'Provider calendar'**
  String get providerCalendar;

  /// No description provided for @formatBoldShortLabel.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get formatBoldShortLabel;

  /// No description provided for @formatBoldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get formatBoldTooltip;

  /// No description provided for @formatItalicShortLabel.
  ///
  /// In en, this message translates to:
  /// **'I'**
  String get formatItalicShortLabel;

  /// No description provided for @formatItalicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get formatItalicTooltip;

  /// No description provided for @formatUnderlineShortLabel.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get formatUnderlineShortLabel;

  /// No description provided for @formatUnderlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get formatUnderlineTooltip;

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute before} other{{minutes} minutes before}}'**
  String reminderMinutesBefore(int minutes);

  /// No description provided for @reminderAtStart.
  ///
  /// In en, this message translates to:
  /// **'At start'**
  String get reminderAtStart;

  /// No description provided for @reminderHoursBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour before} other{{hours} hours before}}'**
  String reminderHoursBefore(int hours);

  /// No description provided for @reminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day before} other{{days} days before}}'**
  String reminderDaysBefore(int days);

  /// No description provided for @availabilityFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get availabilityFree;

  /// No description provided for @availabilityTentative.
  ///
  /// In en, this message translates to:
  /// **'Tentative'**
  String get availabilityTentative;

  /// No description provided for @availabilityOutOfOffice.
  ///
  /// In en, this message translates to:
  /// **'Out of office'**
  String get availabilityOutOfOffice;

  /// No description provided for @availabilityWorkingElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Working elsewhere'**
  String get availabilityWorkingElsewhere;

  /// No description provided for @visibilityDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get visibilityDefault;

  /// No description provided for @visibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get visibilityPublic;

  /// No description provided for @visibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get visibilityPrivate;

  /// No description provided for @visibilityConfidential.
  ///
  /// In en, this message translates to:
  /// **'Confidential'**
  String get visibilityConfidential;

  /// No description provided for @sensitivityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get sensitivityNormal;

  /// No description provided for @sensitivityPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get sensitivityPersonal;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get allTasks;

  /// No description provided for @tasksInList.
  ///
  /// In en, this message translates to:
  /// **'Tasks in {title}'**
  String tasksInList(String title);

  /// No description provided for @taskLists.
  ///
  /// In en, this message translates to:
  /// **'Task lists'**
  String get taskLists;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @mainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenu;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @shortcutGroupGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get shortcutGroupGeneral;

  /// No description provided for @shortcutKeyboardShortcutsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show this shortcuts reference'**
  String get shortcutKeyboardShortcutsDescription;

  /// No description provided for @shortcutGroupNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get shortcutGroupNavigation;

  /// No description provided for @shortcutNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get shortcutNextPeriod;

  /// No description provided for @shortcutNextPeriodDescription.
  ///
  /// In en, this message translates to:
  /// **'Next week in week view, next month in month view, and so on'**
  String get shortcutNextPeriodDescription;

  /// No description provided for @shortcutPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get shortcutPreviousPeriod;

  /// No description provided for @shortcutPreviousPeriodDescription.
  ///
  /// In en, this message translates to:
  /// **'Previous week in week view, previous month in month view, and so on'**
  String get shortcutPreviousPeriodDescription;

  /// No description provided for @shortcutJumpToToday.
  ///
  /// In en, this message translates to:
  /// **'Jump to today'**
  String get shortcutJumpToToday;

  /// No description provided for @shortcutGroupView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get shortcutGroupView;

  /// No description provided for @shortcutDayView.
  ///
  /// In en, this message translates to:
  /// **'Day view'**
  String get shortcutDayView;

  /// No description provided for @shortcutWeekView.
  ///
  /// In en, this message translates to:
  /// **'Week view'**
  String get shortcutWeekView;

  /// No description provided for @shortcutMonthView.
  ///
  /// In en, this message translates to:
  /// **'Month view'**
  String get shortcutMonthView;

  /// No description provided for @shortcutYearView.
  ///
  /// In en, this message translates to:
  /// **'Year view'**
  String get shortcutYearView;

  /// No description provided for @shortcutAgendaView.
  ///
  /// In en, this message translates to:
  /// **'Agenda view'**
  String get shortcutAgendaView;

  /// No description provided for @shortcutGroupCreateAndEdit.
  ///
  /// In en, this message translates to:
  /// **'Create and Edit'**
  String get shortcutGroupCreateAndEdit;

  /// No description provided for @shortcutSaveItem.
  ///
  /// In en, this message translates to:
  /// **'Save event or task'**
  String get shortcutSaveItem;

  /// No description provided for @shortcutDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete event or task'**
  String get shortcutDeleteItem;

  /// No description provided for @shortcutGroupTaskEditing.
  ///
  /// In en, this message translates to:
  /// **'Task editing'**
  String get shortcutGroupTaskEditing;

  /// No description provided for @shortcutCancelEditing.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get shortcutCancelEditing;

  /// No description provided for @shortcutCancelEditingDescription.
  ///
  /// In en, this message translates to:
  /// **'Close task editing or task details'**
  String get shortcutCancelEditingDescription;

  /// No description provided for @shortcutGroupCompactAgenda.
  ///
  /// In en, this message translates to:
  /// **'Compact agenda'**
  String get shortcutGroupCompactAgenda;

  /// No description provided for @shortcutRefreshCompactAgendaDescription.
  ///
  /// In en, this message translates to:
  /// **'Refresh the compact agenda window'**
  String get shortcutRefreshCompactAgendaDescription;

  /// No description provided for @shortcutHideCompactAgendaDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide the compact agenda window'**
  String get shortcutHideCompactAgendaDescription;

  /// No description provided for @aboutBusyMax.
  ///
  /// In en, this message translates to:
  /// **'About BusyMax'**
  String get aboutBusyMax;

  /// No description provided for @aboutBusyMaxDescription.
  ///
  /// In en, this message translates to:
  /// **'ToDo and Calendar'**
  String get aboutBusyMaxDescription;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @reportAnIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get reportAnIssue;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @feedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get feedbackSubmit;

  /// No description provided for @feedbackCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get feedbackCategory;

  /// No description provided for @feedbackSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get feedbackSelectCategory;

  /// No description provided for @feedbackCategoryProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem or bug'**
  String get feedbackCategoryProblem;

  /// No description provided for @feedbackCategoryFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature request'**
  String get feedbackCategoryFeature;

  /// No description provided for @feedbackCategoryPrivacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy or security concern'**
  String get feedbackCategoryPrivacySecurity;

  /// No description provided for @feedbackCategoryUsability.
  ///
  /// In en, this message translates to:
  /// **'Usability concern'**
  String get feedbackCategoryUsability;

  /// No description provided for @feedbackCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get feedbackCategoryOther;

  /// No description provided for @feedbackSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get feedbackSubject;

  /// No description provided for @feedbackDetailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Detailed message'**
  String get feedbackDetailedMessage;

  /// No description provided for @feedbackReplyEmail.
  ///
  /// In en, this message translates to:
  /// **'Reply email (optional)'**
  String get feedbackReplyEmail;

  /// No description provided for @feedbackIncludeTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Include technical details'**
  String get feedbackIncludeTechnicalDetails;

  /// No description provided for @feedbackTechnicalDetailsDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Adds only your Linux operating-system version and application locale. No logs, account data, file names, or other diagnostics are included.'**
  String get feedbackTechnicalDetailsDisclosure;

  /// No description provided for @feedbackCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a category.'**
  String get feedbackCategoryRequired;

  /// No description provided for @feedbackSubjectLengthError.
  ///
  /// In en, this message translates to:
  /// **'Subject must be between 3 and 120 characters.'**
  String get feedbackSubjectLengthError;

  /// No description provided for @feedbackMessageLengthError.
  ///
  /// In en, this message translates to:
  /// **'Message must be between 10 and 5,000 characters.'**
  String get feedbackMessageLengthError;

  /// No description provided for @feedbackInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get feedbackInvalidEmail;

  /// No description provided for @feedbackConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to BusyStack. Check your connection and try again.'**
  String get feedbackConnectionError;

  /// No description provided for @feedbackTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Your feedback has not been cleared; please try again.'**
  String get feedbackTimeoutError;

  /// No description provided for @feedbackRateLimitedError.
  ///
  /// In en, this message translates to:
  /// **'Too many feedback submissions have been sent from this network. Please wait and try again.'**
  String get feedbackRateLimitedError;

  /// No description provided for @feedbackRejectedError.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the submission. Review the fields and try again.'**
  String get feedbackRejectedError;

  /// No description provided for @feedbackServerError.
  ///
  /// In en, this message translates to:
  /// **'BusyStack could not accept your feedback right now. Your feedback has not been cleared; please try again.'**
  String get feedbackServerError;

  /// No description provided for @feedbackSuccess.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent. Reference: {id}'**
  String feedbackSuccess(String id);

  /// No description provided for @toggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get toggleSidebar;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @currentAccount.
  ///
  /// In en, this message translates to:
  /// **'Current account'**
  String get currentAccount;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchAccount;

  /// No description provided for @addGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Google account'**
  String get addGoogleAccount;

  /// No description provided for @addMicrosoftAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Microsoft account'**
  String get addMicrosoftAccount;

  /// No description provided for @googleProvider.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get googleProvider;

  /// No description provided for @microsoftProvider.
  ///
  /// In en, this message translates to:
  /// **'Microsoft'**
  String get microsoftProvider;

  /// No description provided for @signedInAccount.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedInAccount;

  /// No description provided for @removeAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove account…'**
  String get removeAccount;

  /// No description provided for @removingAccount.
  ///
  /// In en, this message translates to:
  /// **'Removing account…'**
  String get removingAccount;

  /// No description provided for @removeAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'Stop syncing and remove this account’s data from this device.'**
  String get removeAccountDescription;

  /// No description provided for @removeAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {account} from BusyMax?'**
  String removeAccountTitle(String account);

  /// No description provided for @removeAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Nothing will be deleted from Google or Microsoft.'**
  String get removeAccountConfirmation;

  /// No description provided for @revokeGoogleAccess.
  ///
  /// In en, this message translates to:
  /// **'Also revoke BusyMax’s access to this Google Account'**
  String get revokeGoogleAccess;

  /// No description provided for @revokeGoogleAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'You will need to grant access again before reconnecting.'**
  String get revokeGoogleAccessDescription;

  /// No description provided for @removeAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Remove account'**
  String get removeAccountAction;

  /// No description provided for @removeAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not finish removing the account. Try again.'**
  String get removeAccountFailed;

  /// No description provided for @accountRemovedGoogleRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'The account was removed from this device, but BusyMax could not revoke Google access. You can revoke it from your Google Account.'**
  String get accountRemovedGoogleRevokeFailed;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @signInToViewTaskLists.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view task lists.'**
  String get signInToViewTaskLists;

  /// No description provided for @noTaskListsSynced.
  ///
  /// In en, this message translates to:
  /// **'No task lists synced yet.'**
  String get noTaskListsSynced;

  /// No description provided for @listActions.
  ///
  /// In en, this message translates to:
  /// **'List actions'**
  String get listActions;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @renameList.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get renameList;

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteList;

  /// No description provided for @builtInMicrosoftList.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtInMicrosoftList;

  /// No description provided for @builtInMicrosoftListCannotRenameDelete.
  ///
  /// In en, this message translates to:
  /// **'Built-in Microsoft To Do lists cannot be renamed or deleted.'**
  String get builtInMicrosoftListCannotRenameDelete;

  /// No description provided for @deleteListConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" from Google Tasks?'**
  String deleteListConfirmation(String title);

  /// No description provided for @deleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get deleteEvent;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @clearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get clearCompleted;

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get refreshList;

  /// No description provided for @refreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh all'**
  String get refreshAll;

  /// No description provided for @listRefreshed.
  ///
  /// In en, this message translates to:
  /// **'List refreshed.'**
  String get listRefreshed;

  /// No description provided for @allTasksRefreshed.
  ///
  /// In en, this message translates to:
  /// **'All accounts refreshed.'**
  String get allTasksRefreshed;

  /// No description provided for @exportedFile.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportedFile(String path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String refreshFailed(String error);

  /// No description provided for @selectOrCreateTaskList.
  ///
  /// In en, this message translates to:
  /// **'Select or create a task list to begin.'**
  String get selectOrCreateTaskList;

  /// No description provided for @signInToViewTasks.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view tasks.'**
  String get signInToViewTasks;

  /// No description provided for @noTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks.'**
  String get noTasks;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasksYet;

  /// No description provided for @noTasksYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a task or refresh your accounts to get started.'**
  String get noTasksYetMessage;

  /// No description provided for @noTasksInList.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this list.'**
  String get noTasksInList;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @noDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get noDate;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @duePrefix.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String duePrefix(String date);

  /// No description provided for @dateTimeDisplay.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String dateTimeDisplay(String date, String time);

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @noTaskSelected.
  ///
  /// In en, this message translates to:
  /// **'No task selected.'**
  String get noTaskSelected;

  /// No description provided for @noTaskSelectedHelper.
  ///
  /// In en, this message translates to:
  /// **'Select a task to view and edit details.'**
  String get noTaskSelectedHelper;

  /// No description provided for @taskUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Task unavailable.'**
  String get taskUnavailable;

  /// No description provided for @signInToEditTasks.
  ///
  /// In en, this message translates to:
  /// **'Sign in to edit tasks.'**
  String get signInToEditTasks;

  /// No description provided for @refreshTask.
  ///
  /// In en, this message translates to:
  /// **'Refresh task'**
  String get refreshTask;

  /// No description provided for @primarySection.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primarySection;

  /// No description provided for @statusSection.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusSection;

  /// No description provided for @openStatus.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openStatus;

  /// No description provided for @doneStatus.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneStatus;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @clearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get clearDueDate;

  /// No description provided for @dueTime.
  ///
  /// In en, this message translates to:
  /// **'Due time'**
  String get dueTime;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @reminderDate.
  ///
  /// In en, this message translates to:
  /// **'Reminder date'**
  String get reminderDate;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add Reminder'**
  String get addReminder;

  /// No description provided for @addGuest.
  ///
  /// In en, this message translates to:
  /// **'Add Guest'**
  String get addGuest;

  /// No description provided for @addGuestEmail.
  ///
  /// In en, this message translates to:
  /// **'Add guest email'**
  String get addGuestEmail;

  /// No description provided for @removeReminder.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get removeReminder;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get repeatNone;

  /// No description provided for @noneValue.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneValue;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get repeatYearly;

  /// No description provided for @importance.
  ///
  /// In en, this message translates to:
  /// **'Importance'**
  String get importance;

  /// No description provided for @importanceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get importanceLow;

  /// No description provided for @importanceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get importanceNormal;

  /// No description provided for @importanceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get importanceHigh;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @scheduleSection.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleSection;

  /// No description provided for @dueGroup.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get dueGroup;

  /// No description provided for @startGroup.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startGroup;

  /// No description provided for @reminderGroup.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderGroup;

  /// No description provided for @organizationSection.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organizationSection;

  /// No description provided for @actionsSection.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsSection;

  /// No description provided for @advancedSection.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSection;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @microsoftMoveUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Moving between lists is not supported for Microsoft To Do accounts in this version.'**
  String get microsoftMoveUnsupported;

  /// No description provided for @createSubtask.
  ///
  /// In en, this message translates to:
  /// **'Create subtask'**
  String get createSubtask;

  /// No description provided for @moveToTop.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get moveToTop;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTask;

  /// No description provided for @newSubtask.
  ///
  /// In en, this message translates to:
  /// **'New subtask'**
  String get newSubtask;

  /// No description provided for @deleteTaskConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" from Google Tasks?'**
  String deleteTaskConfirmation(String title);

  /// No description provided for @metadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadata;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @etag.
  ///
  /// In en, this message translates to:
  /// **'ETag'**
  String get etag;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @parent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parent;

  /// No description provided for @position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// No description provided for @webLink.
  ///
  /// In en, this message translates to:
  /// **'Web link'**
  String get webLink;

  /// No description provided for @assignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get assignment;

  /// No description provided for @localState.
  ///
  /// In en, this message translates to:
  /// **'Local state'**
  String get localState;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @manualFullSync.
  ///
  /// In en, this message translates to:
  /// **'Manual full sync'**
  String get manualFullSync;

  /// No description provided for @runInBackgroundWhenClosed.
  ///
  /// In en, this message translates to:
  /// **'Continue running when the window is closed'**
  String get runInBackgroundWhenClosed;

  /// No description provided for @showTrayIcon.
  ///
  /// In en, this message translates to:
  /// **'Show tray icon'**
  String get showTrayIcon;

  /// No description provided for @startMinimizedToTray.
  ///
  /// In en, this message translates to:
  /// **'Start minimized to the tray'**
  String get startMinimizedToTray;

  /// No description provided for @requiresTrayIcon.
  ///
  /// In en, this message translates to:
  /// **'Requires the tray icon.'**
  String get requiresTrayIcon;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete.'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed(String error);

  /// No description provided for @notifySyncFailures.
  ///
  /// In en, this message translates to:
  /// **'Notifications on sync failure'**
  String get notifySyncFailures;

  /// No description provided for @notifyConflicts.
  ///
  /// In en, this message translates to:
  /// **'Notifications on conflicts'**
  String get notifyConflicts;

  /// No description provided for @notifyDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due-today notifications'**
  String get notifyDueToday;

  /// No description provided for @eventReminders.
  ///
  /// In en, this message translates to:
  /// **'Event reminders'**
  String get eventReminders;

  /// No description provided for @taskReminders.
  ///
  /// In en, this message translates to:
  /// **'Task reminders'**
  String get taskReminders;

  /// No description provided for @notificationDetailLevel.
  ///
  /// In en, this message translates to:
  /// **'Notification detail level'**
  String get notificationDetailLevel;

  /// No description provided for @notificationDetailPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get notificationDetailPrivate;

  /// No description provided for @notificationDetailNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get notificationDetailNormal;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @quietHoursDescription.
  ///
  /// In en, this message translates to:
  /// **'Pause notifications during this period.'**
  String get quietHoursDescription;

  /// No description provided for @quietHoursStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get quietHoursStart;

  /// No description provided for @quietHoursEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get quietHoursEnd;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeFamily.
  ///
  /// In en, this message translates to:
  /// **'Theme family'**
  String get themeFamily;

  /// No description provided for @themeFamilyYaru.
  ///
  /// In en, this message translates to:
  /// **'Native Ubuntu (Yaru)'**
  String get themeFamilyYaru;

  /// No description provided for @localization.
  ///
  /// In en, this message translates to:
  /// **'Localization'**
  String get localization;

  /// No description provided for @currentLocale.
  ///
  /// In en, this message translates to:
  /// **'Current locale'**
  String get currentLocale;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @redactTaskContentInDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Redact task content in diagnostics'**
  String get redactTaskContentInDiagnostics;

  /// No description provided for @developerDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Developer diagnostics'**
  String get developerDiagnostics;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @apiInspectorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Show API inspector'**
  String get apiInspectorDisabled;

  /// No description provided for @googleTasksApi.
  ///
  /// In en, this message translates to:
  /// **'Google Tasks API'**
  String get googleTasksApi;

  /// No description provided for @discoveryRevision.
  ///
  /// In en, this message translates to:
  /// **'Discovery revision: {revision}'**
  String discoveryRevision(String revision);

  /// No description provided for @implementedMethods.
  ///
  /// In en, this message translates to:
  /// **'Implemented methods'**
  String get implementedMethods;

  /// No description provided for @supportsTasksScopes.
  ///
  /// In en, this message translates to:
  /// **'Supports tasks and tasks.readonly scopes'**
  String get supportsTasksScopes;

  /// No description provided for @requiresTasksScope.
  ///
  /// In en, this message translates to:
  /// **'Requires tasks scope'**
  String get requiresTasksScope;

  /// No description provided for @blockedPendingOperations.
  ///
  /// In en, this message translates to:
  /// **'Blocked pending operations'**
  String get blockedPendingOperations;

  /// No description provided for @signInToInspectPendingOperations.
  ///
  /// In en, this message translates to:
  /// **'Sign in to inspect pending operations.'**
  String get signInToInspectPendingOperations;

  /// No description provided for @noBlockedPendingOperations.
  ///
  /// In en, this message translates to:
  /// **'No blocked pending operations.'**
  String get noBlockedPendingOperations;

  /// No description provided for @operationActions.
  ///
  /// In en, this message translates to:
  /// **'Operation actions'**
  String get operationActions;

  /// No description provided for @pendingOpListId.
  ///
  /// In en, this message translates to:
  /// **'list={id}'**
  String pendingOpListId(String id);

  /// No description provided for @pendingOpTaskId.
  ///
  /// In en, this message translates to:
  /// **'task={id}'**
  String pendingOpTaskId(String id);

  /// No description provided for @pendingOpAttempts.
  ///
  /// In en, this message translates to:
  /// **'attempts={count}'**
  String pendingOpAttempts(int count);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChanges;

  /// No description provided for @discardChangesConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This discards unsaved edits to this task.'**
  String get discardChangesConfirmation;

  /// No description provided for @retryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Retry completed.'**
  String get retryCompleted;

  /// No description provided for @discardPendingOperation.
  ///
  /// In en, this message translates to:
  /// **'Discard pending operation?'**
  String get discardPendingOperation;

  /// No description provided for @discardPendingOperationConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This removes the blocked local operation. The next sync will refresh from Google Tasks.'**
  String get discardPendingOperationConfirmation;

  /// No description provided for @pendingOperationDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Pending operation discarded.'**
  String get pendingOperationDiscarded;

  /// No description provided for @syncFailureNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'BusyMax sync failed'**
  String get syncFailureNotificationTitle;

  /// No description provided for @syncFailureNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Background sync failed. {message}'**
  String syncFailureNotificationBody(String message);

  /// No description provided for @conflictNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'BusyMax sync conflict'**
  String get conflictNotificationTitle;

  /// No description provided for @conflictNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'A pending local change was blocked. {summary}'**
  String conflictNotificationBody(String summary);

  /// No description provided for @dueTodayNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks due today'**
  String get dueTodayNotificationTitle;

  /// No description provided for @dueTodayNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One task is due today.} other{{count} tasks are due today.}}'**
  String dueTodayNotificationBody(int count);

  /// No description provided for @notificationDetailsHidden.
  ///
  /// In en, this message translates to:
  /// **'Details are hidden by privacy settings.'**
  String get notificationDetailsHidden;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @openMonthView.
  ///
  /// In en, this message translates to:
  /// **'Open month view'**
  String get openMonthView;

  /// No description provided for @previousYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get previousYear;

  /// No description provided for @nextYear.
  ///
  /// In en, this message translates to:
  /// **'Next year'**
  String get nextYear;

  /// No description provided for @openYearView.
  ///
  /// In en, this message translates to:
  /// **'Open year view'**
  String get openYearView;

  /// No description provided for @weekNumberTooltip.
  ///
  /// In en, this message translates to:
  /// **'Week {number}'**
  String weekNumberTooltip(int number);

  /// No description provided for @resizeAllDayPanel.
  ///
  /// In en, this message translates to:
  /// **'Resize the all-day panel'**
  String get resizeAllDayPanel;

  /// No description provided for @scheduleItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String scheduleItemCount(int count);

  /// No description provided for @readOnlyCalendar.
  ///
  /// In en, this message translates to:
  /// **'This calendar is read-only.'**
  String get readOnlyCalendar;

  /// No description provided for @deleteCalendarConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteCalendarConfirmation(String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

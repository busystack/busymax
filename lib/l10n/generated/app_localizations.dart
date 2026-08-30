// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_et.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

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
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('et'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BusyMax'**
  String get appTitle;

  /// Shown in account onboarding and settings; names the supported account providers.
  ///
  /// In en, this message translates to:
  /// **'Connect Google, Microsoft, Apple iCloud Calendar, or Nextcloud accounts.'**
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

  /// Onboarding explanation of the account data BusyMax synchronizes.
  ///
  /// In en, this message translates to:
  /// **'Add every account you want to use. BusyMax syncs supported calendars, events, task lists, and tasks from each account.'**
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

  /// No description provided for @newCalendar.
  ///
  /// In en, this message translates to:
  /// **'New calendar'**
  String get newCalendar;

  /// No description provided for @calendarColor.
  ///
  /// In en, this message translates to:
  /// **'Calendar color'**
  String get calendarColor;

  /// No description provided for @calendarColorOption.
  ///
  /// In en, this message translates to:
  /// **'Color {number}'**
  String calendarColorOption(int number);

  /// No description provided for @calendarManagementUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This provider does not support calendar management in BusyMax.'**
  String get calendarManagementUnsupported;

  /// No description provided for @primaryCalendarCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'The primary calendar cannot be deleted.'**
  String get primaryCalendarCannotDelete;

  /// No description provided for @calendarCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the calendar: {error}'**
  String calendarCreateFailed(String error);

  /// No description provided for @calendarCreatedRefreshPending.
  ///
  /// In en, this message translates to:
  /// **'The calendar was created, but BusyMax could not refresh the account. It will appear after the next sync.'**
  String get calendarCreatedRefreshPending;

  /// No description provided for @calendarUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the calendar: {error}'**
  String calendarUpdateFailed(String error);

  /// No description provided for @calendarDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the calendar: {error}'**
  String calendarDeleteFailed(String error);

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

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @trayOpenBusyMax.
  ///
  /// In en, this message translates to:
  /// **'Open BusyMax'**
  String get trayOpenBusyMax;

  /// No description provided for @trayShowBusyMax.
  ///
  /// In en, this message translates to:
  /// **'Show BusyMax'**
  String get trayShowBusyMax;

  /// No description provided for @trayNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event…'**
  String get trayNewEvent;

  /// No description provided for @trayNewTask.
  ///
  /// In en, this message translates to:
  /// **'New task…'**
  String get trayNewTask;

  /// No description provided for @trayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get trayToday;

  /// No description provided for @trayAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get trayAllDay;

  /// No description provided for @trayNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get trayNow;

  /// No description provided for @trayCalendarEvent.
  ///
  /// In en, this message translates to:
  /// **'Calendar event'**
  String get trayCalendarEvent;

  /// No description provided for @trayUntitledEvent.
  ///
  /// In en, this message translates to:
  /// **'Untitled event'**
  String get trayUntitledEvent;

  /// No description provided for @trayNothingElseToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing else today'**
  String get trayNothingElseToday;

  /// No description provided for @trayTasksDueToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task due today} other{{count} tasks due today}}'**
  String trayTasksDueToday(int count);

  /// No description provided for @trayOpenTodayAgenda.
  ///
  /// In en, this message translates to:
  /// **'Open today’s agenda'**
  String get trayOpenTodayAgenda;

  /// No description provided for @traySyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get traySyncNow;

  /// No description provided for @traySyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get traySyncing;

  /// No description provided for @trayNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get trayNotConnected;

  /// No description provided for @trayNotYetSynced.
  ///
  /// In en, this message translates to:
  /// **'Not yet synced'**
  String get trayNotYetSynced;

  /// No description provided for @trayLastSyncedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Last synced just now'**
  String get trayLastSyncedJustNow;

  /// No description provided for @trayLastSyncedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last synced 1 minute ago} other{Last synced {count} minutes ago}}'**
  String trayLastSyncedMinutesAgo(int count);

  /// No description provided for @trayLastSyncedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last synced 1 hour ago} other{Last synced {count} hours ago}}'**
  String trayLastSyncedHoursAgo(int count);

  /// No description provided for @trayLastSyncedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last synced 1 day ago} other{Last synced {count} days ago}}'**
  String trayLastSyncedDaysAgo(int count);

  /// No description provided for @traySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get traySettings;

  /// No description provided for @trayQuitBusyMax.
  ///
  /// In en, this message translates to:
  /// **'Quit BusyMax'**
  String get trayQuitBusyMax;

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

  /// No description provided for @attendeeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get attendeeRequired;

  /// No description provided for @attendeeOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get attendeeOptional;

  /// No description provided for @meetingSection.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingSection;

  /// No description provided for @addGoogleMeet.
  ///
  /// In en, this message translates to:
  /// **'Add Google Meet'**
  String get addGoogleMeet;

  /// No description provided for @addTeamsMeeting.
  ///
  /// In en, this message translates to:
  /// **'Add Microsoft Teams meeting'**
  String get addTeamsMeeting;

  /// No description provided for @onlineMeetingAdded.
  ///
  /// In en, this message translates to:
  /// **'Online meeting added'**
  String get onlineMeetingAdded;

  /// No description provided for @requestResponses.
  ///
  /// In en, this message translates to:
  /// **'Request responses'**
  String get requestResponses;

  /// No description provided for @requestResponsesDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask guests to respond to the invitation.'**
  String get requestResponsesDescription;

  /// No description provided for @hideGuestList.
  ///
  /// In en, this message translates to:
  /// **'Hide guest list'**
  String get hideGuestList;

  /// No description provided for @hideGuestListDescription.
  ///
  /// In en, this message translates to:
  /// **'Guests cannot see who else was invited.'**
  String get hideGuestListDescription;

  /// No description provided for @allowNewTimeProposals.
  ///
  /// In en, this message translates to:
  /// **'Allow new time proposals'**
  String get allowNewTimeProposals;

  /// No description provided for @allowNewTimeProposalsDescription.
  ///
  /// In en, this message translates to:
  /// **'Guests can suggest a different meeting time.'**
  String get allowNewTimeProposalsDescription;

  /// No description provided for @notifyGuestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notify guests?'**
  String get notifyGuestsTitle;

  /// No description provided for @notifyGuestsSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'This meeting has guests. Send invitations or event updates when it is saved?'**
  String get notifyGuestsSaveMessage;

  /// No description provided for @notifyGuestsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This meeting has guests. Send a cancellation when it is deleted?'**
  String get notifyGuestsDeleteMessage;

  /// No description provided for @sendUpdates.
  ///
  /// In en, this message translates to:
  /// **'Send updates'**
  String get sendUpdates;

  /// No description provided for @sendCancellation.
  ///
  /// In en, this message translates to:
  /// **'Send cancellation'**
  String get sendCancellation;

  /// No description provided for @doNotSend.
  ///
  /// In en, this message translates to:
  /// **'Don’t send'**
  String get doNotSend;

  /// No description provided for @microsoftNotifyGuestsSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save meeting?'**
  String get microsoftNotifyGuestsSaveTitle;

  /// No description provided for @microsoftNotifyGuestsSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Microsoft will send invitations or event updates to guests.'**
  String get microsoftNotifyGuestsSaveMessage;

  /// No description provided for @microsoftNotifyGuestsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete meeting?'**
  String get microsoftNotifyGuestsDeleteTitle;

  /// No description provided for @microsoftNotifyGuestsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Microsoft will send a cancellation to guests.'**
  String get microsoftNotifyGuestsDeleteMessage;

  /// No description provided for @organizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// No description provided for @yourResponse.
  ///
  /// In en, this message translates to:
  /// **'Your response'**
  String get yourResponse;

  /// No description provided for @guestResponses.
  ///
  /// In en, this message translates to:
  /// **'Guest responses'**
  String get guestResponses;

  /// No description provided for @respond.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get respond;

  /// No description provided for @acceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptInvitation;

  /// No description provided for @tentativeInvitation.
  ///
  /// In en, this message translates to:
  /// **'Tentative'**
  String get tentativeInvitation;

  /// No description provided for @declineInvitation.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineInvitation;

  /// No description provided for @joinMeeting.
  ///
  /// In en, this message translates to:
  /// **'Join meeting'**
  String get joinMeeting;

  /// No description provided for @responseAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get responseAccepted;

  /// No description provided for @responseTentative.
  ///
  /// In en, this message translates to:
  /// **'Tentative'**
  String get responseTentative;

  /// No description provided for @responseDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get responseDeclined;

  /// No description provided for @responseNeedsAction.
  ///
  /// In en, this message translates to:
  /// **'Awaiting response'**
  String get responseNeedsAction;

  /// No description provided for @responseNotResponded.
  ///
  /// In en, this message translates to:
  /// **'Not responded'**
  String get responseNotResponded;

  /// No description provided for @responseOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get responseOrganizer;

  /// No description provided for @invitationResponseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your response: {error}'**
  String invitationResponseFailed(String error);

  /// No description provided for @joinMeetingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the meeting link.'**
  String get joinMeetingFailed;

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

  /// No description provided for @aboutBusyMax.
  ///
  /// In en, this message translates to:
  /// **'About BusyMax'**
  String get aboutBusyMax;

  /// No description provided for @aboutBusyMaxDescription.
  ///
  /// In en, this message translates to:
  /// **'Calendar and tasks'**
  String get aboutBusyMaxDescription;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @apacheLicenseName.
  ///
  /// In en, this message translates to:
  /// **'Apache License 2.0'**
  String get apacheLicenseName;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

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

  /// No description provided for @showSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar panel'**
  String get showSidebar;

  /// No description provided for @hideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar panel'**
  String get hideSidebar;

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
  /// **'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Provider copies of calendars, events, task lists, and tasks are not deleted.'**
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

  /// No description provided for @newTaskList.
  ///
  /// In en, this message translates to:
  /// **'New task list'**
  String get newTaskList;

  /// No description provided for @taskListCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the task list: {error}'**
  String taskListCreateFailed(String error);

  /// No description provided for @taskListRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename the task list: {error}'**
  String taskListRenameFailed(String error);

  /// No description provided for @taskListDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the task list: {error}'**
  String taskListDeleteFailed(String error);

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

  /// No description provided for @unshare.
  ///
  /// In en, this message translates to:
  /// **'Unshare'**
  String get unshare;

  /// No description provided for @readOnlyTaskListCannotRename.
  ///
  /// In en, this message translates to:
  /// **'This task list is read-only and cannot be renamed.'**
  String get readOnlyTaskListCannotRename;

  /// No description provided for @taskListCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'This task list cannot be deleted with your current permissions.'**
  String get taskListCannotDelete;

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

  /// No description provided for @deleteTaskListConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\" and all of its tasks?'**
  String deleteTaskListConfirmation(String title);

  /// No description provided for @unshareTaskListConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Unshare \"{title}\" from this account?'**
  String unshareTaskListConfirmation(String title);

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

  /// No description provided for @taskStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get taskStatus;

  /// No description provided for @taskStatusNone.
  ///
  /// In en, this message translates to:
  /// **'No status'**
  String get taskStatusNone;

  /// No description provided for @taskStatusNeedsAction.
  ///
  /// In en, this message translates to:
  /// **'Needs action'**
  String get taskStatusNeedsAction;

  /// No description provided for @taskStatusInProcess.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskStatusInProcess;

  /// No description provided for @taskStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskStatusCompleted;

  /// No description provided for @taskStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskStatusCancelled;

  /// No description provided for @completionPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% completed'**
  String completionPercent(int percent);

  /// No description provided for @completionDate.
  ///
  /// In en, this message translates to:
  /// **'Completion date'**
  String get completionDate;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityNone.
  ///
  /// In en, this message translates to:
  /// **'No priority'**
  String get priorityNone;

  /// No description provided for @priorityHighValue.
  ///
  /// In en, this message translates to:
  /// **'Priority {priority} · High'**
  String priorityHighValue(int priority);

  /// No description provided for @priorityMediumValue.
  ///
  /// In en, this message translates to:
  /// **'Priority {priority} · Medium'**
  String priorityMediumValue(int priority);

  /// No description provided for @priorityLowValue.
  ///
  /// In en, this message translates to:
  /// **'Priority {priority} · Low'**
  String priorityLowValue(int priority);

  /// No description provided for @taskUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get taskUrl;

  /// No description provided for @invalidTaskUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute URL, including its scheme.'**
  String get invalidTaskUrl;

  /// No description provided for @classification.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get classification;

  /// No description provided for @classificationPublic.
  ///
  /// In en, this message translates to:
  /// **'When shared, show the full task'**
  String get classificationPublic;

  /// No description provided for @classificationConfidential.
  ///
  /// In en, this message translates to:
  /// **'When shared, show only busy'**
  String get classificationConfidential;

  /// No description provided for @classificationPrivate.
  ///
  /// In en, this message translates to:
  /// **'When shared, hide this task'**
  String get classificationPrivate;

  /// No description provided for @pinTask.
  ///
  /// In en, this message translates to:
  /// **'Pin task'**
  String get pinTask;

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

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @noReminders.
  ///
  /// In en, this message translates to:
  /// **'No reminders'**
  String get noReminders;

  /// No description provided for @editReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder'**
  String get editReminder;

  /// No description provided for @beforeTaskStarts.
  ///
  /// In en, this message translates to:
  /// **'Before the task starts'**
  String get beforeTaskStarts;

  /// Reminder timing relative to the task's due time/deadline, not task completion.
  ///
  /// In en, this message translates to:
  /// **'Before the task is due'**
  String get beforeTaskDue;

  /// No description provided for @afterTaskStarts.
  ///
  /// In en, this message translates to:
  /// **'After the task starts'**
  String get afterTaskStarts;

  /// No description provided for @afterTaskDue.
  ///
  /// In en, this message translates to:
  /// **'After the task is due'**
  String get afterTaskDue;

  /// No description provided for @relativeToTaskStart.
  ///
  /// In en, this message translates to:
  /// **'Relative to the task start date'**
  String get relativeToTaskStart;

  /// No description provided for @relativeToTaskDue.
  ///
  /// In en, this message translates to:
  /// **'Relative to the task due date'**
  String get relativeToTaskDue;

  /// No description provided for @reminderTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'Time of day'**
  String get reminderTimeOfDay;

  /// No description provided for @absoluteReminder.
  ///
  /// In en, this message translates to:
  /// **'At a date and time'**
  String get absoluteReminder;

  /// No description provided for @reminderAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get reminderAmount;

  /// No description provided for @reminderUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get reminderUnit;

  /// No description provided for @reminderUnitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get reminderUnitSeconds;

  /// No description provided for @reminderUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get reminderUnitMinutes;

  /// No description provided for @reminderUnitHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get reminderUnitHours;

  /// No description provided for @reminderUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get reminderUnitDays;

  /// No description provided for @reminderUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get reminderUnitWeeks;

  /// No description provided for @reminderAtTaskStart.
  ///
  /// In en, this message translates to:
  /// **'At the task start'**
  String get reminderAtTaskStart;

  /// No description provided for @reminderAtTaskDue.
  ///
  /// In en, this message translates to:
  /// **'At the task due time'**
  String get reminderAtTaskDue;

  /// No description provided for @unsupportedReminder.
  ///
  /// In en, this message translates to:
  /// **'This reminder type is preserved but its time cannot be edited.'**
  String get unsupportedReminder;

  /// No description provided for @relatedRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep related reminders?'**
  String get relatedRemindersTitle;

  /// No description provided for @relatedRemindersDescription.
  ///
  /// In en, this message translates to:
  /// **'This date has {count} related reminders. Keep them at their current date and time?'**
  String relatedRemindersDescription(int count);

  /// No description provided for @discardRelatedReminders.
  ///
  /// In en, this message translates to:
  /// **'Discard reminders'**
  String get discardRelatedReminders;

  /// No description provided for @keepRelatedReminders.
  ///
  /// In en, this message translates to:
  /// **'Keep reminders'**
  String get keepRelatedReminders;

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

  /// Standalone label for the numeric interval used by daily, weekly, monthly, and yearly recurrence.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get repeatEvery;

  /// Recurrence editor label introducing the selected weekdays, month days, or ordinal weekday.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get repeatOn;

  /// No description provided for @repeatEnd.
  ///
  /// In en, this message translates to:
  /// **'End repeat'**
  String get repeatEnd;

  /// No description provided for @repeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatNever;

  /// No description provided for @repeatUntil.
  ///
  /// In en, this message translates to:
  /// **'On date'**
  String get repeatUntil;

  /// No description provided for @repeatAfter.
  ///
  /// In en, this message translates to:
  /// **'After a number of occurrences'**
  String get repeatAfter;

  /// No description provided for @repeatCount.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get repeatCount;

  /// No description provided for @repeatDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Days of month'**
  String get repeatDayOfMonth;

  /// No description provided for @repeatMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get repeatMonths;

  /// No description provided for @repeatOrdinal.
  ///
  /// In en, this message translates to:
  /// **'Weekday position'**
  String get repeatOrdinal;

  /// No description provided for @repeatSpecificDays.
  ///
  /// In en, this message translates to:
  /// **'Specific days'**
  String get repeatSpecificDays;

  /// No description provided for @repeatFirst.
  ///
  /// In en, this message translates to:
  /// **'First'**
  String get repeatFirst;

  /// No description provided for @repeatSecond.
  ///
  /// In en, this message translates to:
  /// **'Second'**
  String get repeatSecond;

  /// No description provided for @repeatThird.
  ///
  /// In en, this message translates to:
  /// **'Third'**
  String get repeatThird;

  /// No description provided for @repeatFourth.
  ///
  /// In en, this message translates to:
  /// **'Fourth'**
  String get repeatFourth;

  /// No description provided for @repeatFifth.
  ///
  /// In en, this message translates to:
  /// **'Fifth'**
  String get repeatFifth;

  /// No description provided for @repeatSecondToLast.
  ///
  /// In en, this message translates to:
  /// **'Second to last'**
  String get repeatSecondToLast;

  /// No description provided for @repeatLast.
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get repeatLast;

  /// No description provided for @repeatAnyDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get repeatAnyDay;

  /// No description provided for @repeatWeekday.
  ///
  /// In en, this message translates to:
  /// **'Weekday'**
  String get repeatWeekday;

  /// No description provided for @repeatWeekendDay.
  ///
  /// In en, this message translates to:
  /// **'Weekend day'**
  String get repeatWeekendDay;

  /// No description provided for @repeatEveryDays.
  ///
  /// In en, this message translates to:
  /// **'Every {count} days'**
  String repeatEveryDays(int count);

  /// No description provided for @repeatEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {count} weeks'**
  String repeatEveryWeeks(int count);

  /// No description provided for @repeatEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {count} months'**
  String repeatEveryMonths(int count);

  /// No description provided for @repeatEveryYears.
  ///
  /// In en, this message translates to:
  /// **'Every {count} years'**
  String repeatEveryYears(int count);

  /// Sentence fragment appended to a recurrence summary; {days} is a localized list of weekdays.
  ///
  /// In en, this message translates to:
  /// **'on {days}'**
  String repeatOnDaysSummary(String days);

  /// Sentence fragment appended to a recurrence summary; {days} is a localized list of day-of-month numbers.
  ///
  /// In en, this message translates to:
  /// **'on day {days}'**
  String repeatOnMonthDaysSummary(String days);

  /// Complete sentence fragment for ordinal recurrence. {position} is one of first, second, third, fourth, fifth, secondToLast, or last; {days} is a localized weekday.
  ///
  /// In en, this message translates to:
  /// **'{position, select, first{on the first {days}} second{on the second {days}} third{on the third {days}} fourth{on the fourth {days}} fifth{on the fifth {days}} secondToLast{on the second to last {days}} last{on the last {days}} other{on {days}}}'**
  String repeatOnOrdinalSummary(String position, String days);

  /// Sentence fragment for selected recurrence months; {months} is a localized list of month names.
  ///
  /// In en, this message translates to:
  /// **'in {months}'**
  String repeatInMonthsSummary(String months);

  /// Sentence fragment summarizing a finite recurrence count.
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String repeatTimesSummary(int count);

  /// Sentence fragment for the recurrence end date.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String repeatUntilSummary(String date);

  /// No description provided for @unsupportedRecurrencePreserved.
  ///
  /// In en, this message translates to:
  /// **'This recurrence rule uses options that this editor does not change.'**
  String get unsupportedRecurrencePreserved;

  /// No description provided for @recurrenceUnsupportedByProvider.
  ///
  /// In en, this message translates to:
  /// **'This recurrence cannot be used with {provider}.'**
  String recurrenceUnsupportedByProvider(String provider);

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

  /// No description provided for @subtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get subtasks;

  /// No description provided for @duplicateTask.
  ///
  /// In en, this message translates to:
  /// **'Duplicate task'**
  String get duplicateTask;

  /// No description provided for @taskDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Task duplicated.'**
  String get taskDuplicated;

  /// No description provided for @taskDuplicateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not duplicate the task: {error}'**
  String taskDuplicateFailed(String error);

  /// No description provided for @hideSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Hide subtasks'**
  String get hideSubtasks;

  /// No description provided for @hideClosedSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Hide closed subtasks'**
  String get hideClosedSubtasks;

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
  /// **'Delete \"{title}\"?'**
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

  /// Metadata label for the immediate parent task of a subtask.
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

  /// No description provided for @launchAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Launch at login'**
  String get launchAtLogin;

  /// No description provided for @launchAtLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Start BusyMax in the background so reminders work after you sign in.'**
  String get launchAtLoginDescription;

  /// No description provided for @launchAtLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the launch-at-login setting.'**
  String get launchAtLoginFailed;

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

  /// No description provided for @onState.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get onState;

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

  /// Destructive confirmation button that throws away unsaved edits. Translate it distinctly from Cancel.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChangesAction;

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

  /// No description provided for @eventReminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Event reminder'**
  String get eventReminderNotificationTitle;

  /// No description provided for @taskReminderNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Task reminder'**
  String get taskReminderNotificationTitle;

  /// No description provided for @eventReminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Event starts soon.'**
  String get eventReminderNotificationBody;

  /// No description provided for @taskReminderNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Task is due soon.'**
  String get taskReminderNotificationBody;

  /// No description provided for @notificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationOpenAction;

  /// No description provided for @notificationSnoozeAction.
  ///
  /// In en, this message translates to:
  /// **'Snooze 10 minutes'**
  String get notificationSnoozeAction;

  /// Non-destructive action that closes or dismisses a desktop notification. Translate distinctly from reject, discard, or cancel.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get notificationDismissAction;

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

  /// No description provided for @selectTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Select Timezone'**
  String get selectTimeZone;

  /// No description provided for @searchLocations.
  ///
  /// In en, this message translates to:
  /// **'Search locations'**
  String get searchLocations;

  /// No description provided for @noLocationsFound.
  ///
  /// In en, this message translates to:
  /// **'No locations found'**
  String get noLocationsFound;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @providerConnectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect calendars and tasks from one of these providers.'**
  String get providerConnectionDescription;

  /// No description provided for @appleICloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Apple iCloud Calendar'**
  String get appleICloudProvider;

  /// No description provided for @nextcloudProvider.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud'**
  String get nextcloudProvider;

  /// No description provided for @appleICloudTasksProvider.
  ///
  /// In en, this message translates to:
  /// **'Apple iCloud'**
  String get appleICloudTasksProvider;

  /// No description provided for @nextcloudTasksProvider.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud Tasks'**
  String get nextcloudTasksProvider;

  /// No description provided for @addAppleICloudAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Apple iCloud Calendar account'**
  String get addAppleICloudAccount;

  /// No description provided for @addNextcloudAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Nextcloud account'**
  String get addNextcloudAccount;

  /// No description provided for @waitingForAppleICloud.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Apple iCloud…'**
  String get waitingForAppleICloud;

  /// No description provided for @waitingForNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Nextcloud authorization…'**
  String get waitingForNextcloud;

  /// No description provided for @connectAppleICloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple iCloud Calendar'**
  String get connectAppleICloudTitle;

  /// No description provided for @appleAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Apple Account email'**
  String get appleAccountEmail;

  /// No description provided for @appleAppSpecificPassword.
  ///
  /// In en, this message translates to:
  /// **'App-specific password'**
  String get appleAppSpecificPassword;

  /// No description provided for @appleAppSpecificPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Create an app-specific password after enabling two-factor authentication for your Apple Account.'**
  String get appleAppSpecificPasswordHelp;

  /// No description provided for @appleAppSpecificPasswordResetWarning.
  ///
  /// In en, this message translates to:
  /// **'Resetting your Apple Account password revokes app-specific passwords.'**
  String get appleAppSpecificPasswordResetWarning;

  /// No description provided for @connectNextcloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Nextcloud'**
  String get connectNextcloudTitle;

  /// No description provided for @nextcloudServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud server or CalDAV address'**
  String get nextcloudServerUrl;

  /// No description provided for @nextcloudServerUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter your Nextcloud server URL, or paste the primary CalDAV address copied from Nextcloud.'**
  String get nextcloudServerUrlHelp;

  /// No description provided for @nextcloudBrowserAuthorizationHelp.
  ///
  /// In en, this message translates to:
  /// **'BusyMax will open your browser. Approve access there, then return to BusyMax.'**
  String get nextcloudBrowserAuthorizationHelp;

  /// No description provided for @connectAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectAccountAction;

  /// No description provided for @cancelAccountConnection.
  ///
  /// In en, this message translates to:
  /// **'Cancel connection'**
  String get cancelAccountConnection;

  /// No description provided for @nextcloudAccountRemovedRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'The account was removed locally, but its Nextcloud app password could not be revoked.'**
  String get nextcloudAccountRemovedRevokeFailed;

  /// No description provided for @davCachedOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Calendar and task data is cached locally for offline use.'**
  String get davCachedOfflineNotice;

  /// No description provided for @davReauthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Reconnect this account to resume synchronization.'**
  String get davReauthenticationRequired;

  /// No description provided for @davTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This account is temporarily unavailable.'**
  String get davTemporarilyUnavailable;

  /// No description provided for @davPermissionChanged.
  ///
  /// In en, this message translates to:
  /// **'Server permissions changed. Pending edits are paused.'**
  String get davPermissionChanged;

  /// No description provided for @davUnsupportedServer.
  ///
  /// In en, this message translates to:
  /// **'This server or provider profile is not supported.'**
  String get davUnsupportedServer;

  /// No description provided for @collectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Calendars and task lists'**
  String get collectionSettings;

  /// No description provided for @calendarContent.
  ///
  /// In en, this message translates to:
  /// **'Calendar events'**
  String get calendarContent;

  /// No description provided for @taskContent.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get taskContent;

  /// No description provided for @readOnlySharedCollection.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get readOnlySharedCollection;

  /// No description provided for @pendingLocally.
  ///
  /// In en, this message translates to:
  /// **'Pending locally'**
  String get pendingLocally;

  /// No description provided for @conflictBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked by conflict'**
  String get conflictBlocked;

  /// No description provided for @authenticationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked until reconnect'**
  String get authenticationBlocked;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @keepServerVersion.
  ///
  /// In en, this message translates to:
  /// **'Keep server version'**
  String get keepServerVersion;

  /// No description provided for @reapplyLocalChange.
  ///
  /// In en, this message translates to:
  /// **'Review and reapply local change'**
  String get reapplyLocalChange;

  /// No description provided for @duplicateLocalItem.
  ///
  /// In en, this message translates to:
  /// **'Duplicate as new item'**
  String get duplicateLocalItem;

  /// No description provided for @davConnectionState.
  ///
  /// In en, this message translates to:
  /// **'Connection state'**
  String get davConnectionState;

  /// No description provided for @davConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get davConnected;

  /// No description provided for @davConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get davConnecting;

  /// No description provided for @davSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get davSignedOut;

  /// No description provided for @davLastSuccessfulSync.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync: {time}'**
  String davLastSuccessfulSync(String time);

  /// No description provided for @davNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synchronized yet'**
  String get davNeverSynced;

  /// No description provided for @refreshCollections.
  ///
  /// In en, this message translates to:
  /// **'Refresh calendars and task lists'**
  String get refreshCollections;

  /// No description provided for @nextcloudServerHost.
  ///
  /// In en, this message translates to:
  /// **'Server: {host}'**
  String nextcloudServerHost(String host);

  /// No description provided for @collectionSupportsEvents.
  ///
  /// In en, this message translates to:
  /// **'Event calendar'**
  String get collectionSupportsEvents;

  /// No description provided for @collectionSupportsTasks.
  ///
  /// In en, this message translates to:
  /// **'Task list'**
  String get collectionSupportsTasks;

  /// No description provided for @collectionSupportsEventsAndTasks.
  ///
  /// In en, this message translates to:
  /// **'Events and tasks'**
  String get collectionSupportsEventsAndTasks;

  /// No description provided for @writableCollection.
  ///
  /// In en, this message translates to:
  /// **'Writable'**
  String get writableCollection;

  /// No description provided for @sharedCollection.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sharedCollection;

  /// No description provided for @collectionLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synchronized: {time}'**
  String collectionLastSynced(String time);

  /// No description provided for @collectionSyncError.
  ///
  /// In en, this message translates to:
  /// **'Sync issue: {code}'**
  String collectionSyncError(String code);

  /// No description provided for @syncConflicts.
  ///
  /// In en, this message translates to:
  /// **'Synchronization conflicts'**
  String get syncConflicts;

  /// No description provided for @remoteChangedAt.
  ///
  /// In en, this message translates to:
  /// **'Server changed: {time}'**
  String remoteChangedAt(String time);

  /// No description provided for @localPendingEdit.
  ///
  /// In en, this message translates to:
  /// **'Local edit: {summary}'**
  String localPendingEdit(String summary);

  /// No description provided for @conflictResolutionFailed.
  ///
  /// In en, this message translates to:
  /// **'The conflict could not be resolved.'**
  String get conflictResolutionFailed;

  /// No description provided for @recurringEventScope.
  ///
  /// In en, this message translates to:
  /// **'Recurring event scope'**
  String get recurringEventScope;

  /// No description provided for @entireSeries.
  ///
  /// In en, this message translates to:
  /// **'Entire series'**
  String get entireSeries;

  /// No description provided for @singleOccurrence.
  ///
  /// In en, this message translates to:
  /// **'This event'**
  String get singleOccurrence;

  /// No description provided for @thisAndFollowingEvents.
  ///
  /// In en, this message translates to:
  /// **'This and following events'**
  String get thisAndFollowingEvents;

  /// No description provided for @thisAndFutureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not supported by this provider.'**
  String get thisAndFutureUnavailable;

  /// No description provided for @thisAndFutureMoveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This and following events cannot be moved safely. Choose this event or the entire series.'**
  String get thisAndFutureMoveUnavailable;

  /// No description provided for @entireSeriesMoveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The recurrence rule is not available locally. Move this event instead.'**
  String get entireSeriesMoveUnavailable;

  /// No description provided for @copyEventAndDeleteOriginal.
  ///
  /// In en, this message translates to:
  /// **'Copy event and delete original?'**
  String get copyEventAndDeleteOriginal;

  /// No description provided for @copyEventMoveWarning.
  ///
  /// In en, this message translates to:
  /// **'BusyMax cannot move this event directly from {source} to {destination}. It will create the copy first and delete the original only after the copy succeeds. Event IDs will change; attendee response statuses may reset and invitations or cancellations may be sent; conference links, attachments, reminders, provider-specific fields, and recurrence exceptions may not carry over.'**
  String copyEventMoveWarning(String source, String destination);

  /// No description provided for @copyAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Copy and delete'**
  String get copyAndDelete;

  /// Explains the three recurring-event scope choices: entire series, one occurrence, or this and following events.
  ///
  /// In en, this message translates to:
  /// **'Choose whether this change applies to the entire series, only this occurrence, or this and following events.'**
  String get chooseRecurringEventScope;

  /// No description provided for @taskDueBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Due must not be before start.'**
  String get taskDueBeforeStart;

  /// No description provided for @taskStartDueTimeModeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Set times for both start and due, or make the task all day.'**
  String get taskStartDueTimeModeMismatch;

  /// No description provided for @deleteCalendarConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String deleteCalendarConfirmation(String title);

  /// No description provided for @setCustomCalendarName.
  ///
  /// In en, this message translates to:
  /// **'Set custom name'**
  String get setCustomCalendarName;

  /// No description provided for @setAction.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setAction;

  /// No description provided for @removeFromMyCalendars.
  ///
  /// In en, this message translates to:
  /// **'Remove from my calendars'**
  String get removeFromMyCalendars;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @removeCalendarConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from your Google Calendar list? The shared calendar and its events will not be deleted.'**
  String removeCalendarConfirmation(String title);

  /// No description provided for @calendarCannotRemove.
  ///
  /// In en, this message translates to:
  /// **'This calendar cannot be deleted or removed from this account.'**
  String get calendarCannotRemove;

  /// No description provided for @calendarPendingChangesPreventRemoval.
  ///
  /// In en, this message translates to:
  /// **'Wait for this calendar’s pending changes to finish syncing before deleting or removing it.'**
  String get calendarPendingChangesPreventRemoval;

  /// No description provided for @calendarSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Calendar subscriptions'**
  String get calendarSubscriptions;

  /// No description provided for @calendarSubscriptionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add read-only calendars that refresh from a secure WebCal URL.'**
  String get calendarSubscriptionsDescription;

  /// No description provided for @addCalendarSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add calendar subscription'**
  String get addCalendarSubscription;

  /// No description provided for @subscriptionName.
  ///
  /// In en, this message translates to:
  /// **'Local name'**
  String get subscriptionName;

  /// No description provided for @subscriptionUrl.
  ///
  /// In en, this message translates to:
  /// **'Subscription URL'**
  String get subscriptionUrl;

  /// No description provided for @subscriptionUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS or webcal URL. BusyMax keeps the complete URL in secure storage.'**
  String get subscriptionUrlHelp;

  /// No description provided for @subscriptionUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTPS or webcal URL without user information or a fragment.'**
  String get subscriptionUrlInvalid;

  /// No description provided for @subscriptionColor.
  ///
  /// In en, this message translates to:
  /// **'Local color'**
  String get subscriptionColor;

  /// No description provided for @subscriptionColorHelp.
  ///
  /// In en, this message translates to:
  /// **'Use a six-digit color such as #3584E4.'**
  String get subscriptionColorHelp;

  /// No description provided for @subscriptionColorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a six-digit hexadecimal color.'**
  String get subscriptionColorInvalid;

  /// No description provided for @subscriptionRefreshMode.
  ///
  /// In en, this message translates to:
  /// **'Refresh frequency'**
  String get subscriptionRefreshMode;

  /// No description provided for @subscriptionAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get subscriptionAutomatic;

  /// No description provided for @subscriptionHourly.
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get subscriptionHourly;

  /// No description provided for @subscriptionSixHours.
  ///
  /// In en, this message translates to:
  /// **'Every six hours'**
  String get subscriptionSixHours;

  /// No description provided for @subscriptionDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get subscriptionDaily;

  /// No description provided for @subscriptionSafeOrigin.
  ///
  /// In en, this message translates to:
  /// **'Source: {origin}'**
  String subscriptionSafeOrigin(String origin);

  /// No description provided for @subscriptionSafeOriginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid URL to preview its safe origin.'**
  String get subscriptionSafeOriginUnavailable;

  /// No description provided for @subscriptionReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only subscription'**
  String get subscriptionReadOnly;

  /// No description provided for @subscriptionNeverRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Not refreshed yet'**
  String get subscriptionNeverRefreshed;

  /// No description provided for @subscriptionLastRefresh.
  ///
  /// In en, this message translates to:
  /// **'Last successful refresh: {time}'**
  String subscriptionLastRefresh(String time);

  /// No description provided for @subscriptionNextRefresh.
  ///
  /// In en, this message translates to:
  /// **'Next refresh: {time}'**
  String subscriptionNextRefresh(String time);

  /// No description provided for @subscriptionStatusHealthy.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get subscriptionStatusHealthy;

  /// No description provided for @subscriptionStatusIssue.
  ///
  /// In en, this message translates to:
  /// **'Refresh issue: {code}'**
  String subscriptionStatusIssue(String code);

  /// No description provided for @refreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get refreshNow;

  /// No description provided for @unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get unsubscribe;

  /// No description provided for @unsubscribeCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe from “{name}”?'**
  String unsubscribeCalendarTitle(String name);

  /// No description provided for @unsubscribeCalendarConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This removes the local subscription and its cached events. The published calendar is not changed.'**
  String get unsubscribeCalendarConfirmation;

  /// No description provided for @addSubscriptionAction.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscriptionAction;

  /// No description provided for @subscriptionOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Calendar subscription failed: {error}'**
  String subscriptionOperationFailed(String error);

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

  /// No description provided for @calendarImport.
  ///
  /// In en, this message translates to:
  /// **'Calendar import'**
  String get calendarImport;

  /// No description provided for @calendarImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a file, review its events, then choose the writable calendar that should receive them.'**
  String get calendarImportDescription;

  /// No description provided for @importIcsFile.
  ///
  /// In en, this message translates to:
  /// **'Import .ics file'**
  String get importIcsFile;

  /// No description provided for @importIcsPreview.
  ///
  /// In en, this message translates to:
  /// **'Import calendar events'**
  String get importIcsPreview;

  /// No description provided for @importEventsFound.
  ///
  /// In en, this message translates to:
  /// **'Importable event sets: {count}'**
  String importEventsFound(int count);

  /// No description provided for @importInvalidEvents.
  ///
  /// In en, this message translates to:
  /// **'Invalid events: {count}'**
  String importInvalidEvents(int count);

  /// No description provided for @importFieldsOmitted.
  ///
  /// In en, this message translates to:
  /// **'Intentionally omitted: {fields}'**
  String importFieldsOmitted(String fields);

  /// No description provided for @noWritableCalendars.
  ///
  /// In en, this message translates to:
  /// **'No writable destination calendar is available.'**
  String get noWritableCalendars;

  /// No description provided for @importDestinationCalendar.
  ///
  /// In en, this message translates to:
  /// **'Destination calendar'**
  String get importDestinationCalendar;

  /// No description provided for @importIcsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import events'**
  String get importIcsConfirm;

  /// No description provided for @importIcsComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importIcsComplete;

  /// No description provided for @importQueued.
  ///
  /// In en, this message translates to:
  /// **'Imported or queued: {count}'**
  String importQueued(int count);

  /// No description provided for @importDuplicatesSkipped.
  ///
  /// In en, this message translates to:
  /// **'Duplicates skipped: {count}'**
  String importDuplicatesSkipped(int count);

  /// No description provided for @importUnsupportedSets.
  ///
  /// In en, this message translates to:
  /// **'Unsupported recurrence sets: {count}'**
  String importUnsupportedSets(int count);

  /// No description provided for @importIcsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import the calendar file: {error}'**
  String importIcsFailed(String error);

  /// No description provided for @networkOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get networkOffline;

  /// No description provided for @networkOfflineDescription.
  ///
  /// In en, this message translates to:
  /// **'Changes will sync when the connection is restored.'**
  String get networkOfflineDescription;

  /// No description provided for @networkOfflineTryAgain.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. Connect to the internet and try again.'**
  String get networkOfflineTryAgain;

  /// Sentence fragment for recurrence on multiple days of the month; {days} is a localized list of day numbers.
  ///
  /// In en, this message translates to:
  /// **'on days {days}'**
  String repeatOnMonthDaysSummaryMultiple(String days);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'et',
    'fa',
    'fi',
    'fr',
    'hi',
    'it',
    'ja',
    'ko',
    'pt',
    'ru',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'et':
      return AppLocalizationsEt();
    case 'fa':
      return AppLocalizationsFa();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Connect Google, Microsoft, Apple iCloud Calendar, or Nextcloud accounts.';

  @override
  String get googlePermissionsConsentNotice =>
      'Google अनुमति स्क्रीन पर, कैलेंडर और कार्य दोनों अनुमतियाँ चुनें।';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google Calendar और Google Tasks की अनुमतियाँ आवश्यक हैं। फिर से कोशिश करें और दोनों चेकबॉक्स चुनें।';

  @override
  String get finishSetup => 'सेटअप पूरा करें';

  @override
  String get continueSetup => 'जारी रखें';

  @override
  String get onboardingSetupTitle => 'BusyMax सेट अप करें';

  @override
  String get onboardingAccountsStepTitle => 'खाते कनेक्ट करें';

  @override
  String get onboardingAccountsStepDescription =>
      'Add every account you want to use. BusyMax syncs supported calendars, events, task lists, and tasks from each account.';

  @override
  String get onboardingPreferencesStepTitle => 'सिस्टम सेटिंग्स चुनें';

  @override
  String get onboardingPreferencesStepDescription =>
      'अपना शेड्यूल खोलने से पहले डेस्कटॉप व्यवहार, रिमाइंडर, सूचनाओं के विवरण का स्तर और दिखावट सेट करें।';

  @override
  String get signInWithGoogle => 'Google से साइन इन करें';

  @override
  String get signInWithMicrosoft => 'Microsoft से साइन इन करें';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'यह प्रदाता कॉन्फ़िगर नहीं किया गया है।';

  @override
  String get waitingForGoogleSignIn =>
      'Google साइन-इन की प्रतीक्षा हो रही है...';

  @override
  String get waitingForMicrosoftSignIn =>
      'Microsoft साइन-इन की प्रतीक्षा हो रही है...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsoft साइन-इन कॉन्फ़िगर नहीं है। MICROSOFT_OAUTH_CLIENT_ID सेट करें।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get close => 'बंद करें';

  @override
  String get exit => 'बाहर निकलें';

  @override
  String get options => 'विकल्प';

  @override
  String get hide => 'छिपाएँ';

  @override
  String get show => 'दिखाएँ';

  @override
  String get export => 'निर्यात करें';

  @override
  String get save => 'सहेजें';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get all => 'सभी';

  @override
  String get calendarEvents => 'ईवेंट';

  @override
  String get calendarTasks => 'कार्य';

  @override
  String get calendar => 'कैलेंडर';

  @override
  String get calendars => 'कैलेंडर';

  @override
  String get newCalendar => 'नया कैलेंडर';

  @override
  String get calendarColor => 'कैलेंडर का रंग';

  @override
  String calendarColorOption(int number) {
    return 'रंग $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'यह प्रदाता BusyMax में कैलेंडर प्रबंधन का समर्थन नहीं करता है।';

  @override
  String get primaryCalendarCannotDelete =>
      'प्राथमिक कैलेंडर को हटाया नहीं जा सकता।';

  @override
  String calendarCreateFailed(String error) {
    return 'कैलेंडर नहीं बनाया जा सका: $error';
  }

  @override
  String calendarUpdateFailed(String error) {
    return 'कैलेंडर अपडेट नहीं किया जा सका: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'कैलेंडर हटाया नहीं जा सका: $error';
  }

  @override
  String get newEvent => 'नया ईवेंट';

  @override
  String get refreshCalendar => 'कैलेंडर रीफ़्रेश करें';

  @override
  String get openInProvider => 'सेवा में खोलें';

  @override
  String get hideFromSchedule => 'शेड्यूल से छिपाएँ';

  @override
  String get showInSchedule => 'शेड्यूल में दिखाएँ';

  @override
  String get noCalendarsSynced => 'अभी तक कोई कैलेंडर सिंक नहीं हुआ है।';

  @override
  String get allDay => 'पूरे दिन';

  @override
  String moreItems(int count) {
    return '+$count और';
  }

  @override
  String get noEventsOrTasks => 'कोई ईवेंट या कार्य नहीं';

  @override
  String get scheduleLoading => 'शेड्यूल लोड हो रहा है...';

  @override
  String get scheduleUnavailable => 'शेड्यूल उपलब्ध नहीं है';

  @override
  String get scheduleNoSources =>
      'कोई दिखाई देने वाला कैलेंडर या कार्य सूची नहीं';

  @override
  String get scheduleNoSourcesDescription =>
      'सेटिंग्स में चुनें कि क्या दिखाना है, फिर रीफ़्रेश करें।';

  @override
  String get scheduleSignInRequired => 'खाता कनेक्ट करें';

  @override
  String get scheduleSignInDescription =>
      'कैलेंडर और कार्य सिंक करने के लिए साइन इन करें।';

  @override
  String get scheduleNoSearchResults => 'कोई मिलता-जुलता ईवेंट या कार्य नहीं';

  @override
  String get scheduleNoSearchResultsDescription =>
      'कोई दूसरी खोज आज़माएँ या मौजूदा फ़िल्टर हटाएँ।';

  @override
  String get refresh => 'रीफ़्रेश करें';

  @override
  String get trayOpenBusyMax => 'BusyMax खोलें';

  @override
  String get agendaLoadMoreOverdue =>
      'समय-सीमा पार कर चुके अतिरिक्त कार्य लोड करें';

  @override
  String get agendaLoadMoreNoDate => 'बिना तारीख वाले और कार्य लोड करें';

  @override
  String get viewDay => 'दिन';

  @override
  String get viewWeek => 'सप्ताह';

  @override
  String get viewMonth => 'महीना';

  @override
  String get viewYear => 'वर्ष';

  @override
  String get viewAgenda => 'कार्यसूची';

  @override
  String get scheduleSettings => 'शेड्यूल';

  @override
  String get scheduleDisplaySettings => 'शेड्यूल प्रदर्शन';

  @override
  String get scheduleDisplayHoursDescription =>
      'दिन और सप्ताह दृश्य शुरू में यह समयावधि दिखाते हैं। आवश्यकता होने पर पहले या बाद के आइटम इस सीमा को बढ़ाते हैं।';

  @override
  String get scheduleDayStartsAt => 'दिन शुरू होता है';

  @override
  String get scheduleDayEndsAt => 'दिन समाप्त होता है';

  @override
  String get sourceCalendar => 'कैलेंडर';

  @override
  String get sourceTaskList => 'कार्य सूची';

  @override
  String get createChoiceTitle => 'बनाएँ';

  @override
  String get createEventAtTime => 'ईवेंट';

  @override
  String get createTaskAtDate => 'कार्य';

  @override
  String get editEvent => 'ईवेंट संपादित करें';

  @override
  String get eventTitle => 'ईवेंट का शीर्षक';

  @override
  String get location => 'स्थान';

  @override
  String get timeSlot => 'समयावधि';

  @override
  String get startDateTime => 'शुरू होने की तारीख/समय';

  @override
  String get endDateTime => 'समाप्त होने की तारीख/समय';

  @override
  String get doesNotRepeat => 'दोहराया नहीं जाता';

  @override
  String get defaultReminder => 'डिफ़ॉल्ट रिमाइंडर';

  @override
  String get guests => 'अतिथि';

  @override
  String get noGuests => 'कोई अतिथि नहीं';

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
  String get description => 'विवरण';

  @override
  String get availabilityShowAs => 'उपलब्धता / इस रूप में दिखाएँ';

  @override
  String get busy => 'व्यस्त';

  @override
  String get visibility => 'दृश्यता';

  @override
  String get defaultVisibility => 'डिफ़ॉल्ट दृश्यता';

  @override
  String get conference => 'कॉन्फ़्रेंस';

  @override
  String get noConference => 'कोई कॉन्फ़्रेंस नहीं';

  @override
  String get providerCalendar => 'प्रदाता कैलेंडर';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => 'बोल्ड';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'इटैलिक';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'रेखांकित';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes मिनट पहले',
      one: '1 मिनट पहले',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'शुरू होने पर';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours घंटे पहले',
      one: '1 घंटा पहले',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'खाली';

  @override
  String get availabilityTentative => 'अस्थायी';

  @override
  String get availabilityOutOfOffice => 'कार्यालय से बाहर';

  @override
  String get availabilityWorkingElsewhere => 'किसी अन्य स्थान पर कार्यरत';

  @override
  String get visibilityDefault => 'डिफ़ॉल्ट';

  @override
  String get visibilityPublic => 'सार्वजनिक';

  @override
  String get visibilityPrivate => 'निजी';

  @override
  String get visibilityConfidential => 'गोपनीय';

  @override
  String get sensitivityNormal => 'सामान्य';

  @override
  String get sensitivityPersonal => 'व्यक्तिगत';

  @override
  String get tasks => 'कार्य';

  @override
  String get allTasks => 'सभी कार्य';

  @override
  String tasksInList(String title) {
    return '$title में कार्य';
  }

  @override
  String get taskLists => 'कार्य सूचियाँ';

  @override
  String get navigation => 'नेविगेशन';

  @override
  String get mainMenu => 'मुख्य मेन्यू';

  @override
  String get keyboardShortcuts => 'कीबोर्ड शॉर्टकट';

  @override
  String get shortcutGroupGeneral => 'सामान्य';

  @override
  String get shortcutKeyboardShortcutsDescription => 'यह शॉर्टकट संदर्भ दिखाएँ';

  @override
  String get shortcutGroupNavigation => 'नेविगेशन';

  @override
  String get shortcutNextPeriod => 'अगली अवधि';

  @override
  String get shortcutNextPeriodDescription =>
      'सप्ताह दृश्य में अगला सप्ताह, महीने के दृश्य में अगला महीना, इत्यादि';

  @override
  String get shortcutPreviousPeriod => 'पिछली अवधि';

  @override
  String get shortcutPreviousPeriodDescription =>
      'सप्ताह दृश्य में पिछला सप्ताह, महीने के दृश्य में पिछला महीना, इत्यादि';

  @override
  String get shortcutJumpToToday => 'आज की तारीख पर जाएँ';

  @override
  String get shortcutGroupView => 'दृश्य';

  @override
  String get shortcutDayView => 'दिन का दृश्य';

  @override
  String get shortcutWeekView => 'सप्ताह का दृश्य';

  @override
  String get shortcutMonthView => 'महीने का दृश्य';

  @override
  String get shortcutYearView => 'वर्ष का दृश्य';

  @override
  String get shortcutAgendaView => 'कार्यसूची दृश्य';

  @override
  String get shortcutGroupCreateAndEdit => 'बनाएँ और संपादित करें';

  @override
  String get shortcutSaveItem => 'ईवेंट या कार्य सहेजें';

  @override
  String get shortcutDeleteItem => 'ईवेंट या कार्य मिटाएँ';

  @override
  String get shortcutGroupTaskEditing => 'कार्य संपादन';

  @override
  String get shortcutCancelEditing => 'संपादन रद्द करें';

  @override
  String get shortcutCancelEditingDescription =>
      'कार्य संपादन या कार्य विवरण बंद करें';

  @override
  String get aboutBusyMax => 'BusyMax के बारे में';

  @override
  String get aboutBusyMaxDescription => 'कैलेंडर और कार्य';

  @override
  String get license => 'लाइसेंस';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'वेबसाइट';

  @override
  String get sourceCode => 'स्रोत कोड';

  @override
  String get reportAnIssue => 'समस्या की रिपोर्ट करें';

  @override
  String get sendFeedback => 'प्रतिक्रिया भेजें';

  @override
  String get feedbackSubmit => 'सबमिट करें';

  @override
  String get feedbackCategory => 'श्रेणी';

  @override
  String get feedbackSelectCategory => 'श्रेणी चुनें';

  @override
  String get feedbackCategoryProblem => 'समस्या या बग';

  @override
  String get feedbackCategoryFeature => 'सुविधा का अनुरोध';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'गोपनीयता या सुरक्षा संबंधी चिंता';

  @override
  String get feedbackCategoryUsability => 'उपयोगिता संबंधी चिंता';

  @override
  String get feedbackCategoryOther => 'अन्य';

  @override
  String get feedbackSubject => 'विषय';

  @override
  String get feedbackDetailedMessage => 'विस्तृत संदेश';

  @override
  String get feedbackReplyEmail => 'जवाब के लिए ईमेल (वैकल्पिक)';

  @override
  String get feedbackIncludeTechnicalDetails => 'तकनीकी विवरण शामिल करें';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'केवल आपके Linux ऑपरेटिंग सिस्टम का संस्करण और ऐप की भाषा व क्षेत्रीय सेटिंग जोड़ी जाती है। लॉग, खाता डेटा, फ़ाइल नाम या अन्य निदान जानकारी शामिल नहीं की जाती।';

  @override
  String get feedbackCategoryRequired => 'श्रेणी चुनें।';

  @override
  String get feedbackSubjectLengthError =>
      'विषय 3 से 120 वर्णों के बीच होना चाहिए।';

  @override
  String get feedbackMessageLengthError =>
      'संदेश 10 से 5,000 वर्णों के बीच होना चाहिए।';

  @override
  String get feedbackInvalidEmail => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String get feedbackConnectionError =>
      'BusyStack से कनेक्ट नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get feedbackTimeoutError =>
      'अनुरोध का समय समाप्त हो गया। आपकी प्रतिक्रिया हटाई नहीं गई है; फिर से कोशिश करें।';

  @override
  String get feedbackRateLimitedError =>
      'इस नेटवर्क से बहुत अधिक प्रतिक्रियाएँ भेजी गई हैं। प्रतीक्षा करें और फिर कोशिश करें।';

  @override
  String get feedbackRejectedError =>
      'सर्वर ने सबमिशन अस्वीकार कर दिया। फ़ील्ड की समीक्षा करें और फिर कोशिश करें।';

  @override
  String get feedbackServerError =>
      'BusyStack अभी आपकी प्रतिक्रिया स्वीकार नहीं कर सका। आपकी प्रतिक्रिया हटाई नहीं गई है; फिर से कोशिश करें।';

  @override
  String feedbackSuccess(String id) {
    return 'प्रतिक्रिया भेज दी गई। संदर्भ: $id';
  }

  @override
  String get toggleSidebar => 'साइडबार दिखाएँ या छिपाएँ';

  @override
  String get showSidebar => 'साइडबार पैनल दिखाएँ';

  @override
  String get hideSidebar => 'साइडबार पैनल छिपाएँ';

  @override
  String get accounts => 'खाते';

  @override
  String get currentAccount => 'मौजूदा खाता';

  @override
  String get switchAccount => 'खाता बदलें';

  @override
  String get addGoogleAccount => 'Google खाता जोड़ें';

  @override
  String get addMicrosoftAccount => 'Microsoft खाता जोड़ें';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'साइन इन है';

  @override
  String get removeAccount => 'खाता हटाएँ…';

  @override
  String get removingAccount => 'खाता हटाया जा रहा है…';

  @override
  String get removeAccountDescription =>
      'सिंक करना बंद करें और इस डिवाइस से इस खाते का डेटा हटाएँ।';

  @override
  String removeAccountTitle(String account) {
    return 'BusyMax से $account हटाएँ?';
  }

  @override
  String get removeAccountConfirmation =>
      'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Provider copies of calendars, events, task lists, and tasks are not deleted.';

  @override
  String get revokeGoogleAccess =>
      'इस Google खाते से BusyMax की पहुँच भी रद्द करें';

  @override
  String get revokeGoogleAccessDescription =>
      'दोबारा कनेक्ट करने से पहले आपको फिर से पहुँच देनी होगी।';

  @override
  String get removeAccountAction => 'खाता हटाएँ';

  @override
  String get removeAccountFailed =>
      'खाता हटाना पूरा नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'खाता इस डिवाइस से हटा दिया गया, लेकिन BusyMax की Google खाते तक पहुँच रद्द नहीं की जा सकी। आप यह पहुँच अपने Google खाते से रद्द कर सकते हैं।';

  @override
  String get newTaskList => 'नई कार्य सूची';

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
  String get signInToViewTaskLists =>
      'कार्य सूचियाँ देखने के लिए साइन इन करें।';

  @override
  String get noTaskListsSynced => 'अभी तक कोई कार्य सूची सिंक नहीं हुई है।';

  @override
  String get listActions => 'सूची की कार्रवाइयाँ';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get delete => 'मिटाएँ';

  @override
  String get renameList => 'सूची का नाम बदलें';

  @override
  String get deleteList => 'सूची मिटाएँ';

  @override
  String get unshare => 'Unshare';

  @override
  String get readOnlyTaskListCannotRename =>
      'This task list is read-only and cannot be renamed.';

  @override
  String get taskListCannotDelete =>
      'This task list cannot be deleted with your current permissions.';

  @override
  String get builtInMicrosoftList => 'अंतर्निहित';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Microsoft To Do की अंतर्निहित सूचियों का नाम बदला या उन्हें मिटाया नहीं जा सकता।';

  @override
  String deleteListConfirmation(String title) {
    return 'Google Tasks से “$title” मिटाएँ?';
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
  String get deleteEvent => 'ईवेंट मिटाएँ';

  @override
  String get title => 'शीर्षक';

  @override
  String get create => 'बनाएँ';

  @override
  String get newTask => 'नया कार्य';

  @override
  String get clearCompleted => 'पूरे हुए कार्य हटाएँ';

  @override
  String get refreshList => 'सूची रीफ़्रेश करें';

  @override
  String get refreshAll => 'सभी रीफ़्रेश करें';

  @override
  String get listRefreshed => 'सूची रीफ़्रेश हो गई।';

  @override
  String get allTasksRefreshed => 'सभी खाते रीफ़्रेश हो गए।';

  @override
  String exportedFile(String path) {
    return '$path में निर्यात किया गया';
  }

  @override
  String exportFailed(String error) {
    return 'निर्यात विफल: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'रीफ़्रेश विफल: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'शुरू करने के लिए कार्य सूची चुनें या बनाएँ।';

  @override
  String get signInToViewTasks => 'कार्य देखने के लिए साइन इन करें।';

  @override
  String get noTasks => 'कोई कार्य नहीं।';

  @override
  String get noTasksYet => 'अभी तक कोई कार्य नहीं';

  @override
  String get noTasksYetMessage =>
      'शुरू करने के लिए कार्य बनाएँ या अपने खाते रीफ़्रेश करें।';

  @override
  String get noTasksInList => 'इस सूची में कोई कार्य नहीं है।';

  @override
  String get overdue => 'समय सीमा बीत चुकी';

  @override
  String get today => 'आज';

  @override
  String get tomorrow => 'कल';

  @override
  String get upcoming => 'आगामी';

  @override
  String get noDate => 'कोई तारीख नहीं';

  @override
  String get completed => 'पूर्ण';

  @override
  String duePrefix(String date) {
    return '$date को देय';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => 'कार्य का विवरण';

  @override
  String get editTask => 'कार्य संपादित करें';

  @override
  String get noTaskSelected => 'कोई कार्य नहीं चुना गया।';

  @override
  String get noTaskSelectedHelper =>
      'विवरण देखने और संपादित करने के लिए कोई कार्य चुनें।';

  @override
  String get taskUnavailable => 'कार्य उपलब्ध नहीं है।';

  @override
  String get signInToEditTasks => 'कार्य संपादित करने के लिए साइन इन करें।';

  @override
  String get refreshTask => 'कार्य रीफ़्रेश करें';

  @override
  String get primarySection => 'मुख्य';

  @override
  String get statusSection => 'स्थिति';

  @override
  String get openStatus => 'खुला';

  @override
  String get doneStatus => 'पूर्ण';

  @override
  String get taskStatus => 'Status';

  @override
  String get taskStatusNone => 'No status';

  @override
  String get taskStatusNeedsAction => 'Needs action';

  @override
  String get taskStatusInProcess => 'In process';

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
  String get notes => 'नोट्स';

  @override
  String get dueDate => 'देय तारीख';

  @override
  String get clearDueDate => 'देय तारीख हटाएँ';

  @override
  String get dueTime => 'देय समय';

  @override
  String get startDate => 'शुरू होने की तारीख';

  @override
  String get startTime => 'शुरू होने का समय';

  @override
  String get endDate => 'समाप्ति तारीख';

  @override
  String get endTime => 'समाप्ति समय';

  @override
  String get reminderDate => 'रिमाइंडर की तारीख';

  @override
  String get reminderTime => 'रिमाइंडर का समय';

  @override
  String get reminder => 'रिमाइंडर';

  @override
  String get addReminder => 'रिमाइंडर जोड़ें';

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
  String get addGuest => 'अतिथि जोड़ें';

  @override
  String get addGuestEmail => 'अतिथि का ईमेल जोड़ें';

  @override
  String get removeReminder => 'रिमाइंडर हटाएँ';

  @override
  String get off => 'बंद';

  @override
  String get repeat => 'दोहराएँ';

  @override
  String get repeatNone => 'कभी नहीं';

  @override
  String get noneValue => 'कोई नहीं';

  @override
  String get repeatDaily => 'प्रतिदिन';

  @override
  String get repeatWeekly => 'हर सप्ताह';

  @override
  String get repeatMonthly => 'हर महीने';

  @override
  String get repeatYearly => 'हर वर्ष';

  @override
  String get repeatEvery => 'Repeat every';

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
  String repeatOnOrdinalSummary(String ordinal, String days) {
    return 'on the $ordinal $days';
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
    return 'इस पुनरावृत्ति का उपयोग $provider के साथ नहीं किया जा सकता।';
  }

  @override
  String get importance => 'महत्त्व';

  @override
  String get importanceLow => 'कम';

  @override
  String get importanceNormal => 'सामान्य';

  @override
  String get importanceHigh => 'उच्च';

  @override
  String get categories => 'श्रेणियाँ';

  @override
  String get scheduleSection => 'शेड्यूल';

  @override
  String get dueGroup => 'देय';

  @override
  String get startGroup => 'शुरुआत';

  @override
  String get reminderGroup => 'रिमाइंडर';

  @override
  String get organizationSection => 'व्यवस्था';

  @override
  String get actionsSection => 'कार्रवाइयाँ';

  @override
  String get advancedSection => 'उन्नत';

  @override
  String get addCategory => 'श्रेणी जोड़ें';

  @override
  String get list => 'सूची';

  @override
  String get microsoftMoveUnsupported =>
      'इस संस्करण में Microsoft To Do खातों के लिए सूचियों के बीच कार्य ले जाना समर्थित नहीं है।';

  @override
  String get createSubtask => 'उपकार्य बनाएँ';

  @override
  String get subtasks => 'उपकार्य';

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
  String get moveToTop => 'सबसे ऊपर ले जाएँ';

  @override
  String get deleteTask => 'कार्य मिटाएँ';

  @override
  String get newSubtask => 'नया उपकार्य';

  @override
  String deleteTaskConfirmation(String title) {
    return '“$title” मिटाएँ?';
  }

  @override
  String get metadata => 'मेटाडेटा';

  @override
  String get id => 'आईडी';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'अपडेट किया गया';

  @override
  String get parent => 'मूल कार्य';

  @override
  String get position => 'स्थान';

  @override
  String get webLink => 'वेब लिंक';

  @override
  String get assignment => 'असाइनमेंट';

  @override
  String get localState => 'स्थानीय स्थिति';

  @override
  String get pendingSync => 'सिंक लंबित';

  @override
  String get synced => 'सिंक किया गया';

  @override
  String get account => 'खाता';

  @override
  String get sync => 'सिंक';

  @override
  String get manualFullSync => 'मैन्युअल पूर्ण सिंक';

  @override
  String get runInBackgroundWhenClosed => 'विंडो बंद होने पर भी चलते रहें';

  @override
  String get showTrayIcon => 'ट्रे आइकन दिखाएँ';

  @override
  String get startMinimizedToTray => 'ट्रे में मिनिमाइज़ होकर शुरू करें';

  @override
  String get launchAtLogin => 'लॉगिन पर शुरू करें';

  @override
  String get launchAtLoginDescription =>
      'BusyMax को बैकग्राउंड में शुरू करें ताकि लॉगिन के बाद रिमाइंडर काम करें।';

  @override
  String get launchAtLoginFailed =>
      'लॉगिन पर शुरू करने की सेटिंग अपडेट नहीं की जा सकी।';

  @override
  String get requiresTrayIcon => 'ट्रे आइकन आवश्यक है।';

  @override
  String get syncComplete => 'सिंक पूरा हुआ।';

  @override
  String syncFailed(String error) {
    return 'सिंक विफल: $error';
  }

  @override
  String get notifySyncFailures => 'सिंक विफल होने की सूचनाएँ';

  @override
  String get notifyConflicts => 'टकराव की सूचनाएँ';

  @override
  String get notifyDueToday => 'आज देय कार्यों की सूचनाएँ';

  @override
  String get eventReminders => 'ईवेंट रिमाइंडर';

  @override
  String get taskReminders => 'कार्य रिमाइंडर';

  @override
  String get notificationDetailLevel => 'सूचनाओं के विवरण का स्तर';

  @override
  String get notificationDetailPrivate => 'निजी';

  @override
  String get notificationDetailNormal => 'सामान्य';

  @override
  String get quietHours => 'शांत समय';

  @override
  String get quietHoursDescription => 'इस अवधि के दौरान सूचनाएँ रोकें।';

  @override
  String get quietHoursStart => 'शांत समय की शुरुआत';

  @override
  String get quietHoursEnd => 'शांत समय की समाप्ति';

  @override
  String get notifications => 'सूचनाएँ';

  @override
  String get appearance => 'दिखावट';

  @override
  String get theme => 'थीम';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get themeLight => 'हल्की';

  @override
  String get themeDark => 'गहरी';

  @override
  String get themeFamily => 'थीम परिवार';

  @override
  String get themeFamilyYaru => 'Ubuntu की मूल थीम (Yaru)';

  @override
  String get localization => 'स्थानीयकरण';

  @override
  String get currentLocale => 'मौजूदा भाषा और क्षेत्रीय सेटिंग';

  @override
  String get privacy => 'गोपनीयता';

  @override
  String get redactTaskContentInDiagnostics => 'निदान में कार्य सामग्री छिपाएँ';

  @override
  String get developerDiagnostics => 'डेवलपर निदान';

  @override
  String get diagnostics => 'निदान';

  @override
  String get apiInspectorDisabled => 'API इंस्पेक्टर दिखाएँ';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'डिस्कवरी संशोधन: $revision';
  }

  @override
  String get implementedMethods => 'लागू की गई विधियाँ';

  @override
  String get supportsTasksScopes => 'tasks और tasks.readonly स्कोप समर्थित हैं';

  @override
  String get requiresTasksScope => 'tasks स्कोप आवश्यक है';

  @override
  String get blockedPendingOperations => 'अवरुद्ध लंबित कार्रवाइयाँ';

  @override
  String get signInToInspectPendingOperations =>
      'लंबित कार्रवाइयाँ देखने के लिए साइन इन करें।';

  @override
  String get noBlockedPendingOperations =>
      'कोई अवरुद्ध लंबित कार्रवाई नहीं है।';

  @override
  String get operationActions => 'कार्रवाई के विकल्प';

  @override
  String pendingOpListId(String id) {
    return 'सूची=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'कार्य=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'प्रयास=$count';
  }

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get discard => 'खारिज करें';

  @override
  String get discardChangesAction => 'बदलाव छोड़ें';

  @override
  String get discardChanges => 'बदलाव खारिज करें?';

  @override
  String get discardChangesConfirmation =>
      'इससे इस कार्य में किए गए सहेजे न गए बदलाव खारिज हो जाएँगे।';

  @override
  String get retryCompleted => 'दोबारा प्रयास पूरा हुआ।';

  @override
  String get discardPendingOperation => 'लंबित कार्रवाई खारिज करें?';

  @override
  String get discardPendingOperationConfirmation =>
      'इससे अवरुद्ध स्थानीय कार्रवाई हट जाती है। अगला सिंक Google Tasks से डेटा रीफ़्रेश करेगा।';

  @override
  String get pendingOperationDiscarded => 'लंबित कार्रवाई खारिज कर दी गई।';

  @override
  String get syncFailureNotificationTitle => 'BusyMax सिंक विफल';

  @override
  String syncFailureNotificationBody(String message) {
    return 'बैकग्राउंड सिंक विफल हुआ। $message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax सिंक में टकराव';

  @override
  String conflictNotificationBody(String summary) {
    return 'एक लंबित स्थानीय बदलाव अवरुद्ध हो गया। $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'आज देय कार्य';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज $count कार्य देय हैं।',
      one: 'आज एक कार्य देय है।',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'ईवेंट रिमाइंडर';

  @override
  String get taskReminderNotificationTitle => 'कार्य रिमाइंडर';

  @override
  String get eventReminderNotificationBody => 'ईवेंट जल्द शुरू होगा।';

  @override
  String get taskReminderNotificationBody => 'कार्य जल्द देय है।';

  @override
  String get notificationOpenAction => 'खोलें';

  @override
  String get notificationSnoozeAction => '10 मिनट के लिए स्नूज़ करें';

  @override
  String get notificationDismissAction => 'खारिज करें';

  @override
  String get notificationDetailsHidden =>
      'गोपनीयता सेटिंग्स के कारण विवरण छिपे हुए हैं।';

  @override
  String get previousMonth => 'पिछला महीना';

  @override
  String get nextMonth => 'अगला महीना';

  @override
  String get openMonthView => 'महीने का दृश्य खोलें';

  @override
  String get previousYear => 'पिछला वर्ष';

  @override
  String get nextYear => 'अगला वर्ष';

  @override
  String get openYearView => 'वर्ष का दृश्य खोलें';

  @override
  String weekNumberTooltip(int number) {
    return 'सप्ताह $number';
  }

  @override
  String get resizeAllDayPanel => 'पूरे दिन वाले पैनल का आकार बदलें';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम',
      one: '1 आइटम',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'यह कैलेंडर केवल पढ़ने योग्य है।';

  @override
  String get selectTimeZone => 'समय क्षेत्र चुनें';

  @override
  String get searchLocations => 'स्थान खोजें';

  @override
  String get noLocationsFound => 'कोई स्थान नहीं मिला';

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
  String get singleOccurrence => 'यह इवेंट';

  @override
  String get thisAndFollowingEvents => 'यह और इसके बाद के इवेंट';

  @override
  String get thisAndFutureUnavailable => 'यह प्रदाता इसका समर्थन नहीं करता।';

  @override
  String get thisAndFutureMoveUnavailable =>
      'इस और इसके बाद के इवेंट सुरक्षित रूप से नहीं ले जाए जा सकते। यह इवेंट या पूरी शृंखला चुनें।';

  @override
  String get entireSeriesMoveUnavailable =>
      'दोहराव का नियम स्थानीय रूप से उपलब्ध नहीं है। इसके बजाय केवल यह इवेंट ले जाएँ।';

  @override
  String get copyEventAndDeleteOriginal =>
      'इवेंट की कॉपी बनाकर मूल इवेंट मिटाएँ?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax इस इवेंट को $source से $destination में सीधे नहीं ले जा सकता। यह पहले कॉपी बनाएगा और कॉपी सफल होने के बाद ही मूल इवेंट मिटाएगा। इवेंट ID बदलेंगे; सहभागियों की प्रतिक्रिया स्थितियां रीसेट हो सकती हैं और आमंत्रण या रद्दीकरण भेजे जा सकते हैं; और कॉन्फ़्रेंस लिंक, अटैचमेंट, रिमाइंडर, प्रदाता-विशिष्ट फ़ील्ड तथा दोहराव अपवाद शायद स्थानांतरित न हों।';
  }

  @override
  String get copyAndDelete => 'कॉपी बनाएँ और मिटाएँ';

  @override
  String get chooseRecurringEventScope =>
      'Choose whether this change applies to the entire series or only this occurrence.';

  @override
  String get taskDueBeforeStart => 'नियत समय प्रारंभ समय से पहले नहीं हो सकता।';

  @override
  String get taskStartDueTimeModeMismatch =>
      'प्रारंभ और नियत समय दोनों सेट करें, या कार्य को पूरे दिन का बनाएँ।';

  @override
  String deleteCalendarConfirmation(String title) {
    return '“$title” मिटाएँ?';
  }

  @override
  String get networkOffline => 'ऑफ़लाइन';

  @override
  String get networkOfflineDescription =>
      'कनेक्शन वापस आने पर बदलाव सिंक हो जाएंगे।';

  @override
  String get networkOfflineTryAgain =>
      'आप ऑफ़लाइन हैं। इंटरनेट से कनेक्ट करें और फिर से कोशिश करें।';
}

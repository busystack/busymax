// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Connect Google, Microsoft, Apple iCloud Calendar, or Nextcloud accounts.';

  @override
  String get googlePermissionsConsentNotice =>
      'در صفحهٔ مجوزهای Google، مجوزهای تقویم و کارها را هر دو انتخاب کنید.';

  @override
  String get googlePermissionsRequiredRetry =>
      'مجوزهای Google Calendar و Google Tasks لازم هستند. دوباره تلاش کنید و هر دو کادر را علامت بزنید.';

  @override
  String get finishSetup => 'پایان راه‌اندازی';

  @override
  String get continueSetup => 'ادامه';

  @override
  String get onboardingSetupTitle => 'راه‌اندازی BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'اتصال حساب‌ها';

  @override
  String get onboardingAccountsStepDescription =>
      'Add every account you want to use. BusyMax syncs supported calendars, events, task lists, and tasks from each account.';

  @override
  String get onboardingPreferencesStepTitle => 'انتخاب تنظیمات سیستم';

  @override
  String get onboardingPreferencesStepDescription =>
      'پیش از باز کردن برنامه، رفتار برنامه روی میزکار، یادآورها، سطح جزئیات اعلان‌ها و ظاهر را تنظیم کنید.';

  @override
  String get signInWithGoogle => 'ورود با Google';

  @override
  String get signInWithMicrosoft => 'ورود با Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'این سرویس پیکربندی نشده است.';

  @override
  String get waitingForGoogleSignIn => 'در انتظار ورود به Google...';

  @override
  String get waitingForMicrosoftSignIn => 'در انتظار ورود به Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'ورود به Microsoft پیکربندی نشده است. MICROSOFT_OAUTH_CLIENT_ID را تنظیم کنید.';

  @override
  String get cancel => 'لغو';

  @override
  String get close => 'بستن';

  @override
  String get exit => 'خروج';

  @override
  String get options => 'گزینه‌ها';

  @override
  String get hide => 'پنهان کردن';

  @override
  String get show => 'نمایش';

  @override
  String get export => 'خروجی گرفتن';

  @override
  String get save => 'ذخیره';

  @override
  String get settings => 'تنظیمات';

  @override
  String get all => 'همه';

  @override
  String get calendarEvents => 'رویدادها';

  @override
  String get calendarTasks => 'کارها';

  @override
  String get calendar => 'تقویم';

  @override
  String get calendars => 'تقویم‌ها';

  @override
  String get newCalendar => 'تقویم جدید';

  @override
  String get calendarColor => 'رنگ تقویم';

  @override
  String calendarColorOption(int number) {
    return 'رنگ $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'این ارائه‌دهنده از مدیریت تقویم در BusyMax پشتیبانی نمی‌کند.';

  @override
  String get primaryCalendarCannotDelete => 'تقویم اصلی را نمی‌توان حذف کرد.';

  @override
  String calendarCreateFailed(String error) {
    return 'ایجاد تقویم ممکن نشد: $error';
  }

  @override
  String calendarUpdateFailed(String error) {
    return 'به‌روزرسانی تقویم ممکن نشد: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'حذف تقویم ممکن نشد: $error';
  }

  @override
  String get newEvent => 'رویداد جدید';

  @override
  String get refreshCalendar => 'تازه‌سازی تقویم';

  @override
  String get openInProvider => 'باز کردن در سرویس';

  @override
  String get hideFromSchedule => 'پنهان کردن از برنامه';

  @override
  String get showInSchedule => 'نمایش در برنامه';

  @override
  String get noCalendarsSynced => 'هنوز هیچ تقویمی همگام نشده است.';

  @override
  String get allDay => 'تمام روز';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+⁨$countString⁩ مورد دیگر';
  }

  @override
  String get noEventsOrTasks => 'هیچ رویداد یا کاری وجود ندارد';

  @override
  String get scheduleLoading => 'در حال بارگیری برنامه...';

  @override
  String get scheduleUnavailable => 'برنامه در دسترس نیست';

  @override
  String get scheduleNoSources =>
      'هیچ تقویم یا فهرست کار قابل نمایشی وجود ندارد';

  @override
  String get scheduleNoSourcesDescription =>
      'در تنظیمات انتخاب کنید چه چیزهایی نمایش داده شوند، سپس برنامه را تازه‌سازی کنید.';

  @override
  String get scheduleSignInRequired => 'اتصال حساب';

  @override
  String get scheduleSignInDescription =>
      'برای همگام‌سازی تقویم‌ها و کارها وارد شوید.';

  @override
  String get scheduleNoSearchResults => 'هیچ رویداد یا کار منطبقی وجود ندارد';

  @override
  String get scheduleNoSearchResultsDescription =>
      'جست‌وجوی دیگری را امتحان کنید یا پالایه‌های فعلی را پاک کنید.';

  @override
  String get refresh => 'تازه‌سازی';

  @override
  String get trayOpenBusyMax => 'باز کردن BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'بارگیری کارهای عقب‌افتادهٔ بیشتر';

  @override
  String get agendaLoadMoreNoDate => 'بارگیری کارهای بدون تاریخ بیشتر';

  @override
  String get viewDay => 'روز';

  @override
  String get viewWeek => 'هفته';

  @override
  String get viewMonth => 'ماه';

  @override
  String get viewYear => 'سال';

  @override
  String get viewAgenda => 'برنامه';

  @override
  String get scheduleSettings => 'برنامه';

  @override
  String get scheduleDisplaySettings => 'نمایش برنامه';

  @override
  String get scheduleDisplayHoursDescription =>
      'نماهای روز و هفته ابتدا این بازهٔ زمانی را نشان می‌دهند. موارد زودتر یا دیرتر در صورت نیاز این بازه را گسترش می‌دهند.';

  @override
  String get scheduleDayStartsAt => 'شروع روز از';

  @override
  String get scheduleDayEndsAt => 'پایان روز در';

  @override
  String get sourceCalendar => 'تقویم';

  @override
  String get sourceTaskList => 'فهرست کار';

  @override
  String get createChoiceTitle => 'ایجاد';

  @override
  String get createEventAtTime => 'رویداد';

  @override
  String get createTaskAtDate => 'کار';

  @override
  String get editEvent => 'ویرایش رویداد';

  @override
  String get eventTitle => 'عنوان رویداد';

  @override
  String get location => 'مکان';

  @override
  String get timeSlot => 'بازهٔ زمانی';

  @override
  String get startDateTime => 'تاریخ/زمان شروع';

  @override
  String get endDateTime => 'تاریخ/زمان پایان';

  @override
  String get doesNotRepeat => 'تکرار نمی‌شود';

  @override
  String get defaultReminder => 'یادآور پیش‌فرض';

  @override
  String get guests => 'مهمانان';

  @override
  String get noGuests => 'بدون مهمان';

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
  String get description => 'توضیحات';

  @override
  String get availabilityShowAs => 'وضعیت دسترسی / نمایش به‌عنوان';

  @override
  String get busy => 'مشغول';

  @override
  String get visibility => 'قابلیت مشاهده';

  @override
  String get defaultVisibility => 'قابلیت مشاهدهٔ پیش‌فرض';

  @override
  String get conference => 'جلسه';

  @override
  String get noConference => 'بدون جلسه';

  @override
  String get providerCalendar => 'تقویم سرویس';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => 'پررنگ';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'مورب';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'زیرخط';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '⁨$minutesString⁩ دقیقه قبل',
      one: 'یک دقیقه قبل',
      zero: 'هنگام شروع',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'هنگام شروع';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '⁨$hoursString⁩ ساعت قبل',
      one: 'یک ساعت قبل',
      zero: 'هنگام شروع',
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
      other: '⁨$daysString⁩ روز قبل',
      one: 'یک روز قبل',
      zero: 'همان روز',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'آزاد';

  @override
  String get availabilityTentative => 'احتمالی';

  @override
  String get availabilityOutOfOffice => 'خارج از دفتر';

  @override
  String get availabilityWorkingElsewhere => 'مشغول به کار در مکانی دیگر';

  @override
  String get visibilityDefault => 'پیش‌فرض';

  @override
  String get visibilityPublic => 'عمومی';

  @override
  String get visibilityPrivate => 'خصوصی';

  @override
  String get visibilityConfidential => 'محرمانه';

  @override
  String get sensitivityNormal => 'عادی';

  @override
  String get sensitivityPersonal => 'شخصی';

  @override
  String get tasks => 'کارها';

  @override
  String get allTasks => 'همهٔ کارها';

  @override
  String tasksInList(String title) {
    return 'کارهای ⁨$title⁩';
  }

  @override
  String get taskLists => 'فهرست‌های کار';

  @override
  String get navigation => 'پیمایش';

  @override
  String get mainMenu => 'منوی اصلی';

  @override
  String get keyboardShortcuts => 'میان‌برهای صفحه‌کلید';

  @override
  String get shortcutGroupGeneral => 'عمومی';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'نمایش این راهنمای میان‌برها';

  @override
  String get shortcutGroupNavigation => 'پیمایش';

  @override
  String get shortcutNextPeriod => 'بازهٔ بعدی';

  @override
  String get shortcutNextPeriodDescription =>
      'هفتهٔ بعد در نمای هفته، ماه بعد در نمای ماه و به همین ترتیب';

  @override
  String get shortcutPreviousPeriod => 'بازهٔ قبلی';

  @override
  String get shortcutPreviousPeriodDescription =>
      'هفتهٔ قبل در نمای هفته، ماه قبل در نمای ماه و به همین ترتیب';

  @override
  String get shortcutJumpToToday => 'رفتن به امروز';

  @override
  String get shortcutGroupView => 'نما';

  @override
  String get shortcutDayView => 'نمای روز';

  @override
  String get shortcutWeekView => 'نمای هفته';

  @override
  String get shortcutMonthView => 'نمای ماه';

  @override
  String get shortcutYearView => 'نمای سال';

  @override
  String get shortcutAgendaView => 'نمای برنامه';

  @override
  String get shortcutGroupCreateAndEdit => 'ایجاد و ویرایش';

  @override
  String get shortcutSaveItem => 'ذخیرهٔ رویداد یا کار';

  @override
  String get shortcutDeleteItem => 'حذف رویداد یا کار';

  @override
  String get shortcutGroupTaskEditing => 'ویرایش کار';

  @override
  String get shortcutCancelEditing => 'لغو ویرایش';

  @override
  String get shortcutCancelEditingDescription => 'بستن ویرایش یا جزئیات کار';

  @override
  String get aboutBusyMax => 'دربارهٔ BusyMax';

  @override
  String get aboutBusyMaxDescription => 'تقویم و کارها';

  @override
  String get license => 'مجوز';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'وب‌سایت';

  @override
  String get sourceCode => 'کد منبع';

  @override
  String get reportAnIssue => 'گزارش مشکل';

  @override
  String get sendFeedback => 'ارسال بازخورد';

  @override
  String get feedbackSubmit => 'ارسال';

  @override
  String get feedbackCategory => 'دسته‌بندی';

  @override
  String get feedbackSelectCategory => 'یک دسته‌بندی انتخاب کنید';

  @override
  String get feedbackCategoryProblem => 'مشکل یا اشکال';

  @override
  String get feedbackCategoryFeature => 'درخواست قابلیت';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'نگرانی دربارهٔ حریم خصوصی یا امنیت';

  @override
  String get feedbackCategoryUsability => 'نگرانی دربارهٔ کاربردپذیری';

  @override
  String get feedbackCategoryOther => 'سایر';

  @override
  String get feedbackSubject => 'موضوع';

  @override
  String get feedbackDetailedMessage => 'پیام با جزئیات';

  @override
  String get feedbackReplyEmail => 'نشانی ایمیل برای پاسخ (اختیاری)';

  @override
  String get feedbackIncludeTechnicalDetails => 'افزودن جزئیات فنی';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'فقط نسخهٔ سیستم‌عامل Linux و تنظیمات منطقه‌ای برنامه افزوده می‌شود. هیچ گزارش، دادهٔ حساب، نام پرونده یا اطلاعات تشخیصی دیگری افزوده نمی‌شود.';

  @override
  String get feedbackCategoryRequired => 'یک دسته‌بندی انتخاب کنید.';

  @override
  String get feedbackSubjectLengthError =>
      'موضوع باید بین ۳ تا ۱۲۰ نویسه باشد.';

  @override
  String get feedbackMessageLengthError =>
      'پیام باید بین ۱۰ تا ۵٬۰۰۰ نویسه باشد.';

  @override
  String get feedbackInvalidEmail => 'یک نشانی ایمیل معتبر وارد کنید.';

  @override
  String get feedbackConnectionError =>
      'اتصال به BusyStack ممکن نشد. اتصال خود را بررسی و دوباره تلاش کنید.';

  @override
  String get feedbackTimeoutError =>
      'مهلت درخواست پایان یافت. بازخورد شما پاک نشده است؛ دوباره تلاش کنید.';

  @override
  String get feedbackRateLimitedError =>
      'بازخوردهای بیش از حدی از این شبکه ارسال شده است. کمی صبر کنید و دوباره تلاش کنید.';

  @override
  String get feedbackRejectedError =>
      'سرور ارسال را رد کرد. فیلدها را بررسی و دوباره تلاش کنید.';

  @override
  String get feedbackServerError =>
      'BusyStack اکنون نمی‌تواند بازخورد شما را بپذیرد. بازخورد شما پاک نشده است؛ دوباره تلاش کنید.';

  @override
  String feedbackSuccess(String id) {
    return 'بازخورد ارسال شد. شناسهٔ پیگیری: ⁨$id⁩';
  }

  @override
  String get toggleSidebar => 'نمایش یا پنهان کردن نوار کناری';

  @override
  String get showSidebar => 'نمایش پنل کناری';

  @override
  String get hideSidebar => 'پنهان کردن پنل کناری';

  @override
  String get accounts => 'حساب‌ها';

  @override
  String get currentAccount => 'حساب فعلی';

  @override
  String get switchAccount => 'تعویض حساب';

  @override
  String get addGoogleAccount => 'افزودن حساب Google';

  @override
  String get addMicrosoftAccount => 'افزودن حساب Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'وارد شده';

  @override
  String get removeAccount => 'حذف حساب…';

  @override
  String get removingAccount => 'در حال حذف حساب…';

  @override
  String get removeAccountDescription =>
      'همگام‌سازی را متوقف و داده‌های این حساب را از این دستگاه حذف کنید.';

  @override
  String removeAccountTitle(String account) {
    return 'حذف ⁨$account⁩ از BusyMax؟';
  }

  @override
  String get removeAccountConfirmation =>
      'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Provider copies of calendars, events, task lists, and tasks are not deleted.';

  @override
  String get revokeGoogleAccess =>
      'دسترسی BusyMax به این حساب Google نیز لغو شود';

  @override
  String get revokeGoogleAccessDescription =>
      'پیش از اتصال دوباره باید دسترسی را دوباره اعطا کنید.';

  @override
  String get removeAccountAction => 'حذف حساب';

  @override
  String get removeAccountFailed => 'حذف حساب کامل نشد. دوباره تلاش کنید.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'حساب از این دستگاه حذف شد، اما BusyMax نتوانست دسترسی Google را لغو کند. می‌توانید آن را از حساب Google خود لغو کنید.';

  @override
  String get newTaskList => 'فهرست کار جدید';

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
  String get signInToViewTaskLists => 'برای دیدن فهرست‌های کار وارد شوید.';

  @override
  String get noTaskListsSynced => 'هنوز هیچ فهرست کاری همگام نشده است.';

  @override
  String get listActions => 'عملیات فهرست';

  @override
  String get rename => 'تغییر نام';

  @override
  String get delete => 'حذف';

  @override
  String get renameList => 'تغییر نام فهرست';

  @override
  String get deleteList => 'حذف فهرست';

  @override
  String get unshare => 'لغو اشتراک‌گذاری';

  @override
  String get readOnlyTaskListCannotRename =>
      'This task list is read-only and cannot be renamed.';

  @override
  String get taskListCannotDelete =>
      'This task list cannot be deleted with your current permissions.';

  @override
  String get builtInMicrosoftList => 'داخلی';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'فهرست‌های داخلی Microsoft To Do را نمی‌توان تغییر نام داد یا حذف کرد.';

  @override
  String deleteListConfirmation(String title) {
    return '«⁨$title⁩» از Google Tasks حذف شود؟';
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
  String get deleteEvent => 'حذف رویداد';

  @override
  String get title => 'عنوان';

  @override
  String get create => 'ایجاد';

  @override
  String get newTask => 'کار جدید';

  @override
  String get clearCompleted => 'پاک کردن کارهای انجام‌شده';

  @override
  String get refreshList => 'تازه‌سازی فهرست';

  @override
  String get refreshAll => 'تازه‌سازی همه';

  @override
  String get listRefreshed => 'فهرست تازه‌سازی شد.';

  @override
  String get allTasksRefreshed => 'همهٔ حساب‌ها تازه‌سازی شدند.';

  @override
  String exportedFile(String path) {
    return 'در ⁨$path⁩ خروجی گرفته شد';
  }

  @override
  String exportFailed(String error) {
    return 'خروجی گرفتن ناموفق بود: ⁨$error⁩';
  }

  @override
  String refreshFailed(String error) {
    return 'تازه‌سازی ناموفق بود: ⁨$error⁩';
  }

  @override
  String get selectOrCreateTaskList =>
      'برای شروع، یک فهرست کار انتخاب یا ایجاد کنید.';

  @override
  String get signInToViewTasks => 'برای دیدن کارها وارد شوید.';

  @override
  String get noTasks => 'هیچ کاری وجود ندارد.';

  @override
  String get noTasksYet => 'هنوز کاری وجود ندارد';

  @override
  String get noTasksYetMessage =>
      'برای شروع یک کار ایجاد کنید یا حساب‌هایتان را تازه‌سازی کنید.';

  @override
  String get noTasksInList => 'هیچ کاری در این فهرست وجود ندارد.';

  @override
  String get overdue => 'گذشته از موعد';

  @override
  String get today => 'امروز';

  @override
  String get tomorrow => 'فردا';

  @override
  String get upcoming => 'پیش رو';

  @override
  String get noDate => 'بدون تاریخ';

  @override
  String get completed => 'انجام‌شده';

  @override
  String duePrefix(String date) {
    return 'سررسید: ⁨$date⁩';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '⁨$date⁩ · ⁨$time⁩';
  }

  @override
  String get taskDetails => 'جزئیات کار';

  @override
  String get editTask => 'ویرایش کار';

  @override
  String get noTaskSelected => 'هیچ کاری انتخاب نشده است.';

  @override
  String get noTaskSelectedHelper =>
      'برای دیدن و ویرایش جزئیات، کاری را انتخاب کنید.';

  @override
  String get taskUnavailable => 'کار در دسترس نیست.';

  @override
  String get signInToEditTasks => 'برای ویرایش کارها وارد شوید.';

  @override
  String get refreshTask => 'تازه‌سازی کار';

  @override
  String get primarySection => 'اصلی';

  @override
  String get statusSection => 'وضعیت';

  @override
  String get openStatus => 'باز';

  @override
  String get doneStatus => 'انجام‌شده';

  @override
  String get taskStatus => 'Status';

  @override
  String get taskStatusNone => 'No status';

  @override
  String get taskStatusNeedsAction => 'نیاز به اقدام';

  @override
  String get taskStatusInProcess => 'در حال انجام';

  @override
  String get taskStatusCompleted => 'انجام‌شده';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String completionPercent(int percent) {
    return '$percent% completed';
  }

  @override
  String get completionDate => 'Completion date';

  @override
  String get priority => 'اولویت';

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
  String get notes => 'یادداشت‌ها';

  @override
  String get dueDate => 'تاریخ سررسید';

  @override
  String get clearDueDate => 'پاک کردن تاریخ سررسید';

  @override
  String get dueTime => 'زمان سررسید';

  @override
  String get startDate => 'تاریخ شروع';

  @override
  String get startTime => 'زمان شروع';

  @override
  String get endDate => 'تاریخ پایان';

  @override
  String get endTime => 'زمان پایان';

  @override
  String get reminderDate => 'تاریخ یادآور';

  @override
  String get reminderTime => 'زمان یادآور';

  @override
  String get reminder => 'یادآور';

  @override
  String get addReminder => 'افزودن یادآور';

  @override
  String get reminders => 'Reminders';

  @override
  String get noReminders => 'بدون یادآوری';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get beforeTaskStarts => 'قبل از شروع کار';

  @override
  String get beforeTaskDue => 'قبل از موعد انجام کار';

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
  String get discardRelatedReminders => 'حذف یادآوری‌ها';

  @override
  String get keepRelatedReminders => 'نگه‌داشتن یادآوری‌ها';

  @override
  String get addGuest => 'افزودن مهمان';

  @override
  String get addGuestEmail => 'افزودن ایمیل مهمان';

  @override
  String get removeReminder => 'حذف یادآور';

  @override
  String get off => 'خاموش';

  @override
  String get repeat => 'تکرار';

  @override
  String get repeatNone => 'بدون تکرار';

  @override
  String get noneValue => 'هیچ‌کدام';

  @override
  String get repeatDaily => 'روزانه';

  @override
  String get repeatWeekly => 'هفتگی';

  @override
  String get repeatMonthly => 'ماهانه';

  @override
  String get repeatYearly => 'سالانه';

  @override
  String get repeatEvery => 'تکرار هر';

  @override
  String get repeatOn => 'Repeat on';

  @override
  String get repeatEnd => 'پایان تکرار';

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
    return 'در $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'در روز $days';
  }

  @override
  String repeatOnOrdinalSummary(String ordinal, String days) {
    return 'on the $ordinal $days';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'در $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count بار';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'تا $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'This recurrence rule uses options that this editor does not change.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'این تکرار را نمی‌توان با $provider استفاده کرد.';
  }

  @override
  String get importance => 'اهمیت';

  @override
  String get importanceLow => 'کم';

  @override
  String get importanceNormal => 'عادی';

  @override
  String get importanceHigh => 'زیاد';

  @override
  String get categories => 'دسته‌ها';

  @override
  String get scheduleSection => 'برنامه';

  @override
  String get dueGroup => 'سررسید';

  @override
  String get startGroup => 'شروع';

  @override
  String get reminderGroup => 'یادآور';

  @override
  String get organizationSection => 'سازمان‌دهی';

  @override
  String get actionsSection => 'عملیات';

  @override
  String get advancedSection => 'پیشرفته';

  @override
  String get addCategory => 'افزودن دسته';

  @override
  String get list => 'فهرست';

  @override
  String get microsoftMoveUnsupported =>
      'در این نسخه، جابه‌جایی کارها بین فهرست‌های حساب Microsoft To Do پشتیبانی نمی‌شود.';

  @override
  String get createSubtask => 'ایجاد زیرکار';

  @override
  String get subtasks => 'زیرکارها';

  @override
  String get duplicateTask => 'تکراری‌سازی وظیفه';

  @override
  String get taskDuplicated => 'Task duplicated.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Could not duplicate the task: $error';
  }

  @override
  String get hideSubtasks => 'مخفی‌سازی زیروظیفه‌ها';

  @override
  String get hideClosedSubtasks => 'مخفی‌سازی زیروظیفه‌های بسته‌شده';

  @override
  String get moveToTop => 'انتقال به بالاترین جایگاه';

  @override
  String get deleteTask => 'حذف کار';

  @override
  String get newSubtask => 'زیرکار جدید';

  @override
  String deleteTaskConfirmation(String title) {
    return '«⁨$title⁩» حذف شود؟';
  }

  @override
  String get metadata => 'فراداده';

  @override
  String get id => 'شناسه';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'به‌روزشده';

  @override
  String get parent => 'کار والد';

  @override
  String get position => 'جایگاه';

  @override
  String get webLink => 'پیوند وب';

  @override
  String get assignment => 'واگذاری';

  @override
  String get localState => 'وضعیت محلی';

  @override
  String get pendingSync => 'در انتظار همگام‌سازی';

  @override
  String get synced => 'همگام‌شده';

  @override
  String get account => 'حساب';

  @override
  String get sync => 'همگام‌سازی';

  @override
  String get manualFullSync => 'همگام‌سازی کامل دستی';

  @override
  String get runInBackgroundWhenClosed => 'ادامهٔ اجرا پس از بسته شدن پنجره';

  @override
  String get showTrayIcon => 'نمایش نماد سینی سیستم';

  @override
  String get startMinimizedToTray => 'شروع به‌صورت کوچک‌شده در سینی سیستم';

  @override
  String get launchAtLogin => 'اجرا هنگام ورود';

  @override
  String get launchAtLoginDescription =>
      'BusyMax را در پس‌زمینه اجرا کنید تا یادآورها پس از ورود کار کنند.';

  @override
  String get launchAtLoginFailed => 'تنظیم اجرای هنگام ورود به‌روزرسانی نشد.';

  @override
  String get requiresTrayIcon => 'به نماد سینی سیستم نیاز دارد.';

  @override
  String get syncComplete => 'همگام‌سازی کامل شد.';

  @override
  String syncFailed(String error) {
    return 'همگام‌سازی ناموفق بود: ⁨$error⁩';
  }

  @override
  String get notifySyncFailures => 'اعلان هنگام شکست همگام‌سازی';

  @override
  String get notifyConflicts => 'اعلان هنگام تداخل';

  @override
  String get notifyDueToday => 'اعلان کارهای دارای سررسید امروز';

  @override
  String get eventReminders => 'یادآورهای رویداد';

  @override
  String get taskReminders => 'یادآورهای کار';

  @override
  String get notificationDetailLevel => 'سطح جزئیات اعلان';

  @override
  String get notificationDetailPrivate => 'خصوصی';

  @override
  String get notificationDetailNormal => 'عادی';

  @override
  String get quietHours => 'ساعات سکوت';

  @override
  String get quietHoursDescription =>
      'اعلان‌ها را در این بازه موقتاً متوقف کنید.';

  @override
  String get quietHoursStart => 'شروع ساعات سکوت';

  @override
  String get quietHoursEnd => 'پایان ساعات سکوت';

  @override
  String get notifications => 'اعلان‌ها';

  @override
  String get appearance => 'ظاهر';

  @override
  String get theme => 'پوسته';

  @override
  String get themeSystem => 'سیستم';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تیره';

  @override
  String get themeFamily => 'خانوادهٔ پوسته';

  @override
  String get themeFamilyYaru => 'پوستهٔ بومی Ubuntu ‏(Yaru)';

  @override
  String get localization => 'زبان و منطقه';

  @override
  String get currentLocale => 'زبان و منطقهٔ فعلی';

  @override
  String get privacy => 'حریم خصوصی';

  @override
  String get redactTaskContentInDiagnostics =>
      'پنهان کردن محتوای کارها در اطلاعات تشخیصی';

  @override
  String get developerDiagnostics => 'تشخیص‌های توسعه‌دهنده';

  @override
  String get diagnostics => 'اطلاعات تشخیصی';

  @override
  String get apiInspectorDisabled => 'نمایش بازرس API';

  @override
  String get googleTasksApi => 'رابط Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'بازبینی Discovery: ⁨$revision⁩';
  }

  @override
  String get implementedMethods => 'روش‌های پیاده‌سازی‌شده';

  @override
  String get supportsTasksScopes =>
      'از محدوده‌های tasks و tasks.readonly پشتیبانی می‌کند';

  @override
  String get requiresTasksScope => 'به محدودهٔ tasks نیاز دارد';

  @override
  String get blockedPendingOperations => 'عملیات در انتظار مسدودشده';

  @override
  String get signInToInspectPendingOperations =>
      'برای بررسی عملیات در انتظار وارد شوید.';

  @override
  String get noBlockedPendingOperations =>
      'هیچ عملیات در انتظار مسدودشده‌ای وجود ندارد.';

  @override
  String get operationActions => 'اقدامات عملیات';

  @override
  String pendingOpListId(String id) {
    return 'فهرست=⁨$id⁩';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'کار=⁨$id⁩';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'تلاش‌ها=⁨$countString⁩';
  }

  @override
  String get retry => 'تلاش دوباره';

  @override
  String get discard => 'کنار گذاشتن';

  @override
  String get discardChangesAction => 'ذخیره نشود';

  @override
  String get discardChanges => 'تغییرات کنار گذاشته شوند؟';

  @override
  String get discardChangesConfirmation =>
      'با این کار ویرایش‌های ذخیره‌نشدهٔ این کار کنار گذاشته می‌شوند.';

  @override
  String get retryCompleted => 'تلاش دوباره کامل شد.';

  @override
  String get discardPendingOperation => 'عملیات در انتظار کنار گذاشته شود؟';

  @override
  String get discardPendingOperationConfirmation =>
      'با این کار عملیات محلی مسدودشده حذف می‌شود. در همگام‌سازی بعدی، داده‌ها از Google Tasks تازه‌سازی می‌شوند.';

  @override
  String get pendingOperationDiscarded => 'عملیات در انتظار کنار گذاشته شد.';

  @override
  String get syncFailureNotificationTitle => 'همگام‌سازی BusyMax ناموفق بود';

  @override
  String syncFailureNotificationBody(String message) {
    return 'همگام‌سازی پس‌زمینه ناموفق بود. ⁨$message⁩';
  }

  @override
  String get conflictNotificationTitle => 'تداخل همگام‌سازی BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'یک تغییر محلی در انتظار مسدود شد. ⁨$summary⁩';
  }

  @override
  String get dueTodayNotificationTitle => 'کارهای دارای سررسید امروز';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'امروز ⁨$countString⁩ کار سررسید دارند.',
      one: 'امروز یک کار سررسید دارد.',
      zero: 'امروز هیچ کاری سررسید ندارد.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'یادآور رویداد';

  @override
  String get taskReminderNotificationTitle => 'یادآور کار';

  @override
  String get eventReminderNotificationBody => 'رویداد به‌زودی شروع می‌شود.';

  @override
  String get taskReminderNotificationBody => 'سررسید کار نزدیک است.';

  @override
  String get notificationOpenAction => 'باز کردن';

  @override
  String get notificationSnoozeAction => 'تعویق ۱۰ دقیقه‌ای';

  @override
  String get notificationDismissAction => 'رد کردن';

  @override
  String get notificationDetailsHidden =>
      'جزئیات به‌دلیل تنظیمات حریم خصوصی پنهان شده‌اند.';

  @override
  String get previousMonth => 'ماه قبل';

  @override
  String get nextMonth => 'ماه بعد';

  @override
  String get openMonthView => 'باز کردن نمای ماه';

  @override
  String get previousYear => 'سال قبل';

  @override
  String get nextYear => 'سال بعد';

  @override
  String get openYearView => 'باز کردن نمای سال';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'هفتهٔ ⁨$numberString⁩';
  }

  @override
  String get resizeAllDayPanel => 'تغییر اندازهٔ پنل تمام‌روز';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ مورد',
      one: 'یک مورد',
      zero: 'هیچ موردی',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'این تقویم فقط‌خواندنی است.';

  @override
  String get selectTimeZone => 'انتخاب منطقهٔ زمانی';

  @override
  String get searchLocations => 'جست‌وجوی مکان‌ها';

  @override
  String get noLocationsFound => 'مکانی پیدا نشد';

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
  String get singleOccurrence => 'این رویداد';

  @override
  String get thisAndFollowingEvents => 'این رویداد و رویدادهای بعدی';

  @override
  String get thisAndFutureUnavailable =>
      'این ارائه‌دهنده از آن پشتیبانی نمی‌کند.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'انتقال امن این رویداد و رویدادهای بعدی ممکن نیست. این رویداد یا کل مجموعه را انتخاب کنید.';

  @override
  String get entireSeriesMoveUnavailable =>
      'قاعدهٔ تکرار به‌صورت محلی در دسترس نیست. به‌جای آن فقط این رویداد را منتقل کنید.';

  @override
  String get copyEventAndDeleteOriginal => 'رویداد کپی و نسخهٔ اصلی حذف شود؟';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax نمی‌تواند این رویداد را مستقیماً از $source به $destination منتقل کند. ابتدا کپی را ایجاد می‌کند و فقط پس از موفقیت کپی، نسخهٔ اصلی را حذف می‌کند. شناسه‌های رویداد تغییر می‌کنند؛ ممکن است وضعیت پاسخ شرکت‌کنندگان بازنشانی شود و دعوت‌نامه یا لغو ارسال شود؛ و شاید پیوندهای جلسه، پیوست‌ها، یادآورها، فیلدهای ویژهٔ ارائه‌دهنده و استثناهای تکرار منتقل نشوند.';
  }

  @override
  String get copyAndDelete => 'کپی و حذف';

  @override
  String get chooseRecurringEventScope =>
      'Choose whether this change applies to the entire series or only this occurrence.';

  @override
  String get taskDueBeforeStart => 'زمان سررسید نباید پیش از زمان شروع باشد.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'برای شروع و سررسید هر دو زمان تعیین کنید، یا کار را تمام‌روز کنید.';

  @override
  String deleteCalendarConfirmation(String title) {
    return '«⁨$title⁩» حذف شود؟';
  }

  @override
  String get setCustomCalendarName => 'تنظیم نام سفارشی';

  @override
  String get setAction => 'تنظیم';

  @override
  String get removeFromMyCalendars => 'حذف از تقویم‌های من';

  @override
  String get removeAction => 'حذف';

  @override
  String removeCalendarConfirmation(String title) {
    return '«$title» از فهرست تقویم Google شما حذف شود؟ تقویم اشتراکی و رویدادهای آن حذف نخواهند شد.';
  }

  @override
  String get calendarCannotRemove =>
      'این تقویم را نمی‌توان از این حساب حذف کرد.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'پیش از حذف یا برداشتن این تقویم، صبر کنید تا تغییرات در انتظار آن همگام‌سازی شوند.';

  @override
  String get networkOffline => 'آفلاین';

  @override
  String get networkOfflineDescription =>
      'تغییرات پس از برقراری دوبارهٔ اتصال همگام‌سازی می‌شوند.';

  @override
  String get networkOfflineTryAgain =>
      'آفلاین هستید. به اینترنت متصل شوید و دوباره تلاش کنید.';
}

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
      'حساب‌های Google، Microsoft، Apple iCloud Calendar یا Nextcloud را متصل کنید.';

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
      'همهٔ حساب‌هایی را که می‌خواهید استفاده کنید اضافه کنید. BusyMax تقویم‌ها، رویدادها، فهرست‌های کار و کارهای پشتیبانی‌شده را از هر حساب همگام می‌کند.';

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
  String get calendarCreatedRefreshPending =>
      'تقویم ایجاد شد، اما BusyMax نتوانست حساب را تازه‌سازی کند. پس از همگام‌سازی بعدی نمایش داده می‌شود.';

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
  String get trayShowBusyMax => 'نمایش BusyMax';

  @override
  String get trayNewEvent => 'رویداد جدید…';

  @override
  String get trayNewTask => 'کار جدید…';

  @override
  String get trayToday => 'امروز';

  @override
  String get trayAllDay => 'تمام‌روز';

  @override
  String get trayNow => 'اکنون';

  @override
  String get trayCalendarEvent => 'رویداد تقویم';

  @override
  String get trayUntitledEvent => 'رویداد بدون عنوان';

  @override
  String get trayNothingElseToday => 'امروز مورد دیگری نیست';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کار امروز سررسید دارند',
      one: '۱ کار امروز سررسید دارد',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'باز کردن برنامهٔ امروز';

  @override
  String get traySyncNow => 'همگام‌سازی اکنون';

  @override
  String get traySyncing => 'در حال همگام‌سازی…';

  @override
  String get trayNotConnected => 'متصل نیست';

  @override
  String get trayNotYetSynced => 'هنوز همگام نشده';

  @override
  String get trayLastSyncedJustNow => 'همین الان همگام شد';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقیقه پیش همگام شد',
      one: '۱ دقیقه پیش همگام شد',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعت پیش همگام شد',
      one: '۱ ساعت پیش همگام شد',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count روز پیش همگام شد',
      one: '۱ روز پیش همگام شد',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'تنظیمات';

  @override
  String get trayQuitBusyMax => 'خروج از BusyMax';

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
  String get noGuests => 'مهمانی وجود ندارد';

  @override
  String get attendeeRequired => 'ضروری';

  @override
  String get attendeeOptional => 'اختیاری';

  @override
  String get meetingSection => 'جلسه';

  @override
  String get addGoogleMeet => 'افزودن Google Meet';

  @override
  String get addTeamsMeeting => 'افزودن جلسهٔ Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'جلسهٔ آنلاین افزوده شد';

  @override
  String get requestResponses => 'درخواست پاسخ';

  @override
  String get requestResponsesDescription =>
      'از مهمانان بخواهید به دعوت‌نامه پاسخ دهند.';

  @override
  String get hideGuestList => 'پنهان کردن فهرست مهمانان';

  @override
  String get hideGuestListDescription =>
      'مهمانان نمی‌توانند ببینند چه افراد دیگری دعوت شده‌اند.';

  @override
  String get allowNewTimeProposals => 'اجازهٔ پیشنهاد زمان‌های جدید';

  @override
  String get allowNewTimeProposalsDescription =>
      'مهمانان می‌توانند زمان دیگری برای جلسه پیشنهاد کنند.';

  @override
  String get notifyGuestsTitle => 'مهمانان اطلاع داده شوند؟';

  @override
  String get notifyGuestsSaveMessage =>
      'این جلسه مهمان دارد. هنگام ذخیره، دعوت‌نامه یا به‌روزرسانی رویداد برای آن‌ها ارسال شود؟';

  @override
  String get notifyGuestsDeleteMessage =>
      'این جلسه مهمان دارد. هنگام حذف، لغو جلسه ارسال شود؟';

  @override
  String get sendUpdates => 'ارسال به‌روزرسانی‌ها';

  @override
  String get sendCancellation => 'ارسال لغو';

  @override
  String get doNotSend => 'ارسال نکن';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'جلسه ذخیره شود؟';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft دعوت‌نامه یا به‌روزرسانی رویداد را برای مهمانان ارسال می‌کند.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'جلسه حذف شود؟';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft لغو جلسه را برای مهمانان ارسال می‌کند.';

  @override
  String get organizer => 'برگزارکننده';

  @override
  String get yourResponse => 'پاسخ شما';

  @override
  String get guestResponses => 'پاسخ مهمانان';

  @override
  String get respond => 'پاسخ دادن';

  @override
  String get acceptInvitation => 'پذیرفتن';

  @override
  String get tentativeInvitation => 'موقت';

  @override
  String get declineInvitation => 'رد کردن';

  @override
  String get joinMeeting => 'پیوستن به جلسه';

  @override
  String get responseAccepted => 'پذیرفته‌شده';

  @override
  String get responseTentative => 'موقت';

  @override
  String get responseDeclined => 'ردشده';

  @override
  String get responseNeedsAction => 'در انتظار پاسخ';

  @override
  String get responseNotResponded => 'بی‌پاسخ';

  @override
  String get responseOrganizer => 'برگزارکننده';

  @override
  String invitationResponseFailed(String error) {
    return 'ارسال پاسخ شما ممکن نیست: $error';
  }

  @override
  String get joinMeetingFailed => 'باز کردن پیوند جلسه ممکن نیست.';

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
    return '$account از BusyMax حذف شود؟';
  }

  @override
  String get removeAccountConfirmation =>
      'این کار، کارها، تقویم‌ها، رویدادها، یادآورها و تغییرات آفلاین در انتظار را که در این دستگاه ذخیره شده‌اند حذف می‌کند. تغییرات همگام‌نشده از بین می‌روند. نسخه‌های تقویم‌ها، رویدادها، فهرست‌های کار و کارها نزد ارائه‌دهنده حذف نمی‌شوند.';

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
    return 'ایجاد فهرست کار ممکن نیست: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'تغییر نام فهرست کار ممکن نیست: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'حذف فهرست کار ممکن نیست: $error';
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
      'این فهرست کار فقط‌خواندنی است و نمی‌توان نام آن را تغییر داد.';

  @override
  String get taskListCannotDelete =>
      'این فهرست کار با مجوزهای فعلی شما قابل حذف نیست.';

  @override
  String get builtInMicrosoftList => 'داخلی';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'فهرست‌های داخلی Microsoft To Do را نمی‌توان تغییر نام داد یا حذف کرد.';

  @override
  String deleteListConfirmation(String title) {
    return '‏«$title» از Google Tasks حذف شود؟';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '‏«$title» و همهٔ کارهای آن حذف شوند؟';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'اشتراک‌گذاری «$title» از این حساب لغو شود؟';
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
  String get taskStatus => 'وضعیت';

  @override
  String get taskStatusNone => 'بدون وضعیت';

  @override
  String get taskStatusNeedsAction => 'نیازمند اقدام';

  @override
  String get taskStatusInProcess => 'در حال انجام';

  @override
  String get taskStatusCompleted => 'انجام‌شده';

  @override
  String get taskStatusCancelled => 'لغوشده';

  @override
  String completionPercent(int percent) {
    return '$percent٪ تکمیل‌شده';
  }

  @override
  String get completionDate => 'تاریخ تکمیل';

  @override
  String get priority => 'اولویت';

  @override
  String get priorityNone => 'بدون اولویت';

  @override
  String priorityHighValue(int priority) {
    return 'اولویت $priority · زیاد';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'اولویت $priority · متوسط';
  }

  @override
  String priorityLowValue(int priority) {
    return 'اولویت $priority · کم';
  }

  @override
  String get taskUrl => 'URL کار';

  @override
  String get invalidTaskUrl => 'یک URL مطلق شامل طرح آن وارد کنید.';

  @override
  String get classification => 'دسته‌بندی';

  @override
  String get classificationPublic => 'هنگام اشتراک‌گذاری، کل کار نشان داده شود';

  @override
  String get classificationConfidential =>
      'هنگام اشتراک‌گذاری، فقط مشغول بودن نشان داده شود';

  @override
  String get classificationPrivate => 'هنگام اشتراک‌گذاری، این کار پنهان شود';

  @override
  String get pinTask => 'سنجاق کردن کار';

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
  String get reminders => 'یادآورها';

  @override
  String get noReminders => 'بدون یادآور';

  @override
  String get editReminder => 'ویرایش یادآور';

  @override
  String get beforeTaskStarts => 'پیش از شروع کار';

  @override
  String get beforeTaskDue => 'پیش از سررسید کار';

  @override
  String get afterTaskStarts => 'پس از شروع کار';

  @override
  String get afterTaskDue => 'پس از سررسید کار';

  @override
  String get relativeToTaskStart => 'نسبت به تاریخ شروع کار';

  @override
  String get relativeToTaskDue => 'نسبت به تاریخ سررسید کار';

  @override
  String get reminderTimeOfDay => 'زمان روز';

  @override
  String get absoluteReminder => 'در تاریخ و زمان مشخص';

  @override
  String get reminderAmount => 'مقدار';

  @override
  String get reminderUnit => 'واحد';

  @override
  String get reminderUnitSeconds => 'ثانیه';

  @override
  String get reminderUnitMinutes => 'دقیقه';

  @override
  String get reminderUnitHours => 'ساعت';

  @override
  String get reminderUnitDays => 'روز';

  @override
  String get reminderUnitWeeks => 'هفته';

  @override
  String get reminderAtTaskStart => 'هنگام شروع کار';

  @override
  String get reminderAtTaskDue => 'هنگام سررسید کار';

  @override
  String get unsupportedReminder =>
      'نوع این یادآور حفظ می‌شود، اما زمان آن قابل ویرایش نیست.';

  @override
  String get relatedRemindersTitle => 'یادآورهای مرتبط نگه داشته شوند؟';

  @override
  String relatedRemindersDescription(int count) {
    return 'این تاریخ $count یادآور مرتبط دارد. آن‌ها در تاریخ و زمان فعلی نگه داشته شوند؟';
  }

  @override
  String get discardRelatedReminders => 'دور انداختن یادآورها';

  @override
  String get keepRelatedReminders => 'نگه‌داشتن یادآورها';

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
  String get repeatEvery => 'فاصلهٔ تکرار';

  @override
  String get repeatOn => 'تکرار در';

  @override
  String get repeatEnd => 'پایان تکرار';

  @override
  String get repeatNever => 'هرگز';

  @override
  String get repeatUntil => 'در تاریخ';

  @override
  String get repeatAfter => 'پس از تعداد مشخصی تکرار';

  @override
  String get repeatCount => 'تعداد تکرار';

  @override
  String get repeatDayOfMonth => 'روزهای ماه';

  @override
  String get repeatMonths => 'ماه‌ها';

  @override
  String get repeatOrdinal => 'جایگاه روز هفته';

  @override
  String get repeatSpecificDays => 'روزهای مشخص';

  @override
  String get repeatFirst => 'اول';

  @override
  String get repeatSecond => 'دوم';

  @override
  String get repeatThird => 'سوم';

  @override
  String get repeatFourth => 'چهارم';

  @override
  String get repeatFifth => 'پنجم';

  @override
  String get repeatSecondToLast => 'یکی مانده به آخر';

  @override
  String get repeatLast => 'آخر';

  @override
  String get repeatAnyDay => 'روز';

  @override
  String get repeatWeekday => 'روز هفته';

  @override
  String get repeatWeekendDay => 'روز آخر هفته';

  @override
  String repeatEveryDays(int count) {
    return 'هر $count روز';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'هر $count هفته';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'هر $count ماه';
  }

  @override
  String repeatEveryYears(int count) {
    return 'هر $count سال';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'در $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'در روز $days ماه';
  }

  @override
  String repeatOnOrdinalSummary(String ordinal, String days) {
    return 'در $ordinal $days';
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
      'این قانون تکرار از گزینه‌هایی استفاده می‌کند که این ویرایشگر تغییر نمی‌دهد.';

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
  String get duplicateTask => 'تکرار کار';

  @override
  String get taskDuplicated => 'کار تکرار شد.';

  @override
  String taskDuplicateFailed(String error) {
    return 'تکرار کار ممکن نیست: $error';
  }

  @override
  String get hideSubtasks => 'پنهان کردن زیروظیفه‌ها';

  @override
  String get hideClosedSubtasks => 'پنهان کردن زیروظیفه‌های بسته‌شده';

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
  String get onState => 'روشن';

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
    return 'یک تغییر محلی در انتظار مسدود شد. $summary';
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
  String get notificationDismissAction => 'بستن';

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
  String get requiredField => 'این فیلد الزامی است.';

  @override
  String get providerConnectionDescription =>
      'تقویم‌ها و کارها را از یکی از این ارائه‌دهندگان متصل کنید.';

  @override
  String get appleICloudProvider => 'تقویم Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'کارهای Nextcloud';

  @override
  String get addAppleICloudAccount => 'افزودن حساب تقویم Apple iCloud';

  @override
  String get addNextcloudAccount => 'افزودن حساب Nextcloud';

  @override
  String get waitingForAppleICloud => 'در حال اتصال به Apple iCloud…';

  @override
  String get waitingForNextcloud => 'در انتظار تأیید Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'اتصال تقویم Apple iCloud';

  @override
  String get appleAccountEmail => 'ایمیل حساب Apple';

  @override
  String get appleAppSpecificPassword => 'گذرواژهٔ اختصاصی برنامه';

  @override
  String get appleAppSpecificPasswordHelp =>
      'پس از فعال کردن احراز هویت دومرحله‌ای برای حساب Apple، یک گذرواژهٔ اختصاصی برنامه بسازید.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'بازنشانی گذرواژهٔ حساب Apple، گذرواژه‌های اختصاصی برنامه را باطل می‌کند.';

  @override
  String get connectNextcloudTitle => 'اتصال Nextcloud';

  @override
  String get nextcloudServerUrl => 'سرور Nextcloud یا نشانی CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'URL سرور Nextcloud خود را وارد کنید یا نشانی اصلی CalDAV را که از Nextcloud کپی کرده‌اید بچسبانید.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax مرورگر شما را باز می‌کند. آنجا دسترسی را تأیید کنید و سپس به BusyMax برگردید.';

  @override
  String get connectAccountAction => 'اتصال';

  @override
  String get cancelAccountConnection => 'لغو اتصال';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'حساب به‌صورت محلی حذف شد، اما ابطال گذرواژهٔ برنامهٔ Nextcloud ممکن نیست.';

  @override
  String get davCachedOfflineNotice =>
      'داده‌های تقویم و کار برای استفادهٔ آفلاین به‌صورت محلی ذخیره می‌شوند.';

  @override
  String get davReauthenticationRequired =>
      'برای ادامهٔ همگام‌سازی، این حساب را دوباره متصل کنید.';

  @override
  String get davTemporarilyUnavailable => 'این حساب موقتاً در دسترس نیست.';

  @override
  String get davPermissionChanged =>
      'مجوزهای سرور تغییر کرده‌اند. ویرایش‌های در انتظار متوقف شده‌اند.';

  @override
  String get davUnsupportedServer =>
      'این سرور یا نمایهٔ ارائه‌دهنده پشتیبانی نمی‌شود.';

  @override
  String get collectionSettings => 'تقویم‌ها و فهرست‌های کار';

  @override
  String get calendarContent => 'رویدادهای تقویم';

  @override
  String get taskContent => 'کارها';

  @override
  String get readOnlySharedCollection => 'فقط‌خواندنی';

  @override
  String get pendingLocally => 'در انتظار محلی';

  @override
  String get conflictBlocked => 'مسدودشده به‌دلیل تعارض';

  @override
  String get authenticationBlocked => 'تا اتصال دوباره مسدود است';

  @override
  String get operationFailed => 'عملیات ناموفق بود';

  @override
  String get keepServerVersion => 'نگه‌داشتن نسخهٔ سرور';

  @override
  String get reapplyLocalChange => 'بررسی و اعمال دوبارهٔ تغییر محلی';

  @override
  String get duplicateLocalItem => 'تکرار به‌عنوان مورد جدید';

  @override
  String get davConnectionState => 'وضعیت اتصال';

  @override
  String get davConnected => 'متصل';

  @override
  String get davConnecting => 'در حال اتصال…';

  @override
  String get davSignedOut => 'خارج‌شده';

  @override
  String davLastSuccessfulSync(String time) {
    return 'آخرین همگام‌سازی موفق: $time';
  }

  @override
  String get davNeverSynced => 'هنوز همگام نشده';

  @override
  String get refreshCollections => 'تازه‌سازی تقویم‌ها و فهرست‌های کار';

  @override
  String nextcloudServerHost(String host) {
    return 'سرور: $host';
  }

  @override
  String get collectionSupportsEvents => 'تقویم رویدادها';

  @override
  String get collectionSupportsTasks => 'فهرست کار';

  @override
  String get collectionSupportsEventsAndTasks => 'رویدادها و کارها';

  @override
  String get writableCollection => 'قابل نوشتن';

  @override
  String get sharedCollection => 'اشتراکی';

  @override
  String collectionLastSynced(String time) {
    return 'آخرین همگام‌سازی: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'مشکل همگام‌سازی: $code';
  }

  @override
  String get syncConflicts => 'تعارض‌های همگام‌سازی';

  @override
  String remoteChangedAt(String time) {
    return 'تغییر سرور: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'ویرایش محلی: $summary';
  }

  @override
  String get conflictResolutionFailed => 'حل تعارض ممکن نیست.';

  @override
  String get recurringEventScope => 'دامنهٔ رویداد تکرارشونده';

  @override
  String get entireSeries => 'کل مجموعه';

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
      'انتخاب کنید این تغییر برای کل مجموعه، فقط این رویداد، یا این رویداد و رویدادهای بعدی اعمال شود.';

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
      'این تقویم را نمی‌توان از این حساب حذف یا جدا کرد.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'پیش از حذف یا جدا کردن این تقویم، صبر کنید تغییرات در انتظار آن همگام شوند.';

  @override
  String get calendarSubscriptions => 'اشتراک‌های تقویم';

  @override
  String get calendarSubscriptionsDescription =>
      'تقویم‌های فقط‌خواندنی را اضافه کنید که از یک URL امن WebCal تازه می‌شوند.';

  @override
  String get addCalendarSubscription => 'افزودن اشتراک تقویم';

  @override
  String get subscriptionName => 'نام محلی';

  @override
  String get subscriptionUrl => 'URL اشتراک';

  @override
  String get subscriptionUrlHelp =>
      'یک URL از نوع HTTPS یا webcal وارد کنید. BusyMax URL کامل را در فضای ذخیره‌سازی امن نگه می‌دارد.';

  @override
  String get subscriptionUrlInvalid =>
      'یک URL معتبر HTTPS یا webcal بدون اطلاعات کاربر یا قطعه وارد کنید.';

  @override
  String get subscriptionColor => 'رنگ محلی';

  @override
  String get subscriptionColorHelp => 'یک رنگ شش‌رقمی مانند #3584E4 وارد کنید.';

  @override
  String get subscriptionColorInvalid => 'یک رنگ هگزادسیمال شش‌رقمی وارد کنید.';

  @override
  String get subscriptionRefreshMode => 'دفعات تازه‌سازی';

  @override
  String get subscriptionAutomatic => 'خودکار';

  @override
  String get subscriptionHourly => 'ساعتی';

  @override
  String get subscriptionSixHours => 'هر شش ساعت';

  @override
  String get subscriptionDaily => 'روزانه';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'مبدأ: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'برای پیش‌نمایش مبدأ امن، یک URL معتبر وارد کنید.';

  @override
  String get subscriptionReadOnly => 'اشتراک فقط‌خواندنی';

  @override
  String get subscriptionNeverRefreshed => 'هنوز تازه نشده';

  @override
  String subscriptionLastRefresh(String time) {
    return 'آخرین تازه‌سازی موفق: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'تازه‌سازی بعدی: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'به‌روز';

  @override
  String subscriptionStatusIssue(String code) {
    return 'مشکل تازه‌سازی: $code';
  }

  @override
  String get refreshNow => 'تازه‌سازی اکنون';

  @override
  String get unsubscribe => 'لغو اشتراک';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'اشتراک «$name» لغو شود؟';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'این کار اشتراک محلی و رویدادهای ذخیره‌شدهٔ آن را حذف می‌کند. تقویم منتشرشده تغییر نمی‌کند.';

  @override
  String get addSubscriptionAction => 'افزودن اشتراک';

  @override
  String subscriptionOperationFailed(String error) {
    return 'اشتراک تقویم ناموفق بود: $error';
  }

  @override
  String get subscriptions => 'اشتراک‌ها';

  @override
  String get calendarImport => 'درون‌ریزی تقویم';

  @override
  String get calendarImportDescription =>
      'یک فایل انتخاب کنید، رویدادهای آن را بررسی کنید و سپس تقویم قابل نوشتنی را که باید آن‌ها را دریافت کند انتخاب کنید.';

  @override
  String get importIcsFile => 'درون‌ریزی فایل .ics';

  @override
  String get importIcsPreview => 'درون‌ریزی رویدادهای تقویم';

  @override
  String importEventsFound(int count) {
    return 'مجموعه رویدادهای قابل درون‌ریزی: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'رویدادهای نامعتبر: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'عمداً حذف‌شده: $fields';
  }

  @override
  String get noWritableCalendars => 'تقویم مقصد قابل نوشتنی موجود نیست.';

  @override
  String get importDestinationCalendar => 'تقویم مقصد';

  @override
  String get importIcsConfirm => 'درون‌ریزی رویدادها';

  @override
  String get importIcsComplete => 'درون‌ریزی کامل شد';

  @override
  String importQueued(int count) {
    return 'درون‌ریزی‌شده یا در صف: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'تکراری‌ها رد شدند: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'مجموعه‌های تکرار پشتیبانی‌نشده: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'درون‌ریزی فایل تقویم ممکن نیست: $error';
  }

  @override
  String get networkOffline => 'آفلاین';

  @override
  String get networkOfflineDescription =>
      'تغییرات پس از برقراری دوبارهٔ اتصال همگام‌سازی می‌شوند.';

  @override
  String get networkOfflineTryAgain =>
      'آفلاین هستید. به اینترنت متصل شوید و دوباره تلاش کنید.';
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get launchAtLoginManagedExternally =>
      'تم تشغيل BusyMax من إعدادات بدء التشغيل في سطح المكتب. أزل إدخاله هناك، ثم أنهِ BusyMax وافتحه مجددًا لاستخدام هذا المفتاح.';

  @override
  String get timeFormat => 'تنسيق الوقت';

  @override
  String get firstDayOfWeek => 'أول أيام الأسبوع';

  @override
  String get systemDefault => 'الإعداد الافتراضي للنظام';

  @override
  String systemDefaultResolved(String weekday) {
    return 'الإعداد الافتراضي للنظام (⁨$weekday⁩)';
  }

  @override
  String get timeFormatTwelveHour => '12 ساعة';

  @override
  String get timeFormatTwentyFourHour => '24 ساعة';

  @override
  String get timeEndOfDay => 'نهاية اليوم';

  @override
  String get timePeriod => 'الفترة';

  @override
  String get launchAtLoginReadFailed =>
      'تعذر تحديد حالة التشغيل عند تسجيل الدخول.';

  @override
  String get launchAtLoginUnavailable =>
      'التشغيل عند تسجيل الدخول غير متاح على هذا النظام.';

  @override
  String get windowsStartupEnabledByPolicy =>
      'فعّل المسؤول التشغيل عند بدء النظام ولا يمكن تغييره هنا.';

  @override
  String get settingsSaveFailed =>
      'تعذر حفظ الإعدادات. قد تُفقد تغييراتك عند إعادة تشغيل BusyMax.';

  @override
  String get nextcloudExportCollection => 'تصدير موارد المجموعة';

  @override
  String nextcloudImportItems(int count) {
    return 'تم العثور على $count من موارد الأحداث والمهام';
  }

  @override
  String get nextcloudSchedulingInbox => 'صندوق وارد الدعوات';

  @override
  String get nextcloudInboxExplanation =>
      'يعالج Nextcloud هذه الرسائل في تقاويمك. يؤدي الإقرار إلى إزالة الرسالة فقط، وليس الحدث.';

  @override
  String get nextcloudInboxEmpty => 'لا توجد رسائل جدولة.';

  @override
  String get nextcloudAcknowledge => 'الإقرار بالرسالة';

  @override
  String get nextcloudAcknowledgeConfirm =>
      'إزالة هذه الرسالة من صندوق الوارد؟ سيُحتفظ بحدث التقويم.';

  @override
  String get nextcloudGuestAvailability => 'التحقق من توفر المدعوين';

  @override
  String nextcloudTrashRetention(int days) {
    return 'مدة الاحتفاظ في مهملات الخادم: $days يومًا';
  }

  @override
  String get nextcloudCancelMeeting => 'إلغاء الاجتماع';

  @override
  String get nextcloudDeclineAndRemove => 'رفض الدعوة وإزالتها';

  @override
  String get nextcloudDeclineRemovalWarning =>
      'ستُرسل رسالة رفض عند المزامنة. لن يُلغى اجتماع المنظّم.';

  @override
  String get nextcloudAvailabilityUnknown => 'التوفر غير معروف';

  @override
  String get nextcloudAvailabilityFree =>
      'لم يُبلّغ عن فترات انشغال في هذا النطاق';

  @override
  String get nextcloudAvailabilityBusy => 'فترات الانشغال';

  @override
  String get nextcloudSchedulingPending =>
      'سيرسل Nextcloud تحديثات الاجتماع عند المزامنة. الحفظ المحلي لا يؤكد التسليم.';

  @override
  String get nextcloudAttendeeRestrictions =>
      'لا يمكن تغيير تفاصيل الاجتماع إلا للمنظّم أو المفوّض المخوّل. يمكنك الرد على الدعوة من تفاصيلها.';

  @override
  String get nextcloudMeetingMoveUnsupported =>
      'لا يمكن نقل هذا الاجتماع بالنسخ والحذف. استخدم تقويمًا له هوية الجدولة نفسها.';

  @override
  String get nextcloudSchedulingStatus => 'حالة الجدولة لدى الخادم';

  @override
  String get nextcloudImportFollowUp =>
      'حُفظت الموارد المستوردة محليًا. تحديث التذكيرات معلّق؛ لا تستوردها مجددًا.';

  @override
  String get nextcloudNativeImport =>
      'استيراد موارد الأحداث والمهام كاملةً دون إرسال دعوات. تُتخطى معرّفات UID الموجودة ما لم تختر نسخًا جديدة. يُبلّغ عن الموارد غير المدعومة كلٌّ على حدة.';

  @override
  String get nextcloudImportMethod =>
      'يحتوي الملف على رسائل جدولة. يحفظ الاستيراد المحتوى ويزيل METHOD؛ ولا يعالج دعوة أو ردًا.';

  @override
  String get nextcloudImportCopies => 'استيراد نسخ جديدة بهويات جديدة';

  @override
  String get nextcloudCollectionSettings => 'إعدادات المجموعة';

  @override
  String get nextcloudSharing => 'المشاركة';

  @override
  String get nextcloudOwned => 'مملوكة';

  @override
  String get nextcloudShared => 'مشتركة';

  @override
  String get nextcloudDelegated => 'مفوّضة';

  @override
  String get nextcloudSubscription => 'اشتراك';

  @override
  String get nextcloudDeleted => 'محذوفة';

  @override
  String get nextcloudMetadataEditable =>
      'محتوى التقويم للقراءة فقط؛ يمكن تغيير خصائص المجموعة.';

  @override
  String get nextcloudServerOrder =>
      'ترتيب الخادم (منفصل عن ترتيب الشريط الجانبي)';

  @override
  String get nextcloudCalendarEnabled => 'مفعّلة على الخادم';

  @override
  String get nextcloudAvailability => 'تضمين هذه المجموعة في التوفر';

  @override
  String get nextcloudCalendarTimezone =>
      'المنطقة الزمنية للتقويم (مستند VTIMEZONE)';

  @override
  String get nextcloudRefreshPending =>
      'حُفظ التغيير في Nextcloud. التحديث معلّق؛ لا تكرر التغيير.';

  @override
  String get nextcloudOutcomeUnknown =>
      'تعذّر تأكيد النتيجة لدى الخادم. حدّث قبل المحاولة مجددًا.';

  @override
  String get nextcloudRemoveShared => 'إزالة التقويم أو القائمة المشتركة';

  @override
  String get nextcloudRemoveMixed =>
      'تحتوي هذه المجموعة على أحداث ومهام. يؤدي حذفها إلى إزالة كليهما.';

  @override
  String get nextcloudReadAccess => 'للقراءة فقط';

  @override
  String get nextcloudWriteAccess => 'قراءة وكتابة';

  @override
  String get nextcloudRecipientSearch => 'البحث عن أشخاص أو مجموعات';

  @override
  String get nextcloudNoRecipients => 'لا توجد أشخاص أو مجموعات مطابقة.';

  @override
  String get nextcloudRevokeShare => 'إلغاء صلاحية الوصول';

  @override
  String get nextcloudPublish => 'نشر الرابط';

  @override
  String get nextcloudUnpublish => 'إيقاف النشر';

  @override
  String get nextcloudPublishWarning =>
      'قد يتمكن أي شخص يملك الرابط المنشور من قراءة هذا التقويم. هل تريد نشره؟';

  @override
  String get nextcloudTrash => 'التقاويم والمهام المحذوفة';

  @override
  String get nextcloudTrashEmpty => 'لا توجد عناصر تقويم محذوفة.';

  @override
  String get nextcloudRestore => 'استعادة';

  @override
  String get nextcloudPermanentDelete => 'حذف نهائي';

  @override
  String get nextcloudPermanentDeleteWarning =>
      'حذف هذا العنصر نهائيًا؟ لن يمكن استعادته من مهملات تقويم Nextcloud.';

  @override
  String get nextcloudOperationDenied => 'لم يسمح Nextcloud بهذه العملية.';

  @override
  String get nextcloudUnsupported => 'الخادم لا يدعم هذه العملية.';

  @override
  String get nextcloudPendingChanges =>
      'احفظ تغييرات المجموعة أو تجاهلها قبل الإغلاق.';

  @override
  String get nextcloudServerUnavailable =>
      'تعذّر الوصول إلى Nextcloud. لم تتغير العناصر المخزّنة مؤقتًا ولا الأعمال المعلّقة.';

  @override
  String get mapsShow => 'عرض على الخريطة';

  @override
  String get openLink => 'فتح الرابط';

  @override
  String get externalLocationOpenFailed => 'تعذّر فتح الموقع في تطبيق خارجي.';

  @override
  String scheduleProposedRange(String start, String end) {
    return '⁨$start⁩ – ⁨$end⁩';
  }

  @override
  String get scheduleRescheduleFailed =>
      'تعذّر تغيير موعد الحدث. لم يتغيّر وقته المحفوظ.';

  @override
  String get scheduleRescheduleStale =>
      'تغيّر هذا الحدث أثناء السحب. يُرجى المحاولة مجددًا.';

  @override
  String get scheduleRescheduleNotificationsFailed =>
      'تم حفظ الوقت الجديد، لكن تعذّر تحديث التذكيرات.';

  @override
  String get moveUp => 'نقل لأعلى';

  @override
  String get moveDown => 'نقل لأسفل';

  @override
  String get windowsSupport => 'الدعم';

  @override
  String get windowsThirdPartyLicenses => 'تراخيص الجهات الخارجية';

  @override
  String get windowsSearch => 'بحث';

  @override
  String get windowsStartupDisabledByUser =>
      'عطّل المستخدم هذه الميزة في إعدادات Windows.';

  @override
  String get windowsStartupDisabledByPolicy => 'معطّلة بواسطة نهج Windows.';

  @override
  String get windowsStartupUnavailable =>
      'تتوفر بعد تثبيت BusyMax من حزمة MSIX.';

  @override
  String get windowsReminderExitNotice =>
      'تتوقف التذكيرات عند إنهاء BusyMax بالكامل. أبقِه قيد التشغيل في الخلفية لتلقيها.';

  @override
  String get windowsProductVersionLabel => 'إصدار المنتج';

  @override
  String get windowsPackageVersionLabel => 'إصدار حزمة Windows';

  @override
  String get windowsUnpackaged => 'غير معبأ';

  @override
  String get windowsAgendaLoadMore => 'تحميل المزيد من عناصر جدول الأعمال';

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'الاثنين',
      'TU': 'الثلاثاء',
      'WE': 'الأربعاء',
      'TH': 'الخميس',
      'FR': 'الجمعة',
      'SA': 'السبت',
      'SU': 'الأحد',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return 'في يومي $first و$second من الشهر';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency في يومي $firstDay و$secondDay من $month';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency في اليوم $day من شهري $firstMonth و$secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency في يومي $firstDay و$secondDay من شهري $firstMonth و$secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency في الأيام $days من شهري $firstMonth و$secondMonth';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'اربط حسابات Google أو Microsoft أو تقويم Apple iCloud أو Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'في شاشة أذونات Google، حدّد أذونات التقويم والمهام معًا.';

  @override
  String get googlePermissionsRequiredRetry =>
      'أذونات تقويم Google وGoogle Tasks مطلوبة. حاول مرة أخرى وحدّد مربعي الاختيار.';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'هذه الخدمة غير مهيأة.';

  @override
  String get waitingForGoogleSignIn => 'في انتظار تسجيل الدخول إلى Google...';

  @override
  String get waitingForMicrosoftSignIn =>
      'في انتظار تسجيل الدخول إلى Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'تسجيل الدخول إلى Microsoft غير مهيأ. اضبط MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get windowMinimize => 'تصغير';

  @override
  String get windowMaximize => 'تكبير';

  @override
  String get windowRestore => 'استعادة';

  @override
  String get exit => 'خروج';

  @override
  String get options => 'خيارات';

  @override
  String get hide => 'إخفاء';

  @override
  String get show => 'إظهار';

  @override
  String get export => 'تصدير';

  @override
  String get save => 'حفظ';

  @override
  String get settings => 'الإعدادات';

  @override
  String get all => 'الكل';

  @override
  String get calendarEvents => 'الأحداث';

  @override
  String get calendarTasks => 'المهام';

  @override
  String get calendar => 'التقويم';

  @override
  String get calendars => 'التقويمات';

  @override
  String get newCalendar => 'تقويم جديد';

  @override
  String get calendarColor => 'لون التقويم';

  @override
  String calendarColorOption(int number) {
    return 'اللون $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'لا يدعم هذا المزوّد إدارة التقويمات في BusyMax.';

  @override
  String get primaryCalendarCannotDelete => 'لا يمكن حذف التقويم الأساسي.';

  @override
  String calendarCreateFailed(String error) {
    return 'تعذّر إنشاء التقويم: ⁨$error⁩';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'تم إنشاء التقويم، لكن تعذّر على BusyMax تحديث الحساب. سيظهر بعد المزامنة التالية.';

  @override
  String calendarUpdateFailed(String error) {
    return 'تعذّر تحديث التقويم: ⁨$error⁩';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'تعذّر حذف التقويم: ⁨$error⁩';
  }

  @override
  String get newEvent => 'حدث جديد';

  @override
  String get refreshCalendar => 'تحديث التقويم';

  @override
  String get openInProvider => 'فتح في الخدمة';

  @override
  String get linkedResources => 'الموارد المرتبطة';

  @override
  String get noLinkedResources => 'لا توجد موارد مرتبطة';

  @override
  String get attachments => 'المرفقات';

  @override
  String get attachmentsNotLoaded => 'لم يتم تحميل المرفقات';

  @override
  String get hideFromSchedule => 'إخفاء من الجدول';

  @override
  String get showInSchedule => 'إظهار في الجدول';

  @override
  String get noCalendarsSynced => 'لم تتم مزامنة أي تقويمات بعد.';

  @override
  String get allDay => 'طوال اليوم';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+⁨$countString⁩ عنصر آخر',
      many: '+⁨$countString⁩ عنصرًا آخر',
      few: '+⁨$countString⁩ عناصر أخرى',
      two: '+عنصران آخران',
      one: '+عنصر واحد آخر',
    );
    return '$_temp0';
  }

  @override
  String get noEventsOrTasks => 'لا توجد أحداث أو مهام';

  @override
  String get scheduleLoading => 'جارٍ تحميل الجدول...';

  @override
  String get scheduleUnavailable => 'الجدول غير متاح';

  @override
  String get scheduleNoSources => 'لا توجد تقويمات أو قوائم مهام ظاهرة';

  @override
  String get scheduleNoSourcesDescription =>
      'اختر ما تريد إظهاره في الإعدادات، ثم حدّث الجدول.';

  @override
  String get scheduleNoSearchResults => 'لا توجد أحداث أو مهام مطابقة';

  @override
  String get scheduleNoSearchResultsDescription =>
      'جرّب بحثًا مختلفًا أو امسح عوامل التصفية الحالية.';

  @override
  String get refresh => 'تحديث';

  @override
  String get trayOpenBusyMax => 'فتح BusyMax';

  @override
  String get trayShowBusyMax => 'إظهار BusyMax';

  @override
  String get trayNewEvent => 'حدث جديد…';

  @override
  String get trayNewTask => 'مهمة جديدة…';

  @override
  String get trayToday => 'اليوم';

  @override
  String get trayAllDay => 'طوال اليوم';

  @override
  String get trayNow => 'الآن';

  @override
  String get trayCalendarEvent => 'حدث في التقويم';

  @override
  String get trayUntitledEvent => 'حدث بلا عنوان';

  @override
  String get trayNothingElseToday => 'لا شيء آخر اليوم';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$count⁩ مهمة مستحقة اليوم',
      many: '⁨$count⁩ مهمة مستحقة اليوم',
      few: '⁨$count⁩ مهام مستحقة اليوم',
      two: 'مهمتان مستحقتان اليوم',
      one: 'مهمة واحدة مستحقة اليوم',
      zero: 'لا توجد مهام مستحقة اليوم',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'فتح جدول أعمال اليوم';

  @override
  String get traySyncNow => 'مزامنة الآن';

  @override
  String get traySyncing => 'جارٍ العمل على المزامنة…';

  @override
  String get trayNotConnected => 'غير متصل';

  @override
  String get trayNotYetSynced => 'لم تتم المزامنة بعد';

  @override
  String get trayLastSyncedJustNow => 'تمت المزامنة للتو';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت المزامنة قبل ⁨$count⁩ دقيقة',
      many: 'تمت المزامنة قبل ⁨$count⁩ دقيقة',
      few: 'تمت المزامنة قبل ⁨$count⁩ دقائق',
      two: 'تمت المزامنة قبل دقيقتين',
      one: 'تمت المزامنة قبل دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت المزامنة قبل ⁨$count⁩ ساعة',
      many: 'تمت المزامنة قبل ⁨$count⁩ ساعة',
      few: 'تمت المزامنة قبل ⁨$count⁩ ساعات',
      two: 'تمت المزامنة قبل ساعتين',
      one: 'تمت المزامنة قبل ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت المزامنة قبل ⁨$count⁩ يوم',
      many: 'تمت المزامنة قبل ⁨$count⁩ يومًا',
      few: 'تمت المزامنة قبل ⁨$count⁩ أيام',
      two: 'تمت المزامنة قبل يومين',
      one: 'تمت المزامنة قبل يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'الإعدادات';

  @override
  String get trayQuitBusyMax => 'إنهاء BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'تحميل المزيد من المهام المتأخرة';

  @override
  String get agendaLoadMoreNoDate => 'تحميل المزيد من المهام بلا تاريخ';

  @override
  String get viewDay => 'يوم';

  @override
  String get viewWeek => 'أسبوع';

  @override
  String get viewMonth => 'شهر';

  @override
  String get viewYear => 'سنة';

  @override
  String get viewAgenda => 'جدول الأعمال';

  @override
  String get scheduleSettings => 'الجدول';

  @override
  String get scheduleDisplaySettings => 'عرض الجدول';

  @override
  String get newEventsAndTasks => 'الأحداث والمهام الجديدة';

  @override
  String get defaultCalendar => 'التقويم الافتراضي';

  @override
  String get defaultTaskList => 'قائمة المهام الافتراضية';

  @override
  String get lastUsed => 'آخر استخدام';

  @override
  String get scheduleDisplayHoursDescription =>
      'تفتح طريقتا عرض اليوم والأسبوع ضمن هذه الساعات. توسّع العناصر المبكرة والمتأخرة النطاق عند الحاجة.';

  @override
  String get scheduleDayStartsAt => 'يبدأ اليوم في';

  @override
  String get scheduleDayEndsAt => 'ينتهي اليوم في';

  @override
  String get sourceCalendar => 'التقويم';

  @override
  String get sourceTaskList => 'قائمة المهام';

  @override
  String get createChoiceTitle => 'إنشاء';

  @override
  String get createEventAtTime => 'حدث';

  @override
  String get createTaskAtDate => 'مهمة';

  @override
  String get editEvent => 'تعديل الحدث';

  @override
  String get eventTitle => 'عنوان الحدث';

  @override
  String get location => 'الموقع';

  @override
  String get timeSlot => 'الفترة الزمنية';

  @override
  String get startDateTime => 'تاريخ/وقت البدء';

  @override
  String get endDateTime => 'تاريخ/وقت الانتهاء';

  @override
  String get doesNotRepeat => 'لا يتكرر';

  @override
  String get defaultReminder => 'التذكير الافتراضي';

  @override
  String get guests => 'المدعوون';

  @override
  String get noGuests => 'لا يوجد مدعوون';

  @override
  String get attendeeRequired => 'مطلوب';

  @override
  String get attendeeOptional => 'اختياري';

  @override
  String get meetingSection => 'الاجتماع';

  @override
  String get addGoogleMeet => 'إضافة Google Meet';

  @override
  String get addTeamsMeeting => 'إضافة اجتماع Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'تمت إضافة الاجتماع عبر الإنترنت';

  @override
  String get requestResponses => 'طلب الردود';

  @override
  String get requestResponsesDescription => 'اطلب من المدعوين الرد على الدعوة.';

  @override
  String get hideGuestList => 'إخفاء قائمة المدعوين';

  @override
  String get hideGuestListDescription =>
      'لا يمكن للمدعوين رؤية المدعوين الآخرين.';

  @override
  String get allowNewTimeProposals => 'السماح باقتراح أوقات جديدة';

  @override
  String get allowNewTimeProposalsDescription =>
      'يمكن للمدعوين اقتراح وقت مختلف للاجتماع.';

  @override
  String get notifyGuestsTitle => 'إبلاغ المدعوين؟';

  @override
  String get notifyGuestsSaveMessage =>
      'يضم هذا الاجتماع مدعوين. هل تريد إرسال الدعوات أو تحديثات الحدث عند حفظه؟';

  @override
  String get notifyGuestsDeleteMessage =>
      'يضم هذا الاجتماع مدعوين. هل تريد إرسال إلغاء عند حذفه؟';

  @override
  String get sendUpdates => 'إرسال التحديثات';

  @override
  String get sendCancellation => 'إرسال الإلغاء';

  @override
  String get doNotSend => 'عدم الإرسال';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'حفظ الاجتماع؟';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'سترسل Microsoft الدعوات أو تحديثات الحدث إلى المدعوين.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'حذف الاجتماع؟';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'سترسل Microsoft إلغاءً إلى المدعوين.';

  @override
  String get organizer => 'المنظّم';

  @override
  String get yourResponse => 'ردك';

  @override
  String get guestResponses => 'ردود المدعوين';

  @override
  String get respond => 'الرد';

  @override
  String get acceptInvitation => 'قبول';

  @override
  String get tentativeInvitation => 'مبدئي';

  @override
  String get declineInvitation => 'رفض';

  @override
  String get joinMeeting => 'الانضمام إلى الاجتماع';

  @override
  String get responseAccepted => 'مقبول';

  @override
  String get responseTentative => 'مبدئي';

  @override
  String get responseDeclined => 'مرفوض';

  @override
  String get responseNeedsAction => 'بانتظار الرد';

  @override
  String get responseNotResponded => 'لم يتم الرد';

  @override
  String get responseOrganizer => 'المنظّم';

  @override
  String invitationResponseFailed(String error) {
    return 'تعذّر إرسال ردك: ⁨$error⁩';
  }

  @override
  String get joinMeetingFailed => 'تعذّر فتح رابط الاجتماع.';

  @override
  String get description => 'الوصف';

  @override
  String get availabilityShowAs => 'التوفر / إظهار كـ';

  @override
  String get busy => 'مشغول';

  @override
  String get visibility => 'إمكانية العرض';

  @override
  String get defaultVisibility => 'إمكانية العرض الافتراضية';

  @override
  String get conference => 'اجتماع';

  @override
  String get noConference => 'لا يوجد اجتماع';

  @override
  String get providerCalendar => 'تقويم الخدمة';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => 'عريض';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'مائل';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'تحته خط';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'قبل ⁨$minutesString⁩ دقيقة',
      many: 'قبل ⁨$minutesString⁩ دقيقة',
      few: 'قبل ⁨$minutesString⁩ دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة واحدة',
      zero: 'عند البدء',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'عند البدء';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'قبل ⁨$hoursString⁩ ساعة',
      many: 'قبل ⁨$hoursString⁩ ساعة',
      few: 'قبل ⁨$hoursString⁩ ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة واحدة',
      zero: 'عند البدء',
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
      other: 'قبل ⁨$daysString⁩ يوم',
      many: 'قبل ⁨$daysString⁩ يومًا',
      few: 'قبل ⁨$daysString⁩ أيام',
      two: 'قبل يومين',
      one: 'قبل يوم واحد',
      zero: 'في اليوم نفسه',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'متاح';

  @override
  String get availabilityTentative => 'مبدئي';

  @override
  String get availabilityOutOfOffice => 'خارج المكتب';

  @override
  String get availabilityWorkingElsewhere => 'العمل من مكان آخر';

  @override
  String get visibilityDefault => 'افتراضي';

  @override
  String get visibilityPublic => 'عام';

  @override
  String get visibilityPrivate => 'خاص';

  @override
  String get visibilityConfidential => 'سري';

  @override
  String get sensitivityNormal => 'عادي';

  @override
  String get sensitivityPersonal => 'شخصي';

  @override
  String get tasks => 'المهام';

  @override
  String get allTasks => 'كل المهام';

  @override
  String tasksInList(String title) {
    return 'المهام في ⁨⁨$title⁩⁩';
  }

  @override
  String get taskLists => 'قوائم المهام';

  @override
  String get navigation => 'التنقل';

  @override
  String get mainMenu => 'القائمة الرئيسية';

  @override
  String get keyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get shortcutGroupGeneral => 'عام';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'إظهار مرجع الاختصارات هذا';

  @override
  String get shortcutGroupNavigation => 'التنقل';

  @override
  String get shortcutNextPeriod => 'الفترة التالية';

  @override
  String get shortcutNextPeriodDescription =>
      'الأسبوع التالي في عرض الأسبوع، والشهر التالي في عرض الشهر، وهكذا';

  @override
  String get shortcutPreviousPeriod => 'الفترة السابقة';

  @override
  String get shortcutPreviousPeriodDescription =>
      'الأسبوع السابق في عرض الأسبوع، والشهر السابق في عرض الشهر، وهكذا';

  @override
  String get shortcutJumpToToday => 'الانتقال إلى اليوم';

  @override
  String get shortcutGroupView => 'العرض';

  @override
  String get viewSelector => 'العرض';

  @override
  String get shortcutDayView => 'عرض اليوم';

  @override
  String get shortcutWeekView => 'عرض الأسبوع';

  @override
  String get shortcutMonthView => 'عرض الشهر';

  @override
  String get shortcutYearView => 'عرض السنة';

  @override
  String get shortcutAgendaView => 'عرض جدول الأعمال';

  @override
  String get shortcutGroupCreateAndEdit => 'الإنشاء والتعديل';

  @override
  String get shortcutSaveItem => 'حفظ الحدث أو المهمة';

  @override
  String get shortcutDeleteItem => 'حذف الحدث أو المهمة';

  @override
  String get shortcutGroupTaskEditing => 'تعديل المهام';

  @override
  String get shortcutCancelEditing => 'إلغاء التعديل';

  @override
  String get shortcutCancelEditingDescription =>
      'إغلاق تعديل المهمة أو تفاصيلها';

  @override
  String get aboutBusyMax => 'حول BusyMax';

  @override
  String get aboutBusyMaxDescription => 'التقويم والمهام';

  @override
  String get license => 'الترخيص';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get sourceCode => 'الشيفرة المصدرية';

  @override
  String get reportAnIssue => 'الإبلاغ عن مشكلة';

  @override
  String get sendFeedback => 'إرسال الملاحظات';

  @override
  String get feedbackSubmit => 'إرسال';

  @override
  String get feedbackCategory => 'الفئة';

  @override
  String get feedbackSelectCategory => 'اختر فئة';

  @override
  String get feedbackCategoryProblem => 'مشكلة أو خلل';

  @override
  String get feedbackCategoryFeature => 'طلب ميزة';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'مشكلة تتعلق بالخصوصية أو الأمان';

  @override
  String get feedbackCategoryUsability => 'مشكلة في سهولة الاستخدام';

  @override
  String get feedbackCategoryOther => 'أخرى';

  @override
  String get feedbackSubject => 'الموضوع';

  @override
  String get feedbackDetailedMessage => 'رسالة مفصّلة';

  @override
  String get feedbackReplyEmail => 'البريد الإلكتروني للرد (اختياري)';

  @override
  String get feedbackIncludeTechnicalDetails => 'تضمين التفاصيل التقنية';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'يضيف فقط اسم نظام التشغيل وإصداره ولغة التطبيق ومنطقته. لا يتم تضمين أي سجلات أو بيانات حسابات أو أسماء ملفات أو معلومات تشخيصية أخرى.';

  @override
  String get feedbackCategoryRequired => 'اختر فئة.';

  @override
  String get feedbackSubjectLengthError =>
      'يجب أن يتراوح الموضوع بين 3 و120 حرفًا.';

  @override
  String get feedbackMessageLengthError =>
      'يجب أن تتراوح الرسالة بين 10 و5,000 حرف.';

  @override
  String get feedbackInvalidEmail => 'أدخل عنوان بريد إلكتروني صالحًا.';

  @override
  String get feedbackConnectionError =>
      'تعذر الاتصال بـ BusyStack. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get feedbackTimeoutError =>
      'انتهت مهلة الطلب. لم تُمسح ملاحظاتك؛ حاول مرة أخرى.';

  @override
  String get feedbackRateLimitedError =>
      'أُرسلت ملاحظات كثيرة جدًا من هذه الشبكة. انتظر وحاول مرة أخرى.';

  @override
  String get feedbackRejectedError =>
      'رفض الخادم الإرسال. راجع الحقول وحاول مرة أخرى.';

  @override
  String get feedbackServerError =>
      'يتعذر على BusyStack قبول ملاحظاتك الآن. لم تُمسح ملاحظاتك؛ حاول مرة أخرى.';

  @override
  String feedbackSuccess(String id) {
    return 'تم إرسال الملاحظات. المرجع: ⁨⁨$id⁩⁩';
  }

  @override
  String get toggleSidebar => 'إظهار الشريط الجانبي أو إخفاؤه';

  @override
  String get showSidebar => 'إظهار اللوحة الجانبية';

  @override
  String get hideSidebar => 'إخفاء اللوحة الجانبية';

  @override
  String get accounts => 'الحسابات';

  @override
  String get currentAccount => 'الحساب الحالي';

  @override
  String get switchAccount => 'تبديل الحساب';

  @override
  String get addGoogleAccount => 'إضافة حساب Google';

  @override
  String get addMicrosoftAccount => 'إضافة حساب Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'تم تسجيل الدخول';

  @override
  String get removeAccount => 'إزالة الحساب…';

  @override
  String get removingAccount => 'جارٍ إزالة الحساب…';

  @override
  String get removeAccountDescription =>
      'إيقاف المزامنة وإزالة بيانات هذا الحساب من هذا الجهاز.';

  @override
  String removeAccountTitle(String account) {
    return 'إزالة ⁨⁨$account⁩⁩ من BusyMax؟';
  }

  @override
  String get removeAccountConfirmation =>
      'سيؤدي هذا إلى حذف المهام والتقويمات والأحداث والتذكيرات والتغييرات غير المتصلة المخزنة مؤقتًا من هذا الجهاز. ستُفقد التغييرات التي لم تتم مزامنتها، ولن تُحذف نسخ التقويمات والأحداث وقوائم المهام والمهام لدى موفّر الخدمة.';

  @override
  String get revokeGoogleAccess =>
      'إلغاء وصول BusyMax إلى حساب Google هذا أيضًا';

  @override
  String get revokeGoogleAccessDescription =>
      'ستحتاج إلى منح الوصول مرة أخرى قبل إعادة الاتصال.';

  @override
  String get removeAccountAction => 'إزالة الحساب';

  @override
  String get removeAccountFailed => 'تعذر إكمال إزالة الحساب. حاول مرة أخرى.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'تمت إزالة الحساب من هذا الجهاز، لكن تعذر على BusyMax إلغاء الوصول إلى Google. يمكنك إلغاء الوصول من حسابك على Google.';

  @override
  String get newTaskList => 'قائمة مهام جديدة';

  @override
  String taskListCreateFailed(String error) {
    return 'تعذّر إنشاء قائمة المهام: ⁨$error⁩';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'تعذّر إعادة تسمية قائمة المهام: ⁨$error⁩';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'تعذّر حذف قائمة المهام: ⁨$error⁩';
  }

  @override
  String get taskListPendingChangesPreventRemoval =>
      'زامِن الحساب، أو عالِج التغييرات المحظورة لقائمة المهام هذه في «التشخيصات»، قبل حذف القائمة أو إزالتها.';

  @override
  String get signInToViewTaskLists => 'سجّل الدخول لعرض قوائم المهام.';

  @override
  String get noTaskListsSynced => 'لم تتم مزامنة أي قوائم مهام بعد.';

  @override
  String get listActions => 'إجراءات القائمة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get delete => 'حذف';

  @override
  String get renameList => 'إعادة تسمية القائمة';

  @override
  String get deleteList => 'حذف القائمة';

  @override
  String get unshare => 'إلغاء المشاركة';

  @override
  String get readOnlyTaskListCannotRename =>
      'قائمة المهام هذه للقراءة فقط ولا يمكن إعادة تسميتها.';

  @override
  String get taskListCannotDelete =>
      'لا يمكن حذف قائمة المهام هذه باستخدام أذوناتك الحالية.';

  @override
  String get builtInMicrosoftList => 'مدمجة';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'لا يمكن إعادة تسمية قوائم Microsoft To Do المدمجة أو حذفها.';

  @override
  String deleteListConfirmation(String title) {
    return 'حذف \"⁨⁨$title⁩⁩\" من Google Tasks؟';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'حذف \"⁨$title⁩\" وجميع مهامها؟';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'إلغاء مشاركة \"⁨$title⁩\" من هذا الحساب؟';
  }

  @override
  String get deleteEvent => 'حذف الحدث';

  @override
  String get title => 'العنوان';

  @override
  String get create => 'إنشاء';

  @override
  String get newTask => 'مهمة جديدة';

  @override
  String get clearCompleted => 'مسح المهام المكتملة';

  @override
  String get refreshList => 'تحديث القائمة';

  @override
  String get refreshAll => 'تحديث الكل';

  @override
  String get listRefreshed => 'تم تحديث القائمة.';

  @override
  String get allTasksRefreshed => 'تم تحديث جميع الحسابات.';

  @override
  String exportedFile(String path) {
    return 'تم التصدير إلى ⁨⁨$path⁩⁩';
  }

  @override
  String exportFailed(String error) {
    return 'فشل التصدير: ⁨⁨$error⁩⁩';
  }

  @override
  String refreshFailed(String error) {
    return 'فشل التحديث: ⁨⁨$error⁩⁩';
  }

  @override
  String get selectOrCreateTaskList => 'اختر قائمة مهام أو أنشئ واحدة للبدء.';

  @override
  String get signInToViewTasks => 'سجّل الدخول لعرض المهام.';

  @override
  String get noTasks => 'لا توجد مهام.';

  @override
  String get noTasksYet => 'لا توجد مهام بعد';

  @override
  String get noTasksYetMessage => 'أنشئ مهمة أو حدّث حساباتك للبدء.';

  @override
  String get noTasksInList => 'لا توجد مهام في هذه القائمة.';

  @override
  String get overdue => 'متأخرة';

  @override
  String get today => 'اليوم';

  @override
  String get tomorrow => 'غدًا';

  @override
  String get upcoming => 'القادمة';

  @override
  String get noDate => 'بلا تاريخ';

  @override
  String get completed => 'مكتملة';

  @override
  String duePrefix(String date) {
    return 'مستحقة في ⁨⁨$date⁩⁩';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '⁨⁨$date⁩⁩ · ⁨⁨$time⁩⁩';
  }

  @override
  String get taskDetails => 'تفاصيل المهمة';

  @override
  String get editTask => 'تعديل المهمة';

  @override
  String get noTaskSelected => 'لم يتم تحديد مهمة.';

  @override
  String get noTaskSelectedHelper => 'حدّد مهمة لعرض تفاصيلها وتعديلها.';

  @override
  String get taskUnavailable => 'المهمة غير متاحة.';

  @override
  String get signInToEditTasks => 'سجّل الدخول لتعديل المهام.';

  @override
  String get refreshTask => 'تحديث المهمة';

  @override
  String get primarySection => 'أساسي';

  @override
  String get statusSection => 'الحالة';

  @override
  String get openStatus => 'مفتوحة';

  @override
  String get doneStatus => 'منجز';

  @override
  String get taskStatus => 'الحالة';

  @override
  String get taskStatusNone => 'بلا حالة';

  @override
  String get taskStatusNeedsAction => 'تحتاج إلى إجراء';

  @override
  String get taskStatusInProcess => 'قيد التنفيذ';

  @override
  String get taskStatusCompleted => 'مكتملة';

  @override
  String get taskStatusCancelled => 'ملغاة';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'اكتمل بنسبة $percentString٪';
  }

  @override
  String get completionDate => 'تاريخ الإكمال';

  @override
  String get priority => 'الأولوية';

  @override
  String get priorityNone => 'بلا أولوية';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'الأولوية $priorityString · عالية';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'الأولوية $priorityString · متوسطة';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'الأولوية $priorityString · منخفضة';
  }

  @override
  String get taskUrl => 'URL المهمة';

  @override
  String get invalidTaskUrl => 'أدخل عنوان URL مطلقًا يتضمن مخططه.';

  @override
  String get classification => 'التصنيف';

  @override
  String get classificationPublic => 'عند المشاركة، أظهر المهمة كاملة';

  @override
  String get classificationConfidential => 'عند المشاركة، أظهر الانشغال فقط';

  @override
  String get classificationPrivate => 'عند المشاركة، أخفِ هذه المهمة';

  @override
  String get pinTask => 'تثبيت المهمة';

  @override
  String get notes => 'ملاحظات';

  @override
  String get dueDate => 'تاريخ الاستحقاق';

  @override
  String get clearDueDate => 'مسح تاريخ الاستحقاق';

  @override
  String get dueTime => 'وقت الاستحقاق';

  @override
  String get startDate => 'تاريخ البدء';

  @override
  String get startTime => 'وقت البدء';

  @override
  String get endDate => 'تاريخ الانتهاء';

  @override
  String get endTime => 'وقت الانتهاء';

  @override
  String get reminderDate => 'تاريخ التذكير';

  @override
  String get reminderTime => 'وقت التذكير';

  @override
  String get reminder => 'تذكير';

  @override
  String get addReminder => 'إضافة تذكير';

  @override
  String get reminders => 'التذكيرات';

  @override
  String get noReminders => 'لا توجد تذكيرات';

  @override
  String get editReminder => 'تعديل التذكير';

  @override
  String get beforeTaskStarts => 'قبل بدء المهمة';

  @override
  String get beforeTaskDue => 'قبل موعد استحقاق المهمة';

  @override
  String get afterTaskStarts => 'بعد بدء المهمة';

  @override
  String get afterTaskDue => 'بعد استحقاق المهمة';

  @override
  String get relativeToTaskStart => 'بالنسبة إلى تاريخ بدء المهمة';

  @override
  String get relativeToTaskDue => 'بالنسبة إلى تاريخ استحقاق المهمة';

  @override
  String get reminderTimeOfDay => 'وقت اليوم';

  @override
  String get absoluteReminder => 'في تاريخ ووقت';

  @override
  String get reminderAmount => 'الكمية';

  @override
  String get reminderUnit => 'الوحدة';

  @override
  String get reminderUnitSeconds => 'ثوانٍ';

  @override
  String get reminderUnitMinutes => 'دقائق';

  @override
  String get reminderUnitHours => 'ساعات';

  @override
  String get reminderUnitDays => 'أيام';

  @override
  String get reminderUnitWeeks => 'أسابيع';

  @override
  String get reminderAtTaskStart => 'عند بدء المهمة';

  @override
  String get reminderAtTaskDue => 'عند وقت استحقاق المهمة';

  @override
  String get unsupportedReminder =>
      'يُحتفظ بنوع هذا التذكير، لكن لا يمكن تعديل وقته.';

  @override
  String get relatedRemindersTitle => 'الاحتفاظ بالتذكيرات المرتبطة؟';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'يحتوي هذا التاريخ على $countString من التذكيرات المرتبطة. هل تريد الاحتفاظ بها في تاريخها ووقتها الحاليين؟';
  }

  @override
  String get discardRelatedReminders => 'تجاهل التذكيرات';

  @override
  String get keepRelatedReminders => 'الاحتفاظ بالتذكيرات';

  @override
  String get addGuest => 'إضافة مدعو';

  @override
  String get addGuestEmail => 'إضافة بريد المدعو الإلكتروني';

  @override
  String get removeReminder => 'إزالة التذكير';

  @override
  String get off => 'إيقاف';

  @override
  String get repeat => 'التكرار';

  @override
  String get repeatNone => 'بلا تكرار';

  @override
  String get noneValue => 'لا شيء';

  @override
  String get repeatDaily => 'يوميًا';

  @override
  String get repeatWeekly => 'أسبوعيًا';

  @override
  String get repeatMonthly => 'شهريًا';

  @override
  String get repeatYearly => 'سنويًا';

  @override
  String get repeatEvery => 'الفاصل الزمني';

  @override
  String get repeatOn => 'التكرار في';

  @override
  String get repeatEnd => 'إنهاء التكرار';

  @override
  String get repeatNever => 'مطلقًا';

  @override
  String get repeatUntil => 'في تاريخ';

  @override
  String get repeatAfter => 'بعد عدد من التكرارات';

  @override
  String get repeatCount => 'عدد التكرارات';

  @override
  String get repeatDayOfMonth => 'أيام الشهر';

  @override
  String get repeatMonths => 'الأشهر';

  @override
  String get repeatOrdinal => 'ترتيب يوم الأسبوع';

  @override
  String get repeatSpecificDays => 'أيام محددة';

  @override
  String get repeatFirst => 'الأول';

  @override
  String get repeatSecond => 'الثاني';

  @override
  String get repeatThird => 'الثالث';

  @override
  String get repeatFourth => 'الرابع';

  @override
  String get repeatFifth => 'الخامس';

  @override
  String get repeatSecondToLast => 'ما قبل الأخير';

  @override
  String get repeatLast => 'الأخير';

  @override
  String get repeatAnyDay => 'اليوم';

  @override
  String get repeatWeekday => 'يوم من أيام الأسبوع';

  @override
  String get repeatWeekendDay => 'يوم عطلة نهاية الأسبوع';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'اثنين',
      'TU': 'ثلاثاء',
      'WE': 'أربعاء',
      'TH': 'خميس',
      'FR': 'جمعة',
      'SA': 'سبت',
      'SU': 'أحد',
      'day': 'يوم',
      'weekday': 'يوم من أيام الأسبوع',
      'weekend': 'يوم من عطلة نهاية الأسبوع',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $countString يوم',
      many: 'كل $countString يومًا',
      few: 'كل $countString أيام',
      two: 'كل يومين',
      one: 'كل يوم',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $countString أسبوع',
      many: 'كل $countString أسبوعًا',
      few: 'كل $countString أسابيع',
      two: 'كل أسبوعين',
      one: 'كل أسبوع',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $countString شهر',
      many: 'كل $countString شهرًا',
      few: 'كل $countString أشهر',
      two: 'كل شهرين',
      one: 'كل شهر',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $countString سنة',
      many: 'كل $countString سنة',
      few: 'كل $countString سنوات',
      two: 'كل سنتين',
      one: 'كل سنة',
    );
    return '$_temp0';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'في $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'في اليوم $days من الشهر';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'في أول $days',
      'second': 'في ثاني $days',
      'third': 'في ثالث $days',
      'fourth': 'في رابع $days',
      'fifth': 'في خامس $days',
      'secondToLast': 'في $days قبل الأخير',
      'last': 'في آخر $days',
      'other': 'في $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'في $months';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString مرة',
      many: '$countString مرة',
      few: '$countString مرات',
      two: 'مرتين',
      one: 'مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'حتى ⁨$date⁩';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'تستخدم قاعدة التكرار هذه خيارات لا يغيّرها هذا المحرر.';

  @override
  String get taskRecurrenceDestinationUnsupported =>
      'لا يمكن استخدام نمط التكرار هذا في هذه القائمة. غيّر النمط أو اختر قائمة أخرى.';

  @override
  String get taskRecurrenceRequiresDate =>
      'أضف تاريخ بدء أو استحقاق لاستخدام نمط التكرار هذا، أو أوقف التكرار.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'لا يمكن استخدام هذا التكرار مع ⁨$provider⁩.';
  }

  @override
  String get importance => 'الأهمية';

  @override
  String get importanceLow => 'منخفضة';

  @override
  String get importanceNormal => 'عادية';

  @override
  String get importanceHigh => 'مرتفعة';

  @override
  String get categories => 'الفئات';

  @override
  String get scheduleSection => 'الجدول';

  @override
  String get dueGroup => 'الاستحقاق';

  @override
  String get startGroup => 'البدء';

  @override
  String get reminderGroup => 'التذكير';

  @override
  String get organizationSection => 'التنظيم';

  @override
  String get actionsSection => 'الإجراءات';

  @override
  String get advancedSection => 'متقدم';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get list => 'القائمة';

  @override
  String get microsoftMoveUnsupported =>
      'نقل المهام بين القوائم غير مدعوم لحسابات Microsoft To Do في هذا الإصدار.';

  @override
  String get createSubtask => 'إنشاء مهمة فرعية';

  @override
  String get subtasks => 'مهام فرعية';

  @override
  String get duplicateTask => 'تكرار المهمة';

  @override
  String get taskDuplicated => 'تم تكرار المهمة.';

  @override
  String taskDuplicateFailed(String error) {
    return 'تعذّر تكرار المهمة: ⁨$error⁩';
  }

  @override
  String get hideSubtasks => 'إخفاء المهام الفرعية';

  @override
  String get hideClosedSubtasks => 'إخفاء المهام الفرعية المغلقة';

  @override
  String get moveToTop => 'نقل إلى الأعلى';

  @override
  String get deleteTask => 'حذف المهمة';

  @override
  String get newSubtask => 'مهمة فرعية جديدة';

  @override
  String deleteTaskConfirmation(String title) {
    return 'حذف «⁨⁨$title⁩⁩»؟';
  }

  @override
  String get deleteAssignedTaskWarning =>
      'سيؤدي هذا أيضًا إلى حذف المهمة الأصلية في مستندات Google أو مساحات Chat.';

  @override
  String get metadata => 'البيانات الوصفية';

  @override
  String get id => 'المعرّف';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'آخر تحديث';

  @override
  String get parent => 'المهمة الأصلية';

  @override
  String get position => 'الموضع';

  @override
  String get webLink => 'رابط الويب';

  @override
  String get assignment => 'التعيين';

  @override
  String get localState => 'الحالة المحلية';

  @override
  String get pendingSync => 'في انتظار المزامنة';

  @override
  String get synced => 'تمت المزامنة';

  @override
  String get account => 'الحساب';

  @override
  String get sync => 'المزامنة';

  @override
  String get forceFullResync => 'فرض إعادة مزامنة كاملة';

  @override
  String get forceFullResyncDescription =>
      'إعادة تحميل جميع البيانات بالكامل من كل حساب متصل. استخدم هذا الخيار فقط لاستكشاف مشكلات المزامنة وإصلاحها.';

  @override
  String get runInBackgroundWhenClosed => 'متابعة التشغيل عند إغلاق النافذة';

  @override
  String get showTrayIcon => 'إظهار أيقونة شريط النظام';

  @override
  String get startMinimizedToTray => 'البدء مصغّرًا في شريط النظام';

  @override
  String get launchAtLogin => 'التشغيل عند تسجيل الدخول';

  @override
  String get launchAtLoginDescription =>
      'تشغيل BusyMax في الخلفية لتعمل التذكيرات بعد تسجيل الدخول.';

  @override
  String get launchAtLoginFailed =>
      'تعذر تحديث إعداد التشغيل عند تسجيل الدخول.';

  @override
  String get requiresTrayIcon => 'يتطلب أيقونة شريط النظام.';

  @override
  String get syncComplete => 'اكتملت المزامنة.';

  @override
  String syncFailed(String error) {
    return 'فشلت المزامنة: ⁨⁨$error⁩⁩';
  }

  @override
  String get notifySyncFailures => 'إشعارات عند فشل المزامنة';

  @override
  String get notifyConflicts => 'إشعارات عند حدوث تعارضات';

  @override
  String get notifyDueToday => 'إشعارات المهام المستحقة اليوم';

  @override
  String get eventReminders => 'تذكيرات الأحداث';

  @override
  String get onState => 'تشغيل';

  @override
  String get taskReminders => 'تذكيرات المهام';

  @override
  String get notificationDetailLevel => 'مستوى تفاصيل الإشعارات';

  @override
  String get notificationDetailPrivate => 'خاص';

  @override
  String get notificationDetailNormal => 'عادي';

  @override
  String get quietHours => 'ساعات الهدوء';

  @override
  String get quietHoursDescription => 'إيقاف الإشعارات مؤقتًا خلال هذه الفترة.';

  @override
  String get quietHoursStart => 'بداية ساعات الهدوء';

  @override
  String get quietHoursEnd => 'نهاية ساعات الهدوء';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get windowsNotificationsUnavailable => 'إشعارات Windows غير متاحة';

  @override
  String get windowsNotificationsUnpackaged =>
      'لا يمكن لتشغيل التطوير غير المحزّم هذا استخدام إشعارات Windows. ثبّت حزمة MSIX الموقّعة للاختبار لاختبار التذكيرات.';

  @override
  String get windowsNotificationsInstalledFailure =>
      'تعذّر على BusyMax تهيئة إشعارات Windows. لن تظهر التذكيرات حتى تُحل مشكلة التثبيت هذه.';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get settingsSystem => 'النظام';

  @override
  String get themeLight => 'فاتحة';

  @override
  String get themeDark => 'داكنة';

  @override
  String get themeFamily => 'عائلة السمات';

  @override
  String get themeFamilyYaru => 'سمة Ubuntu الأصلية (Yaru)';

  @override
  String get localization => 'اللغة والمنطقة';

  @override
  String get currentLocale => 'اللغة والمنطقة الحالية';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get redactTaskContentInDiagnostics =>
      'إخفاء محتوى المهام في معلومات التشخيص';

  @override
  String get developerDiagnostics => 'تشخيصات المطور';

  @override
  String get diagnostics => 'التشخيصات';

  @override
  String get apiInspectorDisabled => 'إظهار فاحص API';

  @override
  String get googleTasksApi => 'واجهة Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'مراجعة Discovery: ⁨⁨$revision⁩⁩';
  }

  @override
  String get implementedMethods => 'الطرق المنفذة';

  @override
  String get supportsTasksScopes => 'يدعم نطاقَي tasks وtasks.readonly';

  @override
  String get requiresTasksScope => 'يتطلب نطاق tasks';

  @override
  String get blockedPendingOperations => 'العمليات المعلّقة المحظورة';

  @override
  String get signInToInspectPendingOperations =>
      'سجّل الدخول لفحص العمليات المعلّقة.';

  @override
  String get noBlockedPendingOperations => 'لا توجد عمليات معلّقة محظورة.';

  @override
  String get operationActions => 'إجراءات العملية';

  @override
  String pendingOpListId(String id) {
    return 'القائمة=⁨⁨$id⁩⁩';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'المهمة=⁨⁨$id⁩⁩';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'المحاولات=⁨$countString⁩';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get discard => 'تجاهل';

  @override
  String get discardChangesAction => 'تجاهل التغييرات';

  @override
  String get discardChanges => 'تجاهل التغييرات؟';

  @override
  String get discardChangesConfirmation =>
      'سيؤدي ذلك إلى تجاهل التعديلات غير المحفوظة على هذه المهمة.';

  @override
  String get retryCompleted => 'اكتملت إعادة المحاولة.';

  @override
  String get discardPendingOperation => 'تجاهل العملية المعلّقة؟';

  @override
  String get discardPendingOperationConfirmation =>
      'سيؤدي ذلك إلى إزالة العملية المحلية المحظورة. ستُحدّث البيانات من Google Tasks في المزامنة التالية.';

  @override
  String get pendingOperationDiscarded => 'تم تجاهل العملية المعلّقة.';

  @override
  String get syncFailureNotificationTitle => 'فشلت مزامنة BusyMax';

  @override
  String syncFailureNotificationBody(String message) {
    return 'فشلت المزامنة في الخلفية. ⁨⁨$message⁩⁩';
  }

  @override
  String get conflictNotificationTitle => 'تعارض في مزامنة BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'تم حظر تغيير محلي معلق. ⁨⁨$summary⁩⁩';
  }

  @override
  String get dueTodayNotificationTitle => 'المهام المستحقة اليوم';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هناك ⁨$countString⁩ مهمة مستحقة اليوم.',
      many: 'هناك ⁨$countString⁩ مهمة مستحقة اليوم.',
      few: 'هناك ⁨$countString⁩ مهام مستحقة اليوم.',
      two: 'هناك مهمتان مستحقتان اليوم.',
      one: 'هناك مهمة واحدة مستحقة اليوم.',
      zero: 'لا توجد مهام مستحقة اليوم.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'تذكير بحدث';

  @override
  String get taskReminderNotificationTitle => 'تذكير بمهمة';

  @override
  String get eventReminderNotificationBody => 'سيبدأ الحدث قريبًا.';

  @override
  String get taskReminderNotificationBody => 'ستحلّ مهلة المهمة قريبًا.';

  @override
  String get notificationOpenAction => 'فتح';

  @override
  String get notificationSnoozeAction => 'غفوة لمدة 10 دقائق';

  @override
  String get notificationDismissAction => 'إغلاق';

  @override
  String get notificationDetailsHidden =>
      'التفاصيل مخفية وفقًا لإعدادات الخصوصية.';

  @override
  String get previousMonth => 'الشهر السابق';

  @override
  String get nextMonth => 'الشهر التالي';

  @override
  String get openMonthView => 'فتح عرض الشهر';

  @override
  String get previousYear => 'السنة السابقة';

  @override
  String get nextYear => 'السنة التالية';

  @override
  String get openYearView => 'فتح عرض السنة';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'الأسبوع ⁨$numberString⁩';
  }

  @override
  String get resizeAllDayPanel => 'تغيير حجم لوحة اليوم الكامل';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '⁨$countString⁩ عنصر',
      many: '⁨$countString⁩ عنصرًا',
      few: '⁨$countString⁩ عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'هذا التقويم للقراءة فقط.';

  @override
  String get selectTimeZone => 'اختيار المنطقة الزمنية';

  @override
  String get searchLocations => 'البحث عن المواقع';

  @override
  String get noLocationsFound => 'لم يتم العثور على مواقع';

  @override
  String get requiredField => 'هذا الحقل مطلوب.';

  @override
  String get providerConnectionDescription =>
      'اربط التقويمات والمهام من أحد موفّري الخدمة هؤلاء.';

  @override
  String get appleICloudProvider => 'تقويم Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'مهام Nextcloud';

  @override
  String get addAppleICloudAccount => 'إضافة حساب تقويم Apple iCloud';

  @override
  String get addNextcloudAccount => 'إضافة حساب Nextcloud';

  @override
  String get waitingForAppleICloud => 'جارٍ الاتصال بـ Apple iCloud…';

  @override
  String get waitingForNextcloud => 'بانتظار تفويض Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'ربط تقويم Apple iCloud';

  @override
  String get appleAccountEmail => 'البريد الإلكتروني لحساب Apple';

  @override
  String get appleAppSpecificPassword => 'كلمة مرور خاصة بالتطبيق';

  @override
  String get appleAppSpecificPasswordHelp =>
      'أنشئ كلمة مرور خاصة بالتطبيق بعد تفعيل المصادقة الثنائية لحساب Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'تؤدي إعادة تعيين كلمة مرور حساب Apple إلى إبطال كلمات المرور الخاصة بالتطبيقات.';

  @override
  String get connectNextcloudTitle => 'ربط Nextcloud';

  @override
  String get nextcloudServerUrl => 'خادم Nextcloud أو عنوان CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'أدخل عنوان URL لخادم Nextcloud أو الصق عنوان CalDAV الأساسي المنسوخ من Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'سيفتح BusyMax متصفحك. وافق على الوصول هناك، ثم عد إلى BusyMax.';

  @override
  String get connectAccountAction => 'ربط';

  @override
  String get cancelAccountConnection => 'إلغاء الربط';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'تمت إزالة الحساب محليًا، لكن تعذّر إبطال كلمة مرور تطبيق Nextcloud.';

  @override
  String get davReauthenticationRequired =>
      'أعد ربط هذا الحساب لاستئناف المزامنة.';

  @override
  String get davTemporarilyUnavailable => 'هذا الحساب غير متاح مؤقتًا.';

  @override
  String get davPermissionChanged =>
      'تغيّرت أذونات الخادم. تم إيقاف التعديلات المعلقة مؤقتًا.';

  @override
  String get davUnsupportedServer =>
      'هذا الخادم أو ملف موفّر الخدمة غير مدعوم.';

  @override
  String get collectionSettings => 'التقويمات وقوائم المهام';

  @override
  String get calendarContent => 'أحداث التقويم';

  @override
  String get taskContent => 'المهام';

  @override
  String get readOnlySharedCollection => 'للقراءة فقط';

  @override
  String get pendingLocally => 'معلق محليًا';

  @override
  String get conflictBlocked => 'محظور بسبب تعارض';

  @override
  String get authenticationBlocked => 'محظور حتى إعادة الاتصال';

  @override
  String get operationFailed => 'فشلت العملية';

  @override
  String get keepServerVersion => 'الاحتفاظ بإصدار الخادم';

  @override
  String get reapplyLocalChange => 'مراجعة التغيير المحلي وإعادة تطبيقه';

  @override
  String get duplicateLocalItem => 'تكرار كعنصر جديد';

  @override
  String get davConnectionState => 'حالة الاتصال';

  @override
  String get davConnected => 'متصل';

  @override
  String get davConnecting => 'جارٍ الاتصال…';

  @override
  String get davSignedOut => 'تم تسجيل الخروج';

  @override
  String davLastSuccessfulSync(String time) {
    return 'آخر مزامنة ناجحة: ⁨$time⁩';
  }

  @override
  String get davNeverSynced => 'لم تتم المزامنة بعد';

  @override
  String get refreshCollections => 'تحديث التقويمات وقوائم المهام';

  @override
  String nextcloudServerHost(String host) {
    return 'الخادم: ⁨$host⁩';
  }

  @override
  String get collectionSupportsEvents => 'تقويم أحداث';

  @override
  String get collectionSupportsTasks => 'قائمة مهام';

  @override
  String get collectionSupportsEventsAndTasks => 'الأحداث والمهام';

  @override
  String get writableCollection => 'قابل للكتابة';

  @override
  String get sharedCollection => 'مشترك';

  @override
  String collectionLastSynced(String time) {
    return 'آخر مزامنة: ⁨$time⁩';
  }

  @override
  String collectionSyncError(String code) {
    return 'مشكلة في المزامنة: ⁨$code⁩';
  }

  @override
  String get syncConflicts => 'تعارضات المزامنة';

  @override
  String remoteChangedAt(String time) {
    return 'تم التغيير على الخادم في: ⁨⁨$time⁩⁩';
  }

  @override
  String localPendingEdit(String summary) {
    return 'تعديل محلي: ⁨$summary⁩';
  }

  @override
  String get conflictResolutionFailed => 'تعذّر حل التعارض.';

  @override
  String get recurringEventScope => 'نطاق الحدث المتكرر';

  @override
  String get entireSeries => 'السلسلة بأكملها';

  @override
  String get singleOccurrence => 'هذا الحدث';

  @override
  String get thisAndFollowingEvents => 'هذا الحدث والأحداث التالية';

  @override
  String get thisAndFutureUnavailable => 'غير مدعوم من موفّر الخدمة هذا.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'لا يمكن نقل هذا الحدث والأحداث التالية بأمان. اختر هذا الحدث أو السلسلة كاملة.';

  @override
  String get entireSeriesMoveUnavailable =>
      'قاعدة التكرار غير متوفرة محليًا. انقل هذا الحدث بدلاً من ذلك.';

  @override
  String get copyEventAndDeleteOriginal => 'هل تريد نسخ الحدث وحذف الأصل؟';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'لا يستطيع BusyMax نقل هذا الحدث مباشرةً من ⁨$source⁩ إلى ⁨$destination⁩. سينشئ النسخة أولاً ولن يحذف الأصل إلا بعد نجاح النسخ. ستتغير معرّفات الحدث؛ وقد تُعاد تعيين حالات استجابة الحاضرين وتُرسل دعوات أو إلغاءات؛ وقد لا تُنقل روابط الاجتماعات والمرفقات والتذكيرات والحقول الخاصة بموفّر الخدمة واستثناءات التكرار.';
  }

  @override
  String get copyAndDelete => 'نسخ وحذف';

  @override
  String get chooseRecurringEventScope =>
      'اختر ما إذا كان هذا التغيير ينطبق على السلسلة بأكملها، أو هذا الحدث فقط، أو هذا الحدث والأحداث التالية.';

  @override
  String get taskDueBeforeStart => 'يجب ألا يكون موعد الاستحقاق قبل وقت البدء.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'عيّن وقتًا لكل من البدء والاستحقاق، أو اجعل المهمة طوال اليوم.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'حذف «⁨⁨$title⁩⁩»؟';
  }

  @override
  String get setCustomCalendarName => 'تعيين اسم مخصص';

  @override
  String get setAction => 'تعيين';

  @override
  String get removeFromMyCalendars => 'إزالة من تقاويمي';

  @override
  String get removeAction => 'إزالة';

  @override
  String removeOpenedSharedCalendarConfirmation(String title) {
    return 'هل تريد إزالة \"⁨$title⁩\" من BusyMax؟ لن يُحذف تقويم المالك أو أحداثه.';
  }

  @override
  String get attachmentUploadUnresolved =>
      'ربما اكتمل رفع المرفق. حدّث المرفقات للتحقق من النتيجة قبل الرفع مرة أخرى.';

  @override
  String removeCalendarConfirmation(String title) {
    return 'هل تريد إزالة \"⁨$title⁩\" من قائمة تقويم Google؟ لن يتم حذف التقويم المشترك أو أحداثه.';
  }

  @override
  String get calendarCannotRemove =>
      'لا يمكن حذف هذا التقويم أو إزالته من هذا الحساب.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'انتظر حتى تنتهي مزامنة التغييرات المعلقة لهذا التقويم قبل حذفه أو إزالته.';

  @override
  String get calendarSubscriptions => 'اشتراكات التقويم';

  @override
  String get calendarSubscriptionsDescription =>
      'أضف تقاويم للقراءة فقط يتم تحديثها من عنوان WebCal آمن.';

  @override
  String get addCalendarSubscription => 'إضافة اشتراك تقويم';

  @override
  String get subscriptionName => 'الاسم المحلي';

  @override
  String get subscriptionUrl => 'عنوان URL للاشتراك';

  @override
  String get subscriptionUrlHelp =>
      'أدخل عنوان HTTPS أو webcal. يحتفظ BusyMax بعنوان URL الكامل في التخزين الآمن.';

  @override
  String get subscriptionUrlInvalid =>
      'أدخل عنوان HTTPS أو webcal صالحًا من دون معلومات مستخدم أو جزء.';

  @override
  String get subscriptionColor => 'اللون المحلي';

  @override
  String get subscriptionColorHelp => 'استخدم لونًا من ستة أرقام مثل #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'أدخل لونًا سداسيًا عشريًا من ستة أرقام.';

  @override
  String get subscriptionRefreshMode => 'تكرار التحديث';

  @override
  String get subscriptionAutomatic => 'تلقائي';

  @override
  String get subscriptionHourly => 'كل ساعة';

  @override
  String get subscriptionSixHours => 'كل ست ساعات';

  @override
  String get subscriptionDaily => 'يوميًا';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'المصدر: ⁨$origin⁩';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'أدخل عنوان URL صالحًا لمعاينة مصدره الآمن.';

  @override
  String get subscriptionReadOnly => 'اشتراك للقراءة فقط';

  @override
  String get subscriptionNeverRefreshed => 'لم يتم التحديث بعد';

  @override
  String subscriptionLastRefresh(String time) {
    return 'آخر تحديث ناجح: ⁨$time⁩';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'التحديث التالي: ⁨$time⁩';
  }

  @override
  String get subscriptionStatusHealthy => 'محدّث';

  @override
  String subscriptionStatusIssue(String code) {
    return 'مشكلة في التحديث: ⁨$code⁩';
  }

  @override
  String get refreshNow => 'تحديث الآن';

  @override
  String get unsubscribe => 'إلغاء الاشتراك';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'إلغاء الاشتراك من «⁨$name⁩»؟';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'يؤدي هذا إلى إزالة الاشتراك المحلي والأحداث المخزنة مؤقتًا. لن يتغير التقويم المنشور.';

  @override
  String get addSubscriptionAction => 'إضافة اشتراك';

  @override
  String subscriptionOperationFailed(String error) {
    return 'فشل اشتراك التقويم: ⁨$error⁩';
  }

  @override
  String get subscriptions => 'الاشتراكات';

  @override
  String get calendarImport => 'استيراد التقويم';

  @override
  String get calendarImportDescription =>
      'حدد ملفًا، وراجع أحداثه، ثم اختر التقويم القابل للكتابة الذي ينبغي أن يستقبلها.';

  @override
  String get importIcsFile => 'استيراد ملف ‎.ics';

  @override
  String get importIcsPreview => 'استيراد أحداث التقويم';

  @override
  String importEventsFound(int count) {
    return 'مجموعات أحداث قابلة للاستيراد: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'أحداث غير صالحة: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'تم الاستبعاد عمدًا: ⁨$fields⁩';
  }

  @override
  String get noWritableCalendars => 'لا يوجد تقويم وجهة قابل للكتابة.';

  @override
  String get importDestinationCalendar => 'تقويم الوجهة';

  @override
  String get importIcsConfirm => 'استيراد الأحداث';

  @override
  String get importIcsComplete => 'اكتمل الاستيراد';

  @override
  String importQueued(int count) {
    return 'تم الاستيراد أو وضعه في قائمة الانتظار: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'تم تخطي التكرارات: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'مجموعات تكرار غير مدعومة: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'تعذّر استيراد ملف التقويم: ⁨$error⁩';
  }

  @override
  String get networkOffline => 'غير متصل';

  @override
  String get networkOfflineDescription =>
      'ستتم مزامنة التغييرات عند استعادة الاتصال.';

  @override
  String get networkOfflineTryAgain =>
      'أنت غير متصل. اتصل بالإنترنت وحاول مرة أخرى.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'في الأيام $days من الشهر';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first، $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String repeatMonthDayListStart(String first, String rest) {
    return '$first، $rest';
  }

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first، $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first و$second';
  }

  @override
  String repeatYearlyMonthListStart(String first, String rest) {
    return '$first، $rest';
  }

  @override
  String repeatYearlyOnMonthDaySummary(
    String frequency,
    String month,
    String day,
  ) {
    return '$frequency في يوم $day من $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency في الأيام $days من $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency في يوم $day من أشهر $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency في الأيام $days من أشهر $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'في أول $days من $month',
      'second': 'في ثاني $days من $month',
      'third': 'في ثالث $days من $month',
      'fourth': 'في رابع $days من $month',
      'fifth': 'في خامس $days من $month',
      'secondToLast': 'في $days قبل الأخير من $month',
      'last': 'في آخر $days من $month',
      'other': 'في $days من $month',
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
      'first': 'في أول $days من أشهر $months',
      'second': 'في ثاني $days من أشهر $months',
      'third': 'في ثالث $days من أشهر $months',
      'fourth': 'في رابع $days من أشهر $months',
      'fifth': 'في خامس $days من أشهر $months',
      'secondToLast': 'في $days قبل الأخير من أشهر $months',
      'last': 'في آخر $days من أشهر $months',
      'other': 'في $days من أشهر $months',
    });
    return '$frequency $_temp0';
  }

  @override
  String get searchFilters => 'عوامل تصفية البحث';

  @override
  String get searchType => 'النوع';

  @override
  String get searchDate => 'التاريخ';

  @override
  String get searchAnyDate => 'أي تاريخ (البيانات المحمّلة)';

  @override
  String get eventLink => 'رابط الحدث';

  @override
  String get eventLinkOpenFailed => 'تعذّر فتح الرابط.';

  @override
  String get scheduleRangeIncomplete =>
      'تعذّر التحقق من بعض الأحداث. تُعرض البيانات المحمّلة.';

  @override
  String get searchThisWeek => 'هذا الأسبوع';

  @override
  String get searchCustomRange => 'نطاق مخصص';

  @override
  String get searchTaskStatus => 'حالة المهمة';

  @override
  String get searchTaskDue => 'استحقاق المهمة';

  @override
  String get searchAnyDueState => 'أي حالة استحقاق';

  @override
  String get searchNoDueDate => 'بلا تاريخ استحقاق';

  @override
  String get searchPerson => 'الشخص';

  @override
  String get searchSources => 'المصادر';

  @override
  String get searchClearFilters => 'إعادة ضبط عوامل التصفية';

  @override
  String get searchFiltersAction => 'عوامل التصفية';

  @override
  String get searchNoSources => 'لم يتم تحديد مصادر للبحث';

  @override
  String get searchClearText => 'مسح النص';

  @override
  String get openSharedCalendar => 'فتح تقويم مشترك';

  @override
  String get manageCalendarSharing => 'إدارة مشاركة التقويم';

  @override
  String get shareRecipientEmail => 'البريد الإلكتروني للمستلم';

  @override
  String get shareRole => 'دور الوصول';

  @override
  String get addCalendarShare => 'إضافة وصول';

  @override
  String get sharingRefreshFailed =>
      'نجح تغيير المشاركة، لكن تعذر تحديث قائمة الأذونات. أعد تحميل القائمة قبل إجراء تغيير آخر.';

  @override
  String get sharingRateLimited =>
      'المشاركة مقيّدة مؤقتًا. حاول مرة أخرى بعد انتهاء فترة الانتظار.';

  @override
  String get attachmentUploadRateLimited =>
      'تحميل المرفقات مقيّد مؤقتًا. حاول مرة أخرى بعد انتهاء فترة الانتظار.';

  @override
  String get sharingPermissionUnavailable =>
      'أذونات المشاركة غير متاحة لهذا التقويم.';

  @override
  String get calendarShareFreeBusy => 'التوفر فقط';

  @override
  String get calendarShareLimitedRead => 'قراءة تفاصيل محدودة';

  @override
  String get calendarShareRead => 'قراءة جميع التفاصيل';

  @override
  String get calendarShareWrite => 'تعديل الأحداث';

  @override
  String get calendarShareWriteWithoutPrivate => 'تعديل دون التفاصيل الخاصة';

  @override
  String get calendarShareOwner => 'المالك';

  @override
  String get eventLabel => 'تسمية الحدث';

  @override
  String get loadOutlookCategories => 'تحميل فئات Outlook';

  @override
  String get outlookCategoriesUnavailable =>
      'فئات Outlook غير متاحة؛ التعيينات الحالية محفوظة.';

  @override
  String get googleEventType => 'نوع الحدث';

  @override
  String get googleRegularEvent => 'حدث عادي';

  @override
  String get googleFocusTime => 'وقت التركيز';

  @override
  String get googleOutOfOffice => 'خارج المكتب';

  @override
  String get googleWorkingLocation => 'موقع العمل';

  @override
  String get googleDeclineInvitations => 'رفض الدعوات المتداخلة';

  @override
  String get googleDeclineNone => 'عدم الرفض';

  @override
  String get googleDeclineNew => 'رفض الدعوات الجديدة';

  @override
  String get googleDeclineAll => 'رفض جميع الدعوات المتعارضة';

  @override
  String get googleDeclineMessage => 'رسالة الرفض';

  @override
  String get googleChatStatus => 'حالة المحادثة';

  @override
  String get googleChatAvailable => 'متاح';

  @override
  String get googleChatDoNotDisturb => 'عدم الإزعاج';

  @override
  String get googleWorkAtHome => 'المنزل';

  @override
  String get googleWorkAtOffice => 'المكتب';

  @override
  String get googleWorkAtCustomLocation => 'موقع مخصص';

  @override
  String get googleWorkLocationLabel => 'وصف الموقع';

  @override
  String get googleStatusPrimaryOnly =>
      'تتطلب أحداث الحالة تقويم Google الأساسي.';

  @override
  String unknownEventLabel(String id) {
    return 'تسمية غير معروفة (⁨$id⁩)';
  }

  @override
  String get calendarOwnerEmail => 'البريد الإلكتروني لمالك التقويم';

  @override
  String registrationSetupTitle(String provider) {
    return 'إعداد ⁨$provider⁩';
  }

  @override
  String get registrationSetupGuide => 'دليل الإعداد';

  @override
  String get registrationGoogleInstructions =>
      'أنشئ مشروع Google Cloud خاصًا بك، وفعّل واجهتي Calendar وTasks، ثم استورد JSON لعميل OAuth لسطح المكتب. امنح الإذن للحساب المقصود.';

  @override
  String get registrationMicrosoftInstructions =>
      'استخدم تسجيل تطبيق عميل عام في مستأجر Entra يسمح بالتسجيل. أدخل معرّف العميل وأنواع الحسابات. لا يلزم سر عميل.';

  @override
  String get registrationImportGoogle => 'اختيار JSON لعميل OAuth لسطح المكتب';

  @override
  String get registrationValidate => 'التحقق من التسجيل';

  @override
  String get registrationAuthorize => 'منح الإذن في المتصفح';

  @override
  String get registrationClientId => 'معرّف التطبيق/العميل';

  @override
  String get registrationTenantId => 'معرّف المستأجر';

  @override
  String get registrationAudience => 'الحسابات المدعومة';

  @override
  String get registrationBothAudience => 'حسابات شخصية ومؤسسية';

  @override
  String get registrationOrganizationAudience => 'حسابات مؤسسية';

  @override
  String get registrationPersonalAudience => 'حسابات شخصية';

  @override
  String get registrationTenantAudience => 'مستأجر مؤسسة واحد';

  @override
  String registrationSummary(String clientId) {
    return 'التسجيل: ⁨$clientId⁩';
  }

  @override
  String get registrationMigrate => 'الانتقال الآن';

  @override
  String get registrationReplace => 'استبدال التسجيل';

  @override
  String registrationRetirementNotice(String provider, String setup) {
    return 'يستخدم هذا الحساب تسجيل ⁨$provider⁩ أصليًا مخصصًا للحسابات الموجودة. لاستبداله، أعدّ ⁨$setup⁩ وأعد اتصال هذا الحساب. ستُحفظ التقويمات والمهام والتغييرات المحلية الموجودة.';
  }

  @override
  String get registrationContinue => 'متابعة استخدام هذا الحساب';

  @override
  String get registrationGoogleProject => 'مشروع Google Cloud';

  @override
  String get registrationMicrosoftApp => 'تسجيل تطبيق Microsoft';

  @override
  String get registrationUserOwned => 'تسجيل يقدمه المستخدم';

  @override
  String get registrationNativeGoogle => 'تسجيل Google الأصلي على Android';

  @override
  String get registrationShared => 'تسجيل مشترك (مرحلة انتقالية)';

  @override
  String get registrationUnresolved =>
      'لم يُحدّد مصدر التسجيل. بيانات الحساب محفوظة.';

  @override
  String get registrationOfficialDocumentation => 'الوثائق الرسمية';

  @override
  String registrationAndroidIdentity(
    String packageName,
    String signatureHash,
    String redirectUri,
  ) {
    return 'الحزمة: ⁨$packageName⁩\nبصمة التوقيع: ⁨$signatureHash⁩\nعنوان إعادة التوجيه: ⁨$redirectUri⁩';
  }

  @override
  String get oauthRegistrationRejected =>
      'تحقق من نوع العميل والحسابات المدعومة والأذونات وإعادة التوجيه في التسجيل. اختر الإعداد المستورد مرة أخرى.';

  @override
  String get oauthAuthorizationCodeUnusable =>
      'تعذر إكمال محاولة التفويض هذه. ابدأ من جديد؛ الاتصال الحالي محفوظ.';

  @override
  String get oauthPermissionRefused =>
      'رُفض التفويض أو لم تُمنح الأذونات المطلوبة. حاول مجددًا وامنح الأذونات اللازمة.';

  @override
  String get oauthProviderThrottled =>
      'يحد موفر الخدمة من الطلبات. انتظر قبل المحاولة مجددًا؛ الاتصال الحالي محفوظ.';

  @override
  String get oauthProviderTemporaryFailure =>
      'تعذر إكمال التفويض بسبب مشكلة مؤقتة لدى موفر الخدمة. حاول مجددًا؛ الاتصال الحالي محفوظ.';

  @override
  String get oauthAuthorizationTimedOut =>
      'انتهت مهلة التفويض. حاول مجددًا واختر الإعداد المستورد مرة أخرى.';

  @override
  String get oauthWrongAccount =>
      'فوّض الحساب المحدد لإعادة الاتصال. الاتصال الحالي محفوظ.';

  @override
  String get oauthSecureStorageUnavailable =>
      'التخزين الآمن غير متاح. استعد الوصول إليه وحاول مجددًا.';

  @override
  String get oauthRevokedRemovalIncomplete =>
      'أُلغي التفويض عن بُعد، لكن تنظيف الحساب لم يكتمل. أعد تشغيل BusyMax لإعادة محاولة الاسترداد المحلي.';

  @override
  String get addAccount => 'إضافة حساب';

  @override
  String get registrationConnect => 'اتصال';

  @override
  String get registrationBack => 'رجوع';

  @override
  String get registrationReplaceGoogle => 'استبدال JSON OAuth لسطح المكتب';

  @override
  String get registrationSelectedConfiguration => 'الإعداد المحدد';

  @override
  String get registrationDirectoryId => 'معرّف الدليل/المستأجر';

  @override
  String get registrationInvalidId => 'أدخل UUID صالحًا.';

  @override
  String get registrationExpired =>
      'انتهت صلاحية هذا الإعداد. استورده مجددًا أو عدّل حقول التسجيل قبل الاتصال.';

  @override
  String get registrationOwnProjectRequired =>
      'اختر تسجيلًا من مشروعك أو مستأجرك الخاص.';

  @override
  String get registrationSetupFailed => 'تعذر إكمال الإعداد. حاول مجددًا.';

  @override
  String get registrationLinkFailed =>
      'تعذر فتح الرابط. تحقق من المتصفح وحاول مجددًا.';

  @override
  String get registrationPermissions => 'الأذونات';

  @override
  String get registrationDesktopClient => 'تطبيق سطح المكتب';

  @override
  String get registrationOpenGoogleConsole => 'فتح وحدة تحكم Google Cloud';

  @override
  String get registrationGoogleAudienceHelp =>
      'متطلبات Google للنشر ومستخدمي الاختبار';

  @override
  String get registrationDesktopHelp => 'تعليمات تسجيل تطبيق سطح المكتب';

  @override
  String get registrationOpenEntra => 'فتح مركز إدارة Microsoft Entra';

  @override
  String get registrationGuideGoogleProject =>
      'افتح Google Cloud Console. استخدم محدد المشاريع في الأعلى لاختيار مشروعك، أو اختر New project وأدخل اسمًا ثم اختر Create. أبقِ هذا المشروع محددًا في بقية الخطوات.';

  @override
  String get registrationGuideGoogleAudience =>
      'انتقل إلى Google Auth Platform → Branding. إن لم يبدأ الإعداد، اختر Get started. أدخل BusyMax في App name واختر بريدك في User support email ثم Next. في Audience، اختر External. اختر Next وأدخل بريدك ضمن Contact Information ثم Next. وافق على User Data Policy ثم اختر Continue وCreate. إذا كان الإعداد موجودًا، راجع Branding وAudience.';

  @override
  String get registrationGuideGooglePermissions =>
      'افتح Google Auth Platform → Data Access → Add or remove scopes. اختر النطاقات الخمسة أدناه؛ استخدم Manually add scopes عند الحاجة. للإدخال اليدوي، الصق القيم الناقصة واختر Add to table. اختر Update ثم Save. يحتاج BusyMax إلى الوصول للتقويم والمهام.';

  @override
  String get registrationGuideGoogleClient =>
      'افتح Google Auth Platform → Clients → Create client. اضبط Application type على Desktop app وأدخل BusyMax في Name ثم اختر Create. في نافذة الإنشاء، اختر Download JSON واحفظ الملف. اختر رجوع للعودة إلى النموذج، واختر الملف وراجع المشروع ومعرّف العميل. اختر اتصال ووافق على الوصول للتقويم والمهام في المتصفح.';

  @override
  String get registrationGuideMicrosoftApp =>
      'سجّل الدخول إلى مركز إدارة Microsoft Entra. استخدم Settings لاختيار مستأجر يسمح لك بتسجيل التطبيقات. افتح Entra ID → App registrations → New registration. أدخل BusyMax في Name ثم اختر أنواع الحسابات في الخطوة التالية. إن كان التسجيل محظورًا، اطلب الوصول من مسؤول المستأجر.';

  @override
  String get registrationGuideMicrosoftRedirect =>
      'في تسجيلك، افتح Authentication → Add a platform → Mobile and desktop applications. اختر عنوان URI لإعادة التوجيه أدناه أو أدخله، ثم اختر Configure لحفظه. يستخدم BusyMax متصفح النظام. لا يلزم سر عميل.';

  @override
  String get registrationGuideMicrosoftPermissions =>
      'افتح API permissions → Add a permission → Microsoft Graph → Delegated permissions. ابحث عن كل نطاق أدناه وحدده ثم اختر Add permissions. احتفظ بـ User.Read إن كان موجودًا. إذا كانت مؤسستك تتطلب موافقة المسؤول، اطلب منه استخدام Grant admin consent لمستأجرك.';

  @override
  String get registrationGuideMicrosoftConnect =>
      'اختر رجوع للعودة إلى النموذج. الصق Application (client) ID واختر الحسابات المدعومة نفسها في التسجيل. لمستأجر مؤسسي واحد، الصق أيضًا Directory (tenant) ID. اختر اتصال وسجّل الدخول إلى الحساب المقصود في المتصفح. يفحص BusyMax الحقول محليًا؛ وتطلب Microsoft موافقتك أثناء تسجيل الدخول في المتصفح.';

  @override
  String get registrationGoogleImportFailed =>
      'تعذر استيراد هذا الملف. اختر JSON OAuth صالحًا لسطح المكتب. يُحتفظ بأي اختيار صالح سابق.';

  @override
  String get registrationGoogleSetupInstructions => 'إرشادات إعداد Google';

  @override
  String get registrationMicrosoftSetupInstructions =>
      'إرشادات إعداد Microsoft';

  @override
  String get registrationDesktopConfiguration => 'إعداد OAuth لسطح المكتب';

  @override
  String get registrationNoFileSelected => 'لم يتم اختيار ملف';

  @override
  String get registrationChooseFile => 'اختيار ملف…';

  @override
  String get registrationReplaceFile => 'استبدال…';

  @override
  String get registrationGoogleIntroduction =>
      'اختر ملف JSON الخاص بـ OAuth لسطح المكتب من مشروع Google Cloud الخاص بك.';

  @override
  String get registrationMicrosoftIntroduction =>
      'أدخل تفاصيل تسجيل تطبيق Microsoft الخاص بك.';

  @override
  String get registrationSetupInstructions => 'إرشادات الإعداد';

  @override
  String get registrationInstructionsDescription =>
      'أنشئ الإعداد المطلوب لربط حسابك.';

  @override
  String get registrationEnableApis => 'تفعيل Calendar وTasks';

  @override
  String get registrationConsentScreen => 'إعداد شاشة الموافقة';

  @override
  String get registrationAppName => 'اسم التطبيق';

  @override
  String get registrationScopes => 'نطاقات الوصول';

  @override
  String get registrationRedirectUri => 'عنوان URI لإعادة التوجيه';

  @override
  String get registrationOpenApiLibrary => 'فتح مكتبة Google API';

  @override
  String get registrationOpenBranding => 'فتح Branding في Google Auth Platform';

  @override
  String get registrationOpenDataAccess =>
      'فتح Data Access في Google Auth Platform';

  @override
  String get registrationOpenClients => 'فتح Clients في Google Auth Platform';

  @override
  String get registrationOpenEntraAuthentication =>
      'فتح تسجيلات تطبيقات Entra لإعداد Authentication';

  @override
  String get registrationOpenEntraPermissions =>
      'فتح تسجيلات تطبيقات Entra لإعداد API permissions';

  @override
  String get registrationCopy => 'نسخ';

  @override
  String get registrationCopyAll => 'نسخ الكل';

  @override
  String get registrationGuideGoogleApis =>
      'انتقل إلى APIs & Services → Library. ابحث عن Google Calendar API وافتح صفحته واختر Enable. عد إلى Library وكرر العملية مع Google Tasks API.';

  @override
  String get registrationGuideMicrosoftAudience =>
      'ضمن Supported account types، اختر Personal accounts only للحساب الشخصي، أو Multiple Entra ID tenants لحسابات المؤسسات، أو Any Entra ID Tenant + Personal Microsoft accounts لكليهما، أو Single tenant only لهذا الدليل. اختر Register. في Overview، انسخ Application (client) ID؛ ولمستأجر واحد انسخ أيضًا Directory (tenant) ID. اختر الحسابات المدعومة المطابقة في BusyMax.';

  @override
  String get registrationConnectBusyMax => 'الاتصال عبر BusyMax';

  @override
  String get registrationRecommended => 'موصى به';

  @override
  String get registrationOtherMethods => 'طرق اتصال أخرى';

  @override
  String get registrationWorkspace => 'مؤسسة Google Workspace';

  @override
  String get registrationGoogleCustom => 'عميل OAuth مخصص';

  @override
  String get registrationMicrosoftCustom => 'تسجيل تطبيق مخصص';

  @override
  String get registrationMethodsIntroduction => 'اختر طريقة ربط حسابك.';

  @override
  String get registrationWorkspaceDescription => 'استخدم إعدادًا تديره مؤسستك.';

  @override
  String get registrationCustomDescription => 'استخدم تسجيلًا تديره بنفسك.';

  @override
  String get registrationSharedUnavailable =>
      'الاتصال عبر BusyMax غير متاح في هذا الإصدار. يمكنك استخدام طريقة اتصال أخرى أدناه.';

  @override
  String get registrationWorkspaceIntroduction =>
      'اختر ملف Desktop OAuth JSON الذي توفره أو تديره مؤسستك. لا يثبت الملف ملكية المؤسسة أو الجمهور أو حالة التحقق.';

  @override
  String get registrationWorkspaceSetupInstructions =>
      'تعليمات إعداد Google Workspace';

  @override
  String get registrationBusyMaxManaged => 'تسجيل تديره BusyMax';

  @override
  String get registrationBranding => 'إعداد العلامة التجارية والنطاقات';

  @override
  String get registrationPublishing => 'النشر للاستخدام العادي';

  @override
  String get registrationOpenAudience => 'فتح جمهور Google Auth Platform';

  @override
  String get registrationGuideWorkspaceProject =>
      'اطلب ملف Desktop OAuth JSON من المسؤول، أو افتح Google Cloud Console واختر مشروعًا تملكه مؤسستك في Google Workspace. لإنشاء مشروع، افتح إدارة الموارد → إنشاء مشروع، وأدخل اسم المشروع، واختر مؤسستك أو أحد مجلداتها في المورد الرئيسي، ثم اختر إنشاء. حدد هذا المشروع للخطوات التالية. يتطلب الإنشاء صلاحية Project Creator، ويتطلب إعداد OAuth صلاحية OAuth Config Editor، ويتطلب تفعيل واجهات API صلاحية Service Usage Admin أو ما يعادلها. اطلب مساعدة المسؤول إذا مُنع الإجراء.';

  @override
  String get registrationGuideGoogleBranding =>
      'في Branding → App domain، أضف نطاقات المشروع المصرح بها قبل روابط الصفحة الرئيسية والخصوصية وشروط الخدمة، ثم Save. تحتاج تطبيقات External الإنتاجية هذه الروابط. استخدم نطاقات تملكها وأثبت ملكيتها في Search Console عندما تطلب Google التحقق من العلامة. رابط خصوصية BusyMax أدناه لا يثبت ملكية busystack.org لمشروعك.';

  @override
  String get registrationGuideGooglePublishing =>
      'في Audience، اختر Publish app وأكد In production. لا تترك الاستخدام العادي في Testing: تنتهي تفويضات Calendar/Tasks ورموز تحديثها بعد سبعة أيام. النشر والتحقق منفصلان. قد يُعفى الاستخدام الشخصي لأقل من 100 مستخدم من التحقق مع تحذيرات وحد للمستخدمين؛ وقد يتطلب التوزيع الأوسع اعتماد العلامة والنطاقات. قد تنتهي التفويضات الإنتاجية أو تُلغى أيضًا.';

  @override
  String get registrationGuideWorkspacePermissions =>
      'راجع هذه النطاقات مع المسؤول. لا تحتاج تطبيقات Internal إلى قائمة نطاقات في شاشة الموافقة. عند طلبها، افتح Data Access → Add or remove scopes وأضف القيم ثم Update وSave. قد تظل قيود المسؤول تمنع التفويض.';

  @override
  String get registrationGuideMicrosoftOptionalPermissions =>
      'تُطلب أذونات التقويمات المشتركة والفئات بشكل منفصل عند تفعيل هذه الميزات الاختيارية؛ لا تضفها إلى الإعداد الإلزامي أعلاه.';

  @override
  String get registrationGuideWorkspaceAudience =>
      'انتقل إلى Google Auth Platform → Branding. إن لم يبدأ الإعداد، اختر Get started. أدخل BusyMax في App name واختر بريدك في User support email ثم Next. في Audience، اختر Internal. اختر Next وأدخل بريدك ضمن Contact Information ثم Next. وافق على User Data Policy ثم اختر Continue وCreate. إذا كان الإعداد موجودًا، راجع Branding وAudience.\n\nيسمح Internal فقط بحسابات المؤسسة الأم للمشروع، مع الخضوع لقيود المسؤول. لا حاجة لقائمة مستخدمي اختبار. لا يستطيع BusyMax التحقق من إعدادات وحدة التحكم عبر ملف JSON.';
}

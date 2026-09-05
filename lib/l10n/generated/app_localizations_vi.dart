// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get windowsSupport => 'Hỗ trợ';

  @override
  String get windowsThirdPartyLicenses => 'Giấy phép bên thứ ba';

  @override
  String get windowsSearch => 'Tìm kiếm';

  @override
  String get windowsStartupDisabledByUser =>
      'Người dùng đã tắt trong Cài đặt Windows.';

  @override
  String get windowsStartupDisabledByPolicy =>
      'Đã tắt theo chính sách Windows.';

  @override
  String get windowsStartupUnavailable =>
      'Khả dụng sau khi cài đặt BusyMax từ gói MSIX.';

  @override
  String get windowsReminderExitNotice =>
      'Lời nhắc sẽ dừng khi thoát hẳn BusyMax. Hãy để ứng dụng chạy trong nền để nhận lời nhắc.';

  @override
  String get windowsProductVersionLabel => 'Phiên bản sản phẩm';

  @override
  String get windowsPackageVersionLabel => 'Phiên bản gói Windows';

  @override
  String get windowsUnpackaged => 'Chưa đóng gói';

  @override
  String get windowsAgendaLoadMore => 'Tải thêm mục lịch biểu';

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'Thứ Hai',
      'TU': 'Thứ Ba',
      'WE': 'Thứ Tư',
      'TH': 'Thứ Năm',
      'FR': 'Thứ Sáu',
      'SA': 'Thứ Bảy',
      'SU': 'Chủ Nhật',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return 'vào các ngày $first và $second';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency vào các ngày $firstDay và $secondDay của $month';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency vào ngày $day của $firstMonth và $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency vào các ngày $firstDay và $secondDay của $firstMonth và $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency vào các ngày $days của $firstMonth và $secondMonth';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Kết nối tài khoản Google, Microsoft, Apple iCloud Calendar hoặc Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'Trên màn hình cấp quyền của Google, hãy chọn cả quyền truy cập Lịch và Công việc.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Cần có quyền truy cập Google Calendar và Google Tasks. Vui lòng thử lại và chọn cả hai hộp kiểm.';

  @override
  String get finishSetup => 'Hoàn tất thiết lập';

  @override
  String get continueSetup => 'Tiếp tục';

  @override
  String get onboardingSetupTitle => 'Thiết lập BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Kết nối tài khoản';

  @override
  String get onboardingAccountsStepDescription =>
      'Thêm mọi tài khoản bạn muốn sử dụng. BusyMax đồng bộ lịch, sự kiện, danh sách công việc và công việc được hỗ trợ từ từng tài khoản.';

  @override
  String get onboardingPreferencesStepTitle => 'Chọn cài đặt hệ thống';

  @override
  String get onboardingPreferencesStepDescription =>
      'Thiết lập cách ứng dụng hoạt động trên máy tính, lời nhắc, mức độ chi tiết của thông báo và giao diện trước khi mở lịch biểu.';

  @override
  String get signInWithGoogle => 'Đăng nhập bằng Google';

  @override
  String get signInWithMicrosoft => 'Đăng nhập bằng Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Dịch vụ này chưa được cấu hình.';

  @override
  String get waitingForGoogleSignIn => 'Đang chờ đăng nhập Google...';

  @override
  String get waitingForMicrosoftSignIn => 'Đang chờ đăng nhập Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'Tính năng đăng nhập Microsoft chưa được cấu hình. Hãy đặt MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Hủy';

  @override
  String get close => 'Đóng';

  @override
  String get exit => 'Thoát';

  @override
  String get options => 'Tùy chọn';

  @override
  String get hide => 'Ẩn';

  @override
  String get show => 'Hiện';

  @override
  String get export => 'Xuất';

  @override
  String get save => 'Lưu';

  @override
  String get settings => 'Cài đặt';

  @override
  String get all => 'Tất cả';

  @override
  String get calendarEvents => 'Sự kiện';

  @override
  String get calendarTasks => 'Công việc';

  @override
  String get calendar => 'Lịch';

  @override
  String get calendars => 'Lịch';

  @override
  String get newCalendar => 'Lịch mới';

  @override
  String get calendarColor => 'Màu lịch';

  @override
  String calendarColorOption(int number) {
    return 'Màu $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Nhà cung cấp này không hỗ trợ quản lý lịch trong BusyMax.';

  @override
  String get primaryCalendarCannotDelete => 'Không thể xóa lịch chính.';

  @override
  String calendarCreateFailed(String error) {
    return 'Không thể tạo lịch: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'Lịch đã được tạo nhưng BusyMax không thể làm mới tài khoản. Lịch sẽ xuất hiện sau lần đồng bộ tiếp theo.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Không thể cập nhật lịch: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Không thể xóa lịch: $error';
  }

  @override
  String get newEvent => 'Sự kiện mới';

  @override
  String get refreshCalendar => 'Làm mới lịch';

  @override
  String get openInProvider => 'Mở trong dịch vụ';

  @override
  String get hideFromSchedule => 'Ẩn khỏi lịch biểu';

  @override
  String get showInSchedule => 'Hiện trong lịch biểu';

  @override
  String get noCalendarsSynced => 'Chưa có lịch nào được đồng bộ.';

  @override
  String get allDay => 'Cả ngày';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString mục khác';
  }

  @override
  String get noEventsOrTasks => 'Không có sự kiện hoặc công việc';

  @override
  String get scheduleLoading => 'Đang tải lịch biểu...';

  @override
  String get scheduleUnavailable => 'Lịch biểu không khả dụng';

  @override
  String get scheduleNoSources =>
      'Không có lịch hoặc danh sách công việc nào đang hiển thị';

  @override
  String get scheduleNoSourcesDescription =>
      'Chọn nội dung cần hiển thị trong Cài đặt, sau đó làm mới lịch biểu.';

  @override
  String get scheduleSignInRequired => 'Kết nối tài khoản';

  @override
  String get scheduleSignInDescription =>
      'Đăng nhập để đồng bộ lịch và công việc.';

  @override
  String get scheduleNoSearchResults =>
      'Không có sự kiện hoặc công việc phù hợp';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Thử tìm kiếm khác hoặc xóa các bộ lọc hiện tại.';

  @override
  String get refresh => 'Làm mới';

  @override
  String get trayOpenBusyMax => 'Mở BusyMax';

  @override
  String get trayShowBusyMax => 'Hiển thị BusyMax';

  @override
  String get trayNewEvent => 'Sự kiện mới…';

  @override
  String get trayNewTask => 'Công việc mới…';

  @override
  String get trayToday => 'Hôm nay';

  @override
  String get trayAllDay => 'Cả ngày';

  @override
  String get trayNow => 'Bây giờ';

  @override
  String get trayCalendarEvent => 'Sự kiện lịch';

  @override
  String get trayUntitledEvent => 'Sự kiện chưa có tiêu đề';

  @override
  String get trayNothingElseToday => 'Hôm nay không còn gì khác';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count công việc đến hạn hôm nay',
      one: '1 công việc đến hạn hôm nay',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Mở lịch hôm nay';

  @override
  String get traySyncNow => 'Đồng bộ ngay';

  @override
  String get traySyncing => 'Đang đồng bộ…';

  @override
  String get trayNotConnected => 'Chưa kết nối';

  @override
  String get trayNotYetSynced => 'Chưa đồng bộ';

  @override
  String get trayLastSyncedJustNow => 'Vừa đồng bộ';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đồng bộ $count phút trước',
      one: 'Đồng bộ 1 phút trước',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đồng bộ $count giờ trước',
      one: 'Đồng bộ 1 giờ trước',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đồng bộ $count ngày trước',
      one: 'Đồng bộ 1 ngày trước',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Cài đặt';

  @override
  String get trayQuitBusyMax => 'Thoát BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Tải thêm công việc quá hạn';

  @override
  String get agendaLoadMoreNoDate => 'Tải thêm công việc không có ngày';

  @override
  String get viewDay => 'Ngày';

  @override
  String get viewWeek => 'Tuần';

  @override
  String get viewMonth => 'Tháng';

  @override
  String get viewYear => 'Năm';

  @override
  String get viewAgenda => 'Lịch biểu';

  @override
  String get scheduleSettings => 'Lịch biểu';

  @override
  String get scheduleDisplaySettings => 'Hiển thị lịch biểu';

  @override
  String get scheduleDisplayHoursDescription =>
      'Chế độ xem Ngày và Tuần ban đầu hiển thị khoảng thời gian này. Các mục sớm hơn hoặc muộn hơn sẽ mở rộng khoảng hiển thị khi cần.';

  @override
  String get scheduleDayStartsAt => 'Ngày bắt đầu lúc';

  @override
  String get scheduleDayEndsAt => 'Ngày kết thúc lúc';

  @override
  String get sourceCalendar => 'Lịch';

  @override
  String get sourceTaskList => 'Danh sách công việc';

  @override
  String get createChoiceTitle => 'Tạo';

  @override
  String get createEventAtTime => 'Sự kiện';

  @override
  String get createTaskAtDate => 'Công việc';

  @override
  String get editEvent => 'Chỉnh sửa sự kiện';

  @override
  String get eventTitle => 'Tiêu đề sự kiện';

  @override
  String get location => 'Địa điểm';

  @override
  String get timeSlot => 'Khoảng thời gian';

  @override
  String get startDateTime => 'Ngày/giờ bắt đầu';

  @override
  String get endDateTime => 'Ngày/giờ kết thúc';

  @override
  String get doesNotRepeat => 'Không lặp lại';

  @override
  String get defaultReminder => 'Lời nhắc mặc định';

  @override
  String get guests => 'Khách mời';

  @override
  String get noGuests => 'Không có khách';

  @override
  String get attendeeRequired => 'Bắt buộc';

  @override
  String get attendeeOptional => 'Tùy chọn';

  @override
  String get meetingSection => 'Cuộc họp';

  @override
  String get addGoogleMeet => 'Thêm Google Meet';

  @override
  String get addTeamsMeeting => 'Thêm cuộc họp Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Đã thêm cuộc họp trực tuyến';

  @override
  String get requestResponses => 'Yêu cầu phản hồi';

  @override
  String get requestResponsesDescription => 'Yêu cầu khách trả lời lời mời.';

  @override
  String get hideGuestList => 'Ẩn danh sách khách';

  @override
  String get hideGuestListDescription =>
      'Khách không thể xem những người khác được mời.';

  @override
  String get allowNewTimeProposals => 'Cho phép đề xuất thời gian mới';

  @override
  String get allowNewTimeProposalsDescription =>
      'Khách có thể đề xuất thời gian họp khác.';

  @override
  String get notifyGuestsTitle => 'Thông báo cho khách?';

  @override
  String get notifyGuestsSaveMessage =>
      'Cuộc họp này có khách. Gửi lời mời hoặc cập nhật sự kiện khi lưu?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Cuộc họp này có khách. Gửi thông báo hủy khi xóa?';

  @override
  String get sendUpdates => 'Gửi cập nhật';

  @override
  String get sendCancellation => 'Gửi thông báo hủy';

  @override
  String get doNotSend => 'Không gửi';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Lưu cuộc họp?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft sẽ gửi lời mời hoặc cập nhật sự kiện cho khách.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Xóa cuộc họp?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft sẽ gửi thông báo hủy cho khách.';

  @override
  String get organizer => 'Người tổ chức';

  @override
  String get yourResponse => 'Phản hồi của bạn';

  @override
  String get guestResponses => 'Phản hồi của khách';

  @override
  String get respond => 'Phản hồi';

  @override
  String get acceptInvitation => 'Chấp nhận';

  @override
  String get tentativeInvitation => 'Tạm thời';

  @override
  String get declineInvitation => 'Từ chối';

  @override
  String get joinMeeting => 'Tham gia cuộc họp';

  @override
  String get responseAccepted => 'Đã chấp nhận';

  @override
  String get responseTentative => 'Tạm thời';

  @override
  String get responseDeclined => 'Đã từ chối';

  @override
  String get responseNeedsAction => 'Đang chờ phản hồi';

  @override
  String get responseNotResponded => 'Chưa phản hồi';

  @override
  String get responseOrganizer => 'Người tổ chức';

  @override
  String invitationResponseFailed(String error) {
    return 'Không thể gửi phản hồi: $error';
  }

  @override
  String get joinMeetingFailed => 'Không thể mở liên kết cuộc họp.';

  @override
  String get description => 'Mô tả';

  @override
  String get availabilityShowAs => 'Tình trạng rảnh/bận / Hiển thị là';

  @override
  String get busy => 'Bận';

  @override
  String get visibility => 'Chế độ hiển thị';

  @override
  String get defaultVisibility => 'Chế độ hiển thị mặc định';

  @override
  String get conference => 'Cuộc họp';

  @override
  String get noConference => 'Không có cuộc họp';

  @override
  String get providerCalendar => 'Lịch của dịch vụ';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => 'Đậm';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'Nghiêng';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'Gạch chân';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Trước $minutesString phút',
      one: 'Trước 1 phút',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'Khi bắt đầu';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Trước $hoursString giờ',
      one: 'Trước 1 giờ',
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
      other: 'Trước $daysString ngày',
      one: 'Trước 1 ngày',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Rảnh';

  @override
  String get availabilityTentative => 'Dự kiến';

  @override
  String get availabilityOutOfOffice => 'Vắng mặt';

  @override
  String get availabilityWorkingElsewhere => 'Làm việc ở nơi khác';

  @override
  String get visibilityDefault => 'Mặc định';

  @override
  String get visibilityPublic => 'Công khai';

  @override
  String get visibilityPrivate => 'Riêng tư';

  @override
  String get visibilityConfidential => 'Bảo mật';

  @override
  String get sensitivityNormal => 'Bình thường';

  @override
  String get sensitivityPersonal => 'Cá nhân';

  @override
  String get tasks => 'Công việc';

  @override
  String get allTasks => 'Tất cả công việc';

  @override
  String tasksInList(String title) {
    return 'Công việc trong $title';
  }

  @override
  String get taskLists => 'Danh sách công việc';

  @override
  String get navigation => 'Điều hướng';

  @override
  String get mainMenu => 'Trình đơn chính';

  @override
  String get keyboardShortcuts => 'Phím tắt';

  @override
  String get shortcutGroupGeneral => 'Chung';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Hiển thị bảng tham khảo phím tắt này';

  @override
  String get shortcutGroupNavigation => 'Điều hướng';

  @override
  String get shortcutNextPeriod => 'Khoảng tiếp theo';

  @override
  String get shortcutNextPeriodDescription =>
      'Tuần tiếp theo trong chế độ xem tuần, tháng tiếp theo trong chế độ xem tháng, v.v.';

  @override
  String get shortcutPreviousPeriod => 'Khoảng trước đó';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Tuần trước trong chế độ xem tuần, tháng trước trong chế độ xem tháng, v.v.';

  @override
  String get shortcutJumpToToday => 'Chuyển đến hôm nay';

  @override
  String get shortcutGroupView => 'Chế độ xem';

  @override
  String get shortcutDayView => 'Chế độ xem ngày';

  @override
  String get shortcutWeekView => 'Chế độ xem tuần';

  @override
  String get shortcutMonthView => 'Chế độ xem tháng';

  @override
  String get shortcutYearView => 'Chế độ xem năm';

  @override
  String get shortcutAgendaView => 'Chế độ xem lịch biểu';

  @override
  String get shortcutGroupCreateAndEdit => 'Tạo và chỉnh sửa';

  @override
  String get shortcutSaveItem => 'Lưu sự kiện hoặc công việc';

  @override
  String get shortcutDeleteItem => 'Xóa sự kiện hoặc công việc';

  @override
  String get shortcutGroupTaskEditing => 'Chỉnh sửa công việc';

  @override
  String get shortcutCancelEditing => 'Hủy chỉnh sửa';

  @override
  String get shortcutCancelEditingDescription =>
      'Đóng phần chỉnh sửa hoặc chi tiết công việc';

  @override
  String get aboutBusyMax => 'Giới thiệu BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Lịch và công việc';

  @override
  String get license => 'Giấy phép';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Trang web';

  @override
  String get sourceCode => 'Mã nguồn';

  @override
  String get reportAnIssue => 'Báo cáo sự cố';

  @override
  String get sendFeedback => 'Gửi phản hồi';

  @override
  String get feedbackSubmit => 'Gửi';

  @override
  String get feedbackCategory => 'Danh mục';

  @override
  String get feedbackSelectCategory => 'Chọn một danh mục';

  @override
  String get feedbackCategoryProblem => 'Sự cố hoặc lỗi';

  @override
  String get feedbackCategoryFeature => 'Yêu cầu tính năng';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Vấn đề về quyền riêng tư hoặc bảo mật';

  @override
  String get feedbackCategoryUsability => 'Vấn đề về khả năng sử dụng';

  @override
  String get feedbackCategoryOther => 'Khác';

  @override
  String get feedbackSubject => 'Chủ đề';

  @override
  String get feedbackDetailedMessage => 'Nội dung chi tiết';

  @override
  String get feedbackReplyEmail =>
      'Địa chỉ email để nhận phản hồi (không bắt buộc)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Bao gồm chi tiết kỹ thuật';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Chỉ thêm tên và phiên bản hệ điều hành cùng ngôn ngữ, khu vực của ứng dụng. Không bao gồm nhật ký, dữ liệu tài khoản, tên tệp hoặc thông tin chẩn đoán khác.';

  @override
  String get feedbackCategoryRequired => 'Hãy chọn một danh mục.';

  @override
  String get feedbackSubjectLengthError => 'Chủ đề phải có từ 3 đến 120 ký tự.';

  @override
  String get feedbackMessageLengthError =>
      'Nội dung phải có từ 10 đến 5.000 ký tự.';

  @override
  String get feedbackInvalidEmail => 'Nhập địa chỉ email hợp lệ.';

  @override
  String get feedbackConnectionError =>
      'Không thể kết nối với BusyStack. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get feedbackTimeoutError =>
      'Yêu cầu đã hết thời gian chờ. Phản hồi của bạn chưa bị xóa; hãy thử lại.';

  @override
  String get feedbackRateLimitedError =>
      'Đã gửi quá nhiều phản hồi từ mạng này. Vui lòng chờ rồi thử lại.';

  @override
  String get feedbackRejectedError =>
      'Máy chủ đã từ chối nội dung gửi. Hãy kiểm tra các trường và thử lại.';

  @override
  String get feedbackServerError =>
      'BusyStack hiện không thể nhận phản hồi của bạn. Phản hồi chưa bị xóa; hãy thử lại.';

  @override
  String feedbackSuccess(String id) {
    return 'Đã gửi phản hồi. Mã tham chiếu: $id';
  }

  @override
  String get toggleSidebar => 'Hiện hoặc ẩn thanh bên';

  @override
  String get showSidebar => 'Hiện bảng bên';

  @override
  String get hideSidebar => 'Ẩn bảng bên';

  @override
  String get accounts => 'Tài khoản';

  @override
  String get currentAccount => 'Tài khoản hiện tại';

  @override
  String get switchAccount => 'Chuyển tài khoản';

  @override
  String get addGoogleAccount => 'Thêm tài khoản Google';

  @override
  String get addMicrosoftAccount => 'Thêm tài khoản Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Đã đăng nhập';

  @override
  String get removeAccount => 'Xóa tài khoản…';

  @override
  String get removingAccount => 'Đang xóa tài khoản…';

  @override
  String get removeAccountDescription =>
      'Dừng đồng bộ và xóa dữ liệu của tài khoản này khỏi thiết bị.';

  @override
  String removeAccountTitle(String account) {
    return 'Xóa $account khỏi BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'Thao tác này xóa khỏi thiết bị các công việc, lịch, sự kiện, lời nhắc và thay đổi ngoại tuyến đang chờ được lưu trong bộ nhớ đệm. Các thay đổi chưa đồng bộ sẽ mất. Bản sao lịch, sự kiện, danh sách công việc và công việc ở nhà cung cấp không bị xóa.';

  @override
  String get revokeGoogleAccess =>
      'Đồng thời thu hồi quyền truy cập của BusyMax vào tài khoản Google này';

  @override
  String get revokeGoogleAccessDescription =>
      'Bạn sẽ cần cấp lại quyền truy cập trước khi kết nối lại.';

  @override
  String get removeAccountAction => 'Xóa tài khoản';

  @override
  String get removeAccountFailed =>
      'Không thể hoàn tất việc xóa tài khoản. Hãy thử lại.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Tài khoản đã bị xóa khỏi thiết bị này, nhưng BusyMax không thể thu hồi quyền truy cập vào tài khoản Google. Bạn có thể thu hồi quyền trong phần cài đặt Tài khoản Google.';

  @override
  String get newTaskList => 'Danh sách công việc mới';

  @override
  String taskListCreateFailed(String error) {
    return 'Không thể tạo danh sách công việc: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Không thể đổi tên danh sách công việc: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Không thể xóa danh sách công việc: $error';
  }

  @override
  String get signInToViewTaskLists => 'Đăng nhập để xem danh sách công việc.';

  @override
  String get noTaskListsSynced =>
      'Chưa có danh sách công việc nào được đồng bộ.';

  @override
  String get listActions => 'Thao tác với danh sách';

  @override
  String get rename => 'Đổi tên';

  @override
  String get delete => 'Xóa';

  @override
  String get renameList => 'Đổi tên danh sách';

  @override
  String get deleteList => 'Xóa danh sách';

  @override
  String get unshare => 'Ngừng chia sẻ';

  @override
  String get readOnlyTaskListCannotRename =>
      'Danh sách công việc này ở chế độ chỉ đọc và không thể đổi tên.';

  @override
  String get taskListCannotDelete =>
      'Bạn không thể xóa danh sách công việc này với quyền hiện tại.';

  @override
  String get builtInMicrosoftList => 'Tích hợp sẵn';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Không thể đổi tên hoặc xóa danh sách tích hợp sẵn của Microsoft To Do.';

  @override
  String deleteListConfirmation(String title) {
    return 'Xóa “$title” khỏi Google Tasks?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Xóa “$title” và tất cả công việc trong đó?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Ngừng chia sẻ “$title” khỏi tài khoản này?';
  }

  @override
  String get deleteEvent => 'Xóa sự kiện';

  @override
  String get title => 'Tiêu đề';

  @override
  String get create => 'Tạo';

  @override
  String get newTask => 'Công việc mới';

  @override
  String get clearCompleted => 'Xóa các công việc đã hoàn thành';

  @override
  String get refreshList => 'Làm mới danh sách';

  @override
  String get refreshAll => 'Làm mới tất cả';

  @override
  String get listRefreshed => 'Đã làm mới danh sách.';

  @override
  String get allTasksRefreshed => 'Đã làm mới tất cả tài khoản.';

  @override
  String exportedFile(String path) {
    return 'Đã xuất sang $path';
  }

  @override
  String exportFailed(String error) {
    return 'Xuất không thành công: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Làm mới không thành công: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Chọn hoặc tạo một danh sách công việc để bắt đầu.';

  @override
  String get signInToViewTasks => 'Đăng nhập để xem công việc.';

  @override
  String get noTasks => 'Không có công việc.';

  @override
  String get noTasksYet => 'Chưa có công việc';

  @override
  String get noTasksYetMessage =>
      'Tạo một công việc hoặc làm mới tài khoản để bắt đầu.';

  @override
  String get noTasksInList => 'Không có công việc nào trong danh sách này.';

  @override
  String get overdue => 'Quá hạn';

  @override
  String get today => 'Hôm nay';

  @override
  String get tomorrow => 'Ngày mai';

  @override
  String get upcoming => 'Sắp tới';

  @override
  String get noDate => 'Không có ngày';

  @override
  String get completed => 'Đã hoàn thành';

  @override
  String duePrefix(String date) {
    return 'Đến hạn $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => 'Chi tiết công việc';

  @override
  String get editTask => 'Chỉnh sửa công việc';

  @override
  String get noTaskSelected => 'Chưa chọn công việc.';

  @override
  String get noTaskSelectedHelper =>
      'Chọn một công việc để xem và chỉnh sửa chi tiết.';

  @override
  String get taskUnavailable => 'Công việc không khả dụng.';

  @override
  String get signInToEditTasks => 'Đăng nhập để chỉnh sửa công việc.';

  @override
  String get refreshTask => 'Làm mới công việc';

  @override
  String get primarySection => 'Chính';

  @override
  String get statusSection => 'Trạng thái';

  @override
  String get openStatus => 'Chưa hoàn thành';

  @override
  String get doneStatus => 'Đã xong';

  @override
  String get taskStatus => 'Trạng thái';

  @override
  String get taskStatusNone => 'Không có trạng thái';

  @override
  String get taskStatusNeedsAction => 'Cần xử lý';

  @override
  String get taskStatusInProcess => 'Đang thực hiện';

  @override
  String get taskStatusCompleted => 'Đã hoàn thành';

  @override
  String get taskStatusCancelled => 'Đã hủy';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Đã hoàn thành $percentString%';
  }

  @override
  String get completionDate => 'Ngày hoàn thành';

  @override
  String get priority => 'Mức độ ưu tiên';

  @override
  String get priorityNone => 'Không có mức độ ưu tiên';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Ưu tiên $priorityString · Cao';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Ưu tiên $priorityString · Trung bình';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Ưu tiên $priorityString · Thấp';
  }

  @override
  String get taskUrl => 'URL công việc';

  @override
  String get invalidTaskUrl => 'Nhập URL tuyệt đối, bao gồm lược đồ.';

  @override
  String get classification => 'Phân loại';

  @override
  String get classificationPublic => 'Khi chia sẻ, hiển thị toàn bộ công việc';

  @override
  String get classificationConfidential =>
      'Khi chia sẻ, chỉ hiển thị trạng thái bận';

  @override
  String get classificationPrivate => 'Khi chia sẻ, ẩn công việc này';

  @override
  String get pinTask => 'Ghim công việc';

  @override
  String get notes => 'Ghi chú';

  @override
  String get dueDate => 'Ngày đến hạn';

  @override
  String get clearDueDate => 'Xóa ngày đến hạn';

  @override
  String get dueTime => 'Giờ đến hạn';

  @override
  String get startDate => 'Ngày bắt đầu';

  @override
  String get startTime => 'Giờ bắt đầu';

  @override
  String get endDate => 'Ngày kết thúc';

  @override
  String get endTime => 'Giờ kết thúc';

  @override
  String get reminderDate => 'Ngày nhắc';

  @override
  String get reminderTime => 'Giờ nhắc';

  @override
  String get reminder => 'Lời nhắc';

  @override
  String get addReminder => 'Thêm lời nhắc';

  @override
  String get reminders => 'Lời nhắc';

  @override
  String get noReminders => 'Không có lời nhắc';

  @override
  String get editReminder => 'Chỉnh sửa lời nhắc';

  @override
  String get beforeTaskStarts => 'Trước khi công việc bắt đầu';

  @override
  String get beforeTaskDue => 'Trước hạn chót của công việc';

  @override
  String get afterTaskStarts => 'Sau khi công việc bắt đầu';

  @override
  String get afterTaskDue => 'Sau hạn chót của công việc';

  @override
  String get relativeToTaskStart => 'Theo ngày bắt đầu công việc';

  @override
  String get relativeToTaskDue => 'Theo ngày đến hạn công việc';

  @override
  String get reminderTimeOfDay => 'Thời gian trong ngày';

  @override
  String get absoluteReminder => 'Vào ngày và giờ cụ thể';

  @override
  String get reminderAmount => 'Số lượng';

  @override
  String get reminderUnit => 'Đơn vị';

  @override
  String get reminderUnitSeconds => 'Giây';

  @override
  String get reminderUnitMinutes => 'Phút';

  @override
  String get reminderUnitHours => 'Giờ';

  @override
  String get reminderUnitDays => 'Ngày';

  @override
  String get reminderUnitWeeks => 'Tuần';

  @override
  String get reminderAtTaskStart => 'Khi công việc bắt đầu';

  @override
  String get reminderAtTaskDue => 'Khi công việc đến hạn';

  @override
  String get unsupportedReminder =>
      'Loại lời nhắc này được giữ lại nhưng không thể chỉnh sửa thời gian.';

  @override
  String get relatedRemindersTitle => 'Giữ lời nhắc liên quan?';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Ngày này có $countString lời nhắc liên quan. Giữ chúng ở ngày và giờ hiện tại?';
  }

  @override
  String get discardRelatedReminders => 'Xóa lời nhắc';

  @override
  String get keepRelatedReminders => 'Giữ lời nhắc';

  @override
  String get addGuest => 'Thêm khách mời';

  @override
  String get addGuestEmail => 'Thêm email khách mời';

  @override
  String get removeReminder => 'Xóa lời nhắc';

  @override
  String get off => 'Tắt';

  @override
  String get repeat => 'Lặp lại';

  @override
  String get repeatNone => 'Không lặp lại';

  @override
  String get noneValue => 'Không có';

  @override
  String get repeatDaily => 'Hằng ngày';

  @override
  String get repeatWeekly => 'Hằng tuần';

  @override
  String get repeatMonthly => 'Hằng tháng';

  @override
  String get repeatYearly => 'Hằng năm';

  @override
  String get repeatEvery => 'Khoảng lặp lại';

  @override
  String get repeatOn => 'Lặp lại vào';

  @override
  String get repeatEnd => 'Kết thúc lặp lại';

  @override
  String get repeatNever => 'Không bao giờ';

  @override
  String get repeatUntil => 'Vào ngày';

  @override
  String get repeatAfter => 'Sau một số lần xuất hiện';

  @override
  String get repeatCount => 'Số lần lặp';

  @override
  String get repeatDayOfMonth => 'Ngày trong tháng';

  @override
  String get repeatMonths => 'Tháng';

  @override
  String get repeatOrdinal => 'Vị trí ngày trong tuần';

  @override
  String get repeatSpecificDays => 'Ngày cụ thể';

  @override
  String get repeatFirst => 'Thứ nhất';

  @override
  String get repeatSecond => 'Thứ hai';

  @override
  String get repeatThird => 'Thứ ba';

  @override
  String get repeatFourth => 'Thứ tư';

  @override
  String get repeatFifth => 'Thứ năm';

  @override
  String get repeatSecondToLast => 'Áp chót';

  @override
  String get repeatLast => 'Cuối cùng';

  @override
  String get repeatAnyDay => 'Ngày';

  @override
  String get repeatWeekday => 'Ngày trong tuần';

  @override
  String get repeatWeekendDay => 'Ngày cuối tuần';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'Thứ Hai',
      'TU': 'Thứ Ba',
      'WE': 'Thứ Tư',
      'TH': 'Thứ Năm',
      'FR': 'Thứ Sáu',
      'SA': 'Thứ Bảy',
      'SU': 'Chủ Nhật',
      'day': 'ngày',
      'weekday': 'ngày trong tuần',
      'weekend': 'ngày cuối tuần',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Mỗi $countString ngày';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Mỗi $countString tuần';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Mỗi $countString tháng';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Mỗi $countString năm';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'vào $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'vào ngày $days trong tháng';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'vào $days đầu tiên',
      'second': 'vào $days thứ hai',
      'third': 'vào $days thứ ba',
      'fourth': 'vào $days thứ tư',
      'fifth': 'vào $days thứ năm',
      'secondToLast': 'vào $days áp chót',
      'last': 'vào $days cuối cùng',
      'other': 'vào $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'vào $months';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString lần',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'đến $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Quy tắc lặp lại này sử dụng các tùy chọn mà trình chỉnh sửa này không thay đổi.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Không thể sử dụng kiểu lặp lại này với $provider.';
  }

  @override
  String get importance => 'Mức độ quan trọng';

  @override
  String get importanceLow => 'Thấp';

  @override
  String get importanceNormal => 'Bình thường';

  @override
  String get importanceHigh => 'Cao';

  @override
  String get categories => 'Danh mục';

  @override
  String get scheduleSection => 'Lịch';

  @override
  String get dueGroup => 'Đến hạn';

  @override
  String get startGroup => 'Bắt đầu';

  @override
  String get reminderGroup => 'Lời nhắc';

  @override
  String get organizationSection => 'Sắp xếp';

  @override
  String get actionsSection => 'Thao tác';

  @override
  String get advancedSection => 'Nâng cao';

  @override
  String get addCategory => 'Thêm danh mục';

  @override
  String get list => 'Danh sách';

  @override
  String get microsoftMoveUnsupported =>
      'Phiên bản này không hỗ trợ di chuyển công việc giữa các danh sách trong tài khoản Microsoft To Do.';

  @override
  String get createSubtask => 'Tạo công việc con';

  @override
  String get subtasks => 'Công việc con';

  @override
  String get duplicateTask => 'Nhân bản công việc';

  @override
  String get taskDuplicated => 'Đã nhân bản công việc.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Không thể nhân bản công việc: $error';
  }

  @override
  String get hideSubtasks => 'Ẩn công việc phụ';

  @override
  String get hideClosedSubtasks => 'Ẩn công việc phụ đã đóng';

  @override
  String get moveToTop => 'Chuyển lên đầu';

  @override
  String get deleteTask => 'Xóa công việc';

  @override
  String get newSubtask => 'Công việc con mới';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Xóa “$title”?';
  }

  @override
  String get metadata => 'Siêu dữ liệu';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Đã cập nhật';

  @override
  String get parent => 'Công việc chính';

  @override
  String get position => 'Vị trí';

  @override
  String get webLink => 'Liên kết web';

  @override
  String get assignment => 'Phân công';

  @override
  String get localState => 'Trạng thái cục bộ';

  @override
  String get pendingSync => 'Đang chờ đồng bộ';

  @override
  String get synced => 'Đã đồng bộ';

  @override
  String get account => 'Tài khoản';

  @override
  String get sync => 'Đồng bộ';

  @override
  String get forceFullResync => 'Buộc đồng bộ hóa lại toàn bộ';

  @override
  String get forceFullResyncDescription =>
      'Tải lại toàn bộ dữ liệu từ mọi tài khoản đã kết nối. Chỉ sử dụng tùy chọn này để khắc phục sự cố đồng bộ hóa.';

  @override
  String get runInBackgroundWhenClosed => 'Tiếp tục chạy khi đóng cửa sổ';

  @override
  String get showTrayIcon => 'Hiện biểu tượng khay hệ thống';

  @override
  String get startMinimizedToTray => 'Khởi động thu nhỏ vào khay hệ thống';

  @override
  String get launchAtLogin => 'Khởi chạy khi đăng nhập';

  @override
  String get launchAtLoginDescription =>
      'Khởi chạy BusyMax trong nền để lời nhắc hoạt động sau khi bạn đăng nhập.';

  @override
  String get launchAtLoginFailed =>
      'Không thể cập nhật cài đặt khởi chạy khi đăng nhập.';

  @override
  String get requiresTrayIcon => 'Yêu cầu biểu tượng khay hệ thống.';

  @override
  String get syncComplete => 'Đồng bộ hoàn tất.';

  @override
  String syncFailed(String error) {
    return 'Đồng bộ không thành công: $error';
  }

  @override
  String get notifySyncFailures => 'Thông báo khi đồng bộ thất bại';

  @override
  String get notifyConflicts => 'Thông báo khi có xung đột';

  @override
  String get notifyDueToday => 'Thông báo công việc đến hạn hôm nay';

  @override
  String get eventReminders => 'Lời nhắc sự kiện';

  @override
  String get onState => 'Bật';

  @override
  String get taskReminders => 'Lời nhắc công việc';

  @override
  String get notificationDetailLevel => 'Mức độ chi tiết của thông báo';

  @override
  String get notificationDetailPrivate => 'Riêng tư';

  @override
  String get notificationDetailNormal => 'Bình thường';

  @override
  String get quietHours => 'Giờ yên tĩnh';

  @override
  String get quietHoursDescription =>
      'Tạm dừng thông báo trong khoảng thời gian này.';

  @override
  String get quietHoursStart => 'Bắt đầu giờ yên tĩnh';

  @override
  String get quietHoursEnd => 'Kết thúc giờ yên tĩnh';

  @override
  String get notifications => 'Thông báo';

  @override
  String get windowsNotificationsUnavailable =>
      'Thông báo Windows không khả dụng';

  @override
  String get windowsNotificationsUnpackaged =>
      'Bản chạy phát triển chưa đóng gói này không thể dùng thông báo Windows. Hãy cài đặt MSIX được ký để thử nghiệm nhằm kiểm tra lời nhắc.';

  @override
  String get windowsNotificationsInstalledFailure =>
      'BusyMax không thể khởi tạo thông báo Windows. Lời nhắc sẽ không xuất hiện cho đến khi sự cố cài đặt này được khắc phục.';

  @override
  String get appearance => 'Giao diện';

  @override
  String get theme => 'Chủ đề';

  @override
  String get themeSystem => 'Hệ thống';

  @override
  String get settingsSystem => 'Hệ thống';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeFamily => 'Họ chủ đề';

  @override
  String get themeFamilyYaru => 'Chủ đề Ubuntu nguyên bản (Yaru)';

  @override
  String get localization => 'Ngôn ngữ và khu vực';

  @override
  String get currentLocale => 'Ngôn ngữ và khu vực hiện tại';

  @override
  String get privacy => 'Quyền riêng tư';

  @override
  String get redactTaskContentInDiagnostics =>
      'Ẩn nội dung công việc trong thông tin chẩn đoán';

  @override
  String get developerDiagnostics => 'Chẩn đoán dành cho nhà phát triển';

  @override
  String get diagnostics => 'Chẩn đoán';

  @override
  String get apiInspectorDisabled => 'Hiện trình kiểm tra API';

  @override
  String get googleTasksApi => 'API Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Bản sửa đổi Discovery: $revision';
  }

  @override
  String get implementedMethods => 'Phương thức đã triển khai';

  @override
  String get supportsTasksScopes => 'Hỗ trợ phạm vi tasks và tasks.readonly';

  @override
  String get requiresTasksScope => 'Yêu cầu phạm vi tasks';

  @override
  String get blockedPendingOperations => 'Thao tác đang chờ bị chặn';

  @override
  String get signInToInspectPendingOperations =>
      'Đăng nhập để kiểm tra các thao tác đang chờ.';

  @override
  String get noBlockedPendingOperations =>
      'Không có thao tác đang chờ nào bị chặn.';

  @override
  String get operationActions => 'Hành động cho thao tác';

  @override
  String pendingOpListId(String id) {
    return 'danh_sách=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'công_việc=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'số_lần_thử=$countString';
  }

  @override
  String get retry => 'Thử lại';

  @override
  String get discard => 'Hủy bỏ';

  @override
  String get discardChangesAction => 'Không lưu';

  @override
  String get discardChanges => 'Hủy bỏ thay đổi?';

  @override
  String get discardChangesConfirmation =>
      'Thao tác này sẽ hủy bỏ các chỉnh sửa chưa lưu đối với công việc.';

  @override
  String get retryCompleted => 'Đã thử lại.';

  @override
  String get discardPendingOperation => 'Hủy bỏ thao tác đang chờ?';

  @override
  String get discardPendingOperationConfirmation =>
      'Thao tác này sẽ xóa thao tác cục bộ bị chặn. Lần đồng bộ tiếp theo sẽ tải lại dữ liệu từ Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Đã hủy bỏ thao tác đang chờ.';

  @override
  String get syncFailureNotificationTitle => 'Đồng bộ BusyMax không thành công';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Đồng bộ nền không thành công. $message';
  }

  @override
  String get conflictNotificationTitle => 'Xung đột đồng bộ BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Một thay đổi cục bộ đang chờ đã bị chặn. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Công việc đến hạn hôm nay';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Có $countString công việc đến hạn hôm nay.',
      one: 'Có một công việc đến hạn hôm nay.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Lời nhắc sự kiện';

  @override
  String get taskReminderNotificationTitle => 'Lời nhắc công việc';

  @override
  String get eventReminderNotificationBody => 'Sự kiện sắp bắt đầu.';

  @override
  String get taskReminderNotificationBody => 'Công việc sắp đến hạn.';

  @override
  String get notificationOpenAction => 'Mở';

  @override
  String get notificationSnoozeAction => 'Báo lại sau 10 phút';

  @override
  String get notificationDismissAction => 'Đóng';

  @override
  String get notificationDetailsHidden =>
      'Chi tiết bị ẩn theo cài đặt quyền riêng tư.';

  @override
  String get previousMonth => 'Tháng trước';

  @override
  String get nextMonth => 'Tháng sau';

  @override
  String get openMonthView => 'Mở chế độ xem tháng';

  @override
  String get previousYear => 'Năm trước';

  @override
  String get nextYear => 'Năm sau';

  @override
  String get openYearView => 'Mở chế độ xem năm';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Tuần $numberString';
  }

  @override
  String get resizeAllDayPanel => 'Đổi kích thước bảng cả ngày';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString mục',
      one: '1 mục',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Lịch này chỉ có thể đọc.';

  @override
  String get selectTimeZone => 'Chọn múi giờ';

  @override
  String get searchLocations => 'Tìm kiếm địa điểm';

  @override
  String get noLocationsFound => 'Không tìm thấy địa điểm';

  @override
  String get requiredField => 'Trường này là bắt buộc.';

  @override
  String get providerConnectionDescription =>
      'Kết nối lịch và công việc từ một trong các nhà cung cấp sau.';

  @override
  String get appleICloudProvider => 'Lịch Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Công việc Nextcloud';

  @override
  String get addAppleICloudAccount => 'Thêm tài khoản Lịch Apple iCloud';

  @override
  String get addNextcloudAccount => 'Thêm tài khoản Nextcloud';

  @override
  String get waitingForAppleICloud => 'Đang kết nối với Apple iCloud…';

  @override
  String get waitingForNextcloud => 'Đang chờ ủy quyền Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Kết nối Lịch Apple iCloud';

  @override
  String get appleAccountEmail => 'Email tài khoản Apple';

  @override
  String get appleAppSpecificPassword => 'Mật khẩu dành riêng cho ứng dụng';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Tạo mật khẩu dành riêng cho ứng dụng sau khi bật xác thực hai yếu tố cho tài khoản Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Đặt lại mật khẩu tài khoản Apple sẽ thu hồi các mật khẩu dành riêng cho ứng dụng.';

  @override
  String get connectNextcloudTitle => 'Kết nối Nextcloud';

  @override
  String get nextcloudServerUrl => 'Máy chủ Nextcloud hoặc địa chỉ CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Nhập URL máy chủ Nextcloud hoặc dán địa chỉ CalDAV chính được sao chép từ Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax sẽ mở trình duyệt. Phê duyệt quyền truy cập ở đó rồi quay lại BusyMax.';

  @override
  String get connectAccountAction => 'Kết nối';

  @override
  String get cancelAccountConnection => 'Hủy kết nối';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'Tài khoản đã bị xóa cục bộ nhưng không thể thu hồi mật khẩu ứng dụng Nextcloud.';

  @override
  String get davCachedOfflineNotice =>
      'Dữ liệu lịch và công việc được lưu trong bộ nhớ đệm cục bộ để sử dụng ngoại tuyến.';

  @override
  String get davReauthenticationRequired =>
      'Kết nối lại tài khoản này để tiếp tục đồng bộ.';

  @override
  String get davTemporarilyUnavailable =>
      'Tài khoản này tạm thời không khả dụng.';

  @override
  String get davPermissionChanged =>
      'Quyền máy chủ đã thay đổi. Các chỉnh sửa đang chờ bị tạm dừng.';

  @override
  String get davUnsupportedServer =>
      'Máy chủ hoặc hồ sơ nhà cung cấp này không được hỗ trợ.';

  @override
  String get collectionSettings => 'Lịch và danh sách công việc';

  @override
  String get calendarContent => 'Sự kiện lịch';

  @override
  String get taskContent => 'Công việc';

  @override
  String get readOnlySharedCollection => 'Chỉ đọc';

  @override
  String get pendingLocally => 'Đang chờ cục bộ';

  @override
  String get conflictBlocked => 'Bị chặn do xung đột';

  @override
  String get authenticationBlocked => 'Bị chặn cho đến khi kết nối lại';

  @override
  String get operationFailed => 'Thao tác không thành công';

  @override
  String get keepServerVersion => 'Giữ phiên bản máy chủ';

  @override
  String get reapplyLocalChange => 'Xem lại và áp dụng lại thay đổi cục bộ';

  @override
  String get duplicateLocalItem => 'Nhân bản thành mục mới';

  @override
  String get davConnectionState => 'Trạng thái kết nối';

  @override
  String get davConnected => 'Đã kết nối';

  @override
  String get davConnecting => 'Đang kết nối…';

  @override
  String get davSignedOut => 'Đã đăng xuất';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Lần đồng bộ thành công gần nhất: $time';
  }

  @override
  String get davNeverSynced => 'Chưa đồng bộ';

  @override
  String get refreshCollections => 'Làm mới lịch và danh sách công việc';

  @override
  String nextcloudServerHost(String host) {
    return 'Máy chủ: $host';
  }

  @override
  String get collectionSupportsEvents => 'Lịch sự kiện';

  @override
  String get collectionSupportsTasks => 'Danh sách công việc';

  @override
  String get collectionSupportsEventsAndTasks => 'Sự kiện và công việc';

  @override
  String get writableCollection => 'Có thể ghi';

  @override
  String get sharedCollection => 'Đã chia sẻ';

  @override
  String collectionLastSynced(String time) {
    return 'Đồng bộ lần cuối: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Sự cố đồng bộ: $code';
  }

  @override
  String get syncConflicts => 'Xung đột đồng bộ';

  @override
  String remoteChangedAt(String time) {
    return 'Máy chủ đã thay đổi: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Chỉnh sửa cục bộ: $summary';
  }

  @override
  String get conflictResolutionFailed => 'Không thể giải quyết xung đột.';

  @override
  String get recurringEventScope => 'Phạm vi sự kiện lặp lại';

  @override
  String get entireSeries => 'Toàn bộ chuỗi';

  @override
  String get singleOccurrence => 'Sự kiện này';

  @override
  String get thisAndFollowingEvents => 'Sự kiện này và các sự kiện tiếp theo';

  @override
  String get thisAndFutureUnavailable => 'Nhà cung cấp này không hỗ trợ.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Không thể di chuyển an toàn sự kiện này và các sự kiện tiếp theo. Hãy chọn sự kiện này hoặc toàn bộ chuỗi.';

  @override
  String get entireSeriesMoveUnavailable =>
      'Quy tắc lặp lại không có sẵn trên thiết bị. Hãy chỉ di chuyển sự kiện này.';

  @override
  String get copyEventAndDeleteOriginal => 'Sao chép sự kiện và xóa bản gốc?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax không thể di chuyển trực tiếp sự kiện này từ $source sang $destination. Ứng dụng sẽ tạo bản sao trước và chỉ xóa bản gốc sau khi sao chép thành công. ID sự kiện sẽ thay đổi; trạng thái phản hồi của người tham dự có thể bị đặt lại và lời mời hoặc thông báo hủy có thể được gửi; liên kết cuộc họp, tệp đính kèm, lời nhắc, trường riêng của nhà cung cấp và ngoại lệ lặp lại có thể không được chuyển sang.';
  }

  @override
  String get copyAndDelete => 'Sao chép và xóa';

  @override
  String get chooseRecurringEventScope =>
      'Chọn áp dụng thay đổi này cho toàn bộ chuỗi, chỉ sự kiện này hay sự kiện này và các sự kiện tiếp theo.';

  @override
  String get taskDueBeforeStart =>
      'Hạn chót không được trước thời gian bắt đầu.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Đặt giờ cho cả thời gian bắt đầu và hạn chót, hoặc đặt công việc là cả ngày.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Xóa “$title”?';
  }

  @override
  String get setCustomCalendarName => 'Đặt tên tùy chỉnh';

  @override
  String get setAction => 'Đặt';

  @override
  String get removeFromMyCalendars => 'Xóa khỏi lịch của tôi';

  @override
  String get removeAction => 'Xóa';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Xóa “$title” khỏi danh sách Google Calendar của bạn? Lịch dùng chung và các sự kiện trong đó sẽ không bị xóa.';
  }

  @override
  String get calendarCannotRemove =>
      'Không thể xóa hoặc gỡ lịch này khỏi tài khoản.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Hãy chờ các thay đổi đang chờ của lịch này đồng bộ xong trước khi xóa hoặc gỡ lịch.';

  @override
  String get calendarSubscriptions => 'Gói đăng ký lịch';

  @override
  String get calendarSubscriptionsDescription =>
      'Thêm lịch chỉ đọc được làm mới từ URL WebCal bảo mật.';

  @override
  String get addCalendarSubscription => 'Thêm gói đăng ký lịch';

  @override
  String get subscriptionName => 'Tên cục bộ';

  @override
  String get subscriptionUrl => 'URL gói đăng ký';

  @override
  String get subscriptionUrlHelp =>
      'Nhập URL HTTPS hoặc webcal. BusyMax giữ URL đầy đủ trong bộ nhớ an toàn.';

  @override
  String get subscriptionUrlInvalid =>
      'Nhập URL HTTPS hoặc webcal hợp lệ không có thông tin người dùng hoặc phân đoạn.';

  @override
  String get subscriptionColor => 'Màu cục bộ';

  @override
  String get subscriptionColorHelp => 'Sử dụng màu sáu chữ số như #3584E4.';

  @override
  String get subscriptionColorInvalid => 'Nhập màu thập lục phân sáu chữ số.';

  @override
  String get subscriptionRefreshMode => 'Tần suất làm mới';

  @override
  String get subscriptionAutomatic => 'Tự động';

  @override
  String get subscriptionHourly => 'Hàng giờ';

  @override
  String get subscriptionSixHours => 'Mỗi sáu giờ';

  @override
  String get subscriptionDaily => 'Hàng ngày';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Nguồn: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Nhập URL hợp lệ để xem trước nguồn an toàn.';

  @override
  String get subscriptionReadOnly => 'Gói đăng ký chỉ đọc';

  @override
  String get subscriptionNeverRefreshed => 'Chưa làm mới';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Lần làm mới thành công gần nhất: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Lần làm mới tiếp theo: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Đã cập nhật';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Sự cố làm mới: $code';
  }

  @override
  String get refreshNow => 'Làm mới ngay';

  @override
  String get unsubscribe => 'Hủy đăng ký';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Hủy đăng ký “$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Thao tác này xóa gói đăng ký cục bộ và các sự kiện đã lưu trong bộ nhớ đệm. Lịch đã xuất bản không thay đổi.';

  @override
  String get addSubscriptionAction => 'Thêm gói đăng ký';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Gói đăng ký lịch không thành công: $error';
  }

  @override
  String get subscriptions => 'Gói đăng ký';

  @override
  String get calendarImport => 'Nhập lịch';

  @override
  String get calendarImportDescription =>
      'Chọn tệp, xem lại các sự kiện rồi chọn lịch có thể ghi để nhận chúng.';

  @override
  String get importIcsFile => 'Nhập tệp .ics';

  @override
  String get importIcsPreview => 'Nhập sự kiện lịch';

  @override
  String importEventsFound(int count) {
    return 'Bộ sự kiện có thể nhập: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Sự kiện không hợp lệ: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Cố ý bỏ qua: $fields';
  }

  @override
  String get noWritableCalendars => 'Không có lịch đích có thể ghi.';

  @override
  String get importDestinationCalendar => 'Lịch đích';

  @override
  String get importIcsConfirm => 'Nhập sự kiện';

  @override
  String get importIcsComplete => 'Đã nhập xong';

  @override
  String importQueued(int count) {
    return 'Đã nhập hoặc xếp hàng: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Đã bỏ qua bản sao: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Bộ lặp lại không được hỗ trợ: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Không thể nhập tệp lịch: $error';
  }

  @override
  String get networkOffline => 'Ngoại tuyến';

  @override
  String get networkOfflineDescription =>
      'Các thay đổi sẽ được đồng bộ khi kết nối được khôi phục.';

  @override
  String get networkOfflineTryAgain =>
      'Bạn đang ngoại tuyến. Hãy kết nối Internet rồi thử lại.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'vào các ngày $days trong tháng';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first và $second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first và $second';
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
    return '$first và $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first và $second';
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
    return '$frequency vào ngày $day $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency vào các ngày $days của $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency vào ngày $day của $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency vào các ngày $days của $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'đầu tiên',
      'second': 'thứ hai',
      'third': 'thứ ba',
      'fourth': 'thứ tư',
      'fifth': 'thứ năm',
      'secondToLast': 'áp chót',
      'last': 'cuối cùng',
      'other': '',
    });
    return '$frequency vào $days $_temp0 của $month';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'đầu tiên',
      'second': 'thứ hai',
      'third': 'thứ ba',
      'fourth': 'thứ tư',
      'fifth': 'thứ năm',
      'secondToLast': 'áp chót',
      'last': 'cuối cùng',
      'other': '',
    });
    return '$frequency vào $days $_temp0 của $months';
  }
}

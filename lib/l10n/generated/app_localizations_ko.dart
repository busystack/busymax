// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Google, Microsoft, Apple iCloud Calendar 또는 Nextcloud 계정을 연결하세요.';

  @override
  String get googlePermissionsConsentNotice =>
      'Google 권한 화면에서 캘린더와 할 일 권한을 모두 선택하세요.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google Calendar 및 Google Tasks 권한이 필요합니다. 다시 시도하여 두 체크박스를 모두 선택하세요.';

  @override
  String get finishSetup => '설정 완료';

  @override
  String get continueSetup => '계속';

  @override
  String get onboardingSetupTitle => 'BusyMax 설정';

  @override
  String get onboardingAccountsStepTitle => '계정 연결';

  @override
  String get onboardingAccountsStepDescription =>
      '사용할 모든 계정을 추가하세요. BusyMax는 각 계정의 지원되는 캘린더, 일정, 할 일 목록 및 할 일을 동기화합니다.';

  @override
  String get onboardingPreferencesStepTitle => '시스템 설정 선택';

  @override
  String get onboardingPreferencesStepDescription =>
      '일정을 열기 전에 데스크톱 동작, 미리 알림, 알림 세부 수준 및 화면 모양을 설정하세요.';

  @override
  String get signInWithGoogle => 'Google로 로그인';

  @override
  String get signInWithMicrosoft => 'Microsoft로 로그인';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => '이 서비스는 설정되어 있지 않습니다.';

  @override
  String get waitingForGoogleSignIn => 'Google 로그인을 기다리는 중...';

  @override
  String get waitingForMicrosoftSignIn => 'Microsoft 로그인을 기다리는 중...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsoft 로그인이 구성되지 않았습니다. MICROSOFT_OAUTH_CLIENT_ID를 설정하세요.';

  @override
  String get cancel => '취소';

  @override
  String get close => '닫기';

  @override
  String get exit => '종료';

  @override
  String get options => '옵션';

  @override
  String get hide => '숨기기';

  @override
  String get show => '표시';

  @override
  String get export => '내보내기';

  @override
  String get save => '저장';

  @override
  String get settings => '설정';

  @override
  String get all => '모두';

  @override
  String get calendarEvents => '일정';

  @override
  String get calendarTasks => '할 일';

  @override
  String get calendar => '캘린더';

  @override
  String get calendars => '캘린더';

  @override
  String get newCalendar => '새 캘린더';

  @override
  String get calendarColor => '캘린더 색상';

  @override
  String calendarColorOption(int number) {
    return '색상 $number';
  }

  @override
  String get calendarManagementUnsupported =>
      '이 공급자는 BusyMax에서 캘린더 관리를 지원하지 않습니다.';

  @override
  String get primaryCalendarCannotDelete => '기본 캘린더는 삭제할 수 없습니다.';

  @override
  String calendarCreateFailed(String error) {
    return '캘린더를 만들 수 없습니다: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      '캘린더가 생성되었지만 BusyMax에서 계정을 새로 고치지 못했습니다. 다음 동기화 후에 표시됩니다.';

  @override
  String calendarUpdateFailed(String error) {
    return '캘린더를 업데이트할 수 없습니다: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return '캘린더를 삭제할 수 없습니다: $error';
  }

  @override
  String get newEvent => '새 일정';

  @override
  String get refreshCalendar => '캘린더 새로 고침';

  @override
  String get openInProvider => '서비스에서 열기';

  @override
  String get hideFromSchedule => '일정에서 숨기기';

  @override
  String get showInSchedule => '일정에 표시';

  @override
  String get noCalendarsSynced => '아직 동기화된 캘린더가 없습니다.';

  @override
  String get allDay => '하루 종일';

  @override
  String moreItems(int count) {
    return '+$count개 더 보기';
  }

  @override
  String get noEventsOrTasks => '일정 또는 할 일이 없습니다';

  @override
  String get scheduleLoading => '일정을 불러오는 중...';

  @override
  String get scheduleUnavailable => '일정을 사용할 수 없습니다';

  @override
  String get scheduleNoSources => '표시할 캘린더 또는 할 일 목록이 없습니다';

  @override
  String get scheduleNoSourcesDescription => '설정에서 표시할 항목을 선택한 다음 새로 고침하세요.';

  @override
  String get scheduleSignInRequired => '계정 연결';

  @override
  String get scheduleSignInDescription => '캘린더와 할 일을 동기화하려면 로그인하세요.';

  @override
  String get scheduleNoSearchResults => '일치하는 일정 또는 할 일이 없습니다';

  @override
  String get scheduleNoSearchResultsDescription => '다른 검색어를 사용하거나 현재 필터를 지우세요.';

  @override
  String get refresh => '새로 고침';

  @override
  String get trayOpenBusyMax => 'BusyMax 열기';

  @override
  String get trayShowBusyMax => 'BusyMax 표시';

  @override
  String get trayNewEvent => '새 일정…';

  @override
  String get trayNewTask => '새 할 일…';

  @override
  String get trayToday => '오늘';

  @override
  String get trayAllDay => '종일';

  @override
  String get trayNow => '지금';

  @override
  String get trayCalendarEvent => '캘린더 일정';

  @override
  String get trayUntitledEvent => '제목 없는 일정';

  @override
  String get trayNothingElseToday => '오늘은 더 이상 없음';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오늘 마감인 할 일 $count개',
      one: '오늘 마감인 할 일 1개',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => '오늘 일정 열기';

  @override
  String get traySyncNow => '지금 동기화';

  @override
  String get traySyncing => '동기화 중…';

  @override
  String get trayNotConnected => '연결되지 않음';

  @override
  String get trayNotYetSynced => '아직 동기화되지 않음';

  @override
  String get trayLastSyncedJustNow => '방금 동기화됨';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 전에 동기화됨',
      one: '1분 전에 동기화됨',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 전에 동기화됨',
      one: '1시간 전에 동기화됨',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 전에 동기화됨',
      one: '1일 전에 동기화됨',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => '설정';

  @override
  String get trayQuitBusyMax => 'BusyMax 종료';

  @override
  String get agendaLoadMoreOverdue => '기한이 지난 할 일 더 불러오기';

  @override
  String get agendaLoadMoreNoDate => '날짜 없는 할 일 더 불러오기';

  @override
  String get viewDay => '일';

  @override
  String get viewWeek => '주';

  @override
  String get viewMonth => '월';

  @override
  String get viewYear => '년';

  @override
  String get viewAgenda => '일정 목록';

  @override
  String get scheduleSettings => '일정';

  @override
  String get scheduleDisplaySettings => '일정 표시';

  @override
  String get scheduleDisplayHoursDescription =>
      '일간 및 주간 보기는 처음에 이 시간 범위를 표시합니다. 필요한 경우 더 이르거나 늦은 항목에 맞춰 범위가 확장됩니다.';

  @override
  String get scheduleDayStartsAt => '하루 시작 시간';

  @override
  String get scheduleDayEndsAt => '하루 종료 시간';

  @override
  String get sourceCalendar => '캘린더';

  @override
  String get sourceTaskList => '할 일 목록';

  @override
  String get createChoiceTitle => '만들기';

  @override
  String get createEventAtTime => '일정';

  @override
  String get createTaskAtDate => '할 일';

  @override
  String get editEvent => '일정 편집';

  @override
  String get eventTitle => '일정 제목';

  @override
  String get location => '위치';

  @override
  String get timeSlot => '시간대';

  @override
  String get startDateTime => '시작 날짜/시간';

  @override
  String get endDateTime => '종료 날짜/시간';

  @override
  String get doesNotRepeat => '반복 안 함';

  @override
  String get defaultReminder => '기본 미리 알림';

  @override
  String get guests => '참석자';

  @override
  String get noGuests => '게스트 없음';

  @override
  String get attendeeRequired => '필수';

  @override
  String get attendeeOptional => '선택사항';

  @override
  String get meetingSection => '회의';

  @override
  String get addGoogleMeet => 'Google Meet 추가';

  @override
  String get addTeamsMeeting => 'Microsoft Teams 회의 추가';

  @override
  String get onlineMeetingAdded => '온라인 회의가 추가됨';

  @override
  String get requestResponses => '응답 요청';

  @override
  String get requestResponsesDescription => '게스트에게 초대에 응답하도록 요청합니다.';

  @override
  String get hideGuestList => '게스트 목록 숨기기';

  @override
  String get hideGuestListDescription => '게스트는 다른 초대 대상자를 볼 수 없습니다.';

  @override
  String get allowNewTimeProposals => '새 시간 제안 허용';

  @override
  String get allowNewTimeProposalsDescription => '게스트가 다른 회의 시간을 제안할 수 있습니다.';

  @override
  String get notifyGuestsTitle => '게스트에게 알릴까요?';

  @override
  String get notifyGuestsSaveMessage =>
      '이 회의에는 게스트가 있습니다. 저장할 때 초대 또는 일정 업데이트를 보낼까요?';

  @override
  String get notifyGuestsDeleteMessage => '이 회의에는 게스트가 있습니다. 삭제할 때 취소를 보낼까요?';

  @override
  String get sendUpdates => '업데이트 보내기';

  @override
  String get sendCancellation => '취소 보내기';

  @override
  String get doNotSend => '보내지 않음';

  @override
  String get microsoftNotifyGuestsSaveTitle => '회의를 저장할까요?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft에서 게스트에게 초대 또는 일정 업데이트를 보냅니다.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => '회의를 삭제할까요?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft에서 게스트에게 취소를 보냅니다.';

  @override
  String get organizer => '주최자';

  @override
  String get yourResponse => '내 응답';

  @override
  String get guestResponses => '게스트 응답';

  @override
  String get respond => '응답';

  @override
  String get acceptInvitation => '수락';

  @override
  String get tentativeInvitation => '미정';

  @override
  String get declineInvitation => '거절';

  @override
  String get joinMeeting => '회의 참가';

  @override
  String get responseAccepted => '수락됨';

  @override
  String get responseTentative => '미정';

  @override
  String get responseDeclined => '거절됨';

  @override
  String get responseNeedsAction => '응답 대기 중';

  @override
  String get responseNotResponded => '응답하지 않음';

  @override
  String get responseOrganizer => '주최자';

  @override
  String invitationResponseFailed(String error) {
    return '응답을 보낼 수 없습니다: $error';
  }

  @override
  String get joinMeetingFailed => '회의 링크를 열 수 없습니다.';

  @override
  String get description => '설명';

  @override
  String get availabilityShowAs => '일정 상태 / 표시 방식';

  @override
  String get busy => '바쁨';

  @override
  String get visibility => '공개 범위';

  @override
  String get defaultVisibility => '기본 공개 범위';

  @override
  String get conference => '회의';

  @override
  String get noConference => '회의 없음';

  @override
  String get providerCalendar => '서비스 캘린더';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => '굵게';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => '기울임꼴';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => '밑줄';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분 전',
      one: '1분 전',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => '시작 시';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간 전',
      one: '1시간 전',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일 전',
      one: '1일 전',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => '한가함';

  @override
  String get availabilityTentative => '미정';

  @override
  String get availabilityOutOfOffice => '부재중';

  @override
  String get availabilityWorkingElsewhere => '다른 장소에서 근무';

  @override
  String get visibilityDefault => '기본값';

  @override
  String get visibilityPublic => '공개';

  @override
  String get visibilityPrivate => '비공개';

  @override
  String get visibilityConfidential => '기밀';

  @override
  String get sensitivityNormal => '일반';

  @override
  String get sensitivityPersonal => '개인';

  @override
  String get tasks => '할 일';

  @override
  String get allTasks => '모든 할 일';

  @override
  String tasksInList(String title) {
    return '$title의 할 일';
  }

  @override
  String get taskLists => '할 일 목록';

  @override
  String get navigation => '탐색';

  @override
  String get mainMenu => '주 메뉴';

  @override
  String get keyboardShortcuts => '키보드 단축키';

  @override
  String get shortcutGroupGeneral => '일반';

  @override
  String get shortcutKeyboardShortcutsDescription => '이 단축키 도움말 표시';

  @override
  String get shortcutGroupNavigation => '탐색';

  @override
  String get shortcutNextPeriod => '다음 기간';

  @override
  String get shortcutNextPeriodDescription =>
      '주간 보기에서는 다음 주, 월간 보기에서는 다음 달로 이동하는 식입니다';

  @override
  String get shortcutPreviousPeriod => '이전 기간';

  @override
  String get shortcutPreviousPeriodDescription =>
      '주간 보기에서는 이전 주, 월간 보기에서는 이전 달로 이동하는 식입니다';

  @override
  String get shortcutJumpToToday => '오늘로 이동';

  @override
  String get shortcutGroupView => '보기';

  @override
  String get shortcutDayView => '일간 보기';

  @override
  String get shortcutWeekView => '주간 보기';

  @override
  String get shortcutMonthView => '월간 보기';

  @override
  String get shortcutYearView => '연간 보기';

  @override
  String get shortcutAgendaView => '일정 목록 보기';

  @override
  String get shortcutGroupCreateAndEdit => '만들기 및 편집';

  @override
  String get shortcutSaveItem => '일정 또는 할 일 저장';

  @override
  String get shortcutDeleteItem => '일정 또는 할 일 삭제';

  @override
  String get shortcutGroupTaskEditing => '할 일 편집';

  @override
  String get shortcutCancelEditing => '편집 취소';

  @override
  String get shortcutCancelEditingDescription => '할 일 편집 또는 할 일 세부 정보 닫기';

  @override
  String get aboutBusyMax => 'BusyMax 정보';

  @override
  String get aboutBusyMaxDescription => '캘린더와 할 일';

  @override
  String get license => '라이선스';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => '웹사이트';

  @override
  String get sourceCode => '소스 코드';

  @override
  String get reportAnIssue => '문제 신고';

  @override
  String get sendFeedback => '의견 보내기';

  @override
  String get feedbackSubmit => '제출';

  @override
  String get feedbackCategory => '범주';

  @override
  String get feedbackSelectCategory => '범주 선택';

  @override
  String get feedbackCategoryProblem => '문제 또는 버그';

  @override
  String get feedbackCategoryFeature => '기능 요청';

  @override
  String get feedbackCategoryPrivacySecurity => '개인정보 보호 또는 보안 우려';

  @override
  String get feedbackCategoryUsability => '사용 편의성 문제';

  @override
  String get feedbackCategoryOther => '기타';

  @override
  String get feedbackSubject => '제목';

  @override
  String get feedbackDetailedMessage => '자세한 내용';

  @override
  String get feedbackReplyEmail => '답변 받을 이메일 주소(선택 사항)';

  @override
  String get feedbackIncludeTechnicalDetails => '기술 세부 정보 포함';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Linux 운영 체제 버전과 앱 로캘만 추가됩니다. 로그, 계정 데이터, 파일 이름 또는 기타 진단 정보는 포함되지 않습니다.';

  @override
  String get feedbackCategoryRequired => '범주를 선택하세요.';

  @override
  String get feedbackSubjectLengthError => '제목은 3~120자여야 합니다.';

  @override
  String get feedbackMessageLengthError => '메시지는 10~5,000자여야 합니다.';

  @override
  String get feedbackInvalidEmail => '올바른 이메일 주소를 입력하세요.';

  @override
  String get feedbackConnectionError =>
      'BusyStack에 연결할 수 없습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get feedbackTimeoutError =>
      '요청 시간이 초과되었습니다. 의견은 지워지지 않았습니다. 다시 시도하세요.';

  @override
  String get feedbackRateLimitedError =>
      '이 네트워크에서 너무 많은 의견이 제출되었습니다. 잠시 기다린 후 다시 시도하세요.';

  @override
  String get feedbackRejectedError => '서버가 제출을 거부했습니다. 입력란을 검토하고 다시 시도하세요.';

  @override
  String get feedbackServerError =>
      '현재 BusyStack에서 의견을 받을 수 없습니다. 의견은 지워지지 않았습니다. 다시 시도하세요.';

  @override
  String feedbackSuccess(String id) {
    return '의견을 보냈습니다. 참조: $id';
  }

  @override
  String get toggleSidebar => '사이드바 표시 전환';

  @override
  String get showSidebar => '사이드바 패널 표시';

  @override
  String get hideSidebar => '사이드바 패널 숨기기';

  @override
  String get accounts => '계정';

  @override
  String get currentAccount => '현재 계정';

  @override
  String get switchAccount => '계정 전환';

  @override
  String get addGoogleAccount => 'Google 계정 추가';

  @override
  String get addMicrosoftAccount => 'Microsoft 계정 추가';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => '로그인됨';

  @override
  String get removeAccount => '계정 삭제…';

  @override
  String get removingAccount => '계정 삭제 중…';

  @override
  String get removeAccountDescription => '동기화를 중지하고 이 기기에서 이 계정의 데이터를 삭제합니다.';

  @override
  String removeAccountTitle(String account) {
    return '$account을(를) BusyMax에서 삭제할까요?';
  }

  @override
  String get removeAccountConfirmation =>
      '이 작업은 이 기기에서 캐시된 할 일, 캘린더, 일정, 알림 및 보류 중인 오프라인 변경사항을 삭제합니다. 동기화되지 않은 변경사항은 손실됩니다. 제공업체의 캘린더, 일정, 할 일 목록 및 할 일 사본은 삭제되지 않습니다.';

  @override
  String get revokeGoogleAccess => '이 Google 계정에 대한 BusyMax의 액세스 권한도 취소';

  @override
  String get revokeGoogleAccessDescription => '다시 연결하기 전에 액세스 권한을 다시 부여해야 합니다.';

  @override
  String get removeAccountAction => '계정 삭제';

  @override
  String get removeAccountFailed => '계정 삭제를 완료할 수 없습니다. 다시 시도하세요.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      '계정은 이 기기에서 삭제되었지만 BusyMax가 Google 계정 액세스 권한을 취소하지 못했습니다. Google 계정에서 직접 취소할 수 있습니다.';

  @override
  String get newTaskList => '새 할 일 목록';

  @override
  String taskListCreateFailed(String error) {
    return '할 일 목록을 만들 수 없습니다: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return '할 일 목록 이름을 바꿀 수 없습니다: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return '할 일 목록을 삭제할 수 없습니다: $error';
  }

  @override
  String get signInToViewTaskLists => '할 일 목록을 보려면 로그인하세요.';

  @override
  String get noTaskListsSynced => '아직 동기화된 할 일 목록이 없습니다.';

  @override
  String get listActions => '목록 작업';

  @override
  String get rename => '이름 바꾸기';

  @override
  String get delete => '삭제';

  @override
  String get renameList => '목록 이름 바꾸기';

  @override
  String get deleteList => '목록 삭제';

  @override
  String get unshare => '공유 해제';

  @override
  String get readOnlyTaskListCannotRename =>
      '이 할 일 목록은 읽기 전용이므로 이름을 바꿀 수 없습니다.';

  @override
  String get taskListCannotDelete => '현재 권한으로는 이 할 일 목록을 삭제할 수 없습니다.';

  @override
  String get builtInMicrosoftList => '기본 제공';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Microsoft To Do의 기본 제공 목록은 이름을 바꾸거나 삭제할 수 없습니다.';

  @override
  String deleteListConfirmation(String title) {
    return 'Google Tasks에서 “$title”을(를) 삭제할까요?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '“$title” 및 모든 할 일을 삭제할까요?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return '이 계정에서 “$title” 공유를 해제할까요?';
  }

  @override
  String get deleteEvent => '일정 삭제';

  @override
  String get title => '제목';

  @override
  String get create => '만들기';

  @override
  String get newTask => '새 할 일';

  @override
  String get clearCompleted => '완료된 항목 지우기';

  @override
  String get refreshList => '목록 새로 고침';

  @override
  String get refreshAll => '모두 새로 고침';

  @override
  String get listRefreshed => '목록을 새로 고쳤습니다.';

  @override
  String get allTasksRefreshed => '모든 계정을 새로 고쳤습니다.';

  @override
  String exportedFile(String path) {
    return '$path에 내보냈습니다';
  }

  @override
  String exportFailed(String error) {
    return '내보내기 실패: $error';
  }

  @override
  String refreshFailed(String error) {
    return '새로 고침 실패: $error';
  }

  @override
  String get selectOrCreateTaskList => '시작하려면 할 일 목록을 선택하거나 만드세요.';

  @override
  String get signInToViewTasks => '할 일을 보려면 로그인하세요.';

  @override
  String get noTasks => '할 일이 없습니다.';

  @override
  String get noTasksYet => '아직 할 일이 없습니다';

  @override
  String get noTasksYetMessage => '할 일을 만들거나 계정을 새로 고쳐 시작하세요.';

  @override
  String get noTasksInList => '이 목록에 할 일이 없습니다.';

  @override
  String get overdue => '기한 지남';

  @override
  String get today => '오늘';

  @override
  String get tomorrow => '내일';

  @override
  String get upcoming => '예정';

  @override
  String get noDate => '날짜 없음';

  @override
  String get completed => '완료';

  @override
  String duePrefix(String date) {
    return '$date 마감';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => '할 일 세부 정보';

  @override
  String get editTask => '할 일 편집';

  @override
  String get noTaskSelected => '선택된 할 일이 없습니다.';

  @override
  String get noTaskSelectedHelper => '세부 정보를 보고 편집할 할 일을 선택하세요.';

  @override
  String get taskUnavailable => '할 일을 사용할 수 없습니다.';

  @override
  String get signInToEditTasks => '할 일을 편집하려면 로그인하세요.';

  @override
  String get refreshTask => '할 일 새로 고침';

  @override
  String get primarySection => '기본';

  @override
  String get statusSection => '상태';

  @override
  String get openStatus => '미완료';

  @override
  String get doneStatus => '완료';

  @override
  String get taskStatus => '상태';

  @override
  String get taskStatusNone => '상태 없음';

  @override
  String get taskStatusNeedsAction => '조치 필요';

  @override
  String get taskStatusInProcess => '진행 중';

  @override
  String get taskStatusCompleted => '완료';

  @override
  String get taskStatusCancelled => '취소됨';

  @override
  String completionPercent(int percent) {
    return '$percent% 완료';
  }

  @override
  String get completionDate => '완료 날짜';

  @override
  String get priority => '우선순위';

  @override
  String get priorityNone => '우선순위 없음';

  @override
  String priorityHighValue(int priority) {
    return '우선순위 $priority · 높음';
  }

  @override
  String priorityMediumValue(int priority) {
    return '우선순위 $priority · 중간';
  }

  @override
  String priorityLowValue(int priority) {
    return '우선순위 $priority · 낮음';
  }

  @override
  String get taskUrl => '할 일 URL';

  @override
  String get invalidTaskUrl => '스킴을 포함한 절대 URL을 입력하세요.';

  @override
  String get classification => '분류';

  @override
  String get classificationPublic => '공유할 때 전체 할 일 표시';

  @override
  String get classificationConfidential => '공유할 때 바쁨 상태만 표시';

  @override
  String get classificationPrivate => '공유할 때 이 할 일 숨기기';

  @override
  String get pinTask => '할 일 고정';

  @override
  String get notes => '메모';

  @override
  String get dueDate => '마감일';

  @override
  String get clearDueDate => '마감일 지우기';

  @override
  String get dueTime => '마감 시간';

  @override
  String get startDate => '시작일';

  @override
  String get startTime => '시작 시간';

  @override
  String get endDate => '종료일';

  @override
  String get endTime => '종료 시간';

  @override
  String get reminderDate => '미리 알림 날짜';

  @override
  String get reminderTime => '미리 알림 시간';

  @override
  String get reminder => '미리 알림';

  @override
  String get addReminder => '알림 추가';

  @override
  String get reminders => '알림';

  @override
  String get noReminders => '알림 없음';

  @override
  String get editReminder => '알림 수정';

  @override
  String get beforeTaskStarts => '할 일 시작 전';

  @override
  String get beforeTaskDue => '할 일 마감 전';

  @override
  String get afterTaskStarts => '할 일 시작 후';

  @override
  String get afterTaskDue => '할 일 마감 후';

  @override
  String get relativeToTaskStart => '할 일 시작일 기준';

  @override
  String get relativeToTaskDue => '할 일 마감일 기준';

  @override
  String get reminderTimeOfDay => '시간';

  @override
  String get absoluteReminder => '날짜 및 시간에';

  @override
  String get reminderAmount => '수량';

  @override
  String get reminderUnit => '단위';

  @override
  String get reminderUnitSeconds => '초';

  @override
  String get reminderUnitMinutes => '분';

  @override
  String get reminderUnitHours => '시간';

  @override
  String get reminderUnitDays => '일';

  @override
  String get reminderUnitWeeks => '주';

  @override
  String get reminderAtTaskStart => '할 일 시작 시';

  @override
  String get reminderAtTaskDue => '할 일 마감 시';

  @override
  String get unsupportedReminder => '이 알림 유형은 유지되지만 시간을 수정할 수 없습니다.';

  @override
  String get relatedRemindersTitle => '관련 알림을 유지할까요?';

  @override
  String relatedRemindersDescription(int count) {
    return '이 날짜에 관련 알림이 $count개 있습니다. 현재 날짜와 시간에 유지할까요?';
  }

  @override
  String get discardRelatedReminders => '알림 삭제';

  @override
  String get keepRelatedReminders => '알림 유지';

  @override
  String get addGuest => '참석자 추가';

  @override
  String get addGuestEmail => '참석자 이메일 추가';

  @override
  String get removeReminder => '미리 알림 삭제';

  @override
  String get off => '끔';

  @override
  String get repeat => '반복';

  @override
  String get repeatNone => '없음';

  @override
  String get noneValue => '없음';

  @override
  String get repeatDaily => '매일';

  @override
  String get repeatWeekly => '매주';

  @override
  String get repeatMonthly => '매월';

  @override
  String get repeatYearly => '매년';

  @override
  String get repeatEvery => '반복 간격';

  @override
  String get repeatOn => '반복 요일';

  @override
  String get repeatEnd => '반복 종료';

  @override
  String get repeatNever => '안 함';

  @override
  String get repeatUntil => '날짜까지';

  @override
  String get repeatAfter => '지정한 횟수 후';

  @override
  String get repeatCount => '반복 횟수';

  @override
  String get repeatDayOfMonth => '월의 날짜';

  @override
  String get repeatMonths => '월';

  @override
  String get repeatOrdinal => '요일 순서';

  @override
  String get repeatSpecificDays => '특정 요일';

  @override
  String get repeatFirst => '첫 번째';

  @override
  String get repeatSecond => '두 번째';

  @override
  String get repeatThird => '세 번째';

  @override
  String get repeatFourth => '네 번째';

  @override
  String get repeatFifth => '다섯 번째';

  @override
  String get repeatSecondToLast => '끝에서 두 번째';

  @override
  String get repeatLast => '마지막';

  @override
  String get repeatAnyDay => '요일';

  @override
  String get repeatWeekday => '평일';

  @override
  String get repeatWeekendDay => '주말';

  @override
  String repeatEveryDays(int count) {
    return '$count일마다';
  }

  @override
  String repeatEveryWeeks(int count) {
    return '$count주마다';
  }

  @override
  String repeatEveryMonths(int count) {
    return '$count개월마다';
  }

  @override
  String repeatEveryYears(int count) {
    return '$count년마다';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '$days에';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '매월 $days일';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '첫 번째 $days',
      'second': '두 번째 $days',
      'third': '세 번째 $days',
      'fourth': '네 번째 $days',
      'fifth': '다섯 번째 $days',
      'secondToLast': '끝에서 두 번째 $days',
      'last': '마지막 $days',
      'other': '$days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return '$months에';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count회';
  }

  @override
  String repeatUntilSummary(String date) {
    return '$date까지';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      '이 반복 규칙에는 이 편집기에서 변경하지 않는 옵션이 사용됩니다.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return '이 반복은 $provider에서 사용할 수 없습니다.';
  }

  @override
  String get importance => '중요도';

  @override
  String get importanceLow => '낮음';

  @override
  String get importanceNormal => '보통';

  @override
  String get importanceHigh => '높음';

  @override
  String get categories => '범주';

  @override
  String get scheduleSection => '일정';

  @override
  String get dueGroup => '마감';

  @override
  String get startGroup => '시작';

  @override
  String get reminderGroup => '미리 알림';

  @override
  String get organizationSection => '구성';

  @override
  String get actionsSection => '작업';

  @override
  String get advancedSection => '고급';

  @override
  String get addCategory => '범주 추가';

  @override
  String get list => '목록';

  @override
  String get microsoftMoveUnsupported =>
      '이 버전에서는 Microsoft To Do 계정의 목록 간에 할 일을 이동할 수 없습니다.';

  @override
  String get createSubtask => '하위 할 일 만들기';

  @override
  String get subtasks => '하위 할 일';

  @override
  String get duplicateTask => '할 일 복제';

  @override
  String get taskDuplicated => '할 일이 복제되었습니다.';

  @override
  String taskDuplicateFailed(String error) {
    return '할 일을 복제할 수 없습니다: $error';
  }

  @override
  String get hideSubtasks => '하위 할 일 숨기기';

  @override
  String get hideClosedSubtasks => '완료된 하위 할 일 숨기기';

  @override
  String get moveToTop => '맨 위로 이동';

  @override
  String get deleteTask => '할 일 삭제';

  @override
  String get newSubtask => '새 하위 할 일';

  @override
  String deleteTaskConfirmation(String title) {
    return '“$title” 항목을 삭제할까요?';
  }

  @override
  String get metadata => '메타데이터';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => '업데이트됨';

  @override
  String get parent => '상위 할 일';

  @override
  String get position => '위치';

  @override
  String get webLink => '웹 링크';

  @override
  String get assignment => '할당';

  @override
  String get localState => '로컬 상태';

  @override
  String get pendingSync => '동기화 보류 중';

  @override
  String get synced => '동기화됨';

  @override
  String get account => '계정';

  @override
  String get sync => '동기화';

  @override
  String get manualFullSync => '수동 전체 동기화';

  @override
  String get runInBackgroundWhenClosed => '창을 닫아도 계속 실행';

  @override
  String get showTrayIcon => '트레이 아이콘 표시';

  @override
  String get startMinimizedToTray => '트레이에 최소화하여 시작';

  @override
  String get launchAtLogin => '로그인할 때 실행';

  @override
  String get launchAtLoginDescription =>
      '로그인 후에도 미리 알림이 작동하도록 BusyMax를 백그라운드에서 실행합니다.';

  @override
  String get launchAtLoginFailed => '로그인 시 실행 설정을 업데이트할 수 없습니다.';

  @override
  String get requiresTrayIcon => '트레이 아이콘이 필요합니다.';

  @override
  String get syncComplete => '동기화가 완료되었습니다.';

  @override
  String syncFailed(String error) {
    return '동기화 실패: $error';
  }

  @override
  String get notifySyncFailures => '동기화 실패 알림';

  @override
  String get notifyConflicts => '충돌 알림';

  @override
  String get notifyDueToday => '오늘 마감인 할 일 알림';

  @override
  String get eventReminders => '일정 미리 알림';

  @override
  String get onState => '켬';

  @override
  String get taskReminders => '할 일 미리 알림';

  @override
  String get notificationDetailLevel => '알림 세부 수준';

  @override
  String get notificationDetailPrivate => '비공개';

  @override
  String get notificationDetailNormal => '일반';

  @override
  String get quietHours => '방해 금지 시간';

  @override
  String get quietHoursDescription => '이 시간 동안 알림을 일시 중지합니다.';

  @override
  String get quietHoursStart => '방해 금지 시작 시간';

  @override
  String get quietHoursEnd => '방해 금지 종료 시간';

  @override
  String get notifications => '알림';

  @override
  String get appearance => '화면 모양';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get themeFamily => '테마 계열';

  @override
  String get themeFamilyYaru => 'Ubuntu 기본 테마(Yaru)';

  @override
  String get localization => '언어 및 지역';

  @override
  String get currentLocale => '현재 로캘';

  @override
  String get privacy => '개인정보 보호';

  @override
  String get redactTaskContentInDiagnostics => '진단 정보에서 할 일 내용 숨기기';

  @override
  String get developerDiagnostics => '개발자 진단';

  @override
  String get diagnostics => '진단';

  @override
  String get apiInspectorDisabled => 'API 검사기 표시';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery 리비전: $revision';
  }

  @override
  String get implementedMethods => '구현된 메서드';

  @override
  String get supportsTasksScopes => 'tasks 및 tasks.readonly 범위 지원';

  @override
  String get requiresTasksScope => 'tasks 범위 필요';

  @override
  String get blockedPendingOperations => '차단된 보류 작업';

  @override
  String get signInToInspectPendingOperations => '보류 작업을 확인하려면 로그인하세요.';

  @override
  String get noBlockedPendingOperations => '차단된 보류 작업이 없습니다.';

  @override
  String get operationActions => '작업별 조치';

  @override
  String pendingOpListId(String id) {
    return '목록=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return '할 일=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return '시도=$count';
  }

  @override
  String get retry => '다시 시도';

  @override
  String get discard => '버리기';

  @override
  String get discardChangesAction => '변경 사항 버리기';

  @override
  String get discardChanges => '변경 사항을 버릴까요?';

  @override
  String get discardChangesConfirmation => '이 할 일에서 저장하지 않은 편집 내용을 버립니다.';

  @override
  String get retryCompleted => '다시 시도했습니다.';

  @override
  String get discardPendingOperation => '보류 작업을 버릴까요?';

  @override
  String get discardPendingOperationConfirmation =>
      '차단된 로컬 작업을 삭제합니다. 다음 동기화에서 Google Tasks의 데이터를 새로 불러옵니다.';

  @override
  String get pendingOperationDiscarded => '보류 작업을 버렸습니다.';

  @override
  String get syncFailureNotificationTitle => 'BusyMax 동기화 실패';

  @override
  String syncFailureNotificationBody(String message) {
    return '백그라운드 동기화에 실패했습니다. $message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax 동기화 충돌';

  @override
  String conflictNotificationBody(String summary) {
    return '보류 중인 로컬 변경사항이 차단되었습니다. $summary';
  }

  @override
  String get dueTodayNotificationTitle => '오늘 마감인 할 일';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오늘 마감인 할 일이 $count개 있습니다.',
      one: '오늘 마감인 할 일이 1개 있습니다.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => '일정 미리 알림';

  @override
  String get taskReminderNotificationTitle => '할 일 미리 알림';

  @override
  String get eventReminderNotificationBody => '일정이 곧 시작됩니다.';

  @override
  String get taskReminderNotificationBody => '할 일 마감이 얼마 남지 않았습니다.';

  @override
  String get notificationOpenAction => '열기';

  @override
  String get notificationSnoozeAction => '10분 후 다시 알림';

  @override
  String get notificationDismissAction => '닫기';

  @override
  String get notificationDetailsHidden => '개인정보 보호 설정에 따라 세부 정보가 숨겨졌습니다.';

  @override
  String get previousMonth => '이전 달';

  @override
  String get nextMonth => '다음 달';

  @override
  String get openMonthView => '월간 보기 열기';

  @override
  String get previousYear => '이전 해';

  @override
  String get nextYear => '다음 해';

  @override
  String get openYearView => '연간 보기 열기';

  @override
  String weekNumberTooltip(int number) {
    return '$number주차';
  }

  @override
  String get resizeAllDayPanel => '종일 패널 크기 조절';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '항목 $count개',
      one: '항목 1개',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => '이 캘린더는 읽기 전용입니다.';

  @override
  String get selectTimeZone => '시간대 선택';

  @override
  String get searchLocations => '위치 검색';

  @override
  String get noLocationsFound => '위치를 찾을 수 없음';

  @override
  String get requiredField => '이 필드는 필수입니다.';

  @override
  String get providerConnectionDescription => '다음 제공업체 중 하나에서 캘린더와 할 일을 연결하세요.';

  @override
  String get appleICloudProvider => 'Apple iCloud 캘린더';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud 할 일';

  @override
  String get addAppleICloudAccount => 'Apple iCloud 캘린더 계정 추가';

  @override
  String get addNextcloudAccount => 'Nextcloud 계정 추가';

  @override
  String get waitingForAppleICloud => 'Apple iCloud에 연결 중…';

  @override
  String get waitingForNextcloud => 'Nextcloud 인증 대기 중…';

  @override
  String get connectAppleICloudTitle => 'Apple iCloud 캘린더 연결';

  @override
  String get appleAccountEmail => 'Apple 계정 이메일';

  @override
  String get appleAppSpecificPassword => '앱 전용 암호';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Apple 계정에서 이중 인증을 활성화한 후 앱 전용 암호를 생성하세요.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Apple 계정 암호를 재설정하면 앱 전용 암호가 취소됩니다.';

  @override
  String get connectNextcloudTitle => 'Nextcloud 연결';

  @override
  String get nextcloudServerUrl => 'Nextcloud 서버 또는 CalDAV 주소';

  @override
  String get nextcloudServerUrlHelp =>
      'Nextcloud 서버 URL을 입력하거나 Nextcloud에서 복사한 기본 CalDAV 주소를 붙여넣으세요.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax가 브라우저를 엽니다. 그곳에서 액세스를 승인한 다음 BusyMax로 돌아오세요.';

  @override
  String get connectAccountAction => '연결';

  @override
  String get cancelAccountConnection => '연결 취소';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      '계정은 로컬에서 삭제되었지만 Nextcloud 앱 암호를 취소할 수 없습니다.';

  @override
  String get davCachedOfflineNotice => '오프라인 사용을 위해 캘린더 및 할 일 데이터가 로컬에 캐시됩니다.';

  @override
  String get davReauthenticationRequired => '동기화를 재개하려면 이 계정을 다시 연결하세요.';

  @override
  String get davTemporarilyUnavailable => '이 계정은 일시적으로 사용할 수 없습니다.';

  @override
  String get davPermissionChanged => '서버 권한이 변경되었습니다. 보류 중인 편집이 일시 중지되었습니다.';

  @override
  String get davUnsupportedServer => '이 서버 또는 제공업체 프로필은 지원되지 않습니다.';

  @override
  String get collectionSettings => '캘린더 및 할 일 목록';

  @override
  String get calendarContent => '캘린더 일정';

  @override
  String get taskContent => '할 일';

  @override
  String get readOnlySharedCollection => '읽기 전용';

  @override
  String get pendingLocally => '로컬에서 보류 중';

  @override
  String get conflictBlocked => '충돌로 차단됨';

  @override
  String get authenticationBlocked => '다시 연결할 때까지 차단됨';

  @override
  String get operationFailed => '작업 실패';

  @override
  String get keepServerVersion => '서버 버전 유지';

  @override
  String get reapplyLocalChange => '로컬 변경사항 검토 후 다시 적용';

  @override
  String get duplicateLocalItem => '새 항목으로 복제';

  @override
  String get davConnectionState => '연결 상태';

  @override
  String get davConnected => '연결됨';

  @override
  String get davConnecting => '연결 중…';

  @override
  String get davSignedOut => '로그아웃됨';

  @override
  String davLastSuccessfulSync(String time) {
    return '마지막으로 성공한 동기화: $time';
  }

  @override
  String get davNeverSynced => '아직 동기화되지 않음';

  @override
  String get refreshCollections => '캘린더 및 할 일 목록 새로 고침';

  @override
  String nextcloudServerHost(String host) {
    return '서버: $host';
  }

  @override
  String get collectionSupportsEvents => '일정 캘린더';

  @override
  String get collectionSupportsTasks => '할 일 목록';

  @override
  String get collectionSupportsEventsAndTasks => '일정 및 할 일';

  @override
  String get writableCollection => '쓰기 가능';

  @override
  String get sharedCollection => '공유됨';

  @override
  String collectionLastSynced(String time) {
    return '마지막 동기화: $time';
  }

  @override
  String collectionSyncError(String code) {
    return '동기화 문제: $code';
  }

  @override
  String get syncConflicts => '동기화 충돌';

  @override
  String remoteChangedAt(String time) {
    return '서버 변경: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return '로컬 편집: $summary';
  }

  @override
  String get conflictResolutionFailed => '충돌을 해결할 수 없습니다.';

  @override
  String get recurringEventScope => '반복 일정 범위';

  @override
  String get entireSeries => '전체 시리즈';

  @override
  String get singleOccurrence => '이 일정';

  @override
  String get thisAndFollowingEvents => '이 일정 및 향후 일정';

  @override
  String get thisAndFutureUnavailable => '이 제공업체에서는 지원되지 않습니다.';

  @override
  String get thisAndFutureMoveUnavailable =>
      '이 일정과 이후 일정을 안전하게 이동할 수 없습니다. 이 일정 또는 전체 반복 일정을 선택하세요.';

  @override
  String get entireSeriesMoveUnavailable =>
      '반복 규칙을 로컬에서 사용할 수 없습니다. 이 일정만 이동하세요.';

  @override
  String get copyEventAndDeleteOriginal => '일정을 복사하고 원본을 삭제할까요?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax는 이 일정을 $source에서 $destination(으)로 직접 이동할 수 없습니다. 먼저 복사본을 만들고 복사가 성공한 뒤에만 원본을 삭제합니다. 일정 ID가 변경되고 참석자 응답 상태가 초기화되며 초대 또는 취소가 전송될 수 있습니다. 회의 링크, 첨부 파일, 미리 알림, 제공업체별 필드 및 반복 예외는 이전되지 않을 수 있습니다.';
  }

  @override
  String get copyAndDelete => '복사 후 삭제';

  @override
  String get chooseRecurringEventScope =>
      '이 변경을 전체 시리즈, 이 일정만 또는 이 일정과 이후 일정에 적용할지 선택하세요.';

  @override
  String get taskDueBeforeStart => '마감은 시작보다 빠를 수 없습니다.';

  @override
  String get taskStartDueTimeModeMismatch =>
      '시작과 마감에 모두 시간을 설정하거나 작업을 종일로 설정하세요.';

  @override
  String deleteCalendarConfirmation(String title) {
    return '“$title” 캘린더를 삭제할까요?';
  }

  @override
  String get setCustomCalendarName => '맞춤 이름 설정';

  @override
  String get setAction => '설정';

  @override
  String get removeFromMyCalendars => '내 캘린더에서 삭제';

  @override
  String get removeAction => '삭제';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Google Calendar 목록에서 \"$title\"을(를) 삭제할까요? 공유 캘린더와 일정은 삭제되지 않습니다.';
  }

  @override
  String get calendarCannotRemove => '이 캘린더는 이 계정에서 삭제하거나 제거할 수 없습니다.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      '삭제하거나 제거하기 전에 이 캘린더의 보류 중인 변경사항이 동기화될 때까지 기다리세요.';

  @override
  String get calendarSubscriptions => '캘린더 구독';

  @override
  String get calendarSubscriptionsDescription =>
      '보안 WebCal URL에서 새로 고침되는 읽기 전용 캘린더를 추가하세요.';

  @override
  String get addCalendarSubscription => '캘린더 구독 추가';

  @override
  String get subscriptionName => '로컬 이름';

  @override
  String get subscriptionUrl => '구독 URL';

  @override
  String get subscriptionUrlHelp =>
      'HTTPS 또는 webcal URL을 입력하세요. BusyMax는 전체 URL을 안전한 저장소에 보관합니다.';

  @override
  String get subscriptionUrlInvalid =>
      '사용자 정보나 프래그먼트가 없는 올바른 HTTPS 또는 webcal URL을 입력하세요.';

  @override
  String get subscriptionColor => '로컬 색상';

  @override
  String get subscriptionColorHelp => '#3584E4와 같은 6자리 색상을 사용하세요.';

  @override
  String get subscriptionColorInvalid => '6자리 16진수 색상을 입력하세요.';

  @override
  String get subscriptionRefreshMode => '새로 고침 빈도';

  @override
  String get subscriptionAutomatic => '자동';

  @override
  String get subscriptionHourly => '매시간';

  @override
  String get subscriptionSixHours => '6시간마다';

  @override
  String get subscriptionDaily => '매일';

  @override
  String subscriptionSafeOrigin(String origin) {
    return '소스: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      '안전한 원본을 미리 보려면 올바른 URL을 입력하세요.';

  @override
  String get subscriptionReadOnly => '읽기 전용 구독';

  @override
  String get subscriptionNeverRefreshed => '아직 새로 고치지 않음';

  @override
  String subscriptionLastRefresh(String time) {
    return '마지막으로 성공한 새로 고침: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return '다음 새로 고침: $time';
  }

  @override
  String get subscriptionStatusHealthy => '최신 상태';

  @override
  String subscriptionStatusIssue(String code) {
    return '새로 고침 문제: $code';
  }

  @override
  String get refreshNow => '지금 새로 고침';

  @override
  String get unsubscribe => '구독 취소';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '“$name” 구독을 취소할까요?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      '로컬 구독과 캐시된 일정을 제거합니다. 게시된 캘린더는 변경되지 않습니다.';

  @override
  String get addSubscriptionAction => '구독 추가';

  @override
  String subscriptionOperationFailed(String error) {
    return '캘린더 구독 실패: $error';
  }

  @override
  String get subscriptions => '구독';

  @override
  String get calendarImport => '캘린더 가져오기';

  @override
  String get calendarImportDescription =>
      '파일을 선택하고 일정을 검토한 다음 이를 받을 쓰기 가능한 캘린더를 선택하세요.';

  @override
  String get importIcsFile => '.ics 파일 가져오기';

  @override
  String get importIcsPreview => '캘린더 일정 가져오기';

  @override
  String importEventsFound(int count) {
    return '가져올 수 있는 일정 세트: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return '잘못된 일정: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return '의도적으로 생략됨: $fields';
  }

  @override
  String get noWritableCalendars => '쓰기 가능한 대상 캘린더가 없습니다.';

  @override
  String get importDestinationCalendar => '대상 캘린더';

  @override
  String get importIcsConfirm => '일정 가져오기';

  @override
  String get importIcsComplete => '가져오기 완료';

  @override
  String importQueued(int count) {
    return '가져왔거나 대기열에 추가됨: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return '중복 건너뜀: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return '지원되지 않는 반복 세트: $count';
  }

  @override
  String importIcsFailed(String error) {
    return '캘린더 파일을 가져올 수 없습니다: $error';
  }

  @override
  String get networkOffline => '오프라인';

  @override
  String get networkOfflineDescription => '연결이 복구되면 변경 사항이 동기화됩니다.';

  @override
  String get networkOfflineTryAgain => '오프라인 상태입니다. 인터넷에 연결한 후 다시 시도하세요.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return '매월 $days일';
  }
}

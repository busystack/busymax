// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      '连接 Google、Microsoft、Apple iCloud Calendar 或 Nextcloud 账户。';

  @override
  String get googlePermissionsConsentNotice => '在 Google 权限页面上，同时选择日历和任务权限。';

  @override
  String get googlePermissionsRequiredRetry =>
      '必须授予 Google 日历和 Google Tasks 权限。请重试并选中两个复选框。';

  @override
  String get finishSetup => '完成设置';

  @override
  String get continueSetup => '继续';

  @override
  String get onboardingSetupTitle => '设置 BusyMax';

  @override
  String get onboardingAccountsStepTitle => '连接帐户';

  @override
  String get onboardingAccountsStepDescription =>
      '添加所有要使用的账户。BusyMax 会同步每个账户中受支持的日历、活动、任务列表和任务。';

  @override
  String get onboardingPreferencesStepTitle => '选择系统设置';

  @override
  String get onboardingPreferencesStepDescription =>
      '打开日程前，请设置桌面行为、提醒、通知详细程度和外观。';

  @override
  String get signInWithGoogle => '使用 Google 登录';

  @override
  String get signInWithMicrosoft => '使用 Microsoft 登录';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => '尚未配置此服务。';

  @override
  String get waitingForGoogleSignIn => '正在等待 Google 登录...';

  @override
  String get waitingForMicrosoftSignIn => '正在等待 Microsoft 登录...';

  @override
  String get microsoftSignInNotConfigured =>
      '尚未配置 Microsoft 登录。请设置 MICROSOFT_OAUTH_CLIENT_ID。';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get exit => '退出';

  @override
  String get options => '选项';

  @override
  String get hide => '隐藏';

  @override
  String get show => '显示';

  @override
  String get export => '导出';

  @override
  String get save => '保存';

  @override
  String get settings => '设置';

  @override
  String get all => '全部';

  @override
  String get calendarEvents => '日程';

  @override
  String get calendarTasks => '任务';

  @override
  String get calendar => '日历';

  @override
  String get calendars => '日历';

  @override
  String get newCalendar => '新建日历';

  @override
  String get calendarColor => '日历颜色';

  @override
  String calendarColorOption(int number) {
    return '颜色 $number';
  }

  @override
  String get calendarManagementUnsupported => '此提供商不支持 BusyMax 中的日历管理。';

  @override
  String get primaryCalendarCannotDelete => '无法删除主日历。';

  @override
  String calendarCreateFailed(String error) {
    return '无法创建日历：$error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      '日历已创建，但 BusyMax 无法刷新账户。它将在下次同步后显示。';

  @override
  String calendarUpdateFailed(String error) {
    return '无法更新日历：$error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return '无法删除日历：$error';
  }

  @override
  String get newEvent => '新建日程';

  @override
  String get refreshCalendar => '刷新日历';

  @override
  String get openInProvider => '在服务中打开';

  @override
  String get hideFromSchedule => '从日程中隐藏';

  @override
  String get showInSchedule => '在日程中显示';

  @override
  String get noCalendarsSynced => '尚未同步任何日历。';

  @override
  String get allDay => '全天';

  @override
  String moreItems(int count) {
    return '还有 $count 项';
  }

  @override
  String get noEventsOrTasks => '没有日程或任务';

  @override
  String get scheduleLoading => '正在加载日程...';

  @override
  String get scheduleUnavailable => '日程不可用';

  @override
  String get scheduleNoSources => '没有可见的日历或任务列表';

  @override
  String get scheduleNoSourcesDescription => '请在设置中选择要显示的内容，然后刷新。';

  @override
  String get scheduleSignInRequired => '连接帐户';

  @override
  String get scheduleSignInDescription => '登录以同步日历和任务。';

  @override
  String get scheduleNoSearchResults => '没有匹配的日程或任务';

  @override
  String get scheduleNoSearchResultsDescription => '请尝试其他搜索内容或清除当前筛选条件。';

  @override
  String get refresh => '刷新';

  @override
  String get trayOpenBusyMax => '打开 BusyMax';

  @override
  String get trayShowBusyMax => '显示 BusyMax';

  @override
  String get trayNewEvent => '新活动…';

  @override
  String get trayNewTask => '新任务…';

  @override
  String get trayToday => '今天';

  @override
  String get trayAllDay => '全天';

  @override
  String get trayNow => '现在';

  @override
  String get trayCalendarEvent => '日历活动';

  @override
  String get trayUntitledEvent => '无标题活动';

  @override
  String get trayNothingElseToday => '今天没有其他内容';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天有 $count 个任务到期',
      one: '今天有 1 个任务到期',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => '打开今天的日程';

  @override
  String get traySyncNow => '立即同步';

  @override
  String get traySyncing => '正在同步…';

  @override
  String get trayNotConnected => '未连接';

  @override
  String get trayNotYetSynced => '尚未同步';

  @override
  String get trayLastSyncedJustNow => '刚刚同步';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前同步',
      one: '1 分钟前同步',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前同步',
      one: '1 小时前同步',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前同步',
      one: '1 天前同步',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => '设置';

  @override
  String get trayQuitBusyMax => '退出 BusyMax';

  @override
  String get agendaLoadMoreOverdue => '加载更多逾期任务';

  @override
  String get agendaLoadMoreNoDate => '加载更多无日期任务';

  @override
  String get viewDay => '日';

  @override
  String get viewWeek => '周';

  @override
  String get viewMonth => '月';

  @override
  String get viewYear => '年';

  @override
  String get viewAgenda => '日程';

  @override
  String get scheduleSettings => '日程';

  @override
  String get scheduleDisplaySettings => '日程显示';

  @override
  String get scheduleDisplayHoursDescription =>
      '日视图和周视图最初显示此时间范围。需要时，更早或更晚的项目会扩展该范围。';

  @override
  String get scheduleDayStartsAt => '每日开始时间';

  @override
  String get scheduleDayEndsAt => '每日结束时间';

  @override
  String get sourceCalendar => '日历';

  @override
  String get sourceTaskList => '任务列表';

  @override
  String get createChoiceTitle => '新建';

  @override
  String get createEventAtTime => '日程';

  @override
  String get createTaskAtDate => '任务';

  @override
  String get editEvent => '编辑日程';

  @override
  String get eventTitle => '日程标题';

  @override
  String get location => '地点';

  @override
  String get timeSlot => '时间段';

  @override
  String get startDateTime => '开始日期/时间';

  @override
  String get endDateTime => '结束日期/时间';

  @override
  String get doesNotRepeat => '不重复';

  @override
  String get defaultReminder => '默认提醒';

  @override
  String get guests => '参与者';

  @override
  String get noGuests => '无参与者';

  @override
  String get attendeeRequired => '必需';

  @override
  String get attendeeOptional => '可选';

  @override
  String get meetingSection => '会议';

  @override
  String get addGoogleMeet => '添加 Google Meet';

  @override
  String get addTeamsMeeting => '添加 Microsoft Teams 会议';

  @override
  String get onlineMeetingAdded => '已添加在线会议';

  @override
  String get requestResponses => '请求回复';

  @override
  String get requestResponsesDescription => '要求参与者回复邀请。';

  @override
  String get hideGuestList => '隐藏参与者列表';

  @override
  String get hideGuestListDescription => '参与者无法查看其他受邀者。';

  @override
  String get allowNewTimeProposals => '允许提出新时间';

  @override
  String get allowNewTimeProposalsDescription => '参与者可以建议其他会议时间。';

  @override
  String get notifyGuestsTitle => '通知参与者？';

  @override
  String get notifyGuestsSaveMessage => '此会议有参与者。保存时发送邀请或活动更新吗？';

  @override
  String get notifyGuestsDeleteMessage => '此会议有参与者。删除时发送取消通知吗？';

  @override
  String get sendUpdates => '发送更新';

  @override
  String get sendCancellation => '发送取消通知';

  @override
  String get doNotSend => '不发送';

  @override
  String get microsoftNotifyGuestsSaveTitle => '保存会议？';

  @override
  String get microsoftNotifyGuestsSaveMessage => 'Microsoft 将向参与者发送邀请或活动更新。';

  @override
  String get microsoftNotifyGuestsDeleteTitle => '删除会议？';

  @override
  String get microsoftNotifyGuestsDeleteMessage => 'Microsoft 将向参与者发送取消通知。';

  @override
  String get organizer => '组织者';

  @override
  String get yourResponse => '你的回复';

  @override
  String get guestResponses => '参与者回复';

  @override
  String get respond => '回复';

  @override
  String get acceptInvitation => '接受';

  @override
  String get tentativeInvitation => '暂定';

  @override
  String get declineInvitation => '拒绝';

  @override
  String get joinMeeting => '加入会议';

  @override
  String get responseAccepted => '已接受';

  @override
  String get responseTentative => '暂定';

  @override
  String get responseDeclined => '已拒绝';

  @override
  String get responseNeedsAction => '等待回复';

  @override
  String get responseNotResponded => '未回复';

  @override
  String get responseOrganizer => '组织者';

  @override
  String invitationResponseFailed(String error) {
    return '无法发送回复：$error';
  }

  @override
  String get joinMeetingFailed => '无法打开会议链接。';

  @override
  String get description => '说明';

  @override
  String get availabilityShowAs => '空闲状态 / 显示为';

  @override
  String get busy => '忙碌';

  @override
  String get visibility => '可见性';

  @override
  String get defaultVisibility => '默认可见性';

  @override
  String get conference => '会议';

  @override
  String get noConference => '无会议';

  @override
  String get providerCalendar => '服务日历';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => '粗体';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => '斜体';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => '下划线';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟前',
      one: '1 分钟前',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => '开始时';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时前',
      one: '1 小时前',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => '空闲';

  @override
  String get availabilityTentative => '暂定';

  @override
  String get availabilityOutOfOffice => '不在办公室';

  @override
  String get availabilityWorkingElsewhere => '在其他地点办公';

  @override
  String get visibilityDefault => '默认';

  @override
  String get visibilityPublic => '公开';

  @override
  String get visibilityPrivate => '私密';

  @override
  String get visibilityConfidential => '机密';

  @override
  String get sensitivityNormal => '普通';

  @override
  String get sensitivityPersonal => '个人';

  @override
  String get tasks => '任务';

  @override
  String get allTasks => '所有任务';

  @override
  String tasksInList(String title) {
    return '$title中的任务';
  }

  @override
  String get taskLists => '任务列表';

  @override
  String get navigation => '导航';

  @override
  String get mainMenu => '主菜单';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get shortcutGroupGeneral => '常规';

  @override
  String get shortcutKeyboardShortcutsDescription => '显示快捷键参考表';

  @override
  String get shortcutGroupNavigation => '导航';

  @override
  String get shortcutNextPeriod => '下一时段';

  @override
  String get shortcutNextPeriodDescription => '在周视图中前往下一周，在月视图中前往下个月，依此类推';

  @override
  String get shortcutPreviousPeriod => '上一时段';

  @override
  String get shortcutPreviousPeriodDescription => '在周视图中前往上一周，在月视图中前往上个月，依此类推';

  @override
  String get shortcutJumpToToday => '跳转到今天';

  @override
  String get shortcutGroupView => '视图';

  @override
  String get shortcutDayView => '日视图';

  @override
  String get shortcutWeekView => '周视图';

  @override
  String get shortcutMonthView => '月视图';

  @override
  String get shortcutYearView => '年视图';

  @override
  String get shortcutAgendaView => '日程视图';

  @override
  String get shortcutGroupCreateAndEdit => '新建和编辑';

  @override
  String get shortcutSaveItem => '保存日程或任务';

  @override
  String get shortcutDeleteItem => '删除日程或任务';

  @override
  String get shortcutGroupTaskEditing => '任务编辑';

  @override
  String get shortcutCancelEditing => '取消编辑';

  @override
  String get shortcutCancelEditingDescription => '关闭任务编辑或任务详情';

  @override
  String get aboutBusyMax => '关于 BusyMax';

  @override
  String get aboutBusyMaxDescription => '日历和任务';

  @override
  String get license => '许可证';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => '网站';

  @override
  String get sourceCode => '源代码';

  @override
  String get reportAnIssue => '报告问题';

  @override
  String get sendFeedback => '发送反馈';

  @override
  String get feedbackSubmit => '提交';

  @override
  String get feedbackCategory => '类别';

  @override
  String get feedbackSelectCategory => '选择类别';

  @override
  String get feedbackCategoryProblem => '问题或错误';

  @override
  String get feedbackCategoryFeature => '功能请求';

  @override
  String get feedbackCategoryPrivacySecurity => '隐私或安全问题';

  @override
  String get feedbackCategoryUsability => '易用性问题';

  @override
  String get feedbackCategoryOther => '其他';

  @override
  String get feedbackSubject => '主题';

  @override
  String get feedbackDetailedMessage => '详细信息';

  @override
  String get feedbackReplyEmail => '用于接收回复的电子邮件地址（可选）';

  @override
  String get feedbackIncludeTechnicalDetails => '包含技术详情';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      '仅添加您的 Linux 操作系统版本和应用区域设置。不包含日志、帐户数据、文件名或其他诊断信息。';

  @override
  String get feedbackCategoryRequired => '请选择类别。';

  @override
  String get feedbackSubjectLengthError => '主题必须为 3 至 120 个字符。';

  @override
  String get feedbackMessageLengthError => '消息必须为 10 至 5,000 个字符。';

  @override
  String get feedbackInvalidEmail => '请输入有效的电子邮件地址。';

  @override
  String get feedbackConnectionError => '无法连接到 BusyStack。请检查连接，然后重试。';

  @override
  String get feedbackTimeoutError => '请求超时。您的反馈尚未清除，请重试。';

  @override
  String get feedbackRateLimitedError => '从此网络发送的反馈过多。请稍后再试。';

  @override
  String get feedbackRejectedError => '服务器拒绝了提交。请检查各字段，然后重试。';

  @override
  String get feedbackServerError => 'BusyStack 目前无法接收您的反馈。您的反馈尚未清除，请重试。';

  @override
  String feedbackSuccess(String id) {
    return '反馈已发送。参考编号：$id';
  }

  @override
  String get toggleSidebar => '显示或隐藏侧边栏';

  @override
  String get showSidebar => '显示侧边栏面板';

  @override
  String get hideSidebar => '隐藏侧边栏面板';

  @override
  String get accounts => '帐户';

  @override
  String get currentAccount => '当前帐户';

  @override
  String get switchAccount => '切换帐户';

  @override
  String get addGoogleAccount => '添加 Google 帐户';

  @override
  String get addMicrosoftAccount => '添加 Microsoft 帐户';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => '已登录';

  @override
  String get removeAccount => '移除帐户…';

  @override
  String get removingAccount => '正在移除帐户…';

  @override
  String get removeAccountDescription => '停止同步并从此设备移除此帐户的数据。';

  @override
  String removeAccountTitle(String account) {
    return '从 BusyMax 中移除 $account？';
  }

  @override
  String get removeAccountConfirmation =>
      '这会从此设备删除缓存的任务、日历、活动、提醒和待处理的离线更改。未同步的更改将会丢失。提供商中的日历、活动、任务列表和任务副本不会被删除。';

  @override
  String get revokeGoogleAccess => '同时撤销 BusyMax 对此 Google 帐户的访问权限';

  @override
  String get revokeGoogleAccessDescription => '重新连接之前，您需要再次授予访问权限。';

  @override
  String get removeAccountAction => '移除帐户';

  @override
  String get removeAccountFailed => '无法完成帐户移除。请重试。';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      '该帐户已从此设备移除，但无法撤销 BusyMax 对您的 Google 帐户的访问权限。您可以在 Google 帐户中手动撤销该权限。';

  @override
  String get newTaskList => '新任务列表';

  @override
  String taskListCreateFailed(String error) {
    return '无法创建任务列表：$error';
  }

  @override
  String taskListRenameFailed(String error) {
    return '无法重命名任务列表：$error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return '无法删除任务列表：$error';
  }

  @override
  String get signInToViewTaskLists => '登录以查看任务列表。';

  @override
  String get noTaskListsSynced => '尚未同步任何任务列表。';

  @override
  String get listActions => '列表操作';

  @override
  String get rename => '重命名';

  @override
  String get delete => '删除';

  @override
  String get renameList => '重命名列表';

  @override
  String get deleteList => '删除列表';

  @override
  String get unshare => '取消共享';

  @override
  String get readOnlyTaskListCannotRename => '此任务列表为只读，无法重命名。';

  @override
  String get taskListCannotDelete => '使用当前权限无法删除此任务列表。';

  @override
  String get builtInMicrosoftList => '内置';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      '无法重命名或删除 Microsoft To Do 内置列表。';

  @override
  String deleteListConfirmation(String title) {
    return '要从 Google Tasks 中删除“$title”吗？';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '要删除“$title”及其所有任务吗？';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return '要取消此账户对“$title”的共享吗？';
  }

  @override
  String get deleteEvent => '删除日程';

  @override
  String get title => '标题';

  @override
  String get create => '新建';

  @override
  String get newTask => '新建任务';

  @override
  String get clearCompleted => '清除已完成项';

  @override
  String get refreshList => '刷新列表';

  @override
  String get refreshAll => '全部刷新';

  @override
  String get listRefreshed => '列表已刷新。';

  @override
  String get allTasksRefreshed => '所有帐户均已刷新。';

  @override
  String exportedFile(String path) {
    return '已导出到 $path';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String refreshFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String get selectOrCreateTaskList => '请选择或创建任务列表以开始使用。';

  @override
  String get signInToViewTasks => '登录以查看任务。';

  @override
  String get noTasks => '没有任务。';

  @override
  String get noTasksYet => '还没有任务';

  @override
  String get noTasksYetMessage => '创建任务或刷新帐户以开始使用。';

  @override
  String get noTasksInList => '此列表中没有任务。';

  @override
  String get overdue => '已逾期';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get upcoming => '即将到期';

  @override
  String get noDate => '无日期';

  @override
  String get completed => '已完成';

  @override
  String duePrefix(String date) {
    return '$date 到期';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => '任务详情';

  @override
  String get editTask => '编辑任务';

  @override
  String get noTaskSelected => '未选择任务。';

  @override
  String get noTaskSelectedHelper => '选择任务以查看和编辑详情。';

  @override
  String get taskUnavailable => '任务不可用。';

  @override
  String get signInToEditTasks => '登录以编辑任务。';

  @override
  String get refreshTask => '刷新任务';

  @override
  String get primarySection => '主要信息';

  @override
  String get statusSection => '状态';

  @override
  String get openStatus => '未完成';

  @override
  String get doneStatus => '已完成';

  @override
  String get taskStatus => '状态';

  @override
  String get taskStatusNone => '无状态';

  @override
  String get taskStatusNeedsAction => '需要操作';

  @override
  String get taskStatusInProcess => '进行中';

  @override
  String get taskStatusCompleted => '已完成';

  @override
  String get taskStatusCancelled => '已取消';

  @override
  String completionPercent(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get completionDate => '完成日期';

  @override
  String get priority => '优先级';

  @override
  String get priorityNone => '无优先级';

  @override
  String priorityHighValue(int priority) {
    return '优先级 $priority · 高';
  }

  @override
  String priorityMediumValue(int priority) {
    return '优先级 $priority · 中';
  }

  @override
  String priorityLowValue(int priority) {
    return '优先级 $priority · 低';
  }

  @override
  String get taskUrl => '任务 URL';

  @override
  String get invalidTaskUrl => '请输入包含方案的绝对 URL。';

  @override
  String get classification => '分类';

  @override
  String get classificationPublic => '共享时显示完整任务';

  @override
  String get classificationConfidential => '共享时仅显示忙碌状态';

  @override
  String get classificationPrivate => '共享时隐藏此任务';

  @override
  String get pinTask => '固定任务';

  @override
  String get notes => '备注';

  @override
  String get dueDate => '截止日期';

  @override
  String get clearDueDate => '清除截止日期';

  @override
  String get dueTime => '截止时间';

  @override
  String get startDate => '开始日期';

  @override
  String get startTime => '开始时间';

  @override
  String get endDate => '结束日期';

  @override
  String get endTime => '结束时间';

  @override
  String get reminderDate => '提醒日期';

  @override
  String get reminderTime => '提醒时间';

  @override
  String get reminder => '提醒';

  @override
  String get addReminder => '添加提醒';

  @override
  String get reminders => '提醒';

  @override
  String get noReminders => '无提醒';

  @override
  String get editReminder => '编辑提醒';

  @override
  String get beforeTaskStarts => '任务开始前';

  @override
  String get beforeTaskDue => '任务到期前';

  @override
  String get afterTaskStarts => '任务开始后';

  @override
  String get afterTaskDue => '任务到期后';

  @override
  String get relativeToTaskStart => '相对于任务开始日期';

  @override
  String get relativeToTaskDue => '相对于任务到期日期';

  @override
  String get reminderTimeOfDay => '时间';

  @override
  String get absoluteReminder => '在指定日期和时间';

  @override
  String get reminderAmount => '数量';

  @override
  String get reminderUnit => '单位';

  @override
  String get reminderUnitSeconds => '秒';

  @override
  String get reminderUnitMinutes => '分钟';

  @override
  String get reminderUnitHours => '小时';

  @override
  String get reminderUnitDays => '天';

  @override
  String get reminderUnitWeeks => '周';

  @override
  String get reminderAtTaskStart => '任务开始时';

  @override
  String get reminderAtTaskDue => '任务到期时';

  @override
  String get unsupportedReminder => '此提醒类型会保留，但无法编辑其时间。';

  @override
  String get relatedRemindersTitle => '保留相关提醒？';

  @override
  String relatedRemindersDescription(int count) {
    return '此日期有 $count 个相关提醒。要保留它们当前的日期和时间吗？';
  }

  @override
  String get discardRelatedReminders => '舍弃提醒';

  @override
  String get keepRelatedReminders => '保留提醒';

  @override
  String get addGuest => '添加参与者';

  @override
  String get addGuestEmail => '添加参与者电子邮件';

  @override
  String get removeReminder => '移除提醒';

  @override
  String get off => '关闭';

  @override
  String get repeat => '重复';

  @override
  String get repeatNone => '不重复';

  @override
  String get noneValue => '无';

  @override
  String get repeatDaily => '每天';

  @override
  String get repeatWeekly => '每周';

  @override
  String get repeatMonthly => '每月';

  @override
  String get repeatYearly => '每年';

  @override
  String get repeatEvery => '重复间隔';

  @override
  String get repeatOn => '重复日期';

  @override
  String get repeatEnd => '结束重复';

  @override
  String get repeatNever => '从不';

  @override
  String get repeatUntil => '指定日期';

  @override
  String get repeatAfter => '指定次数后';

  @override
  String get repeatCount => '重复次数';

  @override
  String get repeatDayOfMonth => '每月日期';

  @override
  String get repeatMonths => '月份';

  @override
  String get repeatOrdinal => '星期位置';

  @override
  String get repeatSpecificDays => '特定日期';

  @override
  String get repeatFirst => '第一';

  @override
  String get repeatSecond => '第二';

  @override
  String get repeatThird => '第三';

  @override
  String get repeatFourth => '第四';

  @override
  String get repeatFifth => '第五';

  @override
  String get repeatSecondToLast => '倒数第二';

  @override
  String get repeatLast => '最后';

  @override
  String get repeatAnyDay => '日期';

  @override
  String get repeatWeekday => '工作日';

  @override
  String get repeatWeekendDay => '周末';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': '星期一',
      'TU': '星期二',
      'WE': '星期三',
      'TH': '星期四',
      'FR': '星期五',
      'SA': '星期六',
      'SU': '星期日',
      'day': '日期',
      'weekday': '工作日',
      'weekend': '周末',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    return '每 $count 天';
  }

  @override
  String repeatEveryWeeks(int count) {
    return '每 $count 周';
  }

  @override
  String repeatEveryMonths(int count) {
    return '每 $count 个月';
  }

  @override
  String repeatEveryYears(int count) {
    return '每 $count 年';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '在 $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一个$days',
      'second': '第二个$days',
      'third': '第三个$days',
      'fourth': '第四个$days',
      'fifth': '第五个$days',
      'secondToLast': '倒数第二个$days',
      'last': '最后一个$days',
      'other': '$days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return '在 $months';
  }

  @override
  String repeatTimesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重复 $count 次',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return '直到 $date';
  }

  @override
  String get unsupportedRecurrencePreserved => '此重复规则使用了编辑器不会更改的选项。';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return '此重复规则不能用于 $provider。';
  }

  @override
  String get importance => '重要性';

  @override
  String get importanceLow => '低';

  @override
  String get importanceNormal => '普通';

  @override
  String get importanceHigh => '高';

  @override
  String get categories => '类别';

  @override
  String get scheduleSection => '日程';

  @override
  String get dueGroup => '截止';

  @override
  String get startGroup => '开始';

  @override
  String get reminderGroup => '提醒';

  @override
  String get organizationSection => '整理';

  @override
  String get actionsSection => '操作';

  @override
  String get advancedSection => '高级';

  @override
  String get addCategory => '添加类别';

  @override
  String get list => '列表';

  @override
  String get microsoftMoveUnsupported => '此版本不支持在 Microsoft To Do 帐户的列表之间移动任务。';

  @override
  String get createSubtask => '创建子任务';

  @override
  String get subtasks => '子任务';

  @override
  String get duplicateTask => '复制任务';

  @override
  String get taskDuplicated => '任务已复制。';

  @override
  String taskDuplicateFailed(String error) {
    return '无法复制任务：$error';
  }

  @override
  String get hideSubtasks => '隐藏子任务';

  @override
  String get hideClosedSubtasks => '隐藏已关闭的子任务';

  @override
  String get moveToTop => '移到顶部';

  @override
  String get deleteTask => '删除任务';

  @override
  String get newSubtask => '新建子任务';

  @override
  String deleteTaskConfirmation(String title) {
    return '删除“$title”？';
  }

  @override
  String get metadata => '元数据';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => '更新时间';

  @override
  String get parent => '父任务';

  @override
  String get position => '位置';

  @override
  String get webLink => '网页链接';

  @override
  String get assignment => '分配';

  @override
  String get localState => '本地状态';

  @override
  String get pendingSync => '等待同步';

  @override
  String get synced => '已同步';

  @override
  String get account => '帐户';

  @override
  String get sync => '同步';

  @override
  String get forceFullResync => '强制完全重新同步';

  @override
  String get forceFullResyncDescription =>
      '从每个已连接的账号中重新完整加载所有数据。请仅在排查同步问题时使用此功能。';

  @override
  String get runInBackgroundWhenClosed => '窗口关闭后继续在后台运行';

  @override
  String get showTrayIcon => '显示托盘图标';

  @override
  String get startMinimizedToTray => '启动时最小化到托盘';

  @override
  String get launchAtLogin => '登录时启动';

  @override
  String get launchAtLoginDescription => '在后台启动 BusyMax，以便登录后提醒能够正常工作。';

  @override
  String get launchAtLoginFailed => '无法更新登录时启动设置。';

  @override
  String get requiresTrayIcon => '需要托盘图标。';

  @override
  String get syncComplete => '同步完成。';

  @override
  String syncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String get notifySyncFailures => '同步失败通知';

  @override
  String get notifyConflicts => '冲突通知';

  @override
  String get notifyDueToday => '今天到期任务通知';

  @override
  String get eventReminders => '日程提醒';

  @override
  String get onState => '开启';

  @override
  String get taskReminders => '任务提醒';

  @override
  String get notificationDetailLevel => '通知详细程度';

  @override
  String get notificationDetailPrivate => '私密';

  @override
  String get notificationDetailNormal => '普通';

  @override
  String get quietHours => '免打扰时段';

  @override
  String get quietHoursDescription => '在此时段暂停通知。';

  @override
  String get quietHoursStart => '免打扰开始时间';

  @override
  String get quietHoursEnd => '免打扰结束时间';

  @override
  String get notifications => '通知';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '系统';

  @override
  String get settingsSystem => '系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeFamily => '主题系列';

  @override
  String get themeFamilyYaru => 'Ubuntu 原生主题（Yaru）';

  @override
  String get localization => '语言和区域';

  @override
  String get currentLocale => '当前区域设置';

  @override
  String get privacy => '隐私';

  @override
  String get redactTaskContentInDiagnostics => '在诊断信息中隐藏任务内容';

  @override
  String get developerDiagnostics => '开发者诊断';

  @override
  String get diagnostics => '诊断';

  @override
  String get apiInspectorDisabled => '显示 API 检查器';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery 修订版：$revision';
  }

  @override
  String get implementedMethods => '已实现的方法';

  @override
  String get supportsTasksScopes => '支持 tasks 和 tasks.readonly 权限范围';

  @override
  String get requiresTasksScope => '需要 tasks 权限范围';

  @override
  String get blockedPendingOperations => '被阻止的待处理操作';

  @override
  String get signInToInspectPendingOperations => '登录以检查待处理操作。';

  @override
  String get noBlockedPendingOperations => '没有被阻止的待处理操作。';

  @override
  String get operationActions => '操作选项';

  @override
  String pendingOpListId(String id) {
    return '列表=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return '任务=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return '尝试次数=$count';
  }

  @override
  String get retry => '重试';

  @override
  String get discard => '舍弃';

  @override
  String get discardChangesAction => '舍弃';

  @override
  String get discardChanges => '舍弃更改？';

  @override
  String get discardChangesConfirmation => '这将舍弃对此任务所做的未保存编辑。';

  @override
  String get retryCompleted => '重试完成。';

  @override
  String get discardPendingOperation => '舍弃待处理操作？';

  @override
  String get discardPendingOperationConfirmation =>
      '这将移除被阻止的本地操作。下次同步时将从 Google Tasks 刷新数据。';

  @override
  String get pendingOperationDiscarded => '已舍弃待处理操作。';

  @override
  String get syncFailureNotificationTitle => 'BusyMax 同步失败';

  @override
  String syncFailureNotificationBody(String message) {
    return '后台同步失败。$message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax 同步冲突';

  @override
  String conflictNotificationBody(String summary) {
    return '一项待处理的本地更改被阻止。$summary';
  }

  @override
  String get dueTodayNotificationTitle => '今天到期的任务';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天有 $count 项任务到期。',
      one: '今天有 1 项任务到期。',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => '日程提醒';

  @override
  String get taskReminderNotificationTitle => '任务提醒';

  @override
  String get eventReminderNotificationBody => '日程即将开始。';

  @override
  String get taskReminderNotificationBody => '任务即将到期。';

  @override
  String get notificationOpenAction => '打开';

  @override
  String get notificationSnoozeAction => '10 分钟后提醒';

  @override
  String get notificationDismissAction => '关闭';

  @override
  String get notificationDetailsHidden => '根据隐私设置，详细信息已隐藏。';

  @override
  String get previousMonth => '上个月';

  @override
  String get nextMonth => '下个月';

  @override
  String get openMonthView => '打开月视图';

  @override
  String get previousYear => '上一年';

  @override
  String get nextYear => '下一年';

  @override
  String get openYearView => '打开年视图';

  @override
  String weekNumberTooltip(int number) {
    return '第 $number 周';
  }

  @override
  String get resizeAllDayPanel => '调整全天面板的大小';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
      one: '1 项',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => '此日历为只读。';

  @override
  String get selectTimeZone => '选择时区';

  @override
  String get searchLocations => '搜索地点';

  @override
  String get noLocationsFound => '未找到地点';

  @override
  String get requiredField => '此字段为必填项。';

  @override
  String get providerConnectionDescription => '连接以下任一提供商中的日历和任务。';

  @override
  String get appleICloudProvider => 'Apple iCloud 日历';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud 任务';

  @override
  String get addAppleICloudAccount => '添加 Apple iCloud 日历账户';

  @override
  String get addNextcloudAccount => '添加 Nextcloud 账户';

  @override
  String get waitingForAppleICloud => '正在连接 Apple iCloud…';

  @override
  String get waitingForNextcloud => '正在等待 Nextcloud 授权…';

  @override
  String get connectAppleICloudTitle => '连接 Apple iCloud 日历';

  @override
  String get appleAccountEmail => 'Apple 账户电子邮件';

  @override
  String get appleAppSpecificPassword => 'App 专用密码';

  @override
  String get appleAppSpecificPasswordHelp => '为 Apple 账户启用双重认证后，创建 App 专用密码。';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      '重置 Apple 账户密码会撤销 App 专用密码。';

  @override
  String get connectNextcloudTitle => '连接 Nextcloud';

  @override
  String get nextcloudServerUrl => 'Nextcloud 服务器或 CalDAV 地址';

  @override
  String get nextcloudServerUrlHelp =>
      '输入 Nextcloud 服务器 URL，或粘贴从 Nextcloud 复制的主要 CalDAV 地址。';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax 将打开浏览器。请在那里批准访问，然后返回 BusyMax。';

  @override
  String get connectAccountAction => '连接';

  @override
  String get cancelAccountConnection => '取消连接';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      '账户已在本地移除，但无法撤销 Nextcloud App 密码。';

  @override
  String get davCachedOfflineNotice => '日历和任务数据会缓存在本地，以供离线使用。';

  @override
  String get davReauthenticationRequired => '重新连接此账户以恢复同步。';

  @override
  String get davTemporarilyUnavailable => '此账户暂时不可用。';

  @override
  String get davPermissionChanged => '服务器权限已更改。待处理的编辑已暂停。';

  @override
  String get davUnsupportedServer => '不支持此服务器或提供商配置。';

  @override
  String get collectionSettings => '日历和任务列表';

  @override
  String get calendarContent => '日历活动';

  @override
  String get taskContent => '任务';

  @override
  String get readOnlySharedCollection => '只读';

  @override
  String get pendingLocally => '本地待处理';

  @override
  String get conflictBlocked => '因冲突而阻止';

  @override
  String get authenticationBlocked => '重新连接前阻止';

  @override
  String get operationFailed => '操作失败';

  @override
  String get keepServerVersion => '保留服务器版本';

  @override
  String get reapplyLocalChange => '查看并重新应用本地更改';

  @override
  String get duplicateLocalItem => '复制为新项目';

  @override
  String get davConnectionState => '连接状态';

  @override
  String get davConnected => '已连接';

  @override
  String get davConnecting => '正在连接…';

  @override
  String get davSignedOut => '已退出登录';

  @override
  String davLastSuccessfulSync(String time) {
    return '上次成功同步：$time';
  }

  @override
  String get davNeverSynced => '尚未同步';

  @override
  String get refreshCollections => '刷新日历和任务列表';

  @override
  String nextcloudServerHost(String host) {
    return '服务器：$host';
  }

  @override
  String get collectionSupportsEvents => '活动日历';

  @override
  String get collectionSupportsTasks => '任务列表';

  @override
  String get collectionSupportsEventsAndTasks => '活动和任务';

  @override
  String get writableCollection => '可写';

  @override
  String get sharedCollection => '已共享';

  @override
  String collectionLastSynced(String time) {
    return '上次同步：$time';
  }

  @override
  String collectionSyncError(String code) {
    return '同步问题：$code';
  }

  @override
  String get syncConflicts => '同步冲突';

  @override
  String remoteChangedAt(String time) {
    return '服务器更改：$time';
  }

  @override
  String localPendingEdit(String summary) {
    return '本地编辑：$summary';
  }

  @override
  String get conflictResolutionFailed => '无法解决冲突。';

  @override
  String get recurringEventScope => '重复活动范围';

  @override
  String get entireSeries => '整个系列';

  @override
  String get singleOccurrence => '此事件';

  @override
  String get thisAndFollowingEvents => '此事件及后续事件';

  @override
  String get thisAndFutureUnavailable => '此提供商不支持。';

  @override
  String get thisAndFutureMoveUnavailable => '无法安全移动此活动及后续活动。请选择此活动或整个系列。';

  @override
  String get entireSeriesMoveUnavailable => '本地没有可用的重复规则。请仅移动此活动。';

  @override
  String get copyEventAndDeleteOriginal => '复制活动并删除原活动？';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax 无法将此活动直接从 $source 移动到 $destination。应用会先创建副本，并且仅在复制成功后删除原活动。活动 ID 将发生变化；参与者的回复状态可能会重置，并可能发送邀请或取消通知；会议链接、附件、提醒、提供商特有的字段和重复例外可能无法保留。';
  }

  @override
  String get copyAndDelete => '复制并删除';

  @override
  String get chooseRecurringEventScope => '选择此更改适用于整个系列、仅此活动，还是此活动及后续活动。';

  @override
  String get taskDueBeforeStart => '截止时间不能早于开始时间。';

  @override
  String get taskStartDueTimeModeMismatch => '请同时设置开始和截止时间，或将任务设为全天。';

  @override
  String deleteCalendarConfirmation(String title) {
    return '删除“$title”？';
  }

  @override
  String get setCustomCalendarName => '设置自定义名称';

  @override
  String get setAction => '设置';

  @override
  String get removeFromMyCalendars => '从“我的日历”中移除';

  @override
  String get removeAction => '移除';

  @override
  String removeCalendarConfirmation(String title) {
    return '要从您的 Google 日历列表中移除“$title”吗？共享日历及其活动不会被删除。';
  }

  @override
  String get calendarCannotRemove => '无法从此账户删除或移除此日历。';

  @override
  String get calendarPendingChangesPreventRemoval =>
      '请等待此日历的待处理更改完成同步，然后再删除或移除它。';

  @override
  String get calendarSubscriptions => '日历订阅';

  @override
  String get calendarSubscriptionsDescription => '添加从安全 WebCal URL 刷新的只读日历。';

  @override
  String get addCalendarSubscription => '添加日历订阅';

  @override
  String get subscriptionName => '本地名称';

  @override
  String get subscriptionUrl => '订阅 URL';

  @override
  String get subscriptionUrlHelp =>
      '输入 HTTPS 或 webcal URL。BusyMax 会将完整 URL 保存在安全存储中。';

  @override
  String get subscriptionUrlInvalid => '请输入不含用户信息或片段的有效 HTTPS 或 webcal URL。';

  @override
  String get subscriptionColor => '本地颜色';

  @override
  String get subscriptionColorHelp => '使用六位颜色，例如 #3584E4。';

  @override
  String get subscriptionColorInvalid => '请输入六位十六进制颜色。';

  @override
  String get subscriptionRefreshMode => '刷新频率';

  @override
  String get subscriptionAutomatic => '自动';

  @override
  String get subscriptionHourly => '每小时';

  @override
  String get subscriptionSixHours => '每六小时';

  @override
  String get subscriptionDaily => '每天';

  @override
  String subscriptionSafeOrigin(String origin) {
    return '来源：$origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable => '请输入有效 URL 以预览其安全来源。';

  @override
  String get subscriptionReadOnly => '只读订阅';

  @override
  String get subscriptionNeverRefreshed => '尚未刷新';

  @override
  String subscriptionLastRefresh(String time) {
    return '上次成功刷新：$time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return '下次刷新：$time';
  }

  @override
  String get subscriptionStatusHealthy => '已是最新';

  @override
  String subscriptionStatusIssue(String code) {
    return '刷新问题：$code';
  }

  @override
  String get refreshNow => '立即刷新';

  @override
  String get unsubscribe => '取消订阅';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '要取消订阅“$name”吗？';
  }

  @override
  String get unsubscribeCalendarConfirmation => '这会移除本地订阅及其缓存的活动。已发布的日历不会更改。';

  @override
  String get addSubscriptionAction => '添加订阅';

  @override
  String subscriptionOperationFailed(String error) {
    return '日历订阅失败：$error';
  }

  @override
  String get subscriptions => '订阅';

  @override
  String get calendarImport => '日历导入';

  @override
  String get calendarImportDescription => '选择文件，查看其中的活动，然后选择接收这些活动的可写日历。';

  @override
  String get importIcsFile => '导入 .ics 文件';

  @override
  String get importIcsPreview => '导入日历活动';

  @override
  String importEventsFound(int count) {
    return '可导入活动集：$count';
  }

  @override
  String importInvalidEvents(int count) {
    return '无效活动：$count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return '有意省略：$fields';
  }

  @override
  String get noWritableCalendars => '没有可用的可写目标日历。';

  @override
  String get importDestinationCalendar => '目标日历';

  @override
  String get importIcsConfirm => '导入活动';

  @override
  String get importIcsComplete => '导入完成';

  @override
  String importQueued(int count) {
    return '已导入或已排队：$count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return '已跳过重复项：$count';
  }

  @override
  String importUnsupportedSets(int count) {
    return '不支持的重复集：$count';
  }

  @override
  String importIcsFailed(String error) {
    return '无法导入日历文件：$error';
  }

  @override
  String get networkOffline => '离线';

  @override
  String get networkOfflineDescription => '恢复连接后将同步更改。';

  @override
  String get networkOfflineTryAgain => '您当前处于离线状态。请连接互联网后重试。';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return '$days';
  }

  @override
  String get repeatSummarySeparator => '';

  @override
  String repeatMonthDayValue(String day) {
    return '$day日';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first、$second';
  }

  @override
  String repeatMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatYearlyMonthListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyOnMonthDaySummary(
    String frequency,
    String month,
    String day,
  ) {
    return '$frequency$month$day';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency$month的$days';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency$months的$day';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency$months的$days';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一个$days',
      'second': '第二个$days',
      'third': '第三个$days',
      'fourth': '第四个$days',
      'fifth': '第五个$days',
      'secondToLast': '倒数第二个$days',
      'last': '最后一个$days',
      'other': '$days',
    });
    return '$frequency$month的$_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一个$days',
      'second': '第二个$days',
      'third': '第三个$days',
      'fourth': '第四个$days',
      'fifth': '第五个$days',
      'secondToLast': '倒数第二个$days',
      'last': '最后一个$days',
      'other': '$days',
    });
    return '$frequency$months的$_temp0';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      '连接 Google、Microsoft、Apple iCloud Calendar 或 Nextcloud 账户。';

  @override
  String get googlePermissionsConsentNotice => '在 Google 权限页面上，同时选择日历和任务权限。';

  @override
  String get googlePermissionsRequiredRetry =>
      '必须授予 Google 日历和 Google Tasks 权限。请重试并选中两个复选框。';

  @override
  String get finishSetup => '完成设置';

  @override
  String get continueSetup => '继续';

  @override
  String get onboardingSetupTitle => '设置 BusyMax';

  @override
  String get onboardingAccountsStepTitle => '连接帐户';

  @override
  String get onboardingAccountsStepDescription =>
      '添加所有要使用的账户。BusyMax 会同步每个账户中受支持的日历、活动、任务列表和任务。';

  @override
  String get onboardingPreferencesStepTitle => '选择系统设置';

  @override
  String get onboardingPreferencesStepDescription =>
      '打开日程前，请设置桌面行为、提醒、通知详细程度和外观。';

  @override
  String get signInWithGoogle => '使用 Google 登录';

  @override
  String get signInWithMicrosoft => '使用 Microsoft 登录';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => '尚未配置此服务。';

  @override
  String get waitingForGoogleSignIn => '正在等待 Google 登录...';

  @override
  String get waitingForMicrosoftSignIn => '正在等待 Microsoft 登录...';

  @override
  String get microsoftSignInNotConfigured =>
      '尚未配置 Microsoft 登录。请设置 MICROSOFT_OAUTH_CLIENT_ID。';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get exit => '退出';

  @override
  String get options => '选项';

  @override
  String get hide => '隐藏';

  @override
  String get show => '显示';

  @override
  String get export => '导出';

  @override
  String get save => '保存';

  @override
  String get settings => '设置';

  @override
  String get all => '全部';

  @override
  String get calendarEvents => '日程';

  @override
  String get calendarTasks => '任务';

  @override
  String get calendar => '日历';

  @override
  String get calendars => '日历';

  @override
  String get newCalendar => '新建日历';

  @override
  String get calendarColor => '日历颜色';

  @override
  String calendarColorOption(int number) {
    return '颜色 $number';
  }

  @override
  String get calendarManagementUnsupported => '此提供商不支持 BusyMax 中的日历管理。';

  @override
  String get primaryCalendarCannotDelete => '无法删除主日历。';

  @override
  String calendarCreateFailed(String error) {
    return '无法创建日历：$error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      '日历已创建，但 BusyMax 无法刷新账户。它将在下次同步后显示。';

  @override
  String calendarUpdateFailed(String error) {
    return '无法更新日历：$error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return '无法删除日历：$error';
  }

  @override
  String get newEvent => '新建日程';

  @override
  String get refreshCalendar => '刷新日历';

  @override
  String get openInProvider => '在服务中打开';

  @override
  String get hideFromSchedule => '从日程中隐藏';

  @override
  String get showInSchedule => '在日程中显示';

  @override
  String get noCalendarsSynced => '尚未同步任何日历。';

  @override
  String get allDay => '全天';

  @override
  String moreItems(int count) {
    return '还有 $count 项';
  }

  @override
  String get noEventsOrTasks => '没有日程或任务';

  @override
  String get scheduleLoading => '正在加载日程...';

  @override
  String get scheduleUnavailable => '日程不可用';

  @override
  String get scheduleNoSources => '没有可见的日历或任务列表';

  @override
  String get scheduleNoSourcesDescription => '请在设置中选择要显示的内容，然后刷新。';

  @override
  String get scheduleSignInRequired => '连接帐户';

  @override
  String get scheduleSignInDescription => '登录以同步日历和任务。';

  @override
  String get scheduleNoSearchResults => '没有匹配的日程或任务';

  @override
  String get scheduleNoSearchResultsDescription => '请尝试其他搜索内容或清除当前筛选条件。';

  @override
  String get refresh => '刷新';

  @override
  String get trayOpenBusyMax => '打开 BusyMax';

  @override
  String get trayShowBusyMax => '显示 BusyMax';

  @override
  String get trayNewEvent => '新活动…';

  @override
  String get trayNewTask => '新任务…';

  @override
  String get trayToday => '今天';

  @override
  String get trayAllDay => '全天';

  @override
  String get trayNow => '现在';

  @override
  String get trayCalendarEvent => '日历活动';

  @override
  String get trayUntitledEvent => '无标题活动';

  @override
  String get trayNothingElseToday => '今天没有其他内容';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天有 $count 个任务到期',
      one: '今天有 1 个任务到期',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => '打开今天的日程';

  @override
  String get traySyncNow => '立即同步';

  @override
  String get traySyncing => '正在同步…';

  @override
  String get trayNotConnected => '未连接';

  @override
  String get trayNotYetSynced => '尚未同步';

  @override
  String get trayLastSyncedJustNow => '刚刚同步';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前同步',
      one: '1 分钟前同步',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前同步',
      one: '1 小时前同步',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前同步',
      one: '1 天前同步',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => '设置';

  @override
  String get trayQuitBusyMax => '退出 BusyMax';

  @override
  String get agendaLoadMoreOverdue => '加载更多逾期任务';

  @override
  String get agendaLoadMoreNoDate => '加载更多无日期任务';

  @override
  String get viewDay => '日';

  @override
  String get viewWeek => '周';

  @override
  String get viewMonth => '月';

  @override
  String get viewYear => '年';

  @override
  String get viewAgenda => '日程';

  @override
  String get scheduleSettings => '日程';

  @override
  String get scheduleDisplaySettings => '日程显示';

  @override
  String get scheduleDisplayHoursDescription =>
      '日视图和周视图最初显示此时间范围。需要时，更早或更晚的项目会扩展该范围。';

  @override
  String get scheduleDayStartsAt => '每日开始时间';

  @override
  String get scheduleDayEndsAt => '每日结束时间';

  @override
  String get sourceCalendar => '日历';

  @override
  String get sourceTaskList => '任务列表';

  @override
  String get createChoiceTitle => '新建';

  @override
  String get createEventAtTime => '日程';

  @override
  String get createTaskAtDate => '任务';

  @override
  String get editEvent => '编辑日程';

  @override
  String get eventTitle => '日程标题';

  @override
  String get location => '地点';

  @override
  String get timeSlot => '时间段';

  @override
  String get startDateTime => '开始日期/时间';

  @override
  String get endDateTime => '结束日期/时间';

  @override
  String get doesNotRepeat => '不重复';

  @override
  String get defaultReminder => '默认提醒';

  @override
  String get guests => '参与者';

  @override
  String get noGuests => '无参与者';

  @override
  String get attendeeRequired => '必需';

  @override
  String get attendeeOptional => '可选';

  @override
  String get meetingSection => '会议';

  @override
  String get addGoogleMeet => '添加 Google Meet';

  @override
  String get addTeamsMeeting => '添加 Microsoft Teams 会议';

  @override
  String get onlineMeetingAdded => '已添加在线会议';

  @override
  String get requestResponses => '请求回复';

  @override
  String get requestResponsesDescription => '要求参与者回复邀请。';

  @override
  String get hideGuestList => '隐藏参与者列表';

  @override
  String get hideGuestListDescription => '参与者无法查看其他受邀者。';

  @override
  String get allowNewTimeProposals => '允许提出新时间';

  @override
  String get allowNewTimeProposalsDescription => '参与者可以建议其他会议时间。';

  @override
  String get notifyGuestsTitle => '通知参与者？';

  @override
  String get notifyGuestsSaveMessage => '此会议有参与者。保存时发送邀请或活动更新吗？';

  @override
  String get notifyGuestsDeleteMessage => '此会议有参与者。删除时发送取消通知吗？';

  @override
  String get sendUpdates => '发送更新';

  @override
  String get sendCancellation => '发送取消通知';

  @override
  String get doNotSend => '不发送';

  @override
  String get microsoftNotifyGuestsSaveTitle => '保存会议？';

  @override
  String get microsoftNotifyGuestsSaveMessage => 'Microsoft 将向参与者发送邀请或活动更新。';

  @override
  String get microsoftNotifyGuestsDeleteTitle => '删除会议？';

  @override
  String get microsoftNotifyGuestsDeleteMessage => 'Microsoft 将向参与者发送取消通知。';

  @override
  String get organizer => '组织者';

  @override
  String get yourResponse => '你的回复';

  @override
  String get guestResponses => '参与者回复';

  @override
  String get respond => '回复';

  @override
  String get acceptInvitation => '接受';

  @override
  String get tentativeInvitation => '暂定';

  @override
  String get declineInvitation => '拒绝';

  @override
  String get joinMeeting => '加入会议';

  @override
  String get responseAccepted => '已接受';

  @override
  String get responseTentative => '暂定';

  @override
  String get responseDeclined => '已拒绝';

  @override
  String get responseNeedsAction => '等待回复';

  @override
  String get responseNotResponded => '未回复';

  @override
  String get responseOrganizer => '组织者';

  @override
  String invitationResponseFailed(String error) {
    return '无法发送回复：$error';
  }

  @override
  String get joinMeetingFailed => '无法打开会议链接。';

  @override
  String get description => '说明';

  @override
  String get availabilityShowAs => '空闲状态 / 显示为';

  @override
  String get busy => '忙碌';

  @override
  String get visibility => '可见性';

  @override
  String get defaultVisibility => '默认可见性';

  @override
  String get conference => '会议';

  @override
  String get noConference => '无会议';

  @override
  String get providerCalendar => '服务日历';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => '粗体';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => '斜体';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => '下划线';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟前',
      one: '1 分钟前',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => '开始时';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时前',
      one: '1 小时前',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => '空闲';

  @override
  String get availabilityTentative => '暂定';

  @override
  String get availabilityOutOfOffice => '不在办公室';

  @override
  String get availabilityWorkingElsewhere => '在其他地点办公';

  @override
  String get visibilityDefault => '默认';

  @override
  String get visibilityPublic => '公开';

  @override
  String get visibilityPrivate => '私密';

  @override
  String get visibilityConfidential => '机密';

  @override
  String get sensitivityNormal => '普通';

  @override
  String get sensitivityPersonal => '个人';

  @override
  String get tasks => '任务';

  @override
  String get allTasks => '所有任务';

  @override
  String tasksInList(String title) {
    return '$title中的任务';
  }

  @override
  String get taskLists => '任务列表';

  @override
  String get navigation => '导航';

  @override
  String get mainMenu => '主菜单';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get shortcutGroupGeneral => '常规';

  @override
  String get shortcutKeyboardShortcutsDescription => '显示快捷键参考表';

  @override
  String get shortcutGroupNavigation => '导航';

  @override
  String get shortcutNextPeriod => '下一时段';

  @override
  String get shortcutNextPeriodDescription => '在周视图中前往下一周，在月视图中前往下个月，依此类推';

  @override
  String get shortcutPreviousPeriod => '上一时段';

  @override
  String get shortcutPreviousPeriodDescription => '在周视图中前往上一周，在月视图中前往上个月，依此类推';

  @override
  String get shortcutJumpToToday => '跳转到今天';

  @override
  String get shortcutGroupView => '视图';

  @override
  String get shortcutDayView => '日视图';

  @override
  String get shortcutWeekView => '周视图';

  @override
  String get shortcutMonthView => '月视图';

  @override
  String get shortcutYearView => '年视图';

  @override
  String get shortcutAgendaView => '日程视图';

  @override
  String get shortcutGroupCreateAndEdit => '新建和编辑';

  @override
  String get shortcutSaveItem => '保存日程或任务';

  @override
  String get shortcutDeleteItem => '删除日程或任务';

  @override
  String get shortcutGroupTaskEditing => '任务编辑';

  @override
  String get shortcutCancelEditing => '取消编辑';

  @override
  String get shortcutCancelEditingDescription => '关闭任务编辑或任务详情';

  @override
  String get aboutBusyMax => '关于 BusyMax';

  @override
  String get aboutBusyMaxDescription => '日历和任务';

  @override
  String get license => '许可证';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => '网站';

  @override
  String get sourceCode => '源代码';

  @override
  String get reportAnIssue => '报告问题';

  @override
  String get sendFeedback => '发送反馈';

  @override
  String get feedbackSubmit => '提交';

  @override
  String get feedbackCategory => '类别';

  @override
  String get feedbackSelectCategory => '选择类别';

  @override
  String get feedbackCategoryProblem => '问题或错误';

  @override
  String get feedbackCategoryFeature => '功能请求';

  @override
  String get feedbackCategoryPrivacySecurity => '隐私或安全问题';

  @override
  String get feedbackCategoryUsability => '易用性问题';

  @override
  String get feedbackCategoryOther => '其他';

  @override
  String get feedbackSubject => '主题';

  @override
  String get feedbackDetailedMessage => '详细信息';

  @override
  String get feedbackReplyEmail => '用于接收回复的电子邮件地址（可选）';

  @override
  String get feedbackIncludeTechnicalDetails => '包含技术详情';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      '仅添加您的 Linux 操作系统版本和应用区域设置。不包含日志、帐户数据、文件名或其他诊断信息。';

  @override
  String get feedbackCategoryRequired => '请选择类别。';

  @override
  String get feedbackSubjectLengthError => '主题必须为 3 至 120 个字符。';

  @override
  String get feedbackMessageLengthError => '消息必须为 10 至 5,000 个字符。';

  @override
  String get feedbackInvalidEmail => '请输入有效的电子邮件地址。';

  @override
  String get feedbackConnectionError => '无法连接到 BusyStack。请检查连接，然后重试。';

  @override
  String get feedbackTimeoutError => '请求超时。您的反馈尚未清除，请重试。';

  @override
  String get feedbackRateLimitedError => '从此网络发送的反馈过多。请稍后再试。';

  @override
  String get feedbackRejectedError => '服务器拒绝了提交。请检查各字段，然后重试。';

  @override
  String get feedbackServerError => 'BusyStack 目前无法接收您的反馈。您的反馈尚未清除，请重试。';

  @override
  String feedbackSuccess(String id) {
    return '反馈已发送。参考编号：$id';
  }

  @override
  String get toggleSidebar => '显示或隐藏侧边栏';

  @override
  String get showSidebar => '显示侧边栏面板';

  @override
  String get hideSidebar => '隐藏侧边栏面板';

  @override
  String get accounts => '帐户';

  @override
  String get currentAccount => '当前帐户';

  @override
  String get switchAccount => '切换帐户';

  @override
  String get addGoogleAccount => '添加 Google 帐户';

  @override
  String get addMicrosoftAccount => '添加 Microsoft 帐户';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => '已登录';

  @override
  String get removeAccount => '移除帐户…';

  @override
  String get removingAccount => '正在移除帐户…';

  @override
  String get removeAccountDescription => '停止同步并从此设备移除此帐户的数据。';

  @override
  String removeAccountTitle(String account) {
    return '从 BusyMax 中移除 $account？';
  }

  @override
  String get removeAccountConfirmation =>
      '这会从此设备删除缓存的任务、日历、活动、提醒和待处理的离线更改。未同步的更改将会丢失。提供商中的日历、活动、任务列表和任务副本不会被删除。';

  @override
  String get revokeGoogleAccess => '同时撤销 BusyMax 对此 Google 帐户的访问权限';

  @override
  String get revokeGoogleAccessDescription => '重新连接之前，您需要再次授予访问权限。';

  @override
  String get removeAccountAction => '移除帐户';

  @override
  String get removeAccountFailed => '无法完成帐户移除。请重试。';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      '该帐户已从此设备移除，但无法撤销 BusyMax 对您的 Google 帐户的访问权限。您可以在 Google 帐户中手动撤销该权限。';

  @override
  String get newTaskList => '新任务列表';

  @override
  String taskListCreateFailed(String error) {
    return '无法创建任务列表：$error';
  }

  @override
  String taskListRenameFailed(String error) {
    return '无法重命名任务列表：$error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return '无法删除任务列表：$error';
  }

  @override
  String get signInToViewTaskLists => '登录以查看任务列表。';

  @override
  String get noTaskListsSynced => '尚未同步任何任务列表。';

  @override
  String get listActions => '列表操作';

  @override
  String get rename => '重命名';

  @override
  String get delete => '删除';

  @override
  String get renameList => '重命名列表';

  @override
  String get deleteList => '删除列表';

  @override
  String get unshare => '取消共享';

  @override
  String get readOnlyTaskListCannotRename => '此任务列表为只读，无法重命名。';

  @override
  String get taskListCannotDelete => '使用当前权限无法删除此任务列表。';

  @override
  String get builtInMicrosoftList => '内置';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      '无法重命名或删除 Microsoft To Do 内置列表。';

  @override
  String deleteListConfirmation(String title) {
    return '要从 Google Tasks 中删除“$title”吗？';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '要删除“$title”及其所有任务吗？';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return '要取消此账户对“$title”的共享吗？';
  }

  @override
  String get deleteEvent => '删除日程';

  @override
  String get title => '标题';

  @override
  String get create => '新建';

  @override
  String get newTask => '新建任务';

  @override
  String get clearCompleted => '清除已完成项';

  @override
  String get refreshList => '刷新列表';

  @override
  String get refreshAll => '全部刷新';

  @override
  String get listRefreshed => '列表已刷新。';

  @override
  String get allTasksRefreshed => '所有帐户均已刷新。';

  @override
  String exportedFile(String path) {
    return '已导出到 $path';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String refreshFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String get selectOrCreateTaskList => '请选择或创建任务列表以开始使用。';

  @override
  String get signInToViewTasks => '登录以查看任务。';

  @override
  String get noTasks => '没有任务。';

  @override
  String get noTasksYet => '还没有任务';

  @override
  String get noTasksYetMessage => '创建任务或刷新帐户以开始使用。';

  @override
  String get noTasksInList => '此列表中没有任务。';

  @override
  String get overdue => '已逾期';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get upcoming => '即将到期';

  @override
  String get noDate => '无日期';

  @override
  String get completed => '已完成';

  @override
  String duePrefix(String date) {
    return '$date 到期';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => '任务详情';

  @override
  String get editTask => '编辑任务';

  @override
  String get noTaskSelected => '未选择任务。';

  @override
  String get noTaskSelectedHelper => '选择任务以查看和编辑详情。';

  @override
  String get taskUnavailable => '任务不可用。';

  @override
  String get signInToEditTasks => '登录以编辑任务。';

  @override
  String get refreshTask => '刷新任务';

  @override
  String get primarySection => '主要信息';

  @override
  String get statusSection => '状态';

  @override
  String get openStatus => '未完成';

  @override
  String get doneStatus => '已完成';

  @override
  String get taskStatus => '状态';

  @override
  String get taskStatusNone => '无状态';

  @override
  String get taskStatusNeedsAction => '需要操作';

  @override
  String get taskStatusInProcess => '进行中';

  @override
  String get taskStatusCompleted => '已完成';

  @override
  String get taskStatusCancelled => '已取消';

  @override
  String completionPercent(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get completionDate => '完成日期';

  @override
  String get priority => '优先级';

  @override
  String get priorityNone => '无优先级';

  @override
  String priorityHighValue(int priority) {
    return '优先级 $priority · 高';
  }

  @override
  String priorityMediumValue(int priority) {
    return '优先级 $priority · 中';
  }

  @override
  String priorityLowValue(int priority) {
    return '优先级 $priority · 低';
  }

  @override
  String get taskUrl => '任务 URL';

  @override
  String get invalidTaskUrl => '请输入包含方案的绝对 URL。';

  @override
  String get classification => '分类';

  @override
  String get classificationPublic => '共享时显示完整任务';

  @override
  String get classificationConfidential => '共享时仅显示忙碌状态';

  @override
  String get classificationPrivate => '共享时隐藏此任务';

  @override
  String get pinTask => '固定任务';

  @override
  String get notes => '备注';

  @override
  String get dueDate => '截止日期';

  @override
  String get clearDueDate => '清除截止日期';

  @override
  String get dueTime => '截止时间';

  @override
  String get startDate => '开始日期';

  @override
  String get startTime => '开始时间';

  @override
  String get endDate => '结束日期';

  @override
  String get endTime => '结束时间';

  @override
  String get reminderDate => '提醒日期';

  @override
  String get reminderTime => '提醒时间';

  @override
  String get reminder => '提醒';

  @override
  String get addReminder => '添加提醒';

  @override
  String get reminders => '提醒';

  @override
  String get noReminders => '无提醒';

  @override
  String get editReminder => '编辑提醒';

  @override
  String get beforeTaskStarts => '任务开始前';

  @override
  String get beforeTaskDue => '任务到期前';

  @override
  String get afterTaskStarts => '任务开始后';

  @override
  String get afterTaskDue => '任务到期后';

  @override
  String get relativeToTaskStart => '相对于任务开始日期';

  @override
  String get relativeToTaskDue => '相对于任务到期日期';

  @override
  String get reminderTimeOfDay => '时间';

  @override
  String get absoluteReminder => '在指定日期和时间';

  @override
  String get reminderAmount => '数量';

  @override
  String get reminderUnit => '单位';

  @override
  String get reminderUnitSeconds => '秒';

  @override
  String get reminderUnitMinutes => '分钟';

  @override
  String get reminderUnitHours => '小时';

  @override
  String get reminderUnitDays => '天';

  @override
  String get reminderUnitWeeks => '周';

  @override
  String get reminderAtTaskStart => '任务开始时';

  @override
  String get reminderAtTaskDue => '任务到期时';

  @override
  String get unsupportedReminder => '此提醒类型会保留，但无法编辑其时间。';

  @override
  String get relatedRemindersTitle => '保留相关提醒？';

  @override
  String relatedRemindersDescription(int count) {
    return '此日期有 $count 个相关提醒。要保留它们当前的日期和时间吗？';
  }

  @override
  String get discardRelatedReminders => '舍弃提醒';

  @override
  String get keepRelatedReminders => '保留提醒';

  @override
  String get addGuest => '添加参与者';

  @override
  String get addGuestEmail => '添加参与者电子邮件';

  @override
  String get removeReminder => '移除提醒';

  @override
  String get off => '关闭';

  @override
  String get repeat => '重复';

  @override
  String get repeatNone => '不重复';

  @override
  String get noneValue => '无';

  @override
  String get repeatDaily => '每天';

  @override
  String get repeatWeekly => '每周';

  @override
  String get repeatMonthly => '每月';

  @override
  String get repeatYearly => '每年';

  @override
  String get repeatEvery => '重复间隔';

  @override
  String get repeatOn => '重复日期';

  @override
  String get repeatEnd => '结束重复';

  @override
  String get repeatNever => '从不';

  @override
  String get repeatUntil => '指定日期';

  @override
  String get repeatAfter => '指定次数后';

  @override
  String get repeatCount => '重复次数';

  @override
  String get repeatDayOfMonth => '每月日期';

  @override
  String get repeatMonths => '月份';

  @override
  String get repeatOrdinal => '星期位置';

  @override
  String get repeatSpecificDays => '特定日期';

  @override
  String get repeatFirst => '第一';

  @override
  String get repeatSecond => '第二';

  @override
  String get repeatThird => '第三';

  @override
  String get repeatFourth => '第四';

  @override
  String get repeatFifth => '第五';

  @override
  String get repeatSecondToLast => '倒数第二';

  @override
  String get repeatLast => '最后';

  @override
  String get repeatAnyDay => '日期';

  @override
  String get repeatWeekday => '工作日';

  @override
  String get repeatWeekendDay => '周末';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': '星期一',
      'TU': '星期二',
      'WE': '星期三',
      'TH': '星期四',
      'FR': '星期五',
      'SA': '星期六',
      'SU': '星期日',
      'day': '日期',
      'weekday': '工作日',
      'weekend': '周末',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    return '每 $count 天';
  }

  @override
  String repeatEveryWeeks(int count) {
    return '每 $count 周';
  }

  @override
  String repeatEveryMonths(int count) {
    return '每 $count 个月';
  }

  @override
  String repeatEveryYears(int count) {
    return '每 $count 年';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '在 $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一个$days',
      'second': '第二个$days',
      'third': '第三个$days',
      'fourth': '第四个$days',
      'fifth': '第五个$days',
      'secondToLast': '倒数第二个$days',
      'last': '最后一个$days',
      'other': '$days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return '在 $months';
  }

  @override
  String repeatTimesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重复 $count 次',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return '直到 $date';
  }

  @override
  String get unsupportedRecurrencePreserved => '此重复规则使用了编辑器不会更改的选项。';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return '此重复规则不能用于 $provider。';
  }

  @override
  String get importance => '重要性';

  @override
  String get importanceLow => '低';

  @override
  String get importanceNormal => '普通';

  @override
  String get importanceHigh => '高';

  @override
  String get categories => '类别';

  @override
  String get scheduleSection => '日程';

  @override
  String get dueGroup => '截止';

  @override
  String get startGroup => '开始';

  @override
  String get reminderGroup => '提醒';

  @override
  String get organizationSection => '整理';

  @override
  String get actionsSection => '操作';

  @override
  String get advancedSection => '高级';

  @override
  String get addCategory => '添加类别';

  @override
  String get list => '列表';

  @override
  String get microsoftMoveUnsupported => '此版本不支持在 Microsoft To Do 帐户的列表之间移动任务。';

  @override
  String get createSubtask => '创建子任务';

  @override
  String get subtasks => '子任务';

  @override
  String get duplicateTask => '复制任务';

  @override
  String get taskDuplicated => '任务已复制。';

  @override
  String taskDuplicateFailed(String error) {
    return '无法复制任务：$error';
  }

  @override
  String get hideSubtasks => '隐藏子任务';

  @override
  String get hideClosedSubtasks => '隐藏已关闭的子任务';

  @override
  String get moveToTop => '移到顶部';

  @override
  String get deleteTask => '删除任务';

  @override
  String get newSubtask => '新建子任务';

  @override
  String deleteTaskConfirmation(String title) {
    return '删除“$title”？';
  }

  @override
  String get metadata => '元数据';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => '更新时间';

  @override
  String get parent => '父任务';

  @override
  String get position => '位置';

  @override
  String get webLink => '网页链接';

  @override
  String get assignment => '分配';

  @override
  String get localState => '本地状态';

  @override
  String get pendingSync => '等待同步';

  @override
  String get synced => '已同步';

  @override
  String get account => '帐户';

  @override
  String get sync => '同步';

  @override
  String get forceFullResync => '强制完全重新同步';

  @override
  String get forceFullResyncDescription =>
      '从每个已连接的账号中重新完整加载所有数据。请仅在排查同步问题时使用此功能。';

  @override
  String get runInBackgroundWhenClosed => '窗口关闭后继续在后台运行';

  @override
  String get showTrayIcon => '显示托盘图标';

  @override
  String get startMinimizedToTray => '启动时最小化到托盘';

  @override
  String get launchAtLogin => '登录时启动';

  @override
  String get launchAtLoginDescription => '在后台启动 BusyMax，以便登录后提醒能够正常工作。';

  @override
  String get launchAtLoginFailed => '无法更新登录时启动设置。';

  @override
  String get requiresTrayIcon => '需要托盘图标。';

  @override
  String get syncComplete => '同步完成。';

  @override
  String syncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String get notifySyncFailures => '同步失败通知';

  @override
  String get notifyConflicts => '冲突通知';

  @override
  String get notifyDueToday => '今天到期任务通知';

  @override
  String get eventReminders => '日程提醒';

  @override
  String get onState => '开启';

  @override
  String get taskReminders => '任务提醒';

  @override
  String get notificationDetailLevel => '通知详细程度';

  @override
  String get notificationDetailPrivate => '私密';

  @override
  String get notificationDetailNormal => '普通';

  @override
  String get quietHours => '免打扰时段';

  @override
  String get quietHoursDescription => '在此时段暂停通知。';

  @override
  String get quietHoursStart => '免打扰开始时间';

  @override
  String get quietHoursEnd => '免打扰结束时间';

  @override
  String get notifications => '通知';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '系统';

  @override
  String get settingsSystem => '系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeFamily => '主题系列';

  @override
  String get themeFamilyYaru => 'Ubuntu 原生主题（Yaru）';

  @override
  String get localization => '语言和区域';

  @override
  String get currentLocale => '当前区域设置';

  @override
  String get privacy => '隐私';

  @override
  String get redactTaskContentInDiagnostics => '在诊断信息中隐藏任务内容';

  @override
  String get developerDiagnostics => '开发者诊断';

  @override
  String get diagnostics => '诊断';

  @override
  String get apiInspectorDisabled => '显示 API 检查器';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery 修订版：$revision';
  }

  @override
  String get implementedMethods => '已实现的方法';

  @override
  String get supportsTasksScopes => '支持 tasks 和 tasks.readonly 权限范围';

  @override
  String get requiresTasksScope => '需要 tasks 权限范围';

  @override
  String get blockedPendingOperations => '被阻止的待处理操作';

  @override
  String get signInToInspectPendingOperations => '登录以检查待处理操作。';

  @override
  String get noBlockedPendingOperations => '没有被阻止的待处理操作。';

  @override
  String get operationActions => '操作选项';

  @override
  String pendingOpListId(String id) {
    return '列表=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return '任务=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return '尝试次数=$count';
  }

  @override
  String get retry => '重试';

  @override
  String get discard => '舍弃';

  @override
  String get discardChangesAction => '舍弃';

  @override
  String get discardChanges => '舍弃更改？';

  @override
  String get discardChangesConfirmation => '这将舍弃对此任务所做的未保存编辑。';

  @override
  String get retryCompleted => '重试完成。';

  @override
  String get discardPendingOperation => '舍弃待处理操作？';

  @override
  String get discardPendingOperationConfirmation =>
      '这将移除被阻止的本地操作。下次同步时将从 Google Tasks 刷新数据。';

  @override
  String get pendingOperationDiscarded => '已舍弃待处理操作。';

  @override
  String get syncFailureNotificationTitle => 'BusyMax 同步失败';

  @override
  String syncFailureNotificationBody(String message) {
    return '后台同步失败。$message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax 同步冲突';

  @override
  String conflictNotificationBody(String summary) {
    return '一项待处理的本地更改被阻止。$summary';
  }

  @override
  String get dueTodayNotificationTitle => '今天到期的任务';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天有 $count 项任务到期。',
      one: '今天有 1 项任务到期。',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => '日程提醒';

  @override
  String get taskReminderNotificationTitle => '任务提醒';

  @override
  String get eventReminderNotificationBody => '日程即将开始。';

  @override
  String get taskReminderNotificationBody => '任务即将到期。';

  @override
  String get notificationOpenAction => '打开';

  @override
  String get notificationSnoozeAction => '10 分钟后提醒';

  @override
  String get notificationDismissAction => '关闭';

  @override
  String get notificationDetailsHidden => '根据隐私设置，详细信息已隐藏。';

  @override
  String get previousMonth => '上个月';

  @override
  String get nextMonth => '下个月';

  @override
  String get openMonthView => '打开月视图';

  @override
  String get previousYear => '上一年';

  @override
  String get nextYear => '下一年';

  @override
  String get openYearView => '打开年视图';

  @override
  String weekNumberTooltip(int number) {
    return '第 $number 周';
  }

  @override
  String get resizeAllDayPanel => '调整全天面板的大小';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
      one: '1 项',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => '此日历为只读。';

  @override
  String get selectTimeZone => '选择时区';

  @override
  String get searchLocations => '搜索地点';

  @override
  String get noLocationsFound => '未找到地点';

  @override
  String get requiredField => '此字段为必填项。';

  @override
  String get providerConnectionDescription => '连接以下任一提供商中的日历和任务。';

  @override
  String get appleICloudProvider => 'Apple iCloud 日历';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud 任务';

  @override
  String get addAppleICloudAccount => '添加 Apple iCloud 日历账户';

  @override
  String get addNextcloudAccount => '添加 Nextcloud 账户';

  @override
  String get waitingForAppleICloud => '正在连接 Apple iCloud…';

  @override
  String get waitingForNextcloud => '正在等待 Nextcloud 授权…';

  @override
  String get connectAppleICloudTitle => '连接 Apple iCloud 日历';

  @override
  String get appleAccountEmail => 'Apple 账户电子邮件';

  @override
  String get appleAppSpecificPassword => 'App 专用密码';

  @override
  String get appleAppSpecificPasswordHelp => '为 Apple 账户启用双重认证后，创建 App 专用密码。';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      '重置 Apple 账户密码会撤销 App 专用密码。';

  @override
  String get connectNextcloudTitle => '连接 Nextcloud';

  @override
  String get nextcloudServerUrl => 'Nextcloud 服务器或 CalDAV 地址';

  @override
  String get nextcloudServerUrlHelp =>
      '输入 Nextcloud 服务器 URL，或粘贴从 Nextcloud 复制的主要 CalDAV 地址。';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax 将打开浏览器。请在那里批准访问，然后返回 BusyMax。';

  @override
  String get connectAccountAction => '连接';

  @override
  String get cancelAccountConnection => '取消连接';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      '账户已在本地移除，但无法撤销 Nextcloud App 密码。';

  @override
  String get davCachedOfflineNotice => '日历和任务数据会缓存在本地，以供离线使用。';

  @override
  String get davReauthenticationRequired => '重新连接此账户以恢复同步。';

  @override
  String get davTemporarilyUnavailable => '此账户暂时不可用。';

  @override
  String get davPermissionChanged => '服务器权限已更改。待处理的编辑已暂停。';

  @override
  String get davUnsupportedServer => '不支持此服务器或提供商配置。';

  @override
  String get collectionSettings => '日历和任务列表';

  @override
  String get calendarContent => '日历活动';

  @override
  String get taskContent => '任务';

  @override
  String get readOnlySharedCollection => '只读';

  @override
  String get pendingLocally => '本地待处理';

  @override
  String get conflictBlocked => '因冲突而阻止';

  @override
  String get authenticationBlocked => '重新连接前阻止';

  @override
  String get operationFailed => '操作失败';

  @override
  String get keepServerVersion => '保留服务器版本';

  @override
  String get reapplyLocalChange => '查看并重新应用本地更改';

  @override
  String get duplicateLocalItem => '复制为新项目';

  @override
  String get davConnectionState => '连接状态';

  @override
  String get davConnected => '已连接';

  @override
  String get davConnecting => '正在连接…';

  @override
  String get davSignedOut => '已退出登录';

  @override
  String davLastSuccessfulSync(String time) {
    return '上次成功同步：$time';
  }

  @override
  String get davNeverSynced => '尚未同步';

  @override
  String get refreshCollections => '刷新日历和任务列表';

  @override
  String nextcloudServerHost(String host) {
    return '服务器：$host';
  }

  @override
  String get collectionSupportsEvents => '活动日历';

  @override
  String get collectionSupportsTasks => '任务列表';

  @override
  String get collectionSupportsEventsAndTasks => '活动和任务';

  @override
  String get writableCollection => '可写';

  @override
  String get sharedCollection => '已共享';

  @override
  String collectionLastSynced(String time) {
    return '上次同步：$time';
  }

  @override
  String collectionSyncError(String code) {
    return '同步问题：$code';
  }

  @override
  String get syncConflicts => '同步冲突';

  @override
  String remoteChangedAt(String time) {
    return '服务器更改：$time';
  }

  @override
  String localPendingEdit(String summary) {
    return '本地编辑：$summary';
  }

  @override
  String get conflictResolutionFailed => '无法解决冲突。';

  @override
  String get recurringEventScope => '重复活动范围';

  @override
  String get entireSeries => '整个系列';

  @override
  String get singleOccurrence => '此事件';

  @override
  String get thisAndFollowingEvents => '此事件及后续事件';

  @override
  String get thisAndFutureUnavailable => '此提供商不支持。';

  @override
  String get thisAndFutureMoveUnavailable => '无法安全移动此活动及后续活动。请选择此活动或整个系列。';

  @override
  String get entireSeriesMoveUnavailable => '本地没有可用的重复规则。请仅移动此活动。';

  @override
  String get copyEventAndDeleteOriginal => '复制活动并删除原活动？';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax 无法将此活动直接从 $source 移动到 $destination。应用会先创建副本，并且仅在复制成功后删除原活动。活动 ID 将发生变化；参与者的回复状态可能会重置，并可能发送邀请或取消通知；会议链接、附件、提醒、提供商特有的字段和重复例外可能无法保留。';
  }

  @override
  String get copyAndDelete => '复制并删除';

  @override
  String get chooseRecurringEventScope => '选择此更改适用于整个系列、仅此活动，还是此活动及后续活动。';

  @override
  String get taskDueBeforeStart => '截止时间不能早于开始时间。';

  @override
  String get taskStartDueTimeModeMismatch => '请同时设置开始和截止时间，或将任务设为全天。';

  @override
  String deleteCalendarConfirmation(String title) {
    return '删除“$title”？';
  }

  @override
  String get setCustomCalendarName => '设置自定义名称';

  @override
  String get setAction => '设置';

  @override
  String get removeFromMyCalendars => '从“我的日历”中移除';

  @override
  String get removeAction => '移除';

  @override
  String removeCalendarConfirmation(String title) {
    return '要从您的 Google 日历列表中移除“$title”吗？共享日历及其活动不会被删除。';
  }

  @override
  String get calendarCannotRemove => '无法从此账户删除或移除此日历。';

  @override
  String get calendarPendingChangesPreventRemoval =>
      '请等待此日历的待处理更改完成同步，然后再删除或移除它。';

  @override
  String get calendarSubscriptions => '日历订阅';

  @override
  String get calendarSubscriptionsDescription => '添加从安全 WebCal URL 刷新的只读日历。';

  @override
  String get addCalendarSubscription => '添加日历订阅';

  @override
  String get subscriptionName => '本地名称';

  @override
  String get subscriptionUrl => '订阅 URL';

  @override
  String get subscriptionUrlHelp =>
      '输入 HTTPS 或 webcal URL。BusyMax 会将完整 URL 保存在安全存储中。';

  @override
  String get subscriptionUrlInvalid => '请输入不含用户信息或片段的有效 HTTPS 或 webcal URL。';

  @override
  String get subscriptionColor => '本地颜色';

  @override
  String get subscriptionColorHelp => '使用六位颜色，例如 #3584E4。';

  @override
  String get subscriptionColorInvalid => '请输入六位十六进制颜色。';

  @override
  String get subscriptionRefreshMode => '刷新频率';

  @override
  String get subscriptionAutomatic => '自动';

  @override
  String get subscriptionHourly => '每小时';

  @override
  String get subscriptionSixHours => '每六小时';

  @override
  String get subscriptionDaily => '每天';

  @override
  String subscriptionSafeOrigin(String origin) {
    return '来源：$origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable => '请输入有效 URL 以预览其安全来源。';

  @override
  String get subscriptionReadOnly => '只读订阅';

  @override
  String get subscriptionNeverRefreshed => '尚未刷新';

  @override
  String subscriptionLastRefresh(String time) {
    return '上次成功刷新：$time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return '下次刷新：$time';
  }

  @override
  String get subscriptionStatusHealthy => '已是最新';

  @override
  String subscriptionStatusIssue(String code) {
    return '刷新问题：$code';
  }

  @override
  String get refreshNow => '立即刷新';

  @override
  String get unsubscribe => '取消订阅';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '要取消订阅“$name”吗？';
  }

  @override
  String get unsubscribeCalendarConfirmation => '这会移除本地订阅及其缓存的活动。已发布的日历不会更改。';

  @override
  String get addSubscriptionAction => '添加订阅';

  @override
  String subscriptionOperationFailed(String error) {
    return '日历订阅失败：$error';
  }

  @override
  String get subscriptions => '订阅';

  @override
  String get calendarImport => '日历导入';

  @override
  String get calendarImportDescription => '选择文件，查看其中的活动，然后选择接收这些活动的可写日历。';

  @override
  String get importIcsFile => '导入 .ics 文件';

  @override
  String get importIcsPreview => '导入日历活动';

  @override
  String importEventsFound(int count) {
    return '可导入活动集：$count';
  }

  @override
  String importInvalidEvents(int count) {
    return '无效活动：$count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return '有意省略：$fields';
  }

  @override
  String get noWritableCalendars => '没有可用的可写目标日历。';

  @override
  String get importDestinationCalendar => '目标日历';

  @override
  String get importIcsConfirm => '导入活动';

  @override
  String get importIcsComplete => '导入完成';

  @override
  String importQueued(int count) {
    return '已导入或已排队：$count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return '已跳过重复项：$count';
  }

  @override
  String importUnsupportedSets(int count) {
    return '不支持的重复集：$count';
  }

  @override
  String importIcsFailed(String error) {
    return '无法导入日历文件：$error';
  }

  @override
  String get networkOffline => '离线';

  @override
  String get networkOfflineDescription => '恢复连接后将同步更改。';

  @override
  String get networkOfflineTryAgain => '您当前处于离线状态。请连接互联网后重试。';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return '$days';
  }

  @override
  String get repeatSummarySeparator => '';

  @override
  String repeatMonthDayValue(String day) {
    return '$day日';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first、$second';
  }

  @override
  String repeatMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatYearlyMonthListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyOnMonthDaySummary(
    String frequency,
    String month,
    String day,
  ) {
    return '$frequency$month$day';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency$month的$days';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency$months的$day';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency$months的$days';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一个$days',
      'second': '第二个$days',
      'third': '第三个$days',
      'fourth': '第四个$days',
      'fifth': '第五个$days',
      'secondToLast': '倒数第二个$days',
      'last': '最后一个$days',
      'other': '$days',
    });
    return '$frequency$month的$_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一个$days',
      'second': '第二个$days',
      'third': '第三个$days',
      'fourth': '第四个$days',
      'fifth': '第五个$days',
      'secondToLast': '倒数第二个$days',
      'last': '最后一个$days',
      'other': '$days',
    });
    return '$frequency$months的$_temp0';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      '連接 Google、Microsoft、Apple iCloud Calendar 或 Nextcloud 帳戶。';

  @override
  String get googlePermissionsConsentNotice => '在 Google 權限畫面中，同時選取行事曆和待辦事項權限。';

  @override
  String get googlePermissionsRequiredRetry =>
      '必須授予 Google 日曆和 Google Tasks 權限。請再試一次並勾選兩個核取方塊。';

  @override
  String get finishSetup => '完成設定';

  @override
  String get continueSetup => '繼續';

  @override
  String get onboardingSetupTitle => '設定 BusyMax';

  @override
  String get onboardingAccountsStepTitle => '連結帳戶';

  @override
  String get onboardingAccountsStepDescription =>
      '新增所有要使用的帳戶。BusyMax 會同步每個帳戶中支援的行事曆、活動、待辦清單和待辦事項。';

  @override
  String get onboardingPreferencesStepTitle => '選擇系統設定';

  @override
  String get onboardingPreferencesStepDescription =>
      '開啟行程前，請設定桌面行為、提醒、通知詳細程度和外觀。';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithMicrosoft => '使用 Microsoft 登入';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => '尚未設定此服務。';

  @override
  String get waitingForGoogleSignIn => '正在等候 Google 登入...';

  @override
  String get waitingForMicrosoftSignIn => '正在等候 Microsoft 登入...';

  @override
  String get microsoftSignInNotConfigured =>
      '尚未設定 Microsoft 登入。請設定 MICROSOFT_OAUTH_CLIENT_ID。';

  @override
  String get cancel => '取消';

  @override
  String get close => '關閉';

  @override
  String get exit => '結束';

  @override
  String get options => '選項';

  @override
  String get hide => '隱藏';

  @override
  String get show => '顯示';

  @override
  String get export => '匯出';

  @override
  String get save => '儲存';

  @override
  String get settings => '設定';

  @override
  String get all => '全部';

  @override
  String get calendarEvents => '活動';

  @override
  String get calendarTasks => '待辦事項';

  @override
  String get calendar => '行事曆';

  @override
  String get calendars => '行事曆';

  @override
  String get newCalendar => '新增行事曆';

  @override
  String get calendarColor => '行事曆顏色';

  @override
  String calendarColorOption(int number) {
    return '顏色 $number';
  }

  @override
  String get calendarManagementUnsupported => '此提供者不支援 BusyMax 中的行事曆管理。';

  @override
  String get primaryCalendarCannotDelete => '無法刪除主要行事曆。';

  @override
  String calendarCreateFailed(String error) {
    return '無法建立行事曆：$error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      '行事曆已建立，但 BusyMax 無法重新整理帳戶。它會在下次同步後顯示。';

  @override
  String calendarUpdateFailed(String error) {
    return '無法更新行事曆：$error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return '無法刪除行事曆：$error';
  }

  @override
  String get newEvent => '新增活動';

  @override
  String get refreshCalendar => '重新整理行事曆';

  @override
  String get openInProvider => '在服務中開啟';

  @override
  String get hideFromSchedule => '從行程中隱藏';

  @override
  String get showInSchedule => '在行程中顯示';

  @override
  String get noCalendarsSynced => '尚未同步任何行事曆。';

  @override
  String get allDay => '全天';

  @override
  String moreItems(int count) {
    return '還有 $count 項';
  }

  @override
  String get noEventsOrTasks => '沒有活動或待辦事項';

  @override
  String get scheduleLoading => '正在載入行程...';

  @override
  String get scheduleUnavailable => '無法使用行程';

  @override
  String get scheduleNoSources => '沒有可見的行事曆或待辦清單';

  @override
  String get scheduleNoSourcesDescription => '請在設定中選擇要顯示的內容，然後重新整理。';

  @override
  String get scheduleSignInRequired => '連結帳戶';

  @override
  String get scheduleSignInDescription => '登入以同步行事曆和待辦事項。';

  @override
  String get scheduleNoSearchResults => '沒有相符的活動或待辦事項';

  @override
  String get scheduleNoSearchResultsDescription => '請嘗試其他搜尋內容或清除目前的篩選條件。';

  @override
  String get refresh => '重新整理';

  @override
  String get trayOpenBusyMax => '打開 BusyMax';

  @override
  String get trayShowBusyMax => '顯示 BusyMax';

  @override
  String get trayNewEvent => '新增活動…';

  @override
  String get trayNewTask => '新增待辦事項…';

  @override
  String get trayToday => '今天';

  @override
  String get trayAllDay => '全天';

  @override
  String get trayNow => '現在';

  @override
  String get trayCalendarEvent => '行事曆活動';

  @override
  String get trayUntitledEvent => '未命名活動';

  @override
  String get trayNothingElseToday => '今天沒有其他內容';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天有 $count 個任務到期',
      one: '今天有 1 個任務到期',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => '打開今天的日程';

  @override
  String get traySyncNow => '立即同步';

  @override
  String get traySyncing => '正在同步…';

  @override
  String get trayNotConnected => '未連接';

  @override
  String get trayNotYetSynced => '尚未同步';

  @override
  String get trayLastSyncedJustNow => '剛剛同步';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分鐘前同步',
      one: '1 分鐘前同步',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小時前同步',
      one: '1 小時前同步',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前同步',
      one: '1 天前同步',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => '設定';

  @override
  String get trayQuitBusyMax => '結束 BusyMax';

  @override
  String get agendaLoadMoreOverdue => '載入更多逾期待辦事項';

  @override
  String get agendaLoadMoreNoDate => '載入更多無日期待辦事項';

  @override
  String get viewDay => '日';

  @override
  String get viewWeek => '週';

  @override
  String get viewMonth => '月';

  @override
  String get viewYear => '年';

  @override
  String get viewAgenda => '行程';

  @override
  String get scheduleSettings => '行程';

  @override
  String get scheduleDisplaySettings => '行程顯示';

  @override
  String get scheduleDisplayHoursDescription =>
      '日檢視和週檢視一開始會顯示此時間範圍。必要時，較早或較晚的項目會擴大此範圍。';

  @override
  String get scheduleDayStartsAt => '每日開始時間';

  @override
  String get scheduleDayEndsAt => '每日結束時間';

  @override
  String get sourceCalendar => '行事曆';

  @override
  String get sourceTaskList => '待辦清單';

  @override
  String get createChoiceTitle => '新增';

  @override
  String get createEventAtTime => '活動';

  @override
  String get createTaskAtDate => '待辦事項';

  @override
  String get editEvent => '編輯活動';

  @override
  String get eventTitle => '活動標題';

  @override
  String get location => '地點';

  @override
  String get timeSlot => '時段';

  @override
  String get startDateTime => '開始日期/時間';

  @override
  String get endDateTime => '結束日期/時間';

  @override
  String get doesNotRepeat => '不重複';

  @override
  String get defaultReminder => '預設提醒';

  @override
  String get guests => '參與者';

  @override
  String get noGuests => '無參與者';

  @override
  String get attendeeRequired => '必要';

  @override
  String get attendeeOptional => '選用';

  @override
  String get meetingSection => '會議';

  @override
  String get addGoogleMeet => '添加 Google Meet';

  @override
  String get addTeamsMeeting => '添加 Microsoft Teams 會議';

  @override
  String get onlineMeetingAdded => '已添加在線會議';

  @override
  String get requestResponses => '要求回覆';

  @override
  String get requestResponsesDescription => '要求參與者回復邀請。';

  @override
  String get hideGuestList => '隱藏參與者清單';

  @override
  String get hideGuestListDescription => '參與者無法查看其他受邀者。';

  @override
  String get allowNewTimeProposals => '允許提出新時間';

  @override
  String get allowNewTimeProposalsDescription => '參與者可以建議其他會議時間。';

  @override
  String get notifyGuestsTitle => '通知參與者？';

  @override
  String get notifyGuestsSaveMessage => '此會議有參與者。保存時發送邀請或活動更新嗎？';

  @override
  String get notifyGuestsDeleteMessage => '此會議有參與者。刪除時發送取消通知嗎？';

  @override
  String get sendUpdates => '傳送更新';

  @override
  String get sendCancellation => '傳送取消通知';

  @override
  String get doNotSend => '不要傳送';

  @override
  String get microsoftNotifyGuestsSaveTitle => '保存會議？';

  @override
  String get microsoftNotifyGuestsSaveMessage => 'Microsoft 將向參與者發送邀請或活動更新。';

  @override
  String get microsoftNotifyGuestsDeleteTitle => '刪除會議？';

  @override
  String get microsoftNotifyGuestsDeleteMessage => 'Microsoft 將向參與者發送取消通知。';

  @override
  String get organizer => '主辦人';

  @override
  String get yourResponse => '你的回覆';

  @override
  String get guestResponses => '參與者回覆';

  @override
  String get respond => '回復';

  @override
  String get acceptInvitation => '接受';

  @override
  String get tentativeInvitation => '暫定';

  @override
  String get declineInvitation => '拒絕';

  @override
  String get joinMeeting => '加入會議';

  @override
  String get responseAccepted => '已接受';

  @override
  String get responseTentative => '暫定';

  @override
  String get responseDeclined => '已拒絕';

  @override
  String get responseNeedsAction => '等待回復';

  @override
  String get responseNotResponded => '未回復';

  @override
  String get responseOrganizer => '組織者';

  @override
  String invitationResponseFailed(String error) {
    return '無法發送回復：$error';
  }

  @override
  String get joinMeetingFailed => '無法打開會議鏈接。';

  @override
  String get description => '說明';

  @override
  String get availabilityShowAs => '空閒狀態 / 顯示為';

  @override
  String get busy => '忙碌';

  @override
  String get visibility => '顯示設定';

  @override
  String get defaultVisibility => '預設顯示設定';

  @override
  String get conference => '會議';

  @override
  String get noConference => '無會議';

  @override
  String get providerCalendar => '服務行事曆';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => '粗體';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => '斜體';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => '底線';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分鐘前',
      one: '1 分鐘前',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => '開始時';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時前',
      one: '1 小時前',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => '有空';

  @override
  String get availabilityTentative => '暫定';

  @override
  String get availabilityOutOfOffice => '不在辦公室';

  @override
  String get availabilityWorkingElsewhere => '在其他地點工作';

  @override
  String get visibilityDefault => '預設';

  @override
  String get visibilityPublic => '公開';

  @override
  String get visibilityPrivate => '私人';

  @override
  String get visibilityConfidential => '機密';

  @override
  String get sensitivityNormal => '一般';

  @override
  String get sensitivityPersonal => '個人';

  @override
  String get tasks => '待辦事項';

  @override
  String get allTasks => '所有待辦事項';

  @override
  String tasksInList(String title) {
    return '$title中的待辦事項';
  }

  @override
  String get taskLists => '待辦清單';

  @override
  String get navigation => '導覽';

  @override
  String get mainMenu => '主選單';

  @override
  String get keyboardShortcuts => '鍵盤快速鍵';

  @override
  String get shortcutGroupGeneral => '一般';

  @override
  String get shortcutKeyboardShortcutsDescription => '顯示快速鍵參考表';

  @override
  String get shortcutGroupNavigation => '導覽';

  @override
  String get shortcutNextPeriod => '下一時段';

  @override
  String get shortcutNextPeriodDescription => '在週檢視中前往下一週，在月檢視中前往下個月，依此類推';

  @override
  String get shortcutPreviousPeriod => '上一時段';

  @override
  String get shortcutPreviousPeriodDescription => '在週檢視中前往上一週，在月檢視中前往上個月，依此類推';

  @override
  String get shortcutJumpToToday => '跳至今天';

  @override
  String get shortcutGroupView => '檢視';

  @override
  String get shortcutDayView => '日檢視';

  @override
  String get shortcutWeekView => '週檢視';

  @override
  String get shortcutMonthView => '月檢視';

  @override
  String get shortcutYearView => '年檢視';

  @override
  String get shortcutAgendaView => '行程檢視';

  @override
  String get shortcutGroupCreateAndEdit => '新增和編輯';

  @override
  String get shortcutSaveItem => '儲存活動或待辦事項';

  @override
  String get shortcutDeleteItem => '刪除活動或待辦事項';

  @override
  String get shortcutGroupTaskEditing => '待辦事項編輯';

  @override
  String get shortcutCancelEditing => '取消編輯';

  @override
  String get shortcutCancelEditingDescription => '關閉待辦事項編輯或詳細資料';

  @override
  String get aboutBusyMax => '關於 BusyMax';

  @override
  String get aboutBusyMaxDescription => '行事曆與待辦事項';

  @override
  String get license => '授權';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => '網站';

  @override
  String get sourceCode => '原始碼';

  @override
  String get reportAnIssue => '回報問題';

  @override
  String get sendFeedback => '傳送意見';

  @override
  String get feedbackSubmit => '提交';

  @override
  String get feedbackCategory => '類別';

  @override
  String get feedbackSelectCategory => '選擇類別';

  @override
  String get feedbackCategoryProblem => '問題或錯誤';

  @override
  String get feedbackCategoryFeature => '功能請求';

  @override
  String get feedbackCategoryPrivacySecurity => '隱私權或安全性疑慮';

  @override
  String get feedbackCategoryUsability => '易用性疑慮';

  @override
  String get feedbackCategoryOther => '其他';

  @override
  String get feedbackSubject => '主旨';

  @override
  String get feedbackDetailedMessage => '詳細訊息';

  @override
  String get feedbackReplyEmail => '回覆用電子郵件地址（選填）';

  @override
  String get feedbackIncludeTechnicalDetails => '包含技術詳細資料';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      '只會加入您的 Linux 作業系統版本和應用程式語系。不會包含記錄、帳戶資料、檔案名稱或其他診斷資訊。';

  @override
  String get feedbackCategoryRequired => '請選擇類別。';

  @override
  String get feedbackSubjectLengthError => '主旨必須介於 3 到 120 個字元之間。';

  @override
  String get feedbackMessageLengthError => '訊息必須介於 10 到 5,000 個字元之間。';

  @override
  String get feedbackInvalidEmail => '請輸入有效的電子郵件地址。';

  @override
  String get feedbackConnectionError => '無法連線至 BusyStack。請檢查連線，然後再試一次。';

  @override
  String get feedbackTimeoutError => '要求逾時。您的意見尚未清除，請再試一次。';

  @override
  String get feedbackRateLimitedError => '此網路已傳送太多意見。請稍候再試。';

  @override
  String get feedbackRejectedError => '伺服器拒絕了提交內容。請檢查各欄位，然後再試一次。';

  @override
  String get feedbackServerError => 'BusyStack 目前無法接收您的意見。您的意見尚未清除，請再試一次。';

  @override
  String feedbackSuccess(String id) {
    return '意見已傳送。參考編號：$id';
  }

  @override
  String get toggleSidebar => '顯示或隱藏側邊欄';

  @override
  String get showSidebar => '顯示側邊欄面板';

  @override
  String get hideSidebar => '隱藏側邊欄面板';

  @override
  String get accounts => '帳戶';

  @override
  String get currentAccount => '目前帳戶';

  @override
  String get switchAccount => '切換帳戶';

  @override
  String get addGoogleAccount => '新增 Google 帳戶';

  @override
  String get addMicrosoftAccount => '新增 Microsoft 帳戶';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => '已登入';

  @override
  String get removeAccount => '移除帳戶…';

  @override
  String get removingAccount => '正在移除帳戶…';

  @override
  String get removeAccountDescription => '停止同步並從此裝置移除此帳戶的資料。';

  @override
  String removeAccountTitle(String account) {
    return '從 BusyMax 中移除 $account？';
  }

  @override
  String get removeAccountConfirmation =>
      '這會從此設備刪除緩存的任務、日曆、活動、提醒和待處理的離線更改。未同步的更改將會丟失。提供商中的日曆、活動、任務列表和任務副本不會被刪除。';

  @override
  String get revokeGoogleAccess => '同時撤銷 BusyMax 對此 Google 帳戶的存取權';

  @override
  String get revokeGoogleAccessDescription => '重新連結前，您必須再次授予存取權。';

  @override
  String get removeAccountAction => '移除帳戶';

  @override
  String get removeAccountFailed => '無法完成帳戶移除。請再試一次。';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      '該帳戶已從此裝置移除，但無法撤銷 BusyMax 對您的 Google 帳戶的存取權。您可以在 Google 帳戶中手動撤銷該權限。';

  @override
  String get newTaskList => '新任務列表';

  @override
  String taskListCreateFailed(String error) {
    return '無法創建任務列表：$error';
  }

  @override
  String taskListRenameFailed(String error) {
    return '無法重命名任務列表：$error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return '無法刪除任務列表：$error';
  }

  @override
  String get signInToViewTaskLists => '登入以查看待辦清單。';

  @override
  String get noTaskListsSynced => '尚未同步任何待辦清單。';

  @override
  String get listActions => '清單動作';

  @override
  String get rename => '重新命名';

  @override
  String get delete => '刪除';

  @override
  String get renameList => '重新命名清單';

  @override
  String get deleteList => '刪除清單';

  @override
  String get unshare => '取消共享';

  @override
  String get readOnlyTaskListCannotRename => '此任務列表為只讀，無法重命名。';

  @override
  String get taskListCannotDelete => '使用當前權限無法刪除此任務列表。';

  @override
  String get builtInMicrosoftList => '內建';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      '無法重新命名或刪除 Microsoft To Do 內建清單。';

  @override
  String deleteListConfirmation(String title) {
    return '要從 Google Tasks 中刪除“$title”嗎？';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '要刪除“$title”及其所有任務嗎？';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return '要取消此賬戶對“$title”的共享嗎？';
  }

  @override
  String get deleteEvent => '刪除活動';

  @override
  String get title => '標題';

  @override
  String get create => '新增';

  @override
  String get newTask => '新增待辦事項';

  @override
  String get clearCompleted => '清除已完成項目';

  @override
  String get refreshList => '重新整理清單';

  @override
  String get refreshAll => '全部重新整理';

  @override
  String get listRefreshed => '清單已重新整理。';

  @override
  String get allTasksRefreshed => '所有帳戶都已重新整理。';

  @override
  String exportedFile(String path) {
    return '已匯出至 $path';
  }

  @override
  String exportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String refreshFailed(String error) {
    return '重新整理失敗：$error';
  }

  @override
  String get selectOrCreateTaskList => '請選擇或建立待辦清單以開始使用。';

  @override
  String get signInToViewTasks => '登入以查看待辦事項。';

  @override
  String get noTasks => '沒有待辦事項。';

  @override
  String get noTasksYet => '還沒有待辦事項';

  @override
  String get noTasksYetMessage => '建立待辦事項或重新整理帳戶以開始使用。';

  @override
  String get noTasksInList => '此清單中沒有待辦事項。';

  @override
  String get overdue => '已逾期';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get upcoming => '即將到期';

  @override
  String get noDate => '無日期';

  @override
  String get completed => '已完成';

  @override
  String duePrefix(String date) {
    return '$date 到期';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => '待辦事項詳細資料';

  @override
  String get editTask => '編輯待辦事項';

  @override
  String get noTaskSelected => '未選取待辦事項。';

  @override
  String get noTaskSelectedHelper => '選擇待辦事項以查看和編輯詳細資料。';

  @override
  String get taskUnavailable => '無法使用待辦事項。';

  @override
  String get signInToEditTasks => '登入以編輯待辦事項。';

  @override
  String get refreshTask => '重新整理待辦事項';

  @override
  String get primarySection => '主要資訊';

  @override
  String get statusSection => '狀態';

  @override
  String get openStatus => '未完成';

  @override
  String get doneStatus => '已完成';

  @override
  String get taskStatus => '狀態';

  @override
  String get taskStatusNone => '無狀態';

  @override
  String get taskStatusNeedsAction => '需要動作';

  @override
  String get taskStatusInProcess => '進行中';

  @override
  String get taskStatusCompleted => '已完成';

  @override
  String get taskStatusCancelled => '已取消';

  @override
  String completionPercent(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get completionDate => '完成日期';

  @override
  String get priority => '優先順序';

  @override
  String get priorityNone => '無優先順序';

  @override
  String priorityHighValue(int priority) {
    return '優先級 $priority · 高';
  }

  @override
  String priorityMediumValue(int priority) {
    return '優先級 $priority · 中';
  }

  @override
  String priorityLowValue(int priority) {
    return '優先級 $priority · 低';
  }

  @override
  String get taskUrl => '任務 URL';

  @override
  String get invalidTaskUrl => '請輸入包含方案的絕對 URL。';

  @override
  String get classification => '分類';

  @override
  String get classificationPublic => '共享時顯示完整任務';

  @override
  String get classificationConfidential => '共享時僅顯示忙碌狀態';

  @override
  String get classificationPrivate => '共享時隱藏此任務';

  @override
  String get pinTask => '固定任務';

  @override
  String get notes => '備註';

  @override
  String get dueDate => '到期日';

  @override
  String get clearDueDate => '清除到期日';

  @override
  String get dueTime => '到期時間';

  @override
  String get startDate => '開始日期';

  @override
  String get startTime => '開始時間';

  @override
  String get endDate => '結束日期';

  @override
  String get endTime => '結束時間';

  @override
  String get reminderDate => '提醒日期';

  @override
  String get reminderTime => '提醒時間';

  @override
  String get reminder => '提醒';

  @override
  String get addReminder => '添加提醒';

  @override
  String get reminders => '提醒';

  @override
  String get noReminders => '無提醒';

  @override
  String get editReminder => '編輯提醒';

  @override
  String get beforeTaskStarts => '待辦事項開始前';

  @override
  String get beforeTaskDue => '待辦事項到期前';

  @override
  String get afterTaskStarts => '任務開始後';

  @override
  String get afterTaskDue => '任務到期後';

  @override
  String get relativeToTaskStart => '相對於任務開始日期';

  @override
  String get relativeToTaskDue => '相對於任務到期日期';

  @override
  String get reminderTimeOfDay => '時間';

  @override
  String get absoluteReminder => '在指定日期和時間';

  @override
  String get reminderAmount => '數量';

  @override
  String get reminderUnit => '單位';

  @override
  String get reminderUnitSeconds => '秒';

  @override
  String get reminderUnitMinutes => '分鐘';

  @override
  String get reminderUnitHours => '小時';

  @override
  String get reminderUnitDays => '天';

  @override
  String get reminderUnitWeeks => '週';

  @override
  String get reminderAtTaskStart => '任務開始時';

  @override
  String get reminderAtTaskDue => '任務到期時';

  @override
  String get unsupportedReminder => '此提醒類型會保留，但無法編輯其時間。';

  @override
  String get relatedRemindersTitle => '保留相關提醒？';

  @override
  String relatedRemindersDescription(int count) {
    return '此日期有 $count 個相關提醒。要保留它們當前的日期和時間嗎？';
  }

  @override
  String get discardRelatedReminders => '捨棄提醒';

  @override
  String get keepRelatedReminders => '保留提醒';

  @override
  String get addGuest => '新增參與者';

  @override
  String get addGuestEmail => '新增參與者電子郵件';

  @override
  String get removeReminder => '移除提醒';

  @override
  String get off => '關閉';

  @override
  String get repeat => '重複';

  @override
  String get repeatNone => '不重複';

  @override
  String get noneValue => '無';

  @override
  String get repeatDaily => '每天';

  @override
  String get repeatWeekly => '每週';

  @override
  String get repeatMonthly => '每月';

  @override
  String get repeatYearly => '每年';

  @override
  String get repeatEvery => '重複間隔';

  @override
  String get repeatOn => '重複日期';

  @override
  String get repeatEnd => '結束重複';

  @override
  String get repeatNever => '永不';

  @override
  String get repeatUntil => '指定日期';

  @override
  String get repeatAfter => '指定次數後';

  @override
  String get repeatCount => '重複次數';

  @override
  String get repeatDayOfMonth => '每月日期';

  @override
  String get repeatMonths => '月份';

  @override
  String get repeatOrdinal => '星期位置';

  @override
  String get repeatSpecificDays => '特定日期';

  @override
  String get repeatFirst => '第一';

  @override
  String get repeatSecond => '第二';

  @override
  String get repeatThird => '第三';

  @override
  String get repeatFourth => '第四';

  @override
  String get repeatFifth => '第五';

  @override
  String get repeatSecondToLast => '倒數第二';

  @override
  String get repeatLast => '最後';

  @override
  String get repeatAnyDay => '日期';

  @override
  String get repeatWeekday => '工作日';

  @override
  String get repeatWeekendDay => '週末';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': '星期一',
      'TU': '星期二',
      'WE': '星期三',
      'TH': '星期四',
      'FR': '星期五',
      'SA': '星期六',
      'SU': '星期日',
      'day': '日期',
      'weekday': '工作日',
      'weekend': '週末',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    return '每 $count 天';
  }

  @override
  String repeatEveryWeeks(int count) {
    return '每 $count 週';
  }

  @override
  String repeatEveryMonths(int count) {
    return '每 $count 個月';
  }

  @override
  String repeatEveryYears(int count) {
    return '每 $count 年';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '在 $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一個$days',
      'second': '第二個$days',
      'third': '第三個$days',
      'fourth': '第四個$days',
      'fifth': '第五個$days',
      'secondToLast': '倒數第二個$days',
      'last': '最後一個$days',
      'other': '$days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return '在 $months';
  }

  @override
  String repeatTimesSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重複 $count 次',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return '直到 $date';
  }

  @override
  String get unsupportedRecurrencePreserved => '此重複規則使用了編輯器不會更改的選項。';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return '此重複規則無法用於 $provider。';
  }

  @override
  String get importance => '重要性';

  @override
  String get importanceLow => '低';

  @override
  String get importanceNormal => '一般';

  @override
  String get importanceHigh => '高';

  @override
  String get categories => '類別';

  @override
  String get scheduleSection => '行程';

  @override
  String get dueGroup => '到期';

  @override
  String get startGroup => '開始';

  @override
  String get reminderGroup => '提醒';

  @override
  String get organizationSection => '整理';

  @override
  String get actionsSection => '動作';

  @override
  String get advancedSection => '進階';

  @override
  String get addCategory => '新增類別';

  @override
  String get list => '清單';

  @override
  String get microsoftMoveUnsupported =>
      '此版本不支援在 Microsoft To Do 帳戶的清單之間移動待辦事項。';

  @override
  String get createSubtask => '建立子待辦事項';

  @override
  String get subtasks => '子待辦事項';

  @override
  String get duplicateTask => '複製待辦事項';

  @override
  String get taskDuplicated => '任務已複製。';

  @override
  String taskDuplicateFailed(String error) {
    return '無法複製任務：$error';
  }

  @override
  String get hideSubtasks => '隱藏子工作項目';

  @override
  String get hideClosedSubtasks => '隱藏已關閉的子工作項目';

  @override
  String get moveToTop => '移至頂端';

  @override
  String get deleteTask => '刪除待辦事項';

  @override
  String get newSubtask => '新增子待辦事項';

  @override
  String deleteTaskConfirmation(String title) {
    return '要刪除「$title」嗎？';
  }

  @override
  String get metadata => '中繼資料';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => '更新時間';

  @override
  String get parent => '上層待辦事項';

  @override
  String get position => '位置';

  @override
  String get webLink => '網頁連結';

  @override
  String get assignment => '指派';

  @override
  String get localState => '本機狀態';

  @override
  String get pendingSync => '等候同步';

  @override
  String get synced => '已同步';

  @override
  String get account => '帳戶';

  @override
  String get sync => '同步';

  @override
  String get forceFullResync => '強制完整重新同步';

  @override
  String get forceFullResyncDescription =>
      '從每個已連結的帳號完整重新載入所有資料。僅在疑難排解同步問題時使用此功能。';

  @override
  String get runInBackgroundWhenClosed => '視窗關閉後繼續在背景執行';

  @override
  String get showTrayIcon => '顯示系統匣圖示';

  @override
  String get startMinimizedToTray => '啟動時最小化至系統匣';

  @override
  String get launchAtLogin => '登入時啟動';

  @override
  String get launchAtLoginDescription => '在背景啟動 BusyMax，讓提醒在登入後正常運作。';

  @override
  String get launchAtLoginFailed => '無法更新登入時啟動設定。';

  @override
  String get requiresTrayIcon => '需要系統匣圖示。';

  @override
  String get syncComplete => '同步完成。';

  @override
  String syncFailed(String error) {
    return '同步失敗：$error';
  }

  @override
  String get notifySyncFailures => '同步失敗通知';

  @override
  String get notifyConflicts => '衝突通知';

  @override
  String get notifyDueToday => '今天到期待辦事項通知';

  @override
  String get eventReminders => '活動提醒';

  @override
  String get onState => '開啟';

  @override
  String get taskReminders => '待辦事項提醒';

  @override
  String get notificationDetailLevel => '通知詳細程度';

  @override
  String get notificationDetailPrivate => '私人';

  @override
  String get notificationDetailNormal => '一般';

  @override
  String get quietHours => '勿擾時段';

  @override
  String get quietHoursDescription => '在此時段暫停通知。';

  @override
  String get quietHoursStart => '勿擾開始時間';

  @override
  String get quietHoursEnd => '勿擾結束時間';

  @override
  String get notifications => '通知';

  @override
  String get appearance => '外觀';

  @override
  String get theme => '主題';

  @override
  String get themeSystem => '系統';

  @override
  String get settingsSystem => '系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get themeFamily => '主題系列';

  @override
  String get themeFamilyYaru => 'Ubuntu 原生主題（Yaru）';

  @override
  String get localization => '語言與地區';

  @override
  String get currentLocale => '目前語系';

  @override
  String get privacy => '隱私權';

  @override
  String get redactTaskContentInDiagnostics => '在診斷資訊中隱藏待辦事項內容';

  @override
  String get developerDiagnostics => '開發人員診斷';

  @override
  String get diagnostics => '診斷';

  @override
  String get apiInspectorDisabled => '顯示 API 檢查器';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery 修訂版本：$revision';
  }

  @override
  String get implementedMethods => '已實作的方法';

  @override
  String get supportsTasksScopes => '支援 tasks 和 tasks.readonly 權限範圍';

  @override
  String get requiresTasksScope => '需要 tasks 權限範圍';

  @override
  String get blockedPendingOperations => '遭封鎖的待處理作業';

  @override
  String get signInToInspectPendingOperations => '登入以檢查待處理作業。';

  @override
  String get noBlockedPendingOperations => '沒有遭封鎖的待處理作業。';

  @override
  String get operationActions => '操作選項';

  @override
  String pendingOpListId(String id) {
    return '清單=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return '待辦事項=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return '嘗試次數=$count';
  }

  @override
  String get retry => '再試一次';

  @override
  String get discard => '捨棄';

  @override
  String get discardChangesAction => '捨棄';

  @override
  String get discardChanges => '要捨棄變更嗎？';

  @override
  String get discardChangesConfirmation => '這會捨棄此待辦事項中尚未儲存的編輯內容。';

  @override
  String get retryCompleted => '重試完成。';

  @override
  String get discardPendingOperation => '要捨棄待處理作業嗎？';

  @override
  String get discardPendingOperationConfirmation =>
      '這會移除遭封鎖的本機作業。下次同步時將從 Google Tasks 重新整理資料。';

  @override
  String get pendingOperationDiscarded => '已捨棄待處理作業。';

  @override
  String get syncFailureNotificationTitle => 'BusyMax 同步失敗';

  @override
  String syncFailureNotificationBody(String message) {
    return '背景同步失敗。$message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax 同步衝突';

  @override
  String conflictNotificationBody(String summary) {
    return '一項擱置中的本機變更已被封鎖。$summary';
  }

  @override
  String get dueTodayNotificationTitle => '今天到期的待辦事項';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天有 $count 項待辦事項到期。',
      one: '今天有 1 項待辦事項到期。',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => '活動提醒';

  @override
  String get taskReminderNotificationTitle => '待辦事項提醒';

  @override
  String get eventReminderNotificationBody => '活動即將開始。';

  @override
  String get taskReminderNotificationBody => '待辦事項即將到期。';

  @override
  String get notificationOpenAction => '開啟';

  @override
  String get notificationSnoozeAction => '10 分鐘後提醒';

  @override
  String get notificationDismissAction => '關閉';

  @override
  String get notificationDetailsHidden => '根據隱私權設定，詳細資料已隱藏。';

  @override
  String get previousMonth => '上個月';

  @override
  String get nextMonth => '下個月';

  @override
  String get openMonthView => '開啟月檢視';

  @override
  String get previousYear => '上一年';

  @override
  String get nextYear => '下一年';

  @override
  String get openYearView => '開啟年檢視';

  @override
  String weekNumberTooltip(int number) {
    return '第 $number 週';
  }

  @override
  String get resizeAllDayPanel => '調整全天面板大小';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 項',
      one: '1 項',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => '此行事曆為唯讀。';

  @override
  String get selectTimeZone => '選擇時區';

  @override
  String get searchLocations => '搜索地點';

  @override
  String get noLocationsFound => '未找到地點';

  @override
  String get requiredField => '此字段為必填項。';

  @override
  String get providerConnectionDescription => '連接以下任一提供商中的日曆和任務。';

  @override
  String get appleICloudProvider => 'Apple iCloud 行事曆';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud 待辦事項';

  @override
  String get addAppleICloudAccount => '新增 Apple iCloud 行事曆帳戶';

  @override
  String get addNextcloudAccount => '新增 Nextcloud 帳戶';

  @override
  String get waitingForAppleICloud => '正在連接 Apple iCloud…';

  @override
  String get waitingForNextcloud => '正在等待 Nextcloud 授權…';

  @override
  String get connectAppleICloudTitle => '連接 Apple iCloud 行事曆';

  @override
  String get appleAccountEmail => 'Apple 賬戶電子郵件';

  @override
  String get appleAppSpecificPassword => 'App 專用密碼';

  @override
  String get appleAppSpecificPasswordHelp => '為 Apple 賬戶啓用雙重認證後，創建 App 專用密碼。';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      '重置 Apple 賬戶密碼會撤銷 App 專用密碼。';

  @override
  String get connectNextcloudTitle => '連接 Nextcloud';

  @override
  String get nextcloudServerUrl => 'Nextcloud 伺服器或 CalDAV 位址';

  @override
  String get nextcloudServerUrlHelp =>
      '輸入 Nextcloud 服務器 URL，或粘貼從 Nextcloud 複製的主要 CalDAV 地址。';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax 將打開瀏覽器。請在那裡批准訪問，然後返回 BusyMax。';

  @override
  String get connectAccountAction => '連接';

  @override
  String get cancelAccountConnection => '取消連接';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      '賬戶已在本地移除，但無法撤銷 Nextcloud App 密碼。';

  @override
  String get davCachedOfflineNotice => '日曆和任務數據會緩存在本地，以供離線使用。';

  @override
  String get davReauthenticationRequired => '重新連接此賬戶以恢復同步。';

  @override
  String get davTemporarilyUnavailable => '此賬戶暫時不可用。';

  @override
  String get davPermissionChanged => '服務器權限已更改。待處理的編輯已暫停。';

  @override
  String get davUnsupportedServer => '不支持此服務器或提供商配置。';

  @override
  String get collectionSettings => '行事曆和待辦清單';

  @override
  String get calendarContent => '行事曆活動';

  @override
  String get taskContent => '待辦事項';

  @override
  String get readOnlySharedCollection => '唯讀';

  @override
  String get pendingLocally => '本機擱置中';

  @override
  String get conflictBlocked => '因衝突而封鎖';

  @override
  String get authenticationBlocked => '重新連接前阻止';

  @override
  String get operationFailed => '操作失敗';

  @override
  String get keepServerVersion => '保留伺服器版本';

  @override
  String get reapplyLocalChange => '查看並重新應用本地更改';

  @override
  String get duplicateLocalItem => '複製為新項目';

  @override
  String get davConnectionState => '連線狀態';

  @override
  String get davConnected => '已連線';

  @override
  String get davConnecting => '正在連線…';

  @override
  String get davSignedOut => '已登出';

  @override
  String davLastSuccessfulSync(String time) {
    return '上次成功同步：$time';
  }

  @override
  String get davNeverSynced => '尚未同步';

  @override
  String get refreshCollections => '刷新日曆和任務列表';

  @override
  String nextcloudServerHost(String host) {
    return '服務器：$host';
  }

  @override
  String get collectionSupportsEvents => '活動日曆';

  @override
  String get collectionSupportsTasks => '任務列表';

  @override
  String get collectionSupportsEventsAndTasks => '活動和任務';

  @override
  String get writableCollection => '可寫';

  @override
  String get sharedCollection => '已共享';

  @override
  String collectionLastSynced(String time) {
    return '上次同步：$time';
  }

  @override
  String collectionSyncError(String code) {
    return '同步問題：$code';
  }

  @override
  String get syncConflicts => '同步衝突';

  @override
  String remoteChangedAt(String time) {
    return '服務器更改：$time';
  }

  @override
  String localPendingEdit(String summary) {
    return '本地編輯：$summary';
  }

  @override
  String get conflictResolutionFailed => '無法解決衝突。';

  @override
  String get recurringEventScope => '重複活動範圍';

  @override
  String get entireSeries => '整個系列';

  @override
  String get singleOccurrence => '此事件';

  @override
  String get thisAndFollowingEvents => '此事件及後續事件';

  @override
  String get thisAndFutureUnavailable => '此提供者不支援。';

  @override
  String get thisAndFutureMoveUnavailable => '無法安全移動此活動及後續活動。請選擇此活動或整個系列。';

  @override
  String get entireSeriesMoveUnavailable => '本機沒有可用的重複規則。請只移動此活動。';

  @override
  String get copyEventAndDeleteOriginal => '複製活動並刪除原活動？';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax 無法將此活動直接從 $source 移動到 $destination。應用程式會先建立副本，並且只在複製成功後刪除原活動。活動 ID 將會變更；參與者的回覆狀態可能會重設，並可能傳送邀請或取消通知；會議連結、附件、提醒、提供者特有的欄位和重複例外可能無法保留。';
  }

  @override
  String get copyAndDelete => '複製並刪除';

  @override
  String get chooseRecurringEventScope => '選擇此變更適用於整個系列、僅此活動，還是此活動及後續活動。';

  @override
  String get taskDueBeforeStart => '到期時間不得早於開始時間。';

  @override
  String get taskStartDueTimeModeMismatch => '請同時設定開始與到期時間，或將待辦事項設為全天。';

  @override
  String deleteCalendarConfirmation(String title) {
    return '要刪除「$title」嗎？';
  }

  @override
  String get setCustomCalendarName => '設定自訂名稱';

  @override
  String get setAction => '設定';

  @override
  String get removeFromMyCalendars => '從「我的日曆」移除';

  @override
  String get removeAction => '移除';

  @override
  String removeCalendarConfirmation(String title) {
    return '要從您的 Google 日曆清單移除「$title」嗎？共用日曆及其活動不會被刪除。';
  }

  @override
  String get calendarCannotRemove => '無法從此賬戶刪除或移除此日曆。';

  @override
  String get calendarPendingChangesPreventRemoval =>
      '請等待此日曆的待處理更改完成同步，然後再刪除或移除它。';

  @override
  String get calendarSubscriptions => '行事曆訂閱';

  @override
  String get calendarSubscriptionsDescription => '添加從安全 WebCal URL 刷新的只讀日曆。';

  @override
  String get addCalendarSubscription => '新增行事曆訂閱';

  @override
  String get subscriptionName => '本機名稱';

  @override
  String get subscriptionUrl => '訂閱 URL';

  @override
  String get subscriptionUrlHelp =>
      '輸入 HTTPS 或 webcal URL。BusyMax 會將完整 URL 保存在安全存儲中。';

  @override
  String get subscriptionUrlInvalid => '請輸入不含用戶信息或片段的有效 HTTPS 或 webcal URL。';

  @override
  String get subscriptionColor => '本地顏色';

  @override
  String get subscriptionColorHelp => '使用六位顏色，例如 #3584E4。';

  @override
  String get subscriptionColorInvalid => '請輸入六位十六進制顏色。';

  @override
  String get subscriptionRefreshMode => '刷新頻率';

  @override
  String get subscriptionAutomatic => '自動';

  @override
  String get subscriptionHourly => '每小時';

  @override
  String get subscriptionSixHours => '每六小時';

  @override
  String get subscriptionDaily => '每天';

  @override
  String subscriptionSafeOrigin(String origin) {
    return '來源：$origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable => '請輸入有效 URL 以預覽其安全來源。';

  @override
  String get subscriptionReadOnly => '只讀訂閱';

  @override
  String get subscriptionNeverRefreshed => '尚未刷新';

  @override
  String subscriptionLastRefresh(String time) {
    return '上次成功刷新：$time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return '下次刷新：$time';
  }

  @override
  String get subscriptionStatusHealthy => '已是最新';

  @override
  String subscriptionStatusIssue(String code) {
    return '刷新問題：$code';
  }

  @override
  String get refreshNow => '立即重新整理';

  @override
  String get unsubscribe => '取消訂閱';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '要取消訂閱“$name”嗎？';
  }

  @override
  String get unsubscribeCalendarConfirmation => '這會移除本地訂閱及其緩存的活動。已發佈的日曆不會更改。';

  @override
  String get addSubscriptionAction => '添加訂閱';

  @override
  String subscriptionOperationFailed(String error) {
    return '日曆訂閱失敗：$error';
  }

  @override
  String get subscriptions => '訂閱';

  @override
  String get calendarImport => '匯入行事曆';

  @override
  String get calendarImportDescription => '選擇文件，查看其中的活動，然後選擇接收這些活動的可寫日曆。';

  @override
  String get importIcsFile => '匯入 .ics 檔案';

  @override
  String get importIcsPreview => '匯入行事曆活動';

  @override
  String importEventsFound(int count) {
    return '可導入活動集：$count';
  }

  @override
  String importInvalidEvents(int count) {
    return '無效活動：$count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return '有意省略：$fields';
  }

  @override
  String get noWritableCalendars => '沒有可用的可寫目標日曆。';

  @override
  String get importDestinationCalendar => '目標日曆';

  @override
  String get importIcsConfirm => '導入活動';

  @override
  String get importIcsComplete => '匯入完成';

  @override
  String importQueued(int count) {
    return '已導入或已排隊：$count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return '已跳過重複項：$count';
  }

  @override
  String importUnsupportedSets(int count) {
    return '不支持的重複集：$count';
  }

  @override
  String importIcsFailed(String error) {
    return '無法導入日曆文件：$error';
  }

  @override
  String get networkOffline => '離線';

  @override
  String get networkOfflineDescription => '連線恢復後將同步變更。';

  @override
  String get networkOfflineTryAgain => '您目前處於離線狀態。請連接網際網路後再試一次。';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return '$days';
  }

  @override
  String get repeatSummarySeparator => '';

  @override
  String repeatMonthDayValue(String day) {
    return '$day日';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first、$second';
  }

  @override
  String repeatMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first和$second';
  }

  @override
  String repeatYearlyMonthListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyOnMonthDaySummary(
    String frequency,
    String month,
    String day,
  ) {
    return '$frequency$month$day';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency$month的$days';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency$months的$day';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency$months的$days';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一個$days',
      'second': '第二個$days',
      'third': '第三個$days',
      'fourth': '第四個$days',
      'fifth': '第五個$days',
      'secondToLast': '倒數第二個$days',
      'last': '最後一個$days',
      'other': '$days',
    });
    return '$frequency$month的$_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第一個$days',
      'second': '第二個$days',
      'third': '第三個$days',
      'fourth': '第四個$days',
      'fifth': '第五個$days',
      'secondToLast': '倒數第二個$days',
      'last': '最後一個$days',
      'other': '$days',
    });
    return '$frequency$months的$_temp0';
  }
}

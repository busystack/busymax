// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get windowsSupport => 'サポート';

  @override
  String get windowsThirdPartyLicenses => 'サードパーティ ライセンス';

  @override
  String get windowsSearch => '検索';

  @override
  String get windowsStartupDisabledByUser => 'Windows の設定でユーザーにより無効にされています。';

  @override
  String get windowsStartupDisabledByPolicy => 'Windows ポリシーにより無効にされています。';

  @override
  String get windowsStartupUnavailable =>
      'BusyMax を MSIX パッケージからインストールすると利用できます。';

  @override
  String get windowsReminderExitNotice =>
      'BusyMax を完全に終了するとリマインダーも停止します。受け取るにはバックグラウンドで実行したままにしてください。';

  @override
  String get windowsProductVersionLabel => '製品バージョン';

  @override
  String get windowsPackageVersionLabel => 'Windows パッケージ バージョン';

  @override
  String get windowsUnpackaged => 'パッケージ化されていません';

  @override
  String get windowsAgendaLoadMore => '予定をさらに読み込む';

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': '月曜日',
      'TU': '火曜日',
      'WE': '水曜日',
      'TH': '木曜日',
      'FR': '金曜日',
      'SA': '土曜日',
      'SU': '日曜日',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return '$first、$second';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency$monthの$firstDayと$secondDay';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency$firstMonthと$secondMonthの$day';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency$firstMonthと$secondMonthの$firstDayと$secondDay';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency$firstMonthと$secondMonthの$days';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Google、Microsoft、Apple iCloud Calendar、または Nextcloud のアカウントを接続します。';

  @override
  String get googlePermissionsConsentNotice =>
      'Google の権限画面で、カレンダーとタスクの両方の権限を選択してください。';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google カレンダーと Google Tasks の権限が必要です。もう一度試して、両方のチェックボックスを選択してください。';

  @override
  String get finishSetup => 'セットアップを完了';

  @override
  String get continueSetup => '続行';

  @override
  String get onboardingSetupTitle => 'BusyMax をセットアップ';

  @override
  String get onboardingAccountsStepTitle => 'アカウントを接続';

  @override
  String get onboardingAccountsStepDescription =>
      '使用するすべてのアカウントを追加します。BusyMax は各アカウントの対応するカレンダー、予定、タスクリスト、タスクを同期します。';

  @override
  String get onboardingPreferencesStepTitle => 'システム設定を選択';

  @override
  String get onboardingPreferencesStepDescription =>
      'スケジュールを開く前に、デスクトップでの動作、リマインダー、通知の詳細度、外観を設定します。';

  @override
  String get signInWithGoogle => 'Google でサインイン';

  @override
  String get signInWithMicrosoft => 'Microsoft でサインイン';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'このプロバイダーは設定されていません。';

  @override
  String get waitingForGoogleSignIn => 'Google のサインインを待機しています...';

  @override
  String get waitingForMicrosoftSignIn => 'Microsoft のサインインを待機しています...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsoft のサインインが設定されていません。MICROSOFT_OAUTH_CLIENT_ID を設定してください。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get close => '閉じる';

  @override
  String get exit => '終了';

  @override
  String get options => 'オプション';

  @override
  String get hide => '非表示';

  @override
  String get show => '表示';

  @override
  String get export => 'エクスポート';

  @override
  String get save => '保存';

  @override
  String get settings => '設定';

  @override
  String get all => 'すべて';

  @override
  String get calendarEvents => '予定';

  @override
  String get calendarTasks => 'タスク';

  @override
  String get calendar => 'カレンダー';

  @override
  String get calendars => 'カレンダー';

  @override
  String get newCalendar => '新しいカレンダー';

  @override
  String get calendarColor => 'カレンダーの色';

  @override
  String calendarColorOption(int number) {
    return '色 $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'このプロバイダーのカレンダー管理は BusyMax ではサポートされていません。';

  @override
  String get primaryCalendarCannotDelete => 'メインカレンダーは削除できません。';

  @override
  String calendarCreateFailed(String error) {
    return 'カレンダーを作成できませんでした: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'カレンダーは作成されましたが、BusyMax はアカウントを更新できませんでした。次回の同期後に表示されます。';

  @override
  String calendarUpdateFailed(String error) {
    return 'カレンダーを更新できませんでした: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'カレンダーを削除できませんでした: $error';
  }

  @override
  String get newEvent => '新しい予定';

  @override
  String get refreshCalendar => 'カレンダーを更新';

  @override
  String get openInProvider => 'サービスで開く';

  @override
  String get hideFromSchedule => 'スケジュールから非表示';

  @override
  String get showInSchedule => 'スケジュールに表示';

  @override
  String get noCalendarsSynced => '同期済みのカレンダーはまだありません。';

  @override
  String get allDay => '終日';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '他 $countString 件';
  }

  @override
  String get noEventsOrTasks => '予定またはタスクはありません';

  @override
  String get scheduleLoading => 'スケジュールを読み込んでいます...';

  @override
  String get scheduleUnavailable => 'スケジュールを利用できません';

  @override
  String get scheduleNoSources => '表示できるカレンダーまたはタスクリストがありません';

  @override
  String get scheduleNoSourcesDescription => '設定で表示する項目を選択してから、更新してください。';

  @override
  String get scheduleSignInRequired => 'アカウントを接続';

  @override
  String get scheduleSignInDescription => 'カレンダーとタスクを同期するにはサインインしてください。';

  @override
  String get scheduleNoSearchResults => '一致する予定またはタスクはありません';

  @override
  String get scheduleNoSearchResultsDescription =>
      '別の条件で検索するか、現在のフィルターを解除してください。';

  @override
  String get refresh => '更新';

  @override
  String get trayOpenBusyMax => 'BusyMax を開く';

  @override
  String get trayShowBusyMax => 'BusyMax を表示';

  @override
  String get trayNewEvent => '新しい予定…';

  @override
  String get trayNewTask => '新しいタスク…';

  @override
  String get trayToday => '今日';

  @override
  String get trayAllDay => '終日';

  @override
  String get trayNow => '今';

  @override
  String get trayCalendarEvent => 'カレンダーの予定';

  @override
  String get trayUntitledEvent => '無題の予定';

  @override
  String get trayNothingElseToday => '今日はこれ以上ありません';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日が期限のタスクは $count 件',
      one: '今日が期限のタスクは 1 件',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => '今日の予定表を開く';

  @override
  String get traySyncNow => '今すぐ同期';

  @override
  String get traySyncing => '同期中…';

  @override
  String get trayNotConnected => '未接続';

  @override
  String get trayNotYetSynced => 'まだ同期されていません';

  @override
  String get trayLastSyncedJustNow => 'たった今同期';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分前に同期',
      one: '1 分前に同期',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 時間前に同期',
      one: '1 時間前に同期',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 日前に同期',
      one: '1 日前に同期',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => '設定';

  @override
  String get trayQuitBusyMax => 'BusyMax を終了';

  @override
  String get agendaLoadMoreOverdue => '期限切れのタスクをさらに読み込む';

  @override
  String get agendaLoadMoreNoDate => '日付のないタスクをさらに読み込む';

  @override
  String get viewDay => '日';

  @override
  String get viewWeek => '週';

  @override
  String get viewMonth => '月';

  @override
  String get viewYear => '年';

  @override
  String get viewAgenda => '予定一覧';

  @override
  String get scheduleSettings => 'スケジュール';

  @override
  String get scheduleDisplaySettings => 'スケジュール表示';

  @override
  String get scheduleDisplayHoursDescription =>
      '日表示と週表示では、最初にこの時間範囲が表示されます。必要に応じて、この範囲より前または後の項目も表示されるように範囲が広がります。';

  @override
  String get scheduleDayStartsAt => '一日の開始時刻';

  @override
  String get scheduleDayEndsAt => '一日の終了時刻';

  @override
  String get sourceCalendar => 'カレンダー';

  @override
  String get sourceTaskList => 'タスクリスト';

  @override
  String get createChoiceTitle => '作成';

  @override
  String get createEventAtTime => '予定';

  @override
  String get createTaskAtDate => 'タスク';

  @override
  String get editEvent => '予定を編集';

  @override
  String get eventTitle => '予定のタイトル';

  @override
  String get location => '場所';

  @override
  String get timeSlot => '時間帯';

  @override
  String get startDateTime => '開始日時';

  @override
  String get endDateTime => '終了日時';

  @override
  String get doesNotRepeat => '繰り返さない';

  @override
  String get defaultReminder => 'デフォルトのリマインダー';

  @override
  String get guests => 'ゲスト';

  @override
  String get noGuests => 'ゲストなし';

  @override
  String get attendeeRequired => '必須';

  @override
  String get attendeeOptional => '任意';

  @override
  String get meetingSection => '会議';

  @override
  String get addGoogleMeet => 'Google Meet を追加';

  @override
  String get addTeamsMeeting => 'Microsoft Teams 会議を追加';

  @override
  String get onlineMeetingAdded => 'オンライン会議を追加しました';

  @override
  String get requestResponses => '返信をリクエスト';

  @override
  String get requestResponsesDescription => 'ゲストに招待への返信を依頼します。';

  @override
  String get hideGuestList => 'ゲストリストを非表示';

  @override
  String get hideGuestListDescription => 'ゲストには他の招待者が表示されません。';

  @override
  String get allowNewTimeProposals => '新しい日時の提案を許可';

  @override
  String get allowNewTimeProposalsDescription => 'ゲストは別の会議時間を提案できます。';

  @override
  String get notifyGuestsTitle => 'ゲストに通知しますか？';

  @override
  String get notifyGuestsSaveMessage => 'この会議にはゲストがいます。保存時に招待または予定の更新を送信しますか？';

  @override
  String get notifyGuestsDeleteMessage => 'この会議にはゲストがいます。削除時にキャンセルを送信しますか？';

  @override
  String get sendUpdates => '更新を送信';

  @override
  String get sendCancellation => 'キャンセルを送信';

  @override
  String get doNotSend => '送信しない';

  @override
  String get microsoftNotifyGuestsSaveTitle => '会議を保存しますか？';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft からゲストに招待または予定の更新が送信されます。';

  @override
  String get microsoftNotifyGuestsDeleteTitle => '会議を削除しますか？';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft からゲストにキャンセルが送信されます。';

  @override
  String get organizer => '主催者';

  @override
  String get yourResponse => '自分の返信';

  @override
  String get guestResponses => 'ゲストの返信';

  @override
  String get respond => '返信';

  @override
  String get acceptInvitation => '承諾';

  @override
  String get tentativeInvitation => '仮承諾';

  @override
  String get declineInvitation => '辞退';

  @override
  String get joinMeeting => '会議に参加';

  @override
  String get responseAccepted => '承諾済み';

  @override
  String get responseTentative => '仮承諾';

  @override
  String get responseDeclined => '辞退済み';

  @override
  String get responseNeedsAction => '返信待ち';

  @override
  String get responseNotResponded => '未返信';

  @override
  String get responseOrganizer => '主催者';

  @override
  String invitationResponseFailed(String error) {
    return '返信を送信できませんでした: $error';
  }

  @override
  String get joinMeetingFailed => '会議リンクを開けませんでした。';

  @override
  String get description => '説明';

  @override
  String get availabilityShowAs => '空き時間情報 / 表示方法';

  @override
  String get busy => '予定あり';

  @override
  String get visibility => '公開設定';

  @override
  String get defaultVisibility => 'デフォルトの公開設定';

  @override
  String get conference => '会議';

  @override
  String get noConference => '会議なし';

  @override
  String get providerCalendar => 'プロバイダーのカレンダー';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => '太字';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => '斜体';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => '下線';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutesString分前',
      one: '1分前',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => '開始時';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString時間前',
      one: '1時間前',
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
      other: '$daysString日前',
      one: '1日前',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => '空き時間';

  @override
  String get availabilityTentative => '仮の予定';

  @override
  String get availabilityOutOfOffice => '外出中';

  @override
  String get availabilityWorkingElsewhere => '別の場所で勤務';

  @override
  String get visibilityDefault => 'デフォルト';

  @override
  String get visibilityPublic => '一般公開';

  @override
  String get visibilityPrivate => '非公開';

  @override
  String get visibilityConfidential => '機密';

  @override
  String get sensitivityNormal => '標準';

  @override
  String get sensitivityPersonal => '個人用';

  @override
  String get tasks => 'タスク';

  @override
  String get allTasks => 'すべてのタスク';

  @override
  String tasksInList(String title) {
    return '$title のタスク';
  }

  @override
  String get taskLists => 'タスクリスト';

  @override
  String get navigation => 'ナビゲーション';

  @override
  String get mainMenu => 'メインメニュー';

  @override
  String get keyboardShortcuts => 'キーボードショートカット';

  @override
  String get shortcutGroupGeneral => '全般';

  @override
  String get shortcutKeyboardShortcutsDescription => 'このショートカット一覧を表示';

  @override
  String get shortcutGroupNavigation => 'ナビゲーション';

  @override
  String get shortcutNextPeriod => '次の期間';

  @override
  String get shortcutNextPeriodDescription => '週表示では次の週、月表示では次の月というように移動します';

  @override
  String get shortcutPreviousPeriod => '前の期間';

  @override
  String get shortcutPreviousPeriodDescription =>
      '週表示では前の週、月表示では前の月というように移動します';

  @override
  String get shortcutJumpToToday => '今日に移動';

  @override
  String get shortcutGroupView => '表示';

  @override
  String get shortcutDayView => '日表示';

  @override
  String get shortcutWeekView => '週表示';

  @override
  String get shortcutMonthView => '月表示';

  @override
  String get shortcutYearView => '年表示';

  @override
  String get shortcutAgendaView => '予定一覧表示';

  @override
  String get shortcutGroupCreateAndEdit => '作成と編集';

  @override
  String get shortcutSaveItem => '予定またはタスクを保存';

  @override
  String get shortcutDeleteItem => '予定またはタスクを削除';

  @override
  String get shortcutGroupTaskEditing => 'タスクの編集';

  @override
  String get shortcutCancelEditing => '編集をキャンセル';

  @override
  String get shortcutCancelEditingDescription => 'タスクの編集または詳細を閉じる';

  @override
  String get aboutBusyMax => 'BusyMax について';

  @override
  String get aboutBusyMaxDescription => 'カレンダーとタスク';

  @override
  String get license => 'ライセンス';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'ウェブサイト';

  @override
  String get sourceCode => 'ソースコード';

  @override
  String get reportAnIssue => '問題を報告';

  @override
  String get sendFeedback => 'フィードバックを送信';

  @override
  String get feedbackSubmit => '送信';

  @override
  String get feedbackCategory => 'カテゴリー';

  @override
  String get feedbackSelectCategory => 'カテゴリーを選択';

  @override
  String get feedbackCategoryProblem => '問題またはバグ';

  @override
  String get feedbackCategoryFeature => '機能のリクエスト';

  @override
  String get feedbackCategoryPrivacySecurity => 'プライバシーまたはセキュリティに関する懸念';

  @override
  String get feedbackCategoryUsability => '使いやすさに関する懸念';

  @override
  String get feedbackCategoryOther => 'その他';

  @override
  String get feedbackSubject => '件名';

  @override
  String get feedbackDetailedMessage => '詳しい内容';

  @override
  String get feedbackReplyEmail => '返信先メールアドレス（任意）';

  @override
  String get feedbackIncludeTechnicalDetails => '技術情報を含める';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'オペレーティングシステムの名前とバージョン、およびアプリのロケールのみが追加されます。ログ、アカウントデータ、ファイル名、その他の診断情報は含まれません。';

  @override
  String get feedbackCategoryRequired => 'カテゴリーを選択してください。';

  @override
  String get feedbackSubjectLengthError => '件名は3文字以上120文字以下にしてください。';

  @override
  String get feedbackMessageLengthError => 'メッセージは10文字以上5,000文字以下にしてください。';

  @override
  String get feedbackInvalidEmail => '有効なメールアドレスを入力してください。';

  @override
  String get feedbackConnectionError =>
      'BusyStack に接続できませんでした。接続を確認して、もう一度お試しください。';

  @override
  String get feedbackTimeoutError =>
      'リクエストがタイムアウトしました。フィードバックは消去されていません。もう一度お試しください。';

  @override
  String get feedbackRateLimitedError =>
      'このネットワークから送信されたフィードバックが多すぎます。しばらく待ってから、もう一度お試しください。';

  @override
  String get feedbackRejectedError => 'サーバーが送信を拒否しました。入力内容を確認して、もう一度お試しください。';

  @override
  String get feedbackServerError =>
      '現在、BusyStack はフィードバックを受け付けられません。フィードバックは消去されていません。もう一度お試しください。';

  @override
  String feedbackSuccess(String id) {
    return 'フィードバックを送信しました。参照番号: $id';
  }

  @override
  String get toggleSidebar => 'サイドバーの表示を切り替え';

  @override
  String get showSidebar => 'サイドバーパネルを表示';

  @override
  String get hideSidebar => 'サイドバーパネルを非表示';

  @override
  String get accounts => 'アカウント';

  @override
  String get currentAccount => '現在のアカウント';

  @override
  String get switchAccount => 'アカウントを切り替え';

  @override
  String get addGoogleAccount => 'Google アカウントを追加';

  @override
  String get addMicrosoftAccount => 'Microsoft アカウントを追加';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'サインイン済み';

  @override
  String get removeAccount => 'アカウントを削除…';

  @override
  String get removingAccount => 'アカウントを削除しています…';

  @override
  String get removeAccountDescription => '同期を停止し、このアカウントのデータをこのデバイスから削除します。';

  @override
  String removeAccountTitle(String account) {
    return '$account を BusyMax から削除しますか？';
  }

  @override
  String get removeAccountConfirmation =>
      'このデバイスから、キャッシュされたタスク、カレンダー、予定、リマインダー、保留中のオフライン変更を削除します。同期されていない変更は失われます。プロバイダー側のカレンダー、予定、タスクリスト、タスクのコピーは削除されません。';

  @override
  String get revokeGoogleAccess => 'この Google アカウントへの BusyMax のアクセス権も取り消す';

  @override
  String get revokeGoogleAccessDescription => '再接続する前に、もう一度アクセスを許可する必要があります。';

  @override
  String get removeAccountAction => 'アカウントを削除';

  @override
  String get removeAccountFailed => 'アカウントの削除を完了できませんでした。もう一度お試しください。';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'アカウントはこのデバイスから削除されましたが、BusyMax は Google アカウントへのアクセス権を取り消せませんでした。Google アカウントの設定から取り消すことができます。';

  @override
  String get newTaskList => '新しいタスクリスト';

  @override
  String taskListCreateFailed(String error) {
    return 'タスクリストを作成できませんでした: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'タスクリストの名前を変更できませんでした: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'タスクリストを削除できませんでした: $error';
  }

  @override
  String get signInToViewTaskLists => 'タスクリストを表示するにはサインインしてください。';

  @override
  String get noTaskListsSynced => '同期済みのタスクリストはまだありません。';

  @override
  String get listActions => 'リストの操作';

  @override
  String get rename => '名前を変更';

  @override
  String get delete => '削除';

  @override
  String get renameList => 'リスト名を変更';

  @override
  String get deleteList => 'リストを削除';

  @override
  String get unshare => '共有を解除';

  @override
  String get readOnlyTaskListCannotRename => 'このタスクリストは読み取り専用のため、名前を変更できません。';

  @override
  String get taskListCannotDelete => '現在の権限ではこのタスクリストを削除できません。';

  @override
  String get builtInMicrosoftList => '組み込み';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Microsoft To Do の組み込みリストは、名前の変更や削除ができません。';

  @override
  String deleteListConfirmation(String title) {
    return 'Google Tasks から「$title」を削除しますか？';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '「$title」とそのすべてのタスクを削除しますか？';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'このアカウントとの「$title」の共有を解除しますか？';
  }

  @override
  String get deleteEvent => '予定を削除';

  @override
  String get title => 'タイトル';

  @override
  String get create => '作成';

  @override
  String get newTask => '新しいタスク';

  @override
  String get clearCompleted => '完了済みを消去';

  @override
  String get refreshList => 'リストを更新';

  @override
  String get refreshAll => 'すべて更新';

  @override
  String get listRefreshed => 'リストを更新しました。';

  @override
  String get allTasksRefreshed => 'すべてのアカウントを更新しました。';

  @override
  String exportedFile(String path) {
    return '$path にエクスポートしました';
  }

  @override
  String exportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String refreshFailed(String error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get selectOrCreateTaskList => '開始するには、タスクリストを選択または作成してください。';

  @override
  String get signInToViewTasks => 'タスクを表示するにはサインインしてください。';

  @override
  String get noTasks => 'タスクはありません。';

  @override
  String get noTasksYet => 'タスクはまだありません';

  @override
  String get noTasksYetMessage => 'タスクを作成するか、アカウントを更新して始めましょう。';

  @override
  String get noTasksInList => 'このリストにタスクはありません。';

  @override
  String get overdue => '期限超過';

  @override
  String get today => '今日';

  @override
  String get tomorrow => '明日';

  @override
  String get upcoming => '今後';

  @override
  String get noDate => '日付なし';

  @override
  String get completed => '完了';

  @override
  String duePrefix(String date) {
    return '期限: $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => 'タスクの詳細';

  @override
  String get editTask => 'タスクを編集';

  @override
  String get noTaskSelected => 'タスクが選択されていません。';

  @override
  String get noTaskSelectedHelper => '詳細を表示して編集するタスクを選択してください。';

  @override
  String get taskUnavailable => 'タスクを利用できません。';

  @override
  String get signInToEditTasks => 'タスクを編集するにはサインインしてください。';

  @override
  String get refreshTask => 'タスクを更新';

  @override
  String get primarySection => '基本情報';

  @override
  String get statusSection => 'ステータス';

  @override
  String get openStatus => '未完了';

  @override
  String get doneStatus => '完了';

  @override
  String get taskStatus => 'ステータス';

  @override
  String get taskStatusNone => 'ステータスなし';

  @override
  String get taskStatusNeedsAction => '要対応';

  @override
  String get taskStatusInProcess => '進行中';

  @override
  String get taskStatusCompleted => '完了';

  @override
  String get taskStatusCancelled => 'キャンセル済み';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$percentString% 完了';
  }

  @override
  String get completionDate => '完了日';

  @override
  String get priority => '優先度';

  @override
  String get priorityNone => '優先度なし';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return '優先度 $priorityString · 高';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return '優先度 $priorityString · 中';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return '優先度 $priorityString · 低';
  }

  @override
  String get taskUrl => 'タスク URL';

  @override
  String get invalidTaskUrl => 'スキームを含む絶対 URL を入力してください。';

  @override
  String get classification => '分類';

  @override
  String get classificationPublic => '共有時にタスク全体を表示';

  @override
  String get classificationConfidential => '共有時に空き状況のみ表示';

  @override
  String get classificationPrivate => '共有時にこのタスクを非表示';

  @override
  String get pinTask => 'タスクをピン留め';

  @override
  String get notes => 'メモ';

  @override
  String get dueDate => '期限日';

  @override
  String get clearDueDate => '期限日を消去';

  @override
  String get dueTime => '期限時刻';

  @override
  String get startDate => '開始日';

  @override
  String get startTime => '開始時刻';

  @override
  String get endDate => '終了日';

  @override
  String get endTime => '終了時刻';

  @override
  String get reminderDate => 'リマインダーの日付';

  @override
  String get reminderTime => 'リマインダーの時刻';

  @override
  String get reminder => 'リマインダー';

  @override
  String get addReminder => 'リマインダーを追加';

  @override
  String get reminders => 'リマインダー';

  @override
  String get noReminders => 'リマインダーなし';

  @override
  String get editReminder => 'リマインダーを編集';

  @override
  String get beforeTaskStarts => 'タスクの開始前';

  @override
  String get beforeTaskDue => 'タスクの期限前';

  @override
  String get afterTaskStarts => 'タスクの開始後';

  @override
  String get afterTaskDue => 'タスクの期限後';

  @override
  String get relativeToTaskStart => 'タスクの開始日に対して';

  @override
  String get relativeToTaskDue => 'タスクの期限日に対して';

  @override
  String get reminderTimeOfDay => '時刻';

  @override
  String get absoluteReminder => '日時を指定';

  @override
  String get reminderAmount => '数値';

  @override
  String get reminderUnit => '単位';

  @override
  String get reminderUnitSeconds => '秒';

  @override
  String get reminderUnitMinutes => '分';

  @override
  String get reminderUnitHours => '時間';

  @override
  String get reminderUnitDays => '日';

  @override
  String get reminderUnitWeeks => '週';

  @override
  String get reminderAtTaskStart => 'タスクの開始時';

  @override
  String get reminderAtTaskDue => 'タスクの期限時刻';

  @override
  String get unsupportedReminder => 'このリマインダーの種類は保持されますが、時刻は編集できません。';

  @override
  String get relatedRemindersTitle => '関連するリマインダーを保持しますか？';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'この日付には関連するリマインダーが $countString 件あります。現在の日付と時刻を保持しますか？';
  }

  @override
  String get discardRelatedReminders => 'リマインダーを破棄';

  @override
  String get keepRelatedReminders => 'リマインダーを保持';

  @override
  String get addGuest => 'ゲストを追加';

  @override
  String get addGuestEmail => 'ゲストのメールアドレスを追加';

  @override
  String get removeReminder => 'リマインダーを削除';

  @override
  String get off => 'オフ';

  @override
  String get repeat => '繰り返し';

  @override
  String get repeatNone => 'なし';

  @override
  String get noneValue => 'なし';

  @override
  String get repeatDaily => '毎日';

  @override
  String get repeatWeekly => '毎週';

  @override
  String get repeatMonthly => '毎月';

  @override
  String get repeatYearly => '毎年';

  @override
  String get repeatEvery => '繰り返し間隔';

  @override
  String get repeatOn => '繰り返す曜日';

  @override
  String get repeatEnd => '繰り返しを終了';

  @override
  String get repeatNever => 'なし';

  @override
  String get repeatUntil => '指定日まで';

  @override
  String get repeatAfter => '指定回数後';

  @override
  String get repeatCount => '繰り返し回数';

  @override
  String get repeatDayOfMonth => '月の日';

  @override
  String get repeatMonths => '月';

  @override
  String get repeatOrdinal => '曜日の順番';

  @override
  String get repeatSpecificDays => '特定の曜日';

  @override
  String get repeatFirst => '第 1';

  @override
  String get repeatSecond => '第 2';

  @override
  String get repeatThird => '第 3';

  @override
  String get repeatFourth => '第 4';

  @override
  String get repeatFifth => '第 5';

  @override
  String get repeatSecondToLast => '最後から 2 番目';

  @override
  String get repeatLast => '最後';

  @override
  String get repeatAnyDay => '日';

  @override
  String get repeatWeekday => '平日';

  @override
  String get repeatWeekendDay => '週末';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': '月曜日',
      'TU': '火曜日',
      'WE': '水曜日',
      'TH': '木曜日',
      'FR': '金曜日',
      'SA': '土曜日',
      'SU': '日曜日',
      'day': '日',
      'weekday': '平日',
      'weekend': '週末',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 日ごと';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 週間ごと';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString か月ごと';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 年ごと';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第1$days',
      'second': '第2$days',
      'third': '第3$days',
      'fourth': '第4$days',
      'fifth': '第5$days',
      'secondToLast': '最後から2番目の$days',
      'last': '最後の$days',
      'other': '$days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return '$months に';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 回',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return '$date まで';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'この繰り返しルールには、このエディターで変更されないオプションが含まれています。';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'この繰り返しは $provider では使用できません。';
  }

  @override
  String get importance => '重要度';

  @override
  String get importanceLow => '低';

  @override
  String get importanceNormal => '標準';

  @override
  String get importanceHigh => '高';

  @override
  String get categories => 'カテゴリー';

  @override
  String get scheduleSection => 'スケジュール';

  @override
  String get dueGroup => '期限';

  @override
  String get startGroup => '開始';

  @override
  String get reminderGroup => 'リマインダー';

  @override
  String get organizationSection => '整理';

  @override
  String get actionsSection => '操作';

  @override
  String get advancedSection => '詳細設定';

  @override
  String get addCategory => 'カテゴリーを追加';

  @override
  String get list => 'リスト';

  @override
  String get microsoftMoveUnsupported =>
      'このバージョンでは、Microsoft To Do アカウントのリスト間でタスクを移動できません。';

  @override
  String get createSubtask => 'サブタスクを作成';

  @override
  String get subtasks => 'サブタスク';

  @override
  String get duplicateTask => 'タスクを複製';

  @override
  String get taskDuplicated => 'タスクを複製しました。';

  @override
  String taskDuplicateFailed(String error) {
    return 'タスクを複製できませんでした: $error';
  }

  @override
  String get hideSubtasks => 'サブタスクを非表示';

  @override
  String get hideClosedSubtasks => '完了したサブタスクを非表示';

  @override
  String get moveToTop => '一番上に移動';

  @override
  String get deleteTask => 'タスクを削除';

  @override
  String get newSubtask => '新しいサブタスク';

  @override
  String deleteTaskConfirmation(String title) {
    return '「$title」を削除しますか？';
  }

  @override
  String get metadata => 'メタデータ';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => '更新日時';

  @override
  String get parent => '親タスク';

  @override
  String get position => '位置';

  @override
  String get webLink => 'ウェブリンク';

  @override
  String get assignment => '割り当て';

  @override
  String get localState => 'ローカル状態';

  @override
  String get pendingSync => '同期待ち';

  @override
  String get synced => '同期済み';

  @override
  String get account => 'アカウント';

  @override
  String get sync => '同期';

  @override
  String get forceFullResync => '完全な再同期を強制';

  @override
  String get forceFullResyncDescription =>
      '接続されているすべてのアカウントからデータを完全に再読み込みします。同期の問題を解決する場合にのみ使用してください。';

  @override
  String get runInBackgroundWhenClosed => 'ウィンドウを閉じてもバックグラウンドで実行を続ける';

  @override
  String get showTrayIcon => 'トレイアイコンを表示';

  @override
  String get startMinimizedToTray => 'トレイに最小化して起動';

  @override
  String get launchAtLogin => 'ログイン時に起動';

  @override
  String get launchAtLoginDescription =>
      'ログイン後もリマインダーが動作するように、BusyMaxをバックグラウンドで起動します。';

  @override
  String get launchAtLoginFailed => 'ログイン時の起動設定を更新できませんでした。';

  @override
  String get requiresTrayIcon => 'トレイアイコンが必要です。';

  @override
  String get syncComplete => '同期が完了しました。';

  @override
  String syncFailed(String error) {
    return '同期に失敗しました: $error';
  }

  @override
  String get notifySyncFailures => '同期失敗時に通知';

  @override
  String get notifyConflicts => '競合時に通知';

  @override
  String get notifyDueToday => '今日が期限のタスクを通知';

  @override
  String get eventReminders => '予定のリマインダー';

  @override
  String get onState => 'オン';

  @override
  String get taskReminders => 'タスクのリマインダー';

  @override
  String get notificationDetailLevel => '通知の詳細度';

  @override
  String get notificationDetailPrivate => '非公開';

  @override
  String get notificationDetailNormal => '標準';

  @override
  String get quietHours => '通知を停止する時間';

  @override
  String get quietHoursDescription => 'この時間帯は通知を一時停止します。';

  @override
  String get quietHoursStart => '通知停止の開始時刻';

  @override
  String get quietHoursEnd => '通知停止の終了時刻';

  @override
  String get notifications => '通知';

  @override
  String get windowsNotificationsUnavailable => 'Windows 通知を利用できません';

  @override
  String get windowsNotificationsUnpackaged =>
      'このパッケージ化されていない開発実行では Windows 通知を使用できません。リマインダーをテストするには、テスト署名済み MSIX をインストールしてください。';

  @override
  String get windowsNotificationsInstalledFailure =>
      'BusyMax は Windows 通知を初期化できませんでした。このインストールの問題が解決するまで、リマインダーは表示されません。';

  @override
  String get appearance => '外観';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get settingsSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeFamily => 'テーマファミリー';

  @override
  String get themeFamilyYaru => 'Ubuntu ネイティブ（Yaru）';

  @override
  String get localization => '言語と地域';

  @override
  String get currentLocale => '現在のロケール';

  @override
  String get privacy => 'プライバシー';

  @override
  String get redactTaskContentInDiagnostics => '診断情報でタスクの内容を伏せる';

  @override
  String get developerDiagnostics => '開発者向け診断';

  @override
  String get diagnostics => '診断';

  @override
  String get apiInspectorDisabled => 'API インスペクターを表示';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery リビジョン: $revision';
  }

  @override
  String get implementedMethods => '実装済みメソッド';

  @override
  String get supportsTasksScopes => 'tasks および tasks.readonly スコープをサポート';

  @override
  String get requiresTasksScope => 'tasks スコープが必要';

  @override
  String get blockedPendingOperations => 'ブロックされた保留中の操作';

  @override
  String get signInToInspectPendingOperations => '保留中の操作を確認するにはサインインしてください。';

  @override
  String get noBlockedPendingOperations => 'ブロックされた保留中の操作はありません。';

  @override
  String get operationActions => '操作への対応';

  @override
  String pendingOpListId(String id) {
    return 'リスト=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'タスク=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '試行回数=$countString';
  }

  @override
  String get retry => '再試行';

  @override
  String get discard => '破棄';

  @override
  String get discardChangesAction => '破棄';

  @override
  String get discardChanges => '変更を破棄しますか？';

  @override
  String get discardChangesConfirmation => 'このタスクの未保存の編集内容を破棄します。';

  @override
  String get retryCompleted => '再試行が完了しました。';

  @override
  String get discardPendingOperation => '保留中の操作を破棄しますか？';

  @override
  String get discardPendingOperationConfirmation =>
      'ブロックされたローカル操作を削除します。次回の同期時に Google Tasks からデータが再取得されます。';

  @override
  String get pendingOperationDiscarded => '保留中の操作を破棄しました。';

  @override
  String get syncFailureNotificationTitle => 'BusyMax の同期に失敗';

  @override
  String syncFailureNotificationBody(String message) {
    return 'バックグラウンド同期に失敗しました。$message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax の同期競合';

  @override
  String conflictNotificationBody(String summary) {
    return '保留中のローカル変更がブロックされました。$summary';
  }

  @override
  String get dueTodayNotificationTitle => '今日が期限のタスク';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日が期限のタスクが$countString件あります。',
      one: '今日が期限のタスクが1件あります。',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => '予定のリマインダー';

  @override
  String get taskReminderNotificationTitle => 'タスクのリマインダー';

  @override
  String get eventReminderNotificationBody => '予定がまもなく始まります。';

  @override
  String get taskReminderNotificationBody => 'タスクの期限が近づいています。';

  @override
  String get notificationOpenAction => '開く';

  @override
  String get notificationSnoozeAction => '10分後に再通知';

  @override
  String get notificationDismissAction => '閉じる';

  @override
  String get notificationDetailsHidden => 'プライバシー設定により詳細は非表示です。';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get openMonthView => '月表示を開く';

  @override
  String get previousYear => '前の年';

  @override
  String get nextYear => '次の年';

  @override
  String get openYearView => '年表示を開く';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return '第$numberString週';
  }

  @override
  String get resizeAllDayPanel => '終日パネルのサイズを変更';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString件',
      one: '1件',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'このカレンダーは読み取り専用です。';

  @override
  String get selectTimeZone => 'タイムゾーンを選択';

  @override
  String get searchLocations => '場所を検索';

  @override
  String get noLocationsFound => '場所が見つかりません';

  @override
  String get requiredField => 'このフィールドは必須です。';

  @override
  String get providerConnectionDescription => '次のいずれかのプロバイダーからカレンダーとタスクを接続します。';

  @override
  String get appleICloudProvider => 'Apple iCloud カレンダー';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud タスク';

  @override
  String get addAppleICloudAccount => 'Apple iCloud カレンダーアカウントを追加';

  @override
  String get addNextcloudAccount => 'Nextcloud アカウントを追加';

  @override
  String get waitingForAppleICloud => 'Apple iCloud に接続中…';

  @override
  String get waitingForNextcloud => 'Nextcloud の認証を待機中…';

  @override
  String get connectAppleICloudTitle => 'Apple iCloud カレンダーを接続';

  @override
  String get appleAccountEmail => 'Apple アカウントのメールアドレス';

  @override
  String get appleAppSpecificPassword => 'App 用パスワード';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Apple アカウントで 2 要素認証を有効にした後、App 用パスワードを作成してください。';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Apple アカウントのパスワードをリセットすると、App 用パスワードが無効になります。';

  @override
  String get connectNextcloudTitle => 'Nextcloud を接続';

  @override
  String get nextcloudServerUrl => 'Nextcloud サーバーまたは CalDAV アドレス';

  @override
  String get nextcloudServerUrlHelp =>
      'Nextcloud サーバーの URL を入力するか、Nextcloud からコピーしたプライマリ CalDAV アドレスを貼り付けてください。';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax がブラウザーを開きます。そこでアクセスを許可してから BusyMax に戻ってください。';

  @override
  String get connectAccountAction => '接続';

  @override
  String get cancelAccountConnection => '接続をキャンセル';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'アカウントはローカルから削除されましたが、Nextcloud の App パスワードを無効にできませんでした。';

  @override
  String get davCachedOfflineNotice =>
      'オフラインで使用できるよう、カレンダーとタスクのデータはローカルにキャッシュされます。';

  @override
  String get davReauthenticationRequired => '同期を再開するには、このアカウントを再接続してください。';

  @override
  String get davTemporarilyUnavailable => 'このアカウントは一時的に利用できません。';

  @override
  String get davPermissionChanged => 'サーバーの権限が変更されました。保留中の編集は一時停止されています。';

  @override
  String get davUnsupportedServer => 'このサーバーまたはプロバイダー プロファイルはサポートされていません。';

  @override
  String get collectionSettings => 'カレンダーとタスクリスト';

  @override
  String get calendarContent => 'カレンダーの予定';

  @override
  String get taskContent => 'タスク';

  @override
  String get readOnlySharedCollection => '読み取り専用';

  @override
  String get pendingLocally => 'ローカルで保留中';

  @override
  String get conflictBlocked => '競合によりブロック';

  @override
  String get authenticationBlocked => '再接続するまでブロック';

  @override
  String get operationFailed => '操作に失敗';

  @override
  String get keepServerVersion => 'サーバーのバージョンを保持';

  @override
  String get reapplyLocalChange => 'ローカル変更を確認して再適用';

  @override
  String get duplicateLocalItem => '新しいアイテムとして複製';

  @override
  String get davConnectionState => '接続状態';

  @override
  String get davConnected => '接続済み';

  @override
  String get davConnecting => '接続中…';

  @override
  String get davSignedOut => 'サインアウト済み';

  @override
  String davLastSuccessfulSync(String time) {
    return '最後に成功した同期: $time';
  }

  @override
  String get davNeverSynced => 'まだ同期されていません';

  @override
  String get refreshCollections => 'カレンダーとタスクリストを更新';

  @override
  String nextcloudServerHost(String host) {
    return 'サーバー: $host';
  }

  @override
  String get collectionSupportsEvents => '予定カレンダー';

  @override
  String get collectionSupportsTasks => 'タスクリスト';

  @override
  String get collectionSupportsEventsAndTasks => '予定とタスク';

  @override
  String get writableCollection => '書き込み可能';

  @override
  String get sharedCollection => '共有';

  @override
  String collectionLastSynced(String time) {
    return '最後の同期: $time';
  }

  @override
  String collectionSyncError(String code) {
    return '同期の問題: $code';
  }

  @override
  String get syncConflicts => '同期の競合';

  @override
  String remoteChangedAt(String time) {
    return 'サーバーでの変更: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'ローカル編集: $summary';
  }

  @override
  String get conflictResolutionFailed => '競合を解決できませんでした。';

  @override
  String get recurringEventScope => '繰り返し予定の範囲';

  @override
  String get entireSeries => '予定全体';

  @override
  String get singleOccurrence => 'この予定';

  @override
  String get thisAndFollowingEvents => 'この予定とこれ以降の予定';

  @override
  String get thisAndFutureUnavailable => 'このプロバイダーではサポートされていません。';

  @override
  String get thisAndFutureMoveUnavailable =>
      'この予定とこれ以降の予定を安全に移動することはできません。この予定または予定全体を選択してください。';

  @override
  String get entireSeriesMoveUnavailable =>
      '繰り返しルールがローカルにありません。代わりにこの予定だけを移動してください。';

  @override
  String get copyEventAndDeleteOriginal => '予定をコピーして元の予定を削除しますか？';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax はこの予定を $source から $destination へ直接移動できません。先にコピーを作成し、コピーが成功した場合にのみ元の予定を削除します。予定 ID は変更されます。出席者の回答状況がリセットされ、招待やキャンセルが送信される場合があります。また、会議リンク、添付ファイル、リマインダー、プロバイダー固有のフィールド、繰り返しの例外は引き継がれない場合があります。';
  }

  @override
  String get copyAndDelete => 'コピーして削除';

  @override
  String get chooseRecurringEventScope =>
      'この変更を予定全体、この予定のみ、この予定とこれ以降の予定のどれに適用するか選択してください。';

  @override
  String get taskDueBeforeStart => '期限を開始より前に設定することはできません。';

  @override
  String get taskStartDueTimeModeMismatch => '開始と期限の両方に時刻を設定するか、タスクを終日にしてください。';

  @override
  String deleteCalendarConfirmation(String title) {
    return '「$title」を削除しますか？';
  }

  @override
  String get setCustomCalendarName => 'カスタム名を設定';

  @override
  String get setAction => '設定';

  @override
  String get removeFromMyCalendars => 'マイカレンダーから削除';

  @override
  String get removeAction => '削除';

  @override
  String removeCalendarConfirmation(String title) {
    return '「$title」を Google カレンダーのリストから削除しますか？共有カレンダーとその予定は削除されません。';
  }

  @override
  String get calendarCannotRemove => 'このカレンダーはこのアカウントから削除または解除できません。';

  @override
  String get calendarPendingChangesPreventRemoval =>
      '削除または解除する前に、このカレンダーの保留中の変更が同期されるまで待ってください。';

  @override
  String get calendarSubscriptions => 'カレンダーの登録';

  @override
  String get calendarSubscriptionsDescription =>
      '安全な WebCal URL から更新される読み取り専用カレンダーを追加します。';

  @override
  String get addCalendarSubscription => 'カレンダー登録を追加';

  @override
  String get subscriptionName => 'ローカル名';

  @override
  String get subscriptionUrl => '登録 URL';

  @override
  String get subscriptionUrlHelp =>
      'HTTPS または webcal URL を入力してください。BusyMax は完全な URL を安全なストレージに保存します。';

  @override
  String get subscriptionUrlInvalid =>
      'ユーザー情報やフラグメントを含まない有効な HTTPS または webcal URL を入力してください。';

  @override
  String get subscriptionColor => 'ローカルの色';

  @override
  String get subscriptionColorHelp => '#3584E4 のような 6 桁の色を使用してください。';

  @override
  String get subscriptionColorInvalid => '6 桁の 16 進数カラーを入力してください。';

  @override
  String get subscriptionRefreshMode => '更新頻度';

  @override
  String get subscriptionAutomatic => '自動';

  @override
  String get subscriptionHourly => '毎時';

  @override
  String get subscriptionSixHours => '6 時間ごと';

  @override
  String get subscriptionDaily => '毎日';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'ソース: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      '安全なオリジンをプレビューするには有効な URL を入力してください。';

  @override
  String get subscriptionReadOnly => '読み取り専用の登録';

  @override
  String get subscriptionNeverRefreshed => 'まだ更新されていません';

  @override
  String subscriptionLastRefresh(String time) {
    return '最後に成功した更新: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return '次回の更新: $time';
  }

  @override
  String get subscriptionStatusHealthy => '最新';

  @override
  String subscriptionStatusIssue(String code) {
    return '更新の問題: $code';
  }

  @override
  String get refreshNow => '今すぐ更新';

  @override
  String get unsubscribe => '登録を解除';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '「$name」の登録を解除しますか？';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'ローカル登録とキャッシュされた予定を削除します。公開されているカレンダーは変更されません。';

  @override
  String get addSubscriptionAction => '登録を追加';

  @override
  String subscriptionOperationFailed(String error) {
    return 'カレンダー登録に失敗: $error';
  }

  @override
  String get subscriptions => '登録';

  @override
  String get calendarImport => 'カレンダーをインポート';

  @override
  String get calendarImportDescription =>
      'ファイルを選択して予定を確認し、受け入れ先の書き込み可能なカレンダーを選択します。';

  @override
  String get importIcsFile => '.ics ファイルをインポート';

  @override
  String get importIcsPreview => 'カレンダーの予定をインポート';

  @override
  String importEventsFound(int count) {
    return 'インポート可能な予定セット: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return '無効な予定: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return '意図的に省略: $fields';
  }

  @override
  String get noWritableCalendars => '書き込み可能な移行先カレンダーがありません。';

  @override
  String get importDestinationCalendar => '移行先カレンダー';

  @override
  String get importIcsConfirm => '予定をインポート';

  @override
  String get importIcsComplete => 'インポート完了';

  @override
  String importQueued(int count) {
    return 'インポート済みまたはキュー済み: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return '重複をスキップ: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'サポートされない繰り返しセット: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'カレンダーファイルをインポートできませんでした: $error';
  }

  @override
  String get networkOffline => 'オフライン';

  @override
  String get networkOfflineDescription => '接続が復旧すると変更が同期されます。';

  @override
  String get networkOfflineTryAgain => 'オフラインです。インターネットに接続して、もう一度お試しください。';

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
    return '$first、$second';
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
    return '$firstと$second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first、$rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$firstと$second';
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
    return '$frequency$monthの$days';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency$monthsの$day';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency$monthsの$days';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第1$days',
      'second': '第2$days',
      'third': '第3$days',
      'fourth': '第4$days',
      'fifth': '第5$days',
      'secondToLast': '最後から2番目の$days',
      'last': '最後の$days',
      'other': '$days',
    });
    return '$frequency$monthの$_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '第1$days',
      'second': '第2$days',
      'third': '第3$days',
      'fourth': '第4$days',
      'fifth': '第5$days',
      'secondToLast': '最後から2番目の$days',
      'last': '最後の$days',
      'other': '$days',
    });
    return '$frequency$monthsの$_temp0';
  }
}

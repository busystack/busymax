// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'понедельникам',
      'TU': 'вторникам',
      'WE': 'средам',
      'TH': 'четвергам',
      'FR': 'пятницам',
      'SA': 'субботам',
      'SU': 'воскресеньям',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return '$first и $second числа каждого месяца';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency: $month, $firstDay и $secondDay числа';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency: $firstMonth и $secondMonth, $day числа';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency: $firstMonth и $secondMonth, $firstDay и $secondDay числа';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency: $firstMonth и $secondMonth, $days числа';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Подключите аккаунты Google, Microsoft, Apple iCloud Calendar или Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'На экране запроса доступа Google установите флажки «Google Календарь» и «Google Задачи».';

  @override
  String get googlePermissionsRequiredRetry =>
      'BusyMax требуется доступ к Google Календарю и Google Задачам. Повторите попытку и установите оба флажка.';

  @override
  String get finishSetup => 'Завершить настройку';

  @override
  String get continueSetup => 'Продолжить';

  @override
  String get onboardingSetupTitle => 'Настройка BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Подключите аккаунты';

  @override
  String get onboardingAccountsStepDescription =>
      'Добавьте все нужные аккаунты. BusyMax синхронизирует поддерживаемые календари, события, списки задач и задачи из каждого аккаунта.';

  @override
  String get onboardingPreferencesStepTitle => 'Выберите системные параметры';

  @override
  String get onboardingPreferencesStepDescription =>
      'Настройте поведение приложения на рабочем столе, напоминания, уровень детализации уведомлений и внешний вид, прежде чем открыть расписание.';

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get signInWithMicrosoft => 'Войти через Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Этот сервис не настроен.';

  @override
  String get waitingForGoogleSignIn => 'Ожидание входа через Google...';

  @override
  String get waitingForMicrosoftSignIn => 'Ожидание входа через Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'Вход через Microsoft не настроен. Задайте MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get exit => 'Выйти';

  @override
  String get options => 'Параметры';

  @override
  String get hide => 'Скрыть';

  @override
  String get show => 'Показать';

  @override
  String get export => 'Экспортировать';

  @override
  String get save => 'Сохранить';

  @override
  String get settings => 'Настройки';

  @override
  String get all => 'Все';

  @override
  String get calendarEvents => 'События';

  @override
  String get calendarTasks => 'Задачи';

  @override
  String get calendar => 'Календарь';

  @override
  String get calendars => 'Календари';

  @override
  String get newCalendar => 'Новый календарь';

  @override
  String get calendarColor => 'Цвет календаря';

  @override
  String calendarColorOption(int number) {
    return 'Цвет $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Этот провайдер не поддерживает управление календарями в BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'Основной календарь нельзя удалить.';

  @override
  String calendarCreateFailed(String error) {
    return 'Не удалось создать календарь: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'Календарь создан, но BusyMax не смог обновить учётную запись. Он появится после следующей синхронизации.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Не удалось обновить календарь: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Не удалось удалить календарь: $error';
  }

  @override
  String get newEvent => 'Новое событие';

  @override
  String get refreshCalendar => 'Обновить календарь';

  @override
  String get openInProvider => 'Открыть в сервисе';

  @override
  String get hideFromSchedule => 'Скрыть из расписания';

  @override
  String get showInSchedule => 'Показывать в расписании';

  @override
  String get noCalendarsSynced => 'Синхронизированных календарей пока нет.';

  @override
  String get allDay => 'Весь день';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+ ещё $countString';
  }

  @override
  String get noEventsOrTasks => 'Нет событий или задач';

  @override
  String get scheduleLoading => 'Загрузка расписания...';

  @override
  String get scheduleUnavailable => 'Расписание недоступно';

  @override
  String get scheduleNoSources => 'Нет видимых календарей или списков задач';

  @override
  String get scheduleNoSourcesDescription =>
      'Выберите в настройках, что нужно показывать, а затем обновите расписание.';

  @override
  String get scheduleSignInRequired => 'Подключите аккаунт';

  @override
  String get scheduleSignInDescription =>
      'Войдите, чтобы синхронизировать календари и задачи.';

  @override
  String get scheduleNoSearchResults => 'Подходящих событий или задач нет';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Попробуйте изменить запрос или сбросить текущие фильтры.';

  @override
  String get refresh => 'Обновить';

  @override
  String get trayOpenBusyMax => 'Открыть BusyMax';

  @override
  String get trayShowBusyMax => 'Показать BusyMax';

  @override
  String get trayNewEvent => 'Новое событие…';

  @override
  String get trayNewTask => 'Новая задача…';

  @override
  String get trayToday => 'Сегодня';

  @override
  String get trayAllDay => 'Весь день';

  @override
  String get trayNow => 'Сейчас';

  @override
  String get trayCalendarEvent => 'Событие календаря';

  @override
  String get trayUntitledEvent => 'Событие без названия';

  @override
  String get trayNothingElseToday => 'На сегодня больше ничего';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сегодня истекает срок $count задачи',
      many: 'Сегодня истекает срок $count задач',
      few: 'Сегодня истекает срок $count задач',
      one: 'Сегодня истекает срок 1 задачи',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Открыть расписание на сегодня';

  @override
  String get traySyncNow => 'Синхронизировать сейчас';

  @override
  String get traySyncing => 'Синхронизация…';

  @override
  String get trayNotConnected => 'Не подключено';

  @override
  String get trayNotYetSynced => 'Ещё не синхронизировано';

  @override
  String get trayLastSyncedJustNow => 'Синхронизировано только что';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Синхронизировано $count минуты назад',
      many: 'Синхронизировано $count минут назад',
      few: 'Синхронизировано $count минуты назад',
      one: 'Синхронизировано минуту назад',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Синхронизировано $count часа назад',
      many: 'Синхронизировано $count часов назад',
      few: 'Синхронизировано $count часа назад',
      one: 'Синхронизировано час назад',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Синхронизировано $count дня назад',
      many: 'Синхронизировано $count дней назад',
      few: 'Синхронизировано $count дня назад',
      one: 'Синхронизировано день назад',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Настройки';

  @override
  String get trayQuitBusyMax => 'Выйти из BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Загрузить ещё просроченные задачи';

  @override
  String get agendaLoadMoreNoDate => 'Загрузить ещё задачи без даты';

  @override
  String get viewDay => 'День';

  @override
  String get viewWeek => 'Неделя';

  @override
  String get viewMonth => 'Месяц';

  @override
  String get viewYear => 'Год';

  @override
  String get viewAgenda => 'Расписание';

  @override
  String get scheduleSettings => 'Расписание';

  @override
  String get scheduleDisplaySettings => 'Отображение расписания';

  @override
  String get scheduleDisplayHoursDescription =>
      'В представлениях дня и недели изначально отображается этот период. Более ранние или поздние записи при необходимости расширяют его.';

  @override
  String get scheduleDayStartsAt => 'Начало дня';

  @override
  String get scheduleDayEndsAt => 'Конец дня';

  @override
  String get sourceCalendar => 'Календарь';

  @override
  String get sourceTaskList => 'Список задач';

  @override
  String get createChoiceTitle => 'Создать';

  @override
  String get createEventAtTime => 'Событие';

  @override
  String get createTaskAtDate => 'Задача';

  @override
  String get editEvent => 'Изменить событие';

  @override
  String get eventTitle => 'Название события';

  @override
  String get location => 'Место';

  @override
  String get timeSlot => 'Интервал времени';

  @override
  String get startDateTime => 'Дата и время начала';

  @override
  String get endDateTime => 'Дата и время окончания';

  @override
  String get doesNotRepeat => 'Не повторяется';

  @override
  String get defaultReminder => 'Напоминание по умолчанию';

  @override
  String get guests => 'Гости';

  @override
  String get noGuests => 'Нет гостей';

  @override
  String get attendeeRequired => 'Обязательно';

  @override
  String get attendeeOptional => 'Необязательно';

  @override
  String get meetingSection => 'Встреча';

  @override
  String get addGoogleMeet => 'Добавить Google Meet';

  @override
  String get addTeamsMeeting => 'Добавить встречу Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Онлайн-встреча добавлена';

  @override
  String get requestResponses => 'Запрашивать ответы';

  @override
  String get requestResponsesDescription =>
      'Попросите гостей ответить на приглашение.';

  @override
  String get hideGuestList => 'Скрыть список гостей';

  @override
  String get hideGuestListDescription => 'Гости не видят других приглашённых.';

  @override
  String get allowNewTimeProposals => 'Разрешить новые предложения времени';

  @override
  String get allowNewTimeProposalsDescription =>
      'Гости могут предложить другое время встречи.';

  @override
  String get notifyGuestsTitle => 'Уведомить гостей?';

  @override
  String get notifyGuestsSaveMessage =>
      'На встрече есть гости. Отправить приглашения или обновления события при сохранении?';

  @override
  String get notifyGuestsDeleteMessage =>
      'На встрече есть гости. Отправить отмену при удалении?';

  @override
  String get sendUpdates => 'Отправить обновления';

  @override
  String get sendCancellation => 'Отправить отмену';

  @override
  String get doNotSend => 'Не отправлять';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Сохранить встречу?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft отправит гостям приглашения или обновления события.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Удалить встречу?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft отправит гостям отмену.';

  @override
  String get organizer => 'Организатор';

  @override
  String get yourResponse => 'Ваш ответ';

  @override
  String get guestResponses => 'Ответы гостей';

  @override
  String get respond => 'Ответить';

  @override
  String get acceptInvitation => 'Принять';

  @override
  String get tentativeInvitation => 'Под вопросом';

  @override
  String get declineInvitation => 'Отклонить';

  @override
  String get joinMeeting => 'Присоединиться к встрече';

  @override
  String get responseAccepted => 'Принято';

  @override
  String get responseTentative => 'Под вопросом';

  @override
  String get responseDeclined => 'Отклонено';

  @override
  String get responseNeedsAction => 'Ожидается ответ';

  @override
  String get responseNotResponded => 'Нет ответа';

  @override
  String get responseOrganizer => 'Организатор';

  @override
  String invitationResponseFailed(String error) {
    return 'Не удалось отправить ответ: $error';
  }

  @override
  String get joinMeetingFailed => 'Не удалось открыть ссылку на встречу.';

  @override
  String get description => 'Описание';

  @override
  String get availabilityShowAs => 'Показывать как';

  @override
  String get busy => 'Занят';

  @override
  String get visibility => 'Видимость';

  @override
  String get defaultVisibility => 'Видимость по умолчанию';

  @override
  String get conference => 'Конференция';

  @override
  String get noConference => 'Без конференции';

  @override
  String get providerCalendar => 'Календарь сервиса';

  @override
  String get formatBoldShortLabel => 'Ж';

  @override
  String get formatBoldTooltip => 'Полужирный';

  @override
  String get formatItalicShortLabel => 'К';

  @override
  String get formatItalicTooltip => 'Курсив';

  @override
  String get formatUnderlineShortLabel => 'Ч';

  @override
  String get formatUnderlineTooltip => 'Подчёркнутый';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'За $minutesString минуты',
      many: 'За $minutesString минут',
      few: 'За $minutesString минуты',
      one: 'За $minutesString минуту',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'В момент начала';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'За $hoursString часа',
      many: 'За $hoursString часов',
      few: 'За $hoursString часа',
      one: 'За $hoursString час',
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
      other: 'За $daysString дня',
      many: 'За $daysString дней',
      few: 'За $daysString дня',
      one: 'За $daysString день',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Свободен';

  @override
  String get availabilityTentative => 'Под вопросом';

  @override
  String get availabilityOutOfOffice => 'Нет на рабочем месте';

  @override
  String get availabilityWorkingElsewhere => 'Работа в другом месте';

  @override
  String get visibilityDefault => 'По умолчанию';

  @override
  String get visibilityPublic => 'Общедоступное';

  @override
  String get visibilityPrivate => 'Личное';

  @override
  String get visibilityConfidential => 'Конфиденциальное';

  @override
  String get sensitivityNormal => 'Обычная';

  @override
  String get sensitivityPersonal => 'Личная';

  @override
  String get tasks => 'Задачи';

  @override
  String get allTasks => 'Все задачи';

  @override
  String tasksInList(String title) {
    return 'Задачи в списке «$title»';
  }

  @override
  String get taskLists => 'Списки задач';

  @override
  String get navigation => 'Навигация';

  @override
  String get mainMenu => 'Главное меню';

  @override
  String get keyboardShortcuts => 'Сочетания клавиш';

  @override
  String get shortcutGroupGeneral => 'Общие';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Показать эту справку по сочетаниям клавиш';

  @override
  String get shortcutGroupNavigation => 'Навигация';

  @override
  String get shortcutNextPeriod => 'Следующий период';

  @override
  String get shortcutNextPeriodDescription =>
      'Следующая неделя в представлении недели, следующий месяц в представлении месяца и так далее';

  @override
  String get shortcutPreviousPeriod => 'Предыдущий период';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Предыдущая неделя в представлении недели, предыдущий месяц в представлении месяца и так далее';

  @override
  String get shortcutJumpToToday => 'Перейти к сегодняшнему дню';

  @override
  String get shortcutGroupView => 'Представление';

  @override
  String get shortcutDayView => 'Представление дня';

  @override
  String get shortcutWeekView => 'Представление недели';

  @override
  String get shortcutMonthView => 'Представление месяца';

  @override
  String get shortcutYearView => 'Представление года';

  @override
  String get shortcutAgendaView => 'Расписание';

  @override
  String get shortcutGroupCreateAndEdit => 'Создание и редактирование';

  @override
  String get shortcutSaveItem => 'Сохранить событие или задачу';

  @override
  String get shortcutDeleteItem => 'Удалить событие или задачу';

  @override
  String get shortcutGroupTaskEditing => 'Редактирование задач';

  @override
  String get shortcutCancelEditing => 'Отменить редактирование';

  @override
  String get shortcutCancelEditingDescription =>
      'Выйти из режима редактирования задачи или закрыть сведения о ней';

  @override
  String get aboutBusyMax => 'О приложении BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Календарь и задачи';

  @override
  String get license => 'Лицензия';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Веб-сайт';

  @override
  String get sourceCode => 'Исходный код';

  @override
  String get reportAnIssue => 'Сообщить о проблеме';

  @override
  String get sendFeedback => 'Отправить отзыв';

  @override
  String get feedbackSubmit => 'Отправить';

  @override
  String get feedbackCategory => 'Категория';

  @override
  String get feedbackSelectCategory => 'Выберите категорию';

  @override
  String get feedbackCategoryProblem => 'Проблема или ошибка';

  @override
  String get feedbackCategoryFeature => 'Запрос функции';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Проблема конфиденциальности или безопасности';

  @override
  String get feedbackCategoryUsability => 'Проблема удобства использования';

  @override
  String get feedbackCategoryOther => 'Другое';

  @override
  String get feedbackSubject => 'Тема';

  @override
  String get feedbackDetailedMessage => 'Подробное сообщение';

  @override
  String get feedbackReplyEmail =>
      'Адрес электронной почты для ответа (необязательно)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Включить технические сведения';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Будут добавлены только версия Linux и выбранный язык приложения. Журналы, данные аккаунтов, имена файлов и другие диагностические сведения не добавляются.';

  @override
  String get feedbackCategoryRequired => 'Выберите категорию.';

  @override
  String get feedbackSubjectLengthError =>
      'Тема должна содержать от 3 до 120 символов.';

  @override
  String get feedbackMessageLengthError =>
      'Сообщение должно содержать от 10 до 5 000 символов.';

  @override
  String get feedbackInvalidEmail =>
      'Введите действительный адрес электронной почты.';

  @override
  String get feedbackConnectionError =>
      'Не удалось подключиться к BusyStack. Проверьте подключение и повторите попытку.';

  @override
  String get feedbackTimeoutError =>
      'Время ожидания запроса истекло. Текст отзыва сохранён. Повторите попытку.';

  @override
  String get feedbackRateLimitedError =>
      'Из этой сети было отправлено слишком много отзывов. Подождите и повторите попытку.';

  @override
  String get feedbackRejectedError =>
      'Сервер отклонил отправку. Проверьте поля и повторите попытку.';

  @override
  String get feedbackServerError =>
      'BusyStack сейчас не может принять ваш отзыв. Текст отзыва сохранён. Повторите попытку.';

  @override
  String feedbackSuccess(String id) {
    return 'Отзыв отправлен. Номер: $id';
  }

  @override
  String get toggleSidebar => 'Показать или скрыть боковую панель';

  @override
  String get showSidebar => 'Показать боковую панель';

  @override
  String get hideSidebar => 'Скрыть боковую панель';

  @override
  String get accounts => 'Аккаунты';

  @override
  String get currentAccount => 'Текущий аккаунт';

  @override
  String get switchAccount => 'Сменить аккаунт';

  @override
  String get addGoogleAccount => 'Добавить аккаунт Google';

  @override
  String get addMicrosoftAccount => 'Добавить аккаунт Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Выполнен вход';

  @override
  String get removeAccount => 'Удалить аккаунт…';

  @override
  String get removingAccount => 'Удаление аккаунта…';

  @override
  String get removeAccountDescription =>
      'Остановить синхронизацию и удалить данные этого аккаунта с устройства.';

  @override
  String removeAccountTitle(String account) {
    return 'Удалить $account из BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'С устройства будут удалены кэшированные задачи, календари, события, напоминания и ожидающие автономные изменения. Несинхронизированные изменения будут потеряны. Копии календарей, событий, списков задач и задач у поставщика не удаляются.';

  @override
  String get revokeGoogleAccess =>
      'Также отозвать у BusyMax доступ к этому аккаунту Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Перед повторным подключением аккаунта потребуется снова предоставить доступ.';

  @override
  String get removeAccountAction => 'Удалить аккаунт';

  @override
  String get removeAccountFailed =>
      'Не удалось завершить удаление аккаунта. Повторите попытку.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Аккаунт удалён с этого устройства, но отозвать доступ BusyMax к Google не удалось. Вы можете отозвать доступ в аккаунте Google.';

  @override
  String get newTaskList => 'Новый список задач';

  @override
  String taskListCreateFailed(String error) {
    return 'Не удалось создать список задач: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Не удалось переименовать список задач: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Не удалось удалить список задач: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Войдите, чтобы просмотреть списки задач.';

  @override
  String get noTaskListsSynced => 'Синхронизированных списков задач пока нет.';

  @override
  String get listActions => 'Действия со списком';

  @override
  String get rename => 'Переименовать';

  @override
  String get delete => 'Удалить';

  @override
  String get renameList => 'Переименовать список';

  @override
  String get deleteList => 'Удалить список';

  @override
  String get unshare => 'Отменить общий доступ';

  @override
  String get readOnlyTaskListCannotRename =>
      'Этот список задач доступен только для чтения и не может быть переименован.';

  @override
  String get taskListCannotDelete =>
      'Этот список задач нельзя удалить с текущими разрешениями.';

  @override
  String get builtInMicrosoftList => 'Встроенный';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Встроенные списки Microsoft To Do нельзя переименовывать или удалять.';

  @override
  String deleteListConfirmation(String title) {
    return 'Удалить «$title» из Google Tasks?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Удалить «$title» и все его задачи?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Отменить общий доступ к «$title» для этого аккаунта?';
  }

  @override
  String get deleteEvent => 'Удалить событие';

  @override
  String get title => 'Название';

  @override
  String get create => 'Создать';

  @override
  String get newTask => 'Новая задача';

  @override
  String get clearCompleted => 'Удалить выполненные';

  @override
  String get refreshList => 'Обновить список';

  @override
  String get refreshAll => 'Обновить всё';

  @override
  String get listRefreshed => 'Список обновлён.';

  @override
  String get allTasksRefreshed => 'Все аккаунты обновлены.';

  @override
  String exportedFile(String path) {
    return 'Экспортировано в $path';
  }

  @override
  String exportFailed(String error) {
    return 'Не удалось экспортировать: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Не удалось обновить: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Сначала выберите или создайте список задач.';

  @override
  String get signInToViewTasks => 'Войдите, чтобы просмотреть задачи.';

  @override
  String get noTasks => 'Задач нет.';

  @override
  String get noTasksYet => 'Задач пока нет';

  @override
  String get noTasksYetMessage =>
      'Создайте задачу или обновите аккаунты, чтобы начать.';

  @override
  String get noTasksInList => 'В этом списке нет задач.';

  @override
  String get overdue => 'Просроченные';

  @override
  String get today => 'Сегодня';

  @override
  String get tomorrow => 'Завтра';

  @override
  String get upcoming => 'Предстоящие';

  @override
  String get noDate => 'Без даты';

  @override
  String get completed => 'Выполненные';

  @override
  String duePrefix(String date) {
    return 'Срок: $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date, $time';
  }

  @override
  String get taskDetails => 'Сведения о задаче';

  @override
  String get editTask => 'Изменить задачу';

  @override
  String get noTaskSelected => 'Задача не выбрана.';

  @override
  String get noTaskSelectedHelper =>
      'Выберите задачу, чтобы просмотреть и изменить её сведения.';

  @override
  String get taskUnavailable => 'Задача недоступна.';

  @override
  String get signInToEditTasks => 'Войдите, чтобы изменять задачи.';

  @override
  String get refreshTask => 'Обновить задачу';

  @override
  String get primarySection => 'Основные сведения';

  @override
  String get statusSection => 'Состояние';

  @override
  String get openStatus => 'Открыта';

  @override
  String get doneStatus => 'Выполнено';

  @override
  String get taskStatus => 'Статус';

  @override
  String get taskStatusNone => 'Нет статуса';

  @override
  String get taskStatusNeedsAction => 'Требуется действие';

  @override
  String get taskStatusInProcess => 'Выполняется';

  @override
  String get taskStatusCompleted => 'Завершена';

  @override
  String get taskStatusCancelled => 'Отменена';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Выполнено на $percentString%';
  }

  @override
  String get completionDate => 'Дата выполнения';

  @override
  String get priority => 'Приоритет';

  @override
  String get priorityNone => 'Без приоритета';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Приоритет $priorityString · высокий';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Приоритет $priorityString · средний';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Приоритет $priorityString · низкий';
  }

  @override
  String get taskUrl => 'URL задачи';

  @override
  String get invalidTaskUrl => 'Введите абсолютный URL вместе со схемой.';

  @override
  String get classification => 'Классификация';

  @override
  String get classificationPublic =>
      'При общем доступе показывать задачу полностью';

  @override
  String get classificationConfidential =>
      'При общем доступе показывать только занятость';

  @override
  String get classificationPrivate => 'При общем доступе скрывать эту задачу';

  @override
  String get pinTask => 'Закрепить задачу';

  @override
  String get notes => 'Заметки';

  @override
  String get dueDate => 'Срок';

  @override
  String get clearDueDate => 'Удалить срок выполнения';

  @override
  String get dueTime => 'Время выполнения';

  @override
  String get startDate => 'Дата начала';

  @override
  String get startTime => 'Время начала';

  @override
  String get endDate => 'Дата окончания';

  @override
  String get endTime => 'Время окончания';

  @override
  String get reminderDate => 'Дата напоминания';

  @override
  String get reminderTime => 'Время напоминания';

  @override
  String get reminder => 'Напоминание';

  @override
  String get addReminder => 'Добавить напоминание';

  @override
  String get reminders => 'Напоминания';

  @override
  String get noReminders => 'Нет напоминаний';

  @override
  String get editReminder => 'Изменить напоминание';

  @override
  String get beforeTaskStarts => 'До начала задачи';

  @override
  String get beforeTaskDue => 'До срока выполнения задачи';

  @override
  String get afterTaskStarts => 'После начала задачи';

  @override
  String get afterTaskDue => 'После срока выполнения задачи';

  @override
  String get relativeToTaskStart => 'Относительно даты начала задачи';

  @override
  String get relativeToTaskDue => 'Относительно срока выполнения задачи';

  @override
  String get reminderTimeOfDay => 'Время суток';

  @override
  String get absoluteReminder => 'В указанную дату и время';

  @override
  String get reminderAmount => 'Количество';

  @override
  String get reminderUnit => 'Единица';

  @override
  String get reminderUnitSeconds => 'Секунды';

  @override
  String get reminderUnitMinutes => 'Минуты';

  @override
  String get reminderUnitHours => 'Часы';

  @override
  String get reminderUnitDays => 'Дни';

  @override
  String get reminderUnitWeeks => 'Недели';

  @override
  String get reminderAtTaskStart => 'В момент начала задачи';

  @override
  String get reminderAtTaskDue => 'В момент наступления срока задачи';

  @override
  String get unsupportedReminder =>
      'Тип этого напоминания сохраняется, но его время нельзя изменить.';

  @override
  String get relatedRemindersTitle => 'Сохранить связанные напоминания?';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'На эту дату приходится $countString связанных напоминаний. Сохранить их текущие дату и время?';
  }

  @override
  String get discardRelatedReminders => 'Удалить напоминания';

  @override
  String get keepRelatedReminders => 'Сохранить напоминания';

  @override
  String get addGuest => 'Добавить гостя';

  @override
  String get addGuestEmail => 'Добавить адрес электронной почты гостя';

  @override
  String get removeReminder => 'Удалить напоминание';

  @override
  String get off => 'Выкл.';

  @override
  String get repeat => 'Повтор';

  @override
  String get repeatNone => 'Не повторять';

  @override
  String get noneValue => 'Нет';

  @override
  String get repeatDaily => 'Ежедневно';

  @override
  String get repeatWeekly => 'Еженедельно';

  @override
  String get repeatMonthly => 'Ежемесячно';

  @override
  String get repeatYearly => 'Ежегодно';

  @override
  String get repeatEvery => 'Интервал';

  @override
  String get repeatOn => 'Повторять в';

  @override
  String get repeatEnd => 'Завершить повтор';

  @override
  String get repeatNever => 'Никогда';

  @override
  String get repeatUntil => 'В указанную дату';

  @override
  String get repeatAfter => 'После указанного числа повторений';

  @override
  String get repeatCount => 'Число повторений';

  @override
  String get repeatDayOfMonth => 'Дни месяца';

  @override
  String get repeatMonths => 'Месяцы';

  @override
  String get repeatOrdinal => 'Порядок дня недели';

  @override
  String get repeatSpecificDays => 'Определённые дни';

  @override
  String get repeatFirst => 'Первый';

  @override
  String get repeatSecond => 'Второй';

  @override
  String get repeatThird => 'Третий';

  @override
  String get repeatFourth => 'Четвёртый';

  @override
  String get repeatFifth => 'Пятый';

  @override
  String get repeatSecondToLast => 'Предпоследний';

  @override
  String get repeatLast => 'Последний';

  @override
  String get repeatAnyDay => 'День';

  @override
  String get repeatWeekday => 'Будний день';

  @override
  String get repeatWeekendDay => 'Выходной день';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'понедельник',
      'TU': 'вторник',
      'WE': 'среду',
      'TH': 'четверг',
      'FR': 'пятницу',
      'SA': 'субботу',
      'SU': 'воскресенье',
      'day': 'день',
      'weekday': 'будний день',
      'weekend': 'выходной день',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Каждые $countString дн.';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Каждые $countString нед.';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Каждые $countString мес.';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Каждые $countString г.';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'по $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '$days числа месяца';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'в первый $days',
      'second': 'во второй $days',
      'third': 'в третий $days',
      'fourth': 'в четвёртый $days',
      'fifth': 'в пятый $days',
      'secondToLast': 'в предпоследний $days',
      'last': 'в последний $days',
      'other': 'в $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'в месяцы $months';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString раза',
      many: '$countString раз',
      few: '$countString раза',
      one: '$countString раз',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'до $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Это правило повторения использует параметры, которые этот редактор не изменяет.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Это повторение нельзя использовать с $provider.';
  }

  @override
  String get importance => 'Важность';

  @override
  String get importanceLow => 'Низкая';

  @override
  String get importanceNormal => 'Обычная';

  @override
  String get importanceHigh => 'Высокая';

  @override
  String get categories => 'Категории';

  @override
  String get scheduleSection => 'Расписание';

  @override
  String get dueGroup => 'Срок';

  @override
  String get startGroup => 'Начало';

  @override
  String get reminderGroup => 'Напоминание';

  @override
  String get organizationSection => 'Организация';

  @override
  String get actionsSection => 'Действия';

  @override
  String get advancedSection => 'Дополнительно';

  @override
  String get addCategory => 'Добавить категорию';

  @override
  String get list => 'Список';

  @override
  String get microsoftMoveUnsupported =>
      'В этой версии перенос между списками для аккаунтов Microsoft To Do не поддерживается.';

  @override
  String get createSubtask => 'Создать подзадачу';

  @override
  String get subtasks => 'Подзадачи';

  @override
  String get duplicateTask => 'Дублировать задачу';

  @override
  String get taskDuplicated => 'Задача продублирована.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Не удалось продублировать задачу: $error';
  }

  @override
  String get hideSubtasks => 'Скрыть подзадачи';

  @override
  String get hideClosedSubtasks => 'Скрыть закрытые подзадачи';

  @override
  String get moveToTop => 'Переместить в самый верх';

  @override
  String get deleteTask => 'Удалить задачу';

  @override
  String get newSubtask => 'Новая подзадача';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Удалить «$title»?';
  }

  @override
  String get metadata => 'Метаданные';

  @override
  String get id => 'Идентификатор';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Обновлено';

  @override
  String get parent => 'Родительская задача';

  @override
  String get position => 'Позиция';

  @override
  String get webLink => 'Веб-ссылка';

  @override
  String get assignment => 'Назначение';

  @override
  String get localState => 'Локальное состояние';

  @override
  String get pendingSync => 'Ожидает синхронизации';

  @override
  String get synced => 'Синхронизировано';

  @override
  String get account => 'Аккаунт';

  @override
  String get sync => 'Синхронизация';

  @override
  String get forceFullResync => 'Принудительная полная синхронизация';

  @override
  String get forceFullResyncDescription =>
      'Полностью загружает заново данные всех подключённых аккаунтов. Используйте эту функцию только для устранения проблем с синхронизацией.';

  @override
  String get runInBackgroundWhenClosed =>
      'Продолжать работу после закрытия окна';

  @override
  String get showTrayIcon => 'Показывать значок в области уведомлений';

  @override
  String get startMinimizedToTray =>
      'Запускать свёрнутым в область уведомлений';

  @override
  String get launchAtLogin => 'Запускать при входе';

  @override
  String get launchAtLoginDescription =>
      'Запускайте BusyMax в фоновом режиме, чтобы напоминания работали после входа в систему.';

  @override
  String get launchAtLoginFailed =>
      'Не удалось изменить настройку запуска при входе.';

  @override
  String get requiresTrayIcon => 'Требуется значок в области уведомлений.';

  @override
  String get syncComplete => 'Синхронизация завершена.';

  @override
  String syncFailed(String error) {
    return 'Синхронизация не удалась: $error';
  }

  @override
  String get notifySyncFailures => 'Уведомлять об ошибках синхронизации';

  @override
  String get notifyConflicts => 'Уведомлять о конфликтах';

  @override
  String get notifyDueToday => 'Уведомлять о задачах на сегодня';

  @override
  String get eventReminders => 'Напоминания о событиях';

  @override
  String get onState => 'Вкл.';

  @override
  String get taskReminders => 'Напоминания о задачах';

  @override
  String get notificationDetailLevel => 'Содержимое уведомлений';

  @override
  String get notificationDetailPrivate => 'Скрывать подробности';

  @override
  String get notificationDetailNormal => 'Показывать подробности';

  @override
  String get quietHours => 'Период без уведомлений';

  @override
  String get quietHoursDescription => 'Не показывать уведомления в это время.';

  @override
  String get quietHoursStart => 'Начало периода';

  @override
  String get quietHoursEnd => 'Конец периода';

  @override
  String get notifications => 'Уведомления';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get settingsSystem => 'Система';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeFamily => 'Семейство тем';

  @override
  String get themeFamilyYaru => 'Стандартная тема Ubuntu (Yaru)';

  @override
  String get localization => 'Язык';

  @override
  String get currentLocale => 'Язык приложения';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get redactTaskContentInDiagnostics =>
      'Скрывать содержимое задач в диагностике';

  @override
  String get developerDiagnostics => 'Диагностика для разработчиков';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get apiInspectorDisabled => 'Показать инспектор API';

  @override
  String get googleTasksApi => 'API Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Версия Discovery: $revision';
  }

  @override
  String get implementedMethods => 'Реализованные методы';

  @override
  String get supportsTasksScopes =>
      'Поддерживает области разрешений tasks и tasks.readonly';

  @override
  String get requiresTasksScope => 'Требуется область разрешений tasks';

  @override
  String get blockedPendingOperations => 'Заблокированные операции';

  @override
  String get signInToInspectPendingOperations =>
      'Войдите, чтобы просмотреть ожидающие операции.';

  @override
  String get noBlockedPendingOperations => 'Заблокированных операций нет.';

  @override
  String get operationActions => 'Действия с операцией';

  @override
  String pendingOpListId(String id) {
    return 'список=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'задача=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'попытки=$countString';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get discard => 'Отменить';

  @override
  String get discardChangesAction => 'Не сохранять';

  @override
  String get discardChanges => 'Не сохранять изменения?';

  @override
  String get discardChangesConfirmation =>
      'Несохранённые изменения этой задачи будут потеряны.';

  @override
  String get retryCompleted => 'Повторная попытка завершена.';

  @override
  String get discardPendingOperation => 'Удалить заблокированную операцию?';

  @override
  String get discardPendingOperationConfirmation =>
      'Заблокированная локальная операция будет удалена. При следующей синхронизации данные будут заново загружены из Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Заблокированная операция удалена.';

  @override
  String get syncFailureNotificationTitle => 'Сбой синхронизации BusyMax';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Сбой фоновой синхронизации. $message';
  }

  @override
  String get conflictNotificationTitle => 'Конфликт синхронизации BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Ожидающее локальное изменение заблокировано. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Задачи на сегодня';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сегодня нужно выполнить $countString задачи.',
      many: 'Сегодня нужно выполнить $countString задач.',
      few: 'Сегодня нужно выполнить $countString задачи.',
      one: 'Сегодня нужно выполнить $countString задачу.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Напоминание о событии';

  @override
  String get taskReminderNotificationTitle => 'Напоминание о задаче';

  @override
  String get eventReminderNotificationBody => 'Событие скоро начнётся.';

  @override
  String get taskReminderNotificationBody =>
      'Срок выполнения задачи скоро наступит.';

  @override
  String get notificationOpenAction => 'Открыть';

  @override
  String get notificationSnoozeAction => 'Отложить на 10 минут';

  @override
  String get notificationDismissAction => 'Закрыть';

  @override
  String get notificationDetailsHidden =>
      'Сведения скрыты настройками конфиденциальности.';

  @override
  String get previousMonth => 'Предыдущий месяц';

  @override
  String get nextMonth => 'Следующий месяц';

  @override
  String get openMonthView => 'Открыть представление месяца';

  @override
  String get previousYear => 'Предыдущий год';

  @override
  String get nextYear => 'Следующий год';

  @override
  String get openYearView => 'Открыть представление года';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Неделя $numberString';
  }

  @override
  String get resizeAllDayPanel => 'Изменить размер панели «Весь день»';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString записи',
      many: '$countString записей',
      few: '$countString записи',
      one: '$countString запись',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Этот календарь доступен только для чтения.';

  @override
  String get selectTimeZone => 'Выберите часовой пояс';

  @override
  String get searchLocations => 'Поиск мест';

  @override
  String get noLocationsFound => 'Места не найдены';

  @override
  String get requiredField => 'Это поле обязательно.';

  @override
  String get providerConnectionDescription =>
      'Подключите календари и задачи одного из следующих поставщиков.';

  @override
  String get appleICloudProvider => 'Календарь Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Задачи Nextcloud';

  @override
  String get addAppleICloudAccount => 'Добавить аккаунт Календаря Apple iCloud';

  @override
  String get addNextcloudAccount => 'Добавить аккаунт Nextcloud';

  @override
  String get waitingForAppleICloud => 'Подключение к Apple iCloud…';

  @override
  String get waitingForNextcloud => 'Ожидание авторизации Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Подключить Календарь Apple iCloud';

  @override
  String get appleAccountEmail => 'Электронная почта аккаунта Apple';

  @override
  String get appleAppSpecificPassword => 'Пароль для приложения';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Создайте пароль для приложения после включения двухфакторной аутентификации аккаунта Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Сброс пароля аккаунта Apple отзывает пароли для приложений.';

  @override
  String get connectNextcloudTitle => 'Подключить Nextcloud';

  @override
  String get nextcloudServerUrl => 'Сервер Nextcloud или адрес CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Введите URL сервера Nextcloud или вставьте основной адрес CalDAV, скопированный из Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax откроет браузер. Разрешите доступ и вернитесь в BusyMax.';

  @override
  String get connectAccountAction => 'Подключить';

  @override
  String get cancelAccountConnection => 'Отменить подключение';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'Аккаунт удалён локально, но пароль приложения Nextcloud не удалось отозвать.';

  @override
  String get davCachedOfflineNotice =>
      'Данные календаря и задач кэшируются локально для работы без подключения.';

  @override
  String get davReauthenticationRequired =>
      'Подключите аккаунт заново, чтобы возобновить синхронизацию.';

  @override
  String get davTemporarilyUnavailable => 'Этот аккаунт временно недоступен.';

  @override
  String get davPermissionChanged =>
      'Разрешения сервера изменились. Ожидающие изменения приостановлены.';

  @override
  String get davUnsupportedServer =>
      'Этот сервер или профиль поставщика не поддерживается.';

  @override
  String get collectionSettings => 'Календари и списки задач';

  @override
  String get calendarContent => 'События календаря';

  @override
  String get taskContent => 'Задачи';

  @override
  String get readOnlySharedCollection => 'Только чтение';

  @override
  String get pendingLocally => 'Ожидает локально';

  @override
  String get conflictBlocked => 'Заблокировано из-за конфликта';

  @override
  String get authenticationBlocked => 'Заблокировано до повторного подключения';

  @override
  String get operationFailed => 'Операция не выполнена';

  @override
  String get keepServerVersion => 'Сохранить версию сервера';

  @override
  String get reapplyLocalChange =>
      'Проверить и повторно применить локальное изменение';

  @override
  String get duplicateLocalItem => 'Дублировать как новый элемент';

  @override
  String get davConnectionState => 'Состояние подключения';

  @override
  String get davConnected => 'Подключено';

  @override
  String get davConnecting => 'Подключение…';

  @override
  String get davSignedOut => 'Выполнен выход';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Последняя успешная синхронизация: $time';
  }

  @override
  String get davNeverSynced => 'Ещё не синхронизировано';

  @override
  String get refreshCollections => 'Обновить календари и списки задач';

  @override
  String nextcloudServerHost(String host) {
    return 'Сервер: $host';
  }

  @override
  String get collectionSupportsEvents => 'Календарь событий';

  @override
  String get collectionSupportsTasks => 'Список задач';

  @override
  String get collectionSupportsEventsAndTasks => 'События и задачи';

  @override
  String get writableCollection => 'Доступно для записи';

  @override
  String get sharedCollection => 'Общий доступ';

  @override
  String collectionLastSynced(String time) {
    return 'Последняя синхронизация: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Проблема синхронизации: $code';
  }

  @override
  String get syncConflicts => 'Конфликты синхронизации';

  @override
  String remoteChangedAt(String time) {
    return 'Изменено на сервере: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Локальное изменение: $summary';
  }

  @override
  String get conflictResolutionFailed => 'Не удалось разрешить конфликт.';

  @override
  String get recurringEventScope => 'Область повторяющегося события';

  @override
  String get entireSeries => 'Вся серия';

  @override
  String get singleOccurrence => 'Это событие';

  @override
  String get thisAndFollowingEvents => 'Это и последующие события';

  @override
  String get thisAndFutureUnavailable => 'Не поддерживается этим поставщиком.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Это и последующие события нельзя безопасно переместить. Выберите это событие или всю серию.';

  @override
  String get entireSeriesMoveUnavailable =>
      'Правило повтора недоступно локально. Переместите только это событие.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Скопировать событие и удалить оригинал?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax не может напрямую переместить это событие из $source в $destination. Сначала будет создана копия, а оригинал будет удалён только после успешного копирования. Идентификаторы события изменятся; статусы ответов участников могут быть сброшены, а приглашения или отмены — отправлены; ссылки на конференции, вложения, напоминания, поля поставщика и исключения повтора могут не сохраниться.';
  }

  @override
  String get copyAndDelete => 'Скопировать и удалить';

  @override
  String get chooseRecurringEventScope =>
      'Выберите, применять ли это изменение ко всей серии, только к этому событию или к этому и последующим событиям.';

  @override
  String get taskDueBeforeStart => 'Срок не может быть раньше начала.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Укажите время начала и срока или сделайте задачу на весь день.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Удалить «$title»?';
  }

  @override
  String get setCustomCalendarName => 'Задать своё название';

  @override
  String get setAction => 'Задать';

  @override
  String get removeFromMyCalendars => 'Удалить из моих календарей';

  @override
  String get removeAction => 'Удалить';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Удалить «$title» из вашего списка Google Календаря? Общий календарь и его события удалены не будут.';
  }

  @override
  String get calendarCannotRemove =>
      'Этот календарь нельзя удалить или убрать из аккаунта.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Дождитесь синхронизации ожидающих изменений этого календаря перед удалением или отключением.';

  @override
  String get calendarSubscriptions => 'Подписки на календари';

  @override
  String get calendarSubscriptionsDescription =>
      'Добавляйте календари только для чтения, обновляемые по защищённому URL WebCal.';

  @override
  String get addCalendarSubscription => 'Добавить подписку на календарь';

  @override
  String get subscriptionName => 'Локальное имя';

  @override
  String get subscriptionUrl => 'URL подписки';

  @override
  String get subscriptionUrlHelp =>
      'Введите HTTPS- или webcal-URL. BusyMax хранит полный URL в защищённом хранилище.';

  @override
  String get subscriptionUrlInvalid =>
      'Введите действительный HTTPS- или webcal-URL без данных пользователя или фрагмента.';

  @override
  String get subscriptionColor => 'Локальный цвет';

  @override
  String get subscriptionColorHelp =>
      'Используйте шестизначный цвет, например #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Введите шестизначный шестнадцатеричный цвет.';

  @override
  String get subscriptionRefreshMode => 'Частота обновления';

  @override
  String get subscriptionAutomatic => 'Автоматически';

  @override
  String get subscriptionHourly => 'Ежечасно';

  @override
  String get subscriptionSixHours => 'Каждые шесть часов';

  @override
  String get subscriptionDaily => 'Ежедневно';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Источник: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Введите действительный URL для просмотра безопасного источника.';

  @override
  String get subscriptionReadOnly => 'Подписка только для чтения';

  @override
  String get subscriptionNeverRefreshed => 'Ещё не обновлялось';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Последнее успешное обновление: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Следующее обновление: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Актуально';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Проблема обновления: $code';
  }

  @override
  String get refreshNow => 'Обновить сейчас';

  @override
  String get unsubscribe => 'Отменить подписку';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Отменить подписку на «$name»?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Локальная подписка и кэшированные события будут удалены. Опубликованный календарь не изменится.';

  @override
  String get addSubscriptionAction => 'Добавить подписку';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Ошибка подписки на календарь: $error';
  }

  @override
  String get subscriptions => 'Подписки';

  @override
  String get calendarImport => 'Импорт календаря';

  @override
  String get calendarImportDescription =>
      'Выберите файл, просмотрите его события, а затем выберите доступный для записи календарь, который должен их принять.';

  @override
  String get importIcsFile => 'Импортировать файл .ics';

  @override
  String get importIcsPreview => 'Импортировать события календаря';

  @override
  String importEventsFound(int count) {
    return 'Наборы импортируемых событий: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Недопустимые события: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Намеренно пропущено: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Нет доступного календаря назначения с правом записи.';

  @override
  String get importDestinationCalendar => 'Календарь назначения';

  @override
  String get importIcsConfirm => 'Импортировать события';

  @override
  String get importIcsComplete => 'Импорт завершён';

  @override
  String importQueued(int count) {
    return 'Импортировано или поставлено в очередь: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Пропущено дубликатов: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Неподдерживаемые наборы повторений: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Не удалось импортировать файл календаря: $error';
  }

  @override
  String get networkOffline => 'Нет подключения';

  @override
  String get networkOfflineDescription =>
      'Изменения будут синхронизированы после восстановления подключения.';

  @override
  String get networkOfflineTryAgain =>
      'Нет подключения к сети. Подключитесь к Интернету и повторите попытку.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'в дни месяца $days';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day-го';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first и $second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first и $second';
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
    return '$first и $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first и $second';
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
    return '$frequency: $month, $day числа';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency: $month, $days числа';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency: $months, $day числа';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency: $months, $days числа';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'в первый $days',
      'second': 'во второй $days',
      'third': 'в третий $days',
      'fourth': 'в четвёртый $days',
      'fifth': 'в пятый $days',
      'secondToLast': 'в предпоследний $days',
      'last': 'в последний $days',
      'other': 'в $days',
    });
    return '$frequency: $month, $_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'в первый $days',
      'second': 'во второй $days',
      'third': 'в третий $days',
      'fourth': 'в четвёртый $days',
      'fifth': 'в пятый $days',
      'secondToLast': 'в предпоследний $days',
      'last': 'в последний $days',
      'other': 'в $days',
    });
    return '$frequency: $months, $_temp0';
  }
}

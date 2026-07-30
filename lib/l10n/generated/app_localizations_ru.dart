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
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Подключите аккаунты Google и Microsoft, чтобы синхронизировать календари и задачи.';

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
      'Добавьте все аккаунты Google и Microsoft, которые хотите использовать. BusyMax синхронизирует календари, события, списки задач и задачи из каждого аккаунта.';

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
    return '+ ещё $count';
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
  String get trayAgendaLoading => 'Загрузка расписания...';

  @override
  String get trayAgendaSignInRequired =>
      'Войдите, чтобы просмотреть расписание.';

  @override
  String get trayAgendaNoSources => 'Нет видимых календарей или списков задач.';

  @override
  String get trayAgendaOpenBusyMax => 'Открыть приложение';

  @override
  String get trayAgendaRefresh => 'Обновить';

  @override
  String get trayAgendaError => 'Расписание недоступно';

  @override
  String get compactAgendaTitle => 'Расписание';

  @override
  String get compactAgendaSubtitle => 'Предстоящие';

  @override
  String get compactAgendaOverdue => 'Просроченные';

  @override
  String get compactAgendaClear => 'На ближайшее время ничего нет';

  @override
  String get compactAgendaOpenBusyMax => 'Открыть BusyMax';

  @override
  String get compactAgendaHide => 'Скрыть';

  @override
  String get compactAgendaNewTask => 'Новая задача';

  @override
  String get compactAgendaRetry => 'Повторить';

  @override
  String get compactAgendaRefresh => 'Обновить';

  @override
  String get compactAgendaAllDay => 'Весь день';

  @override
  String get compactAgendaDueToday => 'Срок — сегодня';

  @override
  String get compactAgendaDueTomorrow => 'Срок — завтра';

  @override
  String compactAgendaDueOn(String date) {
    return 'Срок — $date';
  }

  @override
  String get compactAgendaMoreOverdue => 'Загрузить ещё просроченные задачи';

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
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'За $minutes минуты',
      many: 'За $minutes минут',
      few: 'За $minutes минуты',
      one: 'За $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'В момент начала';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'За $hours часа',
      many: 'За $hours часов',
      few: 'За $hours часа',
      one: 'За $hours час',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'За $days дня',
      many: 'За $days дней',
      few: 'За $days дня',
      one: 'За $days день',
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
  String get shortcutGroupCompactAgenda => 'Компактное расписание';

  @override
  String get shortcutRefreshCompactAgendaDescription =>
      'Обновить окно компактного расписания';

  @override
  String get shortcutHideCompactAgendaDescription =>
      'Скрыть окно компактного расписания';

  @override
  String get aboutBusyMax => 'О приложении BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Календарь и задачи';

  @override
  String get website => 'Веб-сайт';

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
      'С этого устройства будут удалены кэшированные задачи, календари, события, напоминания и локальные изменения, ожидающие синхронизации. Несинхронизированные изменения будут потеряны. В Google и Microsoft ничего не будет удалено.';

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
  String get newList => 'Новый список';

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
  String get builtInMicrosoftList => 'Встроенный';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Встроенные списки Microsoft To Do нельзя переименовывать или удалять.';

  @override
  String deleteListConfirmation(String title) {
    return 'Удалить «$title» из Google Tasks?';
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
  String get doneStatus => 'Выполнена';

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
  String get moveToTop => 'Переместить в самый верх';

  @override
  String get deleteTask => 'Удалить задачу';

  @override
  String get newSubtask => 'Новая подзадача';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Удалить «$title» из Google Tasks?';
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
  String get manualFullSync => 'Полная синхронизация вручную';

  @override
  String get runInBackgroundWhenClosed =>
      'Продолжать работу после закрытия окна';

  @override
  String get showTrayIcon => 'Показывать значок в области уведомлений';

  @override
  String get startMinimizedToTray =>
      'Запускать свёрнутым в область уведомлений';

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
    return 'попытки=$count';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get discard => 'Отменить';

  @override
  String get discardChanges => 'Отменить изменения?';

  @override
  String get discardChangesConfirmation =>
      'Несохранённые изменения этой задачи будут отменены.';

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
    return 'Локальное изменение не удалось синхронизировать. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Задачи на сегодня';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сегодня нужно выполнить $count задачи.',
      many: 'Сегодня нужно выполнить $count задач.',
      few: 'Сегодня нужно выполнить $count задачи.',
      one: 'Сегодня нужно выполнить $count задачу.',
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
    return 'Неделя $number';
  }

  @override
  String get resizeAllDayPanel => 'Изменить размер панели «Весь день»';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Этот календарь доступен только для чтения.';

  @override
  String get selectTimeZone => 'Выберите часовой пояс';

  @override
  String get searchLocations => 'Поиск города';

  @override
  String get noLocationsFound => 'Ничего не найдено';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Удалить «$title»?';
  }
}

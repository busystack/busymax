// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Ligue as contas Google, Microsoft, Calendário Apple iCloud ou Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'No ecrã de autorizações da Google, selecione as autorizações do Calendário e das Tarefas.';

  @override
  String get googlePermissionsRequiredRetry =>
      'As autorizações do Calendário Google e do Google Tasks são necessárias. Tente novamente e selecione ambas as caixas.';

  @override
  String get finishSetup => 'Concluir configuração';

  @override
  String get continueSetup => 'Continuar';

  @override
  String get onboardingSetupTitle => 'Configurar o BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Ligar contas';

  @override
  String get onboardingAccountsStepDescription =>
      'Adicione todas as contas que pretende utilizar. O BusyMax sincroniza calendários, eventos, listas de tarefas e tarefas suportados de cada conta.';

  @override
  String get onboardingPreferencesStepTitle => 'Escolher definições do sistema';

  @override
  String get onboardingPreferencesStepDescription =>
      'Configure o comportamento da aplicação no ambiente de trabalho, os lembretes, o nível de detalhe das notificações e o aspeto antes de abrir a agenda.';

  @override
  String get signInWithGoogle => 'Iniciar sessão com a Google';

  @override
  String get signInWithMicrosoft => 'Iniciar sessão com a Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Este fornecedor não está configurado.';

  @override
  String get waitingForGoogleSignIn =>
      'A aguardar o início de sessão da Google...';

  @override
  String get waitingForMicrosoftSignIn =>
      'A aguardar o início de sessão da Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'O início de sessão da Microsoft não está configurado. Defina MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Fechar';

  @override
  String get exit => 'Sair';

  @override
  String get options => 'Opções';

  @override
  String get hide => 'Ocultar';

  @override
  String get show => 'Mostrar';

  @override
  String get export => 'Exportar';

  @override
  String get save => 'Guardar';

  @override
  String get settings => 'Definições';

  @override
  String get all => 'Tudo';

  @override
  String get calendarEvents => 'Eventos';

  @override
  String get calendarTasks => 'Tarefas';

  @override
  String get calendar => 'Calendário';

  @override
  String get calendars => 'Calendários';

  @override
  String get newCalendar => 'Novo calendário';

  @override
  String get calendarColor => 'Cor do calendário';

  @override
  String calendarColorOption(int number) {
    return 'Cor $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Este fornecedor não suporta a gestão de calendários no BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'O calendário principal não pode ser eliminado.';

  @override
  String calendarCreateFailed(String error) {
    return 'Não foi possível criar o calendário: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'O calendário foi criado, mas o BusyMax não conseguiu atualizar a conta. Será apresentado após a próxima sincronização.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Não foi possível atualizar o calendário: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Não foi possível eliminar o calendário: $error';
  }

  @override
  String get newEvent => 'Novo evento';

  @override
  String get refreshCalendar => 'Atualizar calendário';

  @override
  String get openInProvider => 'Abrir no serviço';

  @override
  String get hideFromSchedule => 'Ocultar da agenda';

  @override
  String get showInSchedule => 'Mostrar na agenda';

  @override
  String get noCalendarsSynced => 'Ainda não há calendários sincronizados.';

  @override
  String get allDay => 'Todo o dia';

  @override
  String moreItems(int count) {
    return '+$count mais';
  }

  @override
  String get noEventsOrTasks => 'Sem eventos ou tarefas';

  @override
  String get scheduleLoading => 'A carregar agenda...';

  @override
  String get scheduleUnavailable => 'Agenda indisponível';

  @override
  String get scheduleNoSources =>
      'Sem calendários ou listas de tarefas visíveis';

  @override
  String get scheduleNoSourcesDescription =>
      'Escolha o que pretende mostrar nas Definições e atualize a agenda.';

  @override
  String get scheduleSignInRequired => 'Ligar uma conta';

  @override
  String get scheduleSignInDescription =>
      'Inicie sessão para sincronizar calendários e tarefas.';

  @override
  String get scheduleNoSearchResults =>
      'Nenhum evento ou tarefa correspondente';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Experimente outra pesquisa ou limpe os filtros atuais.';

  @override
  String get refresh => 'Atualizar';

  @override
  String get trayOpenBusyMax => 'Abrir o BusyMax';

  @override
  String get trayShowBusyMax => 'Mostrar o BusyMax';

  @override
  String get trayNewEvent => 'Novo evento…';

  @override
  String get trayNewTask => 'Nova tarefa…';

  @override
  String get trayToday => 'Hoje';

  @override
  String get trayAllDay => 'Todo o dia';

  @override
  String get trayNow => 'Agora';

  @override
  String get trayCalendarEvent => 'Evento do calendário';

  @override
  String get trayUntitledEvent => 'Evento sem título';

  @override
  String get trayNothingElseToday => 'Nada mais hoje';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas terminam hoje',
      one: '1 tarefa termina hoje',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Abrir a agenda de hoje';

  @override
  String get traySyncNow => 'Sincronizar agora';

  @override
  String get traySyncing => 'A sincronizar…';

  @override
  String get trayNotConnected => 'Não ligado';

  @override
  String get trayNotYetSynced => 'Ainda não sincronizado';

  @override
  String get trayLastSyncedJustNow => 'Sincronizado agora mesmo';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado há $count minutos',
      one: 'Sincronizado há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado há $count horas',
      one: 'Sincronizado há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado há $count dias',
      one: 'Sincronizado há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Definições';

  @override
  String get trayQuitBusyMax => 'Sair do BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Carregar mais tarefas em atraso';

  @override
  String get agendaLoadMoreNoDate => 'Carregar mais tarefas sem data';

  @override
  String get viewDay => 'Dia';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewMonth => 'Mês';

  @override
  String get viewYear => 'Ano';

  @override
  String get viewAgenda => 'Vista de agenda';

  @override
  String get scheduleSettings => 'Agenda';

  @override
  String get scheduleDisplaySettings => 'Apresentação da agenda';

  @override
  String get scheduleDisplayHoursDescription =>
      'As vistas de dia e semana mostram inicialmente este intervalo horário. Os itens anteriores ou posteriores alargam-no quando necessário.';

  @override
  String get scheduleDayStartsAt => 'O dia começa às';

  @override
  String get scheduleDayEndsAt => 'O dia termina às';

  @override
  String get sourceCalendar => 'Calendário';

  @override
  String get sourceTaskList => 'Lista de tarefas';

  @override
  String get createChoiceTitle => 'Criar';

  @override
  String get createEventAtTime => 'Evento';

  @override
  String get createTaskAtDate => 'Tarefa';

  @override
  String get editEvent => 'Editar evento';

  @override
  String get eventTitle => 'Título do evento';

  @override
  String get location => 'Local';

  @override
  String get timeSlot => 'Intervalo de tempo';

  @override
  String get startDateTime => 'Data e hora de início';

  @override
  String get endDateTime => 'Data e hora de fim';

  @override
  String get doesNotRepeat => 'Não se repete';

  @override
  String get defaultReminder => 'Lembrete predefinido';

  @override
  String get guests => 'Convidados';

  @override
  String get noGuests => 'Sem convidados';

  @override
  String get attendeeRequired => 'Obrigatório';

  @override
  String get attendeeOptional => 'Opcional';

  @override
  String get meetingSection => 'Reunião';

  @override
  String get addGoogleMeet => 'Adicionar o Google Meet';

  @override
  String get addTeamsMeeting => 'Adicionar reunião do Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Reunião online adicionada';

  @override
  String get requestResponses => 'Pedir respostas';

  @override
  String get requestResponsesDescription =>
      'Peça aos convidados que respondam ao convite.';

  @override
  String get hideGuestList => 'Ocultar lista de convidados';

  @override
  String get hideGuestListDescription =>
      'Os convidados não podem ver quem mais foi convidado.';

  @override
  String get allowNewTimeProposals => 'Permitir novas propostas de horário';

  @override
  String get allowNewTimeProposalsDescription =>
      'Os convidados podem sugerir uma hora diferente para a reunião.';

  @override
  String get notifyGuestsTitle => 'Notificar convidados?';

  @override
  String get notifyGuestsSaveMessage =>
      'Esta reunião tem convidados. Enviar convites ou atualizações do evento ao guardá-la?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Esta reunião tem convidados. Enviar um cancelamento ao eliminá-la?';

  @override
  String get sendUpdates => 'Enviar atualizações';

  @override
  String get sendCancellation => 'Enviar cancelamento';

  @override
  String get doNotSend => 'Não enviar';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Guardar reunião?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'A Microsoft enviará convites ou atualizações do evento aos convidados.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Eliminar reunião?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'A Microsoft enviará um cancelamento aos convidados.';

  @override
  String get organizer => 'Organizador';

  @override
  String get yourResponse => 'A sua resposta';

  @override
  String get guestResponses => 'Respostas dos convidados';

  @override
  String get respond => 'Responder';

  @override
  String get acceptInvitation => 'Aceitar';

  @override
  String get tentativeInvitation => 'Provisório';

  @override
  String get declineInvitation => 'Recusar';

  @override
  String get joinMeeting => 'Participar na reunião';

  @override
  String get responseAccepted => 'Aceite';

  @override
  String get responseTentative => 'Provisório';

  @override
  String get responseDeclined => 'Recusado';

  @override
  String get responseNeedsAction => 'A aguardar resposta';

  @override
  String get responseNotResponded => 'Sem resposta';

  @override
  String get responseOrganizer => 'Organizador';

  @override
  String invitationResponseFailed(String error) {
    return 'Não foi possível enviar a sua resposta: $error';
  }

  @override
  String get joinMeetingFailed =>
      'Não foi possível abrir a ligação da reunião.';

  @override
  String get description => 'Descrição';

  @override
  String get availabilityShowAs => 'Disponibilidade / Mostrar como';

  @override
  String get busy => 'Ocupado';

  @override
  String get visibility => 'Visibilidade';

  @override
  String get defaultVisibility => 'Visibilidade predefinida';

  @override
  String get conference => 'Conferência';

  @override
  String get noConference => 'Sem conferência';

  @override
  String get providerCalendar => 'Calendário do fornecedor';

  @override
  String get formatBoldShortLabel => 'N';

  @override
  String get formatBoldTooltip => 'Negrito';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'Itálico';

  @override
  String get formatUnderlineShortLabel => 'S';

  @override
  String get formatUnderlineTooltip => 'Sublinhado';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos antes',
      one: '1 minuto antes',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'À hora de início';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas antes',
      one: '1 hora antes',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias antes',
      one: '1 dia antes',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Livre';

  @override
  String get availabilityTentative => 'Provisório';

  @override
  String get availabilityOutOfOffice => 'Fora do escritório';

  @override
  String get availabilityWorkingElsewhere => 'A trabalhar noutro local';

  @override
  String get visibilityDefault => 'Predefinida';

  @override
  String get visibilityPublic => 'Pública';

  @override
  String get visibilityPrivate => 'Privada';

  @override
  String get visibilityConfidential => 'Confidencial';

  @override
  String get sensitivityNormal => 'Habitual';

  @override
  String get sensitivityPersonal => 'Pessoal';

  @override
  String get tasks => 'Tarefas';

  @override
  String get allTasks => 'Todas as tarefas';

  @override
  String tasksInList(String title) {
    return 'Tarefas em $title';
  }

  @override
  String get taskLists => 'Listas de tarefas';

  @override
  String get navigation => 'Navegação';

  @override
  String get mainMenu => 'Menu principal';

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get shortcutGroupGeneral => 'Geral';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Mostrar esta referência de atalhos';

  @override
  String get shortcutGroupNavigation => 'Navegação';

  @override
  String get shortcutNextPeriod => 'Período seguinte';

  @override
  String get shortcutNextPeriodDescription =>
      'Semana seguinte na vista semanal, mês seguinte na vista mensal e assim por diante';

  @override
  String get shortcutPreviousPeriod => 'Período anterior';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Semana anterior na vista semanal, mês anterior na vista mensal e assim por diante';

  @override
  String get shortcutJumpToToday => 'Ir para hoje';

  @override
  String get shortcutGroupView => 'Vista';

  @override
  String get shortcutDayView => 'Vista diária';

  @override
  String get shortcutWeekView => 'Vista semanal';

  @override
  String get shortcutMonthView => 'Vista mensal';

  @override
  String get shortcutYearView => 'Vista anual';

  @override
  String get shortcutAgendaView => 'Vista de agenda';

  @override
  String get shortcutGroupCreateAndEdit => 'Criar e editar';

  @override
  String get shortcutSaveItem => 'Guardar evento ou tarefa';

  @override
  String get shortcutDeleteItem => 'Eliminar evento ou tarefa';

  @override
  String get shortcutGroupTaskEditing => 'Edição de tarefas';

  @override
  String get shortcutCancelEditing => 'Cancelar edição';

  @override
  String get shortcutCancelEditingDescription =>
      'Fechar a edição ou os detalhes da tarefa';

  @override
  String get aboutBusyMax => 'Acerca do BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Calendário e tarefas';

  @override
  String get license => 'Licença';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Site';

  @override
  String get sourceCode => 'Código-fonte';

  @override
  String get reportAnIssue => 'Comunicar um problema';

  @override
  String get sendFeedback => 'Enviar comentários';

  @override
  String get feedbackSubmit => 'Enviar';

  @override
  String get feedbackCategory => 'Categoria';

  @override
  String get feedbackSelectCategory => 'Selecione uma categoria';

  @override
  String get feedbackCategoryProblem => 'Problema ou erro';

  @override
  String get feedbackCategoryFeature => 'Pedido de funcionalidade';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Questão de privacidade ou segurança';

  @override
  String get feedbackCategoryUsability => 'Problema de utilização';

  @override
  String get feedbackCategoryOther => 'Outro';

  @override
  String get feedbackSubject => 'Assunto';

  @override
  String get feedbackDetailedMessage => 'Mensagem detalhada';

  @override
  String get feedbackReplyEmail =>
      'Endereço de e-mail para resposta (opcional)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Incluir detalhes técnicos';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Adiciona apenas a versão do sistema operativo Linux e a configuração regional da aplicação. Não são incluídos registos, dados de contas, nomes de ficheiros nem outros diagnósticos.';

  @override
  String get feedbackCategoryRequired => 'Selecione uma categoria.';

  @override
  String get feedbackSubjectLengthError =>
      'O assunto deve ter entre 3 e 120 carateres.';

  @override
  String get feedbackMessageLengthError =>
      'A mensagem deve ter entre 10 e 5 000 carateres.';

  @override
  String get feedbackInvalidEmail => 'Introduza um endereço de e-mail válido.';

  @override
  String get feedbackConnectionError =>
      'Não foi possível ligar ao BusyStack. Verifique a ligação e tente novamente.';

  @override
  String get feedbackTimeoutError =>
      'O pedido excedeu o tempo limite. Os seus comentários não foram apagados; tente novamente.';

  @override
  String get feedbackRateLimitedError =>
      'Foram enviados demasiados comentários a partir desta rede. Aguarde e tente novamente.';

  @override
  String get feedbackRejectedError =>
      'O servidor rejeitou o envio. Reveja os campos e tente novamente.';

  @override
  String get feedbackServerError =>
      'O BusyStack não pode aceitar os seus comentários neste momento. Os seus comentários não foram apagados; tente novamente.';

  @override
  String feedbackSuccess(String id) {
    return 'Comentários enviados. Referência: $id';
  }

  @override
  String get toggleSidebar => 'Mostrar ou ocultar a barra lateral';

  @override
  String get showSidebar => 'Mostrar painel lateral';

  @override
  String get hideSidebar => 'Ocultar painel lateral';

  @override
  String get accounts => 'Contas';

  @override
  String get currentAccount => 'Conta atual';

  @override
  String get switchAccount => 'Mudar de conta';

  @override
  String get addGoogleAccount => 'Adicionar conta Google';

  @override
  String get addMicrosoftAccount => 'Adicionar conta Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Sessão iniciada';

  @override
  String get removeAccount => 'Remover conta…';

  @override
  String get removingAccount => 'A remover conta…';

  @override
  String get removeAccountDescription =>
      'Parar a sincronização e remover os dados desta conta deste dispositivo.';

  @override
  String removeAccountTitle(String account) {
    return 'Remover $account do BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'Esta ação elimina deste dispositivo as tarefas, calendários, eventos, lembretes e alterações offline pendentes colocados em cache. As alterações não sincronizadas serão perdidas. As cópias dos calendários, eventos, listas de tarefas e tarefas no fornecedor não são eliminadas.';

  @override
  String get revokeGoogleAccess =>
      'Revogar também o acesso do BusyMax a esta conta Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Terá de conceder acesso novamente antes de voltar a ligar a conta.';

  @override
  String get removeAccountAction => 'Remover conta';

  @override
  String get removeAccountFailed =>
      'Não foi possível concluir a remoção da conta. Tente novamente.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'A conta foi removida deste dispositivo, mas não foi possível revogar o acesso do BusyMax à sua conta Google. Pode revogar esse acesso na sua conta Google.';

  @override
  String get newTaskList => 'Nova lista de tarefas';

  @override
  String taskListCreateFailed(String error) {
    return 'Não foi possível criar a lista de tarefas: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Não foi possível mudar o nome da lista de tarefas: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Não foi possível eliminar a lista de tarefas: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Inicie sessão para ver as listas de tarefas.';

  @override
  String get noTaskListsSynced =>
      'Ainda não há listas de tarefas sincronizadas.';

  @override
  String get listActions => 'Ações da lista';

  @override
  String get rename => 'Mudar o nome';

  @override
  String get delete => 'Eliminar';

  @override
  String get renameList => 'Mudar o nome da lista';

  @override
  String get deleteList => 'Eliminar lista';

  @override
  String get unshare => 'Cancelar partilha';

  @override
  String get readOnlyTaskListCannotRename =>
      'Esta lista de tarefas é só de leitura e não pode ter o nome alterado.';

  @override
  String get taskListCannotDelete =>
      'Esta lista de tarefas não pode ser eliminada com as permissões atuais.';

  @override
  String get builtInMicrosoftList => 'Incorporada';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'As listas incorporadas do Microsoft To Do não podem ser renomeadas nem eliminadas.';

  @override
  String deleteListConfirmation(String title) {
    return 'Eliminar “$title” do Google Tasks?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Eliminar “$title” e todas as suas tarefas?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Cancelar a partilha de “$title” desta conta?';
  }

  @override
  String get deleteEvent => 'Eliminar evento';

  @override
  String get title => 'Título';

  @override
  String get create => 'Criar';

  @override
  String get newTask => 'Nova tarefa';

  @override
  String get clearCompleted => 'Limpar tarefas concluídas';

  @override
  String get refreshList => 'Atualizar lista';

  @override
  String get refreshAll => 'Atualizar tudo';

  @override
  String get listRefreshed => 'Lista atualizada.';

  @override
  String get allTasksRefreshed => 'Todas as contas foram atualizadas.';

  @override
  String exportedFile(String path) {
    return 'Exportado para $path';
  }

  @override
  String exportFailed(String error) {
    return 'Falha ao exportar: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Falha ao atualizar: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Selecione ou crie uma lista de tarefas para começar.';

  @override
  String get signInToViewTasks => 'Inicie sessão para ver as tarefas.';

  @override
  String get noTasks => 'Sem tarefas.';

  @override
  String get noTasksYet => 'Ainda não há tarefas';

  @override
  String get noTasksYetMessage =>
      'Crie uma tarefa ou atualize as suas contas para começar.';

  @override
  String get noTasksInList => 'Não há tarefas nesta lista.';

  @override
  String get overdue => 'Em atraso';

  @override
  String get today => 'Hoje';

  @override
  String get tomorrow => 'Amanhã';

  @override
  String get upcoming => 'Próximas';

  @override
  String get noDate => 'Sem data';

  @override
  String get completed => 'Concluídas';

  @override
  String duePrefix(String date) {
    return 'Prazo: $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date, $time';
  }

  @override
  String get taskDetails => 'Detalhes da tarefa';

  @override
  String get editTask => 'Editar tarefa';

  @override
  String get noTaskSelected => 'Nenhuma tarefa selecionada.';

  @override
  String get noTaskSelectedHelper =>
      'Selecione uma tarefa para ver e editar os detalhes.';

  @override
  String get taskUnavailable => 'Tarefa indisponível.';

  @override
  String get signInToEditTasks => 'Inicie sessão para editar tarefas.';

  @override
  String get refreshTask => 'Atualizar tarefa';

  @override
  String get primarySection => 'Principal';

  @override
  String get statusSection => 'Estado';

  @override
  String get openStatus => 'Aberta';

  @override
  String get doneStatus => 'Concluída';

  @override
  String get taskStatus => 'Estado';

  @override
  String get taskStatusNone => 'Sem estado';

  @override
  String get taskStatusNeedsAction => 'Requer ação';

  @override
  String get taskStatusInProcess => 'Em curso';

  @override
  String get taskStatusCompleted => 'Concluída';

  @override
  String get taskStatusCancelled => 'Cancelada';

  @override
  String completionPercent(int percent) {
    return '$percent% concluída';
  }

  @override
  String get completionDate => 'Data de conclusão';

  @override
  String get priority => 'Prioridade';

  @override
  String get priorityNone => 'Sem prioridade';

  @override
  String priorityHighValue(int priority) {
    return 'Prioridade $priority · Alta';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Prioridade $priority · Média';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Prioridade $priority · Baixa';
  }

  @override
  String get taskUrl => 'URL da tarefa';

  @override
  String get invalidTaskUrl =>
      'Introduza um URL absoluto, incluindo o esquema.';

  @override
  String get classification => 'Classificação';

  @override
  String get classificationPublic =>
      'Quando partilhada, mostrar a tarefa completa';

  @override
  String get classificationConfidential =>
      'Quando partilhada, mostrar apenas ocupado';

  @override
  String get classificationPrivate => 'Quando partilhada, ocultar esta tarefa';

  @override
  String get pinTask => 'Afixar tarefa';

  @override
  String get notes => 'Notas';

  @override
  String get dueDate => 'Data limite';

  @override
  String get clearDueDate => 'Limpar data limite';

  @override
  String get dueTime => 'Hora limite';

  @override
  String get startDate => 'Data de início';

  @override
  String get startTime => 'Hora de início';

  @override
  String get endDate => 'Data de fim';

  @override
  String get endTime => 'Hora de fim';

  @override
  String get reminderDate => 'Data do lembrete';

  @override
  String get reminderTime => 'Hora do lembrete';

  @override
  String get reminder => 'Lembrete';

  @override
  String get addReminder => 'Adicionar lembrete';

  @override
  String get reminders => 'Lembretes';

  @override
  String get noReminders => 'Sem lembretes';

  @override
  String get editReminder => 'Editar lembrete';

  @override
  String get beforeTaskStarts => 'Antes do início da tarefa';

  @override
  String get beforeTaskDue => 'Antes do prazo da tarefa';

  @override
  String get afterTaskStarts => 'Depois do início da tarefa';

  @override
  String get afterTaskDue => 'Depois do prazo da tarefa';

  @override
  String get relativeToTaskStart => 'Relativo à data de início da tarefa';

  @override
  String get relativeToTaskDue => 'Relativo à data limite da tarefa';

  @override
  String get reminderTimeOfDay => 'Hora do dia';

  @override
  String get absoluteReminder => 'Numa data e hora';

  @override
  String get reminderAmount => 'Quantidade';

  @override
  String get reminderUnit => 'Unidade';

  @override
  String get reminderUnitSeconds => 'Segundos';

  @override
  String get reminderUnitMinutes => 'Minutos';

  @override
  String get reminderUnitHours => 'Horas';

  @override
  String get reminderUnitDays => 'Dias';

  @override
  String get reminderUnitWeeks => 'Semanas';

  @override
  String get reminderAtTaskStart => 'No início da tarefa';

  @override
  String get reminderAtTaskDue => 'No prazo da tarefa';

  @override
  String get unsupportedReminder =>
      'Este tipo de lembrete é preservado, mas a hora não pode ser editada.';

  @override
  String get relatedRemindersTitle => 'Manter lembretes relacionados?';

  @override
  String relatedRemindersDescription(int count) {
    return 'Esta data tem $count lembretes relacionados. Mantê-los na data e hora atuais?';
  }

  @override
  String get discardRelatedReminders => 'Eliminar lembretes';

  @override
  String get keepRelatedReminders => 'Manter lembretes';

  @override
  String get addGuest => 'Adicionar convidado';

  @override
  String get addGuestEmail => 'Adicionar e-mail do convidado';

  @override
  String get removeReminder => 'Remover lembrete';

  @override
  String get off => 'Desativado';

  @override
  String get repeat => 'Repetição';

  @override
  String get repeatNone => 'Não repetir';

  @override
  String get noneValue => 'Nenhum';

  @override
  String get repeatDaily => 'Diariamente';

  @override
  String get repeatWeekly => 'Semanalmente';

  @override
  String get repeatMonthly => 'Mensalmente';

  @override
  String get repeatYearly => 'Anualmente';

  @override
  String get repeatEvery => 'Intervalo';

  @override
  String get repeatOn => 'Repetir em';

  @override
  String get repeatEnd => 'Terminar repetição';

  @override
  String get repeatNever => 'Nunca';

  @override
  String get repeatUntil => 'Numa data';

  @override
  String get repeatAfter => 'Depois de um número de ocorrências';

  @override
  String get repeatCount => 'Ocorrências';

  @override
  String get repeatDayOfMonth => 'Dias do mês';

  @override
  String get repeatMonths => 'Meses';

  @override
  String get repeatOrdinal => 'Posição do dia da semana';

  @override
  String get repeatSpecificDays => 'Dias específicos';

  @override
  String get repeatFirst => 'Primeiro';

  @override
  String get repeatSecond => 'Segundo';

  @override
  String get repeatThird => 'Terceiro';

  @override
  String get repeatFourth => 'Quarto';

  @override
  String get repeatFifth => 'Quinto';

  @override
  String get repeatSecondToLast => 'Penúltimo';

  @override
  String get repeatLast => 'Último';

  @override
  String get repeatAnyDay => 'Dia';

  @override
  String get repeatWeekday => 'Dia útil';

  @override
  String get repeatWeekendDay => 'Dia do fim de semana';

  @override
  String repeatEveryDays(int count) {
    return 'A cada $count dias';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'A cada $count semanas';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'A cada $count meses';
  }

  @override
  String repeatEveryYears(int count) {
    return 'A cada $count anos';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'em $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'no dia $days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'na primeira ocorrência de $days',
      'second': 'na segunda ocorrência de $days',
      'third': 'na terceira ocorrência de $days',
      'fourth': 'na quarta ocorrência de $days',
      'fifth': 'na quinta ocorrência de $days',
      'secondToLast': 'na penúltima ocorrência de $days',
      'last': 'na última ocorrência de $days',
      'other': 'em $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'em $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count vezes';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'até $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Esta regra de recorrência utiliza opções que este editor não altera.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Esta recorrência não pode ser usada com $provider.';
  }

  @override
  String get importance => 'Importância';

  @override
  String get importanceLow => 'Baixa';

  @override
  String get importanceNormal => 'Média';

  @override
  String get importanceHigh => 'Alta';

  @override
  String get categories => 'Categorias';

  @override
  String get scheduleSection => 'Agenda';

  @override
  String get dueGroup => 'Prazo';

  @override
  String get startGroup => 'Início';

  @override
  String get reminderGroup => 'Lembrete';

  @override
  String get organizationSection => 'Organização';

  @override
  String get actionsSection => 'Ações';

  @override
  String get advancedSection => 'Avançado';

  @override
  String get addCategory => 'Adicionar categoria';

  @override
  String get list => 'Lista';

  @override
  String get microsoftMoveUnsupported =>
      'Nesta versão, não é possível mover tarefas entre listas em contas Microsoft To Do.';

  @override
  String get createSubtask => 'Criar subtarefa';

  @override
  String get subtasks => 'Subtarefas';

  @override
  String get duplicateTask => 'Duplicar tarefa';

  @override
  String get taskDuplicated => 'Tarefa duplicada.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Não foi possível duplicar a tarefa: $error';
  }

  @override
  String get hideSubtasks => 'Ocultar subtarefas';

  @override
  String get hideClosedSubtasks => 'Ocultar subtarefas concluídas';

  @override
  String get moveToTop => 'Mover para o início';

  @override
  String get deleteTask => 'Eliminar tarefa';

  @override
  String get newSubtask => 'Nova subtarefa';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Eliminar «$title»?';
  }

  @override
  String get metadata => 'Metadados';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Atualizado';

  @override
  String get parent => 'Tarefa principal';

  @override
  String get position => 'Posição';

  @override
  String get webLink => 'Ligação Web';

  @override
  String get assignment => 'Atribuição';

  @override
  String get localState => 'Estado local';

  @override
  String get pendingSync => 'Sincronização pendente';

  @override
  String get synced => 'Sincronizado';

  @override
  String get account => 'Conta';

  @override
  String get sync => 'Sincronização';

  @override
  String get forceFullResync => 'Forçar nova sincronização completa';

  @override
  String get forceFullResyncDescription =>
      'Recarrega completamente os dados de todas as contas ligadas. Utilize esta opção apenas para resolver problemas de sincronização.';

  @override
  String get runInBackgroundWhenClosed =>
      'Continuar em execução quando a janela for fechada';

  @override
  String get showTrayIcon => 'Mostrar ícone na área de notificação';

  @override
  String get startMinimizedToTray =>
      'Iniciar minimizado na área de notificação';

  @override
  String get launchAtLogin => 'Iniciar ao entrar';

  @override
  String get launchAtLoginDescription =>
      'Inicie o BusyMax em segundo plano para que os lembretes funcionem após entrar.';

  @override
  String get launchAtLoginFailed =>
      'Não foi possível atualizar o início de sessão.';

  @override
  String get requiresTrayIcon => 'Requer o ícone da área de notificação.';

  @override
  String get syncComplete => 'Sincronização concluída.';

  @override
  String syncFailed(String error) {
    return 'Falha na sincronização: $error';
  }

  @override
  String get notifySyncFailures => 'Notificações de falhas de sincronização';

  @override
  String get notifyConflicts => 'Notificações de conflitos';

  @override
  String get notifyDueToday => 'Notificações de tarefas com prazo para hoje';

  @override
  String get eventReminders => 'Lembretes de eventos';

  @override
  String get onState => 'Ativado';

  @override
  String get taskReminders => 'Lembretes de tarefas';

  @override
  String get notificationDetailLevel => 'Nível de detalhe das notificações';

  @override
  String get notificationDetailPrivate => 'Privado';

  @override
  String get notificationDetailNormal => 'Predefinido';

  @override
  String get quietHours => 'Período de silêncio';

  @override
  String get quietHoursDescription =>
      'Pausar as notificações durante este período.';

  @override
  String get quietHoursStart => 'Início do período de silêncio';

  @override
  String get quietHoursEnd => 'Fim do período de silêncio';

  @override
  String get notifications => 'Notificações';

  @override
  String get appearance => 'Aspeto';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get settingsSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeFamily => 'Família de temas';

  @override
  String get themeFamilyYaru => 'Tema nativo do Ubuntu (Yaru)';

  @override
  String get localization => 'Localização';

  @override
  String get currentLocale => 'Configuração regional atual';

  @override
  String get privacy => 'Privacidade';

  @override
  String get redactTaskContentInDiagnostics =>
      'Ocultar o conteúdo das tarefas nos diagnósticos';

  @override
  String get developerDiagnostics => 'Diagnósticos de programador';

  @override
  String get diagnostics => 'Diagnósticos';

  @override
  String get apiInspectorDisabled => 'Mostrar inspetor da API';

  @override
  String get googleTasksApi => 'API do Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Revisão de descoberta: $revision';
  }

  @override
  String get implementedMethods => 'Métodos implementados';

  @override
  String get supportsTasksScopes =>
      'Suporta os âmbitos de autorização tasks e tasks.readonly';

  @override
  String get requiresTasksScope => 'Requer o âmbito de autorização tasks';

  @override
  String get blockedPendingOperations => 'Operações pendentes bloqueadas';

  @override
  String get signInToInspectPendingOperations =>
      'Inicie sessão para inspecionar as operações pendentes.';

  @override
  String get noBlockedPendingOperations =>
      'Não há operações pendentes bloqueadas.';

  @override
  String get operationActions => 'Ações da operação';

  @override
  String pendingOpListId(String id) {
    return 'lista=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'tarefa=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'tentativas=$count';
  }

  @override
  String get retry => 'Tentar novamente';

  @override
  String get discard => 'Descartar';

  @override
  String get discardChangesAction => 'Descartar';

  @override
  String get discardChanges => 'Descartar alterações?';

  @override
  String get discardChangesConfirmation =>
      'Esta ação descarta as alterações não guardadas nesta tarefa.';

  @override
  String get retryCompleted => 'Nova tentativa concluída.';

  @override
  String get discardPendingOperation => 'Descartar operação pendente?';

  @override
  String get discardPendingOperationConfirmation =>
      'Esta ação remove a operação local bloqueada. Na próxima sincronização, os dados serão novamente carregados do Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Operação pendente descartada.';

  @override
  String get syncFailureNotificationTitle =>
      'Falha na sincronização do BusyMax';

  @override
  String syncFailureNotificationBody(String message) {
    return 'A sincronização em segundo plano falhou. $message';
  }

  @override
  String get conflictNotificationTitle =>
      'Conflito de sincronização do BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Uma alteração local pendente foi bloqueada. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Tarefas com prazo para hoje';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count tarefas com prazo para hoje.',
      one: 'Há uma tarefa com prazo para hoje.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Lembrete de evento';

  @override
  String get taskReminderNotificationTitle => 'Lembrete de tarefa';

  @override
  String get eventReminderNotificationBody => 'O evento começa em breve.';

  @override
  String get taskReminderNotificationBody => 'O prazo da tarefa aproxima-se.';

  @override
  String get notificationOpenAction => 'Abrir';

  @override
  String get notificationSnoozeAction => 'Adiar 10 minutos';

  @override
  String get notificationDismissAction => 'Fechar';

  @override
  String get notificationDetailsHidden =>
      'Os detalhes estão ocultos pelas definições de privacidade.';

  @override
  String get previousMonth => 'Mês anterior';

  @override
  String get nextMonth => 'Mês seguinte';

  @override
  String get openMonthView => 'Abrir vista mensal';

  @override
  String get previousYear => 'Ano anterior';

  @override
  String get nextYear => 'Ano seguinte';

  @override
  String get openYearView => 'Abrir vista anual';

  @override
  String weekNumberTooltip(int number) {
    return 'Semana $number';
  }

  @override
  String get resizeAllDayPanel => 'Redimensionar o painel de dia inteiro';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Este calendário é só de leitura.';

  @override
  String get selectTimeZone => 'Selecionar fuso horário';

  @override
  String get searchLocations => 'Pesquisar locais';

  @override
  String get noLocationsFound => 'Não foram encontrados locais';

  @override
  String get requiredField => 'Este campo é obrigatório.';

  @override
  String get providerConnectionDescription =>
      'Ligue calendários e tarefas a um destes fornecedores.';

  @override
  String get appleICloudProvider => 'Calendário Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Tarefas do Nextcloud';

  @override
  String get addAppleICloudAccount =>
      'Adicionar conta do Calendário Apple iCloud';

  @override
  String get addNextcloudAccount => 'Adicionar conta Nextcloud';

  @override
  String get waitingForAppleICloud => 'A ligar ao Apple iCloud…';

  @override
  String get waitingForNextcloud => 'A aguardar autorização do Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Ligar o Calendário Apple iCloud';

  @override
  String get appleAccountEmail => 'E-mail da conta Apple';

  @override
  String get appleAppSpecificPassword =>
      'Palavra-passe específica da aplicação';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Crie uma palavra-passe específica da aplicação depois de ativar a autenticação de dois fatores na sua conta Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'A reposição da palavra-passe da conta Apple revoga as palavras-passe específicas de aplicações.';

  @override
  String get connectNextcloudTitle => 'Ligar ao Nextcloud';

  @override
  String get nextcloudServerUrl => 'Servidor Nextcloud ou endereço CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Introduza o URL do servidor Nextcloud ou cole o endereço CalDAV principal copiado do Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'O BusyMax abrirá o navegador. Aprove o acesso aí e volte ao BusyMax.';

  @override
  String get connectAccountAction => 'Ligar';

  @override
  String get cancelAccountConnection => 'Cancelar ligação';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'A conta foi removida localmente, mas não foi possível revogar a palavra-passe da aplicação Nextcloud.';

  @override
  String get davCachedOfflineNotice =>
      'Os dados de calendários e tarefas são colocados em cache localmente para utilização offline.';

  @override
  String get davReauthenticationRequired =>
      'Volte a ligar esta conta para retomar a sincronização.';

  @override
  String get davTemporarilyUnavailable =>
      'Esta conta está temporariamente indisponível.';

  @override
  String get davPermissionChanged =>
      'As permissões do servidor foram alteradas. As edições pendentes estão em pausa.';

  @override
  String get davUnsupportedServer =>
      'Este servidor ou perfil do fornecedor não é suportado.';

  @override
  String get collectionSettings => 'Calendários e listas de tarefas';

  @override
  String get calendarContent => 'Eventos do calendário';

  @override
  String get taskContent => 'Tarefas';

  @override
  String get readOnlySharedCollection => 'Só de leitura';

  @override
  String get pendingLocally => 'Pendente localmente';

  @override
  String get conflictBlocked => 'Bloqueado por conflito';

  @override
  String get authenticationBlocked => 'Bloqueado até voltar a ligar';

  @override
  String get operationFailed => 'Operação falhou';

  @override
  String get keepServerVersion => 'Manter versão do servidor';

  @override
  String get reapplyLocalChange => 'Rever e reaplicar alteração local';

  @override
  String get duplicateLocalItem => 'Duplicar como novo item';

  @override
  String get davConnectionState => 'Estado da ligação';

  @override
  String get davConnected => 'Ligado';

  @override
  String get davConnecting => 'A ligar…';

  @override
  String get davSignedOut => 'Sessão terminada';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Última sincronização bem-sucedida: $time';
  }

  @override
  String get davNeverSynced => 'Ainda não sincronizado';

  @override
  String get refreshCollections => 'Atualizar calendários e listas de tarefas';

  @override
  String nextcloudServerHost(String host) {
    return 'Servidor: $host';
  }

  @override
  String get collectionSupportsEvents => 'Calendário de eventos';

  @override
  String get collectionSupportsTasks => 'Lista de tarefas';

  @override
  String get collectionSupportsEventsAndTasks => 'Eventos e tarefas';

  @override
  String get writableCollection => 'Editável';

  @override
  String get sharedCollection => 'Partilhado';

  @override
  String collectionLastSynced(String time) {
    return 'Última sincronização: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Problema de sincronização: $code';
  }

  @override
  String get syncConflicts => 'Conflitos de sincronização';

  @override
  String remoteChangedAt(String time) {
    return 'Alteração no servidor: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Edição local: $summary';
  }

  @override
  String get conflictResolutionFailed =>
      'Não foi possível resolver o conflito.';

  @override
  String get recurringEventScope => 'Âmbito do evento recorrente';

  @override
  String get entireSeries => 'Série inteira';

  @override
  String get singleOccurrence => 'Este evento';

  @override
  String get thisAndFollowingEvents => 'Este evento e os seguintes';

  @override
  String get thisAndFutureUnavailable => 'Não suportado por este fornecedor.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Este evento e os seguintes não podem ser movidos com segurança. Escolha este evento ou a série inteira.';

  @override
  String get entireSeriesMoveUnavailable =>
      'A regra de recorrência não está disponível localmente. Mova apenas este evento.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Copiar o evento e eliminar o original?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'O BusyMax não pode mover este evento diretamente de $source para $destination. Criará primeiro a cópia e eliminará o original apenas depois de a cópia ser criada com êxito. Os IDs do evento mudarão; os estados das respostas dos participantes poderão ser repostos e poderão ser enviados convites ou cancelamentos; as ligações de reuniões, os anexos, os lembretes, os campos específicos do fornecedor e as exceções de recorrência poderão não ser transferidos.';
  }

  @override
  String get copyAndDelete => 'Copiar e eliminar';

  @override
  String get chooseRecurringEventScope =>
      'Escolha se esta alteração se aplica à série inteira, apenas a este evento ou a este e aos eventos seguintes.';

  @override
  String get taskDueBeforeStart => 'O prazo não pode ser anterior ao início.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Defina horários para o início e o prazo, ou torne a tarefa de dia inteiro.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Eliminar «$title»?';
  }

  @override
  String get setCustomCalendarName => 'Definir nome personalizado';

  @override
  String get setAction => 'Definir';

  @override
  String get removeFromMyCalendars => 'Remover dos meus calendários';

  @override
  String get removeAction => 'Remover';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Remover \"$title\" da sua lista do Google Calendar? O calendário partilhado e os respetivos eventos não serão eliminados.';
  }

  @override
  String get calendarCannotRemove =>
      'Não é possível eliminar nem remover este calendário desta conta.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Aguarde que as alterações pendentes deste calendário terminem de sincronizar antes de o eliminar ou remover.';

  @override
  String get calendarSubscriptions => 'Subscrições de calendários';

  @override
  String get calendarSubscriptionsDescription =>
      'Adicione calendários só de leitura que sejam atualizados a partir de um URL WebCal seguro.';

  @override
  String get addCalendarSubscription => 'Adicionar subscrição de calendário';

  @override
  String get subscriptionName => 'Nome local';

  @override
  String get subscriptionUrl => 'URL da subscrição';

  @override
  String get subscriptionUrlHelp =>
      'Introduza um URL HTTPS ou webcal. O BusyMax mantém o URL completo num armazenamento seguro.';

  @override
  String get subscriptionUrlInvalid =>
      'Introduza um URL HTTPS ou webcal válido sem informações de utilizador ou fragmento.';

  @override
  String get subscriptionColor => 'Cor local';

  @override
  String get subscriptionColorHelp =>
      'Utilize uma cor de seis dígitos, como #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Introduza uma cor hexadecimal de seis dígitos.';

  @override
  String get subscriptionRefreshMode => 'Frequência de atualização';

  @override
  String get subscriptionAutomatic => 'Automática';

  @override
  String get subscriptionHourly => 'De hora a hora';

  @override
  String get subscriptionSixHours => 'A cada seis horas';

  @override
  String get subscriptionDaily => 'Diária';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Origem: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Introduza um URL válido para pré-visualizar a origem segura.';

  @override
  String get subscriptionReadOnly => 'Subscrição só de leitura';

  @override
  String get subscriptionNeverRefreshed => 'Ainda não atualizada';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Última atualização bem-sucedida: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Próxima atualização: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Atualizada';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Problema de atualização: $code';
  }

  @override
  String get refreshNow => 'Atualizar agora';

  @override
  String get unsubscribe => 'Cancelar subscrição';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Cancelar subscrição de “$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Isto remove a subscrição local e os eventos colocados em cache. O calendário publicado não é alterado.';

  @override
  String get addSubscriptionAction => 'Adicionar subscrição';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Falha na subscrição do calendário: $error';
  }

  @override
  String get subscriptions => 'Subscrições';

  @override
  String get calendarImport => 'Importação de calendário';

  @override
  String get calendarImportDescription =>
      'Selecione um ficheiro, reveja os eventos e escolha o calendário editável que os deve receber.';

  @override
  String get importIcsFile => 'Importar ficheiro .ics';

  @override
  String get importIcsPreview => 'Importar eventos do calendário';

  @override
  String importEventsFound(int count) {
    return 'Conjuntos de eventos importáveis: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Eventos inválidos: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Omitidos intencionalmente: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Não está disponível nenhum calendário de destino editável.';

  @override
  String get importDestinationCalendar => 'Calendário de destino';

  @override
  String get importIcsConfirm => 'Importar eventos';

  @override
  String get importIcsComplete => 'Importação concluída';

  @override
  String importQueued(int count) {
    return 'Importados ou em fila: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Duplicados ignorados: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Conjuntos de recorrência não suportados: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Não foi possível importar o ficheiro de calendário: $error';
  }

  @override
  String get networkOffline => 'Sem ligação';

  @override
  String get networkOfflineDescription =>
      'As alterações serão sincronizadas quando a ligação for restabelecida.';

  @override
  String get networkOfflineTryAgain =>
      'Está offline. Ligue-se à Internet e tente novamente.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'nos dias $days';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String get repeatMonthDayListSeparator => ', ';

  @override
  String repeatYearlyMonthValue(String month, String monthKey) {
    String _temp0 = intl.Intl.selectLogic(monthKey, {'other': '$month'});
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first e $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first e $second';
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
    return '$frequency no dia $day de $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency nos dias $days de $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency no dia $day de $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency nos dias $days de $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'na primeira ocorrência de $days de $month',
      'second': 'na segunda ocorrência de $days de $month',
      'third': 'na terceira ocorrência de $days de $month',
      'fourth': 'na quarta ocorrência de $days de $month',
      'fifth': 'na quinta ocorrência de $days de $month',
      'secondToLast': 'na penúltima ocorrência de $days de $month',
      'last': 'na última ocorrência de $days de $month',
      'other': 'em $days de $month',
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
      'first': 'na primeira ocorrência de $days de $months',
      'second': 'na segunda ocorrência de $days de $months',
      'third': 'na terceira ocorrência de $days de $months',
      'fourth': 'na quarta ocorrência de $days de $months',
      'fifth': 'na quinta ocorrência de $days de $months',
      'secondToLast': 'na penúltima ocorrência de $days de $months',
      'last': 'na última ocorrência de $days de $months',
      'other': 'em $days de $months',
    });
    return '$frequency $_temp0';
  }
}

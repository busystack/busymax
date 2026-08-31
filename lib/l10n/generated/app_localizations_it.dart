// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Collega gli account Google, Microsoft, Calendario Apple iCloud o Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'Nella schermata delle autorizzazioni di Google, seleziona sia l’autorizzazione per il calendario sia quella per le attività.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Sono necessarie le autorizzazioni per Google Calendar e Google Tasks. Riprova e seleziona entrambe le caselle.';

  @override
  String get finishSetup => 'Completa la configurazione';

  @override
  String get continueSetup => 'Continua';

  @override
  String get onboardingSetupTitle => 'Configura BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Collega gli account';

  @override
  String get onboardingAccountsStepDescription =>
      'Aggiungi tutti gli account che vuoi usare. BusyMax sincronizza calendari, eventi, elenchi di attività e attività supportati da ogni account.';

  @override
  String get onboardingPreferencesStepTitle =>
      'Scegli le impostazioni di sistema';

  @override
  String get onboardingPreferencesStepDescription =>
      'Prima di aprire l’agenda, configura il comportamento sul desktop, i promemoria, il livello di dettaglio delle notifiche e l’aspetto.';

  @override
  String get signInWithGoogle => 'Accedi con Google';

  @override
  String get signInWithMicrosoft => 'Accedi con Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Questo servizio non è configurato.';

  @override
  String get waitingForGoogleSignIn => 'In attesa dell’accesso a Google...';

  @override
  String get waitingForMicrosoftSignIn =>
      'In attesa dell’accesso a Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'L’accesso a Microsoft non è configurato. Imposta MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Annulla';

  @override
  String get close => 'Chiudi';

  @override
  String get exit => 'Esci';

  @override
  String get options => 'Opzioni';

  @override
  String get hide => 'Nascondi';

  @override
  String get show => 'Mostra';

  @override
  String get export => 'Esporta';

  @override
  String get save => 'Salva';

  @override
  String get settings => 'Impostazioni';

  @override
  String get all => 'Tutto';

  @override
  String get calendarEvents => 'Eventi';

  @override
  String get calendarTasks => 'Attività';

  @override
  String get calendar => 'Calendario';

  @override
  String get calendars => 'Calendari';

  @override
  String get newCalendar => 'Nuovo calendario';

  @override
  String get calendarColor => 'Colore del calendario';

  @override
  String calendarColorOption(int number) {
    return 'Colore $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Questo provider non supporta la gestione dei calendari in BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'Il calendario principale non può essere eliminato.';

  @override
  String calendarCreateFailed(String error) {
    return 'Impossibile creare il calendario: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'Il calendario è stato creato, ma BusyMax non ha potuto aggiornare l’account. Apparirà dopo la prossima sincronizzazione.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Impossibile aggiornare il calendario: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Impossibile eliminare il calendario: $error';
  }

  @override
  String get newEvent => 'Nuovo evento';

  @override
  String get refreshCalendar => 'Aggiorna calendario';

  @override
  String get openInProvider => 'Apri nel servizio';

  @override
  String get hideFromSchedule => 'Nascondi dall’agenda';

  @override
  String get showInSchedule => 'Mostra nell’agenda';

  @override
  String get noCalendarsSynced => 'Nessun calendario ancora sincronizzato.';

  @override
  String get allDay => 'Tutto il giorno';

  @override
  String moreItems(int count) {
    return '+$count in più';
  }

  @override
  String get noEventsOrTasks => 'Nessun evento o attività';

  @override
  String get scheduleLoading => 'Caricamento agenda...';

  @override
  String get scheduleUnavailable => 'Agenda non disponibile';

  @override
  String get scheduleNoSources =>
      'Nessun calendario o elenco di attività visibile';

  @override
  String get scheduleNoSourcesDescription =>
      'Scegli cosa mostrare nelle Impostazioni, quindi aggiorna l’agenda.';

  @override
  String get scheduleSignInRequired => 'Collega un account';

  @override
  String get scheduleSignInDescription =>
      'Accedi per sincronizzare calendari e attività.';

  @override
  String get scheduleNoSearchResults =>
      'Nessun evento o attività corrispondente';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Prova una ricerca diversa o cancella i filtri attuali.';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get trayOpenBusyMax => 'Apri BusyMax';

  @override
  String get trayShowBusyMax => 'Mostra BusyMax';

  @override
  String get trayNewEvent => 'Nuovo evento…';

  @override
  String get trayNewTask => 'Nuova attività…';

  @override
  String get trayToday => 'Oggi';

  @override
  String get trayAllDay => 'Tutto il giorno';

  @override
  String get trayNow => 'Adesso';

  @override
  String get trayCalendarEvent => 'Evento del calendario';

  @override
  String get trayUntitledEvent => 'Evento senza titolo';

  @override
  String get trayNothingElseToday => 'Nient’altro oggi';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività scadono oggi',
      one: '1 attività scade oggi',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Apri l’agenda di oggi';

  @override
  String get traySyncNow => 'Sincronizza ora';

  @override
  String get traySyncing => 'Sincronizzazione…';

  @override
  String get trayNotConnected => 'Non connesso';

  @override
  String get trayNotYetSynced => 'Non ancora sincronizzato';

  @override
  String get trayLastSyncedJustNow => 'Sincronizzato proprio ora';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizzato $count minuti fa',
      one: 'Sincronizzato 1 minuto fa',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizzato $count ore fa',
      one: 'Sincronizzato 1 ora fa',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizzato $count giorni fa',
      one: 'Sincronizzato 1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Impostazioni';

  @override
  String get trayQuitBusyMax => 'Esci da BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Carica altre attività scadute';

  @override
  String get agendaLoadMoreNoDate => 'Carica altre attività senza data';

  @override
  String get viewDay => 'Giorno';

  @override
  String get viewWeek => 'Settimana';

  @override
  String get viewMonth => 'Mese';

  @override
  String get viewYear => 'Anno';

  @override
  String get viewAgenda => 'Vista agenda';

  @override
  String get scheduleSettings => 'Agenda';

  @override
  String get scheduleDisplaySettings => 'Visualizzazione agenda';

  @override
  String get scheduleDisplayHoursDescription =>
      'Le viste Giorno e Settimana mostrano inizialmente questo intervallo orario. Gli elementi precedenti o successivi lo estendono quando necessario.';

  @override
  String get scheduleDayStartsAt => 'Inizio giornata';

  @override
  String get scheduleDayEndsAt => 'Fine giornata';

  @override
  String get sourceCalendar => 'Calendario';

  @override
  String get sourceTaskList => 'Elenco di attività';

  @override
  String get createChoiceTitle => 'Crea';

  @override
  String get createEventAtTime => 'Evento';

  @override
  String get createTaskAtDate => 'Attività';

  @override
  String get editEvent => 'Modifica evento';

  @override
  String get eventTitle => 'Titolo dell’evento';

  @override
  String get location => 'Luogo';

  @override
  String get timeSlot => 'Fascia oraria';

  @override
  String get startDateTime => 'Data/ora di inizio';

  @override
  String get endDateTime => 'Data/ora di fine';

  @override
  String get doesNotRepeat => 'Non si ripete';

  @override
  String get defaultReminder => 'Promemoria predefinito';

  @override
  String get guests => 'Invitati';

  @override
  String get noGuests => 'Nessun invitato';

  @override
  String get attendeeRequired => 'Obbligatorio';

  @override
  String get attendeeOptional => 'Facoltativo';

  @override
  String get meetingSection => 'Riunione';

  @override
  String get addGoogleMeet => 'Aggiungi Google Meet';

  @override
  String get addTeamsMeeting => 'Aggiungi riunione Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Riunione online aggiunta';

  @override
  String get requestResponses => 'Richiedi risposte';

  @override
  String get requestResponsesDescription =>
      'Chiedi agli invitati di rispondere all’invito.';

  @override
  String get hideGuestList => 'Nascondi elenco invitati';

  @override
  String get hideGuestListDescription =>
      'Gli invitati non possono vedere chi altro è stato invitato.';

  @override
  String get allowNewTimeProposals => 'Consenti nuove proposte di orario';

  @override
  String get allowNewTimeProposalsDescription =>
      'Gli invitati possono suggerire un altro orario per la riunione.';

  @override
  String get notifyGuestsTitle => 'Notificare gli invitati?';

  @override
  String get notifyGuestsSaveMessage =>
      'Questa riunione ha degli invitati. Inviare inviti o aggiornamenti dell’evento al salvataggio?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Questa riunione ha degli invitati. Inviare una cancellazione quando viene eliminata?';

  @override
  String get sendUpdates => 'Invia aggiornamenti';

  @override
  String get sendCancellation => 'Invia cancellazione';

  @override
  String get doNotSend => 'Non inviare';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Salvare la riunione?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft invierà inviti o aggiornamenti dell’evento agli invitati.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Eliminare la riunione?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft invierà una cancellazione agli invitati.';

  @override
  String get organizer => 'Organizzatore';

  @override
  String get yourResponse => 'La tua risposta';

  @override
  String get guestResponses => 'Risposte degli invitati';

  @override
  String get respond => 'Rispondi';

  @override
  String get acceptInvitation => 'Accetta';

  @override
  String get tentativeInvitation => 'Provvisorio';

  @override
  String get declineInvitation => 'Rifiuta';

  @override
  String get joinMeeting => 'Partecipa alla riunione';

  @override
  String get responseAccepted => 'Accettata';

  @override
  String get responseTentative => 'Provvisoria';

  @override
  String get responseDeclined => 'Rifiutata';

  @override
  String get responseNeedsAction => 'In attesa di risposta';

  @override
  String get responseNotResponded => 'Nessuna risposta';

  @override
  String get responseOrganizer => 'Organizzatore';

  @override
  String invitationResponseFailed(String error) {
    return 'Impossibile inviare la risposta: $error';
  }

  @override
  String get joinMeetingFailed => 'Impossibile aprire il link della riunione.';

  @override
  String get description => 'Descrizione';

  @override
  String get availabilityShowAs => 'Disponibilità / Mostra come';

  @override
  String get busy => 'Occupato';

  @override
  String get visibility => 'Visibilità';

  @override
  String get defaultVisibility => 'Visibilità predefinita';

  @override
  String get conference => 'Conferenza';

  @override
  String get noConference => 'Nessuna conferenza';

  @override
  String get providerCalendar => 'Calendario del servizio';

  @override
  String get formatBoldShortLabel => 'G';

  @override
  String get formatBoldTooltip => 'Grassetto';

  @override
  String get formatItalicShortLabel => 'C';

  @override
  String get formatItalicTooltip => 'Corsivo';

  @override
  String get formatUnderlineShortLabel => 'S';

  @override
  String get formatUnderlineTooltip => 'Sottolineato';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuti prima',
      one: '1 minuto prima',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'All’inizio';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours ore prima',
      one: '1 ora prima',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni prima',
      one: '1 giorno prima',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Libero';

  @override
  String get availabilityTentative => 'Provvisorio';

  @override
  String get availabilityOutOfOffice => 'Fuori sede';

  @override
  String get availabilityWorkingElsewhere => 'Lavora altrove';

  @override
  String get visibilityDefault => 'Predefinita';

  @override
  String get visibilityPublic => 'Pubblica';

  @override
  String get visibilityPrivate => 'Privata';

  @override
  String get visibilityConfidential => 'Riservata';

  @override
  String get sensitivityNormal => 'Normale';

  @override
  String get sensitivityPersonal => 'Personale';

  @override
  String get tasks => 'Attività';

  @override
  String get allTasks => 'Tutte le attività';

  @override
  String tasksInList(String title) {
    return 'Attività in $title';
  }

  @override
  String get taskLists => 'Elenchi di attività';

  @override
  String get navigation => 'Navigazione';

  @override
  String get mainMenu => 'Menu principale';

  @override
  String get keyboardShortcuts => 'Scorciatoie da tastiera';

  @override
  String get shortcutGroupGeneral => 'Generali';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Mostra questo elenco di scorciatoie';

  @override
  String get shortcutGroupNavigation => 'Navigazione';

  @override
  String get shortcutNextPeriod => 'Periodo successivo';

  @override
  String get shortcutNextPeriodDescription =>
      'Settimana successiva nella vista settimanale, mese successivo nella vista mensile e così via';

  @override
  String get shortcutPreviousPeriod => 'Periodo precedente';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Settimana precedente nella vista settimanale, mese precedente nella vista mensile e così via';

  @override
  String get shortcutJumpToToday => 'Vai alla data odierna';

  @override
  String get shortcutGroupView => 'Vista';

  @override
  String get shortcutDayView => 'Vista giornaliera';

  @override
  String get shortcutWeekView => 'Vista settimanale';

  @override
  String get shortcutMonthView => 'Vista mensile';

  @override
  String get shortcutYearView => 'Vista annuale';

  @override
  String get shortcutAgendaView => 'Vista agenda';

  @override
  String get shortcutGroupCreateAndEdit => 'Creazione e modifica';

  @override
  String get shortcutSaveItem => 'Salva evento o attività';

  @override
  String get shortcutDeleteItem => 'Elimina evento o attività';

  @override
  String get shortcutGroupTaskEditing => 'Modifica delle attività';

  @override
  String get shortcutCancelEditing => 'Annulla modifica';

  @override
  String get shortcutCancelEditingDescription =>
      'Chiudi la modifica o i dettagli dell’attività';

  @override
  String get aboutBusyMax => 'Informazioni su BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Calendario e attività';

  @override
  String get license => 'Licenza';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Sito web';

  @override
  String get sourceCode => 'Codice sorgente';

  @override
  String get reportAnIssue => 'Segnala un problema';

  @override
  String get sendFeedback => 'Invia feedback';

  @override
  String get feedbackSubmit => 'Invia';

  @override
  String get feedbackCategory => 'Categoria';

  @override
  String get feedbackSelectCategory => 'Seleziona una categoria';

  @override
  String get feedbackCategoryProblem => 'Problema o errore';

  @override
  String get feedbackCategoryFeature => 'Richiesta di funzionalità';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Problema di privacy o sicurezza';

  @override
  String get feedbackCategoryUsability => 'Problema di usabilità';

  @override
  String get feedbackCategoryOther => 'Altro';

  @override
  String get feedbackSubject => 'Oggetto';

  @override
  String get feedbackDetailedMessage => 'Messaggio dettagliato';

  @override
  String get feedbackReplyEmail =>
      'Indirizzo email per la risposta (facoltativo)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Includi dettagli tecnici';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Aggiunge soltanto la versione del sistema operativo Linux e le impostazioni locali dell’applicazione. Non vengono inclusi log, dati degli account, nomi di file o altre informazioni diagnostiche.';

  @override
  String get feedbackCategoryRequired => 'Seleziona una categoria.';

  @override
  String get feedbackSubjectLengthError =>
      'L’oggetto deve contenere da 3 a 120 caratteri.';

  @override
  String get feedbackMessageLengthError =>
      'Il messaggio deve contenere da 10 a 5.000 caratteri.';

  @override
  String get feedbackInvalidEmail => 'Inserisci un indirizzo email valido.';

  @override
  String get feedbackConnectionError =>
      'Impossibile connettersi a BusyStack. Controlla la connessione e riprova.';

  @override
  String get feedbackTimeoutError =>
      'La richiesta ha superato il tempo limite. Il feedback non è stato cancellato; riprova.';

  @override
  String get feedbackRateLimitedError =>
      'Sono stati inviati troppi feedback da questa rete. Attendi e riprova.';

  @override
  String get feedbackRejectedError =>
      'Il server ha rifiutato l’invio. Controlla i campi e riprova.';

  @override
  String get feedbackServerError =>
      'BusyStack non può accettare il feedback in questo momento. Il feedback non è stato cancellato; riprova.';

  @override
  String feedbackSuccess(String id) {
    return 'Feedback inviato. Riferimento: $id';
  }

  @override
  String get toggleSidebar => 'Mostra o nascondi la barra laterale';

  @override
  String get showSidebar => 'Mostra il pannello laterale';

  @override
  String get hideSidebar => 'Nascondi il pannello laterale';

  @override
  String get accounts => 'Account';

  @override
  String get currentAccount => 'Account attuale';

  @override
  String get switchAccount => 'Cambia account';

  @override
  String get addGoogleAccount => 'Aggiungi account Google';

  @override
  String get addMicrosoftAccount => 'Aggiungi account Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Accesso effettuato';

  @override
  String get removeAccount => 'Rimuovi account…';

  @override
  String get removingAccount => 'Rimozione account…';

  @override
  String get removeAccountDescription =>
      'Interrompi la sincronizzazione e rimuovi i dati di questo account dal dispositivo.';

  @override
  String removeAccountTitle(String account) {
    return 'Rimuovere $account da BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'Questa operazione elimina da questo dispositivo attività, calendari, eventi, promemoria e modifiche offline in sospeso memorizzati nella cache. Le modifiche non sincronizzate andranno perse. Le copie del provider non verranno eliminate.';

  @override
  String get revokeGoogleAccess =>
      'Revoca anche l’accesso di BusyMax a questo account Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Dovrai concedere nuovamente l’accesso prima di riconnetterti.';

  @override
  String get removeAccountAction => 'Rimuovi account';

  @override
  String get removeAccountFailed =>
      'Impossibile completare la rimozione dell’account. Riprova.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'L’account è stato rimosso da questo dispositivo, ma BusyMax non è riuscito a revocare il proprio accesso a Google. Puoi revocarlo dal tuo account Google.';

  @override
  String get newTaskList => 'Nuovo elenco di attività';

  @override
  String taskListCreateFailed(String error) {
    return 'Impossibile creare l’elenco di attività: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Impossibile rinominare l’elenco di attività: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Impossibile eliminare l’elenco di attività: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Accedi per visualizzare gli elenchi di attività.';

  @override
  String get noTaskListsSynced =>
      'Nessun elenco di attività ancora sincronizzato.';

  @override
  String get listActions => 'Azioni dell’elenco';

  @override
  String get rename => 'Rinomina';

  @override
  String get delete => 'Elimina';

  @override
  String get renameList => 'Rinomina elenco';

  @override
  String get deleteList => 'Elimina elenco';

  @override
  String get unshare => 'Rimuovi condivisione';

  @override
  String get readOnlyTaskListCannotRename =>
      'Questo elenco di attività è di sola lettura e non può essere rinominato.';

  @override
  String get taskListCannotDelete =>
      'Questo elenco di attività non può essere eliminato con le autorizzazioni attuali.';

  @override
  String get builtInMicrosoftList => 'Integrato';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Gli elenchi integrati di Microsoft To Do non possono essere rinominati o eliminati.';

  @override
  String deleteListConfirmation(String title) {
    return 'Eliminare “$title” da Google Tasks?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Eliminare “$title” e tutte le sue attività?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Rimuovere la condivisione di “$title” da questo account?';
  }

  @override
  String get deleteEvent => 'Elimina evento';

  @override
  String get title => 'Titolo';

  @override
  String get create => 'Crea';

  @override
  String get newTask => 'Nuova attività';

  @override
  String get clearCompleted => 'Cancella attività completate';

  @override
  String get refreshList => 'Aggiorna elenco';

  @override
  String get refreshAll => 'Aggiorna tutto';

  @override
  String get listRefreshed => 'Elenco aggiornato.';

  @override
  String get allTasksRefreshed => 'Tutti gli account sono stati aggiornati.';

  @override
  String exportedFile(String path) {
    return 'Esportato in $path';
  }

  @override
  String exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Aggiornamento non riuscito: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Seleziona o crea un elenco di attività per iniziare.';

  @override
  String get signInToViewTasks => 'Accedi per visualizzare le attività.';

  @override
  String get noTasks => 'Nessuna attività.';

  @override
  String get noTasksYet => 'Ancora nessuna attività';

  @override
  String get noTasksYetMessage =>
      'Crea un’attività o aggiorna gli account per iniziare.';

  @override
  String get noTasksInList => 'Nessuna attività in questo elenco.';

  @override
  String get overdue => 'Scadute';

  @override
  String get today => 'Oggi';

  @override
  String get tomorrow => 'Domani';

  @override
  String get upcoming => 'In arrivo';

  @override
  String get noDate => 'Senza data';

  @override
  String get completed => 'Completate';

  @override
  String duePrefix(String date) {
    return 'Scadenza: $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => 'Dettagli attività';

  @override
  String get editTask => 'Modifica attività';

  @override
  String get noTaskSelected => 'Nessuna attività selezionata.';

  @override
  String get noTaskSelectedHelper =>
      'Seleziona un’attività per visualizzarne e modificarne i dettagli.';

  @override
  String get taskUnavailable => 'Attività non disponibile.';

  @override
  String get signInToEditTasks => 'Accedi per modificare le attività.';

  @override
  String get refreshTask => 'Aggiorna attività';

  @override
  String get primarySection => 'Principale';

  @override
  String get statusSection => 'Stato';

  @override
  String get openStatus => 'Aperta';

  @override
  String get doneStatus => 'Completata';

  @override
  String get taskStatus => 'Stato';

  @override
  String get taskStatusNone => 'Nessuno stato';

  @override
  String get taskStatusNeedsAction => 'Richiede azione';

  @override
  String get taskStatusInProcess => 'In corso';

  @override
  String get taskStatusCompleted => 'Completata';

  @override
  String get taskStatusCancelled => 'Annullata';

  @override
  String completionPercent(int percent) {
    return '$percent% completata';
  }

  @override
  String get completionDate => 'Data di completamento';

  @override
  String get priority => 'Priorità';

  @override
  String get priorityNone => 'Nessuna priorità';

  @override
  String priorityHighValue(int priority) {
    return 'Priorità $priority · alta';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Priorità $priority · media';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Priorità $priority · bassa';
  }

  @override
  String get taskUrl => 'URL dell’attività';

  @override
  String get invalidTaskUrl => 'Inserisci un URL assoluto, incluso lo schema.';

  @override
  String get classification => 'Classificazione';

  @override
  String get classificationPublic =>
      'Quando condivisa, mostra l’attività completa';

  @override
  String get classificationConfidential =>
      'Quando condivisa, mostra solo lo stato occupato';

  @override
  String get classificationPrivate =>
      'Quando condivisa, nascondi questa attività';

  @override
  String get pinTask => 'Fissa attività';

  @override
  String get notes => 'Note';

  @override
  String get dueDate => 'Data di scadenza';

  @override
  String get clearDueDate => 'Cancella data di scadenza';

  @override
  String get dueTime => 'Ora di scadenza';

  @override
  String get startDate => 'Data di inizio';

  @override
  String get startTime => 'Ora di inizio';

  @override
  String get endDate => 'Data di fine';

  @override
  String get endTime => 'Ora di fine';

  @override
  String get reminderDate => 'Data del promemoria';

  @override
  String get reminderTime => 'Ora del promemoria';

  @override
  String get reminder => 'Promemoria';

  @override
  String get addReminder => 'Aggiungi promemoria';

  @override
  String get reminders => 'Promemoria';

  @override
  String get noReminders => 'Nessun promemoria';

  @override
  String get editReminder => 'Modifica promemoria';

  @override
  String get beforeTaskStarts => 'Prima dell’inizio dell’attività';

  @override
  String get beforeTaskDue => 'Prima della scadenza dell’attività';

  @override
  String get afterTaskStarts => 'Dopo l’inizio dell’attività';

  @override
  String get afterTaskDue => 'Dopo la scadenza dell’attività';

  @override
  String get relativeToTaskStart =>
      'Rispetto alla data di inizio dell’attività';

  @override
  String get relativeToTaskDue =>
      'Rispetto alla data di scadenza dell’attività';

  @override
  String get reminderTimeOfDay => 'Ora del giorno';

  @override
  String get absoluteReminder => 'A una data e un’ora';

  @override
  String get reminderAmount => 'Quantità';

  @override
  String get reminderUnit => 'Unità';

  @override
  String get reminderUnitSeconds => 'Secondi';

  @override
  String get reminderUnitMinutes => 'Minuti';

  @override
  String get reminderUnitHours => 'Ore';

  @override
  String get reminderUnitDays => 'Giorni';

  @override
  String get reminderUnitWeeks => 'Settimane';

  @override
  String get reminderAtTaskStart => 'All’inizio dell’attività';

  @override
  String get reminderAtTaskDue => 'Alla scadenza dell’attività';

  @override
  String get unsupportedReminder =>
      'Questo tipo di promemoria viene conservato, ma non è possibile modificarne l’ora.';

  @override
  String get relatedRemindersTitle => 'Conservare i promemoria correlati?';

  @override
  String relatedRemindersDescription(int count) {
    return 'Questa data ha $count promemoria correlati. Conservarli alla data e all’ora attuali?';
  }

  @override
  String get discardRelatedReminders => 'Scarta promemoria';

  @override
  String get keepRelatedReminders => 'Conserva promemoria';

  @override
  String get addGuest => 'Aggiungi invitato';

  @override
  String get addGuestEmail => 'Aggiungi email dell’invitato';

  @override
  String get removeReminder => 'Rimuovi promemoria';

  @override
  String get off => 'Disattivato';

  @override
  String get repeat => 'Ripeti';

  @override
  String get repeatNone => 'Nessuna ripetizione';

  @override
  String get noneValue => 'Nessuno';

  @override
  String get repeatDaily => 'Ogni giorno';

  @override
  String get repeatWeekly => 'Ogni settimana';

  @override
  String get repeatMonthly => 'Ogni mese';

  @override
  String get repeatYearly => 'Ogni anno';

  @override
  String get repeatEvery => 'Intervallo';

  @override
  String get repeatOn => 'Ripeti il';

  @override
  String get repeatEnd => 'Termina ripetizione';

  @override
  String get repeatNever => 'Mai';

  @override
  String get repeatUntil => 'In data';

  @override
  String get repeatAfter => 'Dopo un numero di occorrenze';

  @override
  String get repeatCount => 'Occorrenze';

  @override
  String get repeatDayOfMonth => 'Giorni del mese';

  @override
  String get repeatMonths => 'Mesi';

  @override
  String get repeatOrdinal => 'Posizione del giorno della settimana';

  @override
  String get repeatSpecificDays => 'Giorni specifici';

  @override
  String get repeatFirst => 'Primo';

  @override
  String get repeatSecond => 'Secondo';

  @override
  String get repeatThird => 'Terzo';

  @override
  String get repeatFourth => 'Quarto';

  @override
  String get repeatFifth => 'Quinto';

  @override
  String get repeatSecondToLast => 'Penultimo';

  @override
  String get repeatLast => 'Ultimo';

  @override
  String get repeatAnyDay => 'Giorno';

  @override
  String get repeatWeekday => 'Giorno feriale';

  @override
  String get repeatWeekendDay => 'Giorno del fine settimana';

  @override
  String repeatEveryDays(int count) {
    return 'Ogni $count giorni';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'Ogni $count settimane';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'Ogni $count mesi';
  }

  @override
  String repeatEveryYears(int count) {
    return 'Ogni $count anni';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'il $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'il giorno $days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'il primo $days',
      'second': 'il secondo $days',
      'third': 'il terzo $days',
      'fourth': 'il quarto $days',
      'fifth': 'il quinto $days',
      'secondToLast': 'il penultimo $days',
      'last': 'l’ultimo $days',
      'other': 'nei giorni $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'nei mesi $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count volte';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'fino al $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Questa regola di ricorrenza usa opzioni che questo editor non modifica.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Questa ricorrenza non può essere usata con $provider.';
  }

  @override
  String get importance => 'Importanza';

  @override
  String get importanceLow => 'Bassa';

  @override
  String get importanceNormal => 'Normale';

  @override
  String get importanceHigh => 'Alta';

  @override
  String get categories => 'Categorie';

  @override
  String get scheduleSection => 'Programmazione';

  @override
  String get dueGroup => 'Scadenza';

  @override
  String get startGroup => 'Inizio';

  @override
  String get reminderGroup => 'Promemoria';

  @override
  String get organizationSection => 'Organizzazione';

  @override
  String get actionsSection => 'Azioni';

  @override
  String get advancedSection => 'Avanzate';

  @override
  String get addCategory => 'Aggiungi categoria';

  @override
  String get list => 'Elenco';

  @override
  String get microsoftMoveUnsupported =>
      'In questa versione non è possibile spostare attività tra elenchi negli account Microsoft To Do.';

  @override
  String get createSubtask => 'Crea sottoattività';

  @override
  String get subtasks => 'Sottoattività';

  @override
  String get duplicateTask => 'Duplica attività';

  @override
  String get taskDuplicated => 'Attività duplicata.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Impossibile duplicare l’attività: $error';
  }

  @override
  String get hideSubtasks => 'Nascondi sottoattività';

  @override
  String get hideClosedSubtasks => 'Nascondi sottoattività chiuse';

  @override
  String get moveToTop => 'Sposta in cima';

  @override
  String get deleteTask => 'Elimina attività';

  @override
  String get newSubtask => 'Nuova sottoattività';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Eliminare «$title»?';
  }

  @override
  String get metadata => 'Metadati';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Aggiornato';

  @override
  String get parent => 'Attività principale';

  @override
  String get position => 'Posizione';

  @override
  String get webLink => 'Collegamento web';

  @override
  String get assignment => 'Assegnazione';

  @override
  String get localState => 'Stato locale';

  @override
  String get pendingSync => 'Sincronizzazione in sospeso';

  @override
  String get synced => 'Sincronizzato';

  @override
  String get account => 'Profilo';

  @override
  String get sync => 'Sincronizzazione';

  @override
  String get manualFullSync => 'Sincronizzazione completa manuale';

  @override
  String get runInBackgroundWhenClosed =>
      'Continua a funzionare quando la finestra è chiusa';

  @override
  String get showTrayIcon => 'Mostra icona nell’area di notifica';

  @override
  String get startMinimizedToTray =>
      'Avvia ridotto a icona nell’area di notifica';

  @override
  String get launchAtLogin => 'Avvia all’accesso';

  @override
  String get launchAtLoginDescription =>
      'Avvia BusyMax in background affinché i promemoria funzionino dopo l’accesso.';

  @override
  String get launchAtLoginFailed =>
      'Impossibile aggiornare l’avvio all’accesso.';

  @override
  String get requiresTrayIcon => 'Richiede l’icona nell’area di notifica.';

  @override
  String get syncComplete => 'Sincronizzazione completata.';

  @override
  String syncFailed(String error) {
    return 'Sincronizzazione non riuscita: $error';
  }

  @override
  String get notifySyncFailures =>
      'Notifiche in caso di errore di sincronizzazione';

  @override
  String get notifyConflicts => 'Notifiche in caso di conflitto';

  @override
  String get notifyDueToday => 'Notifiche per attività in scadenza oggi';

  @override
  String get eventReminders => 'Promemoria degli eventi';

  @override
  String get onState => 'Attivato';

  @override
  String get taskReminders => 'Promemoria delle attività';

  @override
  String get notificationDetailLevel => 'Livello di dettaglio delle notifiche';

  @override
  String get notificationDetailPrivate => 'Privato';

  @override
  String get notificationDetailNormal => 'Normale';

  @override
  String get quietHours => 'Ore di silenzio';

  @override
  String get quietHoursDescription =>
      'Sospendi le notifiche durante questo periodo.';

  @override
  String get quietHoursStart => 'Inizio delle ore di silenzio';

  @override
  String get quietHoursEnd => 'Fine delle ore di silenzio';

  @override
  String get notifications => 'Notifiche';

  @override
  String get appearance => 'Aspetto';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeFamily => 'Famiglia di temi';

  @override
  String get themeFamilyYaru => 'Tema nativo di Ubuntu (Yaru)';

  @override
  String get localization => 'Lingua e area geografica';

  @override
  String get currentLocale => 'Impostazioni locali correnti';

  @override
  String get privacy => 'Riservatezza';

  @override
  String get redactTaskContentInDiagnostics =>
      'Nascondi il contenuto delle attività nelle informazioni diagnostiche';

  @override
  String get developerDiagnostics => 'Diagnostica per sviluppatori';

  @override
  String get diagnostics => 'Diagnostica';

  @override
  String get apiInspectorDisabled => 'Mostra l’ispettore API';

  @override
  String get googleTasksApi => 'API Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Revisione Discovery: $revision';
  }

  @override
  String get implementedMethods => 'Metodi implementati';

  @override
  String get supportsTasksScopes =>
      'Supporta gli ambiti tasks e tasks.readonly';

  @override
  String get requiresTasksScope => 'Richiede l’ambito tasks';

  @override
  String get blockedPendingOperations => 'Operazioni in sospeso bloccate';

  @override
  String get signInToInspectPendingOperations =>
      'Accedi per esaminare le operazioni in sospeso.';

  @override
  String get noBlockedPendingOperations =>
      'Nessuna operazione in sospeso bloccata.';

  @override
  String get operationActions => 'Azioni dell’operazione';

  @override
  String pendingOpListId(String id) {
    return 'elenco=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'attività=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'tentativi=$count';
  }

  @override
  String get retry => 'Riprova';

  @override
  String get discard => 'Scarta';

  @override
  String get discardChangesAction => 'Scarta';

  @override
  String get discardChanges => 'Scartare le modifiche?';

  @override
  String get discardChangesConfirmation =>
      'Questa azione scarta le modifiche non salvate dell’attività.';

  @override
  String get retryCompleted => 'Nuovo tentativo completato.';

  @override
  String get discardPendingOperation => 'Scartare l’operazione in sospeso?';

  @override
  String get discardPendingOperationConfirmation =>
      'Questa azione rimuove l’operazione locale bloccata. Alla prossima sincronizzazione, i dati verranno ricaricati da Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Operazione in sospeso scartata.';

  @override
  String get syncFailureNotificationTitle =>
      'Sincronizzazione di BusyMax non riuscita';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Sincronizzazione in background non riuscita. $message';
  }

  @override
  String get conflictNotificationTitle =>
      'Conflitto di sincronizzazione di BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Una modifica locale in sospeso è stata bloccata. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Attività in scadenza oggi';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attività scadono oggi.',
      one: 'Un’attività scade oggi.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Promemoria evento';

  @override
  String get taskReminderNotificationTitle => 'Promemoria attività';

  @override
  String get eventReminderNotificationBody => 'L’evento inizierà a breve.';

  @override
  String get taskReminderNotificationBody => 'L’attività scadrà a breve.';

  @override
  String get notificationOpenAction => 'Apri';

  @override
  String get notificationSnoozeAction => 'Posticipa di 10 minuti';

  @override
  String get notificationDismissAction => 'Chiudi';

  @override
  String get notificationDetailsHidden =>
      'I dettagli sono nascosti dalle impostazioni sulla privacy.';

  @override
  String get previousMonth => 'Mese precedente';

  @override
  String get nextMonth => 'Mese successivo';

  @override
  String get openMonthView => 'Apri vista mensile';

  @override
  String get previousYear => 'Anno precedente';

  @override
  String get nextYear => 'Anno successivo';

  @override
  String get openYearView => 'Apri vista annuale';

  @override
  String weekNumberTooltip(int number) {
    return 'Settimana $number';
  }

  @override
  String get resizeAllDayPanel =>
      'Ridimensiona il pannello per l’intera giornata';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Questo calendario è di sola lettura.';

  @override
  String get selectTimeZone => 'Seleziona fuso orario';

  @override
  String get searchLocations => 'Cerca località';

  @override
  String get noLocationsFound => 'Nessuna località trovata';

  @override
  String get requiredField => 'Questo campo è obbligatorio.';

  @override
  String get providerConnectionDescription =>
      'Collega calendari e attività a uno di questi provider.';

  @override
  String get appleICloudProvider => 'Calendario Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Attività Nextcloud';

  @override
  String get addAppleICloudAccount =>
      'Aggiungi account Calendario Apple iCloud';

  @override
  String get addNextcloudAccount => 'Aggiungi account Nextcloud';

  @override
  String get waitingForAppleICloud => 'Connessione ad Apple iCloud…';

  @override
  String get waitingForNextcloud => 'In attesa dell’autorizzazione Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Collega Calendario Apple iCloud';

  @override
  String get appleAccountEmail => 'E-mail dell’account Apple';

  @override
  String get appleAppSpecificPassword => 'Password specifica per l’app';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Crea una password specifica per l’app dopo aver attivato l’autenticazione a due fattori per il tuo account Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'La reimpostazione della password dell’account Apple revoca le password specifiche per le app.';

  @override
  String get connectNextcloudTitle => 'Collega Nextcloud';

  @override
  String get nextcloudServerUrl => 'Server Nextcloud o indirizzo CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Inserisci l’URL del server Nextcloud o incolla l’indirizzo CalDAV principale copiato da Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax aprirà il browser. Approva l’accesso e torna a BusyMax.';

  @override
  String get connectAccountAction => 'Collega';

  @override
  String get cancelAccountConnection => 'Annulla connessione';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'L’account è stato rimosso localmente, ma non è stato possibile revocare la password dell’app Nextcloud.';

  @override
  String get davCachedOfflineNotice =>
      'I dati di calendari e attività vengono memorizzati localmente per l’uso offline.';

  @override
  String get davReauthenticationRequired =>
      'Ricollega questo account per riprendere la sincronizzazione.';

  @override
  String get davTemporarilyUnavailable =>
      'Questo account è temporaneamente non disponibile.';

  @override
  String get davPermissionChanged =>
      'Le autorizzazioni del server sono cambiate. Le modifiche in sospeso sono in pausa.';

  @override
  String get davUnsupportedServer =>
      'Questo server o profilo provider non è supportato.';

  @override
  String get collectionSettings => 'Calendari ed elenchi di attività';

  @override
  String get calendarContent => 'Eventi del calendario';

  @override
  String get taskContent => 'Attività';

  @override
  String get readOnlySharedCollection => 'Sola lettura';

  @override
  String get pendingLocally => 'In sospeso localmente';

  @override
  String get conflictBlocked => 'Bloccato da un conflitto';

  @override
  String get authenticationBlocked => 'Bloccato fino alla riconnessione';

  @override
  String get operationFailed => 'Operazione non riuscita';

  @override
  String get keepServerVersion => 'Mantieni la versione del server';

  @override
  String get reapplyLocalChange => 'Esamina e riapplica la modifica locale';

  @override
  String get duplicateLocalItem => 'Duplica come nuovo elemento';

  @override
  String get davConnectionState => 'Stato della connessione';

  @override
  String get davConnected => 'Connesso';

  @override
  String get davConnecting => 'Connessione…';

  @override
  String get davSignedOut => 'Disconnesso';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Ultima sincronizzazione riuscita: $time';
  }

  @override
  String get davNeverSynced => 'Non ancora sincronizzato';

  @override
  String get refreshCollections => 'Aggiorna calendari ed elenchi di attività';

  @override
  String nextcloudServerHost(String host) {
    return 'Indirizzo server: $host';
  }

  @override
  String get collectionSupportsEvents => 'Calendario eventi';

  @override
  String get collectionSupportsTasks => 'Elenco di attività';

  @override
  String get collectionSupportsEventsAndTasks => 'Eventi e attività';

  @override
  String get writableCollection => 'Scrivibile';

  @override
  String get sharedCollection => 'Condiviso';

  @override
  String collectionLastSynced(String time) {
    return 'Ultima sincronizzazione: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Problema di sincronizzazione: $code';
  }

  @override
  String get syncConflicts => 'Conflitti di sincronizzazione';

  @override
  String remoteChangedAt(String time) {
    return 'Modifica del server: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Modifica locale: $summary';
  }

  @override
  String get conflictResolutionFailed => 'Impossibile risolvere il conflitto.';

  @override
  String get recurringEventScope => 'Ambito dell’evento ricorrente';

  @override
  String get entireSeries => 'Intera serie';

  @override
  String get singleOccurrence => 'Questo evento';

  @override
  String get thisAndFollowingEvents => 'Questo evento e quelli successivi';

  @override
  String get thisAndFutureUnavailable => 'Non supportato da questo provider.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Questo evento e quelli successivi non possono essere spostati in modo sicuro. Scegli questo evento o l’intera serie.';

  @override
  String get entireSeriesMoveUnavailable =>
      'La regola di ricorrenza non è disponibile localmente. Sposta invece solo questo evento.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Copiare l’evento ed eliminare l’originale?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax non può spostare direttamente questo evento da $source a $destination. Creerà prima la copia ed eliminerà l’originale solo dopo che la copia sarà riuscita. Gli ID dell’evento cambieranno; gli stati di risposta dei partecipanti potrebbero essere reimpostati e potrebbero essere inviati inviti o annullamenti; i link alle riunioni, gli allegati, i promemoria, i campi specifici del provider e le eccezioni di ricorrenza potrebbero non essere trasferiti.';
  }

  @override
  String get copyAndDelete => 'Copia ed elimina';

  @override
  String get chooseRecurringEventScope =>
      'Scegli se questa modifica si applica all’intera serie, solo a questo evento oppure a questo e agli eventi successivi.';

  @override
  String get taskDueBeforeStart => 'La scadenza non può precedere l\'inizio.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Imposta un orario sia per l’inizio sia per la scadenza, oppure rendi l’attività valida per l’intera giornata.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Eliminare «$title»?';
  }

  @override
  String get setCustomCalendarName => 'Imposta nome personalizzato';

  @override
  String get setAction => 'Imposta';

  @override
  String get removeFromMyCalendars => 'Rimuovi dai miei calendari';

  @override
  String get removeAction => 'Rimuovi';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Rimuovere \"$title\" dall\'elenco di Google Calendar? Il calendario condiviso e i relativi eventi non verranno eliminati.';
  }

  @override
  String get calendarCannotRemove =>
      'Non è possibile eliminare o rimuovere questo calendario da questo account.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Attendi il completamento della sincronizzazione delle modifiche in sospeso del calendario prima di eliminarlo o rimuoverlo.';

  @override
  String get calendarSubscriptions => 'Abbonamenti ai calendari';

  @override
  String get calendarSubscriptionsDescription =>
      'Aggiungi calendari di sola lettura che si aggiornano da un URL WebCal sicuro.';

  @override
  String get addCalendarSubscription => 'Aggiungi abbonamento al calendario';

  @override
  String get subscriptionName => 'Nome locale';

  @override
  String get subscriptionUrl => 'URL abbonamento';

  @override
  String get subscriptionUrlHelp =>
      'Inserisci un URL HTTPS o webcal. BusyMax conserva l’URL completo in un archivio sicuro.';

  @override
  String get subscriptionUrlInvalid =>
      'Inserisci un URL HTTPS o webcal valido senza informazioni utente o frammento.';

  @override
  String get subscriptionColor => 'Colore locale';

  @override
  String get subscriptionColorHelp => 'Usa un colore a sei cifre come #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Inserisci un colore esadecimale di sei cifre.';

  @override
  String get subscriptionRefreshMode => 'Frequenza di aggiornamento';

  @override
  String get subscriptionAutomatic => 'Automatica';

  @override
  String get subscriptionHourly => 'Ogni ora';

  @override
  String get subscriptionSixHours => 'Ogni sei ore';

  @override
  String get subscriptionDaily => 'Ogni giorno';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Origine: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Inserisci un URL valido per visualizzarne l’origine sicura.';

  @override
  String get subscriptionReadOnly => 'Abbonamento di sola lettura';

  @override
  String get subscriptionNeverRefreshed => 'Non ancora aggiornato';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Ultimo aggiornamento riuscito: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Prossimo aggiornamento: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Aggiornato';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Problema di aggiornamento: $code';
  }

  @override
  String get refreshNow => 'Aggiorna ora';

  @override
  String get unsubscribe => 'Annulla abbonamento';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Annullare l’abbonamento a “$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Rimuove l’abbonamento locale e gli eventi memorizzati nella cache. Il calendario pubblicato non cambia.';

  @override
  String get addSubscriptionAction => 'Aggiungi abbonamento';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Abbonamento al calendario non riuscito: $error';
  }

  @override
  String get subscriptions => 'Abbonamenti';

  @override
  String get calendarImport => 'Importazione calendario';

  @override
  String get calendarImportDescription =>
      'Seleziona un file, rivedi gli eventi e scegli il calendario scrivibile che deve riceverli.';

  @override
  String get importIcsFile => 'Importa file .ics';

  @override
  String get importIcsPreview => 'Importa eventi del calendario';

  @override
  String importEventsFound(int count) {
    return 'Insiemi di eventi importabili: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Eventi non validi: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Ommessi intenzionalmente: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Nessun calendario di destinazione scrivibile disponibile.';

  @override
  String get importDestinationCalendar => 'Calendario di destinazione';

  @override
  String get importIcsConfirm => 'Importa eventi';

  @override
  String get importIcsComplete => 'Importazione completata';

  @override
  String importQueued(int count) {
    return 'Importati o accodati: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Duplicati ignorati: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Insiemi di ricorrenze non supportati: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Impossibile importare il file del calendario: $error';
  }

  @override
  String get networkOffline => 'Senza connessione';

  @override
  String get networkOfflineDescription =>
      'Le modifiche verranno sincronizzate al ripristino della connessione.';

  @override
  String get networkOfflineTryAgain =>
      'Sei offline. Connettiti a Internet e riprova.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'i giorni $days';
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
    return '$frequency il giorno $day di $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency nei giorni $days di $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency il giorno $day di $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency nei giorni $days di $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'il primo $days di $month',
      'second': 'il secondo $days di $month',
      'third': 'il terzo $days di $month',
      'fourth': 'il quarto $days di $month',
      'fifth': 'il quinto $days di $month',
      'secondToLast': 'il penultimo $days di $month',
      'last': 'l’ultimo $days di $month',
      'other': 'nei giorni $days di $month',
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
      'first': 'il primo $days di $months',
      'second': 'il secondo $days di $months',
      'third': 'il terzo $days di $months',
      'fourth': 'il quarto $days di $months',
      'fifth': 'il quinto $days di $months',
      'secondToLast': 'il penultimo $days di $months',
      'last': 'l’ultimo $days di $months',
      'other': 'nei giorni $days di $months',
    });
    return '$frequency $_temp0';
  }
}

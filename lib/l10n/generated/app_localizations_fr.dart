// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Connect Google, Microsoft, Apple iCloud Calendar, or Nextcloud accounts.';

  @override
  String get googlePermissionsConsentNotice =>
      'Sur l’écran d’autorisations Google, sélectionnez les autorisations Calendrier et Tâches.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Les autorisations Google Calendar et Google Tasks sont requises. Réessayez et sélectionnez les deux cases.';

  @override
  String get finishSetup => 'Terminer la configuration';

  @override
  String get continueSetup => 'Continuer';

  @override
  String get onboardingSetupTitle => 'Configurer BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Connecter des comptes';

  @override
  String get onboardingAccountsStepDescription =>
      'Add every account you want to use. BusyMax syncs supported calendars, events, task lists, and tasks from each account.';

  @override
  String get onboardingPreferencesStepTitle => 'Choisir les paramètres système';

  @override
  String get onboardingPreferencesStepDescription =>
      'Réglez le comportement de l’application sur le bureau, les rappels, le niveau de détail des notifications et l’apparence avant d’ouvrir votre planning.';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get signInWithMicrosoft => 'Se connecter avec Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Ce fournisseur n’est pas configuré.';

  @override
  String get waitingForGoogleSignIn => 'En attente de la connexion Google...';

  @override
  String get waitingForMicrosoftSignIn =>
      'En attente de la connexion Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'La connexion Microsoft n’est pas configurée. Définissez MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get exit => 'Quitter';

  @override
  String get options => 'Options';

  @override
  String get hide => 'Masquer';

  @override
  String get show => 'Afficher';

  @override
  String get export => 'Exporter';

  @override
  String get save => 'Enregistrer';

  @override
  String get settings => 'Paramètres';

  @override
  String get all => 'Tout';

  @override
  String get calendarEvents => 'Événements';

  @override
  String get calendarTasks => 'Tâches';

  @override
  String get calendar => 'Calendrier';

  @override
  String get calendars => 'Calendriers';

  @override
  String get newCalendar => 'Nouveau calendrier';

  @override
  String get calendarColor => 'Couleur du calendrier';

  @override
  String calendarColorOption(int number) {
    return 'Couleur $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Ce fournisseur ne prend pas en charge la gestion des calendriers dans BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'Le calendrier principal ne peut pas être supprimé.';

  @override
  String calendarCreateFailed(String error) {
    return 'Impossible de créer le calendrier : $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'Le calendrier a été créé, mais BusyMax n’a pas pu actualiser le compte. Il apparaîtra après la prochaine synchronisation.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Impossible de mettre à jour le calendrier : $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Impossible de supprimer le calendrier : $error';
  }

  @override
  String get newEvent => 'Nouvel événement';

  @override
  String get refreshCalendar => 'Actualiser le calendrier';

  @override
  String get openInProvider => 'Ouvrir dans le service';

  @override
  String get hideFromSchedule => 'Masquer du planning';

  @override
  String get showInSchedule => 'Afficher dans le planning';

  @override
  String get noCalendarsSynced => 'Aucun calendrier synchronisé.';

  @override
  String get allDay => 'Toute la journée';

  @override
  String moreItems(int count) {
    return '+$count de plus';
  }

  @override
  String get noEventsOrTasks => 'Aucun événement ni tâche';

  @override
  String get scheduleLoading => 'Chargement du planning...';

  @override
  String get scheduleUnavailable => 'Planning indisponible';

  @override
  String get scheduleNoSources => 'Aucun calendrier ni liste de tâches visible';

  @override
  String get scheduleNoSourcesDescription =>
      'Choisissez les éléments à afficher dans les paramètres, puis actualisez.';

  @override
  String get scheduleSignInRequired => 'Connecter un compte';

  @override
  String get scheduleSignInDescription =>
      'Connectez-vous pour synchroniser vos calendriers et vos tâches.';

  @override
  String get scheduleNoSearchResults =>
      'Aucun événement ni aucune tâche ne correspond';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Essayez une autre recherche ou effacez les filtres actuels.';

  @override
  String get refresh => 'Actualiser';

  @override
  String get trayOpenBusyMax => 'Ouvrir BusyMax';

  @override
  String get trayShowBusyMax => 'Show BusyMax';

  @override
  String get trayNewEvent => 'New event…';

  @override
  String get trayNewTask => 'New task…';

  @override
  String get trayToday => 'Today';

  @override
  String get trayAllDay => 'All day';

  @override
  String get trayNow => 'Now';

  @override
  String get trayCalendarEvent => 'Calendar event';

  @override
  String get trayUntitledEvent => 'Untitled event';

  @override
  String get trayNothingElseToday => 'Nothing else today';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks due today',
      one: '1 task due today',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Open today’s agenda';

  @override
  String get traySyncNow => 'Sync now';

  @override
  String get traySyncing => 'Syncing…';

  @override
  String get trayNotConnected => 'Not connected';

  @override
  String get trayNotYetSynced => 'Not yet synced';

  @override
  String get trayLastSyncedJustNow => 'Last synced just now';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $count minutes ago',
      one: 'Last synced 1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $count hours ago',
      one: 'Last synced 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last synced $count days ago',
      one: 'Last synced 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Settings';

  @override
  String get trayQuitBusyMax => 'Quit BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Charger plus de tâches en retard';

  @override
  String get agendaLoadMoreNoDate => 'Charger plus de tâches sans date';

  @override
  String get viewDay => 'Jour';

  @override
  String get viewWeek => 'Semaine';

  @override
  String get viewMonth => 'Mois';

  @override
  String get viewYear => 'Année';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get scheduleSettings => 'Planning';

  @override
  String get scheduleDisplaySettings => 'Affichage du planning';

  @override
  String get scheduleDisplayHoursDescription =>
      'Les vues Jour et Semaine s’ouvrent dans cette plage horaire. Les éléments situés avant ou après cette plage l’étendent si nécessaire.';

  @override
  String get scheduleDayStartsAt => 'La journée commence à';

  @override
  String get scheduleDayEndsAt => 'La journée se termine à';

  @override
  String get sourceCalendar => 'Calendrier';

  @override
  String get sourceTaskList => 'Liste de tâches';

  @override
  String get createChoiceTitle => 'Créer';

  @override
  String get createEventAtTime => 'Événement';

  @override
  String get createTaskAtDate => 'Tâche';

  @override
  String get editEvent => 'Modifier l’événement';

  @override
  String get eventTitle => 'Titre de l’événement';

  @override
  String get location => 'Lieu';

  @override
  String get timeSlot => 'Créneau';

  @override
  String get startDateTime => 'Date/heure de début';

  @override
  String get endDateTime => 'Date/heure de fin';

  @override
  String get doesNotRepeat => 'Ne se répète pas';

  @override
  String get defaultReminder => 'Rappel par défaut';

  @override
  String get guests => 'Invités';

  @override
  String get noGuests => 'Aucun invité';

  @override
  String get attendeeRequired => 'Required';

  @override
  String get attendeeOptional => 'Optional';

  @override
  String get meetingSection => 'Meeting';

  @override
  String get addGoogleMeet => 'Add Google Meet';

  @override
  String get addTeamsMeeting => 'Add Microsoft Teams meeting';

  @override
  String get onlineMeetingAdded => 'Online meeting added';

  @override
  String get requestResponses => 'Request responses';

  @override
  String get requestResponsesDescription =>
      'Ask guests to respond to the invitation.';

  @override
  String get hideGuestList => 'Hide guest list';

  @override
  String get hideGuestListDescription =>
      'Guests cannot see who else was invited.';

  @override
  String get allowNewTimeProposals => 'Allow new time proposals';

  @override
  String get allowNewTimeProposalsDescription =>
      'Guests can suggest a different meeting time.';

  @override
  String get notifyGuestsTitle => 'Notify guests?';

  @override
  String get notifyGuestsSaveMessage =>
      'This meeting has guests. Send invitations or event updates when it is saved?';

  @override
  String get notifyGuestsDeleteMessage =>
      'This meeting has guests. Send a cancellation when it is deleted?';

  @override
  String get sendUpdates => 'Send updates';

  @override
  String get sendCancellation => 'Send cancellation';

  @override
  String get doNotSend => 'Don’t send';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Save meeting?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft will send invitations or event updates to guests.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Delete meeting?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft will send a cancellation to guests.';

  @override
  String get organizer => 'Organizer';

  @override
  String get yourResponse => 'Your response';

  @override
  String get guestResponses => 'Guest responses';

  @override
  String get respond => 'Respond';

  @override
  String get acceptInvitation => 'Accept';

  @override
  String get tentativeInvitation => 'Tentative';

  @override
  String get declineInvitation => 'Decline';

  @override
  String get joinMeeting => 'Join meeting';

  @override
  String get responseAccepted => 'Accepted';

  @override
  String get responseTentative => 'Tentative';

  @override
  String get responseDeclined => 'Declined';

  @override
  String get responseNeedsAction => 'Awaiting response';

  @override
  String get responseNotResponded => 'Not responded';

  @override
  String get responseOrganizer => 'Organizer';

  @override
  String invitationResponseFailed(String error) {
    return 'Could not send your response: $error';
  }

  @override
  String get joinMeetingFailed => 'Could not open the meeting link.';

  @override
  String get description => 'Description';

  @override
  String get availabilityShowAs => 'Disponibilité / Afficher comme';

  @override
  String get busy => 'Occupé';

  @override
  String get visibility => 'Visibilité';

  @override
  String get defaultVisibility => 'Visibilité par défaut';

  @override
  String get conference => 'Conférence';

  @override
  String get noConference => 'Aucune conférence';

  @override
  String get providerCalendar => 'Calendrier du fournisseur';

  @override
  String get formatBoldShortLabel => 'G';

  @override
  String get formatBoldTooltip => 'Gras';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'Italique';

  @override
  String get formatUnderlineShortLabel => 'S';

  @override
  String get formatUnderlineTooltip => 'Souligné';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes avant',
      one: '1 minute avant',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'À l’heure de début';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours heures avant',
      one: '1 heure avant',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours avant',
      one: '1 jour avant',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Disponible';

  @override
  String get availabilityTentative => 'Provisoire';

  @override
  String get availabilityOutOfOffice => 'Absent du bureau';

  @override
  String get availabilityWorkingElsewhere => 'Travail ailleurs';

  @override
  String get visibilityDefault => 'Par défaut';

  @override
  String get visibilityPublic => 'Publique';

  @override
  String get visibilityPrivate => 'Privée';

  @override
  String get visibilityConfidential => 'Confidentielle';

  @override
  String get sensitivityNormal => 'Normale';

  @override
  String get sensitivityPersonal => 'Personnelle';

  @override
  String get tasks => 'Tâches';

  @override
  String get allTasks => 'Toutes les tâches';

  @override
  String tasksInList(String title) {
    return 'Tâches dans $title';
  }

  @override
  String get taskLists => 'Listes de tâches';

  @override
  String get navigation => 'Navigation';

  @override
  String get mainMenu => 'Menu principal';

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get shortcutGroupGeneral => 'Général';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Afficher cette liste de raccourcis';

  @override
  String get shortcutGroupNavigation => 'Navigation';

  @override
  String get shortcutNextPeriod => 'Période suivante';

  @override
  String get shortcutNextPeriodDescription =>
      'Semaine suivante en vue semaine, mois suivant en vue mois, etc.';

  @override
  String get shortcutPreviousPeriod => 'Période précédente';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Semaine précédente en vue semaine, mois précédent en vue mois, etc.';

  @override
  String get shortcutJumpToToday => 'Aller à la date du jour';

  @override
  String get shortcutGroupView => 'Affichage';

  @override
  String get shortcutDayView => 'Vue jour';

  @override
  String get shortcutWeekView => 'Vue semaine';

  @override
  String get shortcutMonthView => 'Vue mois';

  @override
  String get shortcutYearView => 'Vue année';

  @override
  String get shortcutAgendaView => 'Vue agenda';

  @override
  String get shortcutGroupCreateAndEdit => 'Créer et modifier';

  @override
  String get shortcutSaveItem => 'Enregistrer l\'événement ou la tâche';

  @override
  String get shortcutDeleteItem => 'Supprimer l\'événement ou la tâche';

  @override
  String get shortcutGroupTaskEditing => 'Modification des tâches';

  @override
  String get shortcutCancelEditing => 'Annuler la modification';

  @override
  String get shortcutCancelEditingDescription =>
      'Fermer la modification ou les détails de la tâche';

  @override
  String get aboutBusyMax => 'À propos de BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Calendrier et tâches';

  @override
  String get license => 'Licence';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Site web';

  @override
  String get sourceCode => 'Code source';

  @override
  String get reportAnIssue => 'Signaler un problème';

  @override
  String get sendFeedback => 'Envoyer des commentaires';

  @override
  String get feedbackSubmit => 'Envoyer';

  @override
  String get feedbackCategory => 'Catégorie';

  @override
  String get feedbackSelectCategory => 'Sélectionnez une catégorie';

  @override
  String get feedbackCategoryProblem => 'Problème ou bug';

  @override
  String get feedbackCategoryFeature => 'Demande de fonctionnalité';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Problème de confidentialité ou de sécurité';

  @override
  String get feedbackCategoryUsability => 'Problème d’ergonomie';

  @override
  String get feedbackCategoryOther => 'Autre';

  @override
  String get feedbackSubject => 'Objet';

  @override
  String get feedbackDetailedMessage => 'Message détaillé';

  @override
  String get feedbackReplyEmail => 'Adresse e-mail de réponse (facultatif)';

  @override
  String get feedbackIncludeTechnicalDetails =>
      'Inclure les détails techniques';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Ajoute uniquement la version de votre système d’exploitation Linux et la langue de l’application. Aucun journal, aucune donnée de compte, aucun nom de fichier ni autre diagnostic n’est inclus.';

  @override
  String get feedbackCategoryRequired => 'Sélectionnez une catégorie.';

  @override
  String get feedbackSubjectLengthError =>
      'L’objet doit comporter entre 3 et 120 caractères.';

  @override
  String get feedbackMessageLengthError =>
      'Le message doit comporter entre 10 et 5 000 caractères.';

  @override
  String get feedbackInvalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get feedbackConnectionError =>
      'Impossible de se connecter à BusyStack. Vérifiez votre connexion et réessayez.';

  @override
  String get feedbackTimeoutError =>
      'La demande a expiré. Vos commentaires n’ont pas été effacés ; réessayez.';

  @override
  String get feedbackRateLimitedError =>
      'Trop de commentaires ont été envoyés depuis ce réseau. Patientez, puis réessayez.';

  @override
  String get feedbackRejectedError =>
      'Le serveur a rejeté l’envoi. Vérifiez les champs, puis réessayez.';

  @override
  String get feedbackServerError =>
      'BusyStack ne peut pas accepter vos commentaires pour le moment. Vos commentaires n’ont pas été effacés ; réessayez.';

  @override
  String feedbackSuccess(String id) {
    return 'Commentaires envoyés. Référence : $id';
  }

  @override
  String get toggleSidebar => 'Afficher/masquer la barre latérale';

  @override
  String get showSidebar => 'Afficher le panneau latéral';

  @override
  String get hideSidebar => 'Masquer le panneau latéral';

  @override
  String get accounts => 'Comptes';

  @override
  String get currentAccount => 'Compte actuel';

  @override
  String get switchAccount => 'Changer de compte';

  @override
  String get addGoogleAccount => 'Ajouter un compte Google';

  @override
  String get addMicrosoftAccount => 'Ajouter un compte Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Connecté';

  @override
  String get removeAccount => 'Supprimer le compte…';

  @override
  String get removingAccount => 'Suppression du compte…';

  @override
  String get removeAccountDescription =>
      'Arrêter la synchronisation et supprimer les données de ce compte de cet appareil.';

  @override
  String removeAccountTitle(String account) {
    return 'Supprimer $account de BusyMax ?';
  }

  @override
  String get removeAccountConfirmation =>
      'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Provider copies of calendars, events, task lists, and tasks are not deleted.';

  @override
  String get revokeGoogleAccess =>
      'Révoquer également l’accès de BusyMax à ce compte Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Vous devrez accorder à nouveau l’accès avant de reconnecter le compte.';

  @override
  String get removeAccountAction => 'Supprimer le compte';

  @override
  String get removeAccountFailed =>
      'Impossible de terminer la suppression du compte. Réessayez.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Le compte a été supprimé de cet appareil, mais BusyMax n’a pas pu révoquer son accès à votre compte Google. Vous pouvez révoquer cet accès depuis votre compte Google.';

  @override
  String get newTaskList => 'Nouvelle liste de tâches';

  @override
  String taskListCreateFailed(String error) {
    return 'Could not create the task list: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Could not rename the task list: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Could not delete the task list: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Connectez-vous pour voir les listes de tâches.';

  @override
  String get noTaskListsSynced => 'Aucune liste de tâches synchronisée.';

  @override
  String get listActions => 'Actions de liste';

  @override
  String get rename => 'Renommer';

  @override
  String get delete => 'Supprimer';

  @override
  String get renameList => 'Renommer la liste';

  @override
  String get deleteList => 'Supprimer la liste';

  @override
  String get unshare => 'Ne plus partager';

  @override
  String get readOnlyTaskListCannotRename =>
      'This task list is read-only and cannot be renamed.';

  @override
  String get taskListCannotDelete =>
      'This task list cannot be deleted with your current permissions.';

  @override
  String get builtInMicrosoftList => 'Intégrée';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Les listes Microsoft To Do intégrées ne peuvent pas être renommées ni supprimées.';

  @override
  String deleteListConfirmation(String title) {
    return 'Supprimer « $title » de Google Tasks ?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Delete \"$title\" and all of its tasks?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Unshare \"$title\" from this account?';
  }

  @override
  String get deleteEvent => 'Supprimer l’événement';

  @override
  String get title => 'Titre';

  @override
  String get create => 'Créer';

  @override
  String get newTask => 'Nouvelle tâche';

  @override
  String get clearCompleted => 'Effacer les tâches terminées';

  @override
  String get refreshList => 'Actualiser la liste';

  @override
  String get refreshAll => 'Tout actualiser';

  @override
  String get listRefreshed => 'Liste actualisée.';

  @override
  String get allTasksRefreshed => 'Tous les comptes ont été actualisés.';

  @override
  String exportedFile(String path) {
    return 'Exporté vers $path';
  }

  @override
  String exportFailed(String error) {
    return 'Échec de l’export : $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Échec de l’actualisation : $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Sélectionnez ou créez une liste de tâches pour commencer.';

  @override
  String get signInToViewTasks => 'Connectez-vous pour voir les tâches.';

  @override
  String get noTasks => 'Aucune tâche.';

  @override
  String get noTasksYet => 'Aucune tâche pour le moment';

  @override
  String get noTasksYetMessage =>
      'Créez une tâche ou actualisez vos comptes pour commencer.';

  @override
  String get noTasksInList => 'Aucune tâche dans cette liste.';

  @override
  String get overdue => 'En retard';

  @override
  String get today => 'Aujourd’hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get upcoming => 'À venir';

  @override
  String get noDate => 'Sans date';

  @override
  String get completed => 'Terminées';

  @override
  String duePrefix(String date) {
    return 'Échéance $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date à $time';
  }

  @override
  String get taskDetails => 'Détails de la tâche';

  @override
  String get editTask => 'Modifier la tâche';

  @override
  String get noTaskSelected => 'Aucune tâche sélectionnée.';

  @override
  String get noTaskSelectedHelper =>
      'Sélectionnez une tâche pour afficher et modifier ses détails.';

  @override
  String get taskUnavailable => 'Tâche indisponible.';

  @override
  String get signInToEditTasks => 'Connectez-vous pour modifier les tâches.';

  @override
  String get refreshTask => 'Actualiser la tâche';

  @override
  String get primarySection => 'Principal';

  @override
  String get statusSection => 'État';

  @override
  String get openStatus => 'Ouverte';

  @override
  String get doneStatus => 'Terminée';

  @override
  String get taskStatus => 'Status';

  @override
  String get taskStatusNone => 'No status';

  @override
  String get taskStatusNeedsAction => 'Nécessite une action';

  @override
  String get taskStatusInProcess => 'En cours';

  @override
  String get taskStatusCompleted => 'Terminé';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String completionPercent(int percent) {
    return '$percent% completed';
  }

  @override
  String get completionDate => 'Completion date';

  @override
  String get priority => 'Priorité';

  @override
  String get priorityNone => 'No priority';

  @override
  String priorityHighValue(int priority) {
    return 'Priority $priority · High';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Priority $priority · Medium';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Priority $priority · Low';
  }

  @override
  String get taskUrl => 'URL';

  @override
  String get invalidTaskUrl => 'Enter an absolute URL, including its scheme.';

  @override
  String get classification => 'Classification';

  @override
  String get classificationPublic => 'When shared, show the full task';

  @override
  String get classificationConfidential => 'When shared, show only busy';

  @override
  String get classificationPrivate => 'When shared, hide this task';

  @override
  String get pinTask => 'Pin task';

  @override
  String get notes => 'Notes';

  @override
  String get dueDate => 'Date d’échéance';

  @override
  String get clearDueDate => 'Effacer la date d’échéance';

  @override
  String get dueTime => 'Heure d’échéance';

  @override
  String get startDate => 'Date de début';

  @override
  String get startTime => 'Heure de début';

  @override
  String get endDate => 'Date de fin';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get reminderDate => 'Date de rappel';

  @override
  String get reminderTime => 'Heure de rappel';

  @override
  String get reminder => 'Rappel';

  @override
  String get addReminder => 'Ajouter un rappel';

  @override
  String get reminders => 'Reminders';

  @override
  String get noReminders => 'Aucun rappel';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get beforeTaskStarts => 'Avant le début de la tâche';

  @override
  String get beforeTaskDue => 'Avant l\'échéance de la tâche';

  @override
  String get afterTaskStarts => 'After the task starts';

  @override
  String get afterTaskDue => 'After the task is due';

  @override
  String get relativeToTaskStart => 'Relative to the task start date';

  @override
  String get relativeToTaskDue => 'Relative to the task due date';

  @override
  String get reminderTimeOfDay => 'Time of day';

  @override
  String get absoluteReminder => 'At a date and time';

  @override
  String get reminderAmount => 'Amount';

  @override
  String get reminderUnit => 'Unit';

  @override
  String get reminderUnitSeconds => 'Seconds';

  @override
  String get reminderUnitMinutes => 'Minutes';

  @override
  String get reminderUnitHours => 'Hours';

  @override
  String get reminderUnitDays => 'Days';

  @override
  String get reminderUnitWeeks => 'Weeks';

  @override
  String get reminderAtTaskStart => 'At the task start';

  @override
  String get reminderAtTaskDue => 'At the task due time';

  @override
  String get unsupportedReminder =>
      'This reminder type is preserved but its time cannot be edited.';

  @override
  String get relatedRemindersTitle => 'Keep related reminders?';

  @override
  String relatedRemindersDescription(int count) {
    return 'This date has $count related reminders. Keep them at their current date and time?';
  }

  @override
  String get discardRelatedReminders => 'Discard reminders';

  @override
  String get keepRelatedReminders => 'Keep reminders';

  @override
  String get addGuest => 'Ajouter un invité';

  @override
  String get addGuestEmail => 'Ajouter l’e-mail de l’invité';

  @override
  String get removeReminder => 'Supprimer le rappel';

  @override
  String get off => 'Désactivé';

  @override
  String get repeat => 'Répéter';

  @override
  String get repeatNone => 'Aucun';

  @override
  String get noneValue => 'Aucun';

  @override
  String get repeatDaily => 'Quotidien';

  @override
  String get repeatWeekly => 'Hebdomadaire';

  @override
  String get repeatMonthly => 'Mensuel';

  @override
  String get repeatYearly => 'Annuel';

  @override
  String get repeatEvery => 'Répéter chaque';

  @override
  String get repeatOn => 'Repeat on';

  @override
  String get repeatEnd => 'Arrêter la répétition';

  @override
  String get repeatNever => 'Never';

  @override
  String get repeatUntil => 'On date';

  @override
  String get repeatAfter => 'After a number of occurrences';

  @override
  String get repeatCount => 'Occurrences';

  @override
  String get repeatDayOfMonth => 'Days of month';

  @override
  String get repeatMonths => 'Months';

  @override
  String get repeatOrdinal => 'Weekday position';

  @override
  String get repeatSpecificDays => 'Specific days';

  @override
  String get repeatFirst => 'First';

  @override
  String get repeatSecond => 'Second';

  @override
  String get repeatThird => 'Third';

  @override
  String get repeatFourth => 'Fourth';

  @override
  String get repeatFifth => 'Fifth';

  @override
  String get repeatSecondToLast => 'Second to last';

  @override
  String get repeatLast => 'Last';

  @override
  String get repeatAnyDay => 'Day';

  @override
  String get repeatWeekday => 'Weekday';

  @override
  String get repeatWeekendDay => 'Weekend day';

  @override
  String repeatEveryDays(int count) {
    return 'Every $count days';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'Every $count weeks';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'Every $count months';
  }

  @override
  String repeatEveryYears(int count) {
    return 'Every $count years';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'on $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'le $days';
  }

  @override
  String repeatOnOrdinalSummary(String ordinal, String days) {
    return 'on the $ordinal $days';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'in $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count fois';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'jusqu\'au $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'This recurrence rule uses options that this editor does not change.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Cette récurrence ne peut pas être utilisée avec $provider.';
  }

  @override
  String get importance => 'Importance';

  @override
  String get importanceLow => 'Faible';

  @override
  String get importanceNormal => 'Normale';

  @override
  String get importanceHigh => 'Élevée';

  @override
  String get categories => 'Catégories';

  @override
  String get scheduleSection => 'Planification';

  @override
  String get dueGroup => 'Échéance';

  @override
  String get startGroup => 'Début';

  @override
  String get reminderGroup => 'Rappel';

  @override
  String get organizationSection => 'Organisation';

  @override
  String get actionsSection => 'Actions';

  @override
  String get advancedSection => 'Avancé';

  @override
  String get addCategory => 'Ajouter une catégorie';

  @override
  String get list => 'Liste';

  @override
  String get microsoftMoveUnsupported =>
      'Le déplacement entre listes n’est pas pris en charge pour les comptes Microsoft To Do dans cette version.';

  @override
  String get createSubtask => 'Créer une sous-tâche';

  @override
  String get subtasks => 'Sous-tâches';

  @override
  String get duplicateTask => 'Duplicate task';

  @override
  String get taskDuplicated => 'Task duplicated.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Could not duplicate the task: $error';
  }

  @override
  String get hideSubtasks => 'Masquer les sous-tâches';

  @override
  String get hideClosedSubtasks => 'Masquer les sous-tâches fermées';

  @override
  String get moveToTop => 'Déplacer tout en haut';

  @override
  String get deleteTask => 'Supprimer la tâche';

  @override
  String get newSubtask => 'Nouvelle sous-tâche';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get metadata => 'Métadonnées';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Mis à jour';

  @override
  String get parent => 'Tâche parente';

  @override
  String get position => 'Position';

  @override
  String get webLink => 'Lien web';

  @override
  String get assignment => 'Attribution';

  @override
  String get localState => 'État local';

  @override
  String get pendingSync => 'Synchronisation en attente';

  @override
  String get synced => 'Synchronisé';

  @override
  String get account => 'Compte';

  @override
  String get sync => 'Synchronisation';

  @override
  String get manualFullSync => 'Synchronisation complète manuelle';

  @override
  String get runInBackgroundWhenClosed =>
      'Continuer à s’exécuter après la fermeture de la fenêtre';

  @override
  String get showTrayIcon => 'Afficher l’icône dans la zone de notification';

  @override
  String get startMinimizedToTray =>
      'Démarrer réduit dans la zone de notification';

  @override
  String get launchAtLogin => 'Lancer à la connexion';

  @override
  String get launchAtLoginDescription =>
      'Démarrer BusyMax en arrière-plan afin que les rappels fonctionnent après la connexion.';

  @override
  String get launchAtLoginFailed =>
      'Impossible de modifier le lancement à la connexion.';

  @override
  String get requiresTrayIcon =>
      'Nécessite l’icône de la zone de notification.';

  @override
  String get syncComplete => 'Synchronisation terminée.';

  @override
  String syncFailed(String error) {
    return 'Échec de la synchronisation : $error';
  }

  @override
  String get notifySyncFailures => 'Notifications d’échec de synchronisation';

  @override
  String get notifyConflicts => 'Notifications de conflits';

  @override
  String get notifyDueToday => 'Notifications des tâches dues aujourd’hui';

  @override
  String get eventReminders => 'Rappels d’événements';

  @override
  String get onState => 'Activé';

  @override
  String get taskReminders => 'Rappels de tâches';

  @override
  String get notificationDetailLevel => 'Niveau de détail des notifications';

  @override
  String get notificationDetailPrivate => 'Privé';

  @override
  String get notificationDetailNormal => 'Normal';

  @override
  String get quietHours => 'Période de silence';

  @override
  String get quietHoursDescription =>
      'Mettre les notifications en pause pendant cette période.';

  @override
  String get quietHoursStart => 'Début de la période de silence';

  @override
  String get quietHoursEnd => 'Fin de la période de silence';

  @override
  String get notifications => 'Notifications';

  @override
  String get appearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeFamily => 'Famille de thèmes';

  @override
  String get themeFamilyYaru => 'Thème natif d’Ubuntu (Yaru)';

  @override
  String get localization => 'Localisation';

  @override
  String get currentLocale => 'Paramètres régionaux actuels';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get redactTaskContentInDiagnostics =>
      'Masquer le contenu des tâches dans les diagnostics';

  @override
  String get developerDiagnostics => 'Diagnostics développeur';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get apiInspectorDisabled => 'Afficher l’inspecteur API';

  @override
  String get googleTasksApi => 'API Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Révision Discovery : $revision';
  }

  @override
  String get implementedMethods => 'Méthodes implémentées';

  @override
  String get supportsTasksScopes =>
      'Prend en charge les champs d’application tasks et tasks.readonly';

  @override
  String get requiresTasksScope => 'Nécessite le champ d’application tasks';

  @override
  String get blockedPendingOperations => 'Opérations en attente bloquées';

  @override
  String get signInToInspectPendingOperations =>
      'Connectez-vous pour inspecter les opérations en attente.';

  @override
  String get noBlockedPendingOperations =>
      'Aucune opération en attente bloquée.';

  @override
  String get operationActions => 'Actions de l’opération';

  @override
  String pendingOpListId(String id) {
    return 'liste=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'tâche=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'tentatives=$count';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get discard => 'Abandonner';

  @override
  String get discardChangesAction => 'Abandonner';

  @override
  String get discardChanges => 'Abandonner les modifications ?';

  @override
  String get discardChangesConfirmation =>
      'Les modifications non enregistrées apportées à cette tâche seront perdues.';

  @override
  String get retryCompleted => 'Nouvelle tentative terminée.';

  @override
  String get discardPendingOperation => 'Abandonner l’opération en attente ?';

  @override
  String get discardPendingOperationConfirmation =>
      'Cette action supprime l’opération locale bloquée. Lors de la prochaine synchronisation, les données seront rechargées depuis Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Opération en attente abandonnée.';

  @override
  String get syncFailureNotificationTitle =>
      'Échec de la synchronisation BusyMax';

  @override
  String syncFailureNotificationBody(String message) {
    return 'La synchronisation en arrière-plan a échoué. $message';
  }

  @override
  String get conflictNotificationTitle => 'Conflit de synchronisation BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Une modification locale en attente a été bloquée. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Tâches dues aujourd’hui';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches sont dues aujourd’hui.',
      one: 'Une tâche est due aujourd’hui.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Rappel d’événement';

  @override
  String get taskReminderNotificationTitle => 'Rappel de tâche';

  @override
  String get eventReminderNotificationBody => 'L’événement commence bientôt.';

  @override
  String get taskReminderNotificationBody =>
      'La tâche arrive bientôt à échéance.';

  @override
  String get notificationOpenAction => 'Ouvrir';

  @override
  String get notificationSnoozeAction => 'Rappeler dans 10 minutes';

  @override
  String get notificationDismissAction => 'Ignorer';

  @override
  String get notificationDetailsHidden =>
      'Les détails sont masqués par les paramètres de confidentialité.';

  @override
  String get previousMonth => 'Mois précédent';

  @override
  String get nextMonth => 'Mois suivant';

  @override
  String get openMonthView => 'Ouvrir la vue mensuelle';

  @override
  String get previousYear => 'Année précédente';

  @override
  String get nextYear => 'Année suivante';

  @override
  String get openYearView => 'Ouvrir la vue annuelle';

  @override
  String weekNumberTooltip(int number) {
    return 'Semaine $number';
  }

  @override
  String get resizeAllDayPanel =>
      'Redimensionner le volet des événements sur toute la journée';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Ce calendrier est en lecture seule.';

  @override
  String get selectTimeZone => 'Sélectionner le fuseau horaire';

  @override
  String get searchLocations => 'Rechercher des lieux';

  @override
  String get noLocationsFound => 'Aucun lieu trouvé';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get providerConnectionDescription =>
      'Connect calendars and tasks from one of these providers.';

  @override
  String get appleICloudProvider => 'Apple iCloud Calendar';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud Tasks';

  @override
  String get addAppleICloudAccount => 'Add Apple iCloud Calendar account';

  @override
  String get addNextcloudAccount => 'Add Nextcloud account';

  @override
  String get waitingForAppleICloud => 'Connecting to Apple iCloud…';

  @override
  String get waitingForNextcloud => 'Waiting for Nextcloud authorization…';

  @override
  String get connectAppleICloudTitle => 'Connect Apple iCloud Calendar';

  @override
  String get appleAccountEmail => 'Apple Account email';

  @override
  String get appleAppSpecificPassword => 'App-specific password';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Create an app-specific password after enabling two-factor authentication for your Apple Account.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Resetting your Apple Account password revokes app-specific passwords.';

  @override
  String get connectNextcloudTitle => 'Connect Nextcloud';

  @override
  String get nextcloudServerUrl => 'Nextcloud server or CalDAV address';

  @override
  String get nextcloudServerUrlHelp =>
      'Enter your Nextcloud server URL, or paste the primary CalDAV address copied from Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax will open your browser. Approve access there, then return to BusyMax.';

  @override
  String get connectAccountAction => 'Connect';

  @override
  String get cancelAccountConnection => 'Cancel connection';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'The account was removed locally, but its Nextcloud app password could not be revoked.';

  @override
  String get davCachedOfflineNotice =>
      'Calendar and task data is cached locally for offline use.';

  @override
  String get davReauthenticationRequired =>
      'Reconnect this account to resume synchronization.';

  @override
  String get davTemporarilyUnavailable =>
      'This account is temporarily unavailable.';

  @override
  String get davPermissionChanged =>
      'Server permissions changed. Pending edits are paused.';

  @override
  String get davUnsupportedServer =>
      'This server or provider profile is not supported.';

  @override
  String get collectionSettings => 'Calendars and task lists';

  @override
  String get calendarContent => 'Calendar events';

  @override
  String get taskContent => 'Tasks';

  @override
  String get readOnlySharedCollection => 'Read-only';

  @override
  String get pendingLocally => 'Pending locally';

  @override
  String get conflictBlocked => 'Blocked by conflict';

  @override
  String get authenticationBlocked => 'Blocked until reconnect';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get keepServerVersion => 'Keep server version';

  @override
  String get reapplyLocalChange => 'Review and reapply local change';

  @override
  String get duplicateLocalItem => 'Duplicate as new item';

  @override
  String get davConnectionState => 'Connection state';

  @override
  String get davConnected => 'Connected';

  @override
  String get davConnecting => 'Connecting…';

  @override
  String get davSignedOut => 'Signed out';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Last successful sync: $time';
  }

  @override
  String get davNeverSynced => 'Not synchronized yet';

  @override
  String get refreshCollections => 'Refresh calendars and task lists';

  @override
  String nextcloudServerHost(String host) {
    return 'Server: $host';
  }

  @override
  String get collectionSupportsEvents => 'Event calendar';

  @override
  String get collectionSupportsTasks => 'Task list';

  @override
  String get collectionSupportsEventsAndTasks => 'Events and tasks';

  @override
  String get writableCollection => 'Writable';

  @override
  String get sharedCollection => 'Shared';

  @override
  String collectionLastSynced(String time) {
    return 'Last synchronized: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Sync issue: $code';
  }

  @override
  String get syncConflicts => 'Synchronization conflicts';

  @override
  String remoteChangedAt(String time) {
    return 'Server changed: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Local edit: $summary';
  }

  @override
  String get conflictResolutionFailed => 'The conflict could not be resolved.';

  @override
  String get recurringEventScope => 'Recurring event scope';

  @override
  String get entireSeries => 'Entire series';

  @override
  String get singleOccurrence => 'Cet événement';

  @override
  String get thisAndFollowingEvents => 'Cet événement et les suivants';

  @override
  String get thisAndFutureUnavailable =>
      'Non pris en charge par ce fournisseur.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Cet événement et les suivants ne peuvent pas être déplacés de manière fiable. Choisissez cet événement ou toute la série.';

  @override
  String get entireSeriesMoveUnavailable =>
      'La règle de récurrence n’est pas disponible localement. Déplacez uniquement cet événement.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Copier l’événement et supprimer l’original ?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax ne peut pas déplacer directement cet événement de $source vers $destination. La copie sera créée en premier et l’original ne sera supprimé qu’après la réussite de la copie. Les identifiants changeront ; les statuts de réponse des participants pourront être réinitialisés et des invitations ou annulations envoyées ; les liens de conférence, pièces jointes, rappels, champs propres au fournisseur et exceptions de récurrence pourront ne pas être conservés.';
  }

  @override
  String get copyAndDelete => 'Copier et supprimer';

  @override
  String get chooseRecurringEventScope =>
      'Choose whether this change applies to the entire series or only this occurrence.';

  @override
  String get taskDueBeforeStart => 'L’échéance ne peut pas précéder le début.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Définissez une heure pour le début et l’échéance, ou passez la tâche en journée entière.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get setCustomCalendarName => 'Définir un nom personnalisé';

  @override
  String get setAction => 'Définir';

  @override
  String get removeFromMyCalendars => 'Retirer de mes agendas';

  @override
  String get removeAction => 'Retirer';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Retirer « $title » de votre liste Google Agenda ? L’agenda partagé et ses événements ne seront pas supprimés.';
  }

  @override
  String get calendarCannotRemove =>
      'Cet agenda ne peut pas être supprimé ni retiré de ce compte.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Attendez la fin de la synchronisation des modifications en attente de cet agenda avant de le supprimer ou de le retirer.';

  @override
  String get calendarSubscriptions => 'Calendar subscriptions';

  @override
  String get calendarSubscriptionsDescription =>
      'Add read-only calendars that refresh from a secure WebCal URL.';

  @override
  String get addCalendarSubscription => 'Add calendar subscription';

  @override
  String get subscriptionName => 'Local name';

  @override
  String get subscriptionUrl => 'Subscription URL';

  @override
  String get subscriptionUrlHelp =>
      'Enter an HTTPS or webcal URL. BusyMax keeps the complete URL in secure storage.';

  @override
  String get subscriptionUrlInvalid =>
      'Enter a valid HTTPS or webcal URL without user information or a fragment.';

  @override
  String get subscriptionColor => 'Local color';

  @override
  String get subscriptionColorHelp => 'Use a six-digit color such as #3584E4.';

  @override
  String get subscriptionColorInvalid => 'Enter a six-digit hexadecimal color.';

  @override
  String get subscriptionRefreshMode => 'Refresh frequency';

  @override
  String get subscriptionAutomatic => 'Automatic';

  @override
  String get subscriptionHourly => 'Hourly';

  @override
  String get subscriptionSixHours => 'Every six hours';

  @override
  String get subscriptionDaily => 'Daily';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Source: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Enter a valid URL to preview its safe origin.';

  @override
  String get subscriptionReadOnly => 'Read-only subscription';

  @override
  String get subscriptionNeverRefreshed => 'Not refreshed yet';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Last successful refresh: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Next refresh: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Up to date';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Refresh issue: $code';
  }

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get unsubscribe => 'Unsubscribe';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Unsubscribe from “$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'This removes the local subscription and its cached events. The published calendar is not changed.';

  @override
  String get addSubscriptionAction => 'Add subscription';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Calendar subscription failed: $error';
  }

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get calendarImport => 'Importer un calendrier';

  @override
  String get calendarImportDescription =>
      'Sélectionnez un fichier, vérifiez ses événements, puis choisissez le calendrier modifiable qui les recevra.';

  @override
  String get importIcsFile => 'Import .ics file';

  @override
  String get importIcsPreview => 'Import calendar events';

  @override
  String importEventsFound(int count) {
    return 'Importable event sets: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Invalid events: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Intentionally omitted: $fields';
  }

  @override
  String get noWritableCalendars =>
      'No writable destination calendar is available.';

  @override
  String get importDestinationCalendar => 'Destination calendar';

  @override
  String get importIcsConfirm => 'Import events';

  @override
  String get importIcsComplete => 'Import complete';

  @override
  String importQueued(int count) {
    return 'Imported or queued: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Duplicates skipped: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Unsupported recurrence sets: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Could not import the calendar file: $error';
  }

  @override
  String get networkOffline => 'Hors ligne';

  @override
  String get networkOfflineDescription =>
      'Les modifications seront synchronisées au rétablissement de la connexion.';

  @override
  String get networkOfflineTryAgain =>
      'Vous êtes hors ligne. Connectez-vous à Internet et réessayez.';
}

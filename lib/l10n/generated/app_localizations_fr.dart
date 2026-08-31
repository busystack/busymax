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
      'Connectez les comptes Google, Microsoft, Calendrier Apple iCloud ou Nextcloud.';

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
      'Ajoutez tous les comptes que vous souhaitez utiliser. BusyMax synchronise les calendriers, événements, listes de tâches et tâches pris en charge de chaque compte.';

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
  String get options => 'Choix';

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
  String get trayShowBusyMax => 'Afficher BusyMax';

  @override
  String get trayNewEvent => 'Nouvel événement…';

  @override
  String get trayNewTask => 'Nouvelle tâche…';

  @override
  String get trayToday => 'Aujourd’hui';

  @override
  String get trayAllDay => 'Toute la journée';

  @override
  String get trayNow => 'Maintenant';

  @override
  String get trayCalendarEvent => 'Événement du calendrier';

  @override
  String get trayUntitledEvent => 'Événement sans titre';

  @override
  String get trayNothingElseToday => 'Rien d’autre aujourd’hui';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches arrivent à échéance aujourd’hui',
      one: '1 tâche arrive à échéance aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Ouvrir l’agenda du jour';

  @override
  String get traySyncNow => 'Synchroniser maintenant';

  @override
  String get traySyncing => 'Synchronisation…';

  @override
  String get trayNotConnected => 'Non connecté';

  @override
  String get trayNotYetSynced => 'Pas encore synchronisé';

  @override
  String get trayLastSyncedJustNow => 'Synchronisé à l’instant';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synchronisé il y a $count minutes',
      one: 'Synchronisé il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synchronisé il y a $count heures',
      one: 'Synchronisé il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synchronisé il y a $count jours',
      one: 'Synchronisé il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Paramètres';

  @override
  String get trayQuitBusyMax => 'Quitter BusyMax';

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
  String get viewAgenda => 'Vue agenda';

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
  String get attendeeRequired => 'Obligatoire';

  @override
  String get attendeeOptional => 'Facultatif';

  @override
  String get meetingSection => 'Réunion';

  @override
  String get addGoogleMeet => 'Ajouter Google Meet';

  @override
  String get addTeamsMeeting => 'Ajouter une réunion Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Réunion en ligne ajoutée';

  @override
  String get requestResponses => 'Demander des réponses';

  @override
  String get requestResponsesDescription =>
      'Demandez aux invités de répondre à l’invitation.';

  @override
  String get hideGuestList => 'Masquer la liste des invités';

  @override
  String get hideGuestListDescription =>
      'Les invités ne peuvent pas voir qui d’autre a été invité.';

  @override
  String get allowNewTimeProposals =>
      'Autoriser les nouvelles propositions d’horaire';

  @override
  String get allowNewTimeProposalsDescription =>
      'Les invités peuvent proposer une autre heure de réunion.';

  @override
  String get notifyGuestsTitle => 'Notifier les invités ?';

  @override
  String get notifyGuestsSaveMessage =>
      'Cette réunion comporte des invités. Envoyer les invitations ou les mises à jour de l’événement lors de l’enregistrement ?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Cette réunion comporte des invités. Envoyer une annulation lors de sa suppression ?';

  @override
  String get sendUpdates => 'Envoyer les mises à jour';

  @override
  String get sendCancellation => 'Envoyer l’annulation';

  @override
  String get doNotSend => 'Ne pas envoyer';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Enregistrer la réunion ?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft enverra les invitations ou les mises à jour de l’événement aux invités.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Supprimer la réunion ?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft enverra une annulation aux invités.';

  @override
  String get organizer => 'Organisateur';

  @override
  String get yourResponse => 'Votre réponse';

  @override
  String get guestResponses => 'Réponses des invités';

  @override
  String get respond => 'Répondre';

  @override
  String get acceptInvitation => 'Accepter';

  @override
  String get tentativeInvitation => 'Provisoire';

  @override
  String get declineInvitation => 'Refuser';

  @override
  String get joinMeeting => 'Rejoindre la réunion';

  @override
  String get responseAccepted => 'Acceptée';

  @override
  String get responseTentative => 'Provisoire';

  @override
  String get responseDeclined => 'Refusée';

  @override
  String get responseNeedsAction => 'Réponse attendue';

  @override
  String get responseNotResponded => 'Sans réponse';

  @override
  String get responseOrganizer => 'Organisateur';

  @override
  String invitationResponseFailed(String error) {
    return 'Impossible d’envoyer votre réponse : $error';
  }

  @override
  String get joinMeetingFailed => 'Impossible d’ouvrir le lien de la réunion.';

  @override
  String get description => 'Détails';

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
  String get navigation => 'Déplacement';

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
  String get shortcutGroupNavigation => 'Déplacement';

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
      'Cette action supprime de cet appareil les tâches, calendriers, événements, rappels et modifications hors ligne en attente mis en cache. Les modifications non synchronisées seront perdues. Les copies des calendriers, événements, listes de tâches et tâches conservées chez le fournisseur ne sont pas supprimées.';

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
    return 'Impossible de créer la liste de tâches : $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Impossible de renommer la liste de tâches : $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Impossible de supprimer la liste de tâches : $error';
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
      'Cette liste de tâches est en lecture seule et ne peut pas être renommée.';

  @override
  String get taskListCannotDelete =>
      'Cette liste de tâches ne peut pas être supprimée avec vos autorisations actuelles.';

  @override
  String get builtInMicrosoftList => 'Intégrée';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Les listes Microsoft To Do intégrées ne peuvent pas être renommées ni supprimées.';

  @override
  String deleteListConfirmation(String title) {
    return 'Supprimer « $title » de Google Tasks ?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Supprimer « $title » et toutes ses tâches ?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Ne plus partager « $title » avec ce compte ?';
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
  String get taskStatus => 'État';

  @override
  String get taskStatusNone => 'Aucun état';

  @override
  String get taskStatusNeedsAction => 'Action requise';

  @override
  String get taskStatusInProcess => 'En cours';

  @override
  String get taskStatusCompleted => 'Terminée';

  @override
  String get taskStatusCancelled => 'Annulée';

  @override
  String completionPercent(int percent) {
    return '$percent % terminée';
  }

  @override
  String get completionDate => 'Date d’achèvement';

  @override
  String get priority => 'Priorité';

  @override
  String get priorityNone => 'Aucune priorité';

  @override
  String priorityHighValue(int priority) {
    return 'Priorité $priority · élevée';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Priorité $priority · moyenne';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Priorité $priority · faible';
  }

  @override
  String get taskUrl => 'URL de la tâche';

  @override
  String get invalidTaskUrl => 'Saisissez une URL absolue, avec son schéma.';

  @override
  String get classification => 'Catégorisation';

  @override
  String get classificationPublic =>
      'Lorsqu’elle est partagée, afficher la tâche complète';

  @override
  String get classificationConfidential =>
      'Lorsqu’elle est partagée, afficher uniquement l’état occupé';

  @override
  String get classificationPrivate =>
      'Lorsqu’elle est partagée, masquer cette tâche';

  @override
  String get pinTask => 'Épingler la tâche';

  @override
  String get notes => 'Remarques';

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
  String get reminders => 'Rappels';

  @override
  String get noReminders => 'Aucun rappel';

  @override
  String get editReminder => 'Modifier le rappel';

  @override
  String get beforeTaskStarts => 'Avant le début de la tâche';

  @override
  String get beforeTaskDue => 'Avant l’échéance de la tâche';

  @override
  String get afterTaskStarts => 'Après le début de la tâche';

  @override
  String get afterTaskDue => 'Après l’échéance de la tâche';

  @override
  String get relativeToTaskStart =>
      'Par rapport à la date de début de la tâche';

  @override
  String get relativeToTaskDue =>
      'Par rapport à la date d’échéance de la tâche';

  @override
  String get reminderTimeOfDay => 'Heure de la journée';

  @override
  String get absoluteReminder => 'À une date et une heure';

  @override
  String get reminderAmount => 'Quantité';

  @override
  String get reminderUnit => 'Unité';

  @override
  String get reminderUnitSeconds => 'Secondes';

  @override
  String get reminderUnitMinutes => 'min';

  @override
  String get reminderUnitHours => 'Heures';

  @override
  String get reminderUnitDays => 'Jours';

  @override
  String get reminderUnitWeeks => 'Semaines';

  @override
  String get reminderAtTaskStart => 'Au début de la tâche';

  @override
  String get reminderAtTaskDue => 'À l’échéance de la tâche';

  @override
  String get unsupportedReminder =>
      'Ce type de rappel est conservé, mais son heure ne peut pas être modifiée.';

  @override
  String get relatedRemindersTitle => 'Conserver les rappels associés ?';

  @override
  String relatedRemindersDescription(int count) {
    return 'Cette date comporte $count rappels associés. Les conserver à leur date et heure actuelles ?';
  }

  @override
  String get discardRelatedReminders => 'Supprimer les rappels';

  @override
  String get keepRelatedReminders => 'Conserver les rappels';

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
  String get repeatEvery => 'Intervalle';

  @override
  String get repeatOn => 'Répéter le';

  @override
  String get repeatEnd => 'Terminer la répétition';

  @override
  String get repeatNever => 'Jamais';

  @override
  String get repeatUntil => 'À une date';

  @override
  String get repeatAfter => 'Après un certain nombre de répétitions';

  @override
  String get repeatCount => 'Nombre d’occurrences';

  @override
  String get repeatDayOfMonth => 'Jours du mois';

  @override
  String get repeatMonths => 'Mois';

  @override
  String get repeatOrdinal => 'Position du jour de la semaine';

  @override
  String get repeatSpecificDays => 'Jours précis';

  @override
  String get repeatFirst => 'Premier';

  @override
  String get repeatSecond => 'Deuxième';

  @override
  String get repeatThird => 'Troisième';

  @override
  String get repeatFourth => 'Quatrième';

  @override
  String get repeatFifth => 'Cinquième';

  @override
  String get repeatSecondToLast => 'Avant-dernier';

  @override
  String get repeatLast => 'Dernier';

  @override
  String get repeatAnyDay => 'Jour';

  @override
  String get repeatWeekday => 'Jour de semaine';

  @override
  String get repeatWeekendDay => 'Jour du week-end';

  @override
  String repeatEveryDays(int count) {
    return 'Tous les $count jours';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'Toutes les $count semaines';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'Tous les $count mois';
  }

  @override
  String repeatEveryYears(int count) {
    return 'Toutes les $count années';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'les $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'le $days du mois';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'le premier $days',
      'second': 'le deuxième $days',
      'third': 'le troisième $days',
      'fourth': 'le quatrième $days',
      'fifth': 'le cinquième $days',
      'secondToLast': 'l’avant-dernier $days',
      'last': 'le dernier $days',
      'other': 'les $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'en $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count fois';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'jusqu’au $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Cette règle de récurrence utilise des options que cet éditeur ne modifie pas.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Cette récurrence ne peut pas être utilisée avec $provider.';
  }

  @override
  String get importance => 'Niveau d’importance';

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
  String get actionsSection => 'Opérations';

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
  String get duplicateTask => 'Dupliquer la tâche';

  @override
  String get taskDuplicated => 'Tâche dupliquée.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Impossible de dupliquer la tâche : $error';
  }

  @override
  String get hideSubtasks => 'Masquer les sous-tâches';

  @override
  String get hideClosedSubtasks => 'Masquer les sous-tâches terminées';

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
  String get position => 'Ordre';

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
  String get notificationDetailNormal => 'Standard';

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
  String get notifications => 'Alertes';

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
  String get diagnostics => 'Informations de diagnostic';

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
  String get notificationDismissAction => 'Fermer';

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
  String get requiredField => 'Ce champ est obligatoire.';

  @override
  String get providerConnectionDescription =>
      'Connectez les calendriers et les tâches à l’un de ces fournisseurs.';

  @override
  String get appleICloudProvider => 'Calendrier Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Tâches Nextcloud';

  @override
  String get addAppleICloudAccount =>
      'Ajouter un compte Calendrier Apple iCloud';

  @override
  String get addNextcloudAccount => 'Ajouter un compte Nextcloud';

  @override
  String get waitingForAppleICloud => 'Connexion à Apple iCloud…';

  @override
  String get waitingForNextcloud => 'En attente de l’autorisation Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Connecter le Calendrier Apple iCloud';

  @override
  String get appleAccountEmail => 'E-mail du compte Apple';

  @override
  String get appleAppSpecificPassword => 'Mot de passe spécifique à l’app';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Créez un mot de passe spécifique à l’app après avoir activé l’authentification à deux facteurs de votre compte Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'La réinitialisation du mot de passe de votre compte Apple révoque les mots de passe spécifiques aux apps.';

  @override
  String get connectNextcloudTitle => 'Connecter Nextcloud';

  @override
  String get nextcloudServerUrl => 'Serveur Nextcloud ou adresse CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Saisissez l’URL de votre serveur Nextcloud ou collez l’adresse CalDAV principale copiée depuis Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax va ouvrir votre navigateur. Autorisez-y l’accès, puis revenez dans BusyMax.';

  @override
  String get connectAccountAction => 'Connecter';

  @override
  String get cancelAccountConnection => 'Annuler la connexion';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'Le compte a été supprimé localement, mais le mot de passe d’app Nextcloud n’a pas pu être révoqué.';

  @override
  String get davCachedOfflineNotice =>
      'Les données des calendriers et des tâches sont mises en cache localement pour une utilisation hors connexion.';

  @override
  String get davReauthenticationRequired =>
      'Reconnectez ce compte pour reprendre la synchronisation.';

  @override
  String get davTemporarilyUnavailable =>
      'Ce compte est temporairement indisponible.';

  @override
  String get davPermissionChanged =>
      'Les autorisations du serveur ont changé. Les modifications en attente sont suspendues.';

  @override
  String get davUnsupportedServer =>
      'Ce serveur ou profil de fournisseur n’est pas pris en charge.';

  @override
  String get collectionSettings => 'Calendriers et listes de tâches';

  @override
  String get calendarContent => 'Événements du calendrier';

  @override
  String get taskContent => 'Tâches';

  @override
  String get readOnlySharedCollection => 'Lecture seule';

  @override
  String get pendingLocally => 'En attente localement';

  @override
  String get conflictBlocked => 'Bloqué par un conflit';

  @override
  String get authenticationBlocked => 'Bloqué jusqu’à la reconnexion';

  @override
  String get operationFailed => 'Échec de l’opération';

  @override
  String get keepServerVersion => 'Conserver la version du serveur';

  @override
  String get reapplyLocalChange =>
      'Examiner et réappliquer la modification locale';

  @override
  String get duplicateLocalItem => 'Dupliquer comme nouvel élément';

  @override
  String get davConnectionState => 'État de la connexion';

  @override
  String get davConnected => 'Connecté';

  @override
  String get davConnecting => 'Connexion…';

  @override
  String get davSignedOut => 'Déconnecté';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Dernière synchronisation réussie : $time';
  }

  @override
  String get davNeverSynced => 'Pas encore synchronisé';

  @override
  String get refreshCollections =>
      'Actualiser les calendriers et les listes de tâches';

  @override
  String nextcloudServerHost(String host) {
    return 'Serveur : $host';
  }

  @override
  String get collectionSupportsEvents => 'Calendrier d’événements';

  @override
  String get collectionSupportsTasks => 'Liste de tâches';

  @override
  String get collectionSupportsEventsAndTasks => 'Événements et tâches';

  @override
  String get writableCollection => 'Modifiable';

  @override
  String get sharedCollection => 'Partagé';

  @override
  String collectionLastSynced(String time) {
    return 'Dernière synchronisation : $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Problème de synchronisation : $code';
  }

  @override
  String get syncConflicts => 'Conflits de synchronisation';

  @override
  String remoteChangedAt(String time) {
    return 'Modification du serveur : $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Modification locale : $summary';
  }

  @override
  String get conflictResolutionFailed => 'Impossible de résoudre le conflit.';

  @override
  String get recurringEventScope => 'Portée de l’événement récurrent';

  @override
  String get entireSeries => 'Série entière';

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
      'Choisissez si cette modification s’applique à toute la série, à cet événement uniquement ou à cet événement et aux suivants.';

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
      'Ce calendrier ne peut pas être supprimé ou retiré de ce compte.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Attendez que les modifications en attente de ce calendrier aient fini de se synchroniser avant de le supprimer ou de le retirer.';

  @override
  String get calendarSubscriptions => 'Abonnements aux calendriers';

  @override
  String get calendarSubscriptionsDescription =>
      'Ajoutez des calendriers en lecture seule qui se mettent à jour depuis une URL WebCal sécurisée.';

  @override
  String get addCalendarSubscription => 'Ajouter un abonnement de calendrier';

  @override
  String get subscriptionName => 'Nom local';

  @override
  String get subscriptionUrl => 'URL de l’abonnement';

  @override
  String get subscriptionUrlHelp =>
      'Saisissez une URL HTTPS ou webcal. BusyMax conserve l’URL complète dans un stockage sécurisé.';

  @override
  String get subscriptionUrlInvalid =>
      'Saisissez une URL HTTPS ou webcal valide, sans informations utilisateur ni fragment.';

  @override
  String get subscriptionColor => 'Couleur locale';

  @override
  String get subscriptionColorHelp =>
      'Utilisez une couleur à six chiffres, comme #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Saisissez une couleur hexadécimale à six chiffres.';

  @override
  String get subscriptionRefreshMode => 'Fréquence d’actualisation';

  @override
  String get subscriptionAutomatic => 'Automatique';

  @override
  String get subscriptionHourly => 'Toutes les heures';

  @override
  String get subscriptionSixHours => 'Toutes les six heures';

  @override
  String get subscriptionDaily => 'Tous les jours';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Source : $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Saisissez une URL valide pour prévisualiser son origine sécurisée.';

  @override
  String get subscriptionReadOnly => 'Abonnement en lecture seule';

  @override
  String get subscriptionNeverRefreshed => 'Pas encore actualisé';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Dernière actualisation réussie : $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Prochaine actualisation : $time';
  }

  @override
  String get subscriptionStatusHealthy => 'À jour';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Problème d’actualisation : $code';
  }

  @override
  String get refreshNow => 'Actualiser maintenant';

  @override
  String get unsubscribe => 'Se désabonner';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Se désabonner de « $name » ?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Cette action supprime l’abonnement local et ses événements mis en cache. Le calendrier publié n’est pas modifié.';

  @override
  String get addSubscriptionAction => 'Ajouter un abonnement';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Échec de l’abonnement au calendrier : $error';
  }

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get calendarImport => 'Importation de calendrier';

  @override
  String get calendarImportDescription =>
      'Sélectionnez un fichier, vérifiez ses événements, puis choisissez le calendrier modifiable qui doit les recevoir.';

  @override
  String get importIcsFile => 'Importer un fichier .ics';

  @override
  String get importIcsPreview => 'Importer des événements du calendrier';

  @override
  String importEventsFound(int count) {
    return 'Ensembles d’événements importables : $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Événements non valides : $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Exclus intentionnellement : $fields';
  }

  @override
  String get noWritableCalendars =>
      'Aucun calendrier de destination modifiable n’est disponible.';

  @override
  String get importDestinationCalendar => 'Calendrier de destination';

  @override
  String get importIcsConfirm => 'Importer les événements';

  @override
  String get importIcsComplete => 'Importation terminée';

  @override
  String importQueued(int count) {
    return 'Importés ou mis en file d’attente : $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Doublons ignorés : $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Ensembles de récurrence non pris en charge : $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Impossible d’importer le fichier de calendrier : $error';
  }

  @override
  String get networkOffline => 'Hors ligne';

  @override
  String get networkOfflineDescription =>
      'Les modifications seront synchronisées au rétablissement de la connexion.';

  @override
  String get networkOfflineTryAgain =>
      'Vous êtes hors ligne. Connectez-vous à Internet et réessayez.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'les $days du mois';
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
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency le $days $month';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'le premier $days de $month',
      'second': 'le deuxième $days de $month',
      'third': 'le troisième $days de $month',
      'fourth': 'le quatrième $days de $month',
      'fifth': 'le cinquième $days de $month',
      'secondToLast': 'l’avant-dernier $days de $month',
      'last': 'le dernier $days de $month',
      'other': 'les $days de $month',
    });
    return '$frequency $_temp0';
  }
}

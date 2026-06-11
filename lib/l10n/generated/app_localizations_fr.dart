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
      'Connectez des comptes Google et Microsoft pour synchroniser calendriers et tâches.';

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
      'Ajoutez tous les comptes Google et Microsoft que vous voulez utiliser. BusyMax synchronise les calendriers, événements, listes de tâches et tâches de chaque compte.';

  @override
  String get onboardingPreferencesStepTitle => 'Choisir les paramètres système';

  @override
  String get onboardingPreferencesStepDescription =>
      'Réglez le comportement du bureau, les rappels, le détail des notifications et l’apparence avant d’ouvrir votre planning.';

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
  String get newEvent => 'Nouvel événement';

  @override
  String get refreshCalendar => 'Actualiser le calendrier';

  @override
  String get openInProvider => 'Ouvrir chez le fournisseur';

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
  String get trayAgendaLoading => 'Chargement de l’agenda...';

  @override
  String get trayAgendaSignInRequired =>
      'Connectez-vous pour afficher l’agenda.';

  @override
  String get trayAgendaNoSources =>
      'Aucun calendrier ni liste de tâches visible.';

  @override
  String get trayAgendaOpenBusyMax => 'Ouvrir l’app';

  @override
  String get trayAgendaRefresh => 'Actualiser';

  @override
  String get trayAgendaError => 'Agenda indisponible';

  @override
  String get compactAgendaTitle => 'Agenda';

  @override
  String get compactAgendaSubtitle => '7 prochains jours';

  @override
  String get compactAgendaOverdue => 'En retard';

  @override
  String get compactAgendaClear => 'Libre pour les 7 prochains jours';

  @override
  String get compactAgendaOpenBusyMax => 'Ouvrir BusyMax';

  @override
  String get compactAgendaHide => 'Masquer';

  @override
  String get compactAgendaNewTask => 'Nouvelle tâche';

  @override
  String get compactAgendaRetry => 'Réessayer';

  @override
  String get compactAgendaRefresh => 'Actualiser';

  @override
  String get compactAgendaAllDay => 'Toute la journée';

  @override
  String get compactAgendaDueToday => 'Due aujourd’hui';

  @override
  String get compactAgendaDueTomorrow => 'Due demain';

  @override
  String compactAgendaDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get compactAgendaMoreOverdue =>
      'Plus de tâches en retard dans BusyMax';

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
  String get aboutBusyMax => 'À propos de BusyMax';

  @override
  String get aboutBusyMaxDescription => 'ToDo et calendrier';

  @override
  String get website => 'Site web';

  @override
  String get reportAnIssue => 'Signaler un problème';

  @override
  String get toggleSidebar => 'Afficher/masquer la barre latérale';

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
  String get signOutThisAccount => 'Déconnecter ce compte';

  @override
  String get revokeThisAccount => 'Révoquer ce compte';

  @override
  String get disconnectThisAccount => 'Dissocier ce compte';

  @override
  String get deleteLocalDataForThisAccount =>
      'Supprimer les données locales de ce compte';

  @override
  String get newList => 'Nouvelle liste';

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
  String get builtInMicrosoftList => 'Intégrée';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Les listes Microsoft To Do intégrées ne peuvent pas être renommées ni supprimées.';

  @override
  String deleteListConfirmation(String title) {
    return 'Supprimer « $title » de Google Tasks ?';
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
  String get clearCompleted => 'Effacer les terminées';

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
      'Sélectionnez ou créez une liste de tâches.';

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
  String get searchTasks => 'Rechercher des tâches';

  @override
  String get advancedFilters => 'Filtres avancés';

  @override
  String get showCompleted => 'Afficher les terminées';

  @override
  String get showHidden => 'Afficher les masquées';

  @override
  String get showAssigned => 'Afficher les assignées';

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
  String get moveToTop => 'Déplacer en haut';

  @override
  String get deleteTask => 'Supprimer la tâche';

  @override
  String get newSubtask => 'Nouvelle sous-tâche';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Supprimer « $title » de Google Tasks ?';
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
  String get parent => 'Parent';

  @override
  String get position => 'Position';

  @override
  String get webLink => 'Lien web';

  @override
  String get assignment => 'Assignation';

  @override
  String get localState => 'État local';

  @override
  String get pendingSync => 'Synchronisation en attente';

  @override
  String get synced => 'Synchronisé';

  @override
  String get account => 'Compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get revokeGoogleAuthorization => 'Révoquer l’autorisation Google';

  @override
  String get deleteLocalData => 'Supprimer les données locales';

  @override
  String get deleteLocalDataConfirmation =>
      'Cela supprime de cet appareil le compte local, les tâches synchronisées et les changements hors ligne en attente.';

  @override
  String get sync => 'Synchronisation';

  @override
  String get manualFullSync => 'Synchronisation complète manuelle';

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
  String get themeFamily => 'Famille de thème';

  @override
  String get themeFamilyYaru => 'Ubuntu natif (Yaru)';

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
  String get detailedNotifications => 'Texte de notification détaillé';

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
  String get discard => 'Ignorer';

  @override
  String get discardChanges => 'Ignorer les modifications ?';

  @override
  String get discardChangesConfirmation =>
      'Cela ignore les modifications non enregistrées de cette tâche.';

  @override
  String get retryCompleted => 'Nouvelle tentative terminée.';

  @override
  String get discardPendingOperation => 'Ignorer l’opération en attente ?';

  @override
  String get discardPendingOperationConfirmation =>
      'Cela supprime l’opération locale bloquée. La prochaine synchronisation actualisera depuis Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Opération en attente ignorée.';

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
  String get notificationDetailsHidden =>
      'Les détails sont masqués par les paramètres de confidentialité.';
}

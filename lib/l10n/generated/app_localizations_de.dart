// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Verbinden Sie Google- und Microsoft-Konten, um Kalender und Aufgaben zu synchronisieren.';

  @override
  String get googlePermissionsConsentNotice =>
      'Wählen Sie auf dem Google-Berechtigungsbildschirm sowohl Kalender- als auch Aufgabenberechtigungen aus.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google Calendar- und Google Tasks-Berechtigungen sind erforderlich. Versuchen Sie es erneut und wählen Sie beide Kontrollkästchen aus.';

  @override
  String get finishSetup => 'Einrichtung abschließen';

  @override
  String get continueSetup => 'Weiter';

  @override
  String get onboardingSetupTitle => 'BusyMax einrichten';

  @override
  String get onboardingAccountsStepTitle => 'Konten verbinden';

  @override
  String get onboardingAccountsStepDescription =>
      'Fügen Sie alle Google- und Microsoft-Konten hinzu, die Sie verwenden möchten. BusyMax synchronisiert Kalender, Termine, Aufgabenlisten und Aufgaben aus jedem Konto.';

  @override
  String get onboardingPreferencesStepTitle => 'Systemeinstellungen wählen';

  @override
  String get onboardingPreferencesStepDescription =>
      'Legen Sie Desktop-Verhalten, Erinnerungen, Benachrichtigungsdetails und Darstellung fest, bevor Sie Ihren Zeitplan öffnen.';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get signInWithMicrosoft => 'Mit Microsoft anmelden';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Dieser Anbieter ist nicht konfiguriert.';

  @override
  String get waitingForGoogleSignIn => 'Warten auf Google-Anmeldung...';

  @override
  String get waitingForMicrosoftSignIn => 'Warten auf Microsoft-Anmeldung...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsoft-Anmeldung ist nicht konfiguriert. Setzen Sie MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get exit => 'Beenden';

  @override
  String get options => 'Optionen';

  @override
  String get hide => 'Ausblenden';

  @override
  String get show => 'Anzeigen';

  @override
  String get export => 'Exportieren';

  @override
  String get save => 'Speichern';

  @override
  String get settings => 'Einstellungen';

  @override
  String get all => 'Alle';

  @override
  String get calendarEvents => 'Termine';

  @override
  String get calendarTasks => 'Aufgaben';

  @override
  String get calendar => 'Kalender';

  @override
  String get calendars => 'Kalender';

  @override
  String get newEvent => 'Neuer Termin';

  @override
  String get refreshCalendar => 'Kalender aktualisieren';

  @override
  String get openInProvider => 'Beim Anbieter öffnen';

  @override
  String get hideFromSchedule => 'Im Zeitplan ausblenden';

  @override
  String get showInSchedule => 'Im Zeitplan anzeigen';

  @override
  String get noCalendarsSynced => 'Noch keine Kalender synchronisiert.';

  @override
  String get allDay => 'Ganztägig';

  @override
  String moreItems(int count) {
    return '+$count weitere';
  }

  @override
  String get noEventsOrTasks => 'Keine Termine oder Aufgaben';

  @override
  String get trayAgendaLoading => 'Agenda wird geladen...';

  @override
  String get trayAgendaSignInRequired =>
      'Melden Sie sich an, um die Agenda anzuzeigen.';

  @override
  String get trayAgendaNoSources =>
      'Keine sichtbaren Kalender oder Aufgabenlisten.';

  @override
  String get trayAgendaOpenBusyMax => 'App öffnen';

  @override
  String get trayAgendaRefresh => 'Aktualisieren';

  @override
  String get trayAgendaError => 'Agenda nicht verfügbar';

  @override
  String get compactAgendaTitle => 'Agenda';

  @override
  String get compactAgendaSubtitle => 'Nächste 7 Tage';

  @override
  String get compactAgendaOverdue => 'Überfällig';

  @override
  String get compactAgendaClear => 'Frei für die nächsten 7 Tage';

  @override
  String get compactAgendaOpenBusyMax => 'BusyMax öffnen';

  @override
  String get compactAgendaHide => 'Ausblenden';

  @override
  String get compactAgendaNewTask => 'Neue Aufgabe';

  @override
  String get compactAgendaRetry => 'Erneut versuchen';

  @override
  String get compactAgendaRefresh => 'Aktualisieren';

  @override
  String get compactAgendaAllDay => 'Ganztägig';

  @override
  String get compactAgendaDueToday => 'Heute fällig';

  @override
  String get compactAgendaDueTomorrow => 'Morgen fällig';

  @override
  String compactAgendaDueOn(String date) {
    return 'Fällig $date';
  }

  @override
  String get compactAgendaMoreOverdue =>
      'Weitere überfällige Aufgaben in BusyMax';

  @override
  String get viewDay => 'Tag';

  @override
  String get viewWeek => 'Woche';

  @override
  String get viewMonth => 'Monat';

  @override
  String get viewYear => 'Jahr';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get sourceCalendar => 'Kalender';

  @override
  String get sourceTaskList => 'Aufgabenliste';

  @override
  String get createChoiceTitle => 'Erstellen';

  @override
  String get createEventAtTime => 'Termin';

  @override
  String get createTaskAtDate => 'Aufgabe';

  @override
  String get editEvent => 'Termin bearbeiten';

  @override
  String get eventTitle => 'Termintitel';

  @override
  String get location => 'Ort';

  @override
  String get timeSlot => 'Zeitfenster';

  @override
  String get startDateTime => 'Startdatum/-zeit';

  @override
  String get endDateTime => 'Enddatum/-zeit';

  @override
  String get doesNotRepeat => 'Wiederholt sich nicht';

  @override
  String get defaultReminder => 'Standarderinnerung';

  @override
  String get guests => 'Gäste';

  @override
  String get noGuests => 'Keine Gäste';

  @override
  String get description => 'Beschreibung';

  @override
  String get availabilityShowAs => 'Verfügbarkeit / Anzeigen als';

  @override
  String get busy => 'Beschäftigt';

  @override
  String get visibility => 'Sichtbarkeit';

  @override
  String get defaultVisibility => 'Standardsichtbarkeit';

  @override
  String get conference => 'Konferenz';

  @override
  String get noConference => 'Keine Konferenz';

  @override
  String get providerCalendar => 'Anbieterkalender';

  @override
  String get tasks => 'Aufgaben';

  @override
  String get allTasks => 'Alle Aufgaben';

  @override
  String tasksInList(String title) {
    return 'Aufgaben in $title';
  }

  @override
  String get taskLists => 'Aufgabenlisten';

  @override
  String get navigation => 'Navigation';

  @override
  String get mainMenu => 'Hauptmenü';

  @override
  String get aboutBusyMax => 'Über BusyMax';

  @override
  String get aboutBusyMaxDescription => 'ToDo und Kalender';

  @override
  String get website => 'Website';

  @override
  String get reportAnIssue => 'Problem melden';

  @override
  String get toggleSidebar => 'Seitenleiste umschalten';

  @override
  String get accounts => 'Konten';

  @override
  String get currentAccount => 'Aktuelles Konto';

  @override
  String get switchAccount => 'Konto wechseln';

  @override
  String get addGoogleAccount => 'Google-Konto hinzufügen';

  @override
  String get addMicrosoftAccount => 'Microsoft-Konto hinzufügen';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Angemeldet';

  @override
  String get signOutThisAccount => 'Dieses Konto abmelden';

  @override
  String get revokeThisAccount => 'Dieses Konto widerrufen';

  @override
  String get disconnectThisAccount => 'Dieses Konto trennen';

  @override
  String get deleteLocalDataForThisAccount =>
      'Lokale Daten für dieses Konto löschen';

  @override
  String get newList => 'Neue Liste';

  @override
  String get signInToViewTaskLists =>
      'Melden Sie sich an, um Aufgabenlisten zu sehen.';

  @override
  String get noTaskListsSynced => 'Noch keine Aufgabenlisten synchronisiert.';

  @override
  String get listActions => 'Listenaktionen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get delete => 'Löschen';

  @override
  String get renameList => 'Liste umbenennen';

  @override
  String get deleteList => 'Liste löschen';

  @override
  String get builtInMicrosoftList => 'Integriert';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Integrierte Microsoft To Do-Listen können nicht umbenannt oder gelöscht werden.';

  @override
  String deleteListConfirmation(String title) {
    return '\"$title\" aus Google Tasks löschen?';
  }

  @override
  String get deleteEvent => 'Ereignis löschen';

  @override
  String get title => 'Titel';

  @override
  String get create => 'Erstellen';

  @override
  String get newTask => 'Neue Aufgabe';

  @override
  String get clearCompleted => 'Erledigte löschen';

  @override
  String get refreshList => 'Liste aktualisieren';

  @override
  String get refreshAll => 'Alle aktualisieren';

  @override
  String get listRefreshed => 'Liste aktualisiert.';

  @override
  String get allTasksRefreshed => 'Alle Konten aktualisiert.';

  @override
  String exportedFile(String path) {
    return 'Exportiert nach $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Aktualisierung fehlgeschlagen: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Wählen oder erstellen Sie eine Aufgabenliste.';

  @override
  String get signInToViewTasks => 'Melden Sie sich an, um Aufgaben zu sehen.';

  @override
  String get noTasks => 'Keine Aufgaben.';

  @override
  String get noTasksYet => 'Noch keine Aufgaben';

  @override
  String get noTasksYetMessage =>
      'Erstellen Sie eine Aufgabe oder aktualisieren Sie Ihre Konten.';

  @override
  String get noTasksInList => 'Keine Aufgaben in dieser Liste.';

  @override
  String get overdue => 'Überfällig';

  @override
  String get today => 'Heute';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get upcoming => 'Demnächst';

  @override
  String get noDate => 'Kein Datum';

  @override
  String get completed => 'Erledigt';

  @override
  String duePrefix(String date) {
    return 'Fällig $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date, $time';
  }

  @override
  String get searchTasks => 'Aufgaben suchen';

  @override
  String get advancedFilters => 'Erweiterte Filter';

  @override
  String get showCompleted => 'Erledigte anzeigen';

  @override
  String get showHidden => 'Ausgeblendete anzeigen';

  @override
  String get showAssigned => 'Zugewiesene anzeigen';

  @override
  String get taskDetails => 'Aufgabendetails';

  @override
  String get editTask => 'Aufgabe bearbeiten';

  @override
  String get noTaskSelected => 'Keine Aufgabe ausgewählt.';

  @override
  String get noTaskSelectedHelper =>
      'Wählen Sie eine Aufgabe aus, um Details anzuzeigen und zu bearbeiten.';

  @override
  String get taskUnavailable => 'Aufgabe nicht verfügbar.';

  @override
  String get signInToEditTasks =>
      'Melden Sie sich an, um Aufgaben zu bearbeiten.';

  @override
  String get refreshTask => 'Aufgabe aktualisieren';

  @override
  String get primarySection => 'Primär';

  @override
  String get statusSection => 'Status';

  @override
  String get openStatus => 'Offen';

  @override
  String get doneStatus => 'Erledigt';

  @override
  String get notes => 'Notizen';

  @override
  String get dueDate => 'Fälligkeitsdatum';

  @override
  String get clearDueDate => 'Fälligkeitsdatum löschen';

  @override
  String get dueTime => 'Uhrzeit';

  @override
  String get startDate => 'Startdatum';

  @override
  String get startTime => 'Startzeit';

  @override
  String get endDate => 'Enddatum';

  @override
  String get endTime => 'Endzeit';

  @override
  String get reminderDate => 'Erinnerungsdatum';

  @override
  String get reminderTime => 'Erinnerungszeit';

  @override
  String get reminder => 'Erinnerung';

  @override
  String get addReminder => 'Erinnerung hinzufügen';

  @override
  String get addGuest => 'Gast hinzufügen';

  @override
  String get addGuestEmail => 'Gast-E-Mail hinzufügen';

  @override
  String get removeReminder => 'Erinnerung entfernen';

  @override
  String get off => 'Aus';

  @override
  String get repeat => 'Wiederholen';

  @override
  String get repeatNone => 'Keine';

  @override
  String get noneValue => 'Keine';

  @override
  String get repeatDaily => 'Täglich';

  @override
  String get repeatWeekly => 'Wöchentlich';

  @override
  String get repeatMonthly => 'Monatlich';

  @override
  String get repeatYearly => 'Jährlich';

  @override
  String get importance => 'Wichtigkeit';

  @override
  String get importanceLow => 'Niedrig';

  @override
  String get importanceNormal => 'Normal';

  @override
  String get importanceHigh => 'Hoch';

  @override
  String get categories => 'Kategorien';

  @override
  String get scheduleSection => 'Zeitplan';

  @override
  String get dueGroup => 'Fällig';

  @override
  String get startGroup => 'Start';

  @override
  String get reminderGroup => 'Erinnerung';

  @override
  String get organizationSection => 'Organisation';

  @override
  String get actionsSection => 'Aktionen';

  @override
  String get advancedSection => 'Erweitert';

  @override
  String get addCategory => 'Kategorie hinzufügen';

  @override
  String get list => 'Liste';

  @override
  String get microsoftMoveUnsupported =>
      'Das Verschieben zwischen Listen wird für Microsoft To Do-Konten in dieser Version nicht unterstützt.';

  @override
  String get createSubtask => 'Unteraufgabe erstellen';

  @override
  String get moveToTop => 'Nach oben verschieben';

  @override
  String get deleteTask => 'Aufgabe löschen';

  @override
  String get newSubtask => 'Neue Unteraufgabe';

  @override
  String deleteTaskConfirmation(String title) {
    return '\"$title\" aus Google Tasks löschen?';
  }

  @override
  String get metadata => 'Metadaten';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Aktualisiert';

  @override
  String get parent => 'Übergeordnet';

  @override
  String get position => 'Position';

  @override
  String get webLink => 'Weblink';

  @override
  String get assignment => 'Zuweisung';

  @override
  String get localState => 'Lokaler Status';

  @override
  String get pendingSync => 'Synchronisierung ausstehend';

  @override
  String get synced => 'Synchronisiert';

  @override
  String get account => 'Konto';

  @override
  String get signOut => 'Abmelden';

  @override
  String get revokeGoogleAuthorization => 'Google-Autorisierung widerrufen';

  @override
  String get deleteLocalData => 'Lokale Daten löschen';

  @override
  String get deleteLocalDataConfirmation =>
      'Dies entfernt das lokale Konto, synchronisierte Aufgaben und ausstehende Offline-Änderungen von diesem Gerät.';

  @override
  String get sync => 'Synchronisierung';

  @override
  String get manualFullSync => 'Manuelle vollständige Synchronisierung';

  @override
  String get syncComplete => 'Synchronisierung abgeschlossen.';

  @override
  String syncFailed(String error) {
    return 'Synchronisierung fehlgeschlagen: $error';
  }

  @override
  String get notifySyncFailures =>
      'Benachrichtigungen bei Synchronisierungsfehlern';

  @override
  String get notifyConflicts => 'Benachrichtigungen bei Konflikten';

  @override
  String get notifyDueToday => 'Benachrichtigungen für heute fällige Aufgaben';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get appearance => 'Darstellung';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeFamily => 'Theme-Familie';

  @override
  String get themeFamilyYaru => 'Natives Ubuntu (Yaru)';

  @override
  String get localization => 'Lokalisierung';

  @override
  String get currentLocale => 'Aktuelle Sprache';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get redactTaskContentInDiagnostics =>
      'Aufgabeninhalte in Diagnosen schwärzen';

  @override
  String get detailedNotifications => 'Detaillierte Benachrichtigungstexte';

  @override
  String get developerDiagnostics => 'Entwicklerdiagnose';

  @override
  String get diagnostics => 'Diagnose';

  @override
  String get apiInspectorDisabled => 'API-Inspektor anzeigen';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery-Revision: $revision';
  }

  @override
  String get implementedMethods => 'Implementierte Methoden';

  @override
  String get supportsTasksScopes =>
      'Unterstützt tasks- und tasks.readonly-Berechtigungen';

  @override
  String get requiresTasksScope => 'Benötigt tasks-Berechtigung';

  @override
  String get blockedPendingOperations => 'Blockierte ausstehende Vorgänge';

  @override
  String get signInToInspectPendingOperations =>
      'Melden Sie sich an, um ausstehende Vorgänge zu prüfen.';

  @override
  String get noBlockedPendingOperations =>
      'Keine blockierten ausstehenden Vorgänge.';

  @override
  String get operationActions => 'Vorgangsaktionen';

  @override
  String pendingOpListId(String id) {
    return 'Liste=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'Aufgabe=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'Versuche=$count';
  }

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get discardChanges => 'Änderungen verwerfen?';

  @override
  String get discardChangesConfirmation =>
      'Dies verwirft ungespeicherte Änderungen an dieser Aufgabe.';

  @override
  String get retryCompleted => 'Erneuter Versuch abgeschlossen.';

  @override
  String get discardPendingOperation => 'Ausstehenden Vorgang verwerfen?';

  @override
  String get discardPendingOperationConfirmation =>
      'Dies entfernt den blockierten lokalen Vorgang. Die nächste Synchronisierung aktualisiert von Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Ausstehender Vorgang verworfen.';

  @override
  String get syncFailureNotificationTitle =>
      'BusyMax-Synchronisierung fehlgeschlagen';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Hintergrundsynchronisierung fehlgeschlagen. $message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMax-Synchronisierungskonflikt';

  @override
  String conflictNotificationBody(String summary) {
    return 'Eine ausstehende lokale Änderung wurde blockiert. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Heute fällige Aufgaben';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben sind heute fällig.',
      one: 'Eine Aufgabe ist heute fällig.',
    );
    return '$_temp0';
  }

  @override
  String get notificationDetailsHidden =>
      'Details werden durch Datenschutzeinstellungen ausgeblendet.';
}

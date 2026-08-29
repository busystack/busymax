// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

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
      'Connect Google, Microsoft, Apple iCloud Calendar, or Nextcloud accounts.';

  @override
  String get googlePermissionsConsentNotice =>
      'Wählen Sie auf dem Google-Berechtigungsbildschirm sowohl Kalender- als auch Aufgabenberechtigungen aus.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Die Berechtigungen für Google Kalender und Google Tasks sind erforderlich. Versuchen Sie es erneut und aktivieren Sie beide Kontrollkästchen.';

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
      'Add every account you want to use. BusyMax syncs supported calendars, events, task lists, and tasks from each account.';

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
  String get newCalendar => 'Neuer Kalender';

  @override
  String get calendarColor => 'Kalenderfarbe';

  @override
  String calendarColorOption(int number) {
    return 'Farbe $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Dieser Anbieter unterstützt die Kalenderverwaltung in BusyMax nicht.';

  @override
  String get primaryCalendarCannotDelete =>
      'Der primäre Kalender kann nicht gelöscht werden.';

  @override
  String calendarCreateFailed(String error) {
    return 'Kalender konnte nicht erstellt werden: $error';
  }

  @override
  String calendarUpdateFailed(String error) {
    return 'Kalender konnte nicht aktualisiert werden: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Kalender konnte nicht gelöscht werden: $error';
  }

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
    return '+$count mehr';
  }

  @override
  String get noEventsOrTasks => 'Keine Termine oder Aufgaben';

  @override
  String get scheduleLoading => 'Zeitplan wird geladen...';

  @override
  String get scheduleUnavailable => 'Zeitplan nicht verfügbar';

  @override
  String get scheduleNoSources =>
      'Keine sichtbaren Kalender oder Aufgabenlisten';

  @override
  String get scheduleNoSourcesDescription =>
      'Wählen Sie in den Einstellungen aus, was angezeigt werden soll, und aktualisieren Sie anschließend den Zeitplan.';

  @override
  String get scheduleSignInRequired => 'Konto verbinden';

  @override
  String get scheduleSignInDescription =>
      'Melden Sie sich an, um Kalender und Aufgaben zu synchronisieren.';

  @override
  String get scheduleNoSearchResults => 'Keine passenden Termine oder Aufgaben';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Versuchen Sie es mit einer anderen Suche oder setzen Sie die aktuellen Filter zurück.';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get trayOpenBusyMax => 'BusyMax öffnen';

  @override
  String get agendaLoadMoreOverdue => 'Weitere überfällige Aufgaben laden';

  @override
  String get agendaLoadMoreNoDate => 'Weitere Aufgaben ohne Datum laden';

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
  String get scheduleSettings => 'Zeitplan';

  @override
  String get scheduleDisplaySettings => 'Zeitplananzeige';

  @override
  String get scheduleDisplayHoursDescription =>
      'In der Tages- und Wochenansicht wird zunächst dieser Zeitraum angezeigt. Frühere oder spätere Einträge erweitern ihn bei Bedarf.';

  @override
  String get scheduleDayStartsAt => 'Tag beginnt um';

  @override
  String get scheduleDayEndsAt => 'Tag endet um';

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
  String get formatBoldShortLabel => 'F';

  @override
  String get formatBoldTooltip => 'Fett';

  @override
  String get formatItalicShortLabel => 'K';

  @override
  String get formatItalicTooltip => 'Kursiv';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'Unterstrichen';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten vorher',
      one: '1 Minute vorher',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'Zum Startzeitpunkt';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours Stunden vorher',
      one: '1 Stunde vorher',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage vorher',
      one: '1 Tag vorher',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Frei';

  @override
  String get availabilityTentative => 'Mit Vorbehalt';

  @override
  String get availabilityOutOfOffice => 'Abwesend';

  @override
  String get availabilityWorkingElsewhere => 'An einem anderen Ort tätig';

  @override
  String get visibilityDefault => 'Standard';

  @override
  String get visibilityPublic => 'Öffentlich';

  @override
  String get visibilityPrivate => 'Privat';

  @override
  String get visibilityConfidential => 'Vertraulich';

  @override
  String get sensitivityNormal => 'Normal';

  @override
  String get sensitivityPersonal => 'Persönlich';

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
  String get keyboardShortcuts => 'Tastenkürzel';

  @override
  String get shortcutGroupGeneral => 'Allgemein';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Diese Übersicht der Tastenkürzel anzeigen';

  @override
  String get shortcutGroupNavigation => 'Navigation';

  @override
  String get shortcutNextPeriod => 'Nächster Zeitraum';

  @override
  String get shortcutNextPeriodDescription =>
      'Nächste Woche in der Wochenansicht, nächster Monat in der Monatsansicht usw.';

  @override
  String get shortcutPreviousPeriod => 'Vorheriger Zeitraum';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Vorherige Woche in der Wochenansicht, vorheriger Monat in der Monatsansicht usw.';

  @override
  String get shortcutJumpToToday => 'Zum heutigen Tag springen';

  @override
  String get shortcutGroupView => 'Ansicht';

  @override
  String get shortcutDayView => 'Tagesansicht';

  @override
  String get shortcutWeekView => 'Wochenansicht';

  @override
  String get shortcutMonthView => 'Monatsansicht';

  @override
  String get shortcutYearView => 'Jahresansicht';

  @override
  String get shortcutAgendaView => 'Agendaansicht';

  @override
  String get shortcutGroupCreateAndEdit => 'Erstellen und Bearbeiten';

  @override
  String get shortcutSaveItem => 'Termin oder Aufgabe speichern';

  @override
  String get shortcutDeleteItem => 'Termin oder Aufgabe löschen';

  @override
  String get shortcutGroupTaskEditing => 'Aufgabenbearbeitung';

  @override
  String get shortcutCancelEditing => 'Bearbeitung abbrechen';

  @override
  String get shortcutCancelEditingDescription =>
      'Aufgabenbearbeitung oder Aufgabendetails schließen';

  @override
  String get aboutBusyMax => 'Über BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Kalender und Aufgaben';

  @override
  String get license => 'Lizenz';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Website';

  @override
  String get sourceCode => 'Quellcode';

  @override
  String get reportAnIssue => 'Problem melden';

  @override
  String get sendFeedback => 'Feedback senden';

  @override
  String get feedbackSubmit => 'Senden';

  @override
  String get feedbackCategory => 'Kategorie';

  @override
  String get feedbackSelectCategory => 'Kategorie auswählen';

  @override
  String get feedbackCategoryProblem => 'Problem oder Fehler';

  @override
  String get feedbackCategoryFeature => 'Funktionswunsch';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Datenschutz- oder Sicherheitsbedenken';

  @override
  String get feedbackCategoryUsability =>
      'Problem mit der Benutzerfreundlichkeit';

  @override
  String get feedbackCategoryOther => 'Sonstiges';

  @override
  String get feedbackSubject => 'Betreff';

  @override
  String get feedbackDetailedMessage => 'Ausführliche Nachricht';

  @override
  String get feedbackReplyEmail => 'E-Mail-Adresse für Antworten (optional)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Technische Details hinzufügen';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Fügt nur die Version Ihres Linux-Betriebssystems und die Spracheinstellung der Anwendung hinzu. Es werden keine Protokolle, Kontodaten, Dateinamen oder anderen Diagnosedaten hinzugefügt.';

  @override
  String get feedbackCategoryRequired => 'Wählen Sie eine Kategorie aus.';

  @override
  String get feedbackSubjectLengthError =>
      'Der Betreff muss zwischen 3 und 120 Zeichen lang sein.';

  @override
  String get feedbackMessageLengthError =>
      'Die Nachricht muss zwischen 10 und 5.000 Zeichen lang sein.';

  @override
  String get feedbackInvalidEmail =>
      'Geben Sie eine gültige E-Mail-Adresse ein.';

  @override
  String get feedbackConnectionError =>
      'Verbindung zu BusyStack fehlgeschlagen. Prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';

  @override
  String get feedbackTimeoutError =>
      'Die Anfrage hat zu lange gedauert. Ihr Feedback wurde nicht gelöscht; versuchen Sie es erneut.';

  @override
  String get feedbackRateLimitedError =>
      'Aus diesem Netzwerk wurden zu viele Feedbackmeldungen gesendet. Warten Sie und versuchen Sie es erneut.';

  @override
  String get feedbackRejectedError =>
      'Der Server hat die Übermittlung abgelehnt. Prüfen Sie die Felder und versuchen Sie es erneut.';

  @override
  String get feedbackServerError =>
      'BusyStack kann Ihr Feedback derzeit nicht annehmen. Ihr Feedback wurde nicht gelöscht; versuchen Sie es erneut.';

  @override
  String feedbackSuccess(String id) {
    return 'Feedback gesendet. Referenz: $id';
  }

  @override
  String get toggleSidebar => 'Seitenleiste umschalten';

  @override
  String get showSidebar => 'Seitenbereich anzeigen';

  @override
  String get hideSidebar => 'Seitenbereich ausblenden';

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
  String get removeAccount => 'Konto entfernen…';

  @override
  String get removingAccount => 'Konto wird entfernt…';

  @override
  String get removeAccountDescription =>
      'Synchronisierung beenden und die Daten dieses Kontos von diesem Gerät entfernen.';

  @override
  String removeAccountTitle(String account) {
    return '$account aus BusyMax entfernen?';
  }

  @override
  String get removeAccountConfirmation =>
      'This deletes cached tasks, calendars, events, reminders, and pending offline changes from this device. Unsynced changes will be lost. Provider copies of calendars, events, task lists, and tasks are not deleted.';

  @override
  String get revokeGoogleAccess =>
      'BusyMax-Zugriff auf dieses Google-Konto ebenfalls widerrufen';

  @override
  String get revokeGoogleAccessDescription =>
      'Vor einer erneuten Verbindung müssen Sie den Zugriff wieder gewähren.';

  @override
  String get removeAccountAction => 'Konto entfernen';

  @override
  String get removeAccountFailed =>
      'Das Konto konnte nicht vollständig entfernt werden. Versuchen Sie es erneut.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Das Konto wurde von diesem Gerät entfernt, aber BusyMax konnte den Google-Zugriff nicht widerrufen. Sie können ihn in Ihrem Google-Konto widerrufen.';

  @override
  String get newTaskList => 'Neue Aufgabenliste';

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
  String get unshare => 'Freigabe aufheben';

  @override
  String get readOnlyTaskListCannotRename =>
      'This task list is read-only and cannot be renamed.';

  @override
  String get taskListCannotDelete =>
      'This task list cannot be deleted with your current permissions.';

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
  String deleteTaskListConfirmation(String title) {
    return 'Delete \"$title\" and all of its tasks?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Unshare \"$title\" from this account?';
  }

  @override
  String get deleteEvent => 'Termin löschen';

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
      'Wählen oder erstellen Sie zunächst eine Aufgabenliste.';

  @override
  String get signInToViewTasks => 'Melden Sie sich an, um Aufgaben zu sehen.';

  @override
  String get noTasks => 'Keine Aufgaben.';

  @override
  String get noTasksYet => 'Noch keine Aufgaben';

  @override
  String get noTasksYetMessage =>
      'Erstellen Sie eine Aufgabe oder aktualisieren Sie Ihre Konten, um loszulegen.';

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
  String get taskStatus => 'Status';

  @override
  String get taskStatusNone => 'No status';

  @override
  String get taskStatusNeedsAction => 'Handlungsbedarf';

  @override
  String get taskStatusInProcess => 'In Bearbeitung';

  @override
  String get taskStatusCompleted => 'Fertiggestellt';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String completionPercent(int percent) {
    return '$percent% completed';
  }

  @override
  String get completionDate => 'Completion date';

  @override
  String get priority => 'Priorität';

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
  String get reminders => 'Reminders';

  @override
  String get noReminders => 'Keine Erinnerungen';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get beforeTaskStarts => 'Bevor die Aufgabe startet';

  @override
  String get beforeTaskDue => 'Bevor die Aufgabe fällig ist';

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
  String get discardRelatedReminders => 'Erinnerungen verwerfen';

  @override
  String get keepRelatedReminders => 'Erinnerungen behalten';

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
  String get repeatEvery => 'Wiederhole jeden';

  @override
  String get repeatOn => 'Repeat on';

  @override
  String get repeatEnd => 'Wiederholung beenden';

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
    return 'an $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'am Tag $days';
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
    return '$count mal';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'bis $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'This recurrence rule uses options that this editor does not change.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Diese Wiederholung kann nicht mit $provider verwendet werden.';
  }

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
  String get subtasks => 'Unteraufgaben';

  @override
  String get duplicateTask => 'Aufgabe duplizieren';

  @override
  String get taskDuplicated => 'Task duplicated.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Could not duplicate the task: $error';
  }

  @override
  String get hideSubtasks => 'Teilaufgaben ausblenden';

  @override
  String get hideClosedSubtasks => 'Geschlossene Teilaufgaben ausblenden';

  @override
  String get moveToTop => 'Ganz nach oben verschieben';

  @override
  String get deleteTask => 'Aufgabe löschen';

  @override
  String get newSubtask => 'Neue Unteraufgabe';

  @override
  String deleteTaskConfirmation(String title) {
    return '\"$title\" löschen?';
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
  String get parent => 'Übergeordnete Aufgabe';

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
  String get sync => 'Synchronisierung';

  @override
  String get manualFullSync => 'Manuelle vollständige Synchronisierung';

  @override
  String get runInBackgroundWhenClosed =>
      'Nach dem Schließen des Fensters weiter ausführen';

  @override
  String get showTrayIcon => 'Symbol im Benachrichtigungsbereich anzeigen';

  @override
  String get startMinimizedToTray =>
      'Minimiert im Benachrichtigungsbereich starten';

  @override
  String get launchAtLogin => 'Bei der Anmeldung starten';

  @override
  String get launchAtLoginDescription =>
      'BusyMax im Hintergrund starten, damit Erinnerungen nach der Anmeldung funktionieren.';

  @override
  String get launchAtLoginFailed =>
      'Die Einstellung für den Start bei der Anmeldung konnte nicht aktualisiert werden.';

  @override
  String get requiresTrayIcon =>
      'Erfordert das Symbol im Benachrichtigungsbereich.';

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
  String get eventReminders => 'Terminerinnerungen';

  @override
  String get taskReminders => 'Aufgabenerinnerungen';

  @override
  String get notificationDetailLevel => 'Detailgrad der Benachrichtigungen';

  @override
  String get notificationDetailPrivate => 'Privat';

  @override
  String get notificationDetailNormal => 'Normal';

  @override
  String get quietHours => 'Ruhezeiten';

  @override
  String get quietHoursDescription =>
      'Benachrichtigungen während dieses Zeitraums pausieren.';

  @override
  String get quietHoursStart => 'Beginn der Ruhezeit';

  @override
  String get quietHoursEnd => 'Ende der Ruhezeit';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get appearance => 'Darstellung';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeFamily => 'Designfamilie';

  @override
  String get themeFamilyYaru => 'Natives Ubuntu-Design (Yaru)';

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
      'Unterstützt die Berechtigungsbereiche tasks und tasks.readonly';

  @override
  String get requiresTasksScope => 'Erfordert den Berechtigungsbereich tasks';

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
  String get discardChangesAction => 'Verwerfen';

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
      'Dadurch wird der blockierte lokale Vorgang entfernt. Bei der nächsten Synchronisierung werden die Daten aus Google Tasks neu geladen.';

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
  String get eventReminderNotificationTitle => 'Terminerinnerung';

  @override
  String get taskReminderNotificationTitle => 'Aufgabenerinnerung';

  @override
  String get eventReminderNotificationBody => 'Der Termin beginnt bald.';

  @override
  String get taskReminderNotificationBody => 'Die Aufgabe ist bald fällig.';

  @override
  String get notificationOpenAction => 'Öffnen';

  @override
  String get notificationSnoozeAction => 'In 10 Minuten erinnern';

  @override
  String get notificationDismissAction => 'Verwerfen';

  @override
  String get notificationDetailsHidden =>
      'Details werden durch Datenschutzeinstellungen ausgeblendet.';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String get openMonthView => 'Monatsansicht öffnen';

  @override
  String get previousYear => 'Vorheriges Jahr';

  @override
  String get nextYear => 'Nächstes Jahr';

  @override
  String get openYearView => 'Jahresansicht öffnen';

  @override
  String weekNumberTooltip(int number) {
    return 'Woche $number';
  }

  @override
  String get resizeAllDayPanel =>
      'Ganztägigen Bereich vergrößern oder verkleinern';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Dieser Kalender ist schreibgeschützt.';

  @override
  String get selectTimeZone => 'Zeitzone auswählen';

  @override
  String get searchLocations => 'Orte suchen';

  @override
  String get noLocationsFound => 'Keine Orte gefunden';

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
  String get singleOccurrence => 'Dieses Ereignis';

  @override
  String get thisAndFollowingEvents => 'Dieses und folgende Ereignisse';

  @override
  String get thisAndFutureUnavailable =>
      'Von diesem Anbieter nicht unterstützt.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Dieses und die folgenden Ereignisse können nicht sicher verschoben werden. Wählen Sie dieses Ereignis oder die gesamte Serie.';

  @override
  String get entireSeriesMoveUnavailable =>
      'Die Wiederholungsregel ist lokal nicht verfügbar. Verschieben Sie stattdessen dieses Ereignis.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Ereignis kopieren und Original löschen?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax kann dieses Ereignis nicht direkt von $source nach $destination verschieben. Zuerst wird die Kopie erstellt; das Original wird erst nach erfolgreichem Kopieren gelöscht. Ereignis-IDs ändern sich; Antwortstatus von Teilnehmern können zurückgesetzt und Einladungen oder Absagen versendet werden; Konferenzlinks, Anhänge, Erinnerungen, anbieterspezifische Felder und Wiederholungsausnahmen werden möglicherweise nicht übernommen.';
  }

  @override
  String get copyAndDelete => 'Kopieren und löschen';

  @override
  String get chooseRecurringEventScope =>
      'Choose whether this change applies to the entire series or only this occurrence.';

  @override
  String get taskDueBeforeStart =>
      'Die Fälligkeit darf nicht vor dem Beginn liegen.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Lege für Beginn und Fälligkeit jeweils eine Uhrzeit fest oder mache die Aufgabe ganztägig.';

  @override
  String deleteCalendarConfirmation(String title) {
    return '\"$title\" löschen?';
  }

  @override
  String get setCustomCalendarName => 'Benutzerdefinierten Namen festlegen';

  @override
  String get setAction => 'Festlegen';

  @override
  String get removeFromMyCalendars => 'Aus meinen Kalendern entfernen';

  @override
  String get removeAction => 'Entfernen';

  @override
  String removeCalendarConfirmation(String title) {
    return '„$title“ aus Ihrer Google-Kalenderliste entfernen? Der freigegebene Kalender und seine Termine werden nicht gelöscht.';
  }

  @override
  String get calendarCannotRemove =>
      'Dieser Kalender kann in diesem Konto weder gelöscht noch entfernt werden.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Warten Sie, bis die ausstehenden Änderungen dieses Kalenders synchronisiert wurden, bevor Sie ihn löschen oder entfernen.';

  @override
  String get networkOffline => 'Offline';

  @override
  String get networkOfflineDescription =>
      'Änderungen werden synchronisiert, sobald die Verbindung wiederhergestellt ist.';

  @override
  String get networkOfflineTryAgain =>
      'Sie sind offline. Stellen Sie eine Internetverbindung her und versuchen Sie es erneut.';
}

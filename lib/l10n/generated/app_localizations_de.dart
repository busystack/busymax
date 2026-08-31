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
  String get windowsSupport => 'Hilfe';

  @override
  String get windowsThirdPartyLicenses => 'Lizenzen von Drittanbietern';

  @override
  String get windowsSearch => 'Suchen';

  @override
  String get windowsStartupDisabledByUser =>
      'Vom Benutzer in den Windows-Einstellungen deaktiviert.';

  @override
  String get windowsStartupDisabledByPolicy =>
      'Durch eine Windows-Richtlinie deaktiviert.';

  @override
  String get windowsStartupUnavailable =>
      'Verfügbar, nachdem BusyMax aus einem MSIX-Paket installiert wurde.';

  @override
  String get windowsReminderExitNotice =>
      'Erinnerungen enden, wenn BusyMax vollständig beendet wird. Lassen Sie es im Hintergrund laufen, um sie zu erhalten.';

  @override
  String get windowsProductVersionLabel => 'Produktversion';

  @override
  String get windowsPackageVersionLabel => 'Windows-Paketversion';

  @override
  String get windowsUnpackaged => 'Nicht paketiert';

  @override
  String get windowsAgendaLoadMore => 'Weitere Agendaeinträge laden';

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'montags',
      'TU': 'dienstags',
      'WE': 'mittwochs',
      'TH': 'donnerstags',
      'FR': 'freitags',
      'SA': 'samstags',
      'SU': 'sonntags',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return 'an den Tagen $first und $second des Monats';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency an den Tagen $firstDay und $secondDay im $month';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency jeweils am $day. im $firstMonth und $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency jeweils an den Tagen $firstDay und $secondDay im $firstMonth und $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency jeweils an den Tagen $days im $firstMonth und $secondMonth';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Verbinden Sie Google-, Microsoft-, Apple-iCloud-Kalender- oder Nextcloud-Konten.';

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
      'Fügen Sie alle Konten hinzu, die Sie verwenden möchten. BusyMax synchronisiert unterstützte Kalender, Ereignisse, Aufgabenlisten und Aufgaben aus jedem Konto.';

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
  String get calendarCreatedRefreshPending =>
      'Der Kalender wurde erstellt, aber BusyMax konnte das Konto nicht aktualisieren. Er erscheint nach der nächsten Synchronisierung.';

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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString mehr';
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
  String get trayShowBusyMax => 'BusyMax anzeigen';

  @override
  String get trayNewEvent => 'Neuer Termin…';

  @override
  String get trayNewTask => 'Neue Aufgabe…';

  @override
  String get trayToday => 'Heute';

  @override
  String get trayAllDay => 'Ganztägig';

  @override
  String get trayNow => 'Jetzt';

  @override
  String get trayCalendarEvent => 'Kalendertermin';

  @override
  String get trayUntitledEvent => 'Termin ohne Titel';

  @override
  String get trayNothingElseToday => 'Heute nichts Weiteres';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben heute fällig',
      one: '1 Aufgabe heute fällig',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Heutige Agenda öffnen';

  @override
  String get traySyncNow => 'Jetzt synchronisieren';

  @override
  String get traySyncing => 'Synchronisierung…';

  @override
  String get trayNotConnected => 'Nicht verbunden';

  @override
  String get trayNotYetSynced => 'Noch nicht synchronisiert';

  @override
  String get trayLastSyncedJustNow => 'Gerade synchronisiert';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Minuten synchronisiert',
      one: 'Vor 1 Minute synchronisiert',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Stunden synchronisiert',
      one: 'Vor 1 Stunde synchronisiert',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vor $count Tagen synchronisiert',
      one: 'Vor 1 Tag synchronisiert',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Einstellungen';

  @override
  String get trayQuitBusyMax => 'BusyMax beenden';

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
  String get viewAgenda => 'Tagesübersicht';

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
  String get attendeeRequired => 'Erforderlich';

  @override
  String get attendeeOptional => 'Freiwillig';

  @override
  String get meetingSection => 'Besprechung';

  @override
  String get addGoogleMeet => 'Google Meet hinzufügen';

  @override
  String get addTeamsMeeting => 'Microsoft-Teams-Besprechung hinzufügen';

  @override
  String get onlineMeetingAdded => 'Onlinebesprechung hinzugefügt';

  @override
  String get requestResponses => 'Antworten anfordern';

  @override
  String get requestResponsesDescription =>
      'Bitten Sie Gäste, auf die Einladung zu antworten.';

  @override
  String get hideGuestList => 'Gästeliste ausblenden';

  @override
  String get hideGuestListDescription =>
      'Gäste können nicht sehen, wer sonst eingeladen wurde.';

  @override
  String get allowNewTimeProposals => 'Neue Zeitvorschläge zulassen';

  @override
  String get allowNewTimeProposalsDescription =>
      'Gäste können eine andere Besprechungszeit vorschlagen.';

  @override
  String get notifyGuestsTitle => 'Gäste benachrichtigen?';

  @override
  String get notifyGuestsSaveMessage =>
      'Diese Besprechung hat Gäste. Sollen beim Speichern Einladungen oder Terminaktualisierungen gesendet werden?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Diese Besprechung hat Gäste. Soll beim Löschen eine Absage gesendet werden?';

  @override
  String get sendUpdates => 'Aktualisierungen senden';

  @override
  String get sendCancellation => 'Absage senden';

  @override
  String get doNotSend => 'Nicht senden';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Besprechung speichern?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft sendet Einladungen oder Terminaktualisierungen an die Gäste.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Besprechung löschen?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft sendet eine Absage an die Gäste.';

  @override
  String get organizer => 'Organisator';

  @override
  String get yourResponse => 'Ihre Antwort';

  @override
  String get guestResponses => 'Gästeantworten';

  @override
  String get respond => 'Antworten';

  @override
  String get acceptInvitation => 'Annehmen';

  @override
  String get tentativeInvitation => 'Mit Vorbehalt';

  @override
  String get declineInvitation => 'Ablehnen';

  @override
  String get joinMeeting => 'An Besprechung teilnehmen';

  @override
  String get responseAccepted => 'Angenommen';

  @override
  String get responseTentative => 'Mit Vorbehalt';

  @override
  String get responseDeclined => 'Abgelehnt';

  @override
  String get responseNeedsAction => 'Antwort ausstehend';

  @override
  String get responseNotResponded => 'Nicht beantwortet';

  @override
  String get responseOrganizer => 'Organisator';

  @override
  String invitationResponseFailed(String error) {
    return 'Ihre Antwort konnte nicht gesendet werden: $error';
  }

  @override
  String get joinMeetingFailed =>
      'Der Besprechungslink konnte nicht geöffnet werden.';

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
  String get navigation => 'Bedienung';

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
  String get shortcutGroupNavigation => 'Bedienung';

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
  String get website => 'Webseite';

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
      'Fügt nur Name und Version Ihres Betriebssystems sowie die Spracheinstellung der Anwendung hinzu. Es werden keine Protokolle, Kontodaten, Dateinamen oder anderen Diagnosedaten hinzugefügt.';

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
      'Dadurch werden zwischengespeicherte Aufgaben, Kalender, Termine, Erinnerungen und ausstehende Offline-Änderungen von diesem Gerät gelöscht. Nicht synchronisierte Änderungen gehen verloren. Kopien der Kalender, Termine, Aufgabenlisten und Aufgaben beim Anbieter werden nicht gelöscht.';

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
    return 'Aufgabenliste konnte nicht erstellt werden: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Aufgabenliste konnte nicht umbenannt werden: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Aufgabenliste konnte nicht gelöscht werden: $error';
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
      'Diese Aufgabenliste ist schreibgeschützt und kann nicht umbenannt werden.';

  @override
  String get taskListCannotDelete =>
      'Diese Aufgabenliste kann mit Ihren aktuellen Berechtigungen nicht gelöscht werden.';

  @override
  String get builtInMicrosoftList => 'Integriert';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Integrierte Microsoft To Do-Listen können nicht umbenannt oder gelöscht werden.';

  @override
  String deleteListConfirmation(String title) {
    return '„$title“ aus Google Tasks löschen?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '„$title“ und alle Aufgaben löschen?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Freigabe von „$title“ für dieses Konto aufheben?';
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
  String get statusSection => 'Aufgabenstatus';

  @override
  String get openStatus => 'Offen';

  @override
  String get doneStatus => 'Erledigt';

  @override
  String get taskStatus => 'Aufgabenstatus';

  @override
  String get taskStatusNone => 'Kein Status';

  @override
  String get taskStatusNeedsAction => 'Handlungsbedarf';

  @override
  String get taskStatusInProcess => 'In Bearbeitung';

  @override
  String get taskStatusCompleted => 'Erledigt';

  @override
  String get taskStatusCancelled => 'Abgebrochen';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return '$percentString% abgeschlossen';
  }

  @override
  String get completionDate => 'Abschlussdatum';

  @override
  String get priority => 'Priorität';

  @override
  String get priorityNone => 'Keine Priorität';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priorität $priorityString · Hoch';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priorität $priorityString · Mittel';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priorität $priorityString · Niedrig';
  }

  @override
  String get taskUrl => 'Aufgaben-URL';

  @override
  String get invalidTaskUrl =>
      'Geben Sie eine absolute URL einschließlich ihres Schemas ein.';

  @override
  String get classification => 'Klassifizierung';

  @override
  String get classificationPublic =>
      'Bei Freigabe die vollständige Aufgabe anzeigen';

  @override
  String get classificationConfidential =>
      'Bei Freigabe nur den Belegt-Status anzeigen';

  @override
  String get classificationPrivate => 'Diese Aufgabe bei Freigabe ausblenden';

  @override
  String get pinTask => 'Aufgabe anheften';

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
  String get reminders => 'Erinnerungen';

  @override
  String get noReminders => 'Keine Erinnerungen';

  @override
  String get editReminder => 'Erinnerung bearbeiten';

  @override
  String get beforeTaskStarts => 'Vor Beginn der Aufgabe';

  @override
  String get beforeTaskDue => 'Vor Fälligkeit der Aufgabe';

  @override
  String get afterTaskStarts => 'Nach Beginn der Aufgabe';

  @override
  String get afterTaskDue => 'Nach Fälligkeit der Aufgabe';

  @override
  String get relativeToTaskStart => 'Relativ zum Startdatum der Aufgabe';

  @override
  String get relativeToTaskDue => 'Relativ zum Fälligkeitsdatum der Aufgabe';

  @override
  String get reminderTimeOfDay => 'Tageszeit';

  @override
  String get absoluteReminder => 'Zu einem Datum und einer Uhrzeit';

  @override
  String get reminderAmount => 'Menge';

  @override
  String get reminderUnit => 'Einheit';

  @override
  String get reminderUnitSeconds => 'Sekunden';

  @override
  String get reminderUnitMinutes => 'Minuten';

  @override
  String get reminderUnitHours => 'Stunden';

  @override
  String get reminderUnitDays => 'Tage';

  @override
  String get reminderUnitWeeks => 'Wochen';

  @override
  String get reminderAtTaskStart => 'Zu Beginn der Aufgabe';

  @override
  String get reminderAtTaskDue => 'Zum Fälligkeitszeitpunkt der Aufgabe';

  @override
  String get unsupportedReminder =>
      'Dieser Erinnerungstyp bleibt erhalten, aber seine Zeit kann nicht bearbeitet werden.';

  @override
  String get relatedRemindersTitle => 'Verknüpfte Erinnerungen behalten?';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Für dieses Datum gibt es $countString verknüpfte Erinnerungen. Sollen sie ihr aktuelles Datum und ihre aktuelle Uhrzeit behalten?';
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
  String get repeatEvery => 'Intervall';

  @override
  String get repeatOn => 'Wiederholen an';

  @override
  String get repeatEnd => 'Wiederholung beenden';

  @override
  String get repeatNever => 'Nie';

  @override
  String get repeatUntil => 'An einem Datum';

  @override
  String get repeatAfter => 'Nach einer Anzahl von Wiederholungen';

  @override
  String get repeatCount => 'Wiederholungen';

  @override
  String get repeatDayOfMonth => 'Tage des Monats';

  @override
  String get repeatMonths => 'Monate';

  @override
  String get repeatOrdinal => 'Wochentagsposition';

  @override
  String get repeatSpecificDays => 'Bestimmte Tage';

  @override
  String get repeatFirst => 'Erste';

  @override
  String get repeatSecond => 'Zweite';

  @override
  String get repeatThird => 'Dritte';

  @override
  String get repeatFourth => 'Vierte';

  @override
  String get repeatFifth => 'Fünfte';

  @override
  String get repeatSecondToLast => 'Vorletzte';

  @override
  String get repeatLast => 'Letzte';

  @override
  String get repeatAnyDay => 'Tag';

  @override
  String get repeatWeekday => 'Wochentag';

  @override
  String get repeatWeekendDay => 'Wochenendtag';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'Montag',
      'TU': 'Dienstag',
      'WE': 'Mittwoch',
      'TH': 'Donnerstag',
      'FR': 'Freitag',
      'SA': 'Samstag',
      'SU': 'Sonntag',
      'day': 'Tag',
      'weekday': 'Wochentag',
      'weekend': 'Wochenendtag',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Alle $countString Tage';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Alle $countString Wochen';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Alle $countString Monate';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Alle $countString Jahre';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'am $days. Tag';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'am ersten $days',
      'second': 'am zweiten $days',
      'third': 'am dritten $days',
      'fourth': 'am vierten $days',
      'fifth': 'am fünften $days',
      'secondToLast': 'am vorletzten $days',
      'last': 'am letzten $days',
      'other': 'an $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'in den Monaten $months';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString-mal',
      one: '$countString Mal',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'bis $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Diese Wiederholungsregel verwendet Optionen, die dieser Editor nicht ändert.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Diese Wiederholung kann nicht mit $provider verwendet werden.';
  }

  @override
  String get importance => 'Wichtigkeit';

  @override
  String get importanceLow => 'Niedrig';

  @override
  String get importanceNormal => 'Mittel';

  @override
  String get importanceHigh => 'Hoch';

  @override
  String get categories => 'Kategorien';

  @override
  String get scheduleSection => 'Zeitplan';

  @override
  String get dueGroup => 'Fällig';

  @override
  String get startGroup => 'Beginn';

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
  String get taskDuplicated => 'Aufgabe dupliziert.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Aufgabe konnte nicht dupliziert werden: $error';
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
  String get position => 'Reihenfolge';

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
  String get forceFullResync => 'Vollständige Neusynchronisierung erzwingen';

  @override
  String get forceFullResyncDescription =>
      'Lädt alle Daten aus jedem verbundenen Konto vollständig neu. Verwenden Sie diese Option nur zur Behebung von Synchronisierungsproblemen.';

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
  String get onState => 'Ein';

  @override
  String get taskReminders => 'Aufgabenerinnerungen';

  @override
  String get notificationDetailLevel => 'Detailgrad der Benachrichtigungen';

  @override
  String get notificationDetailPrivate => 'Privat';

  @override
  String get notificationDetailNormal => 'Standard';

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
  String get themeSystem => 'Systemstandard';

  @override
  String get settingsSystem => 'System';

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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Versuche=$countString';
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
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Aufgaben sind heute fällig.',
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
  String get notificationDismissAction => 'Schließen';

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
  String get requiredField => 'Dieses Feld ist erforderlich.';

  @override
  String get providerConnectionDescription =>
      'Verbinden Sie Kalender und Aufgaben mit einem dieser Anbieter.';

  @override
  String get appleICloudProvider => 'Apple-iCloud-Kalender';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud-Aufgaben';

  @override
  String get addAppleICloudAccount => 'Apple-iCloud-Kalenderkonto hinzufügen';

  @override
  String get addNextcloudAccount => 'Nextcloud-Konto hinzufügen';

  @override
  String get waitingForAppleICloud =>
      'Verbindung mit Apple iCloud wird hergestellt…';

  @override
  String get waitingForNextcloud => 'Warten auf die Nextcloud-Autorisierung…';

  @override
  String get connectAppleICloudTitle => 'Apple-iCloud-Kalender verbinden';

  @override
  String get appleAccountEmail => 'E-Mail des Apple-Accounts';

  @override
  String get appleAppSpecificPassword => 'App-spezifisches Passwort';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Erstellen Sie nach dem Aktivieren der Zwei-Faktor-Authentifizierung für Ihren Apple-Account ein app-spezifisches Passwort.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Durch das Zurücksetzen Ihres Apple-Account-Passworts werden app-spezifische Passwörter widerrufen.';

  @override
  String get connectNextcloudTitle => 'Nextcloud verbinden';

  @override
  String get nextcloudServerUrl => 'Nextcloud-Server oder CalDAV-Adresse';

  @override
  String get nextcloudServerUrlHelp =>
      'Geben Sie die URL Ihres Nextcloud-Servers ein oder fügen Sie die aus Nextcloud kopierte primäre CalDAV-Adresse ein.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax öffnet Ihren Browser. Genehmigen Sie dort den Zugriff und kehren Sie anschließend zu BusyMax zurück.';

  @override
  String get connectAccountAction => 'Verbinden';

  @override
  String get cancelAccountConnection => 'Verbindung abbrechen';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'Das Konto wurde lokal entfernt, aber das Nextcloud-App-Passwort konnte nicht widerrufen werden.';

  @override
  String get davCachedOfflineNotice =>
      'Kalender- und Aufgabendaten werden für die Offline-Nutzung lokal zwischengespeichert.';

  @override
  String get davReauthenticationRequired =>
      'Verbinden Sie dieses Konto erneut, um die Synchronisierung fortzusetzen.';

  @override
  String get davTemporarilyUnavailable =>
      'Dieses Konto ist vorübergehend nicht verfügbar.';

  @override
  String get davPermissionChanged =>
      'Die Serverberechtigungen wurden geändert. Ausstehende Bearbeitungen sind pausiert.';

  @override
  String get davUnsupportedServer =>
      'Dieser Server oder dieses Anbieterprofil wird nicht unterstützt.';

  @override
  String get collectionSettings => 'Kalender und Aufgabenlisten';

  @override
  String get calendarContent => 'Kalendertermine';

  @override
  String get taskContent => 'Aufgaben';

  @override
  String get readOnlySharedCollection => 'Schreibgeschützt';

  @override
  String get pendingLocally => 'Lokal ausstehend';

  @override
  String get conflictBlocked => 'Durch Konflikt blockiert';

  @override
  String get authenticationBlocked => 'Bis zur erneuten Verbindung blockiert';

  @override
  String get operationFailed => 'Vorgang fehlgeschlagen';

  @override
  String get keepServerVersion => 'Serverversion behalten';

  @override
  String get reapplyLocalChange => 'Lokale Änderung prüfen und erneut anwenden';

  @override
  String get duplicateLocalItem => 'Als neues Element duplizieren';

  @override
  String get davConnectionState => 'Verbindungsstatus';

  @override
  String get davConnected => 'Verbunden';

  @override
  String get davConnecting => 'Verbindung wird hergestellt…';

  @override
  String get davSignedOut => 'Abgemeldet';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Letzte erfolgreiche Synchronisierung: $time';
  }

  @override
  String get davNeverSynced => 'Noch nicht synchronisiert';

  @override
  String get refreshCollections => 'Kalender und Aufgabenlisten aktualisieren';

  @override
  String nextcloudServerHost(String host) {
    return 'Serveradresse: $host';
  }

  @override
  String get collectionSupportsEvents => 'Terminkalender';

  @override
  String get collectionSupportsTasks => 'Aufgabenliste';

  @override
  String get collectionSupportsEventsAndTasks => 'Termine und Aufgaben';

  @override
  String get writableCollection => 'Beschreibbar';

  @override
  String get sharedCollection => 'Freigegeben';

  @override
  String collectionLastSynced(String time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Synchronisierungsproblem: $code';
  }

  @override
  String get syncConflicts => 'Synchronisierungskonflikte';

  @override
  String remoteChangedAt(String time) {
    return 'Server geändert: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Lokale Änderung: $summary';
  }

  @override
  String get conflictResolutionFailed =>
      'Der Konflikt konnte nicht gelöst werden.';

  @override
  String get recurringEventScope => 'Bereich des wiederkehrenden Termins';

  @override
  String get entireSeries => 'Gesamte Serie';

  @override
  String get singleOccurrence => 'Dieser Termin';

  @override
  String get thisAndFollowingEvents => 'Dieser und die folgenden Termine';

  @override
  String get thisAndFutureUnavailable =>
      'Von diesem Anbieter nicht unterstützt.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Dieser Termin und die folgenden Termine können nicht sicher verschoben werden. Wählen Sie diesen Termin oder die gesamte Serie.';

  @override
  String get entireSeriesMoveUnavailable =>
      'Die Wiederholungsregel ist lokal nicht verfügbar. Verschieben Sie stattdessen diesen Termin.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Termin kopieren und Original löschen?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax kann diesen Termin nicht direkt von $source nach $destination verschieben. Zuerst wird die Kopie erstellt; das Original wird erst nach erfolgreichem Kopieren gelöscht. Termin-IDs ändern sich; Antwortstatus von Teilnehmern können zurückgesetzt und Einladungen oder Absagen versendet werden; Konferenzlinks, Anhänge, Erinnerungen, anbieterspezifische Felder und Wiederholungsausnahmen werden möglicherweise nicht übernommen.';
  }

  @override
  String get copyAndDelete => 'Kopieren und löschen';

  @override
  String get chooseRecurringEventScope =>
      'Wählen Sie, ob diese Änderung für die gesamte Serie, nur diesen Termin oder diesen und die folgenden Termine gilt.';

  @override
  String get taskDueBeforeStart =>
      'Die Fälligkeit darf nicht vor dem Beginn liegen.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Legen Sie für Beginn und Fälligkeit jeweils eine Uhrzeit fest oder machen Sie die Aufgabe ganztägig.';

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
      'Dieser Kalender kann nicht gelöscht oder aus diesem Konto entfernt werden.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Warten Sie, bis die ausstehenden Änderungen dieses Kalenders synchronisiert wurden, bevor Sie ihn löschen oder entfernen.';

  @override
  String get calendarSubscriptions => 'Kalenderabonnements';

  @override
  String get calendarSubscriptionsDescription =>
      'Fügen Sie schreibgeschützte Kalender hinzu, die über eine sichere WebCal-URL aktualisiert werden.';

  @override
  String get addCalendarSubscription => 'Kalenderabonnement hinzufügen';

  @override
  String get subscriptionName => 'Lokaler Name';

  @override
  String get subscriptionUrl => 'Abonnement-URL';

  @override
  String get subscriptionUrlHelp =>
      'Geben Sie eine HTTPS- oder webcal-URL ein. BusyMax speichert die vollständige URL sicher.';

  @override
  String get subscriptionUrlInvalid =>
      'Geben Sie eine gültige HTTPS- oder webcal-URL ohne Benutzerinformationen oder Fragment ein.';

  @override
  String get subscriptionColor => 'Lokale Farbe';

  @override
  String get subscriptionColorHelp =>
      'Verwenden Sie eine sechsstellige Farbe wie #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Geben Sie eine sechsstellige Hexadezimalfarbe ein.';

  @override
  String get subscriptionRefreshMode => 'Aktualisierungshäufigkeit';

  @override
  String get subscriptionAutomatic => 'Automatisch';

  @override
  String get subscriptionHourly => 'Stündlich';

  @override
  String get subscriptionSixHours => 'Alle sechs Stunden';

  @override
  String get subscriptionDaily => 'Täglich';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Quelle: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Geben Sie eine gültige URL ein, um ihre sichere Quelle anzuzeigen.';

  @override
  String get subscriptionReadOnly => 'Schreibgeschütztes Abonnement';

  @override
  String get subscriptionNeverRefreshed => 'Noch nicht aktualisiert';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Letzte erfolgreiche Aktualisierung: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Nächste Aktualisierung: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Aktuell';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Aktualisierungsproblem: $code';
  }

  @override
  String get refreshNow => 'Jetzt aktualisieren';

  @override
  String get unsubscribe => 'Abbestellen';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '„$name“ abbestellen?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Dadurch werden das lokale Abonnement und die zwischengespeicherten Termine entfernt. Der veröffentlichte Kalender wird nicht geändert.';

  @override
  String get addSubscriptionAction => 'Abonnement hinzufügen';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Kalenderabonnement fehlgeschlagen: $error';
  }

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get calendarImport => 'Kalenderimport';

  @override
  String get calendarImportDescription =>
      'Wählen Sie eine Datei aus, prüfen Sie ihre Termine und wählen Sie anschließend den beschreibbaren Kalender aus, der sie aufnehmen soll.';

  @override
  String get importIcsFile => '‎.ics-Datei importieren';

  @override
  String get importIcsPreview => 'Kalendertermine importieren';

  @override
  String importEventsFound(int count) {
    return 'Importierbare Terminserien: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Ungültige Termine: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Absichtlich ausgelassen: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Kein beschreibbarer Zielkalender verfügbar.';

  @override
  String get importDestinationCalendar => 'Zielkalender';

  @override
  String get importIcsConfirm => 'Termine importieren';

  @override
  String get importIcsComplete => 'Import abgeschlossen';

  @override
  String importQueued(int count) {
    return 'Importiert oder in die Warteschlange gestellt: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Übersprungene Duplikate: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Nicht unterstützte Wiederholungsserien: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Kalenderdatei konnte nicht importiert werden: $error';
  }

  @override
  String get networkOffline => 'Ohne Verbindung';

  @override
  String get networkOfflineDescription =>
      'Änderungen werden synchronisiert, sobald die Verbindung wiederhergestellt ist.';

  @override
  String get networkOfflineTryAgain =>
      'Sie sind offline. Stellen Sie eine Internetverbindung her und versuchen Sie es erneut.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'an den Tagen $days des Monats';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first und $second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first und $second';
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
    return '$first und $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first und $second';
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
    return '$frequency am $day. $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency an den Tagen $days im $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency jeweils am $day. in $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency jeweils an den Tagen $days in $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'am ersten',
      'second': 'am zweiten',
      'third': 'am dritten',
      'fourth': 'am vierten',
      'fifth': 'am fünften',
      'secondToLast': 'am vorletzten',
      'last': 'am letzten',
      'other': 'an',
    });
    return '$frequency $_temp0 $days im $month';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'jeweils am ersten',
      'second': 'jeweils am zweiten',
      'third': 'jeweils am dritten',
      'fourth': 'jeweils am vierten',
      'fifth': 'jeweils am fünften',
      'secondToLast': 'jeweils am vorletzten',
      'last': 'jeweils am letzten',
      'other': 'jeweils an',
    });
    return '$frequency $_temp0 $days in $months';
  }
}

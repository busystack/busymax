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
  String get launchAtLoginManagedExternally =>
      'BusyMax wurde durch die Autostart-Einstellungen Ihres Desktops gestartet. Entfernen Sie dort den Eintrag, beenden Sie BusyMax und öffnen Sie es erneut, um diesen Schalter zu verwenden.';

  @override
  String get timeFormat => 'Zeitformat';

  @override
  String get firstDayOfWeek => 'Erster Wochentag';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String systemDefaultResolved(String weekday) {
    return 'Systemstandard ($weekday)';
  }

  @override
  String get timeFormatTwelveHour => '12 Stunden';

  @override
  String get timeFormatTwentyFourHour => '24 Stunden';

  @override
  String get timeEndOfDay => 'Tagesende';

  @override
  String get timePeriod => 'Tageszeit';

  @override
  String get launchAtLoginReadFailed =>
      'Der Status des Starts bei der Anmeldung konnte nicht ermittelt werden.';

  @override
  String get launchAtLoginUnavailable =>
      'Der Start bei der Anmeldung ist auf diesem System nicht verfügbar.';

  @override
  String get windowsStartupEnabledByPolicy =>
      'Der Autostart wurde von Ihrem Administrator aktiviert und kann hier nicht geändert werden.';

  @override
  String get settingsSaveFailed =>
      'Die Einstellungen konnten nicht gespeichert werden. Ihre Änderungen können beim Neustart von BusyMax verloren gehen.';

  @override
  String get nextcloudExportCollection => 'Sammlungsressourcen exportieren';

  @override
  String nextcloudImportItems(int count) {
    return '$count Ereignis-/Aufgabenressourcen gefunden';
  }

  @override
  String get nextcloudSchedulingInbox => 'Einladungsposteingang';

  @override
  String get nextcloudInboxExplanation =>
      'Nextcloud verarbeitet diese Nachrichten in Ihren Kalendern. Eine Bestätigung entfernt nur die Nachricht, nicht den Termin.';

  @override
  String get nextcloudInboxEmpty => 'Keine Planungsnachrichten.';

  @override
  String get nextcloudAcknowledge => 'Nachricht bestätigen';

  @override
  String get nextcloudAcknowledgeConfirm =>
      'Diese Nachricht aus dem Posteingang entfernen? Der Termin bleibt erhalten.';

  @override
  String get nextcloudGuestAvailability => 'Verfügbarkeit der Gäste prüfen';

  @override
  String nextcloudTrashRetention(int days) {
    return 'Aufbewahrung im Server-Papierkorb: $days Tage';
  }

  @override
  String get nextcloudCancelMeeting => 'Besprechung absagen';

  @override
  String get nextcloudDeclineAndRemove => 'Einladung ablehnen und entfernen';

  @override
  String get nextcloudDeclineRemovalWarning =>
      'Beim Synchronisieren wird eine Absage gesendet. Die Besprechung des Organisators wird nicht abgesagt.';

  @override
  String get nextcloudAvailabilityUnknown => 'Verfügbarkeit unbekannt';

  @override
  String get nextcloudAvailabilityFree =>
      'Für diesen Zeitraum wurden keine Belegtzeiten gemeldet';

  @override
  String get nextcloudAvailabilityBusy => 'Belegte Zeiträume';

  @override
  String get nextcloudSchedulingPending =>
      'Nextcloud sendet Besprechungsänderungen bei der Synchronisierung. Lokales Speichern bestätigt keine Zustellung.';

  @override
  String get nextcloudAttendeeRestrictions =>
      'Nur der Organisator oder ein berechtigter Stellvertreter kann Besprechungsdetails ändern. Sie können in den Details auf die Einladung antworten.';

  @override
  String get nextcloudMeetingMoveUnsupported =>
      'Diese Besprechung kann nicht durch Kopieren und Löschen verschoben werden. Verwenden Sie einen Kalender derselben Planungsidentität.';

  @override
  String get nextcloudSchedulingStatus => 'Planungsstatus des Servers';

  @override
  String get nextcloudImportFollowUp =>
      'Die importierten Ressourcen wurden lokal gespeichert. Die Erinnerungsaktualisierung steht aus; importieren Sie sie nicht erneut.';

  @override
  String get nextcloudNativeImport =>
      'Vollständige Termine und Aufgaben ohne Einladungsversand importieren. Vorhandene UIDs werden übersprungen, außer bei neuen Kopien. Nicht unterstützte Ressourcen werden einzeln gemeldet.';

  @override
  String get nextcloudImportMethod =>
      'Diese Datei enthält Planungsnachrichten. Der Import speichert deren Inhalt und entfernt METHOD; Einladungen und Antworten werden nicht verarbeitet.';

  @override
  String get nextcloudImportCopies =>
      'Als neue Kopien mit neuen Identitäten importieren';

  @override
  String get nextcloudCollectionSettings => 'Sammlungseinstellungen';

  @override
  String get nextcloudSharing => 'Freigabe';

  @override
  String get nextcloudOwned => 'Eigene Sammlung';

  @override
  String get nextcloudShared => 'Freigegeben';

  @override
  String get nextcloudDelegated => 'Delegiert';

  @override
  String get nextcloudSubscription => 'Abonniert';

  @override
  String get nextcloudDeleted => 'Gelöscht';

  @override
  String get nextcloudMetadataEditable =>
      'Kalenderinhalte sind schreibgeschützt; Sammlungseigenschaften können geändert werden.';

  @override
  String get nextcloudServerOrder =>
      'Serverreihenfolge (unabhängig von der Seitenleiste)';

  @override
  String get nextcloudCalendarEnabled => 'Auf dem Server aktiviert';

  @override
  String get nextcloudAvailability =>
      'Diese Sammlung bei der Verfügbarkeit berücksichtigen';

  @override
  String get nextcloudCalendarTimezone =>
      'Kalenderzeitzone (VTIMEZONE-Dokument)';

  @override
  String get nextcloudRefreshPending =>
      'Die Änderung wurde auf Nextcloud gespeichert. Die Aktualisierung steht aus; wiederholen Sie die Änderung nicht.';

  @override
  String get nextcloudOutcomeUnknown =>
      'Das Serverergebnis konnte nicht bestätigt werden. Aktualisieren Sie vor einem neuen Versuch.';

  @override
  String get nextcloudRemoveShared => 'Freigegebenen Kalender/Liste entfernen';

  @override
  String get nextcloudRemoveMixed =>
      'Diese Sammlung enthält Termine und Aufgaben. Beim Löschen werden beide entfernt.';

  @override
  String get nextcloudReadAccess => 'Nur lesen';

  @override
  String get nextcloudWriteAccess => 'Lesen und schreiben';

  @override
  String get nextcloudRecipientSearch => 'Personen oder Gruppen suchen';

  @override
  String get nextcloudNoRecipients => 'Keine passenden Personen oder Gruppen.';

  @override
  String get nextcloudRevokeShare => 'Zugriff widerrufen';

  @override
  String get nextcloudPublish => 'Link veröffentlichen';

  @override
  String get nextcloudUnpublish => 'Veröffentlichung beenden';

  @override
  String get nextcloudPublishWarning =>
      'Jeder mit dem veröffentlichten Link kann diesen Kalender möglicherweise lesen. Veröffentlichen?';

  @override
  String get nextcloudTrash => 'Gelöschte Kalender und Aufgaben';

  @override
  String get nextcloudTrashEmpty => 'Keine gelöschten Kalenderelemente.';

  @override
  String get nextcloudRestore => 'Wiederherstellen';

  @override
  String get nextcloudPermanentDelete => 'Endgültig löschen';

  @override
  String get nextcloudPermanentDeleteWarning =>
      'Dieses Element endgültig löschen? Es kann nicht aus dem Nextcloud-Kalenderpapierkorb wiederhergestellt werden.';

  @override
  String get nextcloudOperationDenied =>
      'Nextcloud hat diesen Vorgang nicht erlaubt.';

  @override
  String get nextcloudUnsupported =>
      'Der Server unterstützt diesen Vorgang nicht.';

  @override
  String get nextcloudPendingChanges =>
      'Sammlungsänderungen vor dem Schließen speichern oder verwerfen.';

  @override
  String get nextcloudServerUnavailable =>
      'Nextcloud ist nicht erreichbar. Zwischengespeicherte Elemente und ausstehende Änderungen bleiben unverändert.';

  @override
  String get mapsShow => 'Auf Karte anzeigen';

  @override
  String get openLink => 'Link öffnen';

  @override
  String get externalLocationOpenFailed =>
      'Der Ort konnte nicht in einer externen Anwendung geöffnet werden.';

  @override
  String scheduleProposedRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get scheduleRescheduleFailed =>
      'Der Termin konnte nicht verschoben werden. Seine gespeicherte Zeit wurde nicht geändert.';

  @override
  String get scheduleRescheduleStale =>
      'Dieser Termin wurde während des Ziehens geändert. Bitte versuche es erneut.';

  @override
  String get scheduleRescheduleNotificationsFailed =>
      'Die neue Zeit wurde gespeichert, aber die Erinnerungen konnten nicht aktualisiert werden.';

  @override
  String get moveUp => 'Nach oben verschieben';

  @override
  String get moveDown => 'Nach unten verschieben';

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
  String get windowMinimize => 'Minimieren';

  @override
  String get windowMaximize => 'Maximieren';

  @override
  String get windowRestore => 'Wiederherstellen';

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
  String get linkedResources => 'Verknüpfte Ressourcen';

  @override
  String get noLinkedResources => 'Keine verknüpften Ressourcen';

  @override
  String get attachments => 'Anhänge';

  @override
  String get attachmentsNotLoaded => 'Anhänge nicht geladen';

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
  String get newEventsAndTasks => 'Neue Ereignisse und Aufgaben';

  @override
  String get defaultCalendar => 'Standardkalender';

  @override
  String get defaultTaskList => 'Standardaufgabenliste';

  @override
  String get lastUsed => 'Zuletzt verwendet';

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
  String get viewSelector => 'Ansicht';

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
  String get taskListPendingChangesPreventRemoval =>
      'Synchronisieren Sie das Konto oder beheben Sie die blockierten Änderungen dieser Aufgabenliste unter „Diagnose“, bevor Sie die Liste löschen oder entfernen.';

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
  String get taskRecurrenceDestinationUnsupported =>
      'Diese Liste unterstützt dieses Wiederholungsmuster nicht. Ändere das Muster oder wähle eine andere Liste.';

  @override
  String get taskRecurrenceRequiresDate =>
      'Füge ein Start- oder Fälligkeitsdatum hinzu, um dieses Wiederholungsmuster zu verwenden, oder deaktiviere die Wiederholung.';

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
  String get deleteAssignedTaskWarning =>
      'Dadurch wird auch die ursprüngliche Aufgabe in Google Docs oder Chat-Bereichen gelöscht.';

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
  String get windowsNotificationsUnavailable =>
      'Windows-Benachrichtigungen sind nicht verfügbar';

  @override
  String get windowsNotificationsUnpackaged =>
      'Diese nicht paketierte Entwicklungsausführung kann keine Windows-Benachrichtigungen verwenden. Installieren Sie das testsignierte MSIX, um Erinnerungen zu testen.';

  @override
  String get windowsNotificationsInstalledFailure =>
      'BusyMax konnte Windows-Benachrichtigungen nicht initialisieren. Erinnerungen werden erst angezeigt, wenn dieses Installationsproblem behoben ist.';

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
  String removeOpenedSharedCalendarConfirmation(String title) {
    return '„$title“ aus BusyMax entfernen? Der Kalender und die Termine des Besitzers werden nicht gelöscht.';
  }

  @override
  String get attachmentUploadUnresolved =>
      'Der Upload wurde möglicherweise abgeschlossen. Aktualisieren Sie die Anhänge, bevor Sie erneut hochladen.';

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

  @override
  String get searchFilters => 'Suchfilter';

  @override
  String get searchType => 'Eintragstyp';

  @override
  String get searchDate => 'Datum';

  @override
  String get searchAnyDate => 'Beliebiges Datum (heruntergeladene Daten)';

  @override
  String get eventLink => 'Terminlink';

  @override
  String get eventLinkOpenFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get scheduleRangeIncomplete =>
      'Einige Termine konnten nicht geprüft werden. Heruntergeladene Daten werden angezeigt.';

  @override
  String get searchThisWeek => 'Diese Woche';

  @override
  String get searchCustomRange => 'Eigener Zeitraum';

  @override
  String get searchTaskStatus => 'Aufgabenstatus';

  @override
  String get searchTaskDue => 'Aufgabenfälligkeit';

  @override
  String get searchAnyDueState => 'Beliebige Fälligkeit';

  @override
  String get searchNoDueDate => 'Kein Fälligkeitsdatum';

  @override
  String get searchPerson => 'Beteiligte Person';

  @override
  String get searchSources => 'Quellen';

  @override
  String get searchClearFilters => 'Filter zurücksetzen';

  @override
  String get searchFiltersAction => 'Suchfilter öffnen';

  @override
  String get searchNoSources => 'Keine Suchquellen ausgewählt';

  @override
  String get searchClearText => 'Text löschen';

  @override
  String get openSharedCalendar => 'Freigegebenen Kalender öffnen';

  @override
  String get manageCalendarSharing => 'Kalenderfreigabe verwalten';

  @override
  String get shareRecipientEmail => 'E-Mail-Adresse des Empfängers';

  @override
  String get shareRole => 'Zugriffsrolle';

  @override
  String get addCalendarShare => 'Zugriff hinzufügen';

  @override
  String get sharingRefreshFailed =>
      'Die Freigabe wurde geändert, aber die Berechtigungsliste konnte nicht aktualisiert werden. Laden Sie sie vor einer weiteren Änderung neu.';

  @override
  String get sharingRateLimited =>
      'Die Freigabe ist vorübergehend begrenzt. Versuchen Sie es nach der Wartezeit erneut.';

  @override
  String get attachmentUploadRateLimited =>
      'Das Hochladen von Anhängen ist vorübergehend begrenzt. Versuchen Sie es nach der Wartezeit erneut.';

  @override
  String get sharingPermissionUnavailable =>
      'Freigabeberechtigungen sind für diesen Kalender nicht verfügbar.';

  @override
  String get calendarShareFreeBusy => 'Nur Frei/Gebucht';

  @override
  String get calendarShareLimitedRead => 'Eingeschränkte Details lesen';

  @override
  String get calendarShareRead => 'Alle Details lesen';

  @override
  String get calendarShareWrite => 'Termine bearbeiten';

  @override
  String get calendarShareWriteWithoutPrivate =>
      'Ohne private Details bearbeiten';

  @override
  String get calendarShareOwner => 'Besitzer';

  @override
  String get eventLabel => 'Terminlabel';

  @override
  String get loadOutlookCategories => 'Outlook-Kategorien laden';

  @override
  String get outlookCategoriesUnavailable =>
      'Outlook-Kategorien sind nicht verfügbar; bestehende Zuordnungen bleiben erhalten.';

  @override
  String get googleEventType => 'Termintyp';

  @override
  String get googleRegularEvent => 'Normaler Termin';

  @override
  String get googleFocusTime => 'Fokuszeit';

  @override
  String get googleOutOfOffice => 'Abwesend';

  @override
  String get googleWorkingLocation => 'Arbeitsort';

  @override
  String get googleDeclineInvitations => 'Überschneidende Einladungen ablehnen';

  @override
  String get googleDeclineNone => 'Nicht ablehnen';

  @override
  String get googleDeclineNew => 'Neue Einladungen ablehnen';

  @override
  String get googleDeclineAll => 'Alle kollidierenden Einladungen ablehnen';

  @override
  String get googleDeclineMessage => 'Ablehnungsnachricht';

  @override
  String get googleChatStatus => 'Chatstatus';

  @override
  String get googleChatAvailable => 'Verfügbar';

  @override
  String get googleChatDoNotDisturb => 'Nicht stören';

  @override
  String get googleWorkAtHome => 'Zu Hause';

  @override
  String get googleWorkAtOffice => 'Im Büro';

  @override
  String get googleWorkAtCustomLocation => 'Eigener Ort';

  @override
  String get googleWorkLocationLabel => 'Ortsbezeichnung';

  @override
  String get googleStatusPrimaryOnly =>
      'Google-Statusereignisse benötigen Ihren primären Google-Kalender.';

  @override
  String unknownEventLabel(String id) {
    return 'Unbekanntes Label ($id)';
  }

  @override
  String get calendarOwnerEmail => 'E-Mail-Adresse des Kalenderbesitzers';

  @override
  String registrationSetupTitle(String provider) {
    return '$provider einrichten';
  }

  @override
  String get registrationSetupGuide => 'Einrichtungsanleitung';

  @override
  String get registrationGoogleInstructions =>
      'Erstellen Sie Ihr eigenes Google Cloud-Projekt, aktivieren Sie Calendar und Tasks und importieren Sie die JSON-Datei eines Desktop-OAuth-Clients. Autorisieren Sie das gewünschte Konto.';

  @override
  String get registrationMicrosoftInstructions =>
      'Verwenden Sie eine öffentliche App-Registrierung in einem Entra-Mandanten, der Registrierungen erlaubt. Geben Sie Client-ID und Kontotypen an. Kein Clientgeheimnis erforderlich.';

  @override
  String get registrationImportGoogle => 'Desktop-OAuth-JSON auswählen';

  @override
  String get registrationValidate => 'Registrierung prüfen';

  @override
  String get registrationAuthorize => 'Im Browser autorisieren';

  @override
  String get registrationClientId => 'Anwendungs-/Client-ID';

  @override
  String get registrationTenantId => 'Mandanten-ID';

  @override
  String get registrationAudience => 'Unterstützte Konten';

  @override
  String get registrationBothAudience => 'Private und Organisationskonten';

  @override
  String get registrationOrganizationAudience => 'Organisationskonten';

  @override
  String get registrationPersonalAudience => 'Private Konten';

  @override
  String get registrationTenantAudience => 'Ein Organisationsmandant';

  @override
  String registrationSummary(String clientId) {
    return 'Registrierung: $clientId';
  }

  @override
  String get registrationMigrate => 'Jetzt migrieren';

  @override
  String get registrationReplace => 'Registrierung ersetzen';

  @override
  String registrationRetirementNotice(String provider, String setup) {
    return 'Dieses Konto verwendet eine ursprüngliche $provider-Registrierung für bestehende Konten. Zum Ersetzen richten Sie $setup ein und verbinden dieses Konto erneut. Kalender, Aufgaben und lokale Änderungen bleiben erhalten.';
  }

  @override
  String get registrationContinue => 'Dieses Konto weiter verwenden';

  @override
  String get registrationGoogleProject => 'Google Cloud-Projekt';

  @override
  String get registrationMicrosoftApp => 'Microsoft-App-Registrierung';

  @override
  String get registrationUserOwned =>
      'Vom Benutzer bereitgestellte Registrierung';

  @override
  String get registrationNativeGoogle => 'Native Google-Android-Registrierung';

  @override
  String get registrationShared => 'Gemeinsame Registrierung (Übergang)';

  @override
  String get registrationUnresolved =>
      'Die Herkunft der Registrierung ist ungeklärt. Kontodaten bleiben erhalten.';

  @override
  String get registrationOfficialDocumentation => 'Offizielle Dokumentation';

  @override
  String registrationAndroidIdentity(
    String packageName,
    String signatureHash,
    String redirectUri,
  ) {
    return 'Paket: $packageName\nSignaturhash: $signatureHash\nUmleitungs-URI: $redirectUri';
  }

  @override
  String get oauthRegistrationRejected =>
      'Prüfen Sie Clienttyp, unterstützte Konten, Berechtigungen und Weiterleitung Ihrer Registrierung. Wählen Sie eine importierte Konfiguration erneut aus.';

  @override
  String get oauthAuthorizationCodeUnusable =>
      'Dieser Autorisierungsversuch konnte nicht abgeschlossen werden. Starten Sie erneut; die bestehende Verbindung bleibt erhalten.';

  @override
  String get oauthPermissionRefused =>
      'Die Autorisierung wurde verweigert oder erforderliche Berechtigungen fehlen. Versuchen Sie es erneut und erteilen Sie die Berechtigungen.';

  @override
  String get oauthProviderThrottled =>
      'Der Anbieter begrenzt Anfragen. Warten Sie vor einem neuen Versuch; die bestehende Verbindung bleibt erhalten.';

  @override
  String get oauthProviderTemporaryFailure =>
      'Ein vorübergehendes Anbieterproblem verhindert die Autorisierung. Versuchen Sie es erneut; die bestehende Verbindung bleibt erhalten.';

  @override
  String get oauthAuthorizationTimedOut =>
      'Die Autorisierung hat zu lange gedauert. Versuchen Sie es erneut und wählen Sie eine importierte Konfiguration neu aus.';

  @override
  String get oauthWrongAccount =>
      'Autorisieren Sie das für die Wiederverbindung ausgewählte Konto. Die bestehende Verbindung bleibt erhalten.';

  @override
  String get oauthSecureStorageUnavailable =>
      'Der sichere Speicher ist nicht verfügbar. Stellen Sie den Zugriff wieder her und versuchen Sie es erneut.';

  @override
  String get oauthRevokedRemovalIncomplete =>
      'Die entfernte Autorisierung wurde widerrufen, aber die Kontobereinigung konnte nicht abgeschlossen werden. Starten Sie BusyMax neu, um die lokale Wiederherstellung erneut zu versuchen.';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get registrationConnect => 'Verbinden';

  @override
  String get registrationBack => 'Zurück';

  @override
  String get registrationReplaceGoogle => 'Desktop-OAuth-JSON ersetzen';

  @override
  String get registrationSelectedConfiguration => 'Ausgewählte Konfiguration';

  @override
  String get registrationDirectoryId => 'Verzeichnis-/Mandanten-ID';

  @override
  String get registrationInvalidId => 'Geben Sie eine gültige UUID ein.';

  @override
  String get registrationExpired =>
      'Diese Konfiguration ist abgelaufen. Importieren Sie sie erneut oder bearbeiten Sie die Registrierungsfelder.';

  @override
  String get registrationOwnProjectRequired =>
      'Wählen Sie eine Registrierung aus Ihrem eigenen Projekt oder Mandanten.';

  @override
  String get registrationSetupFailed =>
      'Die Einrichtung konnte nicht abgeschlossen werden. Versuchen Sie es erneut.';

  @override
  String get registrationLinkFailed =>
      'Der Link konnte nicht geöffnet werden. Prüfen Sie Ihren Browser und versuchen Sie es erneut.';

  @override
  String get registrationPermissions => 'Berechtigungen';

  @override
  String get registrationDesktopClient => 'Desktopanwendung';

  @override
  String get registrationOpenGoogleConsole => 'Google Cloud Console öffnen';

  @override
  String get registrationGoogleAudienceHelp =>
      'Google: Veröffentlichung und Testnutzer';

  @override
  String get registrationDesktopHelp =>
      'Anleitung zur Registrierung von Desktopanwendungen';

  @override
  String get registrationOpenEntra => 'Microsoft Entra Admin Center öffnen';

  @override
  String get registrationGuideGoogleProject =>
      'Öffnen Sie die Google Cloud Console. Wählen Sie oben in der Projektauswahl Ihr eigenes Projekt aus oder wählen Sie New project, geben Sie einen Namen ein und wählen Sie Create. Lassen Sie dieses Projekt für die weiteren Schritte ausgewählt.';

  @override
  String get registrationGuideGoogleAudience =>
      'Öffnen Sie Google Auth Platform → Branding. Wählen Sie bei einer neuen Einrichtung Get started. Geben Sie BusyMax als App name ein, wählen Sie Ihre eigene User support email und anschließend Next. Wählen Sie unter Audience External. Wählen Sie Next, geben Sie unter Contact Information Ihre E-Mail-Adresse ein und wählen Sie Next. Akzeptieren Sie die User Data Policy und wählen Sie Continue und Create. Prüfen Sie bei einer vorhandenen Einrichtung Branding und Audience.';

  @override
  String get registrationGuideGooglePermissions =>
      'Öffnen Sie Google Auth Platform → Data Access → Add or remove scopes. Wählen Sie die fünf folgenden Bereiche; verwenden Sie bei Bedarf Manually add scopes. Fügen Sie bei manueller Eingabe die fehlenden Werte ein und wählen Sie Add to table. Wählen Sie Update und dann Save. BusyMax benötigt Zugriff auf Kalender und Aufgaben.';

  @override
  String get registrationGuideGoogleClient =>
      'Öffnen Sie Google Auth Platform → Clients → Create client. Wählen Sie als Application type Desktop app, geben Sie BusyMax als Name ein und wählen Sie Create. Wählen Sie im Erstellungsdialog Download JSON und speichern Sie die Datei. Wählen Sie Zurück, um zum Formular zurückzukehren, wählen Sie die Datei aus und prüfen Sie Projekt und Client-ID. Wählen Sie Verbinden und genehmigen Sie im Browser den Zugriff auf Kalender und Aufgaben.';

  @override
  String get registrationGuideMicrosoftApp =>
      'Melden Sie sich im Microsoft Entra Admin Center an. Wählen Sie über Settings einen Mandanten aus, in dem Sie Anwendungen registrieren dürfen. Öffnen Sie Entra ID → App registrations → New registration. Geben Sie BusyMax als Name ein und wählen Sie im nächsten Schritt die unterstützten Kontotypen. Bitten Sie bei gesperrter Registrierung Ihren Mandantenadministrator um Zugriff.';

  @override
  String get registrationGuideMicrosoftRedirect =>
      'Öffnen Sie in Ihrer Registrierung Authentication → Add a platform → Mobile and desktop applications. Wählen Sie die folgende Umleitungs-URI aus oder geben Sie sie ein und speichern Sie mit Configure. BusyMax verwendet Ihren Systembrowser. Ein Clientgeheimnis ist nicht erforderlich.';

  @override
  String get registrationGuideMicrosoftPermissions =>
      'Öffnen Sie API permissions → Add a permission → Microsoft Graph → Delegated permissions. Suchen und wählen Sie jeden folgenden Bereich und wählen Sie Add permissions. Behalten Sie User.Read, falls es bereits vorhanden ist. Falls Ihre Organisation eine Administratorzustimmung verlangt, bitten Sie einen Administrator, Grant admin consent für Ihren Mandanten zu verwenden.';

  @override
  String get registrationGuideMicrosoftConnect =>
      'Wählen Sie Zurück, um zum Formular zurückzukehren. Fügen Sie die Application (client) ID ein und wählen Sie dieselben unterstützten Konten wie in der Registrierung. Fügen Sie bei einem Organisationsmandanten auch die Directory (tenant) ID ein. Wählen Sie Verbinden und melden Sie sich im Browser am gewünschten Konto an. BusyMax prüft die Felder lokal; Microsoft fragt während der Browseranmeldung nach Ihrer Zustimmung.';

  @override
  String get registrationGoogleImportFailed =>
      'Diese Datei konnte nicht importiert werden. Wählen Sie eine gültige Desktop-OAuth-JSON. Eine vorherige gültige Auswahl bleibt erhalten.';

  @override
  String get registrationGoogleSetupInstructions =>
      'Google-Einrichtungsanleitung';

  @override
  String get registrationMicrosoftSetupInstructions =>
      'Microsoft-Einrichtungsanleitung';

  @override
  String get registrationDesktopConfiguration => 'Desktop-OAuth-Konfiguration';

  @override
  String get registrationNoFileSelected => 'Keine Datei ausgewählt';

  @override
  String get registrationChooseFile => 'Datei auswählen…';

  @override
  String get registrationReplaceFile => 'Ersetzen…';

  @override
  String get registrationGoogleIntroduction =>
      'Wählen Sie die Desktop-OAuth-JSON-Datei aus Ihrem eigenen Google-Cloud-Projekt.';

  @override
  String get registrationMicrosoftIntroduction =>
      'Geben Sie die Daten Ihrer eigenen Microsoft-App-Registrierung ein.';

  @override
  String get registrationSetupInstructions => 'Einrichtungsanleitung';

  @override
  String get registrationInstructionsDescription =>
      'Erstellen Sie die Konfiguration zum Verbinden Ihres Kontos.';

  @override
  String get registrationEnableApis => 'Kalender und Tasks aktivieren';

  @override
  String get registrationConsentScreen => 'Zustimmungsbildschirm konfigurieren';

  @override
  String get registrationAppName => 'App-Name';

  @override
  String get registrationScopes => 'Berechtigungsbereiche';

  @override
  String get registrationRedirectUri => 'Umleitungs-URI';

  @override
  String get registrationOpenApiLibrary => 'Google-API-Bibliothek öffnen';

  @override
  String get registrationOpenBranding =>
      'Branding in Google Auth Platform öffnen';

  @override
  String get registrationOpenDataAccess =>
      'Datenzugriff in Google Auth Platform öffnen';

  @override
  String get registrationOpenClients =>
      'Clients in Google Auth Platform öffnen';

  @override
  String get registrationOpenEntraAuthentication =>
      'Entra-App-Registrierungen für die Authentifizierung öffnen';

  @override
  String get registrationOpenEntraPermissions =>
      'Entra-App-Registrierungen für API-Berechtigungen öffnen';

  @override
  String get registrationCopy => 'Kopieren';

  @override
  String get registrationCopyAll => 'Alle kopieren';

  @override
  String get registrationGuideGoogleApis =>
      'Öffnen Sie APIs & Services → Library. Suchen Sie Google Calendar API, öffnen Sie die Seite und wählen Sie Enable. Kehren Sie zur Library zurück und wiederholen Sie dies für Google Tasks API.';

  @override
  String get registrationGuideMicrosoftAudience =>
      'Wählen Sie unter Supported account types Personal accounts only für persönliche Konten, Multiple Entra ID tenants für Organisationskonten, Any Entra ID Tenant + Personal Microsoft accounts für beide oder Single tenant only für dieses Verzeichnis. Wählen Sie Register. Kopieren Sie unter Overview die Application (client) ID; bei einem Mandanten auch die Directory (tenant) ID. Wählen Sie in BusyMax die entsprechende Option unter Unterstützte Konten.';

  @override
  String get registrationConnectBusyMax => 'Mit BusyMax verbinden';

  @override
  String get registrationRecommended => 'Empfohlen';

  @override
  String get registrationOtherMethods => 'Weitere Verbindungsmethoden';

  @override
  String get registrationWorkspace => 'Google Workspace-Organisation';

  @override
  String get registrationGoogleCustom => 'Eigener OAuth-Client';

  @override
  String get registrationMicrosoftCustom => 'Eigene App-Registrierung';

  @override
  String get registrationMethodsIntroduction =>
      'Wählen Sie, wie Sie Ihr Konto verbinden möchten.';

  @override
  String get registrationWorkspaceDescription =>
      'Verwenden Sie eine von Ihrer Organisation verwaltete Konfiguration.';

  @override
  String get registrationCustomDescription =>
      'Verwenden Sie eine selbst verwaltete Registrierung.';

  @override
  String get registrationSharedUnavailable =>
      'Die Verbindung mit BusyMax ist in diesem Build nicht verfügbar. Sie können unten eine andere Verbindungsmethode verwenden.';

  @override
  String get registrationWorkspaceIntroduction =>
      'Wählen Sie die von Ihrer Organisation bereitgestellte oder verwaltete Desktop-OAuth-JSON. Die Datei bestätigt weder Organisationseigentum noch Zielgruppe oder Verifizierungsstatus.';

  @override
  String get registrationWorkspaceSetupInstructions =>
      'Google Workspace-Einrichtungsanleitung';

  @override
  String get registrationBusyMaxManaged =>
      'Von BusyMax verwaltete Registrierung';

  @override
  String get registrationBranding => 'Branding und Domains konfigurieren';

  @override
  String get registrationPublishing =>
      'Für die normale Nutzung veröffentlichen';

  @override
  String get registrationOpenAudience => 'Google Auth Platform Audience öffnen';

  @override
  String get registrationGuideWorkspaceProject =>
      'Bitten Sie Ihren Administrator um die Desktop-OAuth-JSON oder öffnen Sie die Google Cloud Console und wählen Sie ein Projekt Ihrer Google Workspace-Organisation. Zum Erstellen öffnen Sie Ressourcen verwalten → Projekt erstellen, geben den Projektnamen ein, wählen unter Übergeordnete Ressource Ihre Organisation oder einen ihrer Ordner und wählen Erstellen. Wählen Sie dieses Projekt für die weiteren Schritte. Zum Erstellen benötigen Sie Project Creator, zum Konfigurieren OAuth Config Editor und zum Aktivieren der APIs Service Usage Admin oder gleichwertige Berechtigungen. Wenden Sie sich bei einer Sperre an den Administrator.';

  @override
  String get registrationGuideGoogleBranding =>
      'Tragen Sie unter Branding → App domain zuerst die autorisierten Domains Ihres Projekts und dann dessen Homepage-, Datenschutz- und Nutzungsbedingungen-URLs ein. Wählen Sie Save. Externe Produktionsanwendungen benötigen diese Links. Verwenden Sie eigene Domains und bestätigen Sie deren Inhaberschaft in Search Console, falls Google eine Markenprüfung verlangt. Der BusyMax-Datenschutzlink unten weist Ihrem Projekt keine Inhaberschaft von busystack.org nach.';

  @override
  String get registrationGuideGooglePublishing =>
      'Wählen Sie unter Audience Publish app und bestätigen Sie In production. Lassen Sie die normale Nutzung nicht in Testing: Diese Kalender-/Aufgabenautorisierungen und Aktualisierungstokens laufen nach sieben Tagen ab. Veröffentlichung und Verifizierung sind getrennt. Persönliche Nutzung mit weniger als 100 Nutzern kann von der Verifizierung befreit sein, mit Warnungen und Nutzerlimit; größere Verbreitung kann Marken- und Berechtigungsprüfungen erfordern. Produktionsautorisierungen können weiterhin ablaufen oder widerrufen werden.';

  @override
  String get registrationGuideWorkspacePermissions =>
      'Prüfen Sie diese Berechtigungen mit Ihrem Administrator. Interne Apps benötigen keine Auflistung auf dem Zustimmungsbildschirm. Falls angefordert, öffnen Sie Data Access → Add or remove scopes, fügen Sie die Werte hinzu und wählen Sie Update und Save. Administratorkontrollen können die Autorisierung weiterhin einschränken.';

  @override
  String get registrationGuideMicrosoftOptionalPermissions =>
      'Berechtigungen für freigegebene Kalender und Kategorien werden separat beim Aktivieren dieser optionalen Funktionen angefordert. Fügen Sie sie nicht zur erforderlichen Einrichtung hinzu.';

  @override
  String get registrationGuideWorkspaceAudience =>
      'Öffnen Sie Google Auth Platform → Branding. Wählen Sie bei einer neuen Einrichtung Get started. Geben Sie BusyMax als App name ein, wählen Sie Ihre eigene User support email und anschließend Next. Wählen Sie unter Audience Internal. Wählen Sie Next, geben Sie unter Contact Information Ihre E-Mail-Adresse ein und wählen Sie Next. Akzeptieren Sie die User Data Policy und wählen Sie Continue und Create. Prüfen Sie bei einer vorhandenen Einrichtung Branding und Audience.\n\nInternal erlaubt nur Konten der übergeordneten Projektorganisation und unterliegt Administratorkontrollen. Eine Testnutzerliste ist nicht nötig. BusyMax kann diese Konsoleneinstellungen nicht anhand der JSON prüfen.';

  @override
  String get contactsTitle => 'Kontakte';

  @override
  String get contactsLinkedDescription =>
      'Beim Hinzufügen von Veranstaltungsgästen zwischengespeicherte Kontakte dieses Kontos verwenden.';

  @override
  String get contactsEnableSuggestions => 'Kontaktvorschläge aktivieren';

  @override
  String get contactsReadPermissionDescription =>
      'Fordert schreibgeschützten Zugriff auf Kontakte an';

  @override
  String get contactsEnableEditing => 'Kontaktbearbeitung aktivieren';

  @override
  String get contactsWritePermissionDescription =>
      'Fordert Lese- und Schreibzugriff auf Kontakte an';

  @override
  String get contactsSuggestionsEnabled => 'Kontaktvorschläge aktiviert';

  @override
  String get contactsNeedsAttention => 'Kontakte erfordern Aufmerksamkeit';

  @override
  String get contactsReadWriteAccess => 'Lese- und Schreibzugriff';

  @override
  String get contactsDisableForAccount =>
      'Kontakte für dieses Konto deaktivieren';

  @override
  String get contactsOnlyDescription =>
      'Diese Quellen sind von Kalender- und Aufgabenkonten unabhängig.';

  @override
  String get contactsAddCardDav => 'CardDAV-Kontakte hinzufügen';

  @override
  String get contactsAddNextcloud => 'Nextcloud-Kontakte hinzufügen';

  @override
  String get contactsUseForAttendees => 'Für Teilnehmervorschläge verwenden';

  @override
  String get contactsServerUrlLabel => 'HTTPS-Server-URL';

  @override
  String get contactsUsernameLabel => 'Benutzername';

  @override
  String get contactsPasswordLabel => 'Passwort';
}

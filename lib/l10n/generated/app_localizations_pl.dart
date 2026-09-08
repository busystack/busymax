// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get nextcloudExportCollection => 'Eksportuj zasoby kolekcji';

  @override
  String nextcloudImportItems(int count) {
    return 'Liczba znalezionych zasobów wydarzeń i zadań: $count';
  }

  @override
  String get nextcloudSchedulingInbox =>
      'Skrzynka wiadomości dotyczących spotkań';

  @override
  String get nextcloudInboxExplanation =>
      'Nextcloud uwzględnia te wiadomości w Twoich kalendarzach. Potwierdzenie wiadomości usuwa tylko wiadomość ze skrzynki, a nie wydarzenie.';

  @override
  String get nextcloudInboxEmpty => 'Brak wiadomości dotyczących spotkań.';

  @override
  String get nextcloudAcknowledge => 'Potwierdź wiadomość';

  @override
  String get nextcloudAcknowledgeConfirm =>
      'Usunąć tę wiadomość dotyczącą spotkania ze skrzynki? Wydarzenie w kalendarzu zostanie zachowane.';

  @override
  String get nextcloudGuestAvailability => 'Sprawdź dostępność uczestników';

  @override
  String nextcloudTrashRetention(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dnia',
      many: '$days dni',
      few: '$days dni',
      one: '$days dzień',
    );
    return 'Okres przechowywania w koszu serwera: $_temp0';
  }

  @override
  String get nextcloudCancelMeeting => 'Odwołaj spotkanie';

  @override
  String get nextcloudDeclineAndRemove => 'Odrzuć i usuń zaproszenie';

  @override
  String get nextcloudDeclineRemovalWarning =>
      'Usunięcie tego zaproszenia spowoduje wysłanie odmowy podczas synchronizacji. Nie odwoła spotkania organizatora.';

  @override
  String get nextcloudAvailabilityUnknown => 'Dostępność nieznana';

  @override
  String get nextcloudAvailabilityFree =>
      'Nie zgłoszono zajętych terminów w tym przedziale';

  @override
  String get nextcloudAvailabilityBusy => 'Zajęte terminy';

  @override
  String get nextcloudSchedulingPending =>
      'Nextcloud wyśle aktualizacje spotkania po zsynchronizowaniu tej zmiany. Zapis lokalny nie potwierdza dostarczenia.';

  @override
  String get nextcloudAttendeeRestrictions =>
      'Tylko organizator lub upoważniony pełnomocnik może zmieniać szczegóły spotkania. Możesz odpowiedzieć na zaproszenie w jego szczegółach.';

  @override
  String get nextcloudMeetingMoveUnsupported =>
      'Tego spotkania nie można przenieść przez skopiowanie i usunięcie. Użyj kalendarza powiązanego z tą samą tożsamością używaną do planowania spotkań.';

  @override
  String get nextcloudSchedulingStatus => 'Stan obsługi spotkania na serwerze';

  @override
  String get nextcloudImportFollowUp =>
      'Zaimportowane zasoby zapisano lokalnie. Odświeżenie przypomnień oczekuje na wykonanie; nie importuj zasobów ponownie.';

  @override
  String get nextcloudNativeImport =>
      'Importuj kompletne zasoby wydarzeń i zadań bez wysyłania zaproszeń. Istniejące identyfikatory UID są pomijane, chyba że wybierzesz nowe kopie. Nieobsługiwane zasoby są zgłaszane osobno.';

  @override
  String get nextcloudImportMethod =>
      'Ten plik zawiera wiadomości dotyczące spotkań. Import zapisuje ich treść i usuwa METHOD; nie przetwarza zaproszenia ani odpowiedzi.';

  @override
  String get nextcloudImportCopies =>
      'Importuj jako nowe kopie z nowymi identyfikatorami';

  @override
  String get nextcloudCollectionSettings => 'Ustawienia kolekcji';

  @override
  String get nextcloudSharing => 'Udostępnianie';

  @override
  String get nextcloudOwned => 'Własna';

  @override
  String get nextcloudShared => 'Udostępniona';

  @override
  String get nextcloudDelegated => 'Delegowana';

  @override
  String get nextcloudSubscription => 'Subskrypcja';

  @override
  String get nextcloudDeleted => 'Usunięta';

  @override
  String get nextcloudMetadataEditable =>
      'Zawartość kalendarza jest tylko do odczytu; można zmieniać właściwości kolekcji.';

  @override
  String get nextcloudServerOrder =>
      'Kolejność na serwerze (niezależna od kolejności w panelu bocznym)';

  @override
  String get nextcloudCalendarEnabled => 'Włączona na serwerze';

  @override
  String get nextcloudAvailability =>
      'Uwzględniaj tę kolekcję przy określaniu dostępności';

  @override
  String get nextcloudCalendarTimezone =>
      'Strefa czasowa kalendarza (dokument VTIMEZONE)';

  @override
  String get nextcloudRefreshPending =>
      'Zmianę zapisano w Nextcloud. Odświeżenie oczekuje na wykonanie; nie powtarzaj zmiany.';

  @override
  String get nextcloudOutcomeUnknown =>
      'Nie udało się potwierdzić wyniku operacji na serwerze. Odśwież przed ponowną próbą.';

  @override
  String get nextcloudRemoveShared => 'Usuń udostępniony kalendarz lub listę';

  @override
  String get nextcloudRemoveMixed =>
      'Ta kolekcja zawiera wydarzenia i zadania. Jej usunięcie spowoduje usunięcie zarówno wydarzeń, jak i zadań.';

  @override
  String get nextcloudReadAccess => 'Tylko do odczytu';

  @override
  String get nextcloudWriteAccess => 'Odczyt i zapis';

  @override
  String get nextcloudRecipientSearch => 'Znajdź osoby lub grupy';

  @override
  String get nextcloudNoRecipients => 'Brak pasujących osób lub grup.';

  @override
  String get nextcloudRevokeShare => 'Odbierz dostęp';

  @override
  String get nextcloudPublish => 'Opublikuj link';

  @override
  String get nextcloudUnpublish => 'Zakończ publikowanie';

  @override
  String get nextcloudPublishWarning =>
      'Każda osoba mająca opublikowany link może mieć możliwość odczytania tego kalendarza. Opublikować go?';

  @override
  String get nextcloudTrash => 'Usunięte kalendarze i zadania';

  @override
  String get nextcloudTrashEmpty => 'Brak usuniętych elementów kalendarza.';

  @override
  String get nextcloudRestore => 'Przywróć';

  @override
  String get nextcloudPermanentDelete => 'Usuń trwale';

  @override
  String get nextcloudPermanentDeleteWarning =>
      'Trwale usunąć ten element? Nie będzie można go przywrócić z kosza kalendarza Nextcloud.';

  @override
  String get nextcloudOperationDenied =>
      'Nextcloud nie zezwolił na tę operację.';

  @override
  String get nextcloudUnsupported => 'Serwer nie obsługuje tej operacji.';

  @override
  String get nextcloudPendingChanges =>
      'Przed zamknięciem zapisz lub odrzuć zmiany w kolekcji.';

  @override
  String get nextcloudServerUnavailable =>
      'Nie udało się połączyć z Nextcloud. Dane w pamięci podręcznej i oczekujące operacje pozostają bez zmian.';

  @override
  String get mapsShow => 'Pokaż na mapie';

  @override
  String get openLink => 'Otwórz link';

  @override
  String get externalLocationOpenFailed =>
      'Nie udało się otworzyć lokalizacji w aplikacji zewnętrznej.';

  @override
  String scheduleProposedRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get scheduleRescheduleFailed =>
      'Nie udało się zmienić terminu wydarzenia. Zapisany termin nie został zmieniony.';

  @override
  String get scheduleRescheduleStale =>
      'To wydarzenie zmieniło się podczas przeciągania. Spróbuj ponownie.';

  @override
  String get scheduleRescheduleNotificationsFailed =>
      'Nowy termin zapisano, ale nie udało się odświeżyć przypomnień.';

  @override
  String get moveUp => 'Przenieś w górę';

  @override
  String get moveDown => 'Przenieś w dół';

  @override
  String get windowsSupport => 'Pomoc techniczna';

  @override
  String get windowsThirdPartyLicenses => 'Licencje innych firm';

  @override
  String get windowsSearch => 'Szukaj';

  @override
  String get windowsStartupDisabledByUser =>
      'Wyłączone przez użytkownika w ustawieniach systemu Windows.';

  @override
  String get windowsStartupDisabledByPolicy =>
      'Wyłączone przez zasady systemu Windows.';

  @override
  String get windowsStartupUnavailable =>
      'Dostępne po zainstalowaniu BusyMax z pakietu MSIX.';

  @override
  String get windowsReminderExitNotice =>
      'Przypomnienia przestają działać po całkowitym zamknięciu BusyMax. Aby je otrzymywać, pozostaw aplikację uruchomioną w tle.';

  @override
  String get windowsProductVersionLabel => 'Wersja produktu';

  @override
  String get windowsPackageVersionLabel => 'Wersja pakietu Windows';

  @override
  String get windowsUnpackaged => 'Bez pakietu instalacyjnego';

  @override
  String get windowsAgendaLoadMore => 'Wczytaj więcej elementów planu dnia';

  @override
  String repeatWeeklyDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'MO': 'w poniedziałek',
      'TU': 'we wtorek',
      'WE': 'w środę',
      'TH': 'w czwartek',
      'FR': 'w piątek',
      'SA': 'w sobotę',
      'SU': 'w niedzielę',
      'other': '$day',
    });
    return '$_temp0';
  }

  @override
  String repeatOnTwoMonthDaysSummary(String first, String second) {
    return 'w dniach $first i $second miesiąca';
  }

  @override
  String repeatYearlyOnTwoMonthDaysSummary(
    String frequency,
    String month,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency, $firstDay i $secondDay $month';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaySummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String day,
  ) {
    return '$frequency, $day $firstMonth i $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnTwoMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String firstDay,
    String secondDay,
  ) {
    return '$frequency, $firstDay i $secondDay $firstMonth i $secondMonth';
  }

  @override
  String repeatYearlyInTwoMonthsOnMonthDaysSummary(
    String frequency,
    String firstMonth,
    String secondMonth,
    String days,
  ) {
    return '$frequency, $days $firstMonth i $secondMonth';
  }

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Połącz konta Google, Microsoft, Kalendarza Apple iCloud lub Nextcloud.';

  @override
  String get googlePermissionsConsentNotice =>
      'Na ekranie uprawnień Google zaznacz uprawnienia do Kalendarza i Zadań.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Wymagane są uprawnienia do Kalendarza Google i Zadań Google. Spróbuj ponownie i zaznacz oba pola wyboru.';

  @override
  String get finishSetup => 'Zakończ konfigurację';

  @override
  String get continueSetup => 'Kontynuuj';

  @override
  String get onboardingSetupTitle => 'Skonfiguruj BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Połącz konta';

  @override
  String get onboardingAccountsStepDescription =>
      'Dodaj wszystkie konta, których chcesz używać. BusyMax synchronizuje obsługiwane kalendarze, wydarzenia, listy zadań i zadania z każdego konta.';

  @override
  String get onboardingPreferencesStepTitle => 'Wybierz ustawienia systemowe';

  @override
  String get onboardingPreferencesStepDescription =>
      'Przed otwarciem harmonogramu skonfiguruj działanie aplikacji na pulpicie, przypomnienia, szczegółowość powiadomień i wygląd.';

  @override
  String get signInWithGoogle => 'Zaloguj się przez Google';

  @override
  String get signInWithMicrosoft => 'Zaloguj się przez Microsoft';

  @override
  String get googleTasksProvider => 'Zadania Google';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Ten dostawca nie jest skonfigurowany.';

  @override
  String get waitingForGoogleSignIn => 'Oczekiwanie na logowanie przez Google…';

  @override
  String get waitingForMicrosoftSignIn =>
      'Oczekiwanie na logowanie przez Microsoft…';

  @override
  String get microsoftSignInNotConfigured =>
      'Logowanie przez Microsoft nie jest skonfigurowane. Ustaw MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Anuluj';

  @override
  String get close => 'Zamknij';

  @override
  String get exit => 'Zakończ';

  @override
  String get options => 'Opcje';

  @override
  String get hide => 'Ukryj';

  @override
  String get show => 'Pokaż';

  @override
  String get export => 'Eksportuj';

  @override
  String get save => 'Zapisz';

  @override
  String get settings => 'Ustawienia';

  @override
  String get all => 'Wszystkie';

  @override
  String get calendarEvents => 'Wydarzenia';

  @override
  String get calendarTasks => 'Zadania';

  @override
  String get calendar => 'Kalendarz';

  @override
  String get calendars => 'Kalendarze';

  @override
  String get newCalendar => 'Nowy kalendarz';

  @override
  String get calendarColor => 'Kolor kalendarza';

  @override
  String calendarColorOption(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Kolor $numberString';
  }

  @override
  String get calendarManagementUnsupported =>
      'Ten dostawca nie obsługuje zarządzania kalendarzami w BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'Nie można usunąć kalendarza głównego.';

  @override
  String calendarCreateFailed(String error) {
    return 'Nie udało się utworzyć kalendarza: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'Kalendarz został utworzony, ale BusyMax nie mógł odświeżyć konta. Pojawi się po następnej synchronizacji.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Nie udało się zaktualizować kalendarza: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Nie udało się usunąć kalendarza: $error';
  }

  @override
  String get newEvent => 'Nowe wydarzenie';

  @override
  String get refreshCalendar => 'Odśwież kalendarz';

  @override
  String get openInProvider => 'Otwórz u dostawcy';

  @override
  String get hideFromSchedule => 'Ukryj w harmonogramie';

  @override
  String get showInSchedule => 'Pokaż w harmonogramie';

  @override
  String get noCalendarsSynced =>
      'Nie zsynchronizowano jeszcze żadnych kalendarzy.';

  @override
  String get allDay => 'Cały dzień';

  @override
  String moreItems(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString więcej';
  }

  @override
  String get noEventsOrTasks => 'Brak wydarzeń i zadań';

  @override
  String get scheduleLoading => 'Wczytywanie harmonogramu…';

  @override
  String get scheduleUnavailable => 'Harmonogram niedostępny';

  @override
  String get scheduleNoSources => 'Brak widocznych kalendarzy i list zadań';

  @override
  String get scheduleNoSourcesDescription =>
      'Wybierz w ustawieniach, co ma być widoczne, a następnie odśwież.';

  @override
  String get scheduleSignInRequired => 'Połącz konto';

  @override
  String get scheduleSignInDescription =>
      'Zaloguj się, aby synchronizować kalendarze i zadania.';

  @override
  String get scheduleNoSearchResults => 'Brak pasujących wydarzeń i zadań';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Zmień wyszukiwane hasło lub wyczyść bieżące filtry.';

  @override
  String get refresh => 'Odśwież';

  @override
  String get trayOpenBusyMax => 'Otwórz BusyMax';

  @override
  String get trayShowBusyMax => 'Pokaż BusyMax';

  @override
  String get trayNewEvent => 'Nowe wydarzenie…';

  @override
  String get trayNewTask => 'Nowe zadanie…';

  @override
  String get trayToday => 'Dzisiaj';

  @override
  String get trayAllDay => 'Cały dzień';

  @override
  String get trayNow => 'Teraz';

  @override
  String get trayCalendarEvent => 'Wydarzenie w kalendarzu';

  @override
  String get trayUntitledEvent => 'Wydarzenie bez tytułu';

  @override
  String get trayNothingElseToday => 'Na dzisiaj to wszystko';

  @override
  String trayTasksDueToday(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString zadania na dzisiaj',
      many: '$countString zadań na dzisiaj',
      few: '$countString zadania na dzisiaj',
      one: '$countString zadanie na dzisiaj',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Otwórz dzisiejszy plan dnia';

  @override
  String get traySyncNow => 'Synchronizuj teraz';

  @override
  String get traySyncing => 'Synchronizowanie…';

  @override
  String get trayNotConnected => 'Brak połączenia';

  @override
  String get trayNotYetSynced => 'Jeszcze nie zsynchronizowano';

  @override
  String get trayLastSyncedJustNow => 'Ostatnia synchronizacja: przed chwilą';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ostatnia synchronizacja: $countString minuty temu',
      many: 'Ostatnia synchronizacja: $countString minut temu',
      few: 'Ostatnia synchronizacja: $countString minuty temu',
      one: 'Ostatnia synchronizacja: $countString minutę temu',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ostatnia synchronizacja: $countString godziny temu',
      many: 'Ostatnia synchronizacja: $countString godzin temu',
      few: 'Ostatnia synchronizacja: $countString godziny temu',
      one: 'Ostatnia synchronizacja: $countString godzinę temu',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ostatnia synchronizacja: $countString dnia temu',
      many: 'Ostatnia synchronizacja: $countString dni temu',
      few: 'Ostatnia synchronizacja: $countString dni temu',
      one: 'Ostatnia synchronizacja: $countString dzień temu',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Ustawienia';

  @override
  String get trayQuitBusyMax => 'Zakończ BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Wczytaj więcej zaległych zadań';

  @override
  String get agendaLoadMoreNoDate => 'Wczytaj więcej zadań bez daty';

  @override
  String get viewDay => 'Dzień';

  @override
  String get viewWeek => 'Tydzień';

  @override
  String get viewMonth => 'Miesiąc';

  @override
  String get viewYear => 'Rok';

  @override
  String get viewAgenda => 'Plan dnia';

  @override
  String get scheduleSettings => 'Harmonogram';

  @override
  String get scheduleDisplaySettings => 'Wyświetlanie harmonogramu';

  @override
  String get scheduleDisplayHoursDescription =>
      'Widoki dnia i tygodnia otwierają się w tym zakresie godzin. Wcześniejsze i późniejsze elementy rozszerzają zakres w razie potrzeby.';

  @override
  String get scheduleDayStartsAt => 'Początek dnia';

  @override
  String get scheduleDayEndsAt => 'Koniec dnia';

  @override
  String get sourceCalendar => 'Kalendarz';

  @override
  String get sourceTaskList => 'Lista zadań';

  @override
  String get createChoiceTitle => 'Utwórz';

  @override
  String get createEventAtTime => 'Wydarzenie';

  @override
  String get createTaskAtDate => 'Zadanie';

  @override
  String get editEvent => 'Edytuj wydarzenie';

  @override
  String get eventTitle => 'Tytuł wydarzenia';

  @override
  String get location => 'Lokalizacja';

  @override
  String get timeSlot => 'Przedział czasowy';

  @override
  String get startDateTime => 'Data i godzina rozpoczęcia';

  @override
  String get endDateTime => 'Data i godzina zakończenia';

  @override
  String get doesNotRepeat => 'Nie powtarza się';

  @override
  String get defaultReminder => 'Domyślne przypomnienie';

  @override
  String get guests => 'Uczestnicy';

  @override
  String get noGuests => 'Brak uczestników';

  @override
  String get attendeeRequired => 'Wymagany';

  @override
  String get attendeeOptional => 'Opcjonalny';

  @override
  String get meetingSection => 'Spotkanie';

  @override
  String get addGoogleMeet => 'Dodaj Google Meet';

  @override
  String get addTeamsMeeting => 'Dodaj spotkanie Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Dodano spotkanie online';

  @override
  String get requestResponses => 'Poproś o odpowiedź';

  @override
  String get requestResponsesDescription =>
      'Poproś uczestników o odpowiedź na zaproszenie.';

  @override
  String get hideGuestList => 'Ukryj listę uczestników';

  @override
  String get hideGuestListDescription =>
      'Uczestnicy nie widzą, kto jeszcze został zaproszony.';

  @override
  String get allowNewTimeProposals => 'Zezwalaj na proponowanie innego terminu';

  @override
  String get allowNewTimeProposalsDescription =>
      'Uczestnicy mogą zaproponować inny termin spotkania.';

  @override
  String get notifyGuestsTitle => 'Powiadomić uczestników?';

  @override
  String get notifyGuestsSaveMessage =>
      'To spotkanie ma uczestników. Wysłać zaproszenia lub aktualizacje wydarzenia po zapisaniu?';

  @override
  String get notifyGuestsDeleteMessage =>
      'To spotkanie ma uczestników. Wysłać powiadomienie o odwołaniu po usunięciu?';

  @override
  String get sendUpdates => 'Wyślij aktualizacje';

  @override
  String get sendCancellation => 'Wyślij powiadomienie o odwołaniu';

  @override
  String get doNotSend => 'Nie wysyłaj';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Zapisać spotkanie?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft wyśle uczestnikom zaproszenia lub aktualizacje wydarzenia.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Usunąć spotkanie?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft wyśle uczestnikom powiadomienie o odwołaniu.';

  @override
  String get organizer => 'Organizator';

  @override
  String get yourResponse => 'Twoja odpowiedź';

  @override
  String get guestResponses => 'Odpowiedzi uczestników';

  @override
  String get respond => 'Odpowiedz';

  @override
  String get acceptInvitation => 'Zaakceptuj';

  @override
  String get tentativeInvitation => 'Zaakceptuj wstępnie';

  @override
  String get declineInvitation => 'Odrzuć';

  @override
  String get joinMeeting => 'Dołącz do spotkania';

  @override
  String get responseAccepted => 'Zaakceptowano';

  @override
  String get responseTentative => 'Wstępnie zaakceptowano';

  @override
  String get responseDeclined => 'Odrzucono';

  @override
  String get responseNeedsAction => 'Oczekiwanie na odpowiedź';

  @override
  String get responseNotResponded => 'Brak odpowiedzi';

  @override
  String get responseOrganizer => 'Organizator';

  @override
  String invitationResponseFailed(String error) {
    return 'Nie udało się wysłać odpowiedzi: $error';
  }

  @override
  String get joinMeetingFailed => 'Nie udało się otworzyć linku do spotkania.';

  @override
  String get description => 'Opis';

  @override
  String get availabilityShowAs => 'Dostępność / Pokaż jako';

  @override
  String get busy => 'Zajęty';

  @override
  String get visibility => 'Widoczność';

  @override
  String get defaultVisibility => 'Domyślna widoczność';

  @override
  String get conference => 'Konferencja';

  @override
  String get noConference => 'Brak konferencji';

  @override
  String get providerCalendar => 'Kalendarz u dostawcy';

  @override
  String get formatBoldShortLabel => 'B';

  @override
  String get formatBoldTooltip => 'Pogrubienie';

  @override
  String get formatItalicShortLabel => 'I';

  @override
  String get formatItalicTooltip => 'Kursywa';

  @override
  String get formatUnderlineShortLabel => 'U';

  @override
  String get formatUnderlineTooltip => 'Podkreślenie';

  @override
  String reminderMinutesBefore(int minutes) {
    final intl.NumberFormat minutesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutesString minuty wcześniej',
      many: '$minutesString minut wcześniej',
      few: '$minutesString minuty wcześniej',
      one: '$minutesString minutę wcześniej',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'W momencie rozpoczęcia';

  @override
  String reminderHoursBefore(int hours) {
    final intl.NumberFormat hoursNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString godziny wcześniej',
      many: '$hoursString godzin wcześniej',
      few: '$hoursString godziny wcześniej',
      one: '$hoursString godzinę wcześniej',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysString dnia wcześniej',
      many: '$daysString dni wcześniej',
      few: '$daysString dni wcześniej',
      one: '$daysString dzień wcześniej',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Wolny';

  @override
  String get availabilityTentative => 'Wstępnie zajęty';

  @override
  String get availabilityOutOfOffice => 'Poza biurem';

  @override
  String get availabilityWorkingElsewhere => 'Praca w innym miejscu';

  @override
  String get visibilityDefault => 'Domyślna';

  @override
  String get visibilityPublic => 'Publiczna';

  @override
  String get visibilityPrivate => 'Prywatna';

  @override
  String get visibilityConfidential => 'Poufna';

  @override
  String get sensitivityNormal => 'Zwykła';

  @override
  String get sensitivityPersonal => 'Osobista';

  @override
  String get tasks => 'Zadania';

  @override
  String get allTasks => 'Wszystkie zadania';

  @override
  String tasksInList(String title) {
    return 'Zadania na liście $title';
  }

  @override
  String get taskLists => 'Listy zadań';

  @override
  String get navigation => 'Nawigacja';

  @override
  String get mainMenu => 'Menu główne';

  @override
  String get keyboardShortcuts => 'Skróty klawiszowe';

  @override
  String get shortcutGroupGeneral => 'Ogólne';

  @override
  String get shortcutKeyboardShortcutsDescription => 'Pokaż tę listę skrótów';

  @override
  String get shortcutGroupNavigation => 'Nawigacja';

  @override
  String get shortcutNextPeriod => 'Następny okres';

  @override
  String get shortcutNextPeriodDescription =>
      'Następny tydzień w widoku tygodnia, następny miesiąc w widoku miesiąca itd.';

  @override
  String get shortcutPreviousPeriod => 'Poprzedni okres';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Poprzedni tydzień w widoku tygodnia, poprzedni miesiąc w widoku miesiąca itd.';

  @override
  String get shortcutJumpToToday => 'Przejdź do dzisiaj';

  @override
  String get shortcutGroupView => 'Widok';

  @override
  String get shortcutDayView => 'Widok dnia';

  @override
  String get shortcutWeekView => 'Widok tygodnia';

  @override
  String get shortcutMonthView => 'Widok miesiąca';

  @override
  String get shortcutYearView => 'Widok roku';

  @override
  String get shortcutAgendaView => 'Widok planu dnia';

  @override
  String get shortcutGroupCreateAndEdit => 'Tworzenie i edycja';

  @override
  String get shortcutSaveItem => 'Zapisz wydarzenie lub zadanie';

  @override
  String get shortcutDeleteItem => 'Usuń wydarzenie lub zadanie';

  @override
  String get shortcutGroupTaskEditing => 'Edycja zadań';

  @override
  String get shortcutCancelEditing => 'Anuluj edycję';

  @override
  String get shortcutCancelEditingDescription =>
      'Zamknij edycję lub szczegóły zadania';

  @override
  String get aboutBusyMax => 'O BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Kalendarz i zadania';

  @override
  String get license => 'Licencja';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Strona internetowa';

  @override
  String get sourceCode => 'Kod źródłowy';

  @override
  String get reportAnIssue => 'Zgłoś problem';

  @override
  String get sendFeedback => 'Wyślij opinię';

  @override
  String get feedbackSubmit => 'Wyślij';

  @override
  String get feedbackCategory => 'Kategoria';

  @override
  String get feedbackSelectCategory => 'Wybierz kategorię';

  @override
  String get feedbackCategoryProblem => 'Problem lub błąd';

  @override
  String get feedbackCategoryFeature => 'Propozycja funkcji';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Kwestia prywatności lub bezpieczeństwa';

  @override
  String get feedbackCategoryUsability => 'Problem z obsługą';

  @override
  String get feedbackCategoryOther => 'Inne';

  @override
  String get feedbackSubject => 'Temat';

  @override
  String get feedbackDetailedMessage => 'Szczegółowy opis';

  @override
  String get feedbackReplyEmail => 'Adres e-mail do odpowiedzi (opcjonalnie)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Dołącz informacje techniczne';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Dodaje tylko nazwę i wersję systemu operacyjnego oraz język aplikacji. Nie dołącza dzienników, danych kont, nazw plików ani innych danych diagnostycznych.';

  @override
  String get feedbackCategoryRequired => 'Wybierz kategorię.';

  @override
  String get feedbackSubjectLengthError =>
      'Temat musi mieć od 3 do 120 znaków.';

  @override
  String get feedbackMessageLengthError =>
      'Wiadomość musi mieć od 10 do 5000 znaków.';

  @override
  String get feedbackInvalidEmail => 'Wpisz prawidłowy adres e-mail.';

  @override
  String get feedbackConnectionError =>
      'Nie udało się połączyć z BusyStack. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get feedbackTimeoutError =>
      'Upłynął limit czasu żądania. Twoja opinia nie została usunięta; spróbuj ponownie.';

  @override
  String get feedbackRateLimitedError =>
      'Z tej sieci wysłano zbyt wiele opinii. Poczekaj i spróbuj ponownie.';

  @override
  String get feedbackRejectedError =>
      'Serwer odrzucił zgłoszenie. Sprawdź pola i spróbuj ponownie.';

  @override
  String get feedbackServerError =>
      'BusyStack nie może teraz przyjąć Twojej opinii. Jej treść nie została usunięta; spróbuj ponownie.';

  @override
  String feedbackSuccess(String id) {
    return 'Wysłano opinię. Numer zgłoszenia: $id';
  }

  @override
  String get toggleSidebar => 'Pokaż lub ukryj panel boczny';

  @override
  String get showSidebar => 'Pokaż panel boczny';

  @override
  String get hideSidebar => 'Ukryj panel boczny';

  @override
  String get accounts => 'Konta';

  @override
  String get currentAccount => 'Bieżące konto';

  @override
  String get switchAccount => 'Przełącz konto';

  @override
  String get addGoogleAccount => 'Dodaj konto Google';

  @override
  String get addMicrosoftAccount => 'Dodaj konto Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Zalogowano';

  @override
  String get removeAccount => 'Usuń konto…';

  @override
  String get removingAccount => 'Usuwanie konta…';

  @override
  String get removeAccountDescription =>
      'Zatrzymaj synchronizację i usuń dane tego konta z urządzenia.';

  @override
  String removeAccountTitle(String account) {
    return 'Usunąć konto $account z BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'Spowoduje to usunięcie z tego urządzenia zapisanych w pamięci podręcznej zadań, kalendarzy, wydarzeń, przypomnień i oczekujących zmian offline. Niezsynchronizowane zmiany zostaną utracone. Kopie kalendarzy, wydarzeń, list zadań i zadań u dostawcy nie zostaną usunięte.';

  @override
  String get revokeGoogleAccess =>
      'Odbierz również BusyMax dostęp do tego konta Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Przed ponownym połączeniem trzeba będzie jeszcze raz przyznać dostęp.';

  @override
  String get removeAccountAction => 'Usuń konto';

  @override
  String get removeAccountFailed =>
      'Nie udało się zakończyć usuwania konta. Spróbuj ponownie.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Konto usunięto z tego urządzenia, ale BusyMax nie mógł odebrać dostępu do Google. Możesz go odebrać w ustawieniach konta Google.';

  @override
  String get newTaskList => 'Nowa lista zadań';

  @override
  String taskListCreateFailed(String error) {
    return 'Nie udało się utworzyć listy zadań: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Nie udało się zmienić nazwy listy zadań: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Nie udało się usunąć listy zadań: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Zaloguj się, aby wyświetlić listy zadań.';

  @override
  String get noTaskListsSynced =>
      'Nie zsynchronizowano jeszcze żadnych list zadań.';

  @override
  String get listActions => 'Działania na liście';

  @override
  String get rename => 'Zmień nazwę';

  @override
  String get delete => 'Usuń';

  @override
  String get renameList => 'Zmień nazwę listy';

  @override
  String get deleteList => 'Usuń listę';

  @override
  String get unshare => 'Cofnij udostępnienie';

  @override
  String get readOnlyTaskListCannotRename =>
      'Ta lista zadań jest tylko do odczytu i nie można zmienić jej nazwy.';

  @override
  String get taskListCannotDelete =>
      'Nie masz uprawnień do usunięcia tej listy zadań.';

  @override
  String get builtInMicrosoftList => 'Wbudowana';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Nie można zmieniać nazw ani usuwać wbudowanych list Microsoft To Do.';

  @override
  String deleteListConfirmation(String title) {
    return 'Usunąć „$title” z Zadań Google?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Usunąć „$title” wraz ze wszystkimi zadaniami?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Cofnąć udostępnienie „$title” temu kontu?';
  }

  @override
  String get deleteEvent => 'Usuń wydarzenie';

  @override
  String get title => 'Tytuł';

  @override
  String get create => 'Utwórz';

  @override
  String get newTask => 'Nowe zadanie';

  @override
  String get clearCompleted => 'Wyczyść ukończone';

  @override
  String get refreshList => 'Odśwież listę';

  @override
  String get refreshAll => 'Odśwież wszystko';

  @override
  String get listRefreshed => 'Odświeżono listę.';

  @override
  String get allTasksRefreshed => 'Odświeżono wszystkie konta.';

  @override
  String exportedFile(String path) {
    return 'Wyeksportowano do $path';
  }

  @override
  String exportFailed(String error) {
    return 'Eksport nie powiódł się: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Odświeżanie nie powiodło się: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Wybierz lub utwórz listę zadań, aby rozpocząć.';

  @override
  String get signInToViewTasks => 'Zaloguj się, aby wyświetlić zadania.';

  @override
  String get noTasks => 'Brak zadań.';

  @override
  String get noTasksYet => 'Nie ma jeszcze zadań';

  @override
  String get noTasksYetMessage =>
      'Utwórz zadanie lub odśwież konta, aby rozpocząć.';

  @override
  String get noTasksInList => 'Brak zadań na tej liście.';

  @override
  String get overdue => 'Zaległe';

  @override
  String get today => 'Dzisiaj';

  @override
  String get tomorrow => 'Jutro';

  @override
  String get upcoming => 'Nadchodzące';

  @override
  String get noDate => 'Bez daty';

  @override
  String get completed => 'Ukończone';

  @override
  String duePrefix(String date) {
    return 'Termin: $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => 'Szczegóły zadania';

  @override
  String get editTask => 'Edytuj zadanie';

  @override
  String get noTaskSelected => 'Nie wybrano zadania.';

  @override
  String get noTaskSelectedHelper =>
      'Wybierz zadanie, aby wyświetlić i edytować szczegóły.';

  @override
  String get taskUnavailable => 'Zadanie niedostępne.';

  @override
  String get signInToEditTasks => 'Zaloguj się, aby edytować zadania.';

  @override
  String get refreshTask => 'Odśwież zadanie';

  @override
  String get primarySection => 'Podstawowe';

  @override
  String get statusSection => 'Stan';

  @override
  String get openStatus => 'Otwarte';

  @override
  String get doneStatus => 'Wykonane';

  @override
  String get taskStatus => 'Stan';

  @override
  String get taskStatusNone => 'Brak stanu';

  @override
  String get taskStatusNeedsAction => 'Wymaga działania';

  @override
  String get taskStatusInProcess => 'W toku';

  @override
  String get taskStatusCompleted => 'Ukończone';

  @override
  String get taskStatusCancelled => 'Anulowane';

  @override
  String completionPercent(int percent) {
    final intl.NumberFormat percentNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Ukończono $percentString%';
  }

  @override
  String get completionDate => 'Data ukończenia';

  @override
  String get priority => 'Priorytet';

  @override
  String get priorityNone => 'Brak priorytetu';

  @override
  String priorityHighValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priorytet $priorityString · Wysoki';
  }

  @override
  String priorityMediumValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priorytet $priorityString · Średni';
  }

  @override
  String priorityLowValue(int priority) {
    final intl.NumberFormat priorityNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String priorityString = priorityNumberFormat.format(priority);

    return 'Priorytet $priorityString · Niski';
  }

  @override
  String get taskUrl => 'URL';

  @override
  String get invalidTaskUrl =>
      'Wpisz bezwzględny adres URL, łącznie ze schematem.';

  @override
  String get classification => 'Klasyfikacja';

  @override
  String get classificationPublic => 'Po udostępnieniu pokazuj całe zadanie';

  @override
  String get classificationConfidential =>
      'Po udostępnieniu pokazuj tylko zajęty termin';

  @override
  String get classificationPrivate => 'Po udostępnieniu ukrywaj to zadanie';

  @override
  String get pinTask => 'Przypnij zadanie';

  @override
  String get notes => 'Notatki';

  @override
  String get dueDate => 'Termin wykonania';

  @override
  String get clearDueDate => 'Wyczyść termin wykonania';

  @override
  String get dueTime => 'Godzina wykonania';

  @override
  String get startDate => 'Data rozpoczęcia';

  @override
  String get startTime => 'Godzina rozpoczęcia';

  @override
  String get endDate => 'Data zakończenia';

  @override
  String get endTime => 'Godzina zakończenia';

  @override
  String get reminderDate => 'Data przypomnienia';

  @override
  String get reminderTime => 'Godzina przypomnienia';

  @override
  String get reminder => 'Przypomnienie';

  @override
  String get addReminder => 'Dodaj przypomnienie';

  @override
  String get reminders => 'Przypomnienia';

  @override
  String get noReminders => 'Brak przypomnień';

  @override
  String get editReminder => 'Edytuj przypomnienie';

  @override
  String get beforeTaskStarts => 'Przed rozpoczęciem zadania';

  @override
  String get beforeTaskDue => 'Przed terminem wykonania zadania';

  @override
  String get afterTaskStarts => 'Po rozpoczęciu zadania';

  @override
  String get afterTaskDue => 'Po terminie wykonania zadania';

  @override
  String get relativeToTaskStart => 'Względem daty rozpoczęcia zadania';

  @override
  String get relativeToTaskDue => 'Względem terminu wykonania zadania';

  @override
  String get reminderTimeOfDay => 'Pora dnia';

  @override
  String get absoluteReminder => 'W określonym dniu i o określonej godzinie';

  @override
  String get reminderAmount => 'Liczba jednostek';

  @override
  String get reminderUnit => 'Jednostka';

  @override
  String get reminderUnitSeconds => 'Sekundy';

  @override
  String get reminderUnitMinutes => 'Minuty';

  @override
  String get reminderUnitHours => 'Godziny';

  @override
  String get reminderUnitDays => 'Dni';

  @override
  String get reminderUnitWeeks => 'Tygodnie';

  @override
  String get reminderAtTaskStart => 'W momencie rozpoczęcia zadania';

  @override
  String get reminderAtTaskDue => 'W terminie wykonania zadania';

  @override
  String get unsupportedReminder =>
      'Ten typ przypomnienia jest zachowywany, ale nie można edytować jego terminu.';

  @override
  String get relatedRemindersTitle => 'Zachować powiązane przypomnienia?';

  @override
  String relatedRemindersDescription(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Liczba przypomnień powiązanych z tą datą: $countString. Zachować je z obecną datą i godziną?';
  }

  @override
  String get discardRelatedReminders => 'Usuń przypomnienia';

  @override
  String get keepRelatedReminders => 'Zachowaj przypomnienia';

  @override
  String get addGuest => 'Dodaj uczestnika';

  @override
  String get addGuestEmail => 'Dodaj adres e-mail uczestnika';

  @override
  String get removeReminder => 'Usuń przypomnienie';

  @override
  String get off => 'Wyłączone';

  @override
  String get repeat => 'Powtarzanie';

  @override
  String get repeatNone => 'Bez powtarzania';

  @override
  String get noneValue => 'Brak';

  @override
  String get repeatDaily => 'Codziennie';

  @override
  String get repeatWeekly => 'Co tydzień';

  @override
  String get repeatMonthly => 'Co miesiąc';

  @override
  String get repeatYearly => 'Co rok';

  @override
  String get repeatEvery => 'Odstęp';

  @override
  String get repeatOn => 'Powtarzaj w dniach';

  @override
  String get repeatEnd => 'Koniec powtarzania';

  @override
  String get repeatNever => 'Nigdy';

  @override
  String get repeatUntil => 'W określonym dniu';

  @override
  String get repeatAfter => 'Po określonej liczbie wystąpień';

  @override
  String get repeatCount => 'Liczba wystąpień';

  @override
  String get repeatDayOfMonth => 'Dni miesiąca';

  @override
  String get repeatMonths => 'Miesiące';

  @override
  String get repeatOrdinal => 'Kolejność dnia tygodnia';

  @override
  String get repeatSpecificDays => 'Wybrane dni';

  @override
  String get repeatFirst => 'Pierwszy';

  @override
  String get repeatSecond => 'Drugi';

  @override
  String get repeatThird => 'Trzeci';

  @override
  String get repeatFourth => 'Czwarty';

  @override
  String get repeatFifth => 'Piąty';

  @override
  String get repeatSecondToLast => 'Przedostatni';

  @override
  String get repeatLast => 'Ostatni';

  @override
  String get repeatAnyDay => 'Dzień';

  @override
  String get repeatWeekday => 'Dzień roboczy';

  @override
  String get repeatWeekendDay => 'Dzień weekendu';

  @override
  String repeatOrdinalDaySummary(String dayKey, String day) {
    String _temp0 = intl.Intl.selectLogic(dayKey, {
      'firstMO': 'w pierwszy poniedziałek',
      'firstTU': 'w pierwszy wtorek',
      'firstWE': 'w pierwszą środę',
      'firstTH': 'w pierwszy czwartek',
      'firstFR': 'w pierwszy piątek',
      'firstSA': 'w pierwszą sobotę',
      'firstSU': 'w pierwszą niedzielę',
      'firstday': 'w pierwszy dzień',
      'firstweekday': 'w pierwszy dzień roboczy',
      'firstweekend': 'w pierwszy dzień weekendu',
      'secondMO': 'w drugi poniedziałek',
      'secondTU': 'w drugi wtorek',
      'secondWE': 'w drugą środę',
      'secondTH': 'w drugi czwartek',
      'secondFR': 'w drugi piątek',
      'secondSA': 'w drugą sobotę',
      'secondSU': 'w drugą niedzielę',
      'secondday': 'w drugi dzień',
      'secondweekday': 'w drugi dzień roboczy',
      'secondweekend': 'w drugi dzień weekendu',
      'thirdMO': 'w trzeci poniedziałek',
      'thirdTU': 'w trzeci wtorek',
      'thirdWE': 'w trzecią środę',
      'thirdTH': 'w trzeci czwartek',
      'thirdFR': 'w trzeci piątek',
      'thirdSA': 'w trzecią sobotę',
      'thirdSU': 'w trzecią niedzielę',
      'thirdday': 'w trzeci dzień',
      'thirdweekday': 'w trzeci dzień roboczy',
      'thirdweekend': 'w trzeci dzień weekendu',
      'fourthMO': 'w czwarty poniedziałek',
      'fourthTU': 'w czwarty wtorek',
      'fourthWE': 'w czwartą środę',
      'fourthTH': 'w czwarty czwartek',
      'fourthFR': 'w czwarty piątek',
      'fourthSA': 'w czwartą sobotę',
      'fourthSU': 'w czwartą niedzielę',
      'fourthday': 'w czwarty dzień',
      'fourthweekday': 'w czwarty dzień roboczy',
      'fourthweekend': 'w czwarty dzień weekendu',
      'fifthMO': 'w piąty poniedziałek',
      'fifthTU': 'w piąty wtorek',
      'fifthWE': 'w piątą środę',
      'fifthTH': 'w piąty czwartek',
      'fifthFR': 'w piąty piątek',
      'fifthSA': 'w piątą sobotę',
      'fifthSU': 'w piątą niedzielę',
      'fifthday': 'w piąty dzień',
      'fifthweekday': 'w piąty dzień roboczy',
      'fifthweekend': 'w piąty dzień weekendu',
      'secondToLastMO': 'w przedostatni poniedziałek',
      'secondToLastTU': 'w przedostatni wtorek',
      'secondToLastWE': 'w przedostatnią środę',
      'secondToLastTH': 'w przedostatni czwartek',
      'secondToLastFR': 'w przedostatni piątek',
      'secondToLastSA': 'w przedostatnią sobotę',
      'secondToLastSU': 'w przedostatnią niedzielę',
      'secondToLastday': 'w przedostatni dzień',
      'secondToLastweekday': 'w przedostatni dzień roboczy',
      'secondToLastweekend': 'w przedostatni dzień weekendu',
      'lastMO': 'w ostatni poniedziałek',
      'lastTU': 'w ostatni wtorek',
      'lastWE': 'w ostatnią środę',
      'lastTH': 'w ostatni czwartek',
      'lastFR': 'w ostatni piątek',
      'lastSA': 'w ostatnią sobotę',
      'lastSU': 'w ostatnią niedzielę',
      'lastday': 'w ostatni dzień',
      'lastweekday': 'w ostatni dzień roboczy',
      'lastweekend': 'w ostatni dzień weekendu',
      'other': 'w $day',
    });
    return '$_temp0';
  }

  @override
  String repeatEveryDays(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Co $countString dnia',
      many: 'Co $countString dni',
      few: 'Co $countString dni',
      one: 'Codziennie',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryWeeks(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Co $countString tygodnia',
      many: 'Co $countString tygodni',
      few: 'Co $countString tygodnie',
      one: 'Co tydzień',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryMonths(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Co $countString miesiąca',
      many: 'Co $countString miesięcy',
      few: 'Co $countString miesiące',
      one: 'Co miesiąc',
    );
    return '$_temp0';
  }

  @override
  String repeatEveryYears(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Co $countString roku',
      many: 'Co $countString lat',
      few: 'Co $countString lata',
      one: 'Co rok',
    );
    return '$_temp0';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return '$days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return '$days. dnia miesiąca';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '$days',
      'second': '$days',
      'third': '$days',
      'fourth': '$days',
      'fifth': '$days',
      'secondToLast': '$days',
      'last': '$days',
      'other': '$days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'w miesiącach: $months';
  }

  @override
  String repeatTimesSummary(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString raza',
      many: '$countString razy',
      few: '$countString razy',
      one: '$countString raz',
    );
    return '$_temp0';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'do $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Ta reguła powtarzania korzysta z opcji, których ten edytor nie zmienia.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Tego powtarzania nie można użyć u dostawcy $provider.';
  }

  @override
  String get importance => 'Ważność';

  @override
  String get importanceLow => 'Niska';

  @override
  String get importanceNormal => 'Zwykła';

  @override
  String get importanceHigh => 'Wysoka';

  @override
  String get categories => 'Kategorie';

  @override
  String get scheduleSection => 'Harmonogram';

  @override
  String get dueGroup => 'Termin wykonania';

  @override
  String get startGroup => 'Rozpoczęcie';

  @override
  String get reminderGroup => 'Przypomnienie';

  @override
  String get organizationSection => 'Organizacja';

  @override
  String get actionsSection => 'Działania';

  @override
  String get advancedSection => 'Zaawansowane';

  @override
  String get addCategory => 'Dodaj kategorię';

  @override
  String get list => 'Lista';

  @override
  String get microsoftMoveUnsupported =>
      'W tej wersji przenoszenie między listami nie jest obsługiwane dla kont Microsoft To Do.';

  @override
  String get createSubtask => 'Utwórz podzadanie';

  @override
  String get subtasks => 'Podzadania';

  @override
  String get duplicateTask => 'Duplikuj zadanie';

  @override
  String get taskDuplicated => 'Zduplikowano zadanie.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Nie udało się zduplikować zadania: $error';
  }

  @override
  String get hideSubtasks => 'Ukryj podzadania';

  @override
  String get hideClosedSubtasks => 'Ukryj zamknięte podzadania';

  @override
  String get moveToTop => 'Przenieś na początek';

  @override
  String get deleteTask => 'Usuń zadanie';

  @override
  String get newSubtask => 'Nowe podzadanie';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Usunąć „$title”?';
  }

  @override
  String get metadata => 'Metadane';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Zaktualizowano';

  @override
  String get parent => 'Element nadrzędny';

  @override
  String get position => 'Pozycja';

  @override
  String get webLink => 'Link internetowy';

  @override
  String get assignment => 'Przypisanie';

  @override
  String get localState => 'Stan lokalny';

  @override
  String get pendingSync => 'Oczekuje na synchronizację';

  @override
  String get synced => 'Zsynchronizowano';

  @override
  String get account => 'Konto';

  @override
  String get sync => 'Synchronizuj';

  @override
  String get forceFullResync => 'Wymuś pełną synchronizację';

  @override
  String get forceFullResyncDescription =>
      'Ponownie wczytaj wszystkie dane z każdego połączonego konta. Używaj tej opcji wyłącznie do rozwiązywania problemów z synchronizacją.';

  @override
  String get runInBackgroundWhenClosed =>
      'Kontynuuj działanie po zamknięciu okna';

  @override
  String get showTrayIcon => 'Pokaż ikonę w zasobniku systemowym';

  @override
  String get startMinimizedToTray =>
      'Uruchamiaj zminimalizowane do zasobnika systemowego';

  @override
  String get launchAtLogin => 'Uruchamiaj przy logowaniu';

  @override
  String get launchAtLoginDescription =>
      'Uruchamiaj BusyMax w tle, aby przypomnienia działały po zalogowaniu do systemu.';

  @override
  String get launchAtLoginFailed =>
      'Nie udało się zmienić ustawienia uruchamiania przy logowaniu.';

  @override
  String get requiresTrayIcon => 'Wymaga ikony w zasobniku systemowym.';

  @override
  String get syncComplete => 'Synchronizacja zakończona.';

  @override
  String syncFailed(String error) {
    return 'Synchronizacja nie powiodła się: $error';
  }

  @override
  String get notifySyncFailures => 'Powiadomienia o błędach synchronizacji';

  @override
  String get notifyConflicts => 'Powiadomienia o konfliktach';

  @override
  String get notifyDueToday => 'Powiadomienia o zadaniach na dzisiaj';

  @override
  String get eventReminders => 'Przypomnienia o wydarzeniach';

  @override
  String get onState => 'Włączone';

  @override
  String get taskReminders => 'Przypomnienia o zadaniach';

  @override
  String get notificationDetailLevel => 'Szczegółowość powiadomień';

  @override
  String get notificationDetailPrivate => 'Prywatne';

  @override
  String get notificationDetailNormal => 'Zwykłe';

  @override
  String get quietHours => 'Godziny ciszy';

  @override
  String get quietHoursDescription => 'Wstrzymaj powiadomienia w tym okresie.';

  @override
  String get quietHoursStart => 'Początek godzin ciszy';

  @override
  String get quietHoursEnd => 'Koniec godzin ciszy';

  @override
  String get notifications => 'Powiadomienia';

  @override
  String get windowsNotificationsUnavailable =>
      'Powiadomienia systemu Windows są niedostępne';

  @override
  String get windowsNotificationsUnpackaged =>
      'Ta wersja deweloperska bez pakietu instalacyjnego nie może korzystać z powiadomień systemu Windows. Zainstaluj pakiet MSIX z podpisem testowym, aby przetestować przypomnienia.';

  @override
  String get windowsNotificationsInstalledFailure =>
      'BusyMax nie mógł zainicjować powiadomień systemu Windows. Przypomnienia nie będą wyświetlane do czasu rozwiązania tego problemu z instalacją.';

  @override
  String get appearance => 'Wygląd';

  @override
  String get theme => 'Motyw';

  @override
  String get themeSystem => 'Systemowy';

  @override
  String get settingsSystem => 'System';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get themeFamily => 'Rodzina motywów';

  @override
  String get themeFamilyYaru => 'Natywny Ubuntu (Yaru)';

  @override
  String get localization => 'Język i region';

  @override
  String get currentLocale => 'Język aplikacji';

  @override
  String get privacy => 'Prywatność';

  @override
  String get redactTaskContentInDiagnostics =>
      'Ukrywaj treść zadań w danych diagnostycznych';

  @override
  String get developerDiagnostics => 'Diagnostyka dla deweloperów';

  @override
  String get diagnostics => 'Diagnostyka';

  @override
  String get apiInspectorDisabled => 'Pokaż inspektor API';

  @override
  String get googleTasksApi => 'API Zadań Google';

  @override
  String discoveryRevision(String revision) {
    return 'Wersja dokumentu discovery: $revision';
  }

  @override
  String get implementedMethods => 'Zaimplementowane metody';

  @override
  String get supportsTasksScopes =>
      'Obsługuje zakresy uprawnień tasks i tasks.readonly';

  @override
  String get requiresTasksScope => 'Wymaga zakresu uprawnień tasks';

  @override
  String get blockedPendingOperations => 'Zablokowane operacje oczekujące';

  @override
  String get signInToInspectPendingOperations =>
      'Zaloguj się, aby sprawdzić oczekujące operacje.';

  @override
  String get noBlockedPendingOperations =>
      'Brak zablokowanych operacji oczekujących.';

  @override
  String get operationActions => 'Działania na operacji';

  @override
  String pendingOpListId(String id) {
    return 'lista=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'zadanie=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'próby=$countString';
  }

  @override
  String get retry => 'Ponów';

  @override
  String get discard => 'Odrzuć';

  @override
  String get discardChangesAction => 'Odrzuć zmiany';

  @override
  String get discardChanges => 'Odrzucić zmiany?';

  @override
  String get discardChangesConfirmation =>
      'Niezapisane zmiany w tym zadaniu zostaną utracone.';

  @override
  String get retryCompleted => 'Ponowienie zakończone.';

  @override
  String get discardPendingOperation => 'Odrzucić oczekującą operację?';

  @override
  String get discardPendingOperationConfirmation =>
      'Spowoduje to usunięcie zablokowanej operacji lokalnej. Następna synchronizacja odświeży dane z Zadań Google.';

  @override
  String get pendingOperationDiscarded => 'Odrzucono oczekującą operację.';

  @override
  String get syncFailureNotificationTitle =>
      'Synchronizacja BusyMax nie powiodła się';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Synchronizacja w tle nie powiodła się. $message';
  }

  @override
  String get conflictNotificationTitle => 'Konflikt synchronizacji BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Oczekująca zmiana lokalna została zablokowana. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Zadania na dzisiaj';

  @override
  String dueTodayNotificationBody(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString zadania ma termin na dzisiaj.',
      many: '$countString zadań ma termin na dzisiaj.',
      few: '$countString zadania mają termin na dzisiaj.',
      one: '$countString zadanie ma termin na dzisiaj.',
      zero: 'Brak zadań z terminem na dzisiaj.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Przypomnienie o wydarzeniu';

  @override
  String get taskReminderNotificationTitle => 'Przypomnienie o zadaniu';

  @override
  String get eventReminderNotificationBody =>
      'Wydarzenie wkrótce się rozpocznie.';

  @override
  String get taskReminderNotificationBody =>
      'Zbliża się termin wykonania zadania.';

  @override
  String get notificationOpenAction => 'Otwórz';

  @override
  String get notificationSnoozeAction => 'Przypomnij za 10 minut';

  @override
  String get notificationDismissAction => 'Zamknij';

  @override
  String get notificationDetailsHidden =>
      'Szczegóły są ukryte przez ustawienia prywatności.';

  @override
  String get previousMonth => 'Poprzedni miesiąc';

  @override
  String get nextMonth => 'Następny miesiąc';

  @override
  String get openMonthView => 'Otwórz widok miesiąca';

  @override
  String get previousYear => 'Poprzedni rok';

  @override
  String get nextYear => 'Następny rok';

  @override
  String get openYearView => 'Otwórz widok roku';

  @override
  String weekNumberTooltip(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return 'Tydzień $numberString';
  }

  @override
  String get resizeAllDayPanel => 'Zmień rozmiar panelu wydarzeń całodniowych';

  @override
  String scheduleItemCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString elementu',
      many: '$countString elementów',
      few: '$countString elementy',
      one: '$countString element',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Ten kalendarz jest tylko do odczytu.';

  @override
  String get selectTimeZone => 'Wybierz strefę czasową';

  @override
  String get searchLocations => 'Szukaj lokalizacji';

  @override
  String get noLocationsFound => 'Nie znaleziono lokalizacji';

  @override
  String get requiredField => 'To pole jest wymagane.';

  @override
  String get providerConnectionDescription =>
      'Połącz kalendarze i zadania od jednego z tych dostawców.';

  @override
  String get appleICloudProvider => 'Kalendarz Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Zadania Nextcloud';

  @override
  String get addAppleICloudAccount => 'Dodaj konto Kalendarza Apple iCloud';

  @override
  String get addNextcloudAccount => 'Dodaj konto Nextcloud';

  @override
  String get waitingForAppleICloud => 'Łączenie z Apple iCloud…';

  @override
  String get waitingForNextcloud => 'Oczekiwanie na autoryzację Nextcloud…';

  @override
  String get connectAppleICloudTitle => 'Połącz Kalendarz Apple iCloud';

  @override
  String get appleAccountEmail => 'Adres e-mail konta Apple';

  @override
  String get appleAppSpecificPassword => 'Hasło aplikacji';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Utwórz hasło aplikacji po włączeniu uwierzytelniania dwupoziomowego na koncie Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Zresetowanie hasła konta Apple unieważnia hasła aplikacji.';

  @override
  String get connectNextcloudTitle => 'Połącz Nextcloud';

  @override
  String get nextcloudServerUrl => 'Adres serwera Nextcloud lub CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Wpisz adres URL serwera Nextcloud lub wklej główny adres CalDAV skopiowany z Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax otworzy przeglądarkę. Zatwierdź tam dostęp, a następnie wróć do BusyMax.';

  @override
  String get connectAccountAction => 'Połącz';

  @override
  String get cancelAccountConnection => 'Anuluj łączenie';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'Konto usunięto lokalnie, ale nie udało się unieważnić jego hasła aplikacji Nextcloud.';

  @override
  String get davCachedOfflineNotice =>
      'Dane kalendarzy i zadań są zapisywane lokalnie, aby można było korzystać z nich offline.';

  @override
  String get davReauthenticationRequired =>
      'Połącz to konto ponownie, aby wznowić synchronizację.';

  @override
  String get davTemporarilyUnavailable =>
      'To konto jest tymczasowo niedostępne.';

  @override
  String get davPermissionChanged =>
      'Uprawnienia na serwerze uległy zmianie. Oczekujące zmiany zostały wstrzymane.';

  @override
  String get davUnsupportedServer =>
      'Ten serwer lub profil dostawcy nie jest obsługiwany.';

  @override
  String get collectionSettings => 'Kalendarze i listy zadań';

  @override
  String get calendarContent => 'Wydarzenia w kalendarzu';

  @override
  String get taskContent => 'Zadania';

  @override
  String get readOnlySharedCollection => 'Tylko do odczytu';

  @override
  String get pendingLocally => 'Oczekuje lokalnie';

  @override
  String get conflictBlocked => 'Zablokowane przez konflikt';

  @override
  String get authenticationBlocked => 'Zablokowane do ponownego połączenia';

  @override
  String get operationFailed => 'Operacja nie powiodła się';

  @override
  String get keepServerVersion => 'Zachowaj wersję z serwera';

  @override
  String get reapplyLocalChange => 'Sprawdź i ponownie zastosuj zmianę lokalną';

  @override
  String get duplicateLocalItem => 'Duplikuj jako nowy element';

  @override
  String get davConnectionState => 'Stan połączenia';

  @override
  String get davConnected => 'Połączono';

  @override
  String get davConnecting => 'Łączenie…';

  @override
  String get davSignedOut => 'Wylogowano';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Ostatnia udana synchronizacja: $time';
  }

  @override
  String get davNeverSynced => 'Jeszcze nie zsynchronizowano';

  @override
  String get refreshCollections => 'Odśwież kalendarze i listy zadań';

  @override
  String nextcloudServerHost(String host) {
    return 'Serwer: $host';
  }

  @override
  String get collectionSupportsEvents => 'Kalendarz wydarzeń';

  @override
  String get collectionSupportsTasks => 'Lista zadań';

  @override
  String get collectionSupportsEventsAndTasks => 'Wydarzenia i zadania';

  @override
  String get writableCollection => 'Możliwy zapis';

  @override
  String get sharedCollection => 'Udostępniona';

  @override
  String collectionLastSynced(String time) {
    return 'Ostatnia synchronizacja: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Problem z synchronizacją: $code';
  }

  @override
  String get syncConflicts => 'Konflikty synchronizacji';

  @override
  String remoteChangedAt(String time) {
    return 'Zmieniono na serwerze: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Zmiana lokalna: $summary';
  }

  @override
  String get conflictResolutionFailed => 'Nie udało się rozwiązać konfliktu.';

  @override
  String get recurringEventScope => 'Zakres wydarzenia cyklicznego';

  @override
  String get entireSeries => 'Cała seria';

  @override
  String get singleOccurrence => 'To wydarzenie';

  @override
  String get thisAndFollowingEvents => 'To i kolejne wydarzenia';

  @override
  String get thisAndFutureUnavailable =>
      'Ten dostawca nie obsługuje tej opcji.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Nie można bezpiecznie przenieść tego i kolejnych wydarzeń. Wybierz to wydarzenie lub całą serię.';

  @override
  String get entireSeriesMoveUnavailable =>
      'Reguła powtarzania nie jest dostępna lokalnie. Zamiast tego przenieś to wydarzenie.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Skopiować wydarzenie i usunąć oryginał?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax nie może przenieść tego wydarzenia bezpośrednio z $source do $destination. Najpierw utworzy kopię, a oryginał usunie dopiero po jej pomyślnym utworzeniu. Identyfikatory wydarzenia zmienią się; odpowiedzi uczestników mogą zostać zresetowane, a zaproszenia lub powiadomienia o odwołaniu mogą zostać wysłane. Linki do konferencji, załączniki, przypomnienia, pola specyficzne dla dostawcy i wyjątki powtarzania mogą nie zostać przeniesione.';
  }

  @override
  String get copyAndDelete => 'Skopiuj i usuń';

  @override
  String get chooseRecurringEventScope =>
      'Wybierz, czy zmiana dotyczy całej serii, tylko tego wystąpienia, czy tego i kolejnych wydarzeń.';

  @override
  String get taskDueBeforeStart =>
      'Termin wykonania nie może być wcześniejszy niż rozpoczęcie.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Ustaw godziny rozpoczęcia i wykonania albo ustaw zadanie jako całodniowe.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Usunąć „$title”?';
  }

  @override
  String get setCustomCalendarName => 'Ustaw własną nazwę';

  @override
  String get setAction => 'Ustaw';

  @override
  String get removeFromMyCalendars => 'Usuń z moich kalendarzy';

  @override
  String get removeAction => 'Usuń';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Usunąć „$title” z listy Kalendarza Google? Udostępniony kalendarz i jego wydarzenia nie zostaną usunięte.';
  }

  @override
  String get calendarCannotRemove =>
      'Tego kalendarza nie można usunąć ani odłączyć od tego konta.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Przed usunięciem lub odłączeniem kalendarza poczekaj na zakończenie synchronizacji jego oczekujących zmian.';

  @override
  String get calendarSubscriptions => 'Subskrypcje kalendarzy';

  @override
  String get calendarSubscriptionsDescription =>
      'Dodaj kalendarze tylko do odczytu, odświeżane z bezpiecznego adresu WebCal.';

  @override
  String get addCalendarSubscription => 'Dodaj subskrypcję kalendarza';

  @override
  String get subscriptionName => 'Nazwa lokalna';

  @override
  String get subscriptionUrl => 'Adres URL subskrypcji';

  @override
  String get subscriptionUrlHelp =>
      'Wpisz adres HTTPS lub webcal. BusyMax przechowuje pełny adres URL w bezpiecznym magazynie.';

  @override
  String get subscriptionUrlInvalid =>
      'Wpisz prawidłowy adres HTTPS lub webcal bez danych użytkownika ani fragmentu.';

  @override
  String get subscriptionColor => 'Kolor lokalny';

  @override
  String get subscriptionColorHelp =>
      'Użyj sześciocyfrowego kodu koloru, np. #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Wpisz sześciocyfrowy szesnastkowy kod koloru.';

  @override
  String get subscriptionRefreshMode => 'Częstotliwość odświeżania';

  @override
  String get subscriptionAutomatic => 'Automatycznie';

  @override
  String get subscriptionHourly => 'Co godzinę';

  @override
  String get subscriptionSixHours => 'Co sześć godzin';

  @override
  String get subscriptionDaily => 'Codziennie';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Źródło: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Wpisz prawidłowy adres URL, aby wyświetlić jego źródło bez ujawniania poufnych danych.';

  @override
  String get subscriptionReadOnly => 'Subskrypcja tylko do odczytu';

  @override
  String get subscriptionNeverRefreshed => 'Jeszcze nie odświeżono';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Ostatnie udane odświeżenie: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Następne odświeżenie: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Aktualne';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Problem z odświeżaniem: $code';
  }

  @override
  String get refreshNow => 'Odśwież teraz';

  @override
  String get unsubscribe => 'Anuluj subskrypcję';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Anulować subskrypcję „$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Spowoduje to usunięcie lokalnej subskrypcji i jej wydarzeń z pamięci podręcznej. Opublikowany kalendarz nie zostanie zmieniony.';

  @override
  String get addSubscriptionAction => 'Dodaj subskrypcję';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Subskrypcja kalendarza nie powiodła się: $error';
  }

  @override
  String get subscriptions => 'Subskrypcje';

  @override
  String get calendarImport => 'Import kalendarza';

  @override
  String get calendarImportDescription =>
      'Wybierz plik, sprawdź jego wydarzenia, a następnie wybierz kalendarz docelowy z możliwością zapisu.';

  @override
  String get importIcsFile => 'Importuj plik .ics';

  @override
  String get importIcsPreview => 'Importuj wydarzenia kalendarza';

  @override
  String importEventsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Zestawy wydarzeń możliwe do zaimportowania: $countString';
  }

  @override
  String importInvalidEvents(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Nieprawidłowe wydarzenia: $countString';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Celowo pominięto: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Brak dostępnego kalendarza docelowego z możliwością zapisu.';

  @override
  String get importDestinationCalendar => 'Kalendarz docelowy';

  @override
  String get importIcsConfirm => 'Importuj wydarzenia';

  @override
  String get importIcsComplete => 'Import zakończony';

  @override
  String importQueued(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Zaimportowano lub dodano do kolejki: $countString';
  }

  @override
  String importDuplicatesSkipped(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pominięte duplikaty: $countString';
  }

  @override
  String importUnsupportedSets(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Nieobsługiwane zestawy powtarzania: $countString';
  }

  @override
  String importIcsFailed(String error) {
    return 'Nie udało się zaimportować pliku kalendarza: $error';
  }

  @override
  String get networkOffline => 'Brak połączenia';

  @override
  String get networkOfflineDescription =>
      'Zmiany zostaną zsynchronizowane po przywróceniu połączenia.';

  @override
  String get networkOfflineTryAgain =>
      'Brak połączenia. Połącz się z internetem i spróbuj ponownie.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'w dniach $days miesiąca';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(String day) {
    return '$day';
  }

  @override
  String repeatWeekdayListPair(String first, String second) {
    return '$first i $second';
  }

  @override
  String repeatWeekdayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatMonthDayListPair(String first, String second) {
    return '$first i $second';
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
    return '$first i $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first i $second';
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
    return '$frequency, $day $month';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency, $days $month';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency, $day $months';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency, $days $months';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '$days $month',
      'second': '$days $month',
      'third': '$days $month',
      'fourth': '$days $month',
      'fifth': '$days $month',
      'secondToLast': '$days $month',
      'last': '$days $month',
      'other': '$days $month',
    });
    return '$frequency, $_temp0';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': '1. $days w miesiącach: $months',
      'second': '2. $days w miesiącach: $months',
      'third': '3. $days w miesiącach: $months',
      'fourth': '4. $days w miesiącach: $months',
      'fifth': '5. $days w miesiącach: $months',
      'secondToLast': '$days (przedostatnie wystąpienie w miesiącach: $months)',
      'last': '$days (ostatnie wystąpienie w miesiącach: $months)',
      'other': '$days w miesiącach: $months',
    });
    return '$frequency, $_temp0';
  }
}

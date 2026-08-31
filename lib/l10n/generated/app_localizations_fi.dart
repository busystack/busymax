// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Yhdistä Google-, Microsoft-, Apple iCloud Calendar- tai Nextcloud-tilit.';

  @override
  String get googlePermissionsConsentNotice =>
      'Valitse Googlen käyttöoikeusnäkymässä sekä Kalenteri- että Tehtävät-käyttöoikeudet.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google Kalenterin ja Google Tasksin käyttöoikeudet vaaditaan. Yritä uudelleen ja valitse molemmat valintaruudut.';

  @override
  String get finishSetup => 'Viimeistele määritys';

  @override
  String get continueSetup => 'Jatka';

  @override
  String get onboardingSetupTitle => 'Määritä BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Yhdistä tilit';

  @override
  String get onboardingAccountsStepDescription =>
      'Lisää kaikki tilit, joita haluat käyttää. BusyMax synkronoi tuetut kalenterit, tapahtumat, tehtäväluettelot ja tehtävät jokaiselta tililtä.';

  @override
  String get onboardingPreferencesStepTitle => 'Valitse järjestelmäasetukset';

  @override
  String get onboardingPreferencesStepDescription =>
      'Määritä sovelluksen toiminta työpöydällä, muistutukset, ilmoitusten yksityiskohtaisuus ja ulkoasu ennen aikataulun avaamista.';

  @override
  String get signInWithGoogle => 'Kirjaudu Google-tilillä';

  @override
  String get signInWithMicrosoft => 'Kirjaudu Microsoft-tilillä';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured =>
      'Tätä palveluntarjoajaa ei ole määritetty.';

  @override
  String get waitingForGoogleSignIn => 'Odotetaan Google-kirjautumista...';

  @override
  String get waitingForMicrosoftSignIn =>
      'Odotetaan Microsoft-kirjautumista...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsoft-kirjautumista ei ole määritetty. Aseta MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Peruuta';

  @override
  String get close => 'Sulje';

  @override
  String get exit => 'Lopeta';

  @override
  String get options => 'Valinnat';

  @override
  String get hide => 'Piilota';

  @override
  String get show => 'Näytä';

  @override
  String get export => 'Vie';

  @override
  String get save => 'Tallenna';

  @override
  String get settings => 'Asetukset';

  @override
  String get all => 'Kaikki';

  @override
  String get calendarEvents => 'Tapahtumat';

  @override
  String get calendarTasks => 'Tehtävät';

  @override
  String get calendar => 'Kalenteri';

  @override
  String get calendars => 'Kalenterit';

  @override
  String get newCalendar => 'Uusi kalenteri';

  @override
  String get calendarColor => 'Kalenterin väri';

  @override
  String calendarColorOption(int number) {
    return 'Väri $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Tämä palveluntarjoaja ei tue kalenterien hallintaa BusyMaxissa.';

  @override
  String get primaryCalendarCannotDelete =>
      'Ensisijaista kalenteria ei voi poistaa.';

  @override
  String calendarCreateFailed(String error) {
    return 'Kalenteria ei voitu luoda: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'Kalenteri luotiin, mutta BusyMax ei voinut päivittää tiliä. Se tulee näkyviin seuraavan synkronoinnin jälkeen.';

  @override
  String calendarUpdateFailed(String error) {
    return 'Kalenteria ei voitu päivittää: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'Kalenteria ei voitu poistaa: $error';
  }

  @override
  String get newEvent => 'Uusi tapahtuma';

  @override
  String get refreshCalendar => 'Päivitä kalenteri';

  @override
  String get openInProvider => 'Avaa palvelussa';

  @override
  String get hideFromSchedule => 'Piilota aikataulusta';

  @override
  String get showInSchedule => 'Näytä aikataulussa';

  @override
  String get noCalendarsSynced => 'Kalentereita ei ole vielä synkronoitu.';

  @override
  String get allDay => 'Koko päivä';

  @override
  String moreItems(int count) {
    return '+$count muuta';
  }

  @override
  String get noEventsOrTasks => 'Ei tapahtumia tai tehtäviä';

  @override
  String get scheduleLoading => 'Ladataan aikataulua...';

  @override
  String get scheduleUnavailable => 'Aikataulu ei ole käytettävissä';

  @override
  String get scheduleNoSources =>
      'Ei näkyviä kalentereita tai tehtäväluetteloita';

  @override
  String get scheduleNoSourcesDescription =>
      'Valitse asetuksissa, mitä näytetään, ja päivitä sitten näkymä.';

  @override
  String get scheduleSignInRequired => 'Yhdistä tili';

  @override
  String get scheduleSignInDescription =>
      'Kirjaudu sisään synkronoidaksesi kalenterit ja tehtävät.';

  @override
  String get scheduleNoSearchResults => 'Ei vastaavia tapahtumia tai tehtäviä';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Kokeile toista hakua tai tyhjennä nykyiset suodattimet.';

  @override
  String get refresh => 'Päivitä';

  @override
  String get trayOpenBusyMax => 'Avaa BusyMax';

  @override
  String get trayShowBusyMax => 'Näytä BusyMax';

  @override
  String get trayNewEvent => 'Uusi tapahtuma…';

  @override
  String get trayNewTask => 'Uusi tehtävä…';

  @override
  String get trayToday => 'Tänään';

  @override
  String get trayAllDay => 'Koko päivä';

  @override
  String get trayNow => 'Nyt';

  @override
  String get trayCalendarEvent => 'Kalenteritapahtuma';

  @override
  String get trayUntitledEvent => 'Nimetön tapahtuma';

  @override
  String get trayNothingElseToday => 'Ei muuta tänään';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tehtävää erääntyy tänään',
      one: '1 tehtävä erääntyy tänään',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Avaa tämän päivän agenda';

  @override
  String get traySyncNow => 'Synkronoi nyt';

  @override
  String get traySyncing => 'Synkronoidaan…';

  @override
  String get trayNotConnected => 'Ei yhteyttä';

  @override
  String get trayNotYetSynced => 'Ei vielä synkronoitu';

  @override
  String get trayLastSyncedJustNow => 'Synkronoitu juuri nyt';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synkronoitu $count minuuttia sitten',
      one: 'Synkronoitu minuutti sitten',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synkronoitu $count tuntia sitten',
      one: 'Synkronoitu tunti sitten',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synkronoitu $count päivää sitten',
      one: 'Synkronoitu päivä sitten',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Asetukset';

  @override
  String get trayQuitBusyMax => 'Lopeta BusyMax';

  @override
  String get agendaLoadMoreOverdue => 'Lataa lisää myöhässä olevia tehtäviä';

  @override
  String get agendaLoadMoreNoDate => 'Lataa lisää päiväämättömiä tehtäviä';

  @override
  String get viewDay => 'Päivä';

  @override
  String get viewWeek => 'Viikko';

  @override
  String get viewMonth => 'Kuukausi';

  @override
  String get viewYear => 'Vuosi';

  @override
  String get viewAgenda => 'Agendanäkymä';

  @override
  String get scheduleSettings => 'Aikataulu';

  @override
  String get scheduleDisplaySettings => 'Aikataulun näyttö';

  @override
  String get scheduleDisplayHoursDescription =>
      'Päivä- ja viikkonäkymät näyttävät aluksi tämän aikavälin. Aikaisemmat ja myöhemmät kohteet laajentavat sitä tarvittaessa.';

  @override
  String get scheduleDayStartsAt => 'Päivä alkaa';

  @override
  String get scheduleDayEndsAt => 'Päivä päättyy';

  @override
  String get sourceCalendar => 'Kalenteri';

  @override
  String get sourceTaskList => 'Tehtäväluettelo';

  @override
  String get createChoiceTitle => 'Luo';

  @override
  String get createEventAtTime => 'Tapahtuma';

  @override
  String get createTaskAtDate => 'Tehtävä';

  @override
  String get editEvent => 'Muokkaa tapahtumaa';

  @override
  String get eventTitle => 'Tapahtuman nimi';

  @override
  String get location => 'Sijainti';

  @override
  String get timeSlot => 'Ajankohta';

  @override
  String get startDateTime => 'Alkamispäivä ja -aika';

  @override
  String get endDateTime => 'Päättymispäivä ja -aika';

  @override
  String get doesNotRepeat => 'Ei toistu';

  @override
  String get defaultReminder => 'Oletusmuistutus';

  @override
  String get guests => 'Vieraat';

  @override
  String get noGuests => 'Ei vieraita';

  @override
  String get attendeeRequired => 'Pakollinen';

  @override
  String get attendeeOptional => 'Valinnainen';

  @override
  String get meetingSection => 'Kokous';

  @override
  String get addGoogleMeet => 'Lisää Google Meet';

  @override
  String get addTeamsMeeting => 'Lisää Microsoft Teams -kokous';

  @override
  String get onlineMeetingAdded => 'Verkkokokous lisätty';

  @override
  String get requestResponses => 'Pyydä vastauksia';

  @override
  String get requestResponsesDescription =>
      'Pyydä vieraita vastaamaan kutsuun.';

  @override
  String get hideGuestList => 'Piilota vierasluettelo';

  @override
  String get hideGuestListDescription =>
      'Vieraat eivät näe, keitä muita on kutsuttu.';

  @override
  String get allowNewTimeProposals => 'Salli uudet aikaehdotukset';

  @override
  String get allowNewTimeProposalsDescription =>
      'Vieraat voivat ehdottaa toista kokousaikaa.';

  @override
  String get notifyGuestsTitle => 'Ilmoitetaanko vieraille?';

  @override
  String get notifyGuestsSaveMessage =>
      'Tässä kokouksessa on vieraita. Lähetetäänkö kutsut tai tapahtumapäivitykset tallennettaessa?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Tässä kokouksessa on vieraita. Lähetetäänkö peruutus, kun kokous poistetaan?';

  @override
  String get sendUpdates => 'Lähetä päivitykset';

  @override
  String get sendCancellation => 'Lähetä peruutus';

  @override
  String get doNotSend => 'Älä lähetä';

  @override
  String get microsoftNotifyGuestsSaveTitle => 'Tallennetaanko kokous?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft lähettää vieraille kutsut tai tapahtumapäivitykset.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => 'Poistetaanko kokous?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft lähettää vieraille peruutuksen.';

  @override
  String get organizer => 'Järjestäjä';

  @override
  String get yourResponse => 'Vastauksesi';

  @override
  String get guestResponses => 'Vieraiden vastaukset';

  @override
  String get respond => 'Vastaa';

  @override
  String get acceptInvitation => 'Hyväksy';

  @override
  String get tentativeInvitation => 'Alustava';

  @override
  String get declineInvitation => 'Hylkää';

  @override
  String get joinMeeting => 'Liity kokoukseen';

  @override
  String get responseAccepted => 'Hyväksytty';

  @override
  String get responseTentative => 'Alustava';

  @override
  String get responseDeclined => 'Hylätty';

  @override
  String get responseNeedsAction => 'Vastausta odotetaan';

  @override
  String get responseNotResponded => 'Ei vastausta';

  @override
  String get responseOrganizer => 'Järjestäjä';

  @override
  String invitationResponseFailed(String error) {
    return 'Vastauksesi lähetys epäonnistui: $error';
  }

  @override
  String get joinMeetingFailed => 'Kokouslinkkiä ei voitu avata.';

  @override
  String get description => 'Kuvaus';

  @override
  String get availabilityShowAs => 'Saatavuus / Näytä tilana';

  @override
  String get busy => 'Varattu';

  @override
  String get visibility => 'Näkyvyys';

  @override
  String get defaultVisibility => 'Oletusnäkyvyys';

  @override
  String get conference => 'Verkkokokous';

  @override
  String get noConference => 'Ei verkkokokousta';

  @override
  String get providerCalendar => 'Palveluntarjoajan kalenteri';

  @override
  String get formatBoldShortLabel => 'L';

  @override
  String get formatBoldTooltip => 'Lihavointi';

  @override
  String get formatItalicShortLabel => 'K';

  @override
  String get formatItalicTooltip => 'Kursivointi';

  @override
  String get formatUnderlineShortLabel => 'A';

  @override
  String get formatUnderlineTooltip => 'Alleviivaus';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuuttia ennen',
      one: '1 minuutti ennen',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'Alkamishetkellä';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours tuntia ennen',
      one: '1 tunti ennen',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days päivää ennen',
      one: '1 päivä ennen',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Vapaa';

  @override
  String get availabilityTentative => 'Alustava';

  @override
  String get availabilityOutOfOffice => 'Poissa toimistolta';

  @override
  String get availabilityWorkingElsewhere => 'Työskentelee muualla';

  @override
  String get visibilityDefault => 'Oletus';

  @override
  String get visibilityPublic => 'Julkinen';

  @override
  String get visibilityPrivate => 'Yksityinen';

  @override
  String get visibilityConfidential => 'Luottamuksellinen';

  @override
  String get sensitivityNormal => 'Normaali';

  @override
  String get sensitivityPersonal => 'Henkilökohtainen';

  @override
  String get tasks => 'Tehtävät';

  @override
  String get allTasks => 'Kaikki tehtävät';

  @override
  String tasksInList(String title) {
    return 'Luettelon $title tehtävät';
  }

  @override
  String get taskLists => 'Tehtäväluettelot';

  @override
  String get navigation => 'Siirtyminen';

  @override
  String get mainMenu => 'Päävalikko';

  @override
  String get keyboardShortcuts => 'Pikanäppäimet';

  @override
  String get shortcutGroupGeneral => 'Yleiset';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Näytä tämä pikanäppäinluettelo';

  @override
  String get shortcutGroupNavigation => 'Siirtyminen';

  @override
  String get shortcutNextPeriod => 'Seuraava ajanjakso';

  @override
  String get shortcutNextPeriodDescription =>
      'Seuraava viikko viikkonäkymässä, seuraava kuukausi kuukausinäkymässä ja niin edelleen';

  @override
  String get shortcutPreviousPeriod => 'Edellinen ajanjakso';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Edellinen viikko viikkonäkymässä, edellinen kuukausi kuukausinäkymässä ja niin edelleen';

  @override
  String get shortcutJumpToToday => 'Siirry tähän päivään';

  @override
  String get shortcutGroupView => 'Näkymä';

  @override
  String get shortcutDayView => 'Päivänäkymä';

  @override
  String get shortcutWeekView => 'Viikkonäkymä';

  @override
  String get shortcutMonthView => 'Kuukausinäkymä';

  @override
  String get shortcutYearView => 'Vuosinäkymä';

  @override
  String get shortcutAgendaView => 'Agendanäkymä';

  @override
  String get shortcutGroupCreateAndEdit => 'Luominen ja muokkaaminen';

  @override
  String get shortcutSaveItem => 'Tallenna tapahtuma tai tehtävä';

  @override
  String get shortcutDeleteItem => 'Poista tapahtuma tai tehtävä';

  @override
  String get shortcutGroupTaskEditing => 'Tehtävien muokkaaminen';

  @override
  String get shortcutCancelEditing => 'Peruuta muokkaaminen';

  @override
  String get shortcutCancelEditingDescription =>
      'Sulje tehtävän muokkaus tai tehtävän tiedot';

  @override
  String get aboutBusyMax => 'Tietoja BusyMaxista';

  @override
  String get aboutBusyMaxDescription => 'Kalenteri ja tehtävät';

  @override
  String get license => 'Lisenssi';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Verkkosivusto';

  @override
  String get sourceCode => 'Lähdekoodi';

  @override
  String get reportAnIssue => 'Ilmoita ongelmasta';

  @override
  String get sendFeedback => 'Lähetä palautetta';

  @override
  String get feedbackSubmit => 'Lähetä';

  @override
  String get feedbackCategory => 'Luokka';

  @override
  String get feedbackSelectCategory => 'Valitse luokka';

  @override
  String get feedbackCategoryProblem => 'Ongelma tai virhe';

  @override
  String get feedbackCategoryFeature => 'Ominaisuuspyyntö';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Tietosuojaan tai tietoturvaan liittyvä huoli';

  @override
  String get feedbackCategoryUsability => 'Käytettävyyshuoli';

  @override
  String get feedbackCategoryOther => 'Muu';

  @override
  String get feedbackSubject => 'Aihe';

  @override
  String get feedbackDetailedMessage => 'Yksityiskohtainen viesti';

  @override
  String get feedbackReplyEmail =>
      'Sähköpostiosoite vastausta varten (valinnainen)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Sisällytä tekniset tiedot';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Lisää vain Linux-käyttöjärjestelmäsi version ja sovelluksen alueasetuksen. Lokeja, tilitietoja, tiedostonimiä tai muita diagnostiikkatietoja ei lisätä.';

  @override
  String get feedbackCategoryRequired => 'Valitse luokka.';

  @override
  String get feedbackSubjectLengthError =>
      'Aiheen pituuden on oltava 3–120 merkkiä.';

  @override
  String get feedbackMessageLengthError =>
      'Viestin pituuden on oltava 10–5 000 merkkiä.';

  @override
  String get feedbackInvalidEmail => 'Anna kelvollinen sähköpostiosoite.';

  @override
  String get feedbackConnectionError =>
      'BusyStackiin ei saatu yhteyttä. Tarkista yhteys ja yritä uudelleen.';

  @override
  String get feedbackTimeoutError =>
      'Pyyntö aikakatkaistiin. Palautettasi ei ole tyhjennetty. Yritä uudelleen.';

  @override
  String get feedbackRateLimitedError =>
      'Tästä verkosta on lähetetty liian monta palautetta. Odota ja yritä uudelleen.';

  @override
  String get feedbackRejectedError =>
      'Palvelin hylkäsi lähetyksen. Tarkista kentät ja yritä uudelleen.';

  @override
  String get feedbackServerError =>
      'BusyStack ei voi vastaanottaa palautettasi juuri nyt. Palautettasi ei ole tyhjennetty. Yritä uudelleen.';

  @override
  String feedbackSuccess(String id) {
    return 'Palaute lähetetty. Viite: $id';
  }

  @override
  String get toggleSidebar => 'Näytä tai piilota sivupalkki';

  @override
  String get showSidebar => 'Näytä sivupaneeli';

  @override
  String get hideSidebar => 'Piilota sivupaneeli';

  @override
  String get accounts => 'Tilit';

  @override
  String get currentAccount => 'Nykyinen tili';

  @override
  String get switchAccount => 'Vaihda tiliä';

  @override
  String get addGoogleAccount => 'Lisää Google-tili';

  @override
  String get addMicrosoftAccount => 'Lisää Microsoft-tili';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Kirjautunut';

  @override
  String get removeAccount => 'Poista tili…';

  @override
  String get removingAccount => 'Poistetaan tiliä…';

  @override
  String get removeAccountDescription =>
      'Lopeta synkronointi ja poista tämän tilin tiedot tältä laitteelta.';

  @override
  String removeAccountTitle(String account) {
    return 'Poistetaanko $account BusyMaxista?';
  }

  @override
  String get removeAccountConfirmation =>
      'Tämä poistaa laitteelta välimuistiin tallennetut tehtävät, kalenterit, tapahtumat, muistutukset ja odottavat offline-muutokset. Synkronoimattomat muutokset menetetään. Palveluntarjoajan kalenteri-, tapahtuma-, tehtäväluettelo- ja tehtäväkopioita ei poisteta.';

  @override
  String get revokeGoogleAccess =>
      'Peruuta myös BusyMaxin käyttöoikeus tähän Google-tiliin';

  @override
  String get revokeGoogleAccessDescription =>
      'Käyttöoikeus on myönnettävä uudelleen ennen tilin yhdistämistä.';

  @override
  String get removeAccountAction => 'Poista tili';

  @override
  String get removeAccountFailed =>
      'Tilin poistamista ei voitu viimeistellä. Yritä uudelleen.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Tili poistettiin tältä laitteelta, mutta BusyMax ei voinut peruuttaa Google-käyttöoikeutta. Voit peruuttaa sen Google-tililtäsi.';

  @override
  String get newTaskList => 'Uusi tehtäväluettelo';

  @override
  String taskListCreateFailed(String error) {
    return 'Tehtäväluettelon luominen epäonnistui: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'Tehtäväluettelon uudelleennimeäminen epäonnistui: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'Tehtäväluettelon poistaminen epäonnistui: $error';
  }

  @override
  String get signInToViewTaskLists =>
      'Kirjaudu sisään nähdäksesi tehtäväluettelot.';

  @override
  String get noTaskListsSynced =>
      'Tehtäväluetteloita ei ole vielä synkronoitu.';

  @override
  String get listActions => 'Luettelon toiminnot';

  @override
  String get rename => 'Nimeä uudelleen';

  @override
  String get delete => 'Poista';

  @override
  String get renameList => 'Nimeä luettelo uudelleen';

  @override
  String get deleteList => 'Poista luettelo';

  @override
  String get unshare => 'Lopeta jakaminen';

  @override
  String get readOnlyTaskListCannotRename =>
      'Tämä tehtäväluettelo on vain luku -tilassa, eikä sitä voi nimetä uudelleen.';

  @override
  String get taskListCannotDelete =>
      'Tätä tehtäväluetteloa ei voi poistaa nykyisillä käyttöoikeuksillasi.';

  @override
  String get builtInMicrosoftList => 'Sisäänrakennettu';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Microsoft To Do -sovelluksen sisäänrakennettuja luetteloita ei voi nimetä uudelleen tai poistaa.';

  @override
  String deleteListConfirmation(String title) {
    return 'Poistetaanko ”$title” Google Tasksista?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return 'Poistetaanko ”$title” ja kaikki sen tehtävät?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return 'Lopetetaanko kohteen ”$title” jakaminen tämän tilin kanssa?';
  }

  @override
  String get deleteEvent => 'Poista tapahtuma';

  @override
  String get title => 'Nimi';

  @override
  String get create => 'Luo';

  @override
  String get newTask => 'Uusi tehtävä';

  @override
  String get clearCompleted => 'Tyhjennä valmiit';

  @override
  String get refreshList => 'Päivitä luettelo';

  @override
  String get refreshAll => 'Päivitä kaikki';

  @override
  String get listRefreshed => 'Luettelo päivitetty.';

  @override
  String get allTasksRefreshed => 'Kaikki tilit päivitetty.';

  @override
  String exportedFile(String path) {
    return 'Viety kohteeseen $path';
  }

  @override
  String exportFailed(String error) {
    return 'Vienti epäonnistui: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Päivitys epäonnistui: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Valitse tai luo tehtäväluettelo aloittaaksesi.';

  @override
  String get signInToViewTasks => 'Kirjaudu sisään nähdäksesi tehtävät.';

  @override
  String get noTasks => 'Ei tehtäviä.';

  @override
  String get noTasksYet => 'Ei vielä tehtäviä';

  @override
  String get noTasksYetMessage =>
      'Luo tehtävä tai päivitä tilisi aloittaaksesi.';

  @override
  String get noTasksInList => 'Tässä luettelossa ei ole tehtäviä.';

  @override
  String get overdue => 'Myöhässä';

  @override
  String get today => 'Tänään';

  @override
  String get tomorrow => 'Huomenna';

  @override
  String get upcoming => 'Tulossa';

  @override
  String get noDate => 'Ei päivämäärää';

  @override
  String get completed => 'Valmiit';

  @override
  String duePrefix(String date) {
    return 'Eräpäivä $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date klo $time';
  }

  @override
  String get taskDetails => 'Tehtävän tiedot';

  @override
  String get editTask => 'Muokkaa tehtävää';

  @override
  String get noTaskSelected => 'Tehtävää ei ole valittu.';

  @override
  String get noTaskSelectedHelper =>
      'Valitse tehtävä nähdäksesi ja muokataksesi sen tietoja.';

  @override
  String get taskUnavailable => 'Tehtävä ei ole käytettävissä.';

  @override
  String get signInToEditTasks => 'Kirjaudu sisään muokataksesi tehtäviä.';

  @override
  String get refreshTask => 'Päivitä tehtävä';

  @override
  String get primarySection => 'Ensisijaiset tiedot';

  @override
  String get statusSection => 'Tila';

  @override
  String get openStatus => 'Avoin';

  @override
  String get doneStatus => 'Valmis';

  @override
  String get taskStatus => 'Tila';

  @override
  String get taskStatusNone => 'Ei tilaa';

  @override
  String get taskStatusNeedsAction => 'Vaatii toimenpiteitä';

  @override
  String get taskStatusInProcess => 'Käsittelyssä';

  @override
  String get taskStatusCompleted => 'Valmis';

  @override
  String get taskStatusCancelled => 'Peruutettu';

  @override
  String completionPercent(int percent) {
    return 'Valmis $percent %';
  }

  @override
  String get completionDate => 'Valmistumispäivä';

  @override
  String get priority => 'Tärkeys';

  @override
  String get priorityNone => 'Ei tärkeyttä';

  @override
  String priorityHighValue(int priority) {
    return 'Tärkeys $priority · korkea';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Tärkeys $priority · keskitaso';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Tärkeys $priority · matala';
  }

  @override
  String get taskUrl => 'Tehtävän URL';

  @override
  String get invalidTaskUrl => 'Anna absoluuttinen URL-osoite skeemoineen.';

  @override
  String get classification => 'Luokittelu';

  @override
  String get classificationPublic => 'Näytä koko tehtävä jaettaessa';

  @override
  String get classificationConfidential => 'Näytä jaettaessa vain varattu-aika';

  @override
  String get classificationPrivate => 'Piilota tämä tehtävä jaettaessa';

  @override
  String get pinTask => 'Kiinnitä tehtävä';

  @override
  String get notes => 'Muistiinpanot';

  @override
  String get dueDate => 'Eräpäivä';

  @override
  String get clearDueDate => 'Tyhjennä eräpäivä';

  @override
  String get dueTime => 'Erääntymisaika';

  @override
  String get startDate => 'Alkamispäivä';

  @override
  String get startTime => 'Alkamisaika';

  @override
  String get endDate => 'Päättymispäivä';

  @override
  String get endTime => 'Päättymisaika';

  @override
  String get reminderDate => 'Muistutuspäivä';

  @override
  String get reminderTime => 'Muistutusaika';

  @override
  String get reminder => 'Muistutus';

  @override
  String get addReminder => 'Lisää muistutus';

  @override
  String get reminders => 'Muistutukset';

  @override
  String get noReminders => 'Ei muistutuksia';

  @override
  String get editReminder => 'Muokkaa muistutusta';

  @override
  String get beforeTaskStarts => 'Ennen tehtävän alkamista';

  @override
  String get beforeTaskDue => 'Ennen tehtävän määräaikaa';

  @override
  String get afterTaskStarts => 'Tehtävän alkamisen jälkeen';

  @override
  String get afterTaskDue => 'Tehtävän määräajan jälkeen';

  @override
  String get relativeToTaskStart => 'Suhteessa tehtävän aloituspäivään';

  @override
  String get relativeToTaskDue => 'Suhteessa tehtävän määräpäivään';

  @override
  String get reminderTimeOfDay => 'Kellonaika';

  @override
  String get absoluteReminder => 'Tiettynä päivänä ja kellonaikana';

  @override
  String get reminderAmount => 'Määrä';

  @override
  String get reminderUnit => 'Yksikkö';

  @override
  String get reminderUnitSeconds => 'Sekunnit';

  @override
  String get reminderUnitMinutes => 'Minuutit';

  @override
  String get reminderUnitHours => 'Tunnit';

  @override
  String get reminderUnitDays => 'Päivät';

  @override
  String get reminderUnitWeeks => 'Viikot';

  @override
  String get reminderAtTaskStart => 'Tehtävän alkaessa';

  @override
  String get reminderAtTaskDue => 'Tehtävän määräaikana';

  @override
  String get unsupportedReminder =>
      'Tämä muistutustyyppi säilytetään, mutta sen aikaa ei voi muokata.';

  @override
  String get relatedRemindersTitle => 'Säilytetäänkö liittyvät muistutukset?';

  @override
  String relatedRemindersDescription(int count) {
    return 'Tällä päivämäärällä on $count liittyvää muistutusta. Säilytetäänkö ne nykyisessä päivämäärässä ja kellonajassa?';
  }

  @override
  String get discardRelatedReminders => 'Hylkää muistutukset';

  @override
  String get keepRelatedReminders => 'Säilytä muistutukset';

  @override
  String get addGuest => 'Lisää vieras';

  @override
  String get addGuestEmail => 'Lisää vieraan sähköpostiosoite';

  @override
  String get removeReminder => 'Poista muistutus';

  @override
  String get off => 'Ei käytössä';

  @override
  String get repeat => 'Toisto';

  @override
  String get repeatNone => 'Ei toistoa';

  @override
  String get noneValue => 'Ei mitään';

  @override
  String get repeatDaily => 'Päivittäin';

  @override
  String get repeatWeekly => 'Viikoittain';

  @override
  String get repeatMonthly => 'Kuukausittain';

  @override
  String get repeatYearly => 'Vuosittain';

  @override
  String get repeatEvery => 'Toistoväli';

  @override
  String get repeatOn => 'Toistopäivät';

  @override
  String get repeatEnd => 'Lopeta toisto';

  @override
  String get repeatNever => 'Ei koskaan';

  @override
  String get repeatUntil => 'Päivämääränä';

  @override
  String get repeatAfter => 'Toistokertojen jälkeen';

  @override
  String get repeatCount => 'Toistokerrat';

  @override
  String get repeatDayOfMonth => 'Kuukauden päivät';

  @override
  String get repeatMonths => 'Kuukaudet';

  @override
  String get repeatOrdinal => 'Viikonpäivän järjestys';

  @override
  String get repeatSpecificDays => 'Tietyt päivät';

  @override
  String get repeatFirst => 'Ensimmäinen';

  @override
  String get repeatSecond => 'Toinen';

  @override
  String get repeatThird => 'Kolmas';

  @override
  String get repeatFourth => 'Neljäs';

  @override
  String get repeatFifth => 'Viides';

  @override
  String get repeatSecondToLast => 'Toiseksi viimeinen';

  @override
  String get repeatLast => 'Viimeinen';

  @override
  String get repeatAnyDay => 'Päivä';

  @override
  String get repeatWeekday => 'Arkipäivä';

  @override
  String get repeatWeekendDay => 'Viikonlopun päivä';

  @override
  String repeatEveryDays(int count) {
    return 'Joka $count. päivä';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'Joka $count. viikko';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'Joka $count. kuukausi';
  }

  @override
  String repeatEveryYears(int count) {
    return 'Joka $count. vuosi';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'päivinä $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'kuukauden päivinä $days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'ensimmäisenä $days',
      'second': 'toisena $days',
      'third': 'kolmantena $days',
      'fourth': 'neljäntenä $days',
      'fifth': 'viidentenä $days',
      'secondToLast': 'toiseksi viimeisenä $days',
      'last': 'viimeisenä $days',
      'other': 'päivinä $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return '$months aikana';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count kertaa';
  }

  @override
  String repeatUntilSummary(String date) {
    return '$date asti';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Tämä toistosääntö käyttää asetuksia, joita tämä muokkain ei muuta.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Tätä toistoa ei voi käyttää palvelussa $provider.';
  }

  @override
  String get importance => 'Tärkeys';

  @override
  String get importanceLow => 'Pieni';

  @override
  String get importanceNormal => 'Normaali';

  @override
  String get importanceHigh => 'Suuri';

  @override
  String get categories => 'Luokat';

  @override
  String get scheduleSection => 'Aikataulu';

  @override
  String get dueGroup => 'Eräpäivä';

  @override
  String get startGroup => 'Alku';

  @override
  String get reminderGroup => 'Muistutus';

  @override
  String get organizationSection => 'Järjestely';

  @override
  String get actionsSection => 'Toiminnot';

  @override
  String get advancedSection => 'Lisäasetukset';

  @override
  String get addCategory => 'Lisää luokka';

  @override
  String get list => 'Luettelo';

  @override
  String get microsoftMoveUnsupported =>
      'Luettelosta toiseen siirtämistä ei tueta Microsoft To Do -tileillä tässä versiossa.';

  @override
  String get createSubtask => 'Luo alitehtävä';

  @override
  String get subtasks => 'Alitehtävät';

  @override
  String get duplicateTask => 'Monista tehtävä';

  @override
  String get taskDuplicated => 'Tehtävä monistettiin.';

  @override
  String taskDuplicateFailed(String error) {
    return 'Tehtävän monistaminen epäonnistui: $error';
  }

  @override
  String get hideSubtasks => 'Piilota alitehtävät';

  @override
  String get hideClosedSubtasks => 'Piilota suljetut alitehtävät';

  @override
  String get moveToTop => 'Siirrä ylimmäksi';

  @override
  String get deleteTask => 'Poista tehtävä';

  @override
  String get newSubtask => 'Uusi alitehtävä';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Poistetaanko \"$title\"?';
  }

  @override
  String get metadata => 'Metatiedot';

  @override
  String get id => 'Tunnus';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Päivitetty';

  @override
  String get parent => 'Ylätehtävä';

  @override
  String get position => 'Sijainti';

  @override
  String get webLink => 'Verkkolinkki';

  @override
  String get assignment => 'Määritys';

  @override
  String get localState => 'Paikallinen tila';

  @override
  String get pendingSync => 'Odottaa synkronointia';

  @override
  String get synced => 'Synkronoitu';

  @override
  String get account => 'Tili';

  @override
  String get sync => 'Synkronointi';

  @override
  String get forceFullResync => 'Pakota täydellinen uudelleensynkronointi';

  @override
  String get forceFullResyncDescription =>
      'Lataa kaikkien yhdistettyjen tilien tiedot kokonaan uudelleen. Käytä tätä vain synkronointiongelmien vianmääritykseen.';

  @override
  String get runInBackgroundWhenClosed =>
      'Jatka toimintaa, kun ikkuna suljetaan';

  @override
  String get showTrayIcon => 'Näytä ilmoitusalueen kuvake';

  @override
  String get startMinimizedToTray => 'Käynnistä pienennettynä ilmoitusalueelle';

  @override
  String get launchAtLogin => 'Käynnistä kirjautumisen yhteydessä';

  @override
  String get launchAtLoginDescription =>
      'Käynnistä BusyMax taustalla, jotta muistutukset toimivat kirjautumisen jälkeen.';

  @override
  String get launchAtLoginFailed =>
      'Kirjautumisen yhteydessä käynnistämistä ei voitu päivittää.';

  @override
  String get requiresTrayIcon => 'Vaatii ilmoitusalueen kuvakkeen.';

  @override
  String get syncComplete => 'Synkronointi valmis.';

  @override
  String syncFailed(String error) {
    return 'Synkronointi epäonnistui: $error';
  }

  @override
  String get notifySyncFailures => 'Ilmoita synkronointivirheistä';

  @override
  String get notifyConflicts => 'Ilmoita ristiriidoista';

  @override
  String get notifyDueToday => 'Ilmoita tänään erääntyvistä';

  @override
  String get eventReminders => 'Tapahtumamuistutukset';

  @override
  String get onState => 'Käytössä';

  @override
  String get taskReminders => 'Tehtävämuistutukset';

  @override
  String get notificationDetailLevel => 'Ilmoitusten yksityiskohtaisuus';

  @override
  String get notificationDetailPrivate => 'Yksityinen';

  @override
  String get notificationDetailNormal => 'Normaali';

  @override
  String get quietHours => 'Hiljainen aika';

  @override
  String get quietHoursDescription =>
      'Keskeytä ilmoitukset tällä ajanjaksolla.';

  @override
  String get quietHoursStart => 'Hiljaisen ajan alku';

  @override
  String get quietHoursEnd => 'Hiljaisen ajan loppu';

  @override
  String get notifications => 'Ilmoitukset';

  @override
  String get appearance => 'Ulkoasu';

  @override
  String get theme => 'Teema';

  @override
  String get themeSystem => 'Järjestelmä';

  @override
  String get settingsSystem => 'Järjestelmä';

  @override
  String get themeLight => 'Vaalea';

  @override
  String get themeDark => 'Tumma';

  @override
  String get themeFamily => 'Teemaperhe';

  @override
  String get themeFamilyYaru => 'Ubuntun oma (Yaru)';

  @override
  String get localization => 'Lokalisointi';

  @override
  String get currentLocale => 'Nykyinen alueasetus';

  @override
  String get privacy => 'Tietosuoja';

  @override
  String get redactTaskContentInDiagnostics =>
      'Peitä tehtävien sisältö diagnostiikassa';

  @override
  String get developerDiagnostics => 'Kehittäjän diagnostiikka';

  @override
  String get diagnostics => 'Diagnostiikka';

  @override
  String get apiInspectorDisabled => 'Näytä API-tarkastaja';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery-versio: $revision';
  }

  @override
  String get implementedMethods => 'Toteutetut metodit';

  @override
  String get supportsTasksScopes =>
      'Tukee tasks- ja tasks.readonly-käyttöoikeusalueita';

  @override
  String get requiresTasksScope => 'Vaatii tasks-käyttöoikeusalueen';

  @override
  String get blockedPendingOperations => 'Estetyt odottavat toiminnot';

  @override
  String get signInToInspectPendingOperations =>
      'Kirjaudu sisään tarkastellaksesi odottavia toimintoja.';

  @override
  String get noBlockedPendingOperations => 'Ei estettyjä odottavia toimintoja.';

  @override
  String get operationActions => 'Toiminnot';

  @override
  String pendingOpListId(String id) {
    return 'luettelo=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'tehtävä=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'yritykset=$count';
  }

  @override
  String get retry => 'Yritä uudelleen';

  @override
  String get discard => 'Hylkää';

  @override
  String get discardChangesAction => 'Hylkää';

  @override
  String get discardChanges => 'Hylätäänkö muutokset?';

  @override
  String get discardChangesConfirmation =>
      'Tämä hylkää tehtävän tallentamattomat muutokset.';

  @override
  String get retryCompleted => 'Uudelleenyritys suoritettu.';

  @override
  String get discardPendingOperation => 'Hylätäänkö odottava toiminto?';

  @override
  String get discardPendingOperationConfirmation =>
      'Tämä poistaa estetyn paikallisen toiminnon. Seuraava synkronointi päivittää tiedot Google Tasksista.';

  @override
  String get pendingOperationDiscarded => 'Odottava toiminto hylätty.';

  @override
  String get syncFailureNotificationTitle =>
      'BusyMaxin synkronointi epäonnistui';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Taustasynkronointi epäonnistui. $message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMaxin synkronointiristiriita';

  @override
  String conflictNotificationBody(String summary) {
    return 'Odottava paikallinen muutos estettiin. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Tänään erääntyvät tehtävät';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tehtävää erääntyy tänään.',
      one: 'Yksi tehtävä erääntyy tänään.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Tapahtumamuistutus';

  @override
  String get taskReminderNotificationTitle => 'Tehtävämuistutus';

  @override
  String get eventReminderNotificationBody => 'Tapahtuma alkaa pian.';

  @override
  String get taskReminderNotificationBody => 'Tehtävän määräaika lähestyy.';

  @override
  String get notificationOpenAction => 'Avaa';

  @override
  String get notificationSnoozeAction => 'Torkuta 10 minuuttia';

  @override
  String get notificationDismissAction => 'Sulje';

  @override
  String get notificationDetailsHidden =>
      'Yksityiskohdat on piilotettu tietosuoja-asetusten vuoksi.';

  @override
  String get previousMonth => 'Edellinen kuukausi';

  @override
  String get nextMonth => 'Seuraava kuukausi';

  @override
  String get openMonthView => 'Avaa kuukausinäkymä';

  @override
  String get previousYear => 'Edellinen vuosi';

  @override
  String get nextYear => 'Seuraava vuosi';

  @override
  String get openYearView => 'Avaa vuosinäkymä';

  @override
  String weekNumberTooltip(int number) {
    return 'Viikko $number';
  }

  @override
  String get resizeAllDayPanel => 'Muuta koko päivän paneelin kokoa';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kohdetta',
      one: '1 kohde',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Tämä kalenteri on kirjoitussuojattu.';

  @override
  String get selectTimeZone => 'Valitse aikavyöhyke';

  @override
  String get searchLocations => 'Hae sijainteja';

  @override
  String get noLocationsFound => 'Sijainteja ei löytynyt';

  @override
  String get requiredField => 'Tämä kenttä on pakollinen.';

  @override
  String get providerConnectionDescription =>
      'Yhdistä kalenterit ja tehtävät johonkin näistä palveluntarjoajista.';

  @override
  String get appleICloudProvider => 'Apple iCloud -kalenteri';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Nextcloud-tehtävät';

  @override
  String get addAppleICloudAccount => 'Lisää Apple iCloud -kalenteritili';

  @override
  String get addNextcloudAccount => 'Lisää Nextcloud-tili';

  @override
  String get waitingForAppleICloud => 'Yhdistetään Apple iCloudiin…';

  @override
  String get waitingForNextcloud => 'Odotetaan Nextcloud-valtuutusta…';

  @override
  String get connectAppleICloudTitle => 'Yhdistä Apple iCloud -kalenteri';

  @override
  String get appleAccountEmail => 'Apple-tilin sähköposti';

  @override
  String get appleAppSpecificPassword => 'Sovelluskohtainen salasana';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Luo sovelluskohtainen salasana, kun olet ottanut kaksivaiheisen todennuksen käyttöön Apple-tililläsi.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Apple-tilin salasanan vaihtaminen mitätöi sovelluskohtaiset salasanat.';

  @override
  String get connectNextcloudTitle => 'Yhdistä Nextcloud';

  @override
  String get nextcloudServerUrl => 'Nextcloud-palvelin tai CalDAV-osoite';

  @override
  String get nextcloudServerUrlHelp =>
      'Anna Nextcloud-palvelimesi URL-osoite tai liitä Nextcloudista kopioitu ensisijainen CalDAV-osoite.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax avaa selaimesi. Hyväksy käyttö siellä ja palaa sitten BusyMaxiin.';

  @override
  String get connectAccountAction => 'Yhdistä';

  @override
  String get cancelAccountConnection => 'Peruuta yhteys';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'Tili poistettiin paikallisesti, mutta Nextcloudin sovellussalasanaa ei voitu kumota.';

  @override
  String get davCachedOfflineNotice =>
      'Kalenteri- ja tehtävätiedot tallennetaan paikallisesti offline-käyttöä varten.';

  @override
  String get davReauthenticationRequired =>
      'Yhdistä tämä tili uudelleen jatkaaksesi synkronointia.';

  @override
  String get davTemporarilyUnavailable =>
      'Tämä tili ei ole tilapäisesti käytettävissä.';

  @override
  String get davPermissionChanged =>
      'Palvelimen käyttöoikeudet muuttuivat. Odottavat muokkaukset on keskeytetty.';

  @override
  String get davUnsupportedServer =>
      'Tätä palvelinta tai palveluntarjoajan profiilia ei tueta.';

  @override
  String get collectionSettings => 'Kalenterit ja tehtäväluettelot';

  @override
  String get calendarContent => 'Kalenteritapahtumat';

  @override
  String get taskContent => 'Tehtävät';

  @override
  String get readOnlySharedCollection => 'Vain luku';

  @override
  String get pendingLocally => 'Paikallisesti odottava';

  @override
  String get conflictBlocked => 'Ristiriidan estämä';

  @override
  String get authenticationBlocked =>
      'Estetty, kunnes yhteys muodostetaan uudelleen';

  @override
  String get operationFailed => 'Toiminto epäonnistui';

  @override
  String get keepServerVersion => 'Säilytä palvelinversio';

  @override
  String get reapplyLocalChange =>
      'Tarkista ja ota paikallinen muutos uudelleen käyttöön';

  @override
  String get duplicateLocalItem => 'Monista uudeksi kohteeksi';

  @override
  String get davConnectionState => 'Yhteyden tila';

  @override
  String get davConnected => 'Yhdistetty';

  @override
  String get davConnecting => 'Yhdistetään…';

  @override
  String get davSignedOut => 'Kirjautunut ulos';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Viimeisin onnistunut synkronointi: $time';
  }

  @override
  String get davNeverSynced => 'Ei vielä synkronoitu';

  @override
  String get refreshCollections => 'Päivitä kalenterit ja tehtäväluettelot';

  @override
  String nextcloudServerHost(String host) {
    return 'Palvelin: $host';
  }

  @override
  String get collectionSupportsEvents => 'Tapahtumakalenteri';

  @override
  String get collectionSupportsTasks => 'Tehtäväluettelo';

  @override
  String get collectionSupportsEventsAndTasks => 'Tapahtumat ja tehtävät';

  @override
  String get writableCollection => 'Muokattava';

  @override
  String get sharedCollection => 'Jaettu';

  @override
  String collectionLastSynced(String time) {
    return 'Viimeksi synkronoitu: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Synkronointiongelma: $code';
  }

  @override
  String get syncConflicts => 'Synkronointiristiriidat';

  @override
  String remoteChangedAt(String time) {
    return 'Palvelin muuttui: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Paikallinen muokkaus: $summary';
  }

  @override
  String get conflictResolutionFailed => 'Ristiriitaa ei voitu ratkaista.';

  @override
  String get recurringEventScope => 'Toistuvan tapahtuman laajuus';

  @override
  String get entireSeries => 'Koko sarja';

  @override
  String get singleOccurrence => 'Tämä tapahtuma';

  @override
  String get thisAndFollowingEvents => 'Tämä ja seuraavat tapahtumat';

  @override
  String get thisAndFutureUnavailable => 'Tämä palveluntarjoaja ei tue tätä.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'Tätä ja seuraavia tapahtumia ei voi siirtää turvallisesti. Valitse tämä tapahtuma tai koko sarja.';

  @override
  String get entireSeriesMoveUnavailable =>
      'Toistumissääntö ei ole saatavilla paikallisesti. Siirrä sen sijaan vain tämä tapahtuma.';

  @override
  String get copyEventAndDeleteOriginal =>
      'Kopioidaanko tapahtuma ja poistetaanko alkuperäinen?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax ei voi siirtää tätä tapahtumaa suoraan kalenterista $source kalenteriin $destination. Kopio luodaan ensin, ja alkuperäinen poistetaan vasta onnistuneen kopioinnin jälkeen. Tapahtuman tunnisteet muuttuvat; osallistujien vastaustilat voivat nollautua ja kutsuja tai peruutuksia voidaan lähettää; kokouslinkit, liitteet, muistutukset, palveluntarjoajakohtaiset kentät ja toistumisen poikkeukset eivät välttämättä siirry.';
  }

  @override
  String get copyAndDelete => 'Kopioi ja poista';

  @override
  String get chooseRecurringEventScope =>
      'Valitse, koskeeko tämä muutos koko sarjaa, vain tätä tapahtumaa vai tätä ja seuraavia tapahtumia.';

  @override
  String get taskDueBeforeStart => 'Määräaika ei saa olla ennen alkamisaikaa.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Aseta kellonaika sekä alkamiselle että määräajalle tai tee tehtävästä koko päivän tehtävä.';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Poistetaanko \"$title\"?';
  }

  @override
  String get setCustomCalendarName => 'Aseta mukautettu nimi';

  @override
  String get setAction => 'Aseta';

  @override
  String get removeFromMyCalendars => 'Poista omista kalentereistani';

  @override
  String get removeAction => 'Poista';

  @override
  String removeCalendarConfirmation(String title) {
    return 'Poistetaanko ”$title” Google Kalenterin luettelostasi? Jaettua kalenteria tai sen tapahtumia ei poisteta.';
  }

  @override
  String get calendarCannotRemove =>
      'Tätä kalenteria ei voi poistaa tai irrottaa tästä tilistä.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Odota tämän kalenterin odottavien muutosten synkronointia ennen poistamista tai irrottamista.';

  @override
  String get calendarSubscriptions => 'Kalenteritilaukset';

  @override
  String get calendarSubscriptionsDescription =>
      'Lisää vain luku -kalentereita, jotka päivittyvät suojatusta WebCal-URL-osoitteesta.';

  @override
  String get addCalendarSubscription => 'Lisää kalenteritilaus';

  @override
  String get subscriptionName => 'Paikallinen nimi';

  @override
  String get subscriptionUrl => 'Tilauksen URL';

  @override
  String get subscriptionUrlHelp =>
      'Anna HTTPS- tai webcal-URL. BusyMax säilyttää täydellisen URL-osoitteen suojatussa tallennustilassa.';

  @override
  String get subscriptionUrlInvalid =>
      'Anna kelvollinen HTTPS- tai webcal-URL ilman käyttäjätietoja tai fragmenttia.';

  @override
  String get subscriptionColor => 'Paikallinen väri';

  @override
  String get subscriptionColorHelp =>
      'Käytä kuusinumeroista väriä, kuten #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Anna kuusinumeroinen heksadesimaaliväri.';

  @override
  String get subscriptionRefreshMode => 'Päivitystiheys';

  @override
  String get subscriptionAutomatic => 'Automaattinen';

  @override
  String get subscriptionHourly => 'Tunneittain';

  @override
  String get subscriptionSixHours => 'Kuuden tunnin välein';

  @override
  String get subscriptionDaily => 'Päivittäin';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Lähde: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Anna kelvollinen URL esikatsellaksesi sen suojattua alkuperää.';

  @override
  String get subscriptionReadOnly => 'Vain luku -tilaus';

  @override
  String get subscriptionNeverRefreshed => 'Ei vielä päivitetty';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Viimeisin onnistunut päivitys: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Seuraava päivitys: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Ajan tasalla';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Päivitysongelma: $code';
  }

  @override
  String get refreshNow => 'Päivitä nyt';

  @override
  String get unsubscribe => 'Peruuta tilaus';

  @override
  String unsubscribeCalendarTitle(String name) {
    return 'Perutaanko tilaus kalenterista ”$name”?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Tämä poistaa paikallisen tilauksen ja sen välimuistissa olevat tapahtumat. Julkaistua kalenteria ei muuteta.';

  @override
  String get addSubscriptionAction => 'Lisää tilaus';

  @override
  String subscriptionOperationFailed(String error) {
    return 'Kalenteritilaus epäonnistui: $error';
  }

  @override
  String get subscriptions => 'Tilaukset';

  @override
  String get calendarImport => 'Kalenterin tuonti';

  @override
  String get calendarImportDescription =>
      'Valitse tiedosto, tarkista sen tapahtumat ja valitse sitten muokattava kalenteri, joka vastaanottaa ne.';

  @override
  String get importIcsFile => 'Tuo .ics-tiedosto';

  @override
  String get importIcsPreview => 'Tuo kalenteritapahtumat';

  @override
  String importEventsFound(int count) {
    return 'Tuotavat tapahtumajoukot: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Virheelliset tapahtumat: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Jätetty tarkoituksella pois: $fields';
  }

  @override
  String get noWritableCalendars =>
      'Muokattavaa kohdekalenteria ei ole saatavilla.';

  @override
  String get importDestinationCalendar => 'Kohdekalenteri';

  @override
  String get importIcsConfirm => 'Tuo tapahtumat';

  @override
  String get importIcsComplete => 'Tuonti valmis';

  @override
  String importQueued(int count) {
    return 'Tuotu tai jonossa: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Ohitetut kaksoiskappaleet: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Tukemattomat toistojoukot: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'Kalenteritiedostoa ei voitu tuoda: $error';
  }

  @override
  String get networkOffline => 'Ei verkkoyhteyttä';

  @override
  String get networkOfflineDescription =>
      'Muutokset synkronoidaan, kun yhteys palautuu.';

  @override
  String get networkOfflineTryAgain =>
      'Verkkoyhteyttä ei ole. Yhdistä internetiin ja yritä uudelleen.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'kuukauden päivinä $days';
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
    String _temp0 = intl.Intl.selectLogic(monthKey, {
      'jan': 'tammikuun',
      'feb': 'helmikuun',
      'mar': 'maaliskuun',
      'apr': 'huhtikuun',
      'may': 'toukokuun',
      'jun': 'kesäkuun',
      'jul': 'heinäkuun',
      'aug': 'elokuun',
      'sep': 'syyskuun',
      'oct': 'lokakuun',
      'nov': 'marraskuun',
      'dec': 'joulukuun',
      'other': '$month',
    });
    return '$_temp0';
  }

  @override
  String repeatYearlyMonthDayListPair(String first, String second) {
    return '$first ja $second';
  }

  @override
  String repeatYearlyMonthDayListStart(String first, String rest) {
    return '$first, $rest';
  }

  @override
  String repeatYearlyMonthListPair(String first, String second) {
    return '$first ja $second';
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
    return '$frequency $month $day. päivänä';
  }

  @override
  String repeatYearlyOnMonthDaysSummary(
    String frequency,
    String month,
    String days,
  ) {
    return '$frequency $month päivinä $days';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaySummary(
    String frequency,
    String months,
    String day,
  ) {
    return '$frequency $months $day. päivänä';
  }

  @override
  String repeatYearlyInMonthsOnMonthDaysSummary(
    String frequency,
    String months,
    String days,
  ) {
    return '$frequency $months päivinä $days';
  }

  @override
  String repeatYearlyOnOrdinalSummary(
    String frequency,
    String month,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'ensimmäisenä',
      'second': 'toisena',
      'third': 'kolmantena',
      'fourth': 'neljäntenä',
      'fifth': 'viidentenä',
      'secondToLast': 'toiseksi viimeisenä',
      'last': 'viimeisenä',
      'other': '',
    });
    return '$frequency $month $_temp0 $days';
  }

  @override
  String repeatYearlyInMonthsOnOrdinalSummary(
    String frequency,
    String months,
    String position,
    String days,
  ) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'ensimmäisenä',
      'second': 'toisena',
      'third': 'kolmantena',
      'fourth': 'neljäntenä',
      'fifth': 'viidentenä',
      'secondToLast': 'toiseksi viimeisenä',
      'last': 'viimeisenä',
      'other': '',
    });
    return '$frequency $months $_temp0 $days';
  }
}

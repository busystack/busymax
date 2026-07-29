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
      'Yhdistä Google- ja Microsoft-tilit kalenterien ja tehtävien synkronointia varten.';

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
      'Lisää kaikki haluamasi Google- ja Microsoft-tilit. BusyMax synkronoi kunkin tilin kalenterit, tapahtumat, tehtäväluettelot ja tehtävät.';

  @override
  String get onboardingPreferencesStepTitle => 'Valitse järjestelmäasetukset';

  @override
  String get onboardingPreferencesStepDescription =>
      'Määritä työpöytätoiminnot, muistutukset, ilmoitusten yksityiskohdat ja ulkoasu ennen aikataulun avaamista.';

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
  String get newEvent => 'Uusi tapahtuma';

  @override
  String get refreshCalendar => 'Päivitä kalenteri';

  @override
  String get openInProvider => 'Avaa palveluntarjoajassa';

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
      'Valitse asetuksissa näytettävät kohteet ja päivitä sitten.';

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
  String get trayAgendaLoading => 'Ladataan agendaa...';

  @override
  String get trayAgendaSignInRequired => 'Kirjaudu sisään nähdäksesi agendan.';

  @override
  String get trayAgendaNoSources =>
      'Ei näkyviä kalentereita tai tehtäväluetteloita.';

  @override
  String get trayAgendaOpenBusyMax => 'Avaa sovellus';

  @override
  String get trayAgendaRefresh => 'Päivitä';

  @override
  String get trayAgendaError => 'Agenda ei ole käytettävissä';

  @override
  String get compactAgendaTitle => 'Agenda';

  @override
  String get compactAgendaSubtitle => 'Tulossa';

  @override
  String get compactAgendaOverdue => 'Myöhässä';

  @override
  String get compactAgendaClear => 'Ei mitään juuri nyt';

  @override
  String get compactAgendaOpenBusyMax => 'Avaa BusyMax';

  @override
  String get compactAgendaHide => 'Piilota';

  @override
  String get compactAgendaNewTask => 'Uusi tehtävä';

  @override
  String get compactAgendaRetry => 'Yritä uudelleen';

  @override
  String get compactAgendaRefresh => 'Päivitä';

  @override
  String get compactAgendaAllDay => 'Koko päivä';

  @override
  String get compactAgendaDueToday => 'Erääntyy tänään';

  @override
  String get compactAgendaDueTomorrow => 'Erääntyy huomenna';

  @override
  String compactAgendaDueOn(String date) {
    return 'Erääntyy $date';
  }

  @override
  String get compactAgendaMoreOverdue => 'Lataa lisää myöhässä olevia tehtäviä';

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
  String get viewAgenda => 'Agenda';

  @override
  String get scheduleSettings => 'Aikataulu';

  @override
  String get scheduleDisplaySettings => 'Aikataulun näyttö';

  @override
  String get scheduleDisplayHoursDescription =>
      'Päivä- ja viikkonäkymät avautuvat näiden kellonaikojen välille. Aikaiset ja myöhäiset kohteet laajentavat aluetta tarvittaessa.';

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
  String get shortcutGroupCompactAgenda => 'Kompakti agenda';

  @override
  String get shortcutRefreshCompactAgendaDescription =>
      'Päivitä kompaktin agendan ikkuna';

  @override
  String get shortcutHideCompactAgendaDescription =>
      'Piilota kompaktin agendan ikkuna';

  @override
  String get aboutBusyMax => 'Tietoja BusyMaxista';

  @override
  String get aboutBusyMaxDescription => 'Tehtävät ja kalenteri';

  @override
  String get website => 'Verkkosivusto';

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
      'Tietosuoja- tai turvallisuushuoli';

  @override
  String get feedbackCategoryUsability => 'Käytettävyyshuoli';

  @override
  String get feedbackCategoryOther => 'Muu';

  @override
  String get feedbackSubject => 'Aihe';

  @override
  String get feedbackDetailedMessage => 'Yksityiskohtainen viesti';

  @override
  String get feedbackReplyEmail => 'Vastaussähköposti (valinnainen)';

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
      'Tämä poistaa välimuistissa olevat tehtävät, kalenterit, tapahtumat, muistutukset ja odottavat offline-muutokset tältä laitteelta. Synkronoimattomat muutokset menetetään. Mitään ei poisteta Googlesta tai Microsoftista.';

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
  String get newList => 'Uusi luettelo';

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
  String get builtInMicrosoftList => 'Sisäänrakennettu';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Microsoft To Do -sovelluksen sisäänrakennettuja luetteloita ei voi nimetä uudelleen tai poistaa.';

  @override
  String deleteListConfirmation(String title) {
    return 'Poistetaanko \"$title\" Google Tasksista?';
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
  String get moveToTop => 'Siirrä ylimmäksi';

  @override
  String get deleteTask => 'Poista tehtävä';

  @override
  String get newSubtask => 'Uusi alitehtävä';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Poistetaanko \"$title\" Google Tasksista?';
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
  String get manualFullSync => 'Manuaalinen täysi synkronointi';

  @override
  String get runInBackgroundWhenClosed =>
      'Jatka toimintaa, kun ikkuna suljetaan';

  @override
  String get showTrayIcon => 'Näytä ilmoitusalueen kuvake';

  @override
  String get startMinimizedToTray => 'Käynnistä pienennettynä ilmoitusalueelle';

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
  String get taskReminders => 'Tehtävämuistutukset';

  @override
  String get notificationDetailLevel => 'Ilmoitusten yksityiskohtaisuus';

  @override
  String get notificationDetailPrivate => 'Yksityinen';

  @override
  String get notificationDetailNormal => 'Normaali';

  @override
  String get quietHours => 'Hiljaiset tunnit';

  @override
  String get quietHoursDescription =>
      'Keskeytä ilmoitukset tällä ajanjaksolla.';

  @override
  String get quietHoursStart => 'Hiljaisten tuntien alku';

  @override
  String get quietHoursEnd => 'Hiljaisten tuntien loppu';

  @override
  String get notifications => 'Ilmoitukset';

  @override
  String get appearance => 'Ulkoasu';

  @override
  String get theme => 'Teema';

  @override
  String get themeSystem => 'Järjestelmä';

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
  String get operationActions => 'Toiminnon valinnat';

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
  String get discardChanges => 'Hylätäänkö muutokset?';

  @override
  String get discardChangesConfirmation =>
      'Tämä hylkää tehtävän tallentamattomat muutokset.';

  @override
  String get retryCompleted => 'Uudelleenyritys valmis.';

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
  String deleteCalendarConfirmation(String title) {
    return 'Poistetaanko \"$title\"?';
  }
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppLocalizationsEt extends AppLocalizations {
  AppLocalizationsEt([String locale = 'et']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Ühendage Google\'i ja Microsofti kontod kalendrite ja ülesannete sünkroonimiseks.';

  @override
  String get googlePermissionsConsentNotice =>
      'Valige Google\'i õiguste kuval nii kalendri kui ka ülesannete õigused.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Google Calendari ja Google Tasksi õigused on nõutavad. Proovige uuesti ja märkige mõlemad ruudud.';

  @override
  String get finishSetup => 'Lõpeta seadistamine';

  @override
  String get continueSetup => 'Jätka';

  @override
  String get onboardingSetupTitle => 'BusyMaxi seadistamine';

  @override
  String get onboardingAccountsStepTitle => 'Kontode ühendamine';

  @override
  String get onboardingAccountsStepDescription =>
      'Lisage kõik Google\'i ja Microsofti kontod, mida soovite kasutada. BusyMax sünkroonib iga konto kalendrid, sündmused, ülesandeloendid ja ülesanded.';

  @override
  String get onboardingPreferencesStepTitle => 'Süsteemiseadete valimine';

  @override
  String get onboardingPreferencesStepDescription =>
      'Enne ajakava avamist määrake töölauakäitumine, meeldetuletused, teavituste üksikasjalikkus ja välimus.';

  @override
  String get signInWithGoogle => 'Logi Google\'iga sisse';

  @override
  String get signInWithMicrosoft => 'Logi Microsoftiga sisse';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'See teenusepakkuja pole seadistatud.';

  @override
  String get waitingForGoogleSignIn => 'Google\'isse sisselogimise ootel...';

  @override
  String get waitingForMicrosoftSignIn => 'Microsofti sisselogimise ootel...';

  @override
  String get microsoftSignInNotConfigured =>
      'Microsofti sisselogimine pole seadistatud. Määrake MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Tühista';

  @override
  String get close => 'Sulge';

  @override
  String get exit => 'Välju';

  @override
  String get options => 'Valikud';

  @override
  String get hide => 'Peida';

  @override
  String get show => 'Kuva';

  @override
  String get export => 'Ekspordi';

  @override
  String get save => 'Salvesta';

  @override
  String get settings => 'Seaded';

  @override
  String get all => 'Kõik';

  @override
  String get calendarEvents => 'Sündmused';

  @override
  String get calendarTasks => 'Ülesanded';

  @override
  String get calendar => 'Kalender';

  @override
  String get calendars => 'Kalendrid';

  @override
  String get newEvent => 'Uus sündmus';

  @override
  String get refreshCalendar => 'Värskenda kalendrit';

  @override
  String get openInProvider => 'Ava teenuses';

  @override
  String get hideFromSchedule => 'Peida ajakavast';

  @override
  String get showInSchedule => 'Kuva ajakavas';

  @override
  String get noCalendarsSynced => 'Ühtegi kalendrit pole veel sünkroonitud.';

  @override
  String get allDay => 'Kogu päev';

  @override
  String moreItems(int count) {
    return '+$count veel';
  }

  @override
  String get noEventsOrTasks => 'Sündmusi ega ülesandeid pole';

  @override
  String get scheduleLoading => 'Ajakava laadimine...';

  @override
  String get scheduleUnavailable => 'Ajakava pole saadaval';

  @override
  String get scheduleNoSources =>
      'Nähtavaid kalendreid ega ülesandeloendeid pole';

  @override
  String get scheduleNoSourcesDescription =>
      'Valige seadetes, mida kuvada, ja seejärel värskendage.';

  @override
  String get scheduleSignInRequired => 'Ühendage konto';

  @override
  String get scheduleSignInDescription =>
      'Kalendrite ja ülesannete sünkroonimiseks logige sisse.';

  @override
  String get scheduleNoSearchResults =>
      'Sobivaid sündmusi ega ülesandeid ei leitud';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Proovige teistsugust otsingut või eemaldage praegused filtrid.';

  @override
  String get trayAgendaLoading => 'Päevakava laadimine...';

  @override
  String get trayAgendaSignInRequired => 'Päevakava kuvamiseks logige sisse.';

  @override
  String get trayAgendaNoSources =>
      'Nähtavaid kalendreid ega ülesandeloendeid pole.';

  @override
  String get trayAgendaOpenBusyMax => 'Ava rakendus';

  @override
  String get trayAgendaRefresh => 'Värskenda';

  @override
  String get trayAgendaError => 'Päevakava pole saadaval';

  @override
  String get compactAgendaTitle => 'Päevakava';

  @override
  String get compactAgendaSubtitle => 'Tulekul';

  @override
  String get compactAgendaOverdue => 'Tähtaja ületanud';

  @override
  String get compactAgendaClear => 'Praegu vaba';

  @override
  String get compactAgendaOpenBusyMax => 'Ava BusyMax';

  @override
  String get compactAgendaHide => 'Peida';

  @override
  String get compactAgendaNewTask => 'Uus ülesanne';

  @override
  String get compactAgendaRetry => 'Proovi uuesti';

  @override
  String get compactAgendaRefresh => 'Värskenda';

  @override
  String get compactAgendaAllDay => 'Kogu päev';

  @override
  String get compactAgendaDueToday => 'Tähtaeg täna';

  @override
  String get compactAgendaDueTomorrow => 'Tähtaeg homme';

  @override
  String compactAgendaDueOn(String date) {
    return 'Tähtaeg $date';
  }

  @override
  String get compactAgendaMoreOverdue =>
      'Laadi veel tähtaja ületanud ülesandeid';

  @override
  String get agendaLoadMoreOverdue => 'Laadi veel tähtaja ületanud ülesandeid';

  @override
  String get agendaLoadMoreNoDate => 'Laadi veel kuupäevata ülesandeid';

  @override
  String get viewDay => 'Päev';

  @override
  String get viewWeek => 'Nädal';

  @override
  String get viewMonth => 'Kuu';

  @override
  String get viewYear => 'Aasta';

  @override
  String get viewAgenda => 'Päevakava';

  @override
  String get scheduleSettings => 'Ajakava';

  @override
  String get scheduleDisplaySettings => 'Ajakava kuvamine';

  @override
  String get scheduleDisplayHoursDescription =>
      'Päeva- ja nädalavaade avanevad nende kellaaegade piires. Vajaduse korral laiendavad varasemad ja hilisemad kirjed vahemikku.';

  @override
  String get scheduleDayStartsAt => 'Päev algab';

  @override
  String get scheduleDayEndsAt => 'Päev lõpeb';

  @override
  String get sourceCalendar => 'Kalender';

  @override
  String get sourceTaskList => 'Ülesandeloend';

  @override
  String get createChoiceTitle => 'Loo';

  @override
  String get createEventAtTime => 'Sündmus';

  @override
  String get createTaskAtDate => 'Ülesanne';

  @override
  String get editEvent => 'Muuda sündmust';

  @override
  String get eventTitle => 'Sündmuse pealkiri';

  @override
  String get location => 'Asukoht';

  @override
  String get timeSlot => 'Ajavahemik';

  @override
  String get startDateTime => 'Alguskuupäev ja -kellaaeg';

  @override
  String get endDateTime => 'Lõppkuupäev ja -kellaaeg';

  @override
  String get doesNotRepeat => 'Ei kordu';

  @override
  String get defaultReminder => 'Vaikemeeldetuletus';

  @override
  String get guests => 'Külalised';

  @override
  String get noGuests => 'Külalisi pole';

  @override
  String get description => 'Kirjeldus';

  @override
  String get availabilityShowAs => 'Hõivatus / Kuva kui';

  @override
  String get busy => 'Hõivatud';

  @override
  String get visibility => 'Nähtavus';

  @override
  String get defaultVisibility => 'Vaikimisi nähtavus';

  @override
  String get conference => 'Konverents';

  @override
  String get noConference => 'Konverentsi pole';

  @override
  String get providerCalendar => 'Teenuse kalender';

  @override
  String get formatBoldShortLabel => 'R';

  @override
  String get formatBoldTooltip => 'Rasvane';

  @override
  String get formatItalicShortLabel => 'K';

  @override
  String get formatItalicTooltip => 'Kursiiv';

  @override
  String get formatUnderlineShortLabel => 'A';

  @override
  String get formatUnderlineTooltip => 'Allajoonitud';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutit varem',
      one: '1 minut varem',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'Algusajal';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours tundi varem',
      one: '1 tund varem',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days päeva varem',
      one: '1 päev varem',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Vaba';

  @override
  String get availabilityTentative => 'Esialgne';

  @override
  String get availabilityOutOfOffice => 'Kontorist väljas';

  @override
  String get availabilityWorkingElsewhere => 'Töötab mujal';

  @override
  String get visibilityDefault => 'Vaikimisi';

  @override
  String get visibilityPublic => 'Avalik';

  @override
  String get visibilityPrivate => 'Privaatne';

  @override
  String get visibilityConfidential => 'Konfidentsiaalne';

  @override
  String get sensitivityNormal => 'Tavaline';

  @override
  String get sensitivityPersonal => 'Isiklik';

  @override
  String get tasks => 'Ülesanded';

  @override
  String get allTasks => 'Kõik ülesanded';

  @override
  String tasksInList(String title) {
    return 'Loendi „$title” ülesanded';
  }

  @override
  String get taskLists => 'Ülesandeloendid';

  @override
  String get navigation => 'Navigeerimine';

  @override
  String get mainMenu => 'Peamenüü';

  @override
  String get keyboardShortcuts => 'Klaviatuuri otseteed';

  @override
  String get shortcutGroupGeneral => 'Üldine';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Kuva klaviatuuri otseteede loend';

  @override
  String get shortcutGroupNavigation => 'Navigeerimine';

  @override
  String get shortcutNextPeriod => 'Järgmine periood';

  @override
  String get shortcutNextPeriodDescription =>
      'Nädalavaates järgmine nädal, kuuvaates järgmine kuu jne';

  @override
  String get shortcutPreviousPeriod => 'Eelmine periood';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Nädalavaates eelmine nädal, kuuvaates eelmine kuu jne';

  @override
  String get shortcutJumpToToday => 'Mine tänasele kuupäevale';

  @override
  String get shortcutGroupView => 'Vaade';

  @override
  String get shortcutDayView => 'Päevavaade';

  @override
  String get shortcutWeekView => 'Nädalavaade';

  @override
  String get shortcutMonthView => 'Kuuvaade';

  @override
  String get shortcutYearView => 'Aastavaade';

  @override
  String get shortcutAgendaView => 'Päevakavavaade';

  @override
  String get shortcutGroupCreateAndEdit => 'Loomine ja muutmine';

  @override
  String get shortcutSaveItem => 'Salvesta sündmus või ülesanne';

  @override
  String get shortcutDeleteItem => 'Kustuta sündmus või ülesanne';

  @override
  String get shortcutGroupTaskEditing => 'Ülesande muutmine';

  @override
  String get shortcutCancelEditing => 'Tühista muutmine';

  @override
  String get shortcutCancelEditingDescription =>
      'Sulge ülesande muutmine või ülesande üksikasjad';

  @override
  String get shortcutGroupCompactAgenda => 'Kompaktne päevakava';

  @override
  String get shortcutRefreshCompactAgendaDescription =>
      'Värskenda kompaktse päevakava akent';

  @override
  String get shortcutHideCompactAgendaDescription =>
      'Peida kompaktse päevakava aken';

  @override
  String get aboutBusyMax => 'Teave BusyMaxi kohta';

  @override
  String get aboutBusyMaxDescription => 'Kalender ja ülesanded';

  @override
  String get license => 'Litsents';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Veebisait';

  @override
  String get sourceCode => 'Lähtekood';

  @override
  String get reportAnIssue => 'Teata probleemist';

  @override
  String get sendFeedback => 'Saada tagasisidet';

  @override
  String get feedbackSubmit => 'Saada';

  @override
  String get feedbackCategory => 'Kategooria';

  @override
  String get feedbackSelectCategory => 'Valige kategooria';

  @override
  String get feedbackCategoryProblem => 'Probleem või viga';

  @override
  String get feedbackCategoryFeature => 'Funktsioonisoov';

  @override
  String get feedbackCategoryPrivacySecurity => 'Privaatsus- või turbeprobleem';

  @override
  String get feedbackCategoryUsability => 'Kasutatavusprobleem';

  @override
  String get feedbackCategoryOther => 'Muu';

  @override
  String get feedbackSubject => 'Teema';

  @override
  String get feedbackDetailedMessage => 'Üksikasjalik sõnum';

  @override
  String get feedbackReplyEmail => 'Vastamise e-posti aadress (valikuline)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Lisa tehnilised üksikasjad';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Lisatakse ainult teie Linuxi operatsioonisüsteemi versioon ning rakenduse keel ja piirkonnaseaded. Logisid, kontoandmeid, failinimesid ega muid diagnostikaandmeid ei lisata.';

  @override
  String get feedbackCategoryRequired => 'Valige kategooria.';

  @override
  String get feedbackSubjectLengthError =>
      'Teema peab olema 3–120 tähemärki pikk.';

  @override
  String get feedbackMessageLengthError =>
      'Sõnum peab olema 10–5000 tähemärki pikk.';

  @override
  String get feedbackInvalidEmail => 'Sisestage kehtiv e-posti aadress.';

  @override
  String get feedbackConnectionError =>
      'BusyStackiga ei saanud ühendust luua. Kontrollige ühendust ja proovige uuesti.';

  @override
  String get feedbackTimeoutError =>
      'Päring aegus. Teie tagasisidet ei kustutatud; proovige uuesti.';

  @override
  String get feedbackRateLimitedError =>
      'Sellest võrgust on saadetud liiga palju tagasisidet. Oodake ja proovige uuesti.';

  @override
  String get feedbackRejectedError =>
      'Server lükkas saatmise tagasi. Kontrollige välju ja proovige uuesti.';

  @override
  String get feedbackServerError =>
      'BusyStack ei saa praegu teie tagasisidet vastu võtta. Teie tagasisidet ei kustutatud; proovige uuesti.';

  @override
  String feedbackSuccess(String id) {
    return 'Tagasiside saadetud. Viide: $id';
  }

  @override
  String get toggleSidebar => 'Kuva või peida külgriba';

  @override
  String get showSidebar => 'Kuva külgpaneel';

  @override
  String get hideSidebar => 'Peida külgpaneel';

  @override
  String get accounts => 'Kontod';

  @override
  String get currentAccount => 'Praegune konto';

  @override
  String get switchAccount => 'Vaheta kontot';

  @override
  String get addGoogleAccount => 'Lisa Google\'i konto';

  @override
  String get addMicrosoftAccount => 'Lisa Microsofti konto';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Sisse logitud';

  @override
  String get removeAccount => 'Eemalda konto…';

  @override
  String get removingAccount => 'Konto eemaldamine…';

  @override
  String get removeAccountDescription =>
      'Lõpeta sünkroonimine ja eemalda selle konto andmed seadmest.';

  @override
  String removeAccountTitle(String account) {
    return 'Kas eemaldada $account BusyMaxist?';
  }

  @override
  String get removeAccountConfirmation =>
      'See kustutab seadmest vahemällu salvestatud ülesanded, kalendrid, sündmused, meeldetuletused ja sünkroonimist ootavad võrguühenduseta muudatused. Sünkroonimata muudatused lähevad kaotsi. Google\'ist ega Microsoftist midagi ei kustutata.';

  @override
  String get revokeGoogleAccess =>
      'Tühista ka BusyMaxi juurdepääs sellele Google\'i kontole';

  @override
  String get revokeGoogleAccessDescription =>
      'Enne uuesti ühendamist peate juurdepääsu uuesti andma.';

  @override
  String get removeAccountAction => 'Eemalda konto';

  @override
  String get removeAccountFailed =>
      'Konto eemaldamist ei saanud lõpetada. Proovige uuesti.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'Konto eemaldati sellest seadmest, kuid BusyMaxi juurdepääsu teie Google\'i kontole ei saanud tühistada. Saate selle oma Google\'i kontol käsitsi tühistada.';

  @override
  String get newList => 'Uus loend';

  @override
  String get signInToViewTaskLists =>
      'Ülesandeloendite vaatamiseks logige sisse.';

  @override
  String get noTaskListsSynced =>
      'Ühtegi ülesandeloendit pole veel sünkroonitud.';

  @override
  String get listActions => 'Loendi toimingud';

  @override
  String get rename => 'Nimeta ümber';

  @override
  String get delete => 'Kustuta';

  @override
  String get renameList => 'Nimeta loend ümber';

  @override
  String get deleteList => 'Kustuta loend';

  @override
  String get builtInMicrosoftList => 'Sisseehitatud';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Microsoft To Do sisseehitatud loendeid ei saa ümber nimetada ega kustutada.';

  @override
  String deleteListConfirmation(String title) {
    return 'Kas kustutada „$title” Google Tasksist?';
  }

  @override
  String get deleteEvent => 'Kustuta sündmus';

  @override
  String get title => 'Pealkiri';

  @override
  String get create => 'Loo';

  @override
  String get newTask => 'Uus ülesanne';

  @override
  String get clearCompleted => 'Eemalda lõpetatud ülesanded';

  @override
  String get refreshList => 'Värskenda loendit';

  @override
  String get refreshAll => 'Värskenda kõiki';

  @override
  String get listRefreshed => 'Loend on värskendatud.';

  @override
  String get allTasksRefreshed => 'Kõik kontod on värskendatud.';

  @override
  String exportedFile(String path) {
    return 'Eksporditud asukohta $path';
  }

  @override
  String exportFailed(String error) {
    return 'Eksportimine nurjus: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Värskendamine nurjus: $error';
  }

  @override
  String get selectOrCreateTaskList =>
      'Alustamiseks valige või looge ülesandeloend.';

  @override
  String get signInToViewTasks => 'Ülesannete vaatamiseks logige sisse.';

  @override
  String get noTasks => 'Ülesandeid pole.';

  @override
  String get noTasksYet => 'Ülesandeid veel pole';

  @override
  String get noTasksYetMessage =>
      'Alustamiseks looge ülesanne või värskendage kontosid.';

  @override
  String get noTasksInList => 'Selles loendis pole ülesandeid.';

  @override
  String get overdue => 'Tähtaja ületanud';

  @override
  String get today => 'Täna';

  @override
  String get tomorrow => 'Homme';

  @override
  String get upcoming => 'Tulekul';

  @override
  String get noDate => 'Kuupäevata';

  @override
  String get completed => 'Lõpetatud';

  @override
  String duePrefix(String date) {
    return 'Tähtaeg $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date · $time';
  }

  @override
  String get taskDetails => 'Ülesande üksikasjad';

  @override
  String get editTask => 'Muuda ülesannet';

  @override
  String get noTaskSelected => 'Ülesannet pole valitud.';

  @override
  String get noTaskSelectedHelper =>
      'Üksikasjade vaatamiseks ja muutmiseks valige ülesanne.';

  @override
  String get taskUnavailable => 'Ülesanne pole saadaval.';

  @override
  String get signInToEditTasks => 'Ülesannete muutmiseks logige sisse.';

  @override
  String get refreshTask => 'Värskenda ülesannet';

  @override
  String get primarySection => 'Põhiteave';

  @override
  String get statusSection => 'Olek';

  @override
  String get openStatus => 'Pooleli';

  @override
  String get doneStatus => 'Valmis';

  @override
  String get notes => 'Märkmed';

  @override
  String get dueDate => 'Tähtaeg';

  @override
  String get clearDueDate => 'Eemalda tähtaeg';

  @override
  String get dueTime => 'Tähtaja kellaaeg';

  @override
  String get startDate => 'Alguskuupäev';

  @override
  String get startTime => 'Alguskellaaeg';

  @override
  String get endDate => 'Lõppkuupäev';

  @override
  String get endTime => 'Lõppkellaaeg';

  @override
  String get reminderDate => 'Meeldetuletuse kuupäev';

  @override
  String get reminderTime => 'Meeldetuletuse kellaaeg';

  @override
  String get reminder => 'Meeldetuletus';

  @override
  String get addReminder => 'Lisa meeldetuletus';

  @override
  String get addGuest => 'Lisa külaline';

  @override
  String get addGuestEmail => 'Lisa külalise e-posti aadress';

  @override
  String get removeReminder => 'Eemalda meeldetuletus';

  @override
  String get off => 'Väljas';

  @override
  String get repeat => 'Kordus';

  @override
  String get repeatNone => 'Ei kordu';

  @override
  String get noneValue => 'Puudub';

  @override
  String get repeatDaily => 'Iga päev';

  @override
  String get repeatWeekly => 'Iga nädal';

  @override
  String get repeatMonthly => 'Iga kuu';

  @override
  String get repeatYearly => 'Iga aasta';

  @override
  String get importance => 'Tähtsus';

  @override
  String get importanceLow => 'Madal';

  @override
  String get importanceNormal => 'Tavaline';

  @override
  String get importanceHigh => 'Kõrge';

  @override
  String get categories => 'Kategooriad';

  @override
  String get scheduleSection => 'Ajakava';

  @override
  String get dueGroup => 'Tähtaeg';

  @override
  String get startGroup => 'Algus';

  @override
  String get reminderGroup => 'Meeldetuletus';

  @override
  String get organizationSection => 'Korraldus';

  @override
  String get actionsSection => 'Toimingud';

  @override
  String get advancedSection => 'Täpsemad seaded';

  @override
  String get addCategory => 'Lisa kategooria';

  @override
  String get list => 'Loend';

  @override
  String get microsoftMoveUnsupported =>
      'Selles versioonis ei toetata Microsoft To Do kontodel ülesannete teisaldamist loendite vahel.';

  @override
  String get createSubtask => 'Loo alamülesanne';

  @override
  String get moveToTop => 'Teisalda kõige üles';

  @override
  String get deleteTask => 'Kustuta ülesanne';

  @override
  String get newSubtask => 'Uus alamülesanne';

  @override
  String deleteTaskConfirmation(String title) {
    return 'Kas kustutada „$title” Google Tasksist?';
  }

  @override
  String get metadata => 'Metaandmed';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Uuendatud';

  @override
  String get parent => 'Ülemülesanne';

  @override
  String get position => 'Asukoht';

  @override
  String get webLink => 'Veebilink';

  @override
  String get assignment => 'Määramine';

  @override
  String get localState => 'Kohalik olek';

  @override
  String get pendingSync => 'Sünkroonimise ootel';

  @override
  String get synced => 'Sünkroonitud';

  @override
  String get account => 'Konto';

  @override
  String get sync => 'Sünkroonimine';

  @override
  String get manualFullSync => 'Käsitsi täielik sünkroonimine';

  @override
  String get runInBackgroundWhenClosed =>
      'Jätka töötamist, kui aken on suletud';

  @override
  String get showTrayIcon => 'Kuva süsteemisalve ikoon';

  @override
  String get startMinimizedToTray => 'Käivita minimeerituna süsteemisalves';

  @override
  String get requiresTrayIcon => 'Nõuab süsteemisalve ikooni.';

  @override
  String get syncComplete => 'Sünkroonimine on lõpetatud.';

  @override
  String syncFailed(String error) {
    return 'Sünkroonimine nurjus: $error';
  }

  @override
  String get notifySyncFailures => 'Teavitused sünkroonimise nurjumisel';

  @override
  String get notifyConflicts => 'Teavitused konfliktide korral';

  @override
  String get notifyDueToday => 'Täna tähtuvate ülesannete teavitused';

  @override
  String get eventReminders => 'Sündmuste meeldetuletused';

  @override
  String get taskReminders => 'Ülesannete meeldetuletused';

  @override
  String get notificationDetailLevel => 'Teavituste üksikasjalikkus';

  @override
  String get notificationDetailPrivate => 'Privaatne';

  @override
  String get notificationDetailNormal => 'Tavaline';

  @override
  String get quietHours => 'Vaikne aeg';

  @override
  String get quietHoursDescription => 'Peata teavitused selleks ajavahemikuks.';

  @override
  String get quietHoursStart => 'Vaikse aja algus';

  @override
  String get quietHoursEnd => 'Vaikse aja lõpp';

  @override
  String get notifications => 'Teavitused';

  @override
  String get appearance => 'Välimus';

  @override
  String get theme => 'Kujundus';

  @override
  String get themeSystem => 'Süsteem';

  @override
  String get themeLight => 'Hele';

  @override
  String get themeDark => 'Tume';

  @override
  String get themeFamily => 'Kujunduse perekond';

  @override
  String get themeFamilyYaru => 'Ubuntu algupärane kujundus (Yaru)';

  @override
  String get localization => 'Keel ja piirkond';

  @override
  String get currentLocale => 'Praegune lokaat';

  @override
  String get privacy => 'Privaatsus';

  @override
  String get redactTaskContentInDiagnostics =>
      'Peida diagnostikas ülesannete sisu';

  @override
  String get developerDiagnostics => 'Arendaja diagnostika';

  @override
  String get diagnostics => 'Diagnostika';

  @override
  String get apiInspectorDisabled => 'Kuva API-inspektor';

  @override
  String get googleTasksApi => 'Google Tasks API';

  @override
  String discoveryRevision(String revision) {
    return 'Discovery versioon: $revision';
  }

  @override
  String get implementedMethods => 'Rakendatud meetodid';

  @override
  String get supportsTasksScopes =>
      'Toetab õiguse ulatusi tasks ja tasks.readonly';

  @override
  String get requiresTasksScope => 'Nõuab õiguse ulatust tasks';

  @override
  String get blockedPendingOperations => 'Blokeeritud ootel toimingud';

  @override
  String get signInToInspectPendingOperations =>
      'Ootel toimingute kontrollimiseks logige sisse.';

  @override
  String get noBlockedPendingOperations => 'Blokeeritud ootel toiminguid pole.';

  @override
  String get operationActions => 'Toimingu tegevused';

  @override
  String pendingOpListId(String id) {
    return 'loend=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'ülesanne=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'katseid=$count';
  }

  @override
  String get retry => 'Proovi uuesti';

  @override
  String get discard => 'Hülga';

  @override
  String get discardChangesAction => 'Hülga';

  @override
  String get discardChanges => 'Kas hüljata muudatused?';

  @override
  String get discardChangesConfirmation =>
      'See hülgab ülesande salvestamata muudatused.';

  @override
  String get retryCompleted => 'Uuesti proovimine lõpetatud.';

  @override
  String get discardPendingOperation => 'Kas hüljata ootel toiming?';

  @override
  String get discardPendingOperationConfirmation =>
      'See eemaldab blokeeritud kohaliku toimingu. Järgmine sünkroonimine laadib andmed Google Tasksist uuesti.';

  @override
  String get pendingOperationDiscarded => 'Ootel toiming hüljatud.';

  @override
  String get syncFailureNotificationTitle => 'BusyMaxi sünkroonimine nurjus';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Taustal sünkroonimine nurjus. $message';
  }

  @override
  String get conflictNotificationTitle => 'BusyMaxi sünkroonimiskonflikt';

  @override
  String conflictNotificationBody(String summary) {
    return 'Ootel kohalik muudatus blokeeriti. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Täna tähtuvad ülesanded';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ülesannet tähtub täna.',
      one: 'Üks ülesanne tähtub täna.',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderNotificationTitle => 'Sündmuse meeldetuletus';

  @override
  String get taskReminderNotificationTitle => 'Ülesande meeldetuletus';

  @override
  String get eventReminderNotificationBody => 'Sündmus algab varsti.';

  @override
  String get taskReminderNotificationBody => 'Ülesande tähtaeg on varsti.';

  @override
  String get notificationOpenAction => 'Ava';

  @override
  String get notificationDetailsHidden =>
      'Üksikasjad on privaatsusseadete tõttu peidetud.';

  @override
  String get previousMonth => 'Eelmine kuu';

  @override
  String get nextMonth => 'Järgmine kuu';

  @override
  String get openMonthView => 'Ava kuuvaade';

  @override
  String get previousYear => 'Eelmine aasta';

  @override
  String get nextYear => 'Järgmine aasta';

  @override
  String get openYearView => 'Ava aastavaade';

  @override
  String weekNumberTooltip(int number) {
    return 'Nädal $number';
  }

  @override
  String get resizeAllDayPanel => 'Muuda kogu päeva paneeli suurust';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kirjet',
      one: '1 kirje',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'See kalender on kirjutuskaitstud.';

  @override
  String get selectTimeZone => 'Valige ajavöönd';

  @override
  String get searchLocations => 'Otsi asukohti';

  @override
  String get noLocationsFound => 'Asukohti ei leitud';

  @override
  String deleteCalendarConfirmation(String title) {
    return 'Kas kustutada „$title”?';
  }
}

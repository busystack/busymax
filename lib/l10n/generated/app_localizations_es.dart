// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'BusyMax';

  @override
  String get connectGoogleAccount =>
      'Conecta cuentas de Google y Microsoft para sincronizar calendarios y tareas.';

  @override
  String get googlePermissionsConsentNotice =>
      'En la pantalla de permisos de Google, selecciona los permisos de Calendario y Tareas.';

  @override
  String get googlePermissionsRequiredRetry =>
      'Los permisos de Google Calendar y Google Tasks son obligatorios. Inténtalo de nuevo y selecciona ambas casillas.';

  @override
  String get finishSetup => 'Finalizar configuración';

  @override
  String get continueSetup => 'Continuar';

  @override
  String get onboardingSetupTitle => 'Configurar BusyMax';

  @override
  String get onboardingAccountsStepTitle => 'Conectar cuentas';

  @override
  String get onboardingAccountsStepDescription =>
      'Añade todas las cuentas de Google y Microsoft que quieras usar. BusyMax sincroniza calendarios, eventos, listas de tareas y tareas de cada cuenta.';

  @override
  String get onboardingPreferencesStepTitle => 'Elegir ajustes del sistema';

  @override
  String get onboardingPreferencesStepDescription =>
      'Configura el comportamiento de escritorio, recordatorios, detalle de notificaciones y apariencia antes de abrir tu agenda.';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signInWithMicrosoft => 'Iniciar sesión con Microsoft';

  @override
  String get googleTasksProvider => 'Google Tasks';

  @override
  String get microsoftTodoProvider => 'Microsoft To Do';

  @override
  String get providerNotConfigured => 'Este proveedor no está configurado.';

  @override
  String get waitingForGoogleSignIn =>
      'Esperando el inicio de sesión de Google...';

  @override
  String get waitingForMicrosoftSignIn =>
      'Esperando el inicio de sesión de Microsoft...';

  @override
  String get microsoftSignInNotConfigured =>
      'El inicio de sesión de Microsoft no está configurado. Define MICROSOFT_OAUTH_CLIENT_ID.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get exit => 'Salir';

  @override
  String get options => 'Opciones';

  @override
  String get hide => 'Ocultar';

  @override
  String get show => 'Mostrar';

  @override
  String get export => 'Exportar';

  @override
  String get save => 'Guardar';

  @override
  String get settings => 'Configuración';

  @override
  String get all => 'Todo';

  @override
  String get calendarEvents => 'Eventos';

  @override
  String get calendarTasks => 'Tareas';

  @override
  String get calendar => 'Calendario';

  @override
  String get calendars => 'Calendarios';

  @override
  String get newEvent => 'Nuevo evento';

  @override
  String get refreshCalendar => 'Actualizar calendario';

  @override
  String get openInProvider => 'Abrir en proveedor';

  @override
  String get hideFromSchedule => 'Ocultar de la agenda';

  @override
  String get showInSchedule => 'Mostrar en la agenda';

  @override
  String get noCalendarsSynced => 'Aún no hay calendarios sincronizados.';

  @override
  String get allDay => 'Todo el día';

  @override
  String moreItems(int count) {
    return '+$count más';
  }

  @override
  String get noEventsOrTasks => 'No hay eventos ni tareas';

  @override
  String get scheduleLoading => 'Cargando la agenda...';

  @override
  String get scheduleUnavailable => 'Agenda no disponible';

  @override
  String get scheduleNoSources =>
      'No hay calendarios ni listas de tareas visibles';

  @override
  String get scheduleNoSourcesDescription =>
      'Elige qué mostrar en Ajustes y, después, actualiza.';

  @override
  String get scheduleSignInRequired => 'Conectar una cuenta';

  @override
  String get scheduleSignInDescription =>
      'Inicia sesión para sincronizar calendarios y tareas.';

  @override
  String get scheduleNoSearchResults => 'No hay eventos ni tareas coincidentes';

  @override
  String get scheduleNoSearchResultsDescription =>
      'Prueba con otra búsqueda o borra los filtros actuales.';

  @override
  String get trayAgendaLoading => 'Cargando agenda...';

  @override
  String get trayAgendaSignInRequired =>
      'Inicia sesión para mostrar la agenda.';

  @override
  String get trayAgendaNoSources =>
      'No hay calendarios ni listas de tareas visibles.';

  @override
  String get trayAgendaOpenBusyMax => 'Abrir app';

  @override
  String get trayAgendaRefresh => 'Actualizar';

  @override
  String get trayAgendaError => 'Agenda no disponible';

  @override
  String get compactAgendaTitle => 'Agenda';

  @override
  String get compactAgendaSubtitle => 'Próximamente';

  @override
  String get compactAgendaOverdue => 'Vencidas';

  @override
  String get compactAgendaClear => 'Libre por ahora';

  @override
  String get compactAgendaOpenBusyMax => 'Abrir BusyMax';

  @override
  String get compactAgendaHide => 'Ocultar';

  @override
  String get compactAgendaNewTask => 'Nueva tarea';

  @override
  String get compactAgendaRetry => 'Reintentar';

  @override
  String get compactAgendaRefresh => 'Actualizar';

  @override
  String get compactAgendaAllDay => 'Todo el día';

  @override
  String get compactAgendaDueToday => 'Vence hoy';

  @override
  String get compactAgendaDueTomorrow => 'Vence mañana';

  @override
  String compactAgendaDueOn(String date) {
    return 'Vence $date';
  }

  @override
  String get compactAgendaMoreOverdue => 'Cargar más tareas vencidas';

  @override
  String get agendaLoadMoreOverdue => 'Cargar más tareas vencidas';

  @override
  String get agendaLoadMoreNoDate => 'Cargar más tareas sin fecha';

  @override
  String get viewDay => 'Día';

  @override
  String get viewWeek => 'Semana';

  @override
  String get viewMonth => 'Mes';

  @override
  String get viewYear => 'Año';

  @override
  String get viewAgenda => 'Agenda';

  @override
  String get scheduleSettings => 'Agenda';

  @override
  String get scheduleDisplaySettings => 'Visualización de agenda';

  @override
  String get scheduleDisplayHoursDescription =>
      'Las vistas Día y Semana se abren dentro de este horario. Los elementos tempranos y tardíos amplían el intervalo si hace falta.';

  @override
  String get scheduleDayStartsAt => 'El día empieza a las';

  @override
  String get scheduleDayEndsAt => 'El día termina a las';

  @override
  String get sourceCalendar => 'Calendario';

  @override
  String get sourceTaskList => 'Lista de tareas';

  @override
  String get createChoiceTitle => 'Crear';

  @override
  String get createEventAtTime => 'Evento';

  @override
  String get createTaskAtDate => 'Tarea';

  @override
  String get editEvent => 'Editar evento';

  @override
  String get eventTitle => 'Título del evento';

  @override
  String get location => 'Ubicación';

  @override
  String get timeSlot => 'Franja horaria';

  @override
  String get timeMode => 'Hora';

  @override
  String get timeModeDescription => 'Usa solo fechas o define horas concretas.';

  @override
  String get startDateTime => 'Fecha/hora de inicio';

  @override
  String get endDateTime => 'Fecha/hora de fin';

  @override
  String get doesNotRepeat => 'No se repite';

  @override
  String get defaultReminder => 'Recordatorio predeterminado';

  @override
  String get guests => 'Invitados';

  @override
  String get noGuests => 'Sin invitados';

  @override
  String get description => 'Descripción';

  @override
  String get availabilityShowAs => 'Disponibilidad / Mostrar como';

  @override
  String get busy => 'Ocupado';

  @override
  String get visibility => 'Visibilidad';

  @override
  String get defaultVisibility => 'Visibilidad predeterminada';

  @override
  String get conference => 'Conferencia';

  @override
  String get noConference => 'Sin conferencia';

  @override
  String get providerCalendar => 'Calendario del proveedor';

  @override
  String get formatBoldShortLabel => 'N';

  @override
  String get formatBoldTooltip => 'Negrita';

  @override
  String get formatItalicShortLabel => 'C';

  @override
  String get formatItalicTooltip => 'Cursiva';

  @override
  String get formatUnderlineShortLabel => 'S';

  @override
  String get formatUnderlineTooltip => 'Subrayado';

  @override
  String reminderMinutesBefore(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos antes',
      one: '1 minuto antes',
    );
    return '$_temp0';
  }

  @override
  String get reminderAtStart => 'A la hora de inicio';

  @override
  String reminderHoursBefore(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas antes',
      one: '1 hora antes',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días antes',
      one: '1 día antes',
    );
    return '$_temp0';
  }

  @override
  String get availabilityFree => 'Libre';

  @override
  String get availabilityTentative => 'Provisional';

  @override
  String get availabilityOutOfOffice => 'Fuera de la oficina';

  @override
  String get availabilityWorkingElsewhere => 'Trabajando en otro lugar';

  @override
  String get visibilityDefault => 'Predeterminada';

  @override
  String get visibilityPublic => 'Pública';

  @override
  String get visibilityPrivate => 'Privada';

  @override
  String get visibilityConfidential => 'Confidencial';

  @override
  String get sensitivityNormal => 'Normal';

  @override
  String get sensitivityPersonal => 'Personal';

  @override
  String get tasks => 'Tareas';

  @override
  String get allTasks => 'Todas las tareas';

  @override
  String tasksInList(String title) {
    return 'Tareas en $title';
  }

  @override
  String get taskLists => 'Listas de tareas';

  @override
  String get navigation => 'Navegación';

  @override
  String get mainMenu => 'Menú principal';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get shortcutGroupGeneral => 'General';

  @override
  String get shortcutKeyboardShortcutsDescription =>
      'Mostrar esta referencia de atajos';

  @override
  String get shortcutGroupNavigation => 'Navegación';

  @override
  String get shortcutNextPeriod => 'Periodo siguiente';

  @override
  String get shortcutNextPeriodDescription =>
      'Semana siguiente en la vista semanal, mes siguiente en la vista mensual, etc.';

  @override
  String get shortcutPreviousPeriod => 'Periodo anterior';

  @override
  String get shortcutPreviousPeriodDescription =>
      'Semana anterior en la vista semanal, mes anterior en la vista mensual, etc.';

  @override
  String get shortcutJumpToToday => 'Ir a hoy';

  @override
  String get shortcutGroupView => 'Vista';

  @override
  String get shortcutDayView => 'Vista de día';

  @override
  String get shortcutWeekView => 'Vista de semana';

  @override
  String get shortcutMonthView => 'Vista de mes';

  @override
  String get shortcutYearView => 'Vista de año';

  @override
  String get shortcutAgendaView => 'Vista de agenda';

  @override
  String get shortcutGroupCreateAndEdit => 'Crear y editar';

  @override
  String get shortcutSaveItem => 'Guardar evento o tarea';

  @override
  String get shortcutDeleteItem => 'Eliminar evento o tarea';

  @override
  String get shortcutGroupTaskEditing => 'Edición de tareas';

  @override
  String get shortcutCancelEditing => 'Cancelar edición';

  @override
  String get shortcutCancelEditingDescription =>
      'Cerrar la edición o los detalles de la tarea';

  @override
  String get shortcutGroupCompactAgenda => 'Agenda compacta';

  @override
  String get shortcutRefreshCompactAgendaDescription =>
      'Actualizar la ventana de agenda compacta';

  @override
  String get shortcutHideCompactAgendaDescription =>
      'Ocultar la ventana de agenda compacta';

  @override
  String get aboutBusyMax => 'Acerca de BusyMax';

  @override
  String get aboutBusyMaxDescription => 'ToDo y calendario';

  @override
  String get website => 'Sitio web';

  @override
  String get reportAnIssue => 'Informar de un problema';

  @override
  String get sendFeedback => 'Enviar comentarios';

  @override
  String get feedbackSubmit => 'Enviar';

  @override
  String get feedbackCategory => 'Categoría';

  @override
  String get feedbackSelectCategory => 'Selecciona una categoría';

  @override
  String get feedbackCategoryProblem => 'Problema o error';

  @override
  String get feedbackCategoryFeature => 'Solicitud de función';

  @override
  String get feedbackCategoryPrivacySecurity =>
      'Problema de privacidad o seguridad';

  @override
  String get feedbackCategoryUsability => 'Problema de usabilidad';

  @override
  String get feedbackCategoryOther => 'Otro';

  @override
  String get feedbackSubject => 'Asunto';

  @override
  String get feedbackDetailedMessage => 'Mensaje detallado';

  @override
  String get feedbackReplyEmail => 'Correo electrónico de respuesta (opcional)';

  @override
  String get feedbackIncludeTechnicalDetails => 'Incluir detalles técnicos';

  @override
  String get feedbackTechnicalDetailsDisclosure =>
      'Incluye únicamente la versión del sistema operativo Linux y la configuración regional de la aplicación. No se incluyen registros, datos de cuenta, nombres de archivos ni otros diagnósticos.';

  @override
  String get feedbackCategoryRequired => 'Selecciona una categoría.';

  @override
  String get feedbackSubjectLengthError =>
      'El asunto debe tener entre 3 y 120 caracteres.';

  @override
  String get feedbackMessageLengthError =>
      'El mensaje debe tener entre 10 y 5.000 caracteres.';

  @override
  String get feedbackInvalidEmail =>
      'Introduce una dirección de correo electrónico válida.';

  @override
  String get feedbackConnectionError =>
      'No se pudo conectar con BusyStack. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get feedbackTimeoutError =>
      'La solicitud agotó el tiempo de espera. Tus comentarios no se han borrado; inténtalo de nuevo.';

  @override
  String get feedbackRateLimitedError =>
      'Se han enviado demasiados comentarios desde esta red. Espera e inténtalo de nuevo.';

  @override
  String get feedbackRejectedError =>
      'El servidor rechazó el envío. Revisa los campos e inténtalo de nuevo.';

  @override
  String get feedbackServerError =>
      'BusyStack no puede aceptar tus comentarios ahora. Tus comentarios no se han borrado; inténtalo de nuevo.';

  @override
  String feedbackSuccess(String id) {
    return 'Comentarios enviados. Referencia: $id';
  }

  @override
  String get toggleSidebar => 'Alternar barra lateral';

  @override
  String get accounts => 'Cuentas';

  @override
  String get currentAccount => 'Cuenta actual';

  @override
  String get switchAccount => 'Cambiar cuenta';

  @override
  String get addGoogleAccount => 'Añadir cuenta de Google';

  @override
  String get addMicrosoftAccount => 'Añadir cuenta de Microsoft';

  @override
  String get googleProvider => 'Google';

  @override
  String get microsoftProvider => 'Microsoft';

  @override
  String get signedInAccount => 'Sesión iniciada';

  @override
  String get signOutThisAccount => 'Cerrar sesión de esta cuenta';

  @override
  String get revokeThisAccount => 'Revocar esta cuenta';

  @override
  String get disconnectThisAccount => 'Desconectar esta cuenta';

  @override
  String get deleteLocalDataForThisAccount =>
      'Eliminar datos locales de esta cuenta';

  @override
  String get newList => 'Nueva lista';

  @override
  String get signInToViewTaskLists =>
      'Inicia sesión para ver las listas de tareas.';

  @override
  String get noTaskListsSynced => 'Aún no hay listas de tareas sincronizadas.';

  @override
  String get listActions => 'Acciones de lista';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get delete => 'Eliminar';

  @override
  String get renameList => 'Cambiar nombre de lista';

  @override
  String get deleteList => 'Eliminar lista';

  @override
  String get builtInMicrosoftList => 'Integrada';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Las listas integradas de Microsoft To Do no se pueden cambiar de nombre ni eliminar.';

  @override
  String deleteListConfirmation(String title) {
    return '¿Eliminar \"$title\" de Google Tasks?';
  }

  @override
  String get deleteEvent => 'Eliminar evento';

  @override
  String get title => 'Título';

  @override
  String get create => 'Crear';

  @override
  String get newTask => 'Nueva tarea';

  @override
  String get clearCompleted => 'Borrar completadas';

  @override
  String get refreshList => 'Actualizar lista';

  @override
  String get refreshAll => 'Actualizar todo';

  @override
  String get listRefreshed => 'Lista actualizada.';

  @override
  String get allTasksRefreshed => 'Todas las cuentas se actualizaron.';

  @override
  String exportedFile(String path) {
    return 'Exportado a $path';
  }

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String refreshFailed(String error) {
    return 'Error al actualizar: $error';
  }

  @override
  String get selectOrCreateTaskList => 'Selecciona o crea una lista de tareas.';

  @override
  String get signInToViewTasks => 'Inicia sesión para ver las tareas.';

  @override
  String get noTasks => 'No hay tareas.';

  @override
  String get noTasksYet => 'Aún no hay tareas';

  @override
  String get noTasksYetMessage =>
      'Crea una tarea o actualiza tus cuentas para empezar.';

  @override
  String get noTasksInList => 'No hay tareas en esta lista.';

  @override
  String get overdue => 'Vencidas';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get upcoming => 'Próximas';

  @override
  String get noDate => 'Sin fecha';

  @override
  String get completed => 'Completadas';

  @override
  String duePrefix(String date) {
    return 'Vence $date';
  }

  @override
  String dateTimeDisplay(String date, String time) {
    return '$date, $time';
  }

  @override
  String get searchTasks => 'Buscar tareas';

  @override
  String get advancedFilters => 'Filtros avanzados';

  @override
  String get showCompleted => 'Mostrar completadas';

  @override
  String get showHidden => 'Mostrar ocultas';

  @override
  String get showAssigned => 'Mostrar asignadas';

  @override
  String get taskDetails => 'Detalles de la tarea';

  @override
  String get editTask => 'Editar tarea';

  @override
  String get noTaskSelected => 'No hay tarea seleccionada.';

  @override
  String get noTaskSelectedHelper =>
      'Selecciona una tarea para ver y editar sus detalles.';

  @override
  String get taskUnavailable => 'Tarea no disponible.';

  @override
  String get signInToEditTasks => 'Inicia sesión para editar tareas.';

  @override
  String get refreshTask => 'Actualizar tarea';

  @override
  String get primarySection => 'Principal';

  @override
  String get statusSection => 'Estado';

  @override
  String get openStatus => 'Abierta';

  @override
  String get doneStatus => 'Completada';

  @override
  String get notes => 'Notas';

  @override
  String get dueDate => 'Fecha de vencimiento';

  @override
  String get clearDueDate => 'Borrar fecha de vencimiento';

  @override
  String get dueTime => 'Hora de vencimiento';

  @override
  String get startDate => 'Fecha de inicio';

  @override
  String get startTime => 'Hora de inicio';

  @override
  String get endDate => 'Fecha de fin';

  @override
  String get endTime => 'Hora de fin';

  @override
  String get reminderDate => 'Fecha del recordatorio';

  @override
  String get reminderTime => 'Hora del recordatorio';

  @override
  String get reminder => 'Recordatorio';

  @override
  String get addReminder => 'Añadir recordatorio';

  @override
  String get addGuest => 'Añadir invitado';

  @override
  String get addGuestEmail => 'Añadir correo del invitado';

  @override
  String get removeReminder => 'Quitar recordatorio';

  @override
  String get off => 'Desactivado';

  @override
  String get repeat => 'Repetir';

  @override
  String get repeatNone => 'Ninguna';

  @override
  String get noneValue => 'Ninguno';

  @override
  String get repeatDaily => 'Diaria';

  @override
  String get repeatWeekly => 'Semanal';

  @override
  String get repeatMonthly => 'Mensual';

  @override
  String get repeatYearly => 'Anual';

  @override
  String get importance => 'Importancia';

  @override
  String get importanceLow => 'Baja';

  @override
  String get importanceNormal => 'Normal';

  @override
  String get importanceHigh => 'Alta';

  @override
  String get categories => 'Categorías';

  @override
  String get scheduleSection => 'Programación';

  @override
  String get dueGroup => 'Vencimiento';

  @override
  String get startGroup => 'Inicio';

  @override
  String get reminderGroup => 'Recordatorio';

  @override
  String get organizationSection => 'Organización';

  @override
  String get actionsSection => 'Acciones';

  @override
  String get advancedSection => 'Avanzado';

  @override
  String get addCategory => 'Añadir categoría';

  @override
  String get list => 'Lista';

  @override
  String get microsoftMoveUnsupported =>
      'Mover tareas entre listas no es compatible con las cuentas de Microsoft To Do en esta versión.';

  @override
  String get createSubtask => 'Crear subtarea';

  @override
  String get moveToTop => 'Mover arriba';

  @override
  String get deleteTask => 'Eliminar tarea';

  @override
  String get newSubtask => 'Nueva subtarea';

  @override
  String deleteTaskConfirmation(String title) {
    return '¿Eliminar \"$title\" de Google Tasks?';
  }

  @override
  String get metadata => 'Metadatos';

  @override
  String get id => 'ID';

  @override
  String get etag => 'ETag';

  @override
  String get updated => 'Actualizada';

  @override
  String get parent => 'Padre';

  @override
  String get position => 'Posición';

  @override
  String get webLink => 'Enlace web';

  @override
  String get assignment => 'Asignación';

  @override
  String get localState => 'Estado local';

  @override
  String get pendingSync => 'Sincronización pendiente';

  @override
  String get synced => 'Sincronizada';

  @override
  String get account => 'Cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get revokeGoogleAuthorization => 'Revocar autorización de Google';

  @override
  String get deleteLocalData => 'Eliminar datos locales';

  @override
  String get deleteLocalDataConfirmation =>
      'Esto elimina de este dispositivo la cuenta local, las tareas sincronizadas y los cambios sin conexión pendientes.';

  @override
  String get sync => 'Sincronización';

  @override
  String get manualFullSync => 'Sincronización completa manual';

  @override
  String get runInBackgroundWhenClosed =>
      'Seguir ejecutándose al cerrar la ventana';

  @override
  String get showTrayIcon => 'Mostrar el icono en la bandeja del sistema';

  @override
  String get startMinimizedToTray =>
      'Iniciar minimizado en la bandeja del sistema';

  @override
  String get requiresTrayIcon => 'Requiere el icono de la bandeja del sistema.';

  @override
  String get syncComplete => 'Sincronización completa.';

  @override
  String syncFailed(String error) {
    return 'Error de sincronización: $error';
  }

  @override
  String get notifySyncFailures =>
      'Notificaciones de errores de sincronización';

  @override
  String get notifyConflicts => 'Notificaciones de conflictos';

  @override
  String get notifyDueToday => 'Notificaciones de tareas para hoy';

  @override
  String get eventReminders => 'Recordatorios de eventos';

  @override
  String get taskReminders => 'Recordatorios de tareas';

  @override
  String get notificationDetailLevel =>
      'Nivel de detalle de las notificaciones';

  @override
  String get notificationDetailPrivate => 'Privado';

  @override
  String get notificationDetailNormal => 'Normal';

  @override
  String get quietHours => 'Horario silencioso';

  @override
  String get quietHoursDescription =>
      'Pausar las notificaciones durante este período.';

  @override
  String get quietHoursStart => 'Inicio del horario silencioso';

  @override
  String get quietHoursEnd => 'Fin del horario silencioso';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get appearance => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeFamily => 'Familia de tema';

  @override
  String get themeFamilyYaru => 'Ubuntu nativo (Yaru)';

  @override
  String get localization => 'Localización';

  @override
  String get currentLocale => 'Configuración regional actual';

  @override
  String get privacy => 'Privacidad';

  @override
  String get redactTaskContentInDiagnostics =>
      'Ocultar contenido de tareas en diagnósticos';

  @override
  String get developerDiagnostics => 'Diagnósticos de desarrollo';

  @override
  String get diagnostics => 'Diagnósticos';

  @override
  String get apiInspectorDisabled => 'Mostrar inspector de API';

  @override
  String get googleTasksApi => 'API de Google Tasks';

  @override
  String discoveryRevision(String revision) {
    return 'Revisión de Discovery: $revision';
  }

  @override
  String get implementedMethods => 'Métodos implementados';

  @override
  String get supportsTasksScopes =>
      'Admite los alcances tasks y tasks.readonly';

  @override
  String get requiresTasksScope => 'Requiere el alcance tasks';

  @override
  String get blockedPendingOperations => 'Operaciones pendientes bloqueadas';

  @override
  String get signInToInspectPendingOperations =>
      'Inicia sesión para inspeccionar operaciones pendientes.';

  @override
  String get noBlockedPendingOperations =>
      'No hay operaciones pendientes bloqueadas.';

  @override
  String get operationActions => 'Acciones de operación';

  @override
  String pendingOpListId(String id) {
    return 'lista=$id';
  }

  @override
  String pendingOpTaskId(String id) {
    return 'tarea=$id';
  }

  @override
  String pendingOpAttempts(int count) {
    return 'intentos=$count';
  }

  @override
  String get retry => 'Reintentar';

  @override
  String get discard => 'Descartar';

  @override
  String get discardChanges => '¿Descartar cambios?';

  @override
  String get discardChangesConfirmation =>
      'Esto descarta las ediciones no guardadas de esta tarea.';

  @override
  String get retryCompleted => 'Reintento completado.';

  @override
  String get discardPendingOperation => '¿Descartar operación pendiente?';

  @override
  String get discardPendingOperationConfirmation =>
      'Esto elimina la operación local bloqueada. La próxima sincronización actualizará desde Google Tasks.';

  @override
  String get pendingOperationDiscarded => 'Operación pendiente descartada.';

  @override
  String get syncFailureNotificationTitle =>
      'Falló la sincronización de BusyMax';

  @override
  String syncFailureNotificationBody(String message) {
    return 'Falló la sincronización en segundo plano. $message';
  }

  @override
  String get conflictNotificationTitle =>
      'Conflicto de sincronización de BusyMax';

  @override
  String conflictNotificationBody(String summary) {
    return 'Se bloqueó un cambio local pendiente. $summary';
  }

  @override
  String get dueTodayNotificationTitle => 'Tareas que vencen hoy';

  @override
  String dueTodayNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas vencen hoy.',
      one: 'Una tarea vence hoy.',
    );
    return '$_temp0';
  }

  @override
  String get notificationDetailsHidden =>
      'Los detalles están ocultos por la configuración de privacidad.';

  @override
  String get previousMonth => 'Mes anterior';

  @override
  String get nextMonth => 'Mes siguiente';

  @override
  String get openMonthView => 'Abrir la vista mensual';

  @override
  String get previousYear => 'Año anterior';

  @override
  String get nextYear => 'Año siguiente';

  @override
  String get openYearView => 'Abrir la vista anual';

  @override
  String weekNumberTooltip(int number) {
    return 'Semana $number';
  }

  @override
  String get resizeAllDayPanel => 'Cambiar el tamaño del panel de todo el día';

  @override
  String scheduleItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get readOnlyCalendar => 'Este calendario es de solo lectura.';

  @override
  String deleteCalendarConfirmation(String title) {
    return '¿Eliminar \"$title\"?';
  }
}

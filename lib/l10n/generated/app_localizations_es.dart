// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

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
      'Conecta cuentas de Google, Microsoft, Calendario de Apple iCloud o Nextcloud.';

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
      'Añade todas las cuentas que quieras usar. BusyMax sincroniza los calendarios, eventos, listas de tareas y tareas compatibles de cada cuenta.';

  @override
  String get onboardingPreferencesStepTitle => 'Elegir ajustes del sistema';

  @override
  String get onboardingPreferencesStepDescription =>
      'Configura el comportamiento de la aplicación en el escritorio, los recordatorios, el nivel de detalle de las notificaciones y la apariencia antes de abrir tu agenda.';

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
  String get newCalendar => 'Nuevo calendario';

  @override
  String get calendarColor => 'Color del calendario';

  @override
  String calendarColorOption(int number) {
    return 'Opción de color $number';
  }

  @override
  String get calendarManagementUnsupported =>
      'Este proveedor no admite la gestión de calendarios en BusyMax.';

  @override
  String get primaryCalendarCannotDelete =>
      'El calendario principal no se puede eliminar.';

  @override
  String calendarCreateFailed(String error) {
    return 'No se pudo crear el calendario: $error';
  }

  @override
  String get calendarCreatedRefreshPending =>
      'El calendario se creó, pero BusyMax no pudo actualizar la cuenta. Aparecerá después de la próxima sincronización.';

  @override
  String calendarUpdateFailed(String error) {
    return 'No se pudo actualizar el calendario: $error';
  }

  @override
  String calendarDeleteFailed(String error) {
    return 'No se pudo eliminar el calendario: $error';
  }

  @override
  String get newEvent => 'Nuevo evento';

  @override
  String get refreshCalendar => 'Actualizar calendario';

  @override
  String get openInProvider => 'Abrir en el proveedor';

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
      'Elige qué mostrar en Configuración y, después, actualiza la agenda.';

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
  String get refresh => 'Actualizar';

  @override
  String get trayOpenBusyMax => 'Abrir BusyMax';

  @override
  String get trayShowBusyMax => 'Mostrar BusyMax';

  @override
  String get trayNewEvent => 'Evento nuevo…';

  @override
  String get trayNewTask => 'Tarea nueva…';

  @override
  String get trayToday => 'Hoy';

  @override
  String get trayAllDay => 'Todo el día';

  @override
  String get trayNow => 'Ahora';

  @override
  String get trayCalendarEvent => 'Evento del calendario';

  @override
  String get trayUntitledEvent => 'Evento sin título';

  @override
  String get trayNothingElseToday => 'Nada más hoy';

  @override
  String trayTasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas vencen hoy',
      one: '1 tarea vence hoy',
    );
    return '$_temp0';
  }

  @override
  String get trayOpenTodayAgenda => 'Abrir la agenda de hoy';

  @override
  String get traySyncNow => 'Sincronizar ahora';

  @override
  String get traySyncing => 'Sincronizando…';

  @override
  String get trayNotConnected => 'No conectado';

  @override
  String get trayNotYetSynced => 'Aún no sincronizado';

  @override
  String get trayLastSyncedJustNow => 'Sincronizado ahora mismo';

  @override
  String trayLastSyncedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado hace $count minutos',
      one: 'Sincronizado hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado hace $count horas',
      one: 'Sincronizado hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String trayLastSyncedDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizado hace $count días',
      one: 'Sincronizado hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String get traySettings => 'Configuración';

  @override
  String get trayQuitBusyMax => 'Salir de BusyMax';

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
  String get viewAgenda => 'Vista de agenda';

  @override
  String get scheduleSettings => 'Agenda';

  @override
  String get scheduleDisplaySettings => 'Visualización de agenda';

  @override
  String get scheduleDisplayHoursDescription =>
      'Las vistas de día y semana muestran inicialmente este intervalo horario. Los elementos anteriores o posteriores lo amplían cuando es necesario.';

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
  String get noGuests => 'No hay invitados';

  @override
  String get attendeeRequired => 'Obligatorio';

  @override
  String get attendeeOptional => 'Opcional';

  @override
  String get meetingSection => 'Reunión';

  @override
  String get addGoogleMeet => 'Añadir Google Meet';

  @override
  String get addTeamsMeeting => 'Añadir reunión de Microsoft Teams';

  @override
  String get onlineMeetingAdded => 'Reunión en línea añadida';

  @override
  String get requestResponses => 'Solicitar respuestas';

  @override
  String get requestResponsesDescription =>
      'Pide a los invitados que respondan a la invitación.';

  @override
  String get hideGuestList => 'Ocultar la lista de invitados';

  @override
  String get hideGuestListDescription =>
      'Los invitados no pueden ver quién más ha sido invitado.';

  @override
  String get allowNewTimeProposals => 'Permitir nuevas propuestas de horario';

  @override
  String get allowNewTimeProposalsDescription =>
      'Los invitados pueden sugerir otra hora para la reunión.';

  @override
  String get notifyGuestsTitle => '¿Notificar a los invitados?';

  @override
  String get notifyGuestsSaveMessage =>
      'Esta reunión tiene invitados. ¿Enviar invitaciones o actualizaciones del evento al guardarla?';

  @override
  String get notifyGuestsDeleteMessage =>
      'Esta reunión tiene invitados. ¿Enviar una cancelación al eliminarla?';

  @override
  String get sendUpdates => 'Enviar actualizaciones';

  @override
  String get sendCancellation => 'Enviar cancelación';

  @override
  String get doNotSend => 'No enviar';

  @override
  String get microsoftNotifyGuestsSaveTitle => '¿Guardar la reunión?';

  @override
  String get microsoftNotifyGuestsSaveMessage =>
      'Microsoft enviará invitaciones o actualizaciones del evento a los invitados.';

  @override
  String get microsoftNotifyGuestsDeleteTitle => '¿Eliminar la reunión?';

  @override
  String get microsoftNotifyGuestsDeleteMessage =>
      'Microsoft enviará una cancelación a los invitados.';

  @override
  String get organizer => 'Organizador';

  @override
  String get yourResponse => 'Tu respuesta';

  @override
  String get guestResponses => 'Respuestas de los invitados';

  @override
  String get respond => 'Responder';

  @override
  String get acceptInvitation => 'Aceptar';

  @override
  String get tentativeInvitation => 'Provisional';

  @override
  String get declineInvitation => 'Rechazar';

  @override
  String get joinMeeting => 'Unirse a la reunión';

  @override
  String get responseAccepted => 'Aceptada';

  @override
  String get responseTentative => 'Provisional';

  @override
  String get responseDeclined => 'Rechazada';

  @override
  String get responseNeedsAction => 'Esperando respuesta';

  @override
  String get responseNotResponded => 'Sin respuesta';

  @override
  String get responseOrganizer => 'Organizador';

  @override
  String invitationResponseFailed(String error) {
    return 'No se pudo enviar tu respuesta: $error';
  }

  @override
  String get joinMeetingFailed => 'No se pudo abrir el enlace de la reunión.';

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
  String get sensitivityNormal => 'Habitual';

  @override
  String get sensitivityPersonal => 'Personalizada';

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
  String get shortcutGroupGeneral => 'Atajos generales';

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
  String get shortcutJumpToToday => 'Ir a la fecha de hoy';

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
  String get aboutBusyMax => 'Acerca de BusyMax';

  @override
  String get aboutBusyMaxDescription => 'Calendario y tareas';

  @override
  String get license => 'Licencia';

  @override
  String get apacheLicenseName => 'Apache License 2.0';

  @override
  String get website => 'Sitio web';

  @override
  String get sourceCode => 'Código fuente';

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
  String get feedbackReplyEmail =>
      'Correo electrónico para recibir una respuesta (opcional)';

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
      'Se agotó el tiempo de espera de la solicitud. Tus comentarios no se han borrado; inténtalo de nuevo.';

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
  String get toggleSidebar => 'Mostrar u ocultar la barra lateral';

  @override
  String get showSidebar => 'Mostrar panel lateral';

  @override
  String get hideSidebar => 'Ocultar panel lateral';

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
  String get removeAccount => 'Eliminar cuenta…';

  @override
  String get removingAccount => 'Eliminando cuenta…';

  @override
  String get removeAccountDescription =>
      'Detener la sincronización y eliminar de este dispositivo los datos de esta cuenta.';

  @override
  String removeAccountTitle(String account) {
    return '¿Quitar $account de BusyMax?';
  }

  @override
  String get removeAccountConfirmation =>
      'Esto elimina de este dispositivo las tareas, calendarios, eventos, recordatorios y cambios sin conexión pendientes almacenados en caché. Se perderán los cambios no sincronizados. No se eliminan las copias de calendarios, eventos, listas de tareas ni tareas del proveedor.';

  @override
  String get revokeGoogleAccess =>
      'Revocar también el acceso de BusyMax a esta cuenta de Google';

  @override
  String get revokeGoogleAccessDescription =>
      'Tendrás que volver a conceder acceso antes de reconectar la cuenta.';

  @override
  String get removeAccountAction => 'Eliminar cuenta';

  @override
  String get removeAccountFailed =>
      'No se pudo terminar de eliminar la cuenta. Inténtalo de nuevo.';

  @override
  String get accountRemovedGoogleRevokeFailed =>
      'La cuenta se eliminó de este dispositivo, pero BusyMax no pudo revocar su acceso a tu cuenta de Google. Puedes revocarlo desde tu cuenta de Google.';

  @override
  String get newTaskList => 'Lista de tareas nueva';

  @override
  String taskListCreateFailed(String error) {
    return 'No se pudo crear la lista de tareas: $error';
  }

  @override
  String taskListRenameFailed(String error) {
    return 'No se pudo cambiar el nombre de la lista de tareas: $error';
  }

  @override
  String taskListDeleteFailed(String error) {
    return 'No se pudo eliminar la lista de tareas: $error';
  }

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
  String get unshare => 'Dejar de compartir';

  @override
  String get readOnlyTaskListCannotRename =>
      'Esta lista de tareas es de solo lectura y no se puede cambiar su nombre.';

  @override
  String get taskListCannotDelete =>
      'No se puede eliminar esta lista de tareas con tus permisos actuales.';

  @override
  String get builtInMicrosoftList => 'Integrada';

  @override
  String get builtInMicrosoftListCannotRenameDelete =>
      'Las listas integradas de Microsoft To Do no se pueden cambiar de nombre ni eliminar.';

  @override
  String deleteListConfirmation(String title) {
    return '¿Eliminar «$title» de Google Tasks?';
  }

  @override
  String deleteTaskListConfirmation(String title) {
    return '¿Eliminar «$title» y todas sus tareas?';
  }

  @override
  String unshareTaskListConfirmation(String title) {
    return '¿Dejar de compartir «$title» con esta cuenta?';
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
  String get selectOrCreateTaskList =>
      'Selecciona o crea una lista de tareas para empezar.';

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
  String get doneStatus => 'Hecha';

  @override
  String get taskStatus => 'Estado';

  @override
  String get taskStatusNone => 'Sin estado';

  @override
  String get taskStatusNeedsAction => 'Necesita una acción';

  @override
  String get taskStatusInProcess => 'En curso';

  @override
  String get taskStatusCompleted => 'Completada';

  @override
  String get taskStatusCancelled => 'Cancelada';

  @override
  String completionPercent(int percent) {
    return '$percent% completada';
  }

  @override
  String get completionDate => 'Fecha de finalización';

  @override
  String get priority => 'Prioridad';

  @override
  String get priorityNone => 'Sin prioridad';

  @override
  String priorityHighValue(int priority) {
    return 'Prioridad $priority · Alta';
  }

  @override
  String priorityMediumValue(int priority) {
    return 'Prioridad $priority · Media';
  }

  @override
  String priorityLowValue(int priority) {
    return 'Prioridad $priority · Baja';
  }

  @override
  String get taskUrl => 'URL de la tarea';

  @override
  String get invalidTaskUrl =>
      'Introduce una URL absoluta, incluido su esquema.';

  @override
  String get classification => 'Clasificación';

  @override
  String get classificationPublic =>
      'Al compartirla, mostrar la tarea completa';

  @override
  String get classificationConfidential =>
      'Al compartirla, mostrar solo la disponibilidad';

  @override
  String get classificationPrivate => 'Al compartirla, ocultar esta tarea';

  @override
  String get pinTask => 'Fijar tarea';

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
  String get reminders => 'Recordatorios';

  @override
  String get noReminders => 'Sin recordatorios';

  @override
  String get editReminder => 'Editar recordatorio';

  @override
  String get beforeTaskStarts => 'Antes de que empiece la tarea';

  @override
  String get beforeTaskDue => 'Antes del vencimiento de la tarea';

  @override
  String get afterTaskStarts => 'Después de que empiece la tarea';

  @override
  String get afterTaskDue => 'Después del vencimiento de la tarea';

  @override
  String get relativeToTaskStart =>
      'En relación con la fecha de inicio de la tarea';

  @override
  String get relativeToTaskDue =>
      'En relación con la fecha de vencimiento de la tarea';

  @override
  String get reminderTimeOfDay => 'Hora del día';

  @override
  String get absoluteReminder => 'En una fecha y hora';

  @override
  String get reminderAmount => 'Cantidad';

  @override
  String get reminderUnit => 'Unidad';

  @override
  String get reminderUnitSeconds => 'Segundos';

  @override
  String get reminderUnitMinutes => 'Minutos';

  @override
  String get reminderUnitHours => 'Horas';

  @override
  String get reminderUnitDays => 'Días';

  @override
  String get reminderUnitWeeks => 'Semanas';

  @override
  String get reminderAtTaskStart => 'Al comenzar la tarea';

  @override
  String get reminderAtTaskDue => 'Al vencer la tarea';

  @override
  String get unsupportedReminder =>
      'Este tipo de recordatorio se conserva, pero no se puede editar su hora.';

  @override
  String get relatedRemindersTitle =>
      '¿Conservar los recordatorios relacionados?';

  @override
  String relatedRemindersDescription(int count) {
    return 'Esta fecha tiene $count recordatorios relacionados. ¿Quieres conservarlos en su fecha y hora actuales?';
  }

  @override
  String get discardRelatedReminders => 'Descartar recordatorios';

  @override
  String get keepRelatedReminders => 'Conservar recordatorios';

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
  String get repeatEvery => 'Intervalo';

  @override
  String get repeatOn => 'Repetir en';

  @override
  String get repeatEnd => 'Finalizar repetición';

  @override
  String get repeatNever => 'Nunca';

  @override
  String get repeatUntil => 'En una fecha';

  @override
  String get repeatAfter => 'Después de un número de repeticiones';

  @override
  String get repeatCount => 'Repeticiones';

  @override
  String get repeatDayOfMonth => 'Días del mes';

  @override
  String get repeatMonths => 'Meses';

  @override
  String get repeatOrdinal => 'Posición del día de la semana';

  @override
  String get repeatSpecificDays => 'Días específicos';

  @override
  String get repeatFirst => 'Primero';

  @override
  String get repeatSecond => 'Segundo';

  @override
  String get repeatThird => 'Tercero';

  @override
  String get repeatFourth => 'Cuarto';

  @override
  String get repeatFifth => 'Quinto';

  @override
  String get repeatSecondToLast => 'Penúltimo';

  @override
  String get repeatLast => 'Último';

  @override
  String get repeatAnyDay => 'Día';

  @override
  String get repeatWeekday => 'Día laborable';

  @override
  String get repeatWeekendDay => 'Día de fin de semana';

  @override
  String repeatEveryDays(int count) {
    return 'Cada $count días';
  }

  @override
  String repeatEveryWeeks(int count) {
    return 'Cada $count semanas';
  }

  @override
  String repeatEveryMonths(int count) {
    return 'Cada $count meses';
  }

  @override
  String repeatEveryYears(int count) {
    return 'Cada $count años';
  }

  @override
  String repeatOnDaysSummary(String days) {
    return 'los $days';
  }

  @override
  String repeatOnMonthDaysSummary(String days) {
    return 'el día $days';
  }

  @override
  String repeatOnOrdinalSummary(String position, String days) {
    String _temp0 = intl.Intl.selectLogic(position, {
      'first': 'el primer $days',
      'second': 'el segundo $days',
      'third': 'el tercer $days',
      'fourth': 'el cuarto $days',
      'fifth': 'el quinto $days',
      'secondToLast': 'el penúltimo $days',
      'last': 'el último $days',
      'other': 'en $days',
    });
    return '$_temp0';
  }

  @override
  String repeatInMonthsSummary(String months) {
    return 'en $months';
  }

  @override
  String repeatTimesSummary(int count) {
    return '$count veces';
  }

  @override
  String repeatUntilSummary(String date) {
    return 'hasta $date';
  }

  @override
  String get unsupportedRecurrencePreserved =>
      'Esta regla de repetición usa opciones que este editor no modifica.';

  @override
  String recurrenceUnsupportedByProvider(String provider) {
    return 'Esta repetición no se puede usar con $provider.';
  }

  @override
  String get importance => 'Importancia';

  @override
  String get importanceLow => 'Baja';

  @override
  String get importanceNormal => 'Media';

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
      'En esta versión, no se pueden mover tareas entre listas en cuentas de Microsoft To Do.';

  @override
  String get createSubtask => 'Crear subtarea';

  @override
  String get subtasks => 'Subtareas';

  @override
  String get duplicateTask => 'Duplicar tarea';

  @override
  String get taskDuplicated => 'Tarea duplicada.';

  @override
  String taskDuplicateFailed(String error) {
    return 'No se pudo duplicar la tarea: $error';
  }

  @override
  String get hideSubtasks => 'Ocultar subtareas';

  @override
  String get hideClosedSubtasks => 'Ocultar subtareas cerradas';

  @override
  String get moveToTop => 'Mover al principio';

  @override
  String get deleteTask => 'Eliminar tarea';

  @override
  String get newSubtask => 'Nueva subtarea';

  @override
  String deleteTaskConfirmation(String title) {
    return '¿Eliminar \"$title\"?';
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
  String get parent => 'Tarea principal';

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
  String get launchAtLogin => 'Iniciar al acceder';

  @override
  String get launchAtLoginDescription =>
      'Inicia BusyMax en segundo plano para que los recordatorios funcionen después de acceder.';

  @override
  String get launchAtLoginFailed =>
      'No se pudo actualizar el inicio al acceder.';

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
  String get notifyDueToday => 'Notificaciones de tareas que vencen hoy';

  @override
  String get eventReminders => 'Recordatorios de eventos';

  @override
  String get onState => 'Activado';

  @override
  String get taskReminders => 'Recordatorios de tareas';

  @override
  String get notificationDetailLevel =>
      'Nivel de detalle de las notificaciones';

  @override
  String get notificationDetailPrivate => 'Privado';

  @override
  String get notificationDetailNormal => 'Estándar';

  @override
  String get quietHours => 'Horario de silencio';

  @override
  String get quietHoursDescription =>
      'Pausar las notificaciones durante este período.';

  @override
  String get quietHoursStart => 'Inicio del horario de silencio';

  @override
  String get quietHoursEnd => 'Fin del horario de silencio';

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
  String get themeFamily => 'Familia de temas';

  @override
  String get themeFamilyYaru => 'Tema nativo de Ubuntu (Yaru)';

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
  String get operationActions => 'Acciones de la operación';

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
  String get discardChangesAction => 'Descartar';

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
      'Esto elimina la operación local bloqueada. En la próxima sincronización, se volverán a cargar los datos desde Google Tasks.';

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
    return 'Se ha bloqueado un cambio local pendiente. $summary';
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
  String get eventReminderNotificationTitle => 'Recordatorio de evento';

  @override
  String get taskReminderNotificationTitle => 'Recordatorio de tarea';

  @override
  String get eventReminderNotificationBody => 'El evento empieza pronto.';

  @override
  String get taskReminderNotificationBody => 'La tarea vence pronto.';

  @override
  String get notificationOpenAction => 'Abrir';

  @override
  String get notificationSnoozeAction => 'Posponer 10 minutos';

  @override
  String get notificationDismissAction => 'Cerrar';

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
  String get selectTimeZone => 'Seleccionar zona horaria';

  @override
  String get searchLocations => 'Buscar ubicaciones';

  @override
  String get noLocationsFound => 'No se han encontrado ubicaciones';

  @override
  String get requiredField => 'Este campo es obligatorio.';

  @override
  String get providerConnectionDescription =>
      'Conecta calendarios y tareas de uno de estos proveedores.';

  @override
  String get appleICloudProvider => 'Calendario de Apple iCloud';

  @override
  String get nextcloudProvider => 'Nextcloud';

  @override
  String get appleICloudTasksProvider => 'Apple iCloud';

  @override
  String get nextcloudTasksProvider => 'Tareas de Nextcloud';

  @override
  String get addAppleICloudAccount =>
      'Añadir cuenta del Calendario de Apple iCloud';

  @override
  String get addNextcloudAccount => 'Añadir cuenta de Nextcloud';

  @override
  String get waitingForAppleICloud => 'Conectando con Apple iCloud…';

  @override
  String get waitingForNextcloud => 'Esperando la autorización de Nextcloud…';

  @override
  String get connectAppleICloudTitle =>
      'Conectar el Calendario de Apple iCloud';

  @override
  String get appleAccountEmail => 'Correo de la cuenta de Apple';

  @override
  String get appleAppSpecificPassword => 'Contraseña específica de la app';

  @override
  String get appleAppSpecificPasswordHelp =>
      'Crea una contraseña específica de la app después de activar la autenticación de dos factores en tu cuenta de Apple.';

  @override
  String get appleAppSpecificPasswordResetWarning =>
      'Restablecer la contraseña de tu cuenta de Apple revoca las contraseñas específicas de las apps.';

  @override
  String get connectNextcloudTitle => 'Conectar Nextcloud';

  @override
  String get nextcloudServerUrl => 'Servidor de Nextcloud o dirección CalDAV';

  @override
  String get nextcloudServerUrlHelp =>
      'Introduce la URL de tu servidor Nextcloud o pega la dirección CalDAV principal copiada de Nextcloud.';

  @override
  String get nextcloudBrowserAuthorizationHelp =>
      'BusyMax abrirá el navegador. Aprueba allí el acceso y vuelve a BusyMax.';

  @override
  String get connectAccountAction => 'Conectar';

  @override
  String get cancelAccountConnection => 'Cancelar conexión';

  @override
  String get nextcloudAccountRemovedRevokeFailed =>
      'La cuenta se quitó localmente, pero no se pudo revocar la contraseña de app de Nextcloud.';

  @override
  String get davCachedOfflineNotice =>
      'Los datos del calendario y las tareas se almacenan localmente para usarlos sin conexión.';

  @override
  String get davReauthenticationRequired =>
      'Vuelve a conectar esta cuenta para reanudar la sincronización.';

  @override
  String get davTemporarilyUnavailable =>
      'Esta cuenta no está disponible temporalmente.';

  @override
  String get davPermissionChanged =>
      'Han cambiado los permisos del servidor. Las ediciones pendientes están en pausa.';

  @override
  String get davUnsupportedServer =>
      'Este servidor o perfil de proveedor no es compatible.';

  @override
  String get collectionSettings => 'Calendarios y listas de tareas';

  @override
  String get calendarContent => 'Eventos del calendario';

  @override
  String get taskContent => 'Tareas';

  @override
  String get readOnlySharedCollection => 'Solo lectura';

  @override
  String get pendingLocally => 'Pendiente localmente';

  @override
  String get conflictBlocked => 'Bloqueado por un conflicto';

  @override
  String get authenticationBlocked => 'Bloqueado hasta volver a conectar';

  @override
  String get operationFailed => 'La operación ha fallado';

  @override
  String get keepServerVersion => 'Conservar la versión del servidor';

  @override
  String get reapplyLocalChange => 'Revisar y volver a aplicar el cambio local';

  @override
  String get duplicateLocalItem => 'Duplicar como elemento nuevo';

  @override
  String get davConnectionState => 'Estado de conexión';

  @override
  String get davConnected => 'Conectado';

  @override
  String get davConnecting => 'Conectando…';

  @override
  String get davSignedOut => 'Sesión cerrada';

  @override
  String davLastSuccessfulSync(String time) {
    return 'Última sincronización correcta: $time';
  }

  @override
  String get davNeverSynced => 'Aún no se ha sincronizado';

  @override
  String get refreshCollections => 'Actualizar calendarios y listas de tareas';

  @override
  String nextcloudServerHost(String host) {
    return 'Servidor: $host';
  }

  @override
  String get collectionSupportsEvents => 'Calendario de eventos';

  @override
  String get collectionSupportsTasks => 'Lista de tareas';

  @override
  String get collectionSupportsEventsAndTasks => 'Eventos y tareas';

  @override
  String get writableCollection => 'Editable';

  @override
  String get sharedCollection => 'Compartido';

  @override
  String collectionLastSynced(String time) {
    return 'Última sincronización: $time';
  }

  @override
  String collectionSyncError(String code) {
    return 'Problema de sincronización: $code';
  }

  @override
  String get syncConflicts => 'Conflictos de sincronización';

  @override
  String remoteChangedAt(String time) {
    return 'Cambio en el servidor: $time';
  }

  @override
  String localPendingEdit(String summary) {
    return 'Edición local: $summary';
  }

  @override
  String get conflictResolutionFailed => 'No se pudo resolver el conflicto.';

  @override
  String get recurringEventScope => 'Ámbito del evento recurrente';

  @override
  String get entireSeries => 'Serie completa';

  @override
  String get singleOccurrence => 'Este evento';

  @override
  String get thisAndFollowingEvents => 'Este evento y los siguientes';

  @override
  String get thisAndFutureUnavailable => 'No compatible con este proveedor.';

  @override
  String get thisAndFutureMoveUnavailable =>
      'No se pueden mover de forma segura este evento y los siguientes. Elige este evento o toda la serie.';

  @override
  String get entireSeriesMoveUnavailable =>
      'La regla de repetición no está disponible localmente. Mueve solo este evento.';

  @override
  String get copyEventAndDeleteOriginal =>
      '¿Copiar el evento y eliminar el original?';

  @override
  String copyEventMoveWarning(String source, String destination) {
    return 'BusyMax no puede mover este evento directamente de $source a $destination. Primero creará la copia y eliminará el original solo cuando la copia se complete correctamente. Los identificadores del evento cambiarán; los estados de respuesta de los asistentes pueden restablecerse y pueden enviarse invitaciones o cancelaciones; y es posible que no se conserven los enlaces de conferencia, los archivos adjuntos, los recordatorios, los campos específicos del proveedor ni las excepciones de repetición.';
  }

  @override
  String get copyAndDelete => 'Copiar y eliminar';

  @override
  String get chooseRecurringEventScope =>
      'Elige si este cambio se aplica a toda la serie, solo a este evento o a este y los siguientes eventos.';

  @override
  String get taskDueBeforeStart =>
      'El vencimiento no puede ser anterior al inicio.';

  @override
  String get taskStartDueTimeModeMismatch =>
      'Define una hora tanto para el inicio como para el vencimiento, o configura la tarea para todo el día.';

  @override
  String deleteCalendarConfirmation(String title) {
    return '¿Eliminar \"$title\"?';
  }

  @override
  String get setCustomCalendarName => 'Establecer nombre personalizado';

  @override
  String get setAction => 'Establecer';

  @override
  String get removeFromMyCalendars => 'Quitar de mis calendarios';

  @override
  String get removeAction => 'Quitar';

  @override
  String removeCalendarConfirmation(String title) {
    return '¿Quitar \"$title\" de tu lista de Google Calendar? No se eliminarán el calendario compartido ni sus eventos.';
  }

  @override
  String get calendarCannotRemove =>
      'Este calendario no se puede eliminar ni quitar de esta cuenta.';

  @override
  String get calendarPendingChangesPreventRemoval =>
      'Espera a que terminen de sincronizarse los cambios pendientes de este calendario antes de eliminarlo o quitarlo.';

  @override
  String get calendarSubscriptions => 'Suscripciones de calendarios';

  @override
  String get calendarSubscriptionsDescription =>
      'Añade calendarios de solo lectura que se actualicen desde una URL WebCal segura.';

  @override
  String get addCalendarSubscription => 'Añadir suscripción de calendario';

  @override
  String get subscriptionName => 'Nombre local';

  @override
  String get subscriptionUrl => 'URL de la suscripción';

  @override
  String get subscriptionUrlHelp =>
      'Introduce una URL HTTPS o webcal. BusyMax guarda la URL completa en un almacenamiento seguro.';

  @override
  String get subscriptionUrlInvalid =>
      'Introduce una URL HTTPS o webcal válida sin información de usuario ni fragmento.';

  @override
  String get subscriptionColor => 'Color local';

  @override
  String get subscriptionColorHelp =>
      'Usa un color de seis dígitos, como #3584E4.';

  @override
  String get subscriptionColorInvalid =>
      'Introduce un color hexadecimal de seis dígitos.';

  @override
  String get subscriptionRefreshMode => 'Frecuencia de actualización';

  @override
  String get subscriptionAutomatic => 'Automática';

  @override
  String get subscriptionHourly => 'Cada hora';

  @override
  String get subscriptionSixHours => 'Cada seis horas';

  @override
  String get subscriptionDaily => 'Diaria';

  @override
  String subscriptionSafeOrigin(String origin) {
    return 'Origen: $origin';
  }

  @override
  String get subscriptionSafeOriginUnavailable =>
      'Introduce una URL válida para previsualizar su origen seguro.';

  @override
  String get subscriptionReadOnly => 'Suscripción de solo lectura';

  @override
  String get subscriptionNeverRefreshed => 'Aún no se ha actualizado';

  @override
  String subscriptionLastRefresh(String time) {
    return 'Última actualización correcta: $time';
  }

  @override
  String subscriptionNextRefresh(String time) {
    return 'Próxima actualización: $time';
  }

  @override
  String get subscriptionStatusHealthy => 'Actualizada';

  @override
  String subscriptionStatusIssue(String code) {
    return 'Problema de actualización: $code';
  }

  @override
  String get refreshNow => 'Actualizar ahora';

  @override
  String get unsubscribe => 'Cancelar suscripción';

  @override
  String unsubscribeCalendarTitle(String name) {
    return '¿Cancelar la suscripción a «$name»?';
  }

  @override
  String get unsubscribeCalendarConfirmation =>
      'Esto elimina la suscripción local y sus eventos almacenados en caché. El calendario publicado no cambia.';

  @override
  String get addSubscriptionAction => 'Añadir suscripción';

  @override
  String subscriptionOperationFailed(String error) {
    return 'La suscripción al calendario ha fallado: $error';
  }

  @override
  String get subscriptions => 'Suscripciones';

  @override
  String get calendarImport => 'Importación de calendario';

  @override
  String get calendarImportDescription =>
      'Selecciona un archivo, revisa sus eventos y elige el calendario editable que debe recibirlos.';

  @override
  String get importIcsFile => 'Importar archivo .ics';

  @override
  String get importIcsPreview => 'Importar eventos del calendario';

  @override
  String importEventsFound(int count) {
    return 'Conjuntos de eventos importables: $count';
  }

  @override
  String importInvalidEvents(int count) {
    return 'Eventos no válidos: $count';
  }

  @override
  String importFieldsOmitted(String fields) {
    return 'Omitidos intencionadamente: $fields';
  }

  @override
  String get noWritableCalendars =>
      'No hay ningún calendario de destino editable disponible.';

  @override
  String get importDestinationCalendar => 'Calendario de destino';

  @override
  String get importIcsConfirm => 'Importar eventos';

  @override
  String get importIcsComplete => 'Importación completada';

  @override
  String importQueued(int count) {
    return 'Importados o en cola: $count';
  }

  @override
  String importDuplicatesSkipped(int count) {
    return 'Duplicados omitidos: $count';
  }

  @override
  String importUnsupportedSets(int count) {
    return 'Conjuntos de repeticiones no compatibles: $count';
  }

  @override
  String importIcsFailed(String error) {
    return 'No se pudo importar el archivo de calendario: $error';
  }

  @override
  String get networkOffline => 'Sin conexión';

  @override
  String get networkOfflineDescription =>
      'Los cambios se sincronizarán cuando se restablezca la conexión.';

  @override
  String get networkOfflineTryAgain =>
      'No tienes conexión. Conéctate a Internet e inténtalo de nuevo.';

  @override
  String repeatOnMonthDaysSummaryMultiple(String days) {
    return 'los días $days';
  }

  @override
  String get repeatSummarySeparator => ' ';

  @override
  String repeatMonthDayValue(int day) {
    return '$day';
  }

  @override
  String get repeatMonthDayListSeparator => ', ';
}

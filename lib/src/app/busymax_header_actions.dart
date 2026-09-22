/// Commands exposed by BusyMax's Flutter-rendered application header.
///
/// These are presentation commands, not platform-channel messages. A route
/// dispatches them directly to the state that owns the corresponding action.
enum BusyMaxHeaderAction {
  back,
  continueSetup,
  sidebarToggle,
  today,
  previous,
  next,
  viewModeDay,
  viewModeWeek,
  viewModeMonth,
  viewModeYear,
  viewModeAgenda,
  search,
  createEvent,
  createTask,
  refresh,
  settings,
  keyboardShortcuts,
  reportIssue,
  aboutBusyMax,
}

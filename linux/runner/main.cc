#include "my_application.h"

int main(int argc, char** argv) {
  // BusyMax uses a tray-attached compact Agenda window. GNOME Wayland does not
  // allow normal GTK top-level windows to choose an absolute screen position,
  // so the tray popup opens centered. X11/XWayland honors gtk_window_move(),
  // which is required for this app-level tray surface.
  gdk_set_allowed_backends("x11");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

#include "my_application.h"

int main(int argc, char** argv) {
  // Prefer the native GNOME Wayland path. Compact Agenda positioning is exact
  // only when the process is actually running on X11/XWayland; Mutter may
  // center normal GTK top-level windows on Wayland.
  gdk_set_allowed_backends("wayland,x11");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

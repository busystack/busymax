#include "../gtk_window_preferences.h"

#include <gtk/gtk.h>

#include <array>
#include <cstring>
#include <iostream>
#include <string>

namespace {

bool check(bool condition, const char* message) {
  if (condition) return true;
  std::cerr << message << '\n';
  return false;
}

const char* alternate(const char* current, const char* first,
                      const char* second) {
  return current != nullptr && std::strcmp(current, first) == 0 ? second
                                                                : first;
}

struct OriginalSettings {
  explicit OriginalSettings(GtkSettings* settings) : settings(settings) {
    g_object_get(settings,
                 "gtk-decoration-layout", &decoration_layout,
                 "gtk-titlebar-double-click", &double_click,
                 "gtk-titlebar-middle-click", &middle_click,
                 "gtk-titlebar-right-click", &right_click,
                 nullptr);
  }

  ~OriginalSettings() {
    g_object_set(settings,
                 "gtk-decoration-layout", decoration_layout,
                 "gtk-titlebar-double-click", double_click,
                 "gtk-titlebar-middle-click", middle_click,
                 "gtk-titlebar-right-click", right_click,
                 nullptr);
    g_free(decoration_layout);
    g_free(double_click);
    g_free(middle_click);
    g_free(right_click);
  }

  GtkSettings* settings;
  gchar* decoration_layout = nullptr;
  gchar* double_click = nullptr;
  gchar* middle_click = nullptr;
  gchar* right_click = nullptr;
};

}  // namespace

int main(int argc, char** argv) {
  if (!gtk_init_check(&argc, &argv)) {
    std::cerr << "GTK could not initialize\n";
    return 1;
  }

  GtkSettings* settings = gtk_settings_get_default();
  if (!check(settings != nullptr, "GTK settings are unavailable")) return 1;
  OriginalSettings original(settings);

  const BusyMaxGtkWindowPreferences defaults =
      BusyMaxGtkWindowPreferencesWatcher::Defaults();
  bool passed =
      check(defaults.decoration_layout == "menu:minimize,maximize,close",
            "Production default decoration layout does not match GTK 3") &&
      check(defaults.double_click == "toggle-maximize",
            "Production default double-click action is incorrect") &&
      check(defaults.middle_click == "none",
            "Production default middle-click action is incorrect") &&
      check(defaults.right_click == "menu",
            "Production default right-click action is incorrect");

  BusyMaxGtkWindowPreferencesWatcher watcher(settings);
  const BusyMaxGtkWindowPreferences initial = watcher.Read();
  passed = check(!initial.decoration_layout.empty(),
            "Production reader returned no decoration layout") &&
      check(!initial.double_click.empty(),
            "Production reader returned no double-click action") &&
      check(!initial.middle_click.empty(),
            "Production reader returned no middle-click action") &&
      check(!initial.right_click.empty(),
            "Production reader returned no right-click action") &&
      passed;

  int callback_count = 0;
  BusyMaxGtkWindowPreferences observed = initial;
  passed = check(
               watcher.Start(
                   [&](const BusyMaxGtkWindowPreferences& preferences) {
                     callback_count += 1;
                     observed = preferences;
                   }),
               "Production watcher failed to start") &&
           passed;
  const std::array<gulong, 4> signals = watcher.signal_ids();
  for (gulong signal : signals) {
    passed = check(signal != 0, "Failed to connect a production signal") &&
             passed;
  }

  const char* changed_layout =
      alternate(original.decoration_layout, "icon:close", "menu:minimize");
  int before = callback_count;
  g_object_set(settings, "gtk-decoration-layout", changed_layout, nullptr);
  passed = check(callback_count > before,
                 "Decoration-layout callback was not delivered") &&
           check(observed.decoration_layout == changed_layout,
                 "Production reader did not return the changed layout") &&
           passed;

  const char* changed_double_click =
      alternate(original.double_click, "minimize", "toggle-maximize");
  before = callback_count;
  g_object_set(settings, "gtk-titlebar-double-click", changed_double_click,
               nullptr);
  passed = check(callback_count > before,
                 "Double-click callback was not delivered") &&
           check(observed.double_click == changed_double_click,
                 "Production reader did not return the changed double-click action") &&
           passed;

  const char* changed_middle_click =
      alternate(original.middle_click, "lower", "none");
  before = callback_count;
  g_object_set(settings, "gtk-titlebar-middle-click", changed_middle_click,
               nullptr);
  passed = check(callback_count > before,
                 "Middle-click callback was not delivered") &&
           check(observed.middle_click == changed_middle_click,
                 "Production reader did not return the changed middle-click action") &&
           passed;

  const char* changed_right_click =
      alternate(original.right_click, "none", "menu");
  before = callback_count;
  g_object_set(settings, "gtk-titlebar-right-click", changed_right_click,
               nullptr);
  passed = check(callback_count > before,
                 "Right-click callback was not delivered") &&
           check(observed.right_click == changed_right_click,
                 "Production reader did not return the changed right-click action") &&
           passed;

  watcher.Stop();
  watcher.Stop();
  for (gulong signal : signals) {
    passed = check(!g_signal_handler_is_connected(settings, signal),
                   "Production watcher signal remained connected") &&
             passed;
  }

  before = callback_count;
  g_object_set(settings, "gtk-decoration-layout",
               alternate(changed_layout, "close:", "icon:"), nullptr);
  passed = check(callback_count == before,
                 "Callback was delivered after production watcher stop") &&
           passed;

  return passed ? 0 : 1;
}

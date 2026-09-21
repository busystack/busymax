#include <gtk/gtk.h>

#include <cstring>
#include <iostream>

namespace {

struct NotificationCounts {
  int decoration_layout = 0;
  int double_click = 0;
  int middle_click = 0;
  int right_click = 0;
};

void on_setting_changed(GObject*, GParamSpec* specification,
                        gpointer user_data) {
  auto* counts = static_cast<NotificationCounts*>(user_data);
  const char* name = g_param_spec_get_name(specification);
  if (std::strcmp(name, "gtk-decoration-layout") == 0) {
    counts->decoration_layout += 1;
  } else if (std::strcmp(name, "gtk-titlebar-double-click") == 0) {
    counts->double_click += 1;
  } else if (std::strcmp(name, "gtk-titlebar-middle-click") == 0) {
    counts->middle_click += 1;
  } else if (std::strcmp(name, "gtk-titlebar-right-click") == 0) {
    counts->right_click += 1;
  }
}

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

}  // namespace

int main(int argc, char** argv) {
  if (!gtk_init_check(&argc, &argv)) {
    std::cerr << "GTK could not initialize\n";
    return 1;
  }

  GtkSettings* settings = gtk_settings_get_default();
  if (!check(settings != nullptr, "GTK settings are unavailable")) return 1;

  const char* properties[] = {
      "gtk-decoration-layout",
      "gtk-titlebar-double-click",
      "gtk-titlebar-middle-click",
      "gtk-titlebar-right-click",
  };
  for (const char* property : properties) {
    GParamSpec* specification =
        g_object_class_find_property(G_OBJECT_GET_CLASS(settings), property);
    if (!check(specification != nullptr, "Required GTK setting is missing") ||
        !check((specification->flags & G_PARAM_READABLE) != 0,
               "Required GTK setting is not readable")) {
      return 1;
    }
  }

  gchar* original_layout = nullptr;
  gchar* original_double_click = nullptr;
  gchar* original_middle_click = nullptr;
  gchar* original_right_click = nullptr;
  g_object_get(settings, "gtk-decoration-layout", &original_layout,
               "gtk-titlebar-double-click", &original_double_click,
               "gtk-titlebar-middle-click", &original_middle_click,
               "gtk-titlebar-right-click", &original_right_click, nullptr);

  NotificationCounts counts;
  gulong signals[] = {
      g_signal_connect(settings, "notify::gtk-decoration-layout",
                       G_CALLBACK(on_setting_changed), &counts),
      g_signal_connect(settings, "notify::gtk-titlebar-double-click",
                       G_CALLBACK(on_setting_changed), &counts),
      g_signal_connect(settings, "notify::gtk-titlebar-middle-click",
                       G_CALLBACK(on_setting_changed), &counts),
      g_signal_connect(settings, "notify::gtk-titlebar-right-click",
                       G_CALLBACK(on_setting_changed), &counts),
  };

  const char* changed_layout =
      alternate(original_layout, "menu:close", ":close");
  const char* changed_double_click =
      alternate(original_double_click, "minimize", "toggle-maximize");
  const char* changed_middle_click =
      alternate(original_middle_click, "lower", "none");
  const char* changed_right_click =
      alternate(original_right_click, "none", "menu");
  g_object_set(settings, "gtk-decoration-layout", changed_layout,
               "gtk-titlebar-double-click", changed_double_click,
               "gtk-titlebar-middle-click", changed_middle_click,
               "gtk-titlebar-right-click", changed_right_click, nullptr);

  bool passed = check(counts.decoration_layout > 0,
                      "Decoration-layout notification was not delivered") &&
                check(counts.double_click > 0,
                      "Double-click notification was not delivered") &&
                check(counts.middle_click > 0,
                      "Middle-click notification was not delivered") &&
                check(counts.right_click > 0,
                      "Right-click notification was not delivered");

  for (gulong signal : signals) {
    passed = check(signal != 0, "Failed to connect a GTK settings signal") &&
             passed;
    if (signal == 0) continue;
    g_signal_handler_disconnect(settings, signal);
    passed = check(!g_signal_handler_is_connected(settings, signal),
                   "GTK settings signal remained connected") &&
             passed;
  }

  g_object_set(settings, "gtk-decoration-layout", original_layout,
               "gtk-titlebar-double-click", original_double_click,
               "gtk-titlebar-middle-click", original_middle_click,
               "gtk-titlebar-right-click", original_right_click, nullptr);
  g_free(original_layout);
  g_free(original_double_click);
  g_free(original_middle_click);
  g_free(original_right_click);
  return passed ? 0 : 1;
}

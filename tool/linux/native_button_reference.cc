#include <gtk/gtk.h>

#include <cstdio>

namespace {

GtkWidget* MakeButton(const char* label, const char* role,
                      GtkStateFlags state, bool enabled) {
  GtkWidget* button = gtk_button_new_with_label(label);
  GtkStyleContext* context = gtk_widget_get_style_context(button);
  if (role != nullptr) {
    gtk_style_context_add_class(context, role);
  }
  gtk_widget_set_sensitive(button, enabled);
  if (state != GTK_STATE_FLAG_NORMAL) {
    gtk_widget_set_state_flags(button, state, FALSE);
  }
  return button;
}

gboolean Capture(gpointer data) {
  GtkWidget* window = GTK_WIDGET(data);
  GdkWindow* gdk_window = gtk_widget_get_window(window);
  const int width = gtk_widget_get_allocated_width(window);
  const int height = gtk_widget_get_allocated_height(window);
  GdkPixbuf* pixels =
      gdk_pixbuf_get_from_window(gdk_window, 0, 0, width, height);
  const char* output = static_cast<const char*>(
      g_object_get_data(G_OBJECT(window), "busymax-output"));
  GError* error = nullptr;
  if (pixels == nullptr ||
      !gdk_pixbuf_save(pixels, output, "png", &error, nullptr)) {
    g_printerr("Could not save native reference: %s\n",
               error == nullptr ? "no pixels" : error->message);
  }
  if (error != nullptr) {
    g_error_free(error);
  }
  if (pixels != nullptr) {
    g_object_unref(pixels);
  }
  gtk_main_quit();
  return G_SOURCE_REMOVE;
}

}  // namespace

int main(int argc, char** argv) {
  gtk_init(&argc, &argv);
  if (argc != 2) {
    g_printerr("usage: native_button_reference OUTPUT.png\n");
    return 2;
  }

  GtkSettings* settings = gtk_settings_get_default();
  gchar* theme = nullptr;
  gchar* font = nullptr;
  g_object_get(settings, "gtk-theme-name", &theme, "gtk-font-name", &font,
               nullptr);
  g_print("theme=%s font=%s scale=%d\n", theme, font,
          gdk_window_get_scale_factor(gdk_get_default_root_window()));
  g_free(theme);
  g_free(font);

  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), "Native Ubuntu button reference");
  gtk_window_set_default_size(GTK_WINDOW(window), 760, 390);
  gtk_container_set_border_width(GTK_CONTAINER(window), 24);
  g_object_set_data_full(G_OBJECT(window), "busymax-output", g_strdup(argv[1]),
                         g_free);

  GtkWidget* grid = gtk_grid_new();
  gtk_grid_set_row_spacing(GTK_GRID(grid), 12);
  gtk_grid_set_column_spacing(GTK_GRID(grid), 20);
  gtk_container_add(GTK_CONTAINER(window), grid);

  const char* column_labels[] = {"State", "Standard", "Suggested",
                                 "Destructive"};
  for (int column = 0; column < 4; ++column) {
    GtkWidget* label = gtk_label_new(column_labels[column]);
    gtk_widget_set_halign(label, GTK_ALIGN_CENTER);
    gtk_grid_attach(GTK_GRID(grid), label, column, 0, 1, 1);
  }

  struct StateRow {
    const char* label;
    GtkStateFlags state;
    bool enabled;
  };
  const StateRow rows[] = {
      {"Resting", GTK_STATE_FLAG_NORMAL, true},
      {"Hovered", GTK_STATE_FLAG_PRELIGHT, true},
      {"Pressed", GTK_STATE_FLAG_ACTIVE, true},
      {"Focused", GTK_STATE_FLAG_FOCUSED, true},
      {"Disabled", GTK_STATE_FLAG_INSENSITIVE, false},
  };
  const char* roles[] = {nullptr, GTK_STYLE_CLASS_SUGGESTED_ACTION,
                         GTK_STYLE_CLASS_DESTRUCTIVE_ACTION};
  for (int row = 0; row < 5; ++row) {
    GtkWidget* label = gtk_label_new(rows[row].label);
    gtk_widget_set_halign(label, GTK_ALIGN_START);
    gtk_grid_attach(GTK_GRID(grid), label, 0, row + 1, 1, 1);
    for (int column = 0; column < 3; ++column) {
      GtkWidget* button =
          MakeButton("Action", roles[column], rows[row].state,
                     rows[row].enabled);
      gtk_widget_set_hexpand(button, TRUE);
      gtk_grid_attach(GTK_GRID(grid), button, column + 1, row + 1, 1, 1);
    }
  }

  g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), nullptr);
  gtk_widget_show_all(window);
  g_timeout_add(500, Capture, window);
  gtk_main();
  return 0;
}

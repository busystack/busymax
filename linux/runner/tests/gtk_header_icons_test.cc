#include "../gtk_header_icons.h"

#include <gtk/gtk.h>

#include <iostream>
#include <string>
#include <vector>

namespace {

bool Check(bool condition, const char* message) {
  if (condition) return true;
  std::cerr << message << '\n';
  return false;
}

}  // namespace

int main(int argc, char** argv) {
  if (!gtk_init_check(&argc, &argv)) {
    std::cerr << "GTK could not initialize\n";
    return 1;
  }

  GtkIconTheme* theme = gtk_icon_theme_get_default();
  if (!Check(theme != nullptr, "GTK icon theme is unavailable")) return 1;
  g_autoptr(GtkWidget) view = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  g_object_ref_sink(view);
  BusyMaxGtkHeaderIcons icons(view, theme);
  bool passed = Check(kBusyMaxGtkHeaderIconLogicalSize == 16,
                      "Production nominal GTK header icon size is not 16");

  const std::vector<std::string> known = {"go-previous-symbolic"};
  const auto normal = icons.Load(known, BusyMaxGtkIconDirection::kLtr, 1);
  passed = Check(normal.has_value(),
                 "Known standard symbolic icon lookup failed") &&
           passed;
  if (normal) {
    passed = Check(normal->resolved_name == known.front(),
                   "Known icon resolved under an unexpected name") &&
             Check(normal->scale == 1,
                   "Normal-DPI lookup did not retain the supplied scale") &&
             Check(!normal->png_bytes.empty(),
                   "Known icon produced no PNG bytes") &&
             Check(normal->pixel_width > 0 && normal->pixel_height > 0,
                   "Known icon produced an empty raster") &&
             passed;

    g_autoptr(GInputStream) stream = g_memory_input_stream_new_from_data(
        normal->png_bytes.data(), normal->png_bytes.size(), nullptr);
    g_autoptr(GError) decode_error = nullptr;
    g_autoptr(GdkPixbuf) decoded =
        gdk_pixbuf_new_from_stream(stream, nullptr, &decode_error);
    passed = Check(decoded != nullptr,
                   "Produced PNG bytes could not be decoded") &&
             Check(decoded == nullptr ||
                       (gdk_pixbuf_get_width(decoded) > 0 &&
                        gdk_pixbuf_get_height(decoded) > 0),
                   "Decoded PNG was empty") &&
             passed;
  }

  const auto high_dpi =
      icons.Load(known, BusyMaxGtkIconDirection::kLtr, 2);
  passed = Check(high_dpi.has_value(), "High-DPI icon lookup failed") &&
           Check(high_dpi && high_dpi->scale == 2,
                 "High-DPI lookup did not use the supplied scale") &&
           passed;
  if (normal && high_dpi) {
    passed = Check(high_dpi->pixel_width >= normal->pixel_width &&
                       high_dpi->pixel_height >= normal->pixel_height,
                   "High-DPI raster was smaller than the 1x raster") &&
             passed;
  }

  const std::vector<std::string> ordered = {
      "go-next-symbolic", "go-previous-symbolic"};
  const auto preferred =
      icons.Load(ordered, BusyMaxGtkIconDirection::kLtr, 1);
  passed = Check(preferred &&
                     preferred->resolved_name == "go-next-symbolic",
                 "Ordered lookup did not select the first available icon") &&
           passed;

  const std::vector<std::string> fallback = {
      "busymax-deliberately-missing-symbolic", "go-next-symbolic"};
  const auto secondary =
      icons.Load(fallback, BusyMaxGtkIconDirection::kLtr, 1);
  passed = Check(secondary &&
                     secondary->resolved_name == "go-next-symbolic",
                 "Missing primary did not fall through to valid secondary") &&
           passed;

  int callback_count = 0;
  passed = Check(icons.Start([&callback_count]() { callback_count += 1; }),
                 "Icon invalidation watcher failed to start") &&
           passed;
  const gulong theme_signal = icons.theme_changed_signal_id();
  const gulong scale_signal = icons.scale_changed_signal_id();
  const gulong screen_signal = icons.screen_changed_signal_id();
  passed = Check(theme_signal != 0,
                 "Theme changed signal was not connected") &&
           Check(scale_signal != 0,
                 "Scale-factor signal was not connected") &&
           Check(screen_signal != 0,
                 "Screen-changed signal was not connected") &&
           passed;

  g_signal_emit_by_name(theme, "changed");
  passed = Check(callback_count == 1,
                 "Theme change did not invoke invalidation callback") &&
           passed;

  icons.Stop();
  icons.Stop();
  passed = Check(!g_signal_handler_is_connected(theme, theme_signal),
                 "Theme signal remained connected after stop") &&
           Check(!g_signal_handler_is_connected(view, scale_signal),
                 "Scale signal remained connected after stop") &&
           Check(!g_signal_handler_is_connected(view, screen_signal),
                 "Screen signal remained connected after stop") &&
           passed;
  g_signal_emit_by_name(theme, "changed");
  passed = Check(callback_count == 1,
                 "Callback occurred after watcher stop") &&
           passed;

  return passed ? 0 : 1;
}

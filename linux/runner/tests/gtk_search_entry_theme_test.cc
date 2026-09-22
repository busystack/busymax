#include "../gtk_search_entry_theme.h"

#include <gtk/gtk.h>

#include <array>
#include <cmath>
#include <iostream>
#include <string>

namespace {

bool Check(bool condition, const char* message) {
  if (condition) return true;
  std::cerr << message << '\n';
  return false;
}

bool IsValidColor(const GdkRGBA& color) {
  return std::isfinite(color.red) && std::isfinite(color.green) &&
         std::isfinite(color.blue) && std::isfinite(color.alpha) &&
         color.red >= 0.0 && color.red <= 1.0 && color.green >= 0.0 &&
         color.green <= 1.0 && color.blue >= 0.0 && color.blue <= 1.0 &&
         color.alpha >= 0.0 && color.alpha <= 1.0;
}

bool IsValidState(const BusyMaxGtkSearchEntryState& state) {
  return IsValidColor(state.background) && IsValidColor(state.foreground) &&
         IsValidColor(state.border_color) &&
         IsValidColor(state.icon_foreground) &&
         IsValidColor(state.icon_foreground_rtl) &&
         state.border_width.top >= 0 && state.border_width.right >= 0 &&
         state.border_width.bottom >= 0 && state.border_width.left >= 0 &&
         state.border_radius >= 0;
}

bool ThemeInstalled(const char* theme_name) {
  const gchar* const* data_dirs = g_get_system_data_dirs();
  for (const gchar* const* directory = data_dirs; *directory != nullptr;
       ++directory) {
    g_autofree gchar* path = g_build_filename(
        *directory, "themes", theme_name, "gtk-3.0", "gtk.css", nullptr);
    if (g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
      return true;
    }
  }
  return false;
}

std::string ColorString(const GdkRGBA& color) {
  g_autofree gchar* value = gdk_rgba_to_string(&color);
  return value == nullptr ? "invalid" : value;
}

void ReportTheme(const char* theme_name,
                 const BusyMaxGtkSearchEntryTheme& theme) {
  std::cout << "GTK theme=" << theme_name
            << " normal.radius=" << theme.normal.border_radius
            << " normal.background=" << ColorString(theme.normal.background)
            << " normal.border=" << ColorString(theme.normal.border_color)
            << " normal.borderWidth=" << theme.normal.border_width.top << ','
            << theme.normal.border_width.right << ','
            << theme.normal.border_width.bottom << ','
            << theme.normal.border_width.left
            << " focused.border=" << ColorString(theme.focused.border_color)
            << " focused.borderWidth=" << theme.focused.border_width.top << ','
            << theme.focused.border_width.right << ','
            << theme.focused.border_width.bottom << ','
            << theme.focused.border_width.left
            << " backdrop.background="
            << ColorString(theme.backdrop.background)
            << " backdrop.foreground="
            << ColorString(theme.backdrop.foreground)
            << " backdrop.border=" << ColorString(theme.backdrop.border_color)
            << " icon.normal=" << ColorString(theme.normal.icon_foreground)
            << " icon.backdrop="
            << ColorString(theme.backdrop.icon_foreground) << '\n';
}

struct OriginalTheme {
  explicit OriginalTheme(GtkSettings* settings) : settings(settings) {
    g_object_get(settings, "gtk-theme-name", &theme_name,
                 "gtk-application-prefer-dark-theme", &prefer_dark, nullptr);
  }

  ~OriginalTheme() {
    g_object_set(settings, "gtk-theme-name", theme_name,
                 "gtk-application-prefer-dark-theme", prefer_dark, nullptr);
    g_free(theme_name);
  }

  GtkSettings* settings;
  gchar* theme_name = nullptr;
  gboolean prefer_dark = FALSE;
};

}  // namespace

int main(int argc, char** argv) {
  if (!gtk_init_check(&argc, &argv)) {
    std::cerr << "GTK could not initialize\n";
    return 1;
  }

  GtkSettings* settings = gtk_settings_get_default();
  if (!Check(settings != nullptr, "GTK settings are unavailable")) return 1;
  OriginalTheme original(settings);

  BusyMaxGtkSearchEntryTheme initial = {};
  bool passed = Check(busymax_sample_gtk_search_entry_theme(&initial),
                      "A real GtkSearchEntry could not be sampled");
  passed = Check(IsValidColor(initial.normal.background),
                 "Normal background was not returned") &&
           Check(IsValidColor(initial.normal.foreground),
                 "Normal foreground was not returned") &&
           Check(IsValidColor(initial.normal.border_color),
                 "Normal border color was not returned") &&
           Check(initial.normal.border_width.top >= 0 &&
                     initial.normal.border_width.right >= 0 &&
                     initial.normal.border_width.bottom >= 0 &&
                     initial.normal.border_width.left >= 0,
                 "Normal border widths were negative") &&
           Check(initial.normal.border_radius >= 0,
                 "GTK_STYLE_PROPERTY_BORDER_RADIUS was not a non-negative "
                 "pixel value") &&
           Check(IsValidState(initial.focused),
                 "Focused state could not be sampled") &&
           Check(IsValidState(initial.backdrop),
                 "Backdrop state could not be sampled") &&
           Check(IsValidState(initial.backdrop_focused),
                 "Backdrop-focused state could not be sampled") &&
           Check(IsValidColor(initial.normal.icon_foreground) &&
                     IsValidColor(initial.normal.icon_foreground_rtl),
                 "Search-entry image-node foreground could not be sampled") &&
           passed;

  passed = Check(!busymax_gtk_theme_is_standard_yaru("Adwaita"),
                 "Adwaita was classified as ordinary Yaru") &&
           Check(busymax_gtk_theme_is_standard_yaru("Yaru"),
                 "Yaru was not classified for compatibility") &&
           Check(busymax_gtk_theme_is_standard_yaru("Yaru-magenta-dark"),
                 "A normal Yaru variant was not classified") &&
           Check(!busymax_gtk_theme_is_standard_yaru("Yaru-HighContrast"),
                 "HighContrast Yaru received the ordinary-Yaru override") &&
           Check(!busymax_gtk_theme_is_standard_yaru(
                     "Yaru-high-contrast-dark"),
                 "Hyphenated HighContrast Yaru received the override") &&
           passed;

  struct ThemeCase {
    const char* name;
    bool dark;
    bool expect_yaru_radius;
    bool expect_adwaita_radius;
  };
  constexpr std::array<ThemeCase, 4> themes = {{
      {"Yaru", false, true, false},
      {"Yaru-dark", true, true, false},
      {"HighContrast", false, false, false},
      {"Adwaita", false, false, true},
  }};

  for (const ThemeCase& test : themes) {
    if (!ThemeInstalled(test.name)) {
      std::cout << "GTK theme=" << test.name << " skipped (not installed)\n";
      continue;
    }
    g_object_set(settings, "gtk-theme-name", test.name,
                 "gtk-application-prefer-dark-theme", test.dark, nullptr);
    BusyMaxGtkSearchEntryTheme sampled = {};
    passed = Check(busymax_sample_gtk_search_entry_theme(&sampled),
                   "Installed GTK theme could not be sampled") &&
             Check(IsValidState(sampled.normal) &&
                       IsValidState(sampled.focused) &&
                       IsValidState(sampled.backdrop) &&
                       IsValidState(sampled.backdrop_focused),
                   "Installed GTK theme returned invalid state data") &&
             passed;
    if (test.expect_yaru_radius) {
      passed = Check(sampled.normal.border_radius == 9 &&
                         sampled.focused.border_radius == 9 &&
                         sampled.backdrop.border_radius == 9 &&
                         sampled.backdrop_focused.border_radius == 9,
                     "Yaru did not receive BusyMax's 9px compatibility radius") &&
               Check(sampled.focused.border_width.top >= 2 &&
                         sampled.focused.border_width.right >= 2 &&
                         sampled.focused.border_width.bottom >= 2 &&
                         sampled.focused.border_width.left >= 2,
                     "Yaru did not retain BusyMax's 2px active focus weight") &&
               passed;
    }
    if (test.expect_adwaita_radius) {
      passed = Check(sampled.normal.border_radius != 9,
                     "Adwaita incorrectly received the Yaru-only radius") &&
               passed;
    }
    ReportTheme(test.name, sampled);
  }

  return passed ? 0 : 1;
}

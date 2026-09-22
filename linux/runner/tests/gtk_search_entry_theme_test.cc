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
         IsValidColor(state.primary_icon_foreground) &&
         IsValidColor(state.primary_icon_foreground_rtl) &&
         IsValidColor(state.secondary_icon_foreground) &&
         IsValidColor(state.secondary_icon_foreground_rtl) &&
         state.border_width.top >= 0 && state.border_width.right >= 0 &&
         state.border_width.bottom >= 0 && state.border_width.left >= 0 &&
         state.border_radius >= 0 && IsValidColor(state.inner_focus_color) &&
         state.inner_focus_width >= 0;
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

bool ColorsEqual(const GdkRGBA& first, const GdkRGBA& second) {
  constexpr double kTolerance = 1e-6;
  return std::abs(first.red - second.red) < kTolerance &&
         std::abs(first.green - second.green) < kTolerance &&
         std::abs(first.blue - second.blue) < kTolerance &&
         std::abs(first.alpha - second.alpha) < kTolerance;
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
            << " focused.innerFocus="
            << (theme.focused.has_inner_focus ? "true" : "false") << ','
            << theme.focused.inner_focus_width << ','
            << ColorString(theme.focused.inner_focus_color)
            << " backdrop.background="
            << ColorString(theme.backdrop.background)
            << " backdrop.foreground="
            << ColorString(theme.backdrop.foreground)
            << " backdrop.border=" << ColorString(theme.backdrop.border_color)
            << " primary.ltr="
            << ColorString(theme.normal.primary_icon_foreground)
            << " primary.rtl="
            << ColorString(theme.normal.primary_icon_foreground_rtl)
            << " secondary.ltr="
            << ColorString(theme.normal.secondary_icon_foreground)
            << " secondary.rtl="
            << ColorString(theme.normal.secondary_icon_foreground_rtl)
            << '\n';
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
  bool passed = true;

  GdkScreen* screen = gdk_screen_get_default();
  passed = Check(screen != nullptr, "GTK screen is unavailable") && passed;
  if (screen != nullptr) {
    GtkCssProvider* provider = gtk_css_provider_new();
    constexpr const char* kDirectionalIconCss =
        "entry image.left { color: #112233; }\n"
        "entry image.right { color: #445566; }\n"
        "entry image.left:disabled { color: #a1b2c3; }\n"
        "entry image.right:disabled { color: #d4e5f6; }\n"
        "entry image.left:disabled:backdrop { color: #123456; }\n";
    g_autoptr(GError) error = nullptr;
    const bool css_loaded = gtk_css_provider_load_from_data(
        provider, kDirectionalIconCss, -1, &error);
    passed = Check(css_loaded, "Directional image-node CSS did not load") &&
             passed;
    if (css_loaded) {
      gtk_style_context_add_provider_for_screen(
          screen, GTK_STYLE_PROVIDER(provider),
          GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
      GtkWidget* entry = gtk_search_entry_new();
      g_object_ref_sink(entry);
      GtkStyleContext* context = gtk_widget_get_style_context(entry);
      GdkRGBA primary_ltr = {};
      GdkRGBA primary_rtl = {};
      GdkRGBA secondary_ltr = {};
      GdkRGBA secondary_rtl = {};
      GdkRGBA backdrop_primary_ltr = {};
      GdkRGBA sensitive_left = {};
      GdkRGBA sensitive_right = {};
      GdkRGBA disabled_left = {};
      GdkRGBA disabled_right = {};
      GdkRGBA disabled_backdrop_left = {};
      gdk_rgba_parse(&sensitive_left, "#112233");
      gdk_rgba_parse(&sensitive_right, "#445566");
      gdk_rgba_parse(&disabled_left, "#a1b2c3");
      gdk_rgba_parse(&disabled_right, "#d4e5f6");
      gdk_rgba_parse(&disabled_backdrop_left, "#123456");
      const bool sampled_primary_ltr =
          busymax_sample_gtk_search_entry_icon_foreground(
              context, GTK_STATE_FLAG_NORMAL, GTK_ENTRY_ICON_PRIMARY,
              GTK_TEXT_DIR_LTR, &primary_ltr);
      const bool sampled_secondary_ltr =
          busymax_sample_gtk_search_entry_icon_foreground(
              context, GTK_STATE_FLAG_NORMAL, GTK_ENTRY_ICON_SECONDARY,
              GTK_TEXT_DIR_LTR, &secondary_ltr);
      const bool sampled_primary_rtl =
          busymax_sample_gtk_search_entry_icon_foreground(
              context, GTK_STATE_FLAG_NORMAL, GTK_ENTRY_ICON_PRIMARY,
              GTK_TEXT_DIR_RTL, &primary_rtl);
      const bool sampled_secondary_rtl =
          busymax_sample_gtk_search_entry_icon_foreground(
              context, GTK_STATE_FLAG_NORMAL, GTK_ENTRY_ICON_SECONDARY,
              GTK_TEXT_DIR_RTL, &secondary_rtl);
      const bool sampled_backdrop_primary_ltr =
          busymax_sample_gtk_search_entry_icon_foreground(
              context, GTK_STATE_FLAG_BACKDROP, GTK_ENTRY_ICON_PRIMARY,
              GTK_TEXT_DIR_LTR, &backdrop_primary_ltr);
      std::cout << "Directional CSS primary.ltr=" << ColorString(primary_ltr)
                << " secondary.ltr=" << ColorString(secondary_ltr)
                << " primary.rtl=" << ColorString(primary_rtl)
                << " secondary.rtl=" << ColorString(secondary_rtl)
                << " backdrop.primary.ltr="
                << ColorString(backdrop_primary_ltr) << '\n';
      passed =
          Check(sampled_primary_ltr,
                "LTR primary image-node color was not sampled") &&
          Check(sampled_secondary_ltr,
                "LTR secondary image-node color was not sampled") &&
          Check(sampled_primary_rtl,
                "RTL primary image-node color was not sampled") &&
          Check(sampled_secondary_rtl,
                "RTL secondary image-node color was not sampled") &&
          Check(sampled_backdrop_primary_ltr,
                "Backdrop LTR primary image-node color was not sampled") &&
          Check(ColorsEqual(primary_ltr, disabled_left),
                "LTR primary did not use disabled image.left") &&
          Check(ColorsEqual(secondary_ltr, sensitive_right),
                "LTR secondary did not use sensitive image.right") &&
          Check(ColorsEqual(primary_rtl, disabled_right),
                "RTL primary did not use disabled image.right") &&
          Check(ColorsEqual(secondary_rtl, sensitive_left),
                "RTL secondary did not use sensitive image.left") &&
          Check(ColorsEqual(backdrop_primary_ltr,
                            disabled_backdrop_left),
                "LTR primary did not preserve backdrop while disabled") &&
          passed;
      gtk_widget_destroy(entry);
      g_object_unref(entry);
      gtk_style_context_remove_provider_for_screen(
          screen, GTK_STYLE_PROVIDER(provider));
    }
    g_object_unref(provider);
  }

  BusyMaxGtkSearchEntryTheme initial = {};
  passed = Check(busymax_sample_gtk_search_entry_theme(&initial),
                 "A real GtkSearchEntry could not be sampled") &&
           passed;
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
           Check(IsValidColor(initial.normal.primary_icon_foreground) &&
                     IsValidColor(
                         initial.normal.primary_icon_foreground_rtl) &&
                     IsValidColor(initial.normal.secondary_icon_foreground) &&
                     IsValidColor(
                         initial.normal.secondary_icon_foreground_rtl),
                 "Search-entry image-node foregrounds could not be sampled") &&
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

  BusyMaxGtkSearchEntryTheme yaru_model = {};
  gdk_rgba_parse(&yaru_model.focused.border_color, "#123456");
  yaru_model.focused.border_width.top = 7;
  yaru_model.focused.border_width.right = 8;
  yaru_model.focused.border_width.bottom = 9;
  yaru_model.focused.border_width.left = 10;
  yaru_model.normal.has_inner_focus = TRUE;
  yaru_model.normal.inner_focus_width = 4;
  yaru_model.backdrop.has_inner_focus = TRUE;
  yaru_model.backdrop.inner_focus_width = 4;
  yaru_model.backdrop_focused.has_inner_focus = TRUE;
  yaru_model.backdrop_focused.inner_focus_width = 4;
  busymax_apply_yaru_search_entry_compatibility(&yaru_model);
  passed =
      Check(yaru_model.normal.border_radius == 9 &&
                yaru_model.focused.border_radius == 9 &&
                yaru_model.backdrop.border_radius == 9 &&
                yaru_model.backdrop_focused.border_radius == 9,
            "Yaru compatibility did not apply the 9px radius") &&
      Check(yaru_model.focused.border_width.top == 7 &&
                yaru_model.focused.border_width.right == 8 &&
                yaru_model.focused.border_width.bottom == 9 &&
                yaru_model.focused.border_width.left == 10,
            "Yaru compatibility modified sampled focused border widths") &&
      Check(!yaru_model.normal.has_inner_focus &&
                yaru_model.normal.inner_focus_width == 0,
            "Yaru normal state retained an inner focus stroke") &&
      Check(yaru_model.focused.has_inner_focus &&
                yaru_model.focused.inner_focus_width == 1 &&
                ColorsEqual(yaru_model.focused.inner_focus_color,
                            yaru_model.focused.border_color),
            "Yaru focused state did not expose its one-pixel inset") &&
      Check(!yaru_model.backdrop.has_inner_focus &&
                yaru_model.backdrop.inner_focus_width == 0 &&
                !yaru_model.backdrop_focused.has_inner_focus &&
                yaru_model.backdrop_focused.inner_focus_width == 0,
            "Yaru backdrop states retained an active inner focus stroke") &&
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
               Check(sampled.focused.border_width.top == 1 &&
                         sampled.focused.border_width.right == 1 &&
                         sampled.focused.border_width.bottom == 1 &&
                         sampled.focused.border_width.left == 1,
                     "Yaru focused border was not the native 1px border") &&
               Check(sampled.focused.has_inner_focus &&
                         sampled.focused.inner_focus_width == 1 &&
                         ColorsEqual(sampled.focused.inner_focus_color,
                                     sampled.focused.border_color),
                     "Yaru focused state did not expose a separate 1px inset") &&
               Check(!sampled.normal.has_inner_focus &&
                         !sampled.backdrop.has_inner_focus &&
                         !sampled.backdrop_focused.has_inner_focus,
                     "Yaru non-active states exposed an active focus inset") &&
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
